-- =============================================================================
-- SwanSport — SPORCU EKİPMAN VE MALZEME BAKIM TAKİBİ
--
-- Sporcunun ekipmanları (yay, raket, ayakkabı vb.), ayar parametreleri (tuning)
-- ve periyodik bakım kayıtları.
-- =============================================================================

create table if not exists public.athlete_equipment (
  id                uuid primary key default gen_random_uuid(),
  athlete_id        uuid not null references public.athletes (id) on delete cascade,
  club_id           uuid references public.clubs (id) on delete set null,
  name              text not null,
  category          text not null default 'other',
  brand_model       text,
  serial_no         text,
  tuning_params     jsonb not null default '{}'::jsonb,
  status            text not null default 'active',
  last_serviced_at  timestamptz,
  notes             text,
  created_at        timestamptz not null default now(),

  constraint chk_equipment_status check (status in ('active', 'maintenance', 'retired'))
);

create index if not exists idx_athlete_equipment_owner
  on public.athlete_equipment (athlete_id, status);

alter table public.athlete_equipment enable row level security;

drop policy if exists "athlete_equipment_read" on public.athlete_equipment;
create policy "athlete_equipment_read" on public.athlete_equipment
  for select using (
    public.is_athlete_self(athlete_id)
    or public.can_view_athlete_performance(athlete_id)
  );

drop policy if exists "athlete_equipment_insert" on public.athlete_equipment;
create policy "athlete_equipment_insert" on public.athlete_equipment
  for insert with check (public.is_athlete_self(athlete_id));

drop policy if exists "athlete_equipment_update" on public.athlete_equipment;
create policy "athlete_equipment_update" on public.athlete_equipment
  for update using (public.is_athlete_self(athlete_id));

drop policy if exists "athlete_equipment_delete" on public.athlete_equipment;
create policy "athlete_equipment_delete" on public.athlete_equipment
  for delete using (public.is_athlete_self(athlete_id));

grant select, insert, update, delete on public.athlete_equipment to authenticated;