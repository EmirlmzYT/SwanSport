// Real migration/RPC fixtures; no production connection or source ACL changes.
import './live_match_spectator_sql_test.mjs';
import {fixture} from './referee_cockpit_sql_test.mjs';
import {apply,actor,call,id,officer,child,other,coach} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const sql=async n=>readFile(new URL(`../supabase/migrations/${n}.sql`,import.meta.url),'utf8');
const migration=await sql('0117_league_standings_engine');
async function owner(db){await db.exec('reset role');await actor(db,officer);}
async function anon(db){await owner(db);await actor(db,null);await db.exec('set role anon');}
async function auth(db,p){await owner(db);await actor(db,p);await db.exec('set role authenticated');}
async function setup(){const f=await fixture();try{
  await owner(f.db);await f.db.exec('alter table clubs add column logo_path text');
  await apply(f.db,await sql('0116_live_match_spectator_hub'));await apply(f.db,migration);
  await call(f.db,'federation_publish_program',[f.org,true]);return f;
}catch(e){await f.db.close();throw e;}}
async function table(db,org,live=false){return (await db.query('select * from public_league_standings($1,$2)',[org,live])).rows;}
async function result(db,match,home,away,version=0){await owner(db);
  return call(db,'federation_publish_result',[match,{type:'score',home,away},'Fixture result correction',version]);}
async function match(db,org,h,a,days=0){await owner(db);const mid=await call(db,'federation_schedule_match',[
  org,h,a,new Date().toISOString()]);
  // Historical fixture chronology: scheduling RPC correctly forbids dates
  // outside the active program. Its read-only history still spans all dates.
  if(days!==0)await db.query('update org_matches set starts_at=$2 where id=$1',[mid,new Date(Date.now()+days*86400000).toISOString()]);
  return mid;
}
async function participant(db,org,n,name){await owner(db);const club=id(200+n),athlete=id(300+n);
  await db.query("insert into clubs(id,name,sport_code) values($1,$2,'tenis')",[club,name]);
  await call(db,'federation_register_club',[club,'tenis',name,'ST-'+n,'34']);
  const p=await call(db,'federation_add_participant',[org,club,null]);
  await db.query("insert into athletes(id,club_id,first_name,last_name,birth_date) values($1,$2,'Private','Athlete',current_date-interval '25 years')",[athlete,club]);
  await call(db,'federation_register_license',[athlete,'tenis','ST-L-'+n,'2090-01-01']);
  // Seed a valid historical snapshot as the fixture owner, as phase 3 does.
  // This is not a new client write path or a bypass in the tested migration.
  await db.query("insert into org_roster_revisions(participant_id,version,athlete_ids,reason,actor_id) values($1,1,$2,'Fixture roster',$3)",[p,[athlete],officer]);return p;
}
async function event(db,match,kind,side=null){await auth(db,id(71));const st=await call(db,'referee_match_state',[match]);
  return call(db,'referee_append_match_event',[match,(await db.query('select gen_random_uuid() id')).rows[0].id,st.version,kind,side]);}

