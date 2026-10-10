import {PGlite} from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const read=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
const [oldTests,original,partner,turf,requests,queue,duty,identity,gate,chat]=await Promise.all([
 'tools/saha_operations_sql_test.mjs','supabase/migrations/0035_public_courts.sql',
 'supabase/migrations/0037_partner_search.sql','supabase/migrations/0038_turf_venues.sql',
 'supabase/migrations/0039_turf_slot_requests.sql','supabase/migrations/0092_court_waitlist.sql',
 'supabase/migrations/0093_turf_duty_delegation.sql','supabase/migrations/0100_identity_membership_gate.sql',
 'supabase/migrations/0107_venue_guest_action_gate.sql','supabase/migrations/0040_dm_notify_and_turf_chat.sql'].map(read));
function fn(s,name){
 const m=s.match(new RegExp('create (?:or replace )?function public\\.'+name+'\\s*\\(','i'));assert(m,name);
 const tail=s.slice(m.index), tag=tail.match(/as\s+(\$[a-z_]*\$)/i);
 return tail.slice(0,tail.indexOf(tag[1]+';',tag.index+tag[0].length)+tag[1].length+1);
}
const base=oldTests.match(/const fixture=`([\s\S]*?)`;\s*async function actor/)[1]
 .replace(/\$\{id\((\d+)\)\}/g,(_,n)=>id(Number(n)));
assert(!base.includes('${'));
async function actor(db,n,role='authenticated') {
 await db.exec('reset role');await db.query("select set_config('test.actor',$1,false)",[n==null?'':id(n)]);
 await db.exec('set role '+role);
}
async function setup(){
 const db=new PGlite();
 try {
  await db.exec(base);
  await db.exec(`
   create table auth.users(id uuid primary key,phone text,phone_confirmed_at timestamptz,is_anonymous boolean default false);
   insert into auth.users(id) select id from profiles;
   update auth.users set phone='+905320000001',phone_confirmed_at=now() where id in ('${id(1)}','${id(3)}','${id(4)}');
   create table profile_credentials(profile_id uuid,kind text,status text,verified_national_id text);
   insert into profile_credentials values('${id(5)}','identity','approved','12345678901');
   create table direct_messages(id uuid primary key default gen_random_uuid(),sender_id uuid,recipient_id uuid,body text,sender_club_id uuid);
   alter table clubs add column name text;
   create table cities(code text primary key,name text);create table sports(code text primary key,name text);
   insert into cities values('34','İstanbul');insert into sports values('tennis','Tenis');
   alter table profiles add column city_code text default '34';
   alter table courts add column lat numeric default 41,add column lng numeric default 29,
    add column venue text,add column city_code text default '34',add column sport_code text default 'tennis';
   create function is_platform_admin() returns boolean language sql stable security definer as $$select coalesce((select is_platform_admin from profiles where id=auth.uid()),false)$$;
   create table blocks(blocker_id uuid,blocked_id uuid);
   create function is_blocked_between(a uuid,b uuid) returns boolean language sql stable security definer as $$select exists(select 1 from blocks where (blocker_id=a and blocked_id=b) or (blocker_id=b and blocked_id=a))$$;
   alter table profiles enable row level security;
   create policy profile_self on profiles to authenticated using(id=auth.uid()) with check(id=auth.uid());
   grant update(verification_tier) on profiles to authenticated;
   alter table courts enable row level security;create policy court_read on courts for select to anon,authenticated using(active);
   alter table turf_fields enable row level security;create policy turf_read on turf_fields for select to anon,authenticated using(active);
  `);
  await db.exec(fn(identity,'_c1_has_identity')+fn(original,'verification_rank')+fn(original,'meters_between')+fn(original,'court_checkin_radius')+fn(original,'cancel_slot')+fn(turf,'is_turf_manager'));
  await db.exec(partner.slice(partner.indexOf('create table if not exists public.sport_interests'),partner.indexOf('-- ============================ 3. RPC')));
  await db.exec(requests.slice(requests.indexOf('create table if not exists public.turf_slot_requests'),requests.indexOf('create or replace function public.request_turf_slot')));
  await db.exec(fn(chat,'notify_direct_message')+"create trigger trg_notify_direct_message after insert on direct_messages for each row execute function notify_direct_message();");
  await db.exec(fn(partner,'court_sport_codes')+fn(partner,'seek_partner')+fn(partner,'respond_partner_ping')+fn(partner,'cancel_partner_request')+fn(partner,'my_incoming_partner_pings')+fn(partner,'my_open_partner_request'));
  await db.exec(`begin;${queue}commit;begin;${duty}commit;`);
  await db.exec("update feature_flags set audience='everyone'");
  // Pre-existing private request must stay private after the migration.
  await db.query("insert into partner_requests(id,requester_id,sport_code,city_code) values($1,$2,'tennis','34')",[id(100),id(6)]);
  await db.exec(`begin;${gate}commit;`);
  await actor(db,1);return db;
 }catch(e){await db.close();throw e;}
}
async function time(db){return (await db.query("select date_trunc('hour',now())+interval '2 hours' t")).rows[0].t;}
async function claim(db){return (await db.query('select claim_slot($1,$2,0,1) id',[id(10),await time(db)])).rows[0].id;}
async function seek(db,pub=true){return(await db.query("select seek_partner('tennis',null,null,$1) id",[pub])).rows[0].id;}

