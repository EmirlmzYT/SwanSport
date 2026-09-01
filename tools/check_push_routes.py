"""push_route eşlemesi kaybı denetimi.

    python tools/check_push_routes.py

NEDEN VAR: `push_route` bildirime dokununca hangi ekranın açılacağını
söylüyor ve migration'larda **beş kez baştan yazıldı**. Her yeniden yazımda
eşleme kaybetme riski var ve bir kez gerçekten kaybedildi: 0022'nin eklediği
`payment`, `attendance_reminder` ve `donation` eşlemeleri 0039'da düştü.

Kaybın belirtisi yok. Fonksiyon çalışıyor, hata vermiyor, yalnızca `else`
dalına düşüp kullanıcıyı yanlış ekrana götürüyor. Testler görmüyor çünkü
SQL. Bu betik görüyor.

SINIRI: yalnızca **kayıp** eşlemeyi bulur. Eşlemenin doğru ekrana gittiğini
ya da o rotanın uygulamada var olduğunu doğrulamaz.
"""
import glob
import io
import re
import sys

PAT = re.compile(r"when\s+'([a-z_]+)'\s*then\s+'([^']*)'")


def mappings(path):
    src = io.open(path, encoding="utf-8").read()
    out = {}
    # Yalnizca push_route govdesindeki case'ler; dosyada baska `when` de olabilir.
    #
    # Iki sinirlayici da destekleniyor: eski tanimlar `$$`, yenileri `$fn$`
    # kullaniyor. Ilk yazimda yalnizca `$fn$` aranmisti ve betik hicbir eski
    # tanimi gormuyordu -- yani "kayip yok" diyordu, cunku hicbir sey
    # okuyamamisti. Hep gecen bir denetim, denetim degildir.
    for block in re.findall(
            r"function public\.push_route.*?(?:\$fn\$|\$\$);", src, re.S):
        for kind, route in PAT.findall(block):
            out[kind] = route
    return out


def main():
    files = sorted(glob.glob("supabase/migrations/*.sql"))
    seen = {}          # kind -> (route, hangi dosyada goruldu)
    latest = None
    latest_file = None

    for f in files:
        m = mappings(f)
        if not m:
            continue
        latest, latest_file = m, f
        for kind, route in m.items():
            seen[kind] = (route, f)

    if latest is None:
        print("push_route tanimi bulunamadi")
        return 0

    lost = sorted(k for k in seen if k not in latest)

    print(f"en son tanim : {latest_file.split('/')[-1]} ({len(latest)} esleme)")
    print(f"tarihte gorulen toplam: {len(seen)}")

    if lost:
        print()
        print("KAYIP ESLEME:")
        for k in lost:
            route, where = seen[k]
            print(f"  {k:26} -> {route}   ({where.split('/')[-1]}'de vardi)")
        print()
        print("Bu turler bugun `else` dalina dusuyor ve kullaniciyi yanlis")
        print("ekrana goturuyor. En son push_route tanimina geri ekle.")
        return 1

    print("kayip esleme yok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
