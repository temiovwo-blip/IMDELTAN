"""Offline unit tests for read-only development smoke-test safety."""
import importlib.util,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('dev_smoke',ROOT/'scripts/dev_anonymous_security_smoke.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class AnonymousSmokeTests(unittest.TestCase):
 def test_only_dedicated_host_and_publishable_key(self):
  with tempfile.TemporaryDirectory() as d:
   nofile=Path(d)/'none'
   self.assertEqual(m.get_config({'VITE_SUPABASE_URL':m.PROJECT_URL,'VITE_SUPABASE_PUBLISHABLE_KEY':'sb_publishable_'+'x'*24},nofile),'sb_publishable_'+'x'*24)
   for url,key in [('https://old.example','sb_publishable_'+'x'*24),(m.PROJECT_URL,'sb_secret_'+'x'*24),(m.PROJECT_URL,'eyJservice')]:
    with self.assertRaises(ValueError):m.get_config({'VITE_SUPABASE_URL':url,'VITE_SUPABASE_PUBLISHABLE_KEY':key},nofile)
 def test_positive_control_and_scoped_requests(self):
  paths=[];output=[]
  def request(path,key):
   paths.append(path)
   return (200,{'disable_signup':True,'external':{'email':True,'google':False,'phone':False,'anonymous_users':False}}) if path=='/auth/v1/settings' else (400,{'error':'Bucket not found'}) if path.startswith('/storage/v1/bucket/') else (401,{'code':'42501','message':'sensitive-not-printed'})
  m.run('key',request,output.append)
  self.assertEqual(len(paths),26);self.assertTrue(all(p.startswith('/rest/v1/') and p.endswith('limit=0') for p in paths[1:20]));self.assertTrue(all(p.startswith('/storage/v1/bucket/') for p in paths[20:]));self.assertNotIn('sensitive-not-printed',' '.join(output))
 def test_invalid_control_and_inconclusive_denial_fail_closed(self):
  def control(_path,_key):return 401,{'code':'42501'}
  with self.assertRaises(RuntimeError):m.run('key',control,lambda _:None)
  def missing(_path,_key):return (200,{'disable_signup':True,'external':{'email':True,'google':False,'phone':False,'anonymous_users':False}}) if _path=='/auth/v1/settings' else (404,{'code':'PGRST202'})
  with self.assertRaises(RuntimeError):m.run('key',missing,lambda _:None)
  def invalid_key(_path,_key):return (200,{'disable_signup':True,'external':{'email':True,'google':False,'phone':False,'anonymous_users':False}}) if _path=='/auth/v1/settings' else (401,{'message':'Invalid API key'})
  with self.assertRaises(RuntimeError):m.run('key',invalid_key,lambda _:None)
  def open_signup(_path,_key):return 200,{'disable_signup':False,'external':{'email':True}}
  with self.assertRaises(RuntimeError):m.run('key',open_signup,lambda _:None)
 def test_storage_metadata_audit_is_read_only(self):
  sql=(ROOT/'scripts/dev_storage_metadata_audit.sql').read_text().lower();self.assertIn('storage.buckets',sql);self.assertIn('objects_policy_count',sql)
  import re
  lines='\n'.join(line for line in sql.splitlines() if not line.lstrip().startswith('--'));self.assertEqual(lines.count(';'),1)
  self.assertIsNone(re.search(r'\b(insert|update|delete|drop|alter|truncate|create|grant|revoke|call)\b',lines))
 def test_no_redirect_and_paths_are_limited(self):
  self.assertIsNone(m.NoRedirect().redirect_request(None,None,None,None,None,None))
  with self.assertRaises(ValueError):m.fetch('//other.host/','key')
  with self.assertRaises(ValueError):m.fetch('/rest/v1/posts?select=*','key')
if __name__=='__main__':unittest.main()
