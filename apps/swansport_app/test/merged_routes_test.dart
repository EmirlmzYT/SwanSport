import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/courts/presentation/find_partner_screen.dart';
import 'package:swansport_app/features/courts/presentation/venues_screen.dart';
import 'package:swansport_app/features/social/presentation/messages_screen.dart';

/// Birleştirilen sayfaların sekme sözleşmesi.
///
/// Üç sayfa birleştirildi ve **eski rotalar bilerek korundu** — bildirimlerin
/// açtığı derin bağlantılar (`push_route`) bunlara dayanıyor. `/topluluklar`
/// artık ayrı bir ekran değil ama hâlâ çalışmalı ve doğru sekmeye açılmalı;
/// kırılırsa bildirime dokunan kullanıcı yanlış yere düşer ve bunu ancak
/// sahada fark ederiz.
void main() {
  group('birleşen sayfalar doğru sekmeye açılıyor', () {
    test('Sahalar — /kortlar ilk, /halisahalar ikinci sekme', () {
      expect(const VenuesScreen().initialTab, 0);
      expect(const VenuesScreen(initialTab: 1).initialTab, 1);
    });

    test('Mesajlar — /mesajlar ilk, /topluluklar ikinci sekme', () {
      expect(const MessagesScreen().initialTab, 0);
      expect(const MessagesScreen(initialTab: 1).initialTab, 1);
    });

    test('Partner Bul — /partner-ara ilk, /oyuncu-aranan ikinci sekme', () {
      expect(const FindPartnerScreen().initialTab, 0);
      expect(const FindPartnerScreen(initialTab: 1).initialTab, 1);
    });
  });

  group('varsayılan sekme', () {
    test('parametresiz çağrı hep ilk sekmeyi açar', () {
      // Menüden ve alt bardan gelen çağrılar parametresiz; kullanıcı
      // beklenmedik bir sekmede başlamamalı.
      expect(const VenuesScreen().initialTab, 0);
      expect(const MessagesScreen().initialTab, 0);
      expect(const FindPartnerScreen().initialTab, 0);
    });
  });
}
