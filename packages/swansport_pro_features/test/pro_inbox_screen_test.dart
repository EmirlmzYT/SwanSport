import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

final _sampleNotifications = [
  NotificationRow(
    id: 'n-1',
    kind: 'referee_assignment',
    title: 'Yeni Hakem Ataması',
    body: 'Fenerbahçe - Galatasaray U19 maçında görevlendirildiniz.',
    createdAt: DateTime(2026, 10, 28, 14, 0),
    readAt: null,
    entityType: 'match',
    entityId: '00000000-0000-0000-0000-000000000001',
  ),
  NotificationRow(
    id: 'n-2',
    kind: 'expense_approval',
    title: 'Harcama Onayı Bekliyor',
    body: 'Ulaşım masrafı fişi onayınızı bekliyor.',
    createdAt: DateTime(2026, 10, 28, 12, 30),
    readAt: DateTime(2026, 10, 28, 13, 0),
    entityType: 'expense',
    entityId: '00000000-0000-0000-0000-000000000002',
  ),
  NotificationRow(
    id: 'n-3',
    kind: 'message', // Social-only kind, must be excluded from Pro Inbox!
    title: 'Sosyal Mesaj',
    body: 'Bu mesaj Pro gelen kutusunda görünmemelidir.',
    createdAt: DateTime(2026, 10, 28, 11, 0),
    readAt: null,
  ),
];

void main() {
  testWidgets('loading state is shown while pro notifications load',
      (tester) async {
    final completer = Completer<List<NotificationRow>>();
    await _pumpInbox(
      tester,
      notificationsOverride: () => completer.future,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('empty state is shown when no pro notifications exist',
      (tester) async {
    await _pumpInbox(
      tester,
      notificationsOverride: () async => const [],
    );

    expect(find.text('Gelen kutunuzda bildirim bulunmuyor.'), findsOneWidget);
  });

  testWidgets('pro inbox renders server-filtered rows and supports tabs',
      (tester) async {
    await _pumpInbox(
      tester,
      notificationsOverride: () async => _sampleNotifications.take(2).toList(),
    );

    // Pro notifications are present
    expect(find.text('Yeni Hakem Ataması'), findsOneWidget);
    expect(find.text('Harcama Onayı Bekliyor'), findsOneWidget);

    // Switch to "Okunmamış" (Unread) tab
    await tester.tap(find.textContaining('Okunmamış'));
    await tester.pumpAndSettle();

    // Only unread (n-1) remains visible
    expect(find.text('Yeni Hakem Ataması'), findsOneWidget);
    expect(find.text('Harcama Onayı Bekliyor'), findsNothing);
  });

  testWidgets('tapping notification calls tap callback', (tester) async {
    NotificationRow? tapped;
    String? markedId;
    await _pumpInbox(
      tester,
      notificationsOverride: () async => _sampleNotifications.take(2).toList(),
      onNotificationTap: (n) => tapped = n,
      onMarkRead: (id) async => markedId = id,
    );

    await tester.tap(find.text('Yeni Hakem Ataması'));
    await tester.pumpAndSettle();

    expect(tapped, isNotNull);
    expect(tapped?.id, equals('n-1'));
    expect(markedId, equals('n-1'));
  });

  testWidgets('mark all uses the Pro-only read operation', (tester) async {
    var called = false;
    String? markedId = 'not-called';
    await _pumpInbox(
      tester,
      notificationsOverride: () async => _sampleNotifications.take(2).toList(),
      onMarkRead: (id) async {
        called = true;
        markedId = id;
      },
    );

    await tester.tap(find.byTooltip('Tümünü Okundu İşaretle'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(markedId, isNull);
  });

  testWidgets('renders properly on narrow 320px width screen without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpInbox(
      tester,
      notificationsOverride: () async => _sampleNotifications.take(2).toList(),
    );

    expect(find.text('Yeni Hakem Ataması'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpInbox(
  WidgetTester tester, {
  required Future<List<NotificationRow>> Function() notificationsOverride,
  void Function(NotificationRow)? onNotificationTap,
  Future<void> Function(String? notificationId)? onMarkRead,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isSupabaseEnabledProvider.overrideWithValue(true),
        proNotificationsProvider.overrideWith((ref) => notificationsOverride()),
      ],
      child: MaterialApp(
        home: SharedProInboxScreen(
          onNotificationTap: onNotificationTap,
          onMarkRead: onMarkRead,
        ),
      ),
    ),
  );
  await tester.pump();
}
