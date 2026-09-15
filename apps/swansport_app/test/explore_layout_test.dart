import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/network/presentation/explore_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('Keşfet telefon boyutunda içerik ve bağlantıları gösterir',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(SwanAccess.none),
          featureFlagsProvider
              .overrideWith((ref) async => const FeatureFlags.none()),
          unreadNotificationsProvider.overrideWith((ref) async => 0),
          unreadMessagesProvider.overrideWith((ref) async => 0),
          hiddenProfilesProvider.overrideWith((ref) async => <String>{}),
          announcementsProvider.overrideWith(
            (ref) async => [
              AnnouncementRow(
                title: 'Yeni sezon antrenman programı',
                body:
                    'Takım çalışmalarımız pazartesi başlıyor. Programını kulüp takviminden takip edebilirsin.',
                pinned: true,
                createdAt: DateTime(2026, 9, 15),
              ),
            ],
          ),
          suggestionsProvider.overrideWith(
            (ref) async => [
              const SuggestionRow(
                id: 'example-club',
                name: 'Okçuluk Kulübü',
                kind: 'club',
                subtitle: 'Okçuluk • İstanbul',
              ),
            ],
          ),
          discoverProvider.overrideWith(
            (ref) async => [
              PostRow(
                id: 'example-post',
                authorId: 'example-author',
                authorName: 'Spor Kulübü',
                body:
                    'Bugünkü antrenmanımızı tamamladık. Yeni hedeflere birlikte ilerliyoruz.',
                createdAt: DateTime(2026, 9, 15),
              ),
            ],
          ),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ExploreScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    final layoutError = tester.takeException();
    expect(find.text('Öne Çıkan Duyurular'), findsOneWidget);
    expect(find.text('Popüler Sporcular & Antrenörler'), findsOneWidget);
    expect(find.text('Yeni sezon antrenman programı'), findsOneWidget);
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await render.toImage();
      final png = await picture.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/design-review').create(recursive: true);
      await File('build/design-review/explore.png')
          .writeAsBytes(png!.buffer.asUint8List());
      picture.dispose();
    });
    expect(layoutError, isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
