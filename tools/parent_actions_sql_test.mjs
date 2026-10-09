import {PGlite} from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const sql=await readFile(new URL('../supabase/migrations/0090_parent_action_center.sql',import.meta.url),'utf8');
const fixture=`
create role anon; create role authenticated; create schema auth;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
create function my_feature_flags() returns table(key text) language sql stable as $$ select 'parent_hub'::text where coalesce(current_setting('test.flag',true),'on')<>'off' $$;
create table profiles(id uuid primary key,role text);
create table clubs(id uuid primary key,name text);
create table athletes(id uuid primary key,club_id uuid references clubs,profile_id uuid references profiles,first_name text,last_name text,status text default 'active');
create table guardians(id uuid primary key,athlete_id uuid references athletes,profile_id uuid references profiles);
create table events(id uuid primary key,club_id uuid references clubs,team_id uuid,title text,place text,starts_at timestamptz,ends_at timestamptz);
create table team_memberships(id uuid primary key,athlete_id uuid,team_id uuid);
create table documents(id uuid primary key,club_id uuid,name text,doc_type text,storage_path text,owner_type text,owner_id uuid,issued_on date,expires_on date,verified boolean default false,uploaded_by uuid,created_at timestamptz default now());
create table support_tickets(id uuid primary key,profile_id uuid,subject text,body text,status text,created_at timestamptz default now());
create table event_rsvps(event_id uuid,athlete_id uuid,status text check(status in ('attending','uncertain','unavailable')),note text,updated_at timestamptz default now(),primary key(event_id,athlete_id));
alter table event_rsvps enable row level security; revoke all on event_rsvps from public,anon,authenticated;
create function can_view_document(t text,o uuid,c uuid) returns boolean language sql stable as $$ select exists(select 1 from guardians where athlete_id=o and profile_id=auth.uid()) $$;
create schema storage;
create table storage.objects(bucket_id text,name text);
alter table storage.objects enable row level security;
grant usage on schema storage to authenticated,anon;
grant select on storage.objects to authenticated;
create table feature_flags(key text primary key,audience text,label text,description text);
create table faq_entries(question text,answer text,category text,audience text,sort_order int,route text,feature text,active boolean default true);
grant usage on schema public,auth to authenticated,anon;
insert into profiles values('${id(1)}','coach'),('${id(2)}','parent'),('${id(3)}','accountant');
insert into clubs values('${id(10)}','A'),('${id(11)}','B');
insert into athletes values('${id(20)}','${id(10)}',null,'Ada','A','active'),('${id(21)}','${id(11)}',null,'Ece','B','active'),('${id(22)}','${id(10)}',null,'Başka','Çocuk','active');
insert into guardians values('${id(30)}','${id(20)}','${id(1)}'),('${id(31)}','${id(21)}','${id(1)}'),('${id(32)}','${id(22)}','${id(2)}'),('${id(33)}','${id(20)}','${id(1)}'),('${id(34)}','${id(20)}','${id(2)}');
insert into events values('${id(40)}','${id(10)}',null,'Kulüp A',null,now()+interval '1 day',null),('${id(41)}','${id(11)}',null,'Kulüp B',null,now()+interval '2 days',null),('${id(42)}','${id(10)}','${id(60)}','Diğer takım',null,now()+interval '1 day',null),('${id(43)}','${id(10)}',null,'Geçmiş',null,now()-interval '1 day',null),('${id(44)}','${id(10)}',null,'Uzak tarih',null,now()+interval '61 days',null);
insert into documents(id,club_id,name,doc_type,owner_type,owner_id,expires_on) values('${id(70)}','${id(10)}','Lisans','lisans','athlete','${id(20)}',current_date-1),('${id(71)}','${id(11)}','Sağlık','saglik','athlete','${id(21)}',current_date+30),('${id(72)}','${id(10)}','Başka','lisans','athlete','${id(22)}',current_date),('${id(73)}','${id(10)}','Geçerli','saglik','athlete','${id(20)}',current_date+31);
insert into support_tickets values('${id(80)}','${id(1)}','Kendi yanıtım','Metin','awaiting_user_response'),('${id(81)}','${id(2)}','Başka talep','Özel','awaiting_user_response'),('${id(82)}','${id(1)}','Kapalı',null,'closed');
`;
async function setup(){const db=new PGlite();try {await db.exec(fixture);await db.exec(`begin;${sql}commit;`);await actor(db,id(1));return db;}catch(e){await db.close();throw e;}}
async function actor(db,who){await db.query("select set_config('test.actor',$1,false)",[who??'']);}
async function load(db){return (await db.query('select my_parent_actions() as result')).rows[0].result;}
async function respond(db,event=id(40),child=id(20),status='attending',expected=null){return db.query('select set_guardian_event_rsvp($1,$2,$3,$4)',[event,child,status,expected]);}
test('real linked children across clubs, profileless children and duplicate links are isolated',async()=>{const db=await setup();try{
 await db.exec('set role authenticated');const data=await load(db);assert.deepEqual(data.children.map(c=>c.id),[id(20),id(21)]);assert.equal(data.events.length,2);assert.deepEqual(data.documents.map(d=>d.id),[id(70),id(71)]);assert.equal(data.tickets.length,1);assert.equal(data.tickets[0].id,id(80));
 await actor(db,id(3));assert.deepEqual(await load(db),{children:[],events:[],documents:[],tickets:[]});
}finally{await db.close();}});
test('event team scope, past/horizon and answered responses disappear',async()=>{const db=await setup();try{
 await db.query('insert into team_memberships values($1,$2,$3)',[id(90),id(20),id(60)]);let data=await load(db);assert.equal(data.events.length,3);
 await respond(db);data=await load(db);assert.equal(data.events.some(e=>e.id===id(40)),false);
 await respond(db,id(41),id(21),'uncertain');data=await load(db);assert.equal(data.events.find(e=>e.id===id(41)).response,'uncertain');assert.ok(data.events.find(e=>e.id===id(41)).response_at);
}finally{await db.close();}});
test('invalid child, wrong club/team, elapsed event, inactive athlete, null status denied',async()=>{const db=await setup();try{
 for(const args of [[id(40),id(22)],[id(41),id(20)],[id(42),id(20)],[id(43),id(20)],[id(40),id(20),null]]) await assert.rejects(respond(db,...args));
 await db.query("update athletes set status='inactive' where id=$1",[id(20)]);await assert.rejects(respond(db),/kadrosunda/);assert.equal((await db.query('select count(*)::int n from event_rsvps')).rows[0].n,0);
}finally{await db.close();}});
test('optimistic check rejects stale second guardian, same response retry is idempotent',async()=>{const db=await setup();try{
 await respond(db,id(40),id(20),'uncertain');let old=(await load(db)).events.find(e=>e.id===id(40));await actor(db,id(2));await respond(db,id(40),id(20),'attending',old.response_at);
 await actor(db,id(1));await assert.rejects(respond(db,id(40),id(20),'unavailable',old.response_at),/Yanıt değişmiş/);const stamp=(await db.query('select updated_at::text from event_rsvps')).rows[0].updated_at;
 await respond(db,id(40),id(20),'attending',old.response_at);assert.equal((await db.query('select updated_at::text from event_rsvps')).rows[0].updated_at,stamp);
 await assert.rejects(respond(db,id(40),id(20),'uncertain',null),/Yanıt değişmiş/);
}finally{await db.close();}});
test('removed guardian immediately loses reading/writing, role alone gives no children',async()=>{const db=await setup();try{
 await db.query('delete from guardians where profile_id=$1',[id(1)]);assert.equal((await load(db)).children.length,0);assert.equal((await load(db)).tickets.length,0);await assert.rejects(respond(db),/yetkin yok/);
}finally{await db.close();}});
test('unknown and closed flag fail closed, anon/direct table denied; migration repeat safe',async()=>{const db=await setup();try{
 await db.exec(`begin;${sql}commit;`);assert.equal((await db.query("select count(*)::int n from faq_entries where route='/veli-izinleri'")).rows[0].n,1);
 await actor(db,null);await assert.rejects(load(db),/Oturum/);await assert.rejects(respond(db),/Oturum/);await actor(db,id(1));await db.query("select set_config('test.flag','off',false)");await assert.rejects(load(db),/açık değil/);await assert.rejects(respond(db),/açık değil/);
 await db.exec('set role anon');await assert.rejects(load(db),/permission denied/);await assert.rejects(respond(db),/permission denied/);await db.exec('reset role;set role authenticated');await assert.rejects(db.query('select * from event_rsvps'),/permission denied/);
}finally{await db.close();}});
test('verified valid replacement settles old warning; unverified/wrong type does not',async()=>{const db=await setup();try{
 await db.query("insert into documents(id,club_id,name,doc_type,owner_type,owner_id,expires_on,created_at) values($1,$2,'Yeni lisans','lisans','athlete',$3,current_date+365,now()+interval '1 second')",[id(74),id(10),id(20)]);
 assert.equal((await load(db)).documents.some(d=>d.id===id(70)),true);await db.query('update documents set verified=true where id=$1',[id(74)]);assert.equal((await load(db)).documents.some(d=>d.id===id(70)),false);
 await db.query("update documents set doc_type='saglik' where id=$1",[id(74)]);assert.equal((await load(db)).documents.some(d=>d.id===id(70)),true);
}finally{await db.close();}});

