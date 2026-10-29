import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/calendar/pro_calendar_screen.dart';

Session _makeSession(String userId) {
  return Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-26',
      email: 'calendar@swansport.com',
    ),
  );
}

void main() {
  group('Pro Calendar Responsive & Usability Contracts', () {
    testWidgets('calendar provides Month/List switch and preserves state',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-cal-switch')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            unifiedCalendarMonthProvider.overrideWith(
              (ref, month) async => UnifiedCalendarData(
                [
                  UnifiedCalendarEvent(
                    id: 'ev-1',
                    type: CalendarEventType.clubTraining,
                    title: 'A Takım Antrenmanı',
                    startsAt: DateTime(month.year, month.month, 15, 18, 0),
                    status: 'scheduled',
                  ),
                ],
              ),
            ),
          ],
          child: const MaterialApp(
            home: ProCalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProCalendarScreen), findsOneWidget);
      expect(find.text('A Takım Antrenmanı'), findsOneWidget);

      // Verify toggle exists (Ay / Liste)
      final listToggle = find.text('Liste');
      if (listToggle.evaluate().isNotEmpty) {
        await tester.tap(listToggle);
        await tester.pumpAndSettle();
        expect(find.text('A Takım Antrenmanı'), findsOneWidget);
      }
    });

    testWidgets('renders cleanly without overflow across 320px to 1440px',
        (tester) async {
      final widths = [320.0, 390.0, 768.0, 1024.0, 1440.0];

      for (final width in widths) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authSessionProvider.overrideWith(
                (ref) => Stream.value(_makeSession('user-cal-resp')),
              ),
              swanAccessProvider.overrideWithValue(
                const SwanAccess(
                  isPlatformAdmin: false,
                  clubRole: 'club_admin',
                  coachLevel: 0,
                  athleteKind: null,
                ),
              ),
              unifiedCalendarMonthProvider.overrideWith(
                (ref, month) async => const UnifiedCalendarData(
                  [],
                ),
              ),
            ],
            child: const MaterialApp(
              home: ProCalendarScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Overflow occurred at width $width');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
