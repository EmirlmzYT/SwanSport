import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/performance_controller.dart';
import '../domain/performance_analytics.dart';
import 'performance_route_args.dart';

class PerformanceAnalyticsScreen extends ConsumerWidget {
  const PerformanceAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);
    final c = ref.read(performanceControllerProvider.notifier);
    final metrics = state.metrics;

    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Performans Analizi & Gelişim',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (MediaQuery.textScalerOf(context).scale(1) < 1.8)
            DropdownButton<PerformanceRole>(
              key: const Key('performance-role-switcher'),
              value: state.currentRole,
              onChanged: (role) {
                if (role != null) c.changeRole(role);
              },
              items: PerformanceRole.values
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.name),
                    ),
                  )
                  .toList(),
            )
          else
            PopupMenuButton<PerformanceRole>(
              key: const Key('performance-role-switcher'),
              tooltip: 'Rol değiştir',
              icon: const Icon(Icons.manage_accounts),
              onSelected: c.changeRole,
              itemBuilder: (_) => PerformanceRole.values
                  .map(
                    (role) => PopupMenuItem(
                      value: role,
                      child: Text(role.name),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final overview = Column(
            children: [
              Container(
                key: const Key('performance-command-center'),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF008C95), Color(0xFF33C7C2)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PERFORMANCE COMMAND CENTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${metrics.totalAthletes} Sporcu • Hazır Olma: %${metrics.teamReadinessRate}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Değerlendirilen: ${metrics.assessedThisPeriod} • Hedef İlerlemesi: %${metrics.averageGoalCompletion} • Yük Uyarısı: ${metrics.workloadWarningsCount}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  key: const Key('performance-alerts-tile'),
                  title: Row(
                    children: [
                      const Icon(Icons.analytics, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Performans & Hedef Uyarilari (${state.alerts.length})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    if (state.alerts.isEmpty)
                      const ListTile(
                        title: Text('Aktif performans uyarısı yok.'),
                      )
                    else
                      for (final a in state.alerts)
                        ListTile(
                          key: Key('perf-alert-${a.id.value}'),
                          leading: Icon(
                            a.severity == PerformanceAlertSeverity.warning
                                ? Icons.warning
                                : Icons.info,
                            color:
                                a.severity == PerformanceAlertSeverity.warning
                                    ? Colors.amber
                                    : Colors.blue,
                          ),
                          title: Text(a.title),
                          subtitle: Text('${a.athleteName} • ${a.message}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () => c.dismissAlert(a.id),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );

          final directory = Column(
            children: [
              TextField(
                key: const Key('performance-search'),
                onChanged: c.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Sporcu, takım veya mevkii ara...',
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tümü'),
                      selected: state.filter.availability == null,
                      onSelected: (_) => c.filterAvailability(null),
                    ),
                    ...PerformanceAvailabilityStatus.values.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(_statusLabel(s)),
                          selected: state.filter.availability == s,
                          onSelected: (_) => c.filterAvailability(s),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  PopupMenuButton<PerformanceSort>(
                    key: const Key('performance-sort'),
                    tooltip: 'Aktif sıralama: ${state.sort.name}',
                    icon: const Icon(Icons.sort),
                    onSelected: c.setSort,
                    itemBuilder: (_) => PerformanceSort.values
                        .map(
                          (value) => PopupMenuItem(
                            value: value,
                            child: Text('Sırala: ${value.name}'),
                          ),
                        )
                        .toList(),
                  ),
                  PopupMenuButton<PerformanceGroup>(
                    key: const Key('performance-group'),
                    tooltip: 'Aktif gruplama: ${state.group.name}',
                    icon: const Icon(Icons.view_list),
                    onSelected: c.setGroup,
                    itemBuilder: (_) => PerformanceGroup.values
                        .map(
                          (value) => PopupMenuItem(
                            value: value,
                            child: Text('Grupla: ${value.name}'),
                          ),
                        )
                        .toList(),
                  ),
                  TextButton(
                    onPressed: c.resetFilters,
                    child: const Text('Filtreleri Sıfırla'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.filteredProfiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Eşleşen performans kaydı bulunamadı.',
                    key: Key('performance-empty'),
                  ),
                ),
              for (final p in state.filteredProfiles)
                Card(
                  child: ListTile(
                    key: Key('perf-profile-${p.id.value}'),
                    leading: _statusIcon(p.availability),
                    title: Text(p.athleteName),
                    subtitle: Text(
                      '${p.team} • Mevkii: ${p.position}\nHazır Olma: ${_statusLabel(p.availability)} • RPE Yükü: ${p.workloadRpe}/10${state.canViewPrivateWellness ? ' • Wellness: ${p.wellnessScore}/5' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/performance-detail',
                      arguments: PerformanceDetailArgs(p.id),
                    ),
                  ),
                ),
            ],
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'PERFORMANS & GELİŞİM MERKEZİ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const Text(
                'Sporcu Gelişimi & Koçluk Analitiği',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              if (box.maxWidth >= 840)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: overview),
                    const SizedBox(width: 24),
                    Expanded(flex: 7, child: directory),
                  ],
                )
              else ...[
                overview,
                const SizedBox(height: 16),
                directory,
              ],
              const SizedBox(height: 16),
              _intelligenceCenter(context, state, c),
            ],
          );
        },
      ),
    );
  }

  Widget _intelligenceCenter(
    BuildContext context,
    PerformanceCenterState state,
    PerformanceController controller,
  ) {
    return Column(
      key: const Key('performance-intelligence-center'),
      children: [
        _tile('Takım Hazırlık Merkezi', 'performance-team-readiness', [
          ListTile(
            title: Text(
              'Operasyonel uygunluk: %${state.metrics.teamReadinessRate}',
            ),
            subtitle: const Text(
              'Kaynak: Screen 12 operasyonel durumları • Tanı, tedavi ve özel klinik not içermez • Kadro seçimi üretmez',
            ),
          ),
        ]),
        _tile('Şeffaf Boyut & Yük Tanımları', 'performance-dimensions', [
          for (final dimension in state.dimensions)
            ListTile(
              title: Text('${dimension.name} • ${dimension.unit}'),
              subtitle: Text(
                '${dimension.description}\nFormül: ${dimension.calculation} • Kaynak: ${dimension.source} • Sürüm: ${dimension.version} • Minimum örnek: ${dimension.minimumSample}',
              ),
            ),
        ]),
        _tile('Benchmark & Erişilebilir Tablo', 'performance-benchmarks', [
          for (final benchmark in state.benchmarks)
            ListTile(
              title: Text('${benchmark.metric} • ${benchmark.scope}'),
              subtitle: Text(
                '${benchmark.source} • n=${benchmark.sampleSize} • ${benchmark.lowerBound}-${benchmark.upperBound} • Sürüm ${benchmark.version}',
              ),
            ),
        ]),
        Card(
          key: const Key('performance-interactive-chart'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hedef İlerleme Görselleştirmesi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Metrik: hedef ilerlemesi (%) • Dönem: aktif plan • Kaynak: koçluk planı • Tazelik: fixture • Veri kalitesi: doğrulandı',
                ),
                for (final profile in state.filteredProfiles)
                  Semantics(
                    label:
                        '${profile.athleteName} hedef ilerlemesi yüzde ${profile.activeGoals.isEmpty ? 0 : profile.activeGoals.first.currentProgressPercent}',
                    child: ListTile(
                      title: Text(profile.athleteName),
                      subtitle: LinearProgressIndicator(
                        value: profile.activeGoals.isEmpty
                            ? 0
                            : profile.activeGoals.first.currentProgressPercent /
                                100,
                      ),
                      trailing: Text(
                        '%${profile.activeGoals.isEmpty ? 0 : profile.activeGoals.first.currentProgressPercent.toStringAsFixed(0)}',
                      ),
                    ),
                  ),
                const Text(
                  'Tablo alternatifi: Sporcu adı ve kesin ilerleme değeri yukarıdaki satırlarda sunulur.',
                  key: Key('performance-chart-table-alternative'),
                ),
              ],
            ),
          ),
        ),
        _tile('Gelişim Planı & Kilometre Taşları', 'performance-milestones', [
          for (final milestone in state.milestones)
            ListTile(
              title: Text(milestone.title),
              subtitle: Text(
                '${milestone.status.name} • ${milestone.targetDate.toString().split(' ').first} • ${milestone.owner} • Kanıt: ${milestone.evidence}',
              ),
            ),
        ]),
        _tile('Deterministik Koçluk İçgörüleri', 'performance-insights', [
          for (final insight in state.insights)
            ListTile(
              title: Text(insight.reason),
              subtitle: Text(
                '${insight.source} • ${insight.period} • Veri kalitesi: ${insight.quality.name}\nGüvenli sonraki adım: ${insight.safeNextAction}',
              ),
            ),
        ]),
        _tile('İş Akışları', 'performance-workflows', [
          ListTile(
            title: const Text('Takım Performans Detayı'),
            onTap: () => Navigator.pushNamed(
              context,
              '/performance-team-detail',
              arguments: TeamPerformanceArgs(state.teams.first.id),
            ),
          ),
          ListTile(
            title: const Text('Test Oturumu'),
            trailing: state.permissions.canManageTests
                ? IconButton(
                    tooltip: 'Test oturumu oluştur',
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/performance-test-session-editor',
                      arguments: const TestSessionEditorArgs(),
                    ),
                    icon: const Icon(Icons.add),
                  )
                : null,
            onTap: () => Navigator.pushNamed(
              context,
              '/performance-test-session',
              arguments: TestSessionArgs(state.testSessions.first.id),
            ),
          ),
          ListTile(
            title: const Text('Gelişim Planı'),
            trailing: state.permissions.canManageGoals
                ? IconButton(
                    tooltip: 'Gelişim planını düzenle',
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/performance-development-plan-editor',
                      arguments: DevelopmentPlanEditorArgs(
                        planId: state.plans.first.id,
                      ),
                    ),
                    icon: const Icon(Icons.edit),
                  )
                : null,
            onTap: () => Navigator.pushNamed(
              context,
              '/performance-development-plan',
              arguments: DevelopmentPlanArgs(state.plans.first.id),
            ),
          ),
          ListTile(
            title: const Text('İnceleme Oturumu'),
            trailing: state.permissions.canAssessSkills
                ? IconButton(
                    tooltip: 'İnceleme oturumu oluştur',
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/performance-review-session-editor',
                      arguments: const ReviewSessionEditorArgs(),
                    ),
                    icon: const Icon(Icons.add),
                  )
                : null,
            onTap: () => Navigator.pushNamed(
              context,
              '/performance-review-session',
              arguments: ReviewSessionArgs(state.reviewSessions.first.id),
            ),
          ),
          ListTile(
            title: const Text('Maç Performansı'),
            onTap: () => Navigator.pushNamed(
              context,
              '/performance-match-detail',
              arguments: MatchPerformanceArgs(state.matches.first.id),
            ),
          ),
          ListTile(
            title: const Text('Antrenman Performansı'),
            onTap: () => Navigator.pushNamed(
              context,
              '/performance-training-detail',
              arguments: TrainingPerformanceArgs(state.training.first.id),
            ),
          ),
          ListTile(
            title: const Text('Pozisyon Analizi'),
            onTap: () => Navigator.pushNamed(
              context,
              '/performance-position-detail',
              arguments: PositionAnalysisArgs(state.positions.first.id),
            ),
          ),
          for (final evaluation in state.evaluations)
            ListTile(
              title: const Text('Koç Değerlendirmesi • İnsan Yargısı'),
              subtitle: Text(
                '${evaluation.evaluator} • ${evaluation.status.name}',
              ),
              trailing: state.permissions.canAssessSkills
                  ? TextButton(
                      onPressed: () =>
                          controller.publishEvaluation(evaluation.id),
                      child: const Text('Yayınla'),
                    )
                  : null,
            ),
          for (final self in state.selfAssessments)
            ListTile(
              title: const Text('Sporcu Öz Değerlendirmesi • Özel'),
              subtitle: Text('Sporcu bildirimi • ${self.status.name}'),
              trailing: state.currentRole == PerformanceRole.athlete
                  ? Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Taslağı düzenle',
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/performance-self-assessment-editor',
                            arguments: SelfAssessmentEditorArgs(
                              assessmentId: self.id,
                            ),
                          ),
                          icon: const Icon(Icons.edit),
                        ),
                        TextButton(
                          onPressed: () =>
                              controller.submitSelfAssessment(self.id),
                          child: const Text('Gönder'),
                        ),
                      ],
                    )
                  : null,
            ),
        ]),
        if (state.currentRole == PerformanceRole.auditor ||
            state.currentRole == PerformanceRole.performanceDirector ||
            state.currentRole == PerformanceRole.headCoach)
          _tile('Değiştirilemez Performans Denetimi', 'performance-audit', [
            for (final entry in state.audit.reversed)
              ListTile(
                title: Text('${entry.action} • ${entry.entity}'),
                subtitle: Text(
                  '${entry.actor} (${entry.role.name}) • ${entry.previousValue} → ${entry.newValue}\n${entry.reason} • ${entry.scope}',
                ),
              ),
          ]),
        if (state.permissions.canExportReports)
          Card(
            key: const Key('performance-export-center'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gizlilik Korumalı Demo Dışa Aktarma',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Gerçek dosya oluşturulmaz. Wellness, gizli koç notları ve tıbbi ayrıntılar dışlanır.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final format in PerformanceExportFormat.values)
                        OutlinedButton(
                          key: Key('performance-export-${format.name}'),
                          onPressed: () => controller.requestExport(format),
                          child: Text(format.name),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _tile(String title, String keyName, List<Widget> children) {
    return Card(
      child: ExpansionTile(
        key: Key(keyName),
        title: Text(title),
        children: children,
      ),
    );
  }

  String _statusLabel(PerformanceAvailabilityStatus s) {
    switch (s) {
      case PerformanceAvailabilityStatus.available:
        return 'Tam Hazır';
      case PerformanceAvailabilityStatus.limited:
        return 'Kısıtlı';
      case PerformanceAvailabilityStatus.unavailable:
        return 'Uygun Değil';
    }
  }

  Widget _statusIcon(PerformanceAvailabilityStatus s) {
    switch (s) {
      case PerformanceAvailabilityStatus.available:
        return const Icon(Icons.fitness_center, color: Colors.teal);
      case PerformanceAvailabilityStatus.limited:
        return const Icon(Icons.timelapse, color: Colors.orange);
      case PerformanceAvailabilityStatus.unavailable:
        return const Icon(Icons.block, color: Colors.red);
    }
  }
}

class PerformanceDetailScreen extends ConsumerWidget {
  final PerformanceDetailArgs? args;

  const PerformanceDetailScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceControllerProvider);

    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Geçersiz performans profili bağlantısı.')),
      );
    }

    final found = state.profiles.where((p) => p.id == args!.athleteId);
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (found.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Performans profili bulunamadı.')),
      );
    }

    final p = found.single;
    final perms = state.permissions;

    return Scaffold(
      appBar: AppBar(title: Text('${p.athleteName} - Performans Dosyası')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            p.athleteName,
            key: const Key('performance-detail-name'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          Text('${p.team} • Mevkii: ${p.position}'),
          Text('Antrenman RPE Yükü: ${p.workloadRpe}/10'),
          if (state.canViewPrivateWellness)
            Text(
              'Özel wellness öz bildirimi: ${p.wellnessScore}/5',
              key: const Key('private-wellness'),
            ),
          const SizedBox(height: 12),
          _section(
            'Fiziksel Test Sonuçları',
            p.physicalTests.map(
              (t) => ListTile(
                leading: Icon(
                  Icons.speed,
                  color: t.isPersonalBest ? Colors.green : Colors.grey,
                ),
                title: Text('${t.testName} (${t.category})'),
                subtitle: Text(
                  'Skor: ${t.score} ${t.unit} • Rekor: ${t.isPersonalBest}\nTest Tarihi: ${t.testDate.toString().split(' ')[0]} • Test Eden: ${t.assessor}',
                ),
              ),
            ),
          ),
          _section(
            'Teknik & Taktik Değerlendirmeler',
            [
              ...p.technicalSkills.map(
                (s) => ListTile(
                  leading: const Icon(Icons.sports_soccer),
                  title: Text('${s.skillName} (Teknik: ${s.rating}/5)'),
                  subtitle: Text('${s.comments}\nDeğerlendiren: ${s.assessor}'),
                ),
              ),
              ...p.tacticalAssessments.map(
                (tac) => ListTile(
                  leading: const Icon(Icons.alt_route),
                  title: Text('${tac.area} (Taktik: ${tac.rating}/5)'),
                  subtitle: Text(
                    '${tac.comments}\nMaç: ${tac.matchContext} • Değerlendiren: ${tac.assessor}',
                  ),
                ),
              ),
            ],
          ),
          _section(
            'Bireysel Gelişim Planı (IDP Target Goals)',
            p.activeGoals.map(
              (g) => ListTile(
                leading: Icon(
                  g.status == GoalStatus.atRisk ? Icons.warning : Icons.flag,
                  color:
                      g.status == GoalStatus.atRisk ? Colors.red : Colors.green,
                ),
                title: Text(g.title),
                subtitle: Text(
                  'Kategori: ${g.category} • İlerleme: %${g.currentProgressPercent.toStringAsFixed(0)}\nDurum: ${g.status.name} • Hedef Tarih: ${g.targetDate.toString().split(' ')[0]}',
                ),
              ),
            ),
          ),
          if (perms.canViewInternalCoachNotes &&
              p.confidentialCoachNotes != null)
            Card(
              color: Colors.teal.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock, color: Colors.teal),
                        SizedBox(width: 8),
                        Text(
                          'Dahili Koç Değerlendirme Notları (Gizli)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.confidentialCoachNotes!,
                      key: const Key('confidential-coach-notes'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, Iterable<Widget> children) {
    return Card(
      child: ExpansionTile(
        title: Text(title),
        children: children.isEmpty
            ? const [ListTile(title: Text('Kayıt bulunmuyor.'))]
            : children.toList(),
      ),
    );
  }
}
