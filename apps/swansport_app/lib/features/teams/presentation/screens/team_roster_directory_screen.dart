import 'package:flutter/material.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../../pro_operations/swan_pro_feature_host.dart';

/// Legacy route-compatible wrapper for the shared professional team directory.
class TeamRosterDirectoryScreen extends StatelessWidget {
  const TeamRosterDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) => const SwanProFeatureHost(
        child: SharedTeamDirectoryScreen(),
      );
}