test('anon can browse facilities and availability, without owner identity or occupancy notes',async()=>{
 const db=await setup();try{
  await claim(db);await db.exec('reset role');
  await db.query("insert into turf_occupancy(field_id,starts_at,note,created_by) values($1,$2,'PRIVATE NOTE',$3)",[id(20),await time(db),id(1)]);
  await actor(db,null,'anon');
  assert.equal((await db.query('select name from courts')).rows.length,2);
  assert.equal((await db.query('select name from turf_fields')).rows.length,2);
  const timeline=(await db.query('select * from court_timeline($1)',[id(10)])).rows;
  assert(timeline.length>0);assert(timeline.every(s=>s.owner_id===null&&s.owner_name===null&&s.mine===false));
  assert((await db.query('select * from turf_occupancy_grid($1,7)',[id(20)])).rows.every(s=>s.note===null&&!s.requested_by_me));
  const open=(await db.query('select * from open_slots(null)')).rows;
  assert.equal(open.length,1);assert.equal(open[0].owner_id,null);assert.equal(open[0].owner_name,'Oyuncu');
  for(const table of ['profiles','court_slots','court_slot_players','turf_slot_requests','turf_occupancy','partner_requests','partner_request_pings','sport_interests']) {
   await assert.rejects(db.exec('select * from '+table),/permission denied/);
  }
 }finally{await db.close();}
});

test('anon execute denied and PUBLIC cannot grant writes or internal verification helpers',async()=>{
 const db=await setup();try{
  await actor(db,null,'anon');
  for(const sql of ["select claim_slot(null,null,0,0)","select join_court_waitlist(null,null)","select request_turf_slot(null,null)","select send_partner_ping(null)","select seek_partner('tennis')","select check_in_slot(null,41,29)","select _venue_verification_tier(null)","select _require_venue_verification()"]){await assert.rejects(db.exec(sql),/permission denied/);}
  await db.exec('reset role');await db.exec('create role arbitrary;grant usage on schema public to arbitrary;set role arbitrary');
  await assert.rejects(db.exec('select send_partner_ping(null)'),/permission denied/);
 }finally{await db.close();}
});

test('unverified/location/forged admin cannot write; phone/id require trusted source',async()=>{
 const db=await setup();try{
  await actor(db,2);
  assert.equal((await db.query('select my_venue_verification_tier() t')).rows[0].t,'none');
  for(const sql of ["select claim_slot(null,null,0,0)","select join_court_waitlist(null,null)","select request_turf_slot(null,null)","select send_partner_ping(null)","select seek_partner('tennis')","select check_in_slot(null,41,29)","select request_join(null)"]){await assert.rejects(db.exec(sql),/telefon veya kimlik/);}
  await assert.rejects(db.query("update profiles set verification_tier='phone' where id=$1",[id(2)]),/yalnız sunucuda/);
  await db.exec('reset role');await db.query("update profiles set is_platform_admin=true where id=$1",[id(2)]);
  await actor(db,2);await assert.rejects(claim(db),/telefon veya kimlik/);
  // Even a stale legacy profile value does not open the gate.
  await db.exec('reset role;alter table profiles disable trigger guard_venue_verification_tier');
  await db.query("update profiles set verification_tier='id' where id=$1",[id(2)]);
  await db.exec('alter table profiles enable trigger guard_venue_verification_tier');await actor(db,2);
  await assert.rejects(claim(db),/telefon veya kimlik/);
 }finally{await db.close();}
});

