import '../preferences/console_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../modules/console_module.dart';
import '../modules/module_registry.dart';
import '../modules/console_workspace.dart';
import '../theme/console_theme.dart';
import 'too_narrow_notice.dart';

final sidebarCollapsedProvider = consolePreference<bool>('sidebar',
    fallback: () => false,
    decode: (v) => v is bool ? v : false,
    encode: (v) => v);

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
    final collapsed = ref.watch(sidebarCollapsedProvider) ||
        width < ConsoleDensity.autoCollapseWidth;
    final access = ref.watch(consoleAccessProvider);
    final workspace = resolveConsoleWorkspace(
        access, ref.watch(consoleWorkspaceProvider), route);
    return Scaffold(
        body: Row(children: [
      _Sidebar(
          collapsed: collapsed,
          access: access,
          current: route,
          workspace: workspace),
      const VerticalDivider(width: 1),
      Expanded(
          child: Column(children: [
        _TopBar(current: route, workspace: workspace),
        const Divider(height: 1),
        Expanded(child: child),
      ])),
    ]));
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar(
      {required this.collapsed,
      required this.access,
      required this.current,
      required this.workspace});
  final bool collapsed;
  final SwanAccess access;
  final String current;
  final ConsoleWorkspace? workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final config = ref.watch(platformConfigProvider).valueOrNull;
    final name = config?.appName?.trim();
    final appName = name == null || name.isEmpty ? 'SwanSport' : name;
    final visible = workspace == null
        ? <ConsoleModule>[]
        : workspaceModules(access, workspace!);
    final groups = <String, List<ConsoleModule>>{};
    for (final module in visible) {
      groups.putIfAbsent(consoleModuleGroup(module), () => []).add(module);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: collapsed
          ? ConsoleDensity.sidebarCollapsedWidth
          : ConsoleDensity.sidebarWidth,
      color: t.colorScheme.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: ConsoleDensity.topBarHeight,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg),
              child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    SwanNetworkLogo(
                        url: config?.logoUrl,
                        size: ConsoleDensity.brandMarkSize,
                        semanticLabel: appName,
                        fallback: Icon(Icons.sports_rounded,
                            color: t.colorScheme.primary,
                            size: ConsoleDensity.brandMarkSize)),
                    if (!collapsed) ...[
                      const SizedBox(width: ConsoleDensity.md),
                      Expanded(
                          child: Text(appName,
                              overflow: TextOverflow.ellipsis,
                              style: t.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800))),
                      Text('KONSOL',
                          style: t.textTheme.labelSmall?.copyWith(fontSize: 9)),
                    ],
                  ]),
            )),
        Padding(
            padding: const EdgeInsets.all(ConsoleDensity.md),
            child: _WorkspacePicker(
                workspace: workspace, access: access, collapsed: collapsed)),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.sm),
            child: _NavigationRow(
                label: 'Genel bakış',
                icon: Icons.grid_view_rounded,
                collapsed: collapsed,
                selected: current == '/',
                onTap: () {
                  ref.read(consoleWorkspaceProvider.notifier).state = workspace;
                  context.go('/');
                })),
        Expanded(
            child: ListView(
                padding: const EdgeInsets.only(bottom: ConsoleDensity.lg),
                children: [
              for (final group in groups.entries) ...[
                if (!collapsed)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 12, 8),
                      child: Text(group.key,
                          style: t.textTheme.labelSmall
                              ?.copyWith(fontSize: 10, letterSpacing: 1.2)))
                else
                  const SizedBox(height: ConsoleDensity.lg),
                for (final module in group.value)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ConsoleDensity.sm, vertical: 1),
                      child: _NavigationRow(
                          label: module.label,
                          icon: module.icon,
                          collapsed: collapsed,
                          selected: current == module.route ||
                              current.startsWith('${module.route}/'),
                          onTap: () => context.go(module.route))),
              ],
              if (visible.isEmpty && !collapsed)
                const Padding(
                    padding: EdgeInsets.all(ConsoleDensity.lg),
                    child: Text('Bu hesap için açık bir çalışma alanı yok.')),
            ])),
        const Divider(height: 1),
        _AccountCard(collapsed: collapsed, access: access),
        if (MediaQuery.sizeOf(context).width >=
            ConsoleDensity.autoCollapseWidth)
          Align(
              alignment: collapsed ? Alignment.center : Alignment.centerRight,
              child: IconButton(
                  tooltip: collapsed ? 'Menüyü genişlet' : 'Menüyü daralt',
                  icon: Icon(
                      collapsed
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      size: 18),
                  onPressed: () => ref
                      .read(sidebarCollapsedProvider.notifier)
                      .update((v) => !v))),
      ]),
    );
  }
}

