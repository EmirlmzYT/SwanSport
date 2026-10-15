import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('test backend is exactly the dedicated loopback URL', () {
    expect(isLocalTestBackend('http://127.0.0.1:55421'), isTrue);
    for (final url in [
      'https://api.swansport.com.tr', 'https://x.supabase.co',
      'http://localhost:55421', 'http://127.0.0.1:54321',
      'http://127.0.0.1:55421@evil.example', 'http://127.0.0.1:55421?remote=true',
      'http://127.0.0.1:55421/rest/v1',
    ]) {
      expect(isLocalTestBackend(url), isFalse, reason: url);
    }
  });
  test('five personas have distinct local fixture emails', () {
    expect(LocalTestPersona.values.length, 5);
    expect(LocalTestPersona.values.map((p) => p.email).toSet().length, 5);
    expect(LocalTestPersona.coach.email, 'antrenor-3@test.swansport.invalid');
  });
}
