import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/chat_composer.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
        'composer validates input and fits narrow keyboard layout $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var sends = 0;
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
              body: Align(
                  alignment: Alignment.bottomCenter,
                  child: SwanChatComposer(
                      controller: controller, onSend: () => sends++)))));
      final send = find.byTooltip('Gönder');
      await tester.tap(send);
      expect(sends, 0);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(send);
      expect(sends, 0);
      await tester.enterText(
          find.byType(TextField), 'Antrenman kaçta?\nSahada görüşürüz.');
      await tester.pump();
      await tester.tap(send);
      expect(sends, 1);
      expect(tester.takeException(), isNull);
      controller.clear();
      await tester.pump();
      expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
