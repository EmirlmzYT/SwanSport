-- =============================================================================
-- SwanSport — BÜYÜK GÜNCELLEME
--   1) Ferdi sporcu (kulüpsüz) kaydı
--   2) Kulüp → kişi teklifi (çift yönlü eşleşme)
--   3) Antrenör kademesi + süpervizör (1. kademe bağı)
--   4) 18 yaş altı veli kontrolü
--   5) Bildirimler
--   6) Mesajlaşma
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- Not: Önce SETUP.sql, STORAGE.sql, SOCIAL.sql ve APPLICATIONS.sql çalışmış olmalı.
-- =============================================================================


-- ===========================================================================
-- 1) FERDİ SPORCU — kulüpsüz sporcu kaydı mümkün olsun
--    Kural: kulübe bağlıysa lisanslı, değilse ferdi sporcudur.
-- ===========================================================================
alter table public.athletes alter column club_id drop not null;

-- Sporcu kendi kaydını yönetebilsin (kulüpsüzken).
drop policy if exists "athletes: individual self" on public.athletes;
create policy "athletes: individual self" on public.athletes for all
  to authenticated
  using  (club_id is null and profile_id = auth.uid())
  with check (club_id is null and profile_id = auth.uid());

-- Kulüpsüz sporcular herkese görünür (sosyal profil için).
drop policy if exists "athletes: individual public read" on public.athletes;
create policy "athletes: individual public read" on public.athletes for select
  to authenticated
  using (club_id is null);

-- Kişinin ferdi sporcu kaydını oluşturur (yoksa).
create or replace function public.ensure_individual_athlete()
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_name text;
begin
  if auth.uid() is null then raise exception 'Oturum bulunamadı'; end if;

  select id into v_id from public.athletes
   where profile_id = auth.uid() and club_id is null limit 1;
  if v_id is not null then return v_id; end if;

  select coalesce(full_name,'Sporcu') into v_name
    from public.profiles where id = auth.uid();

  insert into public.athletes (club_id, profile_id, first_name, last_name, status)
  values (
    null,
    auth.uid(),
    split_part(v_name,' ',1),
    nullif(trim(substr(v_name, length(split_part(v_name,' ',1))+1)),''),
    'active'
  )
  returning id into v_id;

  return v_id;
end; $$;


-- ===========================================================================
-- 2) ÇİFT YÖNLÜ EŞLEŞME — kulüp de kişiye teklif sunabilsin
-- ===========================================================================
alter table public.club_applications
  add column if not exists kind text not null default 'application', -- application | offer
  add column if not exists coach_level int,
  add column if not exists supervisor_id uuid references public.profiles(id),
  add column if not exists created_by uuid references public.profiles(id);

-- Kulüpten kişiye teklif gönder.
create or replace function public.offer_to_person(
  p_club uuid,
  p_profile uuid,
  p_role text default 'athlete',
  p_message text default null
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.can_review_club_applications(p_club) then
    raise exception 'Bu kulüp adına teklif sunma yetkin yok';
  end if;

  if exists (
    select 1 from public.club_memberships m
    where m.club_id = p_club and m.profile_id = p_profile and m.status = 'active'
  ) then
    raise exception 'Bu kişi zaten kulübün üyesi';
  end if;

  insert into public.club_applications
    (club_id, profile_id, desired_role, message, kind, created_by)
  values (p_club, p_profile, coalesce(p_role,'athlete'), p_message, 'offer', auth.uid())
  on conflict do nothing
  returning id into v_id;

  if v_id is null then
    raise exception 'Bu kişiye bekleyen bir teklifin/başvurun zaten var';
  end if;
  return v_id;
end; $$;

-- İnceleme: başvuruyu kulüp, teklifi kişi karara bağlar.
create or replace function public.review_club_application(
  p_application uuid,
  p_accept boolean,
  p_note text default null,
  p_coach_level int default null,
  p_supervisor uuid default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_app public.club_applications%rowtype;
  v_level int;
  v_sup uuid;
begin
  select * into v_app from public.club_applications where id = p_application;
  if not found then raise exception 'Başvuru bulunamadı'; end if;

  -- Yetki: teklifi hedef kişi, başvuruyu kulüp yetkilisi yanıtlar.
  if v_app.kind = 'offer' then
    if v_app.profile_id <> auth.uid() then
      raise exception 'Bu teklifi yanıtlama yetkin yok';
    end if;
  else
    if not public.can_review_club_applications(v_app.club_id) then
      raise exception 'Bu başvuruyu inceleme yetkin yok';
    end if;
  end if;

  update public.club_applications
     set status = case when p_accept then 'accepted' else 'rejected' end,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         review_note = p_note
   where id = p_application;

  if p_accept then
    v_level := coalesce(p_coach_level, v_app.coach_level);
    v_sup   := coalesce(p_supervisor,  v_app.supervisor_id);

    insert into public.club_memberships
      (club_id, profile_id, role, status, coach_level, supervisor_id)
    values (
      v_app.club_id,
      v_app.profile_id,
      (case when v_app.desired_role = 'coach' then 'coach' else 'athlete' end)
        ::public.club_role,
      'active',
      case when v_app.desired_role = 'coach' then v_level else null end,
      case when v_app.desired_role = 'coach' then v_sup else null end
    )
    on conflict do nothing;
  end if;
end; $$;


-- ===========================================================================
-- 3) SÜPERVİZÖR — kulüpteki 2. kademe ve üstü antrenörler
-- ===========================================================================
create or replace function public.eligible_supervisors(p_club uuid)
returns table (profile_id uuid, full_name text, coach_level int)
language sql stable security definer set search_path = public as $$
  select m.profile_id, p.full_name, m.coach_level
    from public.club_memberships m
    join public.profiles p on p.id = m.profile_id
   where m.club_id = p_club
     and m.status = 'active'
     and m.role in ('club_admin','coach')
     and coalesce(m.coach_level, 0) >= 2
   order by m.coach_level desc nulls last, p.full_name;
$$;


-- ===========================================================================
-- 4) 18 YAŞ ALTI — veli bağı kontrolü
-- ===========================================================================
create or replace function public.athlete_needs_guardian(p_athlete uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.athletes a
    where a.id = p_athlete
      and a.birth_date is not null
      and a.birth_date > (current_date - interval '18 years')
      and not exists (
        select 1 from public.guardians g
        where g.athlete_id = a.id and g.profile_id is not null
      )
  );
