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
