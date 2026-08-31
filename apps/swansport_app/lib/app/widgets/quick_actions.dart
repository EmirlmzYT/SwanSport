import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import 'premium.dart';
import '../../app/design/swan_type.dart';

/// Bir ekrandan ilgili ekranlara geçiş kısayolları.
///
/// **Neden var:** uygulama bir menü kataloğu gibi çalışıyordu — 39 modülün
/// hepsi ortadaki FAB'dan açılıyordu, ekranlar birbirini açmıyordu. Kortu
/// görüp oynayacak kimse bulamıyorsan menüye dönüp "Partner Bul"u aramak
/// zorundaydın. Bu bileşen o kopmayı kapatıyor: ilgili yer, ilgili ekranda
/// duruyor.
///
/// Görsel dil `home_command_center_screen`'deki "HIZLI İŞLEMLER"
/// satırından alındı — orada zaten doğru fikir vardı, yalnızca tek ekranda
/// kalmış ve paylaşılmamıştı.

/// Tek bir kısayol hedefi.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.route,
    this.arguments,
  });

  final IconData icon;
  final String label;
  final String route;
  final Object? arguments;
}

/// Yan yana kısayol kartları.
///
/// Üçten fazla veriliyorsa satır sıkışmasın diye kaydırılabilir olur;
/// üç ve altı eşit bölünür.
class QuickActions extends StatelessWidget {
  const QuickActions({required this.actions, super.key});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    if (actions.length <= 3) {
      return Row(children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _QuickCard(action: actions[i])),
        ],
      ]);
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) =>
            SizedBox(width: 104, child: _QuickCard(action: actions[i])),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.action});
  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pushNamed(context, action.route,
          arguments: action.arguments),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(action.icon, color: kTeal, size: 20),
          ),
          const SizedBox(height: 8),
          Text(action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SwanType.caption(ink, w: FontWeight.w700)),
        ]),
      ),
    );
  }
}
