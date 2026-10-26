import 'package:flutter/material.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../pro_operations/swan_pro_feature_host.dart';

class AttendanceQueueBanner extends StatelessWidget {
  const AttendanceQueueBanner({super.key});

  @override
  Widget build(BuildContext context) => const SwanProFeatureHost(
        child: SharedAttendanceQueueBanner(),
      );
}
