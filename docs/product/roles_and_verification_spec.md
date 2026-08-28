# SwanSport — Roller & Doğrulama Spec (yaşayan doküman)

> Durum: **taslak v0.1** — birlikte detaylandırılıyor. Kod yazımı, bu spec
> oturunca başlayacak. `DETAYLANDIRILACAK` etiketli yerler senin ekleyeceğin
> kararları bekliyor.

**Temel kararlar (onaylandı):**
- **Doğrulayıcı = Platform Yöneticisi (sen).** Tüm kulüp ve birey evraklarını
  inceleyip onaylayan tek merci şimdilik sensin.
- Önce spec, sonra kod.

---

## 1. Roller (taksonomi)

Her rolün: adı · açıklaması · **evrak doğrulaması gerekir mi** · temel yetkileri.

### Platform
| Rol | Açıklama | Doğrulama | Kapsam |
|-----|----------|-----------|--------|
| **Platform Yöneticisi** | Uygulamanın süper-admini (sen). Kulüp başvurularını ve birey evraklarını onaylar. | — | Kulüp-üstü |
| **Federasyon/İl Temsilcisi** | Şimdilik tanımlı; onay yetkisi yok. **İleride** doğrulama yetkisi platformdan buraya devredilebilir. | — | Bölge/il |

### Kulüp yönetimi
| Rol | Açıklama | Doğrulama | Notlar |
|-----|----------|-----------|--------|
| **Kulüp Yöneticisi** | Kulübü kurar ve yönetir. | ✅ Kulüp resmi evrakları | Kulüp ancak evrak onayından sonra aktif olur |
| **Üye** | Temel üyelik, belge gerektirmez. | ❌ | En düşük yetki |

### Antrenörler (kademeli) — hepsi evrak (kademe belgesi) ister
| Rol | Karşılığı |
|-----|-----------|
| **1. Kademe** | Yardımcı Antrenör |
| **2. Kademe** | Antrenör |
| **3. Kademe** | Kıdemli Antrenör |
| **4. Kademe** | Baş Antrenör |
| **5. Kademe** | Teknik Direktör |

> Kademe yönü: **büyük sayı = üst kademe** (5 = Teknik Direktör en üst). ✅ Onaylandı.

### Sporcular
| Rol | Açıklama | Doğrulama |
|-----|----------|-----------|
| **Lisanslı Sporcu** | Federasyon lisanslı, takıma bağlı. | ✅ Lisans belgesi |
| **Ferdi Sporcu** | Bireysel yarışan, **kulübe bağlı değil** (bağımsız). Kendi lisansını doğrulatır. | ✅ Ferdi lisans/belge |

> ⚠️ **Şema etkisi:** Ferdi sporcu kulüpsüz olduğundan mevcut `athletes.club_id`
> (zorunlu) modeli yetmiyor. Ferdi sporcular için ayrı bir yol gerekir: ya
> `club_id` nullable + `is_individual` bayrağı, ya da ayrı `individual_athletes`
> yapısı. `DETAYLANDIRILACAK` (kesin karar kod aşamasında).

### Aile
| Rol | Açıklama | Doğrulama |
|-----|----------|-----------|
| **Veli** | Bir sporcuya **davet kodu ile** bağlanır. | ❌ (evrak gerekmez) |

---

## 2. Evrak doğrulama akışı (verification)

**Merci:** Platform Yöneticisi.

**Durumlar:** `taslak → beklemede → inceleniyor → onaylı / reddedildi`
(reddedilirse: sebep + yeniden yükleme)

**Akış:**
1. Kullanıcı rolüne uygun evrak(lar)ı yükler (Supabase Storage).
2. Bir **doğrulama talebi** oluşur (`beklemede`).
3. Platform Yöneticisi inceler → **onay** (rol/kulüp aktifleşir) veya **ret** (not ile).
4. Onaylanınca kişi/kulüp "doğrulanmış" statüsüne geçer.

**Rol bazında evrak türleri (ilk taslak — genişletilecek):**
| Rol | Beklenen evraklar |
|-----|-------------------|
| Kulüp Yöneticisi | **Kulüp tescil belgesi** + **federasyon kayıt belgesi** (onaylandı). Ayrıca kurucunun **≥2. kademe antrenör belgesi**. |
| Antrenör (kademe) | **Kademe belgesi** + **kimlik (TC)** (onaylandı) |
| Lisanslı Sporcu | **Federasyon lisansı** (onaylandı). 18 yaş altıysa ayrıca **veli bağı zorunlu** (davet kodu ile). |
| Ferdi Sporcu | Ferdi lisans / yeterlilik belgesi |
| Veli | Evrak yok — sporcuya **davet kodu** ile bağlanır |

---

## 3. Kulüp kurma akışı (gerçek kulüp şartı)

> "Kulüp kuracak yöneticinin gerçek hayatta da kulübü olmalı; aynı evrakları
> yükleyip doğrulatmalı."

**Kulüp statüsü:** `beklemede → aktif` (ayrıca `askıda / reddedildi`)

> ⚠️ **Kurucu şartı (onaylandı):** Kulübü kuran kişi **en az 2. kademe antrenör**
> olmalı (2. kademe ve üstü). Yani kulüp kurmak için hem ≥2. kademe belgesi hem de
> kulüp resmi evrakları doğrulanmalı.

