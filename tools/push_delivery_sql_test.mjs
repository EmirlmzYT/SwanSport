import {PGlite} from '@electric-sql/pglite';
import {readFile,readdir} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const id=n=>`40000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const sql=async name=>readFile(new URL('../supabase/migrations/'+name,import.meta.url),'utf8');
async function fixture(){
 const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;create role service_role;
 create schema auth;create schema net;
 create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 create table profiles(id uuid primary key);
 create table guardians(profile_id uuid,athlete_id uuid);
 create table direct_messages(id uuid primary key,sender_id uuid,recipient_id uuid);
 create function is_blocked_between(a uuid,b uuid) returns boolean language sql as $$select coalesce(current_setting('test.blocked',true),'false')='true'$$;
 create function _match_follow_state(m uuid,p uuid) returns jsonb language sql as $$select jsonb_build_object('is_followed',coalesce(current_setting('test.followed',true),'true')<>'false')$$;
 create table notifications(id uuid primary key default gen_random_uuid(),profile_id uuid references profiles(id) on delete cascade,kind text,title text,body text,entity_type text,entity_id uuid,created_at timestamptz default now());
 create table push_subscriptions(id uuid primary key default gen_random_uuid(),profile_id uuid references profiles(id) on delete cascade,endpoint text unique,kind text,p256dh text,auth text);
 create function is_platform_admin() returns boolean language sql as $$select coalesce(current_setting('test.admin',true),'')='true'$$;
 create function push_allowed(p uuid,k text) returns boolean language sql as $$select coalesce(current_setting('test.allowed',true),'true')<>'false'$$;
 create function push_secret() returns text language sql as $$select 'fixture-secret'$$;
 create function _match_follow_public(p uuid) returns boolean language sql as $$select true$$;
 create function _swan_feature_for_profile(k text,p uuid) returns boolean language sql as $$select coalesce(current_setting('test.flag',true),'true')<>'false'$$;
 create function push_route(k text,e text) returns text language sql as $$select '/bildirimler'$$;
 create table net.requests(id bigserial primary key,body jsonb);
 create table net._http_response(id bigint primary key,status_code int,content text,timed_out boolean default false,error_msg text);
 create function net.http_post(url text,body jsonb,params jsonb default '{}',headers jsonb default '{}',timeout_milliseconds int default 5000) returns bigint language plpgsql as $$declare r bigint;begin insert into net.requests(body) values(body) returning id into r;return r;end$$;
 grant usage on schema public,auth to anon,authenticated,service_role;`);
 for(const name of (await readdir(new URL('../supabase/migrations/',import.meta.url))).sort()){
  if(name.endsWith('_push_delivery_tracking.sql'))await db.exec(await sql(name));
 }
 await db.query('insert into profiles values($1),($2)',[id(1),id(2)]);
 await db.query("insert into push_subscriptions(id,profile_id,endpoint,kind) values($1,$2,'fixture-token','fcm')",[id(10),id(1)]);
 return db;
}
async function notify(db,kind='application'){
 return (await db.query("insert into notifications(profile_id,kind,title,body) values($1,$2,'Hello','Private fixture') returning id",[id(1),kind])).rows[0].id;
}
async function response(db,status=200,result={status:200,gone:false,retryable:false}){
 const request=(await db.query('select max(id) id from net.requests')).rows[0].id;
 await db.query('insert into net._http_response(id,status_code,content) values($1,$2,$3)',[request,status,JSON.stringify({results:[result]})]);
}
test('enqueue once per device, accepted is not resent; ledger contains no payload/token and is admin-read-only',async()=>{
 const db=await fixture();try{
  await notify(db);await response(db);await db.exec('select process_push_deliveries()');await db.exec('select process_push_deliveries()');
  const d=(await db.query('select * from push_delivery_attempts')).rows[0];assert.equal(d.status,'accepted');assert.equal(d.attempt_count,1);
  assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,1);
  assert.doesNotMatch(JSON.stringify(d),/fixture-token|Private fixture|fixture-secret/);
  await db.exec('set role anon');await assert.rejects(db.exec('select * from push_delivery_attempts'),/permission/);
  await db.exec('reset role;set role authenticated');assert.equal((await db.query('select * from push_delivery_attempts')).rows.length,0);
  await assert.rejects(db.exec('select process_push_deliveries()'),/permission/);
  await db.exec("reset role;select set_config('test.admin','true',false);set role authenticated");
  assert.equal((await db.query('select * from push_delivery_attempts')).rows.length,1);
  await assert.rejects(db.exec("update push_delivery_attempts set status='pending'"),/permission/);
 }finally{await db.close();}
});
test('only known transient provider rejection retries, maximum three attempts; timeout becomes unknown',async()=>{
 const db=await fixture();try{
  await notify(db);
  for(let i=1;i<=3;i++){
   await response(db,200,{status:503,gone:false,retryable:true});await db.exec('select process_push_deliveries()');
   const d=(await db.query('select * from push_delivery_attempts')).rows[0];assert.equal(d.status,i===3?'failed':'retry');
   if(i<3){await db.exec("update push_delivery_attempts set next_attempt_at=now()-interval '1 second';select process_push_deliveries()");}
  }
  assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,3);
  await notify(db);await db.exec("update push_delivery_attempts set last_attempt_at=now()-interval '3 minutes' where status='in_flight';select process_push_deliveries()");
  assert.equal((await db.query("select count(*)::int n from push_delivery_attempts where status='unknown'")).rows[0].n,1);
  await db.exec('select process_push_deliveries()');assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,4);
 }finally{await db.close();}
});
test('invalid token cleanup cannot delete a re-registered/transferred device; retry cannot send to new account',async()=>{
 const db=await fixture();try{
  await notify(db);await db.query('update push_subscriptions set profile_id=$1 where id=$2',[id(2),id(10)]);
  await response(db,200,{status:404,gone:true,retryable:false});await db.exec('select process_push_deliveries()');
  assert.equal((await db.query('select profile_id from push_subscriptions')).rows[0].profile_id,id(2));
  await db.query('update push_subscriptions set profile_id=$1 where id=$2',[id(1),id(10)]);
  await notify(db);await response(db,200,{status:503,gone:false,retryable:true});await db.exec('select process_push_deliveries()');
  await db.query('update push_subscriptions set profile_id=$1 where id=$2',[id(2),id(10)]);
  await db.exec("update push_delivery_attempts set next_attempt_at=now()-interval '1 second' where status='retry';select process_push_deliveries()");
  assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,2);
  assert.equal((await db.query("select count(*)::int n from push_delivery_attempts where status='skipped'")).rows[0].n,1);
 }finally{await db.close();}
});
test('permanent token removes only matching registration; preference revocation/expiry prevents retry',async()=>{
 const db=await fixture();try{
  await notify(db);await response(db,200,{status:404,gone:true,retryable:false});await db.exec('select process_push_deliveries()');
  assert.equal((await db.query('select * from push_subscriptions')).rows.length,0);
  await db.query("insert into push_subscriptions(id,profile_id,endpoint,kind) values($1,$2,'fixture-next','fcm')",[id(11),id(1)]);
  await notify(db);await response(db,200,{status:503,retryable:true});await db.exec('select process_push_deliveries()');
  await db.exec("select set_config('test.allowed','false',false);update push_delivery_attempts set next_attempt_at=now()-interval '1 second' where status='retry';select process_push_deliveries()");
  assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,2);
  await db.exec("select set_config('test.allowed','true',false)");await notify(db,'match_live');
  await response(db,200,{status:503,retryable:true});await db.exec('select process_push_deliveries()');
  await db.exec("update push_delivery_attempts set expires_at=now()-interval '1 second',next_attempt_at=now()-interval '1 second' where status='retry';select process_push_deliveries()");
  assert.equal((await db.query("select count(*)::int n from push_delivery_attempts where status='expired'")).rows[0].n,1);
 }finally{await db.close();}
});

