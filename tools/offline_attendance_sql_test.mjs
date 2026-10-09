import { PGlite } from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const club=id(1),other=id(2),actor=id(3),coach=id(4),accountant=id(5),event=id(6),team=id(7),a=id(8),b=id(9),foreign=id(10);
const migration=await readFile(new URL('../supabase/migrations/0088_offline_attendance_client.sql',import.meta.url),'utf8');
const audit=await readFile(new URL('../supabase/migrations/0032_attendance_audit.sql',import.meta.url),'utf8');
async function setup() {
  const db=new PGlite();
  await db.exec(`create role anon;create role authenticated;create schema auth;
    create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
    create table roles(actor uuid,club uuid,role text,active boolean default true);
    create function is_club_staff(c uuid) returns boolean language sql as $$ select exists(select 1 from roles where actor=auth.uid() and club=c and active and role in ('club_admin','coach','official')) $$;
    create table clubs(id uuid primary key,name text);
    create table profiles(id uuid primary key);
    create table events(id uuid primary key,club_id uuid,team_id uuid,title text,starts_at timestamptz);
    create table athletes(id uuid primary key,club_id uuid,status text,first_name text,last_name text,blocked boolean default false,profile_id uuid);
    create table team_memberships(athlete_id uuid,team_id uuid,season_id uuid);
    create table event_rsvps(event_id uuid,athlete_id uuid,status text);
    create function eligibility_gate(p uuid) returns table(blocked boolean,status text) language sql as $$ select a.blocked,case when a.blocked then 'restricted' else 'eligible' end from athletes a where a.id=p $$;
    create type attendance_status as enum ('present','absent','excused','late');
    create table attendance(id uuid primary key default gen_random_uuid(),club_id uuid not null,event_id uuid references events(id),athlete_id uuid references athletes(id),
      status attendance_status,marked_at timestamptz,actor_id uuid,version int default 1,unique(event_id,athlete_id));
    create table attendance_op_logs(id uuid primary key default gen_random_uuid(),actor_id uuid,op_id uuid,event_id uuid,club_id uuid,result jsonb,created_at timestamptz default now(),unique(actor_id,op_id));
    create function my_feature_flags() returns table(key text) language sql as $$ select 'offline_attendance'::text where coalesce(current_setting('test.flag',true),'on')='on' $$;
    create table faq_entries(question text,answer text,category text,audience text,sort_order int,route text,feature text);
    insert into clubs values('${club}','Kulüp'),('${other}','Diğer');
    insert into profiles values('${actor}'),('${coach}'),('${accountant}');
    insert into roles(actor,club,role) values('${actor}','${club}','club_admin'),('${coach}','${club}','coach'),('${accountant}','${club}','accountant');
    insert into events values('${event}','${club}','${team}','Antrenman',now()),('${id(11)}','${club}',null,'Genel',now());
    insert into athletes(id,club_id,status,first_name,last_name) values('${a}','${club}','active','Ada','Sporcu'),('${b}','${club}','active','Bora','Sporcu'),('${foreign}','${other}','active','Dış','Sporcu');
    insert into team_memberships values('${a}','${team}','${id(20)}'),('${a}','${team}','${id(21)}'),('${b}','${team}','${id(20)}');
    select set_config('test.actor','${actor}',false);`);
  await db.exec(audit.slice(0,audit.indexOf('create or replace function public.attendance_audit(')));
  await db.exec(migration);return db;
}
const marks=(status='present',version=0,athlete=a)=>[{athlete_id:athlete,status,version,marked_at:'2026-10-07T10:00:00Z'}];
async function save(db,input=marks(),op=id(100),e=event,owner=actor) {
  return (await db.query('select save_attendance_offline($1::uuid,$2::uuid,$3::uuid,$4::jsonb) r',[owner,e,op,input])).rows[0].r;
}
test('profileless roster is unique across seasons; untargeted events use the active club roster',async()=>{
  const db=await setup();try {
    const snapshot=(await db.query('select prepare_attendance_offline($1) r',[event])).rows[0].r;
    assert.equal(snapshot.rows.length,2);assert.equal(snapshot.actor_id,actor);
    assert.equal((await db.query('select * from event_roster_versioned($1)',[id(11)])).rows.length,2);
  }finally{await db.close();}
});
test('same operation writes and audits once; changed payload/event cannot reuse it',async()=>{
  const db=await setup();try {
    assert.equal((await save(db)).applied,1);assert.equal((await save(db)).replayed,true);
    await assert.rejects(save(db,marks('absent')),/farklı/);
    await assert.rejects(save(db,marks(),id(100),id(11)),/farklı/);
    assert.equal((await db.query('select count(*)::int n from attendance_audit_log')).rows[0].n,1);
    assert.equal((await db.query('select version from attendance')).rows[0].version,1);
  }finally{await db.close();}
});
test('stale versions conflict; legacy updates advance the version and cannot silently overwrite it',async()=>{
  const db=await setup();try {
    await save(db);await db.exec("update attendance set status='absent',version=999");
    assert.equal((await db.query('select version from attendance')).rows[0].version,2);
    const conflict=await save(db,marks('present',1),id(101));assert.equal(conflict.applied,0);assert.equal(conflict.conflicts[0].current_version,2);
    assert.equal((await db.query('select status from attendance')).rows[0].status,'absent');
    assert.equal((await save(db,marks('present',2),id(102))).applied,1);
  }finally{await db.close();}
});
test('partial conflicts apply independent rows and preserve the conflicting row',async()=>{
  const db=await setup();try {
    await save(db);const r=await save(db,[...marks('absent',0),...marks('excused',0,b)],id(101));
    assert.equal(r.applied,1);assert.equal(r.conflicts.length,1);
    assert.equal((await db.query('select status from attendance where athlete_id=$1',[a])).rows[0].status,'present');
  }finally{await db.close();}
});
test('accountant, other actor, revoked membership and closed flag cannot send',async()=>{
  const db=await setup();try {
    await assert.rejects(save(db,marks(),id(100),event,coach),/başka hesaba/);
    await db.exec(`select set_config('test.actor','${accountant}',false)`);await assert.rejects(save(db,marks(),id(100),event,accountant),/yetkisi/);
    await db.exec(`select set_config('test.actor','${actor}',false);update roles set active=false where actor='${actor}'`);await assert.rejects(save(db),/yetkisi/);
    await db.exec(`update roles set active=true;select set_config('test.flag','off',false)`);await assert.rejects(save(db),/kapalı/);
    assert.equal((await db.query("select has_function_privilege('anon','save_attendance_offline(uuid,uuid,uuid,jsonb)','EXECUTE') allowed")).rows[0].allowed,false);
  }finally{await db.close();}
});
test('committed operations remain replayable when the rollout is disabled',async()=>{
  const db=await setup();try {await save(db);await db.exec("select set_config('test.flag','off',false)");assert.equal((await save(db)).replayed,true);
    await assert.rejects(db.query('select prepare_attendance_offline($1)',[event]),/kapalı/);
  }finally{await db.close();}
});
test('foreign, duplicate, restricted or malformed marks leave no partial write',async()=>{
  const db=await setup();try {
    for(const input of [marks('present',0,foreign),[...marks(),...marks()],marks('invalid'),marks('present',-1),[],null]) await assert.rejects(save(db,input));
    await db.exec(`update athletes set blocked=true where id='${b}'`);
    await assert.rejects(save(db,[...marks(),...marks('present',0,b)]),/kısıtı/);
    assert.equal((await db.query('select count(*)::int n from attendance')).rows[0].n,0);
    assert.equal((await save(db,marks('excused',0,b))).applied,1);
  }finally{await db.close();}
});
test('migration is repeatable and does not duplicate help',async()=>{
  const db=await setup();try {await db.exec(migration);assert.equal((await db.query('select count(*)::int n from faq_entries')).rows[0].n,1);}finally{await db.close();}
});
