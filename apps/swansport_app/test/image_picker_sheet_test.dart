import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/media/image_pick.dart';
import 'package:swansport_app/app/media/image_picker_sheet.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  final first = PickedImage(bytes: bytes, name: 'first.png');
  final second = PickedImage(bytes: bytes, name: 'second.png');

  Future<void> host(
    WidgetTester tester,
    ImageSelectionLoader loader,
    ValueChanged<List<PickedImage>> onResult,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => onResult(await showImagePickerSheet(
                    context,
                    limit: 8,
                    picker: loader,
                  ),),
                  child: const Text('Aç'),
                ),
              ),),
    ),);
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('vazgeçmek seçim başlatmaz ve dosya döndürmez', (tester) async {
    var calls = 0;
    List<PickedImage>? result;
    await host(tester, ({required source, required limit}) async {
      calls++;
      return [first];
    }, (images) => result = images,);
    await tester.tap(find.byTooltip('Vazgeç'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(result, isEmpty);
  });

  testWidgets('izin reddi kullanıcıya açıklanır, seçim kaybolmaz',
      (tester) async {
    List<PickedImage>? result;
    await host(tester, ({required source, required limit}) async {
      throw PlatformException(code: 'photo_access_denied');
    }, (images) => result = images,);
    await tester.tap(find.text('Galeriden seç'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fotoğraf erişimi kapalı'), findsOneWidget);
    expect(find.text('Galeriden seç'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.byTooltip('Vazgeç'));
    await tester.pumpAndSettle();
  });

  testWidgets('sıra değişikliği onaylanan dosya sırasına yansır',
      (tester) async {
    List<PickedImage>? result;
    await host(tester, ({required source, required limit}) async {
      expect(source, ImagePickSource.gallery);
      expect(limit, 8);
      return [first, second];
    }, (images) => result = images,);
    await tester.runAsync(() async {
      await tester.tap(find.text('Galeriden seç'));
      // Native görüntü çözücüsü gerçek event loop'ta tamamlanır.
      for (var i = 0;
          i < 100 && find.text('2 fotoğrafı kullan').evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.byTooltip('Arkaya taşı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 fotoğrafı kullan'));
    await tester.pumpAndSettle();
    expect(result!.map((image) => image.name), ['second.png', 'first.png']);
  });
}
