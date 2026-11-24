import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/financial_management/presentation/accountant_privacy_ledger_screen.dart';
import 'package:swansport_app/features/financial_management/presentation/closed_period_reversal_screen.dart';
import 'package:swansport_app/features/pro_operations/swan_pro_handoff.dart';

void main() {
  testWidgets('legacy accountant ledger route hands work to Pro',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccountantPrivacyLedgerScreen()),
    );

    expect(find.byType(SwanProHandoffPage), findsOneWidget);
    expect(find.text('Muhasebeci Defteri'), findsOneWidget);
    expect(find.text('Mali operasyon defteri'), findsOneWidget);
    expect(find.text('SwanSport Pro’da aç'), findsOneWidget);
  });

  testWidgets('legacy period closing route hands work to Pro', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ClosedPeriodReversalScreen()),
    );

    expect(find.byType(SwanProHandoffPage), findsOneWidget);
    expect(find.text('Ters İşlem ve Düzeltme'), findsOneWidget);
    expect(find.text('Kapanmış dönem düzeltmeleri'), findsOneWidget);
    expect(find.text('SwanSport Pro’da aç'), findsOneWidget);
  });
}
