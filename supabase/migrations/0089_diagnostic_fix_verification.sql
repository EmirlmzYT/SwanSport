-- Fix declarations are scoped evidence, not proof that a bug no longer exists.
set local lock_timeout='15s';
create or replace function public.diagnostic_release_parts(p_release text)
returns numeric[] language sql immutable set search_path=public as $$
 select case when length(p_release)<=64 and p_release~'^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$'
 then array[split_part(replace(p_release,'+','.'),'.',1)::numeric,
 split_part(replace(p_release,'+','.'),'.',2)::numeric,
 split_part(replace(p_release,'+','.'),'.',3)::numeric,
 coalesce(nullif(split_part(replace(p_release,'+','.'),'.',4),''),'0')::numeric] end;
$$;
revoke all on function public.diagnostic_release_parts(text) from public,anon,authenticated;

create table if not exists public.diagnostic_fixes (
 id uuid primary key default gen_random_uuid(),
 issue_id uuid not null references public.diagnostic_issues(id) on delete cascade,
 release text not null check(diagnostic_release_parts(release) is not null),
 platform text not null check(platform in ('web','android','ios','windows','macos','linux')),
 application text not null check(application in ('app','console')),
 declared_at timestamptz not null default now(),
 declared_by uuid references auth.users(id) on delete set null,
 regression_count bigint not null default 0,
 last_regression_at timestamptz
);
alter table public.diagnostic_fixes enable row level security;
revoke all on public.diagnostic_fixes from public,anon,authenticated;
alter table public.diagnostic_issues add column if not exists current_fix_id uuid references public.diagnostic_fixes(id) on delete set null;
alter table public.support_tickets add column if not exists diagnostic_issue_id uuid references public.diagnostic_issues(id) on delete set null;
alter table public.support_tickets add column if not exists diagnostic_fix_id uuid references public.diagnostic_fixes(id) on delete set null;
alter table public.support_tickets add column if not exists fix_response text check(fix_response in ('awaiting_confirmation','confirmed','still_failing'));
alter table public.support_tickets add column if not exists fix_response_release text;
alter table public.support_tickets add column if not exists fix_answered_at timestamptz;
create index if not exists diagnostic_fix_issue on public.diagnostic_fixes(issue_id);
create index if not exists diagnostic_issue_current_fix on public.diagnostic_issues(current_fix_id) where current_fix_id is not null;
create index if not exists support_diagnostic_fix on public.support_tickets(diagnostic_fix_id) where diagnostic_fix_id is not null;
create index if not exists support_diagnostic_issue on public.support_tickets(diagnostic_issue_id) where diagnostic_issue_id is not null;

create or replace function public.observe_diagnostic_fix()
returns trigger language plpgsql security definer set search_path=public as $$
declare f diagnostic_fixes;
begin
 if new.kind<>'error' or new.issue_id is null then return new; end if;
 select df.* into f from diagnostic_issues i join diagnostic_fixes df on df.id=i.current_fix_id where i.id=new.issue_id;
 if f.id is not null and new.platform=f.platform and new.application=f.application
   and coalesce(diagnostic_release_parts(new.release)>=diagnostic_release_parts(f.release),false)
   and new.occurred_at>f.declared_at then
   update diagnostic_fixes set regression_count=regression_count+1,last_regression_at=new.received_at where id=f.id;
   update diagnostic_issues set state='regressed' where id=new.issue_id;
 end if;
 return new;
end $$;
revoke all on function public.observe_diagnostic_fix() from public,anon,authenticated;
drop trigger if exists trg_observe_diagnostic_fix on public.diagnostic_events;
create trigger trg_observe_diagnostic_fix after insert on public.diagnostic_events for each row execute function public.observe_diagnostic_fix();

