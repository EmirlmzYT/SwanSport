import './league_standings_sql_test.mjs';
import {fixture} from './referee_cockpit_sql_test.mjs';
import {apply,actor,call,id,officer,child,club,coach,admin,guardian} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const sql=async n=>readFile(new URL(`../supabase/migrations/${n}.sql`,import.meta.url),'utf8');
const migration=await sql('0118_match_following_notifications');
async function owner(db){await db.exec('reset role');await actor(db,officer);}
async function auth(db,p){await owner(db);await actor(db,p);await db.exec('set role authenticated');}
async function setup(){const f=await fixture();try{
  const {db}=f;await owner(db);await db.exec('alter table clubs add column logo_path text');
  await apply(db,await sql('0116_live_match_spectator_hub'));await apply(db,await sql('0117_league_standings_engine'));
  const social=await sql('0006_social');await db.exec(social.slice(social.indexOf('create table if not exists public.follows'),social.indexOf('create or replace function public.can_post_personally')));
  const lifecycle=await sql('0092_court_waitlist');await db.exec(lifecycle.slice(lifecycle.indexOf('create or replace function public._swan_feature_for_profile'),lifecycle.indexOf('create or replace function public.my_feature_flags')));
  await apply(db,migration);await call(db,'federation_publish_program',[f.org,true]);
  await db.exec("update feature_flags set audience='everyone' where key in ('live_match_notifications','live_match_hub')");
  // Probe permissive insert to prove 0118's restrictive kind reservation, not
  // merely the absence of a general INSERT policy in this reduced fixture.
  await db.exec('create policy test_insert_own_notice on notifications for insert to authenticated with check(profile_id=auth.uid())');
  await auth(db,id(71));await call(db,'referee_verify_lineup',[f.match,[child],[id(91)],null,[id(92)],[]]);
  return f;
}catch(e){await f.db.close();throw e;}}
async function event(db,mid,kind,side=null,op=null,athlete=null){await auth(db,id(71));const st=await call(db,'referee_match_state',[mid]);
  return call(db,'referee_append_match_event',[mid,op??(await db.query('select gen_random_uuid() id')).rows[0].id,st.version,kind,side,athlete]);}
async function notices(db){await owner(db);return (await db.query("select * from notifications where kind='match_live' order by created_at,id")).rows;}
async function follow(db,mid,p){await auth(db,p);return call(db,'set_match_follow',[mid,true]);}

