import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../demo/demo_role.dart';
import 'admin_review_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';

/// Platform Yönetimi — sistem yöneticisinin paneli.
///
/// Tek uzun liste yerine sekmeler: bekleyen işler, kişi yönetimi, karar
/// geçmişi ve veri eksikleri. Yönetici çoğu zaman yalnızca "bugün ne
/// yapmam gerekiyor" sorusuyla giriyor, o yüzden açılış sekmesi bekleyen
/// işler ve tepesinde sayılar var.
class AdminReviewScreen extends ConsumerStatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  ConsumerState<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends ConsumerState<AdminReviewScreen> {
  int _tab = 0;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(platformStatsProvider);
    ref.invalidate(pendingCredentialsProvider);
    ref.invalidate(pendingClubsProvider);
    ref.invalidate(openReportsProvider);
    ref.invalidate(reviewLogProvider);
    ref.invalidate(sportlessCredentialsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final isAdmin = ref.watch(effectiveIsPlatformAdminProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sistem Yöneticisi', style: SwanType.h3(ink),),
                    const SizedBox(height: 3),
                    Text('Platform Yönetimi',
                        style: SwanType.h2(ink)),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              if (!isAdmin)
                Expanded(
                  child: premiumEmpty(
                    context,
                    icon: Icons.lock_rounded,
                    title: 'Yetkin yok',
                    subtitle: 'Bu ekran yalnızca platform yöneticisine açık.',
                  ),
                )
              else ...[
                _tabBar(isDark, ink),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _refreshAll();
                      await ref.read(platformStatsProvider.future);
                    },
                    child: switch (_tab) {
                      1 => _peopleTab(isDark, ink),
                      2 => _historyTab(isDark, ink),
                      3 => _gapsTab(isDark, ink),
                      _ => _pendingTab(isDark, ink),
                    },
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  // ------------------------------- sekmeler -------------------------------
  Widget _tabBar(bool isDark, Color ink) {
    const labels = ['Bekleyen', 'Kişiler', 'Geçmiş', 'Eksikler'];
    final pending = ref.watch(platformStatsProvider).valueOrNull?.pendingTotal ?? 0;

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        itemBuilder: (_, i) {
          final active = _tab == i;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? kTeal
                    : (isDark ? const Color(0xFF1A2537) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: active
                        ? kTeal
                        : (isDark
                            ? const Color(0xFF233149)
                            : const Color(0xFFEAEEF3)),),
              ),
              child: Row(children: [
                Text(labels[i],
                    style: SwanType.caption(active ? Colors.white : ink, w: FontWeight.w800),),
                // Bekleyen iş sayısı sekmenin üstünde dursun ki panele
                // girmeden de görünsün.
                if (i == 0 && pending > 0) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1,),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: .25)
                          : const Color(0xFFF43F5E),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$pending',
                        style: SwanType.caption(Colors.white, w: FontWeight.w800)),
                  ),
                ],
              ],),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------- 1) BEKLEYEN İŞLER --------------------------
  Widget _pendingTab(bool isDark, Color ink) {
    final creds = ref.watch(pendingCredentialsProvider);
    final clubs = ref.watch(pendingClubsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
      children: [
        _statsBoard(isDark, ink),
        const SizedBox(height: 22),
        _sectionTitle('KULÜP BAŞVURULARI'),
        clubs.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? adminNoneText(isDark, 'Bekleyen kulüp yok')
              : Column(
                  children: list
                      .map((c) => _clubRow(context, ref, isDark, c))
                      .toList(),),
        ),
        const SizedBox(height: 22),
        _sectionTitle('BİREY DOĞRULAMALARI'),
        creds.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? adminNoneText(isDark, 'Bekleyen doğrulama yok')
              : Column(
                  children: list
                      .map((c) => _credRow(context, ref, isDark, c))
                      .toList(),),
        ),
        const SizedBox(height: 22),
        _sectionTitle('ŞİKAYETLER'),
        ref.watch(openReportsProvider).when(
              loading: premiumLoading,
              error: (e, _) => premiumError(context, '$e'),
              data: (list) => list.isEmpty
                  ? adminNoneText(isDark, 'Açık şikayet yok')
                  : Column(
                      children: list
                          .map((r) => adminReportRow(context, ref, isDark, r))
                          .toList(),),
            ),
        const SizedBox(height: 22),
        _sectionTitle('KISAYOLLAR'),
        _shortcut(isDark, ink, Icons.verified_rounded,
            'Federasyon yetkilileri', 'Duyuru yazma yetkisi ver / al',
            () => Navigator.pushNamed(context, '/federasyon-yetkili'),),
        _shortcut(isDark, ink, Icons.rss_feed_rounded, 'Haber kaynakları',
            'Ana akışta görünen RSS beslemeleri',
            () => Navigator.pushNamed(context, '/haber-kaynaklari'),),
      ],
    );
  }

  /// Özet tablo — panelin tepesindeki sayılar.
  Widget _statsBoard(bool isDark, Color ink) {
    final async = ref.watch(platformStatsProvider);
    final s = async.valueOrNull;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    Widget cell(String label, int value, {bool alert = false}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: SwanType.h2(alert && value > 0 ? const Color(0xFFF43F5E) : ink),),
              const SizedBox(height: 2),
              Text(label,
                  style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600),),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: async.isLoading && s == null
          ? premiumLoading()
          : Column(children: [
              Row(children: [
                cell('Kişi', s?.people ?? 0),
                cell('Kulüp', s?.clubsActive ?? 0),
                cell('Antrenör', s?.coaches ?? 0),
                cell('Sporcu', s?.athletes ?? 0),
              ],),
              const SizedBox(height: 16),
              Divider(color: line, height: 1),
              const SizedBox(height: 16),
              Row(children: [
                cell('Bekleyen kulüp', s?.clubsPending ?? 0, alert: true),
                cell('Bekleyen belge', s?.credsPending ?? 0, alert: true),
                cell('Açık şikayet', s?.reportsOpen ?? 0, alert: true),
                cell('Gönderi', s?.posts ?? 0),
              ],),
            ],),
    );
  }

  Widget _shortcut(bool isDark, Color ink, IconData icon, String title,
      String sub, VoidCallback onTap,) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Icon(icon, size: 19, color: kTeal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SwanType.bodySm(ink, w: FontWeight.w800)),
                Text(sub,
                    style: SwanType.caption(SwanColors.textSecondary),),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: SwanColors.textSecondary,),
        ],),
      ),
    );
  }

  // ------------------------------ 2) KİŞİLER -------------------------------
  Widget _peopleTab(bool isDark, Color ink) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final people = ref.watch(adminPeopleProvider(_query));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v.trim()),
          style: SwanType.bodySm(ink),
          decoration: InputDecoration(
            hintText: 'Ad veya kullanıcı adı ara…',
            hintStyle:
                SwanType.bodySm(SwanColors.textSecondary),
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            filled: true,
            fillColor: surf,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: line),),
          ),
        ),
        const SizedBox(height: 14),
        people.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? adminNoneText(isDark, 'Kişi bulunamadı')
              : Column(
                  children: [
                    for (final p in list) _personRow(isDark, ink, p),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _personRow(bool isDark, Color ink, AdminPerson p) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: p.isAdmin ? kTeal.withValues(alpha: .45) : line,),
      ),
      child: Row(children: [
        GradientAvatar(initials: p.initials, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.bodySm(ink, w: FontWeight.w800),),
                ),
                if (p.isAdmin) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2,),
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Yönetici',
                        style: SwanType.caption(kTeal, w: FontWeight.w800)),
                  ),
                ],
              ],),
              const SizedBox(height: 2),
              Text(p.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(SwanColors.textSecondary),),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _openPerson(p),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.more_horiz_rounded, size: 18, color: ink),
          ),
        ),
      ],),
    );
  }

  Future<void> _openPerson(AdminPerson p) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom,),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GradientAvatar(initials: p.initials, size: 56, radius: 18),
          const SizedBox(height: 10),
          Text(p.name, style: SwanType.h3(ink)),
          const SizedBox(height: 3),
          Text(p.subtitle,
              textAlign: TextAlign.center,
              style: SwanType.caption(SwanColors.textSecondary),),
          const SizedBox(height: 18),
          _sheetAction(ink, Icons.person_rounded, 'Profili aç', () {
            Navigator.pop(ctx);
            Navigator.pushNamed(context, '/profil', arguments: p.id);
          },),
          _sheetAction(
            ink,
            p.isAdmin
                ? Icons.remove_moderator_rounded
                : Icons.admin_panel_settings_rounded,
            p.isAdmin ? 'Yöneticiliği kaldır' : 'Platform yöneticisi yap',
            () {
              Navigator.pop(ctx);
              _toggleAdmin(p);
            },
            danger: p.isAdmin,
          ),
        ],),
      ),
    );
  }

  Widget _sheetAction(Color ink, IconData icon, String label, VoidCallback onTap,
      {bool danger = false,}) {
    final color = danger ? const Color(0xFFF43F5E) : ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 13),
          Expanded(
            child: Text(label, style: SwanType.bodySm(color, w: FontWeight.w700)),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: SwanColors.textSecondary,),
        ],),
      ),
    );
  }

  Future<void> _toggleAdmin(AdminPerson p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.isAdmin ? 'Yöneticiliği kaldır' : 'Yönetici yap'),
        content: Text(p.isAdmin
            ? '${p.name} artık platform yönetimi paneline giremeyecek.'
            : '${p.name} tüm kulüpleri, belgeleri ve şikayetleri '
                'yönetebilecek. Bu yetki geniştir.',),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(p.isAdmin ? 'Kaldır' : 'Yetki ver'),),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(adminServiceProvider)
          .setPlatformAdmin(p.id, !p.isAdmin);
      ref.invalidate(adminPeopleProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(p.isAdmin
                ? 'Yöneticilik kaldırıldı'
                : '${p.name} artık yönetici',),
            backgroundColor: kTeal,),);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: const Color(0xFFF43F5E),),);
      }
    }
  }

  // ------------------------------- 3) GEÇMİŞ -------------------------------
  Widget _historyTab(bool isDark, Color ink) {
    final log = ref.watch(reviewLogProvider);
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
      children: [
        Text('Verilen kararlar geri alınamıyor; burada kimin ne zaman ne '
            'yaptığı görünür.',
            style: SwanType.caption(SwanColors.textSecondary),),
        const SizedBox(height: 14),
        log.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? adminNoneText(isDark, 'Henüz karar verilmemiş')
              : Column(children: [
                  for (final r in list)
                    Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: line),
                      ),
                      child: Row(children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: (r.approved
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF43F5E))
                                .withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                              r.approved
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              size: 16,
                              color: r.approved
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF43F5E),),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r.subject}'
                                  '${r.detail == null ? '' : ' · ${r.detail}'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: SwanType.caption(ink, w: FontWeight.w700),),
                              const SizedBox(height: 2),
                              Text([
                                r.isClub ? 'Kulüp' : 'Belge',
                                if (r.reviewer != null) r.reviewer!,
                                _ago(r.reviewedAt),
                              ].join(' · '),
                                  style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600),),
                              if (r.note != null && r.note!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Not: ${r.note}',
                                      style: SwanType.caption(SwanColors.textSecondary),),
                                ),
                            ],
                          ),
                        ),
                      ],),
                    ),
                ],),
        ),
      ],
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
    if (d.inHours < 24) return '${d.inHours} sa önce';
    if (d.inDays < 30) return '${d.inDays} gün önce';
    return '${t.day}.${t.month}.${t.year}';
  }

  // ------------------------------ 4) EKSİKLER ------------------------------
  Widget _gapsTab(bool isDark, Color ink) {
    final list = ref.watch(sportlessCredentialsProvider);
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
      children: [
        Text('Branş alanı sonradan eklendi. Aşağıdaki onaylı antrenörlerin '
            'branşı boş — federasyon kanallarına girebilmeleri için '
            'tamamlanması gerekiyor.',
            style: SwanType.caption(SwanColors.textSecondary),),
        const SizedBox(height: 14),
        list.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (rows) => rows.isEmpty
              ? adminNoneText(isDark, 'Eksik yok — hepsinin branşı tanımlı')
              : Column(children: [
                  for (final c in rows)
                    Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: line),
                      ),
                      child: Row(children: [
                        GradientAvatar(
                            initials: c.name.isEmpty
                                ? '?'
                                : c.name[0].toUpperCase(),
                            size: 38,),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
                              Text('${c.coachLevel ?? '?'}. Kademe · branş yok',
                                  style: SwanType.caption(SwanColors.textSecondary),),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _assignSport(c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 8,),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [kTealBright, kTeal],),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text('Branş ata',
                                style: SwanType.caption(Colors.white, w: FontWeight.w800),),
                          ),
                        ),
                      ],),
                    ),
                ],),
        ),
      ],
    );
  }

  Future<void> _assignSport(SportlessCredential c) async {
    final code = await _pickSport('${c.name} · branş');
    if (code == null) return;
    try {
      await ref.read(adminServiceProvider).setCredentialSport(c.id, code);
      ref.invalidate(sportlessCredentialsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Branş atandı'), backgroundColor: kTeal,),);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Atanamadı: $e'),
            backgroundColor: const Color(0xFFF43F5E),),);
      }
    }
  }

  /// Ortak branş seçici — onay ve eksik tamamlama aynı listeyi kullanır.
  Future<String?> _pickSport(String title) async {
    final sports = ref.read(sportsProvider).valueOrNull ?? const <CityRow>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    if (sports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Branş listesi yüklenemedi — FEDERATION.sql çalıştı mı?'),
          backgroundColor: Color(0xFFF43F5E),),);
      return null;
    }

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(children: [
          Text(title,
              textAlign: TextAlign.center,
              style: SwanType.h3(ink),),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: sports.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(sports[i].name,
                    style: SwanType.bodySm(ink, w: FontWeight.w600),),
                onTap: () => Navigator.pop(ctx, sports[i].code),
              ),
            ),
          ),
        ],),
      ),
    );
  }


  // --------------------- onay / ret (gerekçeli, düzeltmeli) ----------------

  /// Antrenör belgesini onaylarken kademe ve branş teyit edilir.
  ///
  /// Belge, başvuruda yazılandan farklı çıkabiliyor. Reddedip "yeniden başvur"
  /// demek yerine yönetici doğrusuyla onaylayabilsin.
  Future<void> _approveCredential(CredentialRow c) async {
    if (!c.isCoach) {
      await _run(
          context,
          ref,
          () =>
              ref.read(verificationServiceProvider).reviewCredential(c.id, true),
          'Onaylandı',);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    var level = c.coachLevel ?? 2;
    String? sportCode;
    var sportLabel = c.sportName ?? 'Başvurudaki branş';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          decoration: BoxDecoration(
            color: surf,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom,),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Onayla · ${c.personName ?? "Kişi"}',
                style: SwanType.h3(ink),),
            const SizedBox(height: 6),
            Text('Belgeyle eşleşmiyorsa buradan düzeltebilirsin.',
                textAlign: TextAlign.center,
                style: SwanType.caption(SwanColors.textSecondary),),
            const SizedBox(height: 18),
            Text('Kademe', style: SwanType.h3(ink),),
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setSheet(() => level = i),
                    child: Container(
                      height: 42,
                      margin: const EdgeInsets.only(right: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: level == i
                            ? kTeal
                            : (isDark
                                ? const Color(0xFF1A2537)
                                : const Color(0xFFF1F5F8)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$i',
                          style: SwanType.bodySm(level == i ? Colors.white : ink, w: FontWeight.w800),),
                    ),
                  ),
                ),
            ],),
            const SizedBox(height: 18),
            Text('Branş', style: SwanType.h3(ink),),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await _pickSport('Branş seç');
                if (picked == null) return;
                final name = (ref.read(sportsProvider).valueOrNull ?? const [])
                    .where((x) => x.code == picked)
                    .map((x) => x.name)
                    .firstOrNull;
                setSheet(() {
                  sportCode = picked;
                  sportLabel = name ?? picked;
                });
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A2537)
                      : const Color(0xFFF1F5F8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(sportLabel,
                        style: SwanType.bodySm(ink, w: FontWeight.w600)),
                  ),
                  const Icon(Icons.expand_more_rounded,
                      size: 19, color: SwanColors.textSecondary,),
                ],),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text('Onayla',
                    style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
              ),
            ),
          ],),
        );
      },),
    );

    if (ok != true) return;
    await _run(
        context,
        ref,
        () => ref.read(verificationServiceProvider).reviewCredential(
              c.id,
              true,
              coachLevel: level,
              sportCode: sportCode,
            ),
        'Onaylandı',);
  }

  Future<void> _rejectCredential(CredentialRow c) async {
    final note = await _askNote('Reddetme gerekçesi',
        'Kişiye görünür. Örn: belge okunmuyor, kademe eşleşmiyor.',);
    if (note == null) return;
    await _run(
        context,
        ref,
        () => ref
            .read(verificationServiceProvider)
            .reviewCredential(c.id, false, note: note),
        'Reddedildi',);
  }

  Future<void> _rejectClub(PendingClub c) async {
    final note = await _askNote('Kulübü reddet',
        'Kulüp yöneticisine görünür. Örn: tescil belgesi eksik.',);
    if (note == null) return;
    await _run(
        context,
        ref,
        () => ref.read(verificationServiceProvider).rejectClub(c.id, note: note),
        'Kulüp reddedildi',);
  }

  /// Gerekçe sorar. Vazgeçilirse null döner (boş metin geçerli sayılır).
  Future<String?> _askNote(String title, String hint) async {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: SwanType.h3(ink)),
        content: TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 5,
          autofocus: true,
          style: SwanType.bodySm(ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: SwanType.caption(SwanColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style:
                    SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700),),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reddet',
                style:
                    SwanType.bodySm(const Color(0xFFF43F5E), w: FontWeight.w800),),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return ctrl.text.trim();
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700),),
      );

  Widget _clubRow(
      BuildContext context, WidgetRef ref, bool isDark, PendingClub c,) {
    return _row(
      isDark,
      avatar: adminCrest(),
      title: c.name,
      sub: 'Tescil + federasyon belgesi · ${c.city ?? '—'}',
      onDocs: () => showAdminDocs(context, ref, 'club', c.id, c.name),
      onReject: () => _rejectClub(c),
      onApprove: () => _run(
          context,
          ref,
          () => ref.read(verificationServiceProvider).approveClub(c.id),
          'Kulüp onaylandı',),
    );
  }

  Widget _credRow(
      BuildContext context, WidgetRef ref, bool isDark, CredentialRow c,) {
    return _row(
      isDark,
      avatar: GradientAvatar(
          initials: (c.personName ?? '?').isNotEmpty
              ? c.personName![0].toUpperCase()
              : '?',
          size: 42,),
      title: c.personName ?? 'Kişi',
      sub: c.label,
      onDocs: () =>
          showAdminDocs(context, ref, 'credential', c.id, c.personName ?? 'Kişi'),
      onReject: () => _rejectCredential(c),
      onApprove: () => _approveCredential(c),
    );
  }

  Widget _row(bool isDark,
      {required Widget avatar,
      required String title,
      required String sub,
      VoidCallback? onDocs,
      required VoidCallback onReject,
      required VoidCallback onApprove,}) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SwanType.bodySm(ink, w: FontWeight.w800)),
              Text(sub,
                  style:
                      SwanType.caption(SwanColors.textSecondary),),
            ],
          ),
        ),
        if (onDocs != null) ...[
          adminMiniButton(const Color(0xFF2563EB), Icons.folder_open_rounded, onDocs),
          const SizedBox(width: 6),
        ],
        adminMiniButton(const Color(0xFFF43F5E), Icons.close_rounded, onReject),
        const SizedBox(width: 6),
        adminMiniButton(const Color(0xFF10B981), Icons.check_rounded, onApprove),
      ],),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() task, String ok,) async {
    try {
      await task();
      ref.invalidate(pendingCredentialsProvider);
      ref.invalidate(pendingClubsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ok), backgroundColor: kTeal));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: const Color(0xFFF43F5E),),);
      }
    }
  }
}
