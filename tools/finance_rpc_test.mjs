// Isolated PostgreSQL/PLpgSQL execution of repository migrations, no live Supabase.
// Setup: npm install --prefix build/finance-sql-tests --no-audit --no-fund @electric-sql/pglite@0.5.8
// Run: node --test tools/finance_rpc_test.mjs
// PGlite uses one connection: multi-session contention needs native PostgreSQL.
import { PGlite } from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';

const id = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const club = id(1), otherClub = id(2), account = id(3), source = id(4);
const maker = id(10), approver = id(11), accountant = id(12), outsider = id(13);
const migrations = ['0079_finance_adjustment_ledger.sql', '0082_finance_adjustment_safety_and_limits.sql',
  '0084_finance_adjustment_reconciliation_safety.sql', '0085_finance_adjustment_rpc_contract.sql'];
const fixture = `
create role anon; create role authenticated;
create schema auth;
create function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('test.actor', true), '')::uuid $$;
create table test_roles (actor uuid, club uuid, role text);
create function is_club_staff(c uuid) returns boolean language sql stable as
$$ select exists(select 1 from test_roles where actor=auth.uid() and club=c and role='staff') $$;
create function is_club_accountant(c uuid) returns boolean language sql stable as
$$ select exists(select 1 from test_roles where actor=auth.uid() and club=c and role='accountant') $$;
create function is_platform_admin() returns boolean language sql stable as
$$ select coalesce(current_setting('test.admin', true),'')='true' $$;
create table finance_periods(id uuid primary key default gen_random_uuid(), club_id uuid,
period_from date, period_to date, status text);
create function is_period_closed(c uuid, d date) returns boolean language sql stable as
$$ select exists(select 1 from finance_periods where club_id=c and status='closed'
and d between period_from and period_to) $$;
create table cash_accounts(id uuid primary key, club_id uuid, active boolean, name text);
create table expense_categories(id uuid primary key, club_id uuid, name text, sort int);
create table expenses(id uuid primary key default gen_random_uuid(), club_id uuid, account_id uuid,
category_id uuid, amount numeric(12,2) not null, spent_on date, status text, note text,
supplier text, entered_by uuid);
create table invoices(id uuid primary key, label text);
create table payments(id uuid primary key default gen_random_uuid(), club_id uuid, account_id uuid,
amount numeric(12,2) not null, paid_at date, status text, note text, method text,
athlete_id uuid, invoice_id uuid);
create table donation_campaigns(id uuid primary key, title text);
create table donations(id uuid primary key default gen_random_uuid(), club_id uuid, account_id uuid,
amount numeric(12,2) not null, created_at timestamptz default now(), status text,
campaign_id uuid, anonymous boolean, donor_name text);
create table finance_adjustments(id uuid primary key default gen_random_uuid(), club_id uuid,
period_id uuid, target_kind text, target_id uuid, entry_kind text, entry_id uuid,
amount numeric(12,2) not null, reason text, status text default 'pending', created_by uuid,
approved_by uuid, approved_at timestamptz, created_at timestamptz default now());
create table finance_period_logs(id uuid primary key default gen_random_uuid(), period_id uuid,
club_id uuid, actor_id uuid, action text, note text);
create function athlete_ref(a uuid) returns text language sql as $$ select '#MASKED' $$;
create function tr_contains(a text,b text) returns boolean language sql immutable as
$$ select coalesce(a ilike '%' || b || '%', false) $$;
alter table finance_adjustments enable row level security;
create policy fixture_read on finance_adjustments for select to authenticated
using (is_club_staff(club_id) or is_club_accountant(club_id) or is_platform_admin());
grant usage on schema public,auth to authenticated;
grant select on finance_adjustments,test_roles to authenticated;
`;

