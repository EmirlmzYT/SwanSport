import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';

const sql = await readFile(
  new URL('../supabase/migrations/0136_pro_performance_analytics.sql', import.meta.url),
  'utf8',
);

test('performance analytics keeps the established fail-closed boundary', () => {
  assert.match(sql, /can_view_athlete_performance\(a\.id\)/);
  assert.match(sql, /can_view_athlete_performance\(p_athlete\)/);
  assert.match(sql, /auth\.uid\(\) is null/);
  assert.match(sql, /my_feature_flags\(\)/);
  assert.doesNotMatch(sql, /service_role|user_metadata|raw_user_meta_data/i);
});

test('training projection uses only completed club sessions and real scores', () => {
  assert.match(sql, /s\.kind='club' and s\.status='completed'/);
  assert.match(sql, /ts\.total_score is not null/);
  assert.match(sql, /left join public\.training_sets/);
  assert.doesNotMatch(sql, /coalesce\s*\(\s*ts\.total_score\s*,\s*0/i);
});

test('team and sport filters derive from existing memberships', () => {
  assert.match(sql, /public\.team_memberships/);
  assert.match(sql, /coalesce\(s\.is_active,false\) desc/);
  assert.match(sql, /coalesce\(squad\.sport_code,c\.sport_code\)/);
});
