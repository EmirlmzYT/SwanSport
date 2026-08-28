-- ===========================================================================
-- SwanSport — SPOR EKOSİSTEMİ PAKETİ
--
-- Yedi fazın tamamı, çalıştırılması gereken sırayla:
--   1) Faz 1 — Kulüp keşfet + filtreli arama
--   2) Faz 2 — Sporcu/antrenör CV + doğrulanmış başarı
--   3) Faz 3 — İlanlar ve seçmeler
--   4) Faz 4-5 — Belge kasası, veli, bildirim tercihleri
--   5) Faz 6-7 — Lig/turnuva, kulüp mesajı, etkinlik başvurusu
--
-- ÖN KOŞUL: daha önceki kurulumlar (SETUP, SOCIAL, COMMUNITIES, FEDERATION,
-- FINANCE, SCHEDULE, CLUB_PROFILE …) çalıştırılmış olmalı.
--
-- Supabase SQL editöründe TEK SEFERDE çalıştır. Tekrar çalıştırılabilir.
-- ===========================================================================



-- ##########################################################################
-- Faz 1 — Kulüp keşfet + filtreli arama
-- ##########################################################################

-- =============================================================================
-- SwanSport — FAZ 1: KULÜP KEŞFET
--
-- Kulüp künyesindeki il/ilçe/branş verisi zaten duruyordu ama hiçbir yerden
-- filtrelenemiyordu. Arama yalnızca isme bakıyordu.
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- Harita görünümü için hazırlık. Şimdilik doldurulmuyor; veri mimarisi hazır
-- olsun diye ekleniyor (istenen: "mümkünse harita görünümüne uygun veri").
alter table public.clubs
  add column if not exists latitude  numeric(9,6),
  add column if not exists longitude numeric(9,6);


-- ---------------------------------------------------------------------------
-- Kulüp keşfi — filtreli arama.
--
-- Tüm filtreler isteğe bağlı; boş geçilen filtre uygulanmaz. Sıralama
-- kasıtlı: onaylı kulüpler önce, sonra kadrosu kalabalık olanlar. Yeni açılmış
-- boş bir kulüp listenin başında durursa keşfetmenin anlamı kalmaz.
-- ---------------------------------------------------------------------------
create or replace function public.discover_clubs(
  p_query    text default null,
  p_city     text default null,   -- plaka kodu ('42') ya da il adı
  p_district text default null,
  p_sport    text default null,   -- sports.code
  p_verified boolean default false,
  p_limit    int default 40)
returns table (
  id            uuid,
  name          text,
  short_name    text,
  city          text,
  district      text,
  sport_name    text,
  logo_path     text,
  bio           text,
  status        text,
  athlete_count int,
  coach_count   int,
  is_following  boolean
)
language sql stable security definer set search_path = public as $$
  with city_name as (
    -- Plaka kodu da il adı da kabul edilir.
    select coalesce((select c.name from public.cities c where c.code = p_city),
                    p_city) as name
  )
  select
    c.id, c.name, c.short_name, c.city, c.district, s.name, c.logo_path, c.bio,
    c.status::text,
    (select count(*) from public.athletes a where a.club_id = c.id)::int,
    (select count(*) from public.club_memberships m
      where m.club_id = c.id and m.role = 'coach' and m.status = 'active')::int,
    exists (select 1 from public.follows f
             where f.follower_id = auth.uid()
               and f.target_type = 'club' and f.target_id = c.id)
  from public.clubs c
  left join public.sports s on s.code = c.sport_code
  cross join city_name cn
  where (p_query is null or trim(p_query) = ''
         or c.name ilike '%' || p_query || '%'
         or c.short_name ilike '%' || p_query || '%')
    and (cn.name is null or trim(cn.name) = ''
         or c.city ilike '%' || cn.name || '%')
    and (p_district is null or trim(p_district) = ''
         or c.district ilike '%' || p_district || '%')
    and (p_sport is null or trim(p_sport) = '' or c.sport_code = p_sport)
    and (not p_verified or c.status = 'active')
  order by (c.status = 'active') desc,
           (select count(*) from public.athletes a where a.club_id = c.id) desc,
           c.name
  limit greatest(p_limit, 1);
$$;


-- Filtre kutularını doldurmak için: hangi illerde ve branşlarda kulüp var?
-- Boş çıkacak bir filtreyi kullanıcıya sunmamak için kullanılır.
create or replace function public.club_filter_options()
returns table (kind text, code text, label text, club_count int)
language sql stable security definer set search_path = public as $$
  select 'city', c.city, c.city, count(*)::int
    from public.clubs c
   where c.city is not null and trim(c.city) <> ''
   group by c.city
  union all
  select 'sport', s.code, s.name, count(*)::int
    from public.clubs c
    join public.sports s on s.code = c.sport_code
   group by s.code, s.name
  order by 1, 4 desc, 3;
$$;


-- ##########################################################################
-- Faz 2 — Sporcu/antrenör CV + doğrulanmış başarı
-- ##########################################################################

-- =============================================================================
-- SwanSport — FAZ 2: SPORCU / ANTRENÖR CV + DOĞRULANMIŞ BAŞARI
--
-- İkinci bir profil sistemi kurulmuyor: mevcut `profiles`, `athletes`,
-- `profile_credentials` ve `club_memberships` genişletiliyor.
--
-- Kulüp geçmişi için yeni tablo da açılmıyor — üyelikte zaten kayıt var,
-- yalnızca "ne zaman ayrıldı" bilgisi eksikti.
--
-- ÖNCE: COMMUNITIES, FEDERATION, ATHLETE_PROFILE çalıştırılmış olmalı.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) ANTRENÖR KÜNYESİ
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists experience_years int,
  add column if not exists specialties      text,   -- "Altyapı, kuvvet"
  add column if not exists open_to_offers   boolean not null default false;

-- Sporcunun alt branşı / kategorisi (serbest metin: her branşın kendi dili var)
alter table public.athletes
  add column if not exists sub_branch text;


-- ---------------------------------------------------------------------------
-- 2) KULÜP GEÇMİŞİ
--
-- Üyelik silinince geçmiş de siliniyordu. Artık "ayrıldı" olarak işaretlenir;
-- kişinin CV'sinde geçmiş kulüp olarak durur.
-- ---------------------------------------------------------------------------
alter table public.club_memberships
  add column if not exists left_at date;

-- membership_status enum'una yeni değer eklemek yerine tarih alanı kullanıldı:
-- enum değişikliği aynı işlemde kullanılamıyor ve geri alması zor.

