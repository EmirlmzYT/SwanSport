import {PGlite} from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFile} from 'node:fs/promises';import {test} from 'node:test';import assert from 'node:assert/strict';
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const read=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
const [queue,duty,old,original,turf]=await Promise.all(['supabase/migrations/0092_court_waitlist.sql','supabase/migrations/0093_turf_duty_delegation.sql','supabase/migrations/0036_claim_idempotent.sql','supabase/migrations/0035_public_courts.sql','supabase/migrations/0038_turf_venues.sql'].map(read));
function fn(s,name){const i=s.indexOf('create or replace function public.'+name+'(');assert(i>=0,name);const match=s.slice(i).match(/as (\$[a-z]*\$)/i);const tag=match[1];const end=s.indexOf(tag+';',i+match.index+match[0].length);return s.slice(i,end+tag.length+1);}
const fixture=`
create role authenticated;create role anon;create schema auth;create schema cron;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
create table cron.job(jobname text primary key,command text);
create function cron.unschedule(n text) returns boolean language sql as $$with d as(delete from cron.job where jobname=n) select true$$;
create function cron.schedule(n text,s text,c text) returns bigint language plpgsql as $$begin insert into cron.job values(n,c) on conflict(jobname) do update set command=c;return 1;end;$$;
grant usage on schema public,auth to authenticated,anon;
alter default privileges in schema public grant select on tables to authenticated;
alter default privileges in schema public grant execute on functions to authenticated,anon;
create table profiles(id uuid primary key,full_name text,verification_tier text,is_platform_admin boolean default false);
create table clubs(id uuid primary key);create table club_memberships(club_id uuid,profile_id uuid,status text);
create table feature_flags(key text primary key,audience text,label text,description text);
create table feature_flag_testers(key text,profile_id uuid,club_id uuid);
create table faq_entries(question text,answer text,category text,audience text,sort_order int,route text,feature text,active boolean default true);
create table notifications(id uuid primary key default gen_random_uuid(),profile_id uuid,kind text,title text,body text,actor_id uuid,entity_type text,entity_id uuid);
create table courts(id uuid primary key,name text,opens_at time,closes_at time,active boolean,capacity int);
create table court_slots(id uuid primary key default gen_random_uuid(),court_id uuid references courts,starts_at timestamptz,owner_id uuid references profiles,status text default 'claimed',guest_count int default 0,needed int default 0,checked_in_at timestamptz,created_at timestamptz default now(),constraint court_slot_unique unique(court_id,starts_at),check(guest_count between 0 and 19 and needed between 0 and 19));
create table court_players(profile_id uuid primary key references profiles,banned_until timestamptz,no_shows int default 0);
create table court_slot_players(slot_id uuid references court_slots on delete cascade,profile_id uuid,status text,created_at timestamptz default now(),primary key(slot_id,profile_id));
create table turf_fields(id uuid primary key,name text,venue_name text,opens_at time,closes_at time,active boolean);
create table turf_field_managers(field_id uuid,profile_id uuid,status text,primary key(field_id,profile_id));
create table turf_occupancy(id uuid primary key default gen_random_uuid(),field_id uuid,starts_at timestamptz,note text,created_by uuid,created_at timestamptz default now(),unique(field_id,starts_at));
alter table turf_occupancy enable row level security;grant insert,update,delete on turf_occupancy to authenticated;
create policy turf_read on turf_occupancy for select to authenticated using(true);
insert into profiles(id,full_name,verification_tier) select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'User '||n,'location' from generate_series(1,8) n;
insert into courts values('${id(10)}','Kort A','00:00','24:00',true,4),('${id(11)}','Kort B','00:00','24:00',true,4);
insert into turf_fields values('${id(20)}','Saha A','Tesis','00:00','24:00',true),('${id(21)}','Saha B','Tesis','00:00','24:00',true);
insert into turf_field_managers values('${id(20)}','${id(1)}','active');
`;
async function actor(db,n){await db.query("select set_config('test.actor',$1,false)",[n==null?'':id(n)]);}
async function setup(){const db=new PGlite();try{await db.exec(fixture);await db.exec(fn(original,'verification_rank')+fn(old,'claim_slot')+fn(old,'extend_slot')+fn(original,'cancel_slot')+fn(turf,'is_turf_manager'));await db.exec(`begin;${queue}commit;begin;${duty}commit;`);await db.exec("update feature_flags set audience='everyone'");await actor(db,1);return db;}catch(e){await db.close();throw e;}}
async function time(db){return(await db.query("select date_trunc('hour',now())+interval '2 hours' t")).rows[0].t;}
async function claim(db,c=10){return(await db.query('select claim_slot($1,$2,0,0) id',[id(c),await time(db)])).rows[0].id;}
async function join(db){return(await db.query('select join_court_waitlist($1,$2) id',[id(10),await time(db)])).rows[0].id;}
async function invite(db,op=100,hours=4){return(await db.query('select create_turf_duty($1,$2,$3) d',[id(20),hours,id(op)])).rows[0].d;}
async function redeem(db,code){return(await db.query('select redeem_turf_duty($1) id',[code])).rows[0].id;}
async function edit(db,field=20){return db.query('insert into turf_occupancy(field_id,starts_at,note,created_by) values($1,$2,$3,$4)',[id(field),await time(db),'Note',id(8)]);}

