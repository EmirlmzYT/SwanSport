import {fixture} from './referee_cockpit_sql_test.mjs';
import {apply,actor,call,id,officer,child,admin,club,coach} from './federation_foundation_sql_test.mjs';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const migration=await readFile(new URL('../supabase/migrations/0113_federation_console_engine.sql',import.meta.url),'utf8');
async function owner(db,p=officer){await db.exec('reset role');await actor(db,p);}
async function auth(db,p){await owner(db,p);await db.exec('set role authenticated');}
export async function setup(){const f=await fixture();try{await owner(f.db);
 const finance=await readFile(new URL('../supabase/migrations/0030_expenses.sql',import.meta.url),'utf8');
 await f.db.exec(finance.slice(finance.indexOf('create or replace function public.athlete_ref'),finance.indexOf('/* Gelir–gider')));
 const search=await readFile(new URL('../supabase/migrations/0048_tr_search.sql',import.meta.url),'utf8');
 await f.db.exec(search.slice(search.indexOf('create or replace function public.tr_fold'),search.indexOf('-- Mevcut arama')));
 const extended=await readFile(new URL('../supabase/migrations/0003_extended.sql',import.meta.url),'utf8');
 await f.db.exec(extended.slice(extended.indexOf('create table if not exists public.facilities'),extended.indexOf('-- documents')));
 await f.db.exec('alter table events add column ends_at timestamptz,add column facility_id uuid references facilities(id),add column status text default \'scheduled\'; create table invoices(id uuid primary key)');
 const reservations=await readFile(new URL('../supabase/migrations/0108_facility_reservation_conflicts.sql',import.meta.url),'utf8');
 await f.db.exec(reservations.slice(reservations.indexOf('create table if not exists public.facility_reservations'),reservations.indexOf('create index if not exists idx_facility_reservations_facility_starts')));
 await apply(f.db,migration);return f;}catch(e){await f.db.close();throw e;}}
