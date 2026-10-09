// Imports also run the 16 unchanged Phase A regression scenarios.
import { setup, apply, actor, call, id, admin, officer, coach, guardian, child, club, other }
 from './federation_foundation_sql_test.mjs';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';
const migration=await readFile(new URL('../supabase/migrations/0097_federation_public_reads.sql',import.meta.url),'utf8');
async function phaseB(){const f=await setup();try{
 // Deliberately permissive stand-ins exercise the new revokes without unrelated migrations.
 await f.db.exec(`create table invoices(athlete_id uuid,amount numeric);
 create table training_sessions(id uuid,title text);
 create table payments(athlete_id uuid,amount numeric);
 create table documents(athlete_id uuid,path text);
 insert into invoices values('${child}',99);insert into payments values('${child}',99);
 insert into training_sessions values('${id(990)}','Private training');
 insert into documents values('${child}','private/document');
 insert into health_restrictions values('${child}','restricted');`);
 // Simulate a legacy PUBLIC grant as well as Supabase anon default privileges.
 await f.db.exec('grant select on athlete_public,athletes to public');
 await apply(f.db,migration);return f;
 }catch(e){await f.db.close();throw e;}}
async function role(db,name){await db.exec('reset role');await actor(db,name==='anon'?'':coach);await db.exec('set role '+name);}
async function official(db){await db.exec('reset role');await actor(db,officer);}
async function publish(db,org){await official(db);await call(db,'federation_publish_program',[org,true]);}
async function result(db,match,p,version=0){await official(db);await call(db,'federation_publish_result',[match,p,'Phase B result',version]);}
async function guestResult(db,match){await role(db,'anon');return (await db.query('select protocol from public_program_result($1)',[match])).rows;}
function noIdentity(rows){const s=JSON.stringify(rows);for(const forbidden of [child,'athlete_id','national_id','11111111110','license_number','T-1','profile_id','birth_date','health','invoice','document','roster','training'])assert.ok(!s.includes(forbidden),forbidden);}

test('B: migration reapplies, publishes nothing automatically and has exact RPC privileges',async()=>{
 const {db,org,match}=await phaseB();try{
 await apply(db,migration);
 assert.equal((await db.query('select is_public from organizations where id=$1',[org])).rows[0].is_public,false);
 for(const sig of ['public_sport_programs()','public_program_fixture(uuid)','public_program_result(uuid)']){
  const grants=(await db.query("select has_function_privilege('anon',$1,'execute') a,has_function_privilege('authenticated',$1,'execute') u",[sig])).rows[0];assert.deepEqual(grants,{a:true,u:true});
  const priv=(await db.query(`select x.grantee from pg_proc p cross join lateral aclexplode(p.proacl) x where p.oid=$1::regprocedure and x.privilege_type='EXECUTE'`,[sig])).rows;
  assert.ok(!priv.some(x=>x.grantee===0));
 }
 assert.equal((await db.query("select has_function_privilege('anon','federation_publish_program(uuid,boolean)','execute') v")).rows[0].v,false);
 await role(db,'anon');
 assert.deepEqual((await db.query('select * from public_sport_programs()')).rows,[]);
 assert.deepEqual((await db.query('select * from public_program_fixture($1)',[org])).rows,[]);
 assert.deepEqual((await db.query('select * from public_program_result($1)',[match])).rows,[]);
 await assert.rejects(call(db,'federation_publish_program',[org,true]),/permission denied/);
 }finally{await db.close();}});

