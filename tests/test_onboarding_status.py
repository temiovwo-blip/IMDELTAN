"""Static checks only, not authorization assurance."""
from pathlib import Path
import unittest
SQL=(Path(__file__).resolve().parents[1]/'supabase/migrations/202611060021_onboarding_status.sql').read_text().lower()
class OnboardingStatusChecks(unittest.TestCase):
    def test_self_bound_fail_closed(self):
        for part in ('current_user_id uuid := auth.uid()', 'p.user_id=current_user_id', 'pa.user_id=current_user_id', 'and not exists', "set search_path = ''"):
            with self.subTest(part=part): self.assertIn(part,SQL)
    def test_unauthorized_execution_revoked(self):
        self.assertIn('revoke all on function public.get_own_onboarding_status() from public, anon, authenticated',SQL)
if __name__=='__main__': unittest.main()
