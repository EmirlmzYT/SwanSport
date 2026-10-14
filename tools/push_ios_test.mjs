import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const source=await readFile(new URL('../apps/swansport_app/functions/api/push.js',import.meta.url),'utf8');
const {fcmMessage,onRequestPost}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
test('iOS APNs alert/sound/badge and Android/data route are consistent; live TTL bounded',()=>{
 const url='/canli-mac/10000000-0000-0000-0000-000000000001';
 const message=fcmMessage({endpoint:'synthetic-device'},{title:'Skor',body:'Kulüp 1 : 0',url});
 assert.deepEqual(message.apns.payload.aps,{alert:{title:'Skor',body:'Kulüp 1 : 0'},sound:'default',badge:1});
 assert.equal(message.apns.headers['apns-push-type'],'alert');assert.equal(message.apns.headers['apns-priority'],'10');
 const expires=Number(message.apns.headers['apns-expiration']);assert.ok(expires-Math.floor(Date.now()/1000)<=60);
 assert.equal(message.android.ttl,'60s');assert.equal(message.android.notification.channel_id,'swansport_default');
 assert.equal(message.data.url,url);assert.equal(message.token,'synthetic-device');
});
test('non-live messages preserve previous defaults without arbitrary TTL or empty alert',()=>{
 const message=fcmMessage({endpoint:'synthetic-device'},{});
 assert.equal(message.data.url,'/bildirimler');assert.equal(message.notification.title,'SwanSport');
 assert.equal(message.apns.payload.aps.alert.title,'SwanSport');assert.equal(message.android.ttl,undefined);
 assert.equal(message.apns.headers['apns-expiration'],undefined);
});
test('sender still requires configuration and authenticated push secret before network',async()=>{
 const previous=globalThis.fetch;globalThis.fetch=()=>{throw new Error('unexpected network');};try{
  const request=new Request('https://example.test/api/push',{method:'POST',body:'{}'});
  assert.equal((await onRequestPost({request,env:{}})).status,500);
  assert.equal((await onRequestPost({request,env:{PUSH_SECRET:'fixture',VAPID_PRIVATE:'fixture'}})).status,401);
 }finally{globalThis.fetch=previous;}
});
test('real handler serializes APNs through FCM v1, OAuth once and missing FCM stays explicit',async()=>{
 const key=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
 const privateKey=Buffer.from(await crypto.subtle.exportKey('pkcs8',key.privateKey)).toString('base64');
 const sa={private_key:`-----BEGIN PRIVATE KEY-----\n${privateKey}\n-----END PRIVATE KEY-----`,client_email:'fixture@example.test',token_uri:'https://example.test/token',project_id:'swanspor'};
 const previous=globalThis.fetch;const requests=[];globalThis.fetch=async(url,options)=>{
  requests.push({url,options});return Response.json(url===sa.token_uri?{access_token:'fixture-token'}:{name:'fixture-message'});
 };
 try{
  const body={title:'Maç',body:'Legal Club 1 : 0',url:'/canli-mac/10000000-0000-0000-0000-000000000001',subs:[{kind:'fcm',endpoint:'fixture-ios'},{kind:'fcm',endpoint:'fixture-android'}]};
  const request=()=>new Request('https://example.test/api/push',{method:'POST',headers:{'x-push-secret':'fixture'},body:JSON.stringify(body)});
  // Native delivery does not require unrelated web VAPID credentials.
  const env={PUSH_SECRET:'fixture',FCM_SERVICE_ACCOUNT:JSON.stringify(sa)};
  const response=await onRequestPost({request:request(),env});assert.equal((await response.json()).sent,2);
  assert.equal(requests.filter(r=>r.url===sa.token_uri).length,1);
  for(const r of requests.filter(r=>r.url.includes('messages:send'))){const message=JSON.parse(r.options.body).message;
    assert.equal(message.apns.payload.aps.sound,'default');assert.equal(message.data.url,body.url);
    assert.equal(message.android.notification.channel_id,'swansport_default');}
  const missing=await onRequestPost({request:request(),env:{PUSH_SECRET:'fixture',VAPID_PRIVATE:'fixture'}});
  const result=await missing.json();assert.equal(result.sent,0);assert.ok(result.results.every(r=>r.error==='FCM yapılandırılmamış'));
 }finally{globalThis.fetch=previous;}
});
test('bad JSON shape and missing web configuration fail explicitly without network',async()=>{
 const previous=globalThis.fetch;globalThis.fetch=()=>{throw new Error('unexpected network');};try{
  const request=(body)=>new Request('https://example.test/api/push',{method:'POST',headers:{'x-push-secret':'fixture'},body:JSON.stringify(body)});
  for(const body of [null,[],false])assert.equal((await onRequestPost({request:request(body),env:{PUSH_SECRET:'fixture'}})).status,400);
  const result=await (await onRequestPost({request:request({subs:[{kind:'web',endpoint:'fixture-web'}]}),env:{PUSH_SECRET:'fixture'}})).json();
  assert.equal(result.sent,0);assert.equal(result.results[0].error,'Web push yapılandırılmamış');
 }finally{globalThis.fetch=previous;}
});
