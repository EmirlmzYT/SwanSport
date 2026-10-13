import {fixture as sportsFixture} from './sports_role_hierarchy_sql_test.mjs';
import {apply,actor,call,id,officer,coach,child,club,other,admin,guardian} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const referee=id(71),awayAthlete=id(91),bench=id(92),unselected=id(93);
const sql=async n=>readFile(new URL(`../supabase/migrations/${n}.sql`,import.meta.url),'utf8');
const migration=await sql('0112_referee_cockpit_engine');
async function owner(db,p=officer){await db.exec('reset role');await actor(db,p);}
async function auth(db,p){await owner(db,p);await db.exec('set role authenticated');}
export async function fixture(){
  const f=await sportsFixture();const {db,org,participant}=f;
  try{
    await owner(db);await db.exec(await sql('0053_feature_flags'));
    const faq=await sql('0069_faq_and_support');await db.exec(faq.slice(faq.indexOf('create table if not exists public.faq_entries'),faq.indexOf('create or replace function public.search_faq')));
    await db.exec('alter table faq_entries add column feature text references feature_flags(key)');
    await apply(db,await sql('0111_match_lineup_projection'));await apply(db,migration);
    await owner(db,coach);
    for(const [athlete,c] of [[awayAthlete,other],[bench,club],[unselected,club]]){
      await db.query("insert into athletes(id,club_id,first_name,last_name,birth_date) values($1,$2,'Adult','Athlete',current_date-interval '25 years')",[athlete,c]);
      await owner(db);await call(db,'federation_register_license',[athlete,'tenis','L-'+athlete,'2090-01-01']);
    }
    await auth(db,coach);await call(db,'federation_publish_roster',[participant,[child,bench,unselected],'available',1]);
    await owner(db);const away=await call(db,'federation_add_participant',[org,other,null]);
    await db.query("insert into org_roster_revisions(participant_id,version,athlete_ids,reason,actor_id) values($1,1,$2,'fixture roster',$3)",[away,[awayAthlete],officer]);
    const match=await call(db,'federation_schedule_match',[org,participant,away,new Date(Date.now()+172800000).toISOString()]);
    await db.query("insert into match_officials(match_id,profile_id,duty,status) values($1,$2,'head_referee','accepted')",[match,referee]);
    return {...f,match,away};
  }catch(e){await db.close();throw e;}
}
async function lock(db,match){await auth(db,referee);await call(db,'referee_verify_lineup',[match,[child],[awayAthlete],null,[bench],[]]);}
async function event(db,match,kind,side=null,athlete=null,replacement=null,card=null,op=null){
  const state=await call(db,'referee_match_state',[match]);
  const operation=op||(await db.query('select gen_random_uuid() id')).rows[0].id;
  return call(db,'referee_append_match_event',[match,operation,state.version,kind,side,athlete,replacement,card]);
}
test('0112 candidates are scoped, child names remain masked, and actor/role/branch acceptance is mandatory',async()=>{
  const {db,match}=await fixture();try{
    for(const p of [coach,admin,id(77),id(75)]){await auth(db,p);await assert.rejects(call(db,'referee_lineup_candidates',[match]),/görevi/);}
    await auth(db,referee);const rows=(await db.query('select * from referee_lineup_candidates($1)',[match])).rows;
    assert.equal(rows.find(r=>r.athlete_id===child).name,null);
    assert.equal(rows.filter(r=>r.side==='away').length,1);
    assert.doesNotMatch(JSON.stringify(rows),/phone|national_id|diagnosis|guardian/);
    await assert.rejects(call(db,'referee_match_state',[match]),/kilitli/);
    await owner(db);await db.query("update match_officials set duty='observer' where match_id=$1",[match]);
    await auth(db,referee);await assert.rejects(call(db,'referee_lineup_candidates',[match]),/görevi/);
  }finally{await db.close();}
});
test('0112 journal is atomically sequenced, retry-safe and append-only; undo survives a new read',async()=>{
  const {db,match}=await fixture();try{
    await lock(db,match);const op=id(901);
    const first=await call(db,'referee_append_match_event',[match,op,0,'score','home']);assert.equal(first.home_score,1);
    const retry=await call(db,'referee_append_match_event',[match,op,0,'score','home']);assert.equal(retry.version,1);
    await assert.rejects(call(db,'referee_append_match_event',[match,op,0,'score','away']),/kimliği/);
    await assert.rejects(call(db,'referee_append_match_event',[match,id(902),0,'score','home']),/sürümü/);
    const undone=await event(db,match,'undo');assert.equal(undone.home_score,0);assert.equal(undone.events.length,2);
    assert.equal((await call(db,'referee_match_state',[match])).home_score,0);
    await assert.rejects(db.exec('select * from match_live_events'),/permission/);
    await owner(db);await assert.rejects(db.exec('delete from match_live_events'),/değiştirilemez/);
    assert.equal((await db.query("select count(*)::int n from federation_audit where action='referee_live_event' and entity_id=$1",[match])).rows[0].n,2);
  }finally{await db.close();}
});
test('0112 substitutions/cards validate frozen side and active/bench lists; undo restores the state',async()=>{
  const {db,match}=await fixture();try{
    await lock(db,match);
    await assert.rejects(event(db,match,'card','home',awayAthlete,null,'yellow'),/sahada/);
    await assert.rejects(event(db,match,'substitution','home',child,unselected),/uygun/);
    const switched=await event(db,match,'substitution','home',child,bench);
    assert.deepEqual(switched.active_home,[bench]);
    const undone=await event(db,match,'undo');assert.deepEqual(undone.active_home,[child]);
    const red=await event(db,match,'card','home',child,null,'red');assert.deepEqual(red.active_home,[]);
  }finally{await db.close();}
});
test('0112 report uses journal, not submitted score; frozen esame drives CV and guardian notices; legacy rights remain closed',async()=>{
  const {db,match}=await fixture();try{
    await lock(db,match);
    // Two completed 6-0 sets; teniste score means games, not raw ball points.
    for(let set=0;set<2;set++){for(let game=0;game<6;game++)await event(db,match,'score','home');await event(db,match,'period_end');}
    const state=await call(db,'referee_match_state',[match]);const operation=id(903);
    const revision=await call(db,'referee_submit_match_report',[match,operation,state.version,'PRIVATE_REPORT']);
    assert.equal(await call(db,'referee_submit_match_report',[match,operation,state.version,'PRIVATE_REPORT']),revision);
    await assert.rejects(event(db,match,'score','home'),/kapalı/);
    await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:99,away:0},'forged',1]),/yetki|atama|görev/i);
    await owner(db);
    const result=(await db.query('select status,result_protocol from org_matches where id=$1',[match])).rows[0];assert.equal(result.status,'played');assert.equal(result.result_protocol.type,'sets');
    const achievements=(await db.query("select athlete_id from athlete_achievements where source_id=$1",[revision])).rows.map(r=>r.athlete_id);
    assert.deepEqual(achievements.sort(),[child,bench,awayAthlete].sort());assert.ok(!achievements.includes(unselected));
    assert.equal((await db.query('select count(*)::int n from _referee_write_context')).rows[0].n,0);
    assert.equal((await db.query('select count(*)::int n from notifications where result_revision_id=$1',[revision])).rows[0].n,1);
    assert.equal((await db.query('select match_protocol from org_result_revisions where id=$1',[revision])).rows[0].match_protocol,null);
    await assert.rejects(db.exec('delete from referee_match_reports'),/değiştirilemez/);
  }finally{await db.close();}
});
test('0112 replay preserves rows; private context cannot be forged; anonymous and direct writes are closed',async()=>{
  const {db,match}=await fixture();try{
    await lock(db,match);await event(db,match,'score','home');await owner(db);await apply(db,migration);
    assert.equal((await db.query("select audience from feature_flags where key='referee_cockpit'")).rows[0].audience,'admins');
    assert.equal(await call(db,'push_route',['referee_assignment',match]),'/hakem/gorevler');
    assert.equal(await call(db,'push_route',['match_result',match]),'/resmi-sonuc');
    await auth(db,referee);
    await assert.rejects(db.exec('insert into _referee_write_context values(txid_current(),auth.uid(),gen_random_uuid(),gen_random_uuid())'),/permission/);
    await assert.rejects(db.exec('select _referee_context(gen_random_uuid(),gen_random_uuid())'),/permission/);
    assert.equal((await call(db,'referee_match_state',[match])).home_score,1);
    await owner(db);await actor(db,null);await db.exec('set role anon');
    await assert.rejects(call(db,'referee_lineup_candidates',[match]),/permission/);
    await assert.rejects(db.exec('select * from match_live_events'),/permission/);
  }finally{await db.close();}
});

