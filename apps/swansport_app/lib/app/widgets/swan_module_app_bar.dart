import 'package:flutter/material.dart';
import '../navigation/swan_back_navigation.dart';
import '../design/swan_palette.dart';
import '../design/swan_type.dart';

/// Partner Bul contract for secondary module screens. Main social surfaces
/// keep their own headers; this factory is deliberately opt-in.
AppBar swanModuleAppBar(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Widget> actions = const [],
  String? fallbackRoute,
}) {
  final c = context.swan;
  return AppBar(
    backgroundColor: c.bg,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    automaticallyImplyLeading: false,
    leading: SwanBackNavigation.shouldShow(
      context,
      fallbackRoute: fallbackRoute,
    )
        ? SwanBackButton(fallbackRoute: fallbackRoute)
        : null,
    title: subtitle == null
        ? Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SwanType.h3(c.ink))
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.h3(c.ink)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(c.inkMuted)),
              ]),
    actions: actions,
  );
}
