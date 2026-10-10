import {c1,verify,sport} from './identity_membership_sql_test.mjs';
import {apply,actor,call,admin,officer,coach,guardian,child,club,other,id} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const sql=async n=>readFile(new URL('../supabase/migrations/'+n+'.sql',import.meta.url),'utf8');
const migration=await sql('0104_coach_guardian_results');
async function fixture(){const f=await c1();try{
 const {db}=f;
 await apply(db,await sql('0103_official_result_cv'));
 await db.exec(`alter table notifications add column id uuid primary key default gen_random_uuid(),add column read_at timestamptz,add column created_at timestamptz default now();
 alter table notifications enable row level security;
 create policy notif_read_own on notifications for select to authenticated using(profile_id=auth.uid());
 create policy notif_update_own on notifications for update to authenticated using(profile_id=auth.uid()) with check(profile_id=auth.uid());
 create policy notif_delete_own on notifications for delete to authenticated using(profile_id=auth.uid());
 create table notification_prefs(profile_id uuid,category text,enabled boolean);
 create table push_subscriptions(profile_id uuid,kind text,endpoint text,p256dh text,auth text);
 create table test_push_payloads(body jsonb);
 create schema net;
 create function net.http_post(url text,headers jsonb,body jsonb) returns bigint language plpgsql as $$begin insert into test_push_payloads values(body);return 1;end $$;
 create function push_secret() returns text language sql as $$select 'isolated-test-secret'::text$$;
 create function notification_category(p_kind text) returns text language sql as $$select 'sosyal'::text$$;
 create function push_allowed(p_profile uuid,p_kind text) returns boolean language sql as $$select coalesce((select enabled from notification_prefs where profile_id=p_profile and category=notification_category(p_kind)),true)$$;
 create function push_notification(uuid,text,text,text,uuid,text,uuid) returns void language sql as $$select null::void$$;
 `);
 await apply(db,migration);
 await db.exec('create trigger test_push_on_notification after insert on notifications for each row execute function push_on_notification()');
 await db.query("insert into push_subscriptions values($1,'fcm','guardian-device',null,null),($2,'fcm','other-device',null,null)",[guardian,admin]);
 return f;
 }catch(e){await f.db.close();throw e;}}
async function asAuth(db,p){await db.exec('reset role');await actor(db,p);await db.exec('set role authenticated');}
async function owner(db,p=officer){await db.exec('reset role');await actor(db,p);}

test('0104 club-scoped 1/2 denied, 3/4/5 approved, expired/wrong sport/admin bypass denied; assistants keep reading',async()=>{
 const {db,participant,match}=await fixture();try{
 await verify(db,coach,'33333333330');
 await verify(db,guardian,'44444444440');
 const cred=await sport(db,coach,'tenis','coach','2090-01-01',2);
 await owner(db,coach);await db.query("update club_memberships set role='coach',coach_level=2 where profile_id=$1 and club_id=$2",[coach,club]);
 let version=1;
 for(const level of [1,2,3,4,5]){
  await owner(db,admin);await db.query('update profile_credentials set coach_level=$1 where id=$2',[level,cred]);
  await asAuth(db,coach);
  const team=(await db.query('select id from teams where club_id=$1 and sport_code=$2 limit 1',[club,'tenis'])).rows[0].id;
  assert.equal((await db.query('select * from official_team_rosters($1)',[team])).rows.length,1);
  await assert.rejects(db.query("insert into org_roster_revisions(participant_id,version,athlete_ids,reason,actor_id) values($1,99,$2,'bypass',$3)",[participant,[child],coach]),/permission/);
  if(level<3)await assert.rejects(call(db,'federation_publish_roster',[participant,[child],'test',version]),/3. Kademe/);
  else {await call(db,'federation_publish_roster',[participant,[child],'test',version]);version++;}
 }
 for(const mutation of ["expires_on=current_date-1","sport_code='yuzme'","status='rejected'"]){
  await owner(db,admin);await db.exec('begin');await db.query('update profile_credentials set '+mutation+' where id=$1',[cred]);await asAuth(db,coach);
  await assert.rejects(call(db,'federation_publish_roster',[participant,[child],'test',version]),/3. Kademe/);await db.exec('rollback');
 }
 for(const person of [officer,admin,guardian]){await asAuth(db,person);await assert.rejects(call(db,'federation_publish_roster',[participant,[child],'test',version]));}
 await owner(db,coach);await db.query("update club_memberships set role='club_admin' where profile_id=$1 and club_id=$2",[coach,club]);await asAuth(db,coach);
 await call(db,'federation_publish_roster',[participant,[child],'manager',version]);
 await owner(db);const wrong=await call(db,'federation_add_participant',[(await db.query('select org_id from org_participants where id=$1',[participant])).rows[0].org_id,other,null]);
 await asAuth(db,coach);await assert.rejects(call(db,'federation_publish_roster',[wrong,[child],'other club',0]));
 await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'test',0]),/görev/);
 }finally{await db.close();}
});

