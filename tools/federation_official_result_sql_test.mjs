import {setup,apply,actor,call,admin,officer,coach,guardian,child,id,club,other} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const migration=await readFile(new URL('../supabase/migrations/0103_official_result_cv.sql',import.meta.url),'utf8');
const raw={status:'finished',best_of:3,sets:[{home:6,away:0},{home:6,away:2}]};
async function fixture(){const f=await setup();try{await apply(f.db,migration);return f;}catch(e){await f.db.close();throw e;}}
test('0103 reapplies, private helpers and writes have no PUBLIC/anon privileges',async()=>{const {db}=await fixture();try{
 await apply(db,migration);
 for(const signature of ['publish_official_match_result(uuid,jsonb,text,integer)','_federation_commit_result(uuid,jsonb,text,integer,jsonb)','official_athlete_achievements(uuid)','official_achievement_source(uuid)','_official_source_scores(text,jsonb,jsonb)','_official_projection(text,jsonb)']){
  assert.equal((await db.query('select has_function_privilege($1,$2,$3) v',['anon',signature,'EXECUTE'])).rows[0].v,false);
 }
 await db.exec('set role anon');await assert.rejects(db.query('select match_protocol from org_result_revisions'),/permission/);await db.exec('reset role');
}finally{await db.close();}});
test('authorization, immutable automatic CV, current revision and private source',async()=>{const {db,match}=await fixture();try{
 for(const person of [admin,coach,guardian]){await actor(db,person);await assert.rejects(call(db,'publish_official_match_result',[match,raw,'test',0]),/görev/);}
 await actor(db,officer);
 const first=await call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'legacy verified',0]);
 const ac=(await db.query('select id,source_id,title from athlete_achievements')).rows[0];assert.equal(ac.source_id,first);assert.match(ac.title,/galibiyeti/);assert.doesNotMatch(ac.title,/Şampiyon/);
 await actor(db,coach);await db.exec('set role authenticated');
 let cv=await db.query('select * from official_athlete_achievements($1)',[child]);assert.equal(cv.rows.length,1);
 let source=await call(db,'official_achievement_source',[ac.id]);assert.equal(source.match_id,match);assert.equal(source.result,'1–0');assert.equal('athletes' in source,false);
 assert.equal((await db.query('update athlete_achievements set title=$1 where id=$2 returning id',['forged',ac.id])).rows.length,0);
 await db.exec('reset role');await actor(db,officer);
 await call(db,'federation_publish_result',[match,{type:'score',home:0,away:1},'correction',1]);
 assert.equal((await db.query('select count(*)::int n from athlete_achievements')).rows[0].n,2);
 await actor(db,coach);cv=await db.query('select * from official_athlete_achievements($1)',[child]);assert.equal(cv.rows.length,1);assert.equal(cv.rows[0].result_version,2);
 await assert.rejects(db.query('update org_result_revisions set reason=$1 where id=$2',['forged',first]),/değiştirilemez/);
 await actor(db,admin);await assert.rejects(call(db,'official_athlete_achievements',[child]),/erişim/);
 await db.query('update federation_appointments set revoked_at=now() where profile_id=$1',[officer]);await actor(db,guardian);
 assert.equal((await db.query('select * from official_athlete_achievements($1)',[child])).rows.length,1);
}finally{await db.close();}});
test('server validates each supported protocol without relying on UI',async()=>{const {db}=await fixture();try{
 assert.deepEqual(await call(db,'_official_projection',['tenis',raw]),{type:'sets',sets:raw.sets});
 await assert.rejects(call(db,'_official_projection',['tenis',{...raw,sets:[{home:6,away:5}]}]),/seti/);
 await assert.rejects(call(db,'_official_projection',['basketbol',{status:'finished',periods:[1,2,3,4].map((n)=>({label:'Q'+n,home:20,away:20,team_fouls:{home:0,away:0}}))}]),/uzatma/);
 assert.deepEqual(await call(db,'_official_projection',['basketbol',{status:'finished',periods:[1,2,3,4].map((n)=>({label:'Q'+n,home:20,away:19,team_fouls:{home:0,away:0}}))}]),{type:'score',home:80,away:76});
 assert.deepEqual(await call(db,'_official_projection',['futbol',{status:'finished',halves:[{home:1,away:0},{home:0,away:0}]}]),{type:'score',home:1,away:0});
 for(const sport of ['yuzme','atletizm','okculuk']){
  const performance={athlete_ref:child,heat:1,lane:1,rank:1,...(sport==='okculuk'?{series:[25,28]}:{time_ms:65000})};
  const projected=await call(db,'_official_projection',[sport,{status:'finished',performances:[performance]}]);assert.equal(projected.entries[0].value,sport==='okculuk'?53:65000);
  await assert.rejects(call(db,'_official_projection',[sport,{status:'finished',performances:[{...performance,rank:'1'}]}]),/tamsayı/);
 }
}finally{await db.close();}});


