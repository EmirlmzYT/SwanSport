-- Official club roster authority and guardian result delivery. No live execution.
set local lock_timeout = '15s';

create or replace function public._require_head_coach(p_club uuid,p_sport text)
returns void language plpgsql security definer set search_path=public as $$
begin
 perform 1 from public.profile_credentials where profile_id=auth.uid() and kind='coach' and sport_code=p_sport for share;
 perform 1 from public.club_memberships m where m.club_id=p_club and m.profile_id=auth.uid()
 and m.status='active' and (m.role='club_admin' or (m.role='coach' and public.coach_level_for_sport(auth.uid(),p_sport)>=3)) for share;
 if not found then raise exception 'Resmi maç kadrosunu kilitlemek için en az 3. Kademe Başantrenör belgesi veya kulüp yöneticiliği gereklidir' using errcode='42501';end if;
end $$;

revoke all on function public.federation_publish_roster(uuid,uuid[],text,int) from public,anon,authenticated;
grant execute on function public.federation_publish_roster(uuid,uuid[],text,int) to authenticated;

-- Read-only official squad list for active club coaches/managers, including assistants.
create or replace function public.official_team_rosters(p_team uuid)
returns table(participant_id uuid,name text,sport_code text,version int,athlete_ids uuid[])
language sql stable security definer set search_path=public as $$
 select p.id,o.name,o.sport_code,coalesce(r.version,0),coalesce(r.athlete_ids,'{}'::uuid[])
 from public.teams t join public.org_participants p on p.club_id=t.club_id and (p.team_id=t.id or p.team_id is null)
 join public.organizations o on o.id=p.org_id and o.official and o.sport_code=t.sport_code
 left join lateral(select rr.version,rr.athlete_ids from public.org_roster_revisions rr where rr.participant_id=p.id order by rr.version desc limit 1) r on true
 where t.id=p_team and p.status='accepted' and exists(select 1 from public.club_memberships m
 where m.club_id=t.club_id and m.profile_id=auth.uid() and m.status='active' and m.role in('club_admin','coach'))
 order by o.starts_on,p.id
$$;
revoke all on function public.official_team_rosters(uuid) from public,anon,authenticated;
grant execute on function public.official_team_rosters(uuid) to authenticated;

alter table public.notifications add column if not exists result_revision_id uuid;
revoke all on public.notifications from public,anon;
-- entity_id is the child UUID; no snapshot of any other roster member is stored.
create unique index if not exists guardian_result_notification_once
 on public.notifications(profile_id,entity_id,result_revision_id) where kind='match_result';

create or replace function public._notify_guardian_official_result()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.result_version<=old.result_version then return new;end if;
 insert into public.notifications(profile_id,kind,title,body,entity_type,entity_id,result_revision_id)
 select distinct g.profile_id,'match_result',trim(a.first_name||' '||a.last_name)||' - Müsabaka Sonucu Açıklandı',
 o.name||' skoru ve resmi derecesi federasyon tarafından sisteme işlendi.'||case when rv.version>1 then ' Sonuç düzeltildi (revizyon '||rv.version||').' else '' end,
 'official_result',a.id,rv.id
 from public.org_result_revisions rv join public.organizations o on o.id=new.org_id and o.official
 join public.org_roster_revisions rr on rr.id in(rv.home_roster_revision_id,rv.away_roster_revision_id)
 join public.athletes a on a.id=any(rr.athlete_ids)
 join public.guardians g on g.athlete_id=a.id and g.profile_id is not null
 where rv.match_id=new.id and rv.version=new.result_version
 and (a.birth_date is null or a.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date)
 on conflict do nothing;
 return new;
end $$;
revoke all on function public._notify_guardian_official_result() from public,anon,authenticated;
drop trigger if exists guardian_official_result on public.org_matches;
create trigger guardian_official_result after update of result_version on public.org_matches
 for each row execute function public._notify_guardian_official_result();

