import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_center_controller.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/fixtures/fixture_audience_resolver.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/audience_resolution.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/presentation/screens/announcements_screen.dart';
import 'package:swansport_core/swansport_core.dart';

void main() {
  CommunicationCenterController controller({
    CommunicationRole role = CommunicationRole.headCoach,
    AudienceResolver? resolver,
  }) =>
      CommunicationCenterController(
        repository: FixtureCommunicationCenterRepository(
          const FixtureCommunicationCenterDataSource(),
        ),
        role: role,
        audienceResolver: resolver ?? const _DelegatingResolver(),
      );

  Future<void> pump(
    WidgetTester tester,
    CommunicationCenterController subject,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communicationCenterControllerProvider.overrideWith((ref) => subject),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openComposer(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add_comment_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
      'selection renders aggregate preview and mixed deduplicated total',
      (tester) async {
    await pump(tester, controller());
    await openComposer(tester);
    await tester.tap(find.byKey(const Key('audience-team')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('3 benzersiz alıcı'), findsOneWidget);
    await tester.tap(find.byKey(const Key('audience-club')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('6 benzersiz alıcı'), findsOneWidget);
  });

  testWidgets('empty audience shows validation and clear removes preview',
      (tester) async {
    await pump(tester, controller());
    await openComposer(tester);
    await tester.tap(find.byKey(const Key('audience-team')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('audience-recipient-preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('audience-team')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('audience-resolution-error')), findsOneWidget);
    expect(find.byKey(const Key('audience-recipient-preview')), findsNothing);
    await tester.tap(find.byKey(const Key('audience-clear')));
    await tester.pump();
    expect(find.byKey(const Key('audience-recipient-preview')), findsNothing);
  });

  testWidgets('athlete and guardian roles cannot expose recipient details',
      (tester) async {
    for (final role in [
      CommunicationRole.athlete,
      CommunicationRole.guardian,
    ]) {
      await pump(tester, controller(role: role));
      expect(find.byIcon(Icons.add_comment_rounded), findsNothing);
      expect(find.byKey(const Key('audience-recipient-preview')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('resolver loading state is visible', (tester) async {
    final delayed = _WidgetDelayedResolver();
    await pump(tester, controller(resolver: delayed));
    await openComposer(tester);
    await tester.tap(find.byKey(const Key('audience-team')));
    await tester.pump();
    expect(find.byKey(const Key('audience-resolver-loading')), findsOneWidget);
  });
}

class _DelegatingResolver implements AudienceResolver {
  const _DelegatingResolver();

  @override
  Future<AppResult<ResolvedAudience>> resolve(
    CommunicationAudience audience, {
    required CommunicationRole role,
  }) =>
      const FixtureAudienceResolver().resolve(audience, role: role);
}

class _WidgetDelayedResolver implements AudienceResolver {
  final completer = Completer<AppResult<ResolvedAudience>>();

  @override
  Future<AppResult<ResolvedAudience>> resolve(
    CommunicationAudience audience, {
    required CommunicationRole role,
  }) =>
      completer.future;
}
