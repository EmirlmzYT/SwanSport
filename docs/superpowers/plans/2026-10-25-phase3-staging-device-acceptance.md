# Aşama 3 uygulama planı

1. Canlı Supabase varsayılanlarını kaldır; regresyon testleriyle eksik ayarın
   fixture modunda kaldığını ve release workflow'larının secret zorunlu tuttuğunu
   doğrula.
2. Canlı proje kimliğini reddeden staging hedef doğrulayıcısını test güdümlü
   ekle.
3. Elle çalışan, GitHub `staging` environment kullanan migration dry-run/apply,
   Android staging APK ve iOS unsigned staging preview iş akışını ekle.
4. Android/iOS fiziksel cihaz kabul şablonunu ve rapor doğrulayıcısını ekle.
5. Dar ve tam ilgili testleri çalıştır, GitHub staging environment kaydını
   oluştur, commit ve dalı push et. Gerçek hesap/cihaz gerektirenleri kullanıcıya
   devret.
