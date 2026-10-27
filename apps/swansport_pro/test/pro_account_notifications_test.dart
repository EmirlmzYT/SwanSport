import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/account/pro_account_screen.dart';

void main() {
  testWidgets('renders professional notification preferences and toggles',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: ProAccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profesyonel Bildirim Tercihleri'), findsOneWidget);
    expect(find.text('Kulüp & Yönetim'), findsOneWidget);
    expect(find.text('Müsabaka & Hakem'), findsOneWidget);
    expect(find.text('Finans & Muhasebe'), findsOneWidget);
    expect(find.text('Antrenman & Yoklama'), findsOneWidget);
  });
}
