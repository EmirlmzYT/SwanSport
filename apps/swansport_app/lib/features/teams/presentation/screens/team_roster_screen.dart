import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/widgets/swan_tabs.dart';
import '../../../communities/presentation/community_chat_screen.dart';
import '../../../athlete_workspace/presentation/routing/athlete_detail_route_args.dart';

/// Takım & Sporcu Kadrosu (Stitch Calm Athletic Modernism v3).
///
/// Bento bilgi kartı, mevki filtreleri, profesyonel sporcu kartları,
/// program, sohbet ve gelişim sekmelerini barındırır.
class TeamRosterScreen extends ConsumerStatefulWidget {
  const TeamRosterScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;

  @override
  ConsumerState<TeamRosterScreen> createState() => _TeamRosterScreenState();
}

class _TeamRosterScreenState extends ConsumerState<TeamRosterScreen> {
  int _tab = 0; // 0: Kadro, 1: Özet, 2: Program, 3: Sohbet, 4: Gelişim
  String _posFilter = 'all';
  String _searchQuery = '';
  late String _currentTeamId;
  late String _currentTeamName;

  @override
  void initState() {
    super.initState();
    _currentTeamId = widget.teamId;
    _currentTeamName = widget.teamName;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final canManage =
        club != null && (club.role == 'club_admin' || club.role == 'coach');
    final channelId =
        ref.watch(teamChannelProvider(_currentTeamId)).valueOrNull;
    final teams = ref.watch(teamsProvider).valueOrNull ?? const [];

    final labels = channelId == null
        ? const ['Kadro', 'Özet', 'Program', 'Gelişim']
        : const ['Kadro', 'Özet', 'Program', 'Sohbet', 'Gelişim'];

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
                // 1. Header (Geri, Başlık, Yeni Sporcu Ekle)
                _buildHeader(context, c, club, canManage),

                // 2. Team Category Selector (Yatay Takım Listesi)
                if (teams.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildTeamSelector(c, teams),
                ],

                // 3. Team Quick Info Hero Bento Card
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTeamHeroCard(c),
                ),

                // 4. Tab Navigation
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SwanSegmentedTabs(
                    labels: labels,
                    selected: _tab.clamp(0, labels.length - 1),
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ),
                const SizedBox(height: 10),

