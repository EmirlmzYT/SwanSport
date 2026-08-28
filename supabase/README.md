# SwanSport — veritabanı düzeni

Tek kaynak: **`migrations/`**. Şema değişikliği buraya yeni bir numaralı dosya
eklenerek yapılır. Başka hiçbir yerde şema tanımı tutulmaz.

## Klasörler

| Klasör | İçerik |
|---|---|
| `migrations/` | Sıralı şema değişiklikleri. **Tek yetkili kaynak.** |
| `seed/` | Örnek/demo veri. Şema tanımlamaz. |
| `legacy/` | Arşiv. Çalıştırılmaz — aşağıya bakın. |
| `policies/`, `functions/`, `tests/` | Notlar ve yardımcı dosyalar. |

## Sıfırdan kurulum

`migrations/` altındaki dosyaları **numara sırasıyla** Supabase SQL editöründe
çalıştır:

```
0001_foundation.sql          temel tablolar
0002_rls_policies.sql        RLS ve yetki yardımcıları
0003_extended.sql            duyuru, etkinlik, fatura, yoklama…
0004_roles_verification.sql  kimlik doğrulama, kulüp onayı
0005 … 0028                  faz faz eklenen özellikler
```

Hepsi **idempotent**: aynı dosyayı ikinci kez çalıştırmak veri bozmaz.

## Mevcut veritabanını güncelleme

Yalnızca **henüz çalıştırmadığın** numaraları sırayla çalıştır. Hangi
numaraya kadar geldiğini bilmiyorsan hepsini baştan çalıştırabilirsin;
idempotent oldukları için zarar vermez, yalnızca zaman alır.

## Yeni değişiklik ekleme

1. `migrations/` içindeki en büyük numarayı bul, bir fazlasıyla yeni dosya aç:
   `0029_kisa_aciklama.sql`
2. Dosyayı idempotent yaz:
   - `create table if not exists`
   - `alter table … add column if not exists`
   - `create or replace function`
   - `drop policy if exists` + `create policy`
3. Yeni tablo eklediysen **RLS yaz**. Arayüzde düğme gizlemek güvenlik değildir.
4. Yazma yapan `security definer` fonksiyonlarda yetkiyi fonksiyonun içinde
   doğrula (`is_club_staff`, `is_platform_admin`, `auth.uid()` …).
5. Kullanıcı tarafından çağrılmaması gereken bakım fonksiyonlarının iznini
   kaldır — örnek: `0028_hardening.sql`.

## Demo verisi

```sql
select public.seed_demo_data('senin@mailin.com');
select public.clear_demo_data('senin@mailin.com');
```

Dosya: `seed/demo_data.sql`. SQL editörü `postgres` rolüyle çalıştığı için
`auth.uid()` orada boştur; hesap e-postayla verilir.

## `legacy/` neden duruyor?

Silinmedi çünkü hangi veritabanının hangi dosyayla kurulduğu geçmişte
belirsizleşti; arşiv, eski bir kurulumu teşhis etmek gerekirse lazım olur.

| Dosya | Neydi |
|---|---|
| `SETUP.sql` | `0001`–`0004` migration'larının birleşik hali |
| `apply_all.sql` | Eski toplu kurulum betiği |
| `ALL_UPDATES.sql` | 8 fazın birleştirilmiş kopyası (üretilmişti) |
| `EKOSISTEM.sql` | 7 fazın birleştirilmiş kopyası (üretilmişti) |
| `_full_reset.sql`, `_reset_preamble.sql` | Veritabanını sıfırlayan betikler |
| `BOOTSTRAP.sql` | İlk platform yöneticisi atama notu |

**Bu klasördeki hiçbir dosyayı çalıştırma.** Özellikle `_full_reset.sql`
tabloları düşürür. İçerikleri `migrations/` altında zaten var.
