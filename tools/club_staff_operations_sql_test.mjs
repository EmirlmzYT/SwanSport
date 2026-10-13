import {setup as foundation} from './federation_console_sql_test.mjs';
import {apply,actor,call,id,officer,coach,child,club,other,guardian} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const migration=await readFile(new URL('../supabase/migrations/0114_club_inventory_and_equipment.sql',import.meta.url),'utf8');
async function owner(db,p=officer){await db.exec('reset role');await actor(db,p);}
async function auth(db,p){await owner(db,p);await db.exec('set role authenticated');}
async function setup(){const f=await foundation();try{await owner(f.db);
 const extended=(await readFile(new URL('../supabase/migrations/0003_extended.sql',import.meta.url),'utf8')).replaceAll('\r\n','\n');
 await f.db.exec(extended.slice(extended.indexOf('do $$ begin\n  create type public.attendance_status'),extended.indexOf('do $$ begin\n  create type public.fitness_status')));
 await f.db.exec(extended.slice(extended.indexOf('create table if not exists public.attendance'),extended.indexOf('-- injuries (medical)')));
 await f.db.exec(await readFile(new URL('../supabase/migrations/0014_performance.sql',import.meta.url),'utf8'));
 await f.db.exec('alter table development_goals add column test_name text,add column baseline_value numeric,add column target_value numeric');
 await apply(f.db,await readFile(new URL('../supabase/migrations/0091_development_report.sql',import.meta.url),'utf8'));
 await apply(f.db,migration);return f;}catch(e){await f.db.close();throw e;}}