test('FIFO offer, old client cannot jump, recycled cancellation preserves historical game and repeated acceptance',async()=>{const db=await setup();try{
 const slot=await claim(db);await actor(db,2);const a=await join(db);assert.equal(await join(db),a);await actor(db,3);const b=await join(db);
 await actor(db,1);await db.query('select cancel_slot($1)',[slot]);await db.query('select cancel_slot($1)',[slot]);
 const rows=(await db.query('select status from court_waitlist order by created_at,id')).rows;assert.deepEqual(rows.map(r=>r.status),['offered','waiting']);
 await actor(db,3);await assert.rejects(claim(db),/sıradaki/);await assert.rejects(db.query('select accept_court_waitlist($1,0,0)',[a]),/erişilemiyor/);
 await actor(db,2);const accepted=(await db.query('select accept_court_waitlist($1,0,0) id',[a])).rows[0].id;assert.notEqual(accepted,slot);assert.equal((await db.query('select accept_court_waitlist($1,0,0) id',[a])).rows[0].id,accepted);
 assert.equal((await db.query('select count(*)::int n from court_slots')).rows[0].n,2);assert.equal((await db.query("select count(*)::int n from notifications where kind='court_waitlist'")).rows[0].n,1);
 await db.exec('reset role');await assert.rejects(db.query("update court_slots set status='active' where id=$1",[slot]),/geçerli/);
}finally{await db.close();}});
test('offer timeout moves FIFO; cancellation moves immediately; availability never fabricates a reservation',async()=>{const db=await setup();try{
 const slot=await claim(db);await actor(db,2);const a=await join(db);await actor(db,3);const b=await join(db);await actor(db,1);await db.query('select cancel_slot($1)',[slot]);
 await db.query("update court_waitlist set offered_until=now()-interval '1 second' where id=$1",[a]);await db.exec('select court_waitlist_maintenance()');assert.equal((await db.query('select status from court_waitlist where id=$1',[b])).rows[0].status,'offered');
 await actor(db,2);await assert.rejects(db.query('select accept_court_waitlist($1,0,0)',[a]),/dolmuş/);await actor(db,3);await db.query('select leave_court_waitlist($1)',[b]);await actor(db,4);await claim(db);assert.equal((await db.query('select status from court_waitlist where id=$1',[b])).rows[0].status,'cancelled');
}finally{await db.close();}});
test('verification, range, active game, bans, flag rollback, RLS and internal helper restrictions',async()=>{const db=await setup();try{
 await claim(db);await actor(db,2);await db.query("update profiles set verification_tier='none' where id=$1",[id(2)]);await assert.rejects(join(db),/konum/);await db.query("update profiles set verification_tier='location' where id=$1",[id(2)]);
 await assert.rejects(db.query("select join_court_waitlist($1,now()+interval '10 hours')",[id(10)]),/gelecek/);const a=await join(db);await claim(db,11);await db.exec('select court_waitlist_maintenance()');assert.equal((await db.query('select status from court_waitlist where id=$1',[a])).rows[0].status,'expired');
 await actor(db,3);await db.query('insert into court_players(profile_id,banned_until) values($1,now()+interval \'1 day\')',[id(3)]);await assert.rejects(join(db),/aktif sıra/);await actor(db,4);await join(db);
 await db.exec("update feature_flags set audience='off' where key='court_waitlist';select court_waitlist_maintenance();set role authenticated");await assert.rejects(join(db),/erişim/);await assert.rejects(db.query('select _court_waiter_eligible($1)',[id(4)]),/permission/);await assert.rejects(db.query('select _swan_feature_for_profile($1,$2)',['court_waitlist',id(4)]),/permission/);await assert.rejects(db.exec("update court_waitlist set status='offered'"),/permission/);
 await actor(db,2);assert.equal((await db.query('select profile_id from court_waitlist')).rows.every(r=>r.profile_id===id(2)),true);
 await db.exec('reset role');await actor(db,null);await assert.rejects(join(db),/erişim/);await assert.rejects(db.query('select cancel_slot($1)',[id(100)]),/Giriş/);await db.exec('set role anon');await assert.rejects(db.exec('select my_court_waitlist()'),/permission/);
}finally{await db.close();}});
test('legacy claim double tap remains idempotent and one active rule cannot be bypassed',async()=>{const db=await setup();try{const a=await claim(db);assert.equal(await claim(db),a);await assert.rejects(claim(db,11),/aktif/);}finally{await db.close();}});
test('duty invitation exact retries, single recipient, restricted real RLS write, attribution and audit',async()=>{const db=await setup();try{
 const inv=await invite(db);assert.deepEqual(await invite(db),inv);await assert.rejects(invite(db,100,12),/farklı veri/);await actor(db,2);await assert.rejects(edit(db),/görevin/);const d=await redeem(db,inv.code);assert.equal(await redeem(db,inv.code),d);await actor(db,3);await assert.rejects(redeem(db,inv.code),/geçersiz/);
 await actor(db,2);await db.exec('set role authenticated');await edit(db);assert.equal((await db.query('select created_by from turf_occupancy')).rows[0].created_by,id(2));assert.equal((await db.query('select count(*)::int n from turf_occupancy_audit')).rows[0].n,1);
 await assert.rejects(edit(db,21),/row-level security|görevin/);await assert.rejects(invite(db,101),/mevcut yöneticisine/);assert.equal((await db.query('select is_turf_manager($1) b',[id(20)])).rows[0].b,false);
 await assert.rejects(db.exec('update turf_duty_delegations set valid_until=now()+interval \'1 year\''),/permission/);await assert.rejects(db.exec('delete from turf_occupancy_audit'),/permission/);
}finally{await db.close();}});
test('revocation, elapsed lifetime, issuer removal and flag rollback immediately remove duty authority',async()=>{for(const scenario of ['revoke','expire','manager','flag']){const db=await setup();try{
 const inv=await invite(db);await actor(db,2);const d=await redeem(db,inv.code);await db.exec('reset role');
 if(scenario==='revoke'){await actor(db,1);await db.query('select revoke_turf_duty($1)',[d]);await db.query('select revoke_turf_duty($1)',[d]);}
 if(scenario==='expire')await db.query("update turf_duty_delegations set created_at=now()-interval '2 days',valid_until=now()-interval '1 day' where id=$1",[d]);
 if(scenario==='manager')await db.exec("update turf_field_managers set status='revoked'");
 if(scenario==='flag')await db.exec("update feature_flags set audience='off' where key='turf_delegation'");
 await actor(db,2);await db.exec('set role authenticated');assert.equal((await db.query('select can_edit_turf_occupancy($1) b',[id(20)])).rows[0].b,false);await assert.rejects(edit(db),/row-level security|görevin/);
}finally{await db.close();}}});
test('expired invitation cannot be accepted, recipient can give up, durations checked, anonymous denied',async()=>{const db=await setup();try{
 for(const h of [0,169,null])await assert.rejects(invite(db,100,h),/168/);const inv=await invite(db);await db.exec("update turf_duty_delegations set invite_until=now()-interval '1 second'");await actor(db,2);await assert.rejects(redeem(db,inv.code),/geçersiz/);
 await actor(db,1);const valid=await invite(db,101);await actor(db,2);const d=await redeem(db,valid.code);await db.query('select revoke_turf_duty($1)',[d]);assert.equal((await db.query('select can_edit_turf_occupancy($1) b',[id(20)])).rows[0].b,false);
 await db.exec('set role anon');await assert.rejects(redeem(db,valid.code),/permission/);
}finally{await db.close();}});
test('repeat migration, legacy notification routes, feature rollout helper and private mine-only lists',async()=>{const db=await setup();try{
 await db.exec(`begin;${queue}commit;begin;${duty}commit;`);assert.equal((await db.query('select count(*)::int n from faq_entries')).rows[0].n,2);assert.equal((await db.query("select push_route('turf_delegation','') r")).rows[0].r,'/saha-islemlerim');assert.equal((await db.query("select push_route('training_result','') r")).rows[0].r,'/antrenman-sonuc');
 await db.exec("update feature_flags set audience='testers';insert into feature_flag_testers values('court_waitlist',null,'"+id(30)+"');insert into club_memberships values('"+id(30)+"','"+id(2)+"','active')");await actor(db,2);assert.deepEqual((await db.query('select * from my_feature_flags()')).rows.map(r=>r.key),['court_waitlist']);await actor(db,3);assert.equal((await db.query('select * from my_feature_flags()')).rows.length,0);
 await db.exec("update profiles set is_platform_admin=true where id='"+id(3)+"'");assert.equal((await db.query('select * from my_feature_flags()')).rows.length,2);
 await db.exec("update feature_flags set audience='everyone'");await actor(db,1);await invite(db);await actor(db,2);await db.exec('set role authenticated');assert.deepEqual((await db.query('select my_turf_duties() d')).rows[0].d,{items:[],has_more:false});assert.equal((await db.query('select * from turf_duty_delegations')).rows.length,0);
}finally{await db.close();}});

