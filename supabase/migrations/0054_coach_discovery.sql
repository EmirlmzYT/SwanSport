-- 0054 — Antrenör keşfi
--
-- Planın Dönem 5'i: doğrulanmış antrenör profilleri, branş/şehir/kademe ile
-- aranabilsin, ilk aşamada ödeme değil **talep ve sohbet**.
--
-- YENİ TABLO YOK. Gereken her şey duruyor: `profile_credentials` doğrulanmış
-- antrenörlüğü ve kademeyi (`coach_level`) tutuyor, `my_coach_sports()`
-- branşları veriyor, `profiles.city_code` şehri. Eksik olan tek şey bunları
-- birleştiren bir arama.
--
-- DEĞERLENDİRME/YORUM YOK. Plan da istemiyor: doğrulanabilir bir hizmet
-- kaydı olmadan yıldız sistemi kurmak manipülasyona açık — kimin gerçekten
-- ders aldığını bilmeden puan toplamak, puanı anlamsız yapar.

-- ---------------------------------------------------------------------------
-- Antrenör arama
--
-- Yalnızca **görünür olmayı kabul etmiş** antrenörler dönüyor. Doğrulanmış
-- olmak tek başına yetmiyor: kulübünde çalışan bir antrenörün yeni öğrenci
-- aramıyor olabileceğini varsaymak, onu istemediği taleplere açardı.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists coach_discoverable boolean not null default false,
  add column if not exists coach_bio text;

comment on column public.profiles.coach_discoverable is
  'Antrenör keşfinde görünmeyi kabul etti mi. Varsayılan KAPALI — '
  'doğrulanmış olmak, talep almak istemekle aynı şey değil.';

create index if not exists idx_profiles_coach_discoverable
  on public.profiles (city_code) where coach_discoverable;

create or replace function public.search_coaches(
  p_query text default null,
  p_sport text default null,
  p_city  text default null,
  p_min_level int default null,
  p_limit int default 30)
returns table (
  profile_id uuid,
  full_name  text,
  city_code  text,
  bio        text,
  level      int,
  sports     text[])
language sql
stable
security definer
set search_path = public
as $fn$
  select p.id,
         p.full_name,
         p.city_code,
         p.coach_bio,
         max(c.coach_level),
         coalesce(array_agg(distinct c.sport_code)
                    filter (where c.sport_code is not null), '{}')
    from public.profiles p
    join public.profile_credentials c
      on c.profile_id = p.id
     and c.kind = 'coach'
     and c.status = 'approved'
   where p.coach_discoverable
     -- Kendini aramanın anlamı yok ve sonucu kirletiyor.
     and p.id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
     -- Engellenen kişi görünmüyor (0052 ile aynı kural).
     and (auth.uid() is null or not public.is_blocked_between(auth.uid(), p.id))
     and (p_query is null or public.tr_contains(p.full_name, p_query))
     and (p_city  is null or p.city_code = p_city)
     and (p_sport is null or c.sport_code = p_sport)
   group by p.id, p.full_name, p.city_code, p.coach_bio
  having (p_min_level is null or max(c.coach_level) >= p_min_level)
   order by max(c.coach_level) desc nulls last, p.full_name
   limit least(greatest(coalesce(p_limit, 30), 1), 50);
$fn$;

revoke execute on function public.search_coaches(text, text, text, int, int)
  from public;
grant execute on function public.search_coaches(text, text, text, int, int)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Keşfedilebilirlik anahtarı
--
-- RPC olmasının sebebi: yalnızca **doğrulanmış** antrenör açabilsin.
-- Doğrudan `update` ile herkes kendini keşfedilebilir yapabilirdi ve
-- doğrulanmamış kişiler arama sonucunda çıkmasa da bayrak taşırdı.
-- ---------------------------------------------------------------------------
create or replace function public.set_coach_discoverable(
  p_on boolean,
  p_bio text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if p_on and not public.is_verified_coach() then
    raise exception 'Antrenör keşfinde görünmek için onaylanmış antrenör '
                    'belgen olmalı';
  end if;

  update public.profiles
     set coach_discoverable = p_on,
         coach_bio = case when p_bio is null then coach_bio
                          else nullif(trim(p_bio), '') end
   where id = auth.uid();
end;
$fn$;

revoke execute on function public.set_coach_discoverable(boolean, text)
  from public, anon;
grant execute on function public.set_coach_discoverable(boolean, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Bayrak — kademeli yayın (0053)
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('coach_discovery', 'admins', 'Antrenör keşfi',
   'Doğrulanmış antrenörleri branş, şehir ve kademeye göre bulma.')
on conflict (key) do nothing;