async function setup() {
  const db = new PGlite();
  await db.exec(fixture);
  await db.exec(`insert into test_roles values ('${maker}','${club}','staff'),
    ('${approver}','${club}','staff'),('${accountant}','${club}','accountant');
    insert into finance_periods values ('${id(20)}','${club}',current_date-90,current_date-1,'closed'),
    ('${id(21)}','${club}',current_date,current_date+30,'open');
    insert into cash_accounts values ('${account}','${club}',true,'Kasa');
    insert into expense_categories values ('${id(22)}',null,'Diğer',1);
    insert into expenses(id,club_id,account_id,amount,spent_on,status,note)
    values ('${source}','${club}','${account}',100,current_date-20,'complete','Kaynak');`);
  return db;
}
async function apply(db, files = migrations) {
  for (const file of files) {
    const sql = await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8');
    await db.exec(`begin; ${sql} commit;`);
  }
}
async function actor(db, who) { await db.query("select set_config('test.actor',$1,false)", [who]); }
async function create(db, amount, kind='expense', target=source) {
  const r = await db.query(`select create_finance_adjustment($1,$2,$3,$4,'Gerekçe') as id`,
    [club,kind,target,amount]);
  return r.rows[0].id;
}
async function approve(db, adjustment, decision=true, note=null) {
  return db.query('select approve_finance_adjustment(p_id=>$1,p_approve=>$2,p_note=>$3)',
    [adjustment,decision,note]);
}
async function count(db, table) { return (await db.query(`select count(*)::int as n from ${table}`)).rows[0].n; }
async function legacy(db, amount=150, target=source, entry=null) {
  await db.query(`insert into finance_adjustments(id,club_id,target_kind,target_id,amount,reason,status,
    created_by,approved_by,entry_id) values($1,$2,'expense',$3,$4,'Eski','approved',$5,$6,$7)`,
    [id(30),club,target,amount,maker,approver,entry]);
}

test('fresh chain and repeated migrations never synthesize historical money', async () => {
  const db=await setup();
  try {
    await legacy(db);
    for (const file of migrations) {
      await apply(db,[file]);
      assert.equal(await count(db,'payments'),0,file);
      assert.equal((await db.query('select entry_id from finance_adjustments')).rows[0].entry_id,null);
    }
    await apply(db);
    assert.equal(await count(db,'payments'),0);
    assert.equal(await count(db,'finance_period_logs'),0);
  } finally { await db.close(); }
});

test('0085 alone repairs an already-installed bad overload without touching history', async () => {
  const db=await setup();
  try {
    await legacy(db);
    await db.exec(`create function approve_finance_adjustment(p_id uuid,p_approve boolean,p_note text default null)
      returns void language plpgsql as $$ begin raise exception 'old client path'; end $$;
      create function approve_finance_adjustment(p_id uuid,p_approve boolean)
      returns void language plpgsql as $$ begin raise exception 'bad overload'; end $$;`);
    await apply(db,[migrations.at(-1)]);
    await actor(db,approver); await assert.rejects(approve(db,id(30)),/inceleme/);
    assert.equal((await db.query('select * from get_finance_adjustment_reconciliation_issues($1)',[club])).rows.length,1);
    assert.equal(await count(db,'payments'),0);
    assert.equal((await db.query("select count(*)::int n from pg_proc where proname='approve_finance_adjustment'")).rows[0].n,1);
  } finally { await db.close(); }
});

test('audit failure rolls back movement and approval together', async () => {
  const db=await setup();
  try {
    await apply(db); await actor(db,maker); const adjustment=await create(db,20);
    await db.exec(`create function reject_test_log() returns trigger language plpgsql as
      $$ begin raise exception 'audit unavailable'; end $$;
      create trigger fail_log before insert on finance_period_logs for each row execute function reject_test_log();`);
    await actor(db,approver); await assert.rejects(approve(db,adjustment),/audit unavailable/);
    assert.equal(await count(db,'payments'),0);
    assert.equal((await db.query('select status,entry_id from finance_adjustments where id=$1',[adjustment])).rows[0].status,'pending');
  } finally { await db.close(); }
});

