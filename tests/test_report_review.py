"""Static checks; role, MFA and data isolation require runtime/API tests."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060020_report_review.sql').read_text().lower()
class ReportChecks(unittest.TestCase):
    def test_requires_mfa_role_and_gate(self):
        for part in ("auth.jwt()->>'aal'", "= 'aal2'", "r.role_key in ('moderator','administrator')", 'app_private.user_passes_platform_gate(auth.uid())'):
            with self.subTest(part=part): self.assertIn(part, SQL)
    def test_review_records_decision_and_audit(self):
        self.assertIn('insert into public.moderation_records', SQL)
        self.assertIn('insert into public.audit_logs', SQL)
        self.assertIn('for update', SQL)
    def test_no_direct_client_table_grants(self):
        self.assertNotRegex(SQL, r'grant\s+(select|insert|update|delete)\s+on\s+public\.(user_reports|moderation_records|audit_logs)')
if __name__ == '__main__': unittest.main()
