import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/navigation/app_routes.dart';
import '../../../../app/navigation/swan_navigation.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_scaffold.dart';
import '../../../../app/widgets/swan_tabs.dart';
import '../../settings/presentation/screens/club_training_sports_sheet.dart';
import 'club_edit_sheet.dart';

/// Mobil Kulüp Yönetim Kokpiti (Club Cockpit)
///
/// Antrenör ve kulüp yöneticilerinin tüm operasyonları tek çatı altında
/// yönetebildiği modern, estetik ve sadeleştirilmiş kontrol merkezi.
class ClubCockpitScreen extends ConsumerWidget {
  const ClubCockpitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    final clubAsync = ref.watch(activeClubProvider);
    final access = ref.watch(swanAccessProvider);
    final trainingEnabled =
        ref.watch(featureEnabledProvider(FeatureFlags.sportTrainingSessions));
    final staffOperationsEnabled =
        ref.watch(featureEnabledProvider(FeatureFlags.clubStaffOperations));
    final seasonEnabled =
        ref.watch(featureEnabledProvider(FeatureFlags.seasonSetup));
    final pendingApps = access.isClubStaff
        ? ref.watch(clubPendingApplicationsProvider).valueOrNull?.length ?? 0
        : 0;
    final athletes = access.isClubStaff
        ? ref.watch(clubAthletesProvider).valueOrNull ?? const <AthleteRow>[]
        : const <AthleteRow>[];
    final activeAthletesCount = athletes.where((a) => a.isActive).length;
    final pendingPayments = access.isClubStaff
        ? ref.watch(pendingPaymentsProvider).valueOrNull ??
            const <PendingPayment>[]
        : const <PendingPayment>[];

