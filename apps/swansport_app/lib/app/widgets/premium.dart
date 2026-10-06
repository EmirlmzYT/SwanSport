import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';
import 'swan_skeleton.dart';

// Modül kataloğu ayrı dosyada. `import` alt bardaki menü düğmesinin onu
// çağırabilmesi için; `export` ise mevcut `import 'premium.dart'` satırlarının
// hiçbirinin değişmek zorunda kalmaması için.

/// Paylaşılan premium tasarım bileşenleri (v3).
/// Tüm ekranlar aynı yüzen menü, avatar, rozet ve tipografi dilini kullanır.

const kTeal = SwanColors.primary; // #008C95
const kTealBright = Color(0xFF14B8B1);
const kTealDeep = Color(0xFF04464B);
const kCoral = Color(0xFFFF7A59);

TextStyle sora(double size, FontWeight w, Color c, {double ls = -0.6}) =>
    GoogleFonts.sora(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: ls,
      height: 1.08,
    );

TextStyle jakarta(double size, FontWeight w, Color c, {double ls = 0}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: ls,
    );

/// Avatar için gradyan paleti — her sporcuya tutarlı bir renk verir.
const List<List<Color>> kAvatarGradients = [
  [Color(0xFF14B8B1), Color(0xFF008C95)],
  [Color(0xFFFFB65C), Color(0xFFF97316)],
  [Color(0xFF9E7BFF), Color(0xFF6D45C4)],
  [Color(0xFF4FC3F7), Color(0xFF2563EB)],
];

/// Baş harfleri gösteren gradyanlı avatar.
class GradientAvatar extends StatelessWidget {
  const GradientAvatar({
    super.key,
    required this.initials,
    this.gradientIndex = 0,
    this.size = 42,
    this.radius = 14,
  });

  final String initials;
  final int gradientIndex;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final grad = kAvatarGradients[gradientIndex % kAvatarGradients.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: grad.last.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: sora(size * 0.33, FontWeight.w700, Colors.white),
      ),
    );
  }
}

/// Renk + ikon + metin durum rozeti (durum asla yalnız renkle anlatılmaz).
class PremiumStatusChip extends StatelessWidget {
  const PremiumStatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: jakarta(10.5, FontWeight.w700, color)),
        ],
      ),
    );
  }
}

/// Katılım/oran halkası (donut).
class SwanRing extends StatelessWidget {
  const SwanRing({
    super.key,
    required this.value,
    required this.track,
    required this.progress,
    this.size = 62,
    this.stroke = 7,
    this.center,
  });

  final double value;
  final Color track;
  final Color progress;
  final double size;
  final double stroke;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value,
          track: track,
          progress: progress,
          stroke: stroke,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.track,
    required this.progress,
    required this.stroke,
  });

  final double value;
  final Color track;
  final Color progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = progress;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.progress != progress || old.track != track;
}

/// ------------------------- Ortak veri-durum yardımcıları -------------------

/// Yükleniyor göstergesi — 39 ekranın ortak hâli.
///
/// Dönen çemberdi; brief §21 "skeleton loading → soft shimmer" istiyor.
/// İskelet gelecek içeriğin biçimini önceden gösterdiği için aynı süre
/// daha kısa hissettiriyor. Şekli `swan_skeleton.dart`'tan geliyor;
/// buradan değiştirmek 39 ekranı birden değiştirir.
Widget premiumLoading() => const SwanListSkeleton();

Widget premiumCardLoading() => const SwanCardSkeleton();

Widget premiumError(BuildContext context, String msg) {
  final c = context.swan;
  return Padding(
    padding: const EdgeInsets.only(top: 28),
    child: SwanInfoPanel(
      icon: Icons.cloud_off_rounded,
      title: 'Veri yüklenemedi',
      subtitle: msg,
      tone: c.danger,
    ),
  );
}

Widget premiumEmpty(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final c = context.swan;
  return Padding(
    padding: const EdgeInsets.only(top: 28),
    child: SwanInfoPanel(
      icon: icon,
      title: title,
      subtitle: subtitle,
      tone: c.accent,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}

class SwanSectionHeader extends StatelessWidget {
  const SwanSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SwanType.h3(c.ink)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class SwanMetricStrip extends StatelessWidget {
  const SwanMetricStrip({super.key, required this.items});

  final List<SwanMetricItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: SwanSpace.sm),
          Expanded(child: SwanMetricCard(item: items[i])),
        ],
      ],
    );
  }
}

class SwanMetricItem {
  const SwanMetricItem({
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tone;
}

class SwanMetricCard extends StatelessWidget {
  const SwanMetricCard({super.key, required this.item});

  final SwanMetricItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final tone = item.tone ?? c.accent;
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Icon(item.icon, color: tone, size: 17),
          ),
          const SizedBox(height: SwanSpace.sm),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SwanType.h3(c.ink),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SwanType.caption(c.inkMuted),
          ),
        ],
      ),
    );
  }
}

class SwanInfoPanel extends StatelessWidget {
  const SwanInfoPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tone,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final color = tone ?? c.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SwanSpace.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: SwanSpace.md),
          Text(title, textAlign: TextAlign.center, style: SwanType.h3(c.ink)),
          const SizedBox(height: SwanSpace.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: SwanType.bodySm(c.inkMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SwanSpace.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
