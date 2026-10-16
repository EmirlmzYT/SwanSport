import {readFile,readdir} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const read=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
const root='apps/swansport_app/lib/features/';
const targets=[
 'attendance/presentation/screens/attendance_workspace.dart',
 'training/presentation/workout_builder_screen.dart',
 'configuration/presentation/season_setup_screen.dart',
 'calendar/presentation/screens/guardian_official_result_screen.dart',
 'documents/presentation/screens/document_detail_screen.dart',
 'network/presentation/guest_explore_screen.dart',
 'performance_analytics/presentation/performance_workflow_editors.dart',
 'courts/presentation/find_partner_screen.dart',
 'courts/presentation/court_detail_screen.dart',
 'turf/presentation/turf_field_detail_screen.dart',
 'settings/presentation/screens/club_settings_screen.dart',
];
test('all eleven scoped modules use standard headers and no raw ListTile, font or secondary-color calls',async()=>{
 for(const path of targets){const source=await read(root+path);
  assert.match(source,/swanModuleAppBar\(context/,path);
  assert.doesNotMatch(source,/\bAppBar\(|\bListTile\(|SwanColors\.textSecondary|\b(?:jakarta|sora)\(/,path);
  assert.doesNotMatch(source,/Supabase\.instance|\.from\('/,path);
 }
});
test('document/workflow automation keys remain reachable and unchanged',async()=>{
 const doc=await read(root+'documents/presentation/screens/document_detail_screen.dart');
 for(const key of ['document-detail-title','document-invalid-route','document-not-found'])assert.ok(doc.includes(key));
 const workflow=await read(root+'performance_analytics/presentation/performance_workflow_editors.dart');
 for(const key of ['workflow-permission-denied','workflow-editor-${widget.kind.name}','workflow-cancel','workflow-save'])assert.ok(workflow.includes(key));
});
test('common header preserves conditional back and subtitles; actions retain discovery labels',async()=>{
 const header=await read('apps/swansport_app/lib/app/widgets/swan_module_app_bar.dart');
 assert.match(header,/Navigator\.canPop\(context\)/);assert.match(header,/Navigator\.maybePop\(context\)/);
 assert.match(header,/SwanType\.caption\(c\.inkMuted\)/);
 assert.ok((await read(root+'courts/presentation/court_detail_screen.dart')).includes("title: 'Bekleme listem'"));
 const turf=await read(root+'turf/presentation/turf_field_detail_screen.dart');
 for(const label of ['Saha görevlerim','Görev devret'])assert.ok(turf.includes(label));
});
test('settings route entry, pure service mutation and context invalidation are connected',async()=>{
 const settings=await read(root+'settings/presentation/screens/club_settings_screen.dart');
 assert.match(settings,/club != null && access\.isClubStaff/);
 assert.match(settings,/ClubTrainingSportsSheet\(clubId: club\.id\)/);
 const data=await read('packages/swansport_data/lib/src/sport_context_service.dart');
 assert.match(data,/rpc<int>\('set_club_training_sports'/);
 assert.match(data,/ref\.invalidate\(activeClubSportsProvider\)/);
 assert.match(data,/ref\.invalidate\(sportContextOptionsProvider\)/);
 assert.doesNotMatch(data,/WidgetRef|IconData|\bColor\(|\bWidget\b/);
});
test('all SQL feature keys match Dart constants and release keys already exist',async()=>{
 const sqlKeys=new Set();
 for(const name of await readdir(new URL('../supabase/migrations/',import.meta.url))){
  if(!name.endsWith('.sql'))continue;
  const source=await read('supabase/migrations/'+name);
  for(const block of source.matchAll(/insert\s+into\s+public\.feature_flags[\s\S]*?on conflict[^;]*;/gi))
    for(const match of block[0].matchAll(/\(\s*'([a-z0-9_]+)'\s*,\s*'(?:off|admins|testers|everyone)'/g))sqlKeys.add(match[1]);
 }
 const dart=await read('packages/swansport_data/lib/src/feature_flags.dart');
 const dartKeys=new Set([...dart.matchAll(/static const \w+ = '([a-z0-9_]+)';/g)].map(m=>m[1]));
 assert.ok(dartKeys.size>=20);assert.deepEqual([...sqlKeys].sort(),[...dartKeys].sort());
 const release=await read('supabase/migrations/0121_general_availability_and_club_training_sports.sql');
 assert.ok(release.includes("'/settings'"));
 assert.ok((await read('apps/swansport_app/lib/app/swansport_app.dart')).includes("'/settings':"));
 const update=release.slice(release.indexOf('update public.feature_flags'));
 const keys=[...update.matchAll(/'([a-z0-9_]+)'/g)].map(m=>m[1]).filter(k=>!['admins','everyone'].includes(k));
 assert.equal(new Set(keys).size,11);
 for(const key of keys)assert.ok(dartKeys.has(key),key);
});
