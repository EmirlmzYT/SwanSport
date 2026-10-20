# Mobil paketler — 1.0.1+58

Kullanıcı 20 Ekim 2026'da son değişikliklerle IPA ve APK'nın GitHub'a yüklenmesini istedi. Kaynak `codex/home-quick-access`, ürün değişiklikleri `f3e71af` ve sürüm artışıdır.

- Android: mevcut yayın anahtarıyla imzalı APK; son yayımlanan APK ile sertifika eşliği kontrol edilir.
- iOS: Apple imza/config bilgileri depoda olmadığı için unsigned IPA; Sideloadly/AltStore ile kullanıcı tarafından imzalanır. Firebase native açılış koruması ve config yokluğu doğrulanır. TestFlight yüklemesi yapılmaz.
- Önceki beş iş akışının test kanıtları `club-workflows-roadmap.md` içindedir. 0134–0138 migrationları bu yayın talebi kapsamında canlıya uygulanmaz. Yeni sunucu akışları canlı backend üzerinde çalışmış sayılmaz; transfer bayrağı admins başlar.
- Üretim web dağıtımı ve başlangıçtaki iki Windows generated dosyası bu pakete dahil değişiklik değildir.

Derleme/paket kontrolü ve indirme bağlantıları tamamlanınca aşağıya kaydedilir.
