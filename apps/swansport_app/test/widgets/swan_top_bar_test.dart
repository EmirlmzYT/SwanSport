import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/design/swan_palette.dart';
import 'package:swansport_app/app/widgets/stitch_components.dart';

void main() {
  Widget buildTestWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('SwanTopBar / StitchTopBar', () {
    testWidgets(
        'Marka modunda (isBrand: true) swanspor wordmark render edilir ve şimşek ikonu yoktur',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const SwanTopBar(
            isBrand: true,
          ),
        ),
      );

      // 'swanspor' marka metnini doğrula
      expect(find.text('swanspor'), findsOneWidget);

      // Şimşek rozeti kesinlikle olmamalı
      expect(find.byIcon(Icons.bolt_rounded), findsNothing);
    });

    testWidgets(
        'Alt ekran modunda (isBrand: false) başlık ve geri butonu çalışır',
        (tester) async {
      var backTapped = 0;

      await tester.pumpWidget(
        buildTestWidget(
          child: SwanTopBar(
            title: 'Kadro Detayı',
            subtitle: 'A Takımı',
            isBrand: false,
            showBack: true,
            onBack: () => backTapped++,
          ),
        ),
      );

      expect(find.text('Kadro Detayı'), findsOneWidget);
      expect(find.text('A Takımı'), findsOneWidget);
      expect(find.text('swanspor'), findsNothing);

      final backBtn = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backBtn, findsOneWidget);

      await tester.tap(backBtn);
      await tester.pump();

      expect(backTapped, 1);
    });

    testWidgets('Actions ve trailing parametreleri doğru render edilir',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const SwanTopBar(
            isBrand: true,
            actions: [
              Icon(Icons.favorite_border_rounded, key: Key('heart_icon')),
              Icon(Icons.send_outlined, key: Key('send_icon')),
            ],
            trailing: Text('Filtre', key: Key('trailing_text')),
          ),
        ),
      );

      expect(find.byKey(const Key('heart_icon')), findsOneWidget);
      expect(find.byKey(const Key('send_icon')), findsOneWidget);
      expect(find.byKey(const Key('trailing_text')), findsOneWidget);
    });

    testWidgets(
        'Koyu temada (ThemeMode.dark) surface ve ink renkleri tema paletine uyar',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          themeMode: ThemeMode.dark,
          child: const SwanTopBar(
            title: 'Karanlık Mod',
            isBrand: false,
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Karanlık Mod'));
      expect(text.style?.color, SwanPalette.dark.ink);
    });

    testWidgets(
        'Açık temada (ThemeMode.light) ink rengi SwanPalette.light.ink ile eşleşir',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          themeMode: ThemeMode.light,
          child: const SwanTopBar(
            title: 'Açık Mod',
            isBrand: false,
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Açık Mod'));
      expect(text.style?.color, SwanPalette.light.ink);
    });
  });
}
