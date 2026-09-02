import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/update/update_checker.dart';

/// `isVersionNewer` — bu yanlış sonuç verirse ya kullanıcı hiç güncelleme
/// göremez (sessiz aksama) ya da her açılışta gereksiz uyarı görür.
void main() {
  group('isVersionNewer', () {
    test('daha büyük patch yeni sayılır', () {
      expect(isVersionNewer('0.1.1', '0.1.0'), isTrue);
    });

    test('aynı sürüm yeni sayılmaz', () {
      expect(isVersionNewer('0.1.0', '0.1.0'), isFalse);
    });

    test('daha küçük sürüm yeni sayılmaz', () {
      expect(isVersionNewer('0.0.9', '0.1.0'), isFalse);
    });

    test('major/minor patch\'ten önce kıyaslanır', () {
      expect(isVersionNewer('1.0.0', '0.9.9'), isTrue);
      expect(isVersionNewer('0.2.0', '0.1.9'), isTrue);
    });

    test('aynı sürüm adında yalnızca build numarası artmışsa yine yeni '
        'sayılır — hızlı düzeltme yayınlanınca haber gitsin diye', () {
      expect(isVersionNewer('0.1.0+2', '0.1.0+1'), isTrue);
    });

    test('build numarası belirtilmemişse 0 sayılır', () {
      expect(isVersionNewer('0.1.0+1', '0.1.0'), isTrue);
      expect(isVersionNewer('0.1.0', '0.1.0+1'), isFalse);
    });

    test('ayrıştırılamayan sürüm yeni sayılmaz — belirsizlikte kullanıcıyı '
        'gereksiz APK indirmeye yönlendirmemeli', () {
      expect(isVersionNewer('yanlış-format', '0.1.0'), isFalse);
      expect(isVersionNewer('0.1.0', ''), isFalse);
      expect(isVersionNewer('', ''), isFalse);
    });
  });

  group('yayınlanmış sürümler — gerçek geçişler', () {
    // Her yayından sonra buraya bir satır: yanlış bir karşılaştırma,
    // kullanıcının güncelleme bildirimini HİÇ almaması demek ve bunun
    // belirtisi yok — kimse hata görmüyor, sadece eski sürümde kalıyor.
    test('0.3.0+10 -> 0.4.0+11 yeni sayılıyor', () {
      expect(isVersionNewer('0.4.0+11', '0.3.0+10'), isTrue);
    });

    test('aynı sürüm yeni sayılmıyor', () {
      expect(isVersionNewer('0.4.0+11', '0.4.0+11'), isFalse);
    });

    test('geriye gidiş yeni sayılmıyor', () {
      expect(isVersionNewer('0.3.0+10', '0.4.0+11'), isFalse);
    });
  });
}
