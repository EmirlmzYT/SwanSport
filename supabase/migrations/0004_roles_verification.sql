-- =============================================================================
-- SwanSport — Roller & Doğrulama (0004). Apply AFTER 0001+0002 (+0003).
-- Kişi-düzeyi doğrulama · kulüp-beklemede + ≥2. kademe · platform onayı ·
-- davet kodu · kademe hiyerarşi tetikleyicisi. Safe to re-run.
-- =============================================================================

-- Not: 'member' rol değeri şimdilik kullanılmıyor; ihtiyaç olunca eklenecek.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin create type public.credential_kind as enum
  ('coach','athlete_licensed','athlete_individual');
exception when duplicate_object then null; end $$;

do $$ begin create type public.verification_status as enum
  ('pending','approved','rejected');
exception when duplicate_object then null; end $$;

do $$ begin create type public.club_status as enum
  ('pending','active','suspended','rejected');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Platform yöneticisi bayrağı
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_platform_admin boolean not null default false;

create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_platform_admin from public.profiles where id = auth.uid()), false);
$$;

-- ---------------------------------------------------------------------------
-- Kulüp: durum + inceleme alanları
-- ---------------------------------------------------------------------------
alter table public.clubs
  add column if not exists status public.club_status not null default 'pending',
  add column if not exists reviewed_by uuid references public.profiles(id),
  add column if not exists reviewed_at timestamptz,
  add column if not exists review_note text;

-- ---------------------------------------------------------------------------
-- Üyelik: kademe + amir (1. kademe → 2. kademe bağı, kulüp düzeyinde)
-- ---------------------------------------------------------------------------
alter table public.club_memberships
  add column if not exists coach_level int,
  add column if not exists supervisor_id uuid references public.profiles(id);

-- ---------------------------------------------------------------------------
-- Kişi-düzeyi doğrulanmış kimlikler (kulüpten bağımsız)
-- ---------------------------------------------------------------------------
create table if not exists public.profile_credentials (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  kind         public.credential_kind not null,
  coach_level  int,                       -- kind='coach' için 1..5
  status       public.verification_status not null default 'pending',
  submitted_at timestamptz not null default now(),
  reviewed_by  uuid references public.profiles(id),
  reviewed_at  timestamptz,
  note         text
);
create index if not exists idx_cred_profile on public.profile_credentials(profile_id);

-- ---------------------------------------------------------------------------
-- Doğrulama evrakları (credential VEYA kulüp başvurusu sahibi)
-- ---------------------------------------------------------------------------
create table if not exists public.verification_documents (
  id           uuid primary key default gen_random_uuid(),
  owner_type   text not null,             -- 'credential' | 'club'
  owner_id     uuid not null,
  doc_type     text not null,             -- 'kademe_belgesi','kimlik','tescil','federasyon' ...
  storage_path text not null,             -- Supabase Storage yolu
  uploaded_by  uuid references public.profiles(id),
  uploaded_at  timestamptz not null default now()
);
create index if not exists idx_vdoc_owner on public.verification_documents(owner_type, owner_id);

-- ---------------------------------------------------------------------------
-- Davet kodları (veli ↔ sporcu bağı; tek kullanımlık + süreli)
-- ---------------------------------------------------------------------------
create table if not exists public.invite_codes (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  purpose    text not null default 'guardian_link',
  athlete_id uuid references public.athletes(id) on delete cascade,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  used_at    timestamptz,
  used_by    uuid references public.profiles(id)
);
create index if not exists idx_invite_code on public.invite_codes(code);

-- ---------------------------------------------------------------------------
-- Kademe hiyerarşi tetikleyicisi:
-- 1. kademe antrenör, kulüpte ≥2. kademe biri yoksa eklenemez.
-- ---------------------------------------------------------------------------
create or replace function public.enforce_coach_hierarchy()
returns trigger language plpgsql as $$
begin
  if new.role = 'coach' and new.coach_level = 1 then
    if not exists (
      select 1 from public.club_memberships m
      where m.club_id = new.club_id
        and m.role = 'coach'
        and coalesce(m.coach_level, 0) >= 2
        and m.status = 'active'
    ) then
      raise exception '1. kademe antrenör eklenemez: kulüpte ≥2. kademe bir antrenör bulunmalı.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_coach_hierarchy on public.club_memberships;
create trigger trg_coach_hierarchy
  before insert on public.club_memberships
  for each row execute function public.enforce_coach_hierarchy();

