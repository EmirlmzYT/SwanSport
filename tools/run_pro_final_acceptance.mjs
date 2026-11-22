// Disposable local Supabase acceptance for the SwanSport Pro hand-off.
// Never accepts a remote URL and never prints tokens or signed URLs.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {mkdir,writeFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {backend,commandSpec,project,statusKey} from './start_local_test_center.mjs';

const container='supabase_db_'+project;
const club='53570000-0000-4000-8000-000000000001';
const athlete='53570000-0000-4000-8000-000000000012';
const checks=[];

function command(name,args,input){
 const spec=commandSpec(name,args);
 const result=spawnSync(spec.command,spec.args,{input,encoding:'utf8',maxBuffer:8*1024*1024,windowsVerbatimArguments:spec.verbatim});
 if(result.status!==0)throw Error(name+' failed: '+(result.stderr||'').slice(0,500));
 return result.stdout.trim();
}
function sql(input){return command('docker',['exec','-i',container,'psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-At'],input);}
function literal(value){return "'"+String(value).replaceAll("'","''")+"'";}
async function check(name,fn){await fn();checks.push({name,status:'passed'});console.log('PASS '+name);}

async function main(){
 assert.equal(new URL(backend).hostname,'127.0.0.1');
 const info=JSON.parse(command('docker',['inspect',container]))[0];
 assert.equal(info.Config.Labels['com.supabase.cli.project'],project);
 assert.equal(sql('select project from public._local_test_center_install'),project);
 const status=JSON.parse(command('npx.cmd',['--yes','supabase@2.121.0','status','--workdir','tools/local-test-center','--output','json']));
 const anon=statusKey(status);

 async function request(path,{session,body,raw,method,allowError=false,headers={}}={}){
  const token=session?.access_token??anon;
  const isRaw=raw!==undefined;
  const response=await fetch(backend+path,{
   method:method??(body===undefined&&raw===undefined?'GET':'POST'),
   headers:{apikey:anon,Authorization:'Bearer '+token,...(!isRaw?{'Content-Type':'application/json'}:{}),Prefer:'return=representation',...headers},
   body:isRaw?raw:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000),
  });
  const contentType=response.headers.get('content-type')??'';
  const data=contentType.includes('json')?await response.json().catch(()=>null):new Uint8Array(await response.arrayBuffer());
  if(!response.ok&&!allowError)throw Error(`Local API ${path.split('?')[0]} HTTP ${response.status} ${(data?.code||data?.error_code||'')} ${(data?.message||'')}`);
  return {ok:response.ok,status:response.status,data};
 }
 const login=async email=>(await request('/auth/v1/token?grant_type=password',{body:{email,password:'test1234'}})).data;
 async function account(slug){
  const email=slug+'@test.swansport.invalid';
  let result=await request('/auth/v1/signup',{body:{email,password:'test1234'},allowError:true});
  if(!result.ok&&![400,422].includes(result.status))throw Error('Local signup failed: '+slug);
  return login(email);
 }
 const rpc=(session,name,body,allowError=false)=>request('/rest/v1/rpc/'+name,{session,body,allowError});
 const signedUrl=value=>value.startsWith('http')?value:backend+(value.startsWith('/storage/v1')?'':'/storage/v1')+value;
 const manager=await login('kulup-yoneticisi@test.swansport.invalid');
 const coach=await login('antrenor-3@test.swansport.invalid');
 const student=await login('lisansli-sporcu@test.swansport.invalid');
 const outsider=await login('taraftar@test.swansport.invalid');
 const run=Date.now().toString(36);
 const acceptanceNationalId='8'+Date.now().toString().slice(-10);
 const reviewerA=await account('pro-final-reviewer-a');
 const reviewerB=await account('pro-final-reviewer-b');
 const applicantA=await account('pro-final-applicant-a-'+run);
 const applicantB=await account('pro-final-applicant-b-'+run);
 const otherAdmin=await account('pro-final-other-club-admin');
 const guardian=await account('pro-final-guardian');
 const otherClub=randomUUID();
 sql(`begin;
  update public.profiles set is_platform_admin=true where id in (${literal(reviewerA.user.id)},${literal(reviewerB.user.id)});
  select set_config('request.jwt.claim.sub',${literal(reviewerA.user.id)},true);
  do $fixture$ declare credential uuid; begin
   insert into public.profile_credentials(profile_id,kind) values(${literal(otherAdmin.user.id)},'identity')
    on conflict(profile_id) where kind='identity' do nothing;
   select id into credential from public.profile_credentials where profile_id=${literal(otherAdmin.user.id)} and kind='identity';
   insert into public.verification_documents(owner_type,owner_id,doc_type,storage_path,uploaded_by)
    values('credential',credential,'kimlik',${literal(otherAdmin.user.id+'/LOCAL-SYNTHETIC-FIXTURE.txt')},${literal(otherAdmin.user.id)}) on conflict do nothing;
   perform public.review_credential(credential,true,'LOCAL SYNTHETIC FIXTURE',null,null,'44444444440',null);
   if not exists(select 1 from public.profile_credentials where profile_id=${literal(otherAdmin.user.id)} and kind='coach' and sport_code='tenis') then
    insert into public.profile_credentials(profile_id,kind,coach_level,sport_code,expires_on)
     values(${literal(otherAdmin.user.id)},'coach',3,'tenis','2028-12-31') returning id into credential;
    perform public.review_credential(credential,true,'LOCAL SYNTHETIC FIXTURE',3,'tenis',null,'2028-12-31');
   end if;
   insert into public.profile_credentials(profile_id,kind) values(${literal(guardian.user.id)},'identity')
    on conflict(profile_id) where kind='identity' do nothing;
   select id into credential from public.profile_credentials where profile_id=${literal(guardian.user.id)} and kind='identity';
   insert into public.verification_documents(owner_type,owner_id,doc_type,storage_path,uploaded_by)
    values('credential',credential,'kimlik',${literal(guardian.user.id+'/LOCAL-SYNTHETIC-FIXTURE.txt')},${literal(guardian.user.id)}) on conflict do nothing;
   perform public.review_credential(credential,true,'LOCAL SYNTHETIC FIXTURE',null,null,'55555555550',null);
  end $fixture$;
  insert into public.clubs(id,name,status,sport_code,created_by) values(${literal(otherClub)},'LOCAL Other Club','active','tenis',${literal(otherAdmin.user.id)});
  select set_config('request.jwt.claim.sub',${literal(otherAdmin.user.id)},true);
  insert into public.club_memberships(club_id,profile_id,role,status) values(${literal(otherClub)},${literal(otherAdmin.user.id)},'club_admin','active');
  commit;`);
 if(Number(sql(`select count(*) from public.guardians where athlete_id=${literal(athlete)} and profile_id=${literal(guardian.user.id)}`))===0){
  const invite=(await rpc(manager,'create_guardian_invite',{p_athlete:athlete})).data;
  await rpc(guardian,'redeem_invite_code',{p_code:invite});
 }

 async function submitCredential(session,label){
  const existing=(await request('/rest/v1/profile_credentials?select=id,status&profile_id=eq.'+session.user.id+'&kind=eq.identity&status=eq.pending',{session})).data[0];
  if(existing){
   const document=(await request('/rest/v1/verification_documents?select=storage_path&owner_type=eq.credential&owner_id=eq.'+existing.id,{session})).data[0];
   return {credential:existing,path:document.storage_path,bytes:new TextEncoder().encode('LOCAL SYNTHETIC '+label)};
  }
  const credential=(await request('/rest/v1/profile_credentials',{session,body:{profile_id:session.user.id,kind:'identity'}})).data[0];
  const path=session.user.id+'/'+Date.now()+'_'+label+'.pdf';
  const bytes=new TextEncoder().encode('LOCAL SYNTHETIC '+label);
  await request('/storage/v1/object/verification-docs/'+path,{session,raw:bytes,headers:{'Content-Type':'application/pdf','x-upsert':'false'}});
  await request('/rest/v1/verification_documents',{session,body:{owner_type:'credential',owner_id:credential.id,doc_type:'kimlik',storage_path:path,uploaded_by:session.user.id}});
  return {credential,path,bytes};
 }
 const approval=await submitCredential(applicantA,'APPROVE');
 const rejection=await submitCredential(applicantB,'REJECT');

 await check('App upload -> Pro protected preview -> one concurrent approval -> App status',async()=>{
  const pending=(await request('/rest/v1/profile_credentials?select=id,status&id=eq.'+approval.credential.id,{session:reviewerA})).data;
  assert.deepEqual(pending.map(row=>row.status),['pending']);
  const signed=(await request('/storage/v1/object/sign/verification-docs/'+approval.path,{session:reviewerA,body:{expiresIn:300}})).data;
  assert.ok(signed.signedURL||signed.signedUrl);
  const signedPath=signed.signedURL??signed.signedUrl;
  const preview=await fetch(signedUrl(signedPath),{signal:AbortSignal.timeout(20000)});
  assert.equal(preview.status,200);
  assert.deepEqual(new Uint8Array(await preview.arrayBuffer()),approval.bytes);
  const forbidden=await request('/storage/v1/object/sign/verification-docs/'+approval.path,{session:outsider,body:{expiresIn:300},allowError:true});
  assert.equal(forbidden.ok,false);
  const params={p_cred:approval.credential.id,p_approve:true,p_note:'LOCAL acceptance',p_coach_level:null,p_sport_code:null,p_national_id:acceptanceNationalId,p_expires_on:null,p_expected_status:'pending'};
  const decisions=await Promise.all([reviewerA,reviewerB].map(session=>rpc(session,'review_credential',params,true)));
  assert.equal(decisions.filter(result=>result.ok).length,1);
  assert.equal(decisions.filter(result=>!result.ok).length,1);
  const own=(await request('/rest/v1/profile_credentials?select=id,status,reviewed_by&id=eq.'+approval.credential.id,{session:applicantA})).data;
  assert.equal(own[0].status,'approved');assert.ok(own[0].reviewed_by);
 });

 await check('Pro rejection with reason is visible to the applicant',async()=>{
  const result=await rpc(reviewerA,'review_credential',{p_cred:rejection.credential.id,p_approve:false,p_note:'LOCAL eksik belge',p_coach_level:null,p_sport_code:null,p_national_id:null,p_expires_on:null,p_expected_status:'pending'});
  assert.equal(result.ok,true);
  const own=(await request('/rest/v1/profile_credentials?select=status,note&id=eq.'+rejection.credential.id,{session:applicantB})).data[0];
  assert.equal(own.status,'rejected');assert.equal(own.note,'LOCAL eksik belge');
 });

 await check('club document upload, protected preview, cross-club denial and archive',async()=>{
  const path=club+'/'+Date.now()+'_LOCAL-club-document.pdf';
  const row=(await request('/rest/v1/documents',{session:manager,body:{club_id:club,name:'LOCAL Yetki Belgesi',kind:'pdf',size_label:'1 KB',storage_path:path,version:1,valid_until:'2028-12-31',uploaded_by:manager.user.id}})).data[0];
  const bytes=new TextEncoder().encode('LOCAL SYNTHETIC CLUB DOCUMENT');
  await request('/storage/v1/object/club-documents/'+path,{session:manager,raw:bytes,headers:{'Content-Type':'application/pdf','x-upsert':'false'}});
  const signed=(await request('/storage/v1/object/sign/club-documents/'+path,{session:manager,body:{expiresIn:300}})).data;
  const signedPath=signed.signedURL??signed.signedUrl;assert.ok(signedPath);
  const preview=await fetch(signedUrl(signedPath));assert.equal(preview.status,200);
  const hidden=(await request('/rest/v1/documents?select=id&id=eq.'+row.id,{session:otherAdmin})).data;assert.deepEqual(hidden,[]);
  assert.equal((await request('/storage/v1/object/sign/club-documents/'+path,{session:otherAdmin,body:{expiresIn:300},allowError:true})).ok,false);
  const archived=(await request('/rest/v1/documents?id=eq.'+row.id,{session:manager,method:'PATCH',body:{archived_at:new Date().toISOString()}})).data[0];
  assert.ok(archived.archived_at);
 });

 await check('multi-branch coach metric is athlete scoped; athlete and guardian visibility stay isolated',async()=>{
  const protocol=randomUUID(),session=randomUUID();
  const config={archetype:'attempt_drill',set_count:2,units_per_set:20,prep_seconds:10,shoot_seconds:60,collect_seconds:30,rest_seconds:15,max_unit_score:10,entry_mode:'flexible',mode:'technique'};
  sql(`begin;
   select set_config('request.jwt.claim.sub',${literal(reviewerA.user.id)},true);
   insert into public.club_training_sports(club_id,sport_code,created_by) values(${literal(club)},'tenis',${literal(coach.user.id)}) on conflict do nothing;
   do $fixture$ declare credential uuid; begin
    if not exists(select 1 from public.profile_credentials where profile_id=${literal(coach.user.id)} and kind='coach' and sport_code='tenis') then
     insert into public.profile_credentials(profile_id,kind,coach_level,sport_code,expires_on)
      values(${literal(coach.user.id)},'coach',3,'tenis','2028-12-31') returning id into credential;
     perform public.review_credential(credential,true,'LOCAL SYNTHETIC FIXTURE',3,'tenis',null,'2028-12-31');
    end if;
    if not exists(select 1 from public.profile_credentials where profile_id=${literal(student.user.id)} and kind='athlete_licensed' and sport_code='tenis') then
     insert into public.profile_credentials(profile_id,kind,sport_code,expires_on)
      values(${literal(student.user.id)},'athlete_licensed','tenis','2028-12-31') returning id into credential;
     perform public.review_credential(credential,true,'LOCAL SYNTHETIC FIXTURE',null,'tenis',null,'2028-12-31');
    end if;
   end $fixture$;
   insert into public.training_protocols(id,club_id,sport_code,name,config,published,created_by)
    values(${literal(protocol)},${literal(club)},'tenis','LOCAL Tenis Servis',${literal(JSON.stringify(config))}::jsonb,true,${literal(coach.user.id)});
   insert into public.training_sessions(id,club_id,protocol_id,kind,status,current_set,current_phase,created_by)
    values(${literal(session)},${literal(club)},${literal(protocol)},'club','live',1,'active_drill',${literal(coach.user.id)});
   insert into public.training_session_participants(session_id,athlete_id) values(${literal(session)},${literal(athlete)});
   commit;`);
  const sports=(await rpc(coach,'my_training_club_sports',{p_club_id:club})).data.map(row=>row.sport_code);
  assert.ok(sports.includes('futbol'));assert.ok(sports.includes('tenis'));
  const metric={drill_name:'servis',successful:16,faults:4,total_attempts:20,success_rate:0.8};
  await rpc(coach,'submit_coach_set_metric',{p_session:session,p_athlete:athlete,p_set_no:1,p_total:null,p_metric_payload:metric});
  await rpc(coach,'lock_session_results',{p_session:session});
  await rpc(coach,'share_training_feedback',{p_session:session,p_athlete:athlete,p_feedback:'LOCAL servis sonucu paylaşıldı'});
  const athleteSets=(await request('/rest/v1/training_sets?select=session_id,athlete_id,metric_payload,locked_at&session_id=eq.'+session,{session:student})).data;
  assert.equal(athleteSets.length,1,'athlete must read exactly one set');assert.deepEqual(athleteSets[0].metric_payload,metric);assert.ok(athleteSets[0].locked_at);
  const history=(await rpc(student,'my_training_history_v2',{p_limit:30})).data.find(row=>row.session_id===session);
  assert.equal(history.sport_code,'tenis');assert.equal(history.club_id,club);
  const progressParams={p_athlete:athlete,p_from:'2026-01-01',p_to:'2026-12-31'};
  const guardianProgress=(await rpc(guardian,'training_progress',progressParams)).data.filter(row=>row.session_id===session);
  assert.equal(guardianProgress.length,1,'linked guardian must read exactly one explicitly shared result');
  assert.equal(guardianProgress[0].sport_code,'tenis');
  const outsiderProgress=(await rpc(outsider,'training_progress',progressParams)).data.filter(row=>row.session_id===session);
  assert.deepEqual(outsiderProgress,[]);
 });

 return {status:'passed',backend:'disposable-local-supabase',checks,production_contact:false};
}

await mkdir('build',{recursive:true});
try{const report=await main();await writeFile('build/pro-final-local-acceptance.json',JSON.stringify(report,null,2));}
catch(error){await writeFile('build/pro-final-local-acceptance.json',JSON.stringify({status:'failed',checks,error:error.message},null,2));console.error(error.message);process.exitCode=1;}
