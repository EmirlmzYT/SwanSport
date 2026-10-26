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
    final normalizedEnvironment = environmentName.trim().toLowerCase();
    final normalizedAppName = appName.trim();

    if (normalizedAppName.isEmpty) {
      throw const ProEnvironmentException('APP_NAME cannot be empty.');
    }

    final type = switch (normalizedEnvironment) {
      'development' || 'dev' => ProEnvironmentType.development,
      'production' || 'prod' => ProEnvironmentType.production,
      _ => throw const ProEnvironmentException(
          'APP_ENV must be either development or production.',
        ),
    };

    final normalizedDebugTools = enableDebugTools.trim().toLowerCase();
    final debugEnabled = switch (normalizedDebugTools) {
      '' => type == ProEnvironmentType.development,
      'true' => true,
      'false' => false,
      _ => throw const ProEnvironmentException(
          'ENABLE_DEBUG_TOOLS must be true or false.',
        ),
    };

    return ProEnvironment(
      type: type,
      appName: normalizedAppName,
      enableDebugTools: debugEnabled,
    );
  }
}

final proEnvironmentProvider =
    Provider<ProEnvironment>((ref) => const ProEnvironment.production());