-- ---------------------------------------------------------------------------
-- RPC: create_club — artık PENDING + kurucu ≥2. kademe doğrulanmış olmalı
-- (0002'deki sürümü değiştirir)
-- ---------------------------------------------------------------------------
create or replace function public.create_club(
  p_name       text,
  p_short_name text default null,
  p_city       text default null
)
returns public.clubs
language plpgsql security definer set search_path = public as $$
declare v_club public.clubs;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  -- Kurucu şartı: ≥2. kademe onaylı antrenör kimliği
  if not exists (
    select 1 from public.profile_credentials
    where profile_id = auth.uid()
      and kind = 'coach'
      and coalesce(coach_level, 0) >= 2
      and status = 'approved'
  ) then
    raise exception 'Kulüp kurmak için en az 2. kademe doğrulanmış antrenör olmalısın.';
  end if;

  insert into public.clubs (name, short_name, city, created_by, status)
  values (p_name, p_short_name, p_city, auth.uid(), 'pending')
  returning * into v_club;

  insert into public.club_memberships (club_id, profile_id, role, status)
  values (v_club.id, auth.uid(), 'club_admin', 'active');

  return v_club;
end;
$$;

-- ---------------------------------------------------------------------------
-- Platform onay/ret RPC'leri
-- ---------------------------------------------------------------------------
create or replace function public.approve_club(p_club uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;
  update public.clubs
     set status='active', reviewed_by=auth.uid(), reviewed_at=now()
   where id=p_club;
end; $$;

create or replace function public.reject_club(p_club uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;
  update public.clubs
     set status='rejected', reviewed_by=auth.uid(), reviewed_at=now(), review_note=p_note
   where id=p_club;
end; $$;

create or replace function public.review_credential(
  p_cred uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;
  update public.profile_credentials
     set status = (case when p_approve then 'approved' else 'rejected' end)
                  ::public.verification_status,
         reviewed_by = auth.uid(), reviewed_at = now(), note = p_note
   where id = p_cred;
end; $$;

-- ---------------------------------------------------------------------------
-- Davet kodu RPC'leri
-- ---------------------------------------------------------------------------
create or replace function public.create_guardian_invite(p_athlete uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_code text; v_club uuid;
begin
  select club_id into v_club from public.athletes where id = p_athlete;
  if v_club is null or not public.is_club_staff(v_club) then
    raise exception 'Yetkisiz veya sporcu bulunamadı';
  end if;
  v_code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  insert into public.invite_codes (code, athlete_id, created_by)
  values (v_code, p_athlete, auth.uid());
  return v_code;
end; $$;

create or replace function public.redeem_invite_code(p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare v_inv public.invite_codes; v_name text;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select * into v_inv from public.invite_codes
    where code = upper(p_code) and used_at is null and expires_at > now()
    limit 1;
  if v_inv.id is null then raise exception 'Kod geçersiz veya süresi dolmuş'; end if;

  select coalesce(full_name,'Veli') into v_name from public.profiles where id = auth.uid();
  insert into public.guardians (athlete_id, profile_id, display_name, relationship, can_contact)
  values (v_inv.athlete_id, auth.uid(), v_name, 'Veli', true);

  update public.invite_codes set used_at = now(), used_by = auth.uid() where id = v_inv.id;
end; $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.profile_credentials    enable row level security;
alter table public.verification_documents enable row level security;
alter table public.invite_codes           enable row level security;

-- credentials: kişi kendi kaydını görür/ekler; platform admin hepsini görür/günceller
drop policy if exists "cred_own" on public.profile_credentials;
create policy "cred_own" on public.profile_credentials for select
  using (profile_id = auth.uid() or public.is_platform_admin());
drop policy if exists "cred_insert" on public.profile_credentials;
create policy "cred_insert" on public.profile_credentials for insert
  with check (profile_id = auth.uid());
drop policy if exists "cred_admin_update" on public.profile_credentials;
create policy "cred_admin_update" on public.profile_credentials for update
  using (public.is_platform_admin());

-- verification docs: yükleyen veya platform admin
drop policy if exists "vdoc_own" on public.verification_documents;
create policy "vdoc_own" on public.verification_documents for select
  using (uploaded_by = auth.uid() or public.is_platform_admin());
drop policy if exists "vdoc_insert" on public.verification_documents;
create policy "vdoc_insert" on public.verification_documents for insert
  with check (uploaded_by = auth.uid());

-- invite codes: kulüp personeli oluşturur/görür; herkes redeem RPC ile kullanır
drop policy if exists "invite_staff" on public.invite_codes;
create policy "invite_staff" on public.invite_codes for all
  using (created_by = auth.uid() or public.is_platform_admin())
  with check (created_by = auth.uid());

-- Platform admin: kulüpleri ve üyelikleri görebilsin (mevcut polic'​lere ek)
drop policy if exists "clubs_platform_read" on public.clubs;
create policy "clubs_platform_read" on public.clubs for select
  using (public.is_platform_admin());
