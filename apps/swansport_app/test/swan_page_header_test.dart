import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/swan_page_header.dart';

void main() {
  testWidgets('başlık, alt başlık ve gerçek aksiyonlar çalışır',
      (tester) async {
    var backCount = 0;
    var actionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwanPageHeader(
            title: 'Hareketler',
            subtitle: 'Bildirimlerin',
            onBack: () => backCount++,
            actions: [
              SwanHeaderAction(
                icon: Icons.tune_rounded,
                tooltip: 'Bildirim tercihleri',
                onTap: () => actionCount++,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Hareketler'), findsOneWidget);
    expect(find.text('Bildirimlerin'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Geri'));
    await tester.tap(find.bySemanticsLabel('Bildirim tercihleri'));

    expect(backCount, 1);
    expect(actionCount, 1);
  });
}
