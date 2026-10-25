// No remote database flags/URLs accepted. Secrets never printed or passed to Flutter.
import {spawnSync, spawn} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {readdirSync} from 'node:fs';

export const project = 'swansport-test-center';
export const backend = 'http://127.0.0.1:55421';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const workdir=resolve(root,'tools/local-test-center');
const container='supabase_db_'+project;
const cli=process.platform==='win32'?'npx.cmd':'npx';
const flutter=process.platform==='win32'?'flutter.bat':'flutter';

export function migrationNames(entries) {
 return entries.filter(name=>/^(?:\d{4}|\d{14})_[a-z0-9_]+\.sql$/.test(name)).sort();
}
export function backendOnly(args) {
 if(args.length===0)return false;
 if(args.length===1&&args[0]==='--backend-only')return true;
 throw Error('Yalnız --backend-only kabul edilir; uzak hedef/parametre yoktur.');
}

export function assertLocalDocker(endpoint) {
 if(!/^(?:npipe:\/{4}\.\/pipe\/[A-Za-z0-9_.-]+|unix:\/\/\/[^\s]+)$/.test(endpoint)) {
  throw Error('Yalnız yerel Docker socket/context kullanılabilir.');
 }
}
export function localSeed(source) {
 if(!source.includes("v_confirmation text := 'CHANGE_ME'")) throw Error('Seed sözleşmesi değişti.');
 return source.replace("v_confirmation text := 'CHANGE_ME'","v_confirmation text := 'CANLI_TEST_HESAPLARINI_ONAYLIYORUM'")
  .replace('update _swan_role_accounts set',`delete from _swan_role_accounts where slug not in
   ('taraftar','kulup-yoneticisi','antrenor-3','lisansli-sporcu','muhasebeci');
   update _swan_role_accounts set`)
  .replaceAll('45 test hesabı','5 yerel test hesabı');
}
function run(command,args,options={}) {
 const spec=commandSpec(command,args);
 const result=spawnSync(spec.command,spec.args,{cwd:root,encoding:'utf8',maxBuffer:32*1024*1024,
  windowsVerbatimArguments:spec.verbatim,...options});
 if(result.error||result.status!==0) {
  const detail=command==='docker'&&args.includes('psql') ? result.stderr?.split('\n').slice(0,3).join(' ') : '';
  throw Error(`${command} başarısız. Gerekli araçları/yerel servisleri kontrol edin. ${detail}`);
 }
 return result.stdout.trim();
}
export function windowsBatchLine(command,args) {
 const tokens=[command,...args];
 if(tokens.some(value=>/["&|<>^%!\r\n]/.test(value))) throw Error('Güvensiz Windows komut argümanı reddedildi.');
 return '"'+tokens.map(value=>'"'+value+'"').join(' ')+'"';
}
function commandSpec(command,args) {
 if(process.platform==='win32'&&/\.(cmd|bat)$/.test(command)) {
  return {command:'cmd.exe',args:['/d','/s','/c',windowsBatchLine(command,args)],verbatim:true};
 }
 return {command,args,verbatim:false};
}
function sql(input) {
 return run('docker',['exec','-i',container,'psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-At'],{input});
}
export function statusKey(status) {
 if(status.API_URL!==backend) throw Error('Yerel backend adresi uyuşmuyor; işlem durdu.');
 const key=status.ANON_KEY ?? status.PUBLISHABLE_KEY;
 if(typeof key!=='string'||!/^(eyJ[A-Za-z0-9._-]+|sb_publishable_[A-Za-z0-9_-]+)$/.test(key)) {
  throw Error('Yerel public Auth anahtarı bulunamadı.');
 }
 return key;
}
async function main() {
 const headless=backendOnly(process.argv.slice(2));
 if(Number(process.versions.node.split('.')[0])<20) throw Error('Node.js 20 veya üstü gerekli.');
 const missing=[];
 for(const [command,label] of [...(headless?[]:[[flutter,'Flutter SDK']]),['docker','Docker Desktop']]) {
  try {run(command,['--version']);} catch {missing.push(label);}
 }
 if(missing.length) throw Error('Önce kurulması gerekenler: '+missing.join(', ')+'. docs/local-test-center.md rehberine bakın.');
 if(process.env.DOCKER_HOST) assertLocalDocker(process.env.DOCKER_HOST);
 assertLocalDocker(JSON.parse(run('docker',['context','inspect','--format','{{json .Endpoints.docker.Host}}'])));
 run('docker',['info','--format','{{.ServerVersion}}']);
 console.log('Yerel Supabase başlatılıyor. İlk indirme birkaç dakika sürebilir.');
 run(cli,['--yes','supabase@2.121.0','start','--workdir',workdir]);
 // Inspect exact container ownership before executing any SQL.
 const inspect=JSON.parse(run('docker',['inspect',container]))[0];
 if(inspect.Config?.Labels?.['com.supabase.cli.project']!==project) {
  throw Error('Docker proje etiketi uyuşmuyor; SQL çalıştırılmadı.');
 }
 const status=JSON.parse(run(cli,['--yes','supabase@2.121.0','status','--workdir',workdir,'--output','json']));
 const anon=statusKey(status); // Do not print status: it contains backend-only credentials.
 sql(`create table if not exists public._local_test_center_install(project text primary key);
  alter table public._local_test_center_install enable row level security;
  revoke all on public._local_test_center_install from public,anon,authenticated;
  insert into public._local_test_center_install values('${project}') on conflict do nothing;
  create table if not exists public._local_test_center_migrations(name text primary key,sha text not null);
  alter table public._local_test_center_migrations enable row level security;
  revoke all on public._local_test_center_migrations from public,anon,authenticated;`);
 for(const name of migrationNames(readdirSync(resolve(root,'supabase/migrations')))) {
  const source=readFileSync(resolve(root,'supabase/migrations',name),'utf8');
  const hash=createHash('sha256').update(source).digest('hex');
  const previous=sql(`select sha from public._local_test_center_migrations where name='${name}'`);
  if(previous && previous!==hash) throw Error(`Uygulanmış yerel migration değişti: ${name}. Otomatik silme yapılmadı.`);
  if(!previous) {
   console.log('Yerel migration: '+name);
   sql(`begin;set local lock_timeout='15s';\n${source}\n
    insert into public._local_test_center_migrations values('${name}','${hash}');commit;`);
  }
  // Local reminders must not run while fixtures are being assembled.
  sql(`do $$begin if to_regclass('cron.job') is not null then
    perform cron.unschedule(jobname) from cron.job where jobname like 'swansport_%';end if;end$$;`);
 }
 sql(localSeed(readFileSync(resolve(root,'supabase/seed/full_roles_test_seed.sql'),'utf8')));
 sql(readFileSync(resolve(workdir,'fixture.sql'),'utf8'));
 // Verify real Auth for all five personas before launching. Never log tokens/passwords.
 for(const slug of ['taraftar','kulup-yoneticisi','antrenor-3','lisansli-sporcu','muhasebeci']) {
  const response=await fetch(backend+'/auth/v1/token?grant_type=password',{
   method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},
   body:JSON.stringify({email:slug+'@test.swansport.invalid',password:'test1234'}),
   signal:AbortSignal.timeout(15000),
  });
  if(!response.ok) throw Error('Yerel hesap giriş kontrolü başarısız: '+slug);
 }
 if(headless){console.log('Yerel backend ve beş gerçek Auth girişi hazır.');return;}
 run(flutter,['pub','get'],{cwd:resolve(root,'apps/swansport_app')});
 console.log('Test Merkezi açılıyor: http://127.0.0.1:55430 · kapatmak için Ctrl+C');
 const spec=commandSpec(flutter,['run','-d','chrome','--web-hostname','127.0.0.1','--web-port','55430',
  '-t','lib/main_test_center.dart','--dart-define=LOCAL_TEST_ANON_KEY='+anon]);
 const child=spawn(spec.command,spec.args,{
  cwd:resolve(root,'apps/swansport_app'),stdio:'inherit',windowsVerbatimArguments:spec.verbatim,
 });
 child.on('error',()=>{console.error('Flutter başlatılamadı.');process.exitCode=1;});
 child.on('exit',code=>{process.exitCode=code??1;});
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
 main().catch(error=>{console.error(error.message);process.exitCode=1;});
}
