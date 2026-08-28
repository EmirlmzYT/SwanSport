-- =============================================================================
-- SwanSport — FAZ 4 & 5: BELGE KASASI, VELİ DENEYİMİ, BİLDİRİM TERCİHLERİ
--
-- Belge tarafında ikinci bir sistem kurulmuyor: mevcut `documents` tablosu
-- genişletiliyor. `verification_documents` (kimlik başvurusu ekleri) olduğu
-- gibi kalıyor — o farklı bir iş yapıyor, karıştırılmamalı.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) BELGE KASASI
--
-- Eskiden yalnızca isim ve tür tutuluyordu; dosyanın kendisi yoktu.
-- Artık sahibi (kulüp / sporcu / kişi), dosya yolu, geçerlilik tarihi ve
-- doğrulama durumu var.
-- ---------------------------------------------------------------------------
alter table public.documents
  add column if not exists owner_type   text not null default 'club', -- club | athlete | person
  add column if not exists owner_id     uuid,
  add column if not exists doc_type     text,   -- lisans | saglik | kademe | tescil | sertifika | diger
  add column if not exists storage_path text,
  add column if not exists issued_on    date,
  add column if not exists expires_on   date,
  add column if not exists verified     boolean not null default false,
  add column if not exists verified_by  uuid references public.profiles(id) on delete set null,
  add column if not exists note         text,
  add column if not exists uploaded_by  uuid references public.profiles(id) on delete set null;

-- Eski kayıtların sahibi kulüptür.
update public.documents
   set owner_id = club_id
 where owner_id is null;

create index if not exists idx_doc_owner
  on public.documents (owner_type, owner_id);
create index if not exists idx_doc_expiry
  on public.documents (expires_on) where expires_on is not null;


