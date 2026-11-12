# Branşa Özel Antrenman ve Gelişim Tasarımı

## Amaç

Sporcunun her yetkili branşı için bireysel çalışma başlatması, antrenörün kulüp/branş/takım kapsamında oturum yönetmesi ve paylaşıma açılan sonuçların sporcu ile veli tarafından anlaşılır biçimde görülmesi. Bir kaydın branşı, kaynağı ve kulübü oturum anında sabitlenir; profil veya üyelik değişimi geçmişin anlamını değiştirmez.

## Başlangıç durumu ve Faz 0 kararı

Depoda yeni bir motor kurmayı gerektirmeyen güçlü bir temel var:

- `training_protocols` sürümlü ve `sport_code` taşıyor.
- `training_sessions.kind` kişisel ve kulüp kayıtlarını ayırıyor; oturumlar değişmez protokol sürümüne bağlı.
- `training_sets.metric_payload` yedi arketip için tipli ölçüm taşıyor.
- `0120_multi_branch_training_engine.sql` 60 katalog branşını ortak arketiplere bağlıyor.
- `SmartSportScopeBar`, aktif branş seçeneklerini ve tek/çok branş davranışını sağlıyor.
- RLS, kişisel oturumu yalnız sporcuya; kulüp oturumunu katılımcı ve yetkili personele açıyor.
- Aktif oturuma dönüş, kodla katılım, sonuç kilidi, başarısız kayıtta taslağı koruma ve çift dokunuşu engelleme için mevcut kod ve testler var.

Temel boşluklar:

1. `trainingProtocolsProvider` aktif kulüp olmadan boş dönüyor. Bu nedenle kulüpsüz veya farklı kulüp bağlamındaki sporcu, platform şablonuyla bireysel çalışma başlatamıyor.
2. `TrainingHistoryEntry` branşı ve kaynağı taşısa da `club_id`, kulüp adı ve antrenör bilgisini taşımıyor. Aynı branştaki iki kulüp geçmişte ayırt edilemiyor.
3. Antrenör şablon ekranı aktif kulübü kullanıyor fakat branş sonrası yetkili takım/grup/sporcu seçimi sunmuyor; başlatma çağrısındaki `teamId` arayüzden beslenmiyor.
4. Antrenör özel notu var; sporcuya gösterilecek geri bildirim için ayrı paylaşım sözleşmesi yok.
5. Mevcut gelişim raporu performans testlerini, hedefleri ve yoklamayı topluyor; antrenman setlerini branş/kaynak/karşılaştırılabilirlik boyutuyla toplamıyor.
6. Veli ekranı resmi müsabaka sonuçlarını gösteriyor. Antrenman sonuçları için açık paylaşım kararı ve salt okunur sunucu sözleşmesi yok. Bireysel kayıtlar varsayılan olarak kapalı kalmalı.
7. `session_screen.dart`, kulüp personelini yalnız rol üzerinden antrenör paneline alıyor. Oturum-kulüp yetkisini sunucu korusa da arayüz kararının da oturum kapsamına bağlanması gerekiyor.

## Branş kapsam matrisi

Tüm satırların başlangıç yolu bugün `Antrenmanlarım > Kendi başıma` veya kulüp personeli için `Antrenman şablonları > Oturumu Başlat`; aktif oturum `Antrenmanlarım > Oturuma dön`; sonuç `Oturum sonucu` yoludur. Aşağıdaki gruplar, katalogdaki her branşı tek tek kapsar.

| Branşlar | Araç | Kaydedilen ölçüm | Mevcut sonuç özeti | Güvenli karşılaştırma anahtarı | Eksik |
|---|---|---|---|---|---|
| Atıcılık ve Avcılık, Geleneksel Okçuluk, Okçuluk | Hedef/atış girişi | İşaretler, toplam, atış sayısı | Toplam, ortalama, en iyi set, dağılım | Branş + çalışma + mesafe + puanlama biçimi | Mesafe ve puanlama biçimi ölçüm yükünde yok |
| Bedensel Engelliler, Halter, Vücut Geliştirme ve Fitness | Kuvvet seti | Hareket, kg, tekrar, RPE, başarılı set | Set kartları | Branş + hareket + birim | Kaynak/kulüp filtresi ve zaman serisi yok |
| Cimnastik, Dans Sporları, Halk Oyunları, Buz Pateni, Binicilik, Kaykay | Rutin/jüri | Rutin, zorluk, uygulama, kesinti, net | Net rutin puanı | Branş + rutin + puanlama biçimi | Puanlama biçimi/sürümü açık karşılaştırma anahtarı değil |
| Satranç, Briç, E-spor, İzcilik, Dağcılık, Hava Sporları | Taktik görev | Görev, çözüm, hata, süre, doğruluk | Çözüm ve doğruluk | Branş + görev | Kaynak/kulüp ve gelişim görünümü yok |
| Atletizm, Bisiklet, Kano, Kayak, Kızak, Kürek, Motosiklet, Oryantiring, Otomobil Sporları, Rafting, Sualtı Sporları, Triatlon, Yelken, Yüzme | Tur/interval sayacı | Tur, süre, mesafe, isteğe bağlı frekans | Mesafe ve süre kartları | Branş + çalışma + mesafe + birim | Tekrar sayısı çalışma tanımıyla açık bağlanmıyor |
| Boks, Eskrim, Güreş, Judo, Karate, Kick Boks, Muaythai, Taekwondo, Wushu Kung Fu, Badminton, Masa Tenisi, Tenis | Ralli/raund sayacı | Ralli, kazandıran hareket, basit hata | Ralli ve kazandıran hareket | Branş + çalışma türü | Tenis pilotu için deneme/çalışma türü semantiği yetersiz |
| Basketbol, Bilardo, Bocce-Bowling-Dart, Buz Hokeyi, Curling, Futbol, Golf, Görme Engelliler, Hentbol, Hokey, İşitme Engelliler, Modern Pentatlon, Özel Sporcular, Ragbi, Su Topu, Voleybol | Deneme sayacı | Çalışma, başarılı, hata, toplam, oran | Başarı oranı | Branş + çalışma | Kaynak/kulüp ve gelişim görünümü yok |

