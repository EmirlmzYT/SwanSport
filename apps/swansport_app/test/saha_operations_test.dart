import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/courts/presentation/court_detail_screen.dart';
import 'package:swansport_app/features/saha_operations/presentation/saha_operations_screen.dart';
import 'package:swansport_app/features/saha_operations/presentation/turf_duty_invite_dialog.dart';
import 'package:swansport_app/features/turf/presentation/turf_field_detail_screen.dart';
import 'package:swansport_data/swansport_data.dart';

final future = DateTime.now().toUtc().add(const Duration(hours: 2));
const code = '00000000-0000-4000-8000-000000000001';
final wait = CourtWaitEntry(
  id: 'w',
  courtId: 'c',
  courtName: 'Kort A',
  startsAt: future,
  status: 'offered',
  position: 1,
  offeredUntil: future,
);
final duty = TurfDuty(
  id: 'd',
  fieldId: 'f',
  fieldName: 'Saha A',
  venueName: 'Tesis',
  issuer: false,
  validUntil: future,
  inviteUntil: future,
  status: 'active',
);

class Service extends Fake implements SahaOperationsService {
  int accepted = 0, redeemed = 0, revoked = 0, created = 0, joined = 0;
  final operations = <String>[];
  List<CourtWaitEntry> waits = [wait];
  List<TurfDuty> jobs = [];
  Object? error;
  Completer<void>? held;
  @override
  Future<List<CourtWaitEntry>> waitlist() async => waits;
  @override
  Future<TurfDutyPage> duties({int offset = 0}) async =>
      TurfDutyPage(jobs, offset == 0 && jobs.isNotEmpty);
  @override
  Future<Set<String>> delegatedFields() async =>
      jobs.where((d) => d.live && !d.issuer).map((d) => d.fieldId).toSet();
  @override
  Future<String> acceptWait(String id, {int guests = 0, int needed = 0}) async {
    accepted++;
    if (held != null) await held!.future;
    if (error != null) throw error!;
    waits = [];
    return 'slot';
  }

  @override
  Future<String> redeemDuty(String value) async {
    redeemed++;
    if (error != null) throw error!;
    jobs = [duty];
    return 'd';
  }

  @override
  Future<void> revokeDuty(String id) async {
    revoked++;
    if (error != null) throw error!;
    jobs = [];
  }

  @override
  Future<TurfDutyInvite> createDuty(String field, int hours, String op) async {
    created++;
    operations.add(op);
    if (error != null) throw error!;
    return TurfDutyInvite(code: code, validUntil: future, inviteUntil: future);
  }

  @override
  Future<String> joinWait(String court, DateTime start) async {
    joined++;
    return 'w';
  }
}

class Courts extends Fake implements CourtService {
  @override
  Future<List<Court>> courts({String? cityCode}) async => [
        const Court(
          id: 'c',
          name: 'Kort A',
          lat: 0,
          lng: 0,
          opensAt: '00:00',
          closesAt: '24:00',
          capacity: 4,
        ),
      ];
}

