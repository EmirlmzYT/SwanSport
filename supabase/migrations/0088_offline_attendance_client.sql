-- Versioned attendance: prevent lost updates, bind replays to their payload.
set local lock_timeout = '15s';
alter table public.attendance_op_logs add column if not exists input_hash text;

create or replace function public.attendance_version_guard()
returns trigger language plpgsql set search_path=public as $$
begin
  if tg_op='INSERT' then new.version:=1;
  else new.version:=old.version+1; end if;
  return new;
end $$;
drop trigger if exists trg_attendance_version_guard on public.attendance;
create trigger trg_attendance_version_guard before insert or update on public.attendance
for each row execute function public.attendance_version_guard();

create or replace function public.save_attendance_ops(p_event uuid,p_op_id uuid,p_marks jsonb)
returns jsonb language plpgsql security definer set search_path=public as $fn$
declare v_club uuid; v_team uuid; cached attendance_op_logs; m jsonb; aid uuid;
  stat text; ver int; current_row attendance; applied int:=0; conflicts jsonb:='[]';
  written uuid; result jsonb; hash text;
begin
  if auth.uid() is null or p_op_id is null then raise exception 'Giriş ve işlem kimliği gerekli'; end if;
  -- Serialize this actor/op across events, then serialize writes to one event.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_op_id::text,0));
  select club_id,team_id into v_club,v_team from events where id=p_event for update;
  if v_club is null or not coalesce(is_club_staff(v_club),false) then raise exception 'Yoklama yetkisi yok'; end if;
  if jsonb_typeof(p_marks) is distinct from 'array' then raise exception 'İşaret listesi gerekli'; end if;
  if jsonb_array_length(p_marks) not between 1 and 200 or octet_length(p_marks::text)>65536 then raise exception 'Geçersiz işaret sayısı'; end if;
  hash:=md5(p_marks::text);
  select * into cached from attendance_op_logs where actor_id=auth.uid() and op_id=p_op_id;
  if found then
    if cached.event_id is distinct from p_event or (cached.input_hash is not null and cached.input_hash<>hash) then
      raise exception 'İşlem kimliği farklı bir yoklamaya ait';
    end if;
    return cached.result||jsonb_build_object('replayed',true);
  end if;
  if (select count(distinct x->>'athlete_id') from jsonb_array_elements(p_marks) x)<>jsonb_array_length(p_marks) then
    raise exception 'Aynı sporcu bir kez işaretlenebilir';
  end if;
  for m in select value from jsonb_array_elements(p_marks) order by value->>'athlete_id' loop
    if jsonb_typeof(m) is distinct from 'object' or jsonb_typeof(m->'version') is distinct from 'number'
      or coalesce(m->>'version','') !~ '^\d+$' or coalesce(m->>'status','') not in ('present','absent','excused','late') then
      raise exception 'Geçersiz yoklama işareti';
    end if;
    aid:=(m->>'athlete_id')::uuid; stat:=m->>'status'; ver:=(m->>'version')::int;
    perform 1 from athletes a where a.id=aid and a.club_id=v_club and a.status='active' for share;
    if not found or (v_team is not null and not exists(select 1 from team_memberships where team_id=v_team and athlete_id=aid)) then
      raise exception 'Sporcu etkinliğin aktif kadrosunda değil';
    end if;
    if stat in ('present','late') and exists(select 1 from eligibility_gate(aid) g where g.blocked) then
      raise exception 'Sporcunun uygunluk kısıtı var';
    end if;
    select * into current_row from attendance where event_id=p_event and athlete_id=aid for update;
    written:=null;
    if not found and ver=0 then
      insert into attendance(club_id,event_id,athlete_id,status,marked_at,actor_id,version)
      values(v_club,p_event,aid,stat::attendance_status,coalesce((m->>'marked_at')::timestamptz,now()),auth.uid(),1)
      on conflict(event_id,athlete_id) do nothing returning id into written;
    elsif current_row.version=ver then
      update attendance set status=stat::attendance_status,
        marked_at=coalesce((m->>'marked_at')::timestamptz,now()),actor_id=auth.uid()
      where event_id=p_event and athlete_id=aid and version=ver returning id into written;
    end if;
    if written is not null then applied:=applied+1;
    else
      select * into current_row from attendance where event_id=p_event and athlete_id=aid;
      conflicts:=conflicts||jsonb_build_object('athlete_id',aid,
        'reason',case when current_row.id is null then 'deleted' else 'version_mismatch' end,
        'sent_status',stat,'sent_version',ver,'current_status',current_row.status,'current_version',current_row.version);
    end if;
  end loop;
  result:=jsonb_build_object('applied',applied,'conflicts',conflicts,'replayed',false);
  insert into attendance_op_logs(actor_id,op_id,event_id,club_id,result,input_hash)
  values(auth.uid(),p_op_id,p_event,v_club,result,hash);
  return result;
