import {PGlite} from '@electric-sql/pglite';
import {readFile, readdir} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const sql = async name => readFile(new URL('../supabase/migrations/' + name, import.meta.url), 'utf8');
const id = n => `30000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
async function fixture() {
  const db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
    create table profiles(id uuid primary key references auth.users(id) on delete cascade);
    create table athletes(id uuid primary key, profile_id uuid references profiles(id) on delete set null);
    create table events(id uuid primary key); create table org_matches(id uuid primary key);
    create table feature_flags(key text primary key);
    create table club_memberships(club_id uuid,profile_id uuid references profiles(id) on delete cascade,role text,status text);
    grant usage on schema public,auth to anon,authenticated;`);
  const experience = await sql('0132_swan_identity_experience.sql');
  await db.exec(experience.slice(0, experience.indexOf('do $$ declare t')));
  const legacy = await sql('0012_security_reports.sql');
  await db.exec(legacy.slice(legacy.indexOf('create or replace function public.delete_my_account()')));
  // The historical RPC must reject anon even before the new migration.
  await db.exec('revoke all on function delete_my_account() from anon');
  for (const name of (await readdir(new URL('../supabase/migrations/', import.meta.url))).sort()) {
    if (name.endsWith('_account_deletion_lifecycle.sql')) await db.exec(await sql(name));
  }
  for (const n of [1,2]) {
    await db.query('insert into auth.users values($1)', [id(n)]);
    await db.query('insert into profiles values($1)', [id(n)]);
    await db.query('insert into athletes values($1,$2)', [id(n+10),id(n)]);
  }
  await db.query('insert into events values($1)', [id(20)]);
  return db;
}
async function actor(db, n, role='authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('test.actor',$1,false)", [n ? id(n) : '']);
  await db.exec(`set role ${role}`);
}
test('account deletion after kudos preserves receiver, badge and athlete history with anonymous sender', async () => {
  const db=await fixture(); try {
    await db.query("insert into team_kudos(event_id,sender_profile_id,receiver_athlete_id,badge,source) values($1,$2,$3,'fair_play','peer')",[id(20),id(1),id(12)]);
    await actor(db,1); await db.exec('select delete_my_account()'); await db.exec('reset role');
    assert.equal((await db.query('select * from auth.users where id=$1',[id(1)])).rows.length,0);
    assert.equal((await db.query('select profile_id from athletes where id=$1',[id(11)])).rows[0].profile_id,null);
    assert.equal((await db.query('select sender_profile_id from team_kudos')).rows[0].sender_profile_id,null);
    assert.equal((await db.query('select * from profiles where id=$1',[id(2)])).rows.length,1);
  } finally {await db.close();}
});
test('deleting an approver preserves another owner video, milestone and event preparation',async()=>{
  const db=await fixture(); try {
    await db.query("insert into showcase_videos(athlete_id,owner_profile_id,title,storage_path,duration_seconds,size_bytes,mime_type,guardian_approved_by,guardian_approved_at,club_verified_by,club_verified_at) values($1,$2,'Video','fixture/video',10,10,'video/mp4',$3,now(),$3,now())",[id(12),id(2),id(1)]);
    await db.query("insert into athlete_milestones(athlete_id,title,happened_at,created_by) values($1,'History',now(),$2)",[id(11),id(1)]);
    await db.query("insert into event_preparations(event_id,coach_note,updated_by) values($1,'Bring kit',$2)",[id(20),id(1)]);
    await actor(db,1); await db.exec('select delete_my_account()'); await db.exec('reset role');
    const v=(await db.query('select * from showcase_videos')).rows[0];
    assert.equal(v.owner_profile_id,id(2)); assert.equal(v.guardian_approved_by,null); assert.equal(v.club_verified_by,null);
    assert.ok(v.guardian_approved_at); assert.ok(v.club_verified_at);
    assert.equal((await db.query('select created_by from athlete_milestones')).rows[0].created_by,null);
    const prep=(await db.query('select * from event_preparations')).rows[0];
    assert.equal(prep.updated_by,null); assert.equal(prep.coach_note,'Bring kit');
  }finally{await db.close();}
});
test('only manager guard and anon/no-session rejection remain; another manager allows deletion',async()=>{
  const db=await fixture();try{
    await db.query("insert into club_memberships values($1,$2,'club_admin','active')",[id(30),id(1)]);
    await actor(db,1);await assert.rejects(db.exec('select delete_my_account()'),/tek yöneticis/i);
    await actor(db,null);await assert.rejects(db.exec('select delete_my_account()'),/Oturum/);
    await actor(db,2,'anon');await assert.rejects(db.exec('select delete_my_account()'),/permission/);
    await db.exec('reset role');await db.query("insert into club_memberships values($1,$2,'club_admin','active')",[id(30),id(2)]);
    await actor(db,1);await db.exec('select delete_my_account()');
  }finally{await db.close();}
});
