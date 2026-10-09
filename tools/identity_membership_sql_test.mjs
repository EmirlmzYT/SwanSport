// Real legacy membership/invite functions + C1 on the shared isolated PostgreSQL fixture.
import { setup, apply, actor, call, id, admin, officer, coach, guardian, child, club, other }
 from './federation_foundation_sql_test.mjs';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';
const sql=async n=>readFile(new URL('../supabase/migrations/'+n+'.sql',import.meta.url),'utf8');
const kind=await sql('0099_identity_credential_kind'),gate=await sql('0100_identity_membership_gate');
const person=id(50),parent=id(51),kid=id(52),second=id(53);
function fn(src,name){const a=src.indexOf('create or replace function public.'+name+'(');return src.slice(a,src.indexOf('end; $$;',a)+8);}
async function c1(){const f=await setup();try{
 const {db}=f;
 await db.exec(await sql('0007_fix_review_credential'));
 await db.exec(await sql('0008_club_applications'));
 const offers=await sql('0009_offers_notifications_dm');
 const a=offers.indexOf('alter table public.club_applications');
 await db.exec(offers.slice(a,offers.indexOf('-- Kulüpten kişiye teklif gönder.',a)));
 await db.exec(fn(offers,'offer_to_person'));await db.exec(fn(offers,'review_club_application'));
 await db.exec(`alter table auth.users add column email text;
 alter table profiles add column role text;
 alter table invite_codes add column club_id uuid,add column target_email text,add column field_id uuid;
 create table club_accountants(club_id uuid,profile_id uuid,added_by uuid,status text,primary key(club_id,profile_id));
 create table turf_field_managers(field_id uuid,profile_id uuid,added_by uuid,status text,primary key(field_id,profile_id));
 insert into auth.users(id) values('${person}'),('${parent}'),('${kid}'),('${second}');
 update profiles set national_id='11111111110' where id in ('${person}','${second}');`);
 await db.exec(fn(await sql('0038_turf_venues'),'redeem_invite_code'));
 const links=await sql('0076_athlete_account_link');
 // Use the actual small pure helper and the actual account-linking endpoints.
 const la=links.indexOf('create or replace function public.split_full_name(');
 if(la>=0)await db.exec(links.slice(la,links.indexOf('$fn$;',la)+6));
 for(const name of ['create_athlete_from_member','link_athlete_to_member']){
  const start=links.indexOf('create or replace function public.'+name+'(');
  await db.exec(links.slice(start,links.indexOf('$fn$;',start)+6));
 }
 await apply(db,await sql('0097_federation_public_reads'));await apply(db,await sql('0098_public_result_adult_name'));
 f.tablesBefore=(await db.query("select tablename from pg_tables where schemaname='public' order by tablename")).rows;
 await apply(db,kind);await apply(db,gate);return f;
 }catch(e){await f.db.close();throw e;}}
async function auth(db,p){await db.exec('reset role');await actor(db,p);await db.exec('set role authenticated');}
async function owner(db,p=officer){await db.exec('reset role');await actor(db,p);}
async function verify(db,p,national){
 await auth(db,p);
 let cred=(await db.query("select id from profile_credentials where profile_id=$1 and kind='identity'",[p])).rows[0]?.id;
 if(!cred)cred=(await db.query("insert into profile_credentials(profile_id,kind) values($1,'identity') returning id",[p])).rows[0].id;
 await db.query("insert into verification_documents(owner_type,owner_id,doc_type,storage_path,uploaded_by) values('credential',$1,'kimlik',$2,$3)",[cred,p+'/kimlik.pdf',p]);
 await auth(db,admin);await call(db,'review_credential',[cred,true,null,null,null,national,null]);await owner(db);return cred;
}
async function sport(db,p,code='tenis',which='athlete_licensed',expiry='2090-01-01',level=null){
 await auth(db,p);const cred=(await db.query("insert into profile_credentials(profile_id,kind,sport_code,expires_on,coach_level) values($1,$2,$3,$4,$5) returning id",[p,which,code,expiry,level])).rows[0].id;
 await auth(db,admin);await call(db,'review_credential',[cred,true,null,null,null,null,null]);await owner(db);return cred;
}

