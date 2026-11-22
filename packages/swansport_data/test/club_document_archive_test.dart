import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  final repo = Directory.current.path.replaceAll('\\', '/');
  final root = repo.endsWith('/packages/swansport_data')
      ? repo.substring(0, repo.length - '/packages/swansport_data'.length)
      : repo;

  test('legacy metadata and new archive fields remain compatible', () {
    final legacy = DocumentRow.fromMap({
      'id': 'legacy',
      'name': 'Eski karar defteri',
      'kind': 'file',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(legacy.hasFile, isFalse);
    expect(legacy.version, 1);

    final stored = DocumentRow.fromMap({
      'id': 'stored',
      'name': 'Tescil belgesi',
      'kind': 'pdf',
      'storage_path': 'club/file.pdf',
      'version': 3,
      'valid_until': '2027-12-31',
      'created_at': '2026-11-19T00:00:00Z',
    });
    expect(stored.hasFile, isTrue);
    expect(stored.version, 3);
    expect(stored.validUntil, DateTime(2027, 12, 31));
  });

  test('archive migration keeps storage private and row-authorized', () {
    final sql = File(
      '$root/supabase/migrations/20261119120000_club_document_archive.sql',
    ).readAsStringSync();
    expect(sql, contains("'club-documents','club-documents',false"));
    expect(sql, contains('public.is_club_staff(d.club_id)'));
    expect(sql, isNot(contains('public.is_club_member(d.club_id)')));
    expect(sql, contains('d.archived_at is null'));
    expect(sql, contains("storage_path like club_id::text || '/%'"));
  });
}
