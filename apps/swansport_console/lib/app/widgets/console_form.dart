import 'package:flutter/material.dart';
import '../theme/console_theme.dart';

/// Optional inputs stay mounted while collapsed so a form never loses edits.
class ConsoleOptionalFields extends StatelessWidget {
  const ConsoleOptionalFields(
      {required this.children, this.initiallyExpanded = false, super.key});
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        title: const Text('Ek bilgiler'),
        subtitle: const Text('İsteğe bağlı'),
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: ConsoleDensity.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
}
