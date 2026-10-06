# Phase 3: Comprehensive Design Polish & Fluidity - Research & Architecture

**Completed:** 2026-10-05
**Author:** SwanSport Orchestrator & Design Specialists
**Target:** Codex Writer (Implementation) & AGY Reviewer (Verification)

---

## 1. Executive Summary & Goals

Kullanicinin dogrudan talebi:
- " tasarimi komple bi eline al bu sekilde de cok kotu duruyor uygulama guzel dursun- \codex uygulamanin tasarim kismini halledecek ona guzel bi plan verelim tum sayfalarin ve ayriyeten uygulamanin daha akici gorunmesine yardimci olmasi gerekiyor
Bu fazin amaci: pps/swansport_app icindeki tum ana ve alt ekranlari yuksek standartta, modern sosyal spor platformu (Instagram/Strava/Apple Fitness kalitesinde) estetigine kavusturmak ve uygulamanin kaydirma, yukleme ve gecis deneyimini en ust seviyede akici hale getirmektir.

Tum planlar ve gorevler Codex Writer icin acik, dosya hedefleri net, degismezleri koruyan ve otomatik testlerle dogrulanabilir sekilde tasarlanmistir.

---

## 2. Invariants & Guardrails (AGENTS.md Strict Contracts)

Codex Writer asla cigsememesi gereken mimari sinirlar:
1. Konsol Ayrimi: pps/swansport_console ve packages/swansport_design_system paketlerine asla dokunulmaz.
2. Dogrudan Veritabani Cagrisi Yok: Widget'lardan Supabase istemcisine dogrudan cagri yapilmaz.
3. Alt Gezinme Cubugu (SwanBottomNav): 5 elemanli sabit yapi korunur.
4. Birlesen Rotalar ve Derin Baglantilar: /kortlar, /halisahalar, /topluluklar, /oyuncu-aranan rotalari korunur.
5. Kaydedilmemis Durum Kaybi: live_attendance_screen.dart icindeki _marks yoklama durumu korunur.
6. Koyu Tema Kurali: Saf siyah (#000000) yasaktir. Navy/charcoal (SwanPalette.dark) kullanilir.
7. Tipografi 7 Adim: Ham ontSize yasaktir; SwanType adimlari kullanilir.

---

## 3. Fluidity & Perceived Performance Architecture

1. Shimmer Skeleton Yukleme (Zero Layout Shift):
 - CircularProgressIndicator yerine SwanListSkeleton, SwanCardSkeleton ve premiumLoading() kullanilir.
2. Elastik Kaydirma Fizigi (BouncingScrollPhysics):
 - swansport_app.dart icinde MaterialApp seviyesinde global BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()) tanimlanir.
3. Dokunsal Geri Bildirim ve Mikro-Animasyonlar:
 - Tiklanabilir kartlar: Material + InkWell ve 14px SwanRadius.md.
 - PostCard kalp pop animasyonu.
4. Modal Sheet ve Pinned Header Akiciligi:
 - Pinned baslik ve 24px yuvarlatilmis modal sheet'ler.

---

## 4. Verification & Automated Test Gates

Tum degisikliklerden sonra su testler gecmelidir:
- lutter test apps/swansport_app/test/widgets/swan_top_bar_test.dart
- lutter test apps/swansport_app/test/widgets/inbox_actions_test.dart
- lutter test apps/swansport_app/test/navigation_test.dart
- lutter test apps/swansport_app/test/merged_routes_test.dart
- lutter test apps/swansport_app/test/athlete_detail_navigation_test.dart
- lutter test apps/swansport_app/test/athlete_detail_screen_test.dart
- lutter analyze apps/swansport_app

## RESEARCH COMPLETE
