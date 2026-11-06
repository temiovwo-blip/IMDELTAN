"""Static guardrails, not validation of storage or notification security."""
import pathlib
import unittest
SQL = (pathlib.Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060005_media_notifications.sql').read_text().lower()
class MediaChecks(unittest.TestCase):
    def test_default_deny(self):
        for table in ('post_media', 'videos', 'notifications'):
            with self.subTest(table=table):
                self.assertIn(f'alter table public.{table} enable row level security', SQL)
        self.assertIn('from anon, authenticated;', SQL)
        self.assertNotRegex(SQL, r'grant\s+.+?\s+to\s+(?:anon|authenticated)')
    def test_attachment_order_and_reference(self):
        self.assertIn('unique (post_id, position)', SQL)
        self.assertIn('references public.post_media(id)', SQL)
if __name__ == '__main__':
    unittest.main()