test('a match mute, guardian unlink or DM block cancels queued retry before exposing stale content',async()=>{
 const db=await fixture();try{
  await notify(db,'match_live');await response(db,200,{status:503,retryable:true});await db.exec('select process_push_deliveries()');
  await db.exec("select set_config('test.followed','false',false);update push_delivery_attempts set next_attempt_at=now()-interval '1 second' where status='retry';select process_push_deliveries()");
  assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,1);
  await db.query('insert into guardians values($1,$2)',[id(1),id(40)]);
  await db.query("insert into notifications(profile_id,kind,title,entity_id) values($1,'match_result','Result',$2)",[id(1),id(40)]);
  await response(db,200,{status:503,retryable:true});await db.exec('select process_push_deliveries()');await db.exec('delete from guardians');
  await db.exec("update push_delivery_attempts set next_attempt_at=now()-interval '1 second' where status='retry';select process_push_deliveries()");
  assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,2);
  await db.query('insert into direct_messages values($1,$2,$3)',[id(50),id(2),id(1)]);
  await db.query("insert into notifications(profile_id,kind,title,entity_id) values($1,'message','DM',$2)",[id(1),id(50)]);
  await response(db,200,{status:503,retryable:true});await db.exec('select process_push_deliveries()');
  await db.exec("select set_config('test.blocked','true',false);update push_delivery_attempts set next_attempt_at=now()-interval '1 second' where status='retry';select process_push_deliveries()");
  assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,3);
  assert.equal((await db.query("select count(*)::int n from push_delivery_attempts where status='skipped'")).rows[0].n,3);
 }finally{await db.close();}
});

test('malformed, missing-status and ambiguous transport responses never cause automatic resend',async()=>{
 const db=await fixture();try{
  for(const content of ['not-json','{}','{"results":[]}','{"results":[{}]}','{"results":[{"status":200},{"status":200}]}']){
   await notify(db);const request=(await db.query('select max(id) id from net.requests')).rows[0].id;
   await db.query('insert into net._http_response(id,status_code,content) values($1,200,$2)',[request,content]);
   await db.exec('select process_push_deliveries()');
  }
  assert.equal((await db.query("select count(*)::int n from push_delivery_attempts where status='unknown'")).rows[0].n,5);
  assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,5);
 }finally{await db.close();}
});

test('legacy sender 404 without explicit retry classification cannot delete a valid token',async()=>{
 const db=await fixture();try{
  await notify(db);await response(db,200,{status:404,gone:true});await db.exec('select process_push_deliveries()');
  assert.equal((await db.query('select * from push_subscriptions')).rows.length,1);
  assert.equal((await db.query('select count(*)::int n from net.requests')).rows[0].n,1);
 }finally{await db.close();}
});
