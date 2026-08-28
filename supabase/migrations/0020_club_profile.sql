-- =============================================================================
-- SwanSport — DETAYLI KULÜP PROFİLİ
--   1) Künye alanları (adres, iletişim, kuruluş, branş, sosyal hesaplar)
--   2) Kulüp başarıları
--   3) Tek çağrıda kulüp detayı + antrenör kadrosu
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) KÜNYE ALANLARI
--
-- Şehir zaten vardı; adres/iletişim ayrı tutuluyor çünkü şehir arama ve
-- topluluk eşleşmesinde kullanılıyor, adres ise yalnızca gösterim için.
-- ---------------------------------------------------------------------------
alter table public.clubs
  add column if not exists address      text,
  add column if not exists district     text,      -- ilçe
  add column if not exists phone        text,
  add column if not exists email        text,
  add column if not exists website      text,
  add column if not exists instagram    text,
  add column if not exists founded_year int,
  add column if not exists sport_code   text references public.sports(code);


-- ---------------------------------------------------------------------------
-- 2) BAŞARILAR
-- ---------------------------------------------------------------------------
create table if not exists public.club_achievements (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs(id) on delete cascade,
  title      text not null,               -- "Konya İl Şampiyonası"
  rank       text,                        -- "1." / "Şampiyon" / "Katılım"
  year       int,
  note       text,
  created_at timestamptz not null default now()
);
create index if not exists idx_club_ach
  on public.club_achievements (club_id, year desc);

alter table public.club_achievements enable row level security;

-- Başarılar kulüp sayfasının vitrini — herkes okur.
drop policy if exists "club_ach_read" on public.club_achievements;
create policy "club_ach_read" on public.club_achievements for select
  to authenticated using (true);

drop policy if exists "club_ach_write" on public.club_achievements;
create policy "club_ach_write" on public.club_achievements for all
  to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));


-- ---------------------------------------------------------------------------
-- 3) DÜZENLEME
-- ---------------------------------------------------------------------------
create or replace function public.update_club_details(
  p_club    uuid,
  p_address text default null,
  p_district text default null,
  p_phone   text default null,
  p_email   text default null,
  p_website text default null,
  p_instagram text default null,
  p_founded int default null,
  p_sport   text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_club_admin(p_club) then
    raise exception 'Yetkisiz';
  end if;

  -- Kural: null = dokunma, boş metin = alanı temizle.
  update public.clubs
     set address      = case when p_address   is null then address
                             when p_address   = ''   then null else p_address end,
         district     = case when p_district  is null then district
                             when p_district  = ''   then null else p_district end,
         phone        = case when p_phone     is null then phone
                             when p_phone     = ''   then null else p_phone end,
         email        = case when p_email     is null then email
                             when p_email     = ''   then null else p_email end,
         website      = case when p_website   is null then website
                             when p_website   = ''   then null else p_website end,
         instagram    = case when p_instagram is null then instagram
                             when p_instagram = ''   then null else p_instagram end,
         sport_code   = case when p_sport     is null then sport_code
                             when p_sport     = ''   then null else p_sport end,
         founded_year = coalesce(p_founded, founded_year)
   where id = p_club;
end; $$;


-- ---------------------------------------------------------------------------
-- 4) KULÜP DETAYI (tek çağrı)
--
-- Kulüp sayfası açılırken beş ayrı sorgu atılmasın diye künye, sayılar ve
-- yetki bilgisi birlikte döner.
-- ---------------------------------------------------------------------------
create or replace function public.club_details(p_club uuid)
returns table (
  id            uuid,
  name          text,
  short_name    text,
  bio           text,
  city          text,
  district      text,
  address       text,
  phone         text,
  email         text,
  website       text,
  instagram     text,
  founded_year  int,
  sport_name    text,
  status        text,
  logo_path     text,
  athlete_count int,
  coach_count   int,
  team_count    int,
  member_count  int,
  can_manage    boolean
)
language sql stable security definer set search_path = public as $$
  select
    c.id, c.name, c.short_name, c.bio, c.city, c.district, c.address,
    c.phone, c.email, c.website, c.instagram, c.founded_year,
    s.name, c.status::text, c.logo_path,
    (select count(*) from public.athletes a where a.club_id = c.id)::int,
    (select count(*) from public.club_memberships m
      where m.club_id = c.id and m.role = 'coach' and m.status = 'active')::int,
    (select count(*) from public.teams t where t.club_id = c.id)::int,
    (select count(*) from public.club_memberships m
      where m.club_id = c.id and m.status = 'active')::int,
    public.is_club_admin(c.id)
  from public.clubs c
  left join public.sports s on s.code = c.sport_code
  where c.id = p_club;
$$;


-- Antrenör kadrosu — kulüp sayfasında künyenin altında listelenir.
create or replace function public.club_coaches(p_club uuid)
returns table (
  profile_id  uuid,
  full_name   text,
  username    text,
  avatar_path text,
  coach_level int,
  role        text
)
language sql stable security definer set search_path = public as $$
  select
    p.id, p.full_name, p.username, p.avatar_path,
    coalesce(m.coach_level,
             (select c.coach_level from public.profile_credentials c
               where c.profile_id = p.id and c.kind = 'coach'
                 and c.status = 'approved'
               order by c.coach_level desc nulls last limit 1)),
    m.role::text
  from public.club_memberships m
  join public.profiles p on p.id = m.profile_id
  where m.club_id = p_club
    and m.status = 'active'
    and m.role in ('club_admin', 'coach')
  order by (m.role = 'club_admin') desc, m.coach_level desc nulls last,
           p.full_name;
$$;


-- Başarı listesi.
create or replace function public.club_achievement_list(p_club uuid)
returns table (
  id uuid, title text, rank text, year int, note text, can_manage boolean
)
language sql stable security definer set search_path = public as $$
  select a.id, a.title, a.rank, a.year, a.note, public.is_club_staff(a.club_id)
    from public.club_achievements a
   where a.club_id = p_club
   order by a.year desc nulls last, a.created_at desc;
$$;
