"""Structural checks only; no independent age verification is performed."""
from pathlib import Path
import unittest
SQL = (Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060014_adult_self_declaration.sql').read_text().lower()
class AdultDeclarationChecks(unittest.TestCase):
    def test_claim_is_explicit_and_pending_only(self):
        for part in ('p_confirmed is distinct from true', "e.status = 'pending'", "verification_method = 'adult_self_declaration'", 'current_user_id uuid := auth.uid()'):
            with self.subTest(part=part): self.assertIn(part, SQL)
    def test_client_execution_restricted(self):
        self.assertIn('revoke all on function public.declare_adult_eligibility(boolean) from public, anon, authenticated', SQL)
        self.assertIn('grant execute on function public.declare_adult_eligibility(boolean) to authenticated', SQL)
        self.assertIn("set search_path = ''", SQL)
if __name__ == '__main__': unittest.main()
