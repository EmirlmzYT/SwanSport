# SwanSport Pro yönetim parite matrisi

Bu matris sosyal işlevleri değil, normal SwanSport istemcisinde bulunan
profesyonel/yönetim işlevlerini izler. Durumlar yalnızca kod, rota, veri
sözleşmesi ve test kanıtına göre verilmiştir; canlı dağıtım veya cihaz kabulü
anlamına gelmez.

| Alan | SwanSport rotası | Rol | Veri servisi/provider | Pro rotası | Durum | Yetki / RLS | Test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Kulüp başvuruları | `/kulup-basvurulari` | Kulüp yöneticisi | `ClubApplicationService`, `clubPendingApplicationsProvider` | `/operasyon/kulup-yonetimi` | Tamamlandı (Faz A) | İnceleme servisi ve kulüp kapsamı | `pro_club_management_test.dart` |
| Kulüp duyuruları | Kulüp paneli | Kulüp görevlisi | `ClubDataService`, `announcementsProvider` | `/operasyon/kulup-yonetimi` | Tamamlandı (Faz A) | `announcements` RLS | `pro_club_management_test.dart` |
| Kulüp belgeleri | Kulüp paneli | Kulüp görevlisi | `ClubOpsService`, `clubDocumentsProvider` | `/operasyon/kulup-yonetimi` | Tamamlandı (Faz A) | Kulüp kapsamlı belge RLS | `pro_club_management_test.dart` |
| Kulüp ve sezon ayarları | `/settings`, `/sezon-acilisi` | Kulüp yöneticisi; branşta antrenör | `ClubConfigService`, `ClubTrainingSportsService` | `/operasyon/kulup-yonetimi` Ayarlar | Tamamlandı (Faz B) | Kimlik/personel admin RLS; branş RPC admin/coach; sezon mevcut staff RLS | `pro_club_management_test.dart` |
| Takım/kadro yönetimi | `/teams` | Kulüp görevlisi | `ClubDataService`, `teamsProvider` | `/operasyon/takimlar`, kulüp Ayarları | Tamamlandı | `teams` staff RLS | `pro_operations_navigation_test.dart` |
| Yoklama | `/yoklama`, `/devam` | Kulüp görevlisi | Yoklama provider ve RPC'leri | `/operasyon/yoklama`, `/operasyon/devam` | Tamamlandı | Kulüp staff RPC/RLS | Pro attendance testleri |
| Antrenman | `/antrenmanlar` ve sezon hazırlığı | Antrenör / kulüp görevlisi | Training session servisleri | `/operasyon/antrenmanlar` ve alt rotalar | Tamamlandı | Eğitim RPC yetki kontrolleri | Pro training testleri |
| Veli/sporcu bağlantıları | `/veli-bagla`, `/veli-izinleri` | Veli / kulüp yöneticisi | `VerificationService`, `GuardianLinkManagementService`, parent action servisleri | `/operasyon/veli-sporcu-baglantilari` | Tamamlandı (Faz C) | Maskeli admin RPC; davet tüketimi kimlik ve kulüp yetkilisi kontrolü | `pro_guardian_links_test.dart`, `guardian_link_management_test.dart` |
| Aidat ve ödeme | `/finans` | Kulüp yöneticisi / muhasebeci | `ClubDuesManagementService`, Finance servisleri | `/operasyon/aidat-takibi`; maskeli muhasebe için `/operasyon/muhasebe` | Tamamlandı (Faz D) | İsimli aidat projeksiyonu ve mutasyonları yalnız `is_club_admin`; muhasebeci mevcut maskeli defteri kullanır; antrenör fail-closed | `pro_club_dues_test.dart`, `club_dues_management_test.dart`, SQL zincir testleri |
| Muhasebe | Finans çalışma alanı | Muhasebeci | Finance ops servisleri | `/operasyon/muhasebe` ve alt rotalar | Tamamlandı (önceki Pro fazı) | Muhasebeci kulüp kapsamı | Pro accounting testleri |
| Tesis | Tesis rotaları | Tesis yöneticisi/delege | Turf/saha servisleri | `/operasyon/tesis` ve alt rotalar | Tamamlandı (önceki Pro fazı) | Yönetici/delege kapsamı | Pro facility testleri |
| Federasyon | Federasyon merkezi | Federasyon rolleri | Federation center servisleri | Federasyon operasyon rotaları | Tamamlandı (önceki Pro fazı) | Atama kapsamlı RPC | Pro federation testleri |
| Hakem | Hakem rotaları | Hakem/komite | Sports roles servisleri | Hakem operasyon rotaları | Tamamlandı (önceki Pro fazı) | Hakem ve komite kapsamı | Pro referee testleri |
| Disiplin | Disiplin kurulu | Kurul üyesi | Federation servisleri | `/operasyon/disiplin-kurulu` | Tamamlandı | Kurul üyeliği fail-closed | Pro federation testleri |
| Bülten | Federasyon bülteni | Federasyon rolleri | Federation servisleri | `/operasyon/federasyon-bulten` | Tamamlandı | Federasyon kapsamı | Pro federation testleri |
| Performans analitiği | `/gelisim-raporu` ve performans ekranları | Antrenör / kulüp sportif yetkilisi | `DevelopmentReportService`; mevcut performans, yoklama ve antrenman kayıtları | `/operasyon/gelisim-raporu` | Tamamlandı (Faz E) | Seçici ve rapor RPC'leri `can_view_athlete_performance` ile fail-closed; Pro rota kapısı veli/sporcu ve muhasebeciyi kabul etmez | Veri ayrıştırma/sözleşme testleri, Pro route ve responsive paket testleri, SQL yetki zinciri |
| Platform yönetimi | Platform yönetim ekranları, `/haber-kaynaklari`, profesyonel onay ve federasyon yetkileri | Platform yöneticisi | `PlatformMissionControlService`, `NewsService`, `AdminService`, `VerificationService`, `CommunityService` | `/operasyon/platform`; durum, audit, plan, bekleme listesi, RSS, profesyonel inceleme, erişim ve federasyon yetki alt rotaları | Tamamlandı (Faz F) | Pro rota kapısı ve ekranlar `SwanAccess.isPlatformAdmin` ile fail-closed; mutasyonlar mevcut platform-admin RLS/RPC kontrollerinde; feature flag görünümü salt okunur | Platform fail-closed/widget, rota sözleşmesi, Pro ve veri paket testleri |
| Bildirimler/deep linkler | Bildirim merkezi | Rota rolüne göre | Notification service | Pro gelen kutusu ve kayıtlı rotalar | Kısmi | Hedef rotada yeniden yetki kapısı | `pro_notification_route_test.dart` |
| Görev ve takvim | Ana panel/görev/takvim | Çalışma alanı rolü | Dashboard, task, unified calendar provider'ları | `/gorevler`, `/takvim` | Kısmi | Provider kapsamları | Faz A başvuru, Faz C veli-davet ve Faz D gerçek ödeme/gecikmiş aidat sayaçları var |

