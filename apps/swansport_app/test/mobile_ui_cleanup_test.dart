import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/app/design/swan_palette.dart';
import 'package:swansport_app/app/push/push_service.dart';
import 'package:swansport_app/features/attendance/presentation/screens/attendance_history_screen.dart';
import 'package:swansport_app/features/financial_management/presentation/finance_screen.dart';
import 'package:swansport_app/features/marketplace/presentation/marketplace_screen.dart';
import 'package:swansport_app/features/social/presentation/notifications_screen.dart';
import 'package:swansport_app/features/social/presentation/profile_screen.dart';
import 'package:swansport_app/features/social/presentation/messages_screen.dart';
import 'package:swansport_app/features/social/presentation/search_screen.dart';

class _Notifications extends NotificationService {
  _Notifications() : super(Supabase.instance.client);
  int marks = 0;
  @override
  Future<void> markAllRead() async { marks++; }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> render(WidgetTester tester, Widget screen, Brightness mode,
      {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      isSupabaseEnabledProvider.overrideWithValue(false),
      currentProfileProvider.overrideWith((_) async => null),
      myClubsProvider.overrideWith((_) async => []),
      swanAccessProvider.overrideWithValue(SwanAccess.none),
      ...overrides,
    ], child: MaterialApp(theme: ThemeData(brightness: mode),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!), home: screen)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  test('the eleven scoped screens do not reintroduce raw typography/colors', () {
    var root = Directory.current;
    while (!File('${root.path}/AGENTS.md').existsSync()) {
      final parent = root.parent;
      if (parent.path == root.path) throw StateError('repository root missing');
      root = parent;
    }
    final names = {
      'profile_screen.dart', 'notifications_screen.dart', 'messages_screen.dart',
      'search_screen.dart', 'marketplace_screen.dart', 'attendance_history_screen.dart',
      'finance_screen.dart', 'team_roster_screen.dart', 'athlete_workspace_screen.dart',
      'explore_screen.dart', 'club_settings_screen.dart',
    };
    final files = Directory('${root.path}/apps/swansport_app/lib/features')
        .listSync(recursive: true).whereType<File>()
        .where((f) => names.contains(f.uri.pathSegments.last)).toList();
    expect(files, hasLength(names.length));
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(RegExp(r'GoogleFonts\.|fontSize\s*:|TextStyle\s*\(|Color\s*\(\s*0x|Colors\.(black|white)').hasMatch(source),
          isFalse, reason: file.path);
    }
  });

  for (final mode in Brightness.values) {
    testWidgets('message header and long conversation names stay bounded: $mode', (tester) async {
      await render(tester, const MessagesScreen(), mode, overrides: [
        conversationsProvider.overrideWith((_) async => [ConversationRow(
          otherId: 'peer', otherName: 'Çok Uzun Adlı Antrenör ve Takım Arkadaşı',
          lastBody: 'Antrenman hakkında mesaj', lastAt: DateTime(2026), unread: 17)]),
        communityListProvider.overrideWith((_) async => []),
        suggestionsProvider.overrideWith((_) async => []),
      ]);
      expect(find.byTooltip('Yeni Sohbet'), findsOneWidget);
      expect(find.text('Çok Uzun Adlı Antrenör ve Takım Arkadaşı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('search real suggestion headers remain bounded without mock actions: $mode', (tester) async {
      await render(tester, const SearchScreen(), mode, overrides: [
        suggestionsProvider.overrideWith((_) async => const [SuggestionRow(
          id: 'peer', name: 'Çok Uzun İsimli Önerilen Antrenör', kind: 'coach')]),
      ]);
      expect(find.text('Önerilen Sporcular & Antrenörler'), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('filled controls retain contrast and dark shadows are transparent: $mode', () {
      final c = mode == Brightness.dark ? SwanPalette.dark : SwanPalette.light;
      final ratio = (c.onAccent.computeLuminance() + .05) / (c.accentFill.computeLuminance() + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
      if (c.isDark) expect(c.shadow.a, 0);
    });

    for (final count in [0, 17]) {
      testWidgets('notification badge is real, singular and bounded ($mode/$count)', (tester) async {
        final service = _Notifications();
        await render(tester, const NotificationsScreen(), mode, overrides: [
          notificationServiceProvider.overrideWithValue(service),
          unreadNotificationsProvider.overrideWith((_) async => count),
          categorizedNotificationsProvider.overrideWith((_, __) async => []),
          pushEnabledProvider.overrideWith((_) async => false),
          pushDiagnosticsProvider.overrideWith((_) async => const PushDiagnostics(
            supported: true, permission: true, token: 'test', state: PushSubState.mine)),
        ]);
        expect(find.text('$count yeni'), count == 0 ? findsNothing : findsOneWidget);
        expect(find.byIcon(Icons.done_all_rounded),
            count == 0 ? findsNothing : findsOneWidget);
        if (count > 0) {
          await tester.tap(find.byTooltip('Tümünü okundu işaretle'));
          await tester.pump();
          expect(service.marks, 1);
        } else {
          expect(service.marks, 0);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('attendance filters keep bounded horizontal scrolling: $mode', (tester) async {
      await render(tester, const AttendanceHistoryScreen(), mode, overrides: [
        activeClubProvider.overrideWith((_) async => null),
        attendanceSummaryProvider.overrideWith((_) async => const [AttendanceStat(
          athleteId: 'a', name: 'Çok Uzun İsimli Sporcu Soyadı',
          present: 9, absent: 1, total: 10, rate: 90)]),
      ]);
      await tester.tap(find.text('%80+'));
      await tester.pump();
      expect(find.text('Çok Uzun İsimli Sporcu Soyadı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finance snapshots accommodate narrow screens and large amounts: $mode', (tester) async {
      await render(tester, const FinanceScreen(), mode, overrides: [
        activeClubProvider.overrideWith((_) async => null),
        financeSummaryProvider.overrideWith((_) async => const FinanceSummary(
          billed: 999999999999, collected: 888888888888, outstanding: 111111111111,
          overdueCount: 9, overdueTotal: 99999999999, pendingPayments: 12, athletesWithFee: 99)),
      ]);
      expect(find.text('Toplam Tahsilat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('marketplace large price remains bounded and promises are not mocked: $mode', (tester) async {
      await render(tester, const MarketplaceScreen(), mode, overrides: [
        marketSearchProvider.overrideWith((_, __) async => [MarketItem(
          id: 'item', title: 'Çok Uzun Başlıklı Spor Malzemesi', status: MarketStatus.active,
          price: 999999999999, createdAt: DateTime(2026))]),
        marketFavoritesProvider.overrideWith((_) async => <String>{}),
      ]);
      await tester.scrollUntilVisible(find.text('Çok Uzun Başlıklı Spor Malzemesi'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Üyelere %20'), findsNothing);
      expect(find.text('Başantrenör Doğrulama Garantisi'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile long identity is constrained and dead story rings removed: $mode', (tester) async {
      const id = 'profile';
      await render(tester, const ProfileScreen(id: id), mode, overrides: [
        socialProfileProvider(id).overrideWith((_) async => const SocialProfile(
          id: id, name: 'Uzun İsimli Sporcu', isClub: false,
          username: 'çok_uzun_kullanıcı_adı_kart_aksiyonlarını_taşırmamalı',
          postCount: 999999999, followerCount: 999999999, followingCount: 999999999)),
        authorPostsProvider(id).overrideWith((_) async => []),
        myTrainingHistoryProvider.overrideWith((_) async => []),
      ]);
      final username = tester.widget<Text>(find.text('çok_uzun_kullanıcı_adı_kart_aksiyonlarını_taşırmamalı'));
      expect(username.maxLines, 1);
      expect(username.overflow, TextOverflow.ellipsis);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
      expect(find.text('ÖNE ÇIKANLAR'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
