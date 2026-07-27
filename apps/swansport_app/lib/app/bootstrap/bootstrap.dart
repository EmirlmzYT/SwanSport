import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../swansport_app.dart';

void bootstrap(AppEnvironment environment) {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: <Override>[
        appEnvironmentProvider.overrideWithValue(environment),
      ],
      child: const SwanSportApp(),
    ),
  );
}
