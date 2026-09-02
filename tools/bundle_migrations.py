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
    # 0053-0066 CANLIDA (2026-09-02 dogrulandi). Yeniden calistirmak
    # zararsiz ama gereksiz; listede yalnizca bekleyenler var.
    "0067_mention_picker.sql",
    "0068_identity_customization.sql",
]

HEAD = """-- ===========================================================================
-- SwanSport — bekleyen migration'lar (0067-0068)
--
-- Supabase SQL Editor'e yapistir, tek seferde calistir.
--
-- 0053-0066 CANLIDA (2026-09-02 dogrulandi). Bu dosyada iki migration var:
--   0067  etiket secici (@kisi, #etiket)
--   0068  kimlik ozellestirme (kapak, marka rengi, avatar tonu, vitrin)
--
-- NE GETIRIYOR
--   can_mention()          etiketleme izni tek yerde: engelleme + politika
--   search_mentionable()   secicide YALNIZCA etiketlenmeyi kabul edenler
--   search_hashtags()      tr_fold ile arama ("#Isiklar" bulunabilsin)
--   set_post_tags()        artik TOLERANSLI ve kac kisinin etiketlendigini
--                          donuyor
--
-- NEDEN GEREKLI
--   Eskiden secici profiles tablosunu duz sorguluyordu: etiketlenmeyi
--   kapatmis ve engellenmis kisiler de listeleniyordu. Kullanici onlari
--   seciyor, sonra etiketleme reddediliyordu — ve tek kotu etiket BUTUN
--   etiketlemeyi dusuruyordu.
--
--   set_post_tags'in ARGUMAN imzasi ayni (uuid, uuid[], text[]) ama DONUS
--   TIPI void'den int'e geciyor. `create or replace` donus tipini
--   degistiremiyor (42P13); bu yuzden once `drop function` var.
--   Ilk surumde "ayni imza, replace yeterli" yazilmisti — yanlisti.
--
-- CALISTIRILMAZSA: secici hic acilmiyor (hata gostermiyor, sessizce bos),
-- hashtag yazan kullanici "etiketler eklenemedi" uyarisi aliyor. Gonderi
-- yine paylasiliyor.
-- ===========================================================================

begin;

"""

TAIL = """

commit;

-- ===========================================================================
-- DOGRULAMA (ayri calistir)
--
--   select proname, pronargs from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and proname in ('can_mention','search_mentionable','search_hashtags',
--                      'set_post_tags')
--    order by 1;
--
-- Dort satir donmeli ve set_post_tags TEK satir olmali. Iki satir cikarsa
-- eski imza dusmemis demektir ve PostgREST HTTP 300 doner.
-- ===========================================================================
"""


def main() -> int:
    missing = [f for f in FILES if not os.path.exists(os.path.join(MIGRATIONS, f))]
    if missing:
        print("EKSIK DOSYA:", ", ".join(missing))
        return 1

    parts = [HEAD]
    for f in FILES:
        src = io.open(os.path.join(MIGRATIONS, f), encoding="utf-8").read()
        parts.append(
            "\n-- ==========================================================="
            "================\n"
            f"-- {f}\n"
            "-- ============================================================"
            "===============\n\n"
        )
        parts.append(src.rstrip() + "\n")
    parts.append(TAIL)

    out = "tools/pending_migrations.sql"
    io.open(out, "w", encoding="utf-8").write("".join(parts))

    lines = sum(1 for _ in io.open(out, encoding="utf-8"))
    print(f"{out}: {len(FILES)} dosya, {lines} satir")
    return 0


if __name__ == "__main__":
    sys.exit(main())