test('B: publication requires official program and scoped active duty, without admin bypass',async()=>{
 const {db,org,office}=await phaseB();try{
 const before=(await db.query('select count(*) n from federation_audit')).rows[0].n;
 for(const person of [admin,coach]){await actor(db,person);await db.exec('set role authenticated');
  await assert.rejects(call(db,'federation_publish_program',[org,true]),/görev/);await db.exec('reset role');}
 await official(db);
 for(const change of ["duty='result_publisher'","ends_on=current_date-1,starts_on=current_date-10","starts_on=current_date+1","revoked_at=now()"]){
  await db.exec('begin');await db.exec(`update federation_appointments set ${change} where profile_id='${officer}'`);
  await assert.rejects(call(db,'federation_publish_program',[org,true]),/görev/);await db.exec('rollback');}
 for(const [table,change,key] of [['federation_offices',"city_code='06'",office],['federations',"sport_code='yuzme'",(await db.query('select federation_id from federation_offices where id=$1',[office])).rows[0].federation_id]]){
  await db.exec('begin');await db.query(`update ${table} set ${change} where id=$1`,[key]);
  await assert.rejects(call(db,'federation_publish_program',[org,true]),/görev/);await db.exec('rollback');}
 await assert.rejects(call(db,'federation_publish_program',[org,null]),/tercihi/);
 assert.equal((await db.query('select count(*) n from federation_audit')).rows[0].n,before);
 await actor(db,coach);const friendly=await call(db,'create_organization',['Private friendly','league',club]);
 await official(db);await assert.rejects(call(db,'federation_publish_program',[friendly,true]),/Resmi program/);
 await assert.rejects(call(db,'federation_publish_program',[id(999),true]),/Resmi program/);
 await db.exec('set role authenticated');await call(db,'federation_publish_program',[org,true]);await db.exec('reset role');
 const audit=(await db.query("select actor_id,appointment_id,detail from federation_audit where action='program_publication' and entity_id=$1",[org])).rows;
 assert.equal(audit.length,1);assert.equal(audit[0].actor_id,officer);assert.ok(audit[0].appointment_id);
 assert.deepEqual(audit[0].detail,{previous_is_public:false,is_public:true});
 }finally{await db.close();}});

test('B: anon and PUBLIC cannot SELECT official or private source tables/views',async()=>{
 const {db}=await phaseB();try{
 const tables=['organizations','org_matches','org_participants','sport_seasons','org_result_revisions',
 'org_roster_revisions','federation_audit','athlete_sport_registrations','athlete_publicity','athletes',
 'athlete_public','profiles','guardians','health_restrictions','invoices','payments','training_sessions','documents'];
 await role(db,'anon');for(const table of tables){
  assert.equal((await db.query("select has_table_privilege('anon',$1,'select') v",[table])).rows[0].v,false,table);
  await assert.rejects(db.query('select * from '+table),/permission denied/,table);}
 for(const [fn,params] of [['eligibility_gate',[child]],['federation_result_card',[id(999)]],['org_fixture',[id(999)]],['org_standings',[id(999)]],['federation_register_license',[child,'tenis','T-1','2090-01-01']]]){
  await assert.rejects(call(db,fn,params),/permission denied/);}
 }finally{await db.close();}});

test('B: explicit publication and withdrawal gate all three reads; projections are exact',async()=>{
 const {db,org,match}=await phaseB();try{
 await result(db,match,{type:'score',home:3,away:1});assert.deepEqual(await guestResult(db,match),[]);
 await publish(db,org);await role(db,'anon');
 const programs=(await db.query('select * from public_sport_programs()')).rows;
 assert.equal(programs.length,1);assert.deepEqual(Object.keys(programs[0]).sort(),['id','name','sport_code','city_code','season_label','starts_on','ends_on'].sort());
 assert.equal(programs[0].id,org);assert.equal(programs[0].season_label,'Activity');
 const fixtures=(await db.query('select * from public_program_fixture($1)',[org])).rows;
 assert.deepEqual(Object.keys(fixtures[0]).sort(),['id','starts_at','location','home_name','away_name','status'].sort());
 assert.equal(fixtures[0].home_name,'Legal Club');assert.equal(fixtures[0].away_name,null);
 assert.deepEqual((await db.query('select protocol from public_program_result($1)',[match])).rows,[{protocol:{type:'score',home:3,away:1}}]);
 for(const name of ['public_program_fixture','public_program_result'])assert.deepEqual((await db.query('select * from '+name+'($1)',[id(999)])).rows,[]);
 await official(db);await call(db,'federation_publish_program',[org,false]);await role(db,'anon');
 for(const [name,args] of [['public_sport_programs',[]],['public_program_fixture',[org]],['public_program_result',[match]]])
 assert.deepEqual((await db.query(`select * from ${name}(${args.map((_,i)=>'$'+(i+1)).join(',')})`,args)).rows,[]);
 }finally{await db.close();}});

