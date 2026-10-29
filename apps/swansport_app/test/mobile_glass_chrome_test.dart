import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/design/swan_chrome.dart';
import 'package:swansport_app/app/design/swan_palette.dart';
import 'package:swansport_app/app/design/swan_shape.dart';
import 'package:swansport_app/app/design/swan_type.dart';
import 'package:swansport_app/app/widgets/swan_bottom_nav.dart';
import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_app/app/widgets/scroll_chrome.dart';
import 'package:swansport_app/features/social/presentation/widgets/stitch_feed_widgets.dart';
import 'package:swansport_data/swansport_data.dart';

Widget host(
        {Brightness brightness = Brightness.light,
        double keyboard = 0,
        bool reducedMotion = false,
        bool highContrast = false,
        Widget? body,
        PreferredSizeWidget? header,
        VoidCallback? action,
        double textScale = 1}) =>
    ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => null),
          swanAccessProvider.overrideWithValue(SwanAccess.none),
          platformConfigProvider
              .overrideWith((ref) async => PlatformConfig.fromMap({})),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  viewInsets: EdgeInsets.only(bottom: keyboard),
                  disableAnimations: reducedMotion,
                  highContrast: highContrast,
                  textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: SwanScaffold(
            scrollUnderHeader: true,
            backgroundColor: brightness == Brightness.dark
                ? SwanPalette.dark.bg
                : SwanPalette.light.bg,
            extendBody: true,
            appBar: header ??
                AppBar(
                    title: Text('SwanSport',
                        style: SwanType.wordmark(brightness == Brightness.dark
                            ? SwanPalette.dark.ink
                            : SwanPalette.light.ink)),
                    actions: [
                      IconButton(
                          tooltip: 'Bildirimler',
                          icon: const Icon(Icons.notifications_none_rounded),
                          onPressed: action),
                      IconButton(
                          tooltip: 'Mesaj kutusu',
                          icon: const Icon(Icons.send_outlined),
                          onPressed: action),
                    ]),
            body: body ??
                ListView.builder(
                    key: const Key('chrome-list'),
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: 50,
                    itemBuilder: (context, index) => index == 0
                        ? const SwanHeaderSpacer()
                        : ListTile(title: Text('Satır $index'))),
            bottomNavigationBar: const SwanBottomNav(),
          ),
        ));

