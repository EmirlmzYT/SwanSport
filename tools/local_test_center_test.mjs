import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {setup} from './full_roles_seed_sql_test.mjs';
import {assertLocalDocker,localSeed,statusKey,windowsBatchLine} from './start_local_test_center.mjs';
const read = name => readFileSync(new URL('../'+name,import.meta.url),'utf8');
const fixture=read('tools/local-test-center/fixture.sql');
const source=read('supabase/seed/full_roles_test_seed.sql');
test('Windows batch arguments quote spaces and reject shell expansion/injection',()=>{
 assert.equal(windowsBatchLine('npx.cmd',['--workdir','C:\\Test Folder']),
  '""npx.cmd" "--workdir" "C:\\Test Folder""');
 for(const value of ['x & calc','%PATH%','x"y','x\ny','x|y','!X!'])
  assert.throws(()=>windowsBatchLine('flutter.bat',[value]));
});

test('launcher refuses remote Docker and mismatched/public backend; never returns service key',()=>{
 for(const url of ['ssh://host','tcp://127.0.0.1:2375','https://docker.example','npipe://remote/pipe/docker_engine'])
  assert.throws(()=>assertLocalDocker(url));
 assert.doesNotThrow(()=>assertLocalDocker('npipe:////./pipe/docker_engine'));
 assert.doesNotThrow(()=>assertLocalDocker('unix:///var/run/docker.sock'));
 assert.throws(()=>statusKey({API_URL:'https://api.swansport.com.tr',ANON_KEY:'public'}));
 assert.throws(()=>statusKey({API_URL:'http://127.0.0.1:55421',SERVICE_ROLE_KEY:'secret'}));
 assert.equal(statusKey({API_URL:'http://127.0.0.1:55421',ANON_KEY:'sb_publishable_public',SERVICE_ROLE_KEY:'secret'}),'sb_publishable_public');
 for(const key of ['sb_secret_private','abc & echo bad','key with spaces'])
  assert.throws(()=>statusKey({API_URL:'http://127.0.0.1:55421',ANON_KEY:key}));
});
test('production build keeps local center opt-in false, no production credentials in test entrypoint',()=>{
 const ui=read('apps/swansport_app/lib/features/test_center/test_center_screen.dart');
 const main=read('apps/swansport_app/lib/main_test_center.dart');
 assert.ok(ui.includes('Provider<bool>((ref) => false)'));
 assert.ok(ui.includes('env.isDevelopment'));
 assert.ok(ui.includes('isLocalTestBackend'));
 const routes=read('apps/swansport_app/lib/app/swansport_app.dart');
 for(const route of ['/akis','/athletes','/attendance','/aidatlarim','/finans']) {
  assert.ok(ui.includes("'"+route+"'"));
  assert.ok(routes.includes("'"+route+"'"));
 }
 assert.ok(main.includes("url: 'http://127.0.0.1:55421'"));
 assert.ok(!main.includes('SupabaseConfig.fromCompileTime()'));
 const root=read('apps/swansport_app/lib/features/test_center/local_test_center_root.dart');
 assert.ok(root.includes('key: ValueKey(_revision)'));
 assert.ok(!root.includes('parent:')); // fresh provider cache on every persona switch
});

test('local fixture creates five real role accounts, roster, session and invoice; replay preserves rows',async()=>{
 const db=await setup();try {
  await db.exec(localSeed(source));
  // Marker must fail closed even when tables are otherwise compatible.
  await assert.rejects(db.exec(fixture),/LOCAL TEST ONLY/);await db.exec('rollback');
  await db.exec(`create table _local_test_center_install(project text primary key);
   insert into _local_test_center_install values('swansport-test-center');`);
  const extended=read('supabase/migrations/0003_extended.sql');
  const enums=extended.slice(extended.indexOf('do $$ begin'),extended.indexOf('-- announcements'));
  await db.exec(enums);
  const tables=extended.slice(extended.indexOf('create table if not exists public.events ('),
   extended.indexOf('-- attendance'));
  await db.exec(tables);
  await db.exec(fixture);
  const count=async t=>Number((await db.query('select count(*) n from '+t)).rows[0].n);
  assert.equal(Number((await db.query("select count(*) n from auth.users where raw_app_meta_data->>'seed_owner'='swansport-live-role-tests-v2'")).rows[0].n),5);
  assert.equal(await count('club_memberships'),3);
  assert.equal(await count('athletes'),1);assert.equal(await count('events'),1);assert.equal(await count('invoices'),1);
  assert.equal((await db.query('select count(*)::int n from profiles where is_platform_admin')).rows[0].n,1,
   'only the preexisting fixture reviewer, never a persona, remains admin');
  assert.equal((await db.query("select count(*)::int n from club_memberships m join auth.users a on a.id=m.profile_id where a.email='muhasebeci@test.swansport.invalid'")).rows[0].n,0);
  await db.exec(fixture);
  assert.equal(await count('club_memberships'),3);assert.equal(await count('invoices'),1);
  assert.equal((await db.query('select count(*)::int n from club_memberships where identity_gate_legacy')).rows[0].n,0);
  // Apply actual foundation RLS: accountant must not read coach's roster.
  await db.exec(read('supabase/migrations/0002_rls_policies.sql'));
  await db.exec(`grant usage on schema auth to authenticated;
   grant execute on function auth.uid() to authenticated;
   grant select on public.athletes to authenticated;
   select set_config('request.jwt.claim.sub',md5('swansport-live-role-tests-v2/muhasebeci')::uuid::text,false);
   set role authenticated;`);
  assert.equal(await count('athletes'),0,'accountant cannot read athlete names');
  await db.exec(`select set_config('request.jwt.claim.sub',md5('swansport-live-role-tests-v2/antrenor-3')::uuid::text,false)`);
  assert.equal(await count('athletes'),1,'coach reads the same roster through actual RLS');
  await db.exec('reset role');
 }finally{await db.close();}
});
