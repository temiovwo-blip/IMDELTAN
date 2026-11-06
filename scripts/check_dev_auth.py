#!/usr/bin/env python3
"""Negative checks against a configured development Auth service; no user is created.
Run with the two public VITE_SUPABASE_* environment variables set.
Never use service-role credentials or run against production.
"""
import json
import os
import urllib.error
import urllib.request
from urllib.parse import urlparse

url = os.environ['VITE_SUPABASE_URL'].rstrip('/')
key = os.environ['VITE_SUPABASE_PUBLISHABLE_KEY']
if urlparse(url).scheme != 'https' or not key.startswith('sb_publishable_'):
    raise SystemExit('Expected HTTPS and a publishable key; refusing to run.')

def request(path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url + path, data=data, headers={'apikey': key, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)

status, settings = request('/auth/v1/settings')
if status != 200 or settings.get('disable_signup') is not True:
    raise SystemExit('Auth unreachable or signup is not confirmed disabled.')
payload = {'email': 'imdeltan-synthetic-test@example.invalid', 'password': 'Synthetic-Invalid-Login-876!'}
status, result = request('/auth/v1/signup', payload)
if status not in (400, 403, 422) or result.get('error_code') != 'signup_disabled':
    raise SystemExit('Signup was not rejected with signup_disabled.')
status, result = request('/auth/v1/token?grant_type=password', payload)
if status not in (400, 401) or result.get('error_code') != 'invalid_credentials':
    raise SystemExit('Invalid sign-in did not produce the expected rejection.')
print('PASS: auth reachable, signup closed, synthetic invalid sign-in rejected.')
print('NOTE: no successful sign-in, device, database, or full security test was performed.')
