# SwanSport Master UI/UX Architecture & Overhaul Plan

> **Hedef:** SwanSport'u idari bir borç/ERP defteri görünümünden çıkarıp; sporcuların, antrenörlerin ve sporseverlerin her gün tutkuyla açtığı **modern, atletik ve dinamik bir spor ağına** dönüştürmek.

---

## 1. Temel İlke: "Sosyal Spor Hayatı" ile "Kulüp Operasyonunun" Ayrılması

Uygulamanın bugüne kadarki en büyük tasarım çıkmazı, **tüketici deneyimi (sosyal/atletik)** ile **arka ofis yönetimini (ERP/operasyon)** aynı ekranda (Ana Sayfa) üst üste yığmasıydı.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SWANSPORT EKOSİSTEMİ                              │
├──────────────────────────────────────┬──────────────────────────────────────┤
│    GÜNLÜK SPORCU VE TÜKETİCİ AKIŞI   │         KULÜP & İŞLETME YÖNETİMİ     │
│       (Mobil Ana Sayfa /akis)        │      (Profil > Yönetim & Konsol)     │
├──────────────────────────────────────┼──────────────────────────────────────┤
│  ⚡ Sporcu Antrenman Kayıtları        │  📋 Yoklama Alma & Devamsızlık       │
│  🏆 Maç Skorları ve Turnuva Zaferleri│  💳 Aidat Toplama, Fatura ve Defter  │
│  🎯 Kişisel Rekorlar (PR) & Rozetler │  🔒 Lisans ve Sağlık Uygunluğu       │
│  📰 Güncel Spor Haberleri (RSS/Bülten│  🏢 Tesis Rezervasyonu & Çakışmalar  │
│  📸 Takım Fotoğrafları ve Videolar   │  📊 Federasyon Raporları & Denetim   │
│  📢 Resmi Kulüp Duyuruları (Rozetli) │  👥 Kadro ve Personel Yönetimi       │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

---

## 2. Mobil Ana Akış (`swansport_app` / `feed_screen.dart`) Dönüşümü

### A. Üst Bar (`StitchFeedTopBar` ➔ `SwanFeedTopBar`)
- ❌ **Kaldırılan:** `GoogleFonts.grandHotel` (el yazısı, davetiye fontu).
- ✅ **Gelen:** 
  - `Sora` font ailesi (Bold 800, -0.6 tracking).
  - Beyaz `SwanSport` wordmark ve hemen yanında **neon teal vurgu noktası (`#00C7B1`)**.
  - Sağ üst köşede zarif, temiz rozetli bildirim zili (`/bildirimler`) ve direkt mesaj ikonu (`/mesajlar`).

### B. İlk Katman Blokajının Temizlenmesi
- ❌ **Kaldırılanlar:**
  1. `StitchStoriesBar` (içeriği olmayan yapay Instagram hikaye halkaları).
  2. `TodayTasks` (aidat borçları, onay bekleyen fişler gibi idari işler).
  3. `AttendanceQueueBanner` (çevrimdışı yoklama kuyruğu uyarısı).
- ✅ **Yeni Deneyim:** Kullanıcı uygulamayı açtığı anda ilk katmanda doğrudan **en taze sporcu aktiviteleri ve spor haberleri** ile karşılaşır.

### C. Çok Yönlü Akış Kartları (Athletic Activity Stream)

Akış karma listesinde (`FeedEntry`) 5 temel kart tipi nefes alan, kenarlıksız (`borderless`), derin lacivert zeminli (`#1B273A`) yüzeylerde sunulur:

1. **🏋️‍♂️ Sporcu Antrenman & Performans Kartı:**
   - Sporcu avatarı, branş rozeti (örn: Okçuluk, Boks, Tenis, Yüzme).
   - Tamamlanan seans özeti: "72 Ok · 680 Puan" veya "5.2 km Koşu · 24 dk".
   - Antrenman hissi/RPE veya fotoğraf.
   - Hızlı tebrik ("👏 Alkışla", "❤️ Beğen", "💬 Yorum Yap").

2. **🏆 Maç Skoru & Kulüp Zaferi Kartı:**
   - İki takım logosu, canlı/nihai skor panosu (örn: `Swan Akademi 3 - 1 Kartal GSK`).
   - Set/periyot detayları ve maçın oyuncusu (MVP) rozeti.

3. **🎯 Kişisel Rekor (PR) / Başarı Kartı:**
   - Altın/Teal mikro gradyan çerçeve.
   - "Yeni Kişisel Rekor!" başlığı ve sporcunun geliştirdiği derece.

4. **📰 Spor Haberleri Kartı (`NewsCard`):**
   - **Editöryel Kategori Rozeti:** `#SPOR GÜNDEMİ`, `#FUTBOL`, `#TENİS` vb.
   - Kaynak avatarı ve adı (*Anadolu Ajansı*, *TRT Spor*, federasyon kaynakları) + geçen zaman.
   - 16:9 geniş kapak görseli (yumuşak köşeli, `SwanRadius.md`).
   - `SwanType.h3` haber başlığı ve 2 satırlık özet.
   - "Haberi Oku ↗" harici bağlantı butonu.

5. **📢 Kulüp Duyurusu Kartı (`AnnouncementCard`):**
   - Sabitlenmiş rozet (`PushPin`), kulüp arması.
   - Resmi, net ve okunabilir kulüp bülteni.

---

## 3. Kulüp Operasyonları ve "İşlerin" Yeni Yuvası

İdari ve operasyonel işler mobilde yok olmuyor; **ait oldukları doğru sekmelere yerleşiyor**:

1. **Antrenör İçin:**
   - Eğer antrenörün *hemen o gün / o saatte* planlanmış bir oturumu varsa, akışın en üstünde tek satırlık minimal bir canlı oturum çipi görünür:
     `[ 🔴 Devam Eden: U-16 Antrenmanı · Yoklama Al ➔ ]`
   - Tüm yoklama ve oturum yönetimi **Profil > Yönetim** veya Hızlı Eylem (+) menüsünden tek tıkla açılır.
2. **Sporcu & Veli İçin:**
   - Aidat ödemeleri, lisans yüklemeleri ve veli izinleri **Profil > Hesabım / Kulüp Bilgilerim** altında "Mali İşlerim" ve "Belgelerim" sekmelerinde yer alır.

---

## 4. Masaüstü Konsol (`swansport_console`) Dönüşümü

1. **Görsel Dilin Eşitlenmesi:**
   - Masaüstü konsol, mobildeki koyu lacivert (`#131D2E`) ve neon teal (`#00C7B1`) paletine bürünür.
   - Kuru gri Material tablolar yerine modern, yüksek kontrastlı veri kartları kullanılır.
2. **Rol-Özel Dashboard (Çalışma Masası):**
   - **Antrenör Girişi:** Kadro katılım oranları, bugünkü antrenman takvimi, sporcu sağlık/kısıt durumları.
   - **Yönetici Girişi:** Bekleyen üye onayları, tesis doluluk grafiği, kasa nakit projeksiyonu.
   - **Muhasebeci Girişi:** Yalnızca `acc_*` RPC'leri üzerinden beslenen sporcu adı gizlenmiş gelir/gider defteri.

---

## 5. Codex Uygulama Aşamaları

| Aşama | Kapsam | İlgili Dosyalar |
|---|---|---|
| **Aşama 1** | Mobil Header, Tipografi ve İdari Banner Temizliği | `feed_screen.dart`, `stitch_feed_widgets.dart` |
| **Aşama 2** | Spor Haberleri (`NewsCard`) ve Kulüp Duyuruları Yenilemesi | `feed_entry.dart` |
| **Aşama 3** | Sosyal Gönderi Kartı (`PostCard`) ve Atletik Kart Tasarımı | `post_card.dart` |
| **Aşama 4** | Profil Yönetim Merkezi & İdari Bildirim Düzenlemesi | `management_section.dart` |
| **Aşama 5** | Konsol Dashboard ve Kart Modernizasyonu | `console_dashboard.dart`, `console_theme.dart` |
