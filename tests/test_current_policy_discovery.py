"""Structural checks only; access behavior requires runtime tests."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060011_current_policy_discovery.sql').read_text().lower()
class PolicyDiscoveryChecks(unittest.TestCase):
    def test_restricted_to_signed_in_pending_or_active_user(self):
        for part in ('current_user_id uuid := auth.uid()', "p.account_state in ('pending', 'active')", 'pa.user_id = current_user_id', "set search_path = ''"):
            with self.subTest(part=part): self.assertIn(part, SQL)
    def test_no_anonymous_execution_grant(self):
        self.assertIn('revoke all on function public.list_current_required_policies() from public, anon, authenticated', SQL)
        self.assertIn('grant execute on function public.list_current_required_policies() to authenticated', SQL)
if __name__ == '__main__': unittest.main()
