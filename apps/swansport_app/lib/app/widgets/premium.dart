import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../features/demo/demo_role.dart';

// Modül kataloğu ayrı dosyada. `import` alt bardaki menü düğmesinin onu
// çağırabilmesi için; `export` ise mevcut `import 'premium.dart'` satırlarının
// hiçbirinin değişmek zorunda kalmaması için.
import 'module_launcher.dart';
export 'module_launcher.dart';

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

/// Merkez aksiyon (FAB) butonlu yüzen alt navigasyon.
///
/// Sekme indeksleri: 0 Ana · 1 Takvim · (merkez FAB) · 3 Kadro · 4 Duyuru.
/// Alt bardaki bir sekme hedefi.
class NavDest {
  const NavDest(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

class PremiumBottomNav extends ConsumerWidget {
  const PremiumBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAction,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAction;

  /// 2. sekme adayları — rolün erişebildiği ilki gösterilir.
  static const List<NavDest> _slot1 = [
    NavDest(Icons.calendar_month_rounded, 'Takvim', '/calendar'),
    NavDest(Icons.campaign_rounded, 'Duyuru', '/announcements'),
    NavDest(Icons.dashboard_rounded, 'Komuta', '/home-command'),
    NavDest(Icons.folder_rounded, 'Belgeler', '/documents'),
    NavDest(Icons.home_rounded, 'Panel', '/dashboard'),
  ];

  /// 4. sekme adayları — rolün erişebildiği ilki gösterilir.
  static const List<NavDest> _slot3 = [
    NavDest(Icons.groups_rounded, 'Kadro', '/athletes'),
    NavDest(Icons.bar_chart_rounded, 'Performans', '/performance-analytics'),
    NavDest(Icons.medical_services_rounded, 'Sağlık', '/medical-center'),
    NavDest(Icons.admin_panel_settings_rounded, 'Onay', '/onay-paneli'),
    NavDest(Icons.verified_user_rounded, 'Doğrulama', '/dogrulama'),
    NavDest(Icons.home_rounded, 'Panel', '/dashboard'),
  ];

  /// Rolün erişebildiği ilk adayı seçer; hiçbiri uygun değilse sonuncuyu.
  static NavDest _pick(List<NavDest> candidates, Set<String>? allowed) {
    for (final c in candidates) {
      if (demoAllows(allowed, c.route)) return c;
    }
    return candidates.last;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final faint = isDark ? const Color(0xFF5E6D86) : SwanColors.textSecondary;

    final allowed = ref.watch(effectiveAllowedRoutesProvider);

    // Sekmeler role göre kurulur: erişilemeyen bir hedef sönük bırakılmaz,
    // yerine o role uygun başka bir hedef konur.
    final items = <NavDest>[
      const NavDest(Icons.home_rounded, 'Ana', '/akis'),
      _pick(_slot1, allowed),
      _pick(_slot3, allowed),
      const NavDest(Icons.person_rounded, 'Profil', '/profil'),
    ];

    var current = ModalRoute.of(context)?.settings.name;
    if (current == '/') current = '/akis'; // açılış kapısı akışı gösteriyor

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _item(context, items[0], current, faint, 0),
              _item(context, items[1], current, faint, 1),
              _fab(context),
              _item(context, items[2], current, faint, 3),
              _item(context, items[3], current, faint, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, NavDest dest, String? current,
      Color faint, int slotIndex) {
    // Önce açık rotaya, o yoksa ekranın bildirdiği sekmeye göre işaretle.
    final active =
        current != null ? current == dest.route : selectedIndex == slotIndex;
    final color = active ? kTeal : faint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (current == dest.route) return;
        Navigator.pushNamed(context, dest.route);
      },
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(dest.icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(dest.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: jakarta(9.5, FontWeight.w700, color)),
          ],
        ),
      ),
    );
  }

  Widget _fab(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: GestureDetector(
        onTap: () => showModuleLauncher(context),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kTealBright, kTeal],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: kTeal.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.grid_view_rounded,
              color: Colors.white, size: 24),
        ),
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

Widget premiumLoading() => const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(child: CircularProgressIndicator(color: kTeal)),
    );

Widget premiumError(BuildContext context, String msg) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final ink = isDark ? Colors.white : SwanColors.textPrimary;
  return Padding(
    padding: const EdgeInsets.only(top: 50),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFF43F5E)),
        const SizedBox(height: 12),
        Text('Veri yüklenemedi', style: jakarta(14, FontWeight.w700, ink)),
        const SizedBox(height: 6),
        Text(
          msg,
          textAlign: TextAlign.center,
          style: jakarta(11.5, FontWeight.w500, SwanColors.textSecondary),
        ),
      ],
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final ink = isDark ? Colors.white : SwanColors.textPrimary;
  return Padding(
    padding: const EdgeInsets.only(top: 50),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: kTeal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: kTeal, size: 30),
        ),
        const SizedBox(height: 16),
        Text(title, style: sora(18, FontWeight.w800, ink)),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: jakarta(12.5, FontWeight.w500, SwanColors.textSecondary),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onAction,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: kTeal.withValues(alpha: 0.34),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(actionLabel,
                  style: jakarta(14, FontWeight.w800, Colors.white)),
            ),
          ),
        ],
      ],
    ),
  );
}
