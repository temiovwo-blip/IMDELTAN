#!/usr/bin/env python3
"""Opt-in, read-only two-user smoke for the isolated synthetic project.

Requires already-provisioned synthetic users, valid short-lived user JWTs and
one private post per user. Does not create, delete or modify any data. Output
contains no user IDs, JWTs, keys or response bodies. Local JWT claim parsing is
NOT signature verification; /auth/v1/user is the positive service control.
"""
import importlib.util
import sys
from pathlib import Path
import synthetic_anonymous_security_smoke as synthetic

HERE = Path(__file__).resolve().parent

def load_runner():
    spec=importlib.util.spec_from_file_location('_synthetic_signed_runner',HERE/'dev_signed_in_security_smoke.py')
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.PROJECT_URL=synthetic.PROJECT_URL
    module.CONFIRM='SYNTHETIC-ONLY-UXFYHPUKEQTTRVCFEMTS'
    module.get_config=synthetic.get_key
    return module

def main():
    try:
        runner=load_runner()
        print('Target: isolated synthetic project; read-only signed-in checks')
        runner.run(*runner.get_configured())
    except Exception as exc:
        if isinstance(exc,(ValueError,RuntimeError)):
            print('FAIL:',str(exc).replace('development project','synthetic project'),file=sys.stderr)
        else:
            print('FAIL: network or response error ('+type(exc).__name__+')',file=sys.stderr)
        return 1
    return 0

if __name__=='__main__':
    sys.exit(main())