Bu matris “araç mevcut” ile “branş hazır”ı ayırır. Faz 5’te bir branş ancak başlangıç, ölçüm, bitiş, sonuç ve gelişim yolu birlikte doğrulanırsa hazır sayılır.

## Mevcut akış değerlendirmesi

| Ekran/akış | Karar | Gerekçe |
|---|---|---|
| `MyTrainingScreen` | Geliştir | Normal giriş, geçmiş, kod ve aktif oturuma dönüş var; ana eylem hiyerarşisi ve kulüpsüz platform şablonları eksik |
| `SmartSportScopeBar` | Geliştir | Tek/çok branş davranışı var; antrenör kulüp/branş/takım zinciri ve bağlam sıfırlama güvencesi eksik |
| `ProtocolListScreen` | Geliştir | Branşa göre filtre ve başlatma var; takım/grup seçimi ile açık oturum özeti eksik |
| `TrainingSessionScreen` | Geliştir | Yedi araç, aktif oturum, taslak koruma ve notlar var; aktif sporcu güvenli seçimi ve kaynak/kulüp başlığı eksik |
| `SessionResultScreen` | Geliştir | Kilit ve branşa uygun özet var; sporcuya yönelik sonuç, kaynak/kulüp/antrenör bilgisi ve paylaşım durumu eksik |
| `DevelopmentReportScreen` | Geliştir | Yeni bağımsız ekran açmadan önce mevcut rapora antrenman gelişim bölümü eklenebilir |
| `GuardianHomeScreen` | Geliştir | Çocuk seçimi ve rapor girişi var; branş/kaynak filtreli paylaşılan antrenman sonuçları eksik |
| Ayrı “Gelişim” ekranı | Şimdilik gerekli değil | Mevcut gelişim raporu normal gezinmeye bağlı; önce genişletme daha düşük maliyetli ve daha tutarlı |

## Seçilen yaklaşım

### Seçenek A — Mevcut antrenman motorunu genişletmek (seçildi)

Değişmez protokol/oturum kimliğini korur; eksik bağlam alanlarını RPC çıktıları ve küçük modellerle tamamlar. Yedi arketip ve mevcut ekranlar yeniden kullanılır. En düşük migration ve regresyon riski budur.

### Seçenek B — Her branş için ayrı tablo ve ekran

Branş dili daha serbest olur fakat 60 ayrı sözleşme, RLS ve ekran üretir; mevcut ortak motoru çoğaltır. Bakım ve yetki riski nedeniyle reddedildi.

### Seçenek C — Tüm ilerlemeyi mevcut performans testi tablolarına çevirmek

Gelişim raporunu kolaylaştırır ancak canlı oturum, kaynak, kilit ve grup katılımcısı anlamlarını kaybeder. Antrenman ve test farklı kullanım amaçları olduğundan reddedildi.

## Hedef mimari

- Oturum başlangıcı `TrainingLaunchContext` benzeri küçük, UI-bağımsız bir değerle branş, kaynak, kulüp, takım ve sporcu kapsamını taşır.
- Sunucu oturum/protokol ilişkisini geçmişin branş kaynağı olarak korur. Eksik eski kayıtta `sport_code` boş gösterilir; güncel profilden tahmin edilmez.
- Geçmiş RPC’si mevcut imzayı koruyarak kulüp ve mümkünse başlatan antrenörün yalnızca gösterim için gerekli alanlarını döndürür.
- Platform şablonları bireysel sporcu için kulüp gerektirmeyen ayrı bir veri sağlayıcısından okunur; kulüp özel şablonları yalnız o kulüp bağlamında eklenir.
- Antrenör başlatma sırası: aktif kulüp → yetkili branş → takım/grup veya birey → şablon → özet → başlat.
- Özel antrenör notu ile paylaşılan geri bildirim ayrı veri alanı/RPC olur. Özel not hiçbir sporcu/veli sorgusuna girmez.
- Gelişim karşılaştırması ham setleri yalnız aynı branş, arketip ve çalışma anahtarında toplar. Arketipe özgü ek anahtar yoksa karşılaştırma yerine son ölçümler listelenir.
- Veli yalnız açıkça paylaşılmış antrenörlü sonuçları görür. Bireysel sonuçları paylaşmak bu çalışma kapsamında otomatikleştirilmez.

## Kabul dışı

- Resmi müsabaka protokollerini antrenman ölçümüne dönüştürmek.
- Supabase Flutter v3’e veya başka bağımlılıklara yükseltmek.
- Üretime bağlanmak, migration uygulamak veya dağıtım yapmak.
- Eski kaydı güncel profil/üyelik branşından tahmin ederek yeniden sınıflandırmak.
- Veliye ya da antrenöre bireysel kayıtları varsayılan olarak açmak.

## Doğrulama stratejisi

Her faz önce başarısız regresyon testiyle başlar. Dart biçimi, etkilenen paketlerde analiz ve testler; SQL sözleşmeleri için `tools` testleri çalıştırılır. Dar ekran/büyük yazı/koyu tema widget testleri korunur. Yerel Supabase mevcut ve açıkça yapılandırılmış değilse SQL uzaktan uygulanmaz; migration statik sözleşme testleriyle doğrulanır.
