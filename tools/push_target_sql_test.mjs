import { PGlite } from '@electric-sql/pglite';
import { readFile, readdir } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const id = (n) => `50000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const sql = async (name) => readFile(new URL('../supabase/migrations/' + name, import.meta.url), 'utf8');

const ALL_42_KINDS = {
  social: [
    'message',
    'follow',
    'mention',
    'post_repost',
    'post_quote',
    'partner_request',
    'partner_request_accepted',
    'offer',
    'achievement',
  ],
  pro: [
    'referee_assignment',
    'expense_approval',
    'expense_rejected',
    'commitment_due',
    'account_negative',
    'bank_unmatched',
    'period_closed',
    'period_blocked',
    'turf_slot_request',
    'turf_field',
    'turf_manager',
    'court_waitlist',
    'turf_delegation',
    'store_decision',
    'moderation',
  ],
  both: [
    'match_live',
    'match_result',
    'fee',
    'fee_reminder',
    'payment',
    'donation',
    'attendance',
    'attendance_reminder',
    'event',
    'announcement',
    'document',
    'documents',
    'document_expiry',
    'support',
    'eligibility',
    'training_session',
    'training_result',
    'application',
  ],
};

async function createBaseFixture() {
  const db = new PGlite();
  await db.exec(`
    create role anon;
    create role authenticated;
    create role service_role;
    create schema auth;
    create schema net;

    create function auth.uid() returns uuid language sql as $$
      select nullif(current_setting('test.actor', true), '')::uuid
    $$;

    create table profiles (
      id uuid primary key,
      full_name text
    );

    create table guardians (
      profile_id uuid,
      athlete_id uuid
    );

    create table direct_messages (
      id uuid primary key,
      sender_id uuid,
      recipient_id uuid
    );

    create function is_blocked_between(a uuid, b uuid) returns boolean language sql as $$
      select coalesce(current_setting('test.blocked', true), 'false') = 'true'
    $$;

    create function _match_follow_state(m uuid, p uuid) returns jsonb language sql as $$
      select jsonb_build_object('is_followed', coalesce(current_setting('test.followed', true), 'true') <> 'false')
    $$;

    create table notifications (
      id uuid primary key default gen_random_uuid(),
      profile_id uuid references profiles(id) on delete cascade,
      kind text,
      title text,
      body text,
      entity_type text,
      entity_id uuid,
      created_at timestamptz default now()
    );

    create function is_platform_admin() returns boolean language sql as $$
      select coalesce(current_setting('test.admin', true), '') = 'true'
    $$;

    create function push_allowed(p uuid, k text) returns boolean language sql as $$
      select coalesce(current_setting('test.allowed', true), 'true') <> 'false'
    $$;

    create function push_secret() returns text language sql as $$
      select 'fixture-secret'
    $$;

    create function _match_follow_public(p uuid) returns boolean language sql as $$
      select true
    $$;

    create function _swan_feature_for_profile(k text, p uuid) returns boolean language sql as $$
      select coalesce(current_setting('test.flag', true), 'true') <> 'false'
    $$;

    create table net.requests (
      id bigserial primary key,
      headers jsonb,
      body jsonb
    );

    create table net._http_response (
      id bigint primary key,
      status_code int,
      content text,
      timed_out boolean default false,
      error_msg text
    );

    create function net.http_post(
      url text,
      body jsonb,
      params jsonb default '{}',
      headers jsonb default '{}',
      timeout_milliseconds int default 5000
    ) returns bigint language plpgsql as $$
    declare
      r bigint;
    begin
      insert into net.requests(headers, body) values(headers, body) returning id into r;
      return r;
    end;
    $$;

    create table push_subscriptions (
      id uuid primary key default gen_random_uuid(),
      profile_id uuid references profiles(id) on delete cascade,
      endpoint text unique,
      kind text default 'fcm',
      p256dh text,
      auth text,
      user_agent text
    );

    create function push_route(k text, e text) returns text language sql as $$
      select '/bildirimler'
    $$;

    grant usage on schema public, auth to anon, authenticated, service_role;
  `);

  // Load tracking migration and new app target migration
  const files = (await readdir(new URL('../supabase/migrations/', import.meta.url))).sort();
  for (const name of files) {
    if (
      name.endsWith('_push_delivery_tracking.sql') ||
      name.endsWith('_push_app_target.sql')
    ) {
      await db.exec(await sql(name));
    }
  }

  await db.query('insert into profiles values($1), ($2)', [id(1), id(2)]);
  return db;
}

test('all 42 notification kinds match exact target policy and unknown kinds fail closed to social', async () => {
  const db = await createBaseFixture();
  try {
    let totalCount = 0;
    for (const [target, kinds] of Object.entries(ALL_42_KINDS)) {
      for (const kind of kinds) {
        totalCount++;
        const res = await db.query('select public._notification_target_policy($1) as policy', [kind]);
        assert.equal(
          res.rows[0].policy,
          target,
          `kind "${kind}" should map to "${target}" but got "${res.rows[0].policy}"`,
        );
      }
    }
    assert.equal(totalCount, 42, 'Must test exactly 42 kinds');

    // Unknown kinds fail-closed to social
    const unknownRes = await db.query('select public._notification_target_policy($1) as policy', ['unknown_future_kind']);
    assert.equal(unknownRes.rows[0].policy, 'social', 'Unknown kinds must fail closed to social');

    const nullRes = await db.query('select public._notification_target_policy(null) as policy');
    assert.equal(nullRes.rows[0].policy, 'social', 'Null kind must fail closed to social');
  } finally {
    await db.close();
  }
});

test('push_subscriptions app_target defaults to social, enforces valid targets, and revision increments on target change', async () => {
  const db = await createBaseFixture();
  try {
    // Default app_target is 'social'
    await db.query(`
      insert into push_subscriptions(id, profile_id, endpoint, kind, p256dh, auth)
      values($1, $2, 'endpoint-social', 'fcm', 'p256', 'auth')
    `, [id(10), id(1)]);

    let row = (await db.query('select app_target, delivery_revision from push_subscriptions where id = $1', [id(10)])).rows[0];
    assert.equal(row.app_target, 'social');
    assert.equal(row.delivery_revision, 1);

    // Changing app_target increments delivery_revision
    await db.query(`update push_subscriptions set app_target = 'pro' where id = $1`, [id(10)]);
    row = (await db.query('select app_target, delivery_revision from push_subscriptions where id = $1', [id(10)])).rows[0];
    assert.equal(row.app_target, 'pro');
    assert.equal(row.delivery_revision, 2);

    // Invalid app_target is rejected by CHECK constraint
    await assert.rejects(
      db.query(`update push_subscriptions set app_target = 'invalid' where id = $1`, [id(10)]),
      /check/i,
    );
  } finally {
    await db.close();
  }
});

test('register_push_subscription has single canonical 6-parameter signature with app_target and denies anon', async () => {
  const db = await createBaseFixture();
  try {
    // Anonymous user cannot call register_push_subscription
    await db.exec('set role anon');
    await assert.rejects(
      db.query(`select public.register_push_subscription('endpoint-anon', 'fcm', null, null, null, 'social')`),
      /permission denied/i,
    );

    // Authenticated user can register
    await db.exec('reset role');
    await db.query(`select set_config('test.actor', $1, false)`, [id(1)]);
    await db.exec('set role authenticated');

    await db.query(`select public.register_push_subscription('sub-token-pro', 'fcm', 'p', 'a', 'ua', 'pro')`);
    await db.exec('reset role');

    const sub = (await db.query(`select * from push_subscriptions where endpoint = 'sub-token-pro'`)).rows[0];
    assert.equal(sub.profile_id, id(1));
    assert.equal(sub.app_target, 'pro');

    // Calling with default target (social)
    await db.exec('set role authenticated');
    await db.query(`select public.register_push_subscription('sub-token-social', 'fcm', 'p', 'a', 'ua')`);
    await db.exec('reset role');

    const subSocial = (await db.query(`select * from push_subscriptions where endpoint = 'sub-token-social'`)).rows[0];
    assert.equal(subSocial.app_target, 'social');

    // Invalid target in register_push_subscription raises exception
    await db.exec('set role authenticated');
    await assert.rejects(
      db.query(`select public.register_push_subscription('sub-token-bad', 'fcm', 'p', 'a', 'ua', 'invalid_target')`),
      /geçersiz hedef|invalid/i,
    );
    await db.exec('reset role');
  } finally {
    await db.close();
  }
});

test('push_subscription_state checks endpoint and target ownership', async () => {
  const db = await createBaseFixture();
  try {
    await db.query(`
      insert into push_subscriptions(id, profile_id, endpoint, kind, p256dh, auth, app_target)
      values($1, $2, 'ep-pro', 'fcm', 'p', 'a', 'pro')
    `, [id(20), id(1)]);

    // Check with no session
    let state = (await db.query(`select public.push_subscription_state('ep-pro', 'pro') as state`)).rows[0].state;
    assert.equal(state, 'no_session');

    // Session of owner
    await db.query(`select set_config('test.actor', $1, false)`, [id(1)]);
    state = (await db.query(`select public.push_subscription_state('ep-pro', 'pro') as state`)).rows[0].state;
    assert.equal(state, 'mine');

    // Target mismatch or wrong target
    state = (await db.query(`select public.push_subscription_state('ep-pro', 'social') as state`)).rows[0].state;
    assert.equal(state, 'missing');

    // Other account session
    await db.query(`select set_config('test.actor', $1, false)`, [id(2)]);
    state = (await db.query(`select public.push_subscription_state('ep-pro', 'pro') as state`)).rows[0].state;
    assert.equal(state, 'other_account');
  } finally {
    await db.close();
  }
});

test('notification enqueue isolates delivery by app_target and both policy reaches both apps', async () => {
  const db = await createBaseFixture();
  try {
    // User 1 has both a social and a pro subscription
    await db.query(`
      insert into push_subscriptions(id, profile_id, endpoint, kind, p256dh, auth, app_target)
      values
        ($1, $3, 'endpoint-social-1', 'fcm', 'p', 'a', 'social'),
        ($2, $3, 'endpoint-pro-1', 'fcm', 'p', 'a', 'pro')
    `, [id(31), id(32), id(1)]);

    // 1. Social-only notification (e.g. 'message')
    const socialNotif = (await db.query(`
      insert into notifications(profile_id, kind, title, body)
      values($1, 'message', 'Yeni Mesaj', 'Selam') returning id
    `, [id(1)])).rows[0].id;

    let deliveries = (await db.query(`
      select subscription_id, app_target from push_delivery_attempts
      where notification_id = $1
    `, [socialNotif])).rows;

    assert.equal(deliveries.length, 1, 'Social notification must only generate 1 delivery attempt');
    assert.equal(deliveries[0].subscription_id, id(31));
    assert.equal(deliveries[0].app_target, 'social');

    // 2. Pro-only notification (e.g. 'expense_approval')
    const proNotif = (await db.query(`
      insert into notifications(profile_id, kind, title, body)
      values($1, 'expense_approval', 'Harcama Onayı', 'Masraf fişi onay bekliyor') returning id
    `, [id(1)])).rows[0].id;

    deliveries = (await db.query(`
      select subscription_id, app_target from push_delivery_attempts
      where notification_id = $1
    `, [proNotif])).rows;

    assert.equal(deliveries.length, 1, 'Pro notification must only generate 1 delivery attempt');
    assert.equal(deliveries[0].subscription_id, id(32));
    assert.equal(deliveries[0].app_target, 'pro');

    // 3. Both notification (e.g. 'attendance_reminder')
    const bothNotif = (await db.query(`
      insert into notifications(profile_id, kind, title, body)
      values($1, 'attendance_reminder', 'Yoklama', 'Yoklama giriniz') returning id
    `, [id(1)])).rows[0].id;

    deliveries = (await db.query(`
      select subscription_id, app_target from push_delivery_attempts
      where notification_id = $1 order by app_target
    `, [bothNotif])).rows;

    assert.equal(deliveries.length, 2, 'Both notification must generate 2 delivery attempts');
    assert.equal(deliveries[0].app_target, 'pro');
    assert.equal(deliveries[1].app_target, 'social');
  } finally {
    await db.close();
  }
});

test('dispatching push delivery transmits appTarget in HTTP body and validates target during retry', async () => {
  const db = await createBaseFixture();
  try {
    await db.query(`
      insert into push_subscriptions(id, profile_id, endpoint, kind, p256dh, auth, app_target)
      values ($1, $2, 'endpoint-pro-dispatch', 'fcm', 'p', 'a', 'pro')
    `, [id(41), id(1)]);

    // Pro notification
    const proNotif = (await db.query(`
      insert into notifications(profile_id, kind, title, body)
      values($1, 'referee_assignment', 'Hakem Görevi', 'Maç görevi atandı') returning id
    `, [id(1)])).rows[0].id;

    const delivery = (await db.query(`
      select * from push_delivery_attempts where notification_id = $1
    `, [proNotif])).rows[0];

    assert.equal(delivery.status, 'in_flight');
    assert.equal(delivery.app_target, 'pro');

    const req = (await db.query(`select * from net.requests where id = $1`, [delivery.request_id])).rows[0];
    assert.equal(req.body.appTarget, 'pro');
    assert.equal(req.body.url, '/operasyon/hakem-gorevleri');

    // Simulate temporary rejection to enter retry status
    await db.query(`
      insert into net._http_response(id, status_code, content)
      values($1, 200, $2)
    `, [delivery.request_id, JSON.stringify({ results: [{ status: 503, retryable: true, gone: false }] })]);

    await db.exec('select process_push_deliveries()');
    let updatedDelivery = (await db.query(`select * from push_delivery_attempts where id = $1`, [delivery.id])).rows[0];
    assert.equal(updatedDelivery.status, 'retry');

    // Now user switches subscription target from pro to social
    // When retry executes, it must detect target mismatch and skip!
    await db.query(`update push_subscriptions set app_target = 'social' where id = $1`, [id(41)]);
    await db.query(`update push_delivery_attempts set next_attempt_at = now() - interval '1 second' where id = $1`, [delivery.id]);

    await db.exec('select process_push_deliveries()');

    updatedDelivery = (await db.query(`select * from push_delivery_attempts where id = $1`, [delivery.id])).rows[0];
    assert.equal(updatedDelivery.status, 'skipped');
    assert.equal(updatedDelivery.last_outcome, 'target_mismatch');
  } finally {
    await db.close();
  }
});
