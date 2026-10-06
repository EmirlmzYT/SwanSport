import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';
import 'protocol_list_screen.dart';

class MatchSimulationScreen extends StatelessWidget {
  const MatchSimulationScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ProtocolListScreen(initialMode: TrainingMode.simulation);
}
