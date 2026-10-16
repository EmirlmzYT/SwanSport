# SwanSport — Türkiye Spor Federasyonları ve Branş Kataloğu

Bu doküman, SwanSport platformunda desteklenen resmi spor branşlarının ve Türkiye spor federasyonlarının merkezi referans kütüğüdür.

Katalog; mobil (`swansport_app`), masaüstü konsol (`swansport_console`), veri katmanı (`packages/swansport_data`) ve Supabase veritabanı (`public.sports` & `public.federations`) ile birebir uyumludur.

---

## 🏛️ Federasyon ve Branş Listesi (60 Resmi Branş)

| # | Branş Kodu (`sport_code`) | Branş Adı (`name`) | Resmi Federasyon Adı (`federation_name`) | Kısaltma | Kategori |
|---|---|---|---|---|---|
| 1 | `aticilik-avcilik` | Atıcılık ve Avcılık | Türkiye Atıcılık ve Avcılık Federasyonu | TAAF | Hedef & Açık Hava |
| 2 | `atletizm` | Atletizm | Türkiye Atletizm Federasyonu | TAF | Pist & Saha |
| 3 | `badminton` | Badminton | Türkiye Badminton Federasyonu | TBF | Raket Sporları |
| 4 | `basketbol` | Basketbol | Türkiye Basketbol Federasyonu | TBF | Takım Sporları |
| 5 | `bedensel-engelliler` | Bedensel Engelliler Spor | Türkiye Bedensel Engelliler Spor Federasyonu | TBESF | Paralimpik & Engelli |
| 6 | `bilardo` | Bilardo | Türkiye Bilardo Federasyonu | TBF | Salon & Hassas |
| 7 | `binicilik` | Binicilik | Türkiye Binicilik Federasyonu | TBF | Bireysel & Hayvanlı |
| 8 | `bisiklet` | Bisiklet | Türkiye Bisiklet Federasyonu | TBF | Açık Hava & Dayanıklılık |
| 9 | `bocce-bowling-dart` | Bocce, Bowling ve Dart | Türkiye Bocce Bowling ve Dart Federasyonu | TBBDF | Hedef Sporları |
| 10 | `boks` | Boks | Türkiye Boks Federasyonu | TBF | Dövüş Sporları |
| 11 | `bric` | Briç | Türkiye Briç Federasyonu | TBF | Zihin Sporları |
| 12 | `buz-hokeyi` | Buz Hokeyi | Türkiye Buz Hokeyi Federasyonu | TBHF | Kış & Buz Sporları |
| 13 | `buz-pateni` | Buz Pateni | Türkiye Buz Pateni Federasyonu | TBPF | Kış & Buz Sporları |
| 14 | `cimnastik` | Cimnastik | Türkiye Cimnastik Federasyonu | TCF | Estetik & Bireysel |
| 15 | `curling` | Curling | Türkiye Curling Federasyonu | TCF | Kış & Buz Sporları |
| 16 | `dagcilik` | Dağcılık | Türkiye Dağcılık Federasyonu | TDF | Doğa & Tırmanış |
| 17 | `dans-sporlari` | Dans Sporları | Türkiye Dans Sporları Federasyonu | TDSF | Estetik & Performans |
| 18 | `e-spor` | E-Spor | Türkiye E-Spor Federasyonu | TESFED | Dijital & Zihin |
| 19 | `eskrim` | Eskrim | Türkiye Eskrim Federasyonu | TEF | Dövüş & Bireysel |
| 20 | `futbol` | Futbol | Türkiye Futbol Federasyonu | TFF | Takım Sporları |
| 21 | `geleneksel-okculuk` | Geleneksel Türk Okçuluğu | Türkiye Geleneksel Türk Okçuluğu Federasyonu | TGTOF | Hedef & Geleneksel |
| 22 | `golf` | Golf | Türkiye Golf Federasyonu | TGF | Bireysel & Çim |
| 23 | `gorme-engelliler` | Görme Engelliler Spor | Türkiye Görme Engelliler Spor Federasyonu | TGESF | Paralimpik & Engelli |
| 24 | `gures` | Güreş | Türkiye Güreş Federasyonu | TGF | Dövüş & Ata Sporu |
| 25 | `halk-oyunlari` | Halk Oyunları | Türkiye Halk Oyunları Federasyonu | THOF | Kültür & Performans |
| 26 | `halter` | Halter | Türkiye Halter Federasyonu | THF | Güç & Ağırlık |
| 27 | `hava-sporlari` | Hava Sporları | Türkiye Hava Sporları Federasyonu | THSF | Havacılık & Ekstrem |
| 28 | `hentbol` | Hentbol | Türkiye Hentbol Federasyonu | THF | Takım Sporları |
| 29 | `hokey` | Hokey | Türkiye Hokey Federasyonu | THF | Takım Sporları |
| 30 | `isitme-engelliler` | İşitme Engelliler Spor | Türkiye İşitme Engelliler Spor Federasyonu | TİESF | Paralimpik & Engelli |
| 31 | `izcilik` | İzcilik | Türkiye İzcilik Federasyonu | TİF | Doğa & Gençlik |
| 32 | `judo` | Judo | Türkiye Judo Federasyonu | TJF | Dövüş Sporları |
| 33 | `kano` | Kano | Türkiye Kano Federasyonu | TKF | Su Sporları |
| 34 | `karate` | Karate | Türkiye Karate Federasyonu | TKF | Dövüş Sporları |
| 35 | `kayak` | Kayak | Türkiye Kayak Federasyonu | TKF | Kış Sporları |
| 36 | `kaykay` | Kaykay | Türkiye Kaykay Federasyonu | TKF | Ekstrem Sporlar |
| 37 | `kick-boks` | Kick Boks | Türkiye Kick Boks Federasyonu | TKBF | Dövüş Sporları |
| 38 | `kizak` | Kızak | Türkiye Kızak Federasyonu | TKF | Kış Sporları |
| 39 | `kurek` | Kürek | Türkiye Kürek Federasyonu | TKF | Su Sporları |
| 40 | `masa-tenisi` | Masa Tenisi | Türkiye Masa Tenisi Federasyonu | TMTF | Raket Sporları |
| 41 | `modern-pentatlon` | Modern Pentatlon | Türkiye Modern Pentatlon Federasyonu | TMPF | Çoklu & Kombine |
| 42 | `motosiklet` | Motosiklet | Türkiye Motosiklet Federasyonu | TMF | Motor Sporları |
| 43 | `muaythai` | Muaythai | Türkiye Muaythai Federasyonu | TMTF | Dövüş Sporları |
| 44 | `okculuk` | Okçuluk | Türkiye Okçuluk Federasyonu | TOF | Hedef Sporları |
| 45 | `oryantiring` | Oryantiring | Türkiye Oryantiring Federasyonu | TOF | Doğa & Zihin |
| 46 | `otomobil-sporlari` | Otomobil Sporları | Türkiye Otomobil Sporları Federasyonu | TOSFED | Motor Sporları |
| 47 | `ozel-sporcular` | Özel Sporcular | Türkiye Özel Sporcular Spor Federasyonu | TÖSSFED | Paralimpik & Engelli |
| 48 | `rafting` | Rafting | Türkiye Rafting Federasyonu | TRF | Su & Doğa |
| 49 | `ragbi` | Ragbi | Türkiye Ragbi Federasyonu | TRF | Takım Sporları |
| 50 | `satranc` | Satranç | Türkiye Satranç Federasyonu | TSF | Zihin Sporları |
| 51 | `su-topu` | Sutopu | Türkiye Sutopu Federasyonu | TSTF | Su & Takım |
| 52 | `sualti-sporlari` | Sualtı Sporları | Türkiye Sualtı Sporları Federasyonu | TSSF | Su Sporları |
| 53 | `taekwondo` | Taekwondo | Türkiye Taekwondo Federasyonu | TTF | Dövüş Sporları |
| 54 | `tenis` | Tenis | Türkiye Tenis Federasyonu | TTF | Raket Sporları |
| 55 | `triatlon` | Triatlon | Türkiye Triatlon Federasyonu | TTF | Dayanıklılık & Çoklu |
| 56 | `voleybol` | Voleybol | Türkiye Voleybol Federasyonu | TVF | Takım Sporları |
| 57 | `vucut-gelistirme-fitness` | Vücut Geliştirme ve Fitness | Türkiye Vücut Geliştirme, Fitness ve Bilek Güreşi Federasyonu | TVGFBF | Güç & Fitness |
| 58 | `wushu-kung-fu` | Wushu Kung-Fu | Türkiye Wushu Kung Fu Federasyonu | TWKF | Dövüş Sporları |
| 59 | `yelken` | Yelken | Türkiye Yelken Federasyonu | TYF | Su & Rüzgar |
| 60 | `yuzme` | Yüzme | Türkiye Yüzme Federasyonu | TYF | Su Sporları |

---

## 🔗 Veritabanı ve Kod Entegrasyon Noktaları

1. **`public.sports` (SQL)**:
   - `code text primary key`: Branş slug'ı (örn: `basketbol`, `aticilik-avcilik`).
   - `name text not null`: Branşın Türkçe yaygın adı.
2. **`public.federations` (SQL)**:
   - `id uuid primary key default gen_random_uuid()`
   - `sport_code text not null unique references public.sports(code)`
   - `name text not null`: Resmi tüzel kişilik adı (örn: `Türkiye Basketbol Federasyonu`).
3. **Kullanıldığı Alanlar**:
   - `profile_credentials.sport_code`: Antrenörlük veya lisanslı sporcu belgesinin branşı.
   - `clubs.registration_sport_code` & `club_sport_registrations`: Kulübün federe tescil aldığı branşlar.
   - `teams.sport_code`: Takımın branşı.
   - `referee_profiles.sport_code`: Hakemin görev yaptığı branş.
   - `federation_appointments`: Federasyon temsilcisi, lisans tescil, program yayımcı görevlendirmeleri.
   - `courts.sport_code`: Saha / kort / tesis branş tipi.
