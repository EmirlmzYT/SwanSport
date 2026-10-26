import 'package:flutter/material.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../../pro_operations/swan_pro_feature_host.dart';

class TeamRosterScreen extends StatelessWidget {
  const TeamRosterScreen({
    required this.teamId,
    required this.teamName,
    super.key,
  });

  final String teamId;
  final String teamName;

  @override
  Widget build(BuildContext context) => SwanProFeatureHost(
        child: SharedTeamRosterScreen(
          target: TeamRouteTarget(teamId: teamId, teamName: teamName),
        ),
      );
}