Faz C notu: mevcut veri modelinde veli bağlantısı için ayrı bir onay başvurusu
yoktur. Kulüp görevlisinin ürettiği süreli `guardian_link` daveti, kimliği
doğrulanmış veli tarafından tüketildiğinde bağlantı atomik olarak oluşur.
Dolayısıyla Pro gerçek kullanılmamış davetleri “bekleyen” sayar; uydurma bir
onay/red kuyruğu göstermez. Kulüp yöneticisi kullanılmamış daveti iptal
edebilir. Bağlı hesap görünümü telefon, e-posta, doğum tarihi, özel not ve davet
kodunu döndürmeyen sunucu projeksiyonunu kullanır.

Faz D notu: isimli sporcu aidatları yalnız kulüp yöneticisine açılır.
Muhasebeci çalışma alanı mevcut maskeli `acc_ledger` sözleşmesini korur;
antrenör ve diğer roller isimli mali projeksiyona erişemez. Kısmi ödeme durumu
onaylı tahsilat toplamından türetilir; doğrudan tahsilat mutasyonu işlem
anahtarıyla idempotenttir ve belirsiz ağ yanıtı istemcide başarı sayılmaz.

## Faz B güvenlik notları

- Kulüp kimliği, profil bölümleri ve personel rolleri Pro'da yalnızca aktif
  `club_admin` üyeliğine açılır; sunucuda `clubs` ve `club_memberships`
  politikaları `is_club_admin` kullanır.
- Branş seçimi mevcut `set_club_training_sports` RPC'sini kullanır. RPC aktif
  kulüp üyeliğini ve `club_admin`/`coach` rolünü sunucuda yeniden doğrular.
- Sezon ve takım tablolarının mevcut politikası `is_club_staff` kapsamındadır.
  Pro ayar ekranı sezon mutasyonunu yalnızca kulüp yöneticisine, takım
  operasyonunu yönetici ve antrenöre gösterir. UI görünürlüğü tek başına
  güvenlik iddiası değildir; son söz mevcut RLS kapsamınındır.
- Hiçbir sahte kulüp, sezon, takım veya personel kaydı üretilmez. Boş durumlar
  gerçek provider sonuçlarından gelir.
