import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';

/// Sporcunun antrenman algılanan zorluk derecesi (RPE) ve hazırbulunuşluk takibi.
///
/// Veriler doğrudan Supabase `training_self_assessments` ve `my_training_history`
/// servisleri üzerinden okunur ve kaydedilir.
class ReadinessRpeScreen extends ConsumerStatefulWidget {
  const ReadinessRpeScreen({super.key});

  @override
  ConsumerState<ReadinessRpeScreen> createState() => _ReadinessRpeScreenState();
}

class _ReadinessRpeScreenState extends ConsumerState<ReadinessRpeScreen> {
  static const List<String> _availableTags = [
    'Yorgunluk',
    'Kas Ağrısı',
    'Uykusuzluk',
    'Stres',
    'Yüksek Enerji',
    'Odaklanma Tam',
    'Dehidrasyon',
    'Hafif Sancı',
  ];

  static String _rpeLabel(int rpe) {
    switch (rpe) {
      case 1:
        return 'Çok Çok Kolay';
      case 2:
        return 'Çok Kolay';
      case 3:
        return 'Kolay';
      case 4:
        return 'Orta';
      case 5:
        return 'Hafif Zor';
      case 6:
        return 'Zor';
      case 7:
        return 'Çok Zor';
      case 8:
        return 'Ağır / Sert';
      case 9:
        return 'Aşırı Zor';
      case 10:
        return 'Maksimum Efor';
      default:
        return 'Belirlenmedi';
    }
  }

