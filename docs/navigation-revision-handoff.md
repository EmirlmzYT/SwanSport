# SwanSport gezinme revizyonu — Faz 6 devir notu

## Durum

Faz 0–5 uygulandı. Development ortamı `go_router` +
`StatefulShellRoute.indexedStack` + `SwanAppShell` kullanıyor. Production ve
yerel Test Merkezi, cihaz ve deep-link UAT tamamlanana kadar eski Navigator 1
girişinde tutuluyor.

Tamamlanan ana davranışlar:

- Dört sabit branch: `/akis`, `/kesfet`, `/mesajlar`, `/profil`.
- Branch yığınları korunuyor; aktif sekmeye yeniden basmak branch köküne dönüyor.
- Eski named route çağrıları `LegacyNavigationBridge` içinde çalışmaya devam ediyor.
- Web, `app_links`, QR ve push hedefleri ortak `RouteLinkAdapter` hattından geçiyor.
- Yinelenen URI iki saniyelik pencere içinde ikinci kez açılmıyor.
- Swan ID tokenı, maç UUID'si ve profil/kulüp parametreleri doğrulanıyor.
- `/topluluklar`, `/halisahalar` ve `/oyuncu-aranan` eski bağlantıları korunuyor.
- `/hesap` genel ayar; `/settings` aktif kulüp personelinin kulüp ayarıdır.
- Kulüp Merkezi yalnız aktif üyelik kapsamıyla açılır. Antrenör belgesi tek başına
  merkezi açmaz (`SwanAccess.hasActiveClubStaffMembership`).
- Dış muhasebeci yalnız maskeli `/muhasebeci-defter` merkezine girer.
- Saha ve federasyon merkezleri gerçek `SwanAccess` kapsamlarıyla gösterilir.
- Keşfet kamusal bulma akışlarıyla sınırlandı.
- Oluştur menüsündeki çalışmayan antrenman hedefi ve sabit sahte taslak kartı kaldırıldı.
- Swan Asistan Mesajlar'da özellik bayraklı sabit konuşmadır.

## Faz 6 — kalan görevler

1. `Navigator.pushNamed`, `pushReplacementNamed` ve `popUntil` envanterini çıkar.
   Dış sözleşmesi olmayan çağrıları branch bağlamını koruyan ortak gezinme yardımcısına
   geçir. Bildirim, QR ve eski dış bağlantı rotalarını silme.
2. `SystemNavigator.routeInformationUpdated` veya elle web URL'si değiştiren kalan
   kodları ara. URL'nin tek sahibi GoRouter olmalı.
3. `app_routes.dart` içine hâlâ dağınık kullanılan sabit yolları taşı. Dinamik rota
   üreticilerini burada tut; widget içinde URL birleştirme bırakma.
4. `swan_destination.dart` oluştur. Başlık, ait olduğu branch, shell görünürlüğü ve
   özellik bayrağı metadata'sını taşısın. Güvenlik hesabı burada yapılmasın.
5. Onboarding, kimlik doğrulama, QR doğrulama, ödeme, tam ekran medya, canlı maç
   operasyonu ve hakem raporu gibi ekranlarda shell chrome görünürlüğünü metadata ile
   yönet. Aynı hedef için yerel alt bar kopyası üretme.
6. `navigation_test.dart` kaynak dizesi sayımlarını mümkün oldukça gerçek route matrisi
   ve widget navigation testlerine dönüştür. Legacy dış sözleşme testlerini koru.
7. Android sistem geri tuşu, web geri/ileri, initial link ve runtime link senaryolarını
   widget/integration seviyesinde sabitle.
8. Production router geçişini yalnız web + Android deep-link UAT tamamlanınca yap.
   `main_test_center.dart` ayrı kalmalı.
9. Son durumda `AGENTS.md` gezinme bölümünü ve genel doğrulama raporunu güncelle.

## Korunacak sözleşmeler

- Widget doğrudan Supabase çağırmaz.
- Yetki hesabı `packages/swansport_data/lib/src/access.dart` içindeki `SwanAccess`
  üzerinden yapılır; özellik bayrağı güvenlik değildir.
- Muhasebeciye sporcu adı/kadro açılmaz; `acc_*` ve `athlete_ref` gizliliği korunur.
- `athletes.profile_id` nullable kalır.
- Beş noktalı özellik bayrağı sözleşmesi korunur.
- `/topluluklar`, `/halisahalar`, `/oyuncu-aranan` ve push hedefleri silinmez.
- İlgisiz ve önceden var olan `apps/swansport_console` değişikliklerine dokunulmaz.
- Canlı migration veya yayın yapılmaz.

## İlgili yeni dosyalar

- `apps/swansport_app/lib/app/navigation/app_router.dart`
- `apps/swansport_app/lib/app/navigation/app_routes.dart`
- `apps/swansport_app/lib/app/navigation/route_link_adapter.dart`
- `apps/swansport_app/lib/app/navigation/legacy_navigation_bridge.dart`
- `apps/swansport_app/lib/app/navigation/legacy_route_registry.dart`
- `apps/swansport_app/lib/app/navigation/shell_navigation_scope.dart`
- `apps/swansport_app/lib/app/widgets/app_shell.dart`

## Son doğrulama

- Ortak erişim/yetki testleri: 42 geçti.
- Router, deep-link, legacy ve misafir erişim paketi: 47 geçti.
- Faz 5 navigation paketi: 27 geçti.
- Özellik bayrağı/Swan deneyimi sözleşmeleri: 7 geçti.
- `flutter build web -t lib/main_development.dart`: geçti.
- Analyze çıktısında yeni error veya warning yok; depodaki mevcut `info` biçim
  notları devam ediyor.

## Başlangıç komutları

```powershell
cd C:\Users\anado\OneDrive\Documents\ChatGPT\swansport
git status --short
rg -n "Navigator\.(pushNamed|pushReplacementNamed|popUntil)|SystemNavigator\.routeInformationUpdated" apps/swansport_app/lib -g "*.dart"
cd apps\swansport_app
flutter test test\route_link_adapter_test.dart test\app_router_test.dart test\legacy_navigation_bridge_test.dart test\legacy_route_registry_test.dart test\navigation_test.dart test\merged_routes_test.dart test\guest_identity_gate_test.dart
flutter build web -t lib\main_development.dart
```

Local development URL: `http://127.0.0.1:8080/`.
