import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/financial_management/presentation/closed_period_reversal_screen.dart';
import 'package:swansport_app/features/pro_operations/swan_pro_handoff.dart';

void main() {
  testWidgets(
      'social app no longer loads closed-period records and preserves the legacy route',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ClosedPeriodReversalScreen()),
    );

    expect(find.byType(SwanProHandoffCard), findsOneWidget);
    expect(find.text('Yeni Ters İşlem'), findsNothing);
    expect(
      find.text('Aynı SwanSport hesabın ve mevcut yetkilerin kullanılır.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
