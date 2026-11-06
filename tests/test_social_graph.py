"""Static guardrails, not a replacement for SQL integration tests."""
import pathlib
import unittest

SQL = (pathlib.Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060002_social_graph.sql').read_text().lower()

class SocialGraphChecks(unittest.TestCase):
    def test_default_deny(self):
        for name in ('friend_requests', 'friendships', 'user_blocks'):
            with self.subTest(table=name):
                self.assertIn(f'alter table public.{name} enable row level security', SQL)
        self.assertIn('from anon, authenticated;', SQL)
        self.assertNotRegex(SQL, r'grant\s+.+?\s+to\s+(?:anon|authenticated)')

    def test_relationship_invariants(self):
        for text in ('sender_id <> recipient_id', 'least(sender_id, recipient_id)', 'user_low < user_high', 'blocker_id <> blocked_id'):
            with self.subTest(check=text):
                self.assertIn(text, SQL)

if __name__ == '__main__':
    unittest.main()
