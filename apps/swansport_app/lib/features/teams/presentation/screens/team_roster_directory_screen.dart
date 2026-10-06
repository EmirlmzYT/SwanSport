import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/quick_form.dart';
import '../../../../app/widgets/stitch_components.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Takımlar & Antrenman Grupları — Stitch "Calm Athletic Modernism" Takım Dizini.
class TeamRosterDirectoryScreen extends ConsumerStatefulWidget {
  const TeamRosterDirectoryScreen({super.key});

  @override
  ConsumerState<TeamRosterDirectoryScreen> createState() =>
      _TeamRosterDirectoryScreenState();
}

class _TeamRosterDirectoryScreenState
    extends ConsumerState<TeamRosterDirectoryScreen> {
  String _filter = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final canManage =
        club != null && (club.role == 'club_admin' || club.role == 'coach');
    final async = ref.watch(teamsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                StitchTopBar(
                  title: 'Takım Dizini & Kadrolar',
                  subtitle: club?.name ?? 'Kulüp Kadroları ve Programları',
                  actions: [
                    if (canManage)
                      InkWell(
                        onTap: () => _team(context, ref, club.id),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00666D),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Takım Ekle',
                                style: SwanType.caption(
                                  Colors.white,
                                  w: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
                    children: [
                      // Search Bar
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.line),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 20, color: c.inkMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v.trim().toLowerCase()),
                                style: SwanType.bodySm(c.ink),
                                decoration: InputDecoration(
                                  hintText: 'Takım adı veya yaş grubu ara...',
                                  hintStyle: SwanType.bodySm(c.inkMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            StitchFilterPill(
                              label: 'Tümü',
                              isSelected: _filter == 'all',
                              onTap: () => setState(() => _filter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            StitchFilterPill(
                              label: 'Yarışma Kadroları',
                              isSelected: _filter == 'competition',
                              onTap: () => setState(() => _filter = 'competition'),
                            ),
                            const SizedBox(width: 8),
                            StitchFilterPill(
                              label: 'Altyapı & Hazırlık',
                              isSelected: _filter == 'youth',
                              onTap: () => setState(() => _filter = 'youth'),
                            ),
                          ],
                        ),
                      ),
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
                              subtitle:
                                  'Henüz oluşturulmuş bir takım bulunmuyor.',
                            );
                          }

                          final filtered = teams.where((t) {
                            if (_searchQuery.isNotEmpty &&
                                !t.name.toLowerCase().contains(_searchQuery) &&
                                !(t.ageGroup?.toLowerCase().contains(_searchQuery) ?? false)) {
                              return false;
                            }
                            return true;
                          }).toList();

                          return Column(
                            children: List.generate(
                              filtered.length,
                              (i) => _buildTeamCard(
                                context,
                                c,
                                filtered[i],
                                i,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildTeamCard(
    BuildContext context,
    SwanPalette c,
    TeamRow t,
    int index,
  ) {
    final sub = [t.ageGroup, t.gender].where((e) => e != null).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF00666D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF00666D),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: SwanType.body(c.ink, w: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub.isNotEmpty ? sub : 'Standart Takım Kadrosu',
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00666D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Aktif',
                  style: SwanType.caption(
                    const Color(0xFF00666D),
                    w: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/takim-kadro',
                    arguments: {'id': t.id, 'name': t.name},
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00666D),
                    side: const BorderSide(color: Color(0xFF00666D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Kadroyu İncele'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00666D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Yoklama Al'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _team(BuildContext context, WidgetRef ref, String clubId) async {
    final name = FormField_('Takım adı', hint: 'U16 Klasik Yay');
    final age = FormField_('Yaş grubu', hint: 'U16', required: false);
    final gender =
        FormField_('Cinsiyet', hint: 'Kadın / Erkek / Karma', required: false);
    final ok = await showQuickForm(
      context,
      title: 'Yeni Takım Oluştur',
      fields: [name, age, gender],
      onSubmit: () => ref.read(clubDataServiceProvider).addTeam(
            clubId,
            name.value,
            ageGroup: age.value.isEmpty ? null : age.value,
            gender: gender.value.isEmpty ? null : gender.value,
          ),
    );
    if (ok == true) ref.invalidate(teamsProvider);
  }
}
