import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

import '../../../../app/widgets/premium.dart';
import '../routing/athlete_detail_route_args.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

/// Sporcu Yönetimi (Kadro) — Supabase verisine bağlı, premium tasarım (v3).
class AthleteWorkspaceScreen extends ConsumerStatefulWidget {
  const AthleteWorkspaceScreen({super.key});

  @override
  ConsumerState<AthleteWorkspaceScreen> createState() =>
      _AthleteWorkspaceScreenState();
}

class _AthleteWorkspaceScreenState
    extends ConsumerState<AthleteWorkspaceScreen> {
  int _filter = 0;
  static const _filters = ['Bugünkü Takım', 'Lisans', 'Pozisyon'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final clubAsync = ref.watch(activeClubProvider);
    final athletesAsync = ref.watch(clubAthletesProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myClubsProvider);
                ref.invalidate(clubAthletesProvider);
                await ref.read(clubAthletesProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  // Başlık
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clubAsync.valueOrNull?.name.toUpperCase() ??
                                  'KADRO',
                              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              athletesAsync.maybeWhen(
                                data: (a) => 'Kadro · ${a.length}',
                                orElse: () => 'Kadro',
                              ),
                              style: SwanType.h2(ink),
                            ),
                          ],
                        ),
                      ),
                      if (clubAsync.valueOrNull != null)
                        GestureDetector(
                          onTap: () => _showAddAthlete(clubAsync.value!),
                          child:
                              _iconBtn(isDark, Icons.person_add_alt_1_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _searchField(isDark),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _chip(isDark, _filters[i],
                          i == _filter, () => setState(() => _filter = i)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // İçerik: kulüp yok / yükleniyor / hata / liste
                  clubAsync.when(
                    loading: () => _loading(),
                    error: (e, _) => _error(isDark, '$e'),
                    data: (club) {
                      if (club == null) return _noClub(isDark);
                      return athletesAsync.when(
                        loading: () => _loading(),
                        error: (e, _) => _error(isDark, '$e'),
                        data: (athletes) {
                          if (athletes.isEmpty) return _empty(isDark, club);
                          return Column(
                            children: List.generate(athletes.length, (i) {
                              return _athleteRow(context, isDark, athletes[i],
                                  i, i == athletes.length - 1);
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
    );
  }

  // ------------------------------------------------------------- durumlar
  Widget _loading() => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: kTeal)),
      );

  Widget _error(bool isDark, String msg) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 40, color: SwanPalette.light.danger),
          const SizedBox(height: 12),
          Text('Veri yüklenemedi', style: SwanType.bodySm(ink, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(msg,
              textAlign: TextAlign.center,
              style: SwanType.caption(SwanColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _noClub(bool isDark) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child:
                const Icon(Icons.add_business_rounded, color: kTeal, size: 30),
          ),
          const SizedBox(height: 16),
          Text('Henüz bir kulübün yok', style: SwanType.h3(ink)),
          const SizedBox(height: 6),
          Text('Başlamak için bir kulüp oluştur.',
              style: SwanType.caption(SwanColors.textSecondary)),
          const SizedBox(height: 20),
          _primaryButton('Kulüp Oluştur', _showCreateClub),
        ],
      ),
    );
  }

  Widget _empty(bool isDark, ClubRef club) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.groups_rounded, color: kTeal, size: 30),
          ),
          const SizedBox(height: 16),
          Text('Kadro boş', style: SwanType.h3(ink)),
          const SizedBox(height: 6),
          Text('İlk sporcunu ekleyerek başla.',
              style: SwanType.caption(SwanColors.textSecondary)),
          const SizedBox(height: 20),
          _primaryButton('Sporcu Ekle', () => _showAddAthlete(club)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- satır
  Widget _athleteRow(
      BuildContext context, bool isDark, AthleteRow a, int index, bool isLast) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ok = a.isActive;
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/athlete-detail',
        arguments: AthleteDetailRouteArgs(athleteId: SwanId(a.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            GradientAvatar(initials: a.initials, gradientIndex: index % 4),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.fullName, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    a.position ?? 'Sporcu',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PremiumStatusChip(
              label: ok ? 'Aktif' : 'Pasif',
              color: ok ? SwanPalette.light.success : SwanPalette.light.warning,
              icon: ok
                  ? Icons.check_circle_rounded
                  : Icons.pause_circle_filled_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- diyaloglar
  Future<void> _showCreateClub() async {
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final ok = await _formDialog(
      title: 'Kulüp Oluştur',
      fields: [
        _DialogField('Kulüp adı', nameCtrl),
        _DialogField('Şehir (opsiyonel)', cityCtrl),
      ],
      action: 'Oluştur',
    );
    if (ok != true) return;
    if (nameCtrl.text.trim().isEmpty) return;
    var created = false;
    await _run(() async {
      await ref
          .read(athleteServiceProvider)
          .createClub(nameCtrl.text.trim(), city: cityCtrl.text.trim());
      ref.invalidate(myClubsProvider);
      ref.invalidate(clubAthletesProvider);
      await ref.read(activeClubProvider.future);
      created = true;
    }, success: 'Kulüp oluşturuldu — belgeleri yükle');
    // Kulüp PENDING oluşturulur; panele gidince kilit + belge yükleme ekranı
    // (ClubPendingScreen) açılır. Yalnızca başarılıysa yönlendir.
    if (created && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
    }
  }

  Future<void> _showAddAthlete(ClubRef club) async {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final ok = await _formDialog(
      title: 'Sporcu Ekle',
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
    }, success: 'Sporcu eklendi');
  }

  Future<void> _run(Future<void> Function() task,
      {required String success}) async {
    try {
      await task();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: kTeal),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: SwanPalette.light.danger),
      );
    }
  }

  Future<bool?> _formDialog({
    required String title,
    required List<_DialogField> fields,
    required String action,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: SwanType.h3(ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in fields) ...[
              TextField(
                controller: f.controller,
                style: SwanType.bodySm(ink, w: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: f.label,
                  labelStyle:
                      SwanType.caption(SwanColors.textSecondary),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kTeal, width: 1.5),
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
                style: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: SwanType.bodySm(kTeal, w: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- parçalar
  Widget _primaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kTealBright, kTeal]),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: kTeal.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(label, style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
      ),
    );
  }

  Widget _searchField(bool isDark) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: line),
      ),
      child: TextField(
        style: SwanType.bodySm(isDark ? Colors.white : SwanColors.textPrimary, w: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Sporcu ara…',
          hintStyle: SwanType.bodySm(SwanColors.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 19, color: SwanColors.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _chip(bool isDark, String label, bool active, VoidCallback onTap) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? ink : surf,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? ink : line),
        ),
        child: Text(label,
            style: SwanType.caption(active ? bg : SwanColors.textSecondary, w: FontWeight.w700)),
      ),
    );
  }

  Widget _iconBtn(bool isDark, IconData icon) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: line),
      ),
      child: Icon(icon, size: 19, color: kTeal),
    );
  }
}

class _DialogField {
  const _DialogField(this.label, this.controller);
  final String label;
  final TextEditingController controller;
}
