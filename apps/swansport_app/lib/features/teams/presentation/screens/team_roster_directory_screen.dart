import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/quick_form.dart';

/// Takımlar & Antrenman Grupları — Supabase verisine bağlı, premium (v3).
class TeamRosterDirectoryScreen extends ConsumerWidget {
  const TeamRosterDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final canManage = club != null &&
        (club.role == 'club_admin' || club.role == 'coach');
    final async = ref.watch(teamsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
              children: [
                Text(club?.name.toUpperCase() ?? 'KULÜP',
                    style: jakarta(
                        11, FontWeight.w700, SwanColors.textSecondary,
                        ls: 1.4)),
                const SizedBox(height: 3),
                Row(children: [
                  Expanded(child: Text('Takımlar', style: sora(25, FontWeight.w800, ink))),
                  if (canManage)
                    AddButton(onTap: () => _team(context, ref, club!.id)),
                ]),
                const SizedBox(height: 16),
                async.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (teams) {
                    if (teams.isEmpty) {
                      return premiumEmpty(
                        context,
                        icon: Icons.shield_rounded,
                        title: 'Takım yok',
                        subtitle: 'Henüz oluşturulmuş bir takım bulunmuyor.',
                      );
                    }
                    return Column(
                      children: List.generate(teams.length,
                          (i) => _card(context, isDark, teams[i], i)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: 3,
        onSelect: (i) {
          if (i == 0) Navigator.pushNamed(context, '/akis');
          if (i == 1) Navigator.pushNamed(context, '/calendar');
          if (i == 3) Navigator.pushNamed(context, '/athletes');
          if (i == 4) Navigator.pushNamed(context, '/profil');
        },
        onAction: () => Navigator.pushNamed(context, '/attendance'),
      ),
    );
  }

  Widget _card(BuildContext context, bool isDark, TeamRow t, int index) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final sub = [t.ageGroup, t.gender].where((e) => e != null).join(' · ');
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/takim-kadro',
          arguments: {'id': t.id, 'name': t.name}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: kAvatarGradients[index % 4],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: jakarta(14.5, FontWeight.w800, ink)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: jakarta(
                            11.5, FontWeight.w500, SwanColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: SwanColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  /// Yeni takım kurar.
  Future<void> _team(BuildContext context, WidgetRef ref, String clubId) async {
    final name = FormField_('Takım adı', hint: 'U16 Erkek');
    final age = FormField_('Yaş grubu', hint: 'U16', required: false);
    final gender = FormField_('Cinsiyet', hint: 'Erkek / Kadın / Karma',
        required: false);
    final ok = await showQuickForm(
      context,
      title: 'Takım Kur',
      fields: [name, age, gender],
      onSubmit: () => ref.read(clubDataServiceProvider).addTeam(
            clubId, name.value,
            ageGroup: age.value.isEmpty ? null : age.value,
            gender: gender.value.isEmpty ? null : gender.value),
    );
    if (ok == true) ref.invalidate(teamsProvider);
  }

}
