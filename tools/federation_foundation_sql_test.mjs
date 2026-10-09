// Actual foundation/legacy organization SQL + Phase A, on isolated PostgreSQL WASM.
import { PGlite } from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';
const id=n=>`10000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const admin=id(1), officer=id(2), coach=id(3), guardian=id(4), child=id(5), club=id(10), other=id(11);
const sql=async name=>readFile(new URL(`../supabase/migrations/${name}.sql`,import.meta.url),'utf8');
const newer=await Promise.all(['0094_federation_foundation','0095_federation_write_boundaries','0096_federation_rpcs'].map(sql));
async function apply(db,s){await db.exec('begin');try{await db.exec(s);await db.exec('commit');}catch(e){await db.exec('rollback');throw e;}}
async function actor(db,p){await db.query("select set_config('test.actor',$1,false)",[p]);}
async function call(db,name,params=[]){return (await db.query(`select ${name}(${params.map((_,i)=>`$${i+1}`).join(',')}) v`,params)).rows[0].v;}
async function setup(){const db=new PGlite();try{
 await db.exec(`create role anon;create role authenticated;create schema auth;
 create table auth.users(id uuid primary key,raw_user_meta_data jsonb default '{}');
 create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 grant usage on schema auth to authenticated,anon;grant execute on function auth.uid() to authenticated,anon;
 alter default privileges in schema public grant all on tables to authenticated,anon;
 alter default privileges in schema public grant all on sequences to authenticated,anon;`);
 await db.exec((await sql('0001_foundation')).replace('create extension if not exists "pgcrypto";',''));
 await db.exec(await sql('0002_rls_policies'));
 await db.exec(await sql('0004_roles_verification'));
 // Unrelated infrastructure needed by the actual 0027 RPCs.
 await db.exec(`create table cities(code text primary key,name text);insert into cities values('34','İstanbul'),('06','Ankara');
 create table sports(code text primary key,name text);insert into sports values('tenis','Tenis'),('yuzme','Yüzme');
 alter table clubs add column sport_code text references sports(code);
 alter table profile_credentials add column sport_code text references sports(code);
 create table events(id uuid primary key default gen_random_uuid(),club_id uuid references clubs(id),team_id uuid,title text,kind text,starts_at timestamptz,place text);
 create table direct_messages(id uuid primary key,sender_id uuid,recipient_id uuid,body text);
 create table notifications(profile_id uuid,kind text,title text,body text,actor_id uuid,entity_type text,entity_id uuid);
 create table posts(id uuid,body text,author_profile_id uuid,image_path text);
 create table listings(id uuid,title text,price numeric,market_status text,owner_id uuid);
 create function can_view_post(p uuid) returns boolean language sql as $$select true$$;
 create function is_blocked_between(a uuid,b uuid) returns boolean language sql as $$select false$$;`);
 await db.exec(await sql('0011_athlete_profile'));
 await db.exec(await sql('0027_organizations'));
 await db.exec(`alter table athlete_achievements add column source text,add column source_id uuid,add column verified boolean default false,add column verified_by uuid references profiles(id) on delete set null;
 alter table athletes add column license_expires_on date;
 create unique index idx_achv_source_unique on athlete_achievements(athlete_id,source,coalesce(source_id::text,'')) where source is not null;`);
 const eligibility=await sql('0064_eligibility_gate');
 await db.exec(`create table health_restrictions(athlete_id uuid,status text);`);
 await db.exec(eligibility.slice(eligibility.indexOf('create or replace function public.eligibility_gate('),eligibility.indexOf('-- 5) YÖNETİCİ')));
 await db.exec(`insert into auth.users(id) values('${admin}'),('${officer}'),('${coach}'),('${guardian}');
 update profiles set is_platform_admin=true where id='${admin}';
 insert into clubs(id,name,sport_code,status) values('${club}','Club','tenis','active'),('${other}','Other','tenis','active');
 insert into club_memberships(club_id,profile_id,role) values('${club}','${coach}','club_admin');
 insert into athletes(id,club_id,first_name,last_name,birth_date,national_id,license_number) values('${child}','${club}','Private','Child',current_date-interval '12 years','11111111110','T-1');
 insert into guardians(athlete_id,profile_id,display_name) values('${child}','${guardian}','Guardian');
 insert into profile_credentials(profile_id,kind,coach_level,status,sport_code) values('${coach}','coach',5,'approved','yuzme');
 insert into teams(club_id,name) values('${club}','Legacy');
 insert into clubs(id,name,sport_code) values('${id(14)}','Legacy branch unknown',null);
 insert into teams(club_id,name) values('${id(14)}','Legacy branch unknown');
 insert into club_memberships(club_id,profile_id,role,coach_level) values('${club}','${coach}','coach',2);
 insert into club_memberships(club_id,profile_id,role,coach_level) values('${club}','${guardian}','coach',1);`);
 for(const m of newer) await apply(db,m);
 await actor(db,admin);
 const office=await call(db,'federation_create_office',['tenis','Tennis federation','34','İstanbul']);
 const national=await call(db,'federation_create_office',['tenis','Tennis federation',null,'National']);
 for(const duty of ['program_publisher','result_publisher','license_registrar','club_registrar'])
  await db.query(`select federation_appoint($1,$2,$3,current_date-1,current_date+365)`,[office,officer,duty]);
 await actor(db,officer);
 await call(db,'federation_register_club',[club,'tenis','Legal Club','R-1','34']);
 await call(db,'federation_register_club',[other,'tenis','Legal Other','R-2','34']);
 await call(db,'federation_register_license',[child,'tenis','T-1','2090-01-01']);
 const season=await db.query(`select federation_open_season($1,'Activity',current_date-1,current_date+365) v`,[office]);
 const org=(await db.query(`select federation_create_program($1,'Official','34',current_date,current_date+7) v`,[season.rows[0].v])).rows[0].v;
 const participant=await call(db,'federation_add_participant',[org,club,null]);
 const match=(await db.query(`select federation_schedule_match($1,$2,null,now()+interval '1 day') v`,[org,participant])).rows[0].v;
 await call(db,'federation_publish_roster',[participant,[child],'initial',0]);
 return {db,office,national,org,participant,match};
 }catch(e){await db.close();throw e;}}

test('actual migrations apply separately and reapply with legacy null credentials/teams intact',async()=>{
 const {db}=await setup();try{
 for(const m of newer)await apply(db,m);
 assert.equal((await db.query('select expires_on from profile_credentials')).rows[0].expires_on,null);
 assert.equal((await db.query('select sport_code from teams')).rows[0].sport_code,'tenis');
 assert.equal((await db.query("select sport_code from teams where name='Legacy branch unknown'")).rows[0].sport_code,null);
 assert.equal((await db.query('select supervisor_id from club_memberships where coach_level=1')).rows[0].supervisor_id,null);
 await assert.rejects(db.query("insert into teams(club_id,name) values($1,'New needs branch')",[id(14)]),/branş/);
 assert.equal((await db.query("select is_nullable from information_schema.columns where table_name='athletes' and column_name='club_id'")).rows[0].is_nullable,'NO');
 }finally{await db.close();}});
test('platform admin and club admin cannot publish results or license expiry',async()=>{
 const {db,match}=await setup();try{
 for(const p of [admin,coach]){await actor(db,p);
 await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'result',0]),/görev/);
 await assert.rejects(call(db,'federation_register_license',[child,'tenis','T-1','2091-01-01']),/görev/);
 await assert.rejects(db.query('update athletes set license_expires_on=current_date where id=$1',[child]),/görev/);
 await assert.rejects(call(db,'set_match_result',[match,9,0]),/Yetkisiz/);
 }assert.equal((await db.query('select count(*) n from org_result_revisions')).rows[0].n,0);
 }finally{await db.close();}});
test('wrong sport, province, duty, expired, future and revoked appointments all fail closed',async()=>{
 const {db,match,office}=await setup();try{
 const initial=(await db.query('select count(*) n from federation_audit')).rows[0].n;
 for(const mutation of ["duty='license_registrar'","ends_on=current_date-1,starts_on=current_date-10","starts_on=current_date+1","revoked_at=now()"]){
 await db.exec('begin');await db.exec(`update federation_appointments set ${mutation} where profile_id='${officer}'`);
 await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'result',0]),/görev/);await db.exec('rollback');}
 for(const mutation of ["update federation_offices set city_code='06'","update federations set sport_code='yuzme'"]){
 await db.exec('begin');const target=mutation.includes('offices')?office:(await db.query('select federation_id from federation_offices where id=$1',[office])).rows[0].federation_id;await db.query(mutation+' where id=$1',[target]);
 await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'result',0]),/görev/);await db.exec('rollback');}
 assert.equal((await db.query('select count(*) n from federation_audit')).rows[0].n,initial);
 }finally{await db.close();}});
test('result revisions, optimistic version, frozen roster and official degree source',async()=>{
 const {db,match,participant}=await setup();try{
 const r1=await call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'initial',0]);
 await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:2,away:0},'stale',0]),/sürümü/);
 await call(db,'federation_publish_result',[match,{type:'score',home:2,away:0},'correction',1]);
 assert.equal((await db.query('select count(*) n from org_result_revisions')).rows[0].n,2);
 assert.deepEqual((await db.query('select protocol from org_result_revisions where id=$1',[r1])).rows[0].protocol,{type:'score',home:1,away:0});
 await assert.rejects(db.query("update org_participants set name='Replaced' where id=$1",[participant]),/değiştirilemez/);
 await assert.rejects(db.query('delete from org_matches where id=$1',[match]),/silinemez/);
 const award=await call(db,'federation_award_achievement',[match,child,'Championship',1,null]);
 await actor(db,coach);await db.exec('set role authenticated');
 await assert.rejects(db.query("insert into athlete_achievements(athlete_id,title,source,official_match_id) values($1,'Fake','federation_result',$2)",[child,match]));
 assert.equal((await db.query('select count(*) n from athlete_achievements where id=$1',[award])).rows[0].n,0);
 await db.exec('reset role');
 }finally{await db.close();}});
test('protocol allowlist rejects names, nulls, bogus values and non-roster identities atomically',async()=>{
 const {db,match}=await setup();try{
 for(const p of [null,{}, {type:'score',home:-1,away:0},{type:'score',home:1,away:0,name:'Child'},
 {type:'sets',sets:[{home:null,away:1}]},{type:'time',entries:[{athlete_id:id(999),value:1,placement:1}]}])
 await assert.rejects(call(db,'federation_publish_result',[match,p,'bad',0]));
 assert.equal((await db.query('select count(*) n from org_result_revisions')).rows[0].n,0);
 await call(db,'federation_publish_result',[match,{type:'sets',sets:[{home:6,away:3},{home:6,away:4}]},'sets',0]);
 }finally{await db.close();}});
test('child name defaults closed, guardian can consent/revoke, no health/dues/document fields or guest grants',async()=>{
 const {db,match}=await setup();try{
 let c=await call(db,'federation_result_card',[match]);assert.equal(c.athletes[0].name,null);
 assert.deepEqual(Object.keys(c).sort(),['athletes','category','match_id','protocol','sport_code','version']);
 await actor(db,coach);await assert.rejects(call(db,'set_athlete_publicity',[child,true]),/Veli/);
 await actor(db,guardian);await call(db,'set_athlete_publicity',[child,true]);await actor(db,officer);
 c=await call(db,'federation_result_card',[match]);assert.equal(c.athletes[0].name,'Private Child');
 await actor(db,guardian);await call(db,'set_athlete_publicity',[child,false]);await actor(db,officer);
 assert.equal((await call(db,'federation_result_card',[match])).athletes[0].name,null);
 assert.equal((await db.query("select has_function_privilege('anon','federation_result_card(uuid)','EXECUTE') v")).rows[0].v,false);
 await db.exec('set role anon');assert.equal((await db.query('select * from athletes')).rows.length,0);await db.exec('reset role');
 }finally{await db.close();}});
test('same national ID/license resolves existing athlete; conflicting matches do not merge or clone',async()=>{
 const {db}=await setup();try{
 assert.equal(await call(db,'federation_find_or_create_athlete',[club,'tenis','Ignored','Name','T-1',null]),child);
 assert.equal(await call(db,'federation_find_or_create_athlete',[club,'tenis','Ignored','Name',null,'11111111110']),child);
 await assert.rejects(db.query("insert into athletes(club_id,first_name,last_name,license_number) values($1,'Duplicate','Child','T-1')",[club]),/eşleşmesi/);
 await actor(db,coach);await assert.rejects(call(db,'federation_find_or_create_athlete',[club,'tenis','A','B','T-1',null]),/görev/);
 assert.equal((await db.query('select count(*) n from athletes')).rows[0].n,1);
 }finally{await db.close();}});
test('club/account deletion preserves official results and degrees, drops private athlete data/name',async()=>{
 const {db,match}=await setup();try{
 await call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'initial',0]);
 await call(db,'federation_award_achievement',[match,child,'Championship',1,null]);
 await actor(db,admin);await call(db,'federation_revoke_appointment',[(await db.query("select id from federation_appointments where duty='result_publisher'")).rows[0].id]);
 // Whole club deletion must not require a federation appointment on FK cleanup.
 await db.query('delete from clubs where id=$1',[club]);
 assert.equal((await db.query('select count(*) n from athletes')).rows[0].n,0);
 assert.equal((await db.query('select count(*) n from athlete_achievements')).rows[0].n,1);
 assert.equal((await db.query('select count(*) n from org_result_revisions')).rows[0].n,1);
 await db.query('delete from auth.users where id=$1',[officer]);
 assert.equal((await db.query('select count(*) n from org_result_revisions where actor_id is null')).rows[0].n,1);
 }finally{await db.close();}});

test('authenticated RPC works but helpers, official table writes and audit are inaccessible',async()=>{
 const {db,match}=await setup();try{
 await db.exec('set role authenticated');
 await call(db,'federation_publish_result',[match,{type:'time',entries:[{athlete_id:child,value:12.34,placement:1}]},'official time',0]);
 assert.equal((await call(db,'federation_result_card',[match])).protocol.type,'time');
 for(const q of ['select * from federation_audit','select * from athlete_sport_registrations','delete from org_result_revisions',
 "select _federation_require('tenis','34','result_publisher')","select coach_level_for_sport(null,'tenis')"])
 await assert.rejects(db.query(q),/permission denied/);
 await db.exec('reset role');
 }finally{await db.close();}});

test('club development never official; new credentials expire; grade one needs same-sport supervisor',async()=>{
 const {db}=await setup();try{
 await actor(db,coach);
 await db.query("insert into athlete_achievements(athlete_id,title,source,verified) values($1,'Club goal','goal',true)",[child]);
 assert.equal((await db.query("select count(*) n from athlete_achievements where source='federation_result'")).rows[0].n,0);
 await assert.rejects(db.query("insert into profile_credentials(profile_id,kind,sport_code,status) values($1,'coach','tenis','pending')",[coach]),/bitiş/);
 await assert.rejects(db.query("insert into profile_credentials(profile_id,kind,sport_code,status,expires_on) values($1,'coach','tenis','approved',current_date+1)",[coach]),/onaylayamazsın/);
 await assert.rejects(db.query("insert into club_memberships(club_id,profile_id,role,coach_level) values($1,$2,'coach',1)",[club,guardian]),/süpervizör/);
 await assert.rejects(db.query("insert into club_memberships(club_id,profile_id,role,coach_level,supervisor_id) values($1,$2,'coach',1,$3)",[club,guardian,coach]),/süpervizör/);
 assert.equal((await db.query("select coach_level_for_sport($1,'tenis') n",[coach])).rows[0].n,0);
 assert.equal((await db.query("select coach_level_for_sport($1,'yuzme') n",[coach])).rows[0].n,5);
 }finally{await db.close();}});

test('license revision and transfer retain historical roster/results and one current sport club',async()=>{
 const {db,match,participant}=await setup();try{
 await call(db,'federation_publish_result',[match,{type:'rank',entries:[{athlete_id:child,value:1,placement:1}]},'rank',0]);
 await call(db,'federation_register_license',[child,'tenis','T-2','2092-01-01']);
 assert.equal(await call(db,'federation_find_or_create_athlete',[club,'tenis','Ignored','Name','T-2',null]),child);
 const old=(await db.query('select home_roster_revision_id from org_result_revisions')).rows[0].home_roster_revision_id;
 await call(db,'federation_transfer_athlete',[child,'tenis',other,'approved transfer']);
 assert.equal((await db.query('select club_id from athlete_sport_registrations')).rows[0].club_id,other);
 assert.equal((await db.query('select club_id from athletes')).rows[0].club_id,other);
 assert.deepEqual((await db.query('select athlete_ids from org_roster_revisions where id=$1',[old])).rows[0].athlete_ids,[child]);
 assert.equal((await db.query('select count(*) n from athlete_transfers')).rows[0].n,1);
 assert.equal((await db.query("select detail->>'previous_license_number' v from federation_audit where action='license_revision' order by id desc limit 1")).rows[0].v,'T-1');
 assert.equal((await call(db,'federation_result_card',[match])).athletes[0].athlete_id,child);
 await assert.rejects(call(db,'federation_publish_roster',[participant,[child],'old club',1]),/kulüp/);
 }finally{await db.close();}});

test('disputes append; cannot target another match or bypass appointments',async()=>{
 const {db,match}=await setup();try{
 const first=await call(db,'federation_submit_dispute',[match,'Review requested',null]);
 await call(db,'federation_submit_dispute',[match,'Correction investigated',first]);
 await assert.rejects(call(db,'federation_submit_dispute',[match,'Other',id(999)]),/kaynağı/);
 await actor(db,coach);await assert.rejects(call(db,'federation_submit_dispute',[match,'Fake',null]),/görev/);
 assert.equal((await db.query('select count(*) n from official_disputes')).rows[0].n,2);
 }finally{await db.close();}});


test('legacy discovery, fixture, standings, table and share reads cannot expose official records',async()=>{
 const {db,match,org}=await setup();try{
 await call(db,'federation_publish_result',[match,{type:'rank',entries:[{athlete_id:child,value:1,placement:1}]},'rank',0]);
 await actor(db,coach);await db.exec('set role authenticated');
 for(const table of ['organizations','org_matches','org_participants'])assert.equal((await db.query('select * from '+table)).rows.length,0);
 assert.equal((await db.query('select * from org_fixture($1)',[org])).rows.length,0);
 assert.equal((await db.query('select * from org_standings($1)',[org])).rows.length,0);
 assert.equal((await db.query('select * from list_organizations()')).rows.length,0);
 assert.equal((await db.query("select available from shared_content_card('organization_share',$1)",[org])).rows[0].available,false);
 await db.exec('reset role');await db.exec('set role anon');
 for(const name of ['org_fixture','org_standings'])await assert.rejects(db.query('select * from '+name+'($1)',[org]),/permission denied/);
 await db.exec('reset role');
 }finally{await db.close();}});

test('unofficial organization ownership and legacy score flow stay usable',async()=>{
 const {db}=await setup();try{
 await actor(db,coach);await db.exec('set role authenticated');
 const org=await call(db,'create_organization',['Friendly','league',club]);
 const a=await call(db,'join_organization',[org,club,null,'Local A']);
 const b=await call(db,'join_organization',[org,club,null,'Local B']);
 await call(db,'generate_fixture',[org]);
 const m=(await db.query('select id from org_matches where org_id=$1',[org])).rows[0].id;
 await call(db,'set_match_result',[m,3,1]);
 assert.equal((await db.query('select home_score from org_fixture($1)',[org])).rows[0].home_score,3);
 assert.equal((await db.query('select * from org_standings($1)',[org])).rows.length,2);
 await db.exec('reset role');
 assert.equal((await db.query('select count(*) n from org_result_revisions')).rows[0].n,0);
 }finally{await db.close();}});

test('other sport expiry does not block valid branch roster; first legal registration is branch scoped',async()=>{
 const {db}=await setup();try{
 await actor(db,admin);
 const office=await call(db,'federation_create_office',['yuzme','Swimming','34','Swimming office']);
 for(const duty of ['program_publisher','license_registrar','club_registrar'])
 await db.query('select federation_appoint($1,$2,$3,current_date-1,current_date+30)',[office,officer,duty]);
 await actor(db,officer);
 await call(db,'federation_register_club',[club,'yuzme','Legal Club','S-1','34']);
 await call(db,'federation_register_license',[child,'yuzme','S-1','2090-01-01']);
 await call(db,'federation_register_license',[child,'tenis','T-1','2000-01-01']);
 const season=(await db.query("select federation_open_season($1,'Swim season',current_date-1,current_date+20) v",[office])).rows[0].v;
 const org=(await db.query("select federation_create_program($1,'Swim','34',current_date,current_date+7) v",[season])).rows[0].v;
 const participant=await call(db,'federation_add_participant',[org,club,null]);
 await call(db,'federation_publish_roster',[participant,[child],'valid swim license',0]);
 const third=id(12);await db.query("insert into clubs(id,name,sport_code) values($1,'Multi','tenis')",[third]);
 await call(db,'federation_register_club',[third,'yuzme','Legal Multi','S-2','34']);
 assert.equal((await db.query('select registration_sport_code from clubs where id=$1',[third])).rows[0].registration_sport_code,'yuzme');
 }finally{await db.close();}});

test('archived license restores same durable athlete key after club deletion, national authority required',async()=>{
 const {db,national}=await setup();try{
 await db.query('delete from clubs where id=$1',[club]);
 await assert.rejects(call(db,'federation_find_or_create_athlete',[other,'tenis','Private','Child','T-1',null]),/görev/);
 await actor(db,admin);await db.query("select federation_appoint($1,$2,'license_registrar',current_date-1,current_date+30)",[national,officer]);
 await actor(db,officer);
 assert.equal(await call(db,'federation_find_or_create_athlete',[other,'tenis','Private','Child','T-1',null]),child);
 assert.equal((await db.query('select count(*) n from athletes')).rows[0].n,1);
 assert.equal((await db.query('select club_id from athletes')).rows[0].club_id,other);
 }finally{await db.close();}});
