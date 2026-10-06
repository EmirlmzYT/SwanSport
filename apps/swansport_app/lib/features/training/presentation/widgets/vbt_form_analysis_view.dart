import 'package:flutter/material.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';

/// Stitch Screen 9: SwanSport - Antrenman & Form Analiz Detayı.
/// Optik bar izleme (VBT), açı analizi, tekrar seçici zaman çizelgesi ve biyomekanik kas yük dağılımı.
class VbtFormAnalysisView extends StatefulWidget {
  const VbtFormAnalysisView({
    super.key,
    this.exerciseTitle = 'Barbell Back Squat',
    this.exerciseSubtitle = '140kg × 5 Tekrar • Teknik & Bar Hızı Analizi',
  });

  final String exerciseTitle;
  final String exerciseSubtitle;

  @override
  State<VbtFormAnalysisView> createState() => _VbtFormAnalysisViewState();
}

class _VbtFormAnalysisViewState extends State<VbtFormAnalysisView> {
  int _selectedRepIndex = 4; // 1-5
  bool _isSaved = false;
  double _playbackSpeed = 1.0;

  final List<_RepData> _reps = [
    _RepData(repIndex: 1, velocity: '0.74 m/s', depth: '91°', balance: '50L/50R', speedDelta: '+0.06'),
    _RepData(repIndex: 2, velocity: '0.71 m/s', depth: '92°', balance: '51L/49R', speedDelta: '+0.03'),
    _RepData(repIndex: 3, velocity: '0.69 m/s', depth: '93°', balance: '52L/48R', speedDelta: '+0.01'),
    _RepData(repIndex: 4, velocity: '0.62 m/s', depth: '92°', balance: '51L/49R', speedDelta: '-0.06'),
    _RepData(repIndex: 5, velocity: '0.58 m/s', depth: '94°', balance: '53L/47R', speedDelta: '-0.10'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final currentRep = _reps[_selectedRepIndex - 1];

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: palette.ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Antrenman Analizi',
          style: SwanType.h3(palette.ink),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, size: 20, color: palette.ink),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Form analizi raporu paylaşıldı.')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: palette.ink),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
              children: [
                // 1. Sub-Header Info Pill
                _buildSubHeader(palette),
                const SizedBox(height: 12),

                // 2. Exercise Title Card
                _buildExerciseTitleCard(palette),
                const SizedBox(height: 14),

                // 3. Video HUD Viewport with AR Overlay
                _buildVideoHud(palette, currentRep),
                const SizedBox(height: 16),

                // 4. Set Summary Bento
                _buildSetSummaryBento(palette),
                const SizedBox(height: 16),

                // 5. Coach & AI Feedback Card
                _buildCoachFeedbackCard(palette),
                const SizedBox(height: 16),

                // 6. Biomechanical Muscle Load Distribution
                _buildMuscleLoadCard(palette),
                const SizedBox(height: 20),
              ],
            ),

