"""Offline tests of the opt-in dev-only synthetic-user smoke harness."""
import base64,importlib.util,json,sys,time,unittest,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts'))
spec=importlib.util.spec_from_file_location('dev_signed_smoke',ROOT/'scripts/dev_signed_in_security_smoke.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def jwt(uid,**changes):
 payload={'sub':uid,'iss':m.PROJECT_URL+'/auth/v1','role':'authenticated','aud':'authenticated','exp':time.time()+600};payload.update(changes)
 return 'header.'+base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip('=')+'.signature'
class SignedSmokeTests(unittest.TestCase):
 def setUp(self):
  self.a,self.b,self.pa,self.pb=(str(uuid.uuid4()) for _ in range(4));self.ta=jwt(self.a);self.tb=jwt(self.b)
  self.env={'VITE_SUPABASE_URL':m.PROJECT_URL,'VITE_SUPABASE_PUBLISHABLE_KEY':'sb_publishable_'+'x'*24,'IMDELTAN_SYNTHETIC_TESTS_CONFIRMED':m.CONFIRM,'IMDELTAN_SYNTHETIC_A_JWT':self.ta,'IMDELTAN_SYNTHETIC_B_JWT':self.tb,'IMDELTAN_SYNTHETIC_A_PRIVATE_POST_ID':self.pa,'IMDELTAN_SYNTHETIC_B_PRIVATE_POST_ID':self.pb}
 def test_safe_configuration_and_scope(self):
  key,a,b=m.get_configured(self.env);self.assertEqual(a,(self.a,self.ta,self.pa));self.assertEqual(b,(self.b,self.tb,self.pb))
  for field,value in [('IMDELTAN_SYNTHETIC_TESTS_CONFIRMED',''),('VITE_SUPABASE_URL','https://old.invalid'),('IMDELTAN_SYNTHETIC_A_JWT',jwt(self.a,role='service_role')),('IMDELTAN_SYNTHETIC_A_JWT',jwt(self.a,iss='https://old.invalid/auth/v1')),('IMDELTAN_SYNTHETIC_A_JWT',jwt(self.a,exp=time.time()-1)),('IMDELTAN_SYNTHETIC_B_JWT',self.ta),('IMDELTAN_SYNTHETIC_B_PRIVATE_POST_ID',self.pa)]:
   with self.subTest(field=field),self.assertRaises(ValueError):m.get_configured({**self.env,field:value})
 def fake(self,path,key,token):
  uid,own_post=(self.a,self.pa) if token==self.ta else (self.b,self.pb)
  if path=='/auth/v1/user':return 200,{'id':uid,'email':'not-to-be-logged@example.invalid'}
  if '/profiles?' in path:return 200,([{'user_id':uid}] if 'eq.'+uid in path else [])
  if '/posts?' in path:return 200,([{'id':own_post,'author_id':uid}] if 'eq.'+own_post in path else [])
  return 403,{'code':'42501','message':'not-to-be-logged'}
 def test_isolation_and_minimal_output(self):
  out=[];m.run(*m.get_configured(self.env),request=self.fake,emit=out.append);text=' '.join(out)
  self.assertNotIn(self.ta,text);self.assertNotIn(self.tb,text);self.assertNotIn('@example.invalid',text);self.assertNotIn('not-to-be-logged',text);self.assertEqual(len(out),3)
 def test_bad_fixtures_and_unexpected_access_fail(self):
  def leaked(path,key,token):
   if '/posts?' in path and token==self.ta and 'eq.'+self.pb in path:return 200,[{'id':self.pb,'author_id':self.b}]
   return self.fake(path,key,token)
  with self.assertRaises(RuntimeError):m.run(*m.get_configured(self.env),request=leaked,emit=lambda _:None)
  def missing(path,key,token):return (200,[]) if '/profiles?' in path else self.fake(path,key,token)
  with self.assertRaises(RuntimeError):m.run(*m.get_configured(self.env),request=missing,emit=lambda _:None)
  def inconclusive(path,key,token):return (404,{'code':'PGRST202'}) if '/rpc/list_reports_for_review' in path else self.fake(path,key,token)
  with self.assertRaises(RuntimeError):m.run(*m.get_configured(self.env),request=inconclusive,emit=lambda _:None)
if __name__=='__main__':unittest.main()
