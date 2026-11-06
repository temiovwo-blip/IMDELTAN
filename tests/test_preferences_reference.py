"""Static checks; actual consent and privacy enforcement remain unimplemented."""
import pathlib
import unittest
SQL = (pathlib.Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060006_preferences_reference.sql').read_text().lower()
class PreferenceChecks(unittest.TestCase):
    def test_default_deny(self):
        for table in ('languages', 'user_language_preferences', 'lgas', 'ethnic_groups', 'ethnic_group_consents', 'user_ethnic_groups'):
            with self.subTest(table=table):
                self.assertIn(f'alter table public.{table} enable row level security', SQL)
        self.assertIn('from anon, authenticated;', SQL)
        self.assertNotRegex(SQL, r'grant\s+.+?\s+to\s+(?:anon|authenticated)')
    def test_consent_reference_and_language_order(self):
        self.assertIn('references public.policy_versions(id)', SQL)
        self.assertIn('unique (user_id, preference_order)', SQL)
if __name__ == '__main__':
    unittest.main()
