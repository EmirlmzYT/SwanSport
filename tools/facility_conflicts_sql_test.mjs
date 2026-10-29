// Isolated PostgreSQL/PLpgSQL behaviour test; it does not contact Supabase.
// Setup: npm install --prefix build/finance-sql-tests --no-audit --no-fund @electric-sql/pglite@0.5.8
// Run: node --test tools/facility_conflicts_sql_test.mjs
import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {test} from 'node:test';

const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const club=id(1), otherClub=id(2), facility=id(10), staff=id(20), outsider=id(21);
const migration=await readFile(new URL('../supabase/migrations/0108_facility_reservation_conflicts.sql',import.meta.url),'utf8');

const fixture=`
create role anon; create role authenticated;
create schema auth;
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
create function set_updated_at() returns trigger language plpgsql as
  $$ begin new.updated_at=now(); return new; end $$;
create table profiles(id uuid primary key);
create table clubs(id uuid primary key);
create table club_memberships(club_id uuid, profile_id uuid, status text, role text);
create function is_club_member(c uuid) returns boolean language sql stable security definer as
  $$ select exists(select 1 from club_memberships where club_id=c and profile_id=auth.uid() and status='active') $$;
create function is_club_staff(c uuid) returns boolean language sql stable security definer as
  $$ select exists(select 1 from club_memberships where club_id=c and profile_id=auth.uid() and status='active' and role in ('club_admin','coach','official')) $$;
create table facilities(id uuid primary key,club_id uuid not null references clubs(id),name text,kind text,status text default 'Müsait');
create table teams(id uuid primary key,name text);
create table events(id uuid primary key default gen_random_uuid(),club_id uuid not null references clubs(id),team_id uuid references teams(id),title text not null,kind text not null default 'training',starts_at timestamptz not null,ends_at timestamptz,facility_id uuid references facilities(id));
create table invoices(id uuid primary key);
create table faq_entries(feature text,answer text);
insert into profiles values('${staff}'),('${outsider}');
insert into clubs values('${club}'),('${otherClub}');
insert into club_memberships values('${club}','${staff}','active','club_admin'),('${otherClub}','${outsider}','active','club_admin');
insert into facilities values('${facility}','${club}','Ana Salon','hall','Müsait');
insert into faq_entries values('facility_conflicts','Eski açıklama');
grant usage on schema public,auth to authenticated,anon;
grant select,insert,update,delete on all tables in schema public to authenticated;
`;

async function actor(db, who, role='authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('test.actor',$1,false)",[who ?? '']);
  await db.exec(`set role ${role}`);
}
async function setup() {
  const db=new PGlite();
  try {
    await db.exec(fixture);
    await db.exec(`begin; ${migration} commit;`);
    await actor(db,staff);
    return db;
  } catch (error) { await db.close(); throw error; }
}
async function time(db) {
  return (await db.query("select date_trunc('hour',now())+interval '3 hours' as t")).rows[0].t;
}
async function reserve(db, start, end, allow=false) {
  return (await db.query(
    'select create_facility_reservation($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) as id',
    [club,facility,'Pilates','rental',start,end,'Üye','+905320000000',125,null,allow]
  )).rows[0].id;
}

test('clean facility accepts a reservation and preserves the canonical RPC signature',async()=>{
  const db=await setup();
  try {
    const start=await time(db), end=(await db.query("select $1::timestamptz+interval '1 hour' t",[start])).rows[0].t;
    const reservation=await reserve(db,start,end);
    const row=(await db.query('select status,fee,created_by from facility_reservations where id=$1',[reservation])).rows[0];
    assert.equal(row.status,'confirmed'); assert.equal(Number(row.fee),125); assert.equal(row.created_by,staff);
    await db.exec('reset role');
    await db.exec(`begin; ${migration} commit;`);
    await actor(db,staff);
    const signatures=await db.query("select pronargs from pg_proc where proname='facility_conflicts'");
    assert.deepEqual(signatures.rows.map(r=>r.pronargs),[5]);
  } finally { await db.close(); }
});

test('an event blocks a conflicting reservation unless staff deliberately allows it',async()=>{
  const db=await setup();
  try {
    const start=await time(db), end=(await db.query("select $1::timestamptz+interval '1 hour' t",[start])).rows[0].t;
    await db.query('insert into events(club_id,title,kind,starts_at,ends_at,facility_id) values($1,$2,$3,$4,$5,$6)',[club,'Takım Antrenmanı','training',start,end,facility]);
    await assert.rejects(reserve(db,start,end),/tesis çakışması/);
    assert(await reserve(db,start,end,true));
  } finally { await db.close(); }
});

test('an active reservation is returned with its own conflict source and cancellation removes it',async()=>{
  const db=await setup();
  try {
    const start=await time(db), end=(await db.query("select $1::timestamptz+interval '1 hour' t",[start])).rows[0].t;
    const reservation=await reserve(db,start,end);
    const conflicts=(await db.query('select * from facility_conflicts($1,$2,$3)',[facility,start,end])).rows;
    assert.equal(conflicts.length,1); assert.equal(conflicts[0].conflict_source,'reservation'); assert.equal(conflicts[0].id,reservation);
    await db.query('select cancel_facility_reservation($1)',[reservation]);
    assert.equal((await db.query('select * from facility_conflicts($1,$2,$3)',[facility,start,end])).rows.length,0);
  } finally { await db.close(); }
});

test('club outsider is denied by both the RPC and reservation RLS policy',async()=>{
  const db=await setup();
  try {
    const start=await time(db), end=(await db.query("select $1::timestamptz+interval '1 hour' t",[start])).rows[0].t;
    await actor(db,outsider);
    await assert.rejects(reserve(db,start,end),/Yetkisiz/);
    await assert.rejects(db.query("insert into facility_reservations(club_id,facility_id,title,starts_at,ends_at) values($1,$2,'Yetkisiz',$3,$4)",[club,facility,start,end]),/row-level security/);
  } finally { await db.close(); }
});

test('load includes confirmed reservations but excludes cancelled events and reservations',async()=>{
  const db=await setup();
  try {
    const start=await time(db), end=(await db.query("select $1::timestamptz+interval '1 hour' t",[start])).rows[0].t;
    await reserve(db,start,end);
    await db.query("insert into events(club_id,title,kind,starts_at,ends_at,facility_id,status) values($1,'İptal',$2,$3,$4,$5,'cancelled')",[club,'training',start,end,facility]);
    const load=(await db.query('select * from facility_load($1)',[club])).rows[0];
    assert.equal(load.event_count,1); assert.equal(load.busy_minutes,60);
  } finally { await db.close(); }
});
