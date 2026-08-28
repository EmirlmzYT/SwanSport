-- =============================================================================
-- SwanSport — Extended schema (announcements, events, invoices, attendance,
-- injuries, facilities, documents). Apply AFTER 0001 + 0002.
-- Reuses helper functions is_club_member() / is_club_staff() from 0002.
-- SQL Editor → New query → paste → Run. Safe to re-run.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.event_kind as enum ('training', 'match', 'meeting', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.invoice_status as enum ('paid', 'pending', 'overdue');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.attendance_status as enum ('present', 'absent', 'excused', 'late');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.fitness_status as enum ('fit', 'injured', 'pending');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- announcements
-- ---------------------------------------------------------------------------
create table if not exists public.announcements (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  author_id  uuid references public.profiles (id) on delete set null,
  title      text not null,
  body       text not null default '',
  pinned     boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- events (calendar)
-- ---------------------------------------------------------------------------
create table if not exists public.events (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  team_id    uuid references public.teams (id) on delete set null,
  title      text not null,
  place      text,
  kind       public.event_kind not null default 'training',
  starts_at  timestamptz not null,
  ends_at    timestamptz,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- invoices (finance)
-- ---------------------------------------------------------------------------
create table if not exists public.invoices (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  athlete_id uuid references public.athletes (id) on delete set null,
  label      text not null,
  amount     numeric(12,2) not null default 0,
  status     public.invoice_status not null default 'pending',
  period     text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- attendance
-- ---------------------------------------------------------------------------
create table if not exists public.attendance (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  event_id   uuid references public.events (id) on delete set null,
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  status     public.attendance_status not null default 'present',
  taken_at   timestamptz not null default now(),
  unique (event_id, athlete_id)
);

-- ---------------------------------------------------------------------------
-- injuries (medical)
-- ---------------------------------------------------------------------------
create table if not exists public.injuries (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  status     public.fitness_status not null default 'fit',
  note       text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- facilities
-- ---------------------------------------------------------------------------
create table if not exists public.facilities (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  name       text not null,
  kind       text,
  occupancy  int not null default 0,   -- 0..100
  status     text not null default 'Müsait',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- documents
-- ---------------------------------------------------------------------------
create table if not exists public.documents (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  name       text not null,
  kind       text not null default 'file',   -- folder | pdf | xls | file
  size_label text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_ann_club   on public.announcements (club_id);
create index if not exists idx_ev_club    on public.events (club_id);
create index if not exists idx_inv_club   on public.invoices (club_id);
create index if not exists idx_att_club   on public.attendance (club_id);
create index if not exists idx_inj_club   on public.injuries (club_id);
create index if not exists idx_fac_club   on public.facilities (club_id);
create index if not exists idx_doc_club   on public.documents (club_id);

-- ---------------------------------------------------------------------------
-- RLS: members read · staff write   (helpers from 0002)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'announcements','events','invoices','attendance','injuries','facilities','documents'
  ] loop
    execute format('alter table public.%I enable row level security;', t);

    execute format($f$
      drop policy if exists "%1$s_read" on public.%1$s;
      create policy "%1$s_read" on public.%1$s for select
        using (public.is_club_member(club_id));
    $f$, t);

    execute format($f$
      drop policy if exists "%1$s_write" on public.%1$s;
      create policy "%1$s_write" on public.%1$s for all
        using (public.is_club_staff(club_id))
        with check (public.is_club_staff(club_id));
    $f$, t);
  end loop;
end $$;
