import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';

const id = n => `20000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const admin = id(1), coach = id(2), club = id(10), athlete = id(20), invoice = id(30);
const migration = await readFile(
  new URL('../supabase/migrations/20261101090000_pro_club_dues_management.sql', import.meta.url),
  'utf8',
);

async function fixture() {
  const db = new PGlite();
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth;
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('test.actor', true), '')::uuid $$;
    create table test_roles(actor uuid, club uuid, role text);
    create function is_club_admin(c uuid) returns boolean language sql stable as
      $$ select exists(select 1 from test_roles where actor=auth.uid() and club=c and role='club_admin') $$;
    create type invoice_status as enum ('paid', 'pending', 'overdue');
    create table athletes(id uuid primary key, club_id uuid, first_name text, last_name text);
    create table fee_plans(id uuid primary key, club_id uuid, name text, amount numeric,
      due_day int, active boolean, created_at timestamptz default now());
    create table invoices(id uuid primary key, club_id uuid, athlete_id uuid, plan_id uuid,
      label text, amount numeric, status invoice_status, period text, due_date date);
    create table payments(id uuid primary key default gen_random_uuid(), club_id uuid,
      invoice_id uuid, athlete_id uuid, amount numeric, method text, status text,
      paid_at date default current_date, note text, receipt_path text, declared_by uuid,
      confirmed_by uuid, confirmed_at timestamptz, created_at timestamptz default now());
    grant usage on schema public, auth to authenticated;
    grant select on invoices, payments to authenticated;
    insert into test_roles values ('${admin}','${club}','club_admin'),('${coach}','${club}','coach');
    insert into athletes values ('${athlete}','${club}','Ada','Yılmaz');
    insert into fee_plans values ('${id(40)}','${club}','Aylık',1000,10,true,now());
    insert into invoices values ('${invoice}','${club}','${athlete}','${id(40)}',
      'Kasım aidatı',1000,'pending','2026-11',current_date-1);
    insert into payments(club_id,invoice_id,athlete_id,amount,method,status,declared_by)
      values ('${club}','${invoice}','${athlete}',200,'havale','pending','${coach}');
  `);
  await db.exec(`begin; ${migration} commit;`);
  return db;
}

async function actor(db, person) {
  await db.exec('reset role');
  await db.query("select set_config('test.actor',$1,false)", [person]);
  await db.exec('set role authenticated');
}

test('named dues RPC is admin-only and derives real pending/overdue state', async () => {
  const db = await fixture();
  try {
    await actor(db, coach);
    await assert.rejects(db.query('select pro_club_dues_overview($1,null)', [club]), /yetkisi/);
    await actor(db, admin);
    const result = (await db.query('select pro_club_dues_overview($1,null) value', [club])).rows[0].value;
    assert.equal(result.summary.overdue_count, 1);
    assert.equal(result.summary.pending_payment_count, 1);
    assert.equal(result.invoices[0].athlete_name, 'Ada Yılmaz');
  } finally { await db.close(); }
});

test('partial collection is idempotent, bounded and only closes fully paid invoice', async () => {
  const db = await fixture();
  try {
    await actor(db, admin);
    const operation = id(90);
    const first = (await db.query(
      "select pro_record_payment($1,400,'nakit','Kısmi',$2) value",
      [invoice, operation],
    )).rows[0].value;
    const replay = (await db.query(
      "select pro_record_payment($1,400,'nakit','Kısmi',$2) value",
      [invoice, operation],
    )).rows[0].value;
    assert.equal(first, replay);
    assert.equal((await db.query('select status from invoices where id=$1', [invoice])).rows[0].status, 'pending');
    await assert.rejects(
      db.query("select pro_record_payment($1,700,'nakit',null,$2)", [invoice, id(91)]),
      /aşamaz/,
    );
    const pending = (await db.query("select id from payments where status='pending'")).rows[0].id;
    await db.query('select pro_decide_payment($1,true,null)', [pending]);
    assert.equal((await db.query('select status from invoices where id=$1', [invoice])).rows[0].status, 'pending');
    await db.query("select pro_record_payment($1,400,'kart',null,$2)", [invoice, id(92)]);
    assert.equal((await db.query('select status from invoices where id=$1', [invoice])).rows[0].status, 'paid');
  } finally { await db.close(); }
});
