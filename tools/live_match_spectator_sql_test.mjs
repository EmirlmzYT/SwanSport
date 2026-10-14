import {fixture} from './referee_cockpit_sql_test.mjs';
import {apply,actor,call,id,officer,coach,child,guardian,admin} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const migration=await readFile(new URL('../supabase/migrations/0116_live_match_spectator_hub.sql',import.meta.url),'utf8');
const referee=id(71),away=id(91),bench=id(92);
async function owner(db){await db.exec('reset role');await actor(db,officer);}
async function auth(db,p){await owner(db);await actor(db,p);await db.exec('set role authenticated');}
async function setup(){const f=await fixture();try{
  await owner(f.db);await f.db.exec('alter table clubs add column logo_path text;');
  await apply(f.db,migration);await call(f.db,'federation_publish_program',[f.org,true]);
  await f.db.query('update org_matches set starts_at=now() where id=$1',[f.match]);
  await auth(f.db,referee);await call(f.db,'referee_verify_lineup',[f.match,[child],[away],null,[bench],[]]);
  return f;
}catch(e){await f.db.close();throw e;}}
async function event(db,match,kind,side=null,athlete=null,replace=null,card=null){
  await auth(db,referee);const st=await call(db,'referee_match_state',[match]);
  return call(db,'referee_append_match_event',[match,(await db.query('select gen_random_uuid() id')).rows[0].id,st.version,kind,side,athlete,replace,card]);
}
async function anon(db){await owner(db);await actor(db,null);await db.exec('set role anon');}
test('0116 anon/auth safe live projection, undo and private-source ACLs stay closed',async()=>{
 const {db,match}=await setup();try{
  await event(db,match,'clock_start');await event(db,match,'score','home',child);
  await event(db,match,'card','away',away,null,'yellow');
  await owner(db);await db.query("update profiles set full_name='PRIVATE_DECLINED_NAME' where id=$1",[id(75)]);
  await db.query("insert into match_officials(match_id,profile_id,duty,status,decline_reason) values($1,$2,'assistant_referee_1','declined','PRIVATE_EXCUSE')",[match,id(75)]);
  for(const p of [null,coach,admin]){
   if(p)await auth(db,p);else await anon(db);
   const st=await call(db,'match_public_live_state',[match]);assert.equal(st.is_live,true);assert.equal(st.period_home,1);
   assert.equal(st.events.length,2);assert.equal(st.events[0].athlete_name,'sporcu');assert.equal(st.events[1].athlete_name,'Adult Athlete');
   assert.doesNotMatch(JSON.stringify(st),/report_notes|decline_reason|license|national_id|athlete_id|replacement_id|operation_id|actor_id|PRIVATE/);
   await assert.rejects(db.exec('select * from match_live_events'),/permission/);
   await assert.rejects(call(db,'_public_match_header',[match]),/permission/);
  }
  await auth(db,referee);const current=await call(db,'referee_match_state',[match]);
  await call(db,'referee_append_match_event',[match,id(990),current.version,'undo']);
  await anon(db);assert.equal((await call(db,'match_public_live_state',[match])).events.length,1);
  const rows=(await db.query('select public_live_matches(null,null) v')).rows;assert.equal(rows.length,1);
  assert.equal(rows[0].v.match_id,match);assert.equal(rows[0].v.home_score,0); // tennis scoreboard is SET wins, not game totals
 }finally{await db.close();}
});
test('0116 publication revocation, unknown/private IDs, filters, cancellation and replay fail closed',async()=>{
 const {db,match,org}=await setup();try{
  await anon(db);assert.equal((await db.query("select public_live_matches('futbol',null) v")).rows.length,0);
  assert.equal(await call(db,'match_public_live_state',[id(999)]),null);
  assert.equal(await call(db,'match_public_roster',[id(999)]),null);
  await owner(db);await call(db,'federation_publish_program',[org,false]);
  await anon(db);assert.equal(await call(db,'match_public_live_state',[match]),null);assert.equal(await call(db,'match_public_roster',[match]),null);
  await owner(db);await apply(db,migration);await apply(db,migration);
  assert.equal((await db.query("select count(*) n from faq_entries where feature='live_match_hub'")).rows[0].n,1);
  assert.equal((await db.query("select audience from feature_flags where key='live_match_hub'")).rows[0].audience,'admins');
  assert.equal((await db.query('select is_public from organizations where id=$1',[org])).rows[0].is_public,false);
  assert.equal((await db.query("select count(*) n from pg_proc where proname='public_live_matches'")).rows[0].n,1);
 }finally{await db.close();}
});
test('0116 locked roster only; child grant/refusal/revocation and adulthood use existing public consent contract',async()=>{
 const {db,match}=await setup();try{
  await anon(db);let roster=await call(db,'match_public_roster',[match]);assert.equal(roster.players.length,3);
  assert.equal(roster.players.find(p=>p.side==='home'&&p.selection==='starter').name,'sporcu');assert.doesNotMatch(JSON.stringify(roster),/athlete_id|profile_id|license|birth_date/);
  await auth(db,guardian);await call(db,'set_athlete_publicity',[child,true]);
  await anon(db);assert.ok((await call(db,'match_public_roster',[match])).players.some(p=>p.name==='Private Child'));
  await auth(db,guardian);await call(db,'set_athlete_publicity',[child,false]);
  await anon(db);assert.ok((await call(db,'match_public_roster',[match])).players.some(p=>p.name==='sporcu'));
  await owner(db);await db.query("update athletes set birth_date=current_date-interval '18 years' where id=$1",[child]);
  await anon(db);assert.ok((await call(db,'match_public_roster',[match])).players.some(p=>p.name==='Private Child'));
 }finally{await db.close();}
});
test('0116 registered report notes remain private; official correction overrides journal and 48h uses result time',async()=>{
 const {db,match}=await setup();try{
  for(let set=0;set<2;set++){
    for(let game=0;game<6;game++)await event(db,match,'score','home',child);
    await event(db,match,'period_end');
  }
  await auth(db,referee);const state=await call(db,'referee_match_state',[match]);
  await call(db,'referee_submit_match_report',[match,id(998),state.version,'PRIVATE_REPORT_NOTES / DISCIPLINARY_REFERRAL']);
  await anon(db);let publicState=await call(db,'match_public_live_state',[match]);
  assert.equal(publicState.is_live,false);assert.equal(publicState.home_score,2);assert.equal(publicState.away_score,0);
  assert.deepEqual(publicState.sets,[{home:6,away:0},{home:6,away:0}]);
  assert.doesNotMatch(JSON.stringify(publicState),/PRIVATE_REPORT|DISCIPLINARY|report_notes|revision_id/);
  await owner(db);await call(db,'federation_publish_result',[match,{type:'sets',sets:[{home:0,away:6},{home:0,away:6}]},'Correction',1]);
  await anon(db);publicState=await call(db,'match_public_live_state',[match]);assert.equal(publicState.home_score,0);assert.equal(publicState.away_score,2);
  assert.equal((await db.query('select public_live_matches(null,null) v')).rows.length,1);
  await owner(db);await db.query("update org_matches set starts_at=now()-interval '10 days' where id=$1",[match]);
  await anon(db);assert.equal((await db.query('select public_live_matches(null,null) v')).rows.length,1);
 }finally{await db.close();}
});