create or replace function public.end_membership(p_membership uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_club uuid;
begin
  select club_id into v_club from public.club_memberships where id = p_membership;
  if v_club is null then raise exception 'Üyelik bulunamadı'; end if;
  if not public.is_club_admin(v_club) then raise exception 'Yetkisiz'; end if;

  update public.club_memberships
     set status = 'suspended', left_at = coalesce(left_at, current_date)
   where id = p_membership;
end; $$;


-- Kişinin kulüp geçmişi — şimdiki ve geçmiş.
create or replace function public.person_club_history(p_profile uuid)
returns table (
  club_id    uuid,
  club_name  text,
  logo_path  text,
  role       text,
  coach_level int,
  started_on date,
  left_on    date,
  -- 'current' de ayrılmış sözcüklerden; is_current olarak döndürülüyor.
  is_current boolean
)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.logo_path, m.role::text, m.coach_level,
         m.created_at::date, m.left_at,
         (m.status = 'active' and m.left_at is null)
    from public.club_memberships m
    join public.clubs c on c.id = m.club_id
   where m.profile_id = p_profile
   order by (m.status = 'active' and m.left_at is null) desc,
            m.created_at desc;
$$;


-- ---------------------------------------------------------------------------
-- 3) DOĞRULANMIŞ BAŞARI
--
-- Kişinin kendi yazdığı başarı ile doğrulanmış başarı ayrılıyor. Doğrulama
-- için yeni bir onay sistemi kurulmuyor; mevcut platform yöneticisi ve kulüp
-- yetkilisi altyapısı kullanılıyor.
--
-- Kural: kulüp kendi sporcusunun başarısını doğrulayabilir (kulüp kaydı zaten
-- onda), platform yöneticisi her şeyi doğrulayabilir.
-- ---------------------------------------------------------------------------
alter table public.athlete_achievements
  add column if not exists verified     boolean not null default false,
  add column if not exists verified_by  uuid references public.profiles(id) on delete set null,
  add column if not exists verified_at  timestamptz;

alter table public.club_achievements
  add column if not exists verified     boolean not null default false,
  add column if not exists verified_by  uuid references public.profiles(id) on delete set null,
  add column if not exists verified_at  timestamptz;


