import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';

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

  static const _opts = [
    ('present', 'Var', Color(0xFF10B981)),
    ('absent', 'Yok', Color(0xFFF43F5E)),
    ('excused', 'Mazeret', Color(0xFFF59E0B)),
    ('late', 'Geç', Color(0xFF3B82F6)),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

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
                                Text('CANLI YOKLAMA',
                                    style: jakarta(10, FontWeight.w700,
                                        SwanColors.textSecondary,
                                        ls: 1.2)),
                                Text(club?.name ?? 'Kadro',
                                    style: sora(18, FontWeight.w800, ink)),
                              ],
                            ),
                          ),
                          SwanRing(
                            value: pct,
                            size: 52,
                            stroke: 6,
                            track: isDark
                                ? const Color(0xFF1A2537)
                                : const Color(0xFFF1F5F8),
                            progress: kTeal,
                            center: Text('%${(pct * 100).round()}',
                                style: sora(12, FontWeight.w800, ink)),
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
                      style: jakarta(14.5, FontWeight.w800, Colors.white),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _tile(bool isDark, AthleteRow a, int i, Color line) {
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
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
                      style: jakarta(13.5, FontWeight.w700, ink))),
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
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
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
              style: jakarta(11, FontWeight.w700,
                  on ? Colors.white : SwanColors.textSecondary)),
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
              backgroundColor: const Color(0xFFF43F5E)),
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
