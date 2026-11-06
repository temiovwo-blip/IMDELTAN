"""Text-level checks only; runtime and direct API testing still required."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060010_accept_current_policy.sql').read_text().lower()
class PolicyAcceptanceChecks(unittest.TestCase):
    def test_identity_and_valid_policy_are_enforced(self):
        for fragment in ('current_user_id uuid := auth.uid()', "account_state in ('pending', 'active')", 'pv.mandatory', 'pv.retired_at is null', 'on conflict (user_id, policy_version_id) do nothing'):
            with self.subTest(fragment=fragment): self.assertIn(fragment, SQL)
    def test_function_is_restricted_and_search_path_fixed(self):
        self.assertIn("set search_path = ''", SQL)
        self.assertIn('revoke all on function public.accept_current_policy(uuid) from public, anon, authenticated', SQL)
        self.assertIn('grant execute on function public.accept_current_policy(uuid) to authenticated', SQL)
if __name__ == '__main__': unittest.main()
