import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, PostgrestException;

import 'club_lifecycle_service.dart';
import 'diagnostics.dart';
import 'offline/attendance_database_io.dart'
    if (dart.library.js_interop) 'offline/attendance_database_web.dart'
    as platform;
import 'supabase_scope.dart';

/// Actor-scoped local data. No secrets, tokens or diagnoses are persisted.
class OfflineAttendanceStore {
  OfflineAttendanceStore(this.db, {Future<void> Function(Database)? barrier})
      : _barrier = barrier ?? platform.attendanceCommitBarrier;
  final Database db;
  final Future<void> Function(Database) _barrier;
  Future<void> _tail = Future.value();
  final cache = stringMapStoreFactory.store('attendance_cache');
  final drafts = stringMapStoreFactory.store('attendance_drafts');
  final ops = stringMapStoreFactory.store('attendance_ops');
  static String key(String actor, String event) => '$actor/$event';
  Future<T> write<T>(Future<T> Function(Transaction) action) {
    final task = _tail.then((_) => db.transaction(action)).then((result) async {
      await _barrier(db);
      return result;
    });
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  Future<void> close() async {
    await _tail;
    await db.close();
  }

  Future<List<Map<String, dynamic>>> list(
    StoreRef<String, Map<String, Object?>> store,
    String actor,
  ) async {
    await _tail;
    final rows = await store.find(
      db,
      finder: Finder(filter: Filter.equals('actor_id', actor)),
    );
    return rows
        .map((r) => Map<String, dynamic>.from(r.value)..['local_key'] = r.key)
        .toList();
  }

  Future<void> prepare(String actor, Map<String, dynamic> snapshot) async {
    if (snapshot['actor_id'] != actor) {
      throw StateError('Başka hesabın kadrosu');
    }
    final rows = snapshot['rows'] as List;
    if (rows.length > 200) throw StateError('Kadro sınırı');
    await write((tx) async {
      final existing = await cache.find(
        tx,
        finder: Finder(filter: Filter.equals('actor_id', actor)),
      );
      final k = key(actor, snapshot['event_id'] as String);
      if (existing.length >= 20 && !existing.any((r) => r.key == k)) {
        throw StateError('En fazla 20 etkinlik hazırlanabilir');
      }
      await cache.record(k).put(tx, snapshot);
    });
  }

  Future<void> mark(
    String actor,
    String event,
    String athlete,
    String status, {
    DateTime? now,
  }) async {
    final time = (now ?? DateTime.now()).toUtc();
    if (!const ['present', 'absent', 'excused', 'late'].contains(status)) {
      throw ArgumentError('Durum');
    }
    await write((tx) async {
      final snapshot = await cache.record(key(actor, event)).get(tx);
      if (snapshot == null ||
          DateTime.parse(snapshot['expires_at'] as String).isBefore(time)) {
        throw StateError('Kadroyu yeniden hazırla');
      }
      final blocked = await ops.count(
        tx,
        filter: Filter.and([
          Filter.equals('actor_id', actor),
          Filter.equals('event_id', event),
          Filter.notEquals('state', 'done'),
        ]),
      );
      if (blocked > 0) throw StateError('Önce bekleyen işlemi tamamla');
      final row = (snapshot['rows'] as List)
          .cast<Map<String, dynamic>>()
          .where((r) => r['athlete_id'] == athlete)
          .firstOrNull;
      if (row == null) throw StateError('Kadroda yok');
      if (row['eligibility'] == 'restricted' &&
          (status == 'present' || status == 'late')) {
        throw StateError('Uygunluk kısıtı');
      }
      final k = '${key(actor, event)}/$athlete';
      final previous = await drafts.record(k).get(tx);
      await drafts.record(k).put(tx, {
        'actor_id': actor,
        'event_id': event,
        'athlete_id': athlete,
        'status': status,
        'version': previous?['version'] ?? row['version'],
        'marked_at': time.toIso8601String(),
      });
    });
  }

  Future<String> enqueue(String actor, String event, {DateTime? now}) async {
    final id = diagnosticId();
    final time = (now ?? DateTime.now()).toUtc();
    return write((tx) async {
      final pending = await ops.count(
        tx,
        filter: Filter.and([
          Filter.equals('actor_id', actor),
          Filter.notEquals('state', 'done'),
        ]),
      );
      if (pending >= 100) throw StateError('Önce bekleyen kayıtları gönder');
      final same = await ops.count(
        tx,
        filter: Filter.and([
          Filter.equals('actor_id', actor),
          Filter.equals('event_id', event),
          Filter.notEquals('state', 'done'),
        ]),
      );
      if (same > 0) throw StateError('Bu etkinliğin işlemi zaten bekliyor');
      final dirty = await drafts.find(
        tx,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('actor_id', actor),
            Filter.equals('event_id', event),
          ]),
          sortOrders: [SortOrder('athlete_id')],
        ),
      );
      if (dirty.isEmpty) throw StateError('Önce bir işaret seç');
      await ops.record(id).put(tx, {
        'actor_id': actor,
        'event_id': event,
        'op_id': id,
        'state': 'pending',
        'attempts': 0,
        'created_at': time.toIso8601String(),
        'next_at': time.toIso8601String(),
        'marks': dirty.map((r) => r.value).toList(),
      });
      for (final r in dirty) {
        await drafts.record(r.key).delete(tx);
      }
      return id;
    });
  }

  Future<void> retry(String actor, String op, {DateTime? now}) =>
      write((tx) async {
        final row = await ops.record(op).get(tx);
        if (row == null ||
            row['actor_id'] != actor ||
            !['pending', 'rejected', 'paused'].contains(row['state'])) {
          throw StateError('İşlem tekrar denenemez');
        }
        await ops.record(op).update(tx, {
          'state': 'pending',
          'attempts': 0,
          'next_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
          'manual': true,
          'error': null,
        });
      });

  Future<void> forget(String actor, String event) => write((tx) async {
        final dirty = await drafts.count(
          tx,
          filter: Filter.and([
            Filter.equals('actor_id', actor),
            Filter.equals('event_id', event),
          ]),
        );
        final waiting = await ops.count(
          tx,
          filter: Filter.and([
            Filter.equals('actor_id', actor),
            Filter.equals('event_id', event),
            Filter.notEquals('state', 'done'),
          ]),
        );
        if (dirty + waiting > 0) {
          throw StateError('İşaret veya gönderim varken kadro kaldırılamaz');
        }
        await cache.record(key(actor, event)).delete(tx);
      });

  /// Only a definitive rejection can be abandoned, with an explicit user choice.
  /// The original marks remain in local history; uncertain sends cannot use this.
  Future<void> abandonRejected(String actor, String op) => write((tx) async {
        final row = await ops.record(op).get(tx);
        if (row == null ||
            row['actor_id'] != actor ||
            row['state'] != 'rejected') {
          throw StateError('Yalnız reddedilmiş işlem bırakılabilir');
        }
        await ops
            .record(op)
            .update(tx, {'state': 'done', 'resolution': 'abandoned'});
      });

  /// Explicitly acknowledging a conflict never sends a write to the server.
  Future<void> resolve(
    String actor,
    String op, {
    List<Map<String, dynamic>>? replacement,
    DateTime? now,
  }) async {
    final newId = diagnosticId();
    final time = (now ?? DateTime.now()).toUtc().toIso8601String();
    await write((tx) async {
      final row = await ops.record(op).get(tx);
      if (row == null ||
          row['actor_id'] != actor ||
          row['state'] != 'conflict') {
        throw StateError('Çakışma yok');
      }
      if (replacement != null && replacement.isNotEmpty) {
        await ops.record(newId).put(tx, {
          'actor_id': actor,
          'event_id': row['event_id'],
          'op_id': newId,
          'state': 'pending',
          'attempts': 0,
          'created_at': time,
          'next_at': time,
          'marks': replacement,
        });
      }
      await ops.record(op).update(tx, {
        'state': 'done',
        'resolution': replacement == null ? 'server' : 'new_operation',
      });
    });
  }
}