test('private athlete vault files read with current guardian rights; identity and forged associations stay private',async()=>{const db=await setup();try{
 const vault=`${id(1)}/belge_123.pdf`, identity=`${id(1)}/123_identity.pdf`;
 await db.query('update documents set storage_path=$1,uploaded_by=$2 where id=$3',[vault,id(1),id(70)]);
 await db.query("insert into storage.objects values('verification-docs',$1),('verification-docs',$2),('other-bucket',$1)",[vault,identity]);
 await actor(db,id(2));await db.exec('set role authenticated');assert.deepEqual((await db.query('select name from storage.objects')).rows,[{name:vault}]);
 await db.exec('reset role');await assert.rejects(db.query('update documents set storage_path=$1,uploaded_by=$2 where id=$3',[identity,id(1),id(72)]),/kendi kasana/);
 await assert.rejects(db.query('update documents set storage_path=$1,uploaded_by=$2 where id=$3',[vault,id(1),id(72)]),/kendi kasana/);
 await assert.rejects(db.query('update documents set club_id=$1 where id=$2',[id(11),id(70)]),/bu kulübün/);
 await db.query('delete from guardians where profile_id=$1 and athlete_id=$2',[id(2),id(20)]);await db.exec('set role authenticated');assert.equal((await db.query('select name from storage.objects')).rows.length,0);
 await db.exec('reset role');await actor(db,null);assert.equal((await db.query('select can_read_athlete_vault_file($1) allowed',[vault])).rows[0].allowed,false);
}finally{await db.close();}});
