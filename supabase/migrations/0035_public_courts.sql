-- ---------------------------------------------------------------------------
-- 0035 — Halka açık kort sırası
--
-- Konya'da halka açık kortlarda kural şu: bir saat oynanır, sıra alınır. Ama
-- sıra alacak bir yer yok — gidiyorsun, boşsa giriyorsun, biri gelirse senden
-- sonra oynuyor. Sonuç: boşuna gidiş, kort kenarında bekleme, "ben önce
-- geldim" tartışması.
--
-- Bu sistem sahadaki kuralı DEĞİŞTİRMİYOR, dijitalleştiriyor. Bugünkü norm
-- sağlam ve herkes uyuyor: orada olan oynar. Yaptığımız tek şey beklemeyi
-- kortun kenarından evine taşımak. Bu yüzden hiçbir resmî yaptırıma ihtiyaç
-- duymuyor: kullanan avantaj kazanıyor, kullanmayan bugünkü gibi devam ediyor.
--
-- AYRILABİLİRLİK: kort dünyası bir gün kendi uygulamasına ayrılacak. O yüzden
-- kort verisi kulüp tablolarına karışmaz — `court_players` ayrı durur,
-- `profiles` şişirilmez. Buraya kulüp kavramı sokmayın.
-- ---------------------------------------------------------------------------

-- ============================ 1. Kortlar ===================================

-- `facilities` kullanılmadı: o tablo kulübe ait (`club_id not null`),
-- koordinatı ve saat şeridi yok, yalnızca kulüp üyesine görünür. Halka açık
-- kortun sahibi yok, konumu şart ve herkese açık.
create table if not exists public.courts (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,               -- "Millet Bahçesi Kort 1"
  venue      text,                        -- "Millet Bahçesi"
  city_code  text references public.cities(code),
  district   text,
  sport_code text references public.sports(code),
  lat        numeric(9,6) not null,
  lng        numeric(9,6) not null,
  opens_at   time not null default '08:00',
  closes_at  time not null default '23:00',
  capacity   int  not null default 4,     -- kortta kaç kişi oynayabilir
  active     boolean not null default true,
  created_at timestamptz not null default now(),

  constraint court_hours_sane check (closes_at > opens_at),
  constraint court_capacity_sane check (capacity between 1 and 20)
);

create index if not exists idx_court_active
  on public.courts (active, city_code);

-- ============================ 2. Kutular ===================================

create table if not exists public.court_slots (
  id            uuid primary key default gen_random_uuid(),
  court_id      uuid not null references public.courts(id) on delete cascade,
  starts_at     timestamptz not null,
  owner_id      uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'claimed',
  checked_in_at timestamptz,
  guest_count   int not null default 0,   -- uygulamada olmayan arkadaşlar
  needed        int not null default 0,   -- kaç oyuncu aranıyor
  created_at    timestamptz not null default now(),

  -- BU TASARIMIN KİLİT TAŞI. İki kişi aynı saniyede aynı kutuya bastığında
  -- çakışmayı uygulama değil veritabanı çözer; biri kazanır, diğeri hata
  -- alır. Yarış durumunu kodda çözmeye çalışmak bu tür sistemlerde en sık
  -- yapılan hatadır.
  constraint court_slot_unique unique (court_id, starts_at),

  constraint court_slot_status_valid
    check (status in ('claimed', 'active', 'done', 'expired', 'cancelled')),
  constraint court_slot_counts_sane
    check (guest_count between 0 and 19 and needed between 0 and 19)
);

create index if not exists idx_court_slot_window
  on public.court_slots (court_id, starts_at);
create index if not exists idx_court_slot_owner
  on public.court_slots (owner_id, status);
-- Oyuncu aranan kutuların listesi sık okunacak.
create index if not exists idx_court_slot_open
  on public.court_slots (starts_at) where needed > 0;

-- ======================= 3. Katılan oyuncular ==============================

