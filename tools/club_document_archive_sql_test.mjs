import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import test from 'node:test';
import assert from 'node:assert/strict';

const migration=await readFile(new URL('../supabase/migrations/20261119120000_club_document_archive.sql',import.meta.url),'utf8');
const guard=await readFile(new URL('../supabase/migrations/20261121163354_separate_club_document_vault_guard.sql',import.meta.url),'utf8');
const qualifiedPolicies=await readFile(new URL('../supabase/migrations/20261121163636_qualify_club_document_storage_object_name.sql',import.meta.url),'utf8');

test('club document archive migration is idempotent and keeps separate private storage policies',async()=>{
 const db=new PGlite();
 try{
  await db.exec(`
   create schema storage;create schema auth;
   create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
   create table profiles(id uuid primary key);
   create table clubs(id uuid primary key);
   create table athletes(id uuid primary key,club_id uuid not null references clubs(id));
   create table documents(id uuid primary key,club_id uuid not null references clubs(id),name text not null,kind text not null default 'file',size_label text,owner_type text,owner_id uuid,created_at timestamptz not null default now());
   create table storage.buckets(id text primary key,name text not null,public boolean,file_size_limit bigint,allowed_mime_types text[]);
   create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
   create function is_club_staff(uuid) returns boolean language sql stable as $$select true$$;
   create function is_club_member(uuid) returns boolean language sql stable as $$select true$$;
   create function storage.foldername(text) returns text[] language sql immutable as $$select string_to_array($1,'/')$$;
   create role authenticated;
   create role anon;
  `);
  await db.exec(`begin;${migration}commit;`);
  await db.exec(`begin;${migration}commit;`);
  await db.exec(`begin;${guard}commit;`);
  await db.exec(`begin;${qualifiedPolicies}commit;`);
  const columns=(await db.query("select column_name from information_schema.columns where table_name='documents'")).rows.map(r=>r.column_name);
  for(const name of ['storage_path','version','valid_until','archived_at','uploaded_by']) assert.ok(columns.includes(name),name);
  const bucket=(await db.query("select public,file_size_limit from storage.buckets where id='club-documents'")).rows[0];
  assert.equal(bucket.public,false);assert.equal(Number(bucket.file_size_limit),10485760);
  const policies=(await db.query("select policyname from pg_policies where schemaname='storage' and tablename='objects' order by 1")).rows.map(r=>r.policyname);
  assert.deepEqual(policies,['club_document_delete','club_document_read','club_document_update','club_document_upload']);
  const uploadCheck=(await db.query("select with_check from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_document_upload'")).rows[0].with_check;
  // pg_get_expr deparses the already schema-bound policy reference as
  // `objects.name`; the migration source remains explicitly qualified.
  assert.match(uploadCheck,/objects\.name/);
  const actor='10000000-0000-4000-8000-000000000001',club='10000000-0000-4000-8000-000000000002';
  await db.query('insert into profiles values($1)',[actor]);await db.query('insert into clubs values($1)',[club]);
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[actor]);
  const inserted=(await db.query("insert into documents(id,club_id,name,storage_path,uploaded_by) values(gen_random_uuid(),$1::uuid,'Club',$1::text||'/1_file.pdf',$2::uuid) returning uploaded_by",[club,actor])).rows[0];
  assert.equal(inserted.uploaded_by,actor);
  await assert.rejects(db.query("insert into documents(id,club_id,name,storage_path) values(gen_random_uuid(),$1::uuid,'Wrong',$2::text||'/1_file.pdf')",[club,actor]),/documents_storage_path_safe/);
 }finally{await db.close();}
});
