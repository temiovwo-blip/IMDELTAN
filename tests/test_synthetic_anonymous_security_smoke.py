import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('synthetic_smoke', ROOT / 'scripts/synthetic_anonymous_security_smoke.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class SyntheticSmokeTests(unittest.TestCase):
    def setUp(self):
        self.env = {'IMDELTAN_SYNTHETIC_TESTS_CONFIRMED':'SYNTHETIC-ONLY-UXFYHPUKEQTTRVCFEMTS', 'IMDELTAN_SYNTHETIC_PROJECT_URL':m.PROJECT_URL, 'IMDELTAN_SYNTHETIC_PUBLISHABLE_KEY':'sb_publishable_'+'x'*24}
    def test_target_and_key_are_strict(self):
        self.assertEqual(m.get_key(self.env), self.env['IMDELTAN_SYNTHETIC_PUBLISHABLE_KEY'])
        for name, bad in [('IMDELTAN_SYNTHETIC_PROJECT_URL','https://bdhcpgqxhnecrcopoxge.supabase.co'),('IMDELTAN_SYNTHETIC_PROJECT_URL','https://example.com'),('IMDELTAN_SYNTHETIC_TESTS_CONFIRMED','yes'),('IMDELTAN_SYNTHETIC_PUBLISHABLE_KEY','sb_secret_'+'x'*24)]:
            value = dict(self.env); value[name] = bad
            with self.assertRaises(ValueError): m.get_key(value)
        with self.assertRaises(ValueError): m.get_key({})
    def test_loader_pins_separate_module(self):
        runner = m.load_runner()
        self.assertEqual(runner.PROJECT_URL,m.PROJECT_URL)
        spec2=importlib.util.spec_from_file_location('original_dev',ROOT/'scripts/dev_anonymous_security_smoke.py')
        original=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(original)
        self.assertEqual(original.PROJECT_URL,'https://bdhcpgqxhnecrcopoxge.supabase.co')
    def test_scope_and_positive_control(self):
        runner=m.load_runner(); paths=[]
        def fake(path,key):
            paths.append(path)
            if path=='/auth/v1/settings': return 200,{'disable_signup':True,'external':{'email':True,'google':False,'phone':False,'anonymous_users':False}}
            if path.startswith('/storage/'): return 400,{'error':'Bucket not found'}
            return 403,{'code':'42501'}
        runner.run(m.get_key(self.env),fake,lambda _:None)
        self.assertEqual(len(paths),26)
        self.assertTrue(all(p.endswith('limit=0') for p in paths[1:20]))
        with self.assertRaises(RuntimeError):runner.run(m.get_key(self.env),lambda *_:(401,{}),lambda _:None)
if __name__ == '__main__': unittest.main()
