import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/performance_controller.dart';
import '../domain/performance_analytics.dart';
import 'performance_route_args.dart';

class TeamPerformanceScreen extends ConsumerWidget {
  final TeamPerformanceArgs? args;
  const TeamPerformanceScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);
    final found = state.teams.where((e) => e.id == args?.teamId);
    if (!state.permissions.canViewCommandCenter) {
      return const _SafeState('Takım performansına erişim reddedildi.');
    }
    if (found.isEmpty) return const _SafeState('Takım performansı bulunamadı.');
    final team = found.single;
    return _Workspace(
      title: team.name,
      keyName: 'team-performance-detail',
      sections: {
        'Takım Kimliği':
            '${team.branch} • ${team.ageGroup} • ${team.coach} • ${team.period}',
        'Hazırlık':
            'Operasyonel uygunluk %${state.metrics.teamReadinessRate}; Screen 12 clearance geçerlidir.',
        'Dağılım':
            '${team.athletes.length} sporcu • tanı, tedavi veya doktor notu yok',
        'Değerlendirme Tazeliği':
            '${state.metrics.assessedThisPeriod} güncel değerlendirme',
        'Yük, Maç ve Antrenman':
            '${state.training.length} antrenman • ${state.matches.length} maç kaydı',
        'Pozisyon & Benchmark':
            '${state.positions.length} pozisyon • ${state.benchmarks.length} benchmark',
        'İçgörü, Uyarı ve Denetim':
            '${state.insights.length} içgörü • ${state.alerts.length} uyarı • ${state.audit.length} audit',
      },
    );
  }
}

class TestSessionScreen extends ConsumerWidget {
  final TestSessionArgs? args;
  const TestSessionScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);
    final controller = ref.read(performanceControllerProvider.notifier);
    final found = state.testSessions.where((e) => e.id == args?.sessionId);
    if (found.isEmpty) return const _SafeState('Test oturumu bulunamadı.');
    final session = found.single;
    return _Workspace(
      title: session.title,
      keyName: 'test-session-detail',
      sections: {
        'Oturum':
            '${session.sport} • ${session.location} • ${session.assessor}',
        'Batarya': session.battery.join(' • '),
        'İlerleme':
            '%${(session.completionProgress * 100).toStringAsFixed(0)} • Geçerli ${session.validResults} • Eksik ${session.missingResults} • Geçersiz ${session.invalidResults}',
        'Durum': session.status.name,
      },
      actions: state.permissions.canManageTests
          ? [
              _action(
                'Başlat',
                () => controller.transitionTestSession(
                  session.id,
                  TestSessionStatus.inProgress,
                ),
              ),
              _action(
                'Tamamla',
                () => controller.transitionTestSession(
                  session.id,
                  TestSessionStatus.completed,
                ),
              ),
              _action(
                'İncelemeye Gönder',
                () => controller.transitionTestSession(
                  session.id,
                  TestSessionStatus.underReview,
                ),
              ),
              _action(
                'Yayınla',
                () => controller.transitionTestSession(
                  session.id,
                  TestSessionStatus.published,
                ),
              ),
              _action(
                'Arşivle',
                () => controller.transitionTestSession(
                  session.id,
                  TestSessionStatus.archived,
                ),
              ),
            ]
          : const [],
    );
  }
}

class DevelopmentPlanScreen extends ConsumerWidget {
  final DevelopmentPlanArgs? args;
  const DevelopmentPlanScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);
    final controller = ref.read(performanceControllerProvider.notifier);
    final found = state.plans.where((e) => e.id == args?.planId);
    if (found.isEmpty) return const _SafeState('Gelişim planı bulunamadı.');
    final plan = found.single;
    return _Workspace(
      title: plan.title,
      keyName: 'development-plan-detail',
      sections: {
        'Sahip & Dönem':
            '${plan.owner} • ${plan.startDate.toString().split(' ').first} — ${plan.endDate.toString().split(' ').first}',
        'Odak Alanları': plan.focusAreas.join(' • '),
        'Koçluk Eylemleri': plan.coachingActions.join(' • '),
        'İlerleme':
            '%${plan.progress.toStringAsFixed(0)} • ${plan.status.name}',
        'Sınır': plan.notes,
      },
      actions: state.permissions.canManageGoals
          ? [
              _action(
                'Aktifleştir',
                () => controller.transitionPlan(plan.id, PlanStatus.active),
              ),
              _action(
                'Duraklat',
                () => controller.transitionPlan(plan.id, PlanStatus.paused),
              ),
              _action(
                'Devam Et',
                () => controller.transitionPlan(plan.id, PlanStatus.active),
              ),
              _action(
                'Tamamla',
                () => controller.transitionPlan(plan.id, PlanStatus.completed),
              ),
              _action(
                'Arşivle',
                () => controller.transitionPlan(plan.id, PlanStatus.archived),
              ),
            ]
          : const [],
    );
  }
}

