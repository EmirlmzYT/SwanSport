import {PGlite} from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const id=n=>`40000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const source=async name=>readFile(new URL(`../supabase/migrations/${name}.sql`,import.meta.url),'utf8');
const migration=await source('0133_today_training_rsvp');
const foundation=await source('0001_foundation');
const extended=await source('0003_extended');
const rsvp=await source('0033_event_rsvp');
const faq=await source('0069_faq_and_support');
function table(src,name){const start=src.indexOf(`create table if not exists public.${name} (`);assert.ok(start>=0);return src.slice(start,src.indexOf('\n);',start)+3);}
async function actor(db,n){await db.query("select set_config('test.actor',$1,false)",[n==null?'':id(n)]);}
async function load(db){return (await db.query('select my_today_training_rsvps() v')).rows[0].v;}
async function respond(db,event=40,athlete=20,status='attending',expected=null){return db.query('select respond_today_training($1,$2,$3,$4)',[id(event),id(athlete),status,expected]);}
async function setup(){const db=new PGlite();try{
 await db.exec(`create role anon;create role authenticated;create schema auth;
 create table auth.users(id uuid primary key,raw_user_meta_data jsonb);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 create function my_feature_flags() returns table(key text) language sql stable as $$
 select 'sport_training_sessions' where coalesce(current_setting('test.training',true),'on')<>'off'
 union all select 'parent_hub' where coalesce(current_setting('test.parent',true),'on')<>'off' $$;`);
 await db.exec(foundation.replace('create extension if not exists "pgcrypto";',''));
 await db.exec("create type event_kind as enum('training','match','meeting','other')");
 await db.exec(table(extended,'events'));
 await db.exec(rsvp);
 await db.exec(table(faq,'faq_entries'));
 await db.exec('alter table faq_entries add column feature text');
 await db.exec(migration);await db.exec(migration);
 await db.exec(`insert into auth.users(id) values('${id(1)}'),('${id(2)}'),('${id(3)}'),('${id(4)}');
 insert into clubs(id,name) values('${id(10)}','A'),('${id(11)}','B');
 insert into teams(id,club_id,name) values('${id(30)}','${id(10)}','U16'),('${id(31)}','${id(11)}','B takım');
 insert into athletes(id,club_id,profile_id,first_name,last_name) values
 ('${id(20)}','${id(10)}','${id(1)}','Ada','Sporcu'),
 ('${id(21)}','${id(10)}',null,'Ece','Çocuk'),
 ('${id(22)}','${id(11)}','${id(3)}','Başka','Sporcu');
 insert into guardians(profile_id,athlete_id,display_name) values('${id(2)}','${id(21)}','Veli A'),('${id(4)}','${id(21)}','Veli B');
 insert into team_memberships(athlete_id,team_id) values('${id(20)}','${id(30)}');
 insert into events(id,club_id,team_id,title,kind,starts_at,ends_at) values
 ('${id(40)}','${id(10)}',null,'Bugün','training',now()+interval '10 minutes',now()+interval '1 hour'),
 ('${id(41)}','${id(10)}','${id(30)}','Takım','training',now()+interval '15 minutes',null),
 ('${id(42)}','${id(10)}',null,'Maç','match',now()+interval '20 minutes',null),
 ('${id(43)}','${id(11)}',null,'Diğer kulüp','training',now()+interval '10 minutes',null),
 ('${id(44)}','${id(10)}',null,'Yarın','training',now()+interval '1 day',null),
 ('${id(45)}','${id(10)}',null,'Biten','training',now()-interval '2 hours',now()-interval '1 hour');`);
 // Deterministic fixture: set upcoming timestamps inside today's Istanbul day.
 const day=(await db.query("select ((now() at time zone 'Europe/Istanbul')::date+time '23:59:59') at time zone 'Europe/Istanbul' finish")).rows[0].finish;
 await db.query('update events set starts_at=$1,ends_at=null where id=any($2::uuid[])',[day,[40,41,42,43].map(id)]);
 await actor(db,1); return db;
}catch(e){await db.close();throw e;}}

test('real schema: self only, training only, today only, team scope and no phantom attendance',async()=>{const db=await setup();try{
 await db.exec('set role authenticated');let data=await load(db);
 assert.deepEqual(data.items.map(v=>v.event_id).sort(),[id(40),id(41)]);
 assert.ok(data.items.every(v=>v.is_self&&v.child_name===null));
 await respond(db);data=await load(db);assert.equal(data.items.find(v=>v.event_id===id(40)).response,'attending');
 await assert.rejects(()=>db.query('select * from public.event_rsvps'),/permission denied/);
}finally{await db.close();}});

test('guardian profileless child, duplicate-safe answered cards, change and shared CAS',async()=>{const db=await setup();try{
 await actor(db,2);let data=await load(db);assert.equal(data.items.length,1);assert.equal(data.items[0].athlete_id,id(21));
 assert.equal(data.items[0].child_name,'Ece Çocuk');assert.equal(data.items[0].is_self,false);
 await respond(db,40,21);data=await load(db);assert.equal(data.items[0].response,'attending');
 const expected=data.items[0].response_at;
 await actor(db,4);await assert.rejects(()=>respond(db,40,21,'unavailable',null),/Yanıt değişmiş/);
 await respond(db,40,21,'unavailable',expected);assert.equal((await load(db)).items[0].response,'unavailable');
 await respond(db,40,21,'unavailable',null); // same choice is idempotent
}finally{await db.close();}});

test('unrelated IDs, null/invalid responses, other teams and other day are denied',async()=>{const db=await setup();try{
 for(const args of [[40,21],[43,20],[42,20],[44,20],[40,20,null],[40,20,'uncertain']])
   await assert.rejects(()=>respond(db,...args));
 await actor(db,2);await assert.rejects(()=>respond(db,41,21));
 await actor(db,3);assert.equal((await load(db)).items.length,1);
 await actor(db,4);await db.exec(`delete from guardians where profile_id='${id(4)}'`);
 assert.equal((await load(db)).items.length,0);await assert.rejects(()=>respond(db,40,21));
}finally{await db.close();}});

test('start deadline, inactive athlete and both feature gates are enforced server-side',async()=>{const db=await setup();try{
 await db.exec(`update events set starts_at=clock_timestamp()-interval '1 second' where id='${id(40)}'`);
 await assert.rejects(()=>respond(db),/başlamış/);
 await db.exec("select set_config('test.training','off',false)");assert.equal((await load(db)).items.length,0);
 await assert.rejects(()=>respond(db));await db.exec("select set_config('test.training','on',false)");
 await actor(db,2);await db.exec("select set_config('test.parent','off',false)");assert.equal((await load(db)).items.length,0);
 await assert.rejects(()=>respond(db,40,21));await actor(db,1);
 await db.exec(`update athletes set status='inactive' where id='${id(20)}'`);
 assert.equal((await load(db)).items.length,0);
}finally{await db.close();}});

test('anonymous privileges, direct RSVP writes and FAQ idempotence',async()=>{const db=await setup();try{
 assert.equal((await db.query('select count(*) n from faq_entries')).rows[0].n,1);
 await db.exec('set role anon');await assert.rejects(()=>load(db),/permission denied/);
 await assert.rejects(()=>respond(db),/permission denied/);
 await db.exec('reset role');await actor(db,null);await assert.rejects(()=>load(db),/Oturum/);
 await db.exec('set role authenticated');await assert.rejects(()=>db.query('select * from event_rsvps'),/permission denied/);
}finally{await db.close();}});
