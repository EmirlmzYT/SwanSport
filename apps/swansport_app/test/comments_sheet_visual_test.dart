import 'dart:async';
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
import 'package:swansport_app/features/social/presentation/comments_sheet.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('yorum paneli yerel konuşma fixture görünümü', (tester) async {
    final service = _FixtureCommentService(_threadedComments);
    final boundary = GlobalKey();
    await _openSheet(tester, service, const Size(390, 844), boundary: boundary);

    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/comments-mobile-current.png',
      ),
    );

    expect(find.text('Yorumlar'), findsOneWidget);
    expect(
      find.textContaining('Mavişehir Gençlik'),
      findsAtLeastNWidgets(1),
    );
    expect(find.textContaining('Bugünkü antrenmanda'), findsOneWidget);
    expect(find.text('Yanıtla'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dar ekran büyük yazı ve klavye paneli taşırmaz', (tester) async {
    final service = _FixtureCommentService(_threadedComments);
    final boundary = GlobalKey();
    await _openSheet(
      tester,
      service,
      const Size(320, 700),
      boundary: boundary,
      textScale: 1.6,
      keyboard: 260,
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/comments-keyboard-mobile.png',
      ),
    );
  });

  testWidgets('boş liste sohbet başlatma dilini korur', (tester) async {
    await _openSheet(
      tester,
      _FixtureCommentService(const []),
      const Size(390, 844),
    );
    expect(find.text('Henüz yorum yok'), findsOneWidget);
    expect(find.text('İlk yorumu sen yaz.'), findsOneWidget);
  });

  testWidgets('gönderim anındaki metin ve yanıt hedefi sabitlenir',
      (tester) async {
    final service = _FixtureCommentService(_threadedComments)
      ..addGate = Completer<void>();
    await _openSheet(tester, service, const Size(390, 844));
    await tester.tap(find.text('Yanıtla').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Gönderilecek yanıt');
    await tester.tap(find.byTooltip('Yorumu gönder'));
    await tester.pump();
    await tester.tap(find.byTooltip('Yorumu gönder'));
    await tester.pump();

    expect(service.addCalls, hasLength(1));
    expect(service.addCalls.single.body, 'Gönderilecek yanıt');
    expect(service.addCalls.single.parentId, 'root-1');
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.text = 'Bu yeni taslak korunmalı';
    service.addGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Bu yeni taslak korunmalı'), findsOneWidget);
    expect(find.textContaining('kişisine yanıt'), findsAtLeastNWidgets(1));
  });

  testWidgets('başarısız gönderim taslağı ve yanıt hedefini korur',
      (tester) async {
    final service = _FixtureCommentService(_threadedComments)
      ..addFailure = StateError('technical detail');
    await _openSheet(tester, service, const Size(390, 844));
    await tester.tap(find.text('Yanıtla').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Kaybolmaması gereken yanıt');
    await tester.pump();
    await tester.tap(find.byTooltip('Yorumu gönder'));
    await tester.pumpAndSettle();

    expect(service.addCalls, hasLength(1));
    expect(find.text('Kaybolmaması gereken yanıt'), findsOneWidget);
    expect(
      find.text('$_longName kişisine yanıt'),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.text('Yorum gönderilemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .join(' | '),
    );
    expect(find.textContaining('technical detail'), findsNothing);
  });

  testWidgets('enter yeni satır davranışıdır ve yorum göndermez',
      (tester) async {
    final service = _FixtureCommentService(const []);
    await _openSheet(tester, service, const Size(390, 844));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.newline);
    expect(field.keyboardType, TextInputType.multiline);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'İlk satır');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
    expect(service.addCalls, isEmpty);
  });

  testWidgets('geniş koyu görünümde panel okunabilir genişlikte kalır',
      (tester) async {
    await _openSheet(
      tester,
      _FixtureCommentService(_threadedComments),
      const Size(1440, 900),
      brightness: Brightness.dark,
    );
    expect(tester.getSize(find.byKey(const Key('comments-sheet'))).width, 640);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kapat düğmesi ve geri hareketi paneli kapatır', (tester) async {
    final service = _FixtureCommentService(_threadedComments);
    await _openSheet(tester, service, const Size(390, 844));
    await tester.tap(find.byTooltip('Yorumları kapat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comments-sheet')), findsNothing);

    await tester.tap(find.text('Yorumları aç'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comments-sheet')), findsNothing);

    await tester.tap(find.text('Yorumları aç'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('comments-drag-handle')),
      const Offset(0, 700),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comments-sheet')), findsNothing);
  });
}

const _longName = 'Mavişehir Gençlik ve Spor Kulübü Başantrenörü Selin Kaya';
const _longComment =
    'Bugünkü antrenmanda son sete kadar temponuzu korumanız harikaydı. '
    'Bir sonraki çalışmada dönüş tekniğine biraz daha odaklanalım.';

final _threadedComments = [
  CommentRow(
    id: 'root-1',
    body: _longComment,
    createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    profileId: 'coach-1',
    authorName: _longName,
  ),
  CommentRow(
    id: 'reply-1',
    body: 'Teşekkürler hocam, dönüşleri tekrar edeceğim.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
    profileId: 'athlete-1',
    parentCommentId: 'root-1',
    authorName: 'Deniz Yılmaz',
  ),
  CommentRow(
    id: 'reply-2',
    body: 'Video kaydını da antrenman sonrası paylaşırım.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    profileId: 'coach-2',
    parentCommentId: 'reply-1',
    authorName: 'Emre Antrenör',
  ),
  CommentRow(
    id: 'orphan',
    body: 'Silinen bir yanıtın devamı da kaybolmamalı.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
    profileId: 'athlete-2',
    parentCommentId: 'missing-parent',
    authorName: 'Ayşe Demir',
  ),
];

Future<void> _openSheet(
  WidgetTester tester,
  _FixtureCommentService service,
  Size size, {
  GlobalKey? boundary,
  double textScale = 1,
  double keyboard = 0,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => showCommentsSheet(context, 'post-1'),
            child: const Text('Yorumları aç'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isSupabaseEnabledProvider.overrideWithValue(true),
        socialServiceProvider.overrideWithValue(service),
      ],
      child:
          boundary == null ? app : RepaintBoundary(key: boundary, child: app),
    ),
  );
  await tester.tap(find.text('Yorumları aç'));
  await tester.pumpAndSettle();
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

class _FixtureCommentService extends SocialService {
  _FixtureCommentService(List<CommentRow> initial)
      : rows = [...initial],
        super(SupabaseClient(
          'https://example.supabase.co',
          'anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  List<CommentRow> rows;
  Completer<void>? addGate;
  Object? addFailure;
  final addCalls = <({String body, String? parentId})>[];

  @override
  Future<List<CommentRow>> comments(String postId) async => [...rows];

  @override
  Future<void> addComment(
    String postId,
    String body, {
    String? parentCommentId,
  }) async {
    addCalls.add((body: body, parentId: parentCommentId));
    if (addGate != null) await addGate!.future;
    if (addFailure != null) throw addFailure!;
    rows.add(CommentRow(
      id: 'new-${rows.length}',
      body: body,
      createdAt: DateTime.now(),
      profileId: 'current-user',
      parentCommentId: parentCommentId,
      authorName: 'Test Kullanıcısı',
    ));
  }

  @override
  Future<void> deleteComment(String id) async {
    rows.removeWhere((comment) => comment.id == id);
  }
}
