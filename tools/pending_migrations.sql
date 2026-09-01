-- ===========================================================================
-- SwanSport — bekleyen migration'lar (0053-0054)
--
-- Supabase SQL Editor'e yapıştır, tek seferde çalıştır.
--
-- TEK İŞLEM: `begin`/`commit` arasında. Bir yerde hata olursa hiçbiri
-- uygulanmıyor.
--
-- TEKRAR ÇALIŞTIRILABİLİR: `create or replace`, `if not exists`,
-- `on conflict do nothing`.
--
-- İÇİNDEKİLER
--   0053  Özellik bayrakları — kademeli yayın (off/admins/testers/everyone)
--         Pazaryeri `admins`'te başlıyor: bugün herkese açıldı, hiç denenmedi.
--   0054  Antrenör keşfi — doğrulanmış + görünmeyi kabul etmiş antrenörler
--
-- NOT: 0053 çalıştırılmadan pazaryeri VE antrenör keşfi kimseye görünmez.
-- Bayrak bulunamayınca kapalı sayılıyor — bilinçli, güvenli taraf.
-- ===========================================================================

begin;


-- ---------------------------------------------------------------------------
-- 0053_feature_flags.sql
-- ---------------------------------------------------------------------------

-- 0053 — Özellik bayrakları ve kademeli yayın
--
-- Planın 1. bölümü: "Büyük özellikler doğrudan herkese açılmaz." Bugüne kadar
-- öyle açıldı — pazaryeri, kort sistemi, partner arama, halı saha; hepsi
-- yazıldığı gün herkese görünür oldu ve hiçbiri önce denenmedi.
--
-- Bu migration o kararı **uygulanabilir** hale getiriyor. Bayrak olmadan
-- "önce test kullanıcılarıyla dene" bir niyet; bayrakla bir düğme.
--
-- Kademeler planın sırasıyla:
--   off       kimse görmüyor  (geri alma da bu)
--   admins    yalnızca platform yöneticisi
--   testers   seçili kullanıcılar ve kulüpler
--   everyone  genel yayın

create table if not exists public.feature_flags (
  key         text primary key,
  audience    text not null default 'off',
  label       text not null,
  description text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.profiles(id) on delete set null,

  constraint feature_flag_audience_valid
    check (audience in ('off', 'admins', 'testers', 'everyone'))
);

-- Kullanıcı bazlı test listesi. Kulüp bazlı yayın için `club_id` de var:
-- planda "seçili test kulübü" geçiyor ve tek tek kullanıcı eklemek bir
-- kulübün tamamını açmak için pratik değil.
create table if not exists public.feature_flag_testers (
  key        text not null references public.feature_flags(key) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  club_id    uuid references public.clubs(id) on delete cascade,
  created_at timestamptz not null default now(),

  -- Ya kişi ya kulüp; ikisi birden anlamsız, hiçbiri boş satır demek.
  constraint tester_target_present
    check (num_nonnulls(profile_id, club_id) = 1)
);

create unique index if not exists idx_flag_tester_profile
  on public.feature_flag_testers (key, profile_id) where profile_id is not null;
create unique index if not exists idx_flag_tester_club
  on public.feature_flag_testers (key, club_id) where club_id is not null;

alter table public.feature_flags enable row level security;
alter table public.feature_flag_testers enable row level security;

-- Bayrak listesi herkese okunur: istemci hangi özelliğin açık olduğunu
-- bilmek zorunda. Gizli tutulacak bir şey değil — asıl koruma özelliğin
-- kendi RLS'inde, bayrak yalnızca görünürlük.
drop policy if exists "flag_read" on public.feature_flags;
create policy "flag_read" on public.feature_flags for select
  to anon, authenticated using (true);

drop policy if exists "flag_admin" on public.feature_flags;
create policy "flag_admin" on public.feature_flags for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Test listesi yalnızca yöneticiye ve kişinin kendisine. Kimin test
-- kullanıcısı olduğu başkasını ilgilendirmiyor.
drop policy if exists "flag_tester_read" on public.feature_flag_testers;
create policy "flag_tester_read" on public.feature_flag_testers for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists "flag_tester_admin" on public.feature_flag_testers;
create policy "flag_tester_admin" on public.feature_flag_testers for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ---------------------------------------------------------------------------
-- Bu kullanıcı için açık olan bayraklar
--
-- Tek çağrıda hepsi dönüyor: uygulama açılışta bir kez alıp bellekte
-- tutuyor. Her ekranda ayrı sorgu, açılışı ekran sayısı kadar yavaşlatırdı.
-- ---------------------------------------------------------------------------
create or replace function public.my_feature_flags()
returns table (key text)
language sql
stable
security definer
set search_path = public
as $fn$
  select f.key
    from public.feature_flags f
   where f.audience = 'everyone'
      or (f.audience = 'admins' and public.is_platform_admin())
      or (f.audience = 'testers' and (
            public.is_platform_admin()
            or exists (select 1 from public.feature_flag_testers t
                        where t.key = f.key and t.profile_id = auth.uid())
            or exists (select 1 from public.feature_flag_testers t
                        join public.club_memberships m
                          on m.club_id = t.club_id
                         and m.profile_id = auth.uid()
                         and m.status = 'active'
                       where t.key = f.key)
         ));
$fn$;

revoke execute on function public.my_feature_flags() from public;
grant execute on function public.my_feature_flags() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Mevcut özellikler için bayraklar
--
-- Pazaryeri `admins`'te başlıyor — bugün herkese açıldı ve hiç denenmedi.
-- Geri çekmek değil, planın söylediği sıraya oturtmak: önce yönetici, sonra
-- seçili kullanıcılar, sonra genel.
--
-- Diğerleri `everyone`: aylardır canlıdalar ve kapatmak, kullanan varsa
-- (kimse denemediği için bilmiyoruz) elinden almak olurdu. Bayrağa
-- bağlanmalarının sebebi ileride geri alınabilmeleri.
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('marketplace', 'admins', 'Spor malzemeleri pazaryeri',
   'İlan, mağaza, favori ve raporlama. Kademeli açılıyor.'),
  ('courts', 'everyone', 'Halka açık kortlar',
   'Kort sırası ve konum doğrulama.'),
  ('partner_search', 'everyone', 'Partner arama',
   'Branşa göre partner eşleştirme.'),
  ('turf_fields', 'everyone', 'Halı sahalar',
   'Doluluk panosu ve saat isteme.'),
  ('team_hub', 'everyone', 'Takım merkezi',
   'Kadro, program ve takım sohbeti.')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 0054_coach_discovery.sql
-- ---------------------------------------------------------------------------

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


commit;

-- ===========================================================================
-- Doğrulama (ayrı çalıştır):
--
--   select key, audience from public.feature_flags order by key;
--
-- Altı satır dönmeli. Pazaryerini açmak için konsol > Özellik bayrakları.
-- ===========================================================================
