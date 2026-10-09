// Server-side maintenance only. Keys come from job secrets, never from Flutter.
// Removes physical bytes through Storage API before deleting the reference.
export async function purgeDiagnosticAttachments({url,key,fetchImpl=fetch}) {
  if(!url||!key)throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required');
  const base=new URL(url);
  if(base.protocol!=='https:')throw new Error('HTTPS required');
  const headers={apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'};
  async function request(path,body,method='POST'){
    const response=await fetchImpl(new URL(path,base),{method,headers,body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
    if(!response.ok)throw new Error(`Maintenance request failed: HTTP ${response.status}`);
    const text=await response.text();return text?JSON.parse(text):null;
  }
  let removed=0;
  for(let page=0;page<20;page++){
    const rows=await request('/rest/v1/rpc/pending_diagnostic_attachments',{});
    if(!Array.isArray(rows))throw new Error('Invalid cleanup result');
    if(rows.length===0)break;
    for(const {path} of rows){
      if(typeof path!=='string'||!/^[-a-f0-9]{36}\/[-a-f0-9]{36}\/[-a-f0-9]{36}\.png$/.test(path))throw new Error('Unexpected attachment path');
      await request('/storage/v1/object/diagnostic-attachments',{prefixes:[path]},'DELETE');
      await request('/rest/v1/rpc/ack_diagnostic_attachment_cleanup',{p_path:path});
      removed++;
    }
  }
  return removed;
}
if(process.argv[1]?.endsWith('purge_diagnostic_attachments.mjs')){
  try {const removed=await purgeDiagnosticAttachments({url:process.env.SUPABASE_URL,key:process.env.SUPABASE_SERVICE_ROLE_KEY});
    console.log(`Diagnostic attachments removed: ${removed}`);
  } catch(error){console.error(error.message);process.exitCode=1;}
}
