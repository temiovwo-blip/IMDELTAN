"""Text-level checks: this does not test function security or RLS integration."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060008_private_eligibility_gate.sql').read_text().lower()
class GateChecks(unittest.TestCase):
    def test_private_and_no_client_execute(self):
        self.assertIn('security definer', SQL)
        self.assertIn("set search_path = ''", SQL)
        self.assertIn('revoke all on function app_private.user_passes_platform_gate(uuid) from public, anon, authenticated', SQL)
    def test_required_conditions_present(self):
        for term in ("p.account_state = 'active'", "e.status = 'eligible'", 'e.verified_at is not null', 'pv.mandatory', 'public.policy_acceptances'):
            with self.subTest(term=term): self.assertIn(term, SQL)
if __name__ == '__main__': unittest.main()
