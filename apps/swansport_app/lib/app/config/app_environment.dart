import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironmentType {
  development,
  production,
}

class AppEnvironmentException implements Exception {
  const AppEnvironmentException(this.message);

  final String message;

  @override
  String toString() => 'AppEnvironmentException: $message';
}

class AppEnvironment {
  const AppEnvironment({
    required this.type,
    required this.label,
    required this.appName,
    required this.enableDebugTools,
  });

  const AppEnvironment.development()
      : type = AppEnvironmentType.development,
        label = 'Development environment',
        appName = 'SwanSport',
        enableDebugTools = true;

  const AppEnvironment.production()
      : type = AppEnvironmentType.production,
        label = 'Production environment',
        appName = 'SwanSport',
        enableDebugTools = false;

  final AppEnvironmentType type;
  final String label;
  final String appName;
  final bool enableDebugTools;

  bool get isDevelopment => type == AppEnvironmentType.development;

  bool get isProduction => type == AppEnvironmentType.production;

  static AppEnvironment fromCompileTime({
    String environmentName = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    String appName = const String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'SwanSport',
    ),
    String enableDebugTools = const String.fromEnvironment(
      'ENABLE_DEBUG_TOOLS',
      defaultValue: '',
    ),
  }) {
    final parsedType = _parseType(environmentName);
    final normalizedAppName = appName.trim();

    if (normalizedAppName.isEmpty) {
      throw const AppEnvironmentException('APP_NAME cannot be empty.');
    }

    final parsedDebugTools = _parseOptionalBool(
      key: 'ENABLE_DEBUG_TOOLS',
      value: enableDebugTools,
    );

    final shouldEnableDebugTools =
        parsedDebugTools ?? parsedType == AppEnvironmentType.development;

    return AppEnvironment(
      type: parsedType,
      label: switch (parsedType) {
        AppEnvironmentType.development => 'Development environment',
        AppEnvironmentType.production => 'Production environment',
      },
      appName: normalizedAppName,
      enableDebugTools: shouldEnableDebugTools,
    );
  }

  static AppEnvironmentType _parseType(String value) {
    final normalized = value.trim().toLowerCase();

    return switch (normalized) {
      'development' || 'dev' => AppEnvironmentType.development,
      'production' || 'prod' => AppEnvironmentType.production,
      _ => throw const AppEnvironmentException(
          'APP_ENV must be either development or production.',
        ),
    };
  }

  static bool? _parseOptionalBool({
    required String key,
    required String value,
  }) {
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty) {
      return null;
    }

    return switch (normalized) {
      'true' => true,
      'false' => false,
      _ => throw AppEnvironmentException('$key must be true or false.'),
    };
  }
}

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => const AppEnvironment.development(),
);
