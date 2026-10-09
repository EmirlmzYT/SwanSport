-- Parent action center reuses guardians, event_rsvps, documents and support.
set local lock_timeout = '15s';
create index if not exists idx_guardians_profile_athlete on public.guardians(profile_id,athlete_id);

create or replace function public.my_parent_actions()
returns jsonb language plpgsql stable security definer set search_path=public as $fn$
declare result jsonb;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli.'; end if;
  if not exists(select 1 from public.my_feature_flags() f where f.key='parent_hub') then
    raise exception 'Veli işlem merkezi şu anda hesabına açık değil.';
  end if;
  with children as (
    select a.id,a.club_id,a.status,trim(a.first_name||' '||a.last_name) full_name,c.name club_name
    from public.athletes a join public.clubs c on c.id=a.club_id
    where exists(select 1 from public.guardians g where g.athlete_id=a.id and g.profile_id=auth.uid())
  ), ev as (
    select e.id,e.title,e.place,e.starts_at,e.ends_at,c.id athlete_id,c.full_name child_name,
      c.club_id,c.club_name,r.status response,r.updated_at response_at
    from children c join public.events e on e.club_id=c.club_id
    left join public.event_rsvps r on r.event_id=e.id and r.athlete_id=c.id
    where c.status='active' and e.starts_at>now() and e.starts_at<=now()+interval '60 days'
      and (e.team_id is null or exists(select 1 from public.team_memberships tm where tm.team_id=e.team_id and tm.athlete_id=c.id))
      and (r.status is null or r.status='uncertain')
  ), docs as (
    select d.*,c.full_name child_name,c.club_name
    from children c join public.documents d on d.owner_type='athlete' and d.owner_id=c.id and d.club_id=c.club_id
    where d.expires_on<=current_date+30 and public.can_view_document(d.owner_type,d.owner_id,d.club_id)
      -- A valid, verified replacement of the same known type settles the reminder.
      and not exists(select 1 from public.documents newer where d.doc_type is not null
        and newer.owner_type='athlete' and newer.owner_id=d.owner_id and newer.club_id=d.club_id
        and newer.doc_type=d.doc_type and newer.id<>d.id and newer.created_at>d.created_at
        and newer.verified and (newer.expires_on is null or newer.expires_on>current_date+30))
  )
  select jsonb_build_object(
    'children',coalesce((select jsonb_agg(to_jsonb(c) order by c.full_name,c.id) from children c),'[]'::jsonb),
    'events',coalesce((select jsonb_agg(to_jsonb(e) order by e.starts_at,e.id,e.athlete_id) from ev e),'[]'::jsonb),
    'documents',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'doc_type',d.doc_type,
      'owner_type',d.owner_type,'owner_id',d.owner_id,'owner_name',d.child_name,'child_name',d.child_name,
      'club_id',d.club_id,'club_name',d.club_name,'expires_on',d.expires_on,'issued_on',d.issued_on,
      'verified',d.verified,'storage_path',d.storage_path,'created_at',d.created_at,
      'days_left',d.expires_on-current_date,'state',case when d.expires_on<current_date then 'süresi doldu' else 'yakında doluyor' end)
      order by d.expires_on,d.id) from docs d),'[]'::jsonb),
    'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'subject',t.subject,'body',t.body,
      'status',t.status,'created_at',t.created_at) order by t.created_at,t.id)
      from public.support_tickets t where t.profile_id=auth.uid() and t.status='awaiting_user_response'
      and exists(select 1 from children)),'[]'::jsonb)
  ) into result;
  return result;
end $fn$;

-- New name preserves the athlete's existing three-argument RPC contract.
-- expected timestamp prevents a second guardian from silently overwriting a reply.
create or replace function public.set_guardian_event_rsvp(p_event uuid,p_athlete uuid,p_status text,p_expected timestamptz)
returns void language plpgsql security definer set search_path=public as $fn$
declare ev public.events; reply public.event_rsvps; inserted uuid;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli.'; end if;
  if not exists(select 1 from public.my_feature_flags() f where f.key='parent_hub') then
    raise exception 'Veli işlem merkezi şu anda hesabına açık değil.';
  end if;
  if p_status is null or p_status not in ('attending','uncertain','unavailable') then raise exception 'Geçersiz katılım durumu.'; end if;
  perform 1 from public.guardians g where g.profile_id=auth.uid() and g.athlete_id=p_athlete for share;
  if not found then raise exception 'Bu çocuk için yetkin yok.'; end if;
  select * into ev from public.events where id=p_event for share;
  if not found or ev.starts_at<=now() then raise exception 'Etkinlik başlamış veya erişilemiyor.'; end if;
  perform 1 from public.athletes a where a.id=p_athlete and a.club_id=ev.club_id and a.status='active' for update;
  if not found or (ev.team_id is not null and not exists(select 1 from public.team_memberships tm where tm.team_id=ev.team_id and tm.athlete_id=p_athlete)) then
    raise exception 'Çocuk bu etkinliğin kadrosunda değil.';
  end if;
  select * into reply from public.event_rsvps where event_id=p_event and athlete_id=p_athlete for update;
  if found then
    if reply.status=p_status then return; end if;
    if reply.updated_at is distinct from p_expected then raise exception 'Yanıt değişmiş. Listeyi yenileyip tekrar dene.'; end if;
    update public.event_rsvps set status=p_status,updated_at=clock_timestamp() where event_id=p_event and athlete_id=p_athlete;
  else
    if p_expected is not null then raise exception 'Yanıt değişmiş. Listeyi yenileyip tekrar dene.'; end if;
    insert into public.event_rsvps(event_id,athlete_id,status) values(p_event,p_athlete,p_status)
      on conflict do nothing returning event_id into inserted;
    if inserted is null then raise exception 'Yanıt değişmiş. Listeyi yenileyip tekrar dene.'; end if;
  end if;
