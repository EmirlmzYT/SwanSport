-- =============================================================================
-- SwanSport — PLATFORM YÖNETİM PANELİ
--   1) Özet sayılar
--   2) Onayda düzeltme (kademe/branş) + gerekçeli ret
--   3) Kişi arama ve platform yöneticisi atama
--   4) İşlem geçmişi (kim, neyi, ne zaman onayladı)
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) ÖZET
--
-- Panelin tepesindeki sayılar. Tek çağrı: yönetici her açılışta on ayrı
-- sorgu beklemesin.
-- ---------------------------------------------------------------------------
create or replace function public.platform_stats()
returns table (
  people           int,
  clubs_active     int,
  clubs_pending    int,
  coaches          int,
  athletes         int,
  posts            int,
  creds_pending    int,
  reports_open     int
)
language sql stable security definer set search_path = public as $$
  select
    (select count(*) from public.profiles)::int,
    (select count(*) from public.clubs where status = 'active')::int,
    (select count(*) from public.clubs where status = 'pending')::int,
    (select count(distinct c.profile_id) from public.profile_credentials c
      where c.kind = 'coach' and c.status = 'approved')::int,
    (select count(*) from public.athletes)::int,
    (select count(*) from public.posts)::int,
    (select count(*) from public.profile_credentials
      where status = 'pending')::int,
    coalesce((select count(*) from public.content_reports
      where status = 'open'), 0)::int
  where public.is_platform_admin();
$$;


-- ---------------------------------------------------------------------------
-- 2) ONAYDA DÜZELTME
--
-- Belge, başvuruda yazılandan farklı çıkabiliyor (kişi 3. kademe yazmış ama
-- belge 2. kademe). Yöneticinin reddedip "yeniden başvur" demesi yerine
-- doğrusuyla onaylayabilmesi gerekiyor.
-- ---------------------------------------------------------------------------
drop function if exists public.review_credential(uuid, boolean, text);

create or replace function public.review_credential(
  p_cred        uuid,
  p_approve     boolean,
  p_note        text default null,
  p_coach_level int  default null,
  p_sport_code  text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;

  update public.profile_credentials
     set status = (case when p_approve then 'approved' else 'rejected' end)
                  ::public.verification_status,
         -- null gelirse başvurudaki değer korunur
         coach_level = coalesce(p_coach_level, coach_level),
         sport_code  = coalesce(p_sport_code, sport_code),
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         note        = p_note
   where id = p_cred;
end; $$;


-- Onaylı bir belgenin branşını sonradan atamak/düzeltmek için.
-- (Branş alanı sonradan eklendi; eski onaylı belgelerde boş.)
create or replace function public.set_credential_sport(
  p_cred uuid, p_sport_code text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;
  update public.profile_credentials
     set sport_code = p_sport_code
   where id = p_cred and kind = 'coach';
end; $$;


-- Branşı boş kalmış onaylı antrenör belgeleri — yönetici tek tek tamamlasın.
create or replace function public.credentials_without_sport()
returns table (
  id uuid, profile_id uuid, full_name text, coach_level int
)
language sql stable security definer set search_path = public as $$
  select c.id, c.profile_id, p.full_name, c.coach_level
    from public.profile_credentials c
    join public.profiles p on p.id = c.profile_id
   where c.kind = 'coach'
     and c.status = 'approved'
     and c.sport_code is null
     and public.is_platform_admin()
   order by p.full_name;
$$;


-- ---------------------------------------------------------------------------
-- 3) KİŞİ ARAMA VE YÖNETİCİ ATAMA
-- ---------------------------------------------------------------------------
create or replace function public.admin_search_people(p_query text)
returns table (
  id           uuid,
  full_name    text,
  username     text,
  city_name    text,
  is_admin     boolean,
  credentials  text,
  club_name    text
)
language sql stable security definer set search_path = public as $$
  select
    p.id,
    p.full_name,
    p.username,
    ct.name,
    p.is_platform_admin,
    (select string_agg(
              case when c.kind = 'coach'
                   then coalesce(s.name || ' · ', '') ||
                        coalesce(c.coach_level::text, '?') || '. Kademe'
                   else 'Sporcu' end, ', ')
       from public.profile_credentials c
       left join public.sports s on s.code = c.sport_code
      where c.profile_id = p.id and c.status = 'approved'),
    (select cl.name from public.club_memberships m
       join public.clubs cl on cl.id = m.club_id
      where m.profile_id = p.id and m.status = 'active'
      limit 1)
  from public.profiles p
  left join public.cities ct on ct.code = p.city_code
  where public.is_platform_admin()
    and (
      p_query is null or trim(p_query) = ''
      or p.full_name ilike '%' || p_query || '%'
      or p.username  ilike '%' || p_query || '%'
    )
  order by p.full_name
  limit 40;
$$;


create or replace function public.set_platform_admin(
  p_profile uuid, p_value boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;

  -- Son yöneticinin kendi yetkisini düşürüp paneli kilitlemesini engelle.
  if not p_value and p_profile = auth.uid()
     and (select count(*) from public.profiles
           where is_platform_admin) <= 1 then
    raise exception 'Tek yönetici kendi yetkisini kaldıramaz';
  end if;

  update public.profiles set is_platform_admin = p_value where id = p_profile;
end; $$;


-- ---------------------------------------------------------------------------
-- 4) İŞLEM GEÇMİŞİ
--
-- Kararlar geri alınamıyor; en azından kimin ne zaman ne yaptığı görünsün.
-- ---------------------------------------------------------------------------
create or replace function public.admin_recent_reviews(p_limit int default 40)
returns table (
  kind        text,      -- credential | club
  subject     text,      -- kişi ya da kulüp adı
  detail      text,
  approved    boolean,
  note        text,
  reviewer    text,
  reviewed_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select * from (
    select
      'credential'::text,
      p.full_name,
      case when c.kind = 'coach'
           then coalesce(s.name || ' · ', '') ||
                coalesce(c.coach_level::text, '?') || '. Kademe Antrenör'
           else 'Sporcu' end,
      c.status = 'approved',
      c.note,
      rp.full_name,
      c.reviewed_at
    from public.profile_credentials c
    join public.profiles p on p.id = c.profile_id
    left join public.profiles rp on rp.id = c.reviewed_by
    left join public.sports s on s.code = c.sport_code
    where c.reviewed_at is not null

    union all

    select
      'club'::text,
      cl.name,
      coalesce(cl.city, '—'),
      cl.status = 'active',
      cl.review_note,
      rp.full_name,
      cl.reviewed_at
    from public.clubs cl
    left join public.profiles rp on rp.id = cl.reviewed_by
    where cl.reviewed_at is not null
  ) t
  where public.is_platform_admin()
  order by 7 desc
  limit greatest(p_limit, 1);
$$;
