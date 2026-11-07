"""Offline guardrails for the read-only metadata audit (not service proof)."""
import re,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class DevMetadataAuditTests(unittest.TestCase):
 def test_audit_is_select_only(self):
  sql=(ROOT/'scripts/dev_security_metadata_audit.sql').read_text()
  sql='\n'.join(line for line in sql.splitlines() if not line.lstrip().startswith('--'))
  self.assertEqual(sql.count(';'),1)
  sql=re.sub(r"'(?:''|[^'])*'", "''",sql).lower()
  self.assertTrue(sql.lstrip().startswith('with '))
  self.assertIsNone(re.search(r'\b(insert|update|delete|drop|alter|truncate|create|grant|revoke|call|copy|do|execute)\b',sql))
 def test_checks_both_table_and_column_grants(self):
  sql=(ROOT/'scripts/dev_security_metadata_audit.sql').read_text().lower()
  for item in ('has_table_privilege','has_any_column_privilege','definer_without_empty_search_path','anon_executable_definers','definer_owned_by_rls_bypass_role','private_tables_without_rls'):
   self.assertIn(item,sql)
if __name__=='__main__':unittest.main()
