import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  testWidgets('long account details remain usable on a scaled phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    final session = Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: User(
        id: 'account-responsive',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-30',
        email: 'cok.uzun.kurumsal.hesap.adresi@profesyonel-spor-kulubu.example',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(false),
          authSessionProvider.overrideWith((ref) => Stream.value(session)),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: ProAccountScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profesyonel Bildirim Tercihleri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
