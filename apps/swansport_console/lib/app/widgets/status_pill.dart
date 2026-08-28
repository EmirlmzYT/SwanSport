import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../theme/console_theme.dart';

/// Durum rozetinin anlamı — rengin kendisi değil.
///
/// Çağıran taraf "yeşil" demiyor, "iyi" diyor; hangi yeşil olduğu temaya
/// kalıyor. Böylece koyu temada kontrast ayrı ayrı düzeltilmiyor.
enum PillTone { good, warning, bad, info, muted }

/// Bir durumu tek bakışta okunur kılan küçük rozet.
///
/// Tabloda durum yalnızca metinle verilseydi göz her satırı okumak zorunda
/// kalırdı; biçim + renk birlikte tarama hızını artırıyor. Renk tek başına
/// taşıyıcı değil — etiket her zaman yazılı.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, required this.tone, super.key});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;

    final color = switch (tone) {
      PillTone.good => dark ? const Color(0xFF4ADE80) : SwanColors.success,
      PillTone.warning => dark ? const Color(0xFFFFB65C) : SwanColors.warning,
      PillTone.bad => dark ? const Color(0xFFFF8189) : SwanColors.error,
      PillTone.info => dark ? const Color(0xFF7CB6FF) : SwanColors.info,
      PillTone.muted => t.colorScheme.outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .16 : .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        label,
        style: t.textTheme.labelSmall?.copyWith(
          color: tone == PillTone.muted ? t.textTheme.bodySmall?.color : color,
          letterSpacing: .2,
        ),
      ),
    );
  }
}
