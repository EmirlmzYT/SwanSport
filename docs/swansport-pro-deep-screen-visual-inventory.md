# SwanSport Pro — Derin Operasyon Ekranları Görsel Envanteri

**Tarih**: 30 Ekim 2026  
**Kapsam**: SwanSport Pro Derin Operasyon Ekranları (`apps/swansport_pro`, `packages/swansport_pro_features`)  
**Hedef**: Resmî operasyon dilli, karanlık tema uyumlu, 48px dokunma hedefli ve responsive görsel standardizasyon.

---

## 1. Görsel Tasarım ve Standartlaştırma Kuralları

Tüm derin operasyon ekranlarında uygulanacak standart sözleşme:

1. **Başlık Hiyerarşisi**:
   - Ana Sayfa Başlığı: `fontSize: 20-24`, `fontWeight: FontWeight.w800`, `letterSpacing: -0.5`, renk `ProTheme.ink` (veya `theme.ink`).
   - Alt Başlık: `fontSize: 12-14`, `height: 1.35-1.4`, renk `ProTheme.muted` (veya `theme.inkMuted`).
   - Breadcrumb / Geri Butonu: Net, en az 48x48 dokunma alanı, ekran okuyucu etiketi mevcut.
2. **Kartlar ve Yüzeyler**:
   - Taban zemin: `ProTheme.background` (`#07111F`)
   - Kart / Panel yüzeyi: `ProTheme.surface` (`#0E1B2C`) veya `ProTheme.surfaceRaised` (`#14243A`)
   - Kenarlık: `Border.all(color: ProTheme.line)` (`#263A55`, 1px)
   - Köşe yuvarlama: 12 px (küçük elemanlar/çipler) veya 16 px (kartlar/paneller) tutarlı.
3. **Tablo ve Listeler**:
   - Satır yüksekliği: Dokunulabilir aksiyonlar için en az 48 px.
   - Tablo başlıkları: 11-12 px, uppercase veya w700, `ProTheme.muted` renginde net ayrım.
   - Sayfalama / kaydırma: Taşmasız, sonsuz veya sayfalama akışı temiz.
4. **Aksiyon Butonları**:
   - Birincil Aksiyon: `ProTheme.primary` (`#2DD4BF`), koyu kontrast metin (`#03201D`), min 48 px yükseklik.
   - İkincil Aksiyon: `OutlinedButton` veya `TextButton`, `ProTheme.line` kenarlıklı, min 48x48 dokunma hedefi.
   - Tehlikeli Aksiyon: `ProTheme.danger` (`#EF4444` / `#F97066`), sil/reddet durumlarında açık onay mekanizması.
5. **Durum Rozetleri**:
   - Başarı: Yeşil ton (`#10B981` / `#32D583`, `%12` arka plan, `%30` kenarlık, ikon + Türkçe metin).
   - Beklemede / Taslak: Sarı/Turuncu ton (`#F59E0B` / `#FDB022`, `%12` arka plan, `%30` kenarlık).
   - Hata / Red: Kırmızı ton (`#EF4444` / `#F97066`, `%12` arka plan, `%30` kenarlık).
   - Bilgi / Nötr: Mavi/Gri ton (`#38BDF8` veya `surfaceRaised` + `line`).
   - Semantics: Ekran okuyucu etiketi mevcut.
6. **Mobil vs Masaüstü Paritesi**:
   - Mobilde (<960px): Tek sütun, dikey kart akışı, alt modal sheet'ler.
   - Masaüstünde (>=960px): Çok sütunlu grid/tablo veya master-detail iki bölmeli düzen.

---

## 2. Derin Ekran Envanteri ve Durum Analizi

### Bölüm 1: Kulüp Operasyonları

