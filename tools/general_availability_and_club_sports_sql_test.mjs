import {PGlite} from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const read=name=>readFile(new URL('../supabase/migrations/'+name+'.sql',import.meta.url),'utf8');
const migration=await read('0121_general_availability_and_club_training_sports');
const keys=['sport_training_sessions','season_setup','development_report','court_waitlist','turf_delegation','referee_cockpit','club_staff_operations','live_match_hub','league_standings','live_match_notifications','parent_hub'];
const catalog=await readFile(new URL('../packages/swansport_data/lib/src/sports_catalog.dart',import.meta.url),'utf8');
const codes=[...catalog.matchAll(/code: '([^']+)'/g)].map(m=>m[1]);
const id=n=>'12100000-0000-0000-0000-'+String(n).padStart(12,'0');
async function actor(db,n){await db.query("select set_config('test.actor',$1,false)",[n===null?'':id(n)]);}
async function apply(db){await db.exec('begin');try{await db.exec(migration);await db.exec('commit');}catch(e){await db.exec('rollback');throw e;}}
async function setup(){const db=new PGlite();try{
 await db.exec(`create role anon;create role authenticated;create schema auth;
 create table auth.users(id uuid primary key,raw_user_meta_data jsonb default '{}');
 create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 grant usage on schema auth to anon,authenticated;grant execute on function auth.uid() to anon,authenticated;
 alter default privileges in schema public grant all on tables to authenticated;`);
 await db.exec((await read('0001_foundation')).replace('create extension if not exists "pgcrypto";',''));
 await db.exec(await read('0002_rls_policies'));
 await db.exec(await read('0004_roles_verification'));
 await db.exec(`create table sports(code text primary key,name text);
 alter table clubs add column sport_code text;
 alter table teams add column sport_code text;
 create table club_sport_registrations(club_id uuid,sport_code text);
 create table club_accountants(club_id uuid references clubs(id),profile_id uuid references profiles(id),status text default 'active');
 revoke all on club_sport_registrations from public,anon,authenticated;
 create table feature_flags(key text primary key,audience text);
 create table feature_flag_testers(key text,profile_id uuid,club_id uuid);
 alter table feature_flags enable row level security;
 revoke all on feature_flags from public,anon,authenticated;
 create table faq_entries(question text,answer text,category text,audience text,feature text,route text,sort_order int,active boolean default true);`);
 for(const code of codes)await db.query('insert into sports values($1,$1)',[code]);
 for(const key of [...keys,'offline_attendance','social_video','unrelated']){
  await db.query('insert into feature_flags values($1,$2)',[key,['offline_attendance','social_video'].includes(key)?'off':'admins']);
  await db.query('insert into faq_entries(question,feature) values($1,$1)',[key]);
 }
 const faq=await read('0070_faq_follows_features');
 const feature=await read('0092_court_waitlist');
 await db.exec(feature.slice(feature.indexOf('create or replace function public._swan_feature_for_profile'),feature.indexOf('create table if not exists public.court_waitlist')));
 await db.exec('revoke all on function my_feature_flags() from public;grant execute on function my_feature_flags() to anon,authenticated');
 const start=faq.indexOf('create or replace function public.require_faq_before_release()');
 const end=faq.indexOf('-- 3)',start);
 await db.exec(faq.slice(start,end));
 for(let n=1;n<=6;n++)await db.query('insert into auth.users(id) values($1)',[id(n)]);
 await db.query("insert into clubs(id,name,status,sport_code) values($1,'One','active','okculuk'),($2,'Two','active','tenis')",[id(10),id(11)]);
 await db.query('insert into club_accountants(club_id,profile_id) values($1,$2)',[id(10),id(6)]);
 for(const [n,role,status,club] of [[1,'club_admin','active',10],[2,'coach','active',10],[3,'athlete','active',10],[4,'coach','suspended',10],[5,'club_admin','active',11]])
  await db.query('insert into club_memberships(profile_id,club_id,role,status) values($1,$2,$3,$4)',[id(n),id(club),role,status]);
 await actor(db,1);await apply(db);return db;
 }catch(e){await db.close();throw e;}}
const save=(db,list,club=10)=>db.query('select set_club_training_sports($1,$2::text[]) n',[id(club),list]);

