import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/design/swan_type.dart';

/// Antrenör kabul edilirken kademe ve süpervizör seçimi.
///
/// Kural: 1. kademe (yardımcı antrenör) tek başına çalışamaz; kulüpteki
/// 2. kademe veya üstü bir antrenöre bağlanmalıdır.
class CoachAcceptSheet extends StatefulWidget {
  const CoachAcceptSheet({
    super.key,
    required this.personName,
    required this.supervisors,
  });

  final String personName;
  final List<({String profileId, String name, int level})> supervisors;

  @override
  State<CoachAcceptSheet> createState() => _CoachAcceptSheetState();
}

class _CoachAcceptSheetState extends State<CoachAcceptSheet> {
  int _level = 2;
  String? _supervisor;

  bool get _needsSupervisor => _level == 1;
  bool get _canSubmit => !_needsSupervisor || _supervisor != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    final grip = isDark ? const Color(0xFF2E3B4E) : const Color(0xFFE4E9F0);

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: grip, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Antrenörü Kabul Et', style: SwanType.h2(ink)),
            const SizedBox(height: 4),
            Text(widget.personName, style: SwanType.bodySm(kTeal, w: FontWeight.w700)),
            const SizedBox(height: 18),

            Text('Kademe', style: SwanType.h3(ink)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: alt, borderRadius: BorderRadius.circular(13)),
              child: Row(
                children: List.generate(5, (i) {
                  final n = i + 1;
                  final on = _level == n;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _level = n;
                        if (n != 1) _supervisor = null;
                      }),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: on ? kTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$n',
                            style: SwanType.bodySm(on ? Colors.white : SwanColors.textSecondary, w: FontWeight.w800)),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            Text(_levelLabel(_level),
                style:
                    SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),

            if (_needsSupervisor) ...[
              const SizedBox(height: 18),
              Text('Süpervizör', style: SwanType.h3(ink)),
              const SizedBox(height: 6),
              Text(
                  '1. kademe antrenör tek başına çalışamaz; kulüpteki bir '
                  '2. kademe ve üstü antrenöre bağlanmalı.',
                  style: SwanType.caption(SwanColors.textSecondary)),
              const SizedBox(height: 10),
              if (widget.supervisors.isEmpty)
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: const Color(0xFFF43F5E).withValues(alpha: .35)),
                  ),
                  child: Text(
                      'Kulüpte uygun süpervizör yok. Önce 2. kademe veya üstü '
                      'bir antrenör eklemelisin.',
                      style: SwanType.caption(const Color(0xFFF43F5E), w: FontWeight.w600)),
                )
              else
                ...widget.supervisors.map((s) {
                  final on = _supervisor == s.profileId;
                  return GestureDetector(
                    onTap: () => setState(() => _supervisor = s.profileId),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: on ? kTeal.withValues(alpha: .08) : alt,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: on ? kTeal : line),
                      ),
                      child: Row(children: [
                        Icon(
                            on
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 19,
                            color: on ? kTeal : SwanColors.textSecondary),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.bodySm(ink, w: FontWeight.w700)),
                        ),
                        Text('${s.level}. kademe',
                            style: SwanType.caption(kTeal, w: FontWeight.w700)),
                      ]),
                    ),
                  );
                }),
            ],

            const SizedBox(height: 20),
            GestureDetector(
              onTap: _canSubmit
                  ? () =>
                      Navigator.pop(context, (level: _level, sup: _supervisor))
                  : null,
              child: Opacity(
                opacity: _canSubmit ? 1 : .5,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [kTealBright, kTeal]),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text('Kulübe Ekle',
                      style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Vazgeç',
                    style: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _levelLabel(int n) => switch (n) {
        1 => '1. Kademe — Yardımcı Antrenör',
        2 => '2. Kademe — Antrenör',
        3 => '3. Kademe — Kıdemli Antrenör',
        4 => '4. Kademe — Baş Antrenör',
        _ => '5. Kademe — Teknik Direktör',
      };
}
