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
    "0053_feature_flags.sql",
    "0054_coach_discovery.sql",
    "0055_vendors_and_expense_audit.sql",
    "0056_recurring_expenses.sql",
    "0057_expense_approvals.sql",
    "0058_bank_reconciliation.sql",
    "0059_budgets_and_forecast.sql",
    "0060_finance_periods.sql",
    "0061_operations_center.sql",
    "0062_social_upgrade.sql",
    "0063_social_rpc.sql",
    "0064_eligibility_gate.sql",
    "0065_attendance_idempotent.sql",
    "0066_support_risk_retention.sql",
]

HEAD = """-- ===========================================================================
-- SwanSport — bekleyen migration'lar (0053-0066)
--
-- Supabase SQL Editor'e yapistir, TEK SEFERDE calistir.
--
-- TEK ISLEM: `begin`/`commit` arasinda. Bir yerde hata olursa hicbiri
-- uygulanmiyor; yarim sema kalmiyor.
--
-- TEKRAR CALISTIRILABILIR: `create or replace`, `if not exists`,
-- `on conflict do nothing`. Emin degilsen tekrar calistir, zarari yok.
--
-- SURE: 14 dosya, 5382 satir. Editorde birkac saniye surer.
--
-- ---------------------------------------------------------------------------
-- ICINDEKILER
--
--   0053  Ozellik bayraklari — kademeli yayin (off/admins/testers/everyone)
--   0054  Antronor kesfi
--
--   MALI OPERASYON MERKEZI
--   0055  Tedarikciler, gider alanlari, SILINEMEZ denetim izi
--   0056  Tekrarlayan giderler ve taahhutler
--   0057  Gider onay politikalari
--   0058  Banka mutabakati (CSV)
--   0059  Butce ve nakit tahmini
--   0060  Mali donem kapanisi + KAPANMIS DONEM KILIDI
--   0061  Mali is kuyrugu ozeti + kulup operasyon merkezi
--
--   SOSYAL KATMAN
--   0062  Gonderi gorunurlugu, coklu fotograf, kaydedilenler, etiketleme
--   0063  Paylasim, repost/alinti, GUVENLI KART
--
--   KULUP YASAM DONGUSU
--   0064  Saglik kisiti ve KATI UYGUNLUK KILIDI
--   0065  Idempotent yoklama ve surum cakismasi
--   0066  Destek merkezi, operasyon riski, veri saklama
--
-- ---------------------------------------------------------------------------
-- BU MIGRATION UC GUVENLIK ACIGINI KAPATIYOR
--
--   1. `posts_read` politikasi `using (true)` idi (0006'dan beri).
--      Giris yapmis herkes BUTUN gonderileri okuyabiliyordu — kulup ici
--      duyuru da, engelledigin kisinin gonderisi de.
--
--   2. Gider degisiklikleri hicbir yerde izlenmiyordu. Artik tetikleyici
--      her degisikligi yaziyor ve kayit silinemiyor.
--
--   3. Kapanmis mali donem diye bir sey yoktu; gecmis ayin rakami her an
--      degistirilebiliyordu.
--
-- ---------------------------------------------------------------------------
-- CALISTIRDIKTAN SONRA
--
-- Butun yeni ozellikler `admins` kademesinde basliyor, yani yalnizca
-- platform yoneticisine gorunuyor. Bu bilincli: hicbiri gercek kullanimda
-- denenmedi. Konsol > Ozellik bayraklari'ndan kademeleri sen yonetiyorsun.
--
-- `offline_attendance` bayragi `off` — cakisma cozme ekrani yazilmadan
-- acilmamali, yanlis calistiginda VERI KAYBETTIRIR.
-- ===========================================================================

begin;

"""

TAIL = """

commit;

-- ===========================================================================
-- DOGRULAMA (ayri calistir, commit'ten sonra)
--
-- 1) Bayraklar geldi mi — 33 satir donmeli:
--
--   select key, audience from public.feature_flags order by key;
--
-- 2) Cift imza kalmadi mi (HTTP 300 tuzagi) — bos donmeli:
--
--   select p.proname, count(*)
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and p.proname in ('acc_operations_summary', 'push_route',
--                        'shared_content_card', 'eligibility_gate')
--    group by 1 having count(*) > 1;
--
-- 3) Zamanlanmis isler kuruldu mu — 6 YENI is eklendi
--    (recurring_generate, commitment_reminders, approval_reminders,
--     finance_alerts, eligibility_scan, retention_purge):
--
--   select jobname, schedule from cron.job
--    where jobname like 'swansport_%' order by jobname;
--
-- NOT: `auth.uid()` kullanan fonksiyonlar SQL Editor'den test EDILEMEZ.
-- Orada oturum yoktur, `auth.uid()` NULL doner ve fonksiyon bos/hata verir.
-- Bu bir hata degil. Yetki gerektiren seyleri urunun kendisinden test et.
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