test('C1: actual schema applies/reapplies, no new table, snapshots never expand on replay',async()=>{
 const {db,tablesBefore}=await c1();try{
 assert.deepEqual((await db.query("select tablename from pg_tables where schemaname='public' order by tablename")).rows,tablesBefore);
 assert.equal((await db.query('select identity_gate_legacy from club_memberships where profile_id=$1 limit 1',[coach])).rows[0].identity_gate_legacy,true);
 assert.equal((await db.query("select is_nullable from information_schema.columns where table_name='athletes' and column_name='club_id'")).rows[0].is_nullable,'NO');
 assert.equal((await db.query("select is_nullable from information_schema.columns where table_name='athletes' and column_name='profile_id'")).rows[0].is_nullable,'YES');
 await verify(db,person,'22222222220');await sport(db,person);
 await auth(db,coach);await db.query("insert into club_memberships(club_id,profile_id,role) values($1,$2,'athlete')",[club,person]);
 await owner(db);await apply(db,gate);
 assert.equal((await db.query('select identity_gate_legacy from club_memberships where profile_id=$1',[person])).rows[0].identity_gate_legacy,false);
 assert.equal((await db.query("select count(*) n from pg_proc where proname='review_credential' and pronamespace='public'::regnamespace")).rows[0].n,1);
 assert.equal((await db.query("select count(*) n from pg_proc where proname='review_club_application' and pronamespace='public'::regnamespace")).rows[0].n,1);
 }finally{await db.close();}});

test('C1: declared profile fields and roles cannot open identity, membership, team or club gates',async()=>{
 const {db}=await c1();try{
 const team=(await db.query('select id from teams where club_id=$1 limit 1',[club])).rows[0].id;
 await auth(db,person);await db.query("update profiles set national_id='22222222220',role='coach' where id=$1",[person]);
 assert.deepEqual(await call(db,'my_identity_gate'),{identity_verified:false,legacy_club_ids:[]});
 await assert.rejects(call(db,'apply_to_club',[club,'athlete',null]),/kimlik/);
 await assert.rejects(db.query("insert into club_memberships(club_id,profile_id,role) values($1,$2,'athlete')",[club,person]),/kimlik/);
 await assert.rejects(db.query('insert into team_memberships(athlete_id,team_id) values($1,$2)',[child,team]),/kimlik/);
 await assert.rejects(call(db,'create_club',['New club',null,null]),/kimlik/);
 await assert.rejects(db.query('update profiles set is_platform_admin=true where id=$1',[person]),/Platform yetkisi/);
 await auth(db,coach);await assert.rejects(db.query("insert into club_memberships(club_id,profile_id,role) values($1,$2,'coach')",[club,person]),/kimlik/);
 }finally{await db.close();}});

test('C1: identity review is admin RPC only and verifies the document, not a declared TCKN',async()=>{
 const {db}=await c1();try{
 await auth(db,person);
 await assert.rejects(db.query("insert into profile_credentials(profile_id,kind,status,verified_national_id) values($1,'identity','approved','22222222220')",[person]),/İnceleme/);
 const cred=(await db.query("insert into profile_credentials(profile_id,kind) values($1,'identity') returning id",[person])).rows[0].id;
 await assert.rejects(call(db,'review_credential',[cred,true,null,null,null,'22222222220',null]),/Yetkisiz/);
 await assert.rejects(db.query("update profile_credentials set verified_national_id='22222222220',status='approved' where id=$1",[cred]),/permission denied/);
 await auth(db,admin);await assert.rejects(call(db,'review_credential',[cred,true,null,null,null,'22222222220',null]),/kimlik belgesi/);
 await assert.rejects(db.query("update profile_credentials set verified_national_id='22222222220' where id=$1",[cred]),/permission denied/);
 await verify(db,person,'22222222220');await auth(db,person);
 assert.equal((await call(db,'my_identity_gate')).identity_verified,true);
 await assert.rejects(call(db,'_c1_has_identity',[person]),/permission denied/);
 }finally{await db.close();}});

test('C1: one verified TCKN belongs to one account; old duplicate declarations remain untouched',async()=>{
 const {db}=await c1();try{
 await verify(db,person,'11111111110');await assert.rejects(verify(db,second,'11111111110'),/duplicate key/);
 await owner(db);assert.equal((await db.query("select count(*) n from profiles where national_id='11111111110'")).rows[0].n,2);
 await auth(db,second);assert.equal((await call(db,'my_identity_gate')).identity_verified,false);
 await auth(db,admin);const cred=(await db.query("select id from profile_credentials where profile_id=$1 and kind='identity'",[person])).rows[0].id;
 await assert.rejects(call(db,'review_credential',[cred,true,null,null,null,'33333333330',null]),/değiştirilemez/);
 }finally{await db.close();}});

