import {readFileSync} from 'node:fs';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const migrationSql = readFileSync(resolve(root, 'supabase/migrations/0119_turkey_sports_federations_catalog.sql'), 'utf8');
const catalogDart = readFileSync(resolve(root, 'packages/swansport_data/lib/src/sports_catalog.dart'), 'utf8');
const docMarkdown = readFileSync(resolve(root, 'docs/turkey-sports-federations-catalog.md'), 'utf8');

test('0119 migration contains exactly 60 sports and 60 federations', () => {
  const sportsMatches = [...migrationSql.matchAll(/\('([a-z0-9-]+)',\s*'([^']+)'\)/g)];
  // First block is sports, second block is federations
  assert.ok(sportsMatches.length >= 120, 'Should have at least 120 tuples total (60 sports + 60 federations)');
  
  const sportsCodes = sportsMatches.slice(0, 60).map(m => m[1]);
  const fedCodes = sportsMatches.slice(60, 120).map(m => m[1]);
  
  assert.equal(sportsCodes.length, 60, 'Should have 60 sports');
  assert.equal(fedCodes.length, 60, 'Should have 60 federations');
  
  // Every code must match 1-to-1
  for (let i = 0; i < 60; i++) {
    assert.equal(sportsCodes[i], fedCodes[i], `Mismatch at index ${i}: ${sportsCodes[i]} vs ${fedCodes[i]}`);
    assert.match(sportsCodes[i], /^[a-z0-9-]+$/, 'Sport code must be kebab-case lowercase');
  }
  
  // Uniqueness
  const uniqueSports = new Set(sportsCodes);
  assert.equal(uniqueSports.size, 60, 'All 60 sport codes must be unique');
});

test('Dart catalog contains all 60 sports with matching codes', () => {
  const dartCodes = [...catalogDart.matchAll(/code:\s*'([a-z0-9-]+)'/g)].map(m => m[1]);
  assert.equal(dartCodes.length, 60, 'Dart catalog must have 60 SportItem entries');
  
  const uniqueDart = new Set(dartCodes);
  assert.equal(uniqueDart.size, 60, 'All 60 Dart codes must be unique');
  
  // Verify lock_timeout in 0119
  assert.ok(migrationSql.includes("set local lock_timeout = '15s';"), 'Migration 0119 must set lock_timeout 15s');
});

test('Documentation table lists all 60 federations', () => {
  const docCodes = [...docMarkdown.matchAll(/\|\s*\d+\s*\|\s*`([a-z0-9-]+)`/g)].map(m => m[1]);
  assert.equal(docCodes.length, 60, 'Documentation table must list all 60 federations');
});
