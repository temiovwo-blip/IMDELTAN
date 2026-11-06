"""Static guardrails only; integration and tamper-resistance tests are required."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060016_onboarding_audit.sql').read_text().lower()
class OnboardingAuditChecks(unittest.TestCase):
    def test_triggers_and_restricted_function(self):
        for name in ('audit_profile_account_state', 'audit_eligibility_status', 'audit_policy_acceptance'):
            with self.subTest(name=name): self.assertIn('create trigger ' + name, SQL)
        self.assertIn('revoke all on function app_private.audit_onboarding_change() from public, anon, authenticated', SQL)
        self.assertIn("set search_path = ''", SQL)
    def test_minimal_audit_fields(self):
        self.assertIn('insert into public.audit_logs (actor_id, action, target_type, target_id, outcome)', SQL)
if __name__ == '__main__': unittest.main()
