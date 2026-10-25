// Isolated PostgreSQL tests; never connects to the production database.
import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {test} from 'node:test';
const admin='00000000-0000-0000-0000-000000000001', member='00000000-0000-0000-0000-000000000002';
const migration=await readFile(new URL('../supabase/migrations/0109_platform_mission_control.sql',import.meta.url),'utf8');
async function setup(){
  const db=new PGlite();
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
    create table public.profiles(id uuid primary key,is_platform_admin boolean default false);
    insert into profiles values('${admin}',true),('${member}',false);
    create function public.is_platform_admin() returns boolean language sql stable security definer set search_path=public as
      $$select coalesce((select is_platform_admin from profiles where id=auth.uid()),false)$$;
    grant usage on schema public,auth to anon,authenticated;`);
  await db.exec(`begin; ${migration} commit;`);
  return db;
}
async function actor(db,id,role='authenticated'){
  await db.exec('reset role');
  await db.query("select set_config('test.actor',$1,false)",[id??'']);
  await db.exec(`set role ${role}`);
}
test('public config allowlist, four seeds and repeat migration preserve edits',async()=>{
  const db=await setup();try{
    await actor(db,null,'anon');
    const cfg=(await db.query('select get_public_platform_config() c')).rows[0].c;
    assert.equal(Object.keys(cfg).length,5);assert.equal(cfg.commissions.marketplace_rate,5);
    assert.equal((await db.query('select * from platform_plans')).rows.length,4);
    await actor(db,admin);
    await db.query("select update_platform_setting('branding',$1::jsonb)",[JSON.stringify({app_name:'Updated'})]);
    await db.exec('reset role');await db.exec(`begin; ${migration} commit;`);
    assert.equal((await db.query("select value->>'app_name' n from platform_settings where key='branding'")).rows[0].n,'Updated');
    assert.equal((await db.query('select count(*)::int n from platform_audit_logs')).rows[0].n,1);
    await actor(db,admin);await db.exec("insert into platform_settings(key,value) values('future_public','{}')");
    await actor(db,null,'anon');
    assert.equal((await db.query('select get_public_platform_config() c')).rows[0].c.future_public,undefined);
  }finally{await db.close();}
});
test('anon and ordinary account cannot write settings/plans or read audits',async()=>{
  const db=await setup();try{
    for(const [id,role] of [[null,'anon'],[member,'authenticated']]){
      await actor(db,id,role);
      await assert.rejects(db.query("select update_platform_setting('maintenance','{}')"));
      await assert.rejects(db.exec("insert into platform_settings(key,value) values('bad','{}')"));
      await assert.rejects(db.exec("insert into platform_plans(target,code,name) values('club','bad','Bad')"));
      if(role==='anon') await assert.rejects(db.exec("update platform_settings set value='{}' where key='branding'"));
      else {
        assert.equal((await db.query("update platform_settings set value='{}' where key='branding' returning key")).rows.length,0);
        assert.equal((await db.query('delete from platform_plans returning id')).rows.length,0);
      }
    }
  }finally{await db.close();}
});
test('inactive plans are hidden from public but visible to admin; plan writes are audited',async()=>{
  const db=await setup();try{
    await actor(db,admin);await db.exec("update platform_plans set is_active=false where code='pro'");
    assert.equal((await db.query('select * from platform_plans')).rows.length,4);
    await actor(db,null,'anon');assert.equal((await db.query('select * from platform_plans')).rows.length,3);
    await actor(db,member);assert.equal((await db.query('select * from platform_plans')).rows.length,3);
    assert.equal((await db.query('select * from platform_audit_logs')).rows.length,0);
    await actor(db,admin);const log=(await db.query('select * from platform_audit_logs')).rows[0];
    assert.equal(log.entity_type,'platform_plans');assert.equal(log.old_state.is_active,true);assert.equal(log.new_state.is_active,false);
  }finally{await db.close();}
});
test('RPC/direct writes stamp real actor and atomic old/new states; audit is append-only',async()=>{
  const db=await setup();try{
    await actor(db,admin);
    await db.query("select update_platform_setting('maintenance',$1::jsonb)",[JSON.stringify({enabled:true,message:'Maintenance'})]);
    await db.query("update platform_settings set value='{}',updated_by=$1,updated_at='2000-01-01' where key='broadcast_alert'",[member]);
    const logs=(await db.query('select * from platform_audit_logs order by created_at,id')).rows;
    assert.equal(logs.length,2);assert(logs.every(l=>l.actor_id===admin));
    const maintenance=logs.find(l=>l.entity_id==='maintenance');
    assert.equal(maintenance.old_state.value.enabled,false);assert.equal(maintenance.new_state.value.enabled,true);
    assert.equal((await db.query("select updated_by from platform_settings where key='broadcast_alert'")).rows[0].updated_by,admin);
    for(const sql of ["delete from platform_audit_logs","update platform_audit_logs set action='fake'","insert into platform_audit_logs(action,entity_type) values('fake','x')"]){await assert.rejects(db.exec(sql));}
    await db.exec('begin');await db.exec("update platform_settings set value='{}' where key='branding'");await db.exec('rollback');
    assert.equal((await db.query('select count(*)::int n from platform_audit_logs')).rows[0].n,2);
  }finally{await db.close();}
});
test('invalid payloads/prices/target reject and do not generate audit records',async()=>{
  const db=await setup();try{
    await actor(db,admin);
    for(const value of ['null','[]','true'])await assert.rejects(db.query("select update_platform_setting('branding',$1::jsonb)",[value]));
    await assert.rejects(db.exec("select update_platform_setting('missing','{}')"));
    for(const sql of ["update platform_plans set price_monthly=-1","update platform_plans set price_monthly='NaN'","update platform_plans set price_yearly='Infinity'","update platform_plans set max_athletes=-1","update platform_plans set features='{}'","update platform_plans set target='other'"]){await assert.rejects(db.exec(sql));}
    assert.equal((await db.query('select count(*)::int n from platform_audit_logs')).rows[0].n,0);
    await actor(db,null,'anon');await assert.rejects(db.exec('select * from platform_audit_logs'));
  }finally{await db.close();}
});
