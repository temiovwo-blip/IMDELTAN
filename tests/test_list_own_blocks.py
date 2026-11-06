"""Structural checks only; behavior is checked separately in isolated PostgreSQL."""
from pathlib import Path
import unittest

SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060022_list_own_blocks.sql').read_text().lower()

class BlockListChecks(unittest.TestCase):
    def test_identity_gate_and_cursor(self):
        for fragment in ('auth.uid()', 'app_private.user_passes_platform_gate(current_user_id)',
                         'b.blocker_id = current_user_id', 'b.blocked_id > p_after', 'limit 50'):
            self.assertIn(fragment, SQL)
    def test_no_public_execute(self):
        self.assertIn('revoke all on function public.list_own_blocks(uuid) from public, anon, authenticated', SQL)
