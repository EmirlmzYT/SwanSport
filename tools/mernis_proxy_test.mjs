import {readFile} from 'node:fs/promises';
import {webcrypto} from 'node:crypto';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const source=await readFile(new URL('../apps/swansport_app/functions_helpers/identity-verification.js',import.meta.url),'utf8');
const {createVerifyTcknHandler,resolveKpsProvider,validNationalId,toTurkishUpper,withIdentityCors} =
  await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const uid='10000000-0000-0000-0000-000000000050';
const env={SUPABASE_URL:'https://backend.example',SUPABASE_ANON_KEY:'public-test',
  SUPABASE_SERVICE_ROLE_KEY:'backend-test-only',IDENTITY_RATE_HMAC_SECRET:'test-only-secret-not-production-123456789'};
const payload={national_id:'10000000146',first_name:' ilker  ışık ',last_name:'çelik',birth_year:1995};
const request=(body=payload,method='POST',headers={})=>new Request('https://app.example/api/verify-tckn',{
  method,headers:{Authorization:'Bearer user-test','Content-Type':'application/json','CF-Connecting-IP':'192.0.2.1',...headers},
  ...(method==='POST'?{body:typeof body==='string'?body:JSON.stringify(body)}:{})});
function fixture({available=true,kind='institutional-kps',verified=true,rate=true,auth=true,completion=true,
  completionCode='error',providerThrow=false,fetchThrow=false}={}){
  const calls=[];const providerCalls=[];
  const handler=createVerifyTcknHandler({cryptoImpl:webcrypto,
    resolveProvider:()=>({available,kind,verify:async fields=>{providerCalls.push(fields);if(providerThrow)throw new Error('PRIVATE_PAYLOAD');return verified;}}),
    fetchImpl:async(url,init)=>{
      if(fetchThrow)throw new Error('PRIVATE_TOKEN');
      const path=new URL(url).pathname;calls.push({path,init});
      if(path==='/auth/v1/user')return Response.json(auth?{id:uid}:{error:'PRIVATE_PAYLOAD'},{status:auth?200:401});
      if(path.endsWith('consume_identity_verification_attempt'))return Response.json(rate);
      if(path.endsWith('complete_identity_verification'))return Response.json(completion?null:{code:completionCode,message:payload.national_id},{status:completion?200:400});
      throw new Error('unexpected fetch');
    }});
  return {handler,calls,providerCalls};
}

