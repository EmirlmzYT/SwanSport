import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../routing/athlete_detail_route_args.dart';
import '../widgets/add_athlete_sheet.dart';
import '../widgets/link_athletes_sheet.dart';

/// Sporcu & Antrenör Çalışma Alanı (Stitch Calm Athletic Modernism v3).
///
/// Günlük Odak Hub'ı, Etkileşimli Görev Listesi, Taktik Not Defteri,
/// Hızlı Saha Araçları ve Kulüp Kadro Yönetimini tek çatı altında birleştirir.
class AthleteWorkspaceScreen extends ConsumerStatefulWidget {
  const AthleteWorkspaceScreen({super.key});

  @override
  ConsumerState<AthleteWorkspaceScreen> createState() =>
      _AthleteWorkspaceScreenState();
}

class _AthleteWorkspaceScreenState
    extends ConsumerState<AthleteWorkspaceScreen> {
  int _filter = 0;
  static const _filters = ['Tüm Kadro', 'Aktif', 'Pasif'];
  String _searchQuery = '';

  void _openStopwatch(BuildContext context, SwanPalette c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StopwatchSheet(c: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    final clubAsync = ref.watch(activeClubProvider);
    final athletesAsync = ref.watch(clubAthletesProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              color: c.accent,
              onRefresh: () async {
                ref.invalidate(myClubsProvider);
                ref.invalidate(clubAthletesProvider);
                await ref.read(clubAthletesProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                children: [
                  // --- 1. Üst Bar: Geri, Başlık, Arama, Filtre, Profil ---
                  _buildHeader(context, c, isDark, clubAsync.valueOrNull),
                  const SizedBox(height: 16),

                  _toolButton(c,
                      icon: Icons.timer,
                      iconColor: c.accent,
                      title: 'Kronometre',
                      subtitle: 'Tur sayacı',
                      onTap: () => _openStopwatch(context, c)),
                  const SizedBox(height: 24),

                  // --- 8. Kulüp Kadrosu & Canlı Veri Listesi ---
                  _buildRosterSectionHeader(
                      c,
                      athletesAsync.valueOrNull?.length ?? 0,
                      clubAsync.valueOrNull),
                  const SizedBox(height: 12),

                  if (clubAsync.valueOrNull != null)
                    _unlinkedBanner(c, clubAsync.valueOrNull!),

                  _buildSearchAndFilters(c),
                  const SizedBox(height: 12),

                  // Liste Durumları
                  clubAsync.when(
                    loading: () => premiumLoading(),
                    error: (e, _) => _errorState(c, '$e'),
                    data: (club) {
                      if (club == null) return _noClubState(c);
                      return athletesAsync.when(
                        loading: () => premiumLoading(),
                        error: (e, _) => _errorState(c, '$e'),
                        data: (athletes) {
                          if (athletes.isEmpty)
                            return _emptyRosterState(c, club);

                          final filtered = athletes.where((a) {
                            if (_searchQuery.isNotEmpty) {
                              if (!trContains(a.fullName, _searchQuery) &&
                                  !trContains(a.position ?? '', _searchQuery))
                                return false;
                            }
                            if (_filter == 1) return a.isActive;
                            if (_filter == 2) return !a.isActive;
                            return true;
                          }).toList();

                          return Column(
                            children: List.generate(filtered.length, (i) {
                              return _athleteRow(context, c, filtered[i], i,
                                  i == filtered.length - 1);
                            }),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
      floatingActionButton: clubAsync.valueOrNull != null &&
              ref.watch(swanAccessProvider).isClubStaff
          ? Container(
              margin: const EdgeInsets.only(bottom: 70),
              child: FloatingActionButton.extended(
                backgroundColor: c.accent,
                elevation: 4,
                onPressed: () => _showAddAthlete(clubAsync.valueOrNull!),
                icon:
                    const Icon(Icons.add_circle, color: Colors.white, size: 20),
                label: Text(
                  'Yeni Sporcu Ekle',
                  style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
                ),
              ),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // ÜST BAR
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
    BuildContext context,
    SwanPalette c,
    bool isDark,
    ClubRef? club,
  ) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back, color: c.ink, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kulüp Kadrosu',
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              Text(
                club?.name ?? 'Kulüp seçilmedi',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: Icon(Icons.tune, color: c.inkMuted, size: 20),
          tooltip: 'Kulüp Ayarları',
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CANLI HUB SATIRI
  // ---------------------------------------------------------------------------
  Widget _toolButton(
    SwanPalette c, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KADRO BÖLÜMÜ BAŞLIK & ARAMA & FİLTRELER
  // ---------------------------------------------------------------------------
  Widget _buildRosterSectionHeader(SwanPalette c, int count, ClubRef? club) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kulüp Kadrosu · $count',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            Text(
              'Sporcu listesi ve hesap bağlantıları',
              style: SwanType.caption(c.inkMuted),
            ),
          ],
        ),
        if (club != null && ref.watch(swanAccessProvider).isClubStaff)
          IconButton(
            onPressed: () => _showAddAthlete(club),
            icon: Icon(Icons.person_add_alt_1, color: c.accent, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilters(SwanPalette c) {
    return Column(
      children: [
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
                    hintText: 'Sporcu ara...',
                    hintStyle: SwanType.bodySm(c.inkMuted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final active = i == _filter;
              return InkWell(
                onTap: () => setState(() => _filter = i),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? c.accent : c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? c.accent : c.line),
                  ),
                  child: Text(
                    _filters[i],
                    style: SwanType.caption(
                      active ? Colors.white : c.inkMuted,
                      w: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // KADRO SATIRI
  // ---------------------------------------------------------------------------
  Widget _athleteRow(
    BuildContext context,
    SwanPalette c,
    AthleteRow a,
    int index,
    bool isLast,
  ) {
    final ok = a.isActive;
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/athlete-detail',
        arguments: AthleteDetailRouteArgs(athleteId: SwanId(a.id)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            GradientAvatar(initials: a.initials, gradientIndex: index % 4),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.fullName,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.position ?? 'Sporcu',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ok
                    ? c.accent.withValues(alpha: 0.15)
                    : const Color(0xFFFFB6A4).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ok ? Icons.check_circle : Icons.pause_circle_filled,
                    size: 14,
                    color: ok ? c.accent : const Color(0xFFFFB6A4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ok ? 'Aktif' : 'Pasif',
                    style: SwanType.caption(
                      ok ? c.accent : const Color(0xFFFFB6A4),
                      w: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BAĞLANTISIZ SPORCU UYARISI
  // ---------------------------------------------------------------------------
  Widget _unlinkedBanner(SwanPalette c, ClubRef club) {
    final rows = ref.watch(unlinkedAthletesProvider(club.id)).valueOrNull;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          await showLinkAthletesSheet(context, club.id);
          if (mounted) ref.invalidate(clubAthletesProvider);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFB6A4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link_off_rounded,
                  size: 20, color: Color(0xFFFFB6A4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${rows.length} sporcu hesaba bağlı değil — antrenman oturumuna katılamaz',
                  style: SwanType.bodySm(c.ink),
                ),
              ),
              Text(
                'Eşleştir',
                style: SwanType.bodySm(c.accent, w: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // YARDIMCI VE DİYALOGLAR
  // ---------------------------------------------------------------------------
  Widget _errorState(SwanPalette c, String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 36, color: Colors.red),
            const SizedBox(height: 8),
            Text('Veri yüklenemedi',
                style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
            Text(msg, style: SwanType.caption(c.inkMuted)),
          ],
        ),
      ),
    );
  }

  Widget _noClubState(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.add_business_rounded, color: c.accent, size: 36),
            const SizedBox(height: 12),
            Text('Henüz bir kulübün yok',
                style: GoogleFonts.sora(
                    fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
            const SizedBox(height: 4),
            Text('Başlamak için bir kulüp oluştur.',
                style: SwanType.caption(c.inkMuted)),
          ],
        ),
      ),
    );
  }

  Widget _emptyRosterState(SwanPalette c, ClubRef club) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.groups_rounded, color: c.accent, size: 36),
            const SizedBox(height: 12),
            Text('Kadro boş',
                style: GoogleFonts.sora(
                    fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
            const SizedBox(height: 4),
            Text('İlk sporcunu ekleyerek başla.',
                style: SwanType.caption(c.inkMuted)),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAthlete(ClubRef club) async {
    final choice = await showAddAthleteSheet(context, club.id);
    if (choice == null || !mounted) return;

    switch (choice) {
      case AddAthleteFromMember(:final profileId, :final fullName):
        await _addFromMember(club, profileId, fullName);
      case AddAthleteManually():
        await _addManually(club);
    }
  }

  Future<void> _addFromMember(
      ClubRef club, String profileId, String fullName) async {
    String? first;
    String? last;

    if (fullName.trim().isEmpty) {
      final firstCtrl = TextEditingController();
      final lastCtrl = TextEditingController();
      final ok = await _formDialog(
        title: 'Sporcunun Adı',
        fields: [
          _DialogField('Ad', firstCtrl),
          _DialogField('Soyad', lastCtrl),
        ],
        action: 'Ekle',
      );
      if (ok != true) return;
      if (firstCtrl.text.trim().isEmpty) return;
      first = firstCtrl.text.trim();
      last = lastCtrl.text.trim();
    }

    await _run(() async {
      await ref.read(athleteServiceProvider).createAthleteFromMember(
            clubId: club.id,
            profileId: profileId,
            firstName: first,
            lastName: last,
          );
      ref.invalidate(clubAthletesProvider);
      ref.invalidate(clubMemberCandidatesProvider(club.id));
      ref.invalidate(unlinkedAthletesProvider(club.id));
    }, success: 'Sporcu eklendi ve hesabına bağlandı');
  }

  Future<void> _addManually(ClubRef club) async {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final ok = await _formDialog(
      title: 'Hesabı Olmayan Sporcu',
      fields: [
        _DialogField('Ad', firstCtrl),
        _DialogField('Soyad', lastCtrl),
        _DialogField('Pozisyon (opsiyonel)', posCtrl),
      ],
      action: 'Ekle',
    );
    if (ok != true) return;
    if (firstCtrl.text.trim().isEmpty || lastCtrl.text.trim().isEmpty) return;
    await _run(() async {
      await ref.read(athleteServiceProvider).addAthlete(
            clubId: club.id,
            firstName: firstCtrl.text.trim(),
            lastName: lastCtrl.text.trim(),
            position: posCtrl.text.trim(),
          );
      ref.invalidate(clubAthletesProvider);
      ref.invalidate(unlinkedAthletesProvider(club.id));
    }, success: 'Sporcu eklendi — henüz bir hesaba bağlı değil');
  }

  Future<void> _run(Future<void> Function() task,
      {required String success}) async {
    final c = Theme.of(context).brightness == Brightness.dark
        ? SwanPalette.dark
        : SwanPalette.light;
    try {
      await task();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: c.accent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool?> _formDialog({
    required String title,
    required List<_DialogField> fields,
    required String action,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: GoogleFonts.sora(
                fontSize: 18, fontWeight: FontWeight.w700, color: c.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in fields) ...[
              TextField(
                controller: f.controller,
                style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: f.label,
                  labelStyle: SwanType.caption(c.inkMuted),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal',
                style: SwanType.bodySm(c.inkMuted, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action,
                style: SwanType.bodySm(c.accent, w: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _DialogField {
  const _DialogField(this.label, this.controller);
  final String label;
  final TextEditingController controller;
}

class _StopwatchSheet extends StatefulWidget {
  const _StopwatchSheet({required this.c});

  final SwanPalette c;

  @override
  State<_StopwatchSheet> createState() => _StopwatchSheetState();
}

class _StopwatchSheetState extends State<_StopwatchSheet> {
  Timer? _timer;
  int _milliseconds = 0;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        setState(() => _milliseconds += 100);
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _milliseconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final totalSec = _milliseconds ~/ 1000;
    final min = (totalSec ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    final ms = ((_milliseconds % 1000) ~/ 100).toString();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Saha Kronometresi',
              style: GoogleFonts.sora(
                  fontSize: 18, fontWeight: FontWeight.w700, color: c.ink),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.line),
              ),
              child: Text(
                '$min:$sec.$ms',
                style: GoogleFonts.sora(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: c.accent,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Sıfırla'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.ink,
                    side: BorderSide(color: c.line),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(
                      _isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 20),
                  label: Text(_isRunning ? 'Durdur' : 'Başlat'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
