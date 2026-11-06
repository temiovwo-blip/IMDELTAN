"""Offline guardrails for the initial migration; not a substitute for database tests."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
MIGRATION = ROOT / 'supabase/migrations/202611050001_initial_identity_foundation.sql'
TABLES = ('profiles', 'user_eligibility', 'user_privacy_settings', 'policy_versions', 'policy_acceptances')

class FoundationGuardrails(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = MIGRATION.read_text().lower()

    def test_tables_have_rls(self):
        for table in TABLES:
            with self.subTest(table=table):
                self.assertRegex(self.sql, rf'alter\s+table\s+public\.{table}\s+enable\s+row\s+level\s+security')

    def test_client_grants_are_revoked(self):
        self.assertRegex(self.sql, r'revoke\s+all\s+on[\s\S]+?from\s+anon,\s*authenticated')
        self.assertNotRegex(self.sql, r'grant\s+.+?\s+to\s+(?:anon|authenticated)')

    def test_identity_and_policy_constraints_exist(self):
        for term in ('references auth.users(id)', 'eligibility_verification', 'policy_versions_one_current_per_key', 'primary key (user_id, policy_version_id)'):
            with self.subTest(term=term):
                self.assertIn(term, self.sql)

    def test_no_privileged_environment_values(self):
        env = (ROOT / '.env.example').read_text()
        for line in env.splitlines():
            if line and not line.lstrip().startswith('#'):
                self.assertRegex(line, r'^[A-Z][A-Z0-9_]*=$')

if __name__ == '__main__':
    unittest.main()