test('0104 result -> private guardian notice -> FCM + correct revision/card/calendar; correction, no forged payload',async()=>{
 const {db,match}=await fixture();try{
 await owner(db);await call(db,'federation_publish_result',[match,{type:'score',home:2,away:0},'confirmed',0]);
 const notice=(await db.query("select * from notifications where kind='match_result'")).rows[0];assert.equal(notice.profile_id,guardian);assert.equal(notice.entity_id,child);assert.match(notice.title,/Private.*Müsabaka Sonucu Açıklandı/);
 const pushes=(await db.query('select body from test_push_payloads')).rows;assert.equal(pushes.length,1);assert.equal(pushes[0].body.url,'/resmi-sonuc?notification='+notice.id);assert.deepEqual(pushes[0].body.subs.map(x=>x.endpoint),['guardian-device']);
 await asAuth(db,guardian);const card=await call(db,'guardian_notification_result',[notice.id]);assert.equal(card.outcome,'won');assert.equal(card.version,1);assert.equal(card.result,'2–0');assert.equal('athletes' in card,false);
 assert.doesNotMatch(JSON.stringify(card),new RegExp(child+'|athlete_id|license|national_id|health|performances'));
 assert.equal((await db.query("select * from guardian_calendar_results(now(),now()+interval '31 days')")).rows.length,1);
 await call(db,'mark_notifications_read',[notice.id]);assert.ok((await db.query('select read_at from notifications where id=$1',[notice.id])).rows[0].read_at);
 assert.equal((await db.query("update notifications set title='Fake' where id=$1 returning id",[notice.id])).rows.length,0);
 for(const person of [admin,coach,officer]){await asAuth(db,person);await assert.rejects(call(db,'guardian_notification_result',[notice.id]),/erişim/);await assert.rejects(call(db,'guardian_match_result',[match,child]),/erişim/);}
 await owner(db);await call(db,'federation_publish_result',[match,{type:'score',home:0,away:3},'corrected',1]);
 assert.equal((await db.query("select count(*)::int n from notifications where kind='match_result'")).rows[0].n,2);
 await asAuth(db,guardian);const latest=(await db.query("select * from guardian_calendar_results(now(),now()+interval '31 days')")).rows;assert.equal(latest.length,1);assert.equal(latest[0].summary.outcome,'lost');assert.equal(latest[0].summary.version,2);
 const old=await call(db,'guardian_notification_result',[notice.id]);assert.equal(old.version,1);assert.equal(old.current_version,2);
 await owner(db);await db.query('delete from guardians where profile_id=$1 and athlete_id=$2',[guardian,child]);await asAuth(db,guardian);
 await assert.rejects(call(db,'guardian_notification_result',[notice.id]),/erişim/);assert.equal((await db.query('select * from notifications')).rows.length,0);assert.equal((await db.query('select * from my_notifications()')).rows.length,0);
 }finally{await db.close();}
});

test('0104 minors only, unknown DOB protected, atomic rollback and repeat-safe grants',async()=>{
 const {db,match}=await fixture();try{
 await apply(db,migration);
 for(const signature of ['guardian_notification_result(uuid)','guardian_calendar_results(timestamp with time zone,timestamp with time zone)','official_team_rosters(uuid)','_guardian_result_summary(uuid,uuid)']){
  assert.equal((await db.query("select has_function_privilege('anon',$1,'EXECUTE') v",[signature])).rows[0].v,false);
 }
 await owner(db);await db.query("update athletes set birth_date=((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date where id=$1",[child]);
 await call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'adult birthday',0]);assert.equal((await db.query('select count(*)::int n from notifications')).rows[0].n,0);
 await db.query('update athletes set birth_date=null where id=$1',[child]);
 await db.exec("create function test_cv_fail() returns trigger language plpgsql as $$begin raise exception 'CV failure';end $$;create trigger test_cv_fail before insert on athlete_achievements for each row execute function test_cv_fail()");
 await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:2,away:0},'rollback',1]),/CV failure/);assert.equal((await db.query('select count(*)::int n from notifications')).rows[0].n,0);assert.equal((await db.query('select count(*)::int n from test_push_payloads')).rows[0].n,0);
 await db.exec('drop trigger test_cv_fail on athlete_achievements');await call(db,'federation_publish_result',[match,{type:'score',home:2,away:0},'unknown DOB',1]);assert.equal((await db.query('select count(*)::int n from notifications')).rows[0].n,1);
 await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:2,away:0},'retry',1]),/sürümü/);assert.equal((await db.query('select count(*)::int n from notifications')).rows[0].n,1);
 }finally{await db.close();}
});