test('0113 scope, redacted excuses, raw RLS, assignment authority/license and replay',async()=>{
 const {db,match}=await setup();try{
  await owner(db);await db.query("update match_officials set status='declined',decline_reason='PRIVATE_EXCUSE' where match_id=$1",[match]);
  await auth(db,id(73));const redacted=await call(db,'federation_console_matches',[]);
  assert.ok(redacted.rows.some(r=>r.id===match));assert.doesNotMatch(JSON.stringify(redacted),/PRIVATE_EXCUSE/);
  assert.equal((await db.query('select * from match_officials where match_id=$1',[match])).rows.length,0);
  await assert.rejects(call(db,'assign_match_official',[match,id(71),'head_referee']),/Başkan/);
  for(const p of [id(75),id(74),id(76),admin]){await auth(db,p);assert.equal((await call(db,'federation_console_matches',[])).total,0);}
  await auth(db,id(72));assert.match(JSON.stringify(await call(db,'federation_console_matches',[])),/PRIVATE_EXCUSE/);
  const assignment=await call(db,'assign_match_official',[match,id(71),'head_referee']);
  assert.equal(await call(db,'assign_match_official',[match,id(71),'head_referee']),assignment);
  await assert.rejects(call(db,'assign_match_official',[match,id(75),'observer']),/lisansı/);
  await assert.rejects(call(db,'assign_match_official',[match,id(71),'observer']),/ikinci/);
  await owner(db);await apply(db,migration);
  assert.equal((await db.query("select count(*)::int n from federation_audit where action='match_official_assigned'")).rows[0].n,1);
  await auth(db,id(73));await assert.rejects(db.exec('select * from disciplinary_decisions'),/permission/);
 }finally{await db.close();}
});
test('0113 active MHK may assign; disciplinary member cannot, revoked scope and wrong-branch licenses fail',async()=>{
 const {db,match,federation}=await setup();try{
  await owner(db);await db.query("insert into federation_roles(federation_id,profile_id,role) values($1,$2,'referee_committee'),($1,$3,'disciplinary_board')",[federation,id(75),id(77)]);
  await auth(db,id(77));await assert.rejects(call(db,'assign_match_official',[match,id(76),'observer']),/Başkan/);
  await auth(db,id(75));await assert.rejects(call(db,'assign_match_official',[match,id(76),'observer']),/lisansı/);
  assert.ok((await db.query('select * from federation_available_referees($1)',[match])).rows.some(r=>r.profile_id===id(71)));
  await owner(db);await db.query("update match_officials set status='declined' where match_id=$1",[match]);
  await auth(db,id(75));await call(db,'assign_match_official',[match,id(71),'head_referee']);
  await owner(db);await db.query('update federation_roles set revoked_at=now() where profile_id=$1',[id(75)]);
  await auth(db,id(75));assert.equal((await call(db,'federation_console_matches',[])).total,0);
  await assert.rejects(call(db,'assign_match_official',[match,id(71),'head_referee']),/Başkan/);
  for(const signature of ['federation_console_scopes()','federation_console_matches(text,integer,text,timestamptz,timestamptz)',
    'assign_match_official(uuid,uuid,text)','record_disciplinary_decision(uuid,uuid,uuid,text,text,integer,integer,numeric)']){
   await owner(db);assert.equal((await db.query("select has_function_privilege('anon',$1,'EXECUTE') ok",[signature])).rows[0].ok,false);
  }
  await auth(db,id(75));await assert.rejects(call(db,'_disciplinary_suspended',[child,'tenis']),/permission/);
 }finally{await db.close();}
});
test('0113 audit rejection rolls back assignment and notification; pagination/search filters run on server',async()=>{
 const {db,match}=await setup();try{
  await owner(db);await db.query("update match_officials set status='declined' where match_id=$1",[match]);
  const before=(await db.query('select count(*)::int n from notifications')).rows[0].n;
  await db.exec("create function console_fail_audit() returns trigger language plpgsql as $$begin if new.action='match_official_assigned' then raise exception 'audit unavailable';end if;return new;end$$;create trigger console_fail before insert on federation_audit for each row execute function console_fail_audit()");
  await auth(db,id(72));await assert.rejects(call(db,'assign_match_official',[match,id(71),'head_referee']),/audit unavailable/);
  await owner(db);assert.equal((await db.query('select status from match_officials where match_id=$1',[match])).rows[0].status,'declined');
  assert.equal((await db.query('select count(*)::int n from notifications')).rows[0].n,before);
  await auth(db,id(73));assert.equal((await call(db,'federation_console_matches',['06'])).total,0);
  const all=await call(db,'federation_console_matches',[]);assert.ok(all.total>0);
  assert.equal((await call(db,'federation_console_matches',[null,50])).rows.length,0);
  assert.equal((await call(db,'federation_console_matches',[null,0,'not a real league'])).total,0);
  assert.equal((await call(db,'federation_console_matches',[null,0,'','2099-01-01',null])).total,0);
 }finally{await db.close();}
});
test('0113 signed reports, atomic immutable decisions, idempotency and future esame sanction',async()=>{
 const {db,match,org,participant,away}=await setup();try{
  await auth(db,id(71));await call(db,'referee_verify_lineup',[match,[child],[id(91)],null,[id(92),id(93)],[]]);
  for(let s=0;s<2;s++){for(let g=0;g<6;g++){
   const st=await call(db,'referee_match_state',[match]);await call(db,'referee_append_match_event',[match,id(1000+s*10+g),st.version,'score','home']);}
   const st=await call(db,'referee_match_state',[match]);await call(db,'referee_append_match_event',[match,id(1100+s),st.version,'period_end']);}
  const st=await call(db,'referee_match_state',[match]);await call(db,'referee_submit_match_report',[match,id(1200),st.version,'PRIVATE_INCIDENT']);
  await auth(db,id(73));assert.equal((await call(db,'federation_disciplinary_reports',[])).total,0);
  assert.equal(await call(db,'federation_locked_match_report',[match]),null);
  await auth(db,id(72));const reports=await call(db,'federation_disciplinary_reports',[]);assert.match(JSON.stringify(reports),/PRIVATE_INCIDENT/);
  assert.equal((await call(db,'federation_locked_match_report',[match])).notes,'PRIVATE_INCIDENT');
  assert.doesNotMatch(JSON.stringify(reports),/national_id|phone|diagnosis/);
  const args=[match,child,id(1201),'match_ban','Decision',2,null,null];
  const decision=await call(db,'record_disciplinary_decision',args);assert.equal(await call(db,'record_disciplinary_decision',args),decision);
  await assert.rejects(call(db,'record_disciplinary_decision',[...args.slice(0,4),'changed',2,null,null]),/kimliği/);
  await owner(db);await db.query("insert into federation_roles(federation_id,profile_id,role) select federation_id,$1,'referee_committee' from federation_roles where profile_id=$2",[id(75),id(72)]);
  await auth(db,id(75));assert.equal((await call(db,'federation_locked_match_report',[match])).notes,'PRIVATE_INCIDENT');
  await assert.rejects(call(db,'record_disciplinary_decision',[match,id(92),id(1220),'warning','No']),/Disiplin/);
  await owner(db);await db.exec("create function decision_fail_audit() returns trigger language plpgsql as $$begin if new.action='disciplinary_decision' then raise exception 'decision audit unavailable';end if;return new;end$$;create trigger decision_fail before insert on federation_audit for each row execute function decision_fail_audit()");
  await auth(db,id(72));await assert.rejects(call(db,'record_disciplinary_decision',[match,id(92),id(1221),'rights_ban','Rights',null,1,null]),/audit unavailable/);
  await owner(db);assert.equal((await db.query('select count(*)::int n from disciplinary_decisions')).rows[0].n,1);
  await db.exec('drop trigger decision_fail on federation_audit');await auth(db,id(72));
  await assert.rejects(call(db,'record_disciplinary_decision',[match,id(92),id(1222),'rights_ban','Rights',null,13,null]),/check/);
  await call(db,'record_disciplinary_decision',[match,id(92),id(1223),'rights_ban','Rights',null,1,null]);
  await assert.rejects(call(db,'record_disciplinary_decision',[match,id(91),id(1224),'fine','Fine',null,null,0]),/check/);
  await call(db,'record_disciplinary_decision',[match,id(91),id(1225),'fine','Fine',null,null,100]);
  await call(db,'record_disciplinary_decision',[match,id(93),id(1226),'warning','Warning']);
  await owner(db);assert.equal(await call(db,'_disciplinary_suspended',[child,'tenis']),true);
  assert.equal(await call(db,'_disciplinary_suspended',[child,'yuzme']),false);
  assert.equal(await call(db,'_disciplinary_suspended',[id(92),'tenis']),true);
  assert.equal(await call(db,'_disciplinary_suspended',[id(91),'tenis']),false);
  assert.equal(await call(db,'_disciplinary_suspended',[id(93),'tenis']),false);
  await owner(db);await assert.rejects(db.exec('delete from disciplinary_decisions'),/değiştirilemez/);
  const next=await call(db,'federation_schedule_match',[org,participant,away,new Date(Date.now()+259200000).toISOString()]);
  await db.query("insert into match_officials(match_id,profile_id,duty,status) values($1,$2,'head_referee','accepted')",[next,id(71)]);
  await auth(db,id(71));await assert.rejects(call(db,'referee_verify_lineup',[next,[child],[id(91)],null,[],[]]),/suspended/);
  assert.equal((await db.query('select * from match_lineup_approvals where match_id=$1',[next])).rows.length,0);
  const candidates=(await db.query('select * from referee_lineup_candidates($1)',[next])).rows;
  assert.equal(candidates.find(r=>r.athlete_id===child).eligible,false);
  assert.equal(candidates.find(r=>r.athlete_id===child).eligibility_status,'suspended');
 }finally{await db.close();}
});
test('0113 facility conflicts use club-authorized official allocation, not event copies/text/private reservation contents',async()=>{
 const {db,match}=await setup();try{
  await owner(db);await db.query("insert into facilities(id,club_id,name) values($1,$2,'Official Court')",[id(1300),club]);
  const starts=(await db.query('select starts_at from org_matches where id=$1',[match])).rows[0].starts_at;
  await auth(db,id(72));await assert.rejects(call(db,'allocate_official_match_facility',[match,id(1300),new Date(new Date(starts).getTime()+7200000).toISOString()]),/Tesis sahibi/);
  await auth(db,coach);await call(db,'allocate_official_match_facility',[match,id(1300),new Date(new Date(starts).getTime()+7200000).toISOString()]);
  await owner(db);assert.equal((await db.query('select event_id from org_matches where id=$1',[match])).rows[0].event_id,null);
  await db.query("insert into facility_reservations(club_id,facility_id,title,starts_at,ends_at,reserved_by_phone) values($1,$2,'PRIVATE_RENTAL',$3,$3::timestamptz+interval '1 hour','PRIVATE_PHONE')",[club,id(1300),starts]);
  await auth(db,id(73));let row=(await call(db,'federation_console_matches',[])).rows.find(r=>r.id===match);
  assert.equal(row.facility_name,'Official Court');assert.equal(row.facility_conflict_count,1);
  assert.doesNotMatch(JSON.stringify(row),/PRIVATE_RENTAL|PRIVATE_PHONE/);
  await owner(db);await db.exec("update facility_reservations set status='cancelled'");
  await auth(db,id(73));row=(await call(db,'federation_console_matches',[])).rows.find(r=>r.id===match);assert.equal(row.facility_conflict_count,0);
  await owner(db);await db.query('delete from official_match_facilities where match_id=$1',[match]);
  await auth(db,id(73));row=(await call(db,'federation_console_matches',[])).rows.find(r=>r.id===match);assert.equal(row.facility_conflict_count,null);
 }finally{await db.close();}
});
