import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/federation/presentation/federation_center_screen.dart';
import 'package:swansport_app/features/live_match/presentation/league_standings_view.dart';
import 'package:swansport_app/features/live_match/presentation/match_follow_button.dart';
import 'package:swansport_data/swansport_data.dart';

final _mockTodayMatch = PublicLiveMatchSummary.fromMap({
  'match_id': '00000000-0000-0000-0000-000000000001',
  'program_name': 'U16 İstanbul Basketbol Ligi',
  'sport_code': 'basketbol',
  'city_code': '34',
  'status': 'scheduled',
  'home_club_name': 'Kadıköy SK',
  'away_club_name': 'Beşiktaş Akademi',
  'home_score': 68,
  'away_score': 64,
  'is_live': true,
  'is_today': true,
  'location': 'Caferağa Spor Salonu',
  'elapsed_seconds': 1200,
});

final _mockActivity = FederationActivity.fromMap({
  'id': '00000000-0000-0000-0000-000000000002',
  'program_id': 'prog-1',
  'title': 'Türkiye Gençler Şampiyonası',
  'sport_code': 'basketbol',
  'city_code': '34',
  'season_id': 'season-2026',
  'season_label': '2026-2027 Sezonu',
  'federation_name': 'Türkiye Basketbol Federasyonu',
  'office_name': 'İstanbul İl Temsilciliği',
  'kind': 'tournament',
  'status': 'scheduled',
  'starts_at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
  'all_day': false,
  'is_match': true,
});

final _mockLeague = StandingsLeague.fromMap({
  'id': '00000000-0000-0000-0000-000000000003',
  'name': 'Gelişim Ligi A Grubu',
  'sport_code': 'basketbol',
  'city_code': '34',
});

final _mockOfficialPlayedMatch = PublicLiveMatchSummary.fromMap({
  'match_id': '00000000-0000-0000-0000-000000000010',
  'program_name': 'U18 İstanbul Futbol Ligi',
  'sport_code': 'futbol',
  'city_code': '34',
  'status': 'played',
  'home_club_name': 'Galata SK',
  'away_club_name': 'Beyoğlu Gençlik',
  'home_score': 3,
  'away_score': 1,
  'is_live': false,
  'is_today': true,
  'result_version': 1,
  'revision_reason': 'Resmi sonuç tescil edildi',
});

final _mockRevisedPlayedMatch = PublicLiveMatchSummary.fromMap({
  'match_id': '00000000-0000-0000-0000-000000000020',
  'program_name': 'U18 İstanbul Futbol Ligi',
  'sport_code': 'futbol',
  'city_code': '34',
  'status': 'played',
  'home_club_name': 'Anadolu Hisarı İdman',
  'away_club_name': 'Sarıyer GSK',
  'home_score': 0,
  'away_score': 3,
  'is_live': false,
  'is_today': true,
  'result_version': 2,
  'revision_reason': 'Resmi sonuç güncellendi',
});

final _mockPendingMatch = FederationPendingMatch(
  id: '00000000-0000-0000-0000-000000000030',
  name: 'U16 İstanbul Basketbol Ligi',
  sportCode: 'basketbol',
  version: 0,
  homeName: 'Fenerbahçe Koleji',
  awayName: 'Darüşşafaka Akademi',
  startsAt: DateTime(2026, 10, 19, 14, 0),
  location: 'Ayhan Şahenk Spor Salonu',
);

final _mockStandingsRow = LeagueStandingsRow(
  rank: 1,
  participantId: 'part-1',
  name: 'Kadıköy SK',
  played: 10,
  won: 8,
  drawn: 1,
  lost: 1,
  goalsFor: 720,
  goalsAgainst: 650,
  goalDiff: 70,
  points: 25,
  form: ['W', 'W', 'D', 'W', 'L'],
);

final _mockDisciplinaryItem = FederationDisciplinaryItem(
  id: '00000000-0000-0000-0000-000000000040',
  matchId: '00000000-0000-0000-0000-000000000001',
  sportCode: 'basketbol',
  clubName: 'Kadıköy SK',
  athleteDisplay: 'Sporcu (#A3F91C)',
  penaltyType: 'match_ban',
  penaltyLabel: '2 Maç Men',
  reason: 'Sportmenlik dışı kural ihlali nedeniyle tedbirli ceza',
  createdAt: DateTime(2026, 10, 19, 11, 0),
  matchTitle: 'Kadıköy SK – Beşiktaş Akademi',
  programName: 'U16 İstanbul Basketbol Ligi',
);

