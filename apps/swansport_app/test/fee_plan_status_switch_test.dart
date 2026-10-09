import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/financial_management/presentation/fee_plan_status_switch.dart';
import 'package:swansport_data/swansport_data.dart';

class PlanFake extends Fake implements FinanceService {
  final completion = Completer<void>();
  int calls = 0;
  @override
  Future<void> setPlanActive(String id, bool active) {
    expect(id, 'p');
    expect(active, isTrue);
    calls++;
    return completion.future;
  }
}

void main() {
  const plan =
      FeePlan(id: 'p', name: 'Taslak', amount: 100, dueDay: 10, active: false);
  const admin = SwanAccess(
      isPlatformAdmin: false,
      clubRole: 'club_admin',
      coachLevel: 0,
      athleteKind: null);
  Future<void> mount(WidgetTester t, PlanFake service,
      {SwanAccess access = admin}) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          financeServiceProvider.overrideWithValue(service),
          swanAccessProvider.overrideWithValue(access),
          feePlansProvider.overrideWith((ref) async => [plan]),
        ],
        child: const MaterialApp(
            home: Scaffold(body: FeePlanStatusSwitch(plan: plan)))));
    await t.pumpAndSettle();
  }

  testWidgets('status waits for server and prevents duplicate writes',
      (t) async {
    final service = PlanFake();
    await mount(t, service);
    await t.tap(find.byType(Switch));
    await t.pump();
    final sw = t.widget<Switch>(find.byType(Switch));
    expect(sw.onChanged, isNull);
    expect(sw.value, isFalse);
    expect(service.calls, 1);
    service.completion.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('write failure shows retry feedback and restores control',
      (t) async {
    final service = PlanFake();
    await mount(t, service);
    await t.tap(find.byType(Switch));
    await t.pump();
    service.completion.completeError(StateError('fixture'));
    await t.pumpAndSettle();
    expect(
        find.text('Plan durumu kaydedilemedi. Yeniden dene.'), findsOneWidget);
    expect(t.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
  });
  testWidgets('athlete cannot change fee plan status', (t) async {
    final service = PlanFake();
    await mount(t, service, access: SwanAccess.none);
    expect(t.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(service.calls, 0);
  });
}
