"""Source-only bundle must not include local config, signing keys or builds."""
import subprocess,tempfile,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class SyncBundlePrivacy(unittest.TestCase):
 def test_local_files_are_excluded(self):
  with tempfile.TemporaryDirectory(dir=ROOT/'scripts',prefix='bundle_test_') as source, tempfile.TemporaryDirectory(dir=ROOT.parent,prefix='bundle_output_') as output:
   folder=Path(source)
   for name in ('local.properties','.env.local','google-services.json','signing.key','private.pem','private.p12'):(folder/name).write_text('synthetic-placeholder')
   (folder/'safe.txt').write_text('safe synthetic fixture')
   dest=Path(output)/'review.zip'
   subprocess.run(['python3',str(ROOT/'scripts/build_sync_bundle.py'),'--output',str(dest)],check=True,capture_output=True,text=True)
   with zipfile.ZipFile(dest) as z:
    names=z.namelist();base=folder.relative_to(ROOT).as_posix()+'/'
    gradle=z.getinfo('apps/customer/android/gradlew')
    self.assertEqual(gradle.create_system,3)
    self.assertEqual((gradle.external_attr >> 16) & 0o777,0o755)
    self.assertIn(base+'safe.txt',names)
    for name in ('local.properties','.env.local','google-services.json','signing.key','private.pem','private.p12'):self.assertNotIn(base+name,names)
    self.assertFalse(any(n.endswith('/.env.local') or '/node_modules/' in n or '/dist/' in n or n.endswith(('.apk','.aab','.jks','.keystore')) for n in names))
 def test_gradle_zip_mode_does_not_depend_on_source_permissions(self):
  with tempfile.TemporaryDirectory(dir=ROOT.parent,prefix='bundle_mode_') as temp:
   project=Path(temp)/'project'; (project/'scripts').mkdir(parents=True); (project/'apps/customer/android').mkdir(parents=True)
   (project/'scripts/build_sync_bundle.py').write_bytes((ROOT/'scripts/build_sync_bundle.py').read_bytes())
   wrapper=project/'apps/customer/android/gradlew';wrapper.write_text('#!/bin/sh\n');wrapper.chmod(0o644)
   dest=Path(temp)/'test.zip'
   subprocess.run(['python3',str(project/'scripts/build_sync_bundle.py'),'--output',str(dest)],check=True,capture_output=True,text=True)
   with zipfile.ZipFile(dest) as z:
    info=z.getinfo('apps/customer/android/gradlew');self.assertEqual(info.create_system,3);self.assertEqual((info.external_attr>>16)&0o777,0o755)
 def test_outside_workspace_is_rejected(self):
  r=subprocess.run(['python3',str(ROOT/'scripts/build_sync_bundle.py'),'--output','/tmp/outside-imdeltan.zip'],capture_output=True,text=True)
  self.assertNotEqual(r.returncode,0)
if __name__=='__main__':unittest.main()
