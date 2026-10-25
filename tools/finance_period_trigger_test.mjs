import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const migration='20261025194500_fix_finance_period_trigger_row_fields.sql';
test('period lock reads only fields available on each finance table',async()=>{
 const db=new PGlite();
 try {
  await db.exec(`create table finance_periods(club_id uuid,period_from date,period_to date,status text);
   create function is_period_closed(c uuid,d date) returns boolean language sql stable as $$
    select exists(select 1 from finance_periods where club_id=c and status='closed' and d between period_from and period_to)$$;
   create table expenses(id int,club_id uuid,spent_on date);
   create table payments(id int,club_id uuid,paid_at date);
   create table donations(id int,club_id uuid,created_at timestamptz);`);
  await db.exec(await readFile(new URL('../supabase/migrations/'+migration,import.meta.url),'utf8'));
  for(const table of ['expenses','payments','donations'])
   await db.exec(`create trigger lock_${table} before insert or update or delete on ${table} for each row execute function block_closed_period()`);
  const club='10000000-0000-4000-8000-000000000001';
  await db.exec(`insert into expenses values(1,'${club}',current_date);
   insert into payments values(1,'${club}',current_date);
   insert into donations values(1,'${club}',now());`);
  assert.equal((await db.query('select count(*)::int n from payments')).rows[0].n,1);
  await db.exec(`insert into finance_periods values('${club}',current_date-2,current_date-1,'closed')`);
  await assert.rejects(db.exec(`insert into payments values(2,'${club}',current_date-1)`),/kapanmış bir mali döneme/);
  await assert.rejects(db.exec(`update expenses set spent_on=current_date-1 where id=1`),/kapanmış bir mali döneme/);
 } finally {await db.close();}
});
