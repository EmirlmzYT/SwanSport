import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/stitch_components.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../routing/athlete_detail_route_args.dart';
import '../widgets/official_athlete_cv.dart';

/// Sporcu Detayı — Stitch "Calm Athletic Modernism" Sporcu Detay & Veli Bağlantısı.
class AthleteDetailScreen extends ConsumerStatefulWidget {
  const AthleteDetailScreen({super.key, required this.args});

  const AthleteDetailScreen.invalidRoute({super.key}) : args = null;

  final AthleteDetailRouteArgs? args;

  @override
  ConsumerState<AthleteDetailScreen> createState() =>
      _AthleteDetailScreenState();
}

class _AthleteDetailScreenState extends ConsumerState<AthleteDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    final id = widget.args?.athleteId.value;
    final async = id == null
        ? const AsyncValue<AthleteFull?>.data(null)
        : ref.watch(athleteByIdProvider(id));

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: async.when(
              loading: () => premiumLoading(),
              error: (e, _) => premiumError(context, '$e'),
              data: (a) {
                if (a == null) {
                  return premiumEmpty(
                    context,
                    icon: Icons.person_off_rounded,
                    title: 'Sporcu bulunamadı',
                    subtitle: 'Bu profile ulaşılamadı.',
                  );
                }

                final needsGuardian =
                    ref.watch(needsGuardianProvider(a.id)).valueOrNull ?? false;

                return Column(
                  children: [
                    // Stitch Top Bar
                    SwanTopBar(
                      title: 'Sporcu Detayı',
                      subtitle: a.position ?? 'Sporcu',
                      showBack: true,
                      onBack: () => Navigator.maybePop(context),
                    ),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          SwanSpace.lg,
                          SwanSpace.md,
                          SwanSpace.lg,
                          130,
                        ),
                        children: [
                          // Athlete Hero Header Card
                          _buildAthleteHeroCard(c, a),
                          const SizedBox(height: 14),

                          OfficialAthleteCv(athleteId: a.id, includeClub: true),
                          const SizedBox(height: SwanSpace.xl),
                          // Linked Guardian Section
                          if (needsGuardian)
                            _buildGuardianCard(c, a.id)
                          else
                            _buildLinkedGuardianSuccess(c, a.id),
                          const SizedBox(height: 14),

                          ref.watch(athleteCardProvider(a.id)).when(
                                loading: () => const SizedBox.shrink(),
                                error: (e, _) => Text(
                                  'Özet yüklenemedi.',
                                  style: SwanType.bodySm(c.inkMuted),
                                ),
                                data: (card) => !card.hasData
                                    ? const SizedBox.shrink()
                                    : Wrap(
                                        spacing: SwanSpace.sm,
                                        runSpacing: SwanSpace.sm,
                                        children: [
                                          Chip(
                                            label: Text(
                                              '${card.trainings} antrenman',
                                            ),
                                          ),
                                          if (card.trainings > 0)
                                            Chip(
                                              label: Text(
                                                '%${card.attendancePct} katılım',
                                              ),
                                            ),
                                          Chip(
                                            label: Text(
                                              '${card.goalsDone} tamamlanan hedef',
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                          const SizedBox(height: SwanSpace.md),
                          if (ref.watch(
                            featureEnabledProvider(
                              FeatureFlags.developmentReport,
                            ),
                          ))
                            TextButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/gelisim-raporu',
                                arguments: {'id': a.id},
                              ),
                              icon: const Icon(Icons.insights_rounded),
                              label: const Text('Dönem gelişim raporu'),
                            ),
                          ListTile(
                            title: const Text('Testler ve gelişim hedefleri'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/sporcu-performans',
                              arguments: {'id': a.id, 'name': a.fullName},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildAthleteHeroCard(SwanPalette c, AthleteFull a) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line.withValues(alpha: .5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  border: Border.all(
                    color: c.accent.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  a.initials,
                  style: SwanType.h2(c.accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            a.fullName,
                            style: SwanType.h2(c.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            a.position ?? 'Sporcu',
                            style: SwanType.caption(
                              c.accent,
                              w: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Lisans',
                          style:
                              SwanType.caption(c.inkMuted, w: FontWeight.w600),
                        ),
                        Text(
                          a.license ?? 'Lisanssız',
                          style: SwanType.caption(c.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ref.watch(eligibilityProvider(a.id)).when(
                          loading: () => Text(
                            'Uygunluk kontrol ediliyor…',
                            style: SwanType.caption(c.inkMuted),
                          ),
                          error: (e, _) => Text(
                            'Uygunluk bilgisi alınamadı.',
                            style: SwanType.caption(c.inkMuted),
                          ),
                          data: (status) => Text(
                            'Uygunluk: ${status.badgeLabel}',
                            style: SwanType.caption(
                              status.blocked ? c.danger : c.inkMuted,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 15, color: c.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'KVKK gereği özel nitelikli tıbbi ve kişisel kayıtlar gizlenmiştir.',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianCard(SwanPalette c, String athleteId) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(
          color: c.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.family_restroom, size: 20, color: c.warning),
              const SizedBox(width: 8),
              Text(
                'Veli Hesabı Bağlı Değil',
                style: SwanType.bodySm(
                  c.warning,
                  w: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '18 yaş altı sporcularda yasal veli bağlantısı zorunludur. Tek kullanımlık davet kodu oluşturup veliyle paylaşın.',
            style: SwanType.caption(c.inkMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => _generateInvite(athleteId),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.warning,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
              ),
              icon: const Icon(Icons.key, size: 16),
              label: Text(
                'Veli Davet Kodu Üret',
                style: SwanType.caption(Colors.white, w: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedGuardianSuccess(SwanPalette c, String athleteId) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line.withValues(alpha: .5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Icon(Icons.family_restroom, color: c.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Veli bağlantısı',
                          style:
                              SwanType.caption(c.inkMuted, w: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Kontrol',
                            style: SwanType.caption(
                              c.accent,
                              w: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Veli bağlantısı gerekmiyor veya tamamlanmış.',
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () => _generateInvite(athleteId),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.accent,
                side: BorderSide(color: c.line.withValues(alpha: .5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
              ),
              icon: const Icon(Icons.key, size: 16),
              label: Text(
                'Veli Davet Kodu Üret',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateInvite(String athleteId) async {
    try {
      final code = await ref
          .read(verificationServiceProvider)
          .createGuardianInvite(athleteId);
      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final c = isDark ? SwanPalette.dark : SwanPalette.light;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanRadius.md),
          ),
          title: Text('Veli Davet Kodu', style: SwanType.h3(c.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bu kodu veliyle paylaşın. Veli uygulamadaki "Veli Bağla" ekranında bu kodu girerek sporcuya bağlanacaktır.',
                style: SwanType.caption(c.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  code,
                  style: SwanType.h1(c.accent),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '24 saat geçerli • Tek kullanımlık',
                style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Kapat', style: SwanType.caption(c.inkMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Davet kodu panoya kopyalandı'),
                    backgroundColor: c.accent,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Kodu Kopyala'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final c = isDark ? SwanPalette.dark : SwanPalette.light;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kod üretilemedi: $e'),
            backgroundColor: c.danger,
          ),
        );
      }
    }
  }
}
