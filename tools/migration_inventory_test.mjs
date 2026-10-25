import {test} from 'node:test';
import assert from 'node:assert/strict';
import * as center from './start_local_test_center.mjs';

test('local acceptance installs legacy and CLI timestamp migrations in order, ignoring unsafe names',()=>{
  const names=['README.md','20261025042446_push_delivery_tracking.sql','0134_fix_swan_id_pgcrypto_resolution.sql',
    '20261025042357_account_deletion_lifecycle.sql','0001_foundation.sql','0001_bad\nname.sql','0001_bad\x27name.sql'];
  assert.deepEqual(center.migrationNames(names),[
    '0001_foundation.sql','0134_fix_swan_id_pgcrypto_resolution.sql',
    '20261025042357_account_deletion_lifecycle.sql','20261025042446_push_delivery_tracking.sql']);
});