test('0104 all roster children notify once, non-roster siblings stay private and phone preference does not remove inbox',async()=>{
 const {db,participant,match}=await fixture();try{
  await verify(db,guardian,'44444444440');
  await owner(db,coach);
  const second=id(801),outside=id(802);
  for(const [athlete,name] of [[second,'Second'],[outside,'Outside']]){
   await db.query("insert into athletes(id,club_id,first_name,last_name,birth_date) values($1,$2,$3,'Child',current_date-interval '12 years')",[athlete,club,name]);
   const invitation=await call(db,'create_guardian_invite',[athlete]);
   await asAuth(db,guardian);await call(db,'redeem_invite_code',[invitation]);await owner(db,coach);
  }
  await owner(db,officer);await call(db,'federation_register_license',[second,'tenis','SECOND','2090-01-01']);
  await asAuth(db,coach);await call(db,'federation_publish_roster',[participant,[child,second],'two children',1]);
  await owner(db,officer);await db.query("insert into notification_prefs values($1,'federasyon',false)",[guardian]);
  await call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'first',0]);
  const notices=(await db.query("select * from notifications where kind='match_result'")).rows;
  assert.equal(notices.length,2);assert.deepEqual(new Set(notices.map(n=>n.entity_id)),new Set([child,second]));
  assert.equal((await db.query('select count(*)::int n from test_push_payloads')).rows[0].n,0);
  await db.query("update notification_prefs set enabled=true where profile_id=$1",[guardian]);
  await call(db,'federation_publish_result',[match,{type:'score',home:0,away:1},'correction',1]);
  assert.equal((await db.query('select count(*)::int n from test_push_payloads')).rows[0].n,2);
  await asAuth(db,guardian);
  const calendar=(await db.query("select * from guardian_calendar_results(now(),now()+interval '31 days')")).rows;assert.equal(calendar.length,2);
  assert.ok(calendar.every(c=>c.summary.outcome==='lost'));assert.doesNotMatch(JSON.stringify(calendar),/Outside/);
  await db.query('delete from notifications where profile_id=$1',[guardian]);
  const retained=(await db.query("select * from guardian_calendar_results(now(),now()+interval '31 days')")).rows;
  assert.equal(retained.length,2);assert.ok(retained.every(c=>c.notification_id===null));
  assert.equal((await call(db,'guardian_match_result',[match,second])).outcome,'lost');
  await db.exec('reset role');await actor(db,'');await db.exec('set role anon');await assert.rejects(db.query('select * from notifications'),/permission/);
 }finally{await db.close();}
});

test('0104 set and timed/ranked results expose only private numeric summaries, never full roster',async()=>{
 const {db,match,org}=await fixture();try{
  let version=0;
  for(const [protocol,label] of [
   [{type:'sets',sets:[{home:6,away:2},{home:6,away:0}]},'won'],
   [{type:'time',entries:[{athlete_id:child,value:62123,placement:1}]},'recorded'],
   [{type:'rank',entries:[{athlete_id:child,value:580,placement:2}]},'recorded'],
  ]){
   await owner(db);await call(db,'federation_publish_result',[match,protocol,'confirmed',version++]);
   const n=(await db.query("select id from notifications where kind='match_result' order by created_at desc limit 1")).rows[0];
   await asAuth(db,guardian);const card=await call(db,'guardian_notification_result',[n.id]);assert.equal(card.outcome,label);assert.doesNotMatch(JSON.stringify(card),new RegExp(child+'|athlete_id|license|national_id'));
  }
  await owner(db);await call(db,'federation_publish_program',[org,true]);
  await db.exec('set role anon');
  const publicResult=JSON.stringify((await db.query('select * from public_program_result($1)',[match])).rows);
  assert.match(publicResult,/sporcu/);assert.doesNotMatch(publicResult,new RegExp(child+'|Private|athlete_id'));
 }finally{await db.close();}
});
