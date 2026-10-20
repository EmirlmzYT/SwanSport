import 'package:flutter/material.dart';
import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

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
  const QuickActions({required this.actions, this.wrap = false, super.key});

  final List<QuickAction> actions;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    if (wrap) {
      return LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 280 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * SwanSpace.sm) / columns;
        return Wrap(spacing: SwanSpace.sm, runSpacing: SwanSpace.sm, children: [
          for (final action in actions)
            SizedBox(
                width: width,
                child: _QuickCard(action: action, reserveLabelSpace: true)),
        ]);
      });
    }

    if (actions.length <= 3) {
      return Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _QuickCard(action: actions[i])),
          ],
        ],
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          width: 112,
          child: _QuickCard(action: actions[i]),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.action, this.reserveLabelSpace = false});
  final QuickAction action;
  final bool reserveLabelSpace;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final caption = SwanType.caption(c.ink, w: FontWeight.w700);
    final label = Text(
      action.label,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: caption,
    );
    return Semantics(
      button: true,
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanRadius.md),
          side: BorderSide(color: c.line),
        ),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, action.route,
              arguments: action.arguments),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: SwanSpace.sm, vertical: SwanSpace.md),
            child: reserveLabelSpace
                ? Row(
                    children: [
                      Container(
                        width: SwanSpace.xl + SwanSpace.md,
                        height: SwanSpace.xl + SwanSpace.md,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Icon(action.icon, color: c.ink, size: 20),
                      ),
                      const SizedBox(width: SwanSpace.sm),
                      Expanded(
                        child: SizedBox(
                          height: MediaQuery.textScalerOf(context)
                                  .scale(caption.fontSize!) *
                              caption.height! *
                              2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(action.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: caption),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Icon(action.icon, color: c.ink, size: 20),
                      ),
                      const SizedBox(height: 7),
                      label,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
