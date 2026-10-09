import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:swansport_app/features/attendance/presentation/attendance_queue_banner.dart';
import 'package:swansport_app/features/attendance/presentation/screens/live_attendance_screen.dart';
import 'package:swansport_data/swansport_data.dart';

class Lifecycle extends Fake implements ClubLifecycleService {
  int calls = 0;
  Object? failure;
  final operations = <String>[];
  List<Map<String, dynamic>>? sent;
  @override
  Future<AttendanceOpResult> saveAttendance({
    required String eventId,
    required String opId,
    required List<Map<String, dynamic>> marks,
  }) async {
    calls++;
    operations.add(opId);
    sent = marks.map((m) => Map<String, dynamic>.from(m)).toList();
    if (failure != null) {
      final e = failure!;
      failure = null;
      throw e;
    }
    return AttendanceOpResult(
      applied: marks.length,
      conflicts: [],
      replayed: false,
    );
  }
}

class Remote extends Fake implements AttendanceQueueRemote {
  @override
  String? get actorId => 'actor';
  int calls = 0;
  @override
  Future<AttendanceOpResult> send(
    String actor,
    String event,
    String op,
    List<Map<String, dynamic>> marks,
  ) async {
    calls++;
    throw TimeoutException('offline');
  }
}

void main() {
  late Lifecycle lifecycle;
  late OfflineAttendanceStore store;
  late AttendanceQueue queue;
  late Remote remote;
  final now = DateTime.now().toUtc();
  setUp(() async {
    lifecycle = Lifecycle();
    remote = Remote();
    store = OfflineAttendanceStore(
      await databaseFactoryMemory
          .openDatabase('widget-${DateTime.now().microsecondsSinceEpoch}'),
      barrier: (_) async {},
    );
    queue = AttendanceQueue(store, remote, 'actor');
  });
  tearDown(() async {
    queue.dispose();
    await store.close();
  });
  Future<void> prepare() => store.prepare('actor', {
        'actor_id': 'actor',
        'event_id': 'e',
        'club_id': 'c',
        'title': 'Hazır antrenman',
        'starts_at': now.toIso8601String(),
        'prepared_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
        'rows': [
          {
            'athlete_id': 'a',
            'full_name': 'Ada',
            'status': null,
            'version': 0,
            'rsvp_status': 'attending',
            'eligibility': 'eligible',
          }
        ],
      });
  Future<void> mount(
    WidgetTester t, {
    bool offline = false,
    bool banner = false,
  }) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    late ProviderContainer container;
    await t.runAsync(() async {
      container = ProviderContainer(
        overrides: [
          attendanceQueueProvider
              .overrideWith((ref) async => offline ? queue : null),
          activeClubProvider.overrideWith(
            (ref) async => offline
                ? null
                : const ClubRef(id: 'c', name: 'Kulüp', role: 'coach'),
          ),
          eventsProvider.overrideWith((ref) async {
            if (offline) throw StateError('offline');
            return [
              EventRow(
                id: 'e',
                title: 'Antrenman',
                place: null,
                kind: 'training',
                startsAt: now,
              ),
            ];
          }),
          featureEnabledProvider(FeatureFlags.offlineAttendance)
              .overrideWithValue(false),
          versionedRosterProvider('e').overrideWith((ref) async {
            if (offline) throw StateError('offline');
            return const [
              RosterEntry(
                athleteId: 'a',
                fullName: 'Ada',
                rsvp: 'attending',
                version: 3,
              ),
            ];
          }),
          clubLifecycleServiceProvider.overrideWithValue(lifecycle),
        ],
      );
      container.listen(attendanceLocalDataProvider, (_, __) {});
      if (offline) {
        await container
            .read(attendanceLocalDataProvider.future)
            .timeout(const Duration(seconds: 3));
      }
    });
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: banner
              ? const Scaffold(body: AttendanceQueueBanner())
              : const LiveAttendanceScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('RSVP suggestions are not automatically saved', (t) async {
    await mount(t);
    expect(find.text('Sunucuya kaydet (0)'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Sunucuya kaydet (0)'),
          )
          .onPressed,
      isNull,
    );
    expect(lifecycle.calls, 0);
    await t.tap(find.text('Var'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sunucuya kaydet (1)'));
    await t.pumpAndSettle();
    expect(lifecycle.sent!.single['version'], 3);
    expect(lifecycle.sent!.single['status'], 'present');
    expect(t.takeException(), isNull);
  });
  testWidgets('online lost response keeps the same operation and freezes marks',
      (t) async {
    lifecycle.failure = TimeoutException('fixture');
    await mount(t);
    await t.tap(find.text('Var'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sunucuya kaydet (1)'));
    await t.pumpAndSettle();
    expect(
      t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Yok')).onSelected,
      isNull,
    );
    await t.ensureVisible(find.text('Aynı işlemi tekrar dene'));
    await t.tap(find.text('Aynı işlemi tekrar dene'));
    await t.pumpAndSettle();
    expect(lifecycle.operations.first, lifecycle.operations.last);
  });
  testWidgets(
      'prepared roster is usable after reopening with no network and retains unsent marks',
      (t) async {
    await t.runAsync(prepare);
    await mount(t, offline: true);
    expect(find.text('Ada'), findsOneWidget);
    await t.runAsync(() async {
      await t.tap(find.text('Var'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((await store.list(store.drafts, 'actor')).length, 1);
    });
    await t.pumpAndSettle();
    await t.runAsync(() async {
      await t.tap(find.text('İşaretleri kuyruğa al (1)'));
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while ((remote.calls < 1 ||
              (await store.list(store.ops, 'actor')).single['state'] !=
                  'pending') &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect((await store.list(store.ops, 'actor')).single['state'], 'pending');
    });
    await t.pumpAndSettle();
    expect(remote.calls, 1);
    expect(find.text('Sunucuda henüz doğrulanmadı'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'definitive rejection can be explicitly abandoned without losing its history',
      (t) async {
    await t.runAsync(() async {
      await prepare();
      await store.mark('actor', 'e', 'a', 'present');
      final id = await store.enqueue('actor', 'e');
      await store.write(
        (tx) => store.ops.record(id).update(tx, {'state': 'rejected'}),
      );
    });
    await mount(t, offline: true);
    await t.ensureVisible(find.text('Reddedilen işlemi bırak'));
    await t.runAsync(() => t.tap(find.text('Reddedilen işlemi bırak')));
    await t.pumpAndSettle();
    await t.runAsync(() async {
      await t.tap(find.text('Onayla'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pumpAndSettle();
    await t.runAsync(() async {
      final op = (await store.list(store.ops, 'actor')).single;
      expect(op['resolution'], 'abandoned');
      expect(op['marks'], isNotEmpty);
    });
    expect(remote.calls, 0);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'uncertain online send offers an explicit exit to inspect server records',
      (t) async {
    lifecycle.failure = TimeoutException('fixture');
    await mount(t);
    await t.tap(find.text('Var'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sunucuya kaydet (1)'));
    await t.pumpAndSettle();
    await t
        .ensureVisible(find.text('İşaretleri bırak ve kayıtları kontrol et'));
    await t.tap(find.text('İşaretleri bırak ve kayıtları kontrol et'));
    await t.pumpAndSettle();
    await t.tap(find.text('Onayla'));
    await t.pumpAndSettle();
    expect(find.text('Aynı işlemi tekrar dene'), findsNothing);
    expect(lifecycle.calls, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('home row exposes persisted drafts for the current actor',
      (t) async {
    await t.runAsync(prepare);
    await t.runAsync(() => store.mark('actor', 'e', 'a', 'present'));
    await mount(t, offline: true, banner: true);
    expect(
      find.text('0 yoklama gönderimi, 1 cihaz taslağı bekliyor'),
      findsOneWidget,
    );
  });
}
