// Actual foundation, medical, C1 and official result/guardian SQL through 0104 + 0110.
import {verify, sport} from './identity_membership_sql_test.mjs';
import {fixture as coachGuardianFixture} from './coach_guardian_sql_test.mjs';
import {apply, actor, call, id, admin, officer, coach, guardian, child, club, other}
  from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const sql = async n => readFile(new URL(`../supabase/migrations/${n}.sql`, import.meta.url), 'utf8');
const migration = await sql('0110_sports_role_hierarchy');
const projection = await sql('0111_match_lineup_projection');
const referee=id(71), president=id(72), rep=id(73), wrongCity=id(74), stranger=id(75), wrongSport=id(76), accountant=id(77);
const tables=['federation_roles','referee_profiles','match_officials','club_staff_roles','org_match_lineup_notes','match_lineup_approvals'];
test('0110 migration contract: timeout first, replay-safe tables/indexes, no open SELECT policy',()=>{
  assert.equal(migration.split(/\r?\n/)[0],"set local lock_timeout = '15s';");
  assert.equal((migration.match(/create table if not exists/g)||[]).length,6);
  assert.equal((migration.match(/create index if not exists/g)||[]).length,7);
  assert.doesNotMatch(migration,/using\s*\(\s*true\s*\)/i);
  for (const name of tables) assert.match(migration,new RegExp('create table if not exists public\\.'+name));
});

test('0111 projection: timeout, authenticated-only ACL, replay and exact eight-column contract',async()=>{
  const {db,match,assignment,participant}=await fixture(); try {
    assert.equal(projection.split(/\r?\n/)[0], "set local lock_timeout = '15s';");
    await owner(db); await apply(db,projection); await apply(db,projection);
    for (const role of ['anon','authenticated']) {
      const allowed=(await db.query("select has_function_privilege($1,'match_approved_lineups(uuid)','EXECUTE') v",[role])).rows[0].v;
      assert.equal(allowed,role==='authenticated');
    }
    await auth(db,referee); await call(db,'respond_match_assignment',[assignment,true]);
    await call(db,'referee_verify_lineup',[match,[child],null,'Signed']);
    const rows=(await db.query('select * from match_approved_lineups($1)',[match])).rows;
    assert.equal(rows.length,1); assert.equal(rows[0].side,'home');
    assert.equal(rows[0].participant_id,participant); assert.deepEqual(rows[0].starter_athlete_ids,[child]);
    assert.equal(rows[0].notes,'Signed'); assert.equal(rows[0].is_locked,true);
    assert.deepEqual(Object.keys(rows[0]).sort(),['participant_id','side','starter_athlete_ids','substitute_athlete_ids','verified_by','verified_at','is_locked','notes'].sort());
    assert.doesNotMatch(JSON.stringify(rows),/SECRET_|phone|national_id|decline_reason|name/);
    await owner(db); await actor(db,null); await db.exec('set role anon');
    await assert.rejects(db.query('select * from match_approved_lineups($1)',[match]),/permission/);
    await db.exec('reset role'); await db.exec('set role authenticated');
    await assert.rejects(db.query('select * from match_approved_lineups($1)',[match]),/Giriş/);
  } finally { await db.close(); }
});

test('0111 projection scope: own club/federation yes; assigned-only, revoked/inactive, foreign-city, accountant/admin no',async()=>{
  const {db,match,assignment}=await fixture(); try {
    await owner(db); await apply(db,projection);
    await auth(db,referee); await call(db,'respond_match_assignment',[assignment,true]);
    await call(db,'referee_verify_lineup',[match,[child],null]);
    for (const p of [coach,president,rep]) {
      await auth(db,p); assert.equal((await db.query('select * from match_approved_lineups($1)',[match])).rows.length,1);
    }
    for (const p of [stranger,wrongCity,wrongSport,accountant,admin]) {
      await auth(db,p); assert.equal((await db.query('select * from match_approved_lineups($1)',[match])).rows.length,0);
    }
    for (const status of ['assigned','declined','replaced']) {
      await owner(db); await db.query('update match_officials set status=$1 where id=$2',[status,assignment]);
      await auth(db,referee); assert.equal((await db.query('select * from match_approved_lineups($1)',[match])).rows.length,0);
    }
    await owner(db); await db.query("update match_officials set status='accepted' where id=$1",[assignment]);
    await db.query('update referee_profiles set is_active=false where profile_id=$1',[referee]);
    await auth(db,referee); assert.equal((await db.query('select * from match_approved_lineups($1)',[match])).rows.length,0);
    await owner(db); await db.query('update federation_roles set revoked_at=now() where profile_id=$1',[president]);
    await auth(db,president); assert.equal((await db.query('select * from match_approved_lineups($1)',[match])).rows.length,0);
    assert.equal((await db.query('select * from match_approved_lineups($1)',[id(999)])).rows.length,0);
  } finally { await db.close(); }
});