abstract class AttendanceQueueRemote {
  String? get actorId;
  Future<Map<String, dynamic>> prepare(String event);
  Future<AttendanceOpResult> send(
    String actor,
    String event,
    String op,
    List<Map<String, dynamic>> marks,
  );
}

class SupabaseAttendanceQueueRemote implements AttendanceQueueRemote {
  SupabaseAttendanceQueueRemote(this.client);
  final SupabaseClient client;
  @override
  String? get actorId => client.auth.currentUser?.id;
  @override
  Future<Map<String, dynamic>> prepare(String event) async =>
      ((await client.rpc<dynamic>(
        'prepare_attendance_offline',
        params: {'p_event': event},
      )) as Map)
          .cast<String, dynamic>();
  @override
  Future<AttendanceOpResult> send(
    String actor,
    String event,
    String op,
    List<Map<String, dynamic>> marks,
  ) async =>
      AttendanceOpResult.fromMap(
        ((await client.rpc<dynamic>(
          'save_attendance_offline',
          params: {
            'p_actor': actor,
            'p_event': event,
            'p_op_id': op,
            'p_marks': marks,
          },
        )) as Map)
            .cast<String, dynamic>(),
      );
}

class AttendanceQueue {
  AttendanceQueue(
    this.store,
    this.remote,
    this.actor, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final OfflineAttendanceStore store;
  final AttendanceQueueRemote remote;
  final String actor;
  final DateTime Function() clock;
  bool _running = false, _disposed = false;
  Timer? _timer;
  String? lastStorageError;
  void start() {
    unawaited(sync());
    _timer =
        Timer.periodic(const Duration(seconds: 30), (_) => unawaited(sync()));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  Future<void> prepare(String event) async {
    if (remote.actorId != actor) throw StateError('Hesap değişti');
    final snapshot =
        await remote.prepare(event).timeout(const Duration(seconds: 10));
    if (remote.actorId != actor || _disposed) throw StateError('Hesap değişti');
    await store.prepare(actor, snapshot);
  }

  Future<void> sync() async {
    if (_running || _disposed || remote.actorId != actor) return;
    _running = true;
    lastStorageError = null;
    try {
      final rows = await store.list(store.ops, actor);
      rows.sort(
        (a, b) =>
            (a['created_at'] as String).compareTo(b['created_at'] as String),
      );
      for (final initial in rows) {
        if (_disposed || remote.actorId != actor) break;
        final now = clock().toUtc();
        final token = diagnosticId();
        final op = initial['op_id'] as String;
        final claimed = await store.write((tx) async {
          final row = await store.ops.record(op).get(tx);
          if (row == null ||
              row['actor_id'] != actor ||
              !['pending', 'sending'].contains(row['state'])) {
            return null;
          }
          if (row['lease_until'] != null &&
              DateTime.parse(row['lease_until'] as String).isAfter(now)) {
            return null;
          }
          if (DateTime.parse(row['created_at'] as String)
                      .isBefore(now.subtract(const Duration(days: 7))) &&
                  row['manual'] != true ||
              (row['attempts'] as int) >= 5) {
            await store.ops.record(op).update(tx, {
              'state': 'paused',
              'error':
                  'Kayıt eski veya beş kez denenmiş. Elle kontrol edip tekrar dene.',
            });
            return null;
          }
          if (DateTime.parse(row['next_at'] as String).isAfter(now)) {
            return null;
          }
          await store.ops.record(op).update(tx, {
            'state': 'sending',
            'lease': token,
            'lease_until':
                now.add(const Duration(seconds: 30)).toIso8601String(),
            'attempts': (row['attempts'] as int) + 1,
          });
          return row;
        });
        if (claimed == null) continue;
        if (_disposed || remote.actorId != actor) break;
        Map<String, Object?> update;
        try {
          final result = await remote
              .send(
                actor,
                claimed['event_id'] as String,
                op,
                (claimed['marks'] as List)
                    .map((r) => Map<String, dynamic>.from(r as Map))
                    .toList(),
              )
              .timeout(const Duration(seconds: 10));
          update = {
            'state': result.hasConflicts ? 'conflict' : 'done',
            'applied': result.applied,
            'uncertain': false,
            'error': null,
            'conflicts': result.conflicts
                .map(
                  (c) => {
                    'athlete_id': c.athleteId,
                    'current_status': c.currentStatus,
                    'current_version': c.currentVersion,
                    'sent_status': c.sentStatus,
                    'reason': c.reason,
                  },
                )
                .toList(),
          };
        } catch (e) {
          final rejected = e is PostgrestException &&
              (e.code == 'P0001' ||
                  e.code == '42501' ||
                  (e.code?.startsWith('22') ?? false));
          final attempts = (claimed['attempts'] as int) + 1;
          update = {
            'state': rejected
                ? (claimed['uncertain'] == true ? 'paused' : 'rejected')
                : attempts >= 5
                    ? 'paused'
                    : 'pending',
            'uncertain': claimed['uncertain'] == true || !rejected,
            'error': rejected
                ? (claimed['uncertain'] == true
                    ? 'Önceki gönderim uygulanmış olabilir; sonuç doğrulanamadı. Yetkini ve sunucudaki kaydı kontrol et.'
                    : 'Sunucu reddetti. Yetki, kadro veya uygunluk değişmiş olabilir.')
                : 'Sunucu sonucu doğrulanamadı. İşlem aynı kimlikle bekliyor.',
            'next_at': now
                .add(Duration(seconds: 30 * (1 << attempts)))
                .toIso8601String(),
          };
        }
        await store.write((tx) async {
          final latest = await store.ops.record(op).get(tx);
          if (latest?['lease'] == token) {
            await store.ops
                .record(op)
                .update(tx, {...update, 'lease': null, 'lease_until': null});
            if (update['state'] == 'done' || update['state'] == 'conflict') {
              final event = claimed['event_id'] as String;
              final snapshot = await store.cache
                  .record(OfflineAttendanceStore.key(actor, event))
                  .get(tx);
              if (snapshot != null) {
                final changed =
                    (claimed['marks'] as List).cast<Map<String, dynamic>>();
                final conflicts =
                    (update['conflicts'] as List).cast<Map<String, dynamic>>();
                final newRows = (snapshot['rows'] as List)
                    .map((r) => Map<String, Object?>.from(r as Map))
                    .toList();
                for (final row in newRows) {
                  final mark = changed
                      .where((m) => m['athlete_id'] == row['athlete_id'])
                      .firstOrNull;
                  if (mark == null) continue;
                  final conflict = conflicts
                      .where((c) => c['athlete_id'] == row['athlete_id'])
                      .firstOrNull;
                  if (conflict == null && row['version'] == mark['version']) {
                    row['status'] = mark['status'];
                    row['version'] = (mark['version'] as int) + 1;
                  } else if (conflict != null &&
                      row['version'] == mark['version']) {
                    row['status'] = conflict['current_status'];
                    row['version'] = conflict['current_version'] ?? 0;
                  }
                }
                await store.cache
                    .record(OfflineAttendanceStore.key(actor, event))
                    .update(tx, {'rows': newRows});
              }
              final done = await store.ops.find(
                tx,
                finder: Finder(
                  filter: Filter.and([
                    Filter.equals('actor_id', actor),
                    Filter.equals('state', 'done'),
                  ]),
                  sortOrders: [SortOrder('created_at', false)],
                ),
              );
              for (final row in done.skip(100)) {
                await store.ops.record(row.key).delete(tx);
              }
            }
          }
        });
      }
    } catch (_) {
      // Persistence failures retain records and never authorize a network send.
      lastStorageError =
          'Cihaz kaydı doğrulanamadı. Depolama alanını kontrol et.';
    } finally {
      _running = false;
    }
  }

  Future<void> keepMine(Map<String, dynamic> op) async {
    final snapshot = await remote
        .prepare(op['event_id'] as String)
        .timeout(const Duration(seconds: 10));
    if (_disposed || remote.actorId != actor || snapshot['actor_id'] != actor) {
      throw StateError('Hesap değişti');
    }
    final ids =
        (op['conflicts'] as List).map((c) => (c as Map)['athlete_id']).toSet();
    final fresh = (snapshot['rows'] as List).cast<Map<String, dynamic>>();
    final replacement = <Map<String, dynamic>>[];
    for (final mark in (op['marks'] as List)
        .cast<Map<String, dynamic>>()
        .where((r) => ids.contains(r['athlete_id']))) {
      final row =
          fresh.where((r) => r['athlete_id'] == mark['athlete_id']).firstOrNull;
      if (row == null) throw StateError('Sporcu artık kadroda değil');
      if (row['eligibility'] == 'restricted' &&
          ['present', 'late'].contains(mark['status'])) {
        throw StateError('Güncel uygunluk kısıtı bu işarete izin vermiyor');
      }
      replacement.add({
        ...Map<String, dynamic>.from(mark),
        'version': row['version'],
        'marked_at': clock().toUtc().toIso8601String(),
      });
    }
    await store.resolve(
      actor,
      op['op_id'] as String,
      replacement: replacement,
      now: clock(),
    );
    await store.prepare(actor, snapshot);
    await sync();
  }
}

final attendanceActorProvider = Provider<String?>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  final session = ref.watch(authSessionProvider);
  return session.valueOrNull?.user.id ??
      ref.watch(supabaseClientProvider).auth.currentUser?.id;
});
final offlineAttendanceStoreProvider =
    FutureProvider<OfflineAttendanceStore>((ref) async {
  final store = OfflineAttendanceStore(await platform.openAttendanceDatabase());
  ref.onDispose(() => unawaited(store.close()));
  return store;
});
final attendanceQueueProvider = FutureProvider<AttendanceQueue?>((ref) async {
  final actor = ref.watch(attendanceActorProvider);
  if (actor == null) return null;
  final remote =
      SupabaseAttendanceQueueRemote(ref.watch(supabaseClientProvider));
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final store = await ref.watch(offlineAttendanceStoreProvider.future);
  if (disposed) return null;
  final queue = AttendanceQueue(store, remote, actor);
  ref.onDispose(queue.dispose);
  queue.start();
  return queue;
});
final attendanceLocalDataProvider =
    StreamProvider<Map<String, List<Map<String, dynamic>>>>((ref) async* {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final queue = await ref.watch(attendanceQueueProvider.future);
  if (disposed) return;
  if (queue == null) {
    yield {'cache': [], 'drafts': [], 'ops': []};
    return;
  }
  final store = queue.store;
  // Sembast watches also receive changes made by other browser tabs.
  final changes = StreamController<void>();
  final subs = [
    for (final s in [store.cache, store.drafts, store.ops])
      s
          .query(finder: Finder(filter: Filter.equals('actor_id', queue.actor)))
          .onSnapshots(store.db)
          .listen((_) {
        if (!disposed && !changes.isClosed) changes.add(null);
      }),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      unawaited(s.cancel());
    }
    unawaited(changes.close());
  });
  try {
    Future<Map<String, List<Map<String, dynamic>>>> read() async => {
          'cache': await store.list(store.cache, queue.actor),
          'drafts': await store.list(store.drafts, queue.actor),
          'ops': await store.list(store.ops, queue.actor),
        };
    // Emit an initial snapshot independently of watch scheduling.
    final initial = await read();
    if (disposed) return;
    yield initial;
    await for (final _ in changes.stream) {
      if (disposed) break;
      final data = await read();
      if (disposed) break;
      yield data;
    }
  } catch (_) {
    if (!disposed) rethrow;
  } finally {
    for (final sub in subs) {
      await sub.cancel();
    }
    if (!changes.isClosed) await changes.close();
  }
});