create or replace function public.set_diagnostic_issue_status(p_issue uuid,p_status text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not coalesce(is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
 if p_status is distinct from 'investigating' then raise exception 'Düzeltme sürümü ve platformu gerekli'; end if;
 update diagnostic_issues set state='investigating',resolved_at=null,resolved_by=null where id=p_issue;
 if not found then raise exception 'Issue not found'; end if;
end $$;

create or replace function public.declare_diagnostic_fix(p_issue uuid,p_release text,p_platform text)
returns uuid language plpgsql security definer set search_path=public as $$
declare i diagnostic_issues; previous diagnostic_fixes; app text; fid uuid; t support_tickets;
begin
 if not coalesce(is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
 if diagnostic_release_parts(p_release) is null or coalesce(p_platform,'') not in ('web','android','ios','windows','macos','linux') then raise exception 'Geçerli sürüm ve platform gerekli'; end if;
 select * into i from diagnostic_issues where id=p_issue for update;
 if i.id is null then raise exception 'Issue not found'; end if;
 select * into previous from diagnostic_fixes where id=i.current_fix_id;
 if previous.id is not null and previous.platform=p_platform then
   if diagnostic_release_parts(p_release)=diagnostic_release_parts(previous.release) then return previous.id; end if;
   if diagnostic_release_parts(p_release)<diagnostic_release_parts(previous.release) then raise exception 'Yeni düzeltme daha yeni sürümde olmalı'; end if;
 end if;
 select application into app from diagnostic_events where issue_id=p_issue order by received_at desc limit 1;
 app:=coalesce(app,previous.application);
 if app is null then raise exception 'Hatanın uygulama kapsamı bilinmiyor'; end if;
 insert into diagnostic_fixes(issue_id,release,platform,application,declared_by)
 values(p_issue,p_release,p_platform,app,auth.uid()) returning id into fid;
 update diagnostic_issues set current_fix_id=fid,state='resolved',resolved_at=now(),resolved_by=auth.uid() where id=p_issue;
 -- Lock order everywhere is issue -> ticket; older confirmation IDs become stale.
 for t in select * from support_tickets where diagnostic_issue_id=p_issue and status<>'closed' order by id for update loop
   update support_tickets set diagnostic_fix_id=fid,fix_response='awaiting_confirmation',fix_answered_at=null,
    fix_response_release=null,status='awaiting_user_response',resolved_at=null,updated_at=now() where id=t.id;
   insert into support_messages(ticket_id,sender_id,body,is_staff) values(t.id,auth.uid(),
    'Düzeltme bildirildi: '||p_release||' ('||p_platform||'). Güncel sürümde yeniden deneyip sonucu teyit edebilir misin?',true);
   insert into notifications(profile_id,kind,title,body,entity_type,entity_id) values(t.profile_id,'support',
    'Düzeltmeyi kontrol edebilir misin?',left(t.subject,100),'support_ticket',t.id);
 end loop;
 return fid;
end $$;

create or replace function public.link_support_issue(p_ticket uuid,p_issue uuid)
returns void language plpgsql security definer set search_path=public as $$
declare i diagnostic_issues; f diagnostic_fixes; t support_tickets;
begin
 if not coalesce(is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
 select * into i from diagnostic_issues where id=p_issue for update;
 if i.id is null then raise exception 'Issue not found'; end if;
 select * into t from support_tickets where id=p_ticket for update;
 if t.id is null or t.status='closed' then raise exception 'Açık destek talebi gerekli'; end if;
 if t.diagnostic_issue_id=p_issue then return; end if;
 if t.diagnostic_issue_id is not null then raise exception 'Talep zaten bir hataya bağlı'; end if;
 select * into f from diagnostic_fixes where id=i.current_fix_id;
 update support_tickets set diagnostic_issue_id=p_issue,diagnostic_fix_id=f.id,
   fix_response=case when f.id is null then null else 'awaiting_confirmation' end,
   status=case when f.id is null then status else 'awaiting_user_response' end,
   resolved_at=case when f.id is null then resolved_at else null end,updated_at=now() where id=p_ticket;
 if f.id is not null then
   insert into support_messages(ticket_id,sender_id,body,is_staff) values(t.id,auth.uid(),
    'Düzeltme bildirildi: '||f.release||' ('||f.platform||'). Güncel sürümde yeniden deneyip sonucu teyit edebilir misin?',true);
   insert into notifications(profile_id,kind,title,body,entity_type,entity_id) values(t.profile_id,'support','Düzeltmeyi kontrol edebilir misin?',left(t.subject,100),'support_ticket',t.id);
 end if;
end $$;

create or replace function public.unlink_support_issue(p_ticket uuid,p_issue uuid)
returns void language plpgsql security definer set search_path=public as $$
declare t support_tickets;
begin
 if not coalesce(is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
 perform 1 from diagnostic_issues where id=p_issue for update;
 select * into t from support_tickets where id=p_ticket for update;
 if t.id is null then raise exception 'Ticket not found'; end if;
 if t.diagnostic_issue_id is null then return; end if;
 if t.diagnostic_issue_id is distinct from p_issue then raise exception 'Güncel hata bağlantısı gerekli'; end if;
 update support_tickets set diagnostic_issue_id=null,diagnostic_fix_id=null,fix_response=null,
  fix_answered_at=null,fix_response_release=null,
  status=case when status='closed' then status else 'under_review' end,
  resolved_at=case when status='closed' then resolved_at else null end,updated_at=now() where id=p_ticket;
 insert into support_messages(ticket_id,sender_id,body,is_staff) values(p_ticket,auth.uid(),
  'Teknik hata bağlantısı kaldırıldı; talebin yeniden kontrol edilecek. Önceki yazışmalar korunuyor.',true);
end $$;
revoke all on function public.unlink_support_issue(uuid,uuid) from public,anon;
grant execute on function public.unlink_support_issue(uuid,uuid) to authenticated;

create or replace function public.support_fix_context(p_ticket uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare t support_tickets; result jsonb;
begin
 select * into t from support_tickets where id=p_ticket;
 if auth.uid() is null or t.id is null or not coalesce(t.profile_id=auth.uid() or is_platform_admin(),false) then raise exception 'Ticket access denied'; end if;
 if t.diagnostic_issue_id is null then return null; end if;
 select jsonb_build_object('issue_id',i.id,'issue_state',i.state,'ticket_status',t.status,
   'fix_id',f.id,'release',f.release,'platform',f.platform,'application',f.application,
   'declared_at',f.declared_at,'regression_count',coalesce(f.regression_count,0),
   'response',t.fix_response,'answered_at',t.fix_answered_at,'response_release',t.fix_response_release)
 into result from diagnostic_issues i left join diagnostic_fixes f on f.id=t.diagnostic_fix_id where i.id=t.diagnostic_issue_id;
 return result;
end $$;

create or replace function public.respond_support_fix(p_ticket uuid,p_fix uuid,p_result text,p_release text,p_platform text,p_application text)
returns void language plpgsql security definer set search_path=public as $$
declare t support_tickets; iid uuid; current_id uuid; f diagnostic_fixes;
begin
 if auth.uid() is null or coalesce(p_result,'') not in ('confirmed','still_failing') then raise exception 'Geçerli yanıt gerekli'; end if;
 select diagnostic_issue_id into iid from support_tickets where id=p_ticket and profile_id=auth.uid();
 if iid is null then raise exception 'Ticket access denied'; end if;
 select current_fix_id into current_id from diagnostic_issues where id=iid for update;
 select * into t from support_tickets where id=p_ticket for update;
 if t.profile_id is distinct from auth.uid() or t.diagnostic_issue_id is distinct from iid or t.status='closed'
  or p_fix is null or t.diagnostic_fix_id is distinct from p_fix or current_id is distinct from p_fix then raise exception 'Güncel düzeltme gerekli'; end if;
 select * into f from diagnostic_fixes where id=p_fix;
 if p_platform is distinct from f.platform or p_application is distinct from f.application
  or not coalesce(diagnostic_release_parts(p_release)>=diagnostic_release_parts(f.release),false) then raise exception 'Düzeltmenin güncel sürümünde yeniden dene'; end if;
 if t.fix_response=p_result and t.fix_response_release=p_release then return; end if;
 update support_tickets set fix_response=p_result,fix_response_release=p_release,fix_answered_at=now(),
   status=case when p_result='confirmed' then 'resolved' else 'under_review' end,
   resolved_at=case when p_result='confirmed' then now() else null end,updated_at=now() where id=p_ticket;
 insert into support_messages(ticket_id,sender_id,body,is_staff) values(p_ticket,auth.uid(),
  case when p_result='confirmed' then 'Bildirilen düzeltmeyi güncel sürümde denedim; sorun çözüldü.' else 'Bildirilen düzeltmeyi güncel sürümde denedim; sorun devam ediyor.' end,false);
 if p_result='still_failing' then update diagnostic_issues set state='regressed' where id=iid; end if;
end $$;

create or replace function public.admin_diagnostic_detail(p_issue uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if not coalesce(is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
 select jsonb_build_object('issue',to_jsonb(i),'fix',to_jsonb(f),
 'verification',jsonb_build_object(
 'pending',(select count(*) from support_tickets where diagnostic_fix_id=f.id and fix_response='awaiting_confirmation' and status<>'closed'),
 'confirmed',(select count(*) from support_tickets where diagnostic_fix_id=f.id and fix_response='confirmed'),
 'still_failing',(select count(*) from support_tickets where diagnostic_fix_id=f.id and fix_response='still_failing')),
 'events',coalesce((select jsonb_agg(to_jsonb(e)) from (select id,trace_id,session_id,kind,operation,screen,code,release,platform,application,duration_ms,occurred_at,frames,breadcrumbs from diagnostic_events where issue_id=i.id order by received_at desc limit 20) e),'[]'),
 'server_events',coalesce((select jsonb_agg(to_jsonb(s)) from (select s.trace_id,s.operation,s.received_at from diagnostic_server_events s where s.trace_id in (select trace_id from diagnostic_events where issue_id=i.id) order by s.received_at desc limit 50) s),'[]'))
 into result from diagnostic_issues i left join diagnostic_fixes f on f.id=i.current_fix_id where i.id=p_issue;
 return result;
end $$;

-- RPCs retain their old signatures where replaced; new workflows have distinct names.
revoke all on function public.declare_diagnostic_fix(uuid,text,text), public.link_support_issue(uuid,uuid),
 public.support_fix_context(uuid),public.respond_support_fix(uuid,uuid,text,text,text,text),
 public.set_diagnostic_issue_status(uuid,text),public.admin_diagnostic_detail(uuid) from public,anon;
grant execute on function public.declare_diagnostic_fix(uuid,text,text),public.link_support_issue(uuid,uuid),
 public.support_fix_context(uuid),public.respond_support_fix(uuid,uuid,text,text,text,text),
 public.set_diagnostic_issue_status(uuid,text),public.admin_diagnostic_detail(uuid) to authenticated;

insert into faq_entries(question,answer,category,audience,sort_order,route)
select 'Bildirilen hata düzeltmesini nasıl teyit ederim?',
 'Destek talebinde bildirilen sürüm ve platformda uygulamayı güncelle, aynı işlemi yeniden dene. Sorun çözüldü veya Sorun devam ediyor seçeneği yalnız o sürüm ve sonrasında açıktır. Teyidin talebine kaydedilir; sorun sürüyorsa talep tekrar incelemeye alınır. Eski sürümdeysen normal yanıtla ekibe yazabilirsin. Hata kaydı olmaması tek başına çözüm kanıtı değildir.',
 'Destek','everyone',192,'/destek' where not exists(select 1 from faq_entries where question='Bildirilen hata düzeltmesini nasıl teyit ederim?');

create or replace function public.ingest_diagnostics(p_session uuid,p_events jsonb)
returns integer language plpgsql security definer set search_path=public as $fn$
declare e jsonb; v jsonb; owner uuid; n integer; issue uuid; fp text; inserted integer; accepted integer:=0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_session is null or jsonb_typeof(p_events) is distinct from 'array' then raise exception 'Invalid batch'; end if;
  n:=jsonb_array_length(p_events);
  if n not between 1 and 20 or octet_length(p_events::text)>65536 then raise exception 'Batch limit exceeded'; end if;
  -- One locked counter per actor: concurrent sessions cannot bypass the hourly cap.
  insert into diagnostic_limits(owner_id) values(auth.uid()) on conflict do nothing;
  update diagnostic_limits set
    event_count=case when window_start < now()-interval '1 hour' then n else event_count+n end,
    window_start=case when window_start < now()-interval '1 hour' then now() else window_start end
    where owner_id=auth.uid() and (window_start<now()-interval '1 hour' or event_count+n<=1000);
  if not found then raise exception 'Diagnostic rate limit exceeded'; end if;
  insert into diagnostic_sessions(id,owner_id) values(p_session,auth.uid()) on conflict do nothing;
  select owner_id into owner from diagnostic_sessions where id=p_session for update;
  if owner is distinct from auth.uid() then raise exception 'Session access denied'; end if;
  update diagnostic_sessions set last_seen=now() where id=p_session;
  for e in select value from jsonb_array_elements(p_events) loop
    v:=public.clean_diagnostic_event(e);
    -- Session row serializes retries. Don't increment counts for duplicate IDs.
    if exists(select 1 from diagnostic_events where session_id=p_session and id=(v->>'id')::uuid) then continue; end if;
    issue:=null;
    if v->>'kind'='error' then
      fp:=md5(concat_ws('|',v->>'application',v->>'operation',v->>'screen',v->>'code',v->'frames'->0->>'source',v->'frames'->0->>'line'));
      insert into diagnostic_issues(fingerprint,operation,code)
      values(fp,v->>'operation',v->>'code')
      on conflict(fingerprint) do update set occurrence_count=diagnostic_issues.occurrence_count+1,
        last_seen=now()
      returning id into issue;
    end if;
    insert into diagnostic_events(session_id,id,trace_id,issue_id,kind,operation,screen,code,
      release,platform,application,usage_enabled,duration_ms,occurred_at,frames,breadcrumbs)
    values(p_session,(v->>'id')::uuid,(v->>'trace_id')::uuid,issue,v->>'kind',v->>'operation',v->>'screen',v->>'code',
      v->>'release',v->>'platform',v->>'application',(v->>'usage_enabled')::boolean,(v->>'duration_ms')::integer,(v->>'occurred_at')::timestamptz,v->'frames',v->'breadcrumbs');
    accepted:=accepted+1;
  end loop;
  return accepted;
end $fn$;
revoke all on function public.ingest_diagnostics(uuid,jsonb) from public,anon;
grant execute on function public.ingest_diagnostics(uuid,jsonb) to authenticated;


create or replace function public.purge_diagnostics()
returns void language plpgsql security definer set search_path=public as $fn$
begin
  delete from diagnostic_events where received_at<now()-interval '30 days';
  delete from diagnostic_server_events where received_at<now()-interval '30 days';
  delete from diagnostic_sessions where last_seen<now()-interval '30 days';
  delete from diagnostic_alerts where created_at<now()-interval '30 days';
  delete from diagnostic_issues i where last_seen<now()-interval '90 days'
    and not exists(select 1 from support_tickets t where t.diagnostic_issue_id=i.id
      and t.fix_response='awaiting_confirmation' and t.status<>'closed');
  delete from diagnostic_limits where window_start<now()-interval '1 day';
  delete from support_diagnostic_links where created_at<now()-interval '30 days' and attachment_path is null;
  update support_diagnostic_links set snapshot='{}' where created_at<now()-interval '30 days';
end $fn$;
revoke all on function public.purge_diagnostics() from public,anon,authenticated;


create or replace function public.admin_diagnostic_overview()
returns jsonb language plpgsql security definer set search_path=public as $fn$
declare result jsonb;
begin
  if not coalesce(public.is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
  perform public.refresh_diagnostic_alerts();
  select jsonb_build_object('consistency',public.admin_diagnostic_consistency(),'open_issues',(select count(*) from diagnostic_issues i where state<>'resolved' and exists(select 1 from diagnostic_events e where e.issue_id=i.id)),
    'errors_24h',(select count(*) from diagnostic_events where kind='error' and received_at>now()-interval '1 day'),
    'sessions_24h',(select count(distinct session_id) from diagnostic_events where received_at>now()-interval '1 day'),
    'alerts',coalesce((select jsonb_agg(to_jsonb(a)) from (select code,alert_key,qty,created_at from diagnostic_alerts
      where bucket>=now()-interval '1 hour' order by created_at desc limit 30) a),'[]'),
    'flows',coalesce((select jsonb_agg(to_jsonb(f)) from (select operation,
      count(*) filter(where kind='start') as started,count(*) filter(where kind='success') as succeeded,
      count(*) filter(where kind='error') as failed,round(avg(duration_ms) filter(where kind in ('success','error'))) as avg_ms
      from diagnostic_events where usage_enabled and received_at>now()-interval '1 day' and kind in ('start','success','error')
      group by operation order by count(*) filter(where kind='error') desc limit 20) f),'[]')) into result;
  return result||jsonb_build_object(
    'pending_fix_confirmations',(select count(*) from support_tickets t join diagnostic_issues i on i.id=t.diagnostic_issue_id where t.diagnostic_fix_id=i.current_fix_id and t.fix_response='awaiting_confirmation' and t.status<>'closed'),
    'confirmed_fix_tickets',(select count(*) from support_tickets t join diagnostic_issues i on i.id=t.diagnostic_issue_id where t.diagnostic_fix_id=i.current_fix_id and t.fix_response='confirmed'),
    'fix_regressions',(select count(*) from diagnostic_issues where current_fix_id is not null and state='regressed'));

end $fn$;

