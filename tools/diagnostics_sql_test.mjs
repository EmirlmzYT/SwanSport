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
create table public.support_tickets(id uuid primary key default gen_random_uuid(),profile_id uuid);
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
async function setup(){const db=new PGlite();try{await db.exec(fixture);await db.exec(financeValidator);await db.exec(`begin;${sql}\ncommit;`);return db;}
  catch(e){await db.close();throw new Error(`${e.message}; position=${e.position}; ${e.where??''}; context=${sql.slice(Number(e.position)-100,Number(e.position)+100)}`);}}
async function actor(db,id){await db.query("select set_config('test.actor',$1,false)",[id]);}
function event(n=100,changes={}){return {id:uid(n),trace_id:uid(n+1000),kind:'error',operation:'rpc:create_finance_adjustment',
  screen:'/destek',code:'http_400',release:'0.5.1+16',platform:'android',application:'app',usage_enabled:true,
  duration_ms:50,occurred_at:new Date().toISOString(),frames:[],breadcrumbs:[],...changes};}
async function ingest(db,events,s=session){return db.query('select ingest_diagnostics($1,$2::jsonb) as n',[s,JSON.stringify(events)]);}
async function count(db,table){return (await db.query(`select count(*)::int as n from ${table}`)).rows[0].n;}

