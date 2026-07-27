import 'package:swansport_models/swansport_models.dart';
import 'package:test/test.dart';

void main() {
  test('creates an identifier value object', () {
    const id = SwanId('sample-id');

    expect(id.isEmpty, isFalse);
  });
}