            // 7. Fixed Bottom Dock
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildBottomDock(palette),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sub-Header Info Pill ---
  Widget _buildSubHeader(SwanPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Elite VBT Telemetri Modülü',
              style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'AI ONAYLI',
                style: SwanType.caption(palette.accent, w: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSaved = !_isSaved;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isSaved
                        ? 'Egzersiz analizi kaydedildi.'
                        : 'Kayıt kaldırıldı.'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.line),
                ),
                child: Icon(
                  _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 18,
                  color: _isSaved ? palette.accent : palette.ink,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Exercise Title Card ---
  Widget _buildExerciseTitleCard(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AĞIR KUVVET SEANSI',
                style: SwanType.caption(palette.accent, w: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed_rounded,
                        size: 14, color: Color(0xFFFF7A59)),
                    const SizedBox(width: 4),
                    Text(
                      'VBT v3.2',
                      style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.exerciseTitle,
            style: SwanType.h2(palette.ink),
          ),
          const SizedBox(height: 4),
          Text(
            widget.exerciseSubtitle,
            style: SwanType.caption(palette.inkMuted),
          ),
        ],
      ),
    );
  }

  // --- Video HUD Viewport with AR Overlay ---
  Widget _buildVideoHud(SwanPalette palette, _RepData currentRep) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF020F1F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Video Frame & AR Overlay Stack
          SizedBox(
            height: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video Image Background
                Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCCGhOCLlC47l9DIa35YFmL-F5gey4OGU0HcQ7iWV68KxvuuGUnKkcSOIFPDqJ3A7CiuVJT4lbDD6NMgYF7r9F10w9nDz-DxUYCyJzbFyXkOqu4skxrOIotZOB8RvWUBqFMpK-fgf827Ye48-CmwSM8f4Ve7mYp4SyTNfcuvF59SuqNRQ1CE-6J5074jdDxe49eblIxkO9iPMGn_-9OuC0iBY9KxuT-LuFOZnkZ2sQqFcjT9XFYXXJR',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF0A1C2E),
                    child: Center(
                      child: Icon(Icons.fitness_center_rounded,
                          size: 48, color: palette.accent),
                    ),
                  ),
                ),

                // Scrim
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        const Color(0xFF020F1F).withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),

                // Custom AR Vector Path Overlay
                CustomPaint(
                  size: Size.infinite,
                  painter: _BarPathPainter(accentColor: palette.accent),
                ),

                // Top HUD Row
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFB4AB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'CANLI OPTİK İZLEME',
                              style: SwanType.caption(Colors.white,
                                      w: FontWeight.w700)
                                  .copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _playbackSpeed =
                                    _playbackSpeed == 1.0 ? 0.5 : 1.0;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.slow_motion_video_rounded,
                                      size: 14, color: palette.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_playbackSpeed}x',
                                    style: SwanType.caption(Colors.white,
                                        w: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fullscreen_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Overlaid Central Telemetry Chips
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: _hudChip(
                          icon: Icons.bolt_rounded,
                          iconColor: palette.accent,
                          label: 'BAR HIZI',
                          value: currentRep.velocity,
                          sub: '${currentRep.speedDelta} m/s',
                          subColor: palette.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _hudChip(
                          icon: Icons.straighten_rounded,
                          iconColor: const Color(0xFFFF7A59),
                          label: 'DERİNLİK',
                          value: currentRep.depth,
                          sub: 'Paralel Altı ✓',
                          subColor: palette.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _hudChip(
                          icon: Icons.balance_rounded,
                          iconColor: const Color(0xFFC0C6D9),
                          label: 'DENGE',
                          value: currentRep.balance,
                          sub: 'Örnek Simetri',
                          subColor: palette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Interactive 5-Rep Selector Strip
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF061424),
            child: Row(
              children: [
                for (final r in _reps)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRepIndex = r.repIndex;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedRepIndex == r.repIndex
                              ? palette.accent
                              : const Color(0xFF132031),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Tekrar ${r.repIndex}',
                              style: SwanType.caption(
                                _selectedRepIndex == r.repIndex
                                    ? Colors.white
                                    : Colors.white70,
                                w: FontWeight.w600,
                              ).copyWith(fontSize: 10),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.velocity.replaceAll(' m/s', ''),
                              style: SwanType.caption(
                                _selectedRepIndex == r.repIndex
                                    ? Colors.white
                                    : palette.accent,
                                w: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF132031).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF293547)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: SwanType.caption(Colors.white70).copyWith(fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: SwanType.bodySm(Colors.white, w: FontWeight.w800)
                .copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sub,
            style: SwanType.caption(subColor, w: FontWeight.w600)
                .copyWith(fontSize: 9),
          ),
        ],
      ),
    );
  }

  // --- Set Summary Bento ---
  Widget _buildSetSummaryBento(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: palette.accent),
                  const SizedBox(width: 6),
                  Text('Set Özeti', style: SwanType.h3(palette.ink)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Set 3 / 4',
                  style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _bentoTile(
                  palette,
                  icon: Icons.fitness_center_rounded,
                  iconColor: palette.accent,
                  label: 'YÜK',
                  value: '140',
                  unit: 'kg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _bentoTile(
                  palette,
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF7A59),
                  label: 'RPE SEVİYESİ',
                  value: '8.5',
                  unit: '/10',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _bentoTile(
                  palette,
                  icon: Icons.timer_rounded,
                  iconColor: const Color(0xFFC0C6D9),
                  label: 'DİNLENME',
                  value: '2:30',
                  unit: 'dk',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _bentoTile(
                  palette,
                  icon: Icons.storage_rounded,
                  iconColor: palette.accent,
                  label: 'TOPLAM TONAJ',
                  value: '700',
                  unit: 'kg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bentoTile(
    SwanPalette palette, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 9),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: SwanType.bodySm(palette.ink, w: FontWeight.w800)
                          .copyWith(fontSize: 16),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: SwanType.caption(palette.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Coach & AI Feedback Card ---
  Widget _buildCoachFeedbackCard(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy_rounded,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Koç & AI Geri Bildirimi',
                    style: SwanType.h3(palette.ink),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF293547),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded,
                          size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Mert Koç Onayladı',
                      style: SwanType.caption(palette.accent, w: FontWeight.w700)
                          .copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: SwanType.bodySm(palette.ink).copyWith(height: 1.5),
                    children: [
                      const TextSpan(
                          text: '“Mükemmel göğüs pozisyonu ve derinlik. '),
                      TextSpan(
                        text: '4. tekrarda',
                        style: TextStyle(
                            color: const Color(0xFFFF7A59),
                            fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                          text:
                              ' bar kalkış hızında hafif yavaşlama var (0.68 → 0.62 m/s), kalkışta kalça patlayıcılığına odaklan.”'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: palette.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Form Tutarlılığı: %94',
                          style: SwanType.caption(palette.inkMuted,
                              w: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: Color(0xFFFF7A59)),
                        const SizedBox(width: 4),
                        Text(
                          'Hız Kaybı: %21',
                          style: SwanType.caption(const Color(0xFFFF7A59),
                              w: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Biomechanical Muscle Load Card ---
  Widget _buildMuscleLoadCard(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.accessibility_new_rounded,
                      size: 18, color: palette.accent),
                  const SizedBox(width: 6),
                  Text('Hedef Kas Grupları & Yük',
                      style: SwanType.h3(palette.ink)),
                ],
              ),
              Text(
                'Biyomekanik Dağılım',
                style: SwanType.caption(palette.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Circular Donut Placeholder
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 0.65,
                      strokeWidth: 8,
                      backgroundColor: palette.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'DOMİNANT',
                          style: SwanType.caption(palette.inkMuted,
                                  w: FontWeight.w800)
                              .copyWith(fontSize: 8),
                        ),
                        Text(
                          'QUAD',
                          style: SwanType.bodySm(palette.accent,
                              w: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _muscleBar(palette,
                        name: 'Quadriceps (Diz Ekstansiyonu)',
                        percent: 65,
                        color: palette.accent),
                    const SizedBox(height: 8),
                    _muscleBar(palette,
                        name: 'Gluteus Maximus (Kalça)',
                        percent: 25,
                        color: const Color(0xFFFF7A59)),
                    const SizedBox(height: 8),
                    _muscleBar(palette,
                        name: 'Core & Spinal Erector',
                        percent: 10,
                        color: const Color(0xFFC0C6D9)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _muscleBar(
    SwanPalette palette, {
    required String name,
    required int percent,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  name,
                  style:
                      SwanType.caption(palette.ink, w: FontWeight.w600).copyWith(fontSize: 10),
                ),
              ],
            ),
            Text(
              '%$percent',
              style: SwanType.caption(color, w: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent / 100.0,
            minHeight: 4,
            backgroundColor: palette.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // --- Fixed Bottom Dock ---
  Widget _buildBottomDock(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Koç Mert Koç video analizi ile etiketlendi.')),
              );
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 18, color: palette.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Koça Soru İlet',
                    style: SwanType.caption(palette.ink, w: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('140kg x 5 Tekrar günlüğe başarıyla kaydedildi!')),
                );
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kTeal.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_task_rounded,
                        size: 20, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Antrenman Günlüğüne Ekle',
                      style: SwanType.bodySm(Colors.white, w: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepData {
  _RepData({
    required this.repIndex,
    required this.velocity,
    required this.depth,
    required this.balance,
    required this.speedDelta,
  });

  final int repIndex;
  final String velocity;
  final String depth;
  final String balance;
  final String speedDelta;
}

class _BarPathPainter extends CustomPainter {
  _BarPathPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Dynamic Spline of Bar Path
    final path = Path()
      ..moveTo(size.width * 0.51, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.45,
        size.width * 0.49,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.70,
        size.width * 0.50,
        size.height * 0.78,
      );

    // Glowing blur
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Reticle at bottom turnaround
    final bottomPoint = Offset(size.width * 0.50, size.height * 0.78);
    final outerCircle = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bottomPoint, 10, outerCircle);

    final innerCircle = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bottomPoint, 5, innerCircle);

    // Horizontal depth parallel line
    final depthLine = Paint()
      ..color = accentColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(bottomPoint.dx - 30, bottomPoint.dy),
      Offset(bottomPoint.dx + 30, bottomPoint.dy),
      depthLine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
