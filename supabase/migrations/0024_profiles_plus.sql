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