-- Kutu sahibi burada tutulmaz — `court_slots.owner_id` zaten var; aynı bilgiyi
-- iki yerde tutmak ikisinin zamanla ayrışması demek.
create table if not exists public.court_slot_players (
  slot_id    uuid not null references public.court_slots(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  status     text not null default 'pending',
  created_at timestamptz not null default now(),

  primary key (slot_id, profile_id),
  constraint court_player_status_valid
    check (status in ('pending', 'accepted', 'rejected'))
);

-- ==================== 4. Doğrulama kademesi ================================

-- Kademe HESABA aittir: kulüp, antrenörlük, lisans ve velilik zaten hesabın
-- üstüne doğrulanarak ekleniyor; kortun konum doğrulaması da aynı ailenin
-- üyesi. Bugün yalnızca 'location' erişilebilir; 'phone' ve 'id' altyapı
-- olarak duruyor, kullanılmıyor.
alter table public.profiles
  add column if not exists verification_tier text not null default 'none';

create or replace function public.verification_rank(p_tier text)
returns int language sql immutable as $fn$
  select case p_tier
           when 'id' then 3
           when 'phone' then 2
           when 'location' then 1
           else 0
         end;
$fn$;

-- Kort DAVRANIŞI hesaba değil buraya yazılır (ayrılabilirlik).
create table if not exists public.court_players (
  profile_id   uuid primary key references public.profiles(id) on delete cascade,
  no_shows     int not null default 0,
  banned_until timestamptz,
  first_seen   timestamptz not null default now()
);

-- ============================ 5. Mesafe ====================================

-- PostGIS eklenmedi: tek ihtiyaç "150 metre içinde miyim". Haversine yeter.
create or replace function public.meters_between(
  lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric)
returns numeric language sql immutable as $fn$
  select (6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) *
    power(sin(radians(lng2 - lng1) / 2), 2))))::numeric;
$fn$;

-- Kortta sayılmak için azami uzaklık. GPS parkta 30-50 m şaşabiliyor;
-- 150 m dürüst kullanıcıyı kapıda bırakmayacak kadar geniş, yan sokaktan
-- giriş yaptırmayacak kadar dar.
create or replace function public.court_checkin_radius()
returns numeric language sql immutable as $fn$ select 150::numeric; $fn$;

-- ============================ 6. RLS =======================================

alter table public.courts enable row level security;
alter table public.court_slots enable row level security;
alter table public.court_slot_players enable row level security;
alter table public.court_players enable row level security;

-- Kortlar ve doluluk giriş yapmamış kişiye de görünür: uygulamayı indirme
-- sebebi bu. Rol duvarının arkasına koymak tüm amacı boşa çıkarır.
drop policy if exists "court_read" on public.courts;
create policy "court_read" on public.courts
  for select to anon, authenticated using (active or public.is_platform_admin());

drop policy if exists "court_admin" on public.courts;
create policy "court_admin" on public.courts
  for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

drop policy if exists "court_slot_read" on public.court_slots;
create policy "court_slot_read" on public.court_slots
  for select to anon, authenticated using (true);

drop policy if exists "court_slot_player_read" on public.court_slot_players;
create policy "court_slot_player_read" on public.court_slot_players
  for select to authenticated using (true);

-- Kendi kort geçmişini görür; başkasınınkini görmez.
drop policy if exists "court_player_self" on public.court_players;
create policy "court_player_self" on public.court_players
  for select to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

-- Yazma policy'si hiçbirinde YOK: bütün değişiklikler security definer
-- RPC'lerden geçiyor, kurallar orada tek yerde duruyor.

-- ============================ 7. RPC'ler ===================================

-- Kortun 3 saatlik şeridi. Giriş yapmamış kişi de çağırabilir; kim olduğu
-- bilinmiyorsa `mine` alanları false döner.
create or replace function public.court_timeline(p_court uuid)
returns table (
  starts_at timestamptz,
  slot_id   uuid,
  owner_id  uuid,
  owner_name text,
  status    text,
  needed    int,
  players   int,
  mine      boolean
)
language sql stable security definer set search_path = public as $$
  with court as (select * from public.courts where id = p_court and active),
  -- Şeridin başı: içinde bulunduğumuz saat. Sonu: 3 saat ileri.
  hours as (
    select generate_series(
             date_trunc('hour', now()),
             date_trunc('hour', now()) + interval '3 hours',
             interval '1 hour') as h
  )
  select
    hours.h,
    s.id,
    s.owner_id,
    p.full_name,
    coalesce(s.status, 'free'),
    coalesce(s.needed, 0),
    coalesce(s.guest_count, 0)
      + coalesce((select count(*)::int from public.court_slot_players sp
                   where sp.slot_id = s.id and sp.status = 'accepted'), 0)
      + case when s.id is null then 0 else 1 end,
    coalesce(s.owner_id = auth.uid(), false)
  from hours
  cross join court
  left join public.court_slots s
    on s.court_id = court.id
   and s.starts_at = hours.h
   and s.status in ('claimed', 'active')
  left join public.profiles p on p.id = s.owner_id
  -- Kortun kapalı olduğu saatler şeritte görünmez.
  where (hours.h at time zone 'Europe/Istanbul')::time >= court.opens_at
    and (hours.h at time zone 'Europe/Istanbul')::time <  court.closes_at
  order by 1;