test('C1: wrong sport and expired credentials fail; legacy approved null expiry still opens its branch',async()=>{
 const {db}=await c1();try{
 await verify(db,person,'22222222220');await sport(db,person,'yuzme');
 await auth(db,person);await assert.rejects(call(db,'apply_to_club',[club,'athlete',null]),/branş/);
 const cred=await sport(db,person);await owner(db,admin);await db.query("update profile_credentials set expires_on='2000-01-01' where id=$1",[cred]);
 await auth(db,person);await assert.rejects(call(db,'apply_to_club',[club,'athlete',null]),/branş/);
 // Existing approved coach: null expiry is valid in its actual Yüzme branch.
 await owner(db);assert.equal((await db.query("select _c1_has_sport($1,'yuzme','coach') v",[coach])).rows[0].v,true);
 assert.equal((await db.query("select _c1_has_sport($1,'tenis','coach') v",[coach])).rows[0].v,false);
 }finally{await db.close();}});

test('C1: pending legacy sport credential requires expiry on its first new approval',async()=>{
 const {db}=await c1();try{
 // Model a pending record predating Phase A (not a new client insertion).
 await owner(db);await db.exec('alter table profile_credentials disable trigger federation_credential_rules');
 const cred=(await db.query("insert into profile_credentials(profile_id,kind,sport_code) values($1,'athlete_licensed','tenis') returning id",[person])).rows[0].id;
 await db.exec('alter table profile_credentials enable trigger federation_credential_rules');
 await auth(db,admin);await assert.rejects(call(db,'review_credential',[cred,true,null,null,null,null,null]),/Yeni onay/);
 await call(db,'review_credential',[cred,true,null,null,null,null,'2090-01-01']);
 assert.equal((await db.query('select status from profile_credentials where id=$1',[cred])).rows[0].status,'approved');
 }finally{await db.close();}});

test('C1: old active staff keep writes, but cannot manufacture legacy grants for a new member',async()=>{
 const {db}=await c1();try{
 await auth(db,coach);const team=(await db.query("insert into teams(club_id,name) values($1,'New training group') returning id",[club])).rows[0].id;
 await db.query("update teams set name='Renamed' where id=$1",[team]);
 await assert.rejects(db.query("insert into club_memberships(club_id,profile_id,role,identity_gate_legacy) values($1,$2,'athlete',true)",[club,person]),/Geçiş/);
 assert.ok((await call(db,'my_identity_gate')).legacy_club_ids.includes(club));
 await owner(db,coach);await db.query("update club_memberships set status='suspended' where club_id=$1 and profile_id=$2",[club,coach]);
 await auth(db,coach);await assert.rejects(db.query("insert into teams(club_id,name) values($1,'Blocked')",[club]),/kimlik/);
 }finally{await db.close();}});

test('C1: old offer acceptance cannot bypass verification; valid application creates one gated membership',async()=>{
 const {db}=await c1();try{
 await auth(db,coach);const offer=await call(db,'offer_to_person',[club,person,'athlete',null]);
 await auth(db,person);await assert.rejects(call(db,'review_club_application',[offer,true,null,null,null]),/kimlik/);
 await verify(db,person,'22222222220');await sport(db,person);
 await auth(db,person);await call(db,'review_club_application',[offer,true,null,null,null]);
 await assert.rejects(call(db,'review_club_application',[offer,true,null,null,null]),/zaten/);
 await owner(db);assert.equal((await db.query('select identity_gate_legacy from club_memberships where profile_id=$1',[person])).rows[0].identity_gate_legacy,false);
 }finally{await db.close();}});

test('C1: a verified parent redeems a valid invite without a license, not unrelated athletic roles',async()=>{
 const {db}=await c1();try{
 await auth(db,coach);const code=await call(db,'create_guardian_invite',[child]);
 await auth(db,parent);await assert.rejects(call(db,'redeem_invite_code',[code]),/kimlik/);
 await verify(db,parent,'33333333330');await auth(db,parent);await call(db,'redeem_invite_code',[code]);
 await assert.rejects(call(db,'redeem_invite_code',[code]),/geçersiz/);
 assert.equal((await db.query('select athlete_id from guardians where profile_id=$1',[parent])).rows[0].athlete_id,child);
 await assert.rejects(call(db,'apply_to_club',[club,'coach',null]),/branş/);
 await owner(db);assert.equal((await db.query("select count(*) n from profile_credentials where profile_id=$1 and kind<>'identity'",[parent])).rows[0].n,0);
 assert.equal((await db.query('select _c1_live_guardian($1) v',[child])).rows[0].v,true);
 }finally{await db.close();}});