test('0114 stock issue/return is retry-safe, scoped, checked and atomic with damage/missing accounting',async()=>{
 const {db}=await setup();try{
  await auth(db,coach);const item=id(1401),assignment=id(1402);
  await call(db,'inventory_add_item',[item,club,'Top','ball',5,'tenis']);
  assert.equal(await call(db,'inventory_add_item',[item,club,'Top','ball',5,'tenis']),item);
  await call(db,'inventory_assign',[assignment,item,3,coach]);
  assert.equal(await call(db,'inventory_assign',[assignment,item,3,coach]),assignment);
  await assert.rejects(call(db,'inventory_assign',[id(1403),item,3,coach]),/stok/);
  await assert.rejects(call(db,'inventory_assign',[id(1404),item,0,coach]),/pozitif/);
  await assert.rejects(call(db,'inventory_assign',[id(1405),item,1,id(75)]),/üyesi/);
  let board=await call(db,'club_inventory_board',[club]);assert.equal(board.items[0].available,2);
  assert.doesNotMatch(JSON.stringify(board),/SECRET_PHONE|SECRET_TC|full_name|first_name/);
  await call(db,'inventory_return',[assignment,'damaged']);await call(db,'inventory_return',[assignment,'damaged']);
  board=await call(db,'club_inventory_board',[club]);assert.equal(board.items[0].damaged_quantity,3);assert.equal(board.items[0].available,2);
  await assert.rejects(call(db,'inventory_return',[assignment,'returned']),/kapanmış/);
  await call(db,'inventory_assign',[id(1406),item,2,coach]);await call(db,'inventory_return',[id(1406),'missing']);
  assert.equal((await call(db,'club_inventory_board',[club])).items[0].available,0);
  await assert.rejects(db.query("insert into club_inventory_items(id,club_id,name,category,quantity) values($1,$2,'X','x',1)",[id(1407),club]),/permission/);
  await owner(db);await apply(db,migration);
 }finally{await db.close();}
});
test('0114 active kit/physician ordinary membership is required; doctor label alone is not medical permission',async()=>{
 const {db}=await setup();try{
  await owner(db,coach);await db.query("update club_memberships set role='parent',coach_level=null,team_id=null where profile_id=$1 and club_id=$2",[guardian,club]);
  await db.query("insert into club_staff_roles(club_id,profile_id,role) values($1,$2,'kit_manager')",[club,guardian]);
  await auth(db,guardian);await call(db,'inventory_add_item',[id(1420),club,'Yelek','kit',2]);
  const authority=(await db.query('select * from my_club_operations_authority()')).rows.find(r=>r.club_id===club);
  assert.equal(authority.inventory_write,true);assert.equal(authority.health_read,false);
  await owner(db,coach);await db.query("delete from club_staff_roles where profile_id=$1 and role='kit_manager'",[guardian]);
  await db.query("insert into club_staff_roles(club_id,profile_id,role) values($1,$2,'doctor')",[club,guardian]);
  await auth(db,guardian);await assert.rejects(call(db,'open_health_restriction',[child,'restricted']),/sağlık/);
  await owner(db,coach);await call(db,'set_health_officer',[club,guardian,true]);
  await auth(db,guardian);const restriction=await call(db,'open_health_restriction',[child,'restricted']);
  assert.equal(await call(db,'open_health_restriction',[child,'restricted']),restriction);
  assert.ok((await call(db,'club_health_operations',[club])).some(r=>r.restriction_id===restriction));
  await call(db,'clear_health_restriction',[restriction,'PRIVATE_DOCTOR_NARRATIVE']);
  await call(db,'clear_health_restriction',[restriction,'PRIVATE_DOCTOR_NARRATIVE']);
  await owner(db,coach);assert.doesNotMatch(JSON.stringify((await db.query('select audit_log from health_restrictions where id=$1',[restriction])).rows),/PRIVATE_DOCTOR_NARRATIVE/);
  await owner(db,coach);await db.query("update club_memberships set status='suspended' where profile_id=$1 and club_id=$2",[guardian,club]);
  await auth(db,guardian);await assert.rejects(call(db,'club_health_operations',[club]),/yetkisi/);
  await assert.rejects(call(db,'open_health_restriction',[child,'restricted']),/sağlık/);
 }finally{await db.close();}
});
test('0114 sporting director gets only scoped report/overview, not general performance or foreign club access',async()=>{
 const {db}=await setup();try{
  await owner(db,coach);await db.query("update club_memberships set role='parent',coach_level=null,team_id=null where profile_id=$1 and club_id=$2",[guardian,club]);
  await db.query("insert into club_staff_roles(club_id,profile_id,role) values($1,$2,'sporting_director')",[club,guardian]);
  await db.exec("update feature_flags set audience='everyone' where key='development_report'");
  await auth(db,guardian);const overview=await call(db,'club_sporting_overview',[club]);
  assert.ok(overview.athletes>0);assert.ok(Array.isArray(overview.teams));
  await assert.rejects(call(db,'club_sporting_overview',[other]),/Sportif/);
  assert.equal(await call(db,'can_view_athlete_performance',[id(92)]),false);
  const picker=await call(db,'development_report_athletes',['',0]);assert.ok(picker.athletes.some(a=>a.id===id(92)));
  const dates=(await db.query('select current_date as today')).rows[0].today;
  const report=await call(db,'athlete_development_report',[id(92),dates,dates]);assert.equal(report.athlete.id,id(92));
  assert.equal(report.attendance.rate,null);assert.doesNotMatch(JSON.stringify(report),/national_id|phone|diagnosis/);
  await assert.rejects(call(db,'athlete_development_report',[id(91),dates,dates]),/erişilemiyor/);
  await owner(db,coach);await db.query('delete from club_staff_roles where profile_id=$1',[guardian]);
  await auth(db,guardian);await assert.rejects(call(db,'athlete_development_report',[id(92),dates,dates]),/erişilemiyor/);
 }finally{await db.close();}
});
test('0114 audit failure rolls back issue/return and leaves stock unchanged',async()=>{
 const {db}=await setup();try{
  await auth(db,coach);await call(db,'inventory_add_item',[id(1430),club,'Forma','kit',5]);
  await owner(db);await db.exec("create function fail_inventory_audit() returns trigger language plpgsql as $$begin raise exception 'audit unavailable';end$$;create trigger fail_inventory before insert on club_inventory_audit for each row execute function fail_inventory_audit()");
  await auth(db,coach);await assert.rejects(call(db,'inventory_assign',[id(1431),id(1430),2,coach]),/audit unavailable/);
  assert.equal((await call(db,'club_inventory_board',[club])).items[0].available,5);
  await owner(db);await db.exec('drop trigger fail_inventory on club_inventory_audit');
  await auth(db,coach);await call(db,'inventory_assign',[id(1431),id(1430),2,coach]);
  await owner(db);await db.exec('create trigger fail_inventory before insert on club_inventory_audit for each row execute function fail_inventory_audit()');
  await auth(db,coach);await assert.rejects(call(db,'inventory_return',[id(1431),'missing']),/audit unavailable/);
  const b=await call(db,'club_inventory_board',[club]);assert.equal(b.items[0].missing_quantity,0);assert.equal(b.assignments[0].returned_at,null);
 }finally{await db.close();}
});
test('0114 pure accountant/outsider raw RLS and RPC access are closed; foreign team/club and anonymous writes fail',async()=>{
 const {db}=await setup();try{
  await auth(db,coach);await call(db,'inventory_add_item',[id(1410),club,'Forma','kit',10]);
  for(const p of [id(77),id(75)]){await auth(db,p);await assert.rejects(call(db,'club_inventory_board',[club]),/yetkisi/);
   assert.equal((await db.exec('select * from club_inventory_items'))[0].rows.length,0);
   await assert.rejects(call(db,'inventory_assign',[id(1411),id(1410),1,coach]),/sorumlusu/);}
  await owner(db);const t=(await db.query('select id from teams where club_id<>$1 limit 1',[club])).rows[0].id;
  await auth(db,coach);await assert.rejects(call(db,'inventory_assign',[id(1412),id(1410),1,null,t]),/aynı kulüpte/);
  await assert.rejects(call(db,'inventory_add_item',[id(1413),other,'X','x',1]),/sorumlusu/);
  await owner(db);await actor(db,null);await db.exec('set role anon');await assert.rejects(call(db,'club_inventory_board',[club]),/permission/);
 }finally{await db.close();}
});
test('0114 administrative rest blocks common eligibility/esame; removing it cannot clear a clinical restriction',async()=>{
 const {db,match}=await setup();try{
  await auth(db,coach);await call(db,'set_club_athlete_rest',[child,'rested']);
  assert.equal((await db.query('select * from eligibility_gate($1)',[child])).rows[0].blocked,true);
  await owner(db);await db.query('update athletes set license_expires_on=current_date-1 where id=$1',[child]);
  await auth(db,id(71));await assert.rejects(call(db,'referee_verify_lineup',[match,[child],[id(91)],null,[],[]]),/sağlık|İdari/);
  const candidate=(await db.query('select * from referee_lineup_candidates($1)',[match])).rows.find(r=>r.athlete_id===child);assert.equal(candidate.eligible,false);
  await owner(db);await db.query("update athletes set license_expires_on='2090-01-01' where id=$1",[child]);
  await auth(db,coach);await call(db,'set_club_athlete_rest',[child,'eligible']);
  assert.equal((await db.query('select * from eligibility_gate($1)',[child])).rows[0].blocked,false);
  await call(db,'set_health_officer',[club,coach,true]);await call(db,'open_health_restriction',[child,'restricted']);
  await call(db,'set_club_athlete_rest',[child,'rested']);await call(db,'set_club_athlete_rest',[child,'eligible']);
  assert.equal((await db.query('select * from eligibility_gate($1)',[child])).rows[0].blocked,true);
  await assert.rejects(call(db,'set_club_athlete_rest',[child,'injured_admin']),/hekim/);
  const board=await call(db,'club_health_operations',[club]);assert.ok(board.some(r=>r.athlete_id===child&&r.restriction_id));
  assert.doesNotMatch(JSON.stringify(board),/diagnosis|audit_log|evidence|phone|national_id/);
  await call(db,'set_health_officer',[club,coach,false]);
  const restriction=(await db.query('select id from health_restrictions where athlete_id=$1',[child])).rows[0].id;
  await assert.rejects(call(db,'clear_health_restriction',[restriction,'Administrative override']),/yetkili|sağlık/i);
 }finally{await db.close();}
});
