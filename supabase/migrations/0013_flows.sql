-- =============================================================================
-- SwanSport — YARIM AKIŞLARIN TAMAMLANMASI
--   1) Maç sonucu / skor
--   2) Kulüp profili (logo + biyografi) düzenleme yetkisi
--   3) Yoklama özeti
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) MAÇ SONUCU
-- ---------------------------------------------------------------------------
alter table public.events
  add column if not exists opponent    text,
  add column if not exists home_score  int,
  add column if not exists away_score  int,
  add column if not exists result_note text;


-- ---------------------------------------------------------------------------
-- 2) KULÜP PROFİLİ — yalnızca kulüp yöneticisi düzenler
--    (clubs.bio ve clubs.logo_path SOCIAL.sql ile eklenmişti)
-- ---------------------------------------------------------------------------
create or replace function public.update_club_profile(
  p_club uuid,
  p_bio  text default null,
  p_logo text default null,
  p_city text default null
)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_club_admin(p_club) then
    raise exception 'Kulüp profilini yalnızca yönetici düzenleyebilir';
  end if;

  update public.clubs
     set bio       = coalesce(nullif(p_bio, ''), bio),
         logo_path = coalesce(nullif(p_logo, ''), logo_path),
         city      = coalesce(nullif(p_city, ''), city)
   where id = p_club;
end; $$;


-- ---------------------------------------------------------------------------
-- 3) YOKLAMA ÖZETİ — sporcu bazında katılım oranı
-- ---------------------------------------------------------------------------
create or replace function public.attendance_summary(
  p_club uuid,
  p_days int default 90
)
returns table (
  athlete_id uuid,
  full_name  text,
  present    int,
  absent     int,
  excused    int,
  total      int,
  rate       int
)
language sql stable security definer set search_path = public as $$
  select
    a.id,
    (a.first_name || ' ' || coalesce(a.last_name, '')) as full_name,
    count(*) filter (where t.status = 'present')::int  as present,
    count(*) filter (where t.status = 'absent')::int   as absent,
    count(*) filter (where t.status = 'excused')::int  as excused,
    count(t.id)::int                                   as total,
    case when count(t.id) = 0 then 0
         else round(
           100.0 * count(*) filter (where t.status = 'present') / count(t.id)
         )::int
    end as rate
  from public.athletes a
  left join public.attendance t
    on t.athlete_id = a.id
   and t.taken_at > now() - make_interval(days => p_days)
  where a.club_id = p_club
    and public.is_club_staff(p_club)
  group by a.id, a.first_name, a.last_name
  order by rate desc, full_name;
$$;
