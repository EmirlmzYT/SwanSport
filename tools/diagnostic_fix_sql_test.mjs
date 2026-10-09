// Executes the real 0086 migration/functions in isolated PostgreSQL (PGlite).
// npm install --prefix build/finance-sql-tests @electric-sql/pglite@0.5.8
// node --test tools/diagnostics_sql_test.mjs
import {PGlite} from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {test} from 'node:test';
const uid=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const user=uid(1), other=uid(2), admin=uid(3), session=uid(10);
const fixture=`
create role anon; create role authenticated; create role service_role;
create schema auth;create table auth.users(id uuid primary key);
insert into auth.users values('${user}'),('${other}'),('${admin}');
create function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('test.actor',true),'')::uuid $$;
create function public.is_platform_admin() returns boolean language sql stable as
$$ select auth.uid()='${admin}'::uuid $$;
create table public.profiles(id uuid primary key);insert into profiles select id from auth.users;
create table public.support_tickets(id uuid primary key default gen_random_uuid(),profile_id uuid references profiles(id),subject text default 'Talep',status text default 'new' check(status in ('new','under_review','awaiting_user_response','resolved','closed')),resolved_at timestamptz,updated_at timestamptz default now());
create table public.support_messages(id uuid primary key default gen_random_uuid(),ticket_id uuid references support_tickets(id),sender_id uuid references profiles(id),body text,is_staff boolean);
create table public.notifications(profile_id uuid,kind text,title text,body text,entity_type text,entity_id uuid);
create table public.finance_period_logs(id uuid default gen_random_uuid());
create table public.faq_entries(question text,answer text,category text,audience text,sort_order int,route text);
create table public.finance_adjustments(id uuid primary key,club_id uuid,target_kind text,target_id uuid,amount numeric,status text,entry_kind text,entry_id uuid);
create table public.expenses(id uuid primary key,club_id uuid,account_id uuid,amount numeric,status text);
create table public.payments(id uuid primary key,club_id uuid,account_id uuid,amount numeric,status text);
create table public.donations(id uuid primary key,club_id uuid,account_id uuid,amount numeric,status text);
create schema storage;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,created_at timestamptz default now());
alter table storage.objects enable row level security;
alter table public.support_tickets enable row level security;
create policy fixture_ticket_own on public.support_tickets for select to authenticated using(profile_id=auth.uid() or is_platform_admin());
grant usage on schema public,storage,auth to authenticated,anon,service_role;
grant select,insert on storage.objects to authenticated;
grant select on public.support_tickets to authenticated;
`;
const sql=await readFile(new URL('../supabase/migrations/0086_diagnostics_center.sql',import.meta.url),'utf8');
const financeSource=await readFile(new URL('../supabase/migrations/0085_finance_adjustment_rpc_contract.sql',import.meta.url),'utf8');
const financeValidator=financeSource.slice(financeSource.indexOf('create or replace function public.finance_adjustment_entry_matches'),financeSource.indexOf('drop function if exists public.create_finance_adjustment'));
const fixSql=await readFile(new URL('../supabase/migrations/0089_diagnostic_fix_verification.sql',import.meta.url),'utf8');
async function setup(){const db=new PGlite();try{await db.exec(fixture);await db.exec(financeValidator);await db.exec(`begin;${sql}\ncommit;`);await db.exec(`begin;${fixSql}commit;`);return db;}
  catch(e){await db.close();throw new Error(`${e.message}; position=${e.position}; ${e.where??''}; context=${sql.slice(Number(e.position)-100,Number(e.position)+100)}`);}}
async function actor(db,id){await db.query("select set_config('test.actor',$1,false)",[id]);}
function event(n=100,changes={}){return {id:uid(n),trace_id:uid(n+1000),kind:'error',operation:'rpc:create_finance_adjustment',
  screen:'/destek',code:'http_400',release:'0.5.1+16',platform:'android',application:'app',usage_enabled:true,
  duration_ms:50,occurred_at:new Date().toISOString(),frames:[],breadcrumbs:[],...changes};}
async function ingest(db,events,s=session){return db.query('select ingest_diagnostics($1,$2::jsonb) as n',[s,JSON.stringify(events)]);}
async function count(db,table){return (await db.query(`select count(*)::int as n from ${table}`)).rows[0].n;}


