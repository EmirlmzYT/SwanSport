import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:swansport_data/swansport_data.dart';

Map<String, dynamic> snapshot(
  DateTime now, {
  String actor = 'actor',
  String event = 'event',
}) =>
    {
      'actor_id': actor,
      'event_id': event,
      'club_id': 'club',
      'club_name': 'Kulüp',
      'title': 'Antrenman',
      'starts_at': now.toIso8601String(),
      'prepared_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
      'rows': [
        {
          'athlete_id': 'a',
          'full_name': 'Ada Sporcu',
          'version': 0,
          'status': null,
          'rsvp_status': 'attending',
          'eligibility': 'eligible',
        },
        {
          'athlete_id': 'b',
          'full_name': 'Bora Sporcu',
          'version': 2,
          'status': 'absent',
          'rsvp_status': null,
          'eligibility': 'restricted',
        }
      ],
    };

class Remote implements AttendanceQueueRemote {
  @override
  String? actorId = 'actor';
  int calls = 0;
  final ids = <String>[];
  int freshVersion = 0;
  List<Map<String, dynamic>> lastMarks = [];
  Object? error;
  Completer<AttendanceOpResult>? held;
  AttendanceOpResult result =
      const AttendanceOpResult(applied: 1, conflicts: [], replayed: false);
  DateTime now = DateTime.utc(2026, 10, 7);
  @override
  Future<Map<String, dynamic>> prepare(String event) async {
    final fresh = snapshot(now, event: event);
    (fresh['rows'] as List).cast<Map<String, dynamic>>().first['version'] =
        freshVersion;
    return fresh;
  }

  @override
  Future<AttendanceOpResult> send(
    String actor,
    String event,
    String op,
    List<Map<String, dynamic>> marks,
  ) async {
    expect(actor, actorId);
    calls++;
    ids.add(op);
    lastMarks = marks;
    if (error != null) throw error!;
    return held?.future ?? result;
  }
}

