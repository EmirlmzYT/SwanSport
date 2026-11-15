from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PostMediaStorageContractTest(unittest.TestCase):
    def test_policy_is_reasserted_for_current_installations(self) -> None:
        migrations = list((ROOT / "supabase" / "migrations").glob("*.sql"))
        contract = "\n".join(
            path.read_text(encoding="utf-8") for path in migrations
        )

        self.assertIn('postmedia_upload_own_v2', contract)
        self.assertIn("bucket_id = 'post-media'", contract)
        self.assertIn(
            "(storage.foldername(name))[1] = (select auth.uid())::text",
            contract,
        )
        self.assertIn("update storage.buckets", contract)
        self.assertIn("public = true", contract)


if __name__ == "__main__":
    unittest.main()