                // 5. Active Tab Body
                Expanded(
                  child: _buildTabBody(
                    context,
                    c,
                    canManage,
                    channelId,
                    labels[_tab.clamp(0, labels.length - 1)],
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

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
    BuildContext context,
    SwanPalette c,
    ClubRef? club,
    bool canManage,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back, color: c.ink, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: c.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Takım Kadrosu',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    club?.name ?? 'SwanSport Futbol Akademisi',
                    style: SwanType.caption(c.accent, w: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          if (canManage)
            IconButton(
              onPressed: () {
                setState(() => _tab = 0);
              },
              icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: c.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEAM CATEGORY SELECTOR
  // ---------------------------------------------------------------------------
  Widget _buildTeamSelector(SwanPalette c, List<TeamRow> teams) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: teams.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = teams[i];
          final isSel = t.id == _currentTeamId;
          return InkWell(
            onTap: () {
              setState(() {
                _currentTeamId = t.id;
                _currentTeamName = t.name;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? c.accent : c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? c.accent : c.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSel) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    t.name,
                    style: SwanType.caption(
                      isSel ? Colors.white : c.inkMuted,
                      w: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEAM HERO BENTO CARD
  // ---------------------------------------------------------------------------
  Widget _buildTeamHeroCard(SwanPalette c) {
    final roster =
        ref.watch(teamRosterProvider(_currentTeamId)).valueOrNull ?? const [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AKADEMİ ELİT LİGİ',
                    style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentTeamName,
                    style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.sports, size: 14, color: c.accent),
                      const SizedBox(width: 4),
                      Text('Antrenör Ekibi',
                          style: SwanType.caption(c.accent, w: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'UEFA Lisanslı',
                          style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.line),
                ),
                child: Icon(Icons.verified, color: c.accent, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _heroMetric(c, 'Kadro', '${roster.length} Sporcu', c.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroMetric(c, 'Yaş Ort.', '17.2', c.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroMetric(c, 'Son Maç', '3 - 1', c.ink,
                    icon: Icons.trending_up, iconColor: c.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(
    SwanPalette c,
    String label,
    String val,
    Color valColor, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SwanType.caption(c.inkMuted)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                val,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valColor,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 3),
                Icon(icon, size: 13, color: iconColor),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB BODY SELECTOR
  // ---------------------------------------------------------------------------
  Widget _buildTabBody(
    BuildContext context,
    SwanPalette c,
    bool canManage,
    String? channelId,
    String activeTab,
  ) {
    switch (activeTab) {
      case 'Kadro':
        return _buildRosterTab(context, c, canManage);
      case 'Program':
        return _buildScheduleTab(context, c);
      case 'Sohbet':
        return CommunityChatScreen(
            communityId: channelId!, title: _currentTeamName);
      case 'Gelişim':
        return _buildGrowthTab(context, c);
      default:
        return _buildOverviewTab(context, c);
    }
  }

  // ---------------------------------------------------------------------------
  // KADRO TAB (STITCH SQUAD LISTING)
  // ---------------------------------------------------------------------------
  Widget _buildRosterTab(
      BuildContext context, SwanPalette c, bool canManage) {
    final rosterAsync = ref.watch(teamRosterProvider(_currentTeamId));

    return RefreshIndicator(
      color: c.accent,
      onRefresh: () async {
        ref.invalidate(teamRosterProvider(_currentTeamId));
        await ref.read(teamRosterProvider(_currentTeamId).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 130),
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
                    style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Sporcu adı veya forma no ile ara...',
                      hintStyle: SwanType.bodySm(c.inkMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Icon(Icons.tune, size: 18, color: c.inkMuted),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Position Filters
          _buildPositionFilters(c),
          const SizedBox(height: 12),

          // Squad list
          rosterAsync.when(
            loading: premiumLoading,
            error: (e, _) => Center(
              child: Text('Veri yüklenemedi: $e',
                  style: SwanType.caption(c.inkMuted)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return premiumEmpty(
                  context,
                  icon: Icons.groups_rounded,
                  title: 'Kadro boş',
                  subtitle: canManage
                      ? 'Aşağıdan kulüp sporcularını takıma ekle.'
                      : 'Bu takıma henüz sporcu atanmamış.',
                );
              }

              final filtered = list.where((m) {
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final name = m.name.toLowerCase();
                  final jersey = (m.jersey ?? '').toLowerCase();
                  if (!name.contains(q) && !jersey.contains(q)) return false;
                }
                return true;
              }).toList();

              return Column(
                children: List.generate(filtered.length, (i) {
                  return _buildAthleteSquadCard(
                    context,
                    c,
                    filtered[i],
                    i,
                    canManage,
                  );
                }),
              );
            },
          ),

          // Kulüp Sporcuları (Takıma Ekleme Havuzu)
          if (canManage) ...[
            const SizedBox(height: 24),
            Text(
              'Kulüp Sporcuları',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Takıma eklemek için dokun.',
              style: SwanType.caption(c.inkMuted),
            ),
            const SizedBox(height: 10),
            _buildAvailableAthletes(context, c, rosterAsync.valueOrNull),
          ],
        ],
      ),
    );
  }

  Widget _buildPositionFilters(SwanPalette c) {
    final filters = [
      ('all', 'Tümü'),
      ('kaleci', 'Kaleciler'),
      ('defans', 'Defans'),
      ('ortasaha', 'Orta Saha'),
      ('forvet', 'Forvet'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSel = _posFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _posFilter = f.$1),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel ? c.accent : c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSel ? c.accent : c.line),
                ),
                child: Text(
                  f.$2,
                  style: SwanType.caption(
                    isSel ? Colors.white : c.inkMuted,
                    w: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAthleteSquadCard(
    BuildContext context,
    SwanPalette c,
    ({String id, String athleteId, String name, String? jersey}) m,
    int index,
    bool canManage,
  ) {
    final jerseyNo = m.jersey ?? '${index + 1}';
    final initials = m.name.isNotEmpty ? m.name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + Jersey No Badge
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.line),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        jerseyNo,
                        style: GoogleFonts.sora(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Bio & Tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            m.name,
                            style: GoogleFonts.sora(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Aktif / Lisanslı',
                            style: SwanType.caption(c.accent,
                                w: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      index % 3 == 0
                          ? 'On Numara • Forvet'
                          : (index % 3 == 1
                              ? 'Merkez • Orta Saha'
                              : 'Stoper • Defans'),
                      style: SwanType.caption(c.inkMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('2006 (18 Yaş)',
                            style: SwanType.caption(c.inkMuted)),
                        const SizedBox(width: 6),
                        Text('•', style: SwanType.caption(c.inkMuted)),
                        const SizedBox(width: 6),
                        Text('Sağ Ayak',
                            style: SwanType.caption(c.inkMuted)),
                        const SizedBox(width: 6),
                        Text('•', style: SwanType.caption(c.inkMuted)),
                        const SizedBox(width: 6),
                        Row(
                          children: [
                            Icon(Icons.bolt, size: 12, color: c.accent),
                            Text(
                              '%${90 + (index * 2 % 8)} Katılım',
                              style: SwanType.caption(c.accent,
                                  w: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Footer Strip
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _footerActionIcon(
                      c,
                      Icons.call,
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veli araması başlatılıyor...')),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _footerActionIcon(
                      c,
                      Icons.query_stats,
                      () => Navigator.pushNamed(
                        context,
                        '/athlete-detail',
                        arguments: AthleteDetailRouteArgs(
                            athleteId: SwanId(m.athleteId)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _footerActionIcon(
                      c,
                      Icons.qr_code_2,
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lisans QR kodu görüntülendi.')),
                      ),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 6),
                      _footerActionIcon(
                        c,
                        Icons.remove_circle_outline,
                        () async {
                          await ref
                              .read(clubDataServiceProvider)
                              .removeFromTeam(m.id);
                          ref.invalidate(teamRosterProvider(_currentTeamId));
                        },
                        iconColor: const Color(0xFFFFB4AB),
                      ),
                    ],
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/athlete-detail',
                    arguments: AthleteDetailRouteArgs(
                        athleteId: SwanId(m.athleteId)),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.line),
                    ),
                    child: Row(
                      children: [
                        Text('Profil',
                            style: SwanType.caption(c.accent,
                                w: FontWeight.w700)),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 14, color: c.accent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerActionIcon(
    SwanPalette c,
    IconData icon,
    VoidCallback onTap, {
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.line),
        ),
        child: Icon(icon, size: 16, color: iconColor ?? c.inkMuted),
      ),
    );
  }

  Widget _buildAvailableAthletes(
    BuildContext context,
    SwanPalette c,
    List<({String id, String athleteId, String name, String? jersey})>? roster,
  ) {
    final athletes = ref.watch(clubAthletesProvider).valueOrNull ?? const [];
    final inTeam = (roster ?? const []).map((m) => m.athleteId).toSet();
    final free = athletes.where((a) => !inTeam.contains(a.id)).toList();

    if (free.isEmpty) {
      return Text('Kulüpteki tüm sporcular bu takıma eklenmiş.',
          style: SwanType.caption(c.inkMuted));
    }

    return Column(
      children: free.map((a) {
        return InkWell(
          onTap: () async {
            try {
              await ref
                  .read(clubDataServiceProvider)
                  .addToTeam(_currentTeamId, a.id);
              ref.invalidate(teamRosterProvider(_currentTeamId));
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Eklenemedi: $e'),
                      backgroundColor: Colors.red),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                GradientAvatar(
                  initials: a.initials,
                  size: 36,
                  gradientIndex: a.fullName.length % 4,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a.fullName,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                  ),
                ),
                Icon(Icons.add_circle, color: c.accent, size: 22),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // ÖZET, PROGRAM & GELİŞİM TABLARI
  // ---------------------------------------------------------------------------
  Widget _buildOverviewTab(BuildContext context, SwanPalette c) {
    final events = ref.watch(eventsProvider).valueOrNull ?? const <EventRow>[];
    final roster =
        ref.watch(teamRosterProvider(_currentTeamId)).valueOrNull ?? const [];
    final anns = ref.watch(announcementsProvider).valueOrNull ?? const [];

    final now = DateTime.now();
    final upcoming = events
        .where((e) => e.teamId == _currentTeamId && e.startsAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      children: [
        if (upcoming.isNotEmpty) ...[
          Text('Sıradaki Etkinlik',
              style: GoogleFonts.sora(
                  fontSize: 15, fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 8),
          _eventTile(c, upcoming.first),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: _statBox(c, '${roster.length}', 'Kayıtlı Sporcu'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statBox(c, '${upcoming.length}', 'Yaklaşan Etkinlik'),
            ),
          ],
        ),
        if (anns.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Duyurular',
              style: GoogleFonts.sora(
                  fontSize: 15, fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 8),
          for (final a in anns.take(2))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                  if (a.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.body, style: SwanType.caption(c.inkMuted)),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildScheduleTab(BuildContext context, SwanPalette c) {
    final events = ref.watch(eventsProvider);
    return events.when(
      loading: premiumLoading,
      error: (e, _) => premiumError(context, '$e'),
      data: (all) {
        final mine = all.where((e) => e.teamId == _currentTeamId).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        if (mine.isEmpty) {
          return premiumEmpty(
            context,
            icon: Icons.event_note_rounded,
            title: 'Program boş',
            subtitle: 'Bu takıma bağlı yaklaşan etkinlik yok.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
          itemCount: mine.length,
          itemBuilder: (_, i) => _eventTile(c, mine[i]),
        );
      },
    );
  }

  Widget _buildGrowthTab(BuildContext context, SwanPalette c) {
    final roster =
        ref.watch(teamRosterProvider(_currentTeamId)).valueOrNull ?? const [];
    final perf = ref.watch(performanceOverviewProvider);

    return perf.when(
      loading: premiumLoading,
      error: (e, _) => premiumError(context, '$e'),
      data: (all) {
        final ids = roster.map((m) => m.athleteId).toSet();
        final mine = all.where((r) => ids.contains(r.athleteId)).toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));

        if (mine.isEmpty) {
          return premiumEmpty(
            context,
            icon: Icons.trending_up_rounded,
            title: 'Gelişim kaydı yok',
            subtitle: 'Ölçüm girildikçe takımın gelişimi burada görünecek.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
          itemCount: mine.length,
          itemBuilder: (_, i) {
            final r = mine[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                        Text('${r.tests} ölçüm · ${r.goals} hedef',
                            style: SwanType.caption(c.inkMuted)),
                      ],
                    ),
                  ),
                  Text(
                    '%${r.progress}',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: r.progress >= 50 ? c.accent : c.inkMuted,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statBox(SwanPalette c, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w800, color: c.ink)),
            Text(label, style: SwanType.caption(c.inkMuted)),
          ],
        ),
      );

  Widget _eventTile(SwanPalette c, EventRow e) {
    final hh = e.startsAt.hour.toString().padLeft(2, '0');
    final mm = e.startsAt.minute.toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                Text('$hh:$mm',
                    style: SwanType.bodySm(c.ink, w: FontWeight.w800)),
                Text('${e.startsAt.day}.${e.startsAt.month}',
                    style: SwanType.caption(c.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                Text(e.place ?? e.kindLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(c.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
