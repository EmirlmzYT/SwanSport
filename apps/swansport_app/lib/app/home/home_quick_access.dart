import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';
import '../widgets/quick_actions.dart';
import 'quick_access_catalog.dart';
import 'quick_access_preferences.dart';
import 'quick_access_screen.dart';

void openQuickAccessSettings(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const QuickAccessScreen()));

class HomeQuickAccess extends ConsumerWidget {
  const HomeQuickAccess({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(quickAccessAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final prefs =
        ref.watch(quickAccessPreferencesProvider(account)).valueOrNull;
    if (prefs == null || prefs.hidden) return const SizedBox.shrink();
    final shortcuts = selectedHomeShortcuts(
      prefs,
      ref.watch(swanAccessProvider),
      ref.watch(availableHomeShortcutsProvider),
    );
    final c = context.swan;
    return Padding(
      key: const Key('home-quick-access'),
      padding: const EdgeInsets.fromLTRB(
        SwanSpace.lg,
        SwanSpace.sm,
        SwanSpace.lg,
        SwanSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('Hızlı erişim',
                      style: SwanType.body(c.ink, w: FontWeight.w700))),
              TextButton(
                onPressed: () => openQuickAccessSettings(context),
                child: const Text('Düzenle'),
              ),
            ],
          ),
          if (shortcuts.isEmpty)
            TextButton.icon(
              onPressed: () => openQuickAccessSettings(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('İlk kısayolunu seç'),
            )
          else
            QuickActions(
              wrap: true,
              actions: [
                for (final item in shortcuts)
                  QuickAction(
                    icon: item.icon,
                    label: item.label,
                    route: item.route,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
