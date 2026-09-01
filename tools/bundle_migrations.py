"""Bekleyen migration'lari tek dosyada birlestirir.

    python tools/bundle_migrations.py

NEDEN VAR: migration'lar Supabase SQL Editor'e elle yapistiriliyor. Alti
dosyayi tek tek yapistirmak hem yorucu hem sira hatasina acik; bu betik
hepsini `begin`/`commit` arasinda tek dosyada topluyor, boylece bir yerde
hata olursa hicbiri uygulanmiyor.

FILES listesini elle guncelle: hangi migration'larin bekledigini betik
bilemez, o bilgi AGENTS.md'deki durum tablosunda.

Uretilen dosyayi `tools/check_migrations.py` ile denetle.
"""
import io
import os

FILES = [
    "0047_core_loop.sql",
    "0048_tr_search.sql",
    "0049_rpc_authorization.sql",
    "0050_marketplace.sql",
    "0051_marketplace_rpc.sql",
    "0052_blocking_and_market_notify.sql",
]

HEAD = """-- ===========================================================================
-- SwanSport — bekleyen migration'lar, tek dosya
--
-- 0047 → 0052, numara sırasıyla. Supabase SQL Editor'e yapıştır ve çalıştır.
--
-- TEK İŞLEM: hepsi `begin`/`commit` arasında. Bir yerde hata olursa hiçbiri
-- uygulanmıyor — yarım uygulanmış şema, hiç uygulanmamış şemadan çok daha
-- zor toparlanır.
--
-- TEKRAR ÇALIŞTIRILABİLİR: hepsi `create or replace`, `if not exists` ve
-- `drop ... if exists` kullanıyor. Bir kısmını daha önce çalıştırdıysan
-- yeniden çalıştırmak zarar vermez.
--
-- İÇİNDEKİLER
--   0047  Core Loop — antrenman/duyuru/başarı bildirimleri
--         + `push_route`ta kaybolmuş 4 eşlemeyi geri getirir
--   0048  Türkçe arama (tr_fold / tr_contains) + pg_trgm indeksi
--   0049  GÜVENLİK — üç `security definer` RPC'de yetki kontrolü yoktu
--   0050  Pazaryeri şeması: mağazalar, görseller, favoriler, raporlar
--   0051  Pazaryeri RPC'leri: ilan oluşturma, durum, arama
--   0052  GÜVENLİK — engelleme uygulanmıyordu + pazaryeri bildirimleri
-- ===========================================================================

begin;

"""

TAIL = """

commit;

-- ===========================================================================
-- Bittiğinde doğrulama (ayrı çalıştır, işlem dışında):
--
--   select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and proname in ('tr_fold','event_audience','athlete_card','event_roster',
--                      'create_market_listing','search_market_listings',
--                      'is_blocked_between')
--    order by 1;
--
-- Yedi satır dönmeli. Eksik varsa o migration uygulanmamış demektir.
-- ===========================================================================
"""

parts = [HEAD]
for f in FILES:
    src = io.open(os.path.join("supabase/migrations", f), encoding="utf-8").read()
    parts.append(
        "\n-- ---------------------------------------------------------------------------\n"
        f"-- {f}\n"
        "-- ---------------------------------------------------------------------------\n\n"
    )
    parts.append(src.rstrip() + "\n")

parts.append(TAIL)

out = "tools/pending_migrations.sql"
io.open(out, "w", encoding="utf-8").write("".join(parts))
print("olusturuldu:", out)
print("satir:", len("".join(parts).splitlines()))
