#!/usr/bin/env python3
"""Narrow anonymous, read-only smoke for the isolated synthetic project only.

Provide its publishable key as IMDELTAN_SYNTHETIC_PUBLISHABLE_KEY. No local
.env is loaded. No fixture, account, database or storage write is made.
"""
import importlib.util
import os
from pathlib import Path
import re
import sys

PROJECT_URL = 'https://uxfyhpukeqttrvcfemts.supabase.co'
HERE = Path(__file__).resolve().parent

def load_runner():
    spec = importlib.util.spec_from_file_location('_synthetic_anon_runner', HERE / 'dev_anonymous_security_smoke.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # This is a separate module instance: the regular dev smoke stays dev-pinned.
    module.PROJECT_URL = PROJECT_URL
    return module

def get_key(env=os.environ):
    if env.get('IMDELTAN_SYNTHETIC_TESTS_CONFIRMED') != 'SYNTHETIC-ONLY-UXFYHPUKEQTTRVCFEMTS':
        raise ValueError('Explicit synthetic-only confirmation is required.')
    if env.get('IMDELTAN_SYNTHETIC_PROJECT_URL') != PROJECT_URL:
        raise ValueError('Only the isolated synthetic project URL is allowed.')
    key = env.get('IMDELTAN_SYNTHETIC_PUBLISHABLE_KEY', '')
    if not re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]{20,}', key):
        raise ValueError('A synthetic project publishable key is required, never a secret or legacy key.')
    return key

def main():
    try:
        key = get_key()
        print('Target: isolated synthetic project; read-only checks')
        load_runner().run(key, emit=lambda message: print(message.replace('development', 'synthetic test')))
    except Exception as exc:
        if isinstance(exc, (ValueError, RuntimeError)):
            print('FAIL:', str(exc), file=sys.stderr)
        else:
            print('FAIL: network or response error (' + type(exc).__name__ + ')', file=sys.stderr)
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
