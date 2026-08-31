"""Migration soz dizimi denetimi.

    pip install pglast
    python tools/check_migrations.py [dosya...]

NEDEN VAR: bu depoda migration'lar Supabase SQL Editor'e **elle yapistirilarak**
calistiriliyor. Soz dizimi hatasi ancak orada, yarim uygulanmis bir migration
olarak ortaya cikiyor - en kotu yer. Bu betik gercek PostgreSQL ayristiricisini
(libpg_query) kullaniyor; calistirmiyor, yalnizca parse ediyor.

SINIRI: soz dizimi disinda bir sey **dogrulamiyor**. Var olmayan bir tabloya
referans, yanlis tip, eksik izin - hepsi buradan gecer. "Parse oldu" ile
"calisir" ayni sey degil.
"""

import io
import re
import sys
import glob

import pglast

targets = sys.argv[1:] or sorted(glob.glob("supabase/migrations/*.sql"))
bad = 0

for path in targets:
    src = io.open(path, encoding="utf-8").read()
    name = path.split("/")[-1]

    try:
        pglast.parse_sql(src)
        outer = "OK"
    except Exception as e:  # noqa: BLE001
        outer = "HATA: " + str(e).split("\n")[0]
        bad += 1

    # plpgsql govdelerindeki sorgular
    inner_bad = []
    for body in re.findall(r"\$fn\$(.*?)\$fn\$", src, re.S):
        for q in re.findall(r"return query\s+(.*?);\s*\nend;", body, re.S):
            try:
                pglast.parse_sql(q)
            except Exception as e:  # noqa: BLE001
                inner_bad.append(str(e).split("\n")[0])

    mark = "  " if outer == "OK" and not inner_bad else "->"
    print(f"{mark} {name}: {outer}", end="")
    if inner_bad:
        bad += 1
        print("  | govde: " + "; ".join(inner_bad[:2]), end="")
    print()

print()
print("sorunlu dosya:", bad)
