// Offline PostgreSQL only. Real application DDL/C1 triggers, reduced Auth schema.
// This does NOT test GoTrue login, production schema drift or real-user verification.
import {PGlite} from '@electric-sql/pglite';
import {pgcrypto} from '@electric-sql/pglite/contrib/pgcrypto';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const read = path => readFile(new URL('../'+path,import.meta.url),'utf8');
const migration = name => read('supabase/migrations/'+name+'.sql');
const source = await read('supabase/seed/full_roles_test_seed.sql');
const disable = await read('supabase/seed/disable_full_roles_test_accounts.sql');
const marker = 'swansport-live-role-tests-v2';
const club = '53570000-0000-4000-8000-000000000001';
const reviewer = '53570000-0000-4000-9000-000000000001';
const federation = '53570000-0000-4000-9000-000000000002';
const section = (text,start,end) => {
 const a=text.indexOf(start), b=text.indexOf(end,a+start.length);
 assert.ok(a>=0 && b>a,`Missing fixture markers: ${start} / ${end}`);
 return text.slice(a,b);
};
function configured(options={}) {
 let s=source.replace("v_confirmation text := 'CHANGE_ME'", "v_confirmation text := 'CANLI_TEST_HESAPLARINI_ONAYLIYORUM'");
 if(options.admin) s=s.replace('v_enable_platform_admin boolean := false','v_enable_platform_admin boolean := true');
 if(options.federation) s=s.replace('v_enable_federation_roles boolean := false','v_enable_federation_roles boolean := true')
  .replace('v_federation_id uuid := null',`v_federation_id uuid := '${federation}'`);
 if(options.reviewer) s=s.replace('v_reviewer_id uuid := null',`v_reviewer_id uuid := '${reviewer}'`);
 return s;
}
async function run(db,s=configured()) {
 try {return await db.exec(s);} catch(e) {await db.exec('rollback');throw e;}
}
async function setup() {
 const db=new PGlite({extensions:{pgcrypto}});
 try {
  await db.exec(`create role anon;create role authenticated;create role service_role;
   create schema auth;create extension pgcrypto;
   create table auth.users(id uuid primary key,instance_id uuid,aud text,role text,email text unique,
    encrypted_password text,email_confirmed_at timestamptz,confirmation_token text,recovery_token text,
    email_change_token_new text,email_change text,email_change_token_current text,phone_change text,
    phone_change_token text,reauthentication_token text,raw_app_meta_data jsonb default '{}',
    raw_user_meta_data jsonb default '{}',created_at timestamptz,updated_at timestamptz,banned_until timestamptz);
   create table auth.identities(id uuid primary key,user_id uuid references auth.users(id),
    provider_id text,identity_data jsonb,provider text,created_at timestamptz,updated_at timestamptz,
    unique(provider_id,provider));
   create function auth.uid() returns uuid language sql as $$
    select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;`);
  await db.exec(await migration('0001_foundation'));
  await db.exec(await migration('0004_roles_verification'));
  await db.exec(`create table cities(code text primary key,name text);
   create table sports(code text primary key,name text);
   insert into cities values('34','İstanbul');insert into sports values('futbol','Futbol');
   alter table clubs add column sport_code text references sports(code);
   alter table teams add column sport_code text references sports(code);
   alter table profile_credentials add column sport_code text references sports(code),add column expires_on date;
   insert into auth.users(id,email) values('${reviewer}','existing-admin@example.invalid');
   update profiles set is_platform_admin=true where id='${reviewer}';`);
  const foundation=await migration('0094_federation_foundation');
  await db.exec(section(foundation,'create table if not exists public.federations (','create table if not exists public.federation_audit ('));
  await db.exec(section(foundation,'create function public.coach_level_for_sport(', 'revoke all on function public.coach_level_for_sport'));
  await db.exec(`insert into federations(id,sport_code,name) values('${federation}','futbol','Existing federation');`);
  const roles=await migration('0110_sports_role_hierarchy');
  // Only the FK target is used: this seed deliberately creates no matches.
  await db.exec('create table org_matches(id uuid primary key)');
  await db.exec(section(roles,'create table if not exists public.federation_roles (','create table if not exists public.org_match_lineup_notes ('));
  const finance=await migration('0030_expenses');
  await db.exec(section(finance,'create table if not exists public.club_accountants (','alter table public.club_accountants enable'));
  const turf=await migration('0038_turf_venues');
  await db.exec(section(turf,'create table if not exists public.turf_fields (','create or replace function public.is_turf_manager('));
  await db.exec(section(await migration('0093_turf_duty_delegation'),
   'create table if not exists public.turf_duty_delegations(', 'create index if not exists turf_duty_recipient'));
  const store=await migration('0050_marketplace');
  await db.exec(section(store,'create table if not exists public.stores (','-- Bu kişi mağazayı yönetiyor mu'));
  const health=await migration('0064_eligibility_gate');
  await db.exec(section(health,'create table if not exists public.club_staff_permissions (','alter table public.club_staff_permissions enable'));
  await db.exec(await migration('0099_identity_credential_kind'));
  // Real C1 identity/credential/membership/guardian/invite guards, not mocks.
  const gate=await migration('0100_identity_membership_gate');
  await db.exec(section(gate,"set local lock_timeout",'-- Existing endpoint bodies with additive entry checks.'));
  await db.exec(`create trigger seed_new_row_check before insert or update on profile_credentials
   for each row execute function _federation_new_row_rules();
   create trigger seed_membership_row_check before insert or update on club_memberships
   for each row execute function _federation_new_row_rules();`);
  return db;
 } catch(e) {await db.close();throw e;}
}
export {setup};
async function count(db,table) {return Number((await db.query(`select count(*) n from ${table}`)).rows[0].n);}