test('B: score/sets project only numeric protocol fields; scheduled matches have no result',async()=>{
 const {db,org,match}=await phaseB();try{
 await publish(db,org);assert.deepEqual(await guestResult(db,match),[]);
 const protocols=[{type:'score',home:0,away:999},{type:'sets',sets:[{home:6,away:3},{home:0,away:6},{home:7,away:5}]}];
 for(const [i,p] of protocols.entries()){
 await result(db,match,p,i);const rows=await guestResult(db,match);assert.deepEqual(rows,[{protocol:p}]);noIdentity(rows);}
 }finally{await db.close();}});

test('B: time/rank child names require current consent; UUID never leaves projection',async()=>{
 const {db,org,match}=await phaseB();try{
 await publish(db,org);
 for(const [version,type] of ['time','rank'].entries()){
 await result(db,match,{type,entries:[{athlete_id:child,value:12.34,placement:1}]},version);
 const rows=await guestResult(db,match);assert.deepEqual(rows,[{protocol:{type,entries:[{name:'sporcu',value:12.34,placement:1}]}}]);noIdentity(rows);}
 await db.exec('reset role');await actor(db,guardian);await call(db,'set_athlete_publicity',[child,true]);
 let rows=await guestResult(db,match);assert.equal(rows[0].protocol.entries[0].name,'Private Child');noIdentity(rows);
 await db.exec('reset role');await actor(db,guardian);await call(db,'set_athlete_publicity',[child,false]);
 rows=await guestResult(db,match);assert.equal(rows[0].protocol.entries[0].name,'sporcu');noIdentity(rows);
 await db.exec('reset role');await actor(db,guardian);await call(db,'set_athlete_publicity',[child,true]);
 await db.query('delete from guardians where athlete_id=$1',[child]);
 assert.equal((await guestResult(db,match))[0].protocol.entries[0].name,'sporcu');
 }finally{await db.close();}});

test('B: unknown birth is private, registered adult is named, result entries never expand to roster',async()=>{
 const {db,org,match,participant}=await phaseB();try{
 // This scenario tests names, so clear the unrelated fixture health block before expanding its roster.
 await db.exec('delete from health_restrictions');
 const adult=id(22),unscored=id(23);
 await db.query("insert into athletes(id,club_id,first_name,last_name,birth_date) values($1,$3,'Adult','Athlete',current_date-interval '18 years'),($2,$3,'Hidden','Roster',current_date-interval '25 years')",[adult,unscored,club]);
 for(const [key,num] of [[adult,'T-22'],[unscored,'T-23']])await call(db,'federation_register_license',[key,'tenis',num,'2090-01-01']);
 await call(db,'federation_publish_roster',[participant,[child,adult,unscored],'expanded',1]);
 await db.query('update athletes set birth_date=null where id=$1',[child]);
 await publish(db,org);await result(db,match,{type:'time',entries:[{athlete_id:child,value:10,placement:1},{athlete_id:adult,value:11,placement:2}]});
 let rows=await guestResult(db,match);assert.deepEqual(rows[0].protocol.entries.map(e=>e.name),['sporcu','Adult Athlete']);
 assert.equal(rows[0].protocol.entries.length,2);assert.ok(!JSON.stringify(rows).includes(unscored));assert.ok(!JSON.stringify(rows).includes(adult));noIdentity(rows);
 await db.exec('reset role');await actor(db,guardian);await call(db,'set_athlete_publicity',[child,true]);
 assert.equal((await guestResult(db,match))[0].protocol.entries[0].name,'Private Child');
 // Historical reading does not depend on today's license expiry or duty validity.
 await db.exec('reset role');await db.query("update athlete_sport_registrations set expires_on='2000-01-01' where athlete_id=$1",[adult]);
 assert.equal((await guestResult(db,match))[0].protocol.entries[1].name,'Adult Athlete');
 await db.exec('reset role');await db.query('delete from athlete_sport_registrations where athlete_id=$1',[adult]);
 assert.equal((await guestResult(db,match))[0].protocol.entries[1].name,'sporcu');
 }finally{await db.close();}});

