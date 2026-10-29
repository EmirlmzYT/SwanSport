# SwanSport 1.0.4 mobil kabul listesi

`python tools/mobile_release_acceptance.py` çevrimdışı sözleşme kontrolüdür.
Paket yüklenmeden önce aşağıdaki gerçek cihaz akışları ayrıca tamamlanır:

- Başka telefondan Swan ID QR'ını okut; “Uygulamada aç” seçeneğinin kurulu
  uygulamayı ve doğru doğrulama kartını açtığını doğrula.
- Uygulama kurulu değilken aynı bağlantının “Web'de devam et” ile minimum
  alanlı doğrulama ekranına geçtiğini doğrula.
- Profilde Swan ID, doğrulama, belgeler, aidatlar ve antrenman kısayollarını
  dar ekranlı bir Android cihazda ve iPhone'da aç.
- Swan Asistan'da role ve açık bayraklara uygun hazır soruların göründüğünü;
  bilinmeyen sorunun yanıt uydurmayıp Yardım Merkezi'ni sunduğunu doğrula.
- Bir doğrudan mesaj gönder; mesaj rozetinin bir arttığını, zil rozetinin aynı
  mesaj için artmadığını ve sohbet okununca mesaj rozetinin temizlendiğini doğrula.
- Uçak modunda Profil, Swan ID, Bildirimler ve Asistan hata durumlarının teknik
  hata kodu göstermediğini ve “Tekrar Dene” eyleminin çalıştığını doğrula.
- Android release APK ve iOS IPA üzerinde soğuk açılış, oturum yenileme, geri
  tuşu, QR deep link ve video oynatmayı gerçek cihazda dene.

Bu liste fiziksel cihaz kanıtıdır; widget testi veya başarılı derleme onun yerine
geçmez. Canlı migration ve mağaza/TestFlight yayını ayrı işlemdir.
