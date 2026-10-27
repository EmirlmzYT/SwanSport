import 'package:flutter/material.dart';

import '../host/pro_feature_theme.dart';

final class ClubOperationCard extends StatelessWidget {
  const ClubOperationCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    required this.theme,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) => Material(
        color: theme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.line),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: theme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: theme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(detail, style: TextStyle(color: theme.inkMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.inkMuted),
              ],
            ),
          ),
        ),
      );
}