test('migration repeats safely; private tables and internal helpers deny direct access',async()=>{
  const db=await setup();try{
    await db.exec(`begin;${sql}commit;`);
    await actor(db,user);await db.exec('set role authenticated');
    await assert.rejects(db.query('select * from diagnostic_sessions'),/permission denied/);
    await assert.rejects(db.query("select clean_diagnostic_event('{}')"),/permission denied/);
    await assert.rejects(db.query('select admin_diagnostic_overview()'),/admin required/);
    await db.exec('reset role;set role anon');
    await assert.rejects(ingest(db,[event()]),/permission denied/);
  }finally{await db.close();}
});
test('server drops raw content, masks unknown frames and deduplicates retried batches',async()=>{
  const db=await setup();try{
    await actor(db,user);await db.exec('set role authenticated');
    const e=event(100,{message:'SECRET password',email:'private@example.com',body:'medical private',
      frames:[{source:'package:swansport_data/src/diagnostics.dart',line:10,secret:'SECRET'},
      {source:'file:///Users/private/person.dart',line:1}],
      breadcrumbs:[event(101,{kind:'start',token:'SECRET',breadcrumbs:[{message:'SECRET'}]})]});
    assert.equal((await ingest(db,[e])).rows[0].n,1);
    assert.equal((await ingest(db,[e])).rows[0].n,0);
    await db.exec('reset role');await actor(db,admin);
    const issues=(await db.query('select * from admin_diagnostic_issues()')).rows;
    assert.equal(issues.length,1);assert.equal(Number(issues[0].occurrence_count),1);
    const detail=(await db.query('select admin_diagnostic_detail($1) as d',[issues[0].id])).rows[0].d;
    assert.ok(!JSON.stringify(detail).includes('SECRET'));assert.ok(!JSON.stringify(detail).includes('private'));
    assert.equal(detail.events[0].frames.length,1);assert.equal(detail.events[0].breadcrumbs.length,1);
  }finally{await db.close();}
});
test('session ownership, validation, byte/batch bounds and hourly rate cap are enforced',async()=>{
  const db=await setup();try{
    await actor(db,user);await ingest(db,[event()]);
    await actor(db,other);await assert.rejects(ingest(db,[event(200)]),/Session access denied/);
    await actor(db,user);
    for(const change of [{screen:'/user/private@example.com'},{operation:'private@example.com'},
      {duration_ms:'SECRET'},{duration_ms:-1},{release:'SECRET'},{code:'SECRET'}, {id:null}]){
      await assert.rejects(ingest(db,[event(201,change)]));
    }
    await assert.rejects(ingest(db,Array.from({length:21},(_,i)=>event(300+i))),/Batch limit/);
    await assert.rejects(ingest(db,[event(400,{message:'x'.repeat(70000)})]),/Batch limit/);
    await db.exec(`update diagnostic_limits set event_count=1000 where owner_id='${user}'`);
    await assert.rejects(ingest(db,[event(500)]),/rate limit/);
    assert.equal(await count(db,'diagnostic_events'),1);
  }finally{await db.close();}
});
test('resolution reopens for a new occurrence, but not for delayed old events',async()=>{
  const db=await setup();try{
    await actor(db,user);await ingest(db,[event()]);await actor(db,admin);
    const id=(await db.query('select id from diagnostic_issues')).rows[0].id;
    await db.query("select set_diagnostic_issue_status($1,'resolved')",[id]);
    await actor(db,user);await ingest(db,[event(101,{occurred_at:new Date(Date.now()-60000).toISOString()})]);
    assert.equal((await db.query('select state from diagnostic_issues')).rows[0].state,'resolved');
    await ingest(db,[event(102)]);
    assert.equal((await db.query('select state from diagnostic_issues')).rows[0].state,'regressed');
    await actor(db,other);await assert.rejects(db.query("select set_diagnostic_issue_status($1,'resolved')",[id]),/admin required/);
    await actor(db,admin);await assert.rejects(db.query("select set_diagnostic_issue_status($1,'SECRET')",[id]),/Invalid issue/);
  }finally{await db.close();}
});
test('filters and server pagination select matching releases, platforms and screens',async()=>{
  const db=await setup();try{
    await actor(db,user);await ingest(db,[event(100),event(101,{code:'http_500',release:'0.5.2+17',platform:'web',screen:'/gizlilik'}),
      event(102,{screen:'/gizlilik'})]);
    await actor(db,admin);
    const rows=(await db.query("select * from admin_diagnostic_issues(p_release=>'0.5.2+17',p_platform=>'web',p_screen=>'/gizlilik')")).rows;
    assert.equal(rows.length,1);assert.equal(rows[0].code,'http_500');assert.equal(Number(rows[0].total_count),1);
    assert.equal((await db.query('select * from admin_diagnostic_issues(p_offset=>50)')).rows.length,0);
    assert.equal((await db.query("select count(*)::int as n from diagnostic_issues where code='http_400'")).rows[0].n,2);
  }finally{await db.close();}
});
test('overview detects alerts; diagnostic-only samples cannot distort usage failure rates',async()=>{
  const db=await setup();try{
    await actor(db,user);await ingest(db,Array.from({length:10},(_,i)=>event(100+i,{usage_enabled:false})));
    await actor(db,admin);
    let overview=(await db.query('select admin_diagnostic_overview() as d')).rows[0].d;
    assert.ok(overview.alerts.some(a=>a.code==='recurring_error'));
    assert.ok(!overview.alerts.some(a=>a.code==='high_failure_rate'));
    assert.equal(overview.flows.length,0);
    await actor(db,user);await ingest(db,Array.from({length:10},(_,i)=>event(200+i,{kind:i<3?'error':'success'})));
    await actor(db,admin);overview=(await db.query('select admin_diagnostic_overview() as d')).rows[0].d;
    assert.ok(overview.alerts.some(a=>a.code==='high_failure_rate'));
    assert.equal(Number(overview.flows[0].failed),3);assert.equal(Number(overview.flows[0].succeeded),7);
  }finally{await db.close();}
});
test('audited server write correlates via standard client header without copying business data',async()=>{
  const db=await setup();try{
    await actor(db,user);await ingest(db,[event()]);
    await db.query("select set_config('request.headers',$1,false)",[JSON.stringify({'x-client-info':`supabase-flutter;swan-trace=${event().trace_id}`})]);
    await db.exec('insert into finance_period_logs default values');
    assert.equal(await count(db,'diagnostic_server_events'),1);
    await actor(db,admin);const issue=(await db.query('select id from diagnostic_issues')).rows[0].id;
    const d=(await db.query('select admin_diagnostic_detail($1) as d',[issue])).rows[0].d;
    assert.equal(d.server_events[0].trace_id,event().trace_id);
    assert.equal(d.server_events[0].operation,'finance_period_logs');
    await db.query("select set_config('request.headers','invalid-json',false)");
    await db.exec('insert into finance_period_logs default values');
    assert.equal(await count(db,'finance_period_logs'),2);
  }finally{await db.close();}
});
test('support snapshots and private attachment access stay with ticket owner/admin',async()=>{
  const db=await setup();try{
    const ticket=uid(600), path=`${user}/${ticket}/${uid(601)}.png`;
    await db.exec(`insert into support_tickets values('${ticket}','${user}')`);
    await actor(db,user);await db.exec('set role authenticated');
    await db.query("insert into storage.objects(bucket_id,name) values('diagnostic-attachments',$1)",[path]);
    await db.query('select link_support_diagnostics($1,$2,$3::jsonb,$4)',[ticket,session,
      JSON.stringify({screen:'/destek',release:'0.5.1+16',platform:'android',events:[event()],password:'SECRET'}),path]);
    assert.equal((await db.query('select support_diagnostic_context($1) as d',[ticket])).rows[0].d.attachment_path,path);
    await actor(db,other);
    await assert.rejects(db.query('select support_diagnostic_context($1)',[ticket]),/access denied/);
    assert.equal((await db.query('select * from storage.objects')).rows.length,0);
    await assert.rejects(db.query('select link_support_diagnostics($1,$2,$3::jsonb)',[ticket,session,'{}']),/access denied/);
    await actor(db,admin);assert.equal((await db.query('select * from storage.objects')).rows.length,1);
    const d=(await db.query('select support_diagnostic_context($1) as d',[ticket])).rows[0].d;
    assert.ok(!JSON.stringify(d).includes('SECRET'));
  }finally{await db.close();}
});
test('retention hides expired screenshots, purges metadata, exposes cleanup only to service worker',async()=>{
  const db=await setup();try{
    await actor(db,user);await ingest(db,[event()]);
    const ticket=uid(600),path=`${user}/${ticket}/${uid(601)}.png`;
    await db.exec(`insert into support_tickets values('${ticket}','${user}');
      insert into storage.objects(bucket_id,name,created_at) values('diagnostic-attachments','${path}',now()-interval '31 days');
      insert into support_diagnostic_links(ticket_id,session_id,snapshot,attachment_path,created_at)
      values('${ticket}','${session}','{}','${path}',now()-interval '31 days');
      update diagnostic_events set received_at=now()-interval '31 days';select purge_diagnostics();`);
    assert.equal(await count(db,'diagnostic_events'),0);
    await actor(db,admin);
    assert.equal((await db.query('select admin_diagnostic_overview() as d')).rows[0].d.open_issues,0);
    await actor(db,user);
    await db.exec('set role authenticated');
    assert.equal((await db.query('select * from storage.objects')).rows.length,0);
    await assert.rejects(db.query('select * from pending_diagnostic_attachments()'),/permission denied/);
    await db.exec('reset role;set role service_role');
    assert.equal((await db.query('select * from pending_diagnostic_attachments()')).rows[0].path,path);
    await db.query('select ack_diagnostic_attachment_cleanup($1)',[path]);
    await db.exec('reset role');assert.equal(await count(db,'support_diagnostic_links'),0);
  }finally{await db.close();}
});