end $fn$;
revoke all on function public.save_attendance_ops(uuid,uuid,jsonb) from public,anon;
grant execute on function public.save_attendance_ops(uuid,uuid,jsonb) to authenticated;

-- Preserve the existing result type; EXISTS prevents season memberships duplicating rows.
create or replace function public.event_roster_versioned(p_event uuid)
returns table(athlete_id uuid,full_name text,status text,version int,rsvp_status text,eligibility text)
language plpgsql stable security definer set search_path=public as $$
declare c uuid; t uuid;
begin
  select e.club_id,e.team_id into c,t from events e where e.id=p_event;
  if c is null or not coalesce(is_club_staff(c),false) then raise exception 'Kadro yetkisi yok'; end if;
  return query select a.id,a.first_name||' '||a.last_name,at.status::text,coalesce(at.version,0),r.status,g.status
    from athletes a left join attendance at on at.athlete_id=a.id and at.event_id=p_event
    left join event_rsvps r on r.athlete_id=a.id and r.event_id=p_event
    cross join lateral eligibility_gate(a.id) g
    where a.club_id=c and a.status='active'
      and (t is null or exists(select 1 from team_memberships tm where tm.team_id=t and tm.athlete_id=a.id))
    order by 2;
end $$;
revoke all on function public.event_roster_versioned(uuid) from public,anon;
grant execute on function public.event_roster_versioned(uuid) to authenticated;

create or replace function public.prepare_attendance_offline(p_event uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare e events; club_name text; rows jsonb;
begin
  select * into e from events where id=p_event;
  if e.id is null or not coalesce(is_club_staff(e.club_id),false) then raise exception 'Kadro yetkisi yok'; end if;
  if not exists(select 1 from my_feature_flags() f where f.key='offline_attendance') then raise exception 'Çevrimdışı yoklama kapalı'; end if;
  select name into club_name from clubs where id=e.club_id;
  select coalesce(jsonb_agg(to_jsonb(r)),'[]') into rows from event_roster_versioned(p_event) r;
  if jsonb_array_length(rows)>200 then raise exception 'Kadro en fazla 200 sporcu olmalı'; end if;
  return jsonb_build_object('actor_id',auth.uid(),'event_id',e.id,'club_id',e.club_id,'club_name',club_name,
    'title',e.title,'starts_at',e.starts_at,'prepared_at',now(),'expires_at',now()+interval '7 days','rows',rows);
end $$;
revoke all on function public.prepare_attendance_offline(uuid) from public,anon;
grant execute on function public.prepare_attendance_offline(uuid) to authenticated;

create or replace function public.save_attendance_offline(p_actor uuid,p_event uuid,p_op_id uuid,p_marks jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'Kuyruk başka hesaba ait'; end if;
  -- Already committed operations remain replayable after a rollout rollback.
  if not exists(select 1 from attendance_op_logs where actor_id=auth.uid() and op_id=p_op_id)
    and not exists(select 1 from my_feature_flags() f where f.key='offline_attendance') then
    raise exception 'Çevrimdışı yoklama kapalı';
  end if;
  return save_attendance_ops(p_event,p_op_id,p_marks);
end $$;
revoke all on function public.save_attendance_offline(uuid,uuid,uuid,jsonb) from public,anon;
grant execute on function public.save_attendance_offline(uuid,uuid,uuid,jsonb) to authenticated;

-- No rollout change: flag stays off until device and multi-session UAT.
insert into faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'İnternet yokken yoklama nasıl alınır?',
  'İnternet varken Yoklama ekranında etkinliğin kadrosunu Çevrimdışına hazırla ile cihazına kaydet. Hazırlanmış kadro aynı hesapla yedi gün kullanılabilir. Yalnız dokunduğun işaretler cihazda korunur. Kuyruğa al ile gönderimi başlat; Bekleyen Yoklamalar bölümünde sunucuya ulaşıp ulaşmadığını izle. Çakışmada sunucudaki değeri kabul et veya güncel kadroyu yeniden okuyarak kendi işaretini uygula. Hatalı ve eski kayıtlar kendiliğinden silinmez. Cihaz/tarayıcı verilerini silmek yerel kayıtları da siler.',
  'Kulüp','club_staff',191,'/attendance','offline_attendance'
where not exists(select 1 from faq_entries where feature='offline_attendance' and question='İnternet yokken yoklama nasıl alınır?');
