import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_core/swansport_core.dart';

/// Holds the active [SupabaseConfig].
///
/// Defaults to [SupabaseConfig.empty] (fixture mode). [bootstrap] overrides it
/// with the compile-time values when the app starts.
final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => SupabaseConfig.empty,
);

/// Whether the app is running against a live Supabase backend.
///
/// Feature providers watch this to decide between a fixture repository and a
/// Supabase-backed repository, so the whole app flips with a single switch.
final isSupabaseEnabledProvider = Provider<bool>(
  (ref) => ref.watch(supabaseConfigProvider).isConfigured,
);

/// The initialized Supabase client.
///
/// Only valid when [isSupabaseEnabledProvider] is true — reading it in fixture
/// mode throws, which is intentional: live repositories must never be built
/// without a configured backend.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) {
    if (!ref.watch(isSupabaseEnabledProvider)) {
      throw StateError(
        'Supabase client requested while running in fixture mode. '
        'Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
      );
    }
    return Supabase.instance.client;
  },
);
