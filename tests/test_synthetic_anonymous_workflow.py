from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class SyntheticAnonymousWorkflowTests(unittest.TestCase):
 def test_manual_main_only_and_pinned(self):
  w=(ROOT/'.github/workflows/synthetic-anonymous-smoke.yml').read_text()
  for expected in ('workflow_dispatch:',"if: github.ref == 'refs/heads/main'",'environment: imdeltan-synthetic-test','https://uxfyhpukeqttrvcfemts.supabase.co','secrets.IMDELTAN_SYNTHETIC_PUBLISHABLE_KEY','python3 scripts/synthetic_anonymous_security_smoke.py'):self.assertIn(expected,w)
  for forbidden in ('bdhcpgqxhnecrcopoxge','SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','SERVICE_ROLE','sb_secret_','supabase db push'):self.assertNotIn(forbidden,w)
if __name__=='__main__':unittest.main()
