import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../../app/widgets/status_pill.dart';

/// Tesis doluluğu.
///
/// Sol tarafta tesisler, sağda seçili tesisin haftalık programı. Amaç tek bir
/// soruyu hızlı yanıtlamak: "salon perşembe akşamı boş mu?" Mobilde bu, tesis
/// tesis gezip takvime bakmayı gerektiriyor.
class FacilitiesScreen extends ConsumerStatefulWidget {
  const FacilitiesScreen({super.key});

  @override
  ConsumerState<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends ConsumerState<FacilitiesScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final facilities = ref.watch(facilitiesProvider);
    final load = ref.watch(facilityLoadProvider);

    return facilities.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xxl),
          child: SelectableText('Tesisler yüklenemedi: $e',
              textAlign: TextAlign.center, style: t.textTheme.bodySmall),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                'Kulübe tanımlı tesis yok.\nTesis eklendiğinde doluluk ve '
                'çakışma kontrolü burada görünür.',
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall,
              ),
            ),
          );
        }

        final selected = _selectedId ?? list.first.id;
        final loadMap = {
          for (final l in load.valueOrNull ?? const []) l.facilityId: l,
        };

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 300,
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: t.colorScheme.outline),
                itemBuilder: (_, i) {
                  final f = list[i];
                  final l = loadMap[f.id];
                  final isSelected = f.id == selected;

                  return InkWell(
                    onTap: () => setState(() => _selectedId = f.id),
                    child: Container(
                      padding: const EdgeInsets.all(ConsoleDensity.lg),
                      color: isSelected
                          ? t.colorScheme.primary.withValues(alpha: .08)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name,
                                    style: t.textTheme.bodyMedium?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500)),
                                if (f.kind != null)
                                  Text(f.kind!,
                                      style: t.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          if (l != null)
                            StatusPill(
                              label: '${l.eventCount} etkinlik · %'
                                  '${l.loadPercent}',
                              // Doluluk yükseldikçe uyarı tonuna geçiyor;
                              // %80 üstü tesis planlamada dikkat ister.
                              tone: switch (l.loadPercent) {
                                >= 80 => PillTone.warning,
                                0 => PillTone.muted,
                                _ => PillTone.info,
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            VerticalDivider(width: 1, color: t.colorScheme.outline),
            Expanded(child: _Schedule(facilityId: selected)),
          ],
        );
      },
    );
  }
}

class _Schedule extends ConsumerWidget {
  const _Schedule({required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final async = ref.watch(facilityScheduleProvider(facilityId));

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xxl),
          child: SelectableText('Program yüklenemedi: $e',
              textAlign: TextAlign.center, style: t.textTheme.bodySmall),
        ),
      ),
      data: (slots) {
        if (slots.isEmpty) {
          return Center(
            child: Text('Bu tesiste planlanmış etkinlik yok.',
                style: t.textTheme.bodySmall),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(ConsoleDensity.lg),
          itemCount: slots.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: t.colorScheme.outline),
          itemBuilder: (_, i) {
            final s = slots[i];
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(_dateTime(s.startsAt),
                        style: t.textTheme.bodySmall),
                  ),
                  Expanded(
                      child: Text(s.title, style: t.textTheme.bodyMedium)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _dateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
