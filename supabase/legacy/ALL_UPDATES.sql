-- ==========================================================================
-- SwanSport — TÜM GÜNCELLEMELER (tek dosya)
--
-- Bu dosya asagidaki kurulumlarin tamamini icerir ve tekrar
-- calistirilabilir. Supabase SQL editorune yapistirip Run demen yeterli.
--
--   1) Onay paneli düzeltmesi
--   2) Kulüp başvuruları
--   3) Ferdi sporcu, teklif, süpervizör, bildirim, mesajlaşma
--   4) Haber kaynakları (RSS)
--   5) Detaylı sporcu profili (künye + başarılar)
--   6) Şikayet, engelleme, hesap silme
--   7) Maç sonucu, kulüp profili, yoklama özeti
--   8) Performans modülü (test + gelişim hedefi)
--
-- Onkosul: SETUP.sql, STORAGE.sql ve SOCIAL.sql daha once calistirilmis olmali.
-- ==========================================================================


-- ########################################################################
-- Onay paneli düzeltmesi
-- ########################################################################

-- =============================================================================
-- SwanSport — DÜZELTME: review_credential enum dönüşümü
--
-- Hata: column "status" is of type verification_status but expression is of
--       type text (42804)
--
-- Sebep: CASE ifadesi `text` üretiyor; PostgreSQL bunu enum'a kendiliğinden
--        çevirmiyor (düz 'approved' yazsaydık çevirirdi, CASE sonucu çevirmez).
-- Çözüm: sonucu açıkça verification_status'a dönüştür.
--
-- Supabase SQL editöründe çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================

create or replace function public.review_credential(
  p_cred uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;
  update public.profile_credentials
     set status = (case when p_approve then 'approved' else 'rejected' end)
                  ::public.verification_status,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         note = p_note
   where id = p_cred;
end; $$;


-- ########################################################################
-- Kulüp başvuruları
-- ########################################################################

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


-- ########################################################################
-- Ferdi sporcu, teklif, süpervizör, bildirim, mesajlaşma
-- ########################################################################

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


-- ########################################################################
-- Haber kaynakları (RSS)
-- ########################################################################

-- =============================================================================
-- SwanSport — HABER KAYNAKLARI (RSS)
--
-- Platform yöneticisi panelden kaynak ekler/kaldırır; akışta herkese görünür.
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================

create table if not exists public.rss_sources (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  url        text not null,
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null
);

create unique index if not exists idx_rss_url on public.rss_sources (url);

alter table public.rss_sources enable row level security;

-- Herkes aktif kaynakları görebilir (akışta haber gösterebilmek için).
drop policy if exists "rss_read" on public.rss_sources;
create policy "rss_read" on public.rss_sources for select
  to authenticated using (true);

-- Yalnızca platform yöneticisi ekler/düzenler/siler.
drop policy if exists "rss_admin_write" on public.rss_sources;
create policy "rss_admin_write" on public.rss_sources for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Başlangıç kaynakları — canlı olarak test edilip çalıştığı doğrulandı.
-- Panelden istediğini kapatabilir, yenisini ekleyebilirsin.
insert into public.rss_sources (name, url)
values
  ('AA Spor',      'https://www.aa.com.tr/tr/rss/default?cat=spor'),
  ('Hürriyet Spor','https://www.hurriyet.com.tr/rss/spor')
on conflict (url) do nothing;


-- ########################################################################
-- Detaylı sporcu profili (künye + başarılar)
-- ########################################################################

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


-- ########################################################################
-- Şikayet, engelleme, hesap silme
-- ########################################################################

-- =============================================================================
-- SwanSport — GÜVENLİK & YASAL
--   1) İçerik şikayeti (gönderi, yorum, kullanıcı)
--   2) Kullanıcı engelleme
--   3) Hesap silme (KVKK)
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) ŞİKAYETLER
-- ---------------------------------------------------------------------------
create table if not exists public.content_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('post','comment','profile')),
  target_id   uuid not null,
  reason      text not null,          -- spam | taciz | uygunsuz | yanlis_bilgi | diger
  detail      text,
  status      text not null default 'open',  -- open | reviewed | dismissed
  created_at  timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  review_note text
);

