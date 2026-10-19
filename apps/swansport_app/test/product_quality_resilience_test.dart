import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/push/push_service.dart';
import 'package:swansport_app/app/widgets/premium.dart';
import 'package:swansport_app/features/clubs/presentation/club_cockpit_screen.dart';
import 'package:swansport_app/features/network/presentation/discover_screen.dart';
import 'package:swansport_app/features/social/presentation/feed_screen.dart';
import 'package:swansport_app/features/social/presentation/notifications_screen.dart';
import 'package:swansport_data/swansport_data.dart';

const _mockClub = ClubRef(
  id: 'club-test-1',
  name: 'Kadıköy Spor',
  city: 'İstanbul',
  role: 'club_admin',
);

const _adminAccess = SwanAccess(
  isPlatformAdmin: false,
  clubRole: 'club_admin',
  coachLevel: 0,
  athleteKind: null,
);

void main() {
  group('1. Kullanıcı Dostu Hata Raporlama ve Ağ Dayanıklılığı', () {
    test('İnternet ve soket hatalarını anlaşılır Türkçe mesaja dönüştürür', () {
      const socketErr =
          'SocketException: Failed host lookup: \'api.supabase.co\' (OS Error: No address associated with hostname, errno = 7)';
      final msg = friendlyErrorMessage(socketErr);
      expect(msg, contains('İnternet bağlantısı kurulamadı'));
      expect(msg, isNot(contains('SocketException')));
      expect(msg, isNot(contains('errno = 7')));
    });

    test('Zaman aşımı ve bağlantı kopmalarını anlaşılır Türkçe mesaja dönüştürür', () {
      const timeoutErr = 'TimeoutException after 0:00:10.000000: timed out';
      final msg = friendlyErrorMessage(timeoutErr);
      expect(msg, contains('Sunucu yanıt vermedi'));
      expect(msg, isNot(contains('TimeoutException')));
    });

    test('42501 ve RLS yetki hatalarını teknik kod sızdırmadan açıklar', () {
      const permErr =
          'PostgrestException(message: permission denied for table profiles, code: 42501)';
      final msg = friendlyErrorMessage(permErr);
      expect(msg, contains('giriş yapmanız veya yetkinizin olması'));
      expect(msg, isNot(contains('42501')));
      expect(msg, isNot(contains('PostgrestException')));
    });

    testWidgets('premiumError widget onRetry tetiklendiğinde callback çalıştırır',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => premiumError(
                ctx,
                const SocketException('Failed host lookup'),
                onRetry: () => retried = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Veri yüklenemedi'), findsOneWidget);
      expect(find.textContaining('İnternet bağlantısı'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);

      await tester.tap(find.text('Tekrar Dene'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });

  group('2. Kritik Ekranlarda Ağ Hatası ve Tekrar Dene Widget Testleri', () {
    testWidgets(
        'FeedScreen hata durumunda premiumError gösterir ve Tekrar Dene akışı çalışır',
        (tester) async {
      var feedRetried = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith((ref) => Stream.value(null)),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                hasAccount: true,
              ),
            ),
            platformConfigProvider.overrideWith((ref) async => const PlatformConfig.empty()),
            feedProvider.overrideWith((ref) => []),
            discoverProvider.overrideWith((ref) {
              if (!feedRetried) {
                throw const SocketException('No address associated with hostname');
              }
              return [];
            }),
            suggestionsProvider.overrideWith((ref) => []),
            newsProvider.overrideWith((ref) => []),
            announcementsProvider.overrideWith((ref) => []),
            hiddenProfilesProvider.overrideWith((ref) => {}),
            activeClubProvider.overrideWith((ref) => null),
            myRefereeMatchesProvider.overrideWith((ref, _) async => []),
            refereeTodayMatchesProvider.overrideWith((ref) => []),
            publicLiveMatchesProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Veri yüklenemedi'), findsOneWidget);
      expect(find.textContaining('İnternet bağlantısı'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);

      feedRetried = true;
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'NotificationsScreen hata durumunda premiumError gösterir ve Tekrar Dene çalışır',
        (tester) async {
      var notifRetried = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categorizedNotificationsProvider.overrideWith((ref, cat) async {
              if (!notifRetried) {
                throw const SocketException('Connection reset');
              }
              return [];
            }),
            unreadNotificationsProvider.overrideWith((ref) async => 0),
            pushEnabledProvider.overrideWith((ref) async => false),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Veri yüklenemedi'), findsOneWidget);
      expect(find.textContaining('İnternet bağlantısı'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);

      notifRetried = true;
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();

      expect(find.text('Henüz bildirimin yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'DiscoverScreen hata durumunda premiumError gösterir ve Tekrar Dene çalışır',
        (tester) async {
      var discoverRetried = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoverClubsProvider.overrideWith((ref, filter) async {
              if (!discoverRetried) {
                throw const SocketException('Connection refused');
              }
              return [];
            }),
          ],
          child: const MaterialApp(
            home: DiscoverScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Veri yüklenemedi'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);

      discoverRetried = true;
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();

      expect(find.text('Filtreye uygun kulüp bulunamadı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('3. Dar Telefon ve Büyük Yazı Boyutu Dayanıklılık Testleri', () {
    testWidgets(
        'NotificationsScreen dar ekran (320px) ve büyük yazı (1.6x) taşma yapmaz',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categorizedNotificationsProvider.overrideWith(
              (ref, cat) async => [
                NotificationRow(
                  id: 'n-1',
                  title: 'Önemli Kulüp Duyurusu ve Aidat Bilgilendirmesi',
                  body:
                      'Kulübümüzün yeni dönem antrenman programı güncellenmiştir. Lütfen inceleyin.',
                  kind: 'announcement',
                  createdAt: DateTime.now(),
                ),
              ],
            ),
            unreadNotificationsProvider.overrideWith((ref) async => 1),
            pushEnabledProvider.overrideWith((ref) async => false),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Önemli Kulüp Duyurusu'), findsOneWidget);
    });

    testWidgets(
        'ClubCockpitScreen dar ekran (320px) ve büyük yazı (1.6x) taşma yapmaz',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(_adminAccess),
            activeClubProvider.overrideWith((ref) async => _mockClub),
            clubPendingApplicationsProvider.overrideWith((ref) async => const []),
            clubAthletesProvider.overrideWith((ref) async => const []),
            pendingPaymentsProvider.overrideWith((ref) async => const []),
            featureEnabledProvider(FeatureFlags.sportTrainingSessions)
                .overrideWithValue(true),
            featureEnabledProvider(FeatureFlags.clubStaffOperations)
                .overrideWithValue(true),
            featureEnabledProvider(FeatureFlags.seasonSetup)
                .overrideWithValue(true),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const ClubCockpitScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('GÜNÜN ACİL İŞLERİ'), findsOneWidget);
    });
  });
}