test('server search, target filtering and paging return reserved capacity', async () => {
  const db=await setup();
  try {
    await apply(db);
    await db.exec(`insert into expenses(id,club_id,account_id,amount,spent_on,status,note)
      values('${id(60)}','${club}','${account}',200,current_date-10,'complete','İkinci kaynak');`);
    await actor(db,maker); await create(db,30);
    const first=(await db.query(`select * from acc_closed_period_candidates(p_club=>$1,p_target_kind=>'expense',
      p_search=>'Kaynak',p_limit=>1,p_offset=>0)`,[club])).rows;
    const second=(await db.query(`select * from acc_closed_period_candidates(p_club=>$1,p_target_kind=>'expense',
      p_search=>'Kaynak',p_limit=>1,p_offset=>1)`,[club])).rows;
    assert.equal(first.length,1); assert.equal(second.length,1);
    assert.equal(Number(first[0].total_count),2); assert.notEqual(first[0].entry_id,second[0].entry_id);
    assert.equal(Number(second[0].remaining_amount),70);
    assert.equal((await db.query(`select * from acc_closed_period_candidates(p_club=>$1,p_target_kind=>'payment')`,[club])).rows.length,0);
  } finally { await db.close(); }
});

test('canonical client signature removes stale overload, notes persist, repeated approval is idempotent', async () => {
  const db=await setup();
  try {
    await db.exec(`create function approve_finance_adjustment(uuid,boolean) returns void
      language plpgsql as $$ begin raise exception 'stale overload'; end $$;`);
    await apply(db);
    const functions=await db.query(`select proargnames from pg_proc where proname='approve_finance_adjustment'`);
    assert.deepEqual(functions.rows.map(r=>r.proargnames),[['p_id','p_approve','p_note']]);
    await actor(db,maker); const adjustment=await create(db,40);
    await assert.rejects(approve(db,adjustment),/Kendi/);
    await actor(db,approver); await db.exec('set role authenticated');
    await approve(db,adjustment,true,'Denetim notu');
    await approve(db,adjustment); // Three named args used by Dart.
    await db.query('select approve_finance_adjustment($1,true)',[adjustment]); // Default note, no ambiguity.
    await db.exec('reset role');
    assert.equal(await count(db,'payments'),1);
    assert.equal(await count(db,'finance_period_logs'),1);
    const movement=(await db.query('select amount,athlete_id,account_id from payments')).rows[0];
    assert.equal(Number(movement.amount),40); assert.equal(movement.athlete_id,null);
    assert.equal(movement.account_id,account);
    assert.equal((await db.query('select note from finance_period_logs')).rows[0].note,'Denetim notu');
  } finally { await db.close(); }
});

test('approved entry must exist and match club, account, amount, status and direction', async () => {
  const db=await setup();
  try {
    await apply(db); await legacy(db,20,source,id(80));
    await actor(db,maker);
    await assert.rejects(create(db,1),/inceleme/); // Dangling non-null ID.
    await db.exec(`insert into payments(id,club_id,account_id,amount,paid_at,status)
      values('${id(80)}','${club}','${account}',20,current_date,'confirmed');
      update finance_adjustments set entry_kind='payment';`);
    for (const mutation of [
      `update payments set club_id='${otherClub}'`,
      `update payments set account_id='${id(99)}'`,
      'update payments set amount=21',
      "update payments set status='pending'",
      "update finance_adjustments set entry_kind='expense'",
    ]) {
      await db.exec(`update payments set club_id='${club}',account_id='${account}',amount=20,status='confirmed';
        update finance_adjustments set entry_kind='payment'; ${mutation};`);
      await assert.rejects(create(db,1),/inceleme/);
      assert.equal((await db.query('select * from acc_closed_period_candidates($1)',[club])).rows.length,0);
      const issues=(await db.query('select * from get_finance_adjustment_reconciliation_issues($1)',[club])).rows;
      assert.equal(issues.length,1); assert.equal(issues[0].issue_reason,'Defter Hareketi Eşleşmiyor');
    }
    await db.exec(`update payments set club_id='${club}',account_id='${account}',amount=20,status='confirmed';
      update finance_adjustments set entry_kind='payment';`);
    assert.equal(Number((await db.query('select * from acc_closed_period_candidates($1)',[club])).rows[0].remaining_amount),80);
    await create(db,80);
    assert.equal((await db.query(`select has_function_privilege('authenticated',
      'finance_adjustment_entry_matches(finance_adjustments,uuid)','execute') as allowed`)).rows[0].allowed,false);
  } finally { await db.close(); }
});

