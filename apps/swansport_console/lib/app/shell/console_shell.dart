import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../modules/console_module.dart';
import '../modules/module_registry.dart';
import '../theme/console_theme.dart';
import 'too_narrow_notice.dart';

/// Kenar çubuğunun daraltılmış olup olmadığı. Oturum boyunca hatırlanır.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Konsolun kalıcı çerçevesi: solda modül listesi, üstte bağlam, ortada içerik.
///
/// Mobil uygulamanın alt navigasyonunun tersi bir yerleşim. Sebep: masaüstünde
/// dikey alan kıymetli değil, yatay alan bol; modül listesini sürekli görünür
/// tutmak tıklama sayısını düşürüyor.
class ConsoleShell extends ConsumerWidget {
  const ConsoleShell({required this.child, required this.route, super.key});

  final Widget child;
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < ConsoleDensity.minSupportedWidth) {
      return const TooNarrowNotice();
    }

    // Dar ekranda kenar çubuğu kendiliğinden daralır; kullanıcının açık
    // bırakma tercihi yalnızca yer varken geçerli.
    final collapsed = ref.watch(sidebarCollapsedProvider) ||
        width < ConsoleDensity.autoCollapseWidth;
    final access = ref.watch(consoleAccessProvider);
    final t = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(collapsed: collapsed, access: access, current: route),
          VerticalDivider(width: 1, color: t.colorScheme.outline),
          Expanded(
            child: Column(
              children: [
                _TopBar(current: route),
                Divider(height: 1, color: t.colorScheme.outline),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.collapsed,
    required this.access,
    required this.current,
  });

  final bool collapsed;
  final SwanAccess access;
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final visible = kConsoleModules.where((m) => m.visibleTo(access)).toList();
    final club = ref.watch(activeClubProvider).valueOrNull;
    final config = ref.watch(platformConfigProvider).valueOrNull;
    final name = config?.appName?.trim();
    final appName = name == null || name.isEmpty ? 'SwanSport' : name;

    // Kitleye göre grupla — kulüp işleri ile platform işleri karışmasın.
    //
    // Bir modül birden fazla kitleye açık olabiliyor (mali modüller hem kulüp
    // yetkilisine hem muhasebeciye). Başlık, kullanıcının **kendi** sahip
    // olduğu kitleden seçiliyor: dışarıdan gelen muhasebeci mali modülleri
    // "Kulüp" başlığı altında görmesin, "Muhasebe" altında görsün.
    // Kitleye ve role göre temiz, düzenli gruplama.
    final groups = <String, List<ConsoleModule>>{};
    for (final m in visible) {
      String group;
      if (m.audience.contains(ConsoleAudience.federation)) {
        group = 'FEDERASYON YÖNETİMİ';
      } else if (m.audience.contains(ConsoleAudience.referee)) {
        group = 'HAKEM KOKPİTİ';
      } else if (m.audience.contains(ConsoleAudience.accountant) && !access.isClubStaff) {
        group = 'MALİ İŞLER';
      } else if (m.audience.contains(ConsoleAudience.clubStaff)) {
        if (m.audience.contains(ConsoleAudience.accountant)) {
          group = 'MALİ İŞLER';
        } else {
          group = 'KULÜP YÖNETİMİ';
        }
      } else if (m.audience.contains(ConsoleAudience.platformAdmin)) {
        group = 'PLATFORM YÖNETİMİ';
      } else {
        group = 'DİĞER MODÜLLER';
      }
      groups.putIfAbsent(group, () => []).add(m);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: collapsed
          ? ConsoleDensity.sidebarCollapsedWidth
          : ConsoleDensity.sidebarWidth,
      color: t.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: ConsoleDensity.topBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ConsoleDensity.md,
              ),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary.withValues(alpha: .14),
                      borderRadius:
                          BorderRadius.circular(ConsoleDensity.radius),
                      border: Border.all(
                        color: t.colorScheme.primary.withValues(alpha: .32),
                      ),
                    ),
                    child: Tooltip(
                      message: appName,
                      child: SwanNetworkLogo(
                        url: config?.logoUrl,
                        size: ConsoleDensity.brandMarkSize,
                        semanticLabel: appName,
                        fallback: Icon(
                          Icons.shield_moon_rounded,
                          color: t.colorScheme.primary,
                          size: ConsoleDensity.brandMarkSize,
                        ),
                      ),
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: ConsoleDensity.sm + 2),
                    Expanded(
                      child: Text(
                        appName,
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: t.colorScheme.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'PRO',
                        style: t.textTheme.labelSmall?.copyWith(
                          fontSize: 9.5,
                          color: t.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: t.colorScheme.outline),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ConsoleDensity.md,
                ConsoleDensity.md,
                ConsoleDensity.md,
                ConsoleDensity.sm,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ConsoleDensity.md,
                  vertical: ConsoleDensity.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                  border: Border.all(color: t.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Icon(
                      club != null
                          ? Icons.shield_outlined
                          : access.isReferee
                              ? Icons.sports_score_rounded
                              : (access.hasActiveFederationRole || access.canPublishFederationResults)
                                  ? Icons.verified_user_rounded
                                  : access.isPlatformAdmin
                                      ? Icons.admin_panel_settings_rounded
                                      : Icons.shield_outlined,
                      size: 17,
                      color: t.colorScheme.primary,
                    ),
                    const SizedBox(width: ConsoleDensity.sm),
                    Expanded(
                      child: Text(
                        club?.name ??
                            (access.isReferee
                                ? 'Hakem Kokpiti'
                                : (access.hasActiveFederationRole || access.canPublishFederationResults)
                                    ? 'Federasyon Yönetimi'
                                    : access.isPlatformAdmin
                                        ? 'Platform Yönetimi'
                                        : 'Kulüp seçilmedi'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (club != null)
                      Tooltip(
                        message:
                            club.isPending ? 'Onay bekliyor' : 'Aktif kulüp',
                        child: Icon(
                          club.isPending
                              ? Icons.hourglass_top_rounded
                              : Icons.verified_rounded,
                          size: 16,
                          color: club.isPending
                              ? SwanColors.warning
                              : SwanColors.success,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: ConsoleDensity.sm),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: ConsoleDensity.sm),
            child: Material(
              color: current == '/'
                  ? t.colorScheme.primary.withValues(alpha: .14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(ConsoleDensity.radius),
              child: Tooltip(
                message: 'Komuta Merkezi',
                child: InkWell(
                  borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                  onTap: () => context.go('/'),
                  child: Container(
                    height: 40,
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 0 : ConsoleDensity.md,
                    ),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(ConsoleDensity.radius),
                      border: current == '/'
                          ? Border.all(
                              color:
                                  t.colorScheme.primary.withValues(alpha: .35),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: collapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.space_dashboard_rounded,
                          size: 20,
                          color: current == '/'
                              ? t.colorScheme.primary
                              : t.colorScheme.onSurfaceVariant,
                        ),
                        if (!collapsed) ...[
                          const SizedBox(width: ConsoleDensity.md),
                          Expanded(
                            child: Text(
                              'Komuta Merkezi',
                              overflow: TextOverflow.ellipsis,
                              style: t.textTheme.bodyMedium?.copyWith(
                                color: current == '/'
                                    ? t.colorScheme.primary
                                    : t.colorScheme.onSurface,
                                fontWeight: current == '/'
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: ConsoleDensity.sm,
              ),
              children: [
                for (final entry in groups.entries) ...[
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ConsoleDensity.lg,
                        ConsoleDensity.md,
                        ConsoleDensity.lg,
                        ConsoleDensity.xs,
                      ),
                      child: Text(
                        entry.key,
                        style: t.textTheme.labelSmall,
                      ),
                    )
                  else
                    const SizedBox(height: ConsoleDensity.md),
                  for (final m in entry.value)
                    _NavItem(
                      module: m,
                      collapsed: collapsed,
                      selected: m.route == current ||
                          current.startsWith('${m.route}/'),
                    ),
                ],
                if (visible.isEmpty && !collapsed)
                  Padding(
                    padding: const EdgeInsets.all(ConsoleDensity.lg),
                    child: Text(
                      'Bu hesabın konsolda yönetebileceği bir alan yok. '
                      'Kulüp yetkilisi ya da platform yöneticisi olman gerekiyor.',
                      style: t.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: t.colorScheme.outline),
          _AccountCard(collapsed: collapsed, access: access),
          // Ekran zaten dar olduğu için daraltılmışsa düğme işlevsiz —
          // basılabilir görünüp hiçbir şey yapmaması yanıltıcı olurdu.
          if (MediaQuery.sizeOf(context).width >=
              ConsoleDensity.autoCollapseWidth)
            IconButton(
              tooltip: collapsed ? 'Menüyü genişlet' : 'Menüyü daralt',
              icon: Icon(
                collapsed
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
              ),
              onPressed: () => ref
                  .read(sidebarCollapsedProvider.notifier)
                  .update((v) => !v),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.module,
    required this.collapsed,
    required this.selected,
  });

  final ConsoleModule module;
  final bool collapsed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final fg = selected
        ? t.colorScheme.primary
        : t.textTheme.bodyMedium?.color;
    final iconColor = selected
        ? t.colorScheme.primary
        : t.colorScheme.onSurfaceVariant;

    final item = Container(
      height: 38,
      margin: const EdgeInsets.symmetric(
        horizontal: ConsoleDensity.sm,
        vertical: 1.5,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 0 : ConsoleDensity.md,
      ),
      decoration: BoxDecoration(
        color: selected
            ? t.colorScheme.primary.withValues(alpha: .14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: selected
            ? Border.all(
                color: t.colorScheme.primary.withValues(alpha: .32),
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(module.icon, size: 19, color: iconColor),
          if (!collapsed) ...[
            const SizedBox(width: ConsoleDensity.md),
            Expanded(
              child: Text(
                module.label,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.colorScheme.primary,
                ),
              ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: collapsed ? module.label : '',
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        // go_router: tarayıcı adres çubuğu ve geri tuşu gerçekten çalışsın.
        onTap: () => GoRouter.of(context).go(module.route),
        child: item,
      ),
    );
  }
}

/// Birden fazla kulüpte görevli olanlar için kulüp seçici.
///
/// Tek kulübü olan için düz metin: her yere açılır menü koymak, seçenek
/// olmadığı hâlde seçim varmış hissi verirdi.
class _ClubSwitcher extends ConsumerWidget {
  const _ClubSwitcher({required this.current});

  final ClubRef current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final clubs = ref.watch(myClubsProvider).valueOrNull ?? const <ClubRef>[];

    if (clubs.length < 2) {
      return _clubChip(context, current.name, canSwitch: false);
    }

    return PopupMenuButton<String>(
      tooltip: 'Kulüp değiştir',
      onSelected: (id) =>
          ref.read(selectedClubIdProvider.notifier).state = id,
      itemBuilder: (_) => [
        for (final c in clubs)
          PopupMenuItem(
            value: c.id,
            child: Row(
              children: [
                Icon(
                  c.id == current.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: c.id == current.id ? t.colorScheme.primary : null,
                ),
                const SizedBox(width: ConsoleDensity.sm),
                Text(c.name),
                if (c.isPending) ...[
                  const SizedBox(width: ConsoleDensity.sm),
                  Text('(onay bekliyor)', style: t.textTheme.bodySmall),
                ],
              ],
            ),
          ),
      ],
      child: _clubChip(context, current.name, canSwitch: true),
    );
  }

  Widget _clubChip(
    BuildContext context,
    String name, {
    required bool canSwitch,
  }) {
    final t = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(
        horizontal: ConsoleDensity.md,
        vertical: ConsoleDensity.sm - 1,
      ),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withValues(alpha: .10),
        border: Border.all(
          color: t.colorScheme.primary.withValues(alpha: .28),
        ),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: t.colorScheme.primary),
          const SizedBox(width: ConsoleDensity.sm),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (canSwitch) ...[
            const SizedBox(width: ConsoleDensity.xs),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: t.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final module = moduleForRoute(current);
    final club = ref.watch(activeClubProvider).valueOrNull;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final session = ref.watch(authSessionProvider);
    final signedIn = session.valueOrNull != null;

    return Container(
      height: ConsoleDensity.topBarHeight,
      color: t.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.xl),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: t.colorScheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              module?.icon ??
                  (current == '/'
                      ? Icons.space_dashboard_rounded
                      : Icons.person_outline_rounded),
              size: 18,
              color: t.colorScheme.primary,
            ),
          ),
          const SizedBox(width: ConsoleDensity.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module?.label ??
                      (current == '/' ? 'Komuta Merkezi' : 'Sporcu Detayı'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Konsol > ${module?.label ?? (current == '/' ? 'Genel Bakış' : 'Sporcular')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (club != null) ...[
            const SizedBox(width: ConsoleDensity.md),
            Container(
              width: 1,
              height: 20,
              color: t.colorScheme.outline,
            ),
            const SizedBox(width: ConsoleDensity.sm),
            _ClubSwitcher(current: club),
          ],
          const SizedBox(width: ConsoleDensity.md),
          Tooltip(
            message: signedIn
                ? 'Oturum açık; sunucu bağlantısı göstergesi değildir.'
                : 'Oturum doğrulanıyor',
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ConsoleDensity.sm + 2,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.colorScheme.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: signedIn
                          ? SwanColors.success
                          : t.colorScheme.outline,
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width >=
                      ConsoleDensity.autoCollapseWidth) ...[
                    const SizedBox(width: ConsoleDensity.sm),
                    Text(
                      signedIn ? 'Oturum açık' : 'Oturum bekleniyor',
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: ConsoleDensity.xs),
          IconButton(
            tooltip: 'Temayı değiştir',
            icon: Icon(
              t.brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () =>
                ref.read(consoleThemeModeProvider.notifier).state =
                    t.brightness == Brightness.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
          ),
          PopupMenuButton<String>(
            tooltip: 'Hesap',
            icon: const Icon(Icons.account_circle_rounded, size: 22),
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(profile?.fullName ?? 'Hesap'),
              ),
              const PopupMenuItem(value: 'signout', child: Text('Çıkış yap')),
            ],
            onSelected: (v) async {
              if (v == 'signout') {
                await _signOut(context, ref);
              }
            },
          ),
        ],
      ),
    );
  }
}

String _roleLabel(SwanAccess access) {
  if (access.isPlatformAdmin) return 'Platform yöneticisi';
  if (access.isFederationPresident) return 'Federasyon başkanı';
  if (access.isRefereeCommitteeMember) return 'MHK üyesi';
  if (access.isDisciplinaryBoardMember) return 'Disiplin kurulu üyesi';
  if (access.hasActiveFederationRole) return 'Federasyon yetkilisi';
  if (access.isReferee) return 'Müsabaka hakemi';
  if (access.isClubAdmin) return 'Kulüp yöneticisi';
  if (access.isClubStaff) return 'Kulüp personeli';
  if (access.isAccountant) return 'Muhasebeci';
  if (access.canPublishFederationResults) return 'Federasyon yetkilisi';
  return 'Hesap';
}

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(accountSessionServiceProvider).signOut();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çıkış yapılamadı. Yeniden dene.')),
      );
    }
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.collapsed, required this.access});
  final bool collapsed;
  final SwanAccess access;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final t = Theme.of(context);
    final avatar = Tooltip(
      message: profile?.fullName ?? 'Hesap',
      child: CircleAvatar(
        radius: 16,
        backgroundColor: t.colorScheme.primary.withValues(alpha: .16),
        child: Text(
          profile?.initials ?? '?',
          style: t.textTheme.labelSmall?.copyWith(
            color: t.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final exit = IconButton(
      tooltip: 'Çıkış yap',
      icon: const Icon(Icons.logout_rounded, size: 18),
      onPressed: () => _signOut(context, ref),
    );
    return Padding(
      padding: const EdgeInsets.all(ConsoleDensity.sm),
      child: collapsed
          ? Column(children: [avatar, exit])
          : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ConsoleDensity.sm,
                vertical: ConsoleDensity.xs,
              ),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(ConsoleDensity.radius),
              ),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: ConsoleDensity.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.fullName ?? 'Hesap',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(_roleLabel(access), style: t.textTheme.labelSmall),
                      ],
                    ),
                  ),
                  exit,
                ],
              ),
            ),
    );
  }
}
