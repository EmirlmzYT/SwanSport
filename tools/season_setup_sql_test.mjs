// Execute actual wizard and event-series SQL locally; never contacts Supabase.
import { PGlite } from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const club=id(1), other=id(2), actor=id(3), athlete=id(4), foreign=id(5), inactive=id(6);
const migration=await readFile(new URL('../supabase/migrations/0087_season_setup.sql',import.meta.url),'utf8');
const events=await readFile(new URL('../supabase/migrations/0080_event_club_integrity.sql',import.meta.url),'utf8');
const series=events.slice(events.indexOf('create or replace function public.create_event_series('));
async function setup() {
  const db=new PGlite();
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
    create table roles(actor uuid,club uuid,role text);
    create function is_club_admin(c uuid) returns boolean language sql as $$ select exists(select 1 from roles where actor=auth.uid() and club=c and role='club_admin') $$;
    create function is_club_staff(c uuid) returns boolean language sql as $$ select exists(select 1 from roles where actor=auth.uid() and club=c and role in ('club_admin','coach')) $$;
    create table clubs(id uuid primary key,status text);
    create table seasons(id uuid primary key default gen_random_uuid(),club_id uuid,label text,starts_on date,ends_on date,is_active boolean);
    create table teams(id uuid primary key default gen_random_uuid(),club_id uuid,name text);
    create table athletes(id uuid primary key,club_id uuid,status text,profile_id uuid);
    create table team_memberships(id uuid default gen_random_uuid(),athlete_id uuid,team_id uuid,season_id uuid,unique(athlete_id,team_id,season_id));
    create type event_kind as enum ('training','match');
    create table facilities(id uuid primary key,club_id uuid,name text);
    create table events(id uuid default gen_random_uuid(),club_id uuid,team_id uuid,title text,place text,kind event_kind,starts_at timestamptz,ends_at timestamptz,facility_id uuid,series_id uuid);
    create table fee_plans(id uuid default gen_random_uuid(),club_id uuid,name text,amount numeric(12,2),due_day int,active boolean);
    create table feature_flags(key text primary key,audience text,label text,description text);
    create function my_feature_flags() returns table(key text) language sql as $$ select f.key from feature_flags f where coalesce(current_setting('test.feature',true),'on')='on' $$;
    create table faq_entries(question text,answer text,category text,audience text,sort_order int,route text,feature text,active boolean default true);
    insert into auth.users values('${actor}'),('${id(7)}');
    insert into clubs values('${club}','active'),('${other}','active');
    insert into roles values('${actor}','${club}','club_admin'),('${id(7)}','${club}','coach');
    insert into athletes values('${athlete}','${club}','active',null),('${foreign}','${other}','active',null),('${inactive}','${club}','inactive',null);
    select set_config('test.actor','${actor}',false);`);
  await db.exec(series);
  await db.exec(migration);
  return db;
}
const draft = () => ({label:'2026–27',starts_on:'2026-10-05',ends_on:'2027-09-30',team_name:'U12 yeni',athlete_ids:[athlete],activate:true,
  schedule:{until:'2026-10-11',weekdays:[1,3,5],hour:18,minute:30,minutes:90},fee:{name:'Aylık',amount:123.45,due_day:10}});
async function open(db,input=draft(),op=id(100),c=club) {
  return (await db.query('select open_club_season($1::uuid,$2::uuid,$3::jsonb) as result',[c,op,input])).rows[0].result;
}
async function counts(db) {
  return (await db.query(`select (select count(*)::int from seasons) seasons,(select count(*)::int from teams) teams,
    (select count(*)::int from team_memberships) roster,(select count(*)::int from events) events,
    (select count(*)::int from fee_plans) plans,(select count(*)::int from season_setup_runs) runs`)).rows[0];
}
test('full opening includes profileless athlete, Turkey time and inactive fee plan',async()=>{
  const db=await setup();try {
    const r=await open(db);assert.equal(r.roster_count,1);assert.equal(r.event_count,3);
    assert.deepEqual(await counts(db),{seasons:1,teams:1,roster:1,events:3,plans:1,runs:1});
    assert.equal((await db.query('select active from fee_plans')).rows[0].active,false);
    assert.equal((await db.query("select to_char(min(starts_at) at time zone 'UTC','HH24:MI') t from events")).rows[0].t,'15:30');
    assert.equal((await db.query('select team_id::text from events limit 1')).rows[0].team_id,r.team_id);
  }finally{await db.close();}
});
test('retry returns original IDs even after rollout is disabled; changed input rejected',async()=>{
  const db=await setup();try {
    const first=await open(db);await db.exec("select set_config('test.feature','off',false)");
    assert.deepEqual(await open(db),first);
    await assert.rejects(open(db,{...draft(),label:'other'}),/farklı/);
    assert.equal((await counts(db)).seasons,1);
  }finally{await db.close();}
});
test('coach, outsider, wrong club and closed rollout cannot open seasons',async()=>{
  const db=await setup();try {
    await db.exec(`select set_config('test.actor','${id(7)}',false)`);await assert.rejects(open(db),/yöneticisi/);
    await db.exec(`select set_config('test.actor','${actor}',false)`);await assert.rejects(open(db,draft(),id(100),other),/yöneticisi/);
    await db.exec("select set_config('test.feature','off',false)");await assert.rejects(open(db),/açık değil/);
    assert.equal((await counts(db)).seasons,0);
    assert.equal((await db.query("select has_function_privilege('anon','open_club_season(uuid,uuid,jsonb)','EXECUTE') allowed")).rows[0].allowed,false);
    assert.equal((await db.query("select has_table_privilege('authenticated','season_setup_runs','SELECT') allowed")).rows[0].allowed,false);
  }finally{await db.close();}
});
test('foreign, inactive, missing and duplicate athletes leave no partial writes',async()=>{
  const db=await setup();try {
    for(const ids of [[foreign],[inactive],[id(999)],[athlete,athlete],[null]]) await assert.rejects(open(db,{...draft(),athlete_ids:ids}));
    assert.deepEqual(await counts(db),{seasons:0,teams:0,roster:0,events:0,plans:0,runs:0});
  }finally{await db.close();}
});
test('malformed dates, days, times and financial inputs fail atomically',async()=>{
  const db=await setup();try {
    const cases=[{ends_on:'2028-10-10'},{starts_on:'2026-02-31'},{activate:null},
      {schedule:{...draft().schedule,weekdays:[null]}},{schedule:{...draft().schedule,weekdays:[1,1]}},
      {schedule:{...draft().schedule,hour:1.5}},{schedule:{...draft().schedule,until:'2027-01-05'}},
      {fee:{...draft().fee,amount:0}},{fee:{...draft().fee,amount:1.001}},{fee:{...draft().fee,due_day:29}}];
    for(const fields of cases) await assert.rejects(open(db,{...draft(),...fields}));
    assert.equal((await counts(db)).seasons,0);
  }finally{await db.close();}
});
test('downstream event failure rolls back roster, activation and operation cache',async()=>{
  const db=await setup();try {
    await db.exec(`insert into seasons(club_id,label,is_active) values('${club}','old',true);
      create function fail_event() returns trigger language plpgsql as $$ begin raise exception 'fixture failure'; end $$;
      create trigger fail_event before insert on events for each row execute function fail_event();`);
    await assert.rejects(open(db),/fixture failure/);
    assert.deepEqual(await counts(db),{seasons:1,teams:0,roster:0,events:0,plans:0,runs:0});
    assert.equal((await db.query("select is_active from seasons where label='old'")).rows[0].is_active,true);
    await db.exec('drop trigger fail_event on events');await open(db);
    assert.equal((await db.query('select count(*)::int n from seasons where is_active')).rows[0].n,1);
  }finally{await db.close();}
});
test('optional programme and plan can be omitted; names cannot collide',async()=>{
  const db=await setup();try {
    const input=draft();delete input.schedule;delete input.fee;input.athlete_ids=[];input.activate=false;
    const r=await open(db,input);assert.equal(r.event_count,0);assert.equal(r.fee_plan_id,null);
    await assert.rejects(open(db,{...input,label:'  2026–27  '},id(101)),/sezon zaten/);
    await assert.rejects(open(db,{...input,label:'next'},id(101)),/takım zaten/);
    assert.deepEqual(await counts(db),{seasons:1,teams:1,roster:0,events:0,plans:0,runs:1});
  }finally{await db.close();}
});
test('migration re-run retains rollout and does not duplicate FAQ',async()=>{
  const db=await setup();try {
    await db.exec("update feature_flags set audience='everyone' where key='season_setup'");await db.exec(migration);
    assert.equal((await db.query("select audience from feature_flags where key='season_setup'")).rows[0].audience,'everyone');
    assert.equal((await db.query('select count(*)::int n from faq_entries')).rows[0].n,1);
  }finally{await db.close();}
});
