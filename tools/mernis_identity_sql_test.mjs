// Isolated real 0100 schema/guard + additive 0115. No external identity request.
import { c1, verify } from './identity_membership_sql_test.mjs';
import { apply, actor, call, id, admin, child, guardian } from './federation_foundation_sql_test.mjs';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const migration = await readFile(new URL('../supabase/migrations/0115_automated_identity_verification.sql', import.meta.url), 'utf8');
const person = id(50), second = id(53);
// Synthetic algorithm-only fixtures, not genuine identity data.
const national = '10000000146', different = '10000000214';

async function fixture() {
  const f = await c1();
  try {
    await f.db.exec(`create role service_role; grant usage on schema public,auth to service_role;
      create function auth.role() returns text language sql as $$select nullif(current_setting('test.jwt_role',true),'')$$;
      grant execute on function auth.role() to anon,authenticated,service_role;`);
    const faq = await readFile(new URL('../supabase/migrations/0069_faq_and_support.sql', import.meta.url), 'utf8');
    const start = faq.indexOf('create table if not exists public.faq_entries');
    await f.db.exec(faq.slice(start, faq.indexOf('do $blk$', start)));
    await f.db.exec('alter table faq_entries add column feature text;');
    await apply(f.db, migration);
    return f;
  } catch (error) { await f.db.close(); throw error; }
}
async function as(db, role, uid = null, jwtRole = role) {
  await db.exec('reset role'); await actor(db, uid);
  await db.query("select set_config('test.jwt_role',$1,false)", [jwtRole]);
  await db.exec(`set role ${role}`);
}
async function owner(db) { await db.exec('reset role'); await actor(db, admin); }

test('0115 only service role can attest: user/admin/anon, forged GUC and private-context writes closed', async () => {
  const {db} = await fixture(); try {
    assert.equal(migration.split(/\r?\n/)[0], "set local lock_timeout = '15s';");
    for (const role of ['anon', 'authenticated', 'service_role']) {
      await owner(db);
      assert.equal((await db.query("select has_function_privilege($1,'complete_identity_verification(uuid,text,int)','execute') v",[role])).rows[0].v, role === 'service_role');
      await as(db, role, admin, 'service_role');
      await assert.rejects(db.exec('insert into _identity_completion_context values(1,gen_random_uuid(),gen_random_uuid())'), /permission/);
      await assert.rejects(db.exec('select * from identity_verification_audit'), /permission/);
      if (role !== 'service_role') await assert.rejects(call(db,'complete_identity_verification',[person,national,1995]), /permission/);
    }
    await as(db,'service_role',null,'authenticated');
    await assert.rejects(call(db,'complete_identity_verification',[person,national,1995]), /Backend/);
    await owner(db); await apply(db,migration); await apply(db,migration);
    assert.equal((await db.query("select count(*) n from pg_proc where proname='complete_identity_verification'")).rows[0].n,1);
    assert.equal((await db.query("select count(*) n from faq_entries where route='/dogrulama'")).rows[0].n,1);
  } finally { await db.close(); }
});

test('0115 validates checksum/year/target, preserves birthday and sports roles, retries without extra audit', async () => {
  const {db} = await fixture(); try {
    await owner(db);
    const birthday = (await db.query('select birth_date from athletes where id=$1',[child])).rows[0].birth_date;
    const count = (await db.query("select count(*) n from profile_credentials where kind<>'identity'")).rows[0].n;
    await as(db,'service_role');
    for (const [p,n,y] of [[person,null,1995],[person,'00000000146',1995],[person,'10000000147',1995],
      [person,national,null],[person,national,1899],[person,national,3000],[null,national,1995],[id(9999),national,1995]]) {
      await assert.rejects(call(db,'complete_identity_verification',[p,n,y]), /Geçersiz|Hesap/);
    }
    await call(db,'complete_identity_verification',[person,national,1995]);
    await call(db,'complete_identity_verification',[person,national,1995]);
    await owner(db);
    const row=(await db.query("select * from profile_credentials where profile_id=$1 and kind='identity'",[person])).rows[0];
    assert.equal(row.status,'approved'); assert.equal(row.verified_national_id,national); assert.equal(row.reviewed_by,null);
    assert.equal((await db.query('select count(*) n from identity_verification_audit')).rows[0].n,1);
    assert.equal((await db.query('select count(*) n from _identity_completion_context')).rows[0].n,0);
    assert.deepEqual((await db.query('select birth_date from athletes where id=$1',[child])).rows[0].birth_date,birthday);
    assert.equal((await db.query("select count(*) n from profile_credentials where kind<>'identity'")).rows[0].n,count);
    assert.doesNotMatch(JSON.stringify((await db.query('select * from identity_verification_audit')).rows),new RegExp(national+'|birth_year|first_name|last_name'));
    await as(db,'authenticated',person);
    assert.equal((await call(db,'my_identity_gate')).identity_verified,true);
    await assert.rejects(db.exec('select verified_national_id from profile_credentials'),/permission/);
    assert.equal((await db.query('select id,kind,status from profile_credentials where profile_id=$1',[person])).rows.length,1);
    await as(db,'service_role');
    await assert.rejects(call(db,'complete_identity_verification',[person,different,1995]),/değiştirilemez/);
    await assert.rejects(call(db,'complete_identity_verification',[second,national,1995]),/başka bir hesap/);
  } finally { await db.close(); }
});

test('0115 manual document reviewer survives; audit failure rolls back auto approval and context', async () => {
  const {db} = await fixture(); try {
    await verify(db,guardian,'22222222220'); // existing document review contract
    await owner(db);
    await db.exec(`create function fail_identity_audit() returns trigger language plpgsql as $$begin raise exception 'Audit failure';end$$;
      create trigger reject_audit before insert on identity_verification_audit for each row execute function fail_identity_audit();`);
    await as(db,'service_role');
    await assert.rejects(call(db,'complete_identity_verification',[person,national,1995]),/Audit failure/);
    await owner(db);
    assert.equal((await db.query("select count(*) n from profile_credentials where profile_id=$1 and kind='identity'",[person])).rows[0].n,0);
    assert.equal((await db.query('select count(*) n from _identity_completion_context')).rows[0].n,0);
    await as(db,'authenticated',second);
    await assert.rejects(db.query("insert into profile_credentials(profile_id,kind,status,verified_national_id) values($1,'identity','approved',$2)",[second,national]),/RPC/);
  } finally { await db.close(); }
});

test('0115 rolling limit rejects sixth user OR IP attempt across callers, expires and stores no raw identifiers', async () => {
  const {db} = await fixture(); try {
    const u='u:'+'a'.repeat(64), ip='i:'+'b'.repeat(64), ip2='i:'+'c'.repeat(64), u2='u:'+'d'.repeat(64);
    await as(db,'service_role');
    for(let n=0;n<5;n++)assert.equal(await call(db,'consume_identity_verification_attempt',[u,ip]),true);
    assert.equal(await call(db,'consume_identity_verification_attempt',[u,ip2]),false);
    assert.equal(await call(db,'consume_identity_verification_attempt',[u2,ip]),false);
    await assert.rejects(call(db,'consume_identity_verification_attempt',['u:raw-person','i:raw-ip']),/Invalid/);
    await owner(db);
    await db.exec("update _identity_attempt_windows set attempts=array[now()-interval '61 seconds']");
    await as(db,'service_role'); assert.equal(await call(db,'consume_identity_verification_attempt',[u,ip]),true);
    await as(db,'authenticated',person);
    await assert.rejects(call(db,'consume_identity_verification_attempt',[u,ip]),/permission/);
  } finally { await db.close(); }
});
