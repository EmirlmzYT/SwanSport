import assert from 'node:assert/strict';
import {test} from 'node:test';
import {purgeDiagnosticAttachments} from './purge_diagnostic_attachments.mjs';

const path = '00000000-0000-0000-0000-000000000001/00000000-0000-0000-0000-000000000002/00000000-0000-0000-0000-000000000003.png';
const options = {url:'https://backend.example',key:'TEST_SECRET'};
test('physical deletion precedes acknowledgement and an empty batch finishes', async () => {
  const calls=[]; let page=0;
  const removed=await purgeDiagnosticAttachments({...options,fetchImpl:async (url,request)=>{
    calls.push({path:url.pathname,...request});
    if(url.pathname.endsWith('pending_diagnostic_attachments'))return Response.json(page++ === 0 ? [{path}] : []);
    return Response.json([]);
  }});
  assert.equal(removed,1);
  assert.equal(calls[1].method,'DELETE');
  assert.deepEqual(JSON.parse(calls[1].body),{prefixes:[path]});
  assert.equal(calls[2].path,'/rest/v1/rpc/ack_diagnostic_attachment_cleanup');
  assert.deepEqual(JSON.parse(calls[2].body),{p_path:path});
});
test('failed physical deletion keeps the reference available for retry', async () => {
  const calls=[];
  await assert.rejects(purgeDiagnosticAttachments({...options,fetchImpl:async (url)=>{
    calls.push(url.pathname);
    return url.pathname.includes('/storage/') ? new Response('',{status:500}) : Response.json([{path}]);
  }}),/HTTP 500/);
  assert.equal(calls.length,2); assert.ok(!calls.some(p=>p.includes('ack_')));
});
test('unsafe attachment paths cannot reach Storage API', async () => {
  let calls=0;
  await assert.rejects(purgeDiagnosticAttachments({...options,fetchImpl:async ()=>{
    calls++; return Response.json([{path:'../other-bucket/private.png'}]);
  }}),/Unexpected attachment path/);
  assert.equal(calls,1);
});
test('transport failures expose status only and credentials never enter URLs', async () => {
  await assert.rejects(purgeDiagnosticAttachments({...options,fetchImpl:async (url)=>{
    assert.ok(!String(url).includes(options.key));
    return new Response('SECRET body',{status:403});
  }}),error => error.message==='Maintenance request failed: HTTP 403');
});
