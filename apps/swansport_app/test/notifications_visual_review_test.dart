import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/push/push_service.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/social/presentation/notifications_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  const appLinksEvents = MethodChannel('com.llfbandit.app_links/events');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appLinksEvents, (_) async => null);
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appLinksEvents, null);
  });

  testWidgets('karisik bildirim listesi mobil görsel inceleme', (tester) async {
    final boundary = GlobalKey();
    await _pumpNotifications(tester, boundary: boundary);

    expect(find.textContaining('Ayşe'), findsOneWidget);
    expect(find.textContaining('Kulüp programı'), findsOneWidget);
    expect(find.text('Yeni'), findsNWidgets(2));
    expect(
      find.bySemanticsLabel(RegExp('Okunmamış bildirim.*Ayşe')),
      findsOneWidget,
    );
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/notifications-mobile-current.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('geniş koyu görünüm ve büyük metin taşmaz', (tester) async {
    final boundary = GlobalKey();
    await _pumpNotifications(
      tester,
      boundary: boundary,
      size: const Size(1440, 900),
      brightness: Brightness.dark,
      textScale: 1.6,
    );
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/notifications-wide-dark-current.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpNotifications(
  WidgetTester tester, {
  required GlobalKey boundary,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        categorizedNotificationsProvider.overrideWith(
          (_, __) async => _notifications,
        ),
        unreadNotificationsProvider.overrideWith((_) async => 2),
        pushEnabledProvider.overrideWith((_) async => false),
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
          home: const NotificationsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _notifications = [
  NotificationRow(
    id: 'comment-1',
    kind: 'comment',
    title: 'Ayşe Yılmaz Çok Uzun İsimli Bir Sporcu, gönderine yorum yaptı.',
    body: 'Yarınki antrenmana ben de katılacağım.',
    actorId: 'actor-1',
    actorName: 'Ayşe Yılmaz',
    category: 'sosyal',
    entityType: 'post',
    entityId: 'post-1',
    createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
  ),
  NotificationRow(
    id: 'follow-1',
    kind: 'follow',
    title: 'Mert seni takip etmeye başladı.',
    actorId: 'actor-2',
    actorName: 'Mert Demir',
    category: 'sosyal',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  NotificationRow(
    id: 'announcement-1',
    kind: 'announcement',
    title: 'Kulüp programı güncellendi',
    body: 'Hafta sonu antrenman saatlerini kontrol et.',
    entityType: 'announcement',
    entityId: 'announcement-1',
    category: 'kulup',
    readAt: DateTime.now().subtract(const Duration(hours: 2)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  NotificationRow(
    id: 'system-1',
    kind: 'document_expiry',
    title: 'Belgenin geçerlilik süresi yaklaşıyor',
    body: 'Belgeler alanından ayrıntıları inceleyebilirsin.',
    category: 'kritik',
    readAt: DateTime.now().subtract(const Duration(days: 1)),
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
];

Future<void> _capture(GlobalKey key, String path) async {
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
}