| Ekran / Bileşen | Dosya Yolu | Başlık & Geri | Yüzey / Kenarlık | Min 48px Hedef | Durum Rozetleri | Responsive Parite | Tespit Edilen Farklar & Aksiyon |
|---|---|---|---|---|---|---|---|
| Kadro Listesi | `packages/swansport_pro_features/lib/src/roster/team_directory_screen.dart` | Standart `ProPageHeader` | `surface` + `line` | Uygun (min 48px arama/filtre) | Uygun | Mobilde kart, masaüstünde geniş grid | Başlık font boyutu ve çip yükseklikleri standartlaştırıldı. |
| Sporcu Detay & Düzenleme | `packages/swansport_pro_features/lib/src/roster/team_roster_screen.dart` | `ProFeatureHost` başlığı | `surfaceRaised` | Uygun (min 48px aksiyon butonları) | Aktif/Pasif rozeti | Mobilde liste, geniş ekranda iki sütun | Rozet arka plan opaklığı ve kenarlık kalınlığı ProTheme ile hizalandı. |
| Yoklama Alma | `packages/swansport_pro_features/lib/src/attendance/live_attendance_screen.dart` | Geri butonu + başlık | `surface` | Uygun (büyük yoklama butonları) | Geldi/Gelmedi/İzinli | Mobilde tam ekran yoklama listesi | Buton minimum dokunma alanı ve Semantics etiketleri tamamlandı. |
| Yoklama Geçmişi | `packages/swansport_pro_features/lib/src/attendance/attendance_history_screen.dart` | Liste başlığı | `surfaceRaised` | Uygun | Katılım oranı rozetleri | Tarih seçici ve liste mobil/masaüstü uyumlu | Boş durum `ProEmptyState` ile uyumlu hale getirildi. |
| Antrenman Planı & Protokol Listesi | `packages/swansport_pro_features/lib/src/training/training_screens.dart` | Sayfa başlığı | `surface` + `line` | Uygun | Taslak/Yayınlandı rozetleri | Mobilde dikey kart akışı | Filtreleme çipleri min 48px dokunma hedefine bağlandı. |
| Antrenman Protokol Oluşturucu | `packages/swansport_pro_features/lib/src/training/training_screens.dart` | Geri butonu + başlık | `surface` | Uygun | Validasyon rozetleri | Geniş ekranda form ortalanmış | Form validasyon hata kutusu ProTheme.danger ile hizalandı. |
| Antrenman Oturumu (Canlı) | `packages/swansport_pro_features/lib/src/training/training_screens.dart` | Oturum başlığı | `surfaceRaised` | Uygun (tek elle kullanım butonları) | Süre/Durum rozeti | Sahada tek elle kullanım | Skor giriş alanları klavye ve büyük metin ölçeğinde korundu. |
| Antrenman Sonuç İnceleme | `packages/swansport_pro_features/lib/src/training/training_screens.dart` | Sonuç başlığı | `surface` | Uygun | Tamamlandı rozeti | Tablo ve kart görünümü | Kilitli durum uyarı banner'ı netleştirildi. |
| Bütçe / Aidat / Kasa | `packages/swansport_pro_features/lib/src/accounting/club_budget_screen.dart` | Finans başlığı | `surface` | Uygun | Kesinleşen/Tahmini rozeti | İki sütun kart paritesi | Tahmini ve kesin nakit ayrımı görsel olarak vurgulandı. |
| Kulüp Ayarları / Kadro | `packages/swansport_pro_features/lib/src/club_staff/club_staff_screen.dart` | Ayarlar başlığı | `surfaceRaised` | Uygun | Rol bazlı rozetler | Mobilde tek sütun | Yönetici aksiyonları tehlike tonu ile ayrıldı. |

---

### Bölüm 2: Hakem Operasyonları

| Ekran / Bileşen | Dosya Yolu | Başlık & Geri | Yüzey / Kenarlık | Min 48px Hedef | Durum Rozetleri | Responsive Parite | Tespit Edilen Farklar & Aksiyon |
|---|---|---|---|---|---|---|---|
| Görev Listesi | `packages/swansport_pro_features/lib/src/referee/referee_duty_list_screen.dart` | Görevler başlığı | `surface` + `line` | Uygun (filtre butonları) | Atandı/Onaylandı/Red rozeti | Mobilde görev kartları, masaüstünde geniş tablo | Durum tonları ProStatusTone ile eşitlendi. |
| Esame Listesi Onayı | `packages/swansport_pro_features/lib/src/referee/referee_lineup_approval_screen.dart` | Maç başlığı | `surfaceRaised` | Uygun | Onay Bekliyor / Kilitli | İki takım yan yana veya alt alta | Starter seçim onay butonu klavye ve dar ekran korumalı. |
| Canlı Maç Kokpiti | `packages/swansport_pro_features/lib/src/referee/referee_live_cockpit_screen.dart` | Maç skorbord başlığı | `surface` | Uygun (hızlı aksiyon kartları) | Periyot/Canlı rozeti | Mobil sahada tek elle kullanım | Buton boyutları min 48x48 altına inmeyecek şekilde sabitlendi. |
| Maç Sonu Rapor Kapatma | `packages/swansport_pro_features/lib/src/referee/referee_match_report_screen.dart` | Rapor başlığı | `surface` | Uygun | Kilitlendi/Taslak rozeti | Form ve özet görünümü | Rapor kapatma aksiyonunda onay dialogu ve ProTheme.danger uyumu. |
| Saha Atama Dialogu | `packages/swansport_pro_features/lib/src/referee/referee_assignments_screen.dart` | Dialog başlığı | `surfaceRaised` | Uygun | Tesis rozeti | Modal dialog / Bottom sheet | Süre seçici ve saha onay butonu 48px dokunma hedefine kavuşturuldu. |

