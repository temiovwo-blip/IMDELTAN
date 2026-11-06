"""Static guardrails only; no assurance of moderation authorization."""
import pathlib
import unittest

SQL = (pathlib.Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060004_moderation_admin.sql').read_text().lower()

class ModerationChecks(unittest.TestCase):
    def test_default_deny(self):
        for table in ('admin_roles', 'admin_role_assignments', 'user_reports', 'moderation_records', 'audit_logs'):
            with self.subTest(table=table):
                self.assertIn(f'alter table public.{table} enable row level security', SQL)
        self.assertIn('from anon, authenticated;', SQL)
        self.assertNotRegex(SQL, r'grant\s+.+?\s+to\s+(?:anon|authenticated)')

    def test_report_has_exactly_one_target(self):
        self.assertIn('num_nonnulls(reported_user_id, reported_post_id, reported_comment_id) = 1', SQL)

if __name__ == '__main__':
    unittest.main()
