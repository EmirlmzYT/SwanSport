@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test(
      'IndexedDB transaction survives close/reopen and retains actor isolation',
      () async {
    final name = 'swan-offline-test-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc();
    final store = OfflineAttendanceStore(
        await databaseFactoryWeb.openDatabase(name, version: 1),
        barrier: (_) async {},);
    await store.prepare('actor', {
      'actor_id': 'actor',
      'event_id': 'event',
      'club_id': 'club',
      'title': 'Program',
      'starts_at': now.toIso8601String(),
      'prepared_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
      'rows': [
        {
          'athlete_id': 'a',
          'full_name': 'Ada',
          'version': 0,
          'status': null,
          'rsvp_status': 'attending',
          'eligibility': 'eligible',
        }
      ],
    });
    await store.mark('actor', 'event', 'a', 'present');
    final id = await store.enqueue('actor', 'event');
    await store.close();
    final reopened = OfflineAttendanceStore(
        await databaseFactoryWeb.openDatabase(name, version: 1),
        barrier: (_) async {},);
    expect((await reopened.list(reopened.ops, 'actor')).single['op_id'], id);
    expect(await reopened.list(reopened.ops, 'other'), isEmpty);
    await reopened.close();
    await databaseFactoryWeb.deleteDatabase(name);
  });
}
