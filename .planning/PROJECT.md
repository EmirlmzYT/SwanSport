# SwanSport

Spor kulüpleri için yönetim platformu ve spor ağı.

## Project Overview

- **Core Ecosystem:** Flutter / Dart Monorepo (Melos) + Supabase (PostgreSQL 15)
- **Primary Apps:**
  - `apps/swansport_app`: Mobil ve web uygulaması (Android, Web).
  - `apps/swansport_console`: Masaüstü yönetim konsolu (yalnızca Web, >=900px).
- **Core Packages:**
  - `packages/swansport_data`: Supabase veri katmanı, servisler ve Riverpod sağlayıcıları.
  - `packages/swansport_branch_engine`: Branşa özel antrenman motoru (saf Dart).
  - `packages/swansport_design_system`: Tasarım jetonları (`SwanType`, `SwanPalette`) ve ortak bileşenler.
  - `packages/swansport_core`: Ortam (`AppEnvironment`) ve yapılandırma sözleşmeleri.
  - `packages/swansport_models`: Paylaşılan domain modelleri ve DTO'lar.
- **Backend:**
  - 76 numaralı, idempotent SQL migration (`supabase/migrations/`).
  - Cloudflare Pages Functions (`apps/swansport_app/functions/` - RSS ve FCM push relay).

## Critical Invariants

1. **Widget'tan doğrudan Supabase çağrılmaz:** Sorgular ve Riverpod sağlayıcıları `packages/swansport_data/lib/src/` altında düz durur.
2. **`swansport_data` arayüze bağlanmaz:** `IconData`, `Color`, widget, tema oraya girmez.
3. **Yetki hesabı tek yerde:** `SwanAccess` (`swansport_data/lib/src/access.dart`).
4. **Arayüzde gizlemek güvenlik değildir:** Her kısıt veritabanında da olmalı (RLS ya da `security definer` fonksiyon içinde yetki kontrolü).
5. **Muhasebeci gizliliği:** Muhasebeciye `athletes` tablosuna doğrudan RLS erişimi verilmez; `acc_*` RPC'leri sporcu adını seçmez, `#A3F91C` formatında token döner.
