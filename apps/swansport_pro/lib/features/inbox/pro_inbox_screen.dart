import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../app/pro_theme.dart';
import '../../widgets/pro_ui_components.dart';

final class ProInboxScreen extends StatelessWidget {
  const ProInboxScreen({
    required this.onNotificationTap,
    super.key,
  });

  final void Function(NotificationRow notification) onNotificationTap;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 520;
              return Padding(
                padding: EdgeInsets.fromLTRB(20, compact ? 4 : 16, 20, 0),
                child: Column(
                  children: [
                    ProPageHeader(
                      title: 'Gelen Kutusu',
                      compact: compact,
                      subtitle: compact
                          ? null
                          : 'Profesyonel görev ve operasyon bildirimlerini takip edin.',
                      leading: compact
                          ? null
                          : const DecoratedBox(
                              decoration: BoxDecoration(
                                color: ProTheme.surfaceRaised,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(
                                  Icons.inbox_outlined,
                                  color: ProTheme.primary,
                                ),
                              ),
                            ),
                    ),
                    if (!compact) const SizedBox(height: 8),
                    Expanded(
                      child: SharedProInboxScreen(
                        embedded: true,
                        onNotificationTap: onNotificationTap,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}
