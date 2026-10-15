import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/config/app_environment.dart';
import '../../app/app_navigator.dart';
import '../../app/swansport_app.dart';
import 'test_center_screen.dart';

/// Fresh, unparented provider container per account, including failed logins.
/// An accountant must not inherit the previous coach's cached roster/offline state.
class LocalTestCenterRoot extends StatefulWidget {
  const LocalTestCenterRoot({required this.environment, required this.config, super.key});
  final AppEnvironment environment;
  final SupabaseConfig config;
  @override
  State<LocalTestCenterRoot> createState() => _LocalTestCenterRootState();
}

class _LocalTestCenterRootState extends State<LocalTestCenterRoot> {
  int _revision = 0;
  String _route = testCenterRoute;
  String? _error;
  void _restart(String route, String? error) {
    if (!mounted) return;
    setState(() { _revision++; _route = route; _error = error; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) swanNavigatorKey.currentState?.pushNamedAndRemoveUntil(route, (_) => false);
    });
  }
  @override
  Widget build(BuildContext context) => ProviderScope(
    key: ValueKey(_revision),
    overrides: [
      appEnvironmentProvider.overrideWithValue(widget.environment),
      supabaseConfigProvider.overrideWithValue(widget.config),
      localTestCenterRequestedProvider.overrideWithValue(true),
      localTestRestartProvider.overrideWithValue(_restart),
      localTestInitialRouteProvider.overrideWithValue(_route),
      localTestErrorProvider.overrideWithValue(_error),
    ],
    child: const SwanSportApp(),
  );
}
