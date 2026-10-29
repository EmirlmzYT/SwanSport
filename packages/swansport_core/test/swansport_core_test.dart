import 'package:swansport_core/swansport_core.dart';
import 'package:test/test.dart';

void main() {
  test('creates a success result', () {
    const result = AppSuccess<String>('ready');

    expect(result.value, 'ready');
  });

  test('missing compile-time Supabase settings stay in fixture mode', () {
    final config = SupabaseConfig.fromCompileTime();

    expect(config.url, isEmpty);
    expect(config.anonKey, isEmpty);
    expect(config.isConfigured, isFalse);
  });
}
