import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../../app/widgets/status_pill.dart';
import 'athletes_providers.dart';

/// Sporcu dosyası — masaüstü düzeni.
///
/// Mobilde bu bilgiler alt alta kaydırılıyor. Burada iki sütun: solda
/// değişmeyen kimlik bilgisi hep görünür kalıyor, sağda sekmeler arasında
/// gezilirken kime baktığın kaybolmuyor.
class AthleteDetailScreen extends ConsumerWidget {
  const AthleteDetailScreen({required this.athleteId, super.key});

  final String athleteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(athleteDetailProvider(athleteId));
    final t = Theme.of(context);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 26, color: t.colorScheme.error),
            const SizedBox(height: ConsoleDensity.md),
            Text('Sporcu yüklenemedi', style: t.textTheme.titleMedium),
            const SizedBox(height: ConsoleDensity.xs),
            SelectableText('$e', style: t.textTheme.bodySmall),
          ],
        ),
      ),
      data: (a) {
        if (a == null) {
          return Center(
            child: Text('Sporcu bulunamadı.', style: t.textTheme.titleMedium),
          );
        }
        return Column(
          children: [
            _Breadcrumb(name: a.fullName),
            Divider(height: 1, color: t.colorScheme.outline),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 320, child: _IdentityPane(athlete: a)),
                  VerticalDivider(width: 1, color: t.colorScheme.outline),
                  Expanded(child: _DetailTabs(athleteId: athleteId)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Kadroya dön',
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              onPressed: () => GoRouter.of(context).go('/sporcular'),
            ),
            const SizedBox(width: ConsoleDensity.xs),
            Text('Sporcular', style: t.textTheme.bodySmall),
            const SizedBox(width: ConsoleDensity.sm),
            Icon(Icons.chevron_right_rounded,
                size: 15, color: t.colorScheme.outline),
            const SizedBox(width: ConsoleDensity.sm),
            Text(name,
                style: t.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _IdentityPane extends StatelessWidget {
  const _IdentityPane({required this.athlete});

  final AthleteFull athlete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.colorScheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(athlete.initials,
                    style: t.textTheme.titleMedium
                        ?.copyWith(color: t.colorScheme.primary)),
              ),
              const SizedBox(width: ConsoleDensity.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(athlete.fullName, style: t.textTheme.titleMedium),
                    const SizedBox(height: ConsoleDensity.xs),
                    StatusPill(
                      label: athlete.isActive ? 'Aktif' : 'Pasif',
                      tone:
                          athlete.isActive ? PillTone.good : PillTone.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ConsoleDensity.xl),
          _field(t, 'MEVKİ', athlete.position ?? '—'),
          _field(t, 'YAŞ',
              athlete.age == null ? '—' : '${athlete.age}'),
          _field(
              t,
              'DOĞUM TARİHİ',
              athlete.birthDate == null
                  ? '—'
                  : _formatDate(athlete.birthDate!)),
          _field(t, 'LİSANS', athlete.license ?? '—'),
        ],
      ),
    );
  }

  Widget _field(ThemeData t, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: ConsoleDensity.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.textTheme.labelSmall),
            const SizedBox(height: 2),
            SelectableText(value, style: t.textTheme.bodyMedium),
          ],
        ),
      );
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

class _DetailTabs extends ConsumerWidget {
  const _DetailTabs({required this.athleteId});

