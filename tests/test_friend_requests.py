"""Structural checks complement, but do not replace, behavioral/security tests."""
from pathlib import Path
import unittest
SQL=(Path(__file__).resolve().parents[1]/'supabase/migrations/202611060023_friend_requests.sql').read_text().lower()
class FriendRequestsChecks(unittest.TestCase):
    def test_profile_locks_and_gate(self):
        self.assertGreaterEqual(SQL.count('order by p.user_id for update'), 4)
        self.assertIn('app_private.user_passes_platform_gate(p_target_id)', SQL)
        self.assertIn("s.contact_permission='members'", SQL)
    def test_no_anonymous_access(self):
        self.assertIn('revoke all on function public.send_friend_request(uuid) from public,anon,authenticated', SQL)
        self.assertIn('revoke all on function public.respond_friend_request(uuid,boolean) from public,anon,authenticated', SQL)
    def test_block_cleans_up_relationships(self):
        self.assertIn('delete from public.friendships', SQL)
        self.assertIn("set status='cancelled'", SQL)