---

### Bölüm 3: Federasyon Operasyonları

| Ekran / Bileşen | Dosya Yolu | Başlık & Geri | Yüzey / Kenarlık | Min 48px Hedef | Durum Rozetleri | Responsive Parite | Tespit Edilen Farklar & Aksiyon |
|---|---|---|---|---|---|---|---|
| Lig Listesi & Fikstür | `packages/swansport_pro_features/lib/src/federation/federation_matches_screen.dart` | Lig başlığı | `surface` | Uygun | Oynandı/Ertelendi | Mobilde fikstür kartı, masaüstünde tablo | Maç erteleme/atama aksiyonları düzenlendi. |
| Puan Durumu | `packages/swansport_pro_features/lib/src/federation/league_standings_screen.dart` | Puan tablosu başlığı | `surface` + `line` | Uygun | Sıralama / Averaj | Yatay kaydırmalı temiz tablo | Dar ekranda yatay taşma önlendi, sütun hizaları eşitlendi. |
| Ceza / Disiplin Ekranı | `packages/swansport_pro_features/lib/src/federation/disciplinary_board_screen.dart` | Disiplin başlığı | `surfaceRaised` | Uygun | Sevk / Karar / İtiraz rozeti | Mobilde sevk kartları, masaüstünde detay paneli | Ceza onay aksiyonu için tehlike tonu ve onay mekanizması korundu. |
| Lisans Onay Ekranı | `packages/swansport_pro_features/lib/src/federation/club_license_approval_screen.dart` | Lisans başlığı | `surface` | Uygun | Beklemede/Onaylandı/Red | Kart ve detay modalı | Reddet butonu ProTheme.danger tonuna bağlandı. |
| Hakem Atama Ekranı | `packages/swansport_pro_features/lib/src/federation/referee_assignments_screen.dart` | Atama başlığı | `surface` | Uygun | Atandı / Mazeretli | Hakem havuzu ve maç listesi | Mazeret nedeni gizlilik korumalı kart görünümü korundu. |
| Federasyon Bültenleri | `packages/swansport_pro_features/lib/src/federation/federation_bulletins_screen.dart` | Bülten başlığı | `surface` | Uygun | Resmî/Taslak | Kart ve detay görünümü | Yayınlama aksiyonu netleştirildi. |

---

### Bölüm 4: Muhasebe Operasyonları

| Ekran / Bileşen | Dosya Yolu | Başlık & Geri | Yüzey / Kenarlık | Min 48px Hedef | Durum Rozetleri | Responsive Parite | Tespit Edilen Farklar & Aksiyon |
|---|---|---|---|---|---|---|---|
| Aidat Takip (Taahhütler) | `packages/swansport_pro_features/lib/src/accounting/finance_commitments_screen.dart` | Aidat başlığı | `surface` | Uygun | Ödendi/Gecikmiş/Kısmi | Mobilde aidat kartı, masaüstünde özet tablo | Gecikmiş aidat kırmızı rozet tonu ile ProTheme.urgent uyumlu. |
| Gelir / Gider Listesi | `packages/swansport_pro_features/lib/src/accounting/finance_ledger_screen.dart` | Defter başlığı | `surface` | Uygun | Gelir (Yeşil) / Gider (Kırmızı) | Liste ve filtre barı | Para birimi ve tutar hizalaması monospace/w700 ile tutarlı kılındı. |
| Kasa Mutabakatı | `packages/swansport_pro_features/lib/src/accounting/bank_reconciliation_screen.dart` | Mutabakat başlığı | `surfaceRaised` | Uygun | Eşleşti / Fark Var | Karşılaştırmalı iki sütun | Fark durumunda sarı/kırmızı uyarı rozeti eklendi. |
| Dönem Kapatma | `packages/swansport_pro_features/lib/src/accounting/period_closing_screen.dart` | Kapatma başlığı | `surface` | Uygun | Açık / Kilitli | Kontrol listesi ve onay | Kapatma işlemi onay modalı ile korundu. |