test('seed requires explicit live confirmation and rolls back all accounts',async()=>{
 const db=await setup();try {
  await assert.rejects(run(db,source),/güvenlik kilidi/);
  assert.equal(await count(db,'auth.users'),1);assert.equal(await count(db,'clubs'),0);
 }finally{await db.close();}
});
test('45 accounts and email identities, exact password, no fake approvals/admin/federation/athlete records',async()=>{
 const db=await setup();try {
  const result=await run(db);
  assert.equal(result.at(-1).rows.length,45);
  assert.equal(await count(db,'auth.identities'),45);
  const users=(await db.query("select * from auth.users where raw_app_meta_data->>'seed_owner'=$1",[marker])).rows;
  assert.equal(users.length,45);
  assert.equal(new Set(users.map(u=>u.encrypted_password)).size,45,'each account has an independent salt');
  assert.ok(users.every(u=>u.email.endsWith('@test.swansport.invalid')&&u.email_confirmed_at));
  assert.equal(Number((await db.query("select count(*) n from auth.users where encrypted_password=crypt('test1234',encrypted_password)")).rows[0].n),45);
  for(const table of ['profile_credentials','club_memberships','athletes','guardians','federation_roles','referee_profiles'])
   assert.equal(await count(db,table),0,table);
  assert.equal(Number((await db.query('select count(*) n from profiles where is_platform_admin')).rows[0].n),1);
  assert.equal(await count(db,'club_accountants'),1);
  assert.equal((await db.query('select active from turf_fields')).rows[0].active,false);
  assert.equal((await db.query('select status from stores')).rows[0].status,'pending');
 }finally{await db.close();}
});
test('replay preserves changed password, ban, profile edits and revoked accountant relationship',async()=>{
 const db=await setup();try {
  await run(db);
  await db.exec(`update auth.users set encrypted_password='changed',banned_until='2099-01-01'
   where email='muhasebeci@test.swansport.invalid';
   update profiles set full_name='Preserved' where id=md5('${marker}/muhasebeci')::uuid;
   update club_accountants set status='revoked';`);
  await run(db);
  assert.equal(await count(db,'auth.identities'),45);
  assert.equal((await db.query("select encrypted_password from auth.users where email='muhasebeci@test.swansport.invalid'")).rows[0].encrypted_password,'changed');
  assert.ok((await db.query("select banned_until from auth.users where email='muhasebeci@test.swansport.invalid'")).rows[0].banned_until);
  assert.equal((await db.query("select full_name from profiles where id=md5($1)::uuid",[marker+'/muhasebeci'])).rows[0].full_name,'Preserved');
  assert.equal((await db.query('select status from club_accountants')).rows[0].status,'revoked');
 }finally{await db.close();}
});
test('unmarked email collision never changes real account password or creates partial seed',async()=>{
 const db=await setup();try {
  await db.exec("insert into auth.users(id,email,encrypted_password) values(gen_random_uuid(),'taraftar@test.swansport.invalid','original')");
  await assert.rejects(run(db),/çakışması/);
  assert.equal(await count(db,'auth.users'),2);assert.equal(await count(db,'clubs'),0);
  assert.equal((await db.query("select encrypted_password from auth.users where email='taraftar@test.swansport.invalid'")).rows[0].encrypted_password,'original');
 }finally{await db.close();}
});
test('explicit sensitive options create scoped roles without merging president/MHK/disciplines or appointments',async()=>{
 const db=await setup();try {
  await run(db,configured({admin:true,federation:true}));
  assert.equal(await count(db,'federation_roles'),6);assert.equal(await count(db,'federation_appointments'),4);
  assert.equal(await count(db,'referee_profiles'),9);assert.equal(await count(db,'match_officials'),0);
  assert.equal(Number((await db.query('select count(*) n from profiles where is_platform_admin')).rows[0].n),2);
  assert.ok((await db.query('select * from federation_roles')).rows.every(r=>r.federation_id===federation));
  await run(db,configured({admin:true,federation:true}));
  assert.equal(await count(db,'federation_roles'),6);assert.equal(await count(db,'referee_profiles'),9);
 }finally{await db.close();}
});
test('C1 reviewer and real identity/branch gates remain required; no privilege bypass',async()=>{
 const db=await setup();try {
  await assert.rejects(run(db,configured({reviewer:true})),/kimliği doğrulanmış/);
  await run(db);
  // Test-fixture-only review: never copied into live seed. Real C1 guards run.
  await db.exec(`select set_config('request.jwt.claim.sub','${reviewer}',false);
   insert into profile_credentials(profile_id,kind) values('${reviewer}','identity');
   update profile_credentials set status='approved',verified_national_id='11111111110' where profile_id='${reviewer}';`);
  await run(db,configured({reviewer:true}));
  assert.equal(await count(db,'club_memberships'),0);
  await db.exec(`insert into profile_credentials(profile_id,kind)
   select id,'identity' from auth.users where email='antrenor-5@test.swansport.invalid';
   update profile_credentials set status='approved',verified_national_id='22222222220'
    where profile_id=md5('${marker}/antrenor-5')::uuid;
   insert into profile_credentials(profile_id,kind,sport_code,expires_on,coach_level)
   values(md5('${marker}/antrenor-5')::uuid,'coach','futbol',current_date+30,5);
   update profile_credentials set status='approved' where kind='coach';`);
  await run(db,configured({reviewer:true}));
  assert.equal(await count(db,'club_memberships'),1);
  const m=(await db.query('select * from club_memberships')).rows[0];
  assert.equal(m.club_id,club);assert.equal(m.identity_gate_legacy,false);assert.equal(m.coach_level,5);
  assert.equal(await count(db,'club_staff_permissions'),0);
 }finally{await db.close();}
});
test('disable is guarded, bans only owned accounts, revokes sensitive roles and replay never unbans',async()=>{
 const db=await setup();try {
  await run(db,configured({admin:true,federation:true}));
  await db.exec(`create table auth.refresh_tokens(user_id text);
   create table auth.sessions(user_id uuid);
   insert into auth.refresh_tokens select id::text from auth.users;
   insert into auth.sessions select id from auth.users;`);
  await assert.rejects(run(db,disable),/Kapatma onayı/);
  assert.equal((await db.query('select count(*)::int n from auth.users where banned_until is not null')).rows[0].n,0);
  await run(db,disable.replace("v_confirmation text := 'CHANGE_ME'","v_confirmation text := 'TEST_HESAPLARINI_KAPAT'"));
  assert.equal((await db.query('select count(*)::int n from auth.users where banned_until is not null')).rows[0].n,45);
  assert.equal((await db.query('select count(*)::int n from profiles where is_platform_admin')).rows[0].n,1);
  assert.ok((await db.query('select * from federation_roles')).rows.every(r=>r.revoked_at));
  assert.ok((await db.query('select * from referee_profiles')).rows.every(r=>!r.is_active));
  assert.equal(await count(db,'auth.refresh_tokens'),1);assert.equal(await count(db,'auth.sessions'),1);
  await run(db);
  assert.equal((await db.query('select count(*)::int n from auth.users where banned_until is not null')).rows[0].n,45);
  assert.equal((await db.query('select status from club_accountants')).rows[0].status,'revoked');
  assert.equal((await db.query('select status from stores')).rows[0].status,'suspended');
 }finally{await db.close();}
});
test('preflight rejects wrong identity ownership, missing role schema and wrong sport federation atomically',async()=>{
 for(const scenario of ['identity','schema','federation']) {
  const db=await setup();try {
   if(scenario==='identity') {
    await db.exec(`insert into auth.identities(id,user_id,provider_id,provider,identity_data)
     values(gen_random_uuid(),'${reviewer}','${reviewer}','email','{"email":"taraftar@test.swansport.invalid"}')`);
    await assert.rejects(run(db),/Auth identity/);
   }else if(scenario==='schema') {
    await db.exec('drop table club_staff_roles');
    await assert.rejects(run(db),/Önkoşul eksik/);
   }else {
    await assert.rejects(run(db,configured({federation:true}).replace(federation,club)),/doğru branşta/);
   }
   assert.equal(await count(db,'auth.users'),1);assert.equal(await count(db,'clubs'),0);
  }finally{await db.close();}
 }
});
test('verified coaches activate in supervisor order and disable suspends assistants before supervisors',async()=>{
 const db=await setup();try {
  await run(db);
  // Synthetic identity values exist ONLY in this isolated test database.
  await db.exec(`select set_config('request.jwt.claim.sub','${reviewer}',false);
   insert into profile_credentials(profile_id,kind) values('${reviewer}','identity');
   update profile_credentials set status='approved',verified_national_id='11111111110'
    where profile_id='${reviewer}';
   insert into profile_credentials(profile_id,kind)
    select id,'identity' from auth.users where email in ('antrenor-5@test.swansport.invalid','antrenor-1@test.swansport.invalid');
   update profile_credentials set status='approved',verified_national_id='22222222220'
    where profile_id=md5('${marker}/antrenor-5')::uuid;
   update profile_credentials set status='approved',verified_national_id='33333333330'
    where profile_id=md5('${marker}/antrenor-1')::uuid;
   insert into profile_credentials(profile_id,kind,sport_code,expires_on,coach_level) values
    (md5('${marker}/antrenor-5')::uuid,'coach','futbol',current_date+30,5),
    (md5('${marker}/antrenor-1')::uuid,'coach','futbol',current_date+30,1);
   update profile_credentials set status='approved' where kind='coach';`);
  await run(db,configured({reviewer:true}));
  assert.equal(await count(db,'club_memberships'),2);
  assert.equal((await db.query('select count(*)::int n from club_memberships where status=\'active\'')).rows[0].n,2);
  const cleanup=disable.replace("v_confirmation text := 'CHANGE_ME'","v_confirmation text := 'TEST_HESAPLARINI_KAPAT'")
   .replace('v_reviewer_id uuid := null',`v_reviewer_id uuid := '${reviewer}'`);
  await run(db,cleanup);
  assert.ok((await db.query('select * from club_memberships')).rows.every(r=>r.status==='suspended'));
  await run(db,configured({reviewer:true}));
  assert.ok((await db.query('select * from club_memberships')).rows.every(r=>r.status==='suspended'));
 }finally{await db.close();}
});
test('setup and disable are each one atomic DO; reports run after temporary tables have disappeared',async()=>{
 const db=await setup();try {
  const setupSql=configured();
  const setupEnd=setupSql.indexOf('$seed$;',setupSql.indexOf('do $seed$'))+'$seed$;'.length;
  const setupOnly=setupSql.slice(0,setupEnd);
  const report=setupSql.slice(setupEnd);
  // Exactly how a statement-by-statement SQL Editor executes this script.
  await db.exec(setupOnly);
  assert.equal((await db.query("select to_regclass('pg_temp._swan_role_accounts') r")).rows[0].r,null);
  assert.equal((await db.exec(report)).at(-1).rows.length,45);
  const cleanup=disable.replace("v_confirmation text := 'CHANGE_ME'","v_confirmation text := 'TEST_HESAPLARINI_KAPAT'");
  const cleanupEnd=cleanup.indexOf('$disable$;',cleanup.indexOf('do $disable$'))+'$disable$;'.length;
  await db.exec(cleanup.slice(0,cleanupEnd));
  assert.equal((await db.query("select to_regclass('pg_temp._swan_disable_targets') r")).rows[0].r,null);
  assert.equal(Number((await db.exec(cleanup.slice(cleanupEnd))).at(-1).rows[0].devre_disi_test_hesabi),45);
 }finally{await db.close();}
});
