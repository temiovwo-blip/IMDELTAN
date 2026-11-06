"""Static guardrails: these checks are not a substitute for review."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
WORKFLOW=(ROOT/'.github/workflows/dev-migration-dry-run.yml').read_text()
CONFIG=(ROOT/'supabase/config.toml').read_text()
class DevelopmentDeploymentChecks(unittest.TestCase):
    def test_preview_only_and_exact_new_project(self):
        self.assertIn('bdhcpgqxhnecrcopoxge',WORKFLOW)
        self.assertIn('workflow_dispatch:',WORKFLOW)
        self.assertIn('supabase db push --dry-run',WORKFLOW)
        for line in WORKFLOW.splitlines():
            if 'supabase db push' in line:
                self.assertIn('--dry-run',line)
        self.assertNotIn('SUPABASE_SERVICE_ROLE_KEY',WORKFLOW)
    def test_local_signup_defaults_closed(self):
        self.assertNotIn('enable_signup = true',CONFIG)
        self.assertIn('enable_signup = false',CONFIG)
