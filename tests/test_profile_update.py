"""Structural checks only: API, authorization and concurrency need runtime tests."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060012_update_own_profile.sql').read_text().lower()
class ProfileUpdateChecks(unittest.TestCase):
    def test_identity_and_gate(self):
        for fragment in ('current_user_id uuid := auth.uid()', 'app_private.user_passes_platform_gate(current_user_id)', 'where p.user_id = current_user_id', "set search_path = ''"):
            with self.subTest(fragment=fragment): self.assertIn(fragment, SQL)
    def test_restricted_function(self):
        self.assertIn('revoke all on function public.update_own_profile(text,text,text) from public, anon, authenticated', SQL)
        self.assertIn('grant execute on function public.update_own_profile(text,text,text) to authenticated', SQL)
        self.assertNotRegex(SQL, r'grant\s+update\s+on')
if __name__ == '__main__': unittest.main()
