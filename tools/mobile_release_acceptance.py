"""SwanSport mobil paketinden önce hızlı, çevrimdışı kabul kapısı.

Gerçek telefon testinin yerine geçmez. Sürüm, QR el değiştirme sözleşmesi,
Android deep link kaydı ve bildirim sayaçlarının ayrılığını yanlışlıkla
bozan değişiklikleri paket üretilmeden yakalar.
"""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    pubspec = read("apps/swansport_app/pubspec.yaml")
    identity = read(
        "apps/swansport_app/lib/features/swan_identity/presentation/"
        "swan_identity_screens.dart"
    )
    manifest = read("apps/swansport_app/android/app/src/main/AndroidManifest.xml")
    landing = read("landing/index.html")
    notifications = read("packages/swansport_data/lib/src/notification_service.dart")

    version = re.search(r"^version:\s*([^\s]+)", pubspec, re.MULTILINE)
    require(version is not None, "pubspec sürümü bulunamadı")
    require(version.group(1) == "1.0.5+62", "beklenen sürüm 1.0.5+62")
    require(
        "https://swansport.com.tr/#/swan-id/dogrula/$token" in identity,
        "QR üretimi resmi alan adını kullanmıyor",
    )
    require('android:autoVerify="true"' in manifest, "Android app link doğrulaması kapalı")
    for host in ("swansport.com.tr", "www.swansport.com.tr"):
        require(f'android:host="{host}"' in manifest, f"Android host eksik: {host}")
    require("swansport://swan-id/dogrula/" in landing, "web uygulamada-aç geçişi eksik")
    require("Uygulamada aç" in landing and "Web'de devam et" in landing,
            "QR el değiştirme seçenekleri eksik")
    require(notifications.count(".neq('kind', 'message')") >= 2,
            "zil listesi/sayacı mesajlardan ayrılmamış")
    require(".from('direct_messages')" in notifications,
            "mesaj sayacı kendi kaynağından okunmuyor")

    print(f"OK mobile release contract {version.group(1)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL {error}", file=sys.stderr)
        raise SystemExit(1)