test('0117 public whitelist, private/amateur/unknown gates, zero rows, helpers and replay',async()=>{
 const {db,org,match:mid,participant:home,away}=await setup();try{
  for(const p of [null,coach]){if(p)await auth(db,p);else await anon(db);
    const rows=await table(db,org);assert.equal(rows.length,2);assert.equal(Number(rows[0].points),0);
    assert.equal(rows[0].participant_name,'Legal Club');assert.deepEqual(rows[0].form,[]);
    assert.doesNotMatch(JSON.stringify(rows),/athlete_id|profile_id|PRIVATE|reason|national_id|health|roster/);
    const ctx=await call(db,'match_public_standings_context',[mid]);assert.equal(ctx.org_id,org);
    assert.equal(ctx.home_participant_id,home);assert.equal(ctx.away_participant_id,away);
    assert.equal((await db.query('select * from public_standings_leagues()')).rows[0].id,org);
    await assert.rejects(db.exec('select * from org_result_revisions'),/permission/);
    await assert.rejects(call(db,'_public_match_header',[mid]),/permission/);
    assert.deepEqual(await table(db,id(9999)),[]);
  }
  await owner(db);await call(db,'federation_publish_program',[org,false]);await anon(db);
  assert.deepEqual(await table(db,org,true),[]);assert.equal(await call(db,'match_public_standings_context',[mid]),null);
  assert.deepEqual((await db.query('select * from public_standings_leagues()')).rows,[]);
  await owner(db);const amateur=(await db.query("insert into organizations(name,is_public,owner_id,sport_code) values('PRIVATE_AMATEUR',false,$1,'tenis') returning id",[coach])).rows[0].id;
  await anon(db);assert.deepEqual(await table(db,amateur),[]);
  await owner(db);await db.query('update organizations set is_public=true where id=$1',[amateur]);await anon(db);
  assert.deepEqual(await table(db,amateur,true),[]);
  await owner(db);await db.exec("update feature_flags set audience='off' where key='league_standings'");await apply(db,migration);
  assert.equal((await db.query("select audience from feature_flags where key='league_standings'")).rows[0].audience,'off');
  assert.equal((await db.query("select count(*)::int n from faq_entries where feature='league_standings'")).rows[0].n,1);
  assert.equal((await db.query("select count(*)::int n from pg_proc where proname='public_league_standings'")).rows[0].n,1);
 }finally{await db.close();}
});
test('0117 3/1/0, whole season, correct latest revision and no duplicate virtual finals',async()=>{
 const {db,org,participant:h,away:a}=await setup();try{
  const first=await match(db,org,h,a,-10);await result(db,first,3,1);
  const second=await match(db,org,h,a,-5);await result(db,second,2,2);
  await anon(db);let rows=await table(db,org);let home=rows.find(r=>r.participant_id===h);
  assert.equal(Number(home.played),2);assert.equal(Number(home.won),1);assert.equal(Number(home.drawn),1);
  assert.equal(Number(home.points),4);assert.equal(Number(home.goal_diff),2);assert.equal(Number(home.goals_for),5);
  await result(db,first,0,2,1);await anon(db);rows=await table(db,org,true);home=rows.find(r=>r.participant_id===h);
  assert.equal(Number(home.played),2);assert.equal(Number(home.points),1);assert.equal(Number(home.lost),1);
  assert.equal(Number(rows.find(r=>r.participant_id===a).points),4);assert.equal(rows.some(r=>r.is_provisional),false);
 }finally{await db.close();}
});
test('0117 deterministic points/goal-difference/goals/name tiebreak and zero-match participants',async()=>{
 const {db,org,participant:a,away:b}=await setup();try{
  const c=await participant(db,org,1,'Zeta Club');const d=await participant(db,org,2,'Alpha Zero');
  const ab=await match(db,org,a,b),bc=await match(db,org,b,c),ca=await match(db,org,c,a);
  await result(db,ab,1,0);await result(db,bc,3,2);await result(db,ca,2,1);await anon(db);
  let rows=await table(db,org);assert.deepEqual(rows.map(r=>r.participant_id),[c,b,a,d]);
  assert.deepEqual(rows.map(r=>Number(r.rank)),[1,2,3,4]);assert.equal(Number(rows[3].played),0);
  // Equal points: positive difference outranks a higher goals-for value.
  await result(db,ab,3,0,1);await result(db,bc,5,4,1);await result(db,ca,2,0,1);await anon(db);
  rows=await table(db,org);assert.deepEqual(rows.slice(0,3).map(r=>r.participant_id),[c,a,b]);
  await owner(db);const game=await match(db,org,a,d);await result(db,game,4,0);await anon(db);
  rows=await table(db,org);assert.equal(rows[0].participant_id,a);
  // Fresh tied zero-match participants use names, not insertion order.
  const e=await participant(db,org,3,'Zulu Zero');const f=await participant(db,org,4,'Beta Zero');await anon(db);
  const zeros=(await table(db,org)).filter(r=>Number(r.played)===0);assert.deepEqual(zeros.map(r=>r.participant_id),[f,e]);
 }finally{await db.close();}
});
test('0117 form is last five by fixture chronology, oldest to newest, correction does not reorder',async()=>{
 const {db,org,participant:h,away:a}=await setup();try{
  const outcomes=['W','D','L','W','D','L','W'];let oldest;
  for(let i=0;i<outcomes.length;i++){const mid=await match(db,org,h,a,i-20);oldest??=mid;
    await result(db,mid,outcomes[i]==='W'?2:outcomes[i]==='D'?1:0,outcomes[i]==='L'?2:1);}
  await result(db,oldest,0,9,1);await anon(db);const row=(await table(db,org)).find(r=>r.participant_id===h);
  assert.deepEqual(row.form,['L','W','D','L','W']);assert.equal(Number(row.played),7);
 }finally{await db.close();}
});
test('0117 live mode is undo-aware, ignores scheduled scores, counts tennis sets, official result wins',async()=>{
 const {db,org,match:mid,participant:h}=await setup();try{
  await anon(db);assert.equal(Number((await table(db,org,true))[0].played),0);
  await auth(db,id(71));await call(db,'referee_verify_lineup',[mid,[child],[id(91)],null,[id(92)],[]]);
  for(let i=0;i<6;i++)await event(db,mid,'score','home');await event(db,mid,'period_end');
  await anon(db);let home=(await table(db,org,true)).find(r=>r.participant_id===h);
  assert.equal(Number(home.points),3);assert.equal(Number(home.goals_for),1);assert.equal(home.is_provisional,true);
  assert.equal(Number((await table(db,org,false))[0].played),0);
  await event(db,mid,'undo');await anon(db);home=(await table(db,org,true)).find(r=>r.participant_id===h);
  assert.equal(Number(home.points),1);assert.equal(Number(home.goals_for),0);
  await owner(db);await call(db,'federation_publish_result',[mid,{type:'sets',sets:[{home:0,away:6},{home:0,away:6}]},'Official final',0]);
  await anon(db);home=(await table(db,org,true)).find(r=>r.participant_id===h);
  assert.equal(Number(home.played),1);assert.equal(Number(home.goals_against),2);assert.equal(home.is_provisional,false);
 }finally{await db.close();}
});
test('0117 organization scoring rules retained and unsupported protocols never become fake zero draws',async()=>{
 const {db,org,match:mid,participant:h}=await setup();try{
  await owner(db);await db.query('update organizations set win_points=2,draw_points=0,loss_points=1 where id=$1',[org]);
  await result(db,mid,0,1);await anon(db);assert.equal(Number((await table(db,org)).find(r=>r.participant_id===h).points),1);
  await owner(db);await call(db,'federation_publish_result',[mid,{type:'rank',entries:[{athlete_id:child,value:1,placement:1}]},'Rank protocol',1]);
  await anon(db);assert.equal(Number((await table(db,org))[0].played),0);
  await owner(db);await db.query("update organizations set kind='cup' where id=$1",[org]);await anon(db);
  assert.deepEqual(await table(db,org,true),[]);assert.equal(await call(db,'match_public_standings_context',[mid]),null);
 }finally{await db.close();}
});
