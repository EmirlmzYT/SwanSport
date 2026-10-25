import {test} from 'node:test';
import assert from 'node:assert/strict';
import * as launcher from './start_local_test_center.mjs';
test('headless acceptance is explicit and cannot introduce a remote backend flag',()=>{
 assert.equal(launcher.backendOnly([]),false);
 assert.equal(launcher.backendOnly(['--backend-only']),true);
 for(const args of [['--url','https://example.test'],['--backend-only','extra'],['--production']])
  assert.throws(()=>launcher.backendOnly(args));
});
