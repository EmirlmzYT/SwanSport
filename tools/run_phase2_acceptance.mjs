// Real GoTrue/PostgREST acceptance. Only the pinned disposable local container.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdir,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {backend,project,statusKey} from './start_local_test_center.mjs';
const container='supabase_db_'+project;
const club='53570000-0000-4000-8000-000000000001';
const athlete='53570000-0000-4000-8000-000000000012';
const event='53570000-0000-4000-8000-000000000013';
const checks=[];
function command(name,args,input){
 const r=spawnSync(name,args,{input,encoding:'utf8',maxBuffer:8*1024*1024});
 if(r.status!==0)throw Error(name+' failed: '+(r.stderr||'').slice(0,450));
 return r.stdout.trim();
}
function sql(input){return command('docker',['exec','-i',container,'psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-At'],input);}
async function check(name,fn){await fn();checks.push({name,status:'passed'});console.log('PASS '+name);}
async function main(){
 assert.equal(new URL(backend).hostname,'127.0.0.1');
 const info=JSON.parse(command('docker',['inspect',container]))[0];
 assert.equal(info.Config.Labels['com.supabase.cli.project'],project);
 assert.equal(sql('select project from public._local_test_center_install'),project);
 const status=JSON.parse(command('npx',['--yes','supabase@2.121.0','status','--workdir','tools/local-test-center','--output','json']));
 const anon=statusKey(status);
 async function api(path,{token,body,method=body===undefined?'GET':'POST',allowError=false}={}){
  const response=await fetch(backend+path,{method,headers:{apikey:anon,Authorization:'Bearer '+(token||anon),'Content-Type':'application/json',Prefer:'return=representation'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
  const data=await response.json().catch(()=>null);
  if(!response.ok&&!allowError)throw Error('Local API '+path.split('?')[0]+' HTTP '+response.status+' '+(data?.code||data?.error_code||''));
  return {ok:response.ok,data,status:response.status};
 }
 const login=async slug=>(await api('/auth/v1/token?grant_type=password',{body:{email:slug+'@test.swansport.invalid',password:'test1234'}})).data;
 const rpc=async(session,name,body,allowError=false)=>api('/rest/v1/rpc/'+name,{token:session.access_token,body,allowError});
 const manager=await login('kulup-yoneticisi'),coach=await login('antrenor-3'),student=await login('lisansli-sporcu'),accountant=await login('muhasebeci'),outsider=await login('taraftar');
 await check('five real Auth sessions and account isolation',async()=>{
  assert.equal(new Set([manager,coach,student,accountant,outsider].map(s=>s.user.id)).size,5);
  for(const session of [coach,accountant,outsider]){
   const rows=(await api('/rest/v1/athletes?select=id&club_id=eq.'+club,{token:session.access_token})).data;
   assert.equal(rows.length,session===coach?1:0);
  }
 });
 await check('active member resolves to the existing athlete and team',async()=>{
  const result=await rpc(manager,'create_athlete_from_member',{p_club:club,p_profile:student.user.id});assert.equal(result.data,athlete);
  const rows=(await api('/rest/v1/team_memberships?select=athlete_id&athlete_id=eq.'+athlete,{token:coach.access_token})).data;
  assert.equal(rows.length,1);
 });
 sql(`begin;do $$begin if not exists(select 1 from public._local_test_center_install where project='${project}') then raise exception 'LOCAL ONLY';end if;end$$;
 update public.feature_flags set audience='everyone' where key in ('offline_attendance','parent_hub');commit;`);
 await check('two independent sessions conflict visibly; retries are idempotent and account scoped',async()=>{
  const second=await login('antrenor-3');
  const snapshot=(await rpc(coach,'prepare_attendance_offline',{p_event:event})).data;
  const version=snapshot.rows.find(r=>r.athlete_id===athlete).version;
  const ops=[randomUUID(),randomUUID()];
  const marks=['absent','excused'].map(status=>[{athlete_id:athlete,status,version}]);
  const results=await Promise.all([coach,second].map((session,i)=>rpc(session,'save_attendance_offline',{p_actor:coach.user.id,p_event:event,p_op_id:ops[i],p_marks:marks[i]})));
  assert.equal(results.reduce((n,r)=>n+r.data.applied,0),1);
  assert.equal(results.reduce((n,r)=>n+r.data.conflicts.length,0),1);
  const winner=results.findIndex(r=>r.data.applied===1);
  assert.equal((await rpc(coach,'save_attendance_offline',{p_actor:coach.user.id,p_event:event,p_op_id:ops[winner],p_marks:marks[winner]})).data.replayed,true);
  assert.equal((await rpc(accountant,'save_attendance_offline',{p_actor:coach.user.id,p_event:event,p_op_id:randomUUID(),p_marks:marks[0]},true)).ok,false);
 });
 await check('direct messages, read state and bell exclusion use real RLS',async()=>{
  const message=randomUUID();
  await api('/rest/v1/direct_messages',{token:coach.access_token,body:{id:message,sender_id:coach.user.id,recipient_id:student.user.id,body:'LOCAL phase two acceptance'}});
  let rows=(await api('/rest/v1/direct_messages?select=id,read_at&id=eq.'+message,{token:student.access_token})).data;
  assert.equal(rows.length,1);
  await rpc(student,'mark_messages_read',{p_ids:[message]});
  rows=(await api('/rest/v1/direct_messages?select=id,read_at&id=eq.'+message,{token:student.access_token})).data;assert.ok(rows[0].read_at);
  const inbox=(await rpc(student,'my_notifications',{p_category:'',p_limit:60})).data;assert.ok(inbox.every(n=>n.kind!=='message'));
  assert.equal((await api('/rest/v1/direct_messages?select=id&id=eq.'+message,{token:outsider.access_token})).data.length,0);
 });
 await check('accountant ledger has no athlete name access',async()=>{
  const rows=(await rpc(accountant,'acc_ledger',{p_club:club,p_limit:20,p_offset:0})).data;
  const name=sql(`select first_name||' '||last_name from public.athletes where id='${athlete}'`);
  assert.ok(!JSON.stringify(rows).includes(name));
  assert.equal((await api('/rest/v1/athletes?select=first_name,last_name',{token:accountant.access_token})).data.length,0);
 });
 await check('parent invitation uses real identity approval, redeem and live unlink revocation',async()=>{
  const email='phase2-parent@test.swansport.invalid';
  await api('/auth/v1/signup',{body:{email,password:'test1234'}});
  const parent=(await api('/auth/v1/token?grant_type=password',{body:{email,password:'test1234'}})).data;
  const p=parent.user.id;assert.match(p,/^[a-f0-9-]{36}$/);
  // Synthetic approval is restricted to the disposable marker-controlled DB.
  sql(`begin;select set_config('request.jwt.claim.sub','${manager.user.id}',true);
   update public.profiles set is_platform_admin=true where id='${manager.user.id}';
   do $$declare c uuid;begin insert into public.profile_credentials(profile_id,kind) values('${p}','identity') returning id into c;
   insert into public.verification_documents(owner_type,owner_id,doc_type,storage_path,uploaded_by) values('credential',c,'kimlik','${p}/LOCAL-SYNTHETIC-FIXTURE.txt','${p}');
   perform public.review_credential(c,true,'LOCAL SYNTHETIC FIXTURE',null,null,'44444444440',null);end$$;
   update public.profiles set is_platform_admin=false where id='${manager.user.id}';commit;`);
  const code=(await rpc(manager,'create_guardian_invite',{p_athlete:athlete})).data;
  await rpc(parent,'redeem_invite_code',{p_code:code});
  assert.ok(JSON.stringify((await rpc(parent,'my_parent_actions',{})).data).includes(athlete));
  sql(`delete from public.guardians where profile_id='${p}' and athlete_id='${athlete}'`);
  assert.ok(!JSON.stringify((await rpc(parent,'my_parent_actions',{})).data).includes(athlete));
 });
 return {status:'passed',backend:'disposable-local-supabase',checks,physical_device:'not_verified',offline_device_restart:'covered_by_existing_persistence_tests_not_physical_UAT'};
}
await mkdir('build',{recursive:true});
try{const report=await main();await writeFile('build/phase2-acceptance.json',JSON.stringify(report,null,2));}
catch(error){await writeFile('build/phase2-acceptance.json',JSON.stringify({status:'failed',checks,error:error.message},null,2));console.error(error.message);process.exitCode=1;}
