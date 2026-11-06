"""Static checks; the integration workflow exercises actual PostgreSQL RLS."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060009_profile_self_read.sql').read_text().lower()
class ProfileReadChecks(unittest.TestCase):
    def test_is_self_only_and_gated(self):
        self.assertIn('user_id = auth.uid() and app_private.current_user_passes_platform_gate()', SQL)
        self.assertIn('app_private.user_passes_platform_gate(auth.uid())', SQL)
    def test_no_writes_or_anon_grants(self):
        self.assertNotRegex(SQL, r'grant\s+(insert|update|delete)')
        self.assertNotRegex(SQL, r'grant\s+[^;]*\s+to\s+anon\s*;')
    def test_privileged_flag_not_in_selected_columns(self):
        self.assertIn('grant select (user_id, handle, display_name, biography, created_at, updated_at)', SQL)
if __name__ == '__main__': unittest.main()
