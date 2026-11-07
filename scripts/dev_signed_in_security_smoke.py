#!/usr/bin/env python3
"""Optional read-only, two-synthetic-user authorization smoke test.

Dev target is hardcoded; credentials and fixture IDs come only from the process
environment and are never printed or persisted. Requires pre-approved synthetic
accounts and one private post per account. No provisioning or writes occur.
This is not a security certification or exhaustive API coverage.
"""
import base64,json,os,sys,time,uuid,urllib.error,urllib.request
from dev_anonymous_security_smoke import PROJECT_URL,NoRedirect,get_config

CONFIRM='SYNTHETIC-DEV-ONLY'
def parse_uuid(value):
 try:return str(uuid.UUID(value))
 except (TypeError,ValueError,AttributeError):raise ValueError('A required synthetic fixture ID is missing or invalid.') from None

def claims(token):
 try:
  if not isinstance(token,str) or len(token)>8192:raise ValueError()
  parts=token.split('.')
  if len(parts)!=3:raise ValueError()
  payload=json.loads(base64.urlsafe_b64decode(parts[1]+'='*(-len(parts[1])%4)))
  subject=parse_uuid(payload.get('sub'));aud=payload.get('aud');issuer=payload.get('iss');exp=payload.get('exp')
  if issuer!=PROJECT_URL+'/auth/v1' or payload.get('role')!='authenticated' or not (aud=='authenticated' or isinstance(aud,list) and 'authenticated' in aud) or not isinstance(exp,(int,float)) or isinstance(exp,bool) or exp<=time.time():raise ValueError()
  return subject
 except (ValueError,TypeError,UnicodeError,json.JSONDecodeError):raise ValueError('A synthetic user token is missing, expired or not valid for this development project.') from None

def get_configured(env=os.environ):
 if env.get('IMDELTAN_SYNTHETIC_TESTS_CONFIRMED')!=CONFIRM:raise ValueError('Synthetic-only confirmation is required; do not use real accounts or data.')
 key=get_config(env);token_a=env.get('IMDELTAN_SYNTHETIC_A_JWT','');token_b=env.get('IMDELTAN_SYNTHETIC_B_JWT','');a=claims(token_a);b=claims(token_b)
 pa=parse_uuid(env.get('IMDELTAN_SYNTHETIC_A_PRIVATE_POST_ID'));pb=parse_uuid(env.get('IMDELTAN_SYNTHETIC_B_PRIVATE_POST_ID'))
 if a==b or pa==pb:raise ValueError('The two synthetic users and private-post fixtures must be distinct.')
 return key,(a,token_a,pa),(b,token_b,pb)

def fetch(path,key,token,opener=None):
 if not path.startswith('/') or path.startswith('//') or '\n' in path or '\r' in path:raise ValueError('Invalid test path.')
 req=urllib.request.Request(PROJECT_URL+path,headers={'apikey':key,'Authorization':'Bearer '+token,'Accept':'application/json'},method='GET')
 try:
  with (opener or urllib.request.build_opener(NoRedirect())).open(req,timeout=15) as response:return response.status,json.loads(response.read(16384))
 except urllib.error.HTTPError as error:
  try:body=json.loads(error.read(4096))
  except (ValueError,UnicodeError):body={}
  return error.code,body

def run(key,a,b,request=fetch,emit=print):
 for label,own,other in [('A',a,b),('B',b,a)]:
  uid,token,post=own;other_uid,_,other_post=other
  status,body=request('/auth/v1/user',key,token)
  if status!=200 or not isinstance(body,dict) or body.get('id')!=uid:raise RuntimeError('Synthetic user '+label+' identity control failed.')
  for desc,target,expected in [('own',uid,True),('other',other_uid,False)]:
   status,rows=request('/rest/v1/profiles?select=user_id&user_id=eq.'+target+'&limit=1',key,token)
   if status!=200 or not isinstance(rows,list) or rows!=([{'user_id':uid}] if expected else []):raise RuntimeError('Synthetic user '+label+' '+desc+' profile check failed or fixture is not eligible.')
  for desc,target,expected in [('own',post,True),('other',other_post,False)]:
   status,rows=request('/rest/v1/posts?select=id,author_id&id=eq.'+target+'&limit=1',key,token)
   if status!=200 or not isinstance(rows,list) or rows!=([{'id':post,'author_id':uid}] if expected else []):raise RuntimeError('Synthetic user '+label+' '+desc+' private-post check failed or fixture is missing.')
  for path in ('/rest/v1/admin_role_assignments?select=*&limit=0','/rest/v1/rpc/list_reports_for_review?limit=0'):
   status,body=request(path,key,token)
   if status not in (401,403) or not isinstance(body,dict) or body.get('code')!='42501':raise RuntimeError('Synthetic user '+label+' admin-denial check failed or was inconclusive.')
  emit('PASS: synthetic user '+label+' identity, profile/post isolation and admin denials')
 emit('PASS: selected two-user checks only; broader authorization still requires review')

def main():
 try:run(*get_configured())
 except Exception as exc:
  if isinstance(exc,(ValueError,RuntimeError)):print('FAIL:',str(exc),file=sys.stderr)
  else:print('FAIL: network or response error ('+type(exc).__name__+')',file=sys.stderr)
  return 1
 return 0
if __name__=='__main__':sys.exit(main())
