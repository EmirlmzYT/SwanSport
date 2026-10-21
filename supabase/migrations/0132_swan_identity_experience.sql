set local lock_timeout = '15s';

-- Swan ID + athlete experience foundation. Local only until separately deployed.

create table if not exists public.swan_id_cards (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  public_code text not null unique default ('SWN-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  visibility text not null default 'members' check (visibility in ('private','members','public_link')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.swan_id_share_tokens (
  id uuid primary key default gen_random_uuid(), profile_id uuid not null references public.profiles(id) on delete cascade,
  token_hash text not null unique, purpose text not null default 'verify', expires_at timestamptz not null,
  created_by uuid not null references public.profiles(id), revoked_at timestamptz, created_at timestamptz not null default now()
);
create index if not exists swan_id_share_active on public.swan_id_share_tokens(token_hash,expires_at) where revoked_at is null;

create table if not exists public.showcase_videos (
  id uuid primary key default gen_random_uuid(), athlete_id uuid not null references public.athletes(id) on delete cascade,
  owner_profile_id uuid not null references public.profiles(id) on delete cascade,
  title text not null, description text, sport_code text, storage_path text not null unique, cover_path text,
  event_id uuid references public.events(id) on delete set null, match_id uuid references public.org_matches(id) on delete set null,
  duration_seconds int not null check(duration_seconds between 1 and 60), size_bytes bigint not null check(size_bytes between 1 and 104857600),
  mime_type text not null check(mime_type in ('video/mp4','video/quicktime')),
  status text not null default 'draft' check(status in ('draft','pending','published','rejected','archived')),
  discoverable boolean not null default false, guardian_approved_at timestamptz, guardian_approved_by uuid references public.profiles(id),
  club_verified_at timestamptz, club_verified_by uuid references public.profiles(id), rejection_reason text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists showcase_videos_athlete on public.showcase_videos(athlete_id,created_at desc) where status<>'archived';

create table if not exists public.athlete_milestones (
  id uuid primary key default gen_random_uuid(), athlete_id uuid not null references public.athletes(id) on delete cascade,
  source text not null default 'self_added' check(source in ('system','club_verified','self_added')),
  title text not null, summary text, happened_at timestamptz not null, created_by uuid not null references public.profiles(id),
  hidden_at timestamptz, created_at timestamptz not null default now()
);
create index if not exists athlete_milestones_timeline on public.athlete_milestones(athlete_id,happened_at desc) where hidden_at is null;

create table if not exists public.event_preparations (
  event_id uuid primary key references public.events(id) on delete cascade, meeting_at timestamptz,
  equipment text[] not null default '{}', kit_note text, coach_note text,
  updated_by uuid not null references public.profiles(id), updated_at timestamptz not null default now()
);

create table if not exists public.team_kudos (
  id uuid primary key default gen_random_uuid(), event_id uuid not null references public.events(id) on delete cascade,
  sender_profile_id uuid not null references public.profiles(id), receiver_athlete_id uuid not null references public.athletes(id) on delete cascade,
  badge text not null check(badge in ('team_player','fair_play','helpful','determined','motivator')),
  source text not null check(source in ('peer','coach_verified')), hidden_at timestamptz,
  created_at timestamptz not null default now(), unique(event_id,sender_profile_id,receiver_athlete_id)
);
create index if not exists team_kudos_receiver on public.team_kudos(receiver_athlete_id,created_at desc) where hidden_at is null;

create table if not exists public.assistant_intents (
  key text primary key, title text not null, answer text not null, patterns text[] not null,
  audience text[] not null default '{everyone}', feature text references public.feature_flags(key) on delete set null,
  action_key text check(action_key in ('next_event','event_preparation','document_status','open_fees','swan_id','showcase','match_card','help','support')),
  sort_order int not null default 0, active boolean not null default true
);
create table if not exists public.assistant_feedback (
  id uuid primary key default gen_random_uuid(), profile_id uuid references public.profiles(id) on delete set null,
  intent_key text references public.assistant_intents(key) on delete set null, matched boolean not null,
  helpful boolean, created_at timestamptz not null default now()
);

do $$ declare t text; begin foreach t in array array['swan_id_cards','swan_id_share_tokens','showcase_videos','athlete_milestones','event_preparations','team_kudos','assistant_intents','assistant_feedback'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated',t);
end loop; end $$;

create or replace function public._swan_is_minor(p_profile uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select a.birth_date is null or a.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date
    or exists(select 1 from public.guardians g where g.athlete_id=a.id)
    from public.athletes a where a.profile_id=p_profile order by a.created_at limit 1),false)
$$;
create or replace function public._swan_profile_guardian(p_profile uuid,p_viewer uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.athletes a join public.guardians g on g.athlete_id=a.id where a.profile_id=p_profile and g.profile_id=p_viewer)
$$;
create or replace function public._swan_profile_staff(p_profile uuid,p_viewer uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.athletes a join public.club_memberships m on m.club_id=a.club_id and m.profile_id=p_viewer
   where a.profile_id=p_profile and m.status='active' and m.role in ('club_admin','coach'))
$$;
create or replace function public._swan_card_allowed(p_profile uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid()=p_profile or public._swan_profile_guardian(p_profile) or public._swan_profile_staff(p_profile)
   or exists(select 1 from public.swan_id_cards c where c.profile_id=p_profile and c.visibility='members' and auth.uid() is not null and not public._swan_is_minor(p_profile))
$$;

create or replace function public.my_swan_id_card()
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare p uuid:=auth.uid(); result jsonb;
begin
 if p is null then raise exception 'Oturum gerekli';end if;
 if not exists(select 1 from public.profile_credentials c where c.profile_id=p and c.status='approved' and c.kind in('coach','athlete_licensed','athlete_individual'))
    and not exists(select 1 from public.athletes a where a.profile_id=p) then raise exception 'Swan ID için doğrulanmış sporcu veya antrenör kimliği gerekli';end if;
 insert into public.swan_id_cards(profile_id,visibility) values(p,case when public._swan_is_minor(p) then 'private' else 'members' end) on conflict(profile_id) do nothing;
 select jsonb_build_object('public_code',c.public_code,'visibility',c.visibility,'is_minor',public._swan_is_minor(p),
  'full_name',pr.full_name,'avatar_path',pr.avatar_path,
  'roles',coalesce((select jsonb_agg(jsonb_build_object('kind',x.kind,'sport_code',x.sport_code,'coach_level',x.coach_level) order by x.kind,x.sport_code)
    from (select distinct pc.kind,pc.sport_code,pc.coach_level from public.profile_credentials pc where pc.profile_id=p and pc.status='approved' and pc.kind in('coach','athlete_licensed','athlete_individual')) x),'[]'::jsonb),
  'clubs',coalesce((select jsonb_agg(jsonb_build_object('name',cl.name,'role',m.role::text) order by cl.name)
    from public.club_memberships m join public.clubs cl on cl.id=m.club_id where m.profile_id=p and m.status='active'),'[]'::jsonb),
  'athlete_id',(select a.id from public.athletes a where a.profile_id=p order by a.created_at limit 1)) into result
 from public.swan_id_cards c join public.profiles pr on pr.id=c.profile_id where c.profile_id=p;
 return result;
end $$;

create or replace function public.set_my_swan_id_visibility(p_visibility text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if p_visibility not in('private','members','public_link') then raise exception 'Geçersiz görünürlük';end if;
 if public._swan_is_minor(auth.uid()) and p_visibility<>'private' then raise exception 'Çocuk kartı görünürlüğünü veli paylaşım bağlantısıyla yönetir';end if;
 perform public.my_swan_id_card();
 update public.swan_id_cards set visibility=p_visibility,updated_at=now() where profile_id=auth.uid();
end $$;

create or replace function public.create_swan_id_share(p_profile uuid default auth.uid(),p_hours int default 24)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare token text:=encode(gen_random_bytes(24),'hex');
begin
 if auth.uid() is null or p_hours not between 1 and 168 then raise exception 'Geçersiz paylaşım';end if;
 if auth.uid()<>p_profile and not public._swan_profile_guardian(p_profile) then raise exception 'Paylaşım yetkin yok';end if;
 perform 1 from public.swan_id_cards where profile_id=p_profile; if not found then raise exception 'Swan ID bulunamadı';end if;
 insert into public.swan_id_share_tokens(profile_id,token_hash,expires_at,created_by) values(p_profile,encode(digest(token,'sha256'),'hex'),now()+make_interval(hours=>p_hours),auth.uid());
 return token;
end $$;

create or replace function public.verify_swan_id(p_token text)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare p uuid; result jsonb;
begin
 select profile_id into p from public.swan_id_share_tokens where token_hash=encode(digest(coalesce(p_token,''),'sha256'),'hex') and revoked_at is null and expires_at>now();
 if p is null then return jsonb_build_object('valid',false);end if;
 select jsonb_build_object('valid',true,'public_code',c.public_code,'full_name',pr.full_name,'avatar_path',pr.avatar_path,
  'roles',coalesce((select jsonb_agg(jsonb_build_object('kind',x.kind,'sport_code',x.sport_code,'coach_level',x.coach_level)) from
    (select distinct pc.kind,pc.sport_code,pc.coach_level from public.profile_credentials pc where pc.profile_id=p and pc.status='approved' and pc.kind in('coach','athlete_licensed','athlete_individual')) x),'[]'::jsonb)) into result
 from public.swan_id_cards c join public.profiles pr on pr.id=c.profile_id where c.profile_id=p;
 return coalesce(result,jsonb_build_object('valid',false));
end $$;
create or replace function public.revoke_my_swan_id_shares(p_profile uuid default auth.uid())
returns int language plpgsql security definer set search_path=public,pg_temp as $$
declare n int;
begin
 if auth.uid()<>p_profile and not public._swan_profile_guardian(p_profile) then raise exception 'Yetkin yok';end if;
 update public.swan_id_share_tokens set revoked_at=now() where profile_id=p_profile and revoked_at is null;
 get diagnostics n=row_count; return n;
end $$;

create or replace function public._showcase_video_allowed(v public.showcase_videos)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid()=v.owner_profile_id or public.is_guardian_of(v.athlete_id) or public.can_manage_athlete(v.athlete_id)
   or (v.status='published' and not public._swan_is_minor(v.owner_profile_id) and auth.uid() is not null)
$$;
create or replace function public.reserve_showcase_video(p_title text,p_description text,p_sport text,p_duration int,p_size bigint,p_mime text,p_extension text,p_event uuid default null,p_match uuid default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare a public.athletes; vid uuid:=gen_random_uuid(); path text;
begin
 select * into a from public.athletes where profile_id=auth.uid() order by created_at limit 1;
 if a.id is null then raise exception 'Bağlı sporcu kaydı gerekli';end if;
 if p_duration not between 1 and 60 or p_size not between 1 and 104857600 or p_mime not in('video/mp4','video/quicktime') or p_extension not in('mp4','mov') then raise exception 'Video sınırları geçersiz';end if;
 if (select count(*) from public.showcase_videos where athlete_id=a.id and status<>'archived')>=6 then raise exception 'En fazla 6 aktif vitrin videosu olabilir';end if;
 path:=auth.uid()::text||'/'||vid::text||'/video.'||p_extension;
 insert into public.showcase_videos(id,athlete_id,owner_profile_id,title,description,sport_code,storage_path,event_id,match_id,duration_seconds,size_bytes,mime_type)
 values(vid,a.id,auth.uid(),left(trim(p_title),80),nullif(left(trim(coalesce(p_description,'')),500),''),p_sport,path,p_event,p_match,p_duration,p_size,p_mime);
 return jsonb_build_object('id',vid,'storage_path',path);
end $$;
create or replace function public.publish_showcase_video(p_video uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.showcase_videos;
begin
 select * into v from public.showcase_videos where id=p_video for update;
 if v.owner_profile_id<>auth.uid() then raise exception 'Yetkin yok';end if;
 update public.showcase_videos set status=case when public._swan_is_minor(auth.uid()) then 'pending' else 'published' end,updated_at=now() where id=p_video;
end $$;
create or replace function public.review_showcase_video(p_video uuid,p_decision text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.showcase_videos;
begin
 select * into v from public.showcase_videos where id=p_video for update;
 if v.id is null or not public.can_manage_athlete(v.athlete_id) or p_decision not in('approve','reject') then raise exception 'Yetkisiz veya geçersiz karar';end if;
 update public.showcase_videos set club_verified_at=case when p_decision='approve' then now() else null end,club_verified_by=case when p_decision='approve' then auth.uid() else null end,
   discoverable=p_decision='approve' and (not public._swan_is_minor(owner_profile_id) or guardian_approved_at is not null),status=case when p_decision='reject' then 'rejected' else status end,updated_at=now() where id=p_video;
end $$;
create or replace function public.guardian_approve_showcase_video(p_video uuid,p_approved boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.showcase_videos;
begin
 select * into v from public.showcase_videos where id=p_video for update;
 if v.id is null or not public.is_guardian_of(v.athlete_id) then raise exception 'Veli onay yetkin yok';end if;
 update public.showcase_videos set guardian_approved_at=case when p_approved then now() else null end,
   guardian_approved_by=case when p_approved then auth.uid() else null end,
   status=case when p_approved and status='pending' then 'published' when not p_approved then 'rejected' else status end,
   discoverable=p_approved and club_verified_at is not null,updated_at=now() where id=p_video;
end $$;
create or replace function public.archive_showcase_video(p_video uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin update public.showcase_videos set status='archived',discoverable=false,updated_at=now() where id=p_video and owner_profile_id=auth.uid();if not found then raise exception 'Video bulunamadı';end if;end $$;
create or replace function public.my_showcase_videos()
returns setof jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('id',v.id,'athlete_id',v.athlete_id,'title',v.title,'description',v.description,'sport_code',v.sport_code,'storage_path',v.storage_path,
   'cover_path',v.cover_path,'event_id',v.event_id,'match_id',v.match_id,'duration_seconds',v.duration_seconds,'status',v.status,'discoverable',v.discoverable,
   'club_verified',v.club_verified_at is not null,'guardian_approved',v.guardian_approved_at is not null,'created_at',v.created_at)
 from public.showcase_videos v where public._showcase_video_allowed(v) order by v.created_at desc
$$;

create or replace function public.athlete_journey(p_athlete uuid)
returns setof jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if not exists(select 1 from public.athletes a where a.id=p_athlete and (a.profile_id=auth.uid() or public.is_guardian_of(a.id) or public.can_manage_athlete(a.id))) then raise exception 'Erişim yok';end if;
 return query
 select x from (
  select jsonb_build_object('id','membership:'||m.id,'kind','membership','source','system','happened_at',m.created_at,'title',c.name||' kulübüne katıldı','summary',m.role::text) x,m.created_at t
   from public.athletes a join public.club_memberships m on m.profile_id=a.profile_id join public.clubs c on c.id=m.club_id where a.id=p_athlete
  union all select jsonb_build_object('id','achievement:'||ac.id,'kind','achievement','source',case when ac.verified then 'club_verified' else 'self_added' end,'happened_at',coalesce(ac.event_date::timestamptz,ac.created_at),'title',ac.title,'summary',ac.category),coalesce(ac.event_date::timestamptz,ac.created_at) from public.athlete_achievements ac where ac.athlete_id=p_athlete
  union all select jsonb_build_object('id','video:'||v.id,'kind','video','source',case when v.club_verified_at is null then 'self_added' else 'club_verified' end,'happened_at',v.created_at,'title',v.title,'summary','Vitrin videosu'),v.created_at from public.showcase_videos v where v.athlete_id=p_athlete and v.status='published'
  union all select jsonb_build_object('id','milestone:'||am.id,'kind','milestone','source',am.source,'happened_at',am.happened_at,'title',am.title,'summary',am.summary),am.happened_at from public.athlete_milestones am where am.athlete_id=p_athlete and am.hidden_at is null
  union all select jsonb_build_object('id','attendance:'||max(at.event_id),'kind','attendance','source','system','happened_at',max(e.starts_at),'title',count(*)::text||' antrenmana katıldı','summary','Katılım kilometre taşı'),max(e.starts_at) from public.attendance at join public.events e on e.id=at.event_id where at.athlete_id=p_athlete and at.status='present' having count(*)>0
 ) q(x,t) order by t desc;
end $$;
create or replace function public.add_athlete_milestone(p_athlete uuid,p_title text,p_summary text,p_happened_at timestamptz)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid;
begin
 if not exists(select 1 from public.athletes a where a.id=p_athlete and a.profile_id=auth.uid()) then raise exception 'Yalnız kendi gelişim kaydını ekleyebilirsin';end if;
 if coalesce(trim(p_title),'')='' or p_happened_at>now()+interval '1 day' then raise exception 'Geçersiz gelişim kaydı';end if;
 insert into public.athlete_milestones(athlete_id,title,summary,happened_at,created_by) values(p_athlete,left(trim(p_title),100),nullif(left(trim(coalesce(p_summary,'')),500),''),p_happened_at,auth.uid()) returning id into result;return result;
end $$;

create or replace function public.set_event_preparation(p_event uuid,p_meeting timestamptz,p_equipment text[],p_kit text,p_note text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare c uuid;
begin select club_id into c from public.events where id=p_event; if c is null or not public.is_club_staff(c) then raise exception 'Yetkin yok';end if;
 insert into public.event_preparations(event_id,meeting_at,equipment,kit_note,coach_note,updated_by) values(p_event,p_meeting,coalesce(p_equipment,'{}'),nullif(left(trim(coalesce(p_kit,'')),200),''),nullif(left(trim(coalesce(p_note,'')),500),''),auth.uid())
 on conflict(event_id) do update set meeting_at=excluded.meeting_at,equipment=excluded.equipment,kit_note=excluded.kit_note,coach_note=excluded.coach_note,updated_by=auth.uid(),updated_at=now();
end $$;
create or replace function public.my_event_preparation(p_event uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare a uuid; result jsonb;
begin
 select candidate.id into a
 from public.events e
 join lateral (
   select own.id,case when own.profile_id=auth.uid() then 0 else 1 end priority
   from public.athletes own
   where own.club_id=e.club_id
     and (own.profile_id=auth.uid() or public.is_guardian_of(own.id))
     and (e.team_id is null or exists(select 1 from public.team_memberships tm where tm.athlete_id=own.id and tm.team_id=e.team_id))
   order by priority,own.created_at
   limit 1
 ) candidate on true
 where e.id=p_event;
 if not exists(select 1 from public.events e where e.id=p_event and (public.is_club_staff(e.club_id) or a is not null)) then raise exception 'Erişim yok';end if;
 select jsonb_build_object('event_id',e.id,'title',e.title,'starts_at',e.starts_at,'place',e.place,'meeting_at',p.meeting_at,'equipment',coalesce(p.equipment,'{}'),'kit_note',p.kit_note,'coach_note',p.coach_note,
   'rsvp',(select r.status from public.event_rsvps r where r.event_id=e.id and r.athlete_id=a)) into result from public.events e left join public.event_preparations p on p.event_id=e.id where e.id=p_event;
 return result;
end $$;

create or replace function public.send_team_kudos(p_event uuid,p_receiver uuid,p_badge text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare sender_athlete uuid; eid uuid; src text;
begin
 if p_badge not in('team_player','fair_play','helpful','determined','motivator') then raise exception 'Geçersiz rozet';end if;
 if not exists(select 1 from public.events e where e.id=p_event and e.starts_at<now()) then raise exception 'Etkinlik henüz tamamlanmadı';end if;
 select a.id into sender_athlete from public.athletes a join public.events e on e.club_id=a.club_id where a.profile_id=auth.uid() and e.id=p_event limit 1;
 src:=case when exists(select 1 from public.events e where e.id=p_event and public.is_club_staff(e.club_id)) then 'coach_verified' else 'peer' end;
 if src='peer' and (sender_athlete is null or sender_athlete=p_receiver or not exists(select 1 from public.attendance x where x.event_id=p_event and x.athlete_id=sender_athlete and x.status='present')) then raise exception 'Bu etkinlik için rozet veremezsin';end if;
 if not exists(select 1 from public.attendance x where x.event_id=p_event and x.athlete_id=p_receiver and x.status='present') then raise exception 'Alıcı etkinliğe katılmamış';end if;
 if exists(select 1 from public.athletes a where a.id=p_receiver and (a.profile_id is null or public.is_blocked_between(auth.uid(),a.profile_id))) then raise exception 'Bu sporcuya rozet gönderemezsin';end if;
 if (select count(distinct receiver_athlete_id) from public.team_kudos where event_id=p_event and sender_profile_id=auth.uid())>=3 then raise exception 'Bu etkinlik için rozet sınırına ulaştın';end if;
 insert into public.team_kudos(event_id,sender_profile_id,receiver_athlete_id,badge,source) values(p_event,auth.uid(),p_receiver,p_badge,src) returning id into eid; return eid;
end $$;
create or replace function public.my_team_kudos()
returns setof jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('id',k.id,'event_id',k.event_id,'badge',k.badge,'source',k.source,'created_at',k.created_at)
 from public.team_kudos k join public.athletes a on a.id=k.receiver_athlete_id where a.profile_id=auth.uid() and k.hidden_at is null order by k.created_at desc limit 100
$$;

create or replace function public.my_athlete_match_card(p_match uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare a uuid; participant uuid; side text; header jsonb;
begin
 select id into a from public.athletes where profile_id=auth.uid() order by created_at limit 1; if a is null then raise exception 'Sporcu kaydı gerekli';end if;
 select l.participant_id,case when l.participant_id=m.home_id then 'home' else 'away' end into participant,side from public.org_matches m join public.match_lineup_approvals l on l.match_id=m.id and l.participant_id in(m.home_id,m.away_id)
 where m.id=p_match and a=any(l.starter_athlete_ids||l.substitute_athlete_ids) limit 1;
 header:=public._public_match_header(p_match); if header is null then raise exception 'Resmi maç bulunamadı';end if;
 return header||jsonb_build_object('athlete_id',a,'participant_id',participant,'side',side,'lineup_status',case when participant is null then 'not_shared' else 'approved' end,
  'showcase_videos',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'title',v.title)) from public.showcase_videos v where v.match_id=p_match and v.athlete_id=a and v.status='published'),'[]'::jsonb));
end $$;
create or replace function public.my_athlete_match_cards()
returns setof jsonb language sql stable security definer set search_path=public,pg_temp as $$
 with mine as(select id from public.athletes where profile_id=auth.uid() order by created_at limit 1)
 select public.my_athlete_match_card(m.id) from public.org_matches m join public.match_lineup_approvals l on l.match_id=m.id
 where exists(select 1 from mine a where a.id=any(l.starter_athlete_ids||l.substitute_athlete_ids))
 order by m.starts_at desc nulls last limit 30
$$;

create or replace function public.search_swan_assistant(p_query text,p_audience text[],p_features text[])
returns setof jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('key',i.key,'title',i.title,'answer',i.answer,'action_key',i.action_key,'feature',i.feature)
 from public.assistant_intents i where i.active and (i.audience&&coalesce(p_audience,'{everyone}') or 'everyone'=any(i.audience))
 and (i.feature is null or i.feature=any(coalesce(p_features,'{}')))
 and (coalesce(trim(p_query),'')='' or public.tr_contains(i.title,p_query) or public.tr_contains(i.answer,p_query) or exists(select 1 from unnest(i.patterns) p where public.tr_contains(p,p_query) or public.tr_contains(p_query,p)))
 order by i.sort_order,i.title limit 12
$$;
create or replace function public.record_assistant_feedback(p_intent text,p_matched boolean,p_helpful boolean default null)
returns void language sql security definer set search_path=public,pg_temp as $$
 insert into public.assistant_feedback(profile_id,intent_key,matched,helpful) values(auth.uid(),p_intent,p_matched,p_helpful)
$$;

-- Private media bucket: paths are owner_profile/video_id/video.ext.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('athlete-showcase','athlete-showcase',false,104857600,array['video/mp4','video/quicktime'])
on conflict(id) do update set public=false,file_size_limit=104857600,allowed_mime_types=array['video/mp4','video/quicktime'];
drop policy if exists showcase_upload_own on storage.objects;
create policy showcase_upload_own on storage.objects for insert to authenticated with check(bucket_id='athlete-showcase' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.showcase_videos v where v.storage_path=name and v.owner_profile_id=auth.uid()));
drop policy if exists showcase_read_allowed on storage.objects;
create policy showcase_read_allowed on storage.objects for select to authenticated using(bucket_id='athlete-showcase' and exists(select 1 from public.showcase_videos v where v.storage_path=name and public._showcase_video_allowed(v)));
drop policy if exists showcase_delete_own on storage.objects;
create policy showcase_delete_own on storage.objects for delete to authenticated using(bucket_id='athlete-showcase' and (storage.foldername(name))[1]=auth.uid()::text);

do $$ declare f record; begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in
 ('_swan_is_minor','_swan_profile_guardian','_swan_profile_staff','_swan_card_allowed','_showcase_video_allowed','my_swan_id_card','set_my_swan_id_visibility','create_swan_id_share','verify_swan_id','revoke_my_swan_id_shares','reserve_showcase_video','publish_showcase_video','review_showcase_video','guardian_approve_showcase_video','archive_showcase_video','my_showcase_videos','athlete_journey','add_athlete_milestone','set_event_preparation','my_event_preparation','send_team_kudos','my_team_kudos','my_athlete_match_card','my_athlete_match_cards','search_swan_assistant','record_assistant_feedback') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);end loop;end $$;
grant execute on function public.my_swan_id_card(),public.set_my_swan_id_visibility(text),public.create_swan_id_share(uuid,int),public.revoke_my_swan_id_shares(uuid),public.reserve_showcase_video(text,text,text,int,bigint,text,text,uuid,uuid),public.publish_showcase_video(uuid),public.review_showcase_video(uuid,text),public.guardian_approve_showcase_video(uuid,boolean),public.archive_showcase_video(uuid),public.my_showcase_videos(),public.athlete_journey(uuid),public.add_athlete_milestone(uuid,text,text,timestamptz),public.set_event_preparation(uuid,timestamptz,text[],text,text),public.my_event_preparation(uuid),public.send_team_kudos(uuid,uuid,text),public.my_team_kudos(),public.my_athlete_match_card(uuid),public.my_athlete_match_cards(),public.search_swan_assistant(text,text[],text[]),public.record_assistant_feedback(text,boolean,boolean) to authenticated;
grant execute on function public.verify_swan_id(text) to anon,authenticated;

insert into public.feature_flags(key,audience,label,description) values
 ('swan_id','admins','Swan ID','Doğrulanmış dijital spor kimliği.'),
 ('athlete_showcase','admins','Sporcu vitrini','Kontrollü ve doğrulanabilir sporcu video portföyü.'),
 ('swan_assistant','admins','Swan Asistan','Modelsiz, izinli eylemlerle çalışan uygulama rehberi.'),
 ('athlete_journey','admins','Sporcu gelişim çizelgesi','Sporcunun doğrulanmış gelişim geçmişi.'),
 ('event_preparation','admins','Antrenman hazırlık kartı','Etkinlik saati, ekipman ve katılım hazırlığı.'),
 ('team_kudos','admins','Takım içi olumlu geri bildirim','Etkinliğe bağlı sınırlı olumlu takım rozetleri.'),
 ('athlete_match_card','admins','Dijital maç kartı','Sporcuya özel resmi maç ve turnuva kartı.')
on conflict(key) do nothing;

insert into public.assistant_intents(key,title,answer,patterns,audience,feature,action_key,sort_order) values
 ('next_event','Sıradaki etkinliğim ne zaman?','Yaklaşan programını açıp sıradaki etkinliğini görebilirsin.',array['antrenman ne zaman','maçım ne zaman','programım'],'{athlete,coach}','swan_assistant','next_event',10),
 ('prepare_event','Bugün yanıma ne almalıyım?','Sıradaki etkinliğinin buluşma, ekipman ve kıyafet bilgisini hazırlık kartında görebilirsin.',array['ne götüreceğim','forma','ekipman','nerede buluşacağız'],'{athlete,parent}','event_preparation','event_preparation',20),
 ('open_swan_id','Swan ID kartımı göster','Doğrulanmış spor kimliğini ve paylaşım seçeneklerini açabilirsin.',array['kimliğim','qr kartım','sporcu kartım'],'{athlete,coach}','swan_id','swan_id',30),
 ('open_showcase','Video vitrinimi aç','Sporcu videolarını güvenli vitrinin üzerinden yönetebilirsin.',array['videolarım','vitrin','video yükle'],'{athlete}','athlete_showcase','showcase',40),
 ('open_match_card','Maç kartımı göster','Resmi maçın kesinleşen esame, tesis, canlı skor ve sonuç bilgisini açabilirsin.',array['kadrodaki durumum','maç bilgim','esame'],'{athlete}','athlete_match_card','match_card',50)
on conflict(key) do update set title=excluded.title,answer=excluded.answer,patterns=excluded.patterns,audience=excluded.audience,feature=excluded.feature,action_key=excluded.action_key,sort_order=excluded.sort_order,active=true;

insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature) values
 ('Swan ID nedir?','Swan ID, onaylanmış sporcu ve antrenör rollerini gösteren dijital spor kimliğidir. Kimlik, sağlık, iletişim ve belge dosyalarını göstermez.','profil','everyone',132,'/swan-id','swan_id'),
 ('Sporcu vitrini videolarımı kimler görebilir?','Yetişkin videoları üye görünürlüğünde yayımlanabilir. Çocuk videolarının dış görünürlüğü veli, keşfet görünürlüğü ayrıca kulüp onayı ister.','profil','athlete',133,'/swan-id','athlete_showcase'),
 ('Swan Asistan nasıl çalışır?','Swan Asistan bir yapay zekâ modeli kullanmaz. Hazır soruları ve izinli uygulama eylemlerini eşleştirir; bilmediği konuda cevap uydurmaz.','yardım','everyone',134,'/swan-asistan','swan_assistant'),
 ('Antrenman hazırlık kartında ne bulunur?','Buluşma saati, konum, ekipman, kıyafet notu ve katılım yanıtın tek kartta görünür.','antrenman','athlete',135,'/calendar','event_preparation'),
 ('Takım rozetleri nasıl verilir?','Tamamlanmış etkinliğe katılan takım arkadaşları sınırlı sayıda olumlu rozet verebilir. Sıralama ve olumsuz değerlendirme yoktur.','takım','athlete',136,'/swan-id','team_kudos'),
 ('Dijital maç kartı hangi bilgileri gösterir?','Yalnız resmi maç kaynağındaki kesinleşmiş esame, tesis, desteklenen canlı skor ve güncel resmi sonuç gösterilir.','spor','athlete',137,'/swan-id','athlete_match_card')
on conflict do nothing;
