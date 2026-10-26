import 'package:flutter/material.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../../pro_operations/swan_pro_feature_host.dart';

class LiveAttendanceScreen extends StatelessWidget {
  const LiveAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final argument = ModalRoute.of(context)?.settings.arguments;
    return SwanProFeatureHost(
      child: SharedLiveAttendanceScreen(
        initialEventId: argument is String ? argument : null,
      ),
    );
  }
}
