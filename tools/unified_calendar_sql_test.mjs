// Actual federation foundation migrations; isolated PostgreSQL WASM, never live SQL.
import { setup, apply, actor, id, coach, guardian, child, club, other, admin, officer }
  from './federation_foundation_sql_test.mjs';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';
const migration = await readFile(new URL('../supabase/migrations/0102_unified_calendar.sql', import.meta.url), 'utf8');
const publication = await readFile(new URL('../supabase/migrations/0097_federation_public_reads.sql', import.meta.url), 'utf8');
const training = await readFile(new URL('../supabase/migrations/0071_training_sessions.sql', import.meta.url), 'utf8');
const from = '2026-09-30T21:00:00Z', to = '2026-10-31T21:00:00Z';
async function calendar() {
  const f = await setup();
  try {
    await f.db.exec(`alter table events add column ends_at timestamptz, add column opponent text,
      add column home_score int, add column away_score int;
      create table faq_entries(question text,answer text,category text,audience text,sort_order int,route text);
      delete from club_memberships where profile_id='${guardian}';`);
    // Real 0071 config + protocol/session DDL, not a guessed stand-in schema.
    await f.db.exec(training.slice(training.indexOf('create or replace function public.valid_training_config'),
      training.indexOf('-- 4) Katılımcılar')));
    await f.db.exec(`insert into training_protocols(id,name,sport_code,config)
      values('${id(80)}','Technique','tenis','{"set_count":1,"units_per_set":1,"prep_seconds":0,
      "shoot_seconds":5,"collect_seconds":0,"rest_seconds":0,"max_unit_score":10,
      "entry_mode":"simple","mode":"technique"}');`);
    await apply(f.db, publication);
    await apply(f.db, migration);
    return f;
  } catch(e) { await f.db.close(); throw e; }
}
async function role(db, user, name='authenticated') {
  await db.exec('reset role'); await actor(db,user); await db.exec('set role '+name);
}
async function entries(db, selectedClub=null) {
  return (await db.query('select * from my_calendar_club_entries($1,$2,$3)',[from,to,selectedClub])).rows;
}
async function event(db,n,kind='training',team=null,selectedClub=club,time='2026-10-10T09:00Z') {
  await db.query('insert into events(id,club_id,team_id,title,kind,starts_at) values($1,$2,$3,$4,$5,$6)',
    [id(n),selectedClub,team,`Event ${n}`,kind,time]);
}
async function session(db,n,link=null,team=null,kind='club') {
  await db.query(`insert into training_sessions(id,club_id,protocol_id,kind,event_id,team_id,
    athlete_id,started_at,status,join_code) values($1,$2,$3,$4,$5,$6,$7,$8,'live',$9)`,
    [id(n),club,id(80),kind,link,team,kind==='personal'?child:null,'2026-10-10T10:00Z','SECRET'+n]);
}

test('calendar: idempotence, exact grants and anonymous source tables closed',async()=>{
  const {db}=await calendar();try {
    await apply(db,migration);
    assert.equal((await db.query('select count(*) n from faq_entries')).rows[0].n,1);
    const publicSig='public_federation_activities(text,text,uuid,date,date)';
    for(const [sig,anon,auth] of [[publicSig,true,true],
      ['my_calendar_club_entries(timestamptz,timestamptz,uuid)',false,true],
      ['_calendar_team_visible(uuid,uuid)',false,false]]) {
      const row=(await db.query("select has_function_privilege('anon',$1,'execute') a,has_function_privilege('authenticated',$1,'execute') u",[sig])).rows[0];
      assert.deepEqual(row,{a:anon,u:auth});
      assert.equal((await db.query("select count(*) n from pg_proc p cross join lateral aclexplode(p.proacl) x where p.oid=$1::regprocedure and x.grantee=0",[sig])).rows[0].n,0);
    }
    await role(db,'','anon');
    for(const table of ['organizations','org_matches','athletes','guardians','training_sessions','club_memberships','team_memberships'])
      await assert.rejects(db.query('select * from '+table),/permission denied/);
    await assert.rejects(entries(db),/permission denied/);
  } finally {await db.close();}
});

