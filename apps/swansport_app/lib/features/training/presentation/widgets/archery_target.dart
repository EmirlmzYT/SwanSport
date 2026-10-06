import 'package:flutter/material.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';

/// Stitch standardında Hedef Tahtası & Vuruş Dağılımı bileşeni.
class ArcheryTargetWidget extends StatelessWidget {
  const ArcheryTargetWidget({
    super.key,
    required this.arrows,
    this.size = 220,
    this.onTapScore,
  });

  final List<num?> arrows;
  final double size;
  final ValueChanged<int>? onTapScore;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hedef Tahtası & Dağılım',
                style: SwanType.caption(c.ink, w: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00666D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.center_focus_strong,
                        size: 14, color: Color(0xFF00666D)),
                    const SizedBox(width: 4),
                    Text(
                      'WA Standardı',
                      style: SwanType.caption(const Color(0xFF00666D),
                          w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Custom Painted Target
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              size: Size(size, size),
              painter: _TargetPainter(arrows: arrows),
            ),
          ),
          const SizedBox(height: 14),
          // Arrow slots breakdown
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mevcut Seri (${arrows.length} Ok)',
                      style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                    ),
                    Text(
                      'Seri Toplamı: ${_calculateTotal()} Puan',
                      style: SwanType.caption(const Color(0xFF00666D),
                          w: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(arrows.length, (i) {
                    final val = arrows[i];
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: val != null
                                ? const Color(0xFF00666D).withValues(alpha: 0.5)
                                : c.line,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${i + 1}. Ok',
                              style: SwanType.caption(c.inkMuted,
                                  w: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              val != null ? '$val' : '—',
                              style: SwanType.bodySm(
                                val != null ? c.ink : c.inkMuted,
                                w: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  num _calculateTotal() {
    num sum = 0;
    for (final a in arrows) {
      if (a != null) sum += a;
    }
    return sum;
  }
}

class _TargetPainter extends CustomPainter {
  _TargetPainter({required this.arrows});

  final List<num?> arrows;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Rings from outer to inner
    // 6: Light Blue
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF6BA4FF));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF528FE8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 7: Red Outer
    canvas.drawCircle(
        center, radius * 0.80, Paint()..color = const Color(0xFFEF4E4E));
    canvas.drawCircle(
      center,
      radius * 0.80,
      Paint()
        ..color = const Color(0xFFDB3C3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 8: Red Inner
    canvas.drawCircle(
        center, radius * 0.60, Paint()..color = const Color(0xFFEF4E4E));
    canvas.drawCircle(
      center,
      radius * 0.60,
      Paint()
        ..color = const Color(0xFFDB3C3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 9: Gold Outer
    canvas.drawCircle(
        center, radius * 0.40, Paint()..color = const Color(0xFFF7C844));
    canvas.drawCircle(
      center,
      radius * 0.40,
      Paint()
        ..color = const Color(0xFFE0B230)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 10: Gold Inner
    canvas.drawCircle(
        center, radius * 0.22, Paint()..color = const Color(0xFFF7C844));
    canvas.drawCircle(
      center,
      radius * 0.22,
      Paint()
        ..color = const Color(0xFFE0B230)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // X Ring
    canvas.drawCircle(
      center,
      radius * 0.11,
      Paint()
        ..color = const Color(0xFFB88F17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Center Cross
    final crossPaint = Paint()
      ..color = const Color(0xFF8A6907)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - 6, center.dy),
        Offset(center.dx + 6, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 6),
        Offset(center.dx, center.dy + 6), crossPaint);

    // Arrow plots
    final arrowOffsets = [
      Offset(center.dx + 6, center.dy - 10),
      Offset(center.dx - 2, center.dy + 3),
      Offset(center.dx + 22, center.dy - 18),
      Offset(center.dx - 20, center.dy + 16),
      Offset(center.dx + 28, center.dy + 26),
      Offset(center.dx - 12, center.dy - 12),
    ];

    for (var i = 0; i < arrows.length; i++) {
      if (arrows[i] == null) continue;
      final off = arrowOffsets[i % arrowOffsets.length];

      // Draw arrow dot
      canvas.drawCircle(
          off, 5, Paint()..color = const Color(0xFF00666D));
      canvas.drawCircle(
        off,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Arrow number text
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(off.dx - textPainter.width / 2, off.dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TargetPainter oldDelegate) => true;
}
