import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/social/presentation/profile_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('kişisel profil sosyal kimliği ve gönderileri öne çıkarır',
      (tester) async {
    final boundary = GlobalKey();
    await _pumpProfile(
      tester,
      const Size(390, 844),
      _personalProfile,
      [_textPost('personal-post', 'Bugünkü yüzme antrenmanından notlar.')],
      boundary: boundary,
    );

    expect(find.text('Deniz Yılmaz'), findsAtLeastNWidgets(1));
    expect(find.text('@denizyilmaz'), findsAtLeastNWidgets(1));
    expect(find.text('Profili Düzenle'), findsOneWidget);
    expect(find.text('Gönderiler'), findsOneWidget);
    expect(find.text('Hakkında'), findsOneWidget);
    expect(find.text('120 cm'), findsNothing);
    expect(find.text('Devamını gör'), findsOneWidget);
    expect(find.text('2 antrenörlük belgesi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () =>
          _capture(boundary, 'build/design-review/profile-personal-mobile.png'),
    );
    await tester.tap(find.text('Hakkında'));
    await tester.pumpAndSettle();
    expect(find.text('Spor bilgileri'), findsOneWidget);
    expect(find.text('Antrenörlük ve belgeler'), findsOneWidget);
    expect(find.text('Açık Su Yüzme · 1. Kademe Antrenör'), findsOneWidget);
  });

  testWidgets('ziyaretçi profili takip mesaj ve güvenlik seçeneklerini korur',
      (tester) async {
    final boundary = GlobalKey();
    await _pumpProfile(
      tester,
      const Size(1440, 900),
      _visitorProfile,
      [_textPost('visitor-post', 'Yeni sezon için hazırlık devam ediyor.')],
      boundary: boundary,
    );

    expect(find.text('Takip et'), findsOneWidget);
    expect(find.text('Mesaj'), findsOneWidget);
    expect(find.byTooltip('Profil seçenekleri'), findsOneWidget);
    expect(find.text('Profili Düzenle'), findsNothing);
    expect(find.text('Tenis · 3. Kademe Antrenör'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/profile-visitor-wide.png'),
    );
  });

  testWidgets('kulüp profili kişisel alanları taşımaz', (tester) async {
    final boundary = GlobalKey();
    await _pumpProfile(
      tester,
      const Size(390, 844),
      _clubProfile,
      [_clubPost],
      isClub: true,
      boundary: boundary,
    );

    expect(find.text('Mavişehir Yüzme Kulübü'), findsAtLeastNWidgets(1));
    expect(find.text('Takip et'), findsOneWidget);
    expect(find.text('Mesaj'), findsNothing);
    expect(find.byTooltip('Profil seçenekleri'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/profile-club-mobile.png'),
    );
  });

  testWidgets('boş biyografi ve 2x metin dar ekranda taşmaz', (tester) async {
    await _pumpProfile(
      tester,
      const Size(320, 568),
      _visitorProfile.copyWithEmptyBio(),
      const [],
      textScale: 2,
    );
    expect(find.text('Henüz bir biyografi eklenmedi.'), findsNothing);
    expect(
      find.text('Bu profilin gönderileri burada görünecek.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('belge özeti panelde kimliğe göre tekilleştirilir',
      (tester) async {
    final boundary = GlobalKey();
    await _pumpProfile(
      tester,
      const Size(320, 700),
      _manyCredentialProfile,
      const [],
      boundary: boundary,
      textScale: 1.6,
    );

    expect(find.text('4 antrenörlük belgesi'), findsOneWidget);
    expect(find.text('Basketbol · 4. Kademe Antrenör'), findsNothing);
    await tester.tap(find.text('4 antrenörlük belgesi'));
    await tester.pumpAndSettle();
    expect(find.text('Antrenörlük ve belgeler'), findsOneWidget);
    expect(find.text('Basketbol · 4. Kademe Antrenör'), findsOneWidget);
    expect(find.text('Onaylandı'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/profile-credentials-mobile.png',
      ),
    );
  });

  testWidgets('sıfır belgede belge bölümü gösterilmez', (tester) async {
    await _pumpProfile(
      tester,
      const Size(390, 844),
      _visitorProfile.copyWithEmptyBio(),
      const [],
    );
    expect(find.textContaining('antrenörlük belgesi'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _personalProfile = SocialProfile(
  id: 'personal',
  name: 'Deniz Yılmaz',
  isClub: false,
  username: 'denizyilmaz',
  isMe: true,
  bio:
      'Yüzmeyi, açık su yarışlarını ve takım arkadaşlarımla yeni hedefler belirlemeyi seviyorum. Her antrenmanda daha iyi bir sporcu ve daha iyi bir takım arkadaşı olmaya çalışıyorum.',
  roleLabel: 'Sporcu',
  primarySport: 'Yüzme',
  position: 'Serbest stil',
  heightCm: 180,
  weightKg: 74,
  dominantSide: 'Sağ',
  postCount: 12,
  followerCount: 248,
  followingCount: 136,
  credentials: ['Lisanslı Sporcu'],
  credentialDetails: [
    SocialCredentialSummary(
      id: 'swim-2',
      kind: 'coach',
      sportName: 'Yüzme',
      coachLevel: 2,
      status: 'approved',
    ),
    SocialCredentialSummary(
      id: 'open-water-1',
      kind: 'coach',
      sportName: 'Açık Su Yüzme',
      coachLevel: 1,
      status: 'approved',
    ),
  ],
  instagram: 'denizyilmaz',
);

const _visitorProfile = SocialProfile(
  id: 'visitor',
  name: 'Çok Uzun İsimli Antrenör Selin Kaya',
  isClub: false,
  username: 'selinkaya',
  bio: 'Yüzme antrenörü ve spor gelişimi eğitmeni.',
  roleLabel: 'Antrenör',
  primarySport: 'Yüzme',
  postCount: 34,
  followerCount: 1520,
  followingCount: 207,
  credentials: ['2. Kademe Antrenör'],
  credentialDetails: [
    SocialCredentialSummary(
      id: 'tennis-3',
      kind: 'coach',
      sportName: 'Tenis',
      coachLevel: 3,
      status: 'approved',
    ),
  ],
);

const _manyCredentialProfile = SocialProfile(
  id: 'many-credentials',
  name: 'Uzun Branş Adlarıyla Çalışan Antrenör',
  isClub: false,
  username: 'cokbranşlıantrenor',
  roleLabel: 'Antrenör · Örnek Spor Kulübü',
  primarySport: 'Dayanıklılık ve Uzun Mesafe Sporları',
  credentialDetails: [
    SocialCredentialSummary(
      id: 'basketball-4',
      kind: 'coach',
      sportName: 'Basketbol',
      coachLevel: 4,
      status: 'approved',
    ),
    SocialCredentialSummary(
      id: 'basketball-4',
      kind: 'coach',
      sportName: 'Basketbol',
      coachLevel: 4,
      status: 'approved',
    ),
    SocialCredentialSummary(
      id: 'athletics-2',
      kind: 'coach',
      sportName: 'Atletizm',
      coachLevel: 2,
      status: 'approved',
    ),
    SocialCredentialSummary(
      id: 'swimming-3',
      kind: 'coach',
      sportName: 'Yüzme',
      coachLevel: 3,
      status: 'approved',
    ),
    SocialCredentialSummary(
      id: 'mountain-running-1',
      kind: 'coach',
      sportName: 'Dağ Koşusu ve Uzun Mesafe Dayanıklılık',
      coachLevel: 1,
      status: 'approved',
    ),
  ],
);

const _clubProfile = SocialProfile(
  id: 'club',
  name: 'Mavişehir Yüzme Kulübü',
  isClub: true,
  username: 'mavisehiryuzme',
  bio: 'Her yaşta sporcuyla yüzme kültürünü büyütüyoruz.',
  roleLabel: 'İzmir',
  postCount: 48,
  followerCount: 2840,
  followingCount: 92,
  credentials: ['Doğrulanmış Kulüp'],
);

final _clubPost = PostRow(
  id: 'club-post',
  body: 'Hafta sonu açık antrenmanımıza tüm sporcular davetlidir.',
  createdAt: DateTime(2026, 11, 1),
  authorId: 'club-author',
  clubId: 'club',
  clubName: 'Mavişehir Yüzme Kulübü',
);

PostRow _textPost(String id, String body) => PostRow(
      id: id,
      body: body,
      createdAt: DateTime(2026, 11, 1),
      authorId: id,
      authorName: 'Deniz Yılmaz',
    );

extension on SocialProfile {
  SocialProfile copyWithEmptyBio() => SocialProfile(
        id: id,
        name: name,
        isClub: isClub,
        username: username,
        roleLabel: roleLabel,
        postCount: postCount,
        followerCount: followerCount,
        followingCount: followingCount,
      );
}

Future<void> _pumpProfile(
  WidgetTester tester,
  Size size,
  SocialProfile profile,
  List<PostRow> posts, {
  bool isClub = false,
  GlobalKey? boundary,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: ProfileScreen(id: profile.id, isClub: isClub),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
          ),
        ),
        if (isClub)
          clubSocialProfileProvider(profile.id)
              .overrideWith((ref) async => profile)
        else
          socialProfileProvider(profile.id)
              .overrideWith((ref) async => profile),
        if (isClub)
          clubPostsProvider(profile.id).overrideWith((ref) async => posts)
        else
          authorPostsProvider(profile.id).overrideWith((ref) async => posts),
        activeClubProvider.overrideWith((ref) async => null),
        myTrainingHistoryProvider.overrideWith((ref) async => const []),
      ],
      child:
          boundary == null ? app : RepaintBoundary(key: boundary, child: app),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
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
