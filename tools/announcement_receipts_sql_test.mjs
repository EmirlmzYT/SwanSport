import {PGlite} from '../build/finance-sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const id=n=>`50000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const source=n=>readFile(new URL(`../supabase/migrations/${n}.sql`,import.meta.url),'utf8');
function table(s,n){const i=s.indexOf(`create table if not exists public.${n} (`);assert.ok(i>=0);return s.slice(i,s.indexOf('\n);',i)+3);}
async function actor(db,n){await db.query("select set_config('test.actor',$1,false)",[n?id(n):'']);}
async function setup(){const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key,raw_user_meta_data jsonb);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;`);
 await db.exec((await source('0001_foundation')).replace('create extension if not exists "pgcrypto";',''));
 const helpers=await source('0002_rls_policies');
 for(const name of ['is_club_member','is_club_staff']){const start=helpers.indexOf('create or replace function public.'+name+'(');assert.ok(start>=0);await db.exec(helpers.slice(start,helpers.indexOf('$$;',start)+3));}
 await db.exec(table(await source('0003_extended'),'announcements'));
 await db.exec(table(await source('0069_faq_and_support'),'faq_entries'));
 const migration=await source('0134_announcement_receipts');await db.exec(migration);await db.exec(migration);
 await db.exec(`insert into auth.users(id) values('${id(1)}'),('${id(2)}'),('${id(3)}');
 insert into clubs(id,name) values('${id(10)}','Test');
 insert into club_memberships(club_id,profile_id,role) values('${id(10)}','${id(1)}','athlete'),('${id(10)}','${id(2)}','coach');
 insert into announcements(id,club_id,title,body) values('${id(20)}','${id(10)}','Başlık','Metin');`);
 return db;}
async function load(db){return(await db.query('select announcement_detail($1) v',[id(20)])).rows[0].v;}
async function record(db,v,ack){return(await db.query('select record_announcement_receipt($1,$2,$3) v',[id(20),v,ack])).rows[0].v;}
test('opening and explicit acknowledgement are separate, retries keep first timestamps',async()=>{const db=await setup();try{
 await actor(db,1);await db.exec('set role authenticated');let d=await load(db);assert.equal(d.read_at,null);assert.equal(d.read_count,null);
 d=await record(db,d.version,false);assert.ok(d.read_at);assert.equal(d.acknowledged_at,null);
 const first=d.read_at;d=await record(db,d.version,true);assert.ok(d.acknowledged_at);
 assert.equal((await record(db,d.version,false)).acknowledged_at,d.acknowledged_at);assert.equal(d.read_at,first);
 await actor(db,2);d=await load(db);assert.equal(d.read_count,1);assert.equal(d.acknowledged_count,1);
 await assert.rejects(()=>db.query('select * from announcement_receipts'),/permission denied/);
 }finally{await db.close();}});
test('changed content invalidates old acknowledgement and stale write',async()=>{const db=await setup();try{
 await actor(db,1);const d=await load(db);await record(db,d.version,true);
 await db.exec(`update announcements set body='Yeni içerik' where id='${id(20)}'`);
 await assert.rejects(()=>record(db,d.version,true),/Duyuru değişti/);assert.equal((await load(db)).acknowledged_at,null);
 await actor(db,2);assert.equal((await load(db)).read_count,0);
 await db.exec(`update announcements set body='Metin' where id='${id(20)}'`);
 await actor(db,1);assert.equal((await load(db)).acknowledged_at,null);
 await assert.rejects(()=>record(db,d.version,true),/Duyuru değişti/);
 }finally{await db.close();}});
test('outsider, removed member, anonymous and null action are denied',async()=>{const db=await setup();try{
 await actor(db,1);const d=await load(db);await assert.rejects(()=>record(db,d.version,null));
 await actor(db,3);await assert.rejects(()=>load(db),/erişilemiyor/);await assert.rejects(()=>record(db,d.version,true));
 await actor(db,1);await db.exec(`delete from club_memberships where profile_id='${id(1)}'`);await assert.rejects(()=>load(db));
 await db.exec('set role anon');await assert.rejects(()=>load(db),/permission denied/);
 }finally{await db.close();}});
