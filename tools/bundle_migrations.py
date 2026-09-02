"""Bekleyen migration'lari tek dosyada birlestirir.

    python tools/bundle_migrations.py

NEDEN VAR: migration'lar Supabase SQL Editor'e elle yapistiriliyor. On dort
dosyayi tek tek yapistirmak, birini atlamaya ve yarim uygulanmis bir semaya
acik. Tek dosya + tek islem, ya hepsi ya hicbiri.

SINIRI: bu betik yalnizca birlestirir. Dosyalarin dogrulugunu
`tools/check_migrations.py` denetliyor ve o da yalnizca soz dizimine bakiyor.
"""

import io
import os
import sys

MIGRATIONS = "supabase/migrations"

# Canlida OLMAYAN dosyalar, sirasiyla. 0052'ye kadar olanlar dogrulandi.
FILES = [
    # 0053-0068 CANLIDA (2026-09-02 dogrulandi). Listede yalnizca bekleyenler.
    "0069_faq_and_support.sql",
    "0070_faq_follows_features.sql",
]

HEAD = """-- ===========================================================================
-- SwanSport — bekleyen migration'lar (0069-0070): SSS ve destek
--
-- 0053-0068 CANLIDA (2026-09-02 dogrulandi). Bu dosyada iki migration var:
--   0069  SSS + destek yazismasi
--   0070  SSS OZELLIGI TAKIP ETSIN — yardimsiz yayin yok
--
-- ---------------------------------------------------------------------------
-- KILIT CAKISMASI (40P01 deadlock) YASANDIYSA
--
-- Bu dosya once TEK bir islemdi ve butun kilitler sonuna kadar tutuluyordu.
-- `alter table` AccessExclusiveLock istiyor; ayni anda calisan bir sey
-- (pg_cron isi, acik uygulama sekmesi, PostgREST sema yenilemesi) o tabloyu
-- okuyorsa iki taraf birbirini bekleyip deadlock veriyor.
--
-- Simdi IKI AYRI ISLEM var ve her birinde `lock_timeout` tanimli:
--   * kilit 15 saniyede gelmezse islem TEMIZ SEKILDE dusuyor (55P03),
--     deadlock yerine anlasilir bir hata veriyor
--   * 0067 gecip 0068 duserse yalnizca 0068 tekrar calistirilir
--
-- CALISTIRMADAN ONCE:
--   1. Uygulamayi ve konsolu acik sekmelerde KAPAT (acik sekme sorgu atiyor)
--   2. Hata alirsan bekleyip TEKRAR DENE — deadlock geciciddir
--
-- Hangi tablolarin cakistigini gormek icin (hata mesajindaki sayilarla):
--   select 17294::regclass, 21547::regclass;
--
-- Zamanlanmis isler cakisiyorsa gecici olarak durdurulabilir:
--   select cron.unschedule(jobname) from cron.job
--    where jobname like 'swansport_%';
--   -- ... migration'i calistir, sonra 0056/0057/0061/0064/0066'yi
--   -- tekrar calistirarak isleri geri kur.
--
-- ---------------------------------------------------------------------------
-- NE GETIRIYOR
--
--   faq_entries          SSS icerigi VERITABANINDA — yeni soru icin APK
--                        yayinlamak gerekmiyor, konsoldan yazilir
--   search_faq()         tr_contains ile arama; "aidat" ve "AIDAT" ayni
--   reply_support_ticket()  0066 talep ACMAYI getirmisti ama YANIT YAZMANIN
--                        yolu yoktu: support_messages'ta yalnizca okuma
--                        politikasi vardi. Talep aciliyordu, kimse
--                        cevaplayamiyordu.
--   set_support_status() kullanici kendi talebini KAPATABILIYOR, ama
--                        'cozuldu' isaretlemek yetkilinin isi
--   support_queue()      platform yoneticisi kuyrugu; EN ESKI ONCE
--
--   13 baslangic sorusu ekleniyor (aidat, bildirim, kort, gizlilik, veli,
--   mali). Bos bir SSS ekrani, hic SSS olmamasindan kotu.
--
--   push_route: 33 -> 35. 'eligibility' turu 0064'ten beri ROTASIZDI ve
--   /bildirimler'e dusuyordu; artik /athletes'e gidiyor.
--
--   0070 — SSS ARTIK OZELLIGI TAKIP EDIYOR:
--   faq_entries.feature  bir bayrak anahtarina baglaniyor
--   trg_faq_before_release  bir bayragi testers/everyone yapmayi, o
--                        anahtara bagli aktif SSS satiri yoksa REDDEDIYOR.
--                        Geri cekmek (off/admins) kontrolsuz.
--   faq_coverage()       hangi ozelligin yardimi eksik
--   search_faq()         imza degisti (ucuncu parametre), eski surum
--                        dusuruluyor — HTTP 300 tuzagi
--   34 bayragin HEPSININ yardimi yaziliyor; kapi bugun konsaydi hicbir
--   ozellik yayinlanamazdi.
--
-- TEKRAR CALISTIRILABILIR: `create or replace`, `if not exists`,
-- `on conflict do nothing`. Emin degilsen tekrar calistir.
-- ===========================================================================

"""

TAIL = """
-- ===========================================================================
-- DOGRULAMA (ayri calistir)
--
-- 1) Fonksiyonlar geldi mi — dort satir, set_post_tags TEK satir olmali:
--
--   select proname, pronargs from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and proname in ('can_mention','search_mentionable','search_hashtags',
--                      'set_post_tags','set_pinned_post','set_club_media')
--    order by 1;
--
-- 2) Sutunlar geldi mi — yedi satir donmeli:
--
--   select table_name, column_name
--     from information_schema.columns
--    where table_schema = 'public'
--      and (table_name, column_name) in (
--        ('profiles','cover_path'), ('profiles','brand_color'),
--        ('profiles','avatar_tint'), ('profiles','pinned_post_id'),
--        ('clubs','cover_path'), ('clubs','brand_color'),
--        ('clubs','sections'))
--    order by 1, 2;
--
-- NOT: `auth.uid()` kullanan fonksiyonlar SQL Editor'den test EDILEMEZ.
-- Orada oturum yoktur, `auth.uid()` NULL doner. Bu bir hata degildir.
-- ===========================================================================
"""


def main() -> int:
    missing = [f for f in FILES if not os.path.exists(os.path.join(MIGRATIONS, f))]
    if missing:
        print("EKSIK DOSYA:", ", ".join(missing))
        return 1

    parts = [HEAD]
    for n, f in enumerate(FILES, start=1):
        src = io.open(os.path.join(MIGRATIONS, f), encoding="utf-8").read()
        parts.append(
            "\n-- ==========================================================="
            "================\n"
            f"-- {n}/{len(FILES)}  {f}\n"
            "-- ============================================================"
            "===============\n"
            "\nbegin;\n"
            "\n-- Kilit 15 saniyede gelmezse islem temiz dusuyor: deadlock\n"
            "-- yerine anlasilir bir hata (55P03 lock_not_available).\n"
            "set local lock_timeout = '15s';\n\n"
        )
        parts.append(src.rstrip() + "\n")
        parts.append("\ncommit;\n")

    out = "tools/pending_migrations.sql"
    io.open(out, "w", encoding="utf-8").write("".join(parts))

    lines = sum(1 for _ in io.open(out, encoding="utf-8"))
    print(f"{out}: {len(FILES)} dosya, {lines} satir")
    return 0


if __name__ == "__main__":
    sys.exit(main())
