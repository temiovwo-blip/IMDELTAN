import base64, importlib.util, json, sys, time, unittest, uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
spec=importlib.util.spec_from_file_location('synthetic_signed',ROOT/'scripts/synthetic_signed_in_security_smoke.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

def jwt(uid,issuer,**changes):
    payload={'sub':uid,'iss':issuer+'/auth/v1','role':'authenticated','aud':'authenticated','exp':time.time()+600}
    payload.update(changes)
    return 'header.'+base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip('=')+'.signature'

class SignedSyntheticTests(unittest.TestCase):
    def setUp(self):
        self.runner=m.load_runner();self.a,self.b,self.pa,self.pb=[str(uuid.uuid4()) for _ in range(4)]
        self.ta=jwt(self.a,m.synthetic.PROJECT_URL);self.tb=jwt(self.b,m.synthetic.PROJECT_URL)
        self.env={'IMDELTAN_SYNTHETIC_TESTS_CONFIRMED':'SYNTHETIC-ONLY-UXFYHPUKEQTTRVCFEMTS', 'IMDELTAN_SYNTHETIC_PROJECT_URL':m.synthetic.PROJECT_URL, 'IMDELTAN_SYNTHETIC_PUBLISHABLE_KEY':'sb_publishable_'+'x'*24, 'IMDELTAN_SYNTHETIC_A_JWT':self.ta, 'IMDELTAN_SYNTHETIC_B_JWT':self.tb, 'IMDELTAN_SYNTHETIC_A_PRIVATE_POST_ID':self.pa, 'IMDELTAN_SYNTHETIC_B_PRIVATE_POST_ID':self.pb}
    def test_only_synthetic_issuer_target_and_distinct_users(self):
        self.runner.get_configured(self.env)
        for field,value in [('IMDELTAN_SYNTHETIC_PROJECT_URL','https://bdhcpgqxhnecrcopoxge.supabase.co'),('IMDELTAN_SYNTHETIC_A_JWT',jwt(self.a,'https://bdhcpgqxhnecrcopoxge.supabase.co')),('IMDELTAN_SYNTHETIC_A_JWT',jwt(self.a,m.synthetic.PROJECT_URL,role='service_role')),('IMDELTAN_SYNTHETIC_A_JWT',jwt(self.a,m.synthetic.PROJECT_URL,exp=time.time()-1)),('IMDELTAN_SYNTHETIC_B_JWT',self.ta),('IMDELTAN_SYNTHETIC_B_PRIVATE_POST_ID',self.pa)]:
            with self.subTest(field=field),self.assertRaises(ValueError):self.runner.get_configured({**self.env,field:value})
    def fake(self,path,key,token):
        uid,post=(self.a,self.pa) if token==self.ta else (self.b,self.pb)
        if path=='/auth/v1/user':return 200,{'id':uid,'email':'private-not-logged@example.test'}
        if '/profiles?' in path:return 200,([{'user_id':uid}] if 'eq.'+uid in path else [])
        if '/posts?' in path:return 200,([{'id':post,'author_id':uid}] if 'eq.'+post in path else [])
        return 403,{'code':'42501','message':'not-logged'}
    def test_positive_controls_and_no_secret_output(self):
        output=[];self.runner.run(*self.runner.get_configured(self.env),request=self.fake,emit=output.append)
        text=' '.join(output)
        for val in (self.ta,self.tb,self.a,self.b,'private-not-logged','not-logged'):self.assertNotIn(val,text)
        self.assertEqual(len(output),3)
    def test_cross_user_leak_and_missing_own_control_fail(self):
        def leak(path,key,token):
            if '/posts?' in path and token==self.ta and 'eq.'+self.pb in path:return 200,[{'id':self.pb,'author_id':self.b}]
            return self.fake(path,key,token)
        with self.assertRaises(RuntimeError):self.runner.run(*self.runner.get_configured(self.env),request=leak,emit=lambda _:None)
        def missing(path,key,token):return (200,[]) if '/profiles?' in path else self.fake(path,key,token)
        with self.assertRaises(RuntimeError):self.runner.run(*self.runner.get_configured(self.env),request=missing,emit=lambda _:None)
if __name__=='__main__':unittest.main()
