import 'package:swansport_core/swansport_core.dart';
import 'package:test/test.dart';

void main() {
  test('creates a success result', () {
    const result = AppSuccess<String>('ready');

    expect(result.value, 'ready');
  });
}
