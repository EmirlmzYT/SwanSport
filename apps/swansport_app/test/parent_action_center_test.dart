import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:swansport_app/features/support/presentation/support_screen.dart';
import 'package:swansport_app/features/verification/presentation/parent_consent_center_screen.dart';
import 'package:swansport_data/swansport_data.dart';

class Service extends Fake implements ParentActionService {
  ParentActions data = const ParentActions();
  int loads = 0, calls = 0;
  Object? failure;
  Completer<void>? held;
  String? child, status;
  @override
  Future<ParentActions> load() async {
    loads++;
    return data;
  }

  @override
  Future<void> respond(GuardianEventAction e, String value) async {
    calls++;
    child = e.childId;
    status = value;
    if (held != null) await held!.future;
    if (failure != null) throw failure!;
    data = ParentActions(
      children: data.children,
      events: [],
      documents: data.documents,
      tickets: data.tickets,
    );
  }
}

class Vault extends Fake implements VaultService {
  int adds = 0;
  String? club, owner, type;
  Object? error;
  @override
  Future<void> add({
    required String clubId,
    required String name,
    String ownerType = 'club',
    String? ownerId,
    String? docType,
    String? path,
    DateTime? issued,
    DateTime? expires,
    String? note,
  }) async {
    adds++;
    club = clubId;
    owner = ownerId;
    type = ownerType;
    if (error != null) throw error!;
  }
}

