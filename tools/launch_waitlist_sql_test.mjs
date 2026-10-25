import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { onRequestGet, onRequestPost, onRequestOptions } from '../apps/swansport_app/functions/api/waitlist.js';

const readSql = name => readFile(new URL(`../supabase/migrations/${name}.sql`, import.meta.url), 'utf8');
const id = n => `12200000-0000-0000-0000-${String(n).padStart(12, '0')}`;

async function setActor(db, n) {
  await db.query("select set_config('test.actor', $1, false)", [n === null ? '' : id(n)]);
}

async function setupDb() {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon;
      create role authenticated;
      create schema auth;
      create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}');
      create function auth.uid() returns uuid language sql as $$
        select nullif(current_setting('test.actor', true), '')::uuid
      $$;
      grant usage on schema auth to anon, authenticated;
      grant execute on function auth.uid() to anon, authenticated;
    `);
    await db.exec((await readSql('0001_foundation')).replace('create extension if not exists "pgcrypto";', ''));
    await db.exec(await readSql('0002_rls_policies'));
    await db.exec(await readSql('0004_roles_verification'));
    await db.exec(await readSql('0109_platform_mission_control'));
    await db.exec(await readSql('0122_launch_waitlist'));

    await db.query('insert into auth.users(id) values ($1), ($2)', [id(1), id(2)]);
    await db.query('update public.profiles set is_platform_admin = true where id = $1', [id(1)]);
    return db;
  } catch (err) {
    await db.close();
    throw err;
  }
}

test('0122_launch_waitlist: anon/authenticated join idempotently, PII is protected by RLS, and admin marks notified', async () => {
  const db = await setupDb();
  try {
    await setActor(db, null);
    await db.exec('set role anon');

    const configRes = await db.query('select public.get_public_platform_config() as cfg');
    assert.equal(configRes.rows[0].cfg.launch_release.status, 'coming_soon');
    assert.equal(configRes.rows[0].cfg.launch_release.waitlist_enabled, true);

    const first = (await db.query(
      "select public.join_launch_waitlist('  Sporcu@Ornek.COM ', 'athlete', 'tenis', 'Konya', 'swansport.com.tr') as res"
    )).rows[0].res;
    assert.equal(first.ok, true);
    assert.equal(first.already_registered, false);
    assert.equal(first.waitlist_count, 1);

    const second = (await db.query(
      "select public.join_launch_waitlist('sporcu@ornek.com', 'coach', 'okculuk', 'Ankara', 'swansport.com.tr') as res"
    )).rows[0].res;
    assert.equal(second.ok, true);
    assert.equal(second.already_registered, true);
    assert.equal(second.role, 'coach');
    assert.equal(second.waitlist_count, 1);

    await assert.rejects(
      db.query("select public.join_launch_waitlist('gecersiz-mail', 'athlete')"),
      /e-posta/
    );
    await assert.rejects(
      db.query("select public.join_launch_waitlist('veli@ornek.com', 'hacker')"),
      /rol/
    );

    // Anon cannot read raw email rows from launch_waitlist
    await assert.rejects(db.query('select * from public.launch_waitlist'), /permission/);

    // Public summary returns aggregate counts without exposing emails
    const summary = (await db.query('select public.public_waitlist_summary() as s')).rows[0].s;
    assert.equal(summary.total_count, 1);
    assert.equal(summary.coach_count, 1);

    // Non-admin authenticated user cannot read rows or mark notified
    await db.exec('reset role');
    await setActor(db, 2);
    await db.exec('set role authenticated');
    assert.equal((await db.query('select * from public.launch_waitlist')).rows.length, 0);
    await assert.rejects(
      db.query('select public.mark_launch_waitlist_notified(null)'),
      /Platform administrator required/
    );

    // Platform admin can read rows and mark notified with audit log
    await db.exec('reset role');
    await setActor(db, 1);
    await db.exec('set role authenticated');
    const rows = (await db.query('select email, role, sport_code, club_or_city, notified_at from public.launch_waitlist')).rows;
    assert.equal(rows.length, 1);
    assert.equal(rows[0].email, 'sporcu@ornek.com');
    assert.equal(rows[0].role, 'coach');
    assert.equal(rows[0].sport_code, 'okculuk');
    assert.equal(rows[0].notified_at, null);

    const marked = (await db.query("select public.mark_launch_waitlist_notified(array['sporcu@ornek.com']) as n")).rows[0].n;
    assert.equal(marked, 1);

    const after = (await db.query('select notified_at from public.launch_waitlist where email = $1', ['sporcu@ornek.com'])).rows[0];
    assert.ok(after.notified_at !== null);

    const audits = (await db.query("select action, entity_type, new_state from public.platform_audit_logs where entity_type = 'launch_waitlist'")).rows;
    assert.equal(audits.length, 1);
    assert.equal(audits[0].action, 'notify');
    assert.equal(audits[0].new_state.notified_count, 1);
  } finally {
    await db.close();
  }
});

test('Cloudflare /api/waitlist handler and landing/index.html showcase contract', async () => {
  const html = await readFile(new URL('../landing/index.html', import.meta.url), 'utf8');
  assert.ok(!html.includes('.apk'), 'landing/index.html must not expose raw APK download links');
  assert.ok(!html.includes('.ipa'), 'landing/index.html must not expose raw IPA download links');
  assert.ok(!html.includes('konsol.swansport.com.tr'), 'landing/index.html must not expose console login links');
  for (const role of ['athlete', 'coach', 'club_admin', 'guardian', 'referee']) {
    assert.ok(html.includes(`data-role="${role}"`), `missing role chip ${role}`);
    assert.ok(html.includes(`data-preview="${role}"`), `missing cockpit preview tab ${role}`);
  }
  assert.ok(html.includes('phone-3d-rig'), 'missing 3D hardware stage');
  assert.ok(html.includes('canli-laboratuvar'), 'missing interactive live training lab');
  assert.ok(html.includes('join_launch_waitlist'));
  assert.ok(html.includes('/api/waitlist'));

  const optRes = await onRequestOptions({
    request: new Request('https://swansport.com.tr/api/waitlist', {
      method: 'OPTIONS',
      headers: { Origin: 'https://swansport.com.tr' },
    }),
  });
  assert.equal(optRes.status, 204);
  assert.equal(optRes.headers.get('Access-Control-Allow-Origin'), 'https://swansport.com.tr');

  const badEmailRes = await onRequestPost({
    request: new Request('https://swansport.com.tr/api/waitlist', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: 'https://swansport.com.tr' },
      body: JSON.stringify({ email: 'not-an-email', role: 'athlete' }),
    }),
    env: { SUPABASE_URL: 'https://example.supabase.co', SUPABASE_ANON_KEY: 'anon' },
  });
  assert.equal(badEmailRes.status, 400);
});
