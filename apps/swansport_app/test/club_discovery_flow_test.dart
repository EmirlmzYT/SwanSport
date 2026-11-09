import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/clubs/presentation/club_apply_button.dart';
import 'package:swansport_app/features/network/presentation/discover_screen.dart';
import 'package:swansport_app/features/social/presentation/profile_screen.dart';
import 'package:swansport_data/swansport_data.dart';

const _clubId = 'club-meram';

class _FailingApplications extends Fake implements ClubApplicationService {
  @override
  Future<void> apply(
    String clubId, {
    String role = 'athlete',
    String? message,
  }) async {
    throw Exception('network unavailable');
  }
}

const _club = DiscoveredClub(
  id: _clubId,
  name: 'Meram Gençlik ve Çok Branşlı Spor Kulübü',
  athleteCount: 86,
  coachCount: 7,
  isVerified: true,
  isFollowing: false,
  city: 'Konya',
  district: 'Meram',
  sportName: 'Tenis',
);

const _profile = SocialProfile(
  id: _clubId,
  name: 'Meram Gençlik Spor Kulübü',
  isClub: true,
  username: 'meramgenclik',
  bio:
      'Çocuklar ve yetişkinler için tenis eğitimleri, takım çalışmaları ve yerel turnuva programları sunuyoruz.',
  roleLabel: 'Meram, Konya',
  primarySport: 'Tenis',
  postCount: 18,
  followerCount: 940,
  followingCount: 42,
);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('Sora')
          ..addFont(rootBundle.load('assets/fonts/Sora-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Sora-Bold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Sora-ExtraBold.ttf')))
        .load();
    await (FontLoader('PlusJakartaSans')
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'))
          ..addFont(
              rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'))
          ..addFont(
              rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf')))
        .load();
  });

  testWidgets('filtreli kulüp listesi ve geri dönüş durumu korunur',
      (tester) async {
    final boundary = GlobalKey();
    await _setSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverClubsProvider.overrideWith((ref, filter) async => [_club]),
          filterOptionsProvider.overrideWith(
            (ref) async => const [
              FilterOption(
                kind: 'sport',
                code: 'tennis',
                label: 'Tenis',
                count: 1,
              ),
            ],
          ),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routes: {
              '/kulup-profil': (_) => const Scaffold(
                    body: Center(child: Text('KULÜP DETAYI')),
                  ),
            },
            home: const DiscoverScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Meram');
    await tester.tap(find.text('Filtreler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenis').last);
    await tester.tap(find.text('Sonuçları göster'));
    await tester.pumpAndSettle();

    expect(find.text('Filtreler (1)'), findsOneWidget);
    expect(
        find.text('Meram Gençlik ve Çok Branşlı Spor Kulübü'), findsOneWidget);
    expect(find.text('Tenis · Meram, Konya'), findsOneWidget);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/clubs-list-mobile.png'),
    );

    await tester.tap(find.text('Meram Gençlik ve Çok Branşlı Spor Kulübü'));
    await tester.pumpAndSettle();
    expect(find.text('KULÜP DETAYI'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Meram'), findsOneWidget);
    expect(find.text('Filtreler (1)'), findsOneWidget);
  });

  testWidgets('başvuruya uygun kulüp profilinde üyelik ana eylemdir',
      (tester) async {
    final boundary = GlobalKey();
    await _pumpProfile(tester, boundary, const []);
    expect(find.text('Üyelik başvurusu yap'), findsOneWidget);
    expect(find.text('Takip et'), findsOneWidget);
    expect(find.text('Gönderiler'), findsOneWidget);
    expect(find.text('Hakkında'), findsOneWidget);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/club-detail-mobile.png'),
    );
  });

  testWidgets('bekleyen başvuru kesin üyelik gibi gösterilmez', (tester) async {
    final boundary = GlobalKey();
    await _pumpProfile(
      tester,
      boundary,
      [
        ClubApplicationRow(
          id: 'application-1',
          clubId: _clubId,
          profileId: 'visitor',
          desiredRole: 'athlete',
          status: 'pending',
          createdAt: DateTime(2026, 11, 9),
        ),
      ],
    );
    expect(find.text('Başvurun gönderildi · Onay bekliyor'), findsOneWidget);
    expect(find.text('Üyelik başvurusu yap'), findsNothing);
    await tester.runAsync(
      () => _capture(
          boundary, 'build/design-review/club-application-pending.png'),
    );
  });

  testWidgets('mevcut üye tekrar başvuru yapamaz', (tester) async {
    await _pumpProfile(
      tester,
      GlobalKey(),
      const [],
      clubs: const [ClubRef(id: _clubId, name: 'Meram Gençlik Spor Kulübü')],
    );
    expect(find.text('Bu kulübün üyesisin'), findsOneWidget);
    expect(find.text('Üyelik başvurusu yap'), findsNothing);
  });

  testWidgets('gönderim hatasında mesaj korunur ve ikinci gönderim oluşmaz',
      (tester) async {
    await _setSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              hasVerifiedIdentity: true,
            ),
          ),
          myClubsProvider.overrideWith((ref) async => const []),
          myApplicationsProvider.overrideWith((ref) async => const []),
          clubApplicationServiceProvider.overrideWithValue(
            _FailingApplications(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ClubApplyButton(clubId: _clubId, clubName: 'Meram Gençlik'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Üyelik başvurusu yap'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Takıma katılmak istiyorum.');
    await tester.tap(find.text('Başvuruyu gönder'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Başvuru gönderilemedi'), findsOneWidget);
    expect(find.text('Takıma katılmak istiyorum.'), findsOneWidget);
    expect(find.text('Üyelik başvurusu'), findsOneWidget);
  });

  testWidgets('dar büyük yazı ve geniş koyu kulüp profili taşmaz',
      (tester) async {
    await _pumpProfile(
      tester,
      GlobalKey(),
      const [],
      size: const Size(320, 568),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);

    await _pumpProfile(
      tester,
      GlobalKey(),
      const [],
      size: const Size(1440, 900),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpProfile(
  WidgetTester tester,
  GlobalKey boundary,
  List<ClubApplicationRow> applications, {
  List<ClubRef> clubs = const [],
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  await _setSurface(tester, size: size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            hasVerifiedIdentity: true,
          ),
        ),
        clubSocialProfileProvider(_clubId)
            .overrideWith((ref) async => _profile),
        clubPostsProvider(_clubId).overrideWith((ref) async => const []),
        myClubsProvider.overrideWith((ref) async => clubs),
        myApplicationsProvider.overrideWith((ref) async => applications),
        activeClubProvider.overrideWith((ref) async => null),
        myTrainingHistoryProvider.overrideWith((ref) async => const []),
        clubDetailsProvider(_clubId).overrideWith((ref) async => null),
        clubCoachesProvider(_clubId).overrideWith((ref) async => const []),
        clubAchievementsProvider(_clubId).overrideWith((ref) async => const []),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const ProfileScreen(id: _clubId, isClub: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setSurface(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _capture(GlobalKey key, String path) async {
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await Directory(path.substring(0, path.lastIndexOf('/')))
      .create(recursive: true);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}
