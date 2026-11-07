#!/usr/bin/env python3
"""Read-only, tightly scoped anonymous smoke test for the NEW dev project only.

Uses an existing publishable key, never a user/service token. Does not create
users, policies, database rows, storage objects, or print response bodies/keys.
This is a narrow smoke test, not proof of application or production security.
"""
import json, os, re, sys, urllib.error, urllib.request
from pathlib import Path

PROJECT_URL='https://bdhcpgqxhnecrcopoxge.supabase.co'
ROOT=Path(__file__).resolve().parents[1]
TABLES=('profiles','user_eligibility','policy_acceptances','posts','user_reports','community_groups','community_group_memberships','friend_requests','user_blocks','messages','admin_role_assignments','audit_logs','notifications','post_media')
READ_RPCS=('list_reports_for_review','get_own_onboarding_status','list_own_group_invitations','list_own_blocks','list_current_required_policies')
BUCKETS=('community-images','cover-pictures','message-attachments','post-images','profile-pictures','video-uploads')

class NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,*args,**kwargs): return None

def get_config(env=os.environ,path=ROOT/'apps/customer/.env.local'):
 data={}
 if path.exists():
  for line in path.read_text().splitlines():
   if '=' in line and not line.lstrip().startswith('#'):
    key,_,value=line.partition('=');data[key.strip()]=value.strip().strip("'\"")
 url=env.get('VITE_SUPABASE_URL',data.get('VITE_SUPABASE_URL',''))
 key=env.get('VITE_SUPABASE_PUBLISHABLE_KEY',data.get('VITE_SUPABASE_PUBLISHABLE_KEY',''))
 if url!=PROJECT_URL:raise ValueError('Wrong target: this test only permits the dedicated development URL.')
 if not re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]{20,}',key):raise ValueError('A publishable key is required; secret, service-role and legacy keys are not accepted.')
 return key

def fetch(path,key,opener=None):
 if not path.startswith('/') or path.startswith('//') or '?' in path and ('limit=0' not in path):raise ValueError('Invalid test path.')
 req=urllib.request.Request(PROJECT_URL+path,headers={'apikey':key,'Accept':'application/json'},method='GET')
 try:
  with (opener or urllib.request.build_opener(NoRedirect())).open(req,timeout=15) as response:
   return response.status,json.loads(response.read(16384))
 except urllib.error.HTTPError as error:
  try:body=json.loads(error.read(4096))
  except (ValueError,UnicodeError):body={}
  return error.code,body

def run(key,request=fetch,emit=print):
 # A successful real auth settings response is a positive key/connectivity control.
 status,settings=request('/auth/v1/settings',key)
 if status!=200 or not isinstance(settings,dict):raise RuntimeError('Auth-settings control failed; no denial results are accepted.')
 providers=settings.get('external')
 if settings.get('disable_signup') is not True or not isinstance(providers,dict) or providers.get('email') is not True or any(providers.get(name) is not False for name in ('anonymous_users','phone','google')) or any(value is not False for name,value in providers.items() if name!='email'):
  raise RuntimeError('Unexpected public signup/provider configuration; inspect the development dashboard.')
 emit('PASS: development auth settings control; signup disabled; email is the only enabled external provider')
 failed=[]
 for table in TABLES:
  status,body=request('/rest/v1/'+table+'?select=*&limit=0',key)
  ok=status in (401,403) and isinstance(body,dict) and body.get('code')=='42501'
  emit(('PASS' if ok else 'FAIL')+': anonymous table access denied: '+table)
  if not ok:failed.append('table '+table)
 for rpc in READ_RPCS:
  status,body=request('/rest/v1/rpc/'+rpc+'?limit=0',key)
  ok=status in (401,403) and isinstance(body,dict) and body.get('code')=='42501'
  emit(('PASS' if ok else 'FAIL')+': anonymous RPC access denied: '+rpc)
  if not ok:failed.append('RPC '+rpc)
 for bucket in BUCKETS:
  status,body=request('/storage/v1/bucket/'+bucket,key)
  ok=status==400 and isinstance(body,dict) and body.get('error')=='Bucket not found'
  emit(('PASS' if ok else 'FAIL')+': anonymous bucket metadata not returned: '+bucket)
  if not ok:failed.append('bucket '+bucket)
 if failed:raise RuntimeError(str(len(failed))+' anonymous checks failed or were inconclusive; see check names above.')
 emit('PASS: 14 table, 5 read-only RPC and 6 bucket-metadata checks; no object or row data requested')

def main():
 try:run(get_config())
 except Exception as exc:
  # Do not print HTTP bodies, headers, paths with query credentials, or keys.
  if isinstance(exc,(ValueError,RuntimeError)):print('FAIL:',str(exc),file=sys.stderr)
  else:print('FAIL: network or response error ('+type(exc).__name__+')',file=sys.stderr)
  return 1
 return 0
if __name__=='__main__':sys.exit(main())