test('0111 club projection does not expose the other side; side comes from real match participants',async()=>{
  const {db,org,participant}=await fixture(); try {
    await owner(db); await apply(db,projection);
    const away=await call(db,'federation_add_participant',[org,other,null]);
    const match=await call(db,'federation_schedule_match',[org,participant,away,new Date(Date.now()+172800000).toISOString()]);
    const revision=(await db.query('select id from org_roster_revisions where participant_id=$1',[participant])).rows[0].id;
    // Trusted fixture insertion isolates projection semantics from lineup-writing tests.
    await db.query('insert into match_lineup_approvals(match_id,participant_id,roster_revision_id,starter_athlete_ids) values($1,$2,$4,$5),($1,$3,$4,$5)',[match,participant,away,revision,[child]]);
    await auth(db,coach); const own=(await db.query('select * from match_approved_lineups($1)',[match])).rows;
    assert.equal(own.length,1); assert.equal(own[0].side,'home');
    await auth(db,president); const all=(await db.query('select * from match_approved_lineups($1)',[match])).rows;
    assert.deepEqual(all.map(r=>r.side),['home','away']);
    await owner(db); const before=(await db.query('select * from match_lineup_approvals order by id')).rows;
    await apply(db,projection);
    assert.deepEqual((await db.query('select * from match_lineup_approvals order by id')).rows,before);
  } finally { await db.close(); }
});
async function owner(db, p=officer) { await db.exec('reset role'); await actor(db,p); }
async function auth(db,p) { await owner(db,p); await db.exec('set role authenticated'); }
export async function fixture() {
  const f=await coachGuardianFixture();
  try {
    const {db,match}=f;
    await owner(db);
    // Replace the old fixture's eligibility stub with the actual medical schema/RPCs.
    await db.exec('drop table health_restrictions');
    const health=await sql('0064_eligibility_gate');
    await db.exec(health.slice(health.indexOf('create table if not exists public.club_staff_permissions'),health.indexOf('-- 5) YÖNETİCİ')));
    await verify(db,guardian,'44444444440');
    await owner(db);
    for (const p of [referee,president,rep,wrongCity,stranger,wrongSport,accountant]) {
      await db.query('insert into auth.users(id) values($1)',[p]);
      await db.query("update profiles set full_name='Test Official',phone='SECRET_PHONE',national_id='SECRET_TC' where id=$1",[p]);
    }
    await apply(db,migration);
    const federation=(await db.query("select id from federations where sport_code='tenis'")).rows[0].id;
    await db.query("insert into federation_roles(federation_id,profile_id,role,city_code) values($1,$2,'president',null),($1,$3,'provincial_rep','34'),($1,$4,'provincial_rep','06')",[federation,president,rep,wrongCity]);
    await db.query("insert into referee_profiles(profile_id,license_number,badge_tier,sport_code,city_code) values($1,'REF-1','national','tenis','34'),($2,'REF-2','national','yuzme','34')",[referee,wrongSport]);
    const assignment=(await db.query("insert into match_officials(match_id,profile_id,duty,assigned_by) values($1,$2,'head_referee',$3) returning id",[match,referee,president])).rows[0].id;
    await db.query("insert into club_accountants(club_id,profile_id,status) values($1,$2,'active')",[club,accountant]);
    return {...f,federation,assignment};
  } catch(e) { await f.db.close(); throw e; }
}

