import 'package:flutter/material.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../pro_operations/swan_pro_feature_host.dart';

class WorkoutProtocolBuilderScreen extends StatelessWidget {
  const WorkoutProtocolBuilderScreen({this.initialTitle = '', super.key});
  final String initialTitle;

  @override
  Widget build(BuildContext context) => SwanProFeatureHost(
        child: SharedWorkoutBuilderScreen(initialTitle: initialTitle),
      );
}