test('verified phone can claim/request turf/check-in; confirmed identity needs no phone',async()=>{
 const db=await setup();try{
  const slot=await claim(db);assert.equal(await claim(db),slot);
  await db.exec('reset role');await db.query("update court_slots set starts_at=date_trunc('hour',now()) where id=$1",[slot]);await actor(db,1);
  await db.query('select check_in_slot($1,41,29)',[slot]);
  await actor(db,3);
  await db.query('select request_turf_slot($1,$2)',[id(20),await time(db)]);
  await db.query('select request_turf_slot($1,$2)',[id(20),await time(db)]);
  await db.exec('reset role');assert.equal((await db.query('select count(*)::int n from turf_slot_requests')).rows[0].n,1);
  assert.equal((await db.query('select count(*)::int n from direct_messages')).rows[0].n,1);
  assert.equal((await db.query("select count(*)::int n from notifications where kind='message'")).rows[0].n,1);
  await actor(db,5);assert.equal((await db.query('select my_venue_verification_tier() t')).rows[0].t,'id');
  await db.query('select claim_slot($1,$2,0,0)',[id(11),await time(db)]);
 }finally{await db.close();}
});

test('waitlist FIFO preserved and verification removal revokes offer acceptance',async()=>{
 const db=await setup();try{
  const slot=await claim(db);await actor(db,3);
  const wait=(await db.query('select join_court_waitlist($1,$2) id',[id(10),await time(db)])).rows[0].id;
  await actor(db,1);await db.query('select cancel_slot($1)',[slot]);await db.exec('reset role');
  await db.query('update auth.users set phone_confirmed_at=null where id=$1',[id(3)]);
  await actor(db,3);await assert.rejects(db.query('select accept_court_waitlist($1,0,0)',[wait]),/telefon veya kimlik/);
  await db.exec('reset role');await db.query('update auth.users set phone_confirmed_at=now() where id=$1',[id(3)]);
  await actor(db,3);assert((await db.query('select accept_court_waitlist($1,0,0) id',[wait])).rows[0].id);
 }finally{await db.close();}
});

test('public opt-in only; safe metadata; ping creates one existing match and notification',async()=>{
 const db=await setup();try{
  const request=await seek(db);await actor(db,null,'anon');
  const rows=(await db.query('select * from public_partner_requests()')).rows;
  assert.equal(rows.length,1);assert.equal(rows[0].request_id,request);
  assert.deepEqual(Object.keys(rows[0]),['request_id','sport_code','sport_name','city_name','created_at','expires_at']);
  await actor(db,2);await assert.rejects(db.query('select send_partner_ping($1)',[request]),/telefon veya kimlik/);
  await actor(db,3);await db.query('select send_partner_ping($1)',[request]);
  await actor(db,4);await assert.rejects(db.query('select send_partner_ping($1)',[request]),/kullanılamıyor/);
  await db.exec('reset role');assert.equal((await db.query('select count(*)::int n from partner_request_pings where request_id=$1 and status=\'accepted\'',[request])).rows[0].n,1);
  assert.equal((await db.query("select count(*)::int n from notifications where kind='partner_request_accepted'")).rows[0].n,1);
  await actor(db,null,'anon');assert.equal((await db.query('select * from public_partner_requests()')).rows.length,0);
 }finally{await db.close();}
});