test('0112 candidate status shows medical/admin/discipline restrictions without clinical data',async()=>{
  const {db,match}=await fixture();try{
    for(const [status,expected] of [['rested','rested'],['injured_admin','rested'],['injured_medical','medical'],['suspended','suspended']]){
      await owner(db);await db.query("insert into org_match_lineup_notes(match_id,athlete_id,club_id,status,recorded_by) values($1,$2,$3,$4,$5) on conflict(match_id,athlete_id) do update set status=excluded.status",[match,child,club,status,officer]);
      await auth(db,referee);const row=(await db.query('select * from referee_lineup_candidates($1)',[match])).rows.find(r=>r.athlete_id===child);
      assert.equal(row.eligibility_status,expected);assert.equal(row.eligible,false);assert.equal(row.name,null);
    }
  }finally{await db.close();}
});
test('0112 audit failure rolls back the event; inactive/wrong branch/replaced authority cannot mutate',async()=>{
  const {db,match}=await fixture();try{
    await lock(db,match);await owner(db);
    await db.exec("create function test_fail_live_audit() returns trigger language plpgsql as $$begin if new.action='referee_live_event' then raise exception 'audit failed';end if;return new;end$$;create trigger test_fail_live_audit before insert on federation_audit for each row execute function test_fail_live_audit()");
    await auth(db,referee);await assert.rejects(event(db,match,'score','home'),/audit failed/);
    assert.equal((await call(db,'referee_match_state',[match])).version,0);
    await owner(db);await db.exec('drop trigger test_fail_live_audit on federation_audit');
    await db.query('update referee_profiles set is_active=false where profile_id=$1',[referee]);
    await auth(db,referee);await assert.rejects(call(db,'referee_append_match_event',[match,id(905),0,'score','home']),/görevi/);
    await owner(db);await db.query("update referee_profiles set is_active=true,sport_code='yuzme' where profile_id=$1",[referee]);
    await auth(db,referee);await assert.rejects(call(db,'referee_submit_match_report',[match,id(906),0,'note']),/görevi/);
  }finally{await db.close();}
});
test('0112 preserves ordinary federation result writing and real assignment push generation',async()=>{
  const {db,match}=await fixture();try{
    await owner(db);
    await call(db,'federation_publish_result',[match,{type:'score',home:3,away:1},'federation result',0]);
    assert.equal((await db.query('select result_version from org_matches where id=$1',[match])).rows[0].result_version,1);
    await db.query("insert into push_subscriptions(profile_id,kind,endpoint) values($1,'fcm','isolated-referee-device')",[referee]);
    await db.query("update match_officials set status='assigned' where match_id=$1",[match]);
    const row=(await db.query("select entity_type,entity_id from notifications where kind='referee_assignment' and profile_id=$1",[referee])).rows[0];
    assert.deepEqual(row,{entity_type:'match',entity_id:match});
    assert.ok((await db.query("select * from test_push_payloads where body->>'url'='/hakem/gorevler'")).rows.length>0);
  }finally{await db.close();}
});
