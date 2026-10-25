import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the current list route, filters and scroll position mounted.
Future<T?> showConsoleDetailPanel<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  Widget? action,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Ayrıntıyı kapat',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: math.min(MediaQuery.sizeOf(context).width * .8, 640),
          height: double.infinity,
          child: Material(
            elevation: 12,
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                        child: Semantics(
                      header: true,
                      child: Text(title,
                          style: Theme.of(context).textTheme.titleLarge),
                    )),
                    if (action != null) action,
                    IconButton(
                      autofocus: true,
                      tooltip: 'Ayrıntıyı kapat',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(child: child),
              ]),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    );