$$;


-- ===========================================================================
-- 5) BİLDİRİMLER
-- ===========================================================================
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  kind        text not null,          -- like | comment | follow | application | offer | review
  title       text not null,
  body        text,
  actor_id    uuid references public.profiles(id) on delete set null,
  entity_type text,
  entity_id   uuid,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists idx_notif_profile
  on public.notifications (profile_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "notif_read_own" on public.notifications;
create policy "notif_read_own" on public.notifications for select
  to authenticated using (profile_id = auth.uid());

drop policy if exists "notif_update_own" on public.notifications;
create policy "notif_update_own" on public.notifications for update
  to authenticated using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "notif_delete_own" on public.notifications;
create policy "notif_delete_own" on public.notifications for delete
  to authenticated using (profile_id = auth.uid());

-- Bildirim yazan yardımcı (tetikleyiciler security definer olduğu için RLS'i aşar)
create or replace function public.push_notification(
  p_profile uuid, p_kind text, p_title text,
  p_body text default null, p_actor uuid default null,
  p_entity_type text default null, p_entity_id uuid default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  -- Kendine bildirim gönderme.
  if p_profile is null or p_profile = p_actor then return; end if;
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (p_profile, p_kind, p_title, p_body, p_actor, p_entity_type, p_entity_id);
end; $$;

-- Beğeni
create or replace function public.trg_notify_like()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_author uuid; v_name text;
begin
  select author_profile_id into v_author from public.posts where id = new.post_id;
  select full_name into v_name from public.profiles where id = new.profile_id;
  perform public.push_notification(
    v_author, 'like', coalesce(v_name,'Biri') || ' gönderini beğendi',
    null, new.profile_id, 'post', new.post_id);
  return new;
end; $$;
drop trigger if exists trg_post_like_notify on public.post_likes;
create trigger trg_post_like_notify after insert on public.post_likes
  for each row execute function public.trg_notify_like();

-- Yorum
create or replace function public.trg_notify_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_author uuid; v_name text;
begin
  select author_profile_id into v_author from public.posts where id = new.post_id;
  select full_name into v_name from public.profiles where id = new.profile_id;
  perform public.push_notification(
    v_author, 'comment', coalesce(v_name,'Biri') || ' gönderine yorum yaptı',
    left(new.body, 120), new.profile_id, 'post', new.post_id);
  return new;
end; $$;
drop trigger if exists trg_post_comment_notify on public.post_comments;
create trigger trg_post_comment_notify after insert on public.post_comments
  for each row execute function public.trg_notify_comment();

-- Takip
create or replace function public.trg_notify_follow()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if new.target_type <> 'profile' then return new; end if;
  select full_name into v_name from public.profiles where id = new.follower_id;
  perform public.push_notification(
    new.target_id, 'follow', coalesce(v_name,'Biri') || ' seni takip etmeye başladı',
    null, new.follower_id, 'profile', new.follower_id);
  return new;
end; $$;
drop trigger if exists trg_follow_notify on public.follows;
create trigger trg_follow_notify after insert on public.follows
  for each row execute function public.trg_notify_follow();

-- Başvuru / teklif geldi
create or replace function public.trg_notify_application()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_club text; v_person text; r record;
begin
  select name into v_club from public.clubs where id = new.club_id;
  select full_name into v_person from public.profiles where id = new.profile_id;

  if new.kind = 'offer' then
    perform public.push_notification(
      new.profile_id, 'offer',
      coalesce(v_club,'Bir kulüp') || ' sana katılım teklifi gönderdi',
      new.message, new.created_by, 'application', new.id);
  else
    for r in
      select profile_id from public.club_memberships
       where club_id = new.club_id and status='active'
         and role in ('club_admin','coach')
    loop
      perform public.push_notification(
        r.profile_id, 'application',
        coalesce(v_person,'Biri') || ' kulübüne başvurdu',
        new.message, new.profile_id, 'application', new.id);
    end loop;
  end if;
  return new;
end; $$;
drop trigger if exists trg_application_notify on public.club_applications;
create trigger trg_application_notify after insert on public.club_applications
  for each row execute function public.trg_notify_application();

-- Başvuru/teklif sonuçlandı
create or replace function public.trg_notify_application_review()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_club text;
begin
  if new.status = old.status then return new; end if;
  select name into v_club from public.clubs where id = new.club_id;

  if new.kind = 'offer' then
    perform public.push_notification(
      new.created_by, 'review',
      case when new.status='accepted' then 'Teklifin kabul edildi'
           else 'Teklifin reddedildi' end,
      v_club, new.profile_id, 'application', new.id);
  else
    perform public.push_notification(
      new.profile_id, 'review',
      case when new.status='accepted'
           then coalesce(v_club,'Kulüp') || ' başvurunu kabul etti'
           else coalesce(v_club,'Kulüp') || ' başvurunu reddetti' end,
      new.review_note, new.reviewed_by, 'application', new.id);
  end if;
  return new;
end; $$;
drop trigger if exists trg_application_review_notify on public.club_applications;
create trigger trg_application_review_notify after update on public.club_applications
  for each row execute function public.trg_notify_application_review();

-- Kimlik doğrulama sonucu
create or replace function public.trg_notify_credential_review()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = old.status then return new; end if;
  perform public.push_notification(
    new.profile_id, 'review',
    case when new.status = 'approved' then 'Kimliğin onaylandı'
         when new.status = 'rejected' then 'Kimlik başvurun reddedildi'
         else 'Başvuru durumun güncellendi' end,
    new.note, new.reviewed_by, 'credential', new.id);
  return new;
end; $$;
drop trigger if exists trg_credential_review_notify on public.profile_credentials;
create trigger trg_credential_review_notify after update on public.profile_credentials
  for each row execute function public.trg_notify_credential_review();


-- ===========================================================================
-- 6) MESAJLAŞMA (birebir)
-- ===========================================================================
create table if not exists public.direct_messages (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body         text not null,
  created_at   timestamptz not null default now(),
  read_at      timestamptz
);
create index if not exists idx_dm_pair
  on public.direct_messages (sender_id, recipient_id, created_at desc);
create index if not exists idx_dm_recipient
  on public.direct_messages (recipient_id, created_at desc);

alter table public.direct_messages enable row level security;

drop policy if exists "dm_read_own" on public.direct_messages;
create policy "dm_read_own" on public.direct_messages for select
  to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists "dm_send" on public.direct_messages;
create policy "dm_send" on public.direct_messages for insert
  to authenticated with check (sender_id = auth.uid());

drop policy if exists "dm_update_recipient" on public.direct_messages;
create policy "dm_update_recipient" on public.direct_messages for update
  to authenticated using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

drop policy if exists "dm_delete_own" on public.direct_messages;
create policy "dm_delete_own" on public.direct_messages for delete
  to authenticated using (sender_id = auth.uid());

-- Sohbet listesi: her karşı taraf için son mesaj + okunmamış sayısı
create or replace function public.my_conversations()
returns table (
  other_id uuid,
  other_name text,
  other_avatar text,
  last_body text,
  last_at timestamptz,
  unread int
)
language sql stable security definer set search_path = public as $$
  with mine as (
    select
      case when sender_id = auth.uid() then recipient_id else sender_id end as other,
      body, created_at, read_at, recipient_id
    from public.direct_messages
    where sender_id = auth.uid() or recipient_id = auth.uid()
  ),
  ranked as (
    select other, body, created_at,
           row_number() over (partition by other order by created_at desc) rn
    from mine
  )
  select r.other,
         p.full_name,
         p.avatar_path,
         r.body,
         r.created_at,
         (select count(*)::int from mine m
           where m.other = r.other and m.recipient_id = auth.uid()
             and m.read_at is null)
    from ranked r
    join public.profiles p on p.id = r.other
   where r.rn = 1
   order by r.created_at desc;
$$;

-- Bir sohbeti okundu işaretle
create or replace function public.mark_conversation_read(p_other uuid)
returns void
language sql security definer set search_path = public as $$
  update public.direct_messages
     set read_at = now()
   where recipient_id = auth.uid()
     and sender_id = p_other
     and read_at is null;
$$;