create index if not exists idx_report_status
  on public.content_reports (status, created_at desc);
-- Aynı kişi aynı içeriği bir kez şikayet etsin.
create unique index if not exists idx_report_unique
  on public.content_reports (reporter_id, target_type, target_id)
  where status = 'open';

alter table public.content_reports enable row level security;

drop policy if exists "report_insert_own" on public.content_reports;
create policy "report_insert_own" on public.content_reports for insert
  to authenticated with check (reporter_id = auth.uid());

drop policy if exists "report_read" on public.content_reports;
create policy "report_read" on public.content_reports for select
  to authenticated
  using (reporter_id = auth.uid() or public.is_platform_admin());

drop policy if exists "report_admin_update" on public.content_reports;
create policy "report_admin_update" on public.content_reports for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Şikayeti sonuçlandır (platform yöneticisi).
create or replace function public.review_report(
  p_report uuid,
  p_action text,              -- 'reviewed' | 'dismissed'
  p_note text default null,
  p_delete_content boolean default false
)
returns void
language plpgsql security definer set search_path = public as $$
declare r public.content_reports%rowtype;
begin
  if not public.is_platform_admin() then
    raise exception 'Yetkisiz';
  end if;

  select * into r from public.content_reports where id = p_report;
  if not found then raise exception 'Şikayet bulunamadı'; end if;

  update public.content_reports
     set status = case when p_action = 'dismissed' then 'dismissed'
                       else 'reviewed' end,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         review_note = p_note
   where id = p_report;

  if p_delete_content then
    if r.target_type = 'post' then
      delete from public.posts where id = r.target_id;
    elsif r.target_type = 'comment' then
      delete from public.post_comments where id = r.target_id;
    end if;
  end if;
end; $$;


-- ---------------------------------------------------------------------------
-- 2) ENGELLEME
-- ---------------------------------------------------------------------------
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_not_self check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

drop policy if exists "blocks_own" on public.blocks;
create policy "blocks_own" on public.blocks for all
  to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

-- Engellediklerim + beni engelleyenler (içerik gizlemede kullanılır).
create or replace function public.hidden_profiles()
returns setof uuid
language sql stable security definer set search_path = public as $$
  select blocked_id from public.blocks where blocker_id = auth.uid()
  union
  select blocker_id from public.blocks where blocked_id = auth.uid();
$$;

-- Engellendiğinde karşılıklı takip de düşsün.
create or replace function public.trg_block_cleanup()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.follows
   where (follower_id = new.blocker_id and target_type = 'profile'
          and target_id = new.blocked_id)
      or (follower_id = new.blocked_id and target_type = 'profile'
          and target_id = new.blocker_id);
  return new;
end; $$;
drop trigger if exists trg_blocks_cleanup on public.blocks;
create trigger trg_blocks_cleanup after insert on public.blocks
  for each row execute function public.trg_block_cleanup();


-- ---------------------------------------------------------------------------
-- 3) HESAP SİLME (KVKK — kullanıcının verisini silme hakkı)
--
-- profiles.id → auth.users(id) üzerine kuruludur; auth kaydı silinince
-- profil ve ona bağlı tüm içerik (gönderi, yorum, beğeni, takip, mesaj)
-- cascade ile silinir.
-- ---------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Oturum bulunamadı'; end if;

  -- Kulübün tek yöneticisiyse önce devretmeli; veri sahipsiz kalmasın.
  if exists (
    select 1 from public.club_memberships m
    where m.profile_id = v_uid and m.role = 'club_admin' and m.status = 'active'
      and (
        select count(*) from public.club_memberships m2
        where m2.club_id = m.club_id and m2.role = 'club_admin'
          and m2.status = 'active'
      ) = 1
  ) then
    raise exception
      'Kulübün tek yöneticisisin. Önce başka birini yönetici yap veya kulübü kapat.';
  end if;

  delete from auth.users where id = v_uid;
end; $$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;


-- ########################################################################
-- Maç sonucu, kulüp profili, yoklama özeti
-- ########################################################################

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


-- ########################################################################
-- Performans modülü (test + gelişim hedefi)
-- ########################################################################

