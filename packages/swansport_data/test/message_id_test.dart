import 'package:test/test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('mesaj kimlikleri UUID v4 biçiminde ve benzersiz üretilir', () {
    final ids = List.generate(200, (_) => NotificationService.newMessageId());
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.every(uuidV4.hasMatch), isTrue);
  });
}
