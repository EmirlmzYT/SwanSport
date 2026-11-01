from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
MATRIX = ROOT / "docs" / "swansport-pro-management-parity-matrix.md"
MANAGEMENT_SECTION = (
    ROOT
    / "apps"
    / "swansport_app"
    / "lib"
    / "features"
    / "social"
    / "presentation"
    / "widgets"
    / "management_section.dart"
)


class ProParityMatrixTest(unittest.TestCase):
    def test_required_management_domains_are_classified(self):
        text = MATRIX.read_text(encoding="utf-8")
        required = (
            "Kulüp başvuruları",
            "Kulüp duyuruları",
            "Kulüp belgeleri",
            "Kulüp ve sezon ayarları",
            "Takım/kadro yönetimi",
            "Yoklama",
            "Antrenman",
            "Veli/sporcu bağlantıları",
            "Aidat ve ödeme",
            "Muhasebe",
            "Tesis",
            "Federasyon",
            "Hakem",
            "Disiplin",
            "Bülten",
            "Performans analitiği",
            "Platform yönetimi",
            "Bildirimler/deep linkler",
            "Görev ve takvim",
        )
        for domain in required:
            with self.subTest(domain=domain):
                self.assertIn(f"| {domain} |", text)
        self.assertNotIn("| Kısmi", text)
        self.assertNotIn("| Eksik", text)

    def test_social_management_entry_routes_have_evidence(self):
        text = MATRIX.read_text(encoding="utf-8")
        source = MANAGEMENT_SECTION.read_text(encoding="utf-8")
        routes = sorted(set(re.findall(r"'(/[^']+)'", source)))
        self.assertTrue(routes)
        for route in routes:
            with self.subTest(route=route):
                self.assertIn(f"`{route}`", text)

    def test_legacy_management_routes_have_evidence(self):
        text = MATRIX.read_text(encoding="utf-8")
        legacy_routes = (
            "/dashboard",
            "/athletes",
            "/attendance",
            "/calendar",
            "/announcements",
            "/teams",
            "/documents",
            "/performance-analytics",
            "/settings",
            "/antrenman-oturumu",
            "/finans",
            "/mali-isler",
            "/gider-ekle",
            "/medical-center",
            "/kulup/malzeme-zimmet",
            "/kulup/saglik-takibi",
            "/kulup/kadro-planlama",
            "/federasyon-merkezi",
            "/hakem/gorevler",
            "/onay-paneli",
            "/haber-kaynaklari",
            "/federasyon-yetkili",
            "/saha-islemlerim",
            "/facilities",
            "/rezervasyon",
            "/gelisim-raporu",
            "/veli-izinleri",
            "/bagis",
            "/basvurular",
            "/veli-bagla",
            "/rehber",
            "/configuration",
            "/reports",
        )
        for route in legacy_routes:
            with self.subTest(route=route):
                self.assertIn(f"`{route}`", text)


if __name__ == "__main__":
    unittest.main()