test('0110 scope: dates, revocation, federation/sport/city checks, no self-assignment',async()=>{
  const {db,federation}=await fixture(); try {
    await auth(db,president); assert.equal(await call(db,'is_provincial_rep',['06','tenis']),true);
    assert.equal(await call(db,'is_federation_president',['yuzme']),false);
    await auth(db,rep); assert.equal(await call(db,'is_provincial_rep',['34','tenis']),true);
    assert.equal(await call(db,'is_provincial_rep',['06','tenis']),false);
    await assert.rejects(db.query("insert into federation_roles(federation_id,profile_id,role) values($1,$2,'president')",[federation,rep]),/permission/);
    for (const change of ["starts_on=(now() at time zone 'Europe/Istanbul')::date+1,ends_on=(now() at time zone 'Europe/Istanbul')::date+2","ends_on=(now() at time zone 'Europe/Istanbul')::date-1,starts_on=(now() at time zone 'Europe/Istanbul')::date-2","revoked_at=now()"]) {
      await owner(db); await db.exec('begin');
      await db.query('update federation_roles set '+change+' where profile_id=$1',[president]);
      await auth(db,president); assert.equal(await call(db,'is_federation_president',['tenis']),false);
      await db.exec('rollback');
    }
    await owner(db);
    for (const [role,city] of [['president','34'],['provincial_rep',null]])
      await assert.rejects(db.query('insert into federation_roles(federation_id,profile_id,role,city_code) values($1,$2,$3,$4)',[federation,stranger,role,city]),/check/);
  } finally { await db.close(); }
});

test('0110 RLS private rows: own referee/reason, club note only, foreign city and accountant denied',async()=>{
  const {db,match,assignment}=await fixture(); try {
    await auth(db,coach); await call(db,'set_match_lineup_note',[match,child,'rested','Operational rest']);
    await auth(db,referee); assert.equal((await db.query('select * from org_match_lineup_notes')).rows.length,1);
    await call(db,'respond_match_assignment',[assignment,false,'PRIVATE_REASON']);
    assert.equal((await db.query('select decline_reason from match_officials')).rows[0].decline_reason,'PRIVATE_REASON');
    for (const p of [stranger,wrongCity,accountant,admin]) {
      await auth(db,p);
      assert.equal((await db.query('select * from org_match_lineup_notes')).rows.length,0);
      assert.equal((await db.query('select * from match_officials')).rows.length,0);
      await assert.rejects(call(db,'referee_lineup_card',[match]),/görevi/);
    }
    await auth(db,coach); assert.equal((await db.query('select * from match_officials')).rows.length,0);
    assert.equal((await db.query('select * from org_match_lineup_notes')).rows.length,1);
    await auth(db,rep); assert.equal((await db.query('select * from match_officials')).rows.length,1);
  } finally { await db.close(); }
});

test('0110 public projection: only accepted name/duty and only published matches',async()=>{
  const {db,match,assignment,org}=await fixture(); try {
    await auth(db,referee); await call(db,'respond_match_assignment',[assignment,true]);
    await owner(db); await db.query("insert into match_officials(match_id,profile_id,duty,status,decline_reason) values($1,$2,'observer','declined','PRIVATE_REASON')",[match,stranger]);
    await actor(db,null); await db.exec('set role anon');
    assert.equal((await db.query('select * from accepted_match_officials($1)',[match])).rows.length,0);
    await assert.rejects(db.query('select * from match_officials'),/permission/);
    await owner(db); await call(db,'federation_publish_program',[org,true]);
    await actor(db,null); await db.exec('set role anon');
    const rows=(await db.query('select * from accepted_match_officials($1)',[match])).rows;
    assert.deepEqual(rows,[{name:'Test Official',duty:'head_referee'}]);
    assert.doesNotMatch(JSON.stringify(rows),/PRIVATE_REASON|SECRET_PHONE|SECRET_TC|license|profile_id/);
  } finally { await db.close(); }
});

test('0110 assignment response: NULL/wrong actor/replaced/inactive/wrong sport blocked, accepted idempotent',async()=>{
  const {db,match,assignment}=await fixture(); try {
    await auth(db,stranger); await assert.rejects(call(db,'respond_match_assignment',[assignment,true]),/erişilemez/);
    await auth(db,referee); await assert.rejects(call(db,'respond_match_assignment',[assignment,null]),/geçersiz/);
    await owner(db); await db.query('update referee_profiles set is_active=false where profile_id=$1',[referee]);
    await auth(db,referee); await assert.rejects(call(db,'respond_match_assignment',[assignment,true]),/branş/);
    await owner(db); await db.query('update referee_profiles set is_active=true where profile_id=$1',[referee]);
    const wrong=(await db.query("insert into match_officials(match_id,profile_id,duty) values($1,$2,'table_official') returning id",[match,wrongSport])).rows[0].id;
    await auth(db,wrongSport); await assert.rejects(call(db,'respond_match_assignment',[wrong,true]),/branş/);
    await auth(db,referee); await call(db,'respond_match_assignment',[assignment,true]);
    const first=(await db.query('select responded_at from match_officials where id=$1',[assignment])).rows[0].responded_at;
    await call(db,'respond_match_assignment',[assignment,true]);
    assert.deepEqual((await db.query('select responded_at from match_officials where id=$1',[assignment])).rows[0].responded_at,first);
    await owner(db); await db.query("update match_officials set status='replaced' where id=$1",[assignment]);
    await auth(db,referee); await assert.rejects(call(db,'respond_match_assignment',[assignment,true]),/kapanmış/);
  } finally { await db.close(); }
});

