import {setup as foundation,apply,actor,call,id,admin,officer,coach,guardian,child,club,other} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const migration=await readFile(new URL('../supabase/migrations/0138_transfer_requests.sql',import.meta.url),'utf8');
async function setup(){const f=await foundation();const db=f.db;
 await db.exec('reset role');await actor(db,admin);
 const refSql=await readFile(new URL('../supabase/migrations/0030_expenses.sql',import.meta.url),'utf8');
 const refStart=refSql.indexOf('create or replace function public.athlete_ref(');
 await db.exec(refSql.slice(refStart,refSql.indexOf('$$;',refStart)+3));
 await db.exec(`create table feature_flags(key text primary key,audience text,label text,description text);
 create table faq_entries(question text,answer text,category text,audience text,sort_order int,route text,feature text,active boolean default true);
 create function my_feature_flags() returns table(key text) language sql as $$select 'transfer_requests' where coalesce(current_setting('test.feature',true),'on')='on'$$;
 insert into auth.users(id) values('${id(99)}');
 insert into club_memberships(club_id,profile_id,role) values('${other}','${id(99)}','club_admin');`);
 await apply(db,migration);await apply(db,migration);await actor(db,coach);await db.exec('set role authenticated');return db;}
const request=(db,key=id(1901),reason='Kulüp değişikliği')=>call(db,'submit_transfer_request',[key,child,'tenis',other,reason]);
const act=(db,action,key=id(1901))=>call(db,'act_transfer_request',[key,action]);
test('0138 source, target, guardian and scoped registrar complete once through existing official engine',async()=>{const db=await setup();try{
 const opts=await call(db,'transfer_request_options');assert.ok(opts.athletes.some(a=>a.id===child));
 await request(db);await request(db);await assert.rejects(()=>request(db,id(1901),'Başka gerekçe'),/kimliği/);
 await assert.rejects(()=>act(db,'finalize'),/tescil/);
 await actor(db,officer);await assert.rejects(()=>act(db,'finalize'),/onayı tamamlanmalı/);
 await actor(db,id(99));await act(db,'accept');await act(db,'accept');
 await actor(db,guardian);await act(db,'consent');await act(db,'consent');
 const family=await call(db,'my_transfer_requests');assert.equal(family[0].family_name,'Private Child');
 await actor(db,officer);await act(db,'finalize');await act(db,'finalize');
 const b=await call(db,'my_transfer_requests');assert.equal(b[0].status,'completed');assert.ok(b[0].transfer_id);
 assert.doesNotMatch(JSON.stringify(b),/Private|Child|birth_date|national_id|license_number|profile_id/);
 await db.exec('reset role');assert.equal((await db.query('select count(*) n from athlete_transfers where athlete_id=$1',[child])).rows[0].n,1);
 assert.equal((await db.query('select club_id from athlete_sport_registrations where athlete_id=$1',[child])).rows[0].club_id,other);
 }finally{await db.close();}});

test('0138 account deletion does not become blocked by private requests or events',async()=>{const db=await setup();try{
 await request(db);await actor(db,id(99));await act(db,'accept');
 await db.exec('reset role');await actor(db,admin);await db.query('delete from auth.users where id=$1',[id(99)]);
 assert.equal((await db.query('select accepted_by from transfer_requests')).rows[0].accepted_by,null);
 await db.query('delete from auth.users where id=$1',[coach]);
 assert.equal((await db.query('select created_by from transfer_requests')).rows[0].created_by,null);
 }finally{await db.close();}});
test('0138 outsiders/accountants/admin without appointment, direct writes and feature off are closed',async()=>{const db=await setup();try{
 await request(db);await actor(db,admin);assert.deepEqual(await call(db,'my_transfer_requests'),[]);await assert.rejects(()=>act(db,'finalize'),/erişilemiyor/);
 await actor(db,id(99));await assert.rejects(()=>request(db,id(1902)),/kaynak/);
 await assert.rejects(()=>db.query('select * from transfer_requests'),/permission denied/);
 await actor(db,coach);await db.exec("select set_config('test.feature','off',false)");await assert.rejects(()=>call(db,'my_transfer_requests'),/açık değil/);
 await db.exec('set role anon');await assert.rejects(()=>act(db,'consent'),/permission denied/);
 }finally{await db.close();}});
test('0138 guardian removal invalidates consent; cancellation and rejection are terminal and retry-safe',async()=>{const db=await setup();try{
 await request(db);await actor(db,id(99));await act(db,'accept');await actor(db,guardian);await act(db,'consent');
 await db.exec('reset role');await db.query('delete from guardians where athlete_id=$1',[child]);
 await actor(db,officer);await db.exec('set role authenticated');await assert.rejects(()=>act(db,'finalize'),/onayı tamamlanmalı/);
 await actor(db,coach);await act(db,'cancel');await act(db,'cancel');await assert.rejects(()=>act(db,'accept'),/kapanmış/);
 await request(db,id(1902));await actor(db,id(99));await act(db,'reject',id(1902));await act(db,'reject',id(1902));
 await assert.rejects(()=>act(db,'accept',id(1902)),/kapanmış/);
 }finally{await db.close();}});
test('0138 adult consent is self only, request alone leaves license and roster untouched',async()=>{const db=await setup();try{
 await db.exec('reset role');await actor(db,officer);
 await db.query('update athletes set birth_date=current_date-interval \'20 years\',profile_id=$1 where id=$2',[guardian,child]);
 const before=(await db.query('select count(*) n from team_memberships where athlete_id=$1',[child])).rows[0].n;
 await actor(db,coach);await db.exec('set role authenticated');await request(db);
 await assert.rejects(()=>act(db,'consent'),/sporcu/);await actor(db,guardian);await act(db,'consent');
 await db.exec('reset role');assert.equal((await db.query('select club_id from athlete_sport_registrations where athlete_id=$1',[child])).rows[0].club_id,club);
 assert.equal((await db.query('select count(*) n from team_memberships where athlete_id=$1',[child])).rows[0].n,before);
 }finally{await db.close();}});

test('0138 failed request audit rolls back official transfer, license and terminal status together',async()=>{const db=await setup();try{
 await request(db);await actor(db,id(99));await act(db,'accept');await actor(db,guardian);await act(db,'consent');
 await db.exec('reset role');await db.exec(`create function reject_transfer_audit() returns trigger language plpgsql as $$begin if new.action='completed' then raise exception 'audit unavailable';end if;return new;end$$;
 create trigger reject_transfer_audit before insert on transfer_request_events for each row execute function reject_transfer_audit()`);
 await actor(db,officer);await db.exec('set role authenticated');await assert.rejects(()=>act(db,'finalize'),/audit unavailable/);
 await db.exec('reset role');assert.equal((await db.query('select count(*) n from athlete_transfers where athlete_id=$1',[child])).rows[0].n,0);
 assert.equal((await db.query('select club_id from athlete_sport_registrations where athlete_id=$1',[child])).rows[0].club_id,club);
 assert.equal((await db.query('select status from transfer_requests')).rows[0].status,'pending');
 }finally{await db.close();}});
