import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/inbox_actions.dart';

void main() {
  group('badgeLabel', () {
    test('tek haneli sayı olduğu gibi', () {
      expect(badgeLabel(1), '1');
      expect(badgeLabel(9), '9');
    });

    test('9 üstü 9+ olur — iki hane 17px rozete sığmıyor', () {
      expect(badgeLabel(10), '9+');
      expect(badgeLabel(250), '9+');
    });
  });

  group('InboxIconButton', () {
    Widget wrap(Widget child) =>
        MaterialApp(home: Scaffold(body: Center(child: child)));

    testWidgets('rozet 0 iken hiç çizilmez', (tester) async {
      await tester.pumpWidget(wrap(InboxIconButton(
        icon: Icons.favorite_border_rounded,
        badge: 0,
        onTap: () {},
      )));

      expect(find.text('0'), findsNothing);
    });

    testWidgets('rozet 0 üstünde sayıyı gösterir', (tester) async {
      await tester.pumpWidget(wrap(InboxIconButton(
        icon: Icons.favorite_border_rounded,
        badge: 3,
        onTap: () {},
      )));

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('dokunulunca onTap çalışır — ölü buton hatasının testi',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(wrap(InboxIconButton(
        icon: Icons.favorite_border_rounded,
        onTap: () => tapped++,
      )));

      await tester.tap(find.byType(InboxIconButton));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('rozet varken de dokunma çalışır', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(wrap(InboxIconButton(
        icon: Icons.send_outlined,
        badge: 12,
        onTap: () => tapped++,
      )));

      expect(find.text('9+'), findsOneWidget);
      await tester.tap(find.byType(InboxIconButton));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('çerçevesiz minimalist boyut 44x44 dokunma alanını korur',
        (tester) async {
      await tester.pumpWidget(wrap(InboxIconButton(
        icon: Icons.favorite_border_rounded,
        onTap: () {},
      )));

      final box = tester.renderObject<RenderBox>(find.byType(SizedBox).first);
      expect(box.size.width, 44);
      expect(box.size.height, 44);
    });
  });
}
