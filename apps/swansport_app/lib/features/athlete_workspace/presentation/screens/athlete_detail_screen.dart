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
  int _selectedTab = 0;

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
                      subtitle: a.position ?? 'Okçuluk Branşı',
                      showBack: true,
                      onBack: () => Navigator.maybePop(context),
                      actions: [
                        IconButton(
                          icon: Icon(Icons.share_outlined,
                              size: 20, color: c.ink),
                          onPressed: () {},
                        ),
                      ],
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

                          // Linked Guardian Section
                          if (needsGuardian)
                            _buildGuardianCard(c, a.id)
                          else
                            _buildLinkedGuardianSuccess(c, a.id),
                          const SizedBox(height: 14),

                          // 3 Clean Quick Metric Badges
                          Row(
                            children: [
                              _buildMetricTile(
                                c,
                                'Katılım',
                                '%96',
                                'Son 30 Gün',
                                Icons.check_circle_outline,
                                c.accent,
                              ),
                              const SizedBox(width: 8),
                              _buildMetricTile(
                                c,
                                'Antrenman',
                                '24',
                                'Tamamlanan',
                                Icons.fitness_center_outlined,
                                c.inkMuted,
                              ),
                              const SizedBox(width: 8),
                              _buildMetricTile(
                                c,
                                'Aidat',
                                'Güncel',
                                'Borçsuz',
                                Icons.verified_outlined,
                                c.accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Performance & Archery Score Highlight
                          _buildPerformanceHighlight(c),
                          const SizedBox(height: 16),

                          // Segmented Tabs
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _buildTabButton(0, 'Gelişim & Devam', c),
                                _buildTabButton(1, 'Ekipman Ayarları', c),
                                _buildTabButton(2, 'Belgeler & İzinler', c),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Tab Content
                          _buildTabContent(c, a),
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
                            a.position ?? 'Klasik Yay U18',
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
                          ': ${a.license ?? 'Lisanssız'} • Yaş: ${a.age ?? '—'}',
                          style: SwanType.caption(c.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Strictly Privacy-Safe Health Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sağlık Durumu: Müsabakaya Uygun',
                            style: SwanType.caption(
                              c.accent,
                              w: FontWeight.w700,
                            ),
                          ),
                        ],
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
                          'Bağlı Veli Hesabı',
                          style:
                              SwanType.caption(c.inkMuted, w: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Onaylı',
                            style: SwanType.caption(
                              c.accent,
                              w: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Veli Hesabı Aktif (SMS + Push Bildirimleri Açık)',
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

  Widget _buildMetricTile(
    SwanPalette c,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line.withValues(alpha: .5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: SwanType.caption(c.inkMuted)),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: SwanType.h2(c.ink)),
            const SizedBox(height: 2),
            Text(subtitle, style: SwanType.caption(c.inkMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceHighlight(SwanPalette c) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Atış & Skor Ortalaması',
                style: SwanType.bodySm(c.ink, w: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '70 Metre Açık Saha',
                  style: SwanType.caption(
                    c.accent,
                    w: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.accent, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '9.4',
                  style: SwanType.h2(c.accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ortalama Ok Skoru (10.0 skala)',
                      style: SwanType.caption(c.ink, w: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.arrow_upward, size: 13, color: c.accent),
                        const SizedBox(width: 2),
                        Text(
                          '+%4.2 artış (son ay)',
                          style: SwanType.caption(
                            c.accent,
                            w: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Son Seri', style: SwanType.caption(c.inkMuted)),
                  Text(
                    '672 Puan',
                    style: SwanType.bodySm(
                      c.accent,
                      w: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, SwanPalette c) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: SwanType.caption(
              isSelected ? c.accent : c.inkMuted,
              w: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(SwanPalette c, AthleteFull a) {
    if (_selectedTab == 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line.withValues(alpha: .5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Son Devam & Antrenman Kayıtları',
                style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
            const SizedBox(height: 8),
            _buildHistoryItem(
                c, '14 Nisan 2025', 'Sabah Seansı (70m)', 'Katıldı', c.accent),
            _buildHistoryItem(
                c, '12 Nisan 2025', 'Kondisyon & Güç', 'Katıldı', c.accent),
            _buildHistoryItem(
                c, '10 Nisan 2025', 'Ok Simülasyonu', 'İzinli', c.warning),
          ],
        ),
      );
    } else if (_selectedTab == 1) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line.withValues(alpha: .5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tuning & Ekipman Notları',
                style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Yay: Hoyt Formula Xi (25" Gövde, 42# Kanat)',
                style: SwanType.caption(c.ink)),
            const SizedBox(height: 4),
            Text('Ok: Easton X10 500 Spine (120gr Tungsten Uç)',
                style: SwanType.caption(c.ink)),
            const SizedBox(height: 4),
            Text('Nişangah: Shibuya Ultima CPX II Carbon',
                style: SwanType.caption(c.inkMuted)),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line.withValues(alpha: .5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kayıtlı Belgeler & Veli İzinleri',
                style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
            const SizedBox(height: 8),
            _buildHistoryItem(
                c, '2025 Sezonu', 'Sağlık Raporu Belgesi', 'Onaylı', c.accent),
            _buildHistoryItem(c, 'Turnuva İzni',
                'Bahar Şampiyonası Veli Muvafakatı', 'İmzalandı', c.accent),
          ],
        ),
      );
    }
  }

  Widget _buildHistoryItem(
      SwanPalette c, String date, String title, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SwanType.caption(c.ink, w: FontWeight.w600)),
              Text(date, style: SwanType.caption(c.inkMuted)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: SwanType.caption(color, w: FontWeight.w700),
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