-- =============================================================================
-- SwanSport — PERFORMANS MODÜLÜ
--   1) Test kayıtları (sürat, dayanıklılık, kuvvet, teknik)
--   2) Bireysel gelişim planı (IDP) hedefleri
--
-- Gizlilik: performans verisi başarılar gibi herkese açık DEĞİLDİR.
-- Yalnızca kulüp yetkilisi, sporcunun kendisi ve velisi görebilir.
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Görüntüleme yetkisi
-- ---------------------------------------------------------------------------
create or replace function public.can_view_athlete_performance(p_athlete uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.athletes a
    where a.id = p_athlete
      and (
        public.can_manage_athlete(a.id)          -- kulüp yetkilisi / ferdi sporcu
        or a.profile_id = auth.uid()             -- sporcunun kendisi
        or public.is_guardian_of(a.id)           -- velisi
      )
  );
$$;


-- ---------------------------------------------------------------------------
-- 1) TEST KAYITLARI
-- ---------------------------------------------------------------------------
create table if not exists public.performance_tests (
  id          uuid primary key default gen_random_uuid(),
  athlete_id  uuid not null references public.athletes(id) on delete cascade,
  category    text not null default 'surat',  -- surat|dayaniklilik|kuvvet|teknik
  test_name   text not null,                  -- "30 m sprint"
  value       numeric(10,2) not null,
  unit        text not null default '',       -- sn, m, kg, tekrar, puan
  -- Bazı testlerde küçük değer iyidir (sprint süresi gibi).
  lower_is_better boolean not null default false,
  test_date   date not null default current_date,
  note        text,
  assessor_id uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists idx_perf_athlete
  on public.performance_tests (athlete_id, test_name, test_date);

alter table public.performance_tests enable row level security;

drop policy if exists "perf_read" on public.performance_tests;
create policy "perf_read" on public.performance_tests for select
  to authenticated
  using (public.can_view_athlete_performance(athlete_id));

drop policy if exists "perf_write" on public.performance_tests;
create policy "perf_write" on public.performance_tests for all
  to authenticated
  using (public.can_manage_athlete(athlete_id))
  with check (public.can_manage_athlete(athlete_id));


-- ---------------------------------------------------------------------------
-- 2) BİREYSEL GELİŞİM PLANI (IDP)
-- ---------------------------------------------------------------------------
create table if not exists public.development_goals (
  id           uuid primary key default gen_random_uuid(),
  athlete_id   uuid not null references public.athletes(id) on delete cascade,
  title        text not null,
  category     text not null default 'surat',
  progress     int  not null default 0,   -- 0..100
  target_date  date,
  status       text not null default 'active', -- active | done | at_risk
  note         text,
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index if not exists idx_goal_athlete
  on public.development_goals (athlete_id, status);

alter table public.development_goals enable row level security;

drop policy if exists "goal_read" on public.development_goals;
create policy "goal_read" on public.development_goals for select
  to authenticated
  using (public.can_view_athlete_performance(athlete_id));

drop policy if exists "goal_write" on public.development_goals;
create policy "goal_write" on public.development_goals for all
  to authenticated
  using (public.can_manage_athlete(athlete_id))
  with check (public.can_manage_athlete(athlete_id));


-- ---------------------------------------------------------------------------
-- 3) Kulüp özeti — kadroda kimin kaç testi ve hedefi var
-- ---------------------------------------------------------------------------
create or replace function public.performance_overview(p_club uuid)
returns table (
  athlete_id  uuid,
  full_name   text,
  test_count  int,
  goal_count  int,
  avg_progress int,
  last_test   date
)
language sql stable security definer set search_path = public as $$
  select
    a.id,
    (a.first_name || ' ' || coalesce(a.last_name, '')) as full_name,
    (select count(*) from public.performance_tests t
      where t.athlete_id = a.id)::int,
    (select count(*) from public.development_goals g
      where g.athlete_id = a.id and g.status <> 'done')::int,
    coalesce((select round(avg(g.progress)) from public.development_goals g
      where g.athlete_id = a.id and g.status <> 'done'), 0)::int,
    (select max(t.test_date) from public.performance_tests t
      where t.athlete_id = a.id)
  from public.athletes a
  where a.club_id = p_club
    and public.is_club_staff(p_club)
  order by full_name;
$$;

