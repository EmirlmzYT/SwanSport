import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

import 'config/app_environment.dart';
import 'swansport_app.dart';

/// VS Code Flutter Widget Preview entry point.
///
/// An empty Supabase configuration deliberately selects the development
/// fixtures, so the preview never connects to a live backend.
@Preview(
  name: 'SwanSport uygulaması',
  group: 'Uygulama',
  size: Size(390, 844),
)
Widget swanSportAppPreview() {
  return ProviderScope(
    overrides: <Override>[
      appEnvironmentProvider.overrideWithValue(
        const AppEnvironment.development(),
      ),
      supabaseConfigProvider.overrideWithValue(SupabaseConfig.empty),
    ],
    child: const SwanSportApp(),
  );
}
