import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';

/// Kutu alırken verilen bilgiler.
class ClaimResult {
  const ClaimResult({required this.guests, required this.needed});

  /// Uygulamada olmayan arkadaşlar.
  final int guests;

  /// Kaç oyuncu aranıyor.
  final int needed;
}

/// "Saati al" formu — kaç kişisin, oyuncu arıyor musun.
///
/// `guest_count` gerçekçilik için: "üç kişiyiz ama ikisi uygulamada yok"
/// denebilmeli, yoksa insanlar sistemi doğru doldurmaz ve kortun kaç kişilik
/// dolduğu bilgisi anlamını yitirir.
class ClaimSheet extends StatefulWidget {
  const ClaimSheet({required this.court, required this.startsAt, super.key});

  final Court court;
  final DateTime startsAt;

  @override
  State<ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<ClaimSheet> {
  int _guests = 0;
  int _needed = 0;

  /// Sen + yanındakiler + aranan = kortun kapasitesini aşamaz.
  int get _total => 1 + _guests + _needed;
  int get _room => widget.court.capacity - _total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final field = isDark ? const Color(0xFF1A2537) : const Color(0xFFF4F7FA);

    final hour = '${widget.startsAt.hour.toString().padLeft(2, '0')}:'
        '${widget.startsAt.minute.toString().padLeft(2, '0')}';

    Widget stepper(String title, String hint, int value, int max,
            ValueChanged<int> onChanged) =>
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: jakarta(13, FontWeight.w700, ink)),
                  const SizedBox(height: 2),
                  Text(hint,
                      style: jakarta(
                          11, FontWeight.w600, SwanColors.textSecondary)),
                ],
              ),
            ),
            _round(Icons.remove_rounded, field, ink,
                value > 0 ? () => onChanged(value - 1) : null),
            SizedBox(
              width: 38,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: jakarta(15, FontWeight.w800, ink)),
            ),
            _round(Icons.add_rounded, field, ink,
                value < max ? () => onChanged(value + 1) : null),
          ]),
        );

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38,
          height: 4,
          decoration:
              BoxDecoration(color: line, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 14),
        Text('$hour · ${widget.court.name}',
            style: sora(16, FontWeight.w800, ink)),
        const SizedBox(height: 4),
        Text('Bir saat senin.',
            style: jakarta(12, FontWeight.w600, SwanColors.textSecondary)),

        stepper('Yanındakiler', 'Uygulamada olmayan arkadaşların', _guests,
            _guests + _room, (v) => setState(() => _guests = v)),

        stepper('Oyuncu arıyor musun?', 'Boş yerine katılmak isteyen olabilir',
            _needed, _needed + _room, (v) => setState(() => _needed = v)),

        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => Navigator.pop(
              context, ClaimResult(guests: _guests, needed: _needed)),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTealBright, kTeal]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('Saati al',
                style: jakarta(14, FontWeight.w800, Colors.white)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
            'Gelemezsen iptal et — cezası yok. Haber vermeden gelmemek '
            'sıranı ve sonrakini yakıyor.',
            textAlign: TextAlign.center,
            style: jakarta(10.5, FontWeight.w600, SwanColors.textSecondary)),
      ]),
    );
  }

  Widget _round(IconData icon, Color fill, Color ink, VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon,
              size: 18,
              color: onTap == null ? SwanColors.textSecondary : ink),
        ),
      );
}
