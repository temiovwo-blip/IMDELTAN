"""Static checks for the early customer scaffold, not an application security test."""
import pathlib
import unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'apps/customer/src/main.js').read_text()
class CustomerChecks(unittest.TestCase):
    def test_no_secret_client_key_reference(self):
        self.assertNotIn('SUPABASE_SERVICE_ROLE_KEY', SOURCE)
        self.assertNotIn('service_role', SOURCE)
    def test_post_body_uses_text_content(self):
        self.assertIn('text.textContent=post.body', SOURCE)
        self.assertNotIn('text.innerHTML=post.body', SOURCE)
    def test_private_post_call_is_specific(self):
        self.assertIn("client.rpc('create_own_private_text_post'", SOURCE)
if __name__ == '__main__': unittest.main()