async function prepare(db) {
 await actor(db,user);await ingest(db,[event()]);
 return (await db.query('select id from diagnostic_issues')).rows[0].id;
}
async function fix(db,issue,release='0.5.2+17',platform='android') {
 await actor(db,admin);return (await db.query('select declare_diagnostic_fix($1,$2,$3) id',[issue,release,platform])).rows[0].id;
}
async function ticket(db,n=500,owner=user) {const id=uid(n);await db.query('insert into support_tickets(id,profile_id) values($1,$2)',[id,owner]);return id;}
async function link(db,t,i){await actor(db,admin);await db.query('select link_support_issue($1,$2)',[t,i]);}
async function respond(db,t,f,result='confirmed',release='0.5.2+17',platform='android',app='app') {
 return db.query('select respond_support_fix($1,$2,$3,$4,$5,$6)',[t,f,result,release,platform,app]);
}
async function detail(db,i){await actor(db,admin);return (await db.query('select admin_diagnostic_detail($1) d',[i])).rows[0].d;}

test('migration repeats safely, function signatures and private access are protected',async()=>{
 const db=await setup();try{await db.exec(`begin;${fixSql}commit;`);const i=await prepare(db);
 await actor(db,user);await db.exec('set role authenticated');
 for(const query of ['select * from diagnostic_fixes',"select diagnostic_release_parts('0.5.2+17')",`select declare_diagnostic_fix('${i}','0.5.2+17','android')`])await assert.rejects(db.query(query),/permission denied|admin required/);
 await db.exec('reset role');await actor(db,admin);
 await assert.rejects(db.query('select set_diagnostic_issue_status($1,$2)',[i,'resolved']),/sürümü/);
 await assert.rejects(fix(db,i,'unknown'),/Geçerli/);await assert.rejects(fix(db,i,'0.5.2+17','unknown'),/Geçerli/);
 const sigs=(await db.query("select proname,count(*)::int n from pg_proc where proname in ('declare_diagnostic_fix','respond_support_fix','set_diagnostic_issue_status') group by 1")).rows;assert.ok(sigs.every(r=>r.n===1));
 await db.exec('set role anon');await assert.rejects(respond(db,uid(500),uid(600)),/permission denied/);
 }finally{await db.close();}
});
test('regression uses numeric release, scope, occurrence time and duplicate protection',async()=>{
 const db=await setup();try{const i=await prepare(db);const f=await fix(db,i);await db.query("update diagnostic_fixes set declared_at=now()-interval '1 hour' where id=$1",[f]);await actor(db,user);
 for(const [n,change] of [[101,{release:'0.5.1+999'}],[102,{release:'unknown'}],[103,{release:'0.5.2+17',platform:'web'}],[104,{release:'0.5.2+17',occurred_at:new Date(Date.now()-7200000).toISOString()}]]) await ingest(db,[event(n,change)]);
 let d=await detail(db,i);assert.equal(d.issue.state,'resolved');assert.equal(d.fix.regression_count,0);
 await actor(db,user);const e=event(105,{release:'0.5.10+1'});await ingest(db,[e]);await ingest(db,[e]);
 d=await detail(db,i);assert.equal(d.issue.state,'regressed');assert.equal(d.fix.regression_count,1);
 assert.equal((await db.query("select diagnostic_release_parts('0.5.10+1')>=diagnostic_release_parts('0.5.9+99') yes")).rows[0].yes,true);
 }finally{await db.close();}
});
test('fix declarations retry without duplicate requests, keep history and forbid downgrade',async()=>{
 const db=await setup();try{const i=await prepare(db),t=await ticket(db);await link(db,t,i);
 const f=await fix(db,i);assert.equal(await fix(db,i),f);assert.equal(await count(db,'notifications'),1);assert.equal(await count(db,'support_messages'),1);
 await assert.rejects(fix(db,i,'0.5.1+999'),/daha yeni/);
 const next=await fix(db,i,'0.5.3+18');assert.notEqual(next,f);assert.equal(await count(db,'diagnostic_fixes'),2);assert.equal(await count(db,'notifications'),2);
 }finally{await db.close();}
});
test('support association is admin-only, idempotent, valid before and after declaration',async()=>{
 const db=await setup();try{const i=await prepare(db),t=await ticket(db);await fix(db,i);
 await actor(db,user);await assert.rejects(db.query('select link_support_issue($1,$2)',[t,i]),/admin required/);
 await link(db,t,i);await link(db,t,i);assert.equal(await count(db,'support_messages'),1);assert.equal(await count(db,'notifications'),1);
 await actor(db,other);await assert.rejects(db.query('select support_fix_context($1)',[t]),/access denied/);
 await actor(db,user);const context=(await db.query('select support_fix_context($1) c',[t])).rows[0].c;
 assert.equal(context.response,'awaiting_confirmation');assert.ok(!JSON.stringify(context).includes('declared_by'));
 await db.query("update support_tickets set status='closed' where id=$1",[t]);await assert.rejects(link(db,t,i),/Açık/);
 }finally{await db.close();}
});
test('only owner on current fixed version can confirm; duplicate replies have no extra side effects',async()=>{
 const db=await setup();try{const i=await prepare(db),t=await ticket(db);await link(db,t,i);const f=await fix(db,i);
 for(const who of [other,admin]){await actor(db,who);await assert.rejects(respond(db,t,f),/access denied/);}
 await actor(db,user);
 for(const args of [['0.5.1+999','android','app'],['unknown','android','app'],['0.5.2+17','web','app'],['0.5.2+17','android','console']])await assert.rejects(respond(db,t,f,'confirmed',...args),/güncel sürüm/);
 await respond(db,t,f);await respond(db,t,f);
 const row=(await db.query('select * from support_tickets where id=$1',[t])).rows[0];assert.equal(row.status,'resolved');assert.equal(row.fix_response,'confirmed');assert.equal(await count(db,'support_messages'),2);
 const d=await detail(db,i);assert.equal(d.verification.confirmed,1);assert.equal(d.verification.pending,0);const overview=(await db.query('select admin_diagnostic_overview() d')).rows[0].d;assert.equal(overview.confirmed_fix_tickets,1);assert.equal(overview.pending_fix_confirmations,0);
 }finally{await db.close();}
});
test('still failing reopens ticket without inventing technical error events',async()=>{
 const db=await setup();try{const i=await prepare(db),t=await ticket(db);await link(db,t,i);const f=await fix(db,i);await actor(db,user);await respond(db,t,f,'still_failing');
 const row=(await db.query('select * from support_tickets where id=$1',[t])).rows[0];assert.equal(row.status,'under_review');assert.equal(row.resolved_at,null);
 const d=await detail(db,i);assert.equal(d.issue.state,'regressed');assert.equal(d.fix.regression_count,0);assert.equal(d.verification.still_failing,1);assert.equal(await count(db,'diagnostic_events'),1);
 }finally{await db.close();}
});
test('new declaration invalidates stale forms and technical recurrence cannot override user feedback',async()=>{
 const db=await setup();try{const i=await prepare(db),t=await ticket(db);await link(db,t,i);const f=await fix(db,i);await actor(db,user);await respond(db,t,f);
 const newer=await fix(db,i,'0.5.3+18');await actor(db,user);await assert.rejects(respond(db,t,f),/Güncel düzeltme/);
 await respond(db,t,newer,'confirmed','0.5.3+18');await db.query("update diagnostic_fixes set declared_at=now()-interval '1 hour' where id=$1",[newer]);await ingest(db,[event(201,{release:'0.5.3+18'})]);
 const d=await detail(db,i);assert.equal(d.issue.state,'regressed');assert.equal(d.verification.confirmed,1);assert.equal(d.fix.regression_count,1);
 }finally{await db.close();}
});
test('retention preserves a pending confirmation but closed requests release the issue',async()=>{
 const db=await setup();try{const i=await prepare(db),t=await ticket(db);await link(db,t,i);await fix(db,i);
 await db.query("update diagnostic_issues set last_seen=now()-interval '91 days' where id=$1",[i]);await db.query('select purge_diagnostics()');assert.equal(await count(db,'diagnostic_issues'),1);
 await db.query("update support_tickets set status='closed' where id=$1",[t]);await db.query('select purge_diagnostics()');assert.equal(await count(db,'diagnostic_issues'),0);assert.equal(await count(db,'diagnostic_fixes'),0);
 }finally{await db.close();}
});

test('incorrect support association can be removed explicitly, retaining conversation and preventing stale responses',async()=>{
 const db=await setup();try{const i=await prepare(db),t=await ticket(db);await link(db,t,i);const f=await fix(db,i);
 await actor(db,user);await assert.rejects(db.query('select unlink_support_issue($1,$2)',[t,i]),/admin required/);
 await actor(db,admin);await db.query('select unlink_support_issue($1,$2)',[t,i]);await db.query('select unlink_support_issue($1,$2)',[t,i]);
 assert.equal(await count(db,'support_messages'),2);const row=(await db.query('select * from support_tickets where id=$1',[t])).rows[0];assert.equal(row.diagnostic_issue_id,null);assert.equal(row.status,'under_review');
 await actor(db,user);await assert.rejects(respond(db,t,f),/access denied/);
 }finally{await db.close();}
});
