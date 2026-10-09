import {PGlite} from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFile} from 'node:fs/promises';import {test} from 'node:test';import assert from 'node:assert/strict';
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const sql=await readFile(new URL('../supabase/migrations/0091_development_report.sql',import.meta.url),'utf8');
const performance=await readFile(new URL('../supabase/migrations/0014_performance.sql',import.meta.url),'utf8');
const view=performance.slice(performance.indexOf('create or replace function public.can_view_athlete_performance'),performance.indexOf('-- ---------------------------------------------------------------------------',performance.indexOf('create or replace function public.can_view_athlete_performance')));
const profile=await readFile(new URL('../supabase/migrations/0011_athlete_profile.sql',import.meta.url),'utf8');
const manage=profile.slice(profile.indexOf('create or replace function public.can_manage_athlete'),profile.indexOf('-- ---------------------------------------------------------------------------',profile.indexOf('create or replace function public.can_manage_athlete')));
const fixture=`
create role anon;create role authenticated;create schema auth;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
create function my_feature_flags() returns table(key text) language sql stable as $$select 'development_report'::text where coalesce(current_setting('test.flag',true),'on')<>'off'$$;
create table clubs(id uuid primary key,name text);
create table athletes(id uuid primary key,club_id uuid,profile_id uuid,first_name text,last_name text);
create table guardians(athlete_id uuid,profile_id uuid);
create table club_memberships(club_id uuid,profile_id uuid,role text,status text);
create function is_club_staff(c uuid) returns boolean language sql stable as $$select exists(select 1 from club_memberships where club_id=c and profile_id=auth.uid() and role in ('club_admin','coach','official') and status='active')$$;
create function is_guardian_of(a uuid) returns boolean language sql stable as $$select exists(select 1 from guardians where athlete_id=a and profile_id=auth.uid())$$;
create type attendance_status as enum('present','late','absent','excused');
create table events(id uuid primary key,club_id uuid,starts_at timestamptz);
create table attendance(id uuid primary key,athlete_id uuid,club_id uuid,event_id uuid,status attendance_status,taken_at timestamptz default now());
create table performance_tests(id uuid primary key,athlete_id uuid,category text,test_name text,unit text,lower_is_better boolean,value numeric(10,2),test_date date,created_at timestamptz default now(),note text);
create table development_goals(id uuid primary key,athlete_id uuid,title text,category text,progress int,status text,target_date date,created_at timestamptz,test_name text,baseline_value numeric,target_value numeric,note text);
create table feature_flags(key text primary key,audience text,label text,description text);
create table faq_entries(question text,answer text,category text,audience text,sort_order int,route text,feature text,active boolean default true);
grant usage on schema public,auth to authenticated,anon;
insert into clubs values('${id(10)}','İzmir Spor'),('${id(11)}','Başka Kulüp');
insert into athletes values('${id(20)}','${id(10)}',null,'Işık','Çağrı'),('${id(21)}','${id(10)}','${id(1)}','Kendi','Sporcu'),('${id(22)}','${id(11)}',null,'Başka','Çocuk');
insert into guardians values('${id(20)}','${id(2)}');
insert into club_memberships values('${id(10)}','${id(3)}','coach','active'),('${id(10)}','${id(4)}','accountant','active'),('${id(11)}','${id(5)}','coach','active');
insert into events values('${id(30)}','${id(10)}','2026-08-31 21:30Z'),('${id(31)}','${id(10)}','2026-09-02 12:00Z'),('${id(32)}','${id(10)}','2026-09-03 12:00Z'),('${id(33)}','${id(10)}','2026-09-04 12:00Z'),('${id(34)}','${id(10)}','2026-09-30 21:30Z');
insert into attendance values('${id(40)}','${id(20)}','${id(10)}','${id(30)}','present','2026-10-02'),('${id(41)}','${id(20)}','${id(10)}','${id(31)}','late','2026-09-02'),('${id(42)}','${id(20)}','${id(10)}','${id(32)}','absent','2026-09-03'),('${id(43)}','${id(20)}','${id(10)}','${id(33)}','excused','2026-09-04'),('${id(44)}','${id(20)}','${id(10)}','${id(34)}','absent','2026-09-30'),('${id(45)}','${id(20)}','${id(10)}',null,'absent','2026-09-10');
insert into performance_tests(id,athlete_id,category,test_name,unit,lower_is_better,value,test_date,note) values
('${id(50)}','${id(20)}','surat','Sprint','sn',true,10,'2026-09-01','PRIVATE_NOTE'),('${id(51)}','${id(20)}','surat','Sprint','sn',true,9,'2026-09-30','PRIVATE_NOTE'),('${id(52)}','${id(20)}','surat','Sprint','ms',true,10000,'2026-09-01',null),('${id(53)}','${id(20)}','teknik','Sprint','sn',true,5,'2026-09-01',null),('${id(54)}','${id(20)}','surat','Sprint','sn',false,3,'2026-09-01',null),('${id(55)}','${id(20)}','surat','Sprint','sn',true,99,'2026-08-31',null);
insert into development_goals(id,athlete_id,title,category,progress,status,created_at,note) values('${id(60)}','${id(20)}','Önceki hedef','surat',95,'active','2026-01-01','PRIVATE_NOTE'),('${id(61)}','${id(20)}','Yeni hedef','teknik',20,'active','2026-09-15','PRIVATE_NOTE'),('${id(62)}','${id(20)}','Dönem sonrası hedef','surat',10,'active','2026-10-01',null);
`;
async function actor(db,who){await db.query("select set_config('test.actor',$1,false)",[who??'']);}
async function setup(){const db=new PGlite();try{await db.exec(fixture);await db.exec(manage);await db.exec(view);await db.exec(`begin;${sql}commit;`);await actor(db,id(2));return db;}catch(e){await db.close();throw e;}}
async function report(db,athlete=id(20),from='2026-09-01',to='2026-09-30'){return(await db.query('select athlete_development_report($1,$2,$3) r',[athlete,from,to])).rows[0].r;}
async function candidates(db,query='',offset=0){return(await db.query('select development_report_athletes($1,$2) r',[query,offset])).rows[0].r;}
test('real role helpers protect profileless guardian/self/staff and deny accountant/other club/missing',async()=>{const db=await setup();try{
 await db.exec('set role authenticated');assert.equal((await report(db)).athlete.id,id(20));await actor(db,id(1));assert.equal((await report(db,id(21))).athlete.id,id(21));await assert.rejects(report(db));await actor(db,id(3));assert.equal((await report(db)).athlete.id,id(20));
 for(const who of [id(4),id(5),id(6)]){await actor(db,who);await assert.rejects(report(db),/erişilemiyor/);}
 await db.exec('reset role');await db.query('insert into guardians values($1,$2)',[id(20),id(4)]);await actor(db,id(4));await db.exec('set role authenticated');assert.equal((await report(db)).athlete.id,id(20));await assert.rejects(report(db,id(21)),/erişilemiyor/);
 await actor(db,id(2));await assert.rejects(report(db,id(999)),/erişilemiyor/);await db.exec('reset role');await db.query('delete from guardians where profile_id=$1',[id(2)]);await assert.rejects(report(db),/erişilemiyor/);
}finally{await db.close();}});
test('event dates use Turkey calendar even when synced later, excused/unlinked excluded from denominator',async()=>{const db=await setup();try{const r=await report(db);assert.deepEqual(r.attendance,{present:1,late:1,absent:1,excused:1,unlinked:1,rate:66.7});assert.equal(r.metrics.length,4);assert.equal(JSON.stringify(r).includes('PRIVATE_NOTE'),false);
}finally{await db.close();}});
test('compatible measurements compare within period only; unit/category/direction groups stay separate',async()=>{const db=await setup();try{const r=await report(db);const sprint=r.metrics.find(m=>m.category==='surat'&&m.unit==='sn'&&m.lower_is_better);assert.equal(sprint.sample_count,2);assert.equal(sprint.first_value,10);assert.equal(sprint.last_value,9);assert.equal(sprint.first_date,'2026-09-01');assert.equal(r.metrics.filter(m=>m.sample_count===1).length,3);
}finally{await db.close();}});
test('no records is null rate, excused-only is unknown, missing data is not fabricated zero percent',async()=>{const db=await setup();try{const r=await report(db,id(20),'2026-08-01','2026-08-02');assert.equal(r.attendance.rate,null);assert.equal(r.metrics.length,0);assert.equal((await report(db,id(20),'2026-09-04','2026-09-04')).attendance.rate,null);
}finally{await db.close();}});
test('goals are explicit current snapshot of goals created by period end; refresh fingerprint detects changes',async()=>{const db=await setup();try{const old=await report(db);assert.equal(old.goals.length,2);assert.equal(old.goals[0].progress,95);assert.equal((await report(db)).fingerprint,old.fingerprint);await db.query('update development_goals set progress=100 where id=$1',[id(60)]);const fresh=await report(db);assert.equal(fresh.goals[0].progress,100);assert.notEqual(fresh.fingerprint,old.fingerprint);
}finally{await db.close();}});
test('uniform flag/auth denial, valid bounded dates, RPC signatures and repeat migration',async()=>{const db=await setup();try{await db.exec(`begin;${sql}commit;`);assert.equal((await db.query("select count(*)::int n from faq_entries where feature='development_report'")).rows[0].n,1);
 for(const dates of [[null,'2026-09-30'],['2026-10-01','2026-09-01'],['2020-01-01','2021-01-01'],['2026-09-01','2999-01-01']])await assert.rejects(report(db,id(20),...dates),/dönem/);
 await actor(db,null);await assert.rejects(report(db),/erişilemiyor/);await assert.rejects(candidates(db),/Oturum/);await actor(db,id(2));await db.query("select set_config('test.flag','off',false)");await assert.rejects(report(db),/açık değil/);await assert.rejects(candidates(db),/açık değil/);
 await db.exec('set role anon');await assert.rejects(report(db),/permission denied/);await assert.rejects(candidates(db),/permission denied/);
}finally{await db.close();}});
test('candidate list isolates people, folds Turkish characters, validates query and paginates',async()=>{const db=await setup();try{assert.deepEqual((await candidates(db,'isik cagri')).athletes.map(a=>a.id),[id(20)]);await actor(db,id(4));assert.equal((await candidates(db)).athletes.length,0);await actor(db,id(3));
 for(let n=100;n<145;n++)await db.query('insert into athletes values($1,$2,null,$3,$4)',[id(n),id(10),'Sporcu',String(n)]);
 const first=await candidates(db),second=await candidates(db,'',40);assert.equal(first.athletes.length,40);assert.equal(first.has_more,true);assert.equal(second.athletes.length,7);assert.equal(second.has_more,false);assert.equal(new Set([...first.athletes,...second.athletes].map(a=>a.id)).size,47);
 await assert.rejects(candidates(db,'',-1),/arama/);await assert.rejects(candidates(db,'x'.repeat(101)),/arama/);
}finally{await db.close();}});
