"""Structural checks, not runtime or direct-API security assurance."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060013_initialize_onboarding.sql').read_text().lower()
class OnboardingChecks(unittest.TestCase):
    def test_idempotent_and_identity_bound(self):
        self.assertIn('current_user_id uuid := auth.uid()', SQL)
        self.assertEqual(SQL.count('on conflict (user_id) do nothing'), 3)
        self.assertIn('select 1 from auth.users u where u.id = current_user_id', SQL)
    def test_restricted_privileges(self):
        self.assertIn("set search_path = ''", SQL)
        self.assertIn('revoke all on function public.initialize_own_onboarding() from public, anon, authenticated', SQL)
        self.assertIn('grant execute on function public.initialize_own_onboarding() to authenticated', SQL)
if __name__ == '__main__': unittest.main()