  static Color _rpeColor(int rpe, SwanPalette c) {
    if (rpe <= 3) return const Color(0xFF10B981); // Yeşil
    if (rpe <= 5) return c.accent; // Teal / Mavi
    if (rpe <= 7) return const Color(0xFFF59E0B); // Turuncu
    return c.danger; // Kırmızı
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final historyAsync = ref.watch(myTrainingHistoryProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myTrainingHistoryProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    SwanSpace.lg,
                    SwanSpace.md,
                    SwanSpace.lg,
                    120,
                ),
                children: [
                  SwanPageHeader(
                    title: 'Hazırbulunuşluk & RPE',
                    subtitle: 'Antrenman zorluk ve toparlanma takibi',
                    onBack: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(height: SwanSpace.md),
                  historyAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(SwanSpace.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                        border: Border.all(color: c.line),
                      ),
                      child: Text(
                        'Kayıtlar yüklenemedi: $err',
                        style: SwanType.caption(c.danger),
                      ),
                    ),
                    data: (history) {
                      final ratedSessions =
                          history.where((s) => s.rpe != null).toList();
                      final double? avgRpe = ratedSessions.isEmpty
                          ? null
                          : ratedSessions
                                  .map((s) => s.rpe!)
                                  .reduce((a, b) => a + b) /
                              ratedSessions.length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(c, avgRpe, ratedSessions.length),
                          const SizedBox(height: SwanSpace.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Antrenman Seansları', style: SwanType.h3(c.ink)),
                              Text(
                                '${history.length} kayıt',
                                style: SwanType.caption(c.inkMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: SwanSpace.sm),
                          if (history.isEmpty)
                            _buildEmptyCard(c)
                          else
                            ...history.map(
                              (entry) => _buildSessionTile(
                                context: context,
                                c: c,
                                entry: entry,
                                profileId: profile?.id,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildSummaryCard(SwanPalette c, double? avgRpe, int ratedCount) {
    final statusText = avgRpe == null
        ? 'Henüz değerlendirme yok'
        : avgRpe <= 4
            ? 'Toparlanma İyi • Düşük Yük'
            : avgRpe <= 7
                ? 'Dengeli Antrenman Yükü'
                : 'Yüksek Yük • Dinlenme Önerilir';

    final statusColor = avgRpe == null
        ? c.inkMuted
        : _rpeColor(avgRpe.round(), c);

    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ortalama Yük Derecesi',
                    style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        avgRpe != null
                            ? avgRpe.toStringAsFixed(1)
                            : '--',
                        style: SwanType.h1(statusColor),
                      ),
                      const SizedBox(width: 4),
                      Text('/ 10 RPE', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: SwanSpace.sm,
                    vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: SwanType.caption(statusColor, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          Divider(color: c.line, height: 1),
          const SizedBox(height: SwanSpace.md),
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: c.accent),
              const SizedBox(width: SwanSpace.xs),
              Expanded(
                child: Text(
                  '$ratedCount antrenman puanlandı. RPE (Algılanan Zorluk Derecesi) antrenman yükünüzü dengede tutarak sakatlık riskini minimize eder.',
                  style: SwanType.caption(c.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.xl),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center_rounded, size: 36, color: c.inkMuted),
          const SizedBox(height: SwanSpace.sm),
          Text(
            'Henüz antrenman oturumu bulunmuyor',
            style: SwanType.bodySm(c.ink, w: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Bir antrenman tamamladığında buraya gelip zorluk puanı ve toparlanma durumunu girebilirsin.',
            textAlign: TextAlign.center,
            style: SwanType.caption(c.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile({
    required BuildContext context,
    required SwanPalette c,
    required TrainingHistoryEntry entry,
    required String? profileId,
  }) {
    final hasRpe = entry.rpe != null;
    final rpeVal = entry.rpe ?? 5;
    final rpeColor = _rpeColor(rpeVal, c);

    final dateStr =
        '${entry.startedAt.day}.${entry.startedAt.month}.${entry.startedAt.year} · ${entry.startedAt.hour.toString().padLeft(2, '0')}:${entry.startedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasRpe ? rpeColor.withValues(alpha: 0.12) : c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            alignment: Alignment.center,
            child: hasRpe
                ? Text(
                    '$rpeVal',
                    style: SwanType.h3(rpeColor),
                  )
                : Icon(Icons.speed_rounded, size: 22, color: c.inkMuted),
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.protocolName.isNotEmpty
                            ? entry.protocolName
                            : 'Antrenman Seansı',
                        style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.kindLabel,
                        style: SwanType.caption(c.inkMuted, w: FontWeight.w600)
                            .copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: SwanType.caption(c.inkMuted),
                ),
                if (hasRpe) ...[
                  const SizedBox(height: 4),
                  Text(
                    _rpeLabel(rpeVal),
                    style: SwanType.caption(rpeColor, w: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: SwanSpace.sm),
          OutlinedButton(
            onPressed: () => _openAssessmentModal(context, entry, profileId),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              side: BorderSide(color: hasRpe ? c.line : c.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              hasRpe ? 'Düzenle' : 'Puanla',
              style: SwanType.caption(
                hasRpe ? c.ink : c.accent,
                w: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAssessmentModal(
    BuildContext context,
    TrainingHistoryEntry entry,
    String? profileId,
  ) async {
    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değerlendirme için sporcu profili gereklidir.')),
      );
      return;
    }

    final athlete = await ref.read(athleteByProfileProvider(profileId).future);
    if (athlete == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıtlı sporcu profili bulunamadı.')),
      );
      return;
    }

    if (!context.mounted) return;

    // Mevcut değerlendirmeyi oku
    final existing = await ref
        .read(trainingSessionServiceProvider)
        .getAssessment(sessionId: entry.sessionId, athleteId: athlete.id);

    if (!context.mounted) return;

    int selectedRpe = existing?.rpe ?? entry.rpe ?? 6;
    final Set<String> selectedTags = Set.from(existing?.tags ?? []);
    final noteController = TextEditingController(text: existing?.note ?? '');
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final c = context.swan;
            final rpeColor = _rpeColor(selectedRpe, c);

            return Container(
              padding: EdgeInsets.fromLTRB(
                SwanSpace.lg,
                SwanSpace.lg,
                SwanSpace.lg,
                MediaQuery.of(ctx).viewInsets.bottom + SwanSpace.xl,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: SwanSpace.md),
                    Text(
                      'RPE & Durum Değerlendirmesi',
                      style: SwanType.h2(c.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.protocolName.isNotEmpty
                          ? entry.protocolName
                          : 'Antrenman Seansı',
                      style: SwanType.caption(c.inkMuted),
                    ),
                    const SizedBox(height: SwanSpace.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Algılanan Zorluk (RPE):',
                          style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                        ),
                        Text(
                          '$selectedRpe / 10 · ${_rpeLabel(selectedRpe)}',
                          style: SwanType.bodySm(rpeColor, w: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: SwanSpace.xs),
                    Slider(
                      value: selectedRpe.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: rpeColor,
                      inactiveColor: c.surfaceAlt,
                      onChanged: (val) {
                        setModalState(() {
                          selectedRpe = val.round();
                        });
                      },
                    ),
                    const SizedBox(height: SwanSpace.md),
                    Text(
                      'Hazırbulunuşluk & Toparlanma Faktörleri:',
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                    ),
                    const SizedBox(height: SwanSpace.xs),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableTags.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          selectedColor: c.accent.withValues(alpha: 0.15),
                          checkmarkColor: c.accent,
                          labelStyle: SwanType.caption(
                            isSelected ? c.accent : c.ink,
                            w: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          backgroundColor: c.surfaceAlt,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? c.accent : c.line,
                            ),
                          ),
                          onSelected: (checked) {
                            setModalState(() {
                              if (checked) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: SwanSpace.md),
                    Text(
                      'Notlar (Opsiyonel):',
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                    ),
                    const SizedBox(height: SwanSpace.xs),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Nasıl hissettin? Antrenman içi notların...',
                        hintStyle: SwanType.caption(c.inkMuted),
                        filled: true,
                        fillColor: c.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                      ),
                      style: SwanType.bodySm(c.ink),
                    ),
                    const SizedBox(height: SwanSpace.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                try {
                                  await ref
                                      .read(trainingSessionServiceProvider)
                                      .saveAssessment(
                                        sessionId: entry.sessionId,
                                        athleteId: athlete.id,
                                        rpe: selectedRpe,
                                        tags: selectedTags.toList(),
                                        note: noteController.text.trim().isEmpty
                                            ? null
                                            : noteController.text.trim(),
                                      );

                                  ref.invalidate(myTrainingHistoryProvider);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('RPE ve değerlendirme kaydedildi.'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Kayıt başarısız: $e'),
                                        backgroundColor: c.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Değerlendirmeyi Kaydet',
                                style: SwanType.bodySm(
                                  Colors.white,
                                  w: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