test('B: published history survives ended appointments and club deletion with no private snapshots',async()=>{
 const {db,org,match}=await phaseB();try{
 await publish(db,org);await result(db,match,{type:'rank',entries:[{athlete_id:child,value:1,placement:1}]});
 await db.query('update federation_appointments set ends_on=current_date-1,starts_on=current_date-10 where profile_id=$1',[officer]);
 assert.equal((await guestResult(db,match))[0].protocol.entries[0].name,'sporcu');
 await db.exec('reset role');await actor(db,admin);await db.query('delete from clubs where id=$1',[club]);
 const rows=await guestResult(db,match);assert.equal(rows[0].protocol.entries[0].name,'sporcu');noIdentity(rows);
 assert.equal((await db.query('select home_name from public_program_fixture($1)',[org])).rows[0].home_name,'Legal Club');
 }finally{await db.close();}});

test('B: authenticated club tables and legacy friendly fixture/score/standings still work',async()=>{
 const {db}=await phaseB();try{
 await role(db,'authenticated');assert.equal((await db.query('select id from athletes where id=$1',[child])).rows[0].id,child);
 assert.equal((await db.query('select id from athlete_public where id=$1',[child])).rows[0].id,child);
 const org=await call(db,'create_organization',['Friendly','league',club]);
 await call(db,'join_organization',[org,club,null,'Team A']);await call(db,'join_organization',[org,club,null,'Team B']);
 await call(db,'generate_fixture',[org]);const match=(await db.query('select id from org_matches where org_id=$1',[org])).rows[0].id;
 await call(db,'set_match_result',[match,2,1]);assert.equal((await db.query('select home_score from org_fixture($1)',[org])).rows[0].home_score,2);
 assert.equal((await db.query('select * from org_standings($1)',[org])).rows.length,2);
 await role(db,'anon');assert.deepEqual((await db.query('select * from public_program_fixture($1)',[org])).rows,[]);
 assert.deepEqual((await db.query('select * from public_program_result($1)',[match])).rows,[]);
 assert.deepEqual((await db.query('select * from public_sport_programs()')).rows,[]);
 }finally{await db.close();}});


test('B: a second guardian refusal wins and deleting consent closes the name immediately',async()=>{
 const {db,org,match}=await phaseB();try{
 await publish(db,org);await result(db,match,{type:'rank',entries:[{athlete_id:child,value:1,placement:1}]});
 await actor(db,guardian);await call(db,'set_athlete_publicity',[child,true]);
 const second=(await db.query("insert into guardians(athlete_id,profile_id,display_name) values($1,$2,'Other guardian') returning id",[child,coach])).rows[0].id;
 await actor(db,coach);await call(db,'set_athlete_publicity',[child,false]);
 assert.equal((await guestResult(db,match))[0].protocol.entries[0].name,'sporcu');
 await db.exec('reset role');await actor(db,coach);await call(db,'set_athlete_publicity',[child,true]);
 assert.equal((await guestResult(db,match))[0].protocol.entries[0].name,'Private Child');
 await db.exec('reset role');await db.query('delete from guardians where id=$1',[second]);
 await db.query('delete from athlete_publicity where athlete_id=$1',[child]);
 assert.equal((await guestResult(db,match))[0].protocol.entries[0].name,'sporcu');
 }finally{await db.close();}});

test('B: malformed historical protocol fails closed instead of exposing unexpected JSON fields',async()=>{
 const {db,org,match}=await phaseB();try{
 await publish(db,org);await result(db,match,{type:'score',home:1,away:0});
 await db.query("update org_result_revisions set protocol=protocol||jsonb_build_object('national_id','11111111110') where match_id=$1",[match]);
 assert.deepEqual(await guestResult(db,match),[]);
 }finally{await db.close();}});
