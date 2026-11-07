import hashlib
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
class FixturePreflightTests(unittest.TestCase):
 def test_preflight_is_one_read_only_query(self):
  sql=(ROOT/'scripts/synthetic_fixture_preflight.sql').read_text()
  body='\n'.join(line for line in sql.splitlines() if not line.lstrip().startswith('--')).lower()
  self.assertEqual(body.count(';'),1)
  self.assertTrue(body.lstrip().startswith('select'))
  self.assertIsNone(re.search(r'\b(insert|update|delete|drop|alter|truncate|create|grant|revoke|call)\b',body))
  for table in ('auth.users','public.policy_versions','public.profiles','public.posts','storage.objects'):self.assertIn(table,body)
 def test_policy_fixture_is_unambiguously_not_legal(self):
  data=(ROOT/'tests/fixtures/synthetic-only-placeholder-policy.txt').read_bytes()
  text=data.decode('utf-8').lower()
  for phrase in ('synthetic test fixture only','not legal terms','does not establish consent'):self.assertIn(phrase,text)
  self.assertEqual(len(hashlib.sha256(data).hexdigest()),64)
if __name__=='__main__':unittest.main()
