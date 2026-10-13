# SwanSport — Faz 5: Kulüp İçi İhtisas Rolleri & Modüller Codex Uygulama Şartnamesi

**Tarih:** 2026-10-13
**Kapsam:** Kulüp içi ihtisas kadrolarının (Kulüp Başkanı, Doktor/Fizyoterapist, Malzeme Sorumlusu, Sportif Direktör) günlük operasyonel modüllerinin kurulması.

---

## 1. Mimari Prensipler ve Değişmezler (Invariants)

1. **Doktor Esnekliği Kuralı (Kesin Sözleşme):**
   - Kulüpte kadrolu sağlık görevlisi bulunması **zorunlu değildir**.
   - Doktorsuz kulüplerde antrenör veya kulüp yöneticisi sporcuyu esame ve antrenmanda idari dinlendirme (`injured_admin` / `rested`) yapabilir; sistem asla kilitlenmez.
   - Kulüpte yetkili sağlık görevlisi (`is_authorized_health_officer`) varsa tıbbi kısıt (`injured_medical` / `health_restrictions`) devreye girer. Antrenör veya kulüp başkanı bu kilidi tek taraflı kaldıramaz.
   - `health_restrictions` tablosunda teşhis, rapor metni ve özel doktor notu **tutulmaz** (AGENTS.md gizlilik kuralı). Yalnızca durum, tarihler ve belge referansı yer alır.
2. **Muhasebeci Gizliliği (`#A3F91C`):**
   - Muhasebeci kulübün defterini görür ama sporcuları asla göremez. Zimmet veya malzeme kayıtlarına sporcu adıyla erişemez.
3. **Gezinme ve Arayüz Bütünlüğü:**
   - Mobil uygulamada 5 alt sekme (`SwanBottomNav`) değişmez. Kulüp içi ihtisas modülleri Profil > Yönetim (`management_section.dart`) içinden açılır.
   - Masaüstü konsolunda `ConsoleAudience.clubStaff` altında ilgili modüller listelenir.

---

## 2. Oluşturulacak ve Güncellenecek Modüller

### A. Sağlık ve Sakatlık Yönetimi (Doktor / Fizyo vs. Antrenör İdari Dinlendirme)
* **Mobil Ekran:** `/kulup/saglik-takibi` (veya `athlete_detail_screen` / `eligibility_screen` entegrasyonu).
* **İşleyiş:**
  - Kulüpte yetkili doktor varsa: Doktor sporcuya tıbbi kısıt ekler (`create_health_restriction` RPC'si). Durum "Oynayamaz / Tedavi Görüyor" rozetine döner ve esamede kilitlenir.
  - Kulüpte doktor yoksa: Antrenör sporcu kartında veya kadroda "İdari Dinlendir" butonuna basarak `rested` veya `injured_admin` notu düşer. İstediğinde bu notu kaldırabilir.

### B. Malzeme ve Zimmet Takip Modülü (Kit Manager)
* **Backend Şeması (`0114_club_inventory_and_equipment.sql` veya benzeri):**
  - `public.club_inventory_items`: `id`, `club_id`, `name` (Top, Forma Seti, Yelek, Antrenman Konisi vb.), `category`, `quantity`, `sport_code`, `status`.
  - `public.club_inventory_assignments`: `id`, `item_id`, `assigned_to_profile_id` (antrenör/sporcu), `assigned_to_team_id`, `quantity`, `assigned_at`, `returned_at`, `notes`.
* **Ekranlar:**
  - Mobil: `/kulup/malzeme-zimmet` (Malzeme Sorumlusu ve Kulüp Yöneticisi için Profil > Yönetim altında).
  - Konsol: `/malzeme-takibi` (`ConsoleAudience.clubStaff`).
  - Zimmet Listesi: Hangi malzeme kime ne zaman teslim edildi, iade edildi mi takibi.

### C. Sportif Direktör & Kadro Planlama
* **Modül:**
  - Takım kadroları, lisans vize süreleri yaklaşan sporcular ve transfer taleplerinin özeti.
  - Antrenör kadro/esame tercihleri ve yoklama devam özet raporları (`development_report` entegrasyonu).

---

## 3. Test ve Doğrulama Adımları

1. SQL testleri: Yeni tablolar ve RPC'ler için test senaryoları (idempotent, RLS korumalı).
2. `python tools/check_migrations.py` (Hatasız geçmeli).
3. `python tools/check_faq.py` ve `python tools/check_push_routes.py` (Senkronize kalmalı).
4. `python tools/check_mobile_ui_tokens.py --syntax` ve `git diff --check` (Temiz olmalı).