test('0110 esame: accepted head/table only; arrays validated; match-scoped immutable snapshot, C1 preserved',async()=>{
  const {db,match,assignment,participant,org}=await fixture(); try {
    const before=(await db.query('select * from org_roster_revisions order by id')).rows;
    await auth(db,referee); await assert.rejects(call(db,'referee_verify_lineup',[match,[child],null]),/görevi/);
    await call(db,'respond_match_assignment',[assignment,true]);
    for (const roster of [null,[],[null],[child,child],[stranger]])
      await assert.rejects(call(db,'referee_verify_lineup',[match,roster,null]));
    await assert.rejects(call(db,'referee_verify_lineup',[match,[child],null,null,[child],[]]),/geçersiz/);
    await call(db,'referee_verify_lineup',[match,[child],null]);
    assert.equal((await db.query('select count(*)::int n from match_lineup_approvals')).rows[0].n,1);
    await assert.rejects(call(db,'referee_verify_lineup',[match,[child],null]),/kilitli/);
    await assert.rejects(call(db,'respond_match_assignment',[assignment,false,'late']),/kilitli/);
    await owner(db);
    assert.deepEqual((await db.query('select * from org_roster_revisions order by id')).rows,before);
    await assert.rejects(db.query('update match_lineup_approvals set is_locked=false'),/değiştirilemez/);
    await assert.rejects(db.query('delete from match_lineup_approvals'),/değiştirilemez/);
    const second=await call(db,'federation_schedule_match',[org,participant,null,new Date(Date.now()+172800000).toISOString()]);
    await auth(db,referee); await assert.rejects(call(db,'referee_verify_lineup',[second,[child],null]),/görevi/);
    assert.equal((await db.query('select * from match_lineup_approvals where match_id=$1',[second])).rows.length,0);
    await owner(db); await db.query('delete from auth.users where id=$1',[referee]);
    assert.equal((await db.query('select verified_by from match_lineup_approvals')).rows[0].verified_by,null);
  } finally { await db.close(); }
});

test('0110 medical flexibility: doctorless rest works; health/disciplinary locks cannot be downgraded',async()=>{
  const {db,match}=await fixture(); try {
    await auth(db,coach); await call(db,'set_match_lineup_note',[match,child,'injured_admin','Rest']);
    await call(db,'set_match_lineup_note',[match,child,'eligible']);
    await assert.rejects(call(db,'set_match_lineup_note',[match,child,'injured_medical']),/sağlık/);
    await owner(db); await db.query('insert into club_staff_permissions(club_id,profile_id,can_verify_medical) values($1,$2,true)',[club,guardian]);
    await auth(db,coach); await assert.rejects(call(db,'set_match_lineup_note',[match,child,'injured_admin']),/Sakatlık/);
    await call(db,'set_match_lineup_note',[match,child,'rested']);
    await auth(db,guardian); await call(db,'set_match_lineup_note',[match,child,'injured_medical']);
    await assert.rejects(call(db,'set_match_lineup_note',[match,child,'suspended']),/Disiplin/);
    await auth(db,coach); await assert.rejects(call(db,'set_match_lineup_note',[match,child,'eligible']),/Tıbbi/);
    await auth(db,president); await assert.rejects(call(db,'set_match_lineup_note',[match,child,'rested']),/Tıbbi/);
    await auth(db,guardian); const restriction=await call(db,'open_health_restriction',[child,'restricted']);
    await assert.rejects(call(db,'set_match_lineup_note',[match,child,'eligible']),/sağlık kısıtı/);
    await call(db,'clear_health_restriction',[restriction,'Medical review completed']);
    await call(db,'set_match_lineup_note',[match,child,'eligible']);
    await auth(db,president); await call(db,'set_match_lineup_note',[match,child,'suspended']);
    await auth(db,guardian); await assert.rejects(call(db,'set_match_lineup_note',[match,child,'injured_medical']),/Disiplin/);
    await auth(db,coach); await assert.rejects(call(db,'set_match_lineup_note',[match,child,'eligible']),/Disiplin/);
  } finally { await db.close(); }
});

