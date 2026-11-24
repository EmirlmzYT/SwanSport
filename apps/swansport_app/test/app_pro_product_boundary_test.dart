import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/attendance/presentation/attendance_queue_banner.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('App production code does not embed Pro feature UI', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('package:swansport_pro_features') ||
          source.contains('SharedAttendanceQueueBanner') ||
          source.contains('SharedClubOperationsPanel') ||
          source.contains('SharedFinanceOperationsPanel') ||
          source.contains('SharedFederationOperationsPanel') ||
          source.contains('SharedRefereeOperationsPanel')) {
        violations.add(entity.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'App sosyal mobil yüzey olarak kalmalı; ayrıntılı operasyon '
          'arayüzleri SwanSport Pro içinde çalışmalı.',
    );
  });

  test('App dependency manifest does not ship the Pro UI package', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('swansport_pro_features:')));
  });

  testWidgets('App attendance queue keeps its local App route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureEnabledProvider(FeatureFlags.attendanceOperations)
              .overrideWithValue(true),
          attendanceLocalDataProvider.overrideWith(
            (ref) => Stream.value({
              'cache': <Map<String, dynamic>>[],
              'drafts': <Map<String, dynamic>>[
                {'event_id': 'event-1'},
              ],
              'ops': <Map<String, dynamic>>[],
            }),
          ),
        ],
        child: MaterialApp(
          routes: {
            '/attendance': (_) =>
                const Scaffold(body: Text('APP_YOKLAMA_HEDEFI')),
          },
          home: const Scaffold(body: AttendanceQueueBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('0 yoklama gönderimi, 1 cihaz taslağı bekliyor'),
    );
    await tester.pumpAndSettle();

    expect(find.text('APP_YOKLAMA_HEDEFI'), findsOneWidget);
  });
}
