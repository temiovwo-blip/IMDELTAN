"""Static checks for the draft bucket seed, not an upload-security test."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060007_private_media_buckets.sql').read_text().lower()
class BucketChecks(unittest.TestCase):
    def test_named_buckets_are_private(self):
        for name in ('profile-pictures', 'cover-pictures', 'post-images', 'community-images', 'video-uploads', 'message-attachments'):
            with self.subTest(name=name):
                self.assertIn(f"('{name}', '{name}', false,", SQL)
    def test_allowlist_and_limits_are_present(self):
        self.assertIn('file_size_limit', SQL)
        self.assertIn('allowed_mime_types', SQL)
if __name__ == '__main__':
    unittest.main()