const children = [
  GuardianChild(id: 'a', name: 'Ada', clubId: 'c1', clubName: 'Kulüp A'),
  GuardianChild(id: 'b', name: 'Ece', clubId: 'c2', clubName: 'Kulüp B'),
];
final events = [
  GuardianEventAction(
    id: 'e1',
    title: 'Ada antrenman',
    childId: 'a',
    childName: 'Ada',
    clubName: 'Kulüp A',
    startsAt: DateTime(2026, 10, 8),
  ),
  GuardianEventAction(
    id: 'e2',
    title: 'Ece maç',
    childId: 'b',
    childName: 'Ece',
    clubName: 'Kulüp B',
    startsAt: DateTime(2026, 10, 9),
  ),
];
void main() {
  late Service service;
  setUp(() => service = Service());
  Future<void> mount(
    WidgetTester t, {
    bool enabled = true,
    Future<ParentActions> Function()? load,
  }) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          featureEnabledProvider(FeatureFlags.parentHub)
              .overrideWith((_) => enabled),
          parentActionServiceProvider.overrideWithValue(service),
          parentActionsProvider
              .overrideWith((_) => load?.call() ?? service.load()),
          myTicketsProvider.overrideWith((_) async => service.data.tickets),
          ticketMessagesProvider('t').overrideWith((_) async => []),
          supportFixProvider('t').overrideWith((_) async => null),
          childVaultDocsProvider((clubId: 'c2', athleteId: 'b'))
              .overrideWith((_) async => []),
        ],
        child: MaterialApp(
          home: const ParentConsentCenterScreen(),
          routes: {
            '/veli-bagla': (_) => const Scaffold(body: Text('Kod ekranı')),
          },
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('flag closes direct route without loading actions', (t) async {
    await mount(t, enabled: false);
    expect(find.textContaining('hesabına açık değil'), findsOneWidget);
    expect(service.loads, 0);
  });
  testWidgets('loading, error and retry do not claim no pending jobs',
      (t) async {
    final held = Completer<ParentActions>();
    await mount(t, load: () => held.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    held.completeError(StateError('network'));
    await t.pumpAndSettle();
    expect(find.text('İşler yüklenemedi.'), findsOneWidget);
    expect(find.textContaining('işlem bekleyen'), findsNothing);
    await t.tap(find.text('Tekrar dene'));
    await t.pumpAndSettle();
    expect(find.text('İşler yüklenemedi.'), findsOneWidget);
  });
  testWidgets('no children links to actual invitation screen', (t) async {
    await mount(t);
    await t.pumpAndSettle();
    await t.tap(find.text('Davet koduyla çocuk bağla'));
    await t.pumpAndSettle();
    expect(find.text('Kod ekranı'), findsOneWidget);
  });
  testWidgets('child filter keeps the selected sibling and scoped documents',
      (t) async {
    service.data = ParentActions(children: children, events: events);
    await mount(t);
    await t.pumpAndSettle();
    expect(find.text('Ada antrenman'), findsOneWidget);
    expect(find.text('Ece maç'), findsOneWidget);
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Ece · Kulüp B').last);
    await t.pumpAndSettle();
    expect(find.text('Ada antrenman'), findsNothing);
    expect(find.text('Ece maç'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'response blocks repeat tap and removes only after server success',
      (t) async {
    service.data = ParentActions(children: children, events: [events.first]);
    service.held = Completer<void>();
    await mount(t);
    await t.pumpAndSettle();
    await t.tap(find.text('Katılacak'));
    await t.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await t.tap(find.text('Katılacak'));
    expect(service.calls, 1);
    expect(service.child, 'a');
    expect(service.status, 'attending');
    expect(find.text('Ada antrenman'), findsOneWidget);
    service.held!.complete();
    await t.pumpAndSettle();
    expect(find.text('Ada antrenman'), findsNothing);
    expect(find.text('Katılım yanıtı kaydedildi.'), findsOneWidget);
  });
  testWidgets('failure keeps pending task and does not show saved', (t) async {
    service.data = ParentActions(children: children, events: [events.first]);
    service.failure = StateError('conflict');
    await mount(t);
    await t.pumpAndSettle();
    await t.tap(find.text('Katılamayacak'));
    await t.pumpAndSettle();
    expect(find.textContaining('Yanıt kaydedilemedi'), findsOneWidget);
    expect(find.text('Katılım yanıtı kaydedildi.'), findsNothing);
    expect(find.text('Ada antrenman'), findsOneWidget);
  });
  testWidgets(
      'document action opens child club without active club and no verification button',
      (t) async {
    service.data = ParentActions(
      children: children,
      documents: [
        VaultDoc(
          id: 'd',
          name: 'Lisans',
          ownerType: 'athlete',
          ownerId: 'b',
          ownerName: 'Ece',
          verified: false,
          state: 'süresi doldu',
          createdAt: DateTime(2026),
          expiresOn: DateTime(2026, 10, 1),
        ),
      ],
    );
    await mount(t);
    await t.pumpAndSettle();
    await t.tap(find.text('Çocuğun belgelerini aç'));
    await t.pumpAndSettle();
    final screen =
        t.widget<DocumentVaultScreen>(find.byType(DocumentVaultScreen));
    expect(screen.child!.clubId, 'c2');
    expect(screen.child!.id, 'b');
    expect(find.text('Doğrula'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('support action opens the actual latest ticket thread',
      (t) async {
    service.data = ParentActions(
      children: children,
      tickets: [
        SupportTicket(
          id: 't',
          subject: 'Yanıt bekleyen talep',
          status: 'awaiting_user_response',
          createdAt: DateTime(2026),
        ),
      ],
    );
    await mount(t);
    await t.pumpAndSettle();
    await t.tap(find.text('Talebi aç ve yanıtla'));
    await t.pumpAndSettle();
    expect(
      t.widget<TicketThreadScreen>(find.byType(TicketThreadScreen)).ticket.id,
      't',
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'child document upload validates date, keeps failed form and binds correct owner',
      (t) async {
    final vault = Vault();
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          vaultServiceProvider.overrideWithValue(vault),
          documentImagePickerProvider.overrideWith((_) => () async => null),
          childVaultDocsProvider((clubId: 'c2', athleteId: 'b'))
              .overrideWith((_) async => []),
        ],
        child: const MaterialApp(
          home: DocumentVaultScreen(
            child: GuardianChild(
              id: 'b',
              name: 'Çok Uzun İsimli Bir Sporcu Adı Soyadı',
              clubId: 'c2',
              clubName: 'Kulüp B',
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('Yükle'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sporcu lisansı'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, '31.02.2027');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(vault.adds, 0);
    expect(find.textContaining('Geçerli bir tarih gir'), findsWidgets);
    await t.enterText(find.byType(TextField).last, '31.12.2027');
    vault.error = StateError('network');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(vault.adds, 1);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(find.text('Belge eklendi'), findsNothing);
    vault.error = null;
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(vault.adds, 2);
    expect(vault.club, 'c2');
    expect(vault.owner, 'b');
    expect(vault.type, 'athlete');
    expect(find.text('Kaydet'), findsNothing);
    expect(find.text('Belge eklendi'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
