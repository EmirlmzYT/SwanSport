-- =============================================================================
-- SwanSport — DETAYLI SPORCU PROFİLİ
--
-- Yetki ayrımı:
--   • Sportif veriler (mevki, forma no, ölçüler, başarılar) → KULÜP yönetir.
--   • Kişisel veriler (ad, avatar, biyografi, kullanıcı adı)  → SPORCU yönetir.
--   • Kulüpsüz (ferdi) sporcu, sportif verisini de kendisi yönetir.
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) Sporcu kaydına sportif alanlar
-- ---------------------------------------------------------------------------
alter table public.athletes
  add column if not exists jersey_number int,
  add column if not exists height_cm     int,
  add column if not exists weight_kg     numeric(5,1),
  add column if not exists dominant_side text,     -- sağ | sol | çift
  add column if not exists branch        text,     -- futbol, voleybol, atletizm…
  add column if not exists started_at    date;     -- spora başlangıç


-- ---------------------------------------------------------------------------
-- 2) Yetki yardımcısı — bu sporcunun sportif verisini kim düzenleyebilir?
-- ---------------------------------------------------------------------------
create or replace function public.can_manage_athlete(p_athlete uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.athletes a
    where a.id = p_athlete
      and (
        -- Kulübe bağlıysa: kulüp yöneticisi veya antrenörü
        (a.club_id is not null and public.is_club_staff(a.club_id))
        -- Ferdi sporcuysa: kendisi
        or (a.club_id is null and a.profile_id = auth.uid())
      )
  );
$$;


-- ---------------------------------------------------------------------------
-- 3) Başarılar / dereceler
-- ---------------------------------------------------------------------------
create table if not exists public.athlete_achievements (
  id          uuid primary key default gen_random_uuid(),
  athlete_id  uuid not null references public.athletes(id) on delete cascade,
  title       text not null,               -- "Türkiye Şampiyonası"
  category    text not null default 'derece', -- derece | rekor | ödül | seçilme
  placement   int,                         -- 1, 2, 3 … (varsa)
  event_date  date,
  location    text,
  note        text,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists idx_achv_athlete
  on public.athlete_achievements (athlete_id, event_date desc nulls last);

alter table public.athlete_achievements enable row level security;

-- Başarılar herkese açıktır (sporcunun vitrini).
drop policy if exists "achv_read" on public.athlete_achievements;
create policy "achv_read" on public.athlete_achievements for select
  to authenticated using (true);

-- Yazma: kulüp yetkilisi (ya da ferdi sporcunun kendisi).
drop policy if exists "achv_write" on public.athlete_achievements;
create policy "achv_write" on public.athlete_achievements for all
  to authenticated
  using (public.can_manage_athlete(athlete_id))
  with check (public.can_manage_athlete(athlete_id));


-- ---------------------------------------------------------------------------
-- 4) Herkese açık sporcu görünümü
--
-- `athletes` tablosunda doğum tarihi ve lisans numarası gibi kişisel veriler
-- var; bunlar herkese açılmamalı (sporcuların bir kısmı 18 yaş altı).
-- Bu görünüm yalnızca vitrine uygun alanları taşır ve profil sayfasında
-- kullanılır.
-- ---------------------------------------------------------------------------
create or replace view public.athlete_public as
  select
    a.id,
    a.profile_id,
    a.club_id,
    a.first_name,
    a.last_name,
    a.position,
    a.status,
    a.jersey_number,
    a.height_cm,
    a.weight_kg,
    a.dominant_side,
    a.branch,
    a.started_at,
    c.name as club_name
  from public.athletes a
  left join public.clubs c on c.id = a.club_id;

grant select on public.athlete_public to authenticated;


-- ---------------------------------------------------------------------------
-- 5) Sportif bilgileri güncelleme (yetki fonksiyonla korunur)
-- ---------------------------------------------------------------------------
create or replace function public.update_athlete_sport_info(
  p_athlete       uuid,
  p_position      text default null,
  p_jersey        int  default null,
  p_height        int  default null,
  p_weight        numeric default null,
  p_dominant_side text default null,
  p_branch        text default null,
  p_license       text default null
)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_manage_athlete(p_athlete) then
    raise exception 'Bu sporcunun bilgilerini düzenleme yetkin yok';
  end if;

  update public.athletes
     set position       = coalesce(nullif(p_position,''), position),
         jersey_number  = coalesce(p_jersey, jersey_number),
         height_cm      = coalesce(p_height, height_cm),
         weight_kg      = coalesce(p_weight, weight_kg),
         dominant_side  = coalesce(nullif(p_dominant_side,''), dominant_side),
         branch         = coalesce(nullif(p_branch,''), branch),
         license_number = coalesce(nullif(p_license,''), license_number),
         updated_at     = now()
   where id = p_athlete;
end; $$;
