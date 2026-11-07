"""Static workflow checks, not actual GitHub or Supabase security evidence."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
W=(ROOT/'.github/workflows/synthetic-migration-dry-run.yml').read_text()
A=(ROOT/'.github/workflows/synthetic-migration-apply.yml').read_text()
class SyntheticPreviewGuardrails(unittest.TestCase):
 def test_preview_targets_only_dedicated_project(self):
  self.assertIn('uxfyhpukeqttrvcfemts',W);self.assertNotIn('bdhcpgqxhnecrcopoxge',W)
  self.assertIn('test "$SUPABASE_PROJECT_ID" = \'uxfyhpukeqttrvcfemts\'',W)
  self.assertIn('supabase link --project-ref "$SUPABASE_PROJECT_ID"',W)
 def test_preview_is_manual_main_only_and_dry_run(self):
  self.assertIn('workflow_dispatch:',W);self.assertIn("if: github.ref == 'refs/heads/main'",W)
  self.assertIn('environment: imdeltan-synthetic-test',W)
  pushes=[line for line in W.splitlines() if 'supabase db push' in line]
  self.assertEqual(len(pushes),1);self.assertIn('--dry-run',pushes[0]);self.assertNotIn('--yes',W)
 def test_secrets_are_separate_and_not_embedded(self):
  self.assertIn('secrets.SUPABASE_SYNTHETIC_ACCESS_TOKEN',W);self.assertIn('secrets.IMDELTAN_SYNTHETIC_DB_PASSWORD',W)
  self.assertNotIn('SUPABASE_SERVICE_ROLE_KEY',W);self.assertNotIn('secrets.IMDELTAN_DEV_DB_PASSWORD',W)
 def test_apply_is_manual_confirmed_and_separate(self):
  self.assertIn('workflow_dispatch:',A);self.assertIn("if: github.ref == 'refs/heads/main'",A)
  self.assertIn('environment: imdeltan-synthetic-test',A)
  self.assertIn('APPLY-IMDELTAN-SYNTHETIC-TEST',A);self.assertIn('test "$CONFIRMATION" = "APPLY-IMDELTAN-SYNTHETIC-TEST"',A)
  self.assertIn('test "$SUPABASE_PROJECT_ID" = \'uxfyhpukeqttrvcfemts\'',A);self.assertNotIn('bdhcpgqxhnecrcopoxge',A)
  self.assertIn('secrets.SUPABASE_SYNTHETIC_ACCESS_TOKEN',A);self.assertIn('secrets.IMDELTAN_SYNTHETIC_DB_PASSWORD',A)
  self.assertLess(A.index('supabase db push --dry-run'),A.index('supabase db push --yes'))
  self.assertNotIn('SUPABASE_SERVICE_ROLE_KEY',A)
if __name__=='__main__':unittest.main()
