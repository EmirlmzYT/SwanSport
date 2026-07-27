import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/athlete_workspace/application/athlete_detail_controller.dart';
import 'package:swansport_app/features/athlete_workspace/application/athlete_detail_permissions.dart';
import 'package:swansport_app/features/athlete_workspace/application/athlete_detail_state.dart';
import 'package:swansport_app/features/athlete_workspace/data/fixtures/athlete_detail_fixture_data_source.dart';
import 'package:swansport_app/features/athlete_workspace/domain/models/athlete_detail.dart';
import 'package:swansport_app/features/athlete_workspace/domain/repositories/athlete_detail_repository.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/routing/athlete_detail_route_args.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_detail_screen.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  Future<void> pumpAthleteDetail(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Widget buildScreen({
    AthleteDetailRepository? repository,
    Size size = const Size(390, 844),
    double textScaleFactor = 1,
  }) {
    return ProviderScope(
      overrides: [
        if (repository != null)
          athleteDetailRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: SwanTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const AthleteDetailScreen(
            args: AthleteDetailRouteArgs(
              athleteId: SwanId('athlete_can_yilmaz'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders full error state from repository failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        repository: const _FailureAthleteDetailRepository(
          AppFailure(message: 'Fixture failed.', code: 'fixture_failed'),
        ),
      ),
    );

    await pumpAthleteDetail(tester);

    expect(find.text('Fixture failed.'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });

  testWidgets('renders permission denied state from repository failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        repository: const _FailureAthleteDetailRepository(
          AppFailure(
            message: 'Permission denied for athlete detail.',
            code: 'athlete_permission_denied',
          ),
        ),
      ),
    );

    await pumpAthleteDetail(tester);

    expect(find.text('Permission denied for athlete detail.'), findsOneWidget);
  });

  testWidgets('renders deterministic empty section states', (tester) async {
    await tester.pumpWidget(
      _buildSeededScreen(
        AthleteDetailState(
          status: AthleteDetailStatus.loaded,
          athleteId: const SwanId('athlete_can_yilmaz'),
          selectedSection: AthleteDetailSection.activity,
          permissions: _coachPermissions,
          detail: _emptyDetail(),
        ),
      ),
    );

    await tester.pump();

    expect(find.textContaining('aktivite'), findsOneWidget);
  });

  for (final entry in {
    AthleteDetailSection.attendance: 'yoklama',
    AthleteDetailSection.documents: 'evrak',
    AthleteDetailSection.notes: 'notu',
  }.entries) {
    testWidgets('renders empty ${entry.key.name} section state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSeededScreen(
          AthleteDetailState(
            status: AthleteDetailStatus.loaded,
            athleteId: const SwanId('athlete_can_yilmaz'),
            selectedSection: entry.key,
            permissions: _coachPermissions,
            detail: _emptyDetail(),
          ),
        ),
      );

      await tester.pump();
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining(entry.value), findsWidgets);
    });
  }

  testWidgets('renders partial section failure and offline stale metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSeededScreen(
        AthleteDetailState(
          status: AthleteDetailStatus.loaded,
          athleteId: const SwanId('athlete_can_yilmaz'),
          selectedSection: AthleteDetailSection.activity,
          permissions: _coachPermissions,
          detail: _fixtureDetail(),
          sectionErrors: const {
            AthleteDetailSection.activity:
                'Aktivite verisi gecici olarak yuklenemedi.',
          },
          isOffline: true,
          isStale: true,
        ),
      ),
    );

    await tester.pump();

    expect(find.textContaining('nbellek'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Aktivite verisi'),
      120,
    );
    expect(find.textContaining('Aktivite verisi'), findsOneWidget);
  });

  for (final width in <double>[375, 600, 768, 1024, 1440]) {
    testWidgets('renders without overflow at ${width.toInt()} px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildScreen(size: Size(width, 900), textScaleFactor: 1.2),
      );

      await pumpAthleteDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Can'), findsWidgets);
      expect(find.text('Yoklama'), findsOneWidget);
    });
  }

  testWidgets('does not expose hidden notes for restricted controller role', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          athleteDetailControllerProvider.overrideWith((ref, athleteId) {
            return AthleteDetailController(
              athleteId: athleteId,
              repository: _StaticAthleteDetailRepository(_fixtureDetail()),
              role: AthleteDetailRole.athlete,
            );
          }),
        ],
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const AthleteDetailScreen(
            args: AthleteDetailRouteArgs(
              athleteId: SwanId('athlete_can_yilmaz'),
            ),
          ),
        ),
      ),
    );

    await pumpAthleteDetail(tester);

    expect(find.text('Notlar'), findsNothing);
    expect(find.textContaining('Fizyoterapi'), findsNothing);
  });
}

AthleteDetail _fixtureDetail() {
  return const AthleteDetailFixtureDataSource()
      .findById(const SwanId('athlete_can_yilmaz'))!;
}

const _coachPermissions = AthleteDetailPermissions(
  visibleSections: {
    AthleteDetailSection.activity,
    AthleteDetailSection.attendance,
    AthleteDetailSection.documents,
    AthleteDetailSection.notes,
  },
  canContactGuardian: true,
  canEditCoachNotes: true,
);

Widget _buildSeededScreen(AthleteDetailState state) {
  return ProviderScope(
    overrides: [
      athleteDetailControllerProvider.overrideWith((ref, athleteId) {
        return _SeededAthleteDetailController(state);
      }),
    ],
    child: MaterialApp(
      theme: SwanTheme.light(),
      home: AthleteDetailScreen(
        key: ValueKey(state.selectedSection),
        args: AthleteDetailRouteArgs(
          athleteId: state.athleteId,
        ),
      ),
    ),
  );
}

AthleteDetail _emptyDetail() {
  final fixture = _fixtureDetail();

  return fixture.copyWith(
    attendance: const AttendanceSummary(
      rateLabel: '%0',
      scoreLabel: '0',
      scoreUnit: 'Puan',
      recentItems: [],
    ),
    documents: const [],
    notes: const [],
    timeline: const [],
  );
}

class _StaticAthleteDetailRepository implements AthleteDetailRepository {
  const _StaticAthleteDetailRepository(this.detail);

  final AthleteDetail detail;

  @override
  Future<AppResult<AthleteDetail>> getAthleteDetail(SwanId athleteId) async {
    return AppSuccess(detail);
  }
}

class _FailureAthleteDetailRepository implements AthleteDetailRepository {
  const _FailureAthleteDetailRepository(this.failure);

  final AppFailure failure;

  @override
  Future<AppResult<AthleteDetail>> getAthleteDetail(SwanId athleteId) async {
    return AppError(failure);
  }
}

class _SeededAthleteDetailController extends AthleteDetailController {
  _SeededAthleteDetailController(AthleteDetailState seed)
      : super(
          athleteId: seed.athleteId,
          repository: _StaticAthleteDetailRepository(seed.detail!),
        ) {
    state = seed;
  }

  @override
  Future<void> load() async {}
}
