"""Static guardrails. Runtime authorization and API tests remain essential."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060019_private_text_posts.sql').read_text().lower()
class PrivatePostChecks(unittest.TestCase):
    def test_own_private_read_only(self):
        for part in ("author_id = auth.uid()", "audience = 'private'", "status = 'active'", 'app_private.current_user_passes_platform_gate()'):
            with self.subTest(part=part): self.assertIn(part, SQL)
    def test_guarded_create(self):
        self.assertIn('app_private.user_passes_platform_gate(current_user_id)', SQL)
        self.assertIn("values (current_user_id,clean_body,'private','active')", SQL)
        self.assertIn('revoke all on function public.create_own_private_text_post(text) from public, anon, authenticated', SQL)
        self.assertNotRegex(SQL, r'grant\s+(insert|update|delete)\s+on\s+public\.posts')
if __name__ == '__main__': unittest.main()
