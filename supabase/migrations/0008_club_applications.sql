-- =============================================================================
-- SwanSport — KULÜP BAŞVURULARI
-- Doğrulanmış kişiler (ferdi sporcu, lisanslı sporcu, antrenör) istedikleri
-- kulübe başvurur; kulüp yetkilisi kabul edince üyelik oluşur.
--
-- Supabase SQL editöründe BİR KEZ çalıştır (SOCIAL.sql sonrası).
-- Tekrar çalıştırılabilir (idempotent).
-- =============================================================================

create table if not exists public.club_applications (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id)    on delete cascade,
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  -- Başvurulan rol: 'athlete' | 'coach'
  desired_role text not null default 'athlete',
  message      text,
  status       text not null default 'pending',  -- pending | accepted | rejected
  created_at   timestamptz not null default now(),
  reviewed_by  uuid references public.profiles(id),
  reviewed_at  timestamptz,
  review_note  text
);

-- Aynı kulübe birden fazla bekleyen başvuru olmasın.
create unique index if not exists idx_club_app_unique_pending
  on public.club_applications (club_id, profile_id)
  where status = 'pending';

create index if not exists idx_club_app_club
  on public.club_applications (club_id, status);
create index if not exists idx_club_app_profile
  on public.club_applications (profile_id);

-- ---------------------------------------------------------------------------
-- Yetki yardımcıları
-- ---------------------------------------------------------------------------

-- Kulüp başvurularını inceleyebilir mi? (yönetici veya antrenör)
create or replace function public.can_review_club_applications(p_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.club_memberships m
    where m.club_id = p_club
      and m.profile_id = auth.uid()
      and m.status = 'active'
      and m.role in ('club_admin','coach')
  );
$$;

-- ---------------------------------------------------------------------------
-- Başvuru gönder — yalnızca doğrulanmış kişiler, aktif kulüplere
-- ---------------------------------------------------------------------------
create or replace function public.apply_to_club(
  p_club uuid,
  p_role text default 'athlete',
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Oturum bulunamadı';
  end if;

  -- Kimliği onaylanmamış kişi başvuramaz.
  if not exists (
    select 1 from public.profile_credentials c
    where c.profile_id = auth.uid() and c.status = 'approved'
  ) then
    raise exception 'Önce kimliğini doğrulatmalısın';
  end if;

  -- Kulüp aktif olmalı.
  if not exists (
    select 1 from public.clubs c where c.id = p_club and c.status = 'active'
  ) then
    raise exception 'Kulüp bulunamadı veya henüz onaylanmamış';
  end if;

  -- Zaten üyeyse başvurmasın.
  if exists (
    select 1 from public.club_memberships m
    where m.club_id = p_club and m.profile_id = auth.uid()
      and m.status = 'active'
  ) then
    raise exception 'Bu kulübün zaten üyesisin';
  end if;

  insert into public.club_applications (club_id, profile_id, desired_role, message)
  values (p_club, auth.uid(), coalesce(p_role, 'athlete'), p_message)
  on conflict do nothing
  returning id into v_id;

  if v_id is null then
    raise exception 'Bu kulübe bekleyen bir başvurun zaten var';
  end if;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Başvuruyu incele — kabul edilirse üyelik oluşturulur
-- ---------------------------------------------------------------------------
create or replace function public.review_club_application(
  p_application uuid,
  p_accept boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_app public.club_applications%rowtype;
begin
  select * into v_app from public.club_applications where id = p_application;
  if not found then
    raise exception 'Başvuru bulunamadı';
  end if;

  if not public.can_review_club_applications(v_app.club_id) then
    raise exception 'Bu başvuruyu inceleme yetkin yok';
  end if;

  update public.club_applications
     set status = case when p_accept then 'accepted' else 'rejected' end,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         review_note = p_note
   where id = p_application;

  if p_accept then
    insert into public.club_memberships (club_id, profile_id, role, status)
    values (
      v_app.club_id,
      v_app.profile_id,
      (case when v_app.desired_role = 'coach' then 'coach' else 'athlete' end)::public.club_role,
      'active'
    )
    on conflict do nothing;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.club_applications enable row level security;

-- Kendi başvurunu görürsün; kulüp yetkilisi kulübüne gelenleri görür.
drop policy if exists "club_app_read" on public.club_applications;
create policy "club_app_read" on public.club_applications for select
  to authenticated
  using (
    profile_id = auth.uid()
    or public.can_review_club_applications(club_id)
    or public.is_platform_admin()
  );

-- Başvuru gönderimi apply_to_club() üzerinden yapılır; doğrudan ekleme de
-- yalnızca kişinin kendi adına olabilir.
drop policy if exists "club_app_insert_own" on public.club_applications;
create policy "club_app_insert_own" on public.club_applications for insert
  to authenticated
  with check (profile_id = auth.uid());

-- Güncelleme review_club_application() ile yapılır (security definer);
-- kişi kendi bekleyen başvurusunu geri çekebilir.
drop policy if exists "club_app_delete_own" on public.club_applications;
create policy "club_app_delete_own" on public.club_applications for delete
  to authenticated
  using (profile_id = auth.uid() and status = 'pending');
