import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ProEnvironmentType {
  development,
  production,
}

class ProEnvironmentException implements Exception {
  const ProEnvironmentException(this.message);

  final String message;

  @override
  String toString() => 'ProEnvironmentException: $message';
}

class ProEnvironment {
  const ProEnvironment({
    required this.type,
    required this.appName,
    required this.enableDebugTools,
  });

  const ProEnvironment.development({
    this.appName = 'SwanSport Pro',
    this.enableDebugTools = true,
  }) : type = ProEnvironmentType.development;

  const ProEnvironment.production({
    this.appName = 'SwanSport Pro',
    this.enableDebugTools = false,
  }) : type = ProEnvironmentType.production;

  final ProEnvironmentType type;
  final String appName;
  final bool enableDebugTools;

  bool get isDevelopment => type == ProEnvironmentType.development;
  bool get isProduction => type == ProEnvironmentType.production;

  static ProEnvironment fromCompileTime({
    String environmentName = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    String appName = const String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'SwanSport Pro',
    ),
    String enableDebugTools = const String.fromEnvironment(
      'ENABLE_DEBUG_TOOLS',
      defaultValue: '',
    ),
  }) {
    final type = switch (environmentName.toLowerCase()) {
      'production' || 'prod' => ProEnvironmentType.production,
      _ => ProEnvironmentType.development,
    };

    final debugEnabled = switch (enableDebugTools.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => type == ProEnvironmentType.development,
    };

    return ProEnvironment(
      type: type,
      appName: appName,
      enableDebugTools: debugEnabled,
    );
  }
}

final proEnvironmentProvider =
    Provider<ProEnvironment>((ref) => const ProEnvironment.production());
