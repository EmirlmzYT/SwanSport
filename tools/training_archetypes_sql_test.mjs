import {PGlite} from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const sql=async file=>readFile(new URL(`../supabase/migrations/${file}.sql`,import.meta.url),'utf8');
const migration=await sql('0105_training_drill_archetypes');
const id=n=>`20000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const coach=id(1),player=id(2),outsider=id(3),club=id(10),athlete=id(20);
const config=(archetype='target_score')=>({archetype,set_count:2,units_per_set:20,prep_seconds:10,shoot_seconds:60,collect_seconds:30,rest_seconds:15,max_unit_score:10,entry_mode:'flexible',mode:'technique'});
const attempt={drill_name:'servis',successful:16,faults:4,total_attempts:20,success_rate:0.8};
const lap={lap_number:3,split_millis:29400,distance_meters:50,stroke_rate:34};
const rally={rallies:20,winners:8,unforced_errors:4};
const target={marks:['X','10','9','M']};
const metrics={target_score:target,attempt_drill:attempt,lap_interval:lap,combat_rally:rally};
async function call(db,name,args=[]){
 const jsonArgs={valid_training_config:[0],valid_drill_metric:[1],submit_set_score:[3,4],correct_locked_set:[3,4]};
 const params=args.map((a,i)=>jsonArgs[name]?.includes(i)&&a!==null?JSON.stringify(a):a);
 return (await db.query(`select ${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) v`,params)).rows[0].v;
}
async function actor(db,p){await db.query("select set_config('test.actor',$1,false)",[p]);}
async function apply(db,s){await db.exec('begin');try{await db.exec(s);await db.exec('commit');}catch(e){await db.exec('rollback');throw e;}}
async function setup(){const db=new PGlite();try{
 await db.exec(`create role anon;create role authenticated;create schema auth;
 create table auth.users(id uuid primary key,raw_user_meta_data jsonb default '{}');
 create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 grant usage on schema auth to anon,authenticated;grant execute on function auth.uid() to anon,authenticated;
 alter default privileges in schema public grant all on tables to authenticated;
 alter default privileges in schema public grant all on sequences to authenticated;`);
 await db.exec((await sql('0001_foundation')).replace('create extension if not exists "pgcrypto";',''));
 await db.exec(await sql('0002_rls_policies'));await db.exec(await sql('0004_roles_verification'));
 await db.exec(`create table sports(code text primary key,name text);insert into sports values('okculuk','Okçuluk'),('voleybol','Voleybol');
 create table events(id uuid primary key,club_id uuid,team_id uuid,starts_at timestamptz,title text);
 create function can_view_athlete_performance(p uuid) returns boolean language sql security definer as $$select exists(select 1 from athletes a where a.id=p and (a.profile_id=auth.uid() or is_club_staff(a.club_id)))$$;
 create function eligibility_gate(p uuid) returns jsonb language sql as $$select '{"allowed":true}'::jsonb$$;`);
 await db.exec(await sql('0071_training_sessions'));await db.exec(await sql('0072_training_rpc'));await db.exec(await sql('0074_training_function_grants'));
 await db.exec(`insert into auth.users(id) values('${coach}'),('${player}'),('${outsider}');
 insert into clubs(id,name,status) values('${club}','Training Club','active');
 insert into club_memberships(club_id,profile_id,role) values('${club}','${coach}','coach'),('${club}','${player}','athlete');
 insert into athletes(id,club_id,profile_id,first_name,last_name) values('${athlete}','${club}','${player}','Test','Athlete');`);
 await apply(db,migration);await actor(db,player);return db;
 }catch(e){await db.close();throw e;}}
async function session(db,a='target_score',cfg={}){
 const p=id(100+Object.keys(metrics).indexOf(a));const s=id(200+Object.keys(metrics).indexOf(a));
 await db.query("insert into training_protocols(id,club_id,sport_code,name,config) values($1,$2,'voleybol','Drill',$3)",[p,club,{...config(a),...cfg}]);
 await db.query('insert into training_sessions(id,club_id,protocol_id) values($1,$2,$3)',[s,club,p]);
 await db.query('insert into training_session_participants(session_id,athlete_id) values($1,$2)',[s,athlete]);return s;
}
test('0105 reapplies, no old submit overload or PUBLIC/anon execute, no anon table reads',async()=>{const db=await setup();try{
 await apply(db,migration);
 for(const name of ['submit_set_score','correct_locked_set'])assert.equal((await db.query("select count(*)::int n from pg_proc where pronamespace='public'::regnamespace and proname=$1",[name])).rows[0].n,1);
 for(const signature of ['submit_set_score(uuid,int,numeric,jsonb,jsonb)','submit_coach_drill_note(uuid,uuid,text,text)','valid_drill_metric(text,jsonb)','training_next_phase(text,int,jsonb)','training_phase_seconds(text,jsonb)','valid_training_config(jsonb)','_training_number(jsonb,text,numeric,numeric,boolean)','advance_session_phase(uuid,text,text)','correct_locked_set(uuid,numeric,text,jsonb,jsonb)','lock_session_results(uuid)','session_summary(uuid)','session_overview(uuid)','my_training_history(int)','my_live_training_session()']){
  assert.equal((await db.query("select has_function_privilege('anon',$1,'execute') v",[signature])).rows[0].v,false);
  assert.equal((await db.query("select count(*)::int n from pg_proc p cross join lateral aclexplode(p.proacl) a where p.oid=$1::regprocedure and a.grantee=0",[signature])).rows[0].n,0);
 }
 await db.exec('set role anon');await assert.rejects(db.query('select metric_payload from training_sets'),/permission/);await db.exec('reset role');
 }finally{await db.close();}});
test('config preserves legacy archery, collect only required for target; invalid JSON is false without casts',async()=>{const db=await setup();try{
 const legacy=config();delete legacy.archetype;assert.equal(await call(db,'valid_training_config',[legacy]),true);
 for(const a of Object.keys(metrics)){const c=config(a);delete c.collect_seconds;assert.equal(await call(db,'valid_training_config',[c]),a!=='target_score');}
 for(const key of ['set_count','units_per_set','prep_seconds','shoot_seconds','rest_seconds','max_unit_score','entry_mode','mode']){
  for(const bad of [null,{},[],true,'bad']) assert.equal(await call(db,'valid_training_config',[{...config(),[key]:bad}]),false,`${key} ${bad}`);
  const c=config();delete c[key];assert.equal(await call(db,'valid_training_config',[c]),false,key);
 }
 for(const bad of [null,{},[],true,'bad',1])assert.equal(await call(db,'valid_training_config',[{...config(),archetype:bad}]),false);
 for(const bad of [null,[],{},'bad'])assert.equal(await call(db,'valid_training_config',[bad]),false);
 for(const n of [0,-1,1.2,1e20])assert.equal(await call(db,'valid_training_config',[{...config(),set_count:n}]),false);
 }finally{await db.close();}});
for(const a of Object.keys(metrics)){
 test(`${a}: valid metric, required/type/range/unknown field validation`,async()=>{const db=await setup();try{
  const m=metrics[a];assert.equal(await call(db,'valid_drill_metric',[a,m]),true);
  for(const key of Object.keys(m)){
   const copy={...m};delete copy[key];if(key!=='stroke_rate')assert.equal(await call(db,'valid_drill_metric',[a,copy]),a==='target_score',key);
   for(const bad of [null,{},true])assert.equal(await call(db,'valid_drill_metric',[a,{...m,[key]:bad}]),false,key);
  }
  assert.equal(await call(db,'valid_drill_metric',[a,{...m,athlete_id:athlete}]),false);
  assert.equal(await call(db,'valid_drill_metric',[a,{}]),a==='target_score');
  for(const bad of [null,[],true,'bad'])assert.equal(await call(db,'valid_drill_metric',[a,bad]),false);
 }finally{await db.close();}});
 test(`${a}: actual phase RPC, skip restrictions, score persistence, completion and lock`,async()=>{const db=await setup();try{
  const s=await session(db,a);await actor(db,coach);
  const active=a==='target_score'?'shoot':a==='lap_interval'?'lap_active':'active_drill';
  await call(db,'advance_session_phase',[s]);assert.equal((await db.query('select current_phase from training_sessions where id=$1',[s])).rows[0].current_phase,active);
  if(a!=='target_score')await assert.rejects(call(db,'advance_session_phase',[s,'collect','invalid skip']),/Arketip/);
  await actor(db,player);await db.exec('set role authenticated');
  const r=await call(db,'submit_set_score',[s,1,null,null,metrics[a]]);
  assert.deepEqual((await db.query('select metric_payload from training_sets where id=$1',[r.set_id])).rows[0].metric_payload,metrics[a]);
  assert.equal((await db.query('update training_sets set metric_payload=$1 where id=$2 returning id',[{},r.set_id])).rows.length,0);
  await db.exec('reset role');await actor(db,coach);
  const summary=(await db.query('select * from session_summary($1)',[s])).rows[0];assert.equal(summary.sets_done,1);
  if(a==='lap_interval'){assert.equal(summary.total_score,null);assert.equal(summary.units_expected,2);}
  await call(db,'lock_session_results',[s]);await actor(db,player);
  await assert.rejects(call(db,'submit_set_score',[s,1,null,null,metrics[a]]),/kapanmış|onaylanmış/);
  const corrected=a==='target_score'?{marks:['10','8','M']}:a==='attempt_drill'?{...attempt,successful:15,faults:5,success_rate:0.75}:a==='lap_interval'?{...lap,split_millis:28000}:{...rally,winners:9};
  await assert.rejects(call(db,'correct_locked_set',[r.set_id,null,'forged',null,corrected]),/yetkin/);
  await actor(db,coach);
  await assert.rejects(call(db,'correct_locked_set',[r.set_id,null,'',null,corrected]),/gerekçesi/);
  await assert.rejects(call(db,'correct_locked_set',[r.set_id,20,'scalar mismatch',null]),/metric_payload/);
  await call(db,'correct_locked_set',[r.set_id,null,'Drill düzeltmesi',null,corrected]);
  const updated=(await db.query('select metric_payload,locked_at from training_sets where id=$1',[r.set_id])).rows[0];
  assert.deepEqual(updated.metric_payload,corrected);assert.ok(updated.locked_at);
  const audit=(await db.query("select old_value,new_value from training_session_events where action='correct'")).rows[0];
  assert.deepEqual(audit.old_value.metric_payload,metrics[a]);assert.deepEqual(audit.new_value.metric_payload,corrected);
 }finally{await db.close();}});
}
test('legacy entries/totals, malformed types and locked upsert remain safe',async()=>{const db=await setup();try{
 const s=await session(db);const r=await call(db,'submit_set_score',[s,1,null,[10,null,9]]);assert.equal(r.total,19);assert.equal(r.units,2);
 assert.deepEqual((await db.query('select metric_payload from training_sets')).rows[0].metric_payload,{});
 await assert.rejects(call(db,'submit_set_score',[s,1,null,['bad']]),/puanı/);
 await assert.rejects(call(db,'submit_set_score',[s,null,10,null]),/numarası/);
 await db.query('update training_sets set locked_at=now() where id=$1',[r.set_id]);
 await assert.rejects(call(db,'submit_set_score',[s,1,15,null]),/onaylanmış/);
 await actor(db,outsider);await assert.rejects(call(db,'submit_set_score',[s,1,10,null]),/kayıtlı/);
 await actor(db,coach);await call(db,'correct_locked_set',[r.set_id,18,'legacy correction',null]);
 assert.equal((await db.query('select total_score from training_sets where id=$1',[r.set_id])).rows[0].total_score,'18.00');
}finally{await db.close();}});

test('all non-target phase transitions, zero rest, last set, pause and historical metrics remain readable',async()=>{const db=await setup();try{
 for(const a of ['attempt_drill','lap_interval','combat_rally']){
  const s=await session(db,a);await actor(db,coach);
  const active=a==='lap_interval'?'lap_active':'active_drill',rest=a==='lap_interval'?'rest_interval':'rest';
  await call(db,'advance_session_phase',[s]);await call(db,'set_training_pause',[s,true,'rest']);
  assert.ok((await db.query('select paused_at from training_sessions where id=$1',[s])).rows[0].paused_at);
  await call(db,'set_training_pause',[s,false,null]);
  await call(db,'advance_session_phase',[s]);assert.equal((await db.query('select current_phase from training_sessions where id=$1',[s])).rows[0].current_phase,rest);
  await call(db,'advance_session_phase',[s]);assert.equal((await db.query('select current_set from training_sessions where id=$1',[s])).rows[0].current_set,2);
  await call(db,'advance_session_phase',[s]);await call(db,'advance_session_phase',[s]);
  assert.equal((await db.query('select status from training_sessions where id=$1',[s])).rows[0].status,'review');
  const cfg=config(a);cfg.rest_seconds=0;
  assert.deepEqual(await call(db,'training_next_phase',[active,1,cfg]),{phase:'prep',set_no:2});
  await actor(db,player);await call(db,'submit_set_score',[s,1,null,null,metrics[a]]);
  await call(db,'submit_set_score',[s,2,null,null,metrics[a]]);
  const history=(await db.query('select * from my_training_history(30)')).rows.find(r=>r.session_id===s);
  assert.equal(history.sets_done,2);
  await actor(db,coach);const overview=(await db.query('select * from session_overview($1)',[s])).rows[0];assert.equal(overview.completed_count,1);
  if(a==='lap_interval'){assert.equal(overview.team_total,null);assert.equal(overview.units_expected,2);}
 }
}finally{await db.close();}});

test('server rejects mismatched counters, out-of-range values, excess units and dual score sources atomically',async()=>{const db=await setup();try{
 for(const [a,m] of Object.entries(metrics)){
  const s=await session(db,a);
  await assert.rejects(call(db,'submit_set_score',[s,1,10,null,m]),/ikinci skor|yalnız metric/);
  await assert.rejects(call(db,'submit_set_score',[s,1,null,null,{...m,extra:1}]),/metriği/);
  assert.equal((await db.query('select count(*)::int n from training_sets where session_id=$1',[s])).rows[0].n,0);
 }
 for(const [a,m] of [
  ['attempt_drill',{...attempt,total_attempts:19}],['attempt_drill',{...attempt,success_rate:0.9}],
  ['attempt_drill',{...attempt,successful:-1}],['attempt_drill',{...attempt,faults:4.5}],
  ['lap_interval',{...lap,split_millis:0}],['lap_interval',{...lap,distance_meters:'50'}],
  ['lap_interval',{...lap,stroke_rate:301}],['combat_rally',{...rally,rallies:5}],
  ['target_score',{marks:['11']}],['target_score',{marks:[]}],
 ])assert.equal(await call(db,'valid_drill_metric',[a,m]),false);
 const excess={...attempt,successful:21,faults:0,total_attempts:21,success_rate:1};
 await assert.rejects(call(db,'submit_set_score',[id(201),1,null,null,excess]),/protokol dışında/);
}finally{await db.close();}});

test('simple target metrics preserve marks and compute a bounded score',async()=>{const db=await setup();try{
 const s=await session(db,'target_score',{entry_mode:'simple'});
 const r=await call(db,'submit_set_score',[s,1,null,null,target]);assert.equal(r.total,29);assert.equal(r.units,4);
 assert.deepEqual((await db.query('select metric_payload from training_sets where id=$1',[r.set_id])).rows[0].metric_payload,target);
}finally{await db.close();}});

test('integral decimal JSON numbers work after validation; fractional counters are rejected',async()=>{const db=await setup();try{
 const p=id(501),s=id(502);
 const cfg=JSON.stringify(config('attempt_drill')).replace('"set_count":2','"set_count":2.0').replace('"units_per_set":20','"units_per_set":20.0');
 await db.query("insert into training_protocols(id,club_id,sport_code,name,config) values($1,$2,'voleybol','Decimal JSON',$3)",[p,club,cfg]);
 await db.query('insert into training_sessions(id,club_id,protocol_id) values($1,$2,$3)',[s,club,p]);
 await db.query('insert into training_session_participants(session_id,athlete_id) values($1,$2)',[s,athlete]);
 const metric=JSON.stringify(attempt).replace('"total_attempts":20','"total_attempts":20.0');
 const r=(await db.query('select submit_set_score($1,1,null,null,$2) v',[s,metric])).rows[0].v;assert.equal(r.units,20);
 await actor(db,coach);await call(db,'advance_session_phase',[s]);
 assert.equal((await db.query('select * from session_overview($1)',[s])).rows[0].set_count,2);
 await actor(db,player);assert.equal((await db.query('select * from my_live_training_session()')).rows[0].set_count,2);
 const fractional=metric.replace('"total_attempts":20.0','"total_attempts":20.5');
 await assert.rejects(db.query('select submit_set_score($1,1,null,null,$2)',[s,fractional]),/metriği/);
}finally{await db.close();}});

test('assistant levels retain notes; private metrics and notes do not open to an unrelated profile',async()=>{const db=await setup();try{
 const s=await session(db,'attempt_drill');await call(db,'submit_set_score',[s,1,null,null,attempt]);
 await actor(db,coach);
 for(const level of [1,2]){
  await db.query("insert into profile_credentials(profile_id,kind,coach_level,status) values($1,'coach',$2,'approved')",[coach,level]);
  await call(db,'submit_coach_drill_note',[s,athlete,'Teknik not',`kademe-${level}`]);
 }
 await actor(db,outsider);await db.exec('set role authenticated');
 assert.equal((await db.query('select metric_payload from training_sets')).rows.length,0);
 assert.equal((await db.query("select new_value from training_session_events where action='drill_note'")).rows.length,0);
 await assert.rejects(call(db,'submit_coach_drill_note',[s,athlete,'not','servis']),/yetkin/);
 await db.exec('reset role');
}finally{await db.close();}});
test('coach drill notes use existing audit store and reject outsiders, missing athletes and personal sessions',async()=>{const db=await setup();try{
 const s=await session(db,'attempt_drill');
 for(const user of [player,outsider]){await actor(db,user);await assert.rejects(call(db,'submit_coach_drill_note',[s,athlete,'note','servis']),/yetkin/);}
 await actor(db,coach);await call(db,'submit_coach_drill_note',[s,athlete,'Dirsek yüksek','servis']);
 assert.deepEqual((await db.query("select new_value from training_session_events where action='drill_note'")).rows[0].new_value,{note:'Dirsek yüksek',tag:'servis'});
 await assert.rejects(call(db,'submit_coach_drill_note',[s,id(999),'note','servis']),/oturumda/);
 await assert.rejects(call(db,'submit_coach_drill_note',[s,athlete,' ','servis']),/geçersiz/);
 await db.query("update training_sessions set kind='personal',athlete_id=$2 where id=$1",[s,athlete]);
 await actor(db,player);await assert.rejects(call(db,'submit_coach_drill_note',[s,athlete,'note','servis']),/yetkin/);
 }finally{await db.close();}});
