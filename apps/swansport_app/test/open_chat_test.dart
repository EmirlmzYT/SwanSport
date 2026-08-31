import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/push/push_service.dart';

/// Açık sohbet takibi — ön plan bildirimini bastırma kararı buna dayanıyor.
///
/// İkisi de sessizce yanlış davranabilir: yanlış bastırma mesajı kullanıcıdan
/// tamamen gizler, yanlış temizleme ise bastırmayı hiç çalıştırmaz.
void main() {
  setUp(() {
    OpenChat.peerId = null;
    OpenChat.peerName = null;
  });

  test('açık sohbetteki kişiden gelen bildirim bastırılır', () {
    OpenChat.open('u1', 'Emir Yılmaz');
    // 0040'taki başlık biçimi: "<Ad> size yazdı".
    expect(OpenChat.matches('Emir Yılmaz size yazdı'), isTrue);
  });

  test('başkasından gelen bildirim GÖSTERİLİR', () {
    OpenChat.open('u1', 'Emir Yılmaz');
    expect(OpenChat.matches('Ayşe Demir size yazdı'), isFalse,
        reason: 'başkası yazdığında haberin olmalı');
  });

  test('hiçbir sohbet açık değilken bastırma yok', () {
    expect(OpenChat.matches('Emir Yılmaz size yazdı'), isFalse);
  });

  test('büyük/küçük harf ve boşluk farkı bastırmayı engellemez', () {
    OpenChat.open('u1', '  emir yılmaz ');
    expect(OpenChat.matches('Emir Yılmaz size yazdı'), isTrue);
  });

  test('boş ad hiçbir şeyi bastırmaz', () {
    // Adı bilinmiyorsa temkinli davran: göstermek, yanlışlıkla gizlemekten
    // iyi — gizlenen mesajı kullanıcı hiç öğrenemez.
    OpenChat.open('u1', '   ');
    expect(OpenChat.matches('Emir Yılmaz size yazdı'), isFalse);
  });

  group('kapatma', () {
    test('kendi sohbetini kapatır', () {
      OpenChat.open('u1', 'Emir');
      OpenChat.close('u1');
      expect(OpenChat.matches('Emir size yazdı'), isFalse);
    });

    test('başka sohbetin kapanışı açık olanı düşürmez', () {
      // Kritik: iki sohbet arasında geçerken yeni ekranın initState'i
      // eskisinin dispose'undan ÖNCE çalışıyor. Kimlik kontrolü olmasaydı
      // eskinin dispose'u yeni açılan sohbeti kapalı sayardı ve bastırma
      // hiç çalışmazdı.
      OpenChat.open('u1', 'Emir');
      OpenChat.open('u2', 'Ayşe'); // yeni ekran açıldı
      OpenChat.close('u1'); // eski ekran şimdi kapanıyor

      expect(OpenChat.matches('Ayşe size yazdı'), isTrue,
          reason: 'yeni sohbet açık kalmalı');
    });
  });
}
