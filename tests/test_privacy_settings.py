"""Static checks only. Other-user visibility and messaging remain unimplemented."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060017_privacy_settings.sql').read_text().lower()
class PrivacyChecks(unittest.TestCase):
    def test_uses_self_and_gate(self):
        self.assertEqual(SQL.count('current_user_id uuid := auth.uid()'), 2)
        self.assertEqual(SQL.count('app_private.user_passes_platform_gate(current_user_id)'), 2)
        self.assertIn('where s.user_id = current_user_id', SQL)
    def test_no_direct_table_grants(self):
        self.assertNotRegex(SQL, r'grant\s+(select|insert|update|delete)\s+on\s+public\.user_privacy_settings')
        self.assertIn('from public, anon, authenticated', SQL)
if __name__ == '__main__': unittest.main()
