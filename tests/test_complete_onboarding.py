"""Structural checks only, not proof of runtime or legal compliance."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060015_complete_onboarding.sql').read_text().lower()
class CompleteOnboardingChecks(unittest.TestCase):
    def test_pending_identity_eligibility_and_policy(self):
        for part in ('current_user_id uuid := auth.uid()', "p.account_state = 'pending'", "e.status = 'eligible'", 'public.policy_acceptances', 'pv.mandatory'):
            with self.subTest(part=part): self.assertIn(part, SQL)
    def test_function_grants_are_restricted(self):
        self.assertIn("set search_path = ''", SQL)
        self.assertIn('revoke all on function public.complete_own_onboarding() from public, anon, authenticated', SQL)
        self.assertIn('grant execute on function public.complete_own_onboarding() to authenticated', SQL)
if __name__ == '__main__': unittest.main()
