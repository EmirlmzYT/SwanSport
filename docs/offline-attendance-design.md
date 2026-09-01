# Çevrimdışı Yoklama — Teknik Tasarım

**Durum:** tasarım. Uygulanmadı, yayınlanmadı.
**Tarih:** 1 Eylül 2026

Plan bu özelliği bilerek doğrudan yayınlatmıyor: önce aşağıdaki soruların
cevaplanmasını istiyor. Bu belge onları cevaplıyor ve **uygulanmadan önce ne
karar verilmesi gerektiğini** ayrıca işaretliyor.

---

## Problem

Antrenman salonlarında ve sahalarda internet çoğu zaman yok. Antrenör
yoklamayı alıyor, "Kaydet" diyor, istek düşüyor ve **işaretlediği her şey
kayboluyor.** Bugünkü ekran bunu kurtarmıyor: `_marks` yalnızca bellekte
duruyor, ekran kapanınca gidiyor.

Bu, kaybı en pahalı olan veri: 18 kişilik bir kadroyu ikinci kez işaretlemek
kimsenin yapmak istemediği bir iş ve yapılmayınca o günün katılımı hiç
kaydedilmiyor. Üstüne kurulan her şey (katılım oranı, gelişim, başarılar)
eksik veriyle çalışıyor.

---

## 1. Yerel işlem kuyruğu nasıl tutulacak?

**Karar: `shared_preferences` değil, yapılandırılmış yerel depo.**

`shared_preferences` zaten bağımlılık ve tanıtım bayrağı için kullanılıyor,
ama burada uygun değil: kuyruk sıralı, sorgulanabilir ve kısmi güncellenebilir
olmalı. Anahtar-değer deposunda bunu yapmak, JSON'u her yazışta baştan
serileştirmek demek ve 18 satırlık bir yoklamada bile yarış durumu üretiyor.

**Öneri:** `drift` (SQLite). Gerekçesi:
- Sıralı okuma ve `where` desteği var.
- Şema değişikliği migration'la yönetiliyor; kuyruk biçimi değişince eski
  kayıtlar okunamaz hâle gelmiyor.
- Flutter'da yaygın ve bakımlı.

**Alternatif:** `sqflite` doğrudan. Daha az bağımlılık, daha çok elle SQL.

**Karar verilecek:** yeni bir bağımlılık eklemeye değer mi. Değmezse
`sqflite`; o da istenmezse kuyruk tek bir JSON dosyasında (`path_provider`
zaten var) tutulabilir ama o zaman kısmi güncelleme yerine dosyanın tamamı
yeniden yazılır.

### Kuyruk kaydının şekli

| Alan | Ne için |
|---|---|
| `op_id` | İstemcide üretilen UUID — idempotency anahtarı |
| `event_id` | Hangi antrenman |
| `athlete_id` | Kim |
| `status` | present / absent / excused / late |
| `marked_at` | **Cihazda işaretlendiği an** — sunucuya ulaştığı an değil |
| `attempts` | Kaç kez denendi |
| `last_error` | Son hata; kullanıcıya gösterilecek |

---

## 2. Idempotency anahtarı ne olacak?

**Karar: `op_id` (istemcide üretilen UUID), `(event_id, athlete_id)` değil.**

İkisi farklı şeyi çözüyor:

- `(event_id, athlete_id)` **doğal anahtar** — aynı sporcunun aynı antrenmanda
  tek yoklaması olmalı. Bu zaten `unique (event_id, athlete_id)` ile korunuyor.
- `op_id` **işlem kimliği** — aynı işlemin iki kez gönderilmesini ayırt eder.

Yalnızca doğal anahtara güvenmek yetmiyor: ağ kesilip istek iki kez gidince
ikincisi `upsert` ile birinciyi ezer. Ezmesi genelde zararsız ama **denetim
kaydı iki satır** yazar ve "kim ne zaman değiştirdi" bozulur.

**Yapılacak:** `attendance` tablosuna `op_id uuid` sütunu ve
`unique (op_id)` kısmi indeksi. Sunucu aynı `op_id`'yi ikinci kez görürse
sessizce başarı döner, yeni denetim satırı yazmaz.

---

## 3. Aynı sporcu için çakışan iki kayıt nasıl çözülecek?

**Karar: `marked_at` kazanır, `created_at` değil.**

Senaryo: antrenör telefonda "geldi" işaretliyor (10:05, çevrimdışı). Yardımcı
antrenör tabletten "gelmedi" işaretliyor (10:12, çevrimiçi — hemen gidiyor).
Ağ 10:20'de gelince ilk cihazın isteği sunucuya ulaşıyor.

Sunucuya varış sırasına göre **10:05'teki işaret 10:12'dekini eziyor** — yani
eski karar yeniyi bozuyor. Doğrusu, cihazda işaretlendiği an kazanmalı.

**Yapılacak:** `attendance.marked_at timestamptz` sütunu. Upsert koşulu:

```sql
on conflict (event_id, athlete_id) do update
  set status = excluded.status, marked_at = excluded.marked_at
  where attendance.marked_at is null
     or excluded.marked_at > attendance.marked_at;
```