-- Bu belgeyi kim görebilir?
--   • Kulüp belgesi → kulüp görevlisi
--   • Sporcu belgesi → kulüp görevlisi, sporcunun kendisi, velisi
--   • Kişisel belge → yalnızca sahibi
create or replace function public.can_view_document(
  p_owner_type text, p_owner_id uuid, p_club uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case p_owner_type
    when 'club'    then public.is_club_staff(p_club)
    when 'athlete' then public.can_view_athlete_fees(p_owner_id)
                        or public.is_club_staff(p_club)
    when 'person'  then p_owner_id = auth.uid() or public.is_platform_admin()
    else false
  end;
$$;

drop policy if exists "documents_read" on public.documents;
create policy "documents_read" on public.documents for select
  to authenticated
  using (public.can_view_document(owner_type, owner_id, club_id));


create or replace function public.add_document(
  p_club       uuid,
  p_name       text,
  p_owner_type text default 'club',
  p_owner_id   uuid default null,
  p_doc_type   text default null,
  p_path       text default null,
  p_issued     date default null,
  p_expires    date default null,
  p_size       text default null,
  p_note       text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_owner uuid;
begin
  v_owner := coalesce(p_owner_id,
                      case when p_owner_type = 'person' then auth.uid()
                           else p_club end);

  -- Yükleme yetkisi: kulüp/sporcu belgesi kulüp görevlisinden ya da
  -- sporcunun kendisinden/velisinden; kişisel belge yalnızca sahibinden.
  if p_owner_type = 'person' then
    if v_owner <> auth.uid() then raise exception 'Yetkisiz'; end if;
  elsif p_owner_type = 'athlete' then
    if not (public.can_view_athlete_fees(v_owner) or public.is_club_staff(p_club)) then
      raise exception 'Yetkisiz';
    end if;
  else
    if not public.is_club_staff(p_club) then raise exception 'Yetkisiz'; end if;
  end if;

  insert into public.documents
    (club_id, name, kind, size_label, owner_type, owner_id, doc_type,
     storage_path, issued_on, expires_on, note, uploaded_by)
  values (p_club, p_name, coalesce(p_doc_type, 'file'), p_size,
          p_owner_type, v_owner, p_doc_type, p_path, p_issued, p_expires,
          p_note, auth.uid())
  returning id into v_id;

  return v_id;
end; $$;


create or replace function public.verify_document(
  p_document uuid, p_verified boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare v_row record;
begin
  select * into v_row from public.documents where id = p_document;
  if v_row is null then raise exception 'Belge bulunamadı'; end if;
  if not (public.is_platform_admin() or public.is_club_staff(v_row.club_id)) then
    raise exception 'Yetkisiz';
  end if;

  update public.documents
     set verified = p_verified,
         verified_by = case when p_verified then auth.uid() else null end
   where id = p_document;
end; $$;


-- Belge listesi — süre durumu hesaplanmış olarak döner.
create or replace function public.document_list(
  p_club uuid, p_owner_type text default null, p_owner_id uuid default null)
returns table (
  id uuid, name text, doc_type text, storage_path text,
  owner_type text, owner_id uuid, owner_name text,
  issued_on date, expires_on date, verified boolean,
  days_left int, state text, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    d.id, d.name, d.doc_type, d.storage_path,
    d.owner_type, d.owner_id,
    case d.owner_type
      when 'athlete' then (select trim(coalesce(a.first_name,'')||' '||coalesce(a.last_name,''))
                             from public.athletes a where a.id = d.owner_id)
      when 'person'  then (select p.full_name from public.profiles p where p.id = d.owner_id)
      else (select c.name from public.clubs c where c.id = d.owner_id)
    end,
    d.issued_on, d.expires_on, d.verified,
    case when d.expires_on is null then null
         else (d.expires_on - current_date) end,
    case when d.expires_on is null then 'süresiz'
         when d.expires_on < current_date then 'süresi doldu'
         when d.expires_on <= current_date + 30 then 'yakında doluyor'
         else 'geçerli' end,
    d.created_at
  from public.documents d
  where d.club_id = p_club
    and (p_owner_type is null or d.owner_type = p_owner_type)
    and (p_owner_id is null or d.owner_id = p_owner_id)
    and public.can_view_document(d.owner_type, d.owner_id, d.club_id)
  order by (d.expires_on is not null and d.expires_on < current_date) desc,
           d.expires_on nulls last, d.created_at desc;
$$;


-- Süresi dolan belgeler için hatırlatma. Mevcut hatırlatma altyapısına
-- (reminder_log + notifications + push) bağlanır; yeni bir kanal kurulmaz.
create or replace function public.send_document_expiry_reminders()
returns int
language plpgsql security definer set search_path = public as $$
declare v_n int := 0;
begin
  with soon as (
    select d.id, d.name, d.expires_on, d.club_id, d.owner_type, d.owner_id
      from public.documents d
     where d.expires_on in (current_date + 30, current_date + 7, current_date)
  ),
  targets as (
    -- Kulüp belgeleri → kulüp yöneticileri
    select s.id as doc_id, m.profile_id, s.name, s.expires_on
      from soon s
      join public.club_memberships m
        on m.club_id = s.club_id and m.status = 'active'
       and m.role in ('club_admin', 'official')
     where s.owner_type = 'club'
    union
    -- Sporcu belgeleri → sporcu ve velisi
    select s.id, a.profile_id, s.name, s.expires_on
      from soon s
      join public.athletes a on a.id = s.owner_id
     where s.owner_type = 'athlete' and a.profile_id is not null
    union
    select s.id, g.profile_id, s.name, s.expires_on
      from soon s
      join public.guardians g on g.athlete_id = s.owner_id
     where s.owner_type = 'athlete' and g.profile_id is not null
    union
    -- Kişisel belgeler → sahibi
    select s.id, s.owner_id, s.name, s.expires_on
      from soon s
     where s.owner_type = 'person' and s.owner_id is not null
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'document', t.doc_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'document_expiry',
           case when t.expires_on = current_date then 'Belgenin süresi bugün doluyor'
                else 'Belge süresi yaklaşıyor' end,
           t.name || ' · son gün ' || to_char(t.expires_on, 'DD.MM.YYYY'),
           'document', f.entity_id
      from fresh f
      join targets t on t.doc_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;
  return v_n;
end; $$;

do $$ begin perform cron.unschedule('swansport_document_reminders');
exception when others then null; end $$;

select cron.schedule(
  'swansport_document_reminders', '30 6 * * *',
  $$select public.send_document_expiry_reminders();$$);


-- ---------------------------------------------------------------------------
-- 2) VELİ DENEYİMİ
--
-- Veri modeli çoklu çocuğu zaten destekliyordu; eksik olan, çocukların farklı
-- kulüplerde olabildiği durumdu. Uygulama tek "aktif kulüp" varsayıyordu.
-- Bu çağrı her çocuğu kendi kulübüyle birlikte döndürür.
-- ---------------------------------------------------------------------------
create or replace function public.my_children_overview()
returns table (
  athlete_id     uuid,
  full_name      text,
  club_id        uuid,
  club_name      text,
  branch         text,
  attendance_rate int,
  open_fee_count int,
  open_fee_total numeric,
  next_event_at  timestamptz,
  next_event     text,
  health_status  text
)
language sql stable security definer set search_path = public as $$
  select
    a.id,
    trim(coalesce(a.first_name,'') || ' ' || coalesce(a.last_name,'')),
    a.club_id, c.name, a.branch,
    coalesce((
      select round(100.0 * count(*) filter (where at.status = 'present')
                   / nullif(count(*), 0))::int
        from public.attendance at where at.athlete_id = a.id), 0),
    (select count(*) from public.invoices i
      where i.athlete_id = a.id and i.status <> 'paid')::int,
    coalesce((select sum(i.amount) from public.invoices i
      where i.athlete_id = a.id and i.status <> 'paid'), 0),
    (select e.starts_at from public.events e
      where e.club_id = a.club_id and e.starts_at >= now()
      order by e.starts_at limit 1),
    (select e.title from public.events e
      where e.club_id = a.club_id and e.starts_at >= now()
      order by e.starts_at limit 1),
    coalesce((select inj.status::text from public.injuries inj
      where inj.athlete_id = a.id
      order by inj.created_at desc limit 1), 'fit')
  from public.athletes a
  left join public.clubs c on c.id = a.club_id
  where public.can_view_athlete_fees(a.id)
  -- NOT: SQL fonksiyonlarında ORDER BY çıktı sütun adına bakamaz; ifadenin
  -- kendisi tekrarlanmalı.
  order by trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, ''));
$$;


-- ---------------------------------------------------------------------------
-- 3) BİLDİRİM KATEGORİLERİ VE TERCİHLER
--
-- Tasarım ilkesi: kullanıcı bildirim bombardımanına tutulmamalı. Türler yedi
-- kategoriye indirildi; kullanıcı istemediği kategoriyi kapatabiliyor.
-- ---------------------------------------------------------------------------
create or replace function public.notification_category(p_kind text)
returns text language sql immutable as $$
  select case p_kind
    when 'fee_reminder'        then 'aidat'
    when 'payment'             then 'aidat'
    when 'attendance_reminder' then 'antrenman'
    when 'announcement'        then 'federasyon'
    when 'application'         then 'kulup'
    when 'offer'               then 'kulup'
    when 'review'              then 'kritik'
    when 'document_expiry'     then 'kritik'
    when 'donation'            then 'kulup'
    when 'message'             then 'sosyal'
    when 'like'                then 'sosyal'
    when 'comment'             then 'sosyal'
    when 'follow'              then 'sosyal'
    else 'sosyal'
  end;
$$;


create table if not exists public.notification_prefs (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  category   text not null,
  enabled    boolean not null default true,
  primary key (profile_id, category)
);

alter table public.notification_prefs enable row level security;

drop policy if exists "notif_pref_own" on public.notification_prefs;
create policy "notif_pref_own" on public.notification_prefs for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());