test('silent financial inconsistencies reuse the real ledger validator and reveal only counts',async()=>{
  const db=await setup();try{
    const club=uid(2000),account=uid(2001),source=uid(2002),entry=uid(2003);
    await db.query("insert into expenses values($1,$2,$3,100,'complete')",[source,club,account]);
    await db.query("insert into payments values($1,$2,$3,20,'confirmed')",[entry,club,account]);
    await db.query("insert into finance_adjustments values($1,$2,'expense',$3,20,'approved','payment',$4)",[uid(2004),club,source,entry]);
    await db.query("insert into finance_adjustments values($1,$2,'expense',$3,10,'approved',null,null)",[uid(2005),club,source]);
    await db.query("insert into finance_adjustments values($1,$2,'expense',$3,-5,'draft',null,null)",[uid(2006),club,source]);
    await actor(db,user);await db.exec('set role authenticated');
    await assert.rejects(db.query('select admin_diagnostic_consistency()'),/admin required/);
    await actor(db,admin);
    let data=(await db.query('select admin_diagnostic_consistency() as d')).rows[0].d;
    assert.deepEqual(data,[{code:'invalid_financial_amount',count:1},{code:'unmatched_approved_adjustment',count:1}]);
    assert.ok(!JSON.stringify(data).includes(club));assert.ok(!JSON.stringify(data).includes('amount":'));
    await db.exec('reset role');await db.query('update payments set amount=15 where id=$1',[entry]);
    data=(await db.query('select admin_diagnostic_consistency() as d')).rows[0].d;
    assert.equal(data[1].count,2);
  }finally{await db.close();}
});
