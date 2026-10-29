import {test} from 'node:test';
import assert from 'node:assert/strict';
import * as sender from '../apps/swansport_app/functions/api/push.js';

test('only FCM UNREGISTERED is a permanently dead token; project/configuration 404 is retained',()=>{
  assert.deepEqual(sender.classifyFcmResult(404,{error:{status:'NOT_FOUND'}}),{gone:false,retryable:false});
  assert.deepEqual(sender.classifyFcmResult(404,{error:{details:[{errorCode:'UNREGISTERED'}]}}),{gone:true,retryable:false});
  assert.deepEqual(sender.classifyFcmResult(400,{error:{details:[{errorCode:'INVALID_ARGUMENT'}]}}),{gone:false,retryable:false});
});
test('FCM known temporary rejection can retry; accepted and other permanent errors cannot',()=>{
  for(const status of [429,500,503])assert.deepEqual(sender.classifyFcmResult(status,{}),{gone:false,retryable:true});
  for(const status of [200,401,403])assert.deepEqual(sender.classifyFcmResult(status,{}),{gone:false,retryable:false});
});

test('fcmMessage configures swansport_pro_default channel for pro and swansport_default for social', () => {
  const sub = { endpoint: 'fake-token' };
  const proJob = { title: 'Görev', body: 'Hakem görevi', appTarget: 'pro' };
  const proMsg = sender.fcmMessage(sub, proJob);
  assert.equal(proMsg.android?.notification?.channel_id, 'swansport_pro_default');

  const socialJob = { title: 'Mesaj', body: 'Selam', appTarget: 'social' };
  const socialMsg = sender.fcmMessage(sub, socialJob);
  assert.equal(socialMsg.android?.notification?.channel_id, 'swansport_default');
});

test('onRequestPost rejects unknown appTarget with 400', async () => {
  const req = new Request('https://swansport.pages.dev/api/push', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-push-secret': 'sec123' },
    body: JSON.stringify({ appTarget: 'evil_target', subs: [] }),
  });
  const res = await sender.onRequestPost({ request: req, env: { PUSH_SECRET: 'sec123' } });
  assert.equal(res.status, 400);
});

test('onRequestPost isolates PRO_FCM_SERVICE_ACCOUNT from social FCM_SERVICE_ACCOUNT', async () => {
  const reqPro = new Request('https://swansport.pages.dev/api/push', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-push-secret': 'sec123' },
    body: JSON.stringify({ appTarget: 'pro', subs: [{ kind: 'fcm', endpoint: 'pro-ep' }] }),
  });
  const resPro = await sender.onRequestPost({
    request: reqPro,
    env: { PUSH_SECRET: 'sec123', FCM_SERVICE_ACCOUNT: '{"project_id":"social-proj"}' },
  });
  assert.equal(resPro.status, 200);
  const dataPro = await resPro.json();
  assert.equal(dataPro.results[0].error, 'FCM yapılandırılmamış');

  const reqSocial = new Request('https://swansport.pages.dev/api/push', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-push-secret': 'sec123' },
    body: JSON.stringify({ appTarget: 'social', subs: [{ kind: 'fcm', endpoint: 'social-ep' }] }),
  });
  const resSocial = await sender.onRequestPost({
    request: reqSocial,
    env: { PUSH_SECRET: 'sec123', PRO_FCM_SERVICE_ACCOUNT: '{"project_id":"pro-proj"}' },
  });
  assert.equal(resSocial.status, 200);
  const dataSocial = await resSocial.json();
  assert.equal(dataSocial.results[0].error, 'FCM yapılandırılmamış');
});