test('0110 rejects assistant/observer, wrong club, expired license, C1 failure and medical exclusion',async()=>{
  const {db,match,assignment}=await fixture(); try {
    await auth(db,referee); await call(db,'respond_match_assignment',[assignment,true]);
    for (const duty of ['assistant_referee_1','observer']) {
      await owner(db); await db.query('update match_officials set duty=$1 where id=$2',[duty,assignment]);
      await auth(db,referee); await assert.rejects(call(db,'referee_verify_lineup',[match,[child],null]),/görevi/);
    }
    await owner(db); await db.query("update match_officials set duty='head_referee' where id=$1",[assignment]);
    for (const mutation of [
      "update athlete_sport_registrations set expires_on=current_date-1",
      "update profile_credentials set status='rejected' where profile_id='"+guardian+"' and kind='identity'",
      "update athlete_sport_registrations set club_id='"+other+"'",
    ]) {
      await owner(db,mutation.includes('profile_credentials') ? admin : officer);
      await db.exec('begin'); await db.exec(mutation);
      await auth(db,referee); await assert.rejects(call(db,'referee_verify_lineup',[match,[child],null]));
      await db.exec('rollback');
    }
    await auth(db,coach); await call(db,'set_match_lineup_note',[match,child,'rested']);
    await auth(db,referee); await assert.rejects(call(db,'referee_verify_lineup',[match,[child],null]),/kısıt/);
    await owner(db); assert.equal((await db.query('select count(*)::int n from match_lineup_approvals')).rows[0].n,0);
  } finally { await db.close(); }
});

test('0110 validates both sides before atomic insertion and audit failure rolls back the lock',async()=>{
  const {db,org,participant,match,assignment}=await fixture(); try {
    await auth(db,referee); await call(db,'respond_match_assignment',[assignment,true]);
    await owner(db);
    const away=await call(db,'federation_add_participant',[org,other,null]);
    const second=await call(db,'federation_schedule_match',[org,participant,away,new Date(Date.now()+172800000).toISOString()]);
    await db.query("insert into match_officials(match_id,profile_id,duty,status) values($1,$2,'table_official','accepted')",[second,referee]);
    await auth(db,referee); await assert.rejects(call(db,'referee_verify_lineup',[second,[child],[child]]));
    await owner(db); assert.equal((await db.query('select count(*)::int n from match_lineup_approvals')).rows[0].n,0);
    await db.exec(`create function test_fail_lineup_audit() returns trigger language plpgsql as $$begin
      if new.action='match_lineup_verified' then raise exception 'test audit failure'; end if; return new; end$$;
      create trigger test_fail_lineup_audit before insert on federation_audit for each row execute function test_fail_lineup_audit();`);
    await auth(db,referee); await assert.rejects(call(db,'referee_verify_lineup',[match,[child],null]),/test audit failure/);
    await owner(db); assert.equal((await db.query('select count(*)::int n from match_lineup_approvals')).rows[0].n,0);
  } finally { await db.close(); }
});

test('0110 allowlisted referee card masks child without consent, private data never projected',async()=>{
  const {db,match,assignment}=await fixture(); try {
    await auth(db,referee); await call(db,'respond_match_assignment',[assignment,true]);
    const hidden=(await db.query('select * from referee_lineup_card($1)',[match])).rows;
    assert.equal(hidden[0].name,null);
    assert.deepEqual(Object.keys(hidden[0]).sort(),['jersey_number','license_expires_on','license_number','name','side']);
    await auth(db,guardian); await call(db,'set_athlete_publicity',[child,true]);
    await auth(db,referee); const visible=(await db.query('select * from referee_lineup_card($1)',[match])).rows;
    assert.equal(visible[0].name,'Private Child');
    assert.doesNotMatch(JSON.stringify(visible),/national_id|phone|SECRET_|medical|guardian/);
    await auth(db,guardian); await call(db,'set_athlete_publicity',[child,false]);
    await auth(db,referee); assert.equal((await db.query('select * from referee_lineup_card($1)',[match])).rows[0].name,null);
  } finally { await db.close(); }
});

