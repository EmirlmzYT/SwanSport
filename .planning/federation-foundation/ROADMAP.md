# Federasyon / resmi sportif kayıt — kilitli sözleşme

2026-10-09. Yalnız Faz A uygulanır. Faz B–E aşağıda plandır; kodlanmaz.
Mevcut 0077–0093 kullanıcı/AGY/Codex çalışmaları nedeniyle yeni sıra 0094–0096.
Duyuru kanalı kurum değildir. Resmi veri federasyon göreviyle, kulüp gelişimi kulüple yazılır.
Platform yöneticiliği resmi yazma yetkisi değildir; ayrı, branş/il/görev/süre kapsamlı atama gerekir.

## Faz A — yerel temel

Mevcut sports/profile_credentials/athletes/guardians/teams/organizations/org_matches/org_participants/athlete_achievements kullanılır.
0094 kurum/ofis/atama, faaliyet yılı, tescil, kadro/sonuç revizyonu, transfer/itiraz ve veli yayın tercihi sağlar.
0095 eski yazma yollarını tetikleyiciyle sınırlar. 0096 çevrimiçi RPC sözleşmesidir.
Misafir grant, ekran, konsol masası, events kopyası, push/deploy yok.
Faaliyet yılı club seasons değildir. athletes.club_id NOT NULL, profile_id nullable kalır.
Sonuç protokolü ortak JSON allowlist'idir; branş başına yeni maç tablosu açılmaz.

## Faz B — misafir allowlist (uygulanmadı)

- Yalnız yayımlanmış faaliyet programı, fikstür, sonuç için ayrı salt okunur RPC.
- Allowlist alanları açıkça seçilir; hiçbir SELECT *, güvenlik-definer görünüm veya athletes anon SELECT yok.
- Ad/sağlık/TCKN/kadro/aidat/konum guest payload'ına girmez. Çocukta kategori/kulüp/sonuç korunur.
- Yayın tercihi her okumada hesaplanır, önbellek/harici kopya isimleri geri açamaz.
- Etkinlik davetlisi bu misafirden ayrı bir yetki türüdür.
- Ön kapı: gerçek anon rolü ile tüm tablo/view/RPC grant taraması; mevcut athlete_public ve definer RPC'ler ayrıca incelenir.
- Testler: yayımlanmamış kayıt yok, izin iptali anında isim yok, guardian silinmesi, aynı çocuğun hesap olmadan korunması, türetilmiş isim sızıntısı.

## Faz C — hesap bekleme odası (uygulanmadı)

- Mevcut oturum/giriş akışı şimdi değiştirilmez. Sonra hesap/kimlik/branş kapıları ayrı durumlar olarak modellenir.
- Tek doğrulanmış TCKN / tek hesap; profiles.national_id beyanı doğrulanmış kimlik sayılamaz.
- Branş kimliği kulüp üyeliği, kadro, antrenör ataması ve ferdi katılımın sunucu ön koşulu olur.
- Veli kimlik+davet, lisans istemez. Çocuk veli bağı olmadan tam aktif olmaz.
- Yeni belge başvurusunda gerçek expires_on girilir; mevcut süresiz onaylı satırlar korunur.
- Giriş/başvuru ekranları mevcut yeni expiry API'sine bağlanır; bu Faz A'da ekran değiştirilmez.
- Antrenör iç sportif veri yetkisi atanmış takım ve branşa daraltılır; mevcut kulüp-geneli RLS ve definer okuma yolları birlikte değiştirilir.
- Hesap silme: mesaj/sağlık/belge/konum ve Storage nesneleri için mevcut polymorphic kayıt/FK engelleri dahil gerçek lifecycle testi; resmi sonuçta yalnız kalıcı sporcu anahtarı kalır.
- Testler: eski kullanıcı geçişi, doğrulanmamış graph yazıları, farklı branş kademe, süresi dolmuş belge, nullable profile, muhasebeci izolasyonu, atanmamış takım.

## Faz D — konsol federasyon masası (uygulanmadı)

- Yalnız konsol: ofis/atama, faaliyet yılı, kulüp tescili, program, katılımcı, kadro revizyonu, sonuç protokolü, derece, transfer, itiraz ve audit.
- SwanAccess yeni branşlı API ve görev dizisini kullanır; telefon için resmi yazma ekranı açılmaz.
- Atama yönetimi platform kurulumudur. Platform yöneticisi sonuç/tescil/lisans yazarken ayrıca doğru atamayı taşır.
- Yerel cihaz kuyruğu ve otomatik resmi offline tekrar yok. Beklenen sürüm uyuşmazlığı açık gösterilir.
- Branş motorunun yaş/cinsiyet/zorunlu engel sınıfı kategorileri ve gerçek müsabaka protokol kuralları tamamlanır; yeni federasyon kategoriden türetilmez.
- Mevcut motor yalnız antrenman/okçuluk sözlüğüdür; resmi kategori/yarış protokolü motoru varmış gibi davranılmaz.
- Yazma arayüzü açılmadan branch-specific doğrulama ve yalnız gerekli kategorik veri erişimi değerlendirilir.
- Yayın bayrağı gerekiyorsa beş yüzey+SSS birlikte, test edenler açılmadan yardım kapısı.

## Faz E — okumalar ve ferdi kayıt (uygulanmadı)

- Takvim kulüp events ve resmi org_matches üzerinde sorgu/projeksiyon olur, resmi maç events'e çoğaltılmaz.
- Özgeçmiş iki ayrı bölüm: federation_result resmi kayıtlar; goal/attendance_*/manual kulüp gelişimi ve resmi değil etiketi.
- verified=true tek başına resmi değildir. Revizyon zincirinin son hali gösterilir, geçmiş erişilebilir kalır.
- athletes.club_id ancak bu fazın bağımlılık analizi/testleriyle nullable yapılır. Mevcut hesapsız çocuklar ve club_id sözleşmeleri korunur.
- Süreli tek etkinlik davetlisi ayrı kapsam; kadro/aidat/iç takım verisi yok.
- Transferde eski mali/yoklama sahipliği, çok branşta tek kulüp ilkesi ve mevcut ana club_id projeksiyonu için uçtan uca test.

## Canlıya geçiş kapıları

Faz A yerel test kanıtı canlı kuruluma eşit değildir. Migration'lar dosya başına ayrı işlem ve 15s lock_timeout ile uygulanır.
İki gerçek PostgreSQL oturumunda atama iptali/yazma, roster/result ve kimlik yarışları ayrıca doğrulanır.
Kullanıcı talimatıyla bu oturumda push/deploy ve canlı SQL yok.