test('calendar: only explicitly public official programs, exact safe metadata and geographic/season/date filters',async()=>{
  const {db,org,match,office,national}=await calendar();try {
    const read=async(sport=null,city=null,season=null,start=null,end=null)=>
      (await db.query('select * from public_federation_activities($1,$2,$3,$4,$5)',[sport,city,season,start,end])).rows;
    assert.deepEqual(await read(),[]);
    await actor(db,officer);
    await db.query('select federation_publish_program($1,true)',[org]);
    await role(db,'','anon');
    let rows=await read();assert.equal(rows.length,2);
    assert.deepEqual(Object.keys(rows[0]).sort(),['id','program_id','is_match','federation_name','office_name','season_id','season_label','sport_code','city_code','title','kind','category','location','status','starts_at','ends_at','all_day'].sort());
    assert.ok(rows.some(r=>r.id===match && r.title.includes('Legal Club')));
    assert.deepEqual(await read('yuzme'),[]);assert.deepEqual(await read(null,'06'),[]);
    assert.deepEqual(await read(null,null,id(999)),[]);
    assert.deepEqual(await read(null,null,null,'2200-01-01','2200-02-01'),[]);
    await db.exec('reset role');await actor(db,coach);
    await db.query('select create_organization($1,$2,$3)',['Nonofficial','league',club]);
    await actor(db,admin);
    await db.query("select federation_appoint($1,$2,'program_publisher',current_date-1,current_date+365)",[national,officer]);
    await actor(db,officer);
    const season=(await db.query("select federation_open_season($1,'Calendar',date '2026-10-01',date '2026-10-31') v",[national])).rows[0].v;
    const nationalOrg=(await db.query("select federation_create_program($1,'National camp',null,date '2026-10-01',date '2026-10-03') v",[season])).rows[0].v;
    await db.query('select federation_publish_program($1,true)',[nationalOrg]);
    await role(db,'','anon');
    rows=await read('tenis','06',season,'2026-10-03','2026-10-04');
    assert.equal(rows.length,1);assert.equal(rows[0].id,nationalOrg);
    assert.equal(rows[0].starts_at.toISOString(),'2026-09-30T21:00:00.000Z');
    assert.equal(rows[0].ends_at.toISOString(),'2026-10-03T21:00:00.000Z');
    assert.deepEqual(await read(null,null,season,'2026-10-04','2026-10-05'),[]);
    await db.exec('reset role');await actor(db,officer);
    await db.query('select federation_publish_program($1,false)',[nationalOrg]);
    await role(db,'','anon');assert.deepEqual(await read(null,null,season),[]);
  } finally {await db.close();}
});

test('calendar: club events, matches and unlinked sessions merge once; personal sessions and secrets excluded',async()=>{
  const {db}=await calendar();try {
    await event(db,100);await event(db,101,'match');await event(db,102,'training',null,other);
    await session(db,110,id(100));await session(db,111);await session(db,112,null,null,'personal');
    await event(db,103,'training',null,club,'2026-09-30T20:59Z');
    await event(db,104,'training',null,club,from);
    await event(db,105,'training',null,club,to);
    await role(db,coach);
    const rows=await entries(db);assert.deepEqual(rows.map(r=>r.id),[id(104),id(100),id(101),id(111)]);
    assert.equal(rows.find(r=>r.id===id(100)).session_id,id(110));
    assert.equal(rows.find(r=>r.id===id(111)).kind,'training');
    for(const text of ['SECRET','join_code','athlete_id','national_id','Private Child']) assert.ok(!JSON.stringify(rows).includes(text));
    assert.deepEqual(await entries(db,other),[]);
    await db.query("select set_config('test.actor','',false)");await assert.rejects(entries(db),/Oturum/);
  } finally {await db.close();}
});

test('calendar: guardians see only linked child club/team; admin or accountant alone has no private bypass',async()=>{
  const {db}=await calendar();try {
    const team=(await db.query("select id from teams where club_id=$1 limit 1",[club])).rows[0].id;
    const hidden=(await db.query("insert into teams(club_id,name,sport_code) values($1,'Hidden','tenis') returning id",[club])).rows[0].id;
    await db.query('insert into team_memberships(team_id,athlete_id) values($1,$2)',[team,child]);
    await event(db,120,'training',team);await event(db,121,'match',hidden);await event(db,122);
    await event(db,123,'training',null,other);await session(db,124,null,team);
    await session(db,125,id(121),team); // Hidden event cannot leak through a visible session team.
    await session(db,126,null,hidden);
    await role(db,guardian);
    assert.deepEqual((await entries(db)).map(r=>r.id),[id(120),id(122),id(124)]);
    await role(db,admin);assert.deepEqual(await entries(db),[]);
    await role(db,officer);assert.deepEqual(await entries(db),[]);
    await role(db,coach);assert.ok((await entries(db)).some(r=>r.id===id(121)));
    await db.exec('reset role');await db.query("update club_memberships set status='suspended' where profile_id=$1",[coach]);
    await role(db,coach);assert.deepEqual(await entries(db),[]);
  } finally {await db.close();}
});

test('calendar: invalid private ranges fail explicitly',async()=>{
  const {db}=await calendar();try {
    await role(db,coach);
    for(const args of [[null,to],[to,from],[from,from],[from,'2030-01-01']])
      await assert.rejects(db.query('select * from my_calendar_club_entries($1,$2)',args),/aralık/);
  } finally {await db.close();}
});
