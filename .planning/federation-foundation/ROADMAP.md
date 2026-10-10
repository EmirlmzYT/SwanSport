# Federasyon / resmi sportif kayıt — kilitli sözleşme

2026-10-09. Faz A ve dar Faz B RPC temeli yerelde uygulandı. Faz C1 kimlik/üyelik sunucu kapısı yerelde uygulandı. C2 ve D–E plandır.
Mevcut 0077–0093 kullanıcı/AGY/Codex çalışmaları nedeniyle Faz A sırası 0094–0096, Faz B 0097.
Duyuru kanalı kurum değildir. Resmi veri federasyon göreviyle, kulüp gelişimi kulüple yazılır.
Platform yöneticiliği resmi yazma yetkisi değildir; ayrı, branş/il/görev/süre kapsamlı atama gerekir.

## Faz A — yerel temel

Mevcut sports/profile_credentials/athletes/guardians/teams/organizations/org_matches/org_participants/athlete_achievements kullanılır.
0094 kurum/ofis/atama, faaliyet yılı, tescil, kadro/sonuç revizyonu, transfer/itiraz ve veli yayın tercihi sağlar.
0095 eski yazma yollarını tetikleyiciyle sınırlar. 0096 çevrimiçi RPC sözleşmesidir.
Misafir grant, ekran, konsol masası, events kopyası, push/deploy yok.
Faaliyet yılı club seasons değildir. athletes.club_id NOT NULL, profile_id nullable kalır.
Sonuç protokolü ortak JSON allowlist'idir; branş başına yeni maç tablosu açılmaz.

## Faz B — yayın anahtarı ve genel RPC allowlist (yerelde uygulandı)

- 0097: federation_publish_program(p_org,p_public), yalnız program_publisher branş/il/süre yetkisi ve audit ile resmi programın is_public tercihini değiştirir. Varsayılan kapalı kalır, otomatik yayın yok.
- public_sport_programs/public_program_fixture/public_program_result yalnız official=true ve is_public=true kayıtları döndürür. Tabloya anon SELECT yok; PUBLIC execute kapalı.
- Sonuç protokolü alan alan yeniden kurulur. score/sets yalnız sayılar; time/rank yalnız sonuç girdilerinin name/value/placement alanları. Athlete UUID, lisans, TCKN, fotoğraf, tam kadro ve özel sportif/mali veriler yok.
- 0098 ile yalnız çocuk/bilinmeyen doğum için canlı allowed=true ve ret olmaması gerekir; aksi halde sporcu yazılır. Reşit ve aynı branşta kayıtlı kişinin adı dönebilir. İzinli isimde de UUID verilmez.
- Fikstür yeri müsabaka alanıdır; özel canlı konum değildir. Yasal kulüp adı korunur. Etkinlik davetlisi ayrı bir Faz E yetkisidir.
- 27 SQL (16 A + 11 B), 20 Dart testi geçti. Authenticated kulüp tablo/maç akışları regresyonla korundu. Canlı API ve tüm üretim zinciri UAT yapılmadı; sınırlar docs/federation-public-verification.md içinde.
- Yeni ekran yok. C1 sunucu kapısı aşağıda kaydedildi; C2 ve D–E başlamadı.

## Faz C — hesap bekleme odası (C1 yerel sunucu temeli uygulandı)

C1: 0099/0100, mevcut belge sisteminde tekil doğrulanmış TCKN, eski aktif üye geçişi, branş/süre/veli kontrolleri ve eski üyelik/davet RPC kapıları. 34 kimlik/temel SQL, 28 public SQL, 679 Flutter testi geçti; değişen Dart analizi temiz. Ekran yok. Kanıt: docs/identity-membership-verification.md. 0009 kulüpsüz eski satır bırakmışsa 0100 veri değiştirmeden durur.

C2 arayüz bağlantısı 2026-10-10 kullanıcı göreviyle yerelde uygulandı: misafir keşfi, hesap/kimlik işlem kapıları, mevcut kimlik belgesi yükleme ve spor belgesi expiry alanı. Kanıt: docs/guest-identity-verification.md. Antrenör okuma RLS daraltması ve hesap silme yaşam döngüsü henüz uygulanmadı. Aşağıdaki daha geniş Faz C maddelerinin tamamlandığı iddia edilmez.

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

## 2026-10-09 Faz B uygulama kaydı

Kullanıcının daraltılmış kapsamıyla 0097: federation_publish_program ve üç public_* RPC yerelde uygulandı. Yeni ekran/tablo yok. 27 SQL ve 20 dar Dart testi geçti; genel analiz 0 hata/5 önceki uyarı. Kanıt: docs/federation-public-verification.md. Faz B bölümündeki daha geniş guest ürün ekranları yapılmadı; C–E başlamadı. Push/deploy/canlı SQL yok.