**Bilinen sınır:** cihaz saatleri güvenilir değil. Saati yanlış kurulmuş bir
telefon, kendi kaydını hep kazandırır. Kabul edilebilir çünkü alternatif
(sunucu saati) yukarıdaki senaryoyu ters çeviriyor. Sapma büyükse
(örn. 24 saatten fazla) sunucu reddetmeli.

---

## 4. Bağlantı geldiğinde hangi işlem kazanır?

Yukarıdaki kural: **en son işaretlenen.** Kuyruk `marked_at` sırasıyla
gönderiliyor ama sıra garanti değil (paralel istek, kısmi başarı), o yüzden
kararı sunucudaki `where` veriyor — istemcinin gönderme sırası önemsiz.

---

## 5. Sunucu reddederse kullanıcıya nasıl gösterilecek?

**Karar: sessizce yutmak yok.** Bu projede push zincirinin üç katmanında hata
yutuldu ve aylarca görünmedi; aynı hatayı yoklamada yapmak çok daha pahalı
olur, çünkü kaybolan şey veri.

Davranış:

| Durum | Ne olur |
|---|---|
| Ağ yok | Kuyrukta bekler, ekranda "3 yoklama bekliyor" rozeti |
| Sunucu 4xx (yetki, geçersiz) | Kuyruktan **çıkarılır**, kullanıcıya sebebi gösterilir |
| Sunucu 5xx / zaman aşımı | Kuyrukta kalır, artan aralıkla tekrar denenir |
| 5 denemede geçmedi | Kuyrukta kalır ama otomatik denenmez; kullanıcı elle tetikler |

Bekleyen kuyruk **Ana Sayfa'da görünür** — telefonu cebine koyup unutan
antrenör, ertesi gün açtığında bekleyen yoklamayı görmeli.

---

## 6. Denetim izi nasıl korunacak?

`attendance_audit_log` zaten var ve `previous_status`, `actor_profile_id`,
`created_at` tutuyor. Çevrimdışı yazmada iki ek gerekiyor:

- `marked_at` da yazılmalı — denetim "ne zaman kaydedildi"yi değil "ne zaman
  işaretlendi"yi göstermeli.
- Aynı `op_id` ikinci kez gelirse denetim satırı **yazılmamalı**, yoksa tek bir
  işaret birden çok kez yapılmış görünür.

---

## 7. RSVP ön-dolumuyla çelişirse ne olur?

Çelişmiyor: ön-dolum yalnızca **ekranın açılış hâli**, kaydedilmiş bir veri
değil. Antrenör dokunmadıysa kuyruğa hiçbir şey girmiyor.

**Ama bir tuzak var:** bugün ekran RSVP'den ön-doluyor ve antrenör hiçbir şeye
dokunmadan "Kaydet" derse, RSVP tahminleri gerçek yoklama olarak kaydediliyor.
Çevrimiçiyken bu görünür bir tercih; çevrimdışıyken kuyruğa girip saatler
sonra sessizce uygulanıyor.

**Karar:** çevrimdışı kuyruğa yalnızca **antrenörün dokunduğu** satırlar
girer. Dokunulmamış ön-dolum kaydedilmez. Bu, ekranın "hangi satıra
dokunuldu" bilgisini ayrıca tutmasını gerektiriyor.

---

## Uygulanmadan önce karar verilecekler

1. **Yerel depo:** `drift` mi, `sqflite` mi, JSON dosyası mı? (bağımlılık
   kararı)
2. **Saat sapması sınırı:** sunucu hangi eşikten sonra `marked_at`'i reddetsin?
3. **Kuyruk ömrü:** bir hafta gönderilememiş yoklama ne olsun — silinsin mi,
   sonsuza kadar mı beklesin?
4. **Çok cihazlı antrenör:** aynı kişi iki cihazdan işaretlerse kuyruklar
   birbirini görmüyor; `marked_at` kuralı çözüyor ama kullanıcı iki farklı
   "bekleyen" listesi görecek.

---

## Şema değişikliği özeti (uygulanırsa)

```sql
alter table public.attendance
  add column if not exists op_id     uuid,
  add column if not exists marked_at timestamptz;

create unique index if not exists idx_attendance_op
  on public.attendance (op_id) where op_id is not null;
```

Artı `save_attendance_batch(p_ops jsonb)` RPC'si: kuyruğu tek çağrıda alır,
`op_id` tekilliğini ve `marked_at` karşılaştırmasını sunucuda uygular.

---

## Neden şimdi uygulanmıyor

Plan böyle istiyor ve gerekçesi sağlam: çevrimdışı yazma, **yanlış yapıldığında
veri kaybettiren** bir özellik. Bu depoda benzer bir şey zaten yaşandı —
`saveAttendance` `event_id` yazmıyordu ve aylarca kimse fark etmedi, çünkü
ekran çalışıyor görünüyordu.

Yukarıdaki dört karar verilmeden ve testler yazılmadan açılmamalı.