-- Kapatılan kategoriye telefon bildirimi gönderilmez.
-- Not: uygulama içi listede yine görünür — kullanıcı isterse bakar, ama
-- telefonu titremez. "Kapat" demek "sil" demek değildir.
create or replace function public.push_allowed(p_profile uuid, p_kind text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select np.enabled from public.notification_prefs np
      where np.profile_id = p_profile
        and np.category = public.notification_category(p_kind)),
    true);
$$;


-- Push tetikleyicisi tercihleri gözetsin.
create or replace function public.push_on_notification()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_subs jsonb;
begin
  if not public.push_allowed(new.profile_id, new.kind) then
    return new;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth)), '[]'::jsonb)
    into v_subs
    from public.push_subscriptions s
   where s.profile_id = new.profile_id;

  if jsonb_array_length(v_subs) = 0 then
    return new;
  end if;

  perform net.http_post(
    url     := 'https://swansport.pages.dev/api/push',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-push-secret', '9958f52564494dea1a2234c511d9948ad0a6f113cfaf68e3'),
    body    := jsonb_build_object(
                 'title', new.title,
                 'body',  coalesce(new.body, ''),
                 'url',   public.push_route(new.kind, new.entity_type),
                 'subs',  v_subs)
  );

  return new;
exception
  when others then return new;
end; $$;


-- Bildirim listesi — kategoriyle birlikte.
create or replace function public.my_notifications(
  p_category text default null, p_limit int default 60)
returns table (
  id uuid, kind text, category text, title text, body text,
  actor_id uuid, entity_type text, entity_id uuid,
  read_at timestamptz, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select n.id, n.kind, public.notification_category(n.kind), n.title, n.body,
         n.actor_id, n.entity_type, n.entity_id, n.read_at, n.created_at
    from public.notifications n
   where n.profile_id = auth.uid()
     and (p_category is null or p_category = ''
          or public.notification_category(n.kind) = p_category)
   order by n.created_at desc
   limit greatest(p_limit, 1);
$$;


create or replace function public.set_notification_pref(
  p_category text, p_enabled boolean)
returns void language sql security definer set search_path = public as $$
  insert into public.notification_prefs (profile_id, category, enabled)
  values (auth.uid(), p_category, p_enabled)
  on conflict (profile_id, category) do update set enabled = excluded.enabled;
$$;


create or replace function public.my_notification_prefs()
returns table (category text, enabled boolean)
language sql stable security definer set search_path = public as $$
  select c.category,
         coalesce((select np.enabled from public.notification_prefs np
                    where np.profile_id = auth.uid()
                      and np.category = c.category), true)
    from (values ('kritik'), ('kulup'), ('antrenman'), ('musabaka'),
                 ('aidat'), ('federasyon'), ('sosyal')) as c(category);
$$;
