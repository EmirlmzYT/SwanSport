import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';

const migration=new URL('../supabase/migrations/0028_hardening.sql',import.meta.url);

test('0028 is repeatable on a clean database without recreating retired helpers',async()=>{
 const db=new PGlite();
 await db.exec('create role anon; create role authenticated;');
 const source=await readFile(migration,'utf8');
 await db.exec(source);
 await db.exec(source);
 const result=await db.query(`select
  to_regprocedure('public.seed_demo_data(text)') is null as seed_absent,
  to_regprocedure('public.clear_demo_data(text)') is null as clear_absent,
  to_regprocedure('public.demo_target_user(text)') is null as target_absent`);
 assert.deepEqual(result.rows,[{seed_absent:true,clear_absent:true,target_absent:true}]);
 await db.close();
});
