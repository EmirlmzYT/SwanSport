# Resmi kuğu varlıkları — v0.5.5+27

Kaynak `assets/branding/official_swan_logo.jpg`: 873×873 RGB kullanıcı görseli.
Tekrar üretim: `python tools/generate_launcher_icons.py`.
Boyut/piksel/format kontrolü: `python tools/generate_launcher_icons.py --check`.

32 RGB PNG: 5 Android mipmap, 15 benzersiz iOS AppIcon, 6 mobil web,
5 konsol web ve 1 design-system asset. iOS Contents.json'daki 19 kayıt
15 dosya kullanır; plan metnindeki "16 ikon" ifadesi yerine gerçek sözleşme
izlenir. LANCZOS yeniden örnekleme kullanılır; 1024 ikon kaynak 873'ten
büyütülür, kaynaktan fazla ayrıntı üretildiği iddia edilmez.

Maskable ikonlar tüm resmi görseli merkezdeki güvenli daire içinde tutar;
diğer ikonlar özgün kare görünümü korur. Apple touch icon bağlantıları
mevcutta doğru 180/192 dosyalarına bağlı olduğundan HTML/manifest değişmedi.

SwanNetworkLogo eksik URL/yükleme hatasında paket içi 512 PNG'yi gösterir.
Paket asset kaydı ve test beklentileri güncellendi; asset yüklemesi de
başarısız olursa son güvenlik fallback'i korunur. Mission Control logosu
uygulama içi görünümü değiştirir; native launcher ikonunu değiştirmek yeni
APK/IPA kurulumu gerektirir.

Yerel doğrulama: generator 32/32, SSS 39/39, push 40 kayıpsız, SQL 5/5,
diff temiz. Flutter SDK olmadığından widget test/build, cihaz launcher/iOS
kurulumu ve PWA cache yenilenmesi doğrulanmadı. Tag push üç mevcut GitHub
Actions Android/iOS/console release iş akışını tetikler; yayın başarısı
iş akışları tamamlanmadan varsayılmaz. iOS paket iş akışı imzasız IPA üretir.