  final String athleteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: t.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Performans'),
                Tab(text: 'Sağlık'),
                Tab(text: 'Başarılar'),
              ],
            ),
          ),
          Divider(height: 1, color: t.colorScheme.outline),
          Expanded(
            child: TabBarView(
              children: [
                _PerformanceTab(athleteId: athleteId),
                _InjuriesTab(athleteId: athleteId),
                _AchievementsTab(athleteId: athleteId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceTab extends ConsumerWidget {
  const _PerformanceTab({required this.athleteId});

  final String athleteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(testSeriesProvider(athleteId));
    final t = Theme.of(context);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _error(t, e),
      data: (series) {
        if (series.isEmpty) {
          return _empty(t, 'Bu sporcu için test kaydı yok.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(ConsoleDensity.lg),
          itemCount: series.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: t.colorScheme.outline),
          itemBuilder: (_, i) {
            final s = series[i];
            final latest = s.latest;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: t.textTheme.bodyMedium),
                        Text('${s.category} · ${s.records.length} ölçüm',
                            style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text('${latest.value} ${latest.unit}',
                        textAlign: TextAlign.right,
                        style: t.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(width: 110, child: _TrendCell(series: s)),
                  SizedBox(
                    width: 100,
                    child: Text(_formatDate(latest.testDate),
                        textAlign: TextAlign.right,
                        style: t.textTheme.bodySmall),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Son iki ölçüm arasındaki değişim.
///
/// Yön okla da veriliyor, yalnızca renkle değil: renk körlüğünde "iyileşti mi
/// kötüleşti mi" bilgisi kaybolmasın.
class _TrendCell extends StatelessWidget {
  const _TrendCell({required this.series});

  final TestSeries series;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final change = series.changePercent;
    if (change == null) {
      return Text('—',
          textAlign: TextAlign.right, style: t.textTheme.bodySmall);
    }

    final improved = series.improved;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(
          change > 0
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          size: 14,
        ),
        const SizedBox(width: 2),
        StatusPill(
          label: '${change.abs().toStringAsFixed(1)}%',
          tone: improved == null
              ? PillTone.muted
              : improved
                  ? PillTone.good
                  : PillTone.bad,
        ),
      ],
    );
  }
}

class _InjuriesTab extends ConsumerWidget {
  const _InjuriesTab({required this.athleteId});

  final String athleteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(injuriesProvider);
    final t = Theme.of(context);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _error(t, e),
      data: (all) {
        final mine = all.where((i) => i.athleteId == athleteId).toList();
        if (mine.isEmpty) {
          return _empty(t, 'Sağlık kaydı yok — sporcu sağlam görünüyor.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(ConsoleDensity.lg),
          itemCount: mine.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: t.colorScheme.outline),
          itemBuilder: (_, i) {
            final r = mine[i];
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: StatusPill(
                      label: r.statusLabel,
                      tone: switch (r.status) {
                        'injured' => PillTone.bad,
                        'pending' => PillTone.warning,
                        _ => PillTone.good,
                      },
                    ),
                  ),
                  const SizedBox(width: ConsoleDensity.md),
                  Expanded(
                      child: Text(r.note ?? '—',
                          style: t.textTheme.bodySmall)),
                  Text(_formatDate(r.createdAt),
                      style: t.textTheme.bodySmall),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AchievementsTab extends ConsumerWidget {
  const _AchievementsTab({required this.athleteId});

  final String athleteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(achievementsProvider(athleteId));
    final t = Theme.of(context);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _error(t, e),
      data: (list) {
        if (list.isEmpty) return _empty(t, 'Başarı kaydı yok.');
        return ListView.separated(
          padding: const EdgeInsets.all(ConsoleDensity.lg),
          itemCount: list.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: t.colorScheme.outline),
          itemBuilder: (_, i) {
            final a = list[i];
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: t.textTheme.bodyMedium),
                        if (a.location != null)
                          Text(a.location!, style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: a.placement == null
                        ? Text(a.category, style: t.textTheme.bodySmall)
                        : StatusPill(
                            label: a.placementLabel,
                            tone: a.isPodium
                                ? PillTone.good
                                : PillTone.muted,
                          ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      a.eventDate == null ? '—' : _formatDate(a.eventDate!),
                      textAlign: TextAlign.right,
                      style: t.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Widget _empty(ThemeData t, String message) => Center(
      child: Text(message, style: t.textTheme.bodySmall),
    );

Widget _error(ThemeData t, Object e) => Center(
      child: Padding(
        padding: const EdgeInsets.all(ConsoleDensity.xl),
        child: SelectableText('Yüklenemedi: $e',
            textAlign: TextAlign.center, style: t.textTheme.bodySmall),
      ),
    );