test('private/default/expired/blocked/banned requests cannot be pinged or revealed',async()=>{
 const db=await setup();try{
  const request=await seek(db,false);await actor(db,3);
  await assert.rejects(db.query('select send_partner_ping($1)',[request]),/kullanılamıyor/);
  assert.equal((await db.query('select * from public_partner_requests()')).rows.length,0);
  await db.exec('reset role');await db.query('update partner_requests set is_public=true where id=$1',[request]);
  await db.query('insert into blocks values($1,$2)',[id(1),id(3)]);await actor(db,3);
  assert.equal((await db.query('select * from public_partner_requests()')).rows.length,0);
  await assert.rejects(db.query('select send_partner_ping($1)',[request]),/kullanılamıyor/);
  await db.exec('reset role');await db.query("update partner_requests set expires_at=now()-interval '1 second' where id=$1",[request]);
  await actor(db,4);await assert.rejects(db.query('select send_partner_ping($1)',[request]),/kullanılamıyor/);
 }finally{await db.close();}
});

test('repeat migration keeps defaults, one signature, ACLs; anonymous auth user is not a verified account',async()=>{
 const db=await setup();try{
  await db.exec(`reset role;begin;${gate}commit;`);
  assert.equal((await db.query("select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and proname='seek_partner'")).rows[0].n,1);
  assert.equal((await db.query("select is_public from partner_requests where id=$1",[id(100)])).rows[0].is_public,false);
  await db.query('update auth.users set is_anonymous=true where id=$1',[id(1)]);
  await actor(db,1);await assert.rejects(claim(db),/telefon veya kimlik/);
 }finally{await db.close();}
});


test('unconfirmed/blank phones never open gate; identity revocation is live; direct writes denied',async()=>{
 const db=await setup();try{
  await db.exec('reset role');await db.query("update auth.users set phone='+905320000002',phone_confirmed_at=null where id=$1",[id(2)]);
  await actor(db,2);await assert.rejects(claim(db),/telefon veya kimlik/);
  await db.exec('reset role');await db.query("update auth.users set phone='',phone_confirmed_at=now() where id=$1",[id(2)]);
  await actor(db,2);await assert.rejects(claim(db),/telefon veya kimlik/);
  await db.exec('reset role');await db.query("update profile_credentials set status='rejected' where profile_id=$1",[id(5)]);
  await actor(db,5);await assert.rejects(claim(db),/telefon veya kimlik/);
  await actor(db,2);await assert.rejects(db.query("insert into court_slots(court_id,starts_at,owner_id) values($1,$2,$3)",[id(10),await time(db),id(2)]),/permission denied/);
  await db.exec('reset role;grant insert,update,delete on sport_interests to authenticated;grant insert on turf_slot_requests to authenticated');await actor(db,2);
  await assert.rejects(db.query("insert into sport_interests(profile_id,sport_code) values($1,'tennis')",[id(2)]),/telefon veya kimlik/);
  await assert.rejects(db.query("insert into turf_slot_requests(field_id,starts_at,requester_id) values($1,$2,$3)",[id(20),await time(db),id(2)]),/telefon veya kimlik|row-level security/);
 }finally{await db.close();}
});

test('public request ids cannot cancel someone else or accept with a NULL decision',async()=>{
 const db=await setup();try{
  const request=await seek(db);await actor(db,2);
  await assert.rejects(db.query('select cancel_partner_request($1)',[request]),/erişilemiyor/);
  await assert.rejects(db.query('select respond_partner_ping($1,null)',[request]),/kabul veya ret/);
  await actor(db,1);await db.query('select cancel_partner_request($1)',[request]);
  await actor(db,null,'anon');assert.equal((await db.query('select * from public_partner_requests()')).rows.length,0);
 }finally{await db.close();}
});


test('turf request retains DM path, rejects absent/blocked managers atomically',async()=>{
 const db=await setup();try{
  await actor(db,3);await assert.rejects(db.query('select request_turf_slot($1,$2)',[id(21),await time(db)]),/mesaj gönderilemiyor/);
  await db.exec('reset role');await db.query('insert into blocks values($1,$2)',[id(1),id(3)]);await actor(db,3);
  await assert.rejects(db.query('select request_turf_slot($1,$2)',[id(20),await time(db)]),/mesaj gönderilemiyor/);
  await db.exec('reset role');assert.equal((await db.query('select count(*)::int n from turf_slot_requests')).rows[0].n,0);
  assert.equal((await db.query('select count(*)::int n from direct_messages')).rows[0].n,0);
 }finally{await db.close();}
});