test('C1: linked child cannot gain full membership without a verified guardian; nullable account remains supported',async()=>{
 const {db}=await c1();try{
 await verify(db,kid,'44444444440');await sport(db,kid);
 await auth(db,coach);await db.query('update athletes set profile_id=$1 where id=$2',[kid,child]);
 await assert.rejects(db.query("insert into club_memberships(club_id,profile_id,role) values($1,$2,'athlete')",[club,kid]),/veli/);
 await verify(db,guardian,'55555555550');await auth(db,coach);
 await db.query("insert into club_memberships(club_id,profile_id,role) values($1,$2,'athlete')",[club,kid]);
 await db.query("insert into athletes(club_id,first_name,last_name) values($1,'No','Account')",[club]);
 assert.equal((await db.query("select profile_id from athletes where first_name='No'")).rows[0].profile_id,null);
 }finally{await db.close();}});

test('C1: raw guardian insertion and forged used invites cannot replace real redemption',async()=>{
 const {db}=await c1();try{
 await verify(db,parent,'33333333330');await auth(db,coach);
 await assert.rejects(db.query("insert into guardians(athlete_id,profile_id,display_name) values($1,$2,'Forged')",[child,parent]),/davet/);
 await assert.rejects(db.query("insert into invite_codes(code,athlete_id,created_by,used_by,used_at) values('FORGED',$1,$2,$3,now())",[child,coach,parent]),/Tüketilmiş/);
 const code=await call(db,'create_guardian_invite',[child]);await owner(db);await db.query("update invite_codes set expires_at=now()-interval '1 second' where code=$1",[code]);
 await auth(db,parent);await assert.rejects(call(db,'redeem_invite_code',[code]),/geçersiz/);
 }finally{await db.close();}});

test('C1: official roster needs verified writer and eligible child; admin still has no sports bypass',async()=>{
 const {db,participant,match}=await c1();try{
 await auth(db,officer);await assert.rejects(call(db,'federation_publish_roster',[participant,[child],'revision',1]),/kimlik/);
 await verify(db,officer,'66666666660');await auth(db,officer);
 await assert.rejects(call(db,'federation_publish_roster',[participant,[child],'revision',1]),/veli/);
 await verify(db,guardian,'55555555550');await auth(db,officer);await call(db,'federation_publish_roster',[participant,[child],'revision',1]);
 await verify(db,admin,'77777777770');await auth(db,admin);
 await assert.rejects(call(db,'federation_publish_result',[match,{type:'score',home:1,away:0},'admin',0]),/görev/);
 await assert.rejects(call(db,'federation_register_license',[child,'tenis','T-1','2090-01-01']),/görev/);
 }finally{await db.close();}});

test('C1: public RPCs and publication survive the identity gate; anonymous private sources stay closed',async()=>{
 const {db,org,match}=await c1();try{
 await auth(db,officer);await call(db,'federation_publish_program',[org,true]);
 await call(db,'federation_publish_result',[match,{type:'score',home:2,away:0},'published',0]);
 await owner(db);await actor(db,'');await db.exec('set role anon');
 assert.equal((await db.query('select id from public_sport_programs()')).rows[0].id,org);
 assert.equal((await db.query('select id from public_program_fixture($1)',[org])).rows[0].id,match);
 assert.deepEqual((await db.query('select protocol from public_program_result($1)',[match])).rows[0].protocol,{type:'score',home:2,away:0});
 for(const q of ['select * from profile_credentials','select * from athletes','select my_identity_gate()'])await assert.rejects(db.query(q),/permission denied/);
 }finally{await db.close();}});