test('rich publish stores private protocol and atomic automatic CV for all six branches; public privacy survives',async()=>{
 const {db}=await fixture();try{
  for(const file of ['0097_federation_public_reads','0098_public_result_adult_name']) await apply(db,await readFile(new URL(`../supabase/migrations/${file}.sql`,import.meta.url),'utf8'));
  const opponent=id(990);await actor(db,officer);await db.query("insert into athletes(id,club_id,first_name,last_name,birth_date) values($1,$2,'Other','Athlete',current_date-interval '25 years')",[opponent,other]);
  let index=0;
  for(const sport of ['basketbol','futbol','tenis','yuzme','atletizm','okculuk']){
   index++;await db.query('insert into sports(code,name) values($1,$1) on conflict do nothing',[sport]);
   await actor(db,admin);const office=await call(db,'federation_create_office',[sport,`Federation ${sport}`,'34',`Office ${sport}`]);
   for(const duty of ['program_publisher','result_publisher','license_registrar','club_registrar']) await db.query('select federation_appoint($1,$2,$3,current_date-1,current_date+365)',[office,officer,duty]);
   await actor(db,officer);
   for(const [c,n] of [[club,'A'],[other,'B']]) await call(db,'federation_register_club',[c,sport,n==='A'?'Legal Club':'Legal Other',`REG-${sport}-${n}`,'34']);
   for(const [a,n] of [[child,'A'],[opponent,'B']]) await call(db,'federation_register_license',[a,sport,`L-${sport}-${n}`,'2090-01-01']);
   const season=(await db.query("select federation_open_season($1,'Annual',current_date-1,current_date+365) v",[office])).rows[0].v;
   const org=(await db.query("select federation_create_program($1,$2,'34',current_date,current_date+7) v",[season,`Competition ${sport}`])).rows[0].v;
   const home=await call(db,'federation_add_participant',[org,club,null]);const away=await call(db,'federation_add_participant',[org,other,null]);
   const m=(await db.query("select federation_schedule_match($1,$2,$3,now()) v",[org,home,away])).rows[0].v;
   await call(db,'federation_publish_roster',[home,[child],'roster',0]);await call(db,'federation_publish_roster',[away,[opponent],'roster',0]);
   let raw={status:'finished',sport_code:sport};
   if(sport==='basketbol')raw.periods=[1,2,3,4].map(n=>({label:'Q'+n,home:20,away:19,team_fouls:{home:0,away:0}}));
   else if(sport==='futbol')Object.assign(raw,{halves:[{home:0,away:0},{home:0,away:0}],knockout:true,penalties:[1,2,3].flatMap(()=>[{team:'home',scored:true},{team:'away',scored:false}])});
   else if(sport==='tenis')Object.assign(raw,{best_of:3,sets:[{home:6,away:0},{home:6,away:2}]});
   else raw.performances=[{athlete_ref:child,lane:1,heat:1,rank:1,...(sport==='okculuk'?{series:[28,30]}:{time_ms:62000})},{athlete_ref:opponent,lane:2,heat:1,...(sport==='okculuk'?{rank:2,series:[27,30]}:{dq:true})}];
   assert.ok((await db.query('select * from federation_pending_results()')).rows.some(x=>x.match_id===m));
   const before=(await db.query('select count(*)::int n from athlete_achievements')).rows[0].n;
   await assert.rejects(call(db,'publish_official_match_result',[m,{...raw,status:'in_progress'},'invalid',0]),/Bitmiş/);
   assert.equal((await db.query('select count(*)::int n from athlete_achievements')).rows[0].n,before);
   const revision=await call(db,'publish_official_match_result',[m,raw,'confirmed',0]);
   const stored=(await db.query('select match_protocol from org_result_revisions where id=$1',[revision])).rows[0].match_protocol;assert.deepEqual(stored,raw);
   const awards=(await db.query('select * from athlete_achievements where source_id=$1 order by athlete_id',[revision])).rows;
   assert.equal(awards.length,['yuzme','atletizm'].includes(sport)?1:2);assert.ok(awards.some(a=>a.athlete_id===child));
   assert.ok(!(await db.query('select * from federation_pending_results()')).rows.some(x=>x.match_id===m));
   await assert.rejects(call(db,'publish_official_match_result',[m,raw,'stale',0]),/sürümü/);
   if(sport==='futbol')assert.match(awards.find(a=>a.athlete_id===child).title,/galibiyeti/);
   await actor(db,guardian);const cv=(await db.query('select * from official_athlete_achievements($1)',[child])).rows;assert.ok(cv.some(a=>a.source_id===revision));
   const source=await call(db,'official_achievement_source',[cv.find(a=>a.source_id===revision).id]);
   assert.doesNotMatch(JSON.stringify(source),new RegExp(child));
   if(sport==='tenis')assert.equal(source.scores.length,2);
   if(sport==='basketbol')assert.equal(source.scores.length,4);
   await actor(db,officer);
   await db.exec('set role anon');assert.equal((await db.query('select * from public_program_result($1)',[m])).rows.length,0);await db.exec('reset role');
   await call(db,'federation_publish_program',[org,true]);await db.exec('set role anon');
   const output=JSON.stringify((await db.query('select * from public_program_result($1)',[m])).rows);
   assert.doesNotMatch(output,new RegExp(child));assert.doesNotMatch(output,/Private|athlete_ref|athlete_id|performances|players|national_id/);
   if(['yuzme','atletizm','okculuk'].includes(sport))assert.match(output,/sporcu/);
   await assert.rejects(call(db,'official_athlete_achievements',[child]),/permission/);
   await db.exec('reset role');
   if(sport==='yuzme'){
    const allDq={status:'finished',sport_code:sport,performances:[{athlete_ref:child,heat:1,lane:1,dq:true},{athlete_ref:opponent,heat:1,lane:2,dnf:true}]};
    await call(db,'publish_official_match_result',[m,allDq,'DQ correction',1]);
    await actor(db,guardian);assert.equal((await db.query('select * from official_athlete_achievements($1)',[child])).rows.filter(a=>a.official_match_id===m).length,0);
    await actor(db,officer);
    const resumed=await call(db,'publish_official_match_result',[m,raw,'appeal accepted',2]);
    assert.equal((await db.query('select supersedes_id from athlete_achievements where source_id=$1',[resumed])).rows[0].supersedes_id,awards[0].id);
   }
  }
 }finally{await db.close();}
});


test('CV insertion failure rolls back result, revision and audit atomically',async()=>{
 const {db,match}=await fixture();try{
  const before=(await db.query('select count(*)::int n from federation_audit')).rows[0].n;
  await db.exec("create function cv_test_fail() returns trigger language plpgsql as $$begin raise exception 'CV test failure';end $$;create trigger cv_test_fail before insert on athlete_achievements for each row execute function cv_test_fail();");
  await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:2,away:0},'test',0]),/CV test failure/);
  assert.equal((await db.query('select result_version from org_matches where id=$1',[match])).rows[0].result_version,0);
  assert.equal((await db.query('select count(*)::int n from org_result_revisions')).rows[0].n,0);
  assert.equal((await db.query('select count(*)::int n from federation_audit')).rows[0].n,before);
 }finally{await db.close();}
});