final _mockRightsBanItem = FederationDisciplinaryItem(
  id: '00000000-0000-0000-0000-000000000041',
  matchId: '00000000-0000-0000-0000-000000000001',
  sportCode: 'futbol',
  clubName: 'Galata SK',
  athleteDisplay: 'Ahmet Yılmaz',
  penaltyType: 'rights_ban',
  penaltyLabel: '3 Ay Hak Mahrumiyeti',
  reason: 'Müsabaka hakemine yönelik ağır hakaret',
  createdAt: DateTime(2026, 10, 18, 15, 30),
  matchTitle: 'Galata SK – Beyoğlu Gençlik',
  programName: 'U18 İstanbul Futbol Ligi',
);

final _mockNoticeItem = FederationNoticeItem(
  id: '00000000-0000-0000-0000-000000000050',
  sportCode: 'basketbol',
  noticeType: 'match_postponed',
  title: 'Müsabaka Erteleme: Fenerbahçe Koleji – Darüşşafaka Akademi',
  body: 'Saha zemini bakım çalışması nedeniyle ileri bir tarihe ertelenmiştir.',
  publishedAt: DateTime(2026, 10, 19, 9, 0),
  programName: 'U16 İstanbul Basketbol Ligi',
  matchId: '00000000-0000-0000-0000-000000000001',
);