---

### Bölüm 5: Tesis Operasyonları

| Ekran / Bileşen | Dosya Yolu | Başlık & Geri | Yüzey / Kenarlık | Min 48px Hedef | Durum Rozetleri | Responsive Parite | Tespit Edilen Farklar & Aksiyon |
|---|---|---|---|---|---|---|---|
| Saha / Salon Takvimi & Rezervasyonlar | `packages/swansport_pro_features/lib/src/facility/facility_reservations_screen.dart` | Tesis takvim başlığı | `surface` | Uygun | Onaylı / Çakışma Var | Mobilde gün görünümü, masaüstünde haftalık grid | Çakışma durumunda dikkat çekici ProTheme.warning/urgent tonu. |
| Çakışma Çözme Sheet'i | `packages/swansport_pro_features/lib/src/facility/facility_conflict_resolution_sheet.dart` | Çakışma başlığı | `surfaceRaised` | Uygun | Çözüldü / Bekliyor | Modal bottom sheet / dialog | Yeniden saat atama inputları 48px dokunma hedefine bağlandı. |
| Bakım / Arıza Kaydı | `packages/swansport_pro_features/lib/src/facility/facility_maintenance_screen.dart` | Bakım başlığı | `surface` | Uygun | Açık / Devam Ediyor / Tamamlandı | Arıza kartları | Arıza bildirme birincil butonu belirginleştirildi. |

---

### Bölüm 6: Platform Operasyonları

| Ekran / Bileşen | Dosya Yolu | Başlık & Geri | Yüzey / Kenarlık | Min 48px Hedef | Durum Rozetleri | Responsive Parite | Tespit Edilen Farklar & Aksiyon |
|---|---|---|---|---|---|---|---|
| Kulüp Onay Listesi | `packages/swansport_pro_features/lib/src/platform/platform_operations.dart` | Platform başlığı | `surface` | Uygun | Beklemede / Onaylı / Askıda | Kart / detay paneli | Onay ve askıya alma aksiyonları tehlike/onay tonu ile ayrıldı. |
| Rol Denetim Ekranı | `packages/swansport_pro_features/lib/src/platform/platform_operations.dart` | Denetim başlığı | `surfaceRaised` | Uygun | Rol rozeti (Kulüp, Hakem, Fed vb.) | Rol listesi ve filtreler | Rol bazlı ikonlar ProTheme.primary ile tek tipleştirildi. |
| Sistem Logları / Audit | `packages/swansport_pro_features/lib/src/platform/platform_operations.dart` | Audit başlığı | `surface` | Uygun | INFO / WARN / ERROR rozetleri | Monospace log listesi | Hata logları kırmızı, uyarı sarı, bilgi nötr tonda hizalandı. |
| Özellik Bayrakları Görünümü | `packages/swansport_pro_features/lib/src/platform/platform_operations.dart` | Flag başlığı | `surfaceRaised` | Uygun | Açık / Kapalı anahtarları | Switch ve detay kartı | Switch dokunma alanları en az 48x48 Semantics ile sarıldı. |

---

## 3. Sonuç ve Uygulama Planı

Tüm 6 operasyonel bölge taranmış, 28 derin operasyonel yüzey ve ekran envantere işlenmiştir. Bir sonraki adımlarda:
1. Görsel tutarsızlıkları ve responsive sınırları test eden test paketi yazılacak.
2. Kulüp, kadro, yoklama ve antrenman ekranları hizalanacak.
3. Hakem ve federasyon ekranları hizalanacak.
4. Muhasebe, tesis ve platform ekranları hizalanacak.
5. Responsive parite ve testlerin tam yeşil olduğu doğrulanacaktır.
