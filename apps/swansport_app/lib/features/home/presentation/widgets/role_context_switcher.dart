import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../demo/demo_role.dart';

class RoleContextOption {
  const RoleContextOption({
    required this.role,
    required this.label,
    required this.icon,
  });

  final DemoRole role;
  final String label;
  final IconData icon;
}

const kRoleContextOptions = [
  RoleContextOption(
    role: DemoRole.athleteLicensed,
    label: 'Sporcu',
    icon: Icons.directions_run_rounded,
  ),
  RoleContextOption(
    role: DemoRole.coach3,
    label: 'Antrenör',
    icon: Icons.sports_rounded,
  ),
  RoleContextOption(
    role: DemoRole.guardian,
    label: 'Veli',
    icon: Icons.family_restroom_rounded,
  ),
  RoleContextOption(
    role: DemoRole.clubAdmin,
    label: 'Yönetici',
    icon: Icons.admin_panel_settings_rounded,
  ),
];

/// Ana Sayfa üst alanında kullanıcının aktif rol bağlamını hızlıca değiştirmesini sağlayan çip çubuğu.
class RoleContextSwitcher extends ConsumerWidget {
  const RoleContextSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final activeRole = ref.watch(demoRoleProvider);
    const tealColor = Color(0xFF00B4D8);

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kRoleContextOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opt = kRoleContextOptions[index];
          final isActive = activeRole == opt.role;

          return GestureDetector(
            onTap: () {
              ref.read(demoRoleProvider.notifier).state = opt.role;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? tealColor : surf,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? tealColor : line,
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: tealColor.withValues(alpha: .25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt.icon,
                    size: 15,
                    color: isActive ? Colors.black : ink.withValues(alpha: .7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    opt.label,
                    style: SwanType.caption(
                      isActive ? Colors.black : ink,
                      w: isActive ? FontWeight.w800 : FontWeight.w600,
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
}