test('C1: valid legacy null-expiry coach can found a pending club; another branch cannot assign a coach',async()=>{
 const {db}=await c1();try{
 await verify(db,coach,'88888888880');await auth(db,coach);
 const pending=(await db.query('select id,status from create_club($1,$2,$3)',['Pending club',null,null])).rows[0];
 assert.equal(pending.status,'pending');
 assert.equal((await db.query('select identity_gate_legacy from club_memberships where club_id=$1',[pending.id])).rows[0].identity_gate_legacy,false);
 await verify(db,person,'22222222220');await sport(db,person,'yuzme','coach','2090-01-01',2);
 await auth(db,coach);await assert.rejects(db.query("insert into club_memberships(club_id,profile_id,role,coach_level) values($1,$2,'coach',2)",[club,person]),/branş/);
 await sport(db,person,'tenis','coach','2090-01-01',2);await auth(db,coach);
 await db.query("insert into club_memberships(club_id,profile_id,role,coach_level) values($1,$2,'coach',2)",[club,person]);
 }finally{await db.close();}});

test('C1: accountless child team assignment needs a live verified guardian and the matching branch',async()=>{
 const {db}=await c1();try{
 await auth(db,coach);const team=(await db.query("insert into teams(club_id,name,sport_code) values($1,'Tennis','tenis') returning id",[club])).rows[0].id;
 await assert.rejects(db.query('insert into team_memberships(athlete_id,team_id) values($1,$2)',[child,team]),/veli/);
 const identity=await verify(db,guardian,'55555555550');await auth(db,coach);
 await db.query('insert into team_memberships(athlete_id,team_id) values($1,$2)',[child,team]);
 const swim=(await db.query("insert into teams(club_id,name,sport_code) values($1,'Swim','yuzme') returning id",[club])).rows[0].id;
 await assert.rejects(db.query('insert into team_memberships(athlete_id,team_id) values($1,$2)',[child,swim]),/branş/);
 await auth(db,admin);await call(db,'review_credential',[identity,false,'revoked',null,null,null,null]);
 await auth(db,coach);const another=(await db.query("insert into teams(club_id,name) values($1,'Another') returning id",[club])).rows[0].id;
 await assert.rejects(db.query('insert into team_memberships(athlete_id,team_id) values($1,$2)',[child,another]),/veli/);
 }finally{await db.close();}});


test('C1: accountant and turf invite branches survive without acquiring sports membership',async()=>{
 const {db}=await c1();try{
 await auth(db,coach);await db.query("insert into invite_codes(code,purpose,club_id,created_by) values('ACC001','accountant',$1,$2)",[club,coach]);
 await db.query("insert into invite_codes(code,purpose,field_id,created_by) values('TURF01','turf_manager',$1,$2)",[id(901),coach]);
 await auth(db,person);await call(db,'redeem_invite_code',['ACC001']);await call(db,'redeem_invite_code',['TURF01']);
 assert.equal((await db.query('select id from athletes')).rows.length,0);
 await owner(db);assert.equal((await db.query('select count(*) n from club_memberships where profile_id=$1',[person])).rows[0].n,0);
 assert.equal((await db.query('select status from club_accountants where profile_id=$1',[person])).rows[0].status,'active');
 assert.equal((await db.query('select status from turf_field_managers where profile_id=$1',[person])).rows[0].status,'active');
 await verify(db,person,'22222222220');await auth(db,person);
 assert.equal((await db.query('select id from athletes')).rows.length,0);
 }finally{await db.close();}});

test('C1: account-link RPC cannot turn a new active account into an unguarded child',async()=>{
 const {db}=await c1();try{
 await verify(db,person,'22222222220');await sport(db,person);await auth(db,coach);
 await db.query("insert into club_memberships(club_id,profile_id,role) values($1,$2,'athlete')",[club,person]);
 await assert.rejects(call(db,'link_athlete_to_member',[child,person]),/veli/);
 await assert.rejects(call(db,'create_athlete_from_member',[club,person,'New','Child',null]),/veli/);
 assert.equal((await db.query('select profile_id from athletes where id=$1',[child])).rows[0].profile_id,null);
 await verify(db,guardian,'55555555550');await auth(db,coach);await call(db,'link_athlete_to_member',[child,person]);
 assert.equal((await db.query('select profile_id from athletes where id=$1',[child])).rows[0].profile_id,person);
 }finally{await db.close();}});

test('C1: old independent rows fail the migration preflight atomically without deletion or fabricated clubs',async()=>{
 const {db}=await c1();try{
 await owner(db);await db.exec('alter table athletes alter column club_id drop not null');
 await db.query("insert into athletes(id,club_id,first_name,last_name) values($1,null,'Old','Independent')",[id(999)]);
 await assert.rejects(apply(db,gate),/C1 preflight/);
 assert.equal((await db.query('select club_id from athletes where id=$1',[id(999)])).rows[0].club_id,null);
 }finally{await db.close();}});
