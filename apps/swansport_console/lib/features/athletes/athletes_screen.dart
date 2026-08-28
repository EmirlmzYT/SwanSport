import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../../app/widgets/console_table.dart';
import '../../app/widgets/csv_export.dart';
import '../../app/widgets/status_pill.dart';
import 'athletes_providers.dart';

/// Kadro tablosu.
///
/// Konsolun mobil uygulamaya göre asıl kazancı burada görünüyor: mobilde
/// sporcular tek tek kartlar halinde kaydırılıyor, burada hepsi tek ekranda,
/// süzülebilir ve toplu işlenebilir.
class AthletesScreen extends ConsumerWidget {
  const AthletesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(athleteQueryProvider);
    final statusFilter = ref.watch(athleteStatusFilterProvider);
    final selection = ref.watch(athleteSelectionProvider);
    final page = ref.watch(athletePageProvider);
    final count = ref.watch(athleteCountProvider);

    final columns = _columns(context);

    return Column(
      children: [
        ConsoleToolbar(
          query: query,
          searchHint: 'Ad, soyad veya mevkiye göre ara…',
          onQueryChanged: (q) {
            ref.read(athleteQueryProvider.notifier).state = q;
          },
          filters: [
            _StatusFilter(
              value: statusFilter,
              onChanged: (v) {
                ref.read(athleteStatusFilterProvider.notifier).state = v;
                ref.read(athleteQueryProvider.notifier).state =
                    query.copyWith(page: 0);
              },
            ),
          ],
          onExport: () async {
            final all = await fetchAllAthletesForExport(ref);
            await downloadCsv(
              fileName: csvFileName('sporcular'),
              columns: columns,
              rows: all,
            );
          },
        ),
        Divider(height: 1, color: Theme.of(context).colorScheme.outline),
        Expanded(
          child: ConsoleTable<AthleteRow>(
            columns: columns,
            rows: page.valueOrNull ?? const [],
            loading: page.isLoading,
            error: page.hasError ? page.error : null,
            query: query,
            totalCount: count.valueOrNull ?? 0,
            rowId: (r) => r.id,
            emptyMessage: 'Bu kulüpte sporcu kaydı yok.',
            onQueryChanged: (q) {
              ref.read(athleteQueryProvider.notifier).state = q;
            },
            selected: selection,
            onSelectionChanged: (s) {
              ref.read(athleteSelectionProvider.notifier).state = s;
            },
            onRowTap: (r) => GoRouter.of(context).go('/sporcular/${r.id}'),
            bulkActions: [
              ConsoleBulkAction(
                label: 'Aktif yap',
                icon: Icons.play_circle_outline_rounded,
                onRun: () => _setStatus(context, ref, 'active'),
              ),
              ConsoleBulkAction(
                label: 'Pasife al',
                icon: Icons.pause_circle_outline_rounded,
                onRun: () => _setStatus(context, ref, 'inactive'),
                destructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Seçili sporcuların durumunu değiştirir — **çakışma kontrolüyle**.
  ///
  /// Tabloyu iki kişi aynı anda yönetebilir: sen konsolda kadroyu açtıktan
  /// sonra antrenör telefondan bir sporcuyu pasife alabilir. Kontrol olmadan
  /// senin toplu işlemin onu sessizce geri açardı. Burada, yazmadan hemen
  /// önce sunucuya "ben bu sayfayı yükledikten sonra değişen var mı?" diye
  /// soruluyor; varsa kullanıcı karar veriyor.
  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, String status) async {
    final ids = ref.read(athleteSelectionProvider).toList();
    if (ids.isEmpty) return;

    // context'e await sonrası dokunmamak için şimdi alıyoruz.
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final loadedAt = ref.read(athletePageLoadedAtProvider);

    try {
      final service = ref.read(athleteServiceProvider);

      final changed = await service.athletesChangedSince(ids, loadedAt);
      if (changed.isNotEmpty && context.mounted) {
        final proceed = await _confirmConflict(context, changed);
        if (proceed != true) {
          // Kullanıcı vazgeçti — tabloyu tazeleyip güncel hâli göstermek,
          // eski veriyle bırakmaktan iyi.
          ref
            ..invalidate(athletePageProvider)
            ..invalidate(athleteCountProvider);
          return;
        }
      }

      await service.setAthletesStatus(ids, status);
      ref
        ..invalidate(athletePageProvider)
        ..invalidate(athleteCountProvider)
        ..read(athleteSelectionProvider.notifier).state = {};
      messenger.showSnackBar(SnackBar(
        content: Text('${ids.length} sporcu güncellendi.'),
      ));
    } catch (e) {
      // Sunucu reddederse (RLS) kullanıcı bunu bilmeli — sessizce yutma.
      messenger.showSnackBar(SnackBar(
        content: Text('Güncellenemedi: $e'),
        backgroundColor: errorColor,
      ));
    }
  }

  Future<bool?> _confirmConflict(
      BuildContext context, List<AthleteRow> changed) {
    final t = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu kayıtlar sen bakarken değişti'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${changed.length} sporcu, sen bu sayfayı açtıktan sonra '
                'başka biri tarafından güncellendi. Devam edersen onların '
                'değişikliği senin işleminle değişecek.',
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: ConsoleDensity.lg),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in changed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(a.fullName,
                                    style: t.textTheme.bodyMedium)),
                            StatusPill(
                              label: a.isActive ? 'Aktif' : 'Pasif',
                              tone: a.isActive
                                  ? PillTone.good
                                  : PillTone.muted,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç, tabloyu tazele'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yine de uygula'),
          ),
        ],
      ),
    );
  }

  List<ConsoleColumn<AthleteRow>> _columns(BuildContext context) {
    final t = Theme.of(context);
    return [
      ConsoleColumn<AthleteRow>(
        label: 'Ad Soyad',
        sortKey: 'first_name',
        flex: 3,
        csv: (r) => r.fullName,
        cell: (r) => Row(
          children: [
            _Avatar(initials: r.initials),
            const SizedBox(width: ConsoleDensity.md),
            Flexible(
              child: Text(r.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
      ConsoleColumn<AthleteRow>(
        label: 'Mevki',
        sortKey: 'position',
        flex: 2,
        csv: (r) => r.position ?? '',
        cell: (r) => Text(r.position ?? '—',
            overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
      ),
      ConsoleColumn<AthleteRow>(
        label: 'Durum',
        sortKey: 'status',
        width: 120,
        csv: (r) => r.isActive ? 'Aktif' : 'Pasif',
        cell: (r) => StatusPill(
          label: r.isActive ? 'Aktif' : 'Pasif',
          tone: r.isActive ? PillTone.good : PillTone.muted,
        ),
      ),
      ConsoleColumn<AthleteRow>(
        label: '',
        width: 40,
        cell: (r) => Icon(Icons.chevron_right_rounded,
            size: 18, color: t.colorScheme.outline),
      ),
    ];
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isDense: true,
        decoration: const InputDecoration(labelText: 'Durum'),
        items: const [
          DropdownMenuItem(value: null, child: Text('Hepsi')),
          DropdownMenuItem(value: 'active', child: Text('Aktif')),
          DropdownMenuItem(value: 'inactive', child: Text('Pasif')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(initials,
          style: t.textTheme.labelSmall
              ?.copyWith(color: t.colorScheme.primary, letterSpacing: 0)),
    );
  }
}
