# swansport_data

SwanSport'un Supabase veri katmanı: sorgular, satır modelleri ve Riverpod
sağlayıcıları.

## Neden ayrı paket?

Bu kod eskiden `apps/swansport_app` içinde, özellik klasörlerine dağılmıştı.
Masaüstü konsolu (`apps/swansport_console`) aynı veriyi okuyup yazacağı için
buraya çıkarıldı — aksi halde her sorgu iki uygulamada ayrı ayrı yaşar,
zamanla birbirinden ayrılırdı.

## Kural: burada arayüz yok

`IconData`, `Color`, widget, tema — hiçbiri bu pakete girmez. Paket yalnızca
`flutter_riverpod` ve `supabase_flutter` kullanır (`Provider` tipleri için
Flutter'a bağlıdır, çizim için değil).

Bir sabit hem veriyi hem görünümü taşıyorsa, görünüm kısmı tüketen uygulamanın
`presentation/` klasörüne gider. Örnek: test kategorilerinin anahtarları burada,
ikon ve renkleri
`apps/swansport_app/lib/features/performance_analytics/presentation/test_categories.dart`
içinde.

## Yapı

Tek düzey `lib/src/`, barrel `lib/swansport_data.dart` üzerinden dışa açılır.
Tüketiciler tek satır yazar:

```dart
import 'package:swansport_data/swansport_data.dart';
```

Dosyalar düz durduğu için aynı ismi iki dosyada tanımlamak derleme hatası verir
(`ambiguous_export`). Bu bilinçli: taşıma sırasında `InjuryRow`,
`injuriesProvider` ve `attendanceSummaryProvider` üç ayrı çift halinde
kopyalanmış çıktı — ayrı ayrı import edildikleri için yıllarca görünmemişlerdi.
Barrel bu tür kopyaları derleme anında yakalar.

## Güvenlik

Sorgular RLS'in üstünde çalışır; yetki kontrolü veritabanındadır. Bu pakette
"yönetici atlaması" yoktur ve service-role anahtarı asla kullanılmaz.