Future<void> pumpFederationCenter(
  WidgetTester tester, {
  SwanAccess access = SwanAccess.none,
  FederationCenterOverview? overview,
  Object? error,
  double textScale = 1.0,
  bool liveMatchHubEnabled = true,
  bool leagueStandingsEnabled = true,
  bool federationBulletinEnabled = true,
  bool liveMatchNotificationsEnabled = false,
  bool isFollowed = false,
  List<FederationPendingMatch>? pendingMatches,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        swanAccessProvider.overrideWithValue(access),
        isSupabaseEnabledProvider.overrideWithValue(true),
        featureEnabledProvider(FeatureFlags.liveMatchHub)
            .overrideWithValue(liveMatchHubEnabled),
        featureEnabledProvider(FeatureFlags.leagueStandings)
            .overrideWithValue(leagueStandingsEnabled),
        featureEnabledProvider(FeatureFlags.federationBulletin)
            .overrideWithValue(federationBulletinEnabled),
        featureEnabledProvider(FeatureFlags.liveMatchNotifications)
            .overrideWithValue(liveMatchNotificationsEnabled),
        matchFollowStateProvider(_mockTodayMatch.matchId).overrideWith(
          (ref) async => MatchFollowState(
            matchId: _mockTodayMatch.matchId,
            isFollowed: isFollowed,
          ),
        ),
        isMatchFollowedProvider(_mockTodayMatch.matchId)
            .overrideWith((ref) async => isFollowed),
        matchFollowStateProvider(_mockActivity.id).overrideWith(
          (ref) async => MatchFollowState(
            matchId: _mockActivity.id,
            isFollowed: isFollowed,
          ),
        ),
        isMatchFollowedProvider(_mockActivity.id)
            .overrideWith((ref) async => isFollowed),
        leagueStandingsProvider
            .overrideWith((ref, arg) async => [_mockStandingsRow]),
        federationPendingResultsProvider.overrideWith(
            (ref, offset) async => pendingMatches ?? [_mockPendingMatch]),
        federationCenterOverviewProvider.overrideWith((ref, filter) {
          if (error != null) throw error;
          return overview ??
              FederationCenterOverview(
                todayMatches: [_mockTodayMatch],
                liveMatches: [_mockTodayMatch],
                upcomingActivities: [_mockActivity],
                leagues: [_mockLeague],
                disciplinaryDecisions: [
                  _mockDisciplinaryItem,
                  _mockRightsBanItem,
                ],
                notices: [_mockNoticeItem],
              );
        }),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const FederationCenterScreen(),
        routes: {
          '/canli-mac/00000000-0000-0000-0000-000000000001': (_) =>
              const Scaffold(body: Text('Canli Mac Ekrani')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Federasyon Yayın Merkezi (Faz 1) Testleri', () {
    testWidgets('Header hero, sekmeler ve bugünün canlı maç kartı görüntülenir',
        (tester) async {
      await pumpFederationCenter(tester);

      expect(find.text('Resmi Müsabaka & Yayın Platformu'), findsOneWidget);
      expect(find.text('Bugün & Canlı'), findsOneWidget);
      expect(find.text('Fikstür & Takvim'), findsOneWidget);
      expect(find.text('Puan Durumu'), findsOneWidget);
      expect(find.text('Disiplin & Bülten'), findsOneWidget);

      expect(find.text('U16 İstanbul Basketbol Ligi'), findsOneWidget);
      expect(find.text('Kadıköy SK'), findsOneWidget);
      expect(find.text('Beşiktaş Akademi'), findsOneWidget);
      expect(find.text('68 : 64'), findsOneWidget);
    });

    testWidgets('Sekme geçişi fikstür ve puan tablosunu listeler',
        (tester) async {
      await pumpFederationCenter(tester);

      // Fikstür & Takvim sekmesine tıkla
      await tester.tap(find.text('Fikstür & Takvim'));
      await tester.pumpAndSettle();

      expect(find.text('Türkiye Gençler Şampiyonası'), findsOneWidget);
      expect(
        find.textContaining('Türkiye Basketbol Federasyonu'),
        findsOneWidget,
      );

      // Puan Durumu sekmesine tıkla
      await tester.tap(find.text('Puan Durumu'));
      await tester.pumpAndSettle();

      expect(find.text('Gelişim Ligi A Grubu'), findsOneWidget);
      expect(find.textContaining('BASKETBOL'), findsOneWidget);

      // Lige dokunarak ayrıntı puan tablosunu aç
      await tester.tap(find.text('Gelişim Ligi A Grubu'));
      await tester.pumpAndSettle();

      expect(find.byType(LeagueStandingsView), findsOneWidget);
      expect(find.text('Resmi Sonuçlar'), findsOneWidget);
    });

    testWidgets('Maç kartına tıklandığında maç detay sayfasına yönlendirir',
        (tester) async {
      await pumpFederationCenter(tester);

      await tester.ensureVisible(find.text('Kadıköy SK'));
      await tester.tap(find.text('Kadıköy SK'));
      await tester.pumpAndSettle();

      expect(find.text('Canli Mac Ekrani'), findsOneWidget);
    });

    testWidgets('Boş durumda açıklayıcı metinler gösterilir', (tester) async {
      await pumpFederationCenter(
        tester,
        overview: const FederationCenterOverview(
          todayMatches: [],
          liveMatches: [],
          upcomingActivities: [],
          leagues: [],
        ),
      );

      expect(
        find.text('Bugün için planlanmış resmi maç bulunamadı'),
        findsOneWidget,
      );

      await tester.tap(find.text('Fikstür & Takvim'));
      await tester.pumpAndSettle();
      expect(
        find.text('Filtrelere uygun resmi faaliyet bulunamadı'),
        findsOneWidget,
      );

      await tester.tap(find.text('Puan Durumu'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kayıtlı resmi lig puan tablosu bulunamadı'),
        findsOneWidget,
      );
    });

    testWidgets('Hata durumunda premiumError ve Tekrar Dene butonu çalışır',
        (tester) async {
      var retried = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(SwanAccess.none),
            isSupabaseEnabledProvider.overrideWithValue(true),
            featureEnabledProvider(FeatureFlags.liveMatchHub)
                .overrideWithValue(true),
            featureEnabledProvider(FeatureFlags.leagueStandings)
                .overrideWithValue(true),
            federationCenterOverviewProvider.overrideWith((ref, filter) {
              if (!retried) throw Exception('Sunucu yanıt vermedi timed out');
              return FederationCenterOverview(
                todayMatches: [_mockTodayMatch],
                liveMatches: [_mockTodayMatch],
                upcomingActivities: [_mockActivity],
                leagues: [_mockLeague],
              );
            }),
          ],
          child: const MaterialApp(
            home: FederationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Veri yüklenemedi'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);

      retried = true;
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();

      expect(find.text('U16 İstanbul Basketbol Ligi'), findsOneWidget);
    });

    testWidgets('Aktif federasyon rolü yetkili rozetini gösterir',
        (tester) async {
      final fedAccess = SwanAccess(
        isPlatformAdmin: false,
        clubRole: null,
        coachLevel: 0,
        athleteKind: null,
        federationRoles: [
          FederationRole(
            id: 'role-1',
            federationId: 'fed-1',
            profileId: 'test-profile-1',
            role: FederationRoleKind.president,
            startsOn: DateTime(2020, 1, 1),
            endsOn: DateTime(2030, 12, 31),
          ),
        ],
      );

      await pumpFederationCenter(tester, access: fedAccess);

      expect(find.text('Federasyon / MHK Görev Yetkisi Aktif'), findsOneWidget);
    });

    testWidgets(
        'kapalı özellikler canlı skor veya puan tablosu varmış gibi gösterilmez',
        (tester) async {
      await pumpFederationCenter(
        tester,
        liveMatchHubEnabled: false,
        leagueStandingsEnabled: false,
        overview: const FederationCenterOverview(
          todayMatches: [],
          liveMatches: [],
          upcomingActivities: [],
          leagues: [],
        ),
      );

      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Bugün & Canlı'), findsNothing);
      expect(
        find.text('Bugünün canlı skorları henüz kullanıma açılmadı'),
        findsOneWidget,
      );

      await tester.tap(find.text('Puan Durumu'));
      await tester.pumpAndSettle();
      expect(
        find.text('Puan durumu henüz kullanıma açılmadı.'),
        findsOneWidget,
      );
    });

    testWidgets('disiplin bülteni bayrağı kapalıyken sekme gösterilmez',
        (tester) async {
      await pumpFederationCenter(
        tester,
        federationBulletinEnabled: false,
      );

      expect(find.text('Disiplin & Bülten'), findsNothing);
    });

    testWidgets(
        '320px ve 375px dar ekranda 1.6x metin ölçeğinde sıfır RenderFlex overflow',
        (tester) async {
      for (final width in [320.0, 375.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;

        await pumpFederationCenter(tester, textScale: 1.6);
        expect(tester.takeException(), isNull);

        final fiksturTab = find.text('Fikstür & Takvim');
        if (fiksturTab.evaluate().isNotEmpty) {
          await tester.ensureVisible(fiksturTab);
          await tester.tap(fiksturTab);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);

        final puanTab = find.text('Puan Durumu');
        if (puanTab.evaluate().isNotEmpty) {
          await tester.ensureVisible(puanTab);
          await tester.tap(puanTab);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
        'Tescilli ve revize edilmiş müsabaka sonuçları rozet ve gerekçeyle gösterilir',
        (tester) async {
      await pumpFederationCenter(
        tester,
        overview: FederationCenterOverview(
          todayMatches: [_mockOfficialPlayedMatch, _mockRevisedPlayedMatch],
          liveMatches: const [],
          upcomingActivities: const [],
          leagues: const [],
        ),
      );

      // Tescilli sonuç kartı (V1)
      expect(find.text('✓ TESCİLLİ SONUÇ'), findsOneWidget);
      expect(find.text('Galata SK'), findsOneWidget);
      expect(find.text('Beyoğlu Gençlik'), findsOneWidget);
      expect(find.text('3 : 1'), findsOneWidget);
      expect(find.text('Resmi sonuç tescil edildi'), findsOneWidget);

      // Revize sonuç kartı (V2)
      expect(find.text('● REVİZE SONUÇ (V2)'), findsOneWidget);
      expect(find.text('Anadolu Hisarı İdman'), findsOneWidget);
      expect(find.text('Sarıyer GSK'), findsOneWidget);
      expect(find.text('0 : 3'), findsOneWidget);
      expect(find.text('Resmi sonuç güncellendi'), findsOneWidget);
    });

    testWidgets(
        'Yetkili kullanıcı Bekleyen Sonuçlar butonuna dokununca tescil modalı açılır',
        (tester) async {
      final fedAccess = const SwanAccess(
        isPlatformAdmin: true,
        clubRole: null,
        coachLevel: 0,
        athleteKind: null,
      );

      await pumpFederationCenter(tester, access: fedAccess);

      expect(find.text('Bekleyen Sonuçlar'), findsOneWidget);
      await tester.tap(find.text('Bekleyen Sonuçlar'));
      await tester.pumpAndSettle();

      expect(find.text('Bekleyen Resmi Sonuçlar'), findsOneWidget);
      expect(
          find.text('Fenerbahçe Koleji — Darüşşafaka Akademi'), findsOneWidget);
      expect(find.text('V0 Tescil'), findsOneWidget);
      expect(find.text('Sonucu Tescil Et / Yayımla'), findsOneWidget);

      await tester.ensureVisible(find.text('Sonucu Tescil Et / Yayımla'));
      await tester.tap(find.text('Sonucu Tescil Et / Yayımla'));
      await tester.pumpAndSettle();

      expect(find.text('Resmi Sonuç Tescili (V1)'), findsOneWidget);
      expect(find.text('Skor Girişi (Basketbol)'), findsOneWidget);
    });

    testWidgets(
        'Sonuç yayıncısı olmayan federasyon rolü bekleyen sonuçlara erişemez',
        (tester) async {
      final fedAccess = SwanAccess(
        isPlatformAdmin: false,
        clubRole: null,
        coachLevel: 0,
        athleteKind: null,
        federationRoles: [
          FederationRole(
            id: 'role-1',
            federationId: 'fed-1',
            profileId: 'test-profile-1',
            role: FederationRoleKind.president,
            startsOn: DateTime(2020, 1, 1),
            endsOn: DateTime(2030, 12, 31),
          ),
        ],
      );

      await pumpFederationCenter(tester, access: fedAccess);

      expect(find.text('Federasyon / MHK Görev Yetkisi Aktif'), findsOneWidget);
      expect(find.text('Bekleyen Sonuçlar'), findsNothing);
    });

    testWidgets(
        'Tenis müsabakası için set bazlı tescil formu açılır ve dinamik set eklenebilir',
        (tester) async {
      final tennisPending = const FederationPendingMatch(
        id: 'tennis-match-1',
        name: 'İstanbul Veteranlar Tenis Turnuvası',
        sportCode: 'tenis',
        version: 0,
        homeName: 'Enka SK',
        awayName: 'TED Kulübü',
      );

      await pumpFederationCenter(
        tester,
        access: const SwanAccess(
          isPlatformAdmin: true,
          clubRole: null,
          coachLevel: 0,
          athleteKind: null,
        ),
        pendingMatches: [tennisPending],
      );

      await tester.tap(find.text('Bekleyen Sonuçlar'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Sonucu Tescil Et / Yayımla'));
      await tester.tap(find.text('Sonucu Tescil Et / Yayımla'));
      await tester.pumpAndSettle();

      expect(find.text('Set Skorları (Tenis)'), findsOneWidget);
      expect(find.text('1. Set'), findsOneWidget);
      expect(find.text('2. Set'), findsOneWidget);
      expect(find.text('Set Ekle'), findsOneWidget);

      await tester.tap(find.text('Set Ekle'));
      await tester.pumpAndSettle();

      expect(find.text('3. Set'), findsOneWidget);
      expect(find.text('Set Kaldır'), findsOneWidget);
    });

    testWidgets(
        'Yüzme gibi bireysel branşlarda masaüstü konsol zorunluluğu uyarısı gösterilir',
        (tester) async {
      final swimPending = const FederationPendingMatch(
        id: 'swim-match-1',
        name: 'Kulüplerarası Yıldızlar Yüzme Şampiyonası',
        sportCode: 'yuzme',
        version: 0,
        homeName: 'Fenerbahçe',
        awayName: 'Galatasaray',
      );

      await pumpFederationCenter(
        tester,
        access: const SwanAccess(
          isPlatformAdmin: true,
          clubRole: null,
          coachLevel: 0,
          athleteKind: null,
        ),
        pendingMatches: [swimPending],
      );

      await tester.tap(find.text('Bekleyen Sonuçlar'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Sonucu Tescil Et / Yayımla'));
      await tester.tap(find.text('Sonucu Tescil Et / Yayımla'));
      await tester.pumpAndSettle();

      expect(find.text('Masaüstü Konsolu Gerekli'), findsOneWidget);
      expect(
        find.text(
            'Yüzme branşında resmi sonuçlar seri, kulvar ve sporcu dereceleri gerektirir.'),
        findsOneWidget,
      );
      expect(find.text('Anladım'), findsOneWidget);
      expect(find.text('Tescil Et'), findsNothing);
    });

    test('kamusal revizyon akışı operatörün serbest gerekçesini döndürmez', () {
      final root = Directory.current.parent.parent.path;
      final sql = File(
              '$root/supabase/migrations/0127_public_result_reason_redaction.sql')
          .readAsStringSync();

      expect(sql.contains('public._public_result_revision_label(r.version)'),
          isTrue);
      expect(sql.contains('r.reason'), isFalse);
    });

    testWidgets(
        'Disiplin & Bülten sekmesinde ceza kararları, gerekçe ve gizli sporcu referansı (#...) gösterilir',
        (tester) async {
      await pumpFederationCenter(tester);

      await tester.tap(find.text('Disiplin & Bülten'));
      await tester.pumpAndSettle();

      expect(find.text('Resmi Disiplin Kararları (2)'), findsOneWidget);
      expect(find.text('2 Maç Men'), findsOneWidget);
      expect(find.text('3 Ay Hak Mahrumiyeti'), findsOneWidget);
      expect(find.text('Kadıköy SK'), findsOneWidget);
      expect(find.textContaining('#A3F91C'), findsOneWidget);
      expect(find.text('Galata SK'), findsOneWidget);
      expect(find.textContaining('Ahmet Yılmaz'), findsOneWidget);
      expect(
        find.text('Sportmenlik dışı kural ihlali nedeniyle tedbirli ceza'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Fenerbahçe Koleji'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Müsabaka Erteleme: Fenerbahçe Koleji – Darüşşafaka Akademi'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Disiplin bülteninde alt filtre seçimi (Disiplin, Duyurular) kartları doğru filtreler',
        (tester) async {
      await pumpFederationCenter(tester);

      await tester.tap(find.text('Disiplin & Bülten'));
      await tester.pumpAndSettle();

      // Disiplin filtresine bas
      await tester.tap(find.text('Disiplin (2)'));
      await tester.pumpAndSettle();

      expect(find.text('2 Maç Men'), findsOneWidget);
      expect(
        find.text('Müsabaka Erteleme: Fenerbahçe Koleji – Darüşşafaka Akademi'),
        findsNothing,
      );

      // Duyurular filtresine bas
      await tester.tap(find.text('Duyurular (1)'));
      await tester.pumpAndSettle();

      expect(find.text('2 Maç Men'), findsNothing);
      expect(
        find.text('Müsabaka Erteleme: Fenerbahçe Koleji – Darüşşafaka Akademi'),
        findsOneWidget,
      );
    });

    test('kamusal disiplin bülteni yalnız yayımlanmış özetleri döndürür', () {
      final root = Directory.current.parent.parent.path;
      final sql = File(
              '$root/supabase/migrations/0129_federation_bulletin_publication_contract.sql')
          .readAsStringSync();

      expect(sql.contains('public.athlete_ref(d.athlete_id)'), isTrue);
      expect(sql.contains('b.public_summary'), isTrue);
      expect(sql.contains('federation_disciplinary_bulletins'), isTrue);
      expect(sql.contains('federation_match_notices'), isTrue);
      expect(sql.contains("'federation_bulletin'"), isTrue);
      expect(sql.contains('public_federation_disciplinary_bulletin'), isTrue);
      expect(sql.contains('public_federation_notices'), isTrue);
      expect(sql.contains('athlete_publicity'), isTrue);
    });

    testWidgets(
        'liveMatchNotifications kapalıyken Bugün & Canlı ve Fikstür sekmelerinde takip butonu gösterilmez',
        (tester) async {
      await pumpFederationCenter(tester, liveMatchNotificationsEnabled: false);

      expect(find.byType(MatchFollowButton), findsNothing);

      await tester.tap(find.text('Fikstür & Takvim'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchFollowButton), findsNothing);
    });

    testWidgets(
        'liveMatchNotifications açıkken Bugün & Canlı sekmesindeki maç kartında MatchFollowButton yer alır',
        (tester) async {
      await pumpFederationCenter(tester, liveMatchNotificationsEnabled: true);

      expect(find.byType(MatchFollowButton), findsOneWidget);
      expect(find.text('Bildirimleri Aç'), findsOneWidget);
    });

    testWidgets(
        'liveMatchNotifications açıkken Fikstür & Takvim sekmesindeki müsabakada kompakt MatchFollowButton yer alır',
        (tester) async {
      await pumpFederationCenter(tester, liveMatchNotificationsEnabled: true);

      await tester.tap(find.text('Fikstür & Takvim'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchFollowButton), findsOneWidget);
      expect(find.byTooltip('Bildirimleri Aç'), findsOneWidget);
    });

    test('0130 müsabaka duyurusu iptal ve erteleme bildirim sözleşmesi denetimi', () {
      final root = Directory.current.parent.parent.path;
      final sql = File(
              '$root/supabase/migrations/0130_federation_notice_notifications.sql')
          .readAsStringSync();

      expect(sql.contains('trg_notify_federation_match_notice'), isTrue);
      expect(sql.contains('_notify_federation_match_notice'), isTrue);
      expect(sql.contains('_send_match_follow_notice'), isTrue);
      expect(sql.contains('match_cancelled'), isTrue);
      expect(sql.contains('match_postponed'), isTrue);
      expect(sql.contains('müsabakası federasyon tarafından iptal edildi'), isTrue);
      expect(sql.contains('müsabakası federasyon tarafından ertelendi'), isTrue);
      expect(sql.contains("'cancelled','postponed'"), isTrue);
    });
  });
}
