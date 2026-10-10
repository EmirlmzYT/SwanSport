# Branş müsabaka motoru — yerel doğrulama

2026-10-10. Basketbol, futbol, tenis, yüzme ve kulvarlı atletizm müsabaka
modelleri `swansport_branch_engine` saf Dart paketine eklendi.

`BranchDefinitionContract` değişmedi. Okçuluk tanımı, antrenman skor kuralları
ve aşama makinesi korunur. Branş kayıt listesi genişletildi; mevcut iki test
dosyasında yalnız stil/virgül düzenlemesi vardır. Runtime bağımlılığı eklenmedi;
pakette Flutter veya Supabase import'u bulunmadığı otomatik kontrol edildi.

`validateMatchProtocol` tipli, değişmez sonuç modeli veya alan yolunu belirten
`ProtocolValidationException` verir. Eksik skor sıfıra dönüşmez; yanlış JSON
tipleri, negatif/kesirli sayılar, NaN/Infinity, güvenli JSON tamsayı sınırı ve
toplam taşması kontrol edilir. Bilinmeyen branş varsayılan protokole düşmez.

Basketbol çeyrek/uzatma ve takım/oyuncu istatistiklerini; futbol devre/uzatma,
ayrı seri penaltıları ve gol/kart olaylarını; tenis 3/5 set, standart oyun ve
7/10 puan hedefli tie-break'i; yüzme/atletizm kulvar, seri, derece, rank ve DQ/DNF
kayıtlarını doğrular. Desteklenen JSON, örnekler, resmi kaynaklar ve format
sınırları `packages/swansport_branch_engine/lib/protocols/README.md` içindedir.

Entegrasyon incelemesinde mevcut `ScorePad`'in her branşı okçuluğa zorla cast
ettiği görüldü. Kayıt listesi genişleyince oluşabilecek TypeError, tür eşleşmesi
ile giderildi. Yeni branşlar mevcut genel etiketini, okçuluk kendi etiketini
korur. Bu gerekli uyumluluk düzeltmesi dışında uygulama ürün akışı değişmedi.

## Test kanıtı

Loglar ignored `build/identity-phase-c1/branch-*.log` altındadır.

| Kontrol | Sonuç | Log |
|---|---|---|
| Paket kökünde `dart test` | 131/131, sıfır hata | branch-tests-final.log |
| `dart test --platform chrome` | 130/130, sıfır hata | branch-web-tests-final.log |
| Paket `dart analyze` | 0 bulgu, çıkış 0 | branch-analyze-final.log |
| ScorePad altı branş Flutter regresyonu | 6/6 | branch-score-pad-tests-final.log |
| Veri katmanı `training_session_test.dart` | 28/28 | branch-training-regression.log |
| Değişen uygulama kaynağı/yeni test analizi | 0 hata/uyarı, mevcut kaynakta 7 trailing-comma info | branch-app-analyze.log |
| `git diff --check` | Temiz | Yerel komut çıktısı |

Dosya sistemini inceleyen paket saflığı testi yalnız VM'de çalışır; bu nedenle
Chrome toplamı bir eksiktir. Skor/şema/sınır testlerinin tamamı iki platformda
çalıştı. Yanlış iç içe JSON, skor sonrası fazladan set/penaltı, erken penaltı
sonucu ve ani ölüm, canlı/bitmiş durum, 7-7 hatası, eşit yüzme derecesi,
atletizm foto-finiş sırası, bağımsız seriler ve değişmez model testleri vardır.

Kod grafiğinin mevcut kaydı eski/yeni dosyalarda eksikti; gerekli kaynaklar
doğrudan okundu. Sonuçlar güncel kaynak ve çalıştırılmış testlere dayanır.

## Sınırlar

Bu modeller federasyon görev/kimlik/lisans yetkisi vermez. Mevcut Supabase
resmi sonuç allowlist/RPC şeması değiştirilmedi; zengin modelin sunucuya
bağlanması ayrıca alan dönüşümü ve yetki kontrolü gerektirir. Sporcu referansları
public sonuçlara doğrudan taşınmamalıdır. Yeni ekran, SQL migration, canlı SQL,
push veya deploy yapılmadı. Atletizm atma/atlama, otomatik resmi zaman yuvarlama,
rekor/foto-finiş kararı ve tüm alternatif tenis formatları uygulanmış sayılmaz.
