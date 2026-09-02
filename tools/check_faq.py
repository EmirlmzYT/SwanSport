"""SSS kapsam denetimi — her ozellik bayraginin yardimi var mi.

    python tools/check_faq.py

NEDEN VAR: SSS bir kez dolduruldu (0069) ve oradan sonra arkada kalacakti.
Bu depoda ayni sey iki kez yasandi — `push_route` eslemeleri iki kez sessizce
dustu, AGENTS.md bir sure olmayan bir fonksiyondan bahsetti. "Ozellik
ekleyince SSS'yi de guncelle" bir niyet; niyetler eskiyor.

Asil kapi VERITABANINDA: `trg_faq_before_release` (0070) bir bayragi
`testers` ya da `everyone` yapmayi, o anahtara bagli aktif bir SSS kaydi
yoksa reddediyor. Bu betik ayni kurali GELISTIRME ZAMANINDA soyluyor —
hatayi migration calistirirken degil, yazarken gormek icin.

NEDEN pglast: ilk surum ifadeleri `[^;]*;` ile kesiyordu ve bir SSS
cevabinin ICINDEKI noktali virgulde durdu ("...kendi kanali; kadro
disindakiler..."). 34 kaydin 4'unu gordu ve "yardim eksik" dedi. SQL
dizeleri noktali virgul icerebilir; ifade sinirini gercek ayristiriciya
sormak sart.

SINIRI: migration dosyalarini okuyor, canli veritabanini degil. Konsoldan
elle eklenen SSS kayitlarini gormuyor.
"""

import glob
import io
import re
import sys

import pglast

MIGRATIONS = "supabase/migrations/*.sql"

FLAG_ROW = re.compile(
    r"\(\s*'([a-z0-9_]+)'\s*,\s*'(off|admins|testers|everyone)'")


def _statements(src):
    """Kaynaktaki her ifadeyi metin olarak dondur.

    `stmt_location` ifadenin basi, `stmt_len` uzunlugu. Sonuncu ifadede
    `stmt_len` 0 gelebiliyor; o durumda dosyanin sonuna kadar aliniyor.
    """
    try:
        parsed = pglast.parse_sql(src)
    except Exception:  # noqa: BLE001 — sozdizimi check_migrations.py'nin isi
        return []
    out = []
    for raw in parsed:
        loc = raw.stmt_location or 0
        length = raw.stmt_len or 0
        out.append(src[loc:loc + length] if length else src[loc:])
    return out


def main() -> int:
    paths = sorted(glob.glob(MIGRATIONS))
    if not paths:
        print("migration bulunamadi")
        return 1

    flags = {}
    faq_blocks = []

    for p in paths:
        src = io.open(p, encoding="utf-8").read()
        for stmt in _statements(src):
            low = stmt.lower()
            if "insert into public.feature_flags" in low:
                for key, audience in FLAG_ROW.findall(stmt):
                    flags.setdefault(key, audience)
            if "insert into public.faq_entries" in low:
                faq_blocks.append(stmt)

    # Arac calisti mi. Bos kumeyi bos kumeyle karsilastirip "sorun yok"
    # demek, bu depoda `grep 'error •'` ile yasanmis bir hata.
    if len(flags) < 10:
        print(f"ARAC BOZUK: yalnizca {len(flags)} bayrak okundu")
        return 2
    if not faq_blocks:
        print("ARAC BOZUK: hic faq_entries insert'i bulunamadi")
        return 2

    joined = "\n".join(faq_blocks)
    covered = {k for k in flags if re.search(r"'%s'" % re.escape(k), joined)}
    missing = sorted(set(flags) - covered)

    print(f"bayrak: {len(flags)}   SSS kaydi olan: {len(covered)}")
    if missing:
        print()
        print("YARDIMI EKSIK (bunlar testers/everyone yapilamaz):")
        for k in missing:
            print(f"  {k}  [{flags[k]}]")
        print()
        print("Konsol > Yardim icerigi ekranindan soru ekle ya da yeni bir")
        print("migration'da faq_entries'e satir yaz.")
        return 1

    print("Butun ozelliklerin yardimi yazili.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
