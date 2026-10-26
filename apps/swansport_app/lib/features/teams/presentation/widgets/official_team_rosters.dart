import 'package:flutter/material.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../../pro_operations/swan_pro_feature_host.dart';

class OfficialTeamRosters extends StatelessWidget {
  const OfficialTeamRosters({required this.teamId, super.key});
  final String teamId;

  @override
  Widget build(BuildContext context) => SwanProFeatureHost(
        child: SharedOfficialTeamRosters(teamId: teamId),
      );
}