test('0110 repeat migration retains data, RLS/ACL closed, no overloaded verify, immutable rejection atomic',async()=>{
  const {db,match,assignment}=await fixture(); try {
    await auth(db,referee); await call(db,'respond_match_assignment',[assignment,true]);
    await call(db,'referee_verify_lineup',[match,[child],null]);
    await owner(db); const before=(await db.query('select * from match_lineup_approvals')).rows;
    await apply(db,migration);
    assert.deepEqual((await db.query('select * from match_lineup_approvals')).rows,before);
    for (const table of tables) {
      assert.equal((await db.query("select has_table_privilege('anon',$1,'SELECT') v",[table])).rows[0].v,false);
      assert.equal((await db.query("select has_table_privilege('authenticated',$1,'INSERT') v",[table])).rows[0].v,false);
      assert.equal((await db.query("select relrowsecurity from pg_class where oid=$1::regclass",[table])).rows[0].relrowsecurity,true);
    }
    assert.equal((await db.query("select count(*)::int n from pg_proc where proname='referee_verify_lineup'")).rows[0].n,1);
    for (const signature of ['referee_verify_lineup(uuid,uuid[],uuid[],text,uuid[],uuid[])','my_referee_matches(text)','_sports_roster_validate(uuid,uuid[],uuid[])'])
      assert.equal((await db.query("select has_function_privilege('anon',$1,'EXECUTE') v",[signature])).rows[0].v,false);
    await auth(db,coach); assert.equal((await db.query('select * from match_lineup_approvals')).rows.length,1);
    await assert.rejects(db.exec('delete from match_lineup_approvals'),/permission/);
    await assert.rejects(call(db,'set_match_lineup_note',[match,child,'rested']),/kilitli/);
    await owner(db); assert.equal((await db.query("select count(*)::int n from federation_audit where action='match_lineup_verified'")).rows[0].n,1);
  } finally { await db.close(); }
});

test('0110 starters/substitutes freeze separately; later tournament roster does not alter either match',async()=>{
  const {db,match,assignment,participant}=await fixture(); try {
    const bench=id(80);
    await owner(db,coach);
    await db.query("insert into athletes(id,club_id,first_name,last_name,birth_date) values($1,$2,'Bench','Athlete',current_date-interval '25 years')",[bench,club]);
    await owner(db);
    await call(db,'federation_register_license',[bench,'tenis','BENCH-1','2090-01-01']);
    await auth(db,coach);
    await call(db,'federation_publish_roster',[participant,[child,bench],'bench available',1]);
    await auth(db,referee); await call(db,'respond_match_assignment',[assignment,true]);
    await call(db,'referee_verify_lineup',[match,[child],null,'Signed',[bench],[]]);
    const saved=(await db.query('select starter_athlete_ids,substitute_athlete_ids,roster_revision_id from match_lineup_approvals')).rows;
    assert.deepEqual(saved[0].starter_athlete_ids,[child]);assert.deepEqual(saved[0].substitute_athlete_ids,[bench]);
    await auth(db,coach); await call(db,'federation_publish_roster',[participant,[child],'later match roster',2]);
    await auth(db,referee);
    assert.deepEqual((await db.query('select starter_athlete_ids,substitute_athlete_ids,roster_revision_id from match_lineup_approvals')).rows,saved);
    assert.equal((await db.query('select * from referee_lineup_card($1)',[match])).rows.length,2);
  } finally { await db.close(); }
});

test('0110 away club reads accepted officials, not home club private lineup notes/reasons',async()=>{
  const {db,org,participant}=await fixture(); try {
    await verify(db,stranger,'55555555550'); await sport(db,stranger,'tenis','coach','2090-01-01',3);
    await verify(db,officer,'66666666660');
    await owner(db);
    await db.query("insert into club_memberships(club_id,profile_id,role,coach_level) values($1,$2,'coach',3)",[other,stranger]);
    const away=await call(db,'federation_add_participant',[org,other,null]);
    const match=await call(db,'federation_schedule_match',[org,participant,away,new Date(Date.now()+172800000).toISOString()]);
    await db.query("insert into match_officials(match_id,profile_id,duty,status) values($1,$2,'head_referee','accepted')",[match,referee]);
    await auth(db,coach); await call(db,'set_match_lineup_note',[match,child,'rested','Home private reason']);
    await auth(db,stranger);
    assert.equal((await db.query('select * from org_match_lineup_notes')).rows.length,0);
    assert.equal((await db.query('select * from match_officials')).rows.length,0);
    assert.deepEqual((await db.query('select * from accepted_match_officials($1)',[match])).rows,[{name:'Test Official',duty:'head_referee'}]);
  } finally { await db.close(); }
});