class ReviewSessionScreen extends ConsumerWidget {
  final ReviewSessionArgs? args;
  const ReviewSessionScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);
    final controller = ref.read(performanceControllerProvider.notifier);
    final found = state.reviewSessions.where((e) => e.id == args?.reviewId);
    if (found.isEmpty) return const _SafeState('İnceleme oturumu bulunamadı.');
    final review = found.single;
    return _Workspace(
      title: 'Sporcu İnceleme Oturumu',
      keyName: 'review-session-detail',
      sections: {
        'Koç & Tarih':
            '${review.coach} • ${review.date.toString().split(' ').first}',
        'İncelenen Ölçümler': review.reviewedMetrics.join(' • '),
        'İnsan Kararları': review.decisions.join(' • '),
        'Mutabık Eylemler': review.agreedActions.join(' • '),
        'Sonraki İnceleme':
            '${review.nextReviewDate.toString().split(' ').first} • ${review.status.name}',
      },
      actions: state.permissions.canAssessSkills
          ? [
              _action(
                'Başlat',
                () => controller.transitionReview(
                  review.id,
                  ReviewStatus.inProgress,
                ),
              ),
              _action(
                'Tamamla',
                () => controller.transitionReview(
                  review.id,
                  ReviewStatus.completed,
                ),
              ),
              _action(
                'İptal Et',
                () => controller.transitionReview(
                  review.id,
                  ReviewStatus.cancelled,
                ),
              ),
              _action(
                'Takip Gerekli',
                () => controller.transitionReview(
                  review.id,
                  ReviewStatus.followUpRequired,
                ),
              ),
            ]
          : const [],
    );
  }
}

class MatchPerformanceScreen extends ConsumerWidget {
  final MatchPerformanceArgs? args;
  const MatchPerformanceScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);
    final found = state.matches.where((e) => e.id == args?.recordId);
    if (found.isEmpty) return const _SafeState('Maç performansı bulunamadı.');
    final record = found.single;
    return _Workspace(
      title: 'Maç Performansı',
      keyName: 'match-performance-detail',
      sections: {
        'Bağlam':
            '${record.competition} • ${record.opponent} • ${record.minutes} dakika',
        'Ölçülmüş Olaylar': record.factualEvents.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(' • '),
        'Hesaplanan Gösterge':
            '${record.eventsPer90?.toStringAsFixed(1)} olay/90 dk',
        'Koç Yargısı': '${record.coachRating}/5 • İnsan değerlendirmesidir',
        'Veri Kalitesi': record.quality.name,
      },
    );
  }
}

class TrainingPerformanceScreen extends ConsumerWidget {
  final TrainingPerformanceArgs? args;
  const TrainingPerformanceScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);
    final found = state.training.where((e) => e.id == args?.recordId);
    if (found.isEmpty) {
      return const _SafeState('Antrenman performansı bulunamadı.');
    }
    final record = found.single;
    return _Workspace(
      title: record.session,
      keyName: 'training-performance-detail',
      sections: {
        'Katılım':
            '${record.attended ? 'Katıldı' : 'Katılmadı'} • salt okunur Screen 6 girdisi',
        'Tamamlama': 'Ortalama %${record.averageCompletion.toStringAsFixed(1)}',
        'Şeffaf Yük':
            '${record.load.durationMinutes} dk × RPE ${record.load.sessionRpe} = ${record.load.internalLoad} AU',
        'Örnek Kalitesi':
            record.load.lowSample ? 'Düşük örnek' : 'Yeterli örnek',
      },
    );
  }
}

class PositionAnalysisScreen extends ConsumerWidget {
  final PositionAnalysisArgs? args;
  const PositionAnalysisScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);
    final found = state.positions.where((e) => e.id == args?.positionId);
    if (found.isEmpty) return const _SafeState('Pozisyon analizi bulunamadı.');
    final record = found.single;
    return _Workspace(
      title: record.position,
      keyName: 'position-analysis-detail',
      sections: {
        'Boyutlar': record.dimensions.join(' • '),
        'Uygulanabilir Testler': record.tests.join(' • '),
        'Kapsam':
            '${record.athleteCoverage} sporcu • n=${record.sampleSize} • ${record.quality.name}',
        'Karar Güvenliği':
            'Seçim, çıkarma veya ilk 11 önerisi üretilmez; kamuya açık sıralama yoktur.',
      },
    );
  }
}

class _Workspace extends StatelessWidget {
  final String title;
  final String keyName;
  final Map<String, String> sections;
  final List<Widget> actions;

  const _Workspace({
    required this.title,
    required this.keyName,
    required this.sections,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          key: Key(keyName),
          padding: const EdgeInsets.all(20),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            for (final section in sections.entries)
              Card(
                child: ListTile(
                  title: Text(section.key),
                  subtitle: Text(section.value),
                ),
              ),
            if (actions.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      );
}

class _SafeState extends StatelessWidget {
  final String message;
  const _SafeState(this.message);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(message)));
}

Widget _action(String label, VoidCallback callback) => OutlinedButton(
      onPressed: callback,
      child: Text(label),
    );
