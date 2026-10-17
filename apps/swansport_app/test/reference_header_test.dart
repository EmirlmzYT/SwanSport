import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/app/design/swan_chrome.dart';
import 'package:swansport_app/app/widgets/action_gate.dart';
import 'package:swansport_app/app/widgets/swan_floating_header.dart';
import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_app/app/widgets/scroll_chrome.dart';
import 'package:swansport_app/features/social/presentation/widgets/stitch_feed_widgets.dart';

Widget referenceHost(
        {required Brightness brightness,
        double scale = 1,
        ValueChanged<bool>? onFeedChanged,
        bool followingOnly = false}) =>
    ProviderScope(
      overrides: [
        swanAccessProvider.overrideWithValue(SwanAccess.none),
        currentProfileProvider.overrideWith((_) async => null),
        platformConfigProvider
            .overrideWith((_) async => PlatformConfig.fromMap({})),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: SwanScaffold(
          scrollUnderHeader: true,
          appBar: StitchFeedTopBar(
              onFeedChanged: onFeedChanged, followingOnly: followingOnly),
          body: ListView(padding: EdgeInsets.zero, children: const [
            SwanHeaderSpacer(),
            SizedBox(height: 1600),
          ]),
        ),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 393.0]) {
      testWidgets(
          'reference title stays centered and independent controls have 48dp targets: $brightness/$width',
          (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(referenceHost(
            brightness: brightness, scale: 1.6, onFeedChanged: (_) {}));
        await tester.pumpAndSettle();
        final title = find.byTooltip('Akış seçimi');
        expect(tester.getCenter(title).dx, closeTo(width / 2, .1));
        final plus = find.byTooltip('İçerik oluştur');
        final inbox = find.byTooltip('Bildirimler');
        final messages = find.byTooltip('Mesajlar');
        expect(tester.getRect(plus).right,
            lessThanOrEqualTo(tester.getRect(title).left));
        expect(tester.getRect(title).right,
            lessThanOrEqualTo(tester.getRect(inbox).left));
        expect(tester.getRect(inbox).right,
            lessThanOrEqualTo(tester.getRect(messages).left));
        for (final button in [plus, inbox, messages]) {
          expect(tester.getSize(button).width,
              greaterThanOrEqualTo(SwanChrome.touchTarget));
          expect(tester.getSize(button).height,
              greaterThanOrEqualTo(SwanChrome.touchTarget));
        }
        expect(find.byType(SwanHeaderControl), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('brand dropdown selects each real feed mode', (tester) async {
    final selections = <bool>[];
    await tester.pumpWidget(referenceHost(
        brightness: Brightness.dark, onFeedChanged: selections.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Akış seçimi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Takip Ettiklerim'));
    await tester.pumpAndSettle();
    expect(selections, [true]);
    await tester.tap(find.byTooltip('Akış seçimi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümü (Keşfet)'));
    await tester.pumpAndSettle();
    expect(selections, [true, false]);
  });

  testWidgets('header create uses the existing guest action gate',
      (tester) async {
    await tester.pumpWidget(referenceHost(brightness: Brightness.light));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('İçerik oluştur'));
    await tester.pumpAndSettle();
    expect(find.byType(SwanActionGateBottomSheet), findsOneWidget);
    expect(find.text('Hesap gerekli'), findsOneWidget);
  });

  testWidgets('scroll-edge has no tinted full-width panel over uniform content',
      (tester) async {
    final boundary = GlobalKey();
    const background = Colors.orange;
    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
            key: boundary,
            child: const Stack(children: [
              Positioned.fill(child: ColoredBox(color: background)),
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: SwanGlassSurface(child: SizedBox.expand())),
            ]))));
    await tester.pumpAndSettle();
    late List<int> pixel;
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 1);
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final index = (50 * image.width + 100) * 4;
      pixel = rgba!.buffer.asUint8List().sublist(index, index + 4);
      image.dispose();
    });
    expect(pixel, [255, 152, 0, 255]);
    expect(find.byType(BackdropFilter),
        findsNWidgets(SwanChrome.headerEdgeBlurs.length));
  });
}