void main() {
  late Service service;
  setUp(() => service = Service());
  Future<void> mount(
    WidgetTester t, {
    bool enabled = true,
    Widget? screen,
  }) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(true),
          featureFlagsProvider.overrideWith(
            (_) async => enabled
                ? const FeatureFlags({'court_waitlist', 'turf_delegation'})
                : const FeatureFlags.none(),
          ),
          authSessionProvider.overrideWith((_) => Stream.value(null)),
          sahaOperationsServiceProvider.overrideWithValue(service),
          courtServiceProvider.overrideWithValue(Courts()),
          courtWaitlistProvider.overrideWith((_) => service.waitlist()),
          turfDutiesProvider
              .overrideWith((_, offset) => service.duties(offset: offset)),
          delegatedTurfFieldIdsProvider
              .overrideWith((_) => service.delegatedFields()),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              verificationTier: 'location',
              delegatedTurfFieldIds: {'f'},
            ),
          ),
          turfOccupancyGridProvider('f').overrideWith(
            (_) async => [TurfSlot(startsAt: future, occupied: false)],
          ),
          courtTimelineProvider('c').overrideWith(
            (_) async => [
              TimelineSlot(
                startsAt: future,
                status: 'claimed',
                needed: 0,
                players: 1,
                mine: false,
                slotId: 'other',
              ),
            ],
          ),
        ],
        child: MaterialApp(home: screen ?? const SahaOperationsScreen()),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('closed features block the operations screen', (t) async {
    await mount(t, enabled: false);
    expect(
      find.text('Bu özellikler şu anda hesabına açık değil.'),
      findsOneWidget,
    );
    expect(find.text('Saati al'), findsNothing);
  });
  testWidgets('actual empty list explains how to join rather than success',
      (t) async {
    service.waits = [];
    await mount(t);
    expect(find.textContaining('Bekleme kaydın yok.'), findsOneWidget);
    expect(find.text('Saati al'), findsNothing);
  });
  testWidgets(
      'one in-flight accept; success removes offer and reports check-in requirement',
      (t) async {
    await mount(t);
    service.held = Completer<void>();
    await t.tap(find.text('Saati al'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Saati al').last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(service.accepted, 1);
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saati al'))
          .onPressed,
      isNull,
    );
    service.held!.complete();
    await t.pumpAndSettle();
    expect(find.text('Saati al'), findsNothing);
    expect(
      find.text('Kort sıran alındı. Korta varınca onayla.'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('closing the reservation form does not claim or report success',
      (t) async {
    await mount(t);
    await t.tap(find.text('Saati al'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tapAt(const Offset(10, 100));
    await t.pumpAndSettle();
    expect(service.accepted, 0);
    expect(find.text('Kort sıran alındı. Korta varınca onayla.'), findsNothing);
    expect(find.text('Saati al'), findsOneWidget);
  });
  testWidgets('server rejection keeps offer and shows retryable error',
      (t) async {
    service.error = StateError('expired');
    await mount(t);
    await t.tap(find.text('Saati al'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Saati al').last);
    await t.pumpAndSettle();
    expect(find.textContaining('İşlem tamamlanamadı.'), findsOneWidget);
    expect(find.text('Saati al'), findsOneWidget);
  });
  testWidgets(
      'invalid invitation never calls server; valid invitation opens actual duty',
      (t) async {
    service.waits = [];
    await mount(t);
    await t.ensureVisible(find.text('Görevi kabul et'));
    await t.tap(find.text('Görevi kabul et'));
    await t.pumpAndSettle();
    expect(service.redeemed, 0);
    await t.enterText(find.byType(TextField), code);
    await t.tap(find.text('Görevi kabul et'));
    await t.pumpAndSettle();
    expect(service.redeemed, 1);
    expect(find.text('Sahayı aç'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('recipient can end the assignment', (t) async {
    service.waits = [];
    service.jobs = [duty];
    await mount(t);
    await t.ensureVisible(find.text('Görevi bırak'));
    await t.tap(find.text('Görevi bırak'));
    await t.pumpAndSettle();
    expect(service.revoked, 1);
    expect(find.text('Görevi bırak'), findsNothing);
  });
  testWidgets('invite creation keeps operation ID after ambiguous failure',
      (t) async {
    service.error = StateError('network');
    await mount(
      t,
      screen: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const TurfDutyInviteDialog(fieldId: 'f'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Davet oluştur'));
    await t.pumpAndSettle();
    expect(find.textContaining('Davet sonucu doğrulanamadı.'), findsOneWidget);
    service.error = null;
    await t.tap(find.text('Aynı işlemi tekrar dene'));
    await t.pumpAndSettle();
    expect(service.operations.toSet(), hasLength(1));
    expect(find.text(code), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'temporary editor can mark occupancy but never sees redelegation control',
      (t) async {
    await mount(
      t,
      screen: const TurfFieldDetailScreen(
        field: TurfField(
          id: 'f',
          name: 'Saha A',
          venueName: 'Tesis',
          opensAt: '00:00',
          closesAt: '24:00',
        ),
      ),
    );
    expect(find.textContaining('Geçici saha görevin var'), findsOneWidget);
    expect(find.text('Görev devret'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('occupied future court exposes real waitlist join action',
      (t) async {
    await mount(
      t,
      screen: const CourtDetailScreen(
        court: Court(
          id: 'c',
          name: 'Kort A',
          lat: 0,
          lng: 0,
          opensAt: '00:00',
          closesAt: '24:00',
          capacity: 4,
        ),
      ),
    );
    await t.tap(find.text('Bekleme listesine gir'));
    await t.pumpAndSettle();
    expect(service.joined, 1);
    expect(find.textContaining('Bekleme listesine katıldın.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
