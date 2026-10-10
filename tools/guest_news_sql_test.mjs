import { PGlite } from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

test('guest RSS RPC projects only active public metadata; help is valid/idempotent; table stays private', async () => {
 const db = new PGlite();
 try {
  await db.exec(`create role anon; create role authenticated;
   create table rss_sources(id uuid,name text,url text,active bool,created_by uuid,created_at timestamptz);
   create table faq_entries(question text,answer text,category text,audience text check(audience in ('everyone')),sort_order int,route text);
   insert into rss_sources values('00000000-0000-0000-0000-000000000001','Public','https://example.com/rss',true,null,now()),
    ('00000000-0000-0000-0000-000000000002','Private','https://example.com/private',false,'00000000-0000-0000-0000-000000000003',now());`);
  const migration = await readFile(new URL('../supabase/migrations/0101_guest_news_and_help.sql',import.meta.url),'utf8');
  await db.exec('begin;'+migration+'commit;');
  await db.exec('begin;'+migration+'commit;');
  assert.equal((await db.query('select count(*) n from faq_entries')).rows[0].n,2);
  assert.equal((await db.query("select has_function_privilege('anon','public_news_sources()','execute') ok")).rows[0].ok,true);
  assert.equal((await db.query("select coalesce(bool_or(a.grantee=0 and a.privilege_type='EXECUTE'),false) ok from pg_proc p cross join lateral aclexplode(p.proacl) a where p.proname='public_news_sources'")).rows[0].ok,false);
  for(const role of ['anon','authenticated']) {
   await db.exec('set role '+role);
   const rows=(await db.query('select id,name,url,active from public_news_sources()')).rows;
   assert.equal(rows.length,1);assert.equal(rows[0].name,'Public');
   assert.deepEqual(Object.keys(rows[0]).sort(),['active','id','name','url']);
   await assert.rejects(db.query('select created_by from rss_sources'),/permission denied/);
   await db.exec('reset role');
  }
 } finally {await db.close();}
});