$$;

-- İlk doğrulama: kortta olduğunu bir kez kanıtla, hesabın "oyuncu" olsun.
-- Bundan sonra evden sıra alabilirsin.
--
-- Neden bu yöntem: SMS mesaj başına para yakıyor, kimlik istemek de tenis
-- oynamak isteyen adamı kaçırıyor. Konum bedava, kişisel veri toplamıyor ve
-- şu yan etkiyi taşıyor: hesap açan herkes o kortu gerçekten kullanan biri.
create or replace function public.verify_court_location(
  p_court uuid, p_lat numeric, p_lng numeric)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_court record; v_distance numeric;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select * into v_court from public.courts where id = p_court and active;
  if v_court is null then raise exception 'Kort bulunamadı'; end if;

  v_distance := public.meters_between(p_lat, p_lng, v_court.lat, v_court.lng);
  if v_distance > public.court_checkin_radius() then
    raise exception 'Kortta değilsin (% metre uzaktasın)', round(v_distance);
  end if;

  -- Kademe yalnızca yükselir: belgeyle 'id' olmuş biri korta gidince
  -- 'location'a düşmemeli.
  update public.profiles
     set verification_tier = 'location'
   where id = auth.uid()
     and public.verification_rank(verification_tier)
       < public.verification_rank('location');

  insert into public.court_players (profile_id) values (auth.uid())
    on conflict (profile_id) do nothing;

  return true;
end; $$;

-- Kutu al. Sıraya girmek de saat seçmek de bu fonksiyondan geçer — ikisi
-- ayrı sistem değil, aynı şeyin iki arayüzü.
create or replace function public.claim_slot(
  p_court     uuid,
  p_starts_at timestamptz,
  p_guests    int default 0,
  p_needed    int default 0)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_court  record;
  v_player record;
  v_id     uuid;
  v_local  time;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select * into v_court from public.courts where id = p_court and active;
  if v_court is null then raise exception 'Kort bulunamadı'; end if;

  -- 1) Yasaklı mı?
  select * into v_player from public.court_players where profile_id = auth.uid();
  if v_player.banned_until is not null and v_player.banned_until > now() then
    raise exception 'Tekrar tekrar gelmediğin için % tarihine kadar sıra alamazsın',
      to_char(v_player.banned_until at time zone 'Europe/Istanbul', 'DD.MM.YYYY');
  end if;

  -- 2) Doğrulama kademesi yeterli mi? (trol hesap sıra alamaz)
  if public.verification_rank(
       (select verification_tier from public.profiles where id = auth.uid()))
     < public.verification_rank('location') then
    raise exception 'Sıra alabilmek için bir kez kortta olduğunu doğrulamalısın';
  end if;

  -- 3) Zaten aktif kutusu var mı? Tek aktif kutu kuralı, akşamı bloke
  --    etmeyi ve sıra kabzımanlığını engelleyen asıl şey.
  if exists (
    select 1 from public.court_slots
     where owner_id = auth.uid()
       and status in ('claimed', 'active')
       and starts_at + interval '1 hour' > now()
  ) or exists (
    select 1 from public.court_slot_players sp
      join public.court_slots s on s.id = sp.slot_id
     where sp.profile_id = auth.uid() and sp.status = 'accepted'
       and s.status in ('claimed', 'active')
       and s.starts_at + interval '1 hour' > now()
  ) then
    raise exception 'Zaten aktif bir sıran var';
  end if;

  -- 4) Saat şeridin içinde mi?
  if p_starts_at <> date_trunc('hour', p_starts_at) then
    raise exception 'Saat tam saat olmalı';
  end if;
  if p_starts_at < date_trunc('hour', now()) then
    raise exception 'Geçmiş saat alınamaz';
  end if;
  if p_starts_at > date_trunc('hour', now()) + interval '3 hours' then
    raise exception 'En fazla 3 saat ilerisi alınabilir';
  end if;

  -- 5) Kort o saatte açık mı?
  v_local := (p_starts_at at time zone 'Europe/Istanbul')::time;
  if v_local < v_court.opens_at or v_local >= v_court.closes_at then
    raise exception 'Kort o saatte kapalı';
  end if;

  if p_guests + p_needed + 1 > v_court.capacity then
    raise exception 'Kort en fazla % kişilik', v_court.capacity;
  end if;

  -- Çakışma buradan sonra veritabanının işi: unique kısıtı ikinci kişiyi
  -- reddeder. Önce "boş mu" diye bakıp sonra yazmak yarış durumu üretirdi.
  begin
    insert into public.court_slots
      (court_id, starts_at, owner_id, guest_count, needed)
    values (p_court, p_starts_at, auth.uid(), p_guests, p_needed)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'O saati az önce başkası aldı';
  end;

  insert into public.court_players (profile_id) values (auth.uid())
    on conflict (profile_id) do nothing;

  return v_id;
