"""Static checks: recording a block is not enforcement across the application."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060018_block_users.sql').read_text().lower()
class BlockChecks(unittest.TestCase):
    def test_self_bound_and_gated(self):
        self.assertEqual(SQL.count('current_user_id uuid := auth.uid()'), 2)
        self.assertEqual(SQL.count('app_private.user_passes_platform_gate(current_user_id)'), 2)
        self.assertIn('b.blocker_id = current_user_id and b.blocked_id = p_target_id', SQL)
    def test_private_functions(self):
        self.assertIn('revoke all on function public.block_user(uuid) from public, anon, authenticated', SQL)
        self.assertIn('revoke all on function public.unblock_user(uuid) from public, anon, authenticated', SQL)
if __name__ == '__main__': unittest.main()