create or replace function public.verify_athlete_achievement(
  p_achievement uuid, p_verified boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare v_athlete uuid;
begin
  select athlete_id into v_athlete
    from public.athlete_achievements where id = p_achievement;
  if v_athlete is null then raise exception 'Başarı bulunamadı'; end if;

  if not (public.is_platform_admin() or public.can_manage_athlete(v_athlete)) then
    raise exception 'Yetkisiz';
  end if;

  update public.athlete_achievements
     set verified = p_verified,
         verified_by = case when p_verified then auth.uid() else null end,
         verified_at = case when p_verified then now() else null end
   where id = p_achievement;
end; $$;


-- Doğrulama bekleyen başarılar — kulüp yetkilisi ve platform yöneticisi için.
create or replace function public.pending_achievements()
returns table (
  id uuid, athlete_id uuid, athlete_name text, club_name text,
  title text, placement int, event_date date, location text
)
language sql stable security definer set search_path = public as $$
  select a.id, a.athlete_id,
         trim(coalesce(at.first_name,'') || ' ' || coalesce(at.last_name,'')),
         c.name, a.title, a.placement, a.event_date, a.location
    from public.athlete_achievements a
    join public.athletes at on at.id = a.athlete_id
    left join public.clubs c on c.id = at.club_id
   where not a.verified
     and (public.is_platform_admin() or public.can_manage_athlete(a.athlete_id))
   order by a.event_date desc nulls last, a.created_at desc;
$$;


-- ---------------------------------------------------------------------------
-- 4) PROFİL KÜNYESİNİ GÜNCELLEME
-- ---------------------------------------------------------------------------
create or replace function public.update_coach_profile(
  p_experience  int default null,
  p_specialties text default null,
  p_open        boolean default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  update public.profiles
     set experience_years = coalesce(p_experience, experience_years),
         specialties = case when p_specialties is null then specialties
                            when p_specialties = ''   then null
                            else p_specialties end,
         open_to_offers = coalesce(p_open, open_to_offers)
   where id = auth.uid();
end; $$;


-- Kişinin herkese açık künyesi — CV başlığı için tek çağrı.
create or replace function public.person_summary(p_profile uuid)
returns table (
  full_name        text,
  username         text,
  bio              text,
  avatar_path      text,
  city_name        text,
  experience_years int,
  specialties      text,
  open_to_offers   boolean,
  credentials      text,
  is_coach         boolean,
  club_count       int
)
language sql stable security definer set search_path = public as $$
  select p.full_name, p.username, p.bio, p.avatar_path, ct.name,
         p.experience_years, p.specialties, p.open_to_offers,
         (select string_agg(
                   case when c.kind = 'coach'
                        then coalesce(s.name || ' · ', '') ||
                             coalesce(c.coach_level::text,'?') || '. Kademe Antrenör'
                        else 'Sporcu' end, ', ')
            from public.profile_credentials c
            left join public.sports s on s.code = c.sport_code
           where c.profile_id = p.id and c.status = 'approved'),
         exists (select 1 from public.profile_credentials c
                  where c.profile_id = p.id and c.kind = 'coach'
                    and c.status = 'approved'),
         (select count(*) from public.club_memberships m
           where m.profile_id = p.id)::int
    from public.profiles p
    left join public.cities ct on ct.code = p.city_code
   where p.id = p_profile;
$$;


-- ##########################################################################
-- Faz 3 — İlanlar ve seçmeler
-- ##########################################################################

-- =============================================================================
-- SwanSport — FAZ 3: İLANLAR VE SEÇMELER
--
-- Dört ihtiyaç tek tabloda toplanıyor:
--   • Kulüp sporcu arıyor            (athlete_wanted)
--   • Kulüp antrenör arıyor          (coach_wanted)
--   • Sporcu/antrenör kulüp arıyor   (club_wanted)
--   • Kulüp seçme yapıyor            (tryout)
--
-- Seçme için ayrı modül açılmadı: seçme de bir ilandır, yalnızca tarih, konum
-- ve kontenjan alanları dolu olan bir ilan. Ayrı tablo, aynı filtreleri ve
-- başvuru akışını ikinci kez yazmak demekti.
--
-- Başvuru kabul edilince mevcut üyelik akışına bağlanır — paralel bir üyelik
-- sistemi kurulmuyor.
-- =============================================================================


create table if not exists public.listings (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null,          -- athlete_wanted | coach_wanted | club_wanted | tryout
  -- Sahibi ya bir kulüptür ya da bir kişi; ikisinden biri dolu olmalı.
  club_id      uuid references public.clubs(id) on delete cascade,
  owner_id     uuid not null references public.profiles(id) on delete cascade,

  title        text not null,
  body         text,
  sport_code   text references public.sports(code),
  city_code    text references public.cities(code),
  district     text,

  -- Filtre alanları (branşa göre bir kısmı boş kalabilir)
  age_min      int,
  age_max      int,
  position     text,                   -- mevki (uygun branşlarda)
  coach_level_min int,                 -- antrenör ilanlarında aranan kademe

  -- Seçme alanları
  starts_at    timestamptz,
  location     text,
  quota        int,
  requirements text,

  deadline     date,
  status       text not null default 'open',   -- open | closed
  created_at   timestamptz not null default now(),

  constraint listing_owner_present
    check (club_id is not null or kind = 'club_wanted')
);

create index if not exists idx_listing_open
  on public.listings (status, kind, created_at desc);
create index if not exists idx_listing_filter
  on public.listings (sport_code, city_code, status);

alter table public.listings enable row level security;

-- İlanlar herkese açık: ağın çekim gücü görünür olmasına bağlı.
drop policy if exists "listing_read" on public.listings;
create policy "listing_read" on public.listings for select
  to authenticated using (true);

-- Yazma RPC üzerinden; doğrudan insert kapalı (yetki ve tutarlılık için).


create table if not exists public.listing_applications (
  id           uuid primary key default gen_random_uuid(),
  listing_id   uuid not null references public.listings(id) on delete cascade,
  applicant_id uuid not null references public.profiles(id) on delete cascade,
  note         text,
  status       text not null default 'pending',  -- pending | accepted | rejected
  reviewed_by  uuid references public.profiles(id) on delete set null,
  reviewed_at  timestamptz,
  created_at   timestamptz not null default now(),
  unique (listing_id, applicant_id)
);

create index if not exists idx_listing_app
  on public.listing_applications (listing_id, status);

alter table public.listing_applications enable row level security;

-- Başvuruyu yalnızca başvuran ve ilan sahibi görür.
drop policy if exists "listing_app_read" on public.listing_applications;
create policy "listing_app_read" on public.listing_applications for select
  to authenticated
  using (
    applicant_id = auth.uid()
    or exists (select 1 from public.listings l
                where l.id = listing_id
                  and (l.owner_id = auth.uid()
                       or (l.club_id is not null
                           and public.is_club_staff(l.club_id))))
  );


-- ---------------------------------------------------------------------------
-- İlan oluşturma
-- ---------------------------------------------------------------------------
create or replace function public.create_listing(
  p_kind       text,
  p_title      text,
  p_body       text default null,
  p_club       uuid default null,
  p_sport      text default null,
  p_city       text default null,
  p_district   text default null,
  p_age_min    int default null,
  p_age_max    int default null,
  p_position   text default null,
  p_level_min  int default null,
  p_starts_at  timestamptz default null,
  p_location   text default null,
  p_quota      int default null,
  p_requirements text default null,
  p_deadline   date default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  -- Kulüp adına ilan yalnızca kulüp yetkilisinden.
  if p_club is not null and not public.is_club_staff(p_club) then
    raise exception 'Bu kulüp adına ilan veremezsin';
  end if;

  -- Kulüp arayan ilanı kişiye aittir; diğer türler kulübe.
  if p_kind <> 'club_wanted' and p_club is null then
    raise exception 'Bu ilan türü için kulüp gerekiyor';
  end if;

  insert into public.listings
    (kind, club_id, owner_id, title, body, sport_code, city_code, district,
     age_min, age_max, "position", coach_level_min,
     starts_at, location, quota, requirements, deadline)
  values (p_kind, p_club, auth.uid(), p_title, p_body, p_sport, p_city,
          p_district, p_age_min, p_age_max, p_position, p_level_min,
          p_starts_at, p_location, p_quota, p_requirements, p_deadline)
  returning id into v_id;

  return v_id;
end; $$;


create or replace function public.close_listing(p_listing uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_row record;
begin
  select * into v_row from public.listings where id = p_listing;
  if v_row is null then raise exception 'İlan bulunamadı'; end if;

  if not (v_row.owner_id = auth.uid()
          or (v_row.club_id is not null and public.is_club_staff(v_row.club_id))) then
    raise exception 'Yetkisiz';
  end if;

  update public.listings set status = 'closed' where id = p_listing;
end; $$;


-- ---------------------------------------------------------------------------
-- Arama — tüm filtreler isteğe bağlı
-- ---------------------------------------------------------------------------
create or replace function public.search_listings(
  p_kind     text default null,
  p_sport    text default null,
  p_city     text default null,
  p_district text default null,
  p_level    int default null,     -- en az bu kademe
  p_verified boolean default false, -- yalnızca doğrulanmış hesapların ilanları
  p_query    text default null,
  p_limit    int default 40)
returns table (
  id uuid, kind text, title text, body text,
  club_id uuid, club_name text, club_logo text,
  owner_id uuid, owner_name text, owner_avatar text,
  sport_name text, city_name text, district text,
  -- NOT: 'position' PostgreSQL'de ayrılmış sözcük; çıktı sütunu olarak
  -- kullanılamıyor. Tablodaki sütun adı `position` olarak kalıyor, yalnızca
  -- fonksiyonun döndürdüğü ad değişti.
  age_min int, age_max int, position_name text, coach_level_min int,
  starts_at timestamptz, location text, quota int, deadline date,
  application_count int, applied boolean, can_manage boolean,
  created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    l.id, l.kind, l.title, l.body,
    l.club_id, c.name, c.logo_path,
    l.owner_id, p.full_name, p.avatar_path,
    s.name, ct.name, l.district,
    l.age_min, l.age_max, l.position, l.coach_level_min,
    l.starts_at, l.location, l.quota, l.deadline,
    (select count(*) from public.listing_applications a
      where a.listing_id = l.id)::int,
    exists (select 1 from public.listing_applications a
             where a.listing_id = l.id and a.applicant_id = auth.uid()),
    (l.owner_id = auth.uid()
     or (l.club_id is not null and public.is_club_staff(l.club_id))),
    l.created_at
  from public.listings l
  left join public.clubs c on c.id = l.club_id
  join public.profiles p on p.id = l.owner_id
  left join public.sports s on s.code = l.sport_code
  left join public.cities ct on ct.code = l.city_code
  where l.status = 'open'
    and (l.deadline is null or l.deadline >= current_date)
    and (p_kind is null or l.kind = p_kind)
    and (p_sport is null or l.sport_code = p_sport)
    and (p_city is null or l.city_code = p_city)
    and (p_district is null or trim(p_district) = ''
         or l.district ilike '%' || p_district || '%')
    and (p_level is null or coalesce(l.coach_level_min, 0) <= p_level)
    and (p_query is null or trim(p_query) = ''
         or l.title ilike '%' || p_query || '%'
         or l.body ilike '%' || p_query || '%')
    -- "Doğrulanmış" filtresi: kulüp ilanında kulüp onaylı, kişi ilanında
    -- kişinin onaylı bir kimliği olmalı.
    and (not p_verified
         or (l.club_id is not null and c.status = 'active')
         or (l.club_id is null and exists (
               select 1 from public.profile_credentials pc
                where pc.profile_id = l.owner_id and pc.status = 'approved')))
  order by l.created_at desc
  limit greatest(p_limit, 1);
$$;


-- ---------------------------------------------------------------------------
-- Başvuru
-- ---------------------------------------------------------------------------
create or replace function public.apply_to_listing(
  p_listing uuid, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_row record;
  v_id  uuid;
  v_name text;
begin
  select * into v_row from public.listings where id = p_listing;
  if v_row is null then raise exception 'İlan bulunamadı'; end if;
  if v_row.status <> 'open' then raise exception 'İlan kapanmış'; end if;
  if v_row.owner_id = auth.uid() then
    raise exception 'Kendi ilanına başvuramazsın';
  end if;

  insert into public.listing_applications (listing_id, applicant_id, note)
  values (p_listing, auth.uid(), p_note)
  on conflict (listing_id, applicant_id) do update set note = excluded.note
  returning id into v_id;

  select full_name into v_name from public.profiles where id = auth.uid();

  -- İlan sahibine haber ver.
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (v_row.owner_id, 'application',
          'İlanına başvuru geldi',
          coalesce(v_name, 'Bir kullanıcı') || ' · ' || v_row.title,
          auth.uid(), 'listing', p_listing);

  return v_id;
end; $$;


create or replace function public.review_listing_application(
  p_application uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_app  record;
  v_list record;
begin
  select * into v_app from public.listing_applications where id = p_application;
  if v_app is null then raise exception 'Başvuru bulunamadı'; end if;

  select * into v_list from public.listings where id = v_app.listing_id;
  if not (v_list.owner_id = auth.uid()
          or (v_list.club_id is not null and public.is_club_staff(v_list.club_id))) then
    raise exception 'Yetkisiz';
  end if;

  update public.listing_applications
     set status = case when p_accept then 'accepted' else 'rejected' end,
         reviewed_by = auth.uid(), reviewed_at = now()
   where id = p_application;

  -- Başvurana sonucu bildir. Kabul edildiyse üyelik akışı kulüp tarafından
  -- yürütülür (mevcut teklif/başvuru sistemi) — burada ikinci bir üyelik
  -- mekanizması kurulmuyor.
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (v_app.applicant_id, 'application',
          case when p_accept then 'Başvurun kabul edildi'
               else 'Başvurun olumsuz sonuçlandı' end,
          v_list.title, auth.uid(), 'listing', v_list.id);
end; $$;


-- İlana gelen başvurular (ilan sahibi için).
create or replace function public.listing_applicants(p_listing uuid)
returns table (
  id uuid, applicant_id uuid, name text, username text, avatar_path text,
  credentials text, city_name text, note text, status text,
  created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select a.id, a.applicant_id, p.full_name, p.username, p.avatar_path,
         (select string_agg(
                   case when c.kind = 'coach'
                        then coalesce(s.name || ' · ','') ||
                             coalesce(c.coach_level::text,'?') || '. Kademe'
                        else 'Sporcu' end, ', ')
            from public.profile_credentials c
            left join public.sports s on s.code = c.sport_code
           where c.profile_id = p.id and c.status = 'approved'),
         ct.name, a.note, a.status, a.created_at
    from public.listing_applications a
    join public.profiles p on p.id = a.applicant_id
    left join public.cities ct on ct.code = p.city_code
    join public.listings l on l.id = a.listing_id
   where a.listing_id = p_listing
     and (l.owner_id = auth.uid()
          or (l.club_id is not null and public.is_club_staff(l.club_id)))
   order by a.created_at;
$$;


-- Kişinin kendi ilanları ve başvuruları.
create or replace function public.my_listings()
returns table (
  id uuid, kind text, title text, status text,
  application_count int, pending_count int, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select l.id, l.kind, l.title, l.status,
         (select count(*) from public.listing_applications a
           where a.listing_id = l.id)::int,
         (select count(*) from public.listing_applications a
           where a.listing_id = l.id and a.status = 'pending')::int,
         l.created_at
    from public.listings l
   where l.owner_id = auth.uid()
      or (l.club_id is not null and public.is_club_staff(l.club_id))
   order by l.created_at desc;
$$;


-- ##########################################################################
-- Faz 4-5 — Belge kasası, veli, bildirim tercihleri
-- ##########################################################################

-- =============================================================================
-- SwanSport — FAZ 4 & 5: BELGE KASASI, VELİ DENEYİMİ, BİLDİRİM TERCİHLERİ
--
-- Belge tarafında ikinci bir sistem kurulmuyor: mevcut `documents` tablosu
-- genişletiliyor. `verification_documents` (kimlik başvurusu ekleri) olduğu
-- gibi kalıyor — o farklı bir iş yapıyor, karıştırılmamalı.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) BELGE KASASI
--
-- Eskiden yalnızca isim ve tür tutuluyordu; dosyanın kendisi yoktu.
-- Artık sahibi (kulüp / sporcu / kişi), dosya yolu, geçerlilik tarihi ve
-- doğrulama durumu var.
-- ---------------------------------------------------------------------------
alter table public.documents
  add column if not exists owner_type   text not null default 'club', -- club | athlete | person
  add column if not exists owner_id     uuid,
  add column if not exists doc_type     text,   -- lisans | saglik | kademe | tescil | sertifika | diger
  add column if not exists storage_path text,
  add column if not exists issued_on    date,
  add column if not exists expires_on   date,
  add column if not exists verified     boolean not null default false,
  add column if not exists verified_by  uuid references public.profiles(id) on delete set null,
  add column if not exists note         text,
  add column if not exists uploaded_by  uuid references public.profiles(id) on delete set null;

-- Eski kayıtların sahibi kulüptür.
update public.documents
   set owner_id = club_id
 where owner_id is null;

create index if not exists idx_doc_owner
  on public.documents (owner_type, owner_id);
create index if not exists idx_doc_expiry
  on public.documents (expires_on) where expires_on is not null;


-- Bu belgeyi kim görebilir?
--   • Kulüp belgesi → kulüp görevlisi
--   • Sporcu belgesi → kulüp görevlisi, sporcunun kendisi, velisi
--   • Kişisel belge → yalnızca sahibi
create or replace function public.can_view_document(
  p_owner_type text, p_owner_id uuid, p_club uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case p_owner_type
    when 'club'    then public.is_club_staff(p_club)
    when 'athlete' then public.can_view_athlete_fees(p_owner_id)
                        or public.is_club_staff(p_club)
    when 'person'  then p_owner_id = auth.uid() or public.is_platform_admin()
    else false
  end;
$$;

drop policy if exists "documents_read" on public.documents;
create policy "documents_read" on public.documents for select
  to authenticated
  using (public.can_view_document(owner_type, owner_id, club_id));


create or replace function public.add_document(
  p_club       uuid,
  p_name       text,
  p_owner_type text default 'club',
  p_owner_id   uuid default null,
  p_doc_type   text default null,
  p_path       text default null,
  p_issued     date default null,
  p_expires    date default null,
  p_size       text default null,
  p_note       text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_owner uuid;
begin
  v_owner := coalesce(p_owner_id,
                      case when p_owner_type = 'person' then auth.uid()
                           else p_club end);

  -- Yükleme yetkisi: kulüp/sporcu belgesi kulüp görevlisinden ya da
  -- sporcunun kendisinden/velisinden; kişisel belge yalnızca sahibinden.
  if p_owner_type = 'person' then
    if v_owner <> auth.uid() then raise exception 'Yetkisiz'; end if;
  elsif p_owner_type = 'athlete' then
    if not (public.can_view_athlete_fees(v_owner) or public.is_club_staff(p_club)) then
      raise exception 'Yetkisiz';
    end if;
  else
    if not public.is_club_staff(p_club) then raise exception 'Yetkisiz'; end if;
  end if;

  insert into public.documents
    (club_id, name, kind, size_label, owner_type, owner_id, doc_type,
     storage_path, issued_on, expires_on, note, uploaded_by)
  values (p_club, p_name, coalesce(p_doc_type, 'file'), p_size,
          p_owner_type, v_owner, p_doc_type, p_path, p_issued, p_expires,
          p_note, auth.uid())
  returning id into v_id;

  return v_id;
end; $$;


create or replace function public.verify_document(
  p_document uuid, p_verified boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare v_row record;
begin
  select * into v_row from public.documents where id = p_document;
  if v_row is null then raise exception 'Belge bulunamadı'; end if;
  if not (public.is_platform_admin() or public.is_club_staff(v_row.club_id)) then
    raise exception 'Yetkisiz';
  end if;

  update public.documents
     set verified = p_verified,
         verified_by = case when p_verified then auth.uid() else null end
   where id = p_document;
end; $$;


-- Belge listesi — süre durumu hesaplanmış olarak döner.
create or replace function public.document_list(
  p_club uuid, p_owner_type text default null, p_owner_id uuid default null)
returns table (
  id uuid, name text, doc_type text, storage_path text,
  owner_type text, owner_id uuid, owner_name text,
  issued_on date, expires_on date, verified boolean,
  days_left int, state text, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    d.id, d.name, d.doc_type, d.storage_path,
    d.owner_type, d.owner_id,
    case d.owner_type
      when 'athlete' then (select trim(coalesce(a.first_name,'')||' '||coalesce(a.last_name,''))
                             from public.athletes a where a.id = d.owner_id)
      when 'person'  then (select p.full_name from public.profiles p where p.id = d.owner_id)
      else (select c.name from public.clubs c where c.id = d.owner_id)
    end,
    d.issued_on, d.expires_on, d.verified,
    case when d.expires_on is null then null
         else (d.expires_on - current_date) end,
    case when d.expires_on is null then 'süresiz'
         when d.expires_on < current_date then 'süresi doldu'
         when d.expires_on <= current_date + 30 then 'yakında doluyor'
         else 'geçerli' end,
    d.created_at
  from public.documents d
  where d.club_id = p_club
    and (p_owner_type is null or d.owner_type = p_owner_type)
    and (p_owner_id is null or d.owner_id = p_owner_id)
    and public.can_view_document(d.owner_type, d.owner_id, d.club_id)
  order by (d.expires_on is not null and d.expires_on < current_date) desc,
           d.expires_on nulls last, d.created_at desc;
$$;


-- Süresi dolan belgeler için hatırlatma. Mevcut hatırlatma altyapısına
-- (reminder_log + notifications + push) bağlanır; yeni bir kanal kurulmaz.
create or replace function public.send_document_expiry_reminders()
returns int
language plpgsql security definer set search_path = public as $$
declare v_n int := 0;
begin
  with soon as (
    select d.id, d.name, d.expires_on, d.club_id, d.owner_type, d.owner_id
      from public.documents d
     where d.expires_on in (current_date + 30, current_date + 7, current_date)
  ),
  targets as (
    -- Kulüp belgeleri → kulüp yöneticileri
    select s.id as doc_id, m.profile_id, s.name, s.expires_on
      from soon s
      join public.club_memberships m
        on m.club_id = s.club_id and m.status = 'active'
       and m.role in ('club_admin', 'official')
     where s.owner_type = 'club'
    union
    -- Sporcu belgeleri → sporcu ve velisi
    select s.id, a.profile_id, s.name, s.expires_on
      from soon s
      join public.athletes a on a.id = s.owner_id
     where s.owner_type = 'athlete' and a.profile_id is not null
    union
    select s.id, g.profile_id, s.name, s.expires_on
      from soon s
      join public.guardians g on g.athlete_id = s.owner_id
     where s.owner_type = 'athlete' and g.profile_id is not null
    union
    -- Kişisel belgeler → sahibi
    select s.id, s.owner_id, s.name, s.expires_on
      from soon s
     where s.owner_type = 'person' and s.owner_id is not null
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'document', t.doc_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'document_expiry',
           case when t.expires_on = current_date then 'Belgenin süresi bugün doluyor'
                else 'Belge süresi yaklaşıyor' end,
           t.name || ' · son gün ' || to_char(t.expires_on, 'DD.MM.YYYY'),
           'document', f.entity_id
      from fresh f
      join targets t on t.doc_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;
  return v_n;
end; $$;

do $$ begin perform cron.unschedule('swansport_document_reminders');
exception when others then null; end $$;

select cron.schedule(
  'swansport_document_reminders', '30 6 * * *',
  $$select public.send_document_expiry_reminders();$$);


-- ---------------------------------------------------------------------------
-- 2) VELİ DENEYİMİ
--
-- Veri modeli çoklu çocuğu zaten destekliyordu; eksik olan, çocukların farklı
-- kulüplerde olabildiği durumdu. Uygulama tek "aktif kulüp" varsayıyordu.
-- Bu çağrı her çocuğu kendi kulübüyle birlikte döndürür.
-- ---------------------------------------------------------------------------
create or replace function public.my_children_overview()
returns table (
  athlete_id     uuid,
  full_name      text,
  club_id        uuid,
  club_name      text,
  branch         text,
  attendance_rate int,
  open_fee_count int,
  open_fee_total numeric,
  next_event_at  timestamptz,
  next_event     text,
  health_status  text
)
language sql stable security definer set search_path = public as $$
  select
    a.id,
    trim(coalesce(a.first_name,'') || ' ' || coalesce(a.last_name,'')),
    a.club_id, c.name, a.branch,
    coalesce((
      select round(100.0 * count(*) filter (where at.status = 'present')
                   / nullif(count(*), 0))::int
        from public.attendance at where at.athlete_id = a.id), 0),
    (select count(*) from public.invoices i
      where i.athlete_id = a.id and i.status <> 'paid')::int,
    coalesce((select sum(i.amount) from public.invoices i
      where i.athlete_id = a.id and i.status <> 'paid'), 0),
    (select e.starts_at from public.events e
      where e.club_id = a.club_id and e.starts_at >= now()
      order by e.starts_at limit 1),
    (select e.title from public.events e
      where e.club_id = a.club_id and e.starts_at >= now()
      order by e.starts_at limit 1),
    coalesce((select inj.status::text from public.injuries inj
      where inj.athlete_id = a.id
      order by inj.created_at desc limit 1), 'fit')
  from public.athletes a
  left join public.clubs c on c.id = a.club_id
  where public.can_view_athlete_fees(a.id)
  -- NOT: SQL fonksiyonlarında ORDER BY çıktı sütun adına bakamaz; ifadenin
  -- kendisi tekrarlanmalı.
  order by trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, ''));
$$;


-- ---------------------------------------------------------------------------
-- 3) BİLDİRİM KATEGORİLERİ VE TERCİHLER
--
-- Tasarım ilkesi: kullanıcı bildirim bombardımanına tutulmamalı. Türler yedi
-- kategoriye indirildi; kullanıcı istemediği kategoriyi kapatabiliyor.
-- ---------------------------------------------------------------------------
create or replace function public.notification_category(p_kind text)
returns text language sql immutable as $$
  select case p_kind
    when 'fee_reminder'        then 'aidat'
    when 'payment'             then 'aidat'
    when 'attendance_reminder' then 'antrenman'
    when 'announcement'        then 'federasyon'
    when 'application'         then 'kulup'
    when 'offer'               then 'kulup'
    when 'review'              then 'kritik'
    when 'document_expiry'     then 'kritik'
    when 'donation'            then 'kulup'
    when 'message'             then 'sosyal'
    when 'like'                then 'sosyal'
    when 'comment'             then 'sosyal'
    when 'follow'              then 'sosyal'
    else 'sosyal'
  end;
$$;


create table if not exists public.notification_prefs (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  category   text not null,
  enabled    boolean not null default true,
  primary key (profile_id, category)
);

alter table public.notification_prefs enable row level security;

drop policy if exists "notif_pref_own" on public.notification_prefs;
create policy "notif_pref_own" on public.notification_prefs for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());


-- Kapatılan kategoriye telefon bildirimi gönderilmez.
-- Not: uygulama içi listede yine görünür — kullanıcı isterse bakar, ama
-- telefonu titremez. "Kapat" demek "sil" demek değildir.
create or replace function public.push_allowed(p_profile uuid, p_kind text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select np.enabled from public.notification_prefs np
      where np.profile_id = p_profile
        and np.category = public.notification_category(p_kind)),
    true);
$$;


-- Push tetikleyicisi tercihleri gözetsin.
create or replace function public.push_on_notification()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_subs jsonb;
begin
  if not public.push_allowed(new.profile_id, new.kind) then
    return new;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth)), '[]'::jsonb)
    into v_subs
    from public.push_subscriptions s
   where s.profile_id = new.profile_id;

  if jsonb_array_length(v_subs) = 0 then
    return new;
  end if;

  perform net.http_post(
    url     := 'https://swansport.pages.dev/api/push',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-push-secret', '9958f52564494dea1a2234c511d9948ad0a6f113cfaf68e3'),
    body    := jsonb_build_object(
                 'title', new.title,
                 'body',  coalesce(new.body, ''),
                 'url',   public.push_route(new.kind, new.entity_type),
                 'subs',  v_subs)
  );

  return new;
exception
  when others then return new;
end; $$;


-- Bildirim listesi — kategoriyle birlikte.
create or replace function public.my_notifications(
  p_category text default null, p_limit int default 60)
returns table (
  id uuid, kind text, category text, title text, body text,
  actor_id uuid, entity_type text, entity_id uuid,
  read_at timestamptz, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select n.id, n.kind, public.notification_category(n.kind), n.title, n.body,
         n.actor_id, n.entity_type, n.entity_id, n.read_at, n.created_at
    from public.notifications n
   where n.profile_id = auth.uid()
     and (p_category is null or p_category = ''
          or public.notification_category(n.kind) = p_category)
   order by n.created_at desc
   limit greatest(p_limit, 1);
$$;


create or replace function public.set_notification_pref(
  p_category text, p_enabled boolean)
returns void language sql security definer set search_path = public as $$
  insert into public.notification_prefs (profile_id, category, enabled)
  values (auth.uid(), p_category, p_enabled)
  on conflict (profile_id, category) do update set enabled = excluded.enabled;
$$;


create or replace function public.my_notification_prefs()
returns table (category text, enabled boolean)
language sql stable security definer set search_path = public as $$
  select c.category,
         coalesce((select np.enabled from public.notification_prefs np
                    where np.profile_id = auth.uid()
                      and np.category = c.category), true)
    from (values ('kritik'), ('kulup'), ('antrenman'), ('musabaka'),
                 ('aidat'), ('federasyon'), ('sosyal')) as c(category);
$$;


-- ##########################################################################
-- Faz 6-7 — Lig/turnuva, kulüp mesajı, etkinlik başvurusu
-- ##########################################################################

-- =============================================================================
-- SwanSport — FAZ 6 & 7: ORGANİZASYONLAR, KULÜP MESAJI, ETKİNLİK BAŞVURUSU
--
-- Turnuva/lig tek bir spor dalına göre kurgulanmadı: puan sistemi ve eleme
-- yapısı organizasyonun kendi ayarlarından gelir. Maçlar mevcut `events`
-- tablosuna da yazılabilir — takvim ikinci kez yazılmıyor.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) ORGANİZASYON
-- ---------------------------------------------------------------------------
create table if not exists public.organizations (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid references public.clubs(id) on delete cascade,  -- düzenleyen
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  name        text not null,
  kind        text not null default 'league',   -- league | tournament | cup
  sport_code  text references public.sports(code),
  city_code   text references public.cities(code),
  district    text,
  age_group   text,                              -- "U-16", "Büyükler"
  starts_on   date,
  ends_on     date,
  location    text,
  description text,
  -- Puan kuralı branşa göre değişir (voleybolda 3-2-1-0, futbolda 3-1-0).
  win_points  int not null default 3,
  draw_points int not null default 1,
  loss_points int not null default 0,
  is_public   boolean not null default true,
  status      text not null default 'open',     -- open | running | finished
  created_at  timestamptz not null default now()
);

create index if not exists idx_org_public
  on public.organizations (is_public, status, starts_on desc);

alter table public.organizations enable row level security;

drop policy if exists "org_read" on public.organizations;
create policy "org_read" on public.organizations for select
  to authenticated
  using (is_public or owner_id = auth.uid()
         or (club_id is not null and public.is_club_member(club_id)));


-- Katılımcı: bir kulüp takımı ya da serbest isim (dışarıdan katılan takım).
create table if not exists public.org_participants (
  id       uuid primary key default gen_random_uuid(),
  org_id   uuid not null references public.organizations(id) on delete cascade,
  club_id  uuid references public.clubs(id) on delete set null,
  team_id  uuid references public.teams(id) on delete set null,
  name     text not null,
  status   text not null default 'accepted',   -- pending | accepted | rejected
  created_at timestamptz not null default now()
);

create index if not exists idx_org_part on public.org_participants (org_id, status);

alter table public.org_participants enable row level security;

drop policy if exists "org_part_read" on public.org_participants;
create policy "org_part_read" on public.org_participants for select
  to authenticated using (true);


-- Maç. `event_id` doluysa aynı maç kulübün takviminde de görünür.
create table if not exists public.org_matches (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations(id) on delete cascade,
  round      int,
  home_id    uuid references public.org_participants(id) on delete cascade,
  away_id    uuid references public.org_participants(id) on delete cascade,
  starts_at  timestamptz,
  location   text,
  home_score int,
  away_score int,
  status     text not null default 'scheduled',  -- scheduled | played | cancelled
  event_id   uuid references public.events(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_org_match on public.org_matches (org_id, round, starts_at);

alter table public.org_matches enable row level security;

drop policy if exists "org_match_read" on public.org_matches;
create policy "org_match_read" on public.org_matches for select
  to authenticated using (true);


-- Düzenleyici mi?
create or replace function public.is_org_owner(p_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organizations o
     where o.id = p_org
       and (o.owner_id = auth.uid()
            or (o.club_id is not null and public.is_club_staff(o.club_id)))
  );
$$;


create or replace function public.create_organization(
  p_name text, p_kind text default 'league', p_club uuid default null,
  p_sport text default null, p_city text default null, p_district text default null,
  p_age text default null, p_starts date default null, p_ends date default null,
  p_location text default null, p_description text default null,
  p_win int default 3, p_draw int default 1, p_loss int default 0)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;
  if p_club is not null and not public.is_club_staff(p_club) then
    raise exception 'Bu kulüp adına organizasyon açamazsın';
  end if;

  insert into public.organizations
    (club_id, owner_id, name, kind, sport_code, city_code, district, age_group,
     starts_on, ends_on, location, description, win_points, draw_points, loss_points)
  values (p_club, auth.uid(), p_name, p_kind, p_sport, p_city, p_district, p_age,
          p_starts, p_ends, p_location, p_description, p_win, p_draw, p_loss)
  returning id into v_id;

  return v_id;
end; $$;


-- Katılım başvurusu: kulüp kendi takımıyla katılmak ister.
create or replace function public.join_organization(
  p_org uuid, p_club uuid default null, p_team uuid default null,
  p_name text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text;
begin
  if p_club is not null and not public.is_club_staff(p_club) then
    raise exception 'Yetkisiz';
  end if;

  v_name := coalesce(nullif(p_name, ''),
                     (select t.name from public.teams t where t.id = p_team),
                     (select c.name from public.clubs c where c.id = p_club),
                     'Katılımcı');

  insert into public.org_participants (org_id, club_id, team_id, name, status)
  values (p_org, p_club, p_team, v_name,
          case when public.is_org_owner(p_org) then 'accepted' else 'pending' end)
  returning id into v_id;

  return v_id;
end; $$;


create or replace function public.review_participant(
  p_participant uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_org uuid;
begin
  select org_id into v_org from public.org_participants where id = p_participant;
  if not public.is_org_owner(v_org) then raise exception 'Yetkisiz'; end if;

  update public.org_participants
     set status = case when p_accept then 'accepted' else 'rejected' end
   where id = p_participant;
end; $$;


-- ---------------------------------------------------------------------------
-- 2) FİKSTÜR
--
-- Tek devreli lig fikstürü (round-robin). Tek sayıda takım varsa her turda
-- biri bay geçer — o tur için maç üretilmez.
-- ---------------------------------------------------------------------------
create or replace function public.generate_fixture(
  p_org uuid, p_start date default null, p_days_between int default 7)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_ids   uuid[];
  v_n     int;
  v_round int;
  v_i     int;
  v_home  uuid;
  v_away  uuid;
  v_count int := 0;
  v_date  date;
begin
  if not public.is_org_owner(p_org) then raise exception 'Yetkisiz'; end if;

  select array_agg(id order by created_at) into v_ids
    from public.org_participants
   where org_id = p_org and status = 'accepted';

  v_n := coalesce(array_length(v_ids, 1), 0);
  if v_n < 2 then raise exception 'En az iki katılımcı gerekiyor'; end if;

  -- Var olan fikstürü temizle (yalnızca oynanmamışları).
  delete from public.org_matches
   where org_id = p_org and status = 'scheduled';

  -- Tek sayıdaysa bir "boş" yer eklenir; o eşleşme atlanır.
  if v_n % 2 = 1 then
    v_ids := v_ids || array[null::uuid];
    v_n := v_n + 1;
  end if;

  v_date := coalesce(p_start, current_date + 7);

  for v_round in 1..(v_n - 1) loop
    for v_i in 1..(v_n / 2) loop
      v_home := v_ids[v_i];
      v_away := v_ids[v_n + 1 - v_i];

      if v_home is not null and v_away is not null then
        insert into public.org_matches
          (org_id, round, home_id, away_id, starts_at)
        values (p_org, v_round, v_home, v_away,
                (v_date + (v_round - 1) * p_days_between)::timestamptz
                  + interval '18 hours');
        v_count := v_count + 1;
      end if;
    end loop;

    -- Berger dönüşü: ilk takım sabit, diğerleri saat yönünde kayar.
    v_ids := array[v_ids[1]] || array[v_ids[v_n]] ||
             v_ids[2:v_n - 1];
  end loop;

  update public.organizations set status = 'running' where id = p_org;
  return v_count;
end; $$;


create or replace function public.set_match_result(
  p_match uuid, p_home int, p_away int)
returns void language plpgsql security definer set search_path = public as $$
declare v_org uuid;
begin
  select org_id into v_org from public.org_matches where id = p_match;
  if not public.is_org_owner(v_org) then raise exception 'Yetkisiz'; end if;

  update public.org_matches
     set home_score = p_home, away_score = p_away, status = 'played'
   where id = p_match;
end; $$;


-- ---------------------------------------------------------------------------
-- 3) PUAN DURUMU
--
-- Puanlar organizasyonun kendi kuralından hesaplanır; hiçbir branş
-- sabitlenmiyor.
-- ---------------------------------------------------------------------------
create or replace function public.org_standings(p_org uuid)
returns table (
  participant_id uuid, name text, club_id uuid,
  played int, won int, drawn int, lost int,
  scored int, conceded int, diff int, points int
)
language sql stable security definer set search_path = public as $$
  with cfg as (select win_points w, draw_points d, loss_points l
                 from public.organizations where id = p_org),
  games as (
    select m.home_id as pid, m.home_score as gf, m.away_score as ga
      from public.org_matches m
     where m.org_id = p_org and m.status = 'played'
       and m.home_score is not null and m.away_score is not null
    union all
    select m.away_id, m.away_score, m.home_score
      from public.org_matches m
     where m.org_id = p_org and m.status = 'played'
       and m.home_score is not null and m.away_score is not null
  ),
  agg as (
    select g.pid,
           count(*)::int as played,
           count(*) filter (where g.gf > g.ga)::int as won,
           count(*) filter (where g.gf = g.ga)::int as drawn,
           count(*) filter (where g.gf < g.ga)::int as lost,
           coalesce(sum(g.gf), 0)::int as scored,
           coalesce(sum(g.ga), 0)::int as conceded
      from games g group by g.pid
  )
  select p.id, p.name, p.club_id,
         coalesce(a.played, 0), coalesce(a.won, 0), coalesce(a.drawn, 0),
         coalesce(a.lost, 0), coalesce(a.scored, 0), coalesce(a.conceded, 0),
         coalesce(a.scored, 0) - coalesce(a.conceded, 0),
         (coalesce(a.won,0) * (select w from cfg)
          + coalesce(a.drawn,0) * (select d from cfg)
          + coalesce(a.lost,0) * (select l from cfg))::int
    from public.org_participants p
    left join agg a on a.pid = p.id
   where p.org_id = p_org and p.status = 'accepted'
   -- Sıralama: puan (11), averaj (10), atılan (8). Çıktı 11 sütun.
   order by 11 desc, 10 desc, 8 desc, p.name;
$$;


-- Organizasyon listesi (keşif için) ve fikstür.
create or replace function public.list_organizations(
  p_sport text default null, p_city text default null,
  p_kind text default null, p_limit int default 40)
returns table (
  id uuid, name text, kind text, sport_name text, city_name text,
  age_group text, starts_on date, ends_on date, status text,
  club_id uuid, club_name text, participant_count int, can_manage boolean
)
language sql stable security definer set search_path = public as $$
  select o.id, o.name, o.kind, s.name, ct.name, o.age_group,
         o.starts_on, o.ends_on, o.status, o.club_id, c.name,
         (select count(*) from public.org_participants p
           where p.org_id = o.id and p.status = 'accepted')::int,
         public.is_org_owner(o.id)
    from public.organizations o
    left join public.sports s on s.code = o.sport_code
    left join public.cities ct on ct.code = o.city_code
    left join public.clubs c on c.id = o.club_id
   where (o.is_public or public.is_org_owner(o.id))
     and (p_sport is null or o.sport_code = p_sport)
     and (p_city is null or o.city_code = p_city)
     and (p_kind is null or o.kind = p_kind)
   order by (o.status <> 'finished') desc, o.starts_on desc nulls last
   limit greatest(p_limit, 1);
$$;


create or replace function public.org_fixture(p_org uuid)
returns table (
  id uuid, round int, starts_at timestamptz, status text,
  home_id uuid, home_name text, away_id uuid, away_name text,
  home_score int, away_score int, can_manage boolean
)
language sql stable security definer set search_path = public as $$
  select m.id, m.round, m.starts_at, m.status,
         m.home_id, h.name, m.away_id, a.name,
         m.home_score, m.away_score, public.is_org_owner(m.org_id)
    from public.org_matches m
    left join public.org_participants h on h.id = m.home_id
    left join public.org_participants a on a.id = m.away_id
   where m.org_id = p_org
   order by m.round, m.starts_at;
$$;


-- ---------------------------------------------------------------------------
-- 4) KULÜP ADINA MESAJ
--
-- İkinci bir mesajlaşma sistemi kurulmuyor: mevcut birebir mesajlaşmaya
-- "gönderen kulüp" bilgisi ekleniyor. Kulüpler arası yazışma da bu kanaldan
-- yürür — alıcı, karşı kulübün yetkilisidir.
-- ---------------------------------------------------------------------------
alter table public.direct_messages
  add column if not exists sender_club_id uuid references public.clubs(id) on delete set null;


create or replace function public.send_club_message(
  p_club uuid, p_recipient uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Bu kulüp adına mesaj gönderemezsin';
  end if;
  if p_body is null or trim(p_body) = '' then
    raise exception 'Boş mesaj';
  end if;

  insert into public.direct_messages (sender_id, recipient_id, body, sender_club_id)
  values (auth.uid(), p_recipient, trim(p_body), p_club)
  returning id into v_id;

  select name into v_name from public.clubs where id = p_club;

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (p_recipient, 'message', v_name || ' size yazdı',
          left(trim(p_body), 120), auth.uid(), 'message', v_id);

  return v_id;
end; $$;


-- ---------------------------------------------------------------------------
-- 5) ETKİNLİK BAŞVURUSU (eğitim / seminer / kamp)
--
-- Yeni bir etkinlik tablosu açılmıyor: mevcut `events` herkese açık hale
-- getirilebiliyor ve kontenjan tutabiliyor.
-- ---------------------------------------------------------------------------
alter table public.events
  add column if not exists is_public   boolean not null default false,
  add column if not exists capacity    int,
  add column if not exists reg_deadline date,
  add column if not exists description text;

create table if not exists public.event_registrations (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  note       text,
  status     text not null default 'registered', -- registered | cancelled
  created_at timestamptz not null default now(),
  unique (event_id, profile_id)
);

alter table public.event_registrations enable row level security;

drop policy if exists "event_reg_read" on public.event_registrations;
create policy "event_reg_read" on public.event_registrations for select
  to authenticated
  using (profile_id = auth.uid()
         or exists (select 1 from public.events e
                     where e.id = event_id and public.is_club_staff(e.club_id)));


create or replace function public.register_for_event(
  p_event uuid, p_note text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_e record; v_taken int; v_id uuid;
begin
  select * into v_e from public.events where id = p_event;
  if v_e is null then raise exception 'Etkinlik bulunamadı'; end if;
  if not v_e.is_public then raise exception 'Bu etkinlik başvuruya açık değil'; end if;
  if v_e.reg_deadline is not null and v_e.reg_deadline < current_date then
    raise exception 'Başvuru süresi doldu';
  end if;

  if v_e.capacity is not null then
    select count(*) into v_taken from public.event_registrations
     where event_id = p_event and status = 'registered';
    if v_taken >= v_e.capacity then raise exception 'Kontenjan dolu'; end if;
  end if;

  insert into public.event_registrations (event_id, profile_id, note)
  values (p_event, auth.uid(), p_note)
  on conflict (event_id, profile_id) do update
    set status = 'registered', note = excluded.note
  returning id into v_id;

  return v_id;
end; $$;


create or replace function public.public_events(
  p_sport text default null, p_city text default null, p_limit int default 40)
returns table (
  id uuid, title text, kind text, description text,
  starts_at timestamptz, place text, club_id uuid, club_name text,
  city text, capacity int, taken int, reg_deadline date, registered boolean
)
language sql stable security definer set search_path = public as $$
  select e.id, e.title, e.kind::text, e.description, e.starts_at, e.place,
         e.club_id, c.name, c.city, e.capacity,
         (select count(*) from public.event_registrations r
           where r.event_id = e.id and r.status = 'registered')::int,
         e.reg_deadline,
         exists (select 1 from public.event_registrations r
                  where r.event_id = e.id and r.profile_id = auth.uid()
                    and r.status = 'registered')
    from public.events e
    join public.clubs c on c.id = e.club_id
   where e.is_public
     and e.starts_at >= now()
     and (p_city is null or c.city ilike '%' || p_city || '%')
     and (p_sport is null or c.sport_code = p_sport)
   order by e.starts_at
   limit greatest(p_limit, 1);
$$;