end $fn$;
revoke all on function public.my_parent_actions() from public,anon;
revoke all on function public.set_guardian_event_rsvp(uuid,uuid,text,timestamptz) from public,anon;
grant execute on function public.my_parent_actions() to authenticated;
grant execute on function public.set_guardian_event_rsvp(uuid,uuid,text,timestamptz) to authenticated;

-- Reuse the existing release flag, without changing its deployed audience.
insert into public.feature_flags(key,audience,label,description) values
 ('parent_hub','admins','Veli merkezi','Bağlı çocukların etkinlik yanıtları, belge tarihleri ve kendi destek yanıtları.') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Veli işlem merkezinde hangi işler görünür?',
 'Profil > Yönetim > Veli İşlem Merkezi veya Veli Paneli kısayolunu aç. Davet koduyla bağlı çocukların önümüzdeki 60 gündeki yanıt verilmemiş veya belirsiz etkinlikleri, süresi dolan ya da 30 gün içinde dolacak belgeleri ve senin yanıtını bekleyen destek talepleri görünür. Çocuğun adına katılım yanıtı verebilirsin. Bu yanıt yoklama veya hukuki izin değildir. Belgeler ilgili çocuğun kulübüne açılır. Yenilenen aynı tür belge kulüpçe doğrulanınca eski uyarı kalkar. Birden çok veli aynı yanıtı değiştirirse listeyi yenilemen istenir.',
 'Veli','everyone',195,'/veli-izinleri','parent_hub'
where not exists(select 1 from public.faq_entries where question='Veli işlem merkezinde hangi işler görünür?' and active);

-- Files in the shared private bucket need the same athlete authorization as rows.
-- Protect the association first: direct staff writes must not attach another
-- user's identity file by spoofing uploaded_by or the club/athlete relationship.
create or replace function public.guard_vault_file_association()
returns trigger language plpgsql security definer set search_path=public as $fn$
begin
  if new.owner_type='athlete' and not exists(select 1 from public.athletes a where a.id=new.owner_id and a.club_id=new.club_id) then
    raise exception 'Belge sahibi bu kulübün sporcusu değil.';
  end if;
  if tg_op='UPDATE' and new.storage_path is not distinct from old.storage_path
     and new.uploaded_by is not distinct from old.uploaded_by
     and new.owner_type is not distinct from old.owner_type
     and new.owner_id is not distinct from old.owner_id
     and new.club_id is not distinct from old.club_id then return new; end if;
  if new.storage_path is not null then
    if auth.uid() is null or split_part(new.storage_path,'/',1)<>auth.uid()::text
       or new.storage_path !~ '^[0-9a-f-]+/belge_[0-9]+[.][a-z0-9]+$'
       or new.storage_path like '%/../%' then raise exception 'Belge dosyası kendi kasana ait olmalı.'; end if;
    new.uploaded_by:=auth.uid();
  end if;
  return new;
end $fn$;
revoke all on function public.guard_vault_file_association() from public,anon,authenticated;
drop trigger if exists trg_guard_vault_file_association on public.documents;
create trigger trg_guard_vault_file_association before insert or update of storage_path,uploaded_by,owner_type,owner_id,club_id
  on public.documents for each row execute function public.guard_vault_file_association();

create or replace function public.can_read_athlete_vault_file(p_path text)
returns boolean language sql stable security definer set search_path=public as $fn$
  select auth.uid() is not null and exists(
    select 1 from public.documents d join public.athletes a on a.id=d.owner_id and a.club_id=d.club_id
    where d.owner_type='athlete' and d.storage_path=p_path and d.uploaded_by is not null
      and split_part(p_path,'/',1)=d.uploaded_by::text
      and p_path ~ '^[0-9a-f-]+/belge_[0-9]+[.][a-z0-9]+$'
      and public.can_view_document(d.owner_type,d.owner_id,d.club_id));
$fn$;
revoke all on function public.can_read_athlete_vault_file(text) from public,anon;
grant execute on function public.can_read_athlete_vault_file(text) to authenticated;
drop policy if exists vdoc_read_athlete_vault on storage.objects;
create policy vdoc_read_athlete_vault on storage.objects for select to authenticated
 using(bucket_id='verification-docs' and public.can_read_athlete_vault_file(name));
