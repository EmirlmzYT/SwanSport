import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/social/presentation/widgets/feed_entry.dart';
import 'package:swansport_app/features/social/presentation/widgets/post_card.dart';
import 'package:swansport_app/features/social/presentation/widgets/social_widgets.dart';
import 'package:swansport_data/swansport_data.dart';

bool _isUnavailableAppLinks(Object? error) =>
    error is MissingPluginException &&
    error.message?.contains('com.llfbandit.app_links/events') == true;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('aynı fixture ile mobil akış görsel incelemesi', (tester) async {
    final boundary = GlobalKey();
    await _pumpFeed(tester, const Size(390, 844), boundary);

    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/feed-mobile-current.png'),
    );

    expect(find.text(_longAuthor), findsOneWidget);
    expect(
        find.text('Antrenmandan sonra toparlanma notlarım.'), findsOneWidget);
    expect(find.byType(PostCard), findsNWidgets(2));
    expect(find.byType(RatioImage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Günün Spor Gündemi'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('RESMİ KULÜP DUYURUSU'), findsOneWidget);
    expect(find.text('Günün Spor Gündemi'), findsOneWidget);
    final platformError = tester.takeException();
    expect(
      platformError == null || _isUnavailableAppLinks(platformError),
      isTrue,
    );
  });

  testWidgets('dar ekran ve büyük yazıda kartlar taşmaz', (tester) async {
    await _pumpFeed(
      tester,
      const Size(320, 700),
      GlobalKey(),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('geniş koyu görünüm odaklı akış genişliğini korur',
      (tester) async {
    await _pumpFeed(
      tester,
      const Size(1440, 900),
      GlobalKey(),
      brightness: Brightness.dark,
    );
    expect(tester.getSize(find.byType(PostCard).first).width, 620);
    expect(tester.takeException(), isNull);
  });

  testWidgets('başarısız hızlı etkileşim geri alınır ve sade bildirilir',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialServiceProvider.overrideWithValue(_FailingSocialService()),
          socialShareServiceProvider
              .overrideWithValue(_FailingSocialShareService()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: PostCard(post: _textPost)),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Beğen'));
    await tester.pumpAndSettle();
    expect(
      find.text('Beğeni güncellenemedi. Tekrar deneyin.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Kaydet'));
    await tester.pumpAndSettle();
    expect(
      find.text('Gönderi kaydedilemedi. Tekrar deneyin.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
  });
}

const _longAuthor = 'Mavişehir Gençlik ve Spor Kulübü Antrenörleri Topluluğu';

final _photoPost = PostRow(
  id: 'photo-post',
  authorId: 'coach-1',
  authorName: _longAuthor,
  body:
      'Sabah antrenmanında tempoyu birlikte yükselttik. Takımın emeğine sağlık!',
  imageUrl: 'https://example.invalid/training-photo.jpg',
  createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
  likeCount: 128,
  commentCount: 14,
  likedByMe: true,
);

final _textPost = PostRow(
  id: 'text-post',
  authorId: 'athlete-1',
  authorName: 'Deniz Yılmaz',
  body: 'Antrenmandan sonra toparlanma notlarım.',
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  likeCount: 24,
  commentCount: 3,
);

final _announcement = AnnouncementRow(
  title: 'Hafta sonu tesis programı',
  body: 'Cumartesi antrenman saatleri güncellendi.',
  pinned: true,
  createdAt: DateTime.now().subtract(const Duration(hours: 4)),
);

final _news = List.generate(
  3,
  (index) => NewsItem(
    title: 'Spor gündeminden öne çıkan başlık ${index + 1}',
    sourceName: 'Spor Servisi',
    publishedAt: DateTime.now().subtract(Duration(hours: index + 1)),
    link: 'https://example.com/news/$index',
  ),
);

Future<void> _pumpFeed(
  WidgetTester tester,
  Size size,
  GlobalKey boundary, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeClubProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme:
            brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 652),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                  children: [
                    PostCard(post: _photoPost),
                    PostCard(post: _textPost),
                    AnnouncementCard(
                      item: _announcement,
                      clubName: 'Mavişehir Spor Kulübü',
                    ),
                    NewsCarouselCard(
                      items: _news,
                      title: 'Günün Spor Gündemi',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _capture(GlobalKey key, String path) async {
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
}

class _FailingSocialService extends SocialService {
  _FailingSocialService()
      : super(SupabaseClient(
          'https://example.supabase.co',
          'anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  @override
  Future<void> setLike(String postId, bool liked) =>
      Future<void>.error(StateError('network detail'));
}

class _FailingSocialShareService extends SocialShareService {
  _FailingSocialShareService()
      : super(SupabaseClient(
          'https://example.supabase.co',
          'anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  @override
  Future<bool> toggleSaved(String postId) =>
      Future<bool>.error(StateError('network detail'));
}