class _WorkspacePicker extends ConsumerWidget {
  const _WorkspacePicker(
      {required this.workspace, required this.access, required this.collapsed});
  final ConsoleWorkspace? workspace;
  final SwanAccess access;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final available = consoleWorkspaces(access);
    final label = workspace == ConsoleWorkspace.club &&
            access.isAccountant &&
            !access.isClubStaff
        ? 'Muhasebe'
        : workspace?.label ?? 'Çalışma alanı';
    final content = Container(
      padding:
          EdgeInsets.all(collapsed ? ConsoleDensity.sm : ConsoleDensity.md),
      decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          border: Border.all(color: t.colorScheme.outline)),
      child: Row(
          mainAxisAlignment:
              collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(workspace?.icon ?? Icons.workspaces_outline,
                size: 20, color: t.colorScheme.primary),
            if (!collapsed) ...[
              const SizedBox(width: ConsoleDensity.md),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('ÇALIŞMA ALANI',
                        style: t.textTheme.labelSmall
                            ?.copyWith(fontSize: 9, letterSpacing: 1)),
                    const SizedBox(height: 3),
                    Text(label, style: t.textTheme.titleSmall),
                  ])),
              if (available.length > 1)
                const Icon(Icons.unfold_more_rounded, size: 18),
            ],
          ]),
    );
    if (available.length < 2) return Tooltip(message: label, child: content);
    return PopupMenuButton<ConsoleWorkspace>(
      tooltip: 'Çalışma alanını değiştir',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        ref.read(consoleWorkspaceProvider.notifier).state = value;
        context.go('/');
      },
      itemBuilder: (_) => [
        for (final item in available)
          PopupMenuItem(
            value: item,
            child: Row(children: [
              Icon(item.icon, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(item.label)),
              if (item == workspace)
                Icon(Icons.check_rounded,
                    size: 18, color: t.colorScheme.primary)
            ]),
          )
      ],
      child: content,
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow(
      {required this.label,
      required this.icon,
      required this.collapsed,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color =
        selected ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant;
    return Tooltip(
        message: collapsed ? label : '',
        child: Material(
          color: selected
              ? t.colorScheme.primary.withValues(alpha: .08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Semantics(
                selected: selected,
                child: SizedBox(
                    height: 40,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: collapsed ? 0 : ConsoleDensity.md),
                      child: Row(
                          mainAxisAlignment: collapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            Icon(icon, size: 18, color: color),
                            if (!collapsed) ...[
                              const SizedBox(width: ConsoleDensity.md),
                              Expanded(
                                  child: Text(label,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.textTheme.bodyMedium?.copyWith(
                                          color: selected
                                              ? t.colorScheme.onSurface
                                              : color,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400))),
                              if (selected)
                                Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                        color: t.colorScheme.primary,
                                        borderRadius:
                                            BorderRadius.circular(2))),
                            ],
                          ]),
                    ))),
          ),
        ));
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.current, required this.workspace});
  final String current;
  final ConsoleWorkspace? workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final module = moduleForRoute(current);
    final club = ref.watch(activeClubProvider).valueOrNull;
    return Container(
      height: ConsoleDensity.topBarHeight,
      color: t.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.xl),
      child: Row(children: [
        Text(workspace?.label ?? 'Konsol', style: t.textTheme.bodySmall),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.md),
            child: Icon(Icons.chevron_right_rounded,
                size: 16, color: t.colorScheme.onSurfaceVariant)),
        Expanded(
            child: Text(
                module?.label ??
                    (current == '/' ? 'Genel bakış' : 'Sporcu detayı'),
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleSmall)),
        if (club != null && workspace == ConsoleWorkspace.club)
          _ClubSwitcher(current: club),
        const SizedBox(width: ConsoleDensity.md),
        IconButton(
            tooltip: 'Sayfa ara',
            icon: const Icon(Icons.search_rounded, size: 20),
            onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _ModuleSearch(workspace: workspace))),
        IconButton(
            tooltip: 'Temayı değiştir',
            icon: Icon(
                t.brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 20),
            onPressed: () => ref.read(consoleThemeModeProvider.notifier).state =
                t.brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark),
      ]),
    );
  }
}

class _ModuleSearch extends ConsumerStatefulWidget {
  const _ModuleSearch({required this.workspace});
  final ConsoleWorkspace? workspace;
  @override
  ConsumerState<_ModuleSearch> createState() => _ModuleSearchState();
}

class _ModuleSearchState extends ConsumerState<_ModuleSearch> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final access = ref.watch(consoleAccessProvider);
    final modules = widget.workspace == null
        ? <ConsoleModule>[]
        : workspaceModules(access, widget.workspace!);
    final matches = modules
        .where((m) => m.label.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Dialog(
        child: SizedBox(
            width: 520,
            height: 440,
            child: Padding(
              padding: const EdgeInsets.all(ConsoleDensity.xl),
              child: Column(children: [
                TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                        hintText: 'Bu çalışma alanında sayfa ara…',
                        prefixIcon: Icon(Icons.search_rounded)),
                    onChanged: (value) => setState(() => query = value)),
                const SizedBox(height: ConsoleDensity.md),
                Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('Eşleşen sayfa yok.'))
                        : ListView(
                            children: [
                              for (final module in matches)
                                ListTile(
                                  leading: Icon(module.icon, size: 20),
                                  title: Text(module.label),
                                  trailing: const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.go(module.route);
                                  },
                                )
                            ],
                          )),
              ]),
            )));
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
      onSelected: (id) => ref.read(selectedClubIdProvider.notifier).state = id,
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
