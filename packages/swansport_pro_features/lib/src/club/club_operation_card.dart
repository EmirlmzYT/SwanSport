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
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: title,
        child: Material(
          color: theme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.line),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 104),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.accent.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Icon(icon, color: theme.accent, size: 23),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: theme.ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.inkMuted,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: theme.inkMuted,
                        size: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
