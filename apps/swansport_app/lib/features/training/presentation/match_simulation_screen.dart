import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Müsabaka Simülasyonu ve Eleme Maçı (FITA Set Sistemi - Best of 5).
///
/// Stitch "m_sabaka_sim_lasyonu_ve_eleme_ma" tasarımını tam uygular:
/// - 20 saniye canlı atış geri sayımı ve karar seti uyarı çubuğu
/// - Birebir kafa kafaya (Head-to-Head) skor tahtası (Zeynep Yılmaz 5 vs Elif Berra G. 3)
/// - 5 Set ilerleme matrisi (+2 Puan, 1-1, +2 Rakip vb.)
/// - 70m canlı hedef tahtası üzerinde rüzgar etkisi ve ok dağılım projeksiyonu
/// - SwanBand biyometrik gerilim paneli (132 BPM, 3.4s çekiş, %88 odak)
/// - Başantrenör taktik mikronotu
/// - Hızlı puan seçimi (8, 9, 10, X, M) ve interaktif seti tamamlama eylemi
class MatchSimulationScreen extends ConsumerStatefulWidget {
  const MatchSimulationScreen({super.key});

  @override
  ConsumerState<MatchSimulationScreen> createState() => _MatchSimulationScreenState();
}

class _MatchSimulationScreenState extends ConsumerState<MatchSimulationScreen> {
  double _secondsLeft = 18.4;
  Timer? _timer;
  String _selectedScore = '10';
  bool _isFinalizing = false;
  bool _matchFinished = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (_secondsLeft <= 0.1) {
        t.cancel();
        setState(() => _secondsLeft = 0.0);
      } else {
        setState(() => _secondsLeft = (_secondsLeft - 0.1));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SwanSpace.md,
                SwanSpace.sm,
                SwanSpace.md,
                110,
              ),
              children: [
                _buildTopBar(c),
                const SizedBox(height: SwanSpace.md),

                // 1. Simulation Header & Countdown Bar
                _buildSimulationHeader(c),
                const SizedBox(height: SwanSpace.md),

                // 2. Head to Head Match Scoreboard
                _buildScoreboard(c),
                const SizedBox(height: SwanSpace.md),

                // 3. Live Target & Arrows Dispersion
                _buildTargetDispersionView(c),
                const SizedBox(height: SwanSpace.md),

                // 4. Biometrics & Telemetry Panel (SwanBand)
                _buildBiometricsPanel(c),
                const SizedBox(height: SwanSpace.md),

                // 5. Coach Tactical Micro-Note
                _buildCoachNote(c),
                const SizedBox(height: SwanSpace.md),

                // 6. Match Action & Scoring Controls
                _buildScoringControls(c),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildTopBar(SwanPalette c) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.ink),
          tooltip: 'Geri',
        ),
        const SizedBox(width: SwanSpace.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SWANSPORT MÜSABAKA',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
              Text(
                'Eleme Simülasyonu',
                style: SwanType.h2(c.ink),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Dürbün / Kamera',
          icon: Icon(Icons.camera_alt_outlined, color: c.ink),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dürbün kamerası kalibre ediliyor...')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSimulationHeader(SwanPalette c) {
    final progress = (_secondsLeft / 20.0).clamp(0.0, 1.0);
    final isDanger = _secondsLeft < 5.0;

    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
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
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  Text(
                    'CANLI SİMÜLASYON',
                    style: SwanType.caption(c.accent, w: FontWeight.w700),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDanger ? c.danger.withValues(alpha: 0.15) : c.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: isDanger ? c.danger : c.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: isDanger ? c.danger : c.ink,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_secondsLeft.toStringAsFixed(1)}s',
                      style: SwanType.caption(
                        isDanger ? c.danger : c.ink,
                        w: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bahar Kupası Yarı Final',
                    style: SwanType.h3(c.ink),
                  ),
                  Text(
                    '70m Klasik Yay • FITA Set Sistemi (Best of 5)',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Text(
                  '5. Set (Karar)',
                  style: SwanType.caption(c.accent, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: c.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDanger ? c.danger : c.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Player 1 (Blue Corner)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border(left: BorderSide(color: c.accent, width: 3)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: c.accent.withValues(alpha: 0.2),
                        child: Text('ZY', style: SwanType.body(c.accent, w: FontWeight.w700)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Zeynep Yılmaz',
                        style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Marmara Okçuluk',
                        style: SwanType.caption(c.inkMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: SwanSpace.xs),
                      Text(
                        _matchFinished ? '7' : '5',
                        style: SwanType.h1(c.accent),
                      ),
                      Text(
                        'Set Puanı',
                        style: SwanType.caption(c.accent, w: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              // VS & Probability
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SwanSpace.xs),
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.line),
                      ),
                      child: Text('VS', style: SwanType.caption(c.inkMuted, w: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Karar Oku',
                        style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              // Player 2 (Red Corner)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border(right: BorderSide(color: c.danger, width: 3)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: c.danger.withValues(alpha: 0.2),
                        child: Text('EB', style: SwanType.body(c.danger, w: FontWeight.w700)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Elif Berra G.',
                        style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Bursa Okçuluk',
                        style: SwanType.caption(c.inkMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: SwanSpace.xs),
                      Text(
                        '3',
                        style: SwanType.h1(c.danger),
                      ),
                      Text(
                        'Set Puanı',
                        style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          // Set Progression Matrix
          Container(
            padding: const EdgeInsets.all(SwanSpace.xs),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Row(
              children: [
                _buildSetCell(c, '1. SET', '28 - 26', '+2 Puan', c.accent),
                _buildSetCell(c, '2. SET', '27 - 27', '1 - 1', c.inkMuted),
                _buildSetCell(c, '3. SET', '26 - 29', '+2 Rakip', c.danger),
                _buildSetCell(c, '4. SET', '29 - 28', '+2 Puan', c.accent),
                _buildSetCell(
                  c,
                  '5. SET',
                  _matchFinished ? '29 - 27' : '19 - 18',
                  _matchFinished ? '+2 ŞAMP' : '3. Ok',
                  c.accent,
                  isActive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetCell(
    SwanPalette c,
    String setLabel,
    String score,
    String outcome,
    Color outcomeColor, {
    bool isActive = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.sm),
          border: isActive ? null : Border.all(color: c.line),
        ),
        child: Column(
          children: [
            Text(
              setLabel,
              style: SwanType.caption(
                isActive ? Colors.white70 : c.inkMuted,
                w: FontWeight.w600,
              ),
            ),
            Text(
              score,
              style: SwanType.caption(
                isActive ? Colors.white : c.ink,
                w: FontWeight.w700,
              ),
            ),
            Text(
              outcome,
              style: SwanType.caption(
                isActive ? Colors.white : outcomeColor,
                w: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetDispersionView(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
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
              Row(
                children: [
                  Icon(Icons.crisis_alert_rounded, size: 20, color: c.accent),
                  const SizedBox(width: SwanSpace.xs),
                  Text(
                    'Hedef 3A: Zeynep Ok Dağılımı',
                    style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(Icons.air_rounded, size: 14, color: c.accent),
                    const SizedBox(width: 4),
                    Text(
                      '14 km/s (10 yönü)',
                      style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          // Custom interactive Target canvas
          Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.line),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _DuelTargetPainter(c: c),
                ),
                // Arrow 1 indicator
                Positioned(
                  left: 175,
                  top: 90,
                  child: _buildArrowDot('1', '10', c.accent),
                ),
                // Arrow 2 indicator (9 ring slightly left due to wind)
                Positioned(
                  left: 135,
                  top: 85,
                  child: _buildArrowDot('2', '9', c.accent),
                ),
                // Ghost Arrow 3 prediction
                Positioned(
                  left: 185,
                  top: 98,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: c.danger.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                      border: Border.all(color: c.danger),
                    ),
                    child: Text(
                      _matchFinished ? '#3 (10)' : 'Bekleniyor',
                      style: SwanType.caption(c.danger, w: FontWeight.w700),
                    ),
                  ),
                ),
                // Overlay status floating badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _matchFinished ? 'Atılan: 3/3 Ok' : 'Atılan: 2/3 Ok',
                          style: SwanType.caption(c.inkMuted),
                        ),
                        Text(
                          _matchFinished ? 'Toplam: 29 Puan' : 'Toplam: 19 Puan',
                          style: SwanType.caption(c.ink, w: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SwanSpace.sm),
          // Active End Arrow Chips
          Row(
            children: [
              Expanded(
                child: _buildArrowChip(c, '1', 'Sarı Merkez', '10', true),
              ),
              const SizedBox(width: SwanSpace.xs),
              Expanded(
                child: _buildArrowChip(c, '2', 'Kırmızı 9', '9', true),
              ),
              const SizedBox(width: SwanSpace.xs),
              Expanded(
                child: _buildArrowChip(
                  c,
                  '3',
                  _matchFinished ? 'Tam 10' : '3. Atış',
                  _matchFinished ? '10' : 'Hazır',
                  _matchFinished,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrowDot(String num, String score, Color color) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        num,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildArrowChip(
    SwanPalette c,
    String num,
    String label,
    String val,
    bool isCompleted,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? c.surfaceAlt : c.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: isCompleted ? c.line : c.accent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: isCompleted ? c.accent : c.surface,
                child: Text(
                  num,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.white : c.accent,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: SwanType.caption(c.inkMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Text(
            val,
            style: SwanType.bodySm(
              isCompleted ? c.accent : c.ink,
              w: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricsPanel(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_heart_rounded, size: 20, color: c.danger),
                  const SizedBox(width: SwanSpace.xs),
                  Text(
                    'Canlı Biyometrik Gerilim',
                    style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                'SwanBand Sync',
                style: SwanType.caption(c.inkMuted, w: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Row(
            children: [
              // Heart Rate
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nabız', style: SwanType.caption(c.inkMuted)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('132', style: SwanType.h3(c.danger)),
                          const SizedBox(width: 2),
                          Text('BPM', style: SwanType.caption(c.inkMuted)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('İdeal Atış Zonu', style: SwanType.caption(c.accent, w: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              // Draw time
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Çekiş Süresi', style: SwanType.caption(c.inkMuted)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('3.4', style: SwanType.h3(c.ink)),
                          const SizedBox(width: 2),
                          Text('sn', style: SwanType.caption(c.inkMuted)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Hedef: 3.2-3.6s', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              // Focus
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zihinsel Odak', style: SwanType.caption(c.inkMuted)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('%88', style: SwanType.h3(c.accent)),
                          const SizedBox(width: 2),
                          Text('Yüksek', style: SwanType.caption(c.accent)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Göz Kırpma: Düzenli', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoachNote(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: c.accent,
            child: const Icon(Icons.support_agent_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Başantrenör Taktik Notu', style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
                    Text('30sn önce', style: SwanType.caption(c.inkMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '"Rüzgar hafifledi, 12 halkasından 1 klik sağa düzeltme yap ve klikır düşüşünde nefesi sabitle."',
                  style: SwanType.bodySm(c.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoringControls(SwanPalette c) {
    final scores = ['8', '9', '10', 'X', 'M'];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '3. Ok Puanını Doğrula:',
                style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
              ),
              const SizedBox(height: SwanSpace.sm),
              Row(
                children: scores.map((s) {
                  final isSelected = _selectedScore == s;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => setState(() => _selectedScore = s),
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? c.accent : c.surfaceAlt,
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                            border: Border.all(
                              color: isSelected ? c.accent : c.line,
                            ),
                          ),
                          child: Text(
                            s,
                            style: SwanType.body(
                              isSelected ? Colors.white : c.ink,
                              w: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: SwanSpace.sm),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _isFinalizing
                ? null
                : () async {
                    setState(() => _isFinalizing = true);
                    await Future<void>.delayed(const Duration(milliseconds: 700));
                    if (mounted) {
                      setState(() {
                        _isFinalizing = false;
                        _matchFinished = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tebrikler! Zeynep Yılmaz Maçı Kazandı (7 - 3)'),
                        ),
                      );
                    }
                  },
            icon: Icon(
              _matchFinished ? Icons.emoji_events_rounded : Icons.check_circle_outline_rounded,
              size: 20,
            ),
            label: Text(
              _matchFinished
                  ? 'Zeynep Yılmaz Maçı Kazandı! (7 - 3)'
                  : _isFinalizing
                      ? 'Hesaplanıyor...'
                      : 'Son Oku Kaydet ve Seti Bitir',
              style: SwanType.body(Colors.white, w: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _matchFinished ? Colors.green.shade700 : c.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: SwanSpace.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dürbün zoom kaydı hakeme iletildi.')),
                  );
                },
                icon: Icon(Icons.gavel_rounded, size: 18, color: c.ink),
                label: Text('Hakem İtirazı / Dürbün', style: SwanType.bodySm(c.ink)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(width: SwanSpace.sm),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seri özeti tablosu hazırlanıyor...')),
                );
              },
              icon: Icon(Icons.replay_rounded, size: 18, color: c.ink),
              label: Text('Seri Özeti', style: SwanType.bodySm(c.ink)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DuelTargetPainter extends CustomPainter {
  const _DuelTargetPainter({required this.c});
  final SwanPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Rings from outer to inner (FITA target)
    final rings = [
      (maxR, Colors.white, Colors.black26),
      (maxR * 0.85, Colors.white, Colors.black26),
      (maxR * 0.70, const Color(0xFF1E293B), Colors.transparent),
      (maxR * 0.55, const Color(0xFF334155), Colors.transparent),
      (maxR * 0.42, const Color(0xFF0284C7), Colors.transparent),
      (maxR * 0.30, const Color(0xFFE11D48), Colors.transparent),
      (maxR * 0.18, const Color(0xFFFACC15), Colors.transparent),
      (maxR * 0.08, const Color(0xFFEAB308), Colors.black26),
    ];

    for (final r in rings) {
      final p = Paint()
        ..color = r.$2
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, r.$1, p);

      if (r.$3 != Colors.transparent) {
        final stroke = Paint()
          ..color = r.$3
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(center, r.$1, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