1. Yönetici (≥2. kademe) kulüp başvurusu yapar + resmi evrakları yükler.
2. Kulüp **`beklemede`** oluşur (henüz operasyonel değil).
3. Platform Yöneticisi evrakları inceler → **onay** → kulüp **`aktif`**.
4. **Beklemede iken kulüp TAMAMEN KİLİTLİ (onaylandı):** hiçbir işlem yapılamaz;
   yalnızca başvuru/evrak durumu ekranı görünür. Onay gelince tüm modüller açılır.

---

## 4. Hiyerarşi & uygunluk kuralları

- **Kulüp kurma eşiği (onaylandı):** Kulüp yalnızca **≥2. kademe** antrenör
  tarafından kurulabilir.
- **1. kademe bağımlılığı (onaylandı):** 1. kademe (Yardımcı Antrenör) tek başına
  olamaz; bir **2. kademe** antrenöre **bağlı** kaydedilir (amiri/süpervizörü olur).
  - 1→2 bağının kapsamı: **kulüp düzeyinde** (onaylandı) — kulüpteki herhangi bir 2.+ kademe yeterli.
- **Diğer kademeler:** Katı bağımlılık şart değil, ancak hiyerarşi vardır
  (5 > 4 > 3 > 2 > 1).
- **Çoklu rol / çoklu kulüp (onaylandı):** Bir kişi aynı anda **birden fazla rol**
  taşıyabilir (ör. hem antrenör hem veli). **Antrenör birden fazla kulüpte**
  çalışabilir. **Sporcu tek kulübe** bağlıdır (ferdi sporcu ise kulüpsüz).
- **Doğrulama kişiye aittir, kulüpten bağımsız (onaylandı):**
  1. Kişi (antrenör/sporcu) belgesini **kendi başına platforma** onaylatır →
     "doğrulanmış 2. kademe antrenör" gibi bir **profil kimliği** kazanır.
  2. Doğrulandıktan sonra kulüp eşleşmesi **iki yönlü**:
     - Kişi kulübe **başvurur**, veya
     - Kulüp kişiye **teklif** sunar → karşılıklı kabul → üyelik oluşur.
  - Üyelik, kişinin **zaten doğrulanmış** kademesini/lisansını referans alır
    (kulüp yeniden doğrulamaz).
- **Sporcu–Veli eşleşmesi (onaylandı):** 18 yaş altı sporcu için **veli zorunlu** —
  bir veli (davet kodu ile) bağlanmadan sporcu tam aktif olmaz / lisans onayı
  tamamlanmaz.

---

## 5. Şemaya etkisi (Supabase — plan)

Mevcut `club_role` enum: `club_admin, coach, athlete, parent, official, federation_rep`.
Yeni model için öneri:

- **Roller:** `coach` yerine kademe (ör. `coach_l1..coach_l5`); `athlete` yerine
  `athlete_licensed / athlete_individual`; `member` ekle; `platform_admin` ekle.
- **`clubs.status`** ekle: `pending | active | suspended | rejected`.
- **`documents`** tablosunu doğrulama için genişlet (owner_type, owner_id, doc_type)
  veya ayrı **`verification_documents`** + **`verification_requests`**
  (owner: kulüp/kişi, status, reviewer_id, note).
- **`club_memberships`**'e doğrulama/kademe alanı (`coach_level`, `verified`).
- **RLS:** Platform Yöneticisi her şeyi görür/onaylar; kulüp verisi yalnız aktif
  kulüp üyelerine.

> Not: Detaylar netleşince kesin tablo şeması yazılacak.

---

## 6. Karara bağlananlar (özet)

- ✅ Kademe: 5 = Teknik Direktör en üst.
- ✅ Kulüp yalnızca ≥2. kademe antrenör tarafından kurulur.
- ✅ 1. kademe, bir 2. kademeye bağlı olur; diğer kademelerde hiyerarşi var ama katı bağımlılık yok.
- ✅ Ferdi sporcu bağımsız (kulüpsüz).
- ✅ Veli davet kodu ile bağlanır (evrak yok).
- ✅ Kulüp beklemedeyken tamamen kilitli.
- ✅ Kulüp evrakları: tescil + federasyon kayıt belgesi (+ kurucunun ≥2. kademe belgesi).
- ✅ Doğrulama kişiye ait (platform onaylar); sonra kulüp başvuru/teklif ile eşleşir.
- ✅ Federasyon/İl temsilcisi rolü tanımlı kalır; yetki ileride devredilebilir.

## 7. Kalan açık detaylar (bir sonraki tur)

1. ✅ 1→2 bağı **kulüp düzeyinde** (karara bağlandı).
2. ✅ 18 yaş altı için veli **zorunlu** (karara bağlandı).
3. ✅ Evrak listesi: antrenör = kademe belgesi + kimlik; sporcu = federasyon lisansı (karara bağlandı).
4. ✅ Davet kodu: **tek kullanımlık + süreli** (kullanılınca/süre dolunca geçersiz) — karara bağlandı.
5. ✅ Çoklu rol + antrenör çoklu kulüp; sporcu tek kulüp (karara bağlandı).
6. ✅ Kulüp ↔ antrenör: **karşılıklı onay** — kim başlatırsa başlatsın karşı taraf kabul/ret verir; her iki yön de var (karara bağlandı).
7. _(teknik)_ Ferdi sporcu şema kararı — kod aşamasında ben belirleyeceğim.

**→ Domain kararları tamamlandı. Kalan tek madde teknik (ferdi sporcu şeması), o da kod aşamasında.**
