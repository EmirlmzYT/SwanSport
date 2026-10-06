import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';

/// Stitch Screen 8: SwanSport - Canlı Antrenman & GPS Koşu Telemetrisi.
/// GPS harita simülasyonu, anlık tempo/mesafe/nabız HUD'ı, hayalet koşucu ve dokunsal kontrol paneli.
class LiveTrainingGpsHud extends StatefulWidget {
  const LiveTrainingGpsHud({
    super.key,
    this.sessionId,
    this.protocolName = 'Açık Hava Dayanıklılık & GPS Koşusu',
  });

  final String? sessionId;
  final String protocolName;

  @override
  State<LiveTrainingGpsHud> createState() => _LiveTrainingGpsHudState();
}

class _LiveTrainingGpsHudState extends State<LiveTrainingGpsHud> {
  bool _isRunning = true;
  bool _isLocked = false;
  int _secondsElapsed = 2439; // 00:40:39
  double _distanceKm = 7.45;
  int _calories = 540;
  int _heartRate = 156;
  int _currentLap = 4;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRunning && !_isLocked) {
        setState(() {
          _secondsElapsed++;
          if (_secondsElapsed % 5 == 0) {
            _distanceKm += 0.01;
          }
          if (_secondsElapsed % 12 == 0) {
            _calories += 1;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatChrono(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // 1. HUD Sticky Mini Header
            _buildHudHeader(palette),
            const SizedBox(height: 12),

            // 2. Vector GPS Map HUD Viewport
            _buildMapViewport(palette, isDark),
            const SizedBox(height: 14),

            // 3. Primary Metric: Large Digital Time Elapsed
            _buildPrimaryTimeMetric(palette),
            const SizedBox(height: 12),

            // 4. Kinetic 2x2 Telemetry Grid
            _buildTelemetryGrid(palette),
            const SizedBox(height: 14),

            // 5. Ghost Runner & Community Live Tag
            _buildGhostRunnerCard(palette),
            const SizedBox(height: 18),

            // 6. Primary Tactile Action Deck
            _buildActionDeck(palette),
            const SizedBox(height: 16),

            // 7. Finish Safe Guard Bar
            _buildFinishBar(palette),
          ],
        ),
      ),
    );
  }

  // --- HUD Mini Header ---
  Widget _buildHudHeader(SwanPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                size: 24, color: palette.ink),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
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
              const SizedBox(width: 6),
              Text(
                'GPS AKTİF',
                style: SwanType.caption(palette.accent, w: FontWeight.w800),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('•', style: SwanType.caption(palette.inkMuted)),
              ),
              Text(
                'Bebek Parkuru',
                style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
              ),
            ],
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isLocked = !_isLocked;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isLocked
                          ? 'Ekran kilitlendi. Dokunmalar devre dışı.'
                          : 'Ekran kilidi açıldı.',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _isLocked
                      ? const Color(0xFFFF7A59).withValues(alpha: 0.2)
                      : palette.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 20,
                  color: _isLocked ? const Color(0xFFFF7A59) : palette.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('GPS ve telemetre ayarları açılıyor...')),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.tune_rounded, size: 20, color: palette.ink),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Vector GPS Map HUD Viewport ---
  Widget _buildMapViewport(SwanPalette palette, bool isDark) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF020F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background GPS Grid & Stylized Canvas
          CustomPaint(
            size: Size.infinite,
            painter: _GpsMapPainter(accentColor: palette.accent),
          ),

          // Map Overlay HUD Chips
          Positioned(
            top: 12,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2B3C).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.explore_rounded,
                          size: 14, color: palette.accent),
                      const SizedBox(width: 5),
                      Text(
                        'Poyraz Sahil Rotası',
                        style: SwanType.caption(Colors.white,
                            w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2B3C).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.terrain_rounded,
                          size: 12, color: Color(0xFFFF7A59)),
                      const SizedBox(width: 4),
                      Text(
                        'Eğim: +%2.4',
                        style: SwanType.caption(Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Recenter Target Trigger
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Harita canlı konuma merkezlendi.'),
                    duration: Duration(milliseconds: 900),
                  ),
                );
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2B3C).withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(Icons.my_location_rounded,
                    size: 18, color: palette.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Primary Metric: Large Digital Time Elapsed ---
  Widget _buildPrimaryTimeMetric(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 14, color: palette.accent),
              const SizedBox(width: 5),
              Text(
                'TOPLAM SÜRE',
                style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatChrono(_secondsElapsed),
            style: SwanType.display(palette.accent).copyWith(
              fontSize: 38,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Otomatik Duraklama Açık',
                style: SwanType.caption(palette.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Kinetic 2x2 Telemetry Grid ---
  Widget _buildTelemetryGrid(SwanPalette palette) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        // 1. Distance Card
        _telemetryCard(
          palette,
          label: 'MESAFE',
          icon: Icons.straighten_rounded,
          iconColor: palette.accent,
          value: _distanceKm.toStringAsFixed(2),
          unit: 'km',
          progressValue: (_distanceKm / 10.0).clamp(0.0, 1.0),
          progressColor: palette.accent,
          footerText: 'Hedef: 10.00 km',
        ),

        // 2. Current Pace Card
        _telemetryCard(
          palette,
          label: 'ANLIK TEMPO',
          icon: Icons.speed_rounded,
          iconColor: palette.accent,
          value: '5:12',
          unit: '/km',
          trendText: 'Ort. 5:24 /km',
          footerText: 'Aralık: Optimum',
        ),

        // 3. Calories Burned Card
        _telemetryCard(
          palette,
          label: 'AKTİF KALORİ',
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFFFF7A59),
          value: '$_calories',
          unit: 'kcal',
          progressValue: (_calories / 650.0).clamp(0.0, 1.0),
          progressColor: const Color(0xFFFF7A59),
          footerText: 'Hedef: 650 kcal',
        ),

        // 4. Heart Rate Card
        _telemetryCard(
          palette,
          label: 'KALP NABZI',
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFFFB4AB),
          value: '$_heartRate',
          unit: 'BPM',
          badgeText: 'BÖLGE 4',
          footerText: 'Anaerobik Eşik',
        ),
      ],
    );
  }

  Widget _telemetryCard(
    SwanPalette palette, {
    required String label,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    double? progressValue,
    Color? progressColor,
    String? trendText,
    String? badgeText,
    required String footerText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: SwanType.caption(palette.inkMuted, w: FontWeight.w700)
                    .copyWith(fontSize: 10),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: SwanType.h2(palette.ink).copyWith(fontSize: 22),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
              ),
              if (badgeText != null) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB4AB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: SwanType.caption(const Color(0xFFFFB4AB),
                        w: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
          if (progressValue != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 4,
                backgroundColor: palette.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? palette.accent),
              ),
            )
          else if (trendText != null)
            Row(
              children: [
                Icon(Icons.trending_up_rounded, size: 12, color: palette.accent),
                const SizedBox(width: 4),
                Text(
                  trendText,
                  style: SwanType.caption(palette.accent, w: FontWeight.w700),
                ),
              ],
            )
          else
            const SizedBox(height: 4),
          Text(
            footerText,
            style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  // --- Ghost Runner Card ---
  Widget _buildGhostRunnerCard(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'SK',
                    style: SwanType.bodySm(palette.accent, w: FontWeight.w800),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF7A59),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Selin K.',
                      style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '120m Önünde',
                      style: SwanType.caption(const Color(0xFFFF7A59),
                          w: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Swan Bosphorus Run Club • Lider',
                  style: SwanType.caption(palette.inkMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hedef tempo Selin K.\'ya kilitlendi!')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, size: 14, color: palette.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Yetiş',
                    style: SwanType.caption(palette.accent, w: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Action Deck ---
  Widget _buildActionDeck(SwanPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Music Trigger
        Column(
          children: [
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tempo müziği 165 BPM\'e ayarlandı.')),
                );
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.line),
                ),
                child: Icon(Icons.graphic_eq_rounded,
                    size: 24, color: palette.accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '165 BPM',
              style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
            ),
          ],
        ),

        // Center Play/Pause Large Trigger
        Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isRunning = !_isRunning;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isRunning
                        ? [kTealBright, kTeal]
                        : [const Color(0xFFFF7A59), const Color(0xFFE05A39)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRunning ? kTeal : const Color(0xFFFF7A59))
                          .withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isRunning ? 'DURAKLAT' : 'DEVAM ET',
              style: SwanType.caption(
                _isRunning ? palette.accent : const Color(0xFFFF7A59),
                w: FontWeight.w800,
              ),
            ),
          ],
        ),

        // Lap Marker Trigger
        Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentLap++;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tur $_currentLap kaydedildi!'),
                    duration: const Duration(milliseconds: 900),
                  ),
                );
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.line),
                ),
                child: Icon(Icons.flag_circle_rounded,
                    size: 24, color: palette.ink),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tur $_currentLap (1.8k)',
              style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  // --- Finish Safe Guard Bar ---
  Widget _buildFinishBar(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB4AB).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stop_circle_rounded,
                    size: 20, color: Color(0xFFFFB4AB)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Antrenmanı Bitir',
                    style: SwanType.caption(palette.ink, w: FontWeight.w700),
                  ),
                  Text(
                    'Bitirip sonuç analizini aç',
                    style: SwanType.caption(palette.inkMuted),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacementNamed('/antrenman-sonuc');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF93000A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_reset_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Bitir',
                    style: SwanType.caption(Colors.white, w: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom GPS map canvas painter
class _GpsMapPainter extends CustomPainter {
  _GpsMapPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2B3C).withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw grid
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw route path
    final routePath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.85)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.7,
        size.width * 0.4,
        size.height * 0.55,
        size.width * 0.6,
        size.height * 0.4,
      )
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.25,
        size.width * 0.85,
        size.height * 0.15,
        size.width * 0.9,
        size.height * 0.1,
      );

    // Glow trail
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.25)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(routePath, glowPaint);

    // Main line
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(routePath, linePaint);

    // Live position node
    final userPos = Offset(size.width * 0.6, size.height * 0.4);
    final pulsePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 14, pulsePaint);

    final nodePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 6, nodePaint);

    final innerPaint = Paint()
      ..color = const Color(0xFF003734)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 3, innerPaint);

    // Ghost runner node
    final ghostPos = Offset(size.width * 0.8, size.height * 0.2);
    final ghostPaint = Paint()
      ..color = const Color(0xFFFFB6A4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ghostPos, 5, ghostPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
