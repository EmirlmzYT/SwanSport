import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

/// Canlı Yoklama — Supabase sporcuları + sunucuya kayıt, premium (v3).
class LiveAttendanceScreen extends ConsumerStatefulWidget {
  const LiveAttendanceScreen({super.key});

  @override
  ConsumerState<LiveAttendanceScreen> createState() =>
      _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends ConsumerState<LiveAttendanceScreen> {
  // athleteId -> present|absent|excused|late
  final Map<String, String> _marks = {};
  bool _saving = false;

  static final _opts = [
    ('present', 'Var', SwanPalette.light.success),
    ('absent', 'Yok', SwanPalette.light.danger),
    ('excused', 'Mazeret', Color(0xFFF59E0B)),
    ('late', 'Geç', Color(0xFF3B82F6)),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final async = ref.watch(clubAthletesProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: async.when(
              loading: () => premiumLoading(),
              error: (e, _) => premiumError(context, '$e'),
              data: (athletes) {
                // varsayılan: tümü Var
                for (final a in athletes) {
                  _marks.putIfAbsent(a.id, () => 'present');
                }
                final present =
                    _marks.values.where((v) => v == 'present').length;
                final total = athletes.length;
                final pct = total == 0 ? 0.0 : present / total;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 20, 12),
                      child: Row(
                        children: [
                          _back(context, surf, line, ink),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Canlı Yoklama', style: SwanType.h3(ink)),
                                Text(club?.name ?? 'Kadro',
                                    style: SwanType.h3(ink)),
                              ],
                            ),
                          ),
                          SwanRing(
                            value: pct,
                            size: 52,
                            stroke: 6,
                            track: isDark
                                ? SwanPalette.dark.surfaceAlt
                                : SwanPalette.light.surfaceAlt,
                            progress: kTeal,
                            center: Text('%${(pct * 100).round()}',
                                style: SwanType.h3(ink)),
                          ),
                        ],
                      ),
                    ),
                    if (athletes.isEmpty)
                      Expanded(
                        child: premiumEmpty(
                          context,
                          icon: Icons.groups_rounded,
                          title: 'Sporcu yok',
                          subtitle: 'Önce Kadro’dan sporcu ekle.',
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          itemCount: athletes.length,
                          itemBuilder: (_, i) =>
                              _tile(isDark, athletes[i], i, line),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: (club == null)
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: surf,
                  border: Border(top: BorderSide(color: line)),
                ),
                child: GestureDetector(
                  onTap: _saving ? null : () => _save(club),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                            color: kTeal.withValues(alpha: 0.34),
                            blurRadius: 18,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Text(
                      _saving
                          ? 'Kaydediliyor…'
                          : 'Yoklamayı Kaydet · ${_marks.length}',
                      style: SwanType.bodySm(Colors.white, w: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _tile(bool isDark, AthleteRow a, int i, Color line) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: line))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              GradientAvatar(
                  initials: a.initials,
                  gradientIndex: i % 4,
                  size: 36,
                  radius: 12),
              const SizedBox(width: 11),
              Expanded(
                  child: Text(a.fullName,
                      style: SwanType.bodySm(ink, w: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              for (var j = 0; j < _opts.length; j++) ...[
                if (j > 0) const SizedBox(width: 6),
                _tap(a.id, _opts[j].$1, _opts[j].$2, _opts[j].$3, isDark),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tap(String id, String value, String label, Color color, bool isDark) {
    final on = _marks[id] == value;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _marks[id] = value),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? color : alt,
            borderRadius: BorderRadius.circular(11),
            boxShadow: on
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.34),
                        blurRadius: 12,
                        offset: const Offset(0, 5))
                  ]
                : null,
          ),
          child: Text(label,
              style: SwanType.caption(on ? Colors.white : SwanColors.textSecondary, w: FontWeight.w700)),
        ),
      ),
    );
  }

  Future<void> _save(ClubRef club) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(clubDataServiceProvider)
          .saveAttendance(club.id, Map<String, String>.from(_marks));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Yoklama sunucuya kaydedildi'),
              backgroundColor: kTeal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: SwanPalette.light.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _back(BuildContext context, Color surf, Color line, Color ink) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: line),
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: ink),
      ),
    );
  }
}