end; $$;

-- Kortta olduğunu kanıtla. Kanıtlamazsan `court_slot_maintenance` kutuyu
-- 10 dakika sonra düşürür.
create or replace function public.check_in_slot(
  p_slot uuid, p_lat numeric, p_lng numeric)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_slot record; v_court record; v_distance numeric;
begin
  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id <> auth.uid() then raise exception 'Yetkisiz'; end if;
  if v_slot.status not in ('claimed', 'active') then
    raise exception 'Bu kutu artık geçerli değil';
  end if;

  -- Saatinden 15 dakika önce başlayabilir; erken gelen kortu boş bulmuşsa
  -- beklemesin.
  if now() < v_slot.starts_at - interval '15 minutes' then
    raise exception 'Henüz erken';
  end if;

  select * into v_court from public.courts where id = v_slot.court_id;
  v_distance := public.meters_between(p_lat, p_lng, v_court.lat, v_court.lng);
  if v_distance > public.court_checkin_radius() then
    raise exception 'Kortta değilsin (% metre uzaktasın)', round(v_distance);
  end if;

  update public.court_slots
     set checked_in_at = now(), status = 'active'
   where id = p_slot;

  -- Geldiğinde sayaç sıfırlanır: ceza ÜST ÜSTE gelmemeye, toplama değil.
  update public.court_players set no_shows = 0 where profile_id = auth.uid();

  return true;
end; $$;