-- This reservation also prevents the old PUBLIC push_notification helper from forging official notices.
revoke all on function public.push_notification(uuid,text,text,text,uuid,text,uuid) from public,anon,authenticated;
drop policy if exists official_notification_insert on public.notifications;
create policy official_notification_insert on public.notifications as restrictive for insert to authenticated
 with check(kind<>'match_result');
drop policy if exists official_notification_update on public.notifications;
create policy official_notification_update on public.notifications as restrictive for update to authenticated
 using(kind<>'match_result') with check(kind<>'match_result');

create or replace function public._guardian_result_visible(p_child uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and exists(select 1 from public.guardians g where g.profile_id=auth.uid() and g.athlete_id=p_child)
$$;
revoke all on function public._guardian_result_visible(uuid) from public,anon,authenticated;
-- Policy helper contains no private output and is callable only with an authenticated session.
grant execute on function public._guardian_result_visible(uuid) to authenticated;
drop policy if exists official_notification_read on public.notifications;
create policy official_notification_read on public.notifications as restrictive for select to authenticated
 using(kind<>'match_result' or public._guardian_result_visible(entity_id));

create or replace function public.my_notifications(p_category text default null,p_limit int default 60)
returns table(id uuid,kind text,category text,title text,body text,actor_id uuid,entity_type text,entity_id uuid,read_at timestamptz,created_at timestamptz)
language sql stable security definer set search_path=public as $$
 select n.id,n.kind,public.notification_category(n.kind),n.title,n.body,n.actor_id,n.entity_type,n.entity_id,n.read_at,n.created_at
 from public.notifications n where n.profile_id=auth.uid() and n.kind<>'message'
 and (n.kind<>'match_result' or public._guardian_result_visible(n.entity_id))
 and (coalesce(p_category,'')='' or public.notification_category(n.kind)=p_category)
 order by n.created_at desc limit least(greatest(p_limit,1),200)
$$;
revoke all on function public.my_notifications(text,int) from public,anon,authenticated;
grant execute on function public.my_notifications(text,int) to authenticated;

-- Read marking stays possible, without permitting edits to an official notification payload.
create or replace function public.mark_notifications_read(p_notification uuid default null)
returns void language sql security definer set search_path=public as $$
 update public.notifications n set read_at=coalesce(n.read_at,clock_timestamp()) where n.profile_id=auth.uid() and n.kind<>'message'
 and (p_notification is null or n.id=p_notification)
 and (n.kind<>'match_result' or public._guardian_result_visible(n.entity_id))
$$;
revoke all on function public.mark_notifications_read(uuid) from public,anon,authenticated;
grant execute on function public.mark_notifications_read(uuid) to authenticated;

-- Numeric result status is computed server-side, never from a user-supplied team.
create or replace function public._guardian_result_summary(p_revision uuid,p_child uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare r public.org_result_revisions;m public.org_matches;o public.organizations;h int;a int;side_home boolean;outcome text:='recorded';item jsonb;v_note text;
begin
 select rv.* into r from public.org_result_revisions rv where rv.id=p_revision;
 select mm.* into m from public.org_matches mm where mm.id=r.match_id;
 select oo.* into o from public.organizations oo where oo.id=m.org_id and oo.official;
 if o.id is null or not exists(select 1 from public.org_roster_revisions rr where rr.id in(r.home_roster_revision_id,r.away_roster_revision_id) and p_child=any(rr.athlete_ids)) then
  raise exception 'Resmi sonuç erişimi yok' using errcode='42501';end if;
 select p_child=any(rr.athlete_ids) into side_home from public.org_roster_revisions rr where rr.id=r.home_roster_revision_id;
 if r.protocol->>'type'='score' then h:=(r.protocol->>'home')::int;a:=(r.protocol->>'away')::int;
 elsif r.protocol->>'type'='sets' then
  select count(*) filter(where (e->>'home')::int>(e->>'away')::int),count(*) filter(where (e->>'away')::int>(e->>'home')::int) into h,a from jsonb_array_elements(r.protocol->'sets') e;
 end if;
 if h is not null then
  v_note:=h||'–'||a;
  if o.sport_code='futbol' and h=a and jsonb_typeof(r.match_protocol->'penalties')='array' then
   select count(*) filter(where e->>'team'='home' and e->>'scored'='true'),count(*) filter(where e->>'team'='away' and e->>'scored'='true') into h,a from jsonb_array_elements(r.match_protocol->'penalties') e;
   v_note:=v_note||' · Seri penaltılar '||h||'–'||a;
  end if;
  outcome:=case when h=a then 'draw' when (h>a)=coalesce(side_home,false) then 'won' else 'lost' end;
 else
  select e into item from jsonb_array_elements(coalesce(r.protocol->'entries','[]'::jsonb)) e where e->>'athlete_id'=p_child::text order by (e->>'placement')::int limit 1;
  if item is not null then
   v_note:=(item->>'placement')||'. (seri) · '||(item->>'value');
   -- Reuse the official per-child CV summary, including every heat and its unit.
   v_note:=coalesce((select ac.note from public.athlete_achievements ac
    where ac.athlete_id=p_child and ac.source='federation_result' and ac.source_id=r.id limit 1),v_note);
  else
   select e into item from jsonb_array_elements(coalesce(r.match_protocol->'performances','[]'::jsonb)) e where e->>'athlete_ref'=p_child::text limit 1;
   outcome:=case when item->>'dq'='true' then 'dq' when item->>'dnf'='true' then 'dnf' else 'recorded' end;
   v_note:=case when outcome='dq' then 'Diskalifiye (DQ)' when outcome='dnf' then 'Tamamlamadı (DNF)' else 'Resmi sonuç kaydedildi' end;
  end if;
 end if;
 return jsonb_build_object('match_id',m.id,'name',o.name,'sport_code',o.sport_code,'version',r.version,'current_version',m.result_version,
 'starts_at',m.starts_at,'location',m.location,'result',v_note,'outcome',outcome,'scores',public._official_source_scores(o.sport_code,r.match_protocol,r.protocol));
end $$;
revoke all on function public._guardian_result_summary(uuid,uuid) from public,anon,authenticated;

create or replace function public.guardian_notification_result(p_notification uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare n public.notifications;
begin
 select nn.* into n from public.notifications nn where nn.id=p_notification and nn.profile_id=auth.uid() and nn.kind='match_result';
 if n.id is null or not public._guardian_result_visible(n.entity_id) then raise exception 'Resmi sonuç erişimi yok' using errcode='42501';end if;
 return public._guardian_result_summary(n.result_revision_id,n.entity_id)||jsonb_build_object('child_name',(select trim(a.first_name||' '||a.last_name) from public.athletes a where a.id=n.entity_id));
end $$;
revoke all on function public.guardian_notification_result(uuid) from public,anon,authenticated;
grant execute on function public.guardian_notification_result(uuid) to authenticated;

create or replace function public.guardian_match_result(p_match uuid,p_athlete uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare r uuid;
begin
 if not public._guardian_result_visible(p_athlete) then raise exception 'Resmi sonuç erişimi yok' using errcode='42501';end if;
 select rv.id into r from public.org_result_revisions rv join public.org_matches m on m.id=rv.match_id and m.result_version=rv.version where m.id=p_match;
 return public._guardian_result_summary(r,p_athlete)||jsonb_build_object('child_name',(select trim(a.first_name||' '||a.last_name) from public.athletes a where a.id=p_athlete));
end $$;
revoke all on function public.guardian_match_result(uuid,uuid) from public,anon,authenticated;
grant execute on function public.guardian_match_result(uuid,uuid) to authenticated;

drop function if exists public.guardian_calendar_results(timestamptz,timestamptz);
create or replace function public.guardian_calendar_results(p_from timestamptz,p_to timestamptz)
returns table(notification_id uuid,child_id uuid,child_name text,starts_at timestamptz,summary jsonb)
language sql stable security definer set search_path=public as $$
 select n.id,a.id,trim(a.first_name||' '||a.last_name),m.starts_at,public._guardian_result_summary(rv.id,a.id)
 from public.org_matches m join public.organizations o on o.id=m.org_id and o.official
 join public.org_result_revisions rv on rv.match_id=m.id and m.result_version=rv.version
 join public.athletes a on exists(select 1 from public.org_roster_revisions rr where rr.id in(rv.home_roster_revision_id,rv.away_roster_revision_id) and a.id=any(rr.athlete_ids))
 left join public.notifications n on n.profile_id=auth.uid() and n.kind='match_result' and n.entity_id=a.id and n.result_revision_id=rv.id
 where public._guardian_result_visible(a.id)
 and m.starts_at>=p_from and m.starts_at<p_to and p_to<=p_from+interval '32 days'
 order by m.starts_at,a.id
$$;
revoke all on function public.guardian_calendar_results(timestamptz,timestamptz) from public,anon,authenticated;
grant execute on function public.guardian_calendar_results(timestamptz,timestamptz) to authenticated;
revoke all on function public._require_head_coach(uuid,text) from public,anon,authenticated;

create or replace function public.federation_publish_roster(p_participant uuid,p_athletes uuid[],p_reason text,p_expected_version int)
returns uuid language plpgsql security definer set search_path=public as $$
declare p public.org_participants;o public.organizations;a uuid;v uuid;n int;
begin
 perform public._c1_actor_for_club((select club_id from public.org_participants where id=p_participant));
 select * into p from public.org_participants where id=p_participant for update;
 select * into o from public.organizations where id=p.org_id and official;
 if o.id is null or p.status<>'accepted' then raise exception 'Kabul edilmiş resmi program katılımcısı gerekli';end if;
 perform public._require_head_coach(p.club_id,o.sport_code);
 select coalesce(max(version),0) into n from public.org_roster_revisions where participant_id=p.id;
 if p_expected_version is distinct from n then raise exception 'Kadro sürümü değişti'; end if;
 if p_reason is null or length(trim(p_reason)) not between 1 and 500 or cardinality(p_athletes) not between 1 and 200
 or p_athletes is null or array_position(p_athletes,null) is not null
 or cardinality(p_athletes)<>(select count(distinct x) from unnest(p_athletes) x) then raise exception 'Kadro/gerekçe geçersiz'; end if;
 if exists(select 1 from unnest(p_athletes) x where not exists(select 1 from public.athletes at
 join public.athlete_sport_registrations r on r.athlete_id=at.id
 where at.id=x and r.sport_code=o.sport_code and r.club_id=p.club_id and r.expires_on>=o.ends_on
 and (p.team_id is null or exists(select 1 from public.team_memberships tm where tm.team_id=p.team_id and tm.athlete_id=at.id))
 and not exists(select 1 from public.eligibility_gate(at.id) g where g.blocked and g.reason_code<>'license_expired'))) then raise exception 'Kadro branş/kulüp/takım/lisans/uygunluk şartını karşılamıyor'; end if;
 perform public._c1_require_athlete(x,p.club_id,o.sport_code) from unnest(p_athletes) x;
 insert into public.org_roster_revisions(participant_id,version,athlete_ids,reason,actor_id) values(p.id,n+1,p_athletes,p_reason,auth.uid()) returning id into v;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail) values(auth.uid(),a,'roster_revision',v,jsonb_build_object('version',n+1));return v;
end $$;

create or replace function public.push_route(p_kind text, p_entity text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'match_result'              then '/resmi-sonuc'
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'fee'                       then '/aidatlarim'
    when 'fee_reminder'              then '/aidatlarim'
    when 'payment'                   then '/finans'
    when 'donation'                  then '/bagis'
    when 'attendance'                then '/attendance'
    when 'attendance_reminder'       then '/attendance'
    when 'event'                     then '/calendar'
    when 'announcement'              then '/announcements'
    when 'achievement'               then '/performance-analytics'
    when 'document'                  then '/documents'
    when 'documents'                 then '/documents'
    when 'document_expiry'           then '/documents'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    when 'turf_field'                then '/halisahalar'
    when 'turf_manager'              then '/halisahalar'
    when 'store_decision'            then '/magaza-basvuru'
    when 'moderation'                then '/pazaryeri'
    when 'expense_approval'          then '/mali-isler'
    when 'expense_rejected'          then '/mali-isler'
    when 'commitment_due'            then '/mali-isler'
    when 'account_negative'          then '/mali-isler'
    when 'bank_unmatched'            then '/mali-isler'
    when 'period_closed'             then '/mali-isler'
    when 'period_blocked'            then '/mali-isler'
    when 'mention'                   then '/akis'
    when 'post_repost'               then '/akis'
    when 'post_quote'                then '/akis'
    when 'support'                   then '/destek'
    when 'eligibility'               then '/athletes'
    -- 0073
    when 'training_session'          then '/antrenman-oturumu'
    when 'training_result'           then '/antrenman-sonuc'
    when 'court_waitlist' then '/saha-islemlerim'
    when 'turf_delegation' then '/saha-islemlerim'
    else '/bildirimler'
  end;
$fn$;


create or replace function public.notification_category(p_kind text)
returns text language sql immutable as $$
  select case p_kind
    when 'match_result'        then 'federasyon'
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

create or replace function public.push_on_notification()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_subs   jsonb;
  v_secret text;
begin
  if not public.push_allowed(new.profile_id, new.kind) then
    return new;
  end if;

  v_secret := public.push_secret();
  -- Anahtar tanımlı değilse sessizce çık: yanlış anahtarla istek atmak
  -- Cloudflare tarafında 401 yığını üretirdi.
  if v_secret is null or v_secret = '' then
    return new;
  end if;

  -- Her cihaz kendi taşıyıcısıyla birlikte gidiyor; sunucu hangi yolu
  -- kullanacağını satır satır seçiyor.
  select coalesce(jsonb_agg(jsonb_build_object(
           'kind',     s.kind,
           'endpoint', s.endpoint,
           'p256dh',   s.p256dh,
           'auth',     s.auth)), '[]'::jsonb)
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
                 'x-push-secret', v_secret),
    body    := jsonb_build_object(
                 'title', new.title,
                 'body',  coalesce(new.body, ''),
                 'url',   case when new.kind='match_result' then '/resmi-sonuc?notification='||new.id::text else public.push_route(new.kind, new.entity_type) end,
                 'subs',  v_subs)
  );

  return new;
exception
  when others then return new;
end; $$;
revoke all on function public.push_on_notification() from public,anon,authenticated;

do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(
  select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then
  alter publication supabase_realtime add table public.notifications;
 end if;
end $$;

do $faq$ begin
 if to_regclass('public.faq_entries') is not null then
  insert into public.faq_entries(question,answer,category,audience,sort_order,route)
  select 'Resmi kadroyu kim kilitler ve veli sonucu nasıl görür?',
   'İlgili kulübün aktif yöneticisi veya aynı branşta geçerli 3–5. kademe belgesi olan aktif antrenörü resmi esameyi gerekçeyle kilitler. 1–2. kademe resmi kadroyu okur; antrenman yoklaması ve antrenman notu yetkisi devam eder. Resmi sonuç federasyon tarafından yayımlandığında kadrodaki çocuğun bağlı velisine bildirim gelir. Bildirime dokunarak özel müsabaka karnesini açabilirsin; takvim de güncellenir. Bildirim tercihleri telefon uyarısını kapatabilir, uygulama içindeki bildirimi silmez. Bağlantı başka bir çocuğun verisini açmaz. Federasyon düzeltmesi yeni revizyon ve bildirim oluşturur. DQ ve DNF bir başarı derecesi olarak gösterilmez.',
   'Genel','everyone',104,'/calendar'
  where not exists(select 1 from public.faq_entries where question='Resmi kadroyu kim kilitler ve veli sonucu nasıl görür?');
 end if;
end $faq$;
