/// Compile-time Supabase connection settings.
///
/// Values are supplied with `--dart-define` so that no secrets are committed
/// to source control. The `anon` key is safe to embed in the client build;
/// data protection is enforced server-side through Row Level Security.
///
/// When [isConfigured] is false the application stays in fixture mode and no
/// network calls are made. This keeps the app runnable without a backend.
class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
  });

  /// Reads the configuration from compile-time defines.
  ///
  /// ```
  /// flutter run \
  ///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  ///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
  /// ```
  factory SupabaseConfig.fromCompileTime({
    String url = const String.fromEnvironment('SUPABASE_URL'),
    String anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
  }) {
    return SupabaseConfig(
      url: url.trim(),
      anonKey: anonKey.trim(),
    );
  }

  /// An empty configuration, meaning fixture mode.
  static const SupabaseConfig empty = SupabaseConfig(url: '', anonKey: '');

  final String url;
  final String anonKey;

  /// Whether a live Supabase backend should be used.
  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