test('duty pages return all own entries without leaking another persons codes',async()=>{const db=await setup();try{
 for(let n=200;n<245;n++)await db.query("insert into turf_duty_delegations(id,field_id,issuer_id,recipient_id,hours,created_at,valid_until,invite_until,accepted_at) values($1,$2,$3,$4,4,now()-make_interval(secs=>$5),now()+interval '4 hours',now()+interval '1 hour',now())",[id(n),id(20),id(1),id(2),n]);
 await actor(db,2);await db.exec('set role authenticated');const first=(await db.query('select my_turf_duties(0) d')).rows[0].d;const second=(await db.query('select my_turf_duties(40) d')).rows[0].d;assert.equal(first.items.length,40);assert.equal(first.has_more,true);assert.equal(second.items.length,5);assert.equal(second.has_more,false);assert.equal(new Set([...first.items,...second.items].map(d=>d.id)).size,45);assert.equal(JSON.stringify(first).includes('token'),false);await assert.rejects(db.exec('select my_turf_duties(-1)'),/sayfa/);
 await actor(db,3);assert.deepEqual((await db.query('select my_turf_duties(0) d')).rows[0].d,{items:[],has_more:false});
}finally{await db.close();}});

test('legacy extension preserves guest count and repeat result while early extension remains forbidden',async()=>{const db=await setup();try{
 const early=await claim(db);await db.query("update court_slots set status='active' where id=$1",[early]);await assert.rejects(db.query('select extend_slot($1)',[early]),/sonunda/);await db.query('select cancel_slot($1)',[early]);
 const old=(await db.query("insert into court_slots(court_id,starts_at,owner_id,guest_count,status) values($1,date_trunc('hour',now())-interval '1 hour',$2,2,'active') returning id",[id(10),id(1)])).rows[0].id;
 const next=(await db.query('select extend_slot($1) id',[old])).rows[0].id;
 assert.equal((await db.query('select extend_slot($1) id',[old])).rows[0].id,next);
 assert.equal((await db.query('select status from court_slots where id=$1',[old])).rows[0].status,'done');
 assert.equal((await db.query('select guest_count from court_slots where id=$1',[next])).rows[0].guest_count,2);
 await actor(db,2);await assert.rejects(db.query('select extend_slot($1)',[old]),/Yetkisiz/);
 await actor(db,null);await assert.rejects(db.query('select extend_slot($1)',[old]),/Giriş/);
}finally{await db.close();}});