test('0121 release is conditional, idempotent, preserves off/testers/unrelated flags and FAQ gate',async()=>{
 const db=await setup();try{
 for(const key of keys)assert.equal((await db.query('select audience from feature_flags where key=$1',[key])).rows[0].audience,'everyone');
 await actor(db,3);await db.exec('set role authenticated');
 const visible=(await db.query('select * from my_feature_flags()')).rows.map(r=>r.key);
 for(const key of keys)assert.ok(visible.includes(key));
 assert.ok(!visible.includes('offline_attendance')&&!visible.includes('social_video'));
 await assert.rejects(db.query("update feature_flags set audience='everyone'"),/permission/);
 await db.exec('reset role');await actor(db,1);
 await db.exec("update feature_flags set audience='off' where key='referee_cockpit';update feature_flags set audience='testers' where key='season_setup'");
 await apply(db);
 for(const key of ['offline_attendance','social_video','referee_cockpit'])assert.equal((await db.query('select audience from feature_flags where key=$1',[key])).rows[0].audience,'off');
 assert.equal((await db.query("select audience from feature_flags where key='season_setup'")).rows[0].audience,'testers');
 assert.equal((await db.query("select audience from feature_flags where key='unrelated'")).rows[0].audience,'admins');
 await db.exec("update feature_flags set audience='admins' where key='league_standings';delete from faq_entries where feature='league_standings'");
 await assert.rejects(apply(db),/yardımı/);
 assert.equal((await db.query("select audience from feature_flags where key='league_standings'")).rows[0].audience,'admins');
 }finally{await db.close();}
});
test('admin and coach replace ten sports; normalize, clear, preserve metadata and never create federation registrations',async()=>{
 const db=await setup();try{
 await db.exec('set role authenticated');
 assert.equal((await save(db,codes.slice(0,10))).rows[0].n,10);
 const created=(await db.query('select * from club_training_sports order by sport_code')).rows;
 await actor(db,2);await save(db,[...codes.slice(0,10),codes[0],' '+codes[1]+' ','invalid','',null]);
 assert.deepEqual((await db.query('select * from club_training_sports order by sport_code')).rows,created);
 const union=(await db.query('select * from my_training_club_sports($1)',[id(10)])).rows.map(r=>r.sport_code);
 for(const code of [...codes.slice(0,10),'okculuk'])assert.ok(union.includes(code));
 assert.equal((await save(db,null)).rows[0].n,0);
 await db.exec('reset role');
 assert.equal((await db.query('select count(*)::int n from club_sport_registrations')).rows[0].n,0);
 }finally{await db.close();}
});
test('athlete, outsider, accountant-only, suspended coach and anon cannot write; RLS scopes reads',async()=>{
 const db=await setup();try{
 await save(db,['yuzme']);
 await db.exec('set role authenticated');
 for(const n of [3,4,5,6,null]){await actor(db,n);await assert.rejects(save(db,['futbol']),/yetkin/);}
 await actor(db,3);assert.equal((await db.query('select * from club_training_sports')).rows.length,1);
 await actor(db,6);assert.equal((await db.query('select * from club_training_sports')).rows.length,0);
 await actor(db,1);
 await assert.rejects(db.query("insert into club_training_sports(club_id,sport_code) values($1,'tenis')",[id(10)]),/permission/);
 await assert.rejects(db.query('delete from club_training_sports'),/permission/);
 await assert.rejects(db.query('select * from club_sport_registrations'),/permission/);
 await db.exec('reset role');
 for(const signature of ['set_club_training_sports(uuid,text[])','my_training_club_sports(uuid)'])assert.equal((await db.query("select has_function_privilege('anon',$1,'execute') v",[signature])).rows[0].v,false);
 }finally{await db.close();}
});
test('60-sport limit and inactive club fail atomically without wiping the previous selection',async()=>{
 const db=await setup();try{
 await save(db,['yuzme']);
 await db.exec("insert into sports values('extra','Extra')");
 await assert.rejects(save(db,[...codes,'extra']),/60/);
 assert.equal((await db.query('select * from club_training_sports')).rows[0].sport_code,'yuzme');
 await db.query("update clubs set status='pending' where id=$1",[id(10)]);
 await assert.rejects(save(db,['tenis']),/yetkin/);
 await assert.rejects(db.query('select * from my_training_club_sports($1)',[id(10)]),/üyeliği/);
 }finally{await db.close();}
});
