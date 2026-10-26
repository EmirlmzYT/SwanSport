import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../pro_operations/swan_pro_feature_host.dart';

class ProtocolListScreen extends StatelessWidget {
  const ProtocolListScreen({this.initialMode, super.key});
  final TrainingMode? initialMode;

  @override
  Widget build(BuildContext context) => const SwanProFeatureHost(
        child: SharedProtocolListScreen(),
      );
}
