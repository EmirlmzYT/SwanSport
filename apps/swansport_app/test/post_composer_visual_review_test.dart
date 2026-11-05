import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/social/presentation/post_composer_sheet.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('boş oluşturma ekranı görsel inceleme fixture', (tester) async {
    final boundary = GlobalKey();
    await _pumpComposer(tester, boundary);
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/post-composer-empty-current.png',
      ),
    );
    expect(find.text('Yeni gönderi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('klavye açık dar ekran görsel inceleme fixture', (tester) async {
    final boundary = GlobalKey();
    await _pumpComposer(tester, boundary, size: const Size(320, 700));
    await tester.tap(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Bugünkü antrenman');
    await tester.pump();
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/post-composer-keyboard-current.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fotoğraflı taslak görsel inceleme fixture', (tester) async {
    final boundary = GlobalKey();
    await _pumpComposer(
      tester,
      boundary,
      initialMedia: [PickedMedia(bytes: _pngBytes, name: 'antrenman.png')],
    );
    await tester.enterText(
        find.byType(TextField).first, 'Takımla güzel bir antrenman.');
    await tester.pump();
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/post-composer-photo-current.png',
      ),
    );
    expect(find.text('1/8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('geniş koyu görünüm okunabilir genişlikte kalır', (tester) async {
    final boundary = GlobalKey();
    await _pumpComposer(
      tester,
      boundary,
      size: const Size(1440, 900),
      brightness: Brightness.dark,
    );
    final width = tester.getSize(find.byType(PostComposerSheet)).width;
    expect(width, inInclusiveRange(600, 720));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpComposer(
  WidgetTester tester,
  GlobalKey boundary, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  List<PickedMedia> initialMedia = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith(
          (_) async => const ProfileInfo(
            id: 'profile-1',
            fullName: 'Deniz Yılmaz',
          ),
        ),
        activeClubProvider.overrideWith(
          (_) async => const ClubRef(
            id: 'club-1',
            name: 'Mavişehir Gençlik ve Spor Kulübü',
            role: 'coach',
          ),
        ),
        myCredentialsProvider.overrideWith(
          (_) async => const [
            CredentialRow(
              id: 'credential-1',
              kind: 'coach',
              status: 'approved',
              coachLevel: 2,
            ),
          ],
        ),
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: 'coach',
            coachLevel: 2,
            athleteKind: null,
          ),
        ),
      ],
      child: MaterialApp(
        theme:
            brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<bool>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  isDismissible: false,
                  enableDrag: false,
                  builder: (_) => RepaintBoundary(
                    key: boundary,
                    child: PostComposerSheet(initialMedia: initialMedia),
                  ),
                ),
                child: const Text('Oluştur'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Oluştur'));
  await tester.pumpAndSettle();
}

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Future<void> _capture(GlobalKey boundary, String path) async {
  final render = boundary.currentContext!.findRenderObject();
  final image = await (render! as RenderRepaintBoundary).toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}
