import { PGlite } from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

const migrationUrl = new URL(
  '../supabase/migrations/0135_pro_phase2_attendance_operations.sql',
  import.meta.url,
);
const migration = await readFile(migrationUrl, 'utf8');

async function setup() {
  const db = new PGlite();
  await db.exec(`
    create table public.feature_flags (
      key text primary key,
      audience text not null,
      label text not null,
      description text not null
    );
    create table public.faq_entries (
      question text not null,
      answer text not null,
      category text not null,
      audience text not null,
      sort_order int not null,
      route text,
      feature text,
      active boolean default true
    );
    create function public.require_faq_before_release()
    returns trigger language plpgsql as $$
    begin
      if new.audience in ('testers', 'everyone') and not exists (
        select 1 from public.faq_entries
        where feature = new.key and active
      ) then
        raise exception 'yardım gerekli';
      end if;
      return new;
    end
    $$;
    create trigger trg_faq_before_release
      before insert or update on public.feature_flags
      for each row execute function public.require_faq_before_release();
    insert into public.feature_flags(key, audience, label, description) values
      ('offline_attendance', 'off', 'Offline', 'Keep off'),
      ('coach_workspace', 'admins', 'Coach', 'Keep admins'),
      ('sport_training_sessions', 'admins', 'Training', 'Keep admins');
  `);
  return db;
}

async function apply(db) {
  await db.exec('begin');
  try {
    await db.exec(migration);
    await db.exec('commit');
  } catch (error) {
    await db.exec('rollback');
    throw error;
  }
}

test('0135 adds online attendance and help idempotently', async () => {
  const db = await setup();
  try {
    await apply(db);

    const flag = await db.query(
      "select audience from public.feature_flags where key='attendance_operations'",
    );
    assert.equal(flag.rows.length, 1);
    assert.equal(flag.rows[0].audience, 'everyone');

    const help = await db.query(
      "select route, audience from public.faq_entries where feature='attendance_operations'",
    );
    assert.equal(help.rows.length, 1);
    assert.equal(help.rows[0].route, '/attendance');
    assert.equal(help.rows[0].audience, 'club_staff');

    await db.exec(
      "update public.feature_flags set audience='off' where key='attendance_operations'",
    );
    await apply(db);
    const preserved = await db.query(
      "select audience from public.feature_flags where key='attendance_operations'",
    );
    assert.equal(preserved.rows[0].audience, 'off');
    const helpAfterRerun = await db.query(
      "select count(*)::int as count from public.faq_entries where feature='attendance_operations'",
    );
    assert.equal(helpAfterRerun.rows[0].count, 1);
  } finally {
    await db.close();
  }
});

test('0135 preserves existing rollout audiences', async () => {
  const db = await setup();
  try {
    await apply(db);
    const rows = await db.query(
      `select key, audience from public.feature_flags
       where key in ('offline_attendance', 'coach_workspace', 'sport_training_sessions')
       order by key`,
    );
    assert.deepEqual(rows.rows, [
      { key: 'coach_workspace', audience: 'admins' },
      { key: 'offline_attendance', audience: 'off' },
      { key: 'sport_training_sessions', audience: 'admins' },
    ]);
  } finally {
    await db.close();
  }
});

test('0135 changes no database authority', () => {
  assert.doesNotMatch(migration, /\b(?:grant|revoke)\b/i);
  assert.doesNotMatch(migration, /\bcreate\s+(?:or\s+replace\s+)?function\b/i);
  assert.doesNotMatch(migration, /\bcreate\s+policy\b/i);
  assert.doesNotMatch(migration, /\balter\s+table\b/i);
});
