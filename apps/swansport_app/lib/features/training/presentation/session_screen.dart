import 'package:flutter/material.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../pro_operations/swan_pro_feature_host.dart';

class TrainingSessionScreen extends StatelessWidget {
  const TrainingSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final mapId = arguments is Map ? arguments['id'] : null;
    final id = mapId is String
        ? mapId
        : arguments is String
            ? arguments
            : null;
    return SwanProFeatureHost(
      child: SharedTrainingSessionScreen(sessionId: id),
    );
  }
}
