import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/inbox_actions.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_module_app_bar.dart';
import '../../../../app/widgets/swan_scaffold.dart';
import '../../../../app/widgets/swan_tabs.dart';
import '../../settings/presentation/screens/club_training_sports_sheet.dart';
import 'club_edit_sheet.dart';

/// Mobil Kulüp Yönetim Kokpiti (Club Cockpit)
///
/// Antrenör ve kulüp yöneticilerinin tüm operasyonları tek çatı altında
/// yönetebildiği modern, sakin ve sadeleştirilmiş kontrol merkezi.
class ClubCockpitScreen extends ConsumerWidget {
  const ClubCockpitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    final clubAsync = ref.watch(activeClubProvider);
    final access = ref.watch(swanAccessProvider);
    final pendingApps =
        ref.watch(clubPendingApplicationsProvider).valueOrNull?.length ?? 0;
    final athletes =
        ref.watch(clubAthletesProvider).valueOrNull ?? const <AthleteRow>[];
    final activeAthletesCount = athletes.where((a) => a.isActive).length;
    final pendingPayments =
        ref.watch(pendingPaymentsProvider).valueOrNull ?? const <PendingPayment>[];

    return SwanScaffold(
      backgroundColor: c.bg,
      appBar: swanModuleAppBar(
        context,
        title: 'Kulüp Yönetim Kokpiti',
        actions: const [InboxActions()],
      ),
      body: clubAsync.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (club) {
          if (club == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SwanSpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 64, color: c.inkMuted),
                    const SizedBox(height: SwanSpace.md),
                    Text(
                      'Aktif bir kulüp bulunamadı',
                      style: SwanType.h3(c.ink),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SwanSpace.sm),
                    Text(
                      'Kulüp yönetim işlemlerine erişebilmek için bir kulübün yöneticisi veya antrenörü olmanız gerekir.',
                      style: SwanType.bodySm(c.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeClubProvider);
              ref.invalidate(clubPendingApplicationsProvider);
              ref.invalidate(clubAthletesProvider);
              ref.invalidate(pendingPaymentsProvider);
              ref.invalidate(eventsProvider);
              await ref.read(activeClubProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SwanSpace.lg,
                SwanSpace.md,
                SwanSpace.lg,
                SwanSpace.xl * 4,
              ),
              children: [
                // 1. KULÜP HERO KARTI (Kimlik, Logo, Şehir, Hızlı Butonlar)
                _buildClubHeroCard(context, ref, club, c, access),
                const SizedBox(height: SwanSpace.lg),

                // 2. GÜNÜN ACİL İŞLERİ (Aksiyon Kartları)
                _buildUrgentActionsSection(
                  context,
                  ref,
                  c,
                  club: club,
                  pendingApps: pendingApps,
                  pendingPaymentsCount: pendingPayments.length,
                ),
                const SizedBox(height: SwanSpace.lg),

                // 3. CANLI DURUM SAYAÇLARI (KPI Bar)
                _buildKpiStrip(
                  context,
                  c,
                  pendingApps: pendingApps,
                  activeAthletes: activeAthletesCount,
                ),
                const SizedBox(height: SwanSpace.xl),

                // 4. SADELEŞTİRİLMİŞ YÖNETİM BLOKLARI
                _buildSectionHeader('KADRO & SPORCULAR', c),
                const SizedBox(height: SwanSpace.sm),
                _buildGroupCard(
                  c,
                  children: [
                    _buildTile(
                      c,
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Yeni Sporcu / Öğrenci Ekle',
                      subtitle:
                          'WhatsApp davet linki gönder veya sahada elle kaydet',
                      badge: 'Hızlı',
                      badgeColor: c.accent,
                      onTap: () => _showAddAthleteHybridSheet(context, club),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.how_to_reg_rounded,
                      title: 'Gelen Başvurular',
                      subtitle: pendingApps > 0
                          ? '$pendingApps onay bekleyen yeni öğrenci'
                          : 'Yeni kayıt taleplerini incele',
                      badge: pendingApps > 0 ? '$pendingApps' : null,
                      badgeColor: c.warning,
                      onTap: () => Navigator.pushNamed(context, '/basvurular'),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.groups_rounded,
                      title: 'Sporcu Kadrosu',
                      subtitle: '$activeAthletesCount aktif sporcu kaydı',
                      onTap: () => Navigator.pushNamed(context, '/athletes'),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.shield_rounded,
                      title: 'Takımlar ve Yaş Grupları',
                      subtitle: 'Branş takımları, yaş kategorileri ve listeler',
                      onTap: () => Navigator.pushNamed(context, '/teams'),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.xl),

                _buildSectionHeader('ANTRENMAN & TAKVİM', c),
                const SizedBox(height: SwanSpace.sm),
                _buildGroupCard(
                  c,
                  children: [
                    _buildTile(
                      c,
                      icon: Icons.checklist_rounded,
                      title: 'Günlük Yoklama Al',
                      subtitle: 'Bugünkü antrenman için devam çizelgesi',
                      onTap: () => Navigator.pushNamed(context, '/attendance'),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.fact_check_rounded,
                      title: 'Devam Durumu & Geçmiş',
                      subtitle: 'Tüm sporcuların devam ve yoklama raporları',
                      onTap: () =>
                          Navigator.pushNamed(context, '/devam-durumu'),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.tune_rounded,
                      title: 'Antrenman Şablonları & Oturumlar',
                      subtitle: 'Branşa özel egzersiz planları ve drill havuzu',
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/antrenman-sablonlari',
                      ),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.calendar_month_rounded,
                      title: 'Kulüp Takvimi',
                      subtitle: 'Maçlar, antrenmanlar ve etkinlik programı',
                      onTap: () => Navigator.pushNamed(context, '/calendar'),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.xl),

                _buildSectionHeader('MALİ İŞLER & KASA', c),
                const SizedBox(height: SwanSpace.sm),
                _buildGroupCard(
                  c,
                  children: [
                    _buildTile(
                      c,
                      icon: Icons.notifications_active_rounded,
                      title: 'Tek Tıkla Aidat Hatırlatma',
                      subtitle:
                          'Geciken velilere WhatsApp veya bildirim ile hatırlatma gönder',
                      badge: pendingPayments.isNotEmpty
                          ? '${pendingPayments.length}'
                          : null,
                      badgeColor: c.warning,
                      onTap: () => _showFeeReminderSheet(
                        context,
                        club,
                        pendingPayments,
                      ),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.payments_rounded,
                      title: 'Aidat ve Tahsilat Yönetimi',
                      subtitle: 'Öğrenci aidat takibi ve tahsilat durumu',
                      onTap: () => Navigator.pushNamed(context, '/finans'),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.receipt_long_rounded,
                      title: 'Kulüp Gideri Ekle',
                      subtitle: 'Tesis, malzeme ve operasyon harcaması kaydet',
                      onTap: () => Navigator.pushNamed(context, '/gider-ekle'),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.xl),

                _buildSectionHeader('TESİS & OPERASYON', c),
                const SizedBox(height: SwanSpace.sm),
                _buildGroupCard(
                  c,
                  children: [
                    _buildTile(
                      c,
                      icon: Icons.inventory_2_outlined,
                      title: 'Malzeme & Zimmet Takibi',
                      subtitle: 'Kulüp envanteri ve sporculara teslim edilenler',
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/kulup/malzeme-zimmet',
                      ),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.stadium_rounded,
                      title: 'Tesisler ve Sahalar',
                      subtitle: 'Kort ve saha tahsisleri, kullanım saatleri',
                      onTap: () => Navigator.pushNamed(context, '/facilities'),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.health_and_safety_outlined,
                      title: 'Sağlık & İdari Dinlendirme',
                      subtitle: 'Sakatlık kayıtları ve dinlendirme kararları',
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/kulup/saglik-takibi',
                      ),
                    ),
                    _buildDivider(c),
                    _buildTile(
                      c,
                      icon: Icons.campaign_rounded,
                      title: 'Kulüp Duyurusu Paylaş',
                      subtitle: 'Tüm sporcu ve velilere anlık duyuru gönder',
                      onTap: () =>
                          Navigator.pushNamed(context, '/announcements'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. HERO CARD (KULÜP KİMLİĞİ)
  // -------------------------------------------------------------
  Widget _buildClubHeroCard(
    BuildContext context,
    WidgetRef ref,
    ClubRef club,
    SwanPalette c,
    SwanAccess access,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      padding: const EdgeInsets.all(SwanSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  border: Border.all(color: c.accent.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Icon(Icons.shield_rounded, color: c.accent, size: 30),
                ),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: SwanType.h3(c.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      club.city ?? 'Şehir belirtilmedi',
                      style: SwanType.bodySm(c.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: c.inkMuted, size: 22),
                tooltip: 'Kulüp Bilgilerini Düzenle',
                onPressed: () => showClubEditSheet(context, club.id),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          const Divider(height: 1),
          const SizedBox(height: SwanSpace.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: c.bg,
                    builder: (_) => FractionallySizedBox(
                      heightFactor: .9,
                      child: ClubTrainingSportsSheet(clubId: club.id),
                    ),
                  ),
                  icon: Icon(Icons.sports_rounded, size: 16, color: c.ink),
                  label: Text('Branşları Yönet', style: SwanType.bodySm(c.ink)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/kulup-profil',
                    arguments: club.id,
                  ),
                  icon: Icon(Icons.storefront_outlined, size: 16, color: c.ink),
                  label: Text('Kulüp Sayfası', style: SwanType.bodySm(c.ink)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddAthleteHybridSheet(context, club),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(
                'Yeni Sporcu / Öğrenci Ekle (QR veya Elle)',
                style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. GÜNÜN ACİL İŞLERİ (AKSİYON ODAKLI KARTLAR)
  // -------------------------------------------------------------
  Widget _buildUrgentActionsSection(
    BuildContext context,
    WidgetRef ref,
    SwanPalette c, {
    required ClubRef club,
    required int pendingApps,
    required int pendingPaymentsCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: c.accent, size: 20),
              const SizedBox(width: SwanSpace.xs),
              Text(
                'GÜNÜN ACİL İŞLERİ',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          if (pendingApps > 0) ...[
            _urgentRow(
              c,
              icon: Icons.how_to_reg_rounded,
              color: c.warning,
              text: '$pendingApps yeni sporcu başvurusu onayınızı bekliyor',
              buttonLabel: 'Onayla',
              onTap: () => Navigator.pushNamed(context, '/basvurular'),
            ),
            const SizedBox(height: SwanSpace.xs),
          ],
          _urgentRow(
            c,
            icon: Icons.checklist_rounded,
            color: c.accent,
            text: 'Günün antrenman yoklamasını başlatın',
            buttonLabel: 'Yoklama Al',
            onTap: () => Navigator.pushNamed(context, '/attendance'),
          ),
          const SizedBox(height: SwanSpace.xs),
          _urgentRow(
            c,
            icon: Icons.notifications_active_rounded,
            color: pendingPaymentsCount > 0 ? c.warning : c.inkMuted,
            text: pendingPaymentsCount > 0
                ? '$pendingPaymentsCount sporcunun aidat ödemesi bekliyor'
                : 'Velilere tek tıkla aidat hatırlatması gönderin',
            buttonLabel: 'Hatırlat',
            onTap: () => _showFeeReminderSheet(
              context,
              club,
              ref.read(pendingPaymentsProvider).valueOrNull ?? const [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _urgentRow(
    SwanPalette c, {
    required IconData icon,
    required Color color,
    required String text,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SwanSpace.sm,
        vertical: SwanSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: Text(
              text,
              style: SwanType.caption(c.ink, w: FontWeight.w600),
            ),
          ),
          const SizedBox(width: SwanSpace.xs),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SwanRadius.sm),
              ),
            ),
            child: Text(
              buttonLabel,
              style: SwanType.caption(color, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 3. KPI STRIP (CANLI SAYAÇLAR)
  // -------------------------------------------------------------
  Widget _buildKpiStrip(
    BuildContext context,
    SwanPalette c, {
    required int pendingApps,
    required int activeAthletes,
  }) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            c,
            title: 'Başvurular',
            value: '$pendingApps',
            color: pendingApps > 0 ? c.accent : c.ink,
            isAlert: pendingApps > 0,
            onTap: () => Navigator.pushNamed(context, '/basvurular'),
          ),
        ),
        const SizedBox(width: SwanSpace.sm),
        Expanded(
          child: _kpiCard(
            c,
            title: 'Aktif Sporcu',
            value: '$activeAthletes',
            color: c.ink,
            onTap: () => Navigator.pushNamed(context, '/athletes'),
          ),
        ),
        const SizedBox(width: SwanSpace.sm),
        Expanded(
          child: _kpiCard(
            c,
            title: 'Günün Yoklaması',
            value: 'Başlat',
            color: c.accent,
            isText: true,
            onTap: () => Navigator.pushNamed(context, '/attendance'),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(
    SwanPalette c, {
    required String title,
    required String value,
    required Color color,
    bool isAlert = false,
    bool isText = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: SwanSpace.md,
          horizontal: SwanSpace.sm,
        ),
        decoration: BoxDecoration(
          color: isAlert ? c.accent.withValues(alpha: 0.12) : c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: isAlert ? c.accent : c.line),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: isText
                  ? SwanType.bodySm(color, w: FontWeight.w700)
                  : SwanType.h2(color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: SwanType.caption(c.inkMuted),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 4. GRUP KARTI & LİSTE ÖĞELERİ
  // -------------------------------------------------------------
  Widget _buildSectionHeader(String title, SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.only(left: SwanSpace.xs),
      child: Text(
        title,
        style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
      ),
    );
  }

  Widget _buildGroupCard(SwanPalette c, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTile(
    SwanPalette c, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SwanSpace.md,
          vertical: SwanSpace.md,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Icon(icon, color: c.accent, size: 20),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor ?? c.accent,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Text(
                  badge,
                  style: SwanType.caption(Colors.white, w: FontWeight.w700),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
            ],
            Icon(Icons.chevron_right_rounded, color: c.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(SwanPalette c) =>
      Divider(height: 1, indent: 56, color: c.line);

  // -------------------------------------------------------------
  // HİBRİT SPORCU EKLEME MODALI (QR/WhatsApp + Elle Kayıt)
  // -------------------------------------------------------------
  void _showAddAthleteHybridSheet(BuildContext context, ClubRef club) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAthleteHybridSheet(club: club),
    );
  }

  // -------------------------------------------------------------
  // TEK TIKLA AİDAT HATIRLATMA MODALI
  // -------------------------------------------------------------
  void _showFeeReminderSheet(
    BuildContext context,
    ClubRef club,
    List<PendingPayment> pendingPayments,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeeReminderSheet(
        club: club,
        pendingPayments: pendingPayments,
      ),
    );
  }
}

class _AddAthleteHybridSheet extends ConsumerStatefulWidget {
  const _AddAthleteHybridSheet({required this.club});
  final ClubRef club;

  @override
  ConsumerState<_AddAthleteHybridSheet> createState() =>
      _AddAthleteHybridSheetState();
}

class _AddAthleteHybridSheetState
    extends ConsumerState<_AddAthleteHybridSheet> {
  int _tab = 0; // 0: WhatsApp/QR Davet, 1: Sahada Elle Kayıt
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  String get _inviteUrl =>
      'https://swanspor.com/kulup/${widget.club.id}/basvuru';

  String get _whatsappText =>
      'Merhaba! ${widget.club.name} sporcu kadrosuna katılmak için aşağıdaki resmi bağlantıdan başvurunuzu oluşturabilirsiniz:\n$_inviteUrl';

  Future<void> _shareViaWhatsApp(String text) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Davet mesajı panoya kopyalandı!')),
        );
      }
    }
  }

  Future<void> _saveManualAthlete() async {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    if (first.isEmpty || last.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen sporcunun ad ve soyadını girin.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(athleteServiceProvider).addAthlete(
            clubId: widget.club.id,
            firstName: first,
            lastName: last,
            position: _groupCtrl.text.trim().isEmpty
                ? null
                : _groupCtrl.text.trim(),
          );
      ref.invalidate(clubAthletesProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$first $last kulüp kadrosuna eklendi!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt yapılamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SwanRadius.lg),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg,
          SwanSpace.md,
          SwanSpace.lg,
          SwanSpace.xl,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: SwanSpace.md),
              Text('Yeni Sporcu / Öğrenci Ekle', style: SwanType.h3(c.ink)),
              const SizedBox(height: 2),
              Text(
                widget.club.name,
                style: SwanType.caption(c.inkMuted),
              ),
              const SizedBox(height: SwanSpace.md),
              SwanSegmentedTabs(
                labels: const ['1. Davet Linki / QR', '2. Sahada Elle Ekle'],
                selected: _tab,
                onSelect: (int i) => setState(() => _tab = i),
              ),
              const SizedBox(height: SwanSpace.lg),
              if (_tab == 0) ...[
                Container(
                  padding: const EdgeInsets.all(SwanSpace.lg),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(SwanRadius.lg),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 88, color: c.ink),
                      const SizedBox(height: SwanSpace.sm),
                      Text(
                        'Veli veya Sporcu Davet Bağlantısı',
                        style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bu bağlantıyı WhatsApp grubunuza veya veliye gönderin. Veli formu doldurduğunda "Gelen Başvurular" ekranınıza düşer ve tek tıkla kadroya onaylarsınız.',
                        style: SwanType.caption(c.inkMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: SwanSpace.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SwanSpace.md,
                          vertical: SwanSpace.sm,
                        ),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                          border: Border.all(color: c.line),
                        ),
                        child: SelectableText(
                          _inviteUrl,
                          style: SwanType.caption(c.accent, w: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SwanSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _inviteUrl),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Davet linki kopyalandı!'),
                            ),
                          );
                        },
                        icon: Icon(Icons.copy_rounded, size: 18, color: c.ink),
                        label: Text('Kopyala', style: SwanType.bodySm(c.ink)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.line),
                          padding: const EdgeInsets.symmetric(
                            vertical: SwanSpace.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SwanSpace.sm),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _shareViaWhatsApp(_whatsappText),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'WhatsApp ile Gönder',
                          style: SwanType.bodySm(
                            Colors.white,
                            w: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: SwanSpace.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _firstNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Sporcu Adı',
                    hintText: 'Örn: Kerem',
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: SwanSpace.sm),
                TextField(
                  controller: _lastNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Sporcu Soyadı',
                    hintText: 'Örn: Yılmaz',
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: SwanSpace.sm),
                TextField(
                  controller: _groupCtrl,
                  decoration: InputDecoration(
                    labelText: 'Yaş Grubu / Mevki (İsteğe bağlı)',
                    hintText: 'Örn: U14 Takımı veya Oyun Kurucu',
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: SwanSpace.lg),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _saveManualAthlete,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    _saving ? 'Kaydediliyor...' : 'Sporcuyu Kadroya Kaydet',
                    style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeeReminderSheet extends StatelessWidget {
  const _FeeReminderSheet({
    required this.club,
    required this.pendingPayments,
  });

  final ClubRef club;
  final List<PendingPayment> pendingPayments;

  String _buildReminderText() {
    return 'Sayın Velimiz / Sporcumuz,\n\n'
        '${club.name} bünyesindeki aylık kulüp aidat ödemenizi hatırlatmak isteriz. '
        'Ödeme detaylarınızı SwanSport uygulaması > Aidatlarım ekranından görüntüleyebilirsiniz.\n\n'
        'Teşekkür eder, iyi antrenmanlar dileriz.';
  }

  Future<void> _sendWhatsAppReminder(BuildContext context, String text) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hatırlatma mesajı panoya kopyalandı!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    final template = _buildReminderText();

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SwanRadius.lg),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        SwanSpace.lg,
        SwanSpace.md,
        SwanSpace.lg,
        SwanSpace.xl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: SwanSpace.md),
            Text('Tek Tıkla Aidat Hatırlatma', style: SwanType.h3(c.ink)),
            const SizedBox(height: 2),
            Text(
              pendingPayments.isNotEmpty
                  ? '${pendingPayments.length} bekleyen ödeme kaydı mevcut'
                  : 'Standart kulüp aidat hatırlatma şablonu',
              style: SwanType.caption(c.inkMuted),
            ),
            const SizedBox(height: SwanSpace.md),
            Container(
              padding: const EdgeInsets.all(SwanSpace.md),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(SwanRadius.md),
                border: Border.all(color: c.line),
              ),
              child: Text(template, style: SwanType.bodySm(c.ink)),
            ),
            const SizedBox(height: SwanSpace.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: template));
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mesaj panoya kopyalandı!'),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy_rounded, size: 18, color: c.ink),
                    label: Text('Metni Kopyala', style: SwanType.bodySm(c.ink)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.line),
                      padding: const EdgeInsets.symmetric(
                        vertical: SwanSpace.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SwanSpace.sm),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _sendWhatsAppReminder(context, template),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      'WhatsApp ile Hatırlat',
                      style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: SwanSpace.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
