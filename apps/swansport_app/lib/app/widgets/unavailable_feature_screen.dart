import 'package:flutter/material.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';
import 'swan_bottom_nav.dart';

/// Preserves older links without presenting unfinished prototypes as records.
class UnavailableFeatureScreen extends StatelessWidget {
  const UnavailableFeatureScreen({
    super.key,
    required this.title,
    required this.message,
    required this.route,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String route;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(title, style: SwanType.h3(c.ink))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SwanSpace.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message,
                style: SwanType.body(c.inkMuted), textAlign: TextAlign.center),
            const SizedBox(height: SwanSpace.lg),
            FilledButton(
              onPressed: () => Navigator.pushReplacementNamed(context, route),
              child: Text(actionLabel),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}