test('KPS production is closed even with credentials/mock flags; checksum is not identity proof',async()=>{
  assert.equal(validNationalId(payload.national_id),true);assert.equal(validNationalId('10000000147'),false);
  assert.equal(toTurkishUpper(' ilker  ışık '),'İLKER IŞIK');
  assert.equal(resolveKpsProvider({...env,KPS_ENDPOINT:'https://kps.example',KPS_CREDENTIALS:'test',IDENTITY_PROVIDER:'mock'}).available,false);
  const f=fixture({kind:'mock'});const res=await f.handler({request:request(),env});
  assert.equal(res.status,503);assert.equal(f.calls.length,1);assert.equal(f.providerCalls.length,0);
  const defaultHandler=createVerifyTcknHandler({cryptoImpl:webcrypto,fetchImpl:async()=>Response.json({id:uid})});
  assert.equal((await defaultHandler({request:request(),env})).status,503);
  assert.equal((await (await defaultHandler({request:request(null,'GET'),env})).json()).available,false);
});
test('auth rejection, missing configuration and GET status never contact provider or completion',async()=>{
  for(const f of [fixture({auth:false}),fixture({available:false})]){
    const res=await f.handler({request:request(),env});assert.ok([401,503].includes(res.status));
    assert.equal(f.providerCalls.length,0);assert.equal(f.calls.length,1);
  }
  const f=fixture();assert.equal((await f.handler({request:request(),env:{...env,SUPABASE_SERVICE_ROLE_KEY:''}})).status,503);
  const r=await f.handler({request:request(null,'GET'),env});assert.deepEqual(await r.json(),{available:true});
  assert.equal(f.providerCalls.length,0);assert.equal(f.calls.filter(c=>c.path.includes('/rpc/')).length,0);
  assert.equal((await f.handler({request:request(payload,'POST',{Authorization:''}),env})).status,401);
});
test('invalid checksum, year, XML-like names and oversized/malformed JSON cannot consume attempt or call KPS',async()=>{
  for(const p of [{...payload,national_id:'10000000147'},{...payload,birth_year:3000},{...payload,first_name:'<Ad>&evil'},
    '{invalid', 'x'.repeat(5000),{...payload,birth_year:null},{...payload,national_id:10000000146}]){
    const f=fixture();const res=await f.handler({request:request(p),env});
    assert.equal(res.status,400);assert.equal(f.calls.length,1);assert.equal(f.providerCalls.length,0);
    assert.equal(res.headers.get('Cache-Control'),'no-store');
  }
});
test('trusted positive result uses authenticated target, Turkish casing, HMAC keys and service-only completion',async()=>{
  const f=fixture();const res=await f.handler({request:request({...payload,profile_id:'attacker-target',success:true}),env});
  assert.equal(res.status,200);assert.deepEqual(await res.json(),{success:true});
  assert.equal(f.providerCalls[0].firstName,'İLKER IŞIK');assert.equal(f.providerCalls[0].lastName,'ÇELİK');
  const rate=JSON.parse(f.calls[1].init.body);
  assert.match(rate.p_user_key,/^u:[a-f0-9]{64}$/);assert.match(rate.p_ip_key,/^i:[a-f0-9]{64}$/);
  assert.doesNotMatch(f.calls[1].init.body,/192\.0\.2\.1|10000000146/);
  assert.deepEqual(JSON.parse(f.calls[2].init.body),{p_profile_id:uid,p_national_id:payload.national_id,p_birth_year:1995});
  assert.equal(f.calls[0].init.headers.Authorization,'Bearer user-test');
  assert.equal(f.calls[2].init.headers.Authorization,'Bearer '+env.SUPABASE_SERVICE_ROLE_KEY);
});
test('rate denial, mismatch, malformed provider and outages fail closed with no identity completion',async()=>{
  for(const [options,status]of [[{rate:false},429],[{verified:false},422],[{verified:'true'},503],
    [{providerThrow:true},503],[{fetchThrow:true},503]]){
    const f=fixture(options);const res=await f.handler({request:request(),env});assert.equal(res.status,status);
    assert.equal(f.calls.filter(c=>c.path.endsWith('complete_identity_verification')).length,0);
    assert.doesNotMatch(await res.text(),/PRIVATE_|10000000146|backend-test-only/);
  }
});
test('database conflict/upstream failure never leaks TCKN or reports success',async()=>{
  for(const [code,status]of [['23505',409],['42501',503]]){
    const f=fixture({completion:false,completionCode:code});const res=await f.handler({request:request(),env});
    assert.equal(res.status,status);const body=await res.text();assert.doesNotMatch(body,/10000000146/);
    assert.equal(JSON.parse(body).success,false);
  }
});
test('custom-domain preflight is explicit and foreign origins never call auth/backend',async()=>{
  const f=fixture();const handler=withIdentityCors(f.handler);
  const ok=await handler({request:request(null,'OPTIONS',{Origin:'https://swansport.com.tr'}),env});
  assert.equal(ok.status,204);assert.equal(ok.headers.get('Access-Control-Allow-Origin'),'https://swansport.com.tr');
  assert.equal(f.calls.length,0);
  const no=await handler({request:request(payload,'POST',{Origin:'https://attacker.example'}),env});
  assert.equal(no.status,403);assert.equal(no.headers.has('Access-Control-Allow-Origin'),false);assert.equal(f.calls.length,0);
});