void main() {
  late OfflineAttendanceStore store;
  late Remote remote;
  late AttendanceQueue queue;
  late DateTime now;
  setUp(() async {
    now = DateTime.utc(2026, 10, 7);
    remote = Remote();
    store = OfflineAttendanceStore(
      await databaseFactoryMemory
          .openDatabase('test-${DateTime.now().microsecondsSinceEpoch}'),
      barrier: (_) async {},
    );
    queue = AttendanceQueue(store, remote, 'actor', clock: () => now);
    await store.prepare('actor', snapshot(now));
  });
  tearDown(() async {
    queue.dispose();
    await store.close();
  });
  Future<String> enqueue() async {
    await store.mark('actor', 'event', 'a', 'present', now: now);
    return store.enqueue('actor', 'event', now: now);
  }

  Future<Map<String, dynamic>> operation() async =>
      (await store.list(store.ops, 'actor')).single;
  test(
      'RSVP does not become a mark; explicit touch keeps original version across refresh',
      () async {
    expect(await store.list(store.drafts, 'actor'), isEmpty);
    await store.mark('actor', 'event', 'a', 'present', now: now);
    final fresh = snapshot(now);
    (fresh['rows'] as List).cast<Map<String, dynamic>>().first['version'] = 7;
    await store.prepare('actor', fresh);
    await store.mark('actor', 'event', 'a', 'absent', now: now);
    final mark = (await store.list(store.drafts, 'actor')).single;
    expect(mark['version'], 0);
    expect(mark['status'], 'absent');
    await expectLater(
      store.mark('actor', 'event', 'b', 'present', now: now),
      throwsStateError,
    );
  });
  test(
      'account isolation, cache expiration and unsent records prevent forgetting',
      () async {
    expect(await store.list(store.cache, 'other'), isEmpty);
    await expectLater(store.prepare('other', snapshot(now)), throwsStateError);
    await expectLater(
      store.mark(
        'actor',
        'event',
        'a',
        'present',
        now: now.add(const Duration(days: 8)),
      ),
      throwsStateError,
    );
    await enqueue();
    await expectLater(store.forget('actor', 'event'), throwsStateError);
    remote.actorId = 'other';
    await queue.sync();
    expect(remote.calls, 0);
  });
  test(
      'uncertain send retries same operation; only confirmed result completes it',
      () async {
    final op = await enqueue();
    remote.error = TimeoutException('fixture');
    await queue.sync();
    expect((await operation())['state'], 'pending');
    expect((await operation())['op_id'], op);
    now = now.add(const Duration(minutes: 2));
    remote.error = null;
    await queue.sync();
    expect(remote.ids, [op, op]);
    expect((await operation())['state'], 'done');
    final cached = (await store.list(store.cache, 'actor')).single;
    expect(
      (cached['rows'] as List).cast<Map<String, dynamic>>().first['status'],
      'present',
    );
    expect(
      (cached['rows'] as List).cast<Map<String, dynamic>>().first['version'],
      1,
    );
  });
  test('definite rejection and five failures are retained for manual review',
      () async {
    await enqueue();
    remote.error = const PostgrestException(message: 'fixture', code: 'P0001');
    await queue.sync();
    expect((await operation())['state'], 'rejected');
    final id = (await operation())['op_id'] as String;
    await store.retry('actor', id, now: now);
    remote.error = TimeoutException('fixture');
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(hours: 1));
      await queue.sync();
    }
    expect((await operation())['state'], 'paused');
    expect((await operation())['attempts'], 5);
  });
  test(
      'rejection after a lost response remains uncertain and cannot be abandoned',
      () async {
    final id = await enqueue();
    remote.error = TimeoutException('lost response');
    await queue.sync();
    now = now.add(const Duration(minutes: 2));
    remote.error =
        const PostgrestException(message: 'membership revoked', code: 'P0001');
    await queue.sync();
    expect((await operation())['state'], 'paused');
    expect((await operation())['uncertain'], isTrue);
    await expectLater(store.abandonRejected('actor', id), throwsStateError);
    expect(remote.ids, [id, id]);
  });
  test('old operations pause without being discarded', () async {
    await enqueue();
    now = now.add(const Duration(days: 8));
    await queue.sync();
    expect((await operation())['state'], 'paused');
    expect(remote.calls, 0);
  });
  test(
      'two workers claim one lease and do not concurrently send the same operation',
      () async {
    await enqueue();
    remote.held = Completer<AttendanceOpResult>();
    final sending = queue.sync();
    while (remote.calls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final second = AttendanceQueue(store, remote, 'actor', clock: () => now);
    await second.sync();
    second.dispose();
    expect(remote.calls, 1);
    remote.held!.complete(remote.result);
    await sending;
    expect((await operation())['state'], 'done');
  });
  test(
      'conflict acknowledgement never writes; keep mine uses fresh version and a new operation',
      () async {
    final old = await enqueue();
    remote.result = const AttendanceOpResult(
      applied: 0,
      conflicts: [
        AttendanceConflict(
          athleteId: 'a',
          reason: 'version_mismatch',
          sentStatus: 'present',
          currentStatus: 'absent',
          sentVersion: 0,
          currentVersion: 2,
        ),
      ],
      replayed: false,
    );
    await queue.sync();
    expect((await operation())['state'], 'conflict');
    remote.result =
        const AttendanceOpResult(applied: 1, conflicts: [], replayed: false);
    remote.freshVersion = 5;
    await queue.keepMine(await operation());
    expect(remote.lastMarks.single['version'], 5);
    final ops = await store.list(store.ops, 'actor');
    expect(ops.length, 2);
    expect(remote.ids.last, isNot(old));
    expect(ops.every((r) => r['state'] == 'done'), isTrue);
  });
  test('only definitive rejection can be abandoned and original marks remain',
      () async {
    final id = await enqueue();
    await expectLater(store.abandonRejected('actor', id), throwsStateError);
    remote.error = const PostgrestException(message: 'fixture', code: 'P0001');
    await queue.sync();
    await expectLater(store.abandonRejected('other', id), throwsStateError);
    await store.abandonRejected('actor', id);
    expect((await operation())['resolution'], 'abandoned');
    expect((await operation())['marks'], isNotEmpty);
    await store.mark('actor', 'event', 'a', 'absent', now: now);
    expect(
      (await store.list(store.drafts, 'actor')).single['status'],
      'absent',
    );
  });
  test('accepting server conflict never sends another operation', () async {
    final id = await enqueue();
    remote.result = const AttendanceOpResult(
      applied: 0,
      conflicts: [
        AttendanceConflict(
          athleteId: 'a',
          reason: 'version_mismatch',
          sentStatus: 'present',
          currentStatus: 'absent',
          sentVersion: 0,
          currentVersion: 2,
        ),
      ],
      replayed: false,
    );
    await queue.sync();
    await store.resolve('actor', id);
    await queue.sync();
    expect(remote.calls, 1);
    expect((await operation())['resolution'], 'server');
  });
  test('native atomic barrier survives close/reopen with marks and queued IDs',
      () async {
    final dir = await Directory.systemTemp.createTemp('swan-attendance-');
    final path = '${dir.path}/attendance.db';
    final native = OfflineAttendanceStore(
      await databaseFactoryIo.openDatabase(path, version: 1),
    );
    await native.prepare('actor', snapshot(now));
    await native.mark('actor', 'event', 'a', 'present', now: now);
    await native.close();
    final restored = OfflineAttendanceStore(
      await databaseFactoryIo.openDatabase(path, version: 1),
    );
    expect(
      (await restored.list(restored.drafts, 'actor')).single['status'],
      'present',
    );
    final op = await restored.enqueue('actor', 'event', now: now);
    await restored.close();
    final reopened = OfflineAttendanceStore(
      await databaseFactoryIo.openDatabase(path, version: 1),
    );
    expect((await reopened.list(reopened.ops, 'actor')).single['op_id'], op);
    await reopened.close();
    // Only the exact temporary database is deleted; no recursive filesystem cleanup.
    await File(path).delete();
  });
  test('failed durable barrier prevents sending an unconfirmed local claim',
      () async {
    await enqueue();
    var writes = 0;
    final failing = OfflineAttendanceStore(
      store.db,
      barrier: (_) async {
        writes++;
        throw const FileSystemException('fixture');
      },
    );
    final worker = AttendanceQueue(failing, remote, 'actor', clock: () => now);
    await worker.sync();
    worker.dispose();
    expect(writes, 1);
    expect(remote.calls, 0);
    expect(worker.lastStorageError, isNotNull);
  });
}