test('0118 follow RLS, only caller state, private/unknown/anon/feature gates and replay',async()=>{
 const {db,match,org}=await setup();try{
  assert.equal(await follow(db,match,admin),true);await auth(db,guardian);
  assert.equal((await db.query('select * from match_followers')).rows.length,0);
  await assert.rejects(db.query('insert into match_followers(match_id,profile_id) values($1,$2)',[match,admin]),/row-level/);
  await assert.rejects(call(db,'_match_follow_state',[match,admin]),/permission/);
  await assert.rejects(db.exec('select * from match_notification_deliveries'),/permission/);
  assert.equal((await call(db,'get_match_follow_status',[match])).is_followed,false);
  await owner(db);await call(db,'federation_publish_program',[org,false]);await auth(db,admin);
  assert.equal(await call(db,'get_match_follow_status',[match]),null);
  await assert.rejects(call(db,'set_match_follow',[match,true]),/açık/);
  assert.equal(await call(db,'set_match_follow',[match,false]),false);
  assert.equal(await call(db,'get_match_follow_status',[id(999)]),null);
  await assert.rejects(call(db,'toggle_match_follow',[id(999)]),/açık/);
  await owner(db);await actor(db,null);await db.exec('set role anon');
  await assert.rejects(call(db,'get_match_follow_status',[match]),/permission/);
  await assert.rejects(call(db,'set_match_follow',[match,true]),/permission/);
  await owner(db);await db.exec("update feature_flags set audience='off' where key='live_match_notifications'");
  await apply(db,migration);assert.equal((await db.query("select audience from feature_flags where key='live_match_notifications'")).rows[0].audience,'off');
  assert.equal((await db.query("select count(*)::int n from faq_entries where feature='live_match_notifications'")).rows[0].n,1);
  assert.equal((await db.query("select count(*)::int n from pg_proc where proname='toggle_match_follow'")).rows[0].n,1);
  await call(db,'federation_publish_program',[org,true]);await auth(db,admin);
  await assert.rejects(db.query('insert into match_followers(match_id,profile_id) values($1,$2)',[match,admin]),/row-level/);
 }finally{await db.close();}
});
test('0118 explicit idempotent follow and club inheritance with effective match mute/preferences',async()=>{
 const {db,match}=await setup();try{
  await owner(db);await db.query("insert into follows(follower_id,target_type,target_id) values($1,'club',$2)",[guardian,club]);
  await auth(db,guardian);let state=await call(db,'get_match_follow_status',[match]);assert.equal(state.source,'club');assert.equal(state.is_followed,true);
  assert.equal(await call(db,'toggle_match_follow',[match]),false);state=await call(db,'get_match_follow_status',[match]);assert.equal(state.muted,true);
  assert.equal(await call(db,'set_match_follow',[match,false]),false);assert.equal(await call(db,'set_match_follow',[match,true]),true);
  assert.equal(await call(db,'set_match_follow',[match,true]),true);assert.equal((await db.query('select * from match_followers')).rows.length,1);
  await db.query('update match_followers set notify_score=false where match_id=$1',[match]);await event(db,match,'clock_start');await event(db,match,'score','home');
  const rows=await notices(db);assert.equal(rows.length,1);assert.equal(rows[0].title,'Müsabaka başladı');
  await auth(db,guardian);await call(db,'set_match_follow',[match,false]);await event(db,match,'score','home');assert.equal((await notices(db)).length,1);
 }finally{await db.close();}
});
test('0118 kickoff/score/undo uses current snapshot, club+match dedup, safe push URL and no child names',async()=>{
 const {db,match}=await setup();try{
  await follow(db,match,guardian);await owner(db);
  await db.query("insert into follows(follower_id,target_type,target_id) values($1,'club',$2)",[guardian,club]);
  await event(db,match,'clock_start');await event(db,match,'clock_pause');await event(db,match,'clock_start');
  const op=id(9011);const st=await event(db,match,'score','home',op,child);
  await auth(db,id(71));await call(db,'referee_append_match_event',[match,op,st.version-1,'score','home',child]);
  let rows=await notices(db);assert.equal(rows.length,2);const score=rows.find(r=>r.title==='Skor güncellendi');
  assert.match(score.body,/Oyun 1 : 0/);assert.equal(score.entity_id,match);assert.equal(score.actor_id,null);
  assert.doesNotMatch(JSON.stringify(rows),/Child|Athlete|national|license|report|health|guardian|decline/);
  await owner(db);const payloads=(await db.query('select body from test_push_payloads')).rows.map(r=>r.body);
  assert.equal(payloads.filter(r=>r.url===`/canli-mac/${match}`).length,2);
  assert.doesNotMatch(JSON.stringify(payloads),/Child|Athlete|report_notes|athlete_id/);
  await event(db,match,'undo');rows=await notices(db);assert.equal(rows.length,3);assert.match(rows.find(r=>r.title==='Skor düzeltildi').body,/Oyun 0 : 0/);
 }finally{await db.close();}
});
test('0118 final/set and correction use official result, private notes absent, rollout recipients only',async()=>{
 const {db,match}=await setup();try{
  await follow(db,match,admin);await follow(db,match,guardian);
  await owner(db);await db.exec("update feature_flags set audience='admins' where key='live_match_notifications'");
  for(let s=0;s<2;s++){for(let i=0;i<6;i++)await event(db,match,'score','home');await event(db,match,'period_end');}
  await auth(db,id(71));const state=await call(db,'referee_match_state',[match]);
  const reportOp=id(9012);await call(db,'referee_submit_match_report',[match,reportOp,state.version,'PRIVATE_REPORT / MEDICAL_NOTE / DISCIPLINE']);
  await call(db,'referee_submit_match_report',[match,reportOp,state.version,'PRIVATE_REPORT / MEDICAL_NOTE / DISCIPLINE']);
  let rows=await notices(db);assert.ok(rows.every(r=>r.profile_id===admin));
  assert.equal(rows.filter(r=>r.title==='Resmi maç sonucu').length,1);assert.match(rows.find(r=>r.title==='Resmi maç sonucu').body,/2 : 0/);
  await owner(db);await call(db,'federation_publish_result',[match,{type:'sets',sets:[{home:0,away:6},{home:0,away:6}]},'PRIVATE_CORRECTION',1]);
  rows=await notices(db);assert.match(rows.find(r=>r.title==='Resmi sonuç düzeltildi').body,/0 : 2/);
  assert.doesNotMatch(JSON.stringify(rows),/PRIVATE|MEDICAL|DISCIPLINE/);assert.ok(rows.every(r=>r.actor_id===null));
 }finally{await db.close();}
});
test('0118 reserved kind cannot be forged/edited, marking/deletion works, withdrawal hides raw/RPC and stops new sends',async()=>{
 const {db,match,org}=await setup();try{
  await follow(db,match,admin);await event(db,match,'clock_start');let rows=await notices(db);const notice=rows[0];
  await auth(db,admin);await assert.rejects(db.query("insert into notifications(profile_id,kind,title,entity_id) values($1,'match_live','FAKE',$2)",[admin,match]),/row-level/);
  assert.equal((await db.query("update notifications set title='FAKE' where id=$1 returning id",[notice.id])).rows.length,0);
  await call(db,'mark_notifications_read',[notice.id]);assert.ok((await db.query('select read_at from notifications where id=$1',[notice.id])).rows[0].read_at);
  await db.query('delete from notifications where id=$1',[notice.id]);await event(db,match,'clock_pause');await event(db,match,'clock_start');
  assert.equal((await notices(db)).length,0);await event(db,match,'score','home');assert.equal((await notices(db)).length,1);
  await owner(db);await call(db,'federation_publish_program',[org,false]);await auth(db,admin);
  assert.equal((await db.query("select * from notifications where kind='match_live'")).rows.length,0);
  assert.equal((await db.query("select * from my_notifications() where kind='match_live'")).rows.length,0);
  await event(db,match,'score','home');assert.equal((await notices(db)).length,1);
 }finally{await db.close();}
});
test('0118 SQL route keeps all 41 previous kinds and real queue failures roll back event/notice/delivery',async()=>{
 const {db,match}=await setup();try{
  await owner(db);assert.equal(await call(db,'push_route',['match_live',match]),`/canli-mac/${match}`);
  for(const invalid of [null,'match','/canli-mac/bad','../../auth'])assert.equal(await call(db,'push_route',['match_live',invalid]),'/bildirimler');
  const previous=await sql('0112_referee_cockpit_engine');const block=previous.slice(previous.lastIndexOf('create or replace function public.push_route'));
  const kinds=[...block.matchAll(/when\s+'([a-z_]+)'\s*then\s+'([^']*)'/g)];assert.equal(kinds.length,41);
  for(const [,kind,url] of kinds)assert.equal(await call(db,'push_route',[kind,'match']),url);
  await follow(db,match,admin);await owner(db);
  await db.exec("create function reject_live_notice() returns trigger language plpgsql as $$begin if new.kind='match_live' then raise exception 'notice failure';end if;return new;end$$;create trigger reject_live_notice before insert on notifications for each row execute function reject_live_notice()");
  await assert.rejects(event(db,match,'score','home'),/notice failure/);await owner(db);
  assert.equal((await db.query('select * from match_notification_deliveries')).rows.length,0);
  assert.equal((await db.query('select * from match_live_events where match_id=$1',[match])).rows.length,0);
 }finally{await db.close();}
});
test('0118 category mute suppresses physical queue only, feature-off suppresses production and hides notices',async()=>{
 const {db,match}=await setup();try{
  await follow(db,match,admin);await owner(db);
  await db.query("insert into notification_prefs(profile_id,category,enabled) values($1,'sosyal',false)",[admin]);
  const before=(await db.query('select count(*)::int n from test_push_payloads')).rows[0].n;
  await event(db,match,'score','home');assert.equal((await notices(db)).length,1);
  assert.equal((await db.query('select count(*)::int n from test_push_payloads')).rows[0].n,before);
  await owner(db);await db.exec("update feature_flags set audience='off' where key='live_match_notifications'");
  await event(db,match,'score','home');assert.equal((await notices(db)).length,1);
  await auth(db,admin);assert.equal((await db.query("select * from notifications where kind='match_live'")).rows.length,0);
  assert.equal((await db.query("select * from my_notifications() where kind='match_live'")).rows.length,0);
  await owner(db);await db.exec("update feature_flags set audience='everyone' where key='live_match_notifications';update feature_flags set audience='off' where key='live_match_hub'");
  await event(db,match,'score','home');assert.equal((await notices(db)).length,1);
  await auth(db,admin);await assert.rejects(call(db,'set_match_follow',[match,true]),/açık/);
 }finally{await db.close();}
});