-- Boş kortta kimse kovulmaz: sonraki kutu boşsa devam edebilirsin.
-- Bugünkü gerçek de bu — boş kortta saat doldu diye kimse kaldırmıyor.
-- Sistem sahadaki âdete uymalı, yoksa insanlar sisteme değil âdete uyar.
create or replace function public.extend_slot(p_slot uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_slot record; v_court record; v_next timestamptz; v_id uuid; v_local time;
begin
  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id <> auth.uid() then raise exception 'Yetkisiz'; end if;
  if v_slot.status <> 'active' then
    raise exception 'Uzatmak için önce kortta olduğunu doğrula';
  end if;

  v_next := v_slot.starts_at + interval '1 hour';

  -- Sonunda uzatılır, başında değil: son 15 dakika.
  if now() < v_next - interval '15 minutes' then
    raise exception 'Uzatma saatin sonunda açılır';
  end if;

  select * into v_court from public.courts where id = v_slot.court_id;
  v_local := (v_next at time zone 'Europe/Istanbul')::time;
  if v_local < v_court.opens_at or v_local >= v_court.closes_at then
    raise exception 'Kort kapanıyor';
  end if;

  begin
    insert into public.court_slots
      (court_id, starts_at, owner_id, guest_count, status, checked_in_at)
    values (v_slot.court_id, v_next, auth.uid(), v_slot.guest_count,
            'active', now())
    returning id into v_id;
  exception when unique_violation then
    -- Biri sıradaki saati almış: uzatma yok, kort değişiyor. Tartışma da yok.
    raise exception 'Sonraki saati başkası aldı';
  end;

  update public.court_slots set status = 'done' where id = p_slot;
  return v_id;
end; $$;

-- İptal CEZASIZ. Bilerek böyle: iptal cezalandırılırsa kimse iptal etmez,
-- sessizce gelmez — sistemin en beter hali odur.
create or replace function public.cancel_slot(p_slot uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare v_slot record;
begin
  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id <> auth.uid() then raise exception 'Yetkisiz'; end if;

  update public.court_slots set status = 'cancelled' where id = p_slot;

  -- Katılması onaylanmış oyunculara haber ver; boşuna gitmesinler.
  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  select sp.profile_id, 'court_cancelled', 'Oyun iptal edildi',
         'Katıldığın oyun iptal edildi.', 'court_slot', p_slot
    from public.court_slot_players sp
   where sp.slot_id = p_slot and sp.status = 'accepted';
end; $$;

-- ---------------------------------------------------------------------------
-- Eksik oyuncu
-- ---------------------------------------------------------------------------

create or replace function public.request_join(p_slot uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare v_slot record;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id = auth.uid() then raise exception 'Bu senin oyunun'; end if;
  if v_slot.status not in ('claimed', 'active') then
    raise exception 'Bu oyun artık geçerli değil';
  end if;
  if v_slot.needed <= 0 then raise exception 'Oyuncu aranmıyor'; end if;

  if public.verification_rank(
       (select verification_tier from public.profiles where id = auth.uid()))
     < public.verification_rank('location') then
    raise exception 'Katılmak için bir kez kortta olduğunu doğrulamalısın';
  end if;

  insert into public.court_slot_players (slot_id, profile_id)
  values (p_slot, auth.uid())
  on conflict (slot_id, profile_id) do nothing;

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (v_slot.owner_id, 'court_join', 'Oyununa katılmak isteyen var',
          'Kabul veya reddet.', auth.uid(), 'court_slot', p_slot);
end; $$;

-- Katılım kutu sahibinin onayıyla: kortta kiminle karşılaşacağını seçebilmek,
-- özellikle yeni başlayanlar için sistemin kullanılabilirlik şartı.
create or replace function public.review_join(
  p_slot uuid, p_profile uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare v_slot record; v_accepted int;
begin
  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id <> auth.uid() then raise exception 'Yetkisiz'; end if;

  if p_accept then
    select count(*) into v_accepted from public.court_slot_players
     where slot_id = p_slot and status = 'accepted';
    if v_accepted >= v_slot.needed then
      raise exception 'Aranan oyuncu sayısı doldu';
    end if;
  end if;

  update public.court_slot_players
     set status = case when p_accept then 'accepted' else 'rejected' end
   where slot_id = p_slot and profile_id = p_profile;

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (p_profile, 'court_join_result',
          case when p_accept then 'Oyuna kabul edildin'
               else 'Oyun isteğin kabul edilmedi' end,
          null, auth.uid(), 'court_slot', p_slot);
end; $$;

-- Oyuncu aranan kutular.
create or replace function public.open_slots(p_city text default null)
returns table (
  slot_id    uuid,
  court_id   uuid,
  court_name text,
  venue      text,
  city_name  text,
  starts_at  timestamptz,
  owner_id   uuid,
  owner_name text,
  needed     int,
  accepted   int,
  requested  boolean
)
language sql stable security definer set search_path = public as $$
  select s.id, c.id, c.name, c.venue, ct.name, s.starts_at,
         s.owner_id, p.full_name, s.needed,
         (select count(*)::int from public.court_slot_players sp
           where sp.slot_id = s.id and sp.status = 'accepted'),
         exists (select 1 from public.court_slot_players sp
                  where sp.slot_id = s.id and sp.profile_id = auth.uid())
    from public.court_slots s
    join public.courts c on c.id = s.court_id
    join public.profiles p on p.id = s.owner_id
    left join public.cities ct on ct.code = c.city_code
   where s.status in ('claimed', 'active')
     and s.starts_at + interval '1 hour' > now()
     and s.needed > 0
     and s.owner_id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
     and (p_city is null or c.city_code = p_city)
     and (select count(*) from public.court_slot_players sp
           where sp.slot_id = s.id and sp.status = 'accepted') < s.needed
   order by s.starts_at;
$$;

-- ======================= 8. Zamanlanmış bakım ==============================

-- Beş dakikada bir çalışır. Üç iş yapar: hatırlatma, gelmeyeni düşürme,
-- biteni kapatma.
create or replace function public.court_slot_maintenance()
returns int
language plpgsql security definer set search_path = public as $$
declare v_reminders int := 0;
begin
  -- 1) Yaklaşan kutular için hatırlatma (20 dakika kala).
  --    `reminder_log` tekrar göndermeyi engelliyor — bu iş 5 dakikada bir
  --    çalıştığı için o kayıt olmasa aynı kişiye dört kez bildirim giderdi.
  with soon as (
    select s.id, s.owner_id, s.starts_at, c.name as court_name
      from public.court_slots s
      join public.courts c on c.id = s.court_id
     where s.status = 'claimed'
       and s.starts_at between now() and now() + interval '20 minutes'
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'court_slot', s.id, s.owner_id from soon s
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'court_reminder', 'Sıran yaklaşıyor',
           s.court_name || ' · ' ||
             to_char(s.starts_at at time zone 'Europe/Istanbul', 'HH24:MI') ||
             ' · korta varınca uygulamadan onayla',
           'court_slot', f.entity_id
      from fresh f join soon s on s.id = f.entity_id
    returning 1
  )
  select count(*) into v_reminders from sent;

  -- 2) Gelmeyenler: saatinden 10 dakika sonra hâlâ giriş yoksa kutu düşer,
  --    kort serbest kalır. Kortta bekleyen varsa anında alabilir.
  with dropped as (
    update public.court_slots
       set status = 'expired'
     where status = 'claimed'
       and starts_at + interval '10 minutes' < now()
    returning owner_id
  ),
  counted as (
    insert into public.court_players (profile_id, no_shows)
    select owner_id, 1 from dropped
    on conflict (profile_id) do update
      set no_shows = public.court_players.no_shows + 1
    returning profile_id, no_shows
  )
  -- Üç kez ÜST ÜSTE gelmeyen bir hafta sıra alamaz. Gelince sayaç
  -- sıfırlandığı için bu ceza dalgın kullanıcıyı değil, ısrarla
  -- istismar edeni vuruyor.
  update public.court_players cp
     set banned_until = now() + interval '7 days', no_shows = 0
    from counted c
   where cp.profile_id = c.profile_id and c.no_shows >= 3;

  -- 3) Süresi dolmuş oyunları kapat.
  update public.court_slots
     set status = 'done'
   where status = 'active'
     and starts_at + interval '1 hour' < now();

  return v_reminders;
end; $$;

select cron.unschedule('swansport_court_maintenance')
 where exists (select 1 from cron.job where jobname = 'swansport_court_maintenance');

select cron.schedule('swansport_court_maintenance', '*/5 * * * *',
  $cron$select public.court_slot_maintenance();$cron$);

-- ============================ 9. İzinler ===================================

-- 0028'in dersi: izin PUBLIC'ten miras alınır; yalnızca anon'dan almak yetmez.
revoke execute on function public.claim_slot(uuid, timestamptz, int, int) from public, anon;
revoke execute on function public.check_in_slot(uuid, numeric, numeric) from public, anon;
revoke execute on function public.extend_slot(uuid) from public, anon;
revoke execute on function public.cancel_slot(uuid) from public, anon;
revoke execute on function public.request_join(uuid) from public, anon;
revoke execute on function public.review_join(uuid, uuid, boolean) from public, anon;
revoke execute on function public.verify_court_location(uuid, numeric, numeric) from public, anon;
revoke execute on function public.court_slot_maintenance() from public, anon, authenticated;

-- Şerit ve oyuncu aranan listesi giriş yapmamış kişiye de açık: uygulamayı
-- indirme sebebi bu. İkisi de yalnızca herkese açık bilgiyi döndürüyor.
