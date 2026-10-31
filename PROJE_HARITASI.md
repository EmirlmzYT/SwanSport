# SwanSport Proje Haritası

Bu harita yalnızca klasör/dosya adları ile README ve `pubspec.yaml` başlıklarından oluşturulmuştur.

## Kök

- `apps/`: Uygulanabilir Flutter istemcilerini barındırır.
- `packages/`: İstemciler arasında paylaşılan Dart paketlerini barındırır.
- `supabase/`: PostgreSQL/Supabase şeması, güvenlik ve backend destek materyallerini barındırır.
- `docs/`: Mimari, karar, ürün, güvenlik ve tasarım belgelerini barındırır.
- `tools/`: Yerel doğrulama araçları ve test altyapısını barındırır.
- Kod: İstemci kodu `apps/*/lib/`, ortak kod `packages/*/lib/`, Edge Function kodu `supabase/functions/` altındadır.
- Migration'lar: `supabase/migrations/` altındadır.
- Testler: `apps/*/test/`, `packages/*/test/` ve `supabase/tests/` altındadır.

## Uygulamalar

- `apps/swansport_app/`: Android/web Flutter MVP istemcisi; platform klasörleri, `lib/`, `test/`, `web/` ve Pages Functions içerir.
- `apps/swansport_console/`: Web tabanlı masaüstü yönetim konsolu; `lib/`, `test/` ve `web/` içerir.
- `apps/swansport_pro/`: Profesyonel operasyon Flutter istemcisi; platform klasörleri, `lib/`, `test/` ve `web/` içerir.

## Paylaşılan paketler

- `packages/swansport_branch_engine/`: Spor dalı motoru sözleşmeleri, şemaları, skorlaması ve protokolleri.
- `packages/swansport_core/`: Paylaşılan temel yardımcılar, yapılandırma, hata, sonuç ve loglama.
- `packages/swansport_data/`: Supabase veri katmanı; arayüz kodu içermez.
- `packages/swansport_design_system/`: Material 3 tabanlı tasarım sistemi, bileşenler, temalar ve varlıklar.
- `packages/swansport_models/`: Paylaşılan Dart modelleri, değer tipleri, enumlar ve sayfalama.
- `packages/swansport_pro_features/`: SwanSport ve Pro için ortak profesyonel operasyon arayüzleri.

## `swansport_data/lib/src` servis grupları

- Erişim/altyapı: `access.dart`, `supabase_scope.dart`, `operation_error.dart`, `feature_flags.dart`, `diagnostics*.dart`, `local_test_accounts.dart`.
- Kulüp: `club_*.dart`, `club_data.dart`, `club_dashboard.dart`, `club_staff_operations.dart`, `club_ops_service.dart`.
- Finans/gider: `expense_service.dart`, `finance_service.dart`, `finance_ops_service.dart`, `money.dart`.
- Antrenman/performans: `training_cockpit.dart`, `training_session_service.dart`, `performance_service.dart`, `development_report.dart`.
- Sporcu/veli/koç: `athlete_profile_service.dart`, `supabase_athletes.dart`, `parent_actions.dart`, `coach_guardian_results.dart`.
- Sosyal/topluluk: `social_service.dart`, `social_share_service.dart`, `community_service.dart`, `news_service.dart`.
- Bildirim/doğrulama: `notification_service.dart`, `push_target.dart`, `verification_service.dart`, `vault_service.dart`.
- Tesis/operasyon: `court_service.dart`, `turf_service.dart`, `saha_operations.dart`, `equipment_service.dart`, `marketplace_service.dart`.
- Takvim/katılım: `unified_calendar.dart`, `offline_attendance.dart`, `offline/attendance_database_*.dart`, `season_setup.dart`.
- Maç/lig: `live_match_*.dart`, `match_following_*.dart`, `league_standings_*.dart`, `referee_cockpit.dart`.
- Federasyon: `federation_*.dart`.
- Spor bağlamı/roller: `sport_context_service.dart`, `sports_catalog.dart`, `sports_roles_*.dart`, `public_program_service.dart`.
- Yönetim/platform: `admin_service.dart`, `moderation_service.dart`, `network_service.dart`, `platform_mission_control.dart`, `swan_experience.dart`.
- Sağlık/beslenme: `nutrition_service.dart`.

## Supabase

- `supabase/functions/`: Supabase Edge Functions.
- `supabase/migrations/`: Sıralı veritabanı şeması ve RLS değişiklikleri.
- `supabase/policies/`: Yetkilendirme/RLS politika belgeleri ve destek dosyaları.
- `supabase/seed/`: Demo veya başlangıç veri materyalleri.
- `supabase/tests/`: Backend/veritabanı testleri.

## Belgeler ve araçlar

- `docs/architecture/`: Mimari belgeler.
- `docs/decisions/`: Architecture Decision Record (ADR) belgeleri.
- `docs/product/`: Ürün belgeleri.
- `docs/security/`: Güvenlik belgeleri.
- `docs/superpowers/`: Plan, prompt ve specification çalışma materyalleri.
- `tools/local-test-center/`: Yerel test merkezi ve Supabase destek yapısı.

## Varsayılan olarak okunmaması gerekenler

- `build/`, `**/build/`: Yeniden üretilebilir derleme ve test çıktıları.
- `.dart_tool/`, `**/.dart_tool/`: Dart/Flutter araç önbellekleri.
- `tools/node_modules/`, `.venv/`, `**/__pycache__/`: Yeniden kurulabilir bağımlılık ve çalışma önbellekleri.
- `supabase/legacy/`: Eski Supabase materyalleri; güncel kaynak olarak kullanılmamalı.
- `docs/design/`: Tasarım referansları; görev özellikle gerektirmedikçe bağlam tüketmemeli.
- `.ai-team/`, `.agent/`, `.agents/`, `.claude/`, `.superpowers/`, `.planning/`, `.serena/`: Yerel ekip/ajan süreç bağlamı; gerekmedikçe okunmamalı.