    return SwanScaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Geri dön',
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: SwanSpace.lg,
                  color: c.ink,
                ),
                onPressed: () => context.swanPop(),
              )
            : null,
        title: Text(
          'Kulübüm',
          style: SwanType.h3(c.ink),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Kulüp Ayarları',
            icon: Icon(Icons.settings_outlined, color: c.inkMuted, size: 22),
            onPressed: () => context.swanPush(AppRoutes.clubSettings),
          ),
        ],
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
          if (!access.isClubStaff) {
            return Center(
                child: Text('Yetkin yok', style: SwanType.body(c.ink)),);
          }

          // Real data counts from providers (NO fake/dummy sample values!)
          final sportsBranches =
              ref.watch(clubTrainingSportsProvider(club.id)).valueOrNull ??
                  const <String>[];
          final teamsList =
              ref.watch(teamsProvider).valueOrNull ?? const <TeamRow>[];
          final teamsCount = teamsList.isNotEmpty
              ? teamsList.length
              : sportsBranches.length;
          final clubMembers =
              ref.watch(clubMembersProvider(club.id)).valueOrNull ?? const [];
          final coachesCount = clubMembers.isNotEmpty
              ? clubMembers.where((m) => m.role == 'coach').length
              : (access.coachLevel > 0 || access.clubRole == 'coach' ? 1 : 0);
          final recentEvents =
              ref.watch(eventsProvider).valueOrNull ?? const <EventRow>[];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeClubProvider);
              ref.invalidate(clubPendingApplicationsProvider);
              ref.invalidate(clubAthletesProvider);
              ref.invalidate(pendingPaymentsProvider);
              ref.invalidate(eventsProvider);
              ref.invalidate(teamsProvider);
              ref.invalidate(clubTrainingSportsProvider(club.id));
              ref.invalidate(clubMembersProvider(club.id));
              await ref.read(activeClubProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SwanSpace.md,
                SwanSpace.sm,
                SwanSpace.md,
                SwanSpace.xl * 4,
              ),
              children: [
                // 1. KULÜP HERO KARTI (Parlayan Rozet, Kulüp Bilgisi & Hızlı Ekleme)
                _buildClubHeroCard(context, ref, club, c, access),
                const SizedBox(height: SwanSpace.md),

                // 2. GÜNÜN ACİL İŞLERİ (Hemen erişilebilir konumda)
                _buildUrgentActionsSection(
                  context,
                  ref,
                  c,
                  club: club,
                  access: access,
                  trainingEnabled: trainingEnabled,
                  pendingApps: pendingApps,
                  pendingPaymentsCount: pendingPayments.length,
                ),
                const SizedBox(height: SwanSpace.md),

                // 3. 4'LÜ KPI SAYAÇLARI (Takım, Sporcu, Antrenör, Veli)
                _buildModernKpiStrip(
                  context,
                  c,
                  teamsCount: teamsCount,
                  athletesCount: activeAthletesCount,
                  coachesCount: coachesCount,
                  guardiansCount: pendingApps,
                ),
                const SizedBox(height: SwanSpace.md),

                // 4. KULÜP PROFİLİ KARTI (Bilgilerini görüntüle ve düzenle)
                _buildClubProfileCard(context, club, c),
                const SizedBox(height: SwanSpace.md),

                // 5. 2x3 MODERN AKSİYON IZGARASI (Referans Tasarıma Birebir)
                _buildActionGrid(context, club, c),
                const SizedBox(height: SwanSpace.md),

                // 6. SON ETKİNLİKLER (Gerçek takvim verisiyle)
                _buildRecentEventsSection(context, c, recentEvents),
                const SizedBox(height: SwanSpace.xl),

                // 7. ROL ÖNCELİKLİ DETAYLI YÖNETİM BLOKLARI
                if (access.isClubAdmin) ...[
                  // YÖNETİCİ ÖNCELİK SIRASI: Mali İşler -> Kadro & Sporcular -> Antrenman & Takvim -> Tesis & Operasyon -> Analiz & Ayarlar
                  _buildFinanceSection(
                      context, c, club, pendingPayments, access,),
                  const SizedBox(height: SwanSpace.xl),
                  _buildRosterSection(context, c,
                      club: club,
                      pendingApps: pendingApps,
                      activeAthletesCount: activeAthletesCount,),
                  const SizedBox(height: SwanSpace.xl),
                  _buildTrainingSection(context, c,
                      trainingEnabled: trainingEnabled,),
                  const SizedBox(height: SwanSpace.xl),
                  _buildOperationsSection(context, c,
                      club: club,
                      access: access,
                      staffOperationsEnabled: staffOperationsEnabled,
                      seasonEnabled: seasonEnabled,),
                  const SizedBox(height: SwanSpace.xl),
                  _buildAnalyticsSection(context, c, access: access),
                ] else ...[
                  // ANTRENÖR ÖNCELİK SIRASI: Antrenman & Takvim -> Kadro & Sporcular -> Tesis & Operasyon -> Mali İşler -> Analiz
                  _buildTrainingSection(context, c,
                      trainingEnabled: trainingEnabled,),
                  const SizedBox(height: SwanSpace.xl),
                  _buildRosterSection(context, c,
                      club: club,
                      pendingApps: pendingApps,
                      activeAthletesCount: activeAthletesCount,),
                  const SizedBox(height: SwanSpace.xl),
                  _buildOperationsSection(context, c,
                      club: club,
                      access: access,
                      staffOperationsEnabled: staffOperationsEnabled,
                      seasonEnabled: seasonEnabled,),
                  const SizedBox(height: SwanSpace.xl),
                  _buildFinanceSection(
                      context, c, club, pendingPayments, access,),
                  const SizedBox(height: SwanSpace.xl),
                  _buildAnalyticsSection(context, c, access: access),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. HERO KARTI (Stadyum Işıltısı + Parlayan Rozet + Hızlı Aksiyonlar)
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.accent.withValues(alpha: 0.15),
            c.surface,
          ],
        ),
      ),
      padding: const EdgeInsets.all(SwanSpace.md),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Parlayan halka ve kuğu amblemi
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface,
                  border: Border.all(color: c.accent, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: ClipOval(
                    child: Image.asset(
                      'assets/branding/official_swan_logo.jpg',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.shield_rounded,
                        color: c.accent,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
              if (access.isClubAdmin)
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon:
                        Icon(Icons.edit_outlined, color: c.inkMuted, size: 22),
                    tooltip: 'Kulüp Bilgilerini Düzenle',
                    onPressed: () => showClubEditSheet(context, club.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Text(
            club.name,
            style: SwanType.h2(c.ink),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            club.city != null ? '${club.city} • Spor Kulübü' : 'Spor Kulübü',
            style: SwanType.caption(c.accent, w: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SwanSpace.md),
          const Divider(height: 1),
          const SizedBox(height: SwanSpace.sm),
          // Hızlı Aksiyon Butonları (Ekleme & Çıkartma operasyonları)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
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
              const SizedBox(height: SwanSpace.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.swanPush(
                    AppRoutes.clubProfile,
                    extra: club.id,
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
              const SizedBox(height: SwanSpace.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddAthleteHybridSheet(context, club),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(
                    'Yeni Sporcu / Öğrenci Ekle',
                    style: SwanType.bodySm(c.onAccent, w: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accentFill,
                    foregroundColor: c.onAccent,
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
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. GÜNÜN ACİL İŞLERİ (Aksiyon Odaklı Kartlar)
  // -------------------------------------------------------------
  Widget _buildUrgentActionsSection(
    BuildContext context,
    WidgetRef ref,
    SwanPalette c, {
    required ClubRef club,
    required SwanAccess access,
    required bool trainingEnabled,
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
              Expanded(
                child: Text(
                  'GÜNÜN ACİL İŞLERİ',
                  style: SwanType.caption(c.accent, w: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          if (access.isClubAdmin) ...[
            if (pendingApps > 0) ...[
              _urgentRow(
                c,
                icon: Icons.how_to_reg_rounded,
                color: c.warning,
                text: '$pendingApps yeni sporcu başvurusu onayınızı bekliyor',
                buttonLabel: 'Onayla',
                onTap: () => context.swanPush(AppRoutes.applications),
              ),
              const SizedBox(height: SwanSpace.xs),
            ],
            _urgentRow(
              c,
              icon: Icons.checklist_rounded,
              color: c.accent,
              text: 'Günün antrenman yoklamasını başlatın',
              buttonLabel: 'Yoklama Al',
              onTap: () => context.swanPush(AppRoutes.attendance),
            ),
            const SizedBox(height: SwanSpace.xs),
            _urgentRow(
              c,
              icon: Icons.notifications_active_rounded,
              color: pendingPaymentsCount > 0 ? c.warning : c.inkMuted,
              text: pendingPaymentsCount > 0
                  ? '$pendingPaymentsCount ödeme bildirimi onay bekliyor'
                  : 'Genel aidat hatırlatma metnini paylaşın',
              buttonLabel: 'Hatırlat',
              onTap: () => _showFeeReminderSheet(
                context,
                club,
                ref.read(pendingPaymentsProvider).valueOrNull ?? const [],
              ),
            ),
          ] else ...[
            _urgentRow(
              c,
              icon: Icons.checklist_rounded,
              color: c.accent,
              text: 'Günün antrenman yoklamasını başlatın',
              buttonLabel: 'Yoklama Al',
              onTap: () => context.swanPush(AppRoutes.attendance),
            ),
            if (trainingEnabled) ...[
              const SizedBox(height: SwanSpace.xs),
              _urgentRow(
                c,
                icon: Icons.sports_rounded,
                color: c.accent,
                text: 'Günün antrenman oturumunu başlatın ve yönetin',
                buttonLabel: 'Oturum Aç',
                onTap: () =>
                    context.swanPush(AppRoutes.trainingSession),
              ),
            ],
            if (pendingApps > 0) ...[
              const SizedBox(height: SwanSpace.xs),
              _urgentRow(
                c,
                icon: Icons.how_to_reg_rounded,
                color: c.warning,
                text: '$pendingApps yeni sporcu başvurusu inceleme bekliyor',
                buttonLabel: 'Başvurular',
                onTap: () => context.swanPush(AppRoutes.applications),
              ),
            ],
          ],
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
          const SizedBox(width: SwanSpace.xs),
          Expanded(
            child: Text(
              text,
              style: SwanType.caption(c.ink, w: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: SwanSpace.xs),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
  // 3. MODERN 4'LÜ KPI SAYAÇLARI (Takım, Sporcu, Antrenör, Veli)
  // -------------------------------------------------------------
  Widget _buildModernKpiStrip(
    BuildContext context,
    SwanPalette c, {
    required int teamsCount,
    required int athletesCount,
    required int coachesCount,
    required int guardiansCount,
  }) {
    final isCompact = MediaQuery.sizeOf(context).width < 340 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;

    final items = [
      _kpiItem(
        c,
        title: 'Takım',
        value: '$teamsCount',
        onTap: () => context.swanPush(AppRoutes.teams),
      ),
      _kpiItem(
        c,
        title: 'Sporcu',
        value: '$athletesCount',
        onTap: () => context.swanPush(AppRoutes.athletes),
      ),
      _kpiItem(
        c,
        title: 'Antrenör',
        value: '$coachesCount',
        onTap: () => context.swanPush(AppRoutes.athletes),
      ),
      _kpiItem(
        c,
        title: 'Veli',
        value: '$guardiansCount',
        onTap: () => context.swanPush(AppRoutes.applications),
      ),
    ];

    if (isCompact) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: items[0]),
              const SizedBox(width: SwanSpace.xs),
              Expanded(child: items[1]),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Row(
            children: [
              Expanded(child: items[2]),
              const SizedBox(width: SwanSpace.xs),
              Expanded(child: items[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: items[0]),
        const SizedBox(width: SwanSpace.xs),
        Expanded(child: items[1]),
        const SizedBox(width: SwanSpace.xs),
        Expanded(child: items[2]),
        const SizedBox(width: SwanSpace.xs),
        Expanded(child: items[3]),
      ],
    );
  }

  Widget _kpiItem(
    SwanPalette c, {
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: SwanSpace.sm,
          horizontal: SwanSpace.xs,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: SwanType.h2(c.ink),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: SwanType.caption(c.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 4. KULÜP PROFİLİ KARTI
  // -------------------------------------------------------------
  Widget _buildClubProfileCard(
    BuildContext context,
    ClubRef club,
    SwanPalette c,
  ) {
    return InkWell(
      onTap: () => context.swanPush(
        AppRoutes.clubProfile,
        extra: club.id,
      ),
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: Container(
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Icon(Icons.storefront_outlined, color: c.accent, size: 24),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kulüp Profili',
                    style: SwanType.body(c.ink, w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bilgilerini görüntüle ve düzenle',
                    style: SwanType.caption(c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.inkMuted, size: 22),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 5. 2x3 MODERN AKSİYON IZGARASI (Referans Tasarıma Birebir Uyum)
  // -------------------------------------------------------------
  Widget _buildActionGrid(
    BuildContext context,
    ClubRef club,
    SwanPalette c,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _gridCard(
                c,
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF00C9B7),
                title: 'Takımlarım',
                subtitle: 'Tüm takımları yönet',
                onTap: () => context.swanPush(AppRoutes.teams),
              ),
            ),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: _gridCard(
                c,
                icon: Icons.person_pin_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Antrenörler',
                subtitle: 'Antrenör kadronu yönet',
                onTap: () => context.swanPush(AppRoutes.athletes),
              ),
            ),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),
        Row(
          children: [
            Expanded(
              child: _gridCard(
                c,
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Antrenman Programı',
                subtitle: 'Antrenmanları planla',
                onTap: () => context.swanPush(AppRoutes.calendar),
              ),
            ),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: _gridCard(
                c,
                icon: Icons.fact_check_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Yoklama',
                subtitle: 'Yoklamaları takip et',
                onTap: () => context.swanPush(AppRoutes.attendance),
              ),
            ),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),
        Row(
          children: [
            Expanded(
              child: _gridCard(
                c,
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Aidat Takibi',
                subtitle: 'Ödemeleri görüntüle',
                onTap: () => context.swanPush(AppRoutes.finance),
              ),
            ),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: _gridCard(
                c,
                icon: Icons.campaign_rounded,
                iconColor: const Color(0xFFEC4899),
                title: 'Duyurular',
                subtitle: 'Kulüp duyurularını paylaş',
                onTap: () => context.swanPush(AppRoutes.announcements),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gridCard(
    SwanPalette c, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(SwanRadius.sm),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(height: SwanSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: SwanType.caption(c.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 6. SON ETKİNLİKLER (Gerçek Takvim Verisiyle, Asla Örnek/Fake Yok)
  // -------------------------------------------------------------
  Widget _buildRecentEventsSection(
    BuildContext context,
    SwanPalette c,
    List<EventRow> events,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildSectionHeader('SON ETKİNLİKLER', c)),
            InkWell(
              onTap: () => context.swanPush(AppRoutes.calendar),
              borderRadius: BorderRadius.circular(SwanRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: SwanSpace.xs, vertical: 2,),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tümünü Gör',
                        style: SwanType.caption(c.accent, w: FontWeight.w600),),
                    Icon(Icons.chevron_right_rounded,
                        color: c.accent, size: 16,),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.all(SwanSpace.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.line),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded,
                      color: c.inkMuted, size: 36,),
                  const SizedBox(height: SwanSpace.xs),
                  Text(
                    'Henüz planlanmış bir etkinlik bulunmuyor',
                    style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Yeni antrenman veya maç programı oluşturmak için takvimi açabilirsiniz.',
                    style: SwanType.caption(c.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                for (int i = 0; i < events.take(3).length; i++) ...[
                  if (i > 0) _buildDivider(c),
                  _buildEventTile(context, c, events[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEventTile(BuildContext context, SwanPalette c, EventRow event) {
    final dayStr =
        '${event.startsAt.day} ${_monthName(event.startsAt.month)}';
    final timeStr =
        '${event.startsAt.hour.toString().padLeft(2, '0')}:${event.startsAt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => context.swanPush(AppRoutes.calendar),
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SwanSpace.md,
          vertical: SwanSpace.sm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(SwanRadius.sm),
              ),
              child: Column(
                children: [
                  Text(
                    dayStr,
                    style: SwanType.caption(c.accent, w: FontWeight.w700),
                  ),
                  Text(
                    timeStr,
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.place ?? 'Kulüp Tesisi',
                    style: SwanType.caption(c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

  // -------------------------------------------------------------
  // KADRO & SPORCULAR BÖLÜMÜ
  // -------------------------------------------------------------
  Widget _buildRosterSection(
    BuildContext context,
    SwanPalette c, {
    required ClubRef club,
    required int pendingApps,
    required int activeAthletesCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onTap: () => context.swanPush(AppRoutes.applications),
            ),
            _buildDivider(c),
            _buildTile(
              c,
              icon: Icons.groups_rounded,
              title: 'Sporcu Kadrosu',
              subtitle: '$activeAthletesCount aktif sporcu kaydı',
              onTap: () => context.swanPush(AppRoutes.athletes),
            ),
            _buildDivider(c),
            _buildTile(
              c,
              icon: Icons.shield_rounded,
              title: 'Takımlar ve Yaş Grupları',
              subtitle: 'Branş takımları, yaş kategorileri ve listeler',
              onTap: () => context.swanPush(AppRoutes.teams),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // ANTRENMAN & TAKVİM BÖLÜMÜ
  // -------------------------------------------------------------
  Widget _buildTrainingSection(
    BuildContext context,
    SwanPalette c, {
    required bool trainingEnabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onTap: () => context.swanPush(AppRoutes.attendance),
            ),
            _buildDivider(c),
            _buildTile(
              c,
              icon: Icons.fact_check_rounded,
              title: 'Devam Durumu & Geçmiş',
              subtitle: 'Tüm sporcuların devam ve yoklama raporları',
              onTap: () => context.swanPush(AppRoutes.attendanceHistory),
            ),
            _buildDivider(c),
            if (trainingEnabled) ...[
              _buildTile(
                c,
                icon: Icons.tune_rounded,
                title: 'Antrenman Şablonları & Oturumlar',
                subtitle:
                    'Branşa özel egzersiz planları ve drill havuzu',
                onTap: () => context.swanPush(
                  AppRoutes.trainingProtocols,
                ),
              ),
              _buildDivider(c),
              _buildTile(
                c,
                icon: Icons.sports_rounded,
                title: 'Antrenman Oturumu',
                subtitle: 'Aktif antrenman oturumunu başlat ve yönet',
                onTap: () => context.swanPush(
                  AppRoutes.trainingSession,
                ),
              ),
              _buildDivider(c),
            ],
            _buildTile(
              c,
              icon: Icons.calendar_month_rounded,
              title: 'Kulüp Takvimi',
              subtitle: 'Maçlar, antrenmanlar ve etkinlik programı',
              onTap: () => context.swanPush(AppRoutes.calendar),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // MALİ İŞLER & KASA BÖLÜMÜ
  // -------------------------------------------------------------
  Widget _buildFinanceSection(
    BuildContext context,
    SwanPalette c,
    ClubRef club,
    List<PendingPayment> pendingPayments,
    SwanAccess access,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  'Ödeme bildirimlerini incele veya genel mesajı paylaş',
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
              onTap: () => context.swanPush(AppRoutes.finance),
            ),
            if (access.isClubAdmin) ...[
              _buildDivider(c),
              _buildTile(
                c,
                icon: Icons.receipt_long_rounded,
                title: 'Kulüp Gideri Ekle',
                subtitle: 'Tesis, malzeme ve operasyon harcaması kaydet',
                onTap: () => context.swanPush(AppRoutes.quickExpense),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TESİS & OPERASYON BÖLÜMÜ
  // -------------------------------------------------------------
  Widget _buildOperationsSection(
    BuildContext context,
    SwanPalette c, {
    required ClubRef club,
    required SwanAccess access,
    required bool staffOperationsEnabled,
    required bool seasonEnabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('TESİS & OPERASYON', c),
        const SizedBox(height: SwanSpace.sm),
        _buildGroupCard(
          c,
          children: [
            if (staffOperationsEnabled &&
                access.canManageClubInventory(club.id)) ...[
              _buildTile(
                c,
                icon: Icons.inventory_2_outlined,
                title: 'Malzeme & Zimmet Takibi',
                subtitle:
                    'Kulüp envanteri ve sporculara teslim edilenler',
                onTap: () => context.swanPush(
                  AppRoutes.clubInventory,
                ),
              ),
              _buildDivider(c),
            ],
            _buildTile(
              c,
              icon: Icons.stadium_rounded,
              title: 'Tesisler ve Sahalar',
              subtitle: 'Kort ve saha tahsisleri, kullanım saatleri',
              onTap: () => context.swanPush(AppRoutes.facilities),
            ),
            _buildDivider(c),
            if (staffOperationsEnabled &&
                access.canReadClubHealth(club.id)) ...[
              _buildTile(
                c,
                icon: Icons.health_and_safety_outlined,
                title: 'Sağlık & İdari Dinlendirme',
                subtitle: 'Sakatlık kayıtları ve dinlendirme kararları',
                onTap: () => context.swanPush(
                  AppRoutes.clubHealth,
                ),
              ),
              _buildDivider(c),
            ],
            if (staffOperationsEnabled &&
                access.canReadClubPlanning(club.id)) ...[
              _buildTile(
                c,
                icon: Icons.groups_outlined,
                title: 'Sportif Kadro Planlama',
                subtitle: 'Sezon kadrosunu ve görevleri planla',
                onTap: () =>
                    context.swanPush(AppRoutes.clubSquadPlanning),
              ),
              _buildDivider(c),
            ],
            if (access.isClubAdmin && seasonEnabled) ...[
              _buildTile(
                c,
                icon: Icons.event_available_rounded,
                title: 'Sezon Açılışı',
                subtitle: 'Yeni sezonun kulüp hazırlıklarını yönet',
                onTap: () =>
                    context.swanPush(AppRoutes.seasonSetup),
              ),
              _buildDivider(c),
            ],
            _buildTile(
              c,
              icon: Icons.campaign_rounded,
              title: 'Kulüp Duyurusu Paylaş',
              subtitle: 'Tüm sporcu ve velilere anlık duyuru gönder',
              onTap: () => context.swanPush(AppRoutes.announcements),
            ),
            _buildDivider(c),
            _buildTile(
              c,
              icon: Icons.medical_services_rounded,
              title: 'Medikal Merkez',
              subtitle: 'Sağlık muayeneleri, tetkikler ve sağlık raporları',
              onTap: () => context.swanPush(AppRoutes.medicalCenter),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // ANALİZ & KULÜP AYARLARI BÖLÜMÜ
  // -------------------------------------------------------------
  Widget _buildAnalyticsSection(
    BuildContext context,
    SwanPalette c, {
    required SwanAccess access,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ANALİZ & KULÜP AYARLARI', c),
        const SizedBox(height: SwanSpace.sm),
        _buildGroupCard(
          c,
          children: [
            _buildTile(
              c,
              icon: Icons.bar_chart_rounded,
              title: 'Performans & Analitik',
              subtitle: 'Takım ve sporcu gelişim istatistikleri',
              onTap: () => context.swanPush(
                AppRoutes.performanceAnalytics,
              ),
            ),
            _buildDivider(c),
            _buildTile(
              c,
              icon: Icons.dashboard_rounded,
              title: 'Komuta Merkezi',
              subtitle: 'Kulüp operasyonel genel bakış',
              onTap: () => context.swanPush(
                AppRoutes.homeCommand,
              ),
            ),
            if (access.isClubAdmin) ...[
              _buildDivider(c),
              _buildTile(
                c,
                icon: Icons.settings_suggest_rounded,
                title: 'Kulüp Ayarları',
                subtitle: 'Kulüp tercihleri, profil ve üyelik ayarları',
                onTap: () => context.swanPush(
                  AppRoutes.clubSettings,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // GRUP KARTI & LİSTE ÖĞELERİ
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
                  Text(title,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w600),),
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
                  style: SwanType.caption(c.onAccent, w: FontWeight.w700),
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
  int _tab = 0; // 0: kulüp profili daveti, 1: hesapsız sporcu kaydı
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
      'https://swansport.pages.dev/#/kulup-profil?id=${Uri.encodeComponent(widget.club.id)}';

  String get _whatsappText =>
      'Merhaba! ${widget.club.name} kulüp profiline girip Başvur düğmesinden sporcu başvurusu yapabilirsiniz:\n$_inviteUrl';

  Future<void> _shareViaWhatsApp(String text) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Tarayıcı açmayı engellerse mesaj yine kopyalanabilir.
    }
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Paylaşma başarısız; metni elle kopyalayın.'),),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet mesajı panoya kopyalandı!')),
      );
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
            position:
                _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim(),
          );
      ref.invalidate(clubAthletesProvider);
      ref.invalidate(unlinkedAthletesProvider(widget.club.id));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content:
            Text('$first $last kadroya eklendi; henüz bir hesaba bağlı değil.'),
      ),);
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
          child: SingleChildScrollView(
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
                labels: const ['Davet Linki', 'Hesapsız Ekle'],
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
                      Icon(Icons.link_rounded, size: 88, color: c.ink),
                      const SizedBox(height: SwanSpace.sm),
                      Text(
                        'Veli veya Sporcu Davet Bağlantısı',
                        style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bu bağlantı kulüp profilini açar. Sporcu veya veli buradaki Başvur düğmesiyle başvuru yapabilir; başvuru Gelen Başvurular ekranınıza düşer.',
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
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: _inviteUrl),
                            );
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Kopyalama başarısız; bağlantıyı seçip kopyalayın.',),
                              ),);
                            }
                            return;
                          }
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
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'WhatsApp ile Gönder',
                            style: SwanType.bodySm(
                              c.onAccent,
                              w: FontWeight.w700,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.accentFill,
                          foregroundColor: c.onAccent,
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
                Text(
                    'Bu kayıt yalnızca hesabı olmayan sporcular içindir. Kulübe zaten üye olan sporcuyu Sporcu Kadrosu ekranından hesabına bağlayın.',
                    style: SwanType.caption(c.inkMuted),),
                TextButton(
                  onPressed: () {
                    context.swanPop();
                    context.swanPush(AppRoutes.athletes);
                  },
                  child: const Text('Mevcut üyeyi kadroya bağla'),
                ),
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
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    _saving ? 'Kaydediliyor...' : 'Sporcuyu Kadroya Kaydet',
                    style: SwanType.bodySm(c.onAccent, w: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accentFill,
                    foregroundColor: c.onAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
              ],
            ],
          ),),
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
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Tarayıcı açmayı engellerse metni panoya al.
    }
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Paylaşma başarısız; metni elle kopyalayın.'),),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hatırlatma mesajı panoya kopyalandı!')),
      );
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
        child: SingleChildScrollView(
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
                  ? '${pendingPayments.length} ödeme bildirimi onay bekliyor'
                  : 'Genel kulüp aidat hatırlatma şablonu',
              style: SwanType.caption(c.inkMuted),
            ),
            if (pendingPayments.isNotEmpty) ...[
              const SizedBox(height: SwanSpace.xs),
              Text(
                'Bu sporcular ödeme bildirmiştir; aşağıdaki genel mesajı göndermeden önce alıcıyı kontrol edin.',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
            const SizedBox(height: SwanSpace.md),
            if (pendingPayments.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pendingPayments.length,
                  itemBuilder: (context, index) {
                    final payment = pendingPayments[index];
                    final name = payment.athleteName ??
                        payment.declaredName ??
                        'Sporcu belirtilmedi';
                    return Text(
                        '$name • ${payment.label} • ${payment.amount} ₺',
                        style: SwanType.caption(c.ink),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,);
                  },
                ),
              ),
              const SizedBox(height: SwanSpace.md),
            ],
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
                      try {
                        await Clipboard.setData(ClipboardData(text: template));
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Kopyalama başarısız'),),
                          );
                        }
                        return;
                      }
                      if (!context.mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Mesaj panoya kopyalandı!'),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy_rounded, size: 18, color: c.ink),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Metni Kopyala',
                          style: SwanType.bodySm(c.ink),),
                    ),
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
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'WhatsApp ile Hatırlat',
                        style: SwanType.bodySm(c.onAccent, w: FontWeight.w700),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accentFill,
                      foregroundColor: c.onAccent,
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
        ),),
      ),
    );
  }
}