test('already-realized excess is reported without rewriting historical entries', async () => {
  const db=await setup();
  try {
    await apply(db); await legacy(db,60,source,id(80));
    await db.exec(`insert into payments(id,club_id,account_id,amount,paid_at,status)
      values('${id(80)}','${club}','${account}',60,current_date,'confirmed'),
      ('${id(81)}','${club}','${account}',60,current_date,'confirmed');
      update finance_adjustments set entry_kind='payment';
      insert into finance_adjustments(club_id,target_kind,target_id,amount,reason,status,created_by,entry_kind,entry_id)
      values('${club}','expense','${source}',60,'Eski','approved','${maker}','payment','${id(81)}');`);
    await apply(db,[migrations.at(-1)]); await actor(db,approver);
    assert.equal((await db.query('select * from get_finance_adjustment_reconciliation_issues($1)',[club])).rows.length,2);
    await assert.rejects(create(db,1),/inceleme/);
    assert.equal(await count(db,'payments'),2);
    assert.equal(Number((await db.query('select sum(amount) as amount from payments')).rows[0].amount),120);
  } finally { await db.close(); }
});

test('accountant may request but never approve; platform admin has no self-approval exception', async () => {
  const db=await setup();
  try {
    await apply(db); await actor(db,maker); const adjustment=await create(db,30);
    await db.exec("select set_config('test.admin','true',false)");
    await assert.rejects(approve(db,adjustment),/Kendi/);
    await db.exec("select set_config('test.admin','false',false)");
    await actor(db,accountant);
    await assert.rejects(approve(db,adjustment),/yalnızca/);
    await assert.rejects(approve(db,adjustment,false),/yalnızca/);
    await create(db,20);
    await actor(db,outsider); await assert.rejects(create(db,1),/yetkiniz/);
    await actor(db,''); await assert.rejects(approve(db,adjustment),/Giriş/);
    assert.equal(await count(db,'payments'),0);
  } finally { await db.close(); }
});

test('pending reservations and actual approvals enforce cumulative source capacity', async () => {
  const db=await setup();
  try {
    await apply(db); await actor(db,maker);
    const first=await create(db,60), second=await create(db,40);
    await assert.rejects(create(db,0.01),/büyük olamaz/);
    await actor(db,approver); await approve(db,first); await approve(db,second);
    assert.equal(Number((await db.query('select sum(amount) as n from payments')).rows[0].n),100);
    await actor(db,maker); await assert.rejects(create(db,1),/büyük olamaz/);
    // Legacy pending excess inserted outside the RPC is checked again on approval.
    await db.exec(`insert into finance_adjustments(club_id,target_kind,target_id,amount,reason,created_by)
      values('${club}','expense','${source}',1,'Eski talep','${maker}')`);
    const excess=(await db.query("select id from finance_adjustments where status='pending'")).rows[0].id;
    await actor(db,approver); await assert.rejects(approve(db,excess),/aşılamaz/);
    assert.equal(await count(db,'payments'),2);
  } finally { await db.close(); }
});

