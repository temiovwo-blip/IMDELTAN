"""Fast checks for the deliberately inaccessible content schema draft."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SQL = (ROOT / 'supabase/migrations/202611060001_content_foundation.sql').read_text().lower()

class ContentFoundationGuardrails(unittest.TestCase):
    def test_rls_enabled_for_every_table(self):
        for table in ('communities', 'community_memberships', 'posts', 'comments', 'reactions', 'saved_posts'):
            with self.subTest(table=table):
                self.assertIn(f'alter table public.{table} enable row level security', SQL)

    def test_no_client_grants(self):
        self.assertIn('from anon, authenticated;', SQL)
        self.assertNotRegex(SQL, r'grant\s+.+?\s+to\s+(?:anon|authenticated)')

    def test_reply_and_reaction_integrity(self):
        self.assertIn('foreign key (post_id, parent_id) references public.comments(post_id, id)', SQL)
        self.assertIn('check ((post_id is not null) <> (comment_id is not null))', SQL)
        self.assertIn('reactions_one_per_post', SQL)
        self.assertIn('reactions_one_per_comment', SQL)

if __name__ == '__main__':
    unittest.main()