Future<void> collapse(WidgetTester tester) async {
  await tester.drag(
      find.byKey(const Key('chrome-list')), const Offset(0, -240));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  test('all feature scaffolds opt into the shared shell', () {
    for (final f in Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      expect(RegExp(r'\bScaffold\(').hasMatch(f.readAsStringSync()), false,
          reason: f.path);
    }
  });

  test('header controls retain contrast over opposite-luminance content', () {
    for (final palette in [SwanPalette.light, SwanPalette.dark]) {
      final background = Color.alphaBlend(
        palette.surface.withValues(alpha: SwanChrome.headerControlTint),
        palette.isDark ? Colors.white : Colors.black,
      ).computeLuminance();
      final text = palette.ink.computeLuminance();
      final ratio = text > background
          ? (text + .05) / (background + .05)
          : (background + .05) / (text + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });

  for (final width in [320.0, 393.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'icon-only, 48dp targets, collapse/reveal; $width $brightness',
          (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(brightness: brightness, textScale: 1.6));
        await tester.pumpAndSettle();
        final surface = find.byKey(const Key('swan-bottom-nav-surface'));
        expect(tester.getSize(surface).height, SwanChrome.expandedHeight);
        final expandedTop = tester.getTopLeft(surface).dy;
        for (final label in [
          'Ana Sayfa',
          'Keşfet',
          'Mesajlar',
          'Profil',
          'Oluştur'
        ]) {
          expect(find.text(label), findsNothing);
          expect(tester.getSize(find.byTooltip(label)).height,
              greaterThanOrEqualTo(SwanChrome.touchTarget));
        }
        await collapse(tester);
        expect(tester.getSize(surface).height, SwanChrome.compactHeight);
        expect(tester.getTopLeft(surface).dy, greaterThan(expandedTop));
        expect(find.text('SwanSport').hitTestable(), findsNothing);
        await tester.drag(
            find.byKey(const Key('chrome-list')), const Offset(0, 100));
        await tester.pumpAndSettle();
        expect(tester.getSize(surface).height, SwanChrome.expandedHeight);
        expect(find.text('SwanSport').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('header actions survive the common glass wrapper',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(action: () => taps++));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bildirimler'));
    await tester.tap(find.byTooltip('Mesaj kutusu'));
    expect(taps, 2);
  });

  testWidgets(
      'scroll-under header never resizes or moves the list during reveal',
      (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(host(
        body: ListView(
      key: const Key('chrome-list'),
      controller: scroll,
      padding: EdgeInsets.zero,
      children: [
        const SwanHeaderSpacer(),
        for (var i = 0; i < 40; i++) ListTile(title: Text('Stable $i')),
      ],
    )));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Stable 0')).dy,
        greaterThan(SwanChrome.headerHeight));
    scroll.jumpTo(160);
    await tester.pumpAndSettle();
    final list = find.byKey(const Key('chrome-list'));
    final viewport = tester.getRect(list);
    final row = tester.getTopLeft(find.text('Stable 5'));
    final chrome = ScrollChromeScope.maybeOf(tester.element(list))!;
    for (final delta in [SwanChrome.hideTravel, -SwanChrome.revealTravel]) {
      chrome.travel(delta);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(list), viewport);
        expect(tester.getTopLeft(find.text('Stable 5')), row);
        expect(scroll.offset, 160);
        expect(tester.takeException(), isNull);
      }
    }
    expect(find.text('SwanSport').hitTestable(), findsOneWidget);
  });

  testWidgets(
      'header is translucent; approved floating navigation is unchanged',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((w) => w.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.gradient != null),
        isEmpty);
    // Widget test platformu Android; cam yüzey burada performans için opaktır.
    expect(find.byType(BackdropFilter), findsNothing);
    final floating =
        find.byWidgetPredicate((w) => w is SwanGlassSurface && w.floating);
    expect(floating, findsOneWidget);
    final surface =
        find.descendant(of: floating, matching: find.byType(DecoratedBox));
    expect(
        tester.widgetList<DecoratedBox>(surface).any((w) =>
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).color?.a ?? 0) > .8),
        isTrue);
    expect(
        tester.getSize(find.byKey(const Key('swan-bottom-nav-surface'))).height,
        SwanChrome.expandedHeight);
  });

  testWidgets('keyboard hides navigation without resetting form or list',
      (tester) async {
    final text = TextEditingController();
    addTearDown(text.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    Widget content() => ListView(controller: scroll, children: [
          TextField(controller: text),
          const SizedBox(height: 1500),
          const Text('Son'),
        ]);
    await tester.pumpWidget(host(body: content()));
    await tester.pumpAndSettle();
    text.text = 'Kaydedilmemiş not';
    scroll.jumpTo(100);
    await tester.pump();
    await tester.pumpWidget(host(keyboard: 300, body: content()));
    await tester.pumpAndSettle();
    expect(find.byType(SwanBottomNav), findsNothing);
    expect(text.text, 'Kaydedilmemiş not');
    expect(scroll.offset, 100);
    await tester.pumpWidget(host(body: content()));
    await tester.pumpAndSettle();
    expect(find.byType(SwanBottomNav), findsOneWidget);
    expect(text.text, 'Kaydedilmemiş not');
  });

  testWidgets('reduced motion and high contrast keep readable opaque surfaces',
      (tester) async {
    await tester.pumpWidget(host(reducedMotion: true, highContrast: true));
    await tester.pumpAndSettle();
    await collapse(tester);
    expect(find.text('SwanSport').hitTestable(), findsOneWidget);
    for (final filter
        in tester.widgetList<BackdropFilter>(find.byType(BackdropFilter))) {
      expect(filter.enabled, false);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a non-scroll form keeps its full-size chrome', (tester) async {
    await tester.pumpWidget(host(body: const Center(child: Text('Form'))));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byKey(const Key('swan-bottom-nav-surface'))).height,
        SwanChrome.expandedHeight);
  });

  testWidgets('a tall save bar is not resized into the navigation capsule',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: SwanScaffold(
      body: Text('Düzenle'),
      bottomNavigationBar:
          SizedBox(height: 120, child: Center(child: Text('Kaydet'))),
    )));
    expect(tester.getSize(find.byType(SizedBox).first).height, 120);
    expect(find.text('Kaydet').hitTestable(), findsOneWidget);
  });

  testWidgets(
      'bespoke headers are measured and never relaid out at the clipped height',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SwanScaffold(
      header: const Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: 80, child: Center(child: Text('Başlık'))),
        SizedBox(height: 64, child: Center(child: Text('Filtre'))),
      ]),
      body: ListView.builder(
          key: const Key('chrome-list'),
          itemCount: 30,
          itemBuilder: (_, i) => ListTile(title: Text('$i'))),
    )));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('chrome-list'))).dy, 144);
    await tester.drag(
        find.byKey(const Key('chrome-list')), const Offset(0, -240));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Başlık').hitTestable(), findsNothing);
    await tester.drag(
        find.byKey(const Key('chrome-list')), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(find.text('Başlık').hitTestable(), findsOneWidget);
  });

  testWidgets('notch and home-indicator insets stay outside the controls',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => null),
          swanAccessProvider.overrideWithValue(SwanAccess.none),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 59, bottom: 34)),
              child: child!),
          home: SwanScaffold(
              scrollUnderHeader: true,
              appBar: AppBar(title: const Text('Başlık')),
              body: ListView(padding: EdgeInsets.zero, children: const [
                SwanHeaderSpacer(),
                Text('İçerik'),
              ]),
              bottomNavigationBar: const SwanBottomNav()),
        )));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Başlık')).dy, greaterThanOrEqualTo(59));
    expect(tester.getTopLeft(find.text('İçerik')).dy,
        59 + SwanChrome.headerHeight);
    final bottom = tester
        .getBottomLeft(find.byKey(const Key('swan-bottom-nav-surface')))
        .dy;
    expect(bottom, lessThanOrEqualTo(852 - 34));
    expect(tester.takeException(), isNull);
  });

  // These are previews of the real shared widgets, never production seed data.
  for (final brightness in Brightness.values) {
    testWidgets('render actual chrome preview $brightness', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: host(
            brightness: brightness,
            action: () {},
            header: StitchFeedTopBar(onFeedChanged: (_) {}),
            body: Builder(builder: (context) {
              final c = context.swan;
              return ListView(
                  key: const Key('chrome-list'),
                  padding: const EdgeInsets.all(SwanSpace.lg),
                  children: [
                    const SwanHeaderSpacer(),
                    Text('Bugünün ritmi', style: SwanType.h1(c.ink)),
                    const SizedBox(height: SwanSpace.sm),
                    Text('Antrenman, kulübün ve spor gündemi.',
                        style: SwanType.bodySm(c.inkMuted)),
                    const SizedBox(height: SwanSpace.xl),
                    Container(
                        height: 320,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(SwanRadius.lg),
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [c.surfaceAlt, c.line, c.surface])),
                        child: Icon(Icons.sports_tennis_outlined,
                            size: 96, color: c.inkMuted.withValues(alpha: .3))),
                    const SizedBox(height: SwanSpace.lg),
                    Row(children: [
                      Icon(Icons.favorite_border, color: c.ink),
                      const SizedBox(width: SwanSpace.lg),
                      Icon(Icons.chat_bubble_outline_rounded, color: c.ink),
                      const Spacer(),
                      Icon(Icons.bookmark_border, color: c.ink)
                    ]),
                    const SizedBox(height: SwanSpace.lg),
                    Text('Sporun etrafında buluş.', style: SwanType.h3(c.ink)),
                    const SizedBox(height: 1200),
                  ]);
            }),
          )));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      for (final state in ['expanded', 'compact', 'scroll-under']) {
        if (state == 'compact') await collapse(tester);
        if (state == 'scroll-under') {
          ScrollChromeScope.maybeOf(
                  tester.element(find.byKey(const Key('chrome-list'))))!
              .travel(-SwanChrome.revealTravel);
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final file =
              File('../../build/glass-previews/${brightness.name}-$state.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
}