test('negative or missing historical movement blocks new capacity, appears in isolated review RPC', async () => {
  const db=await setup();
  try {
    await legacy(db,-50); await apply(db); await actor(db,maker);
    await assert.rejects(create(db,100),/inceleme/);
    assert.equal((await db.query('select * from acc_closed_period_candidates($1)',[club])).rows.length,0);
    await actor(db,approver); await assert.rejects(approve(db,id(30)),/inceleme/);
    const issues=await db.query('select * from get_finance_adjustment_reconciliation_issues($1)',[club]);
    assert.equal(issues.rows.length,1); assert.equal(issues.rows[0].issue_reason,'Geçersiz Tutar');
    await assert.rejects(db.query('select * from get_finance_adjustment_reconciliation_issues($1)',[otherClub]),/Yetkisiz/);
    await db.exec('set role authenticated');
    assert.equal((await db.query('select * from v_finance_adjustment_reconciliation_issues')).rows.length,1);
    await actor(db,outsider);
    assert.equal((await db.query('select * from v_finance_adjustment_reconciliation_issues')).rows.length,0);
    await db.exec('reset role');
    await actor(db,maker); await db.exec('update finance_adjustments set amount=20');
    await assert.rejects(create(db,80),/inceleme/);
    assert.equal(await count(db,'payments'),0);
  } finally { await db.close(); }
});

test('invalid amounts, target kind, inactive account, open source and closed current period fail without money', async () => {
  const db=await setup();
  try {
    await apply(db); await actor(db,maker);
    for (const value of [0,-1,0.004,'NaN','Infinity',null]) await assert.rejects(create(db,value));
    await assert.rejects(create(db,1,null),/Geçersiz hedef/);
    await db.exec('update cash_accounts set active=false');
    await assert.rejects(create(db,1),/kasa hesabı/);
    await db.exec('update cash_accounts set active=true; update expenses set spent_on=current_date');
    await assert.rejects(create(db,1),/kapanmış/);
    await db.exec('update expenses set spent_on=current_date-20');
    const adjustment=await create(db,10); await actor(db,approver);
    await db.exec("update finance_periods set status='closed' where period_from=current_date");
    await assert.rejects(approve(db,adjustment),/Cari dönem/);
    assert.equal(await count(db,'payments'),0);
  } finally { await db.close(); }
});

test('payment and donation refunds create same-account expenses; rejection releases reservation', async () => {
  const db=await setup();
  try {
    await apply(db);
    await db.exec(`insert into payments(id,club_id,account_id,amount,paid_at,status,athlete_id)
      values('${id(40)}','${club}','${account}',80,current_date-20,'confirmed','${id(50)}');
      insert into donations(id,club_id,account_id,amount,created_at,status,anonymous,donor_name)
      values('${id(41)}','${club}','${account}',70,current_date-20,'confirmed',true,'Private');`);
    await actor(db,maker);
    const payment=await create(db,30,'payment',id(40)), donation=await create(db,20,'donation',id(41));
    const rejected=await create(db,100); await actor(db,approver);
    await approve(db,rejected,false,'Ret gerekçesi'); await approve(db,rejected,false);
    await approve(db,payment); await approve(db,donation);
    const movements=(await db.query('select amount,account_id from expenses where spent_on=current_date')).rows;
    assert.deepEqual(movements.map(r=>Number(r.amount)).sort((a,b)=>a-b),[20,30]);
    assert.ok(movements.every(r=>r.account_id===account));
    await actor(db,maker); await create(db,100);
    await actor(db,accountant);
    const candidates=(await db.query('select * from acc_closed_period_candidates($1)',[club])).rows;
    assert.equal(candidates.find(r=>r.target_kind==='payment').counterpart,'#MASKED');
    assert.equal(candidates.find(r=>r.target_kind==='donation').counterpart,'Anonim');
    const grants=(await db.query(`select has_function_privilege('anon',
      'approve_finance_adjustment(uuid,boolean,text)','execute') as anon,
      has_function_privilege('authenticated','approve_finance_adjustment(uuid,boolean,text)','execute') as member`)).rows[0];
    assert.equal(grants.anon,false); assert.equal(grants.member,true);
  } finally { await db.close(); }
});
