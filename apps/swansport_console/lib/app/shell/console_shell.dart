import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

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

    // Kitleye göre grupla — kulüp işleri ile platform işleri karışmasın.
    final groups = <ConsoleAudience, List<ConsoleModule>>{};
    for (final m in visible) {
      groups.putIfAbsent(m.audience, () => []).add(m);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
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
                  horizontal: ConsoleDensity.md),
              child: Row(
                children: [
                  Icon(Icons.shield_moon_rounded,
                      color: t.colorScheme.primary, size: 22),
                  if (!collapsed) ...[
                    const SizedBox(width: ConsoleDensity.sm),
                    Expanded(
                      child: Text('SwanSport',
                          style: t.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: t.colorScheme.outline),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  vertical: ConsoleDensity.sm),
              children: [
                for (final entry in groups.entries) ...[
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          ConsoleDensity.lg,
                          ConsoleDensity.md,
                          ConsoleDensity.lg,
                          ConsoleDensity.xs),
                      child: Text(entry.key.label.toUpperCase(),
                          style: t.textTheme.labelSmall),
                    )
                  else
                    const SizedBox(height: ConsoleDensity.md),
                  for (final m in entry.value)
                    _NavItem(
                      module: m,
                      collapsed: collapsed,
                      selected: m.route == current,
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
          // Ekran zaten dar olduğu için daraltılmışsa düğme işlevsiz —
          // basılabilir görünüp hiçbir şey yapmaması yanıltıcı olurdu.
          if (MediaQuery.sizeOf(context).width >=
              ConsoleDensity.autoCollapseWidth)
            IconButton(
              tooltip: collapsed ? 'Menüyü genişlet' : 'Menüyü daralt',
              icon: Icon(collapsed
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded),
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
    final fg = selected ? t.colorScheme.primary : t.textTheme.bodyMedium?.color;

    final item = Container(
      height: 38,
      margin: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.sm, vertical: 1),
      padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : ConsoleDensity.md),
      decoration: BoxDecoration(
        color: selected
            ? t.colorScheme.primary.withValues(alpha: .10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      ),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(module.icon, size: 19, color: fg),
          if (!collapsed) ...[
            const SizedBox(width: ConsoleDensity.md),
            Expanded(
              child: Text(
                module.label,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.sm),
        child: Text(current.name, style: t.textTheme.bodySmall),
      );
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ConsoleDensity.sm, vertical: ConsoleDensity.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.name, style: t.textTheme.bodySmall),
            const SizedBox(width: ConsoleDensity.xs),
            Icon(Icons.expand_more_rounded,
                size: 16, color: t.colorScheme.outline),
          ],
        ),
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

    return SizedBox(
      height: ConsoleDensity.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.xl),
        child: Row(
          children: [
            Text(module?.label ?? 'Konsol', style: t.textTheme.titleMedium),
            if (club != null) ...[
              const SizedBox(width: ConsoleDensity.md),
              Container(
                width: 1,
                height: 18,
                color: t.colorScheme.outline,
              ),
              const SizedBox(width: ConsoleDensity.sm),
              _ClubSwitcher(current: club),
            ],
            const Spacer(),
            if (profile != null)
              Text(profile.fullName, style: t.textTheme.bodySmall),
            const SizedBox(width: ConsoleDensity.md),
            PopupMenuButton<String>(
              tooltip: 'Hesap',
              icon: const Icon(Icons.account_circle_rounded, size: 22),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'signout', child: Text('Çıkış yap')),
              ],
              onSelected: (v) async {
                if (v == 'signout') {
                  await Supabase.instance.client.auth.signOut();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
