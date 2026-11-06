#!/usr/bin/env python3
"""Create a source-only sync bundle; excludes local environment and signing files."""
from pathlib import Path
import hashlib
import re
import zipfile

root=Path(__file__).resolve().parents[1]
target=root.parent/'IMDELTAN-delivery'/'IMDELTAN-update.zip'
target.parent.mkdir(parents=True,exist_ok=True)
include=['.github','apps','docs','prototypes','scripts','supabase','tests','.env.example','.gitignore','README.md']
exclude={'node_modules','dist','build','.gradle','__pycache__','.git','.cache','capacitor-cordova-android-plugins'}
files=[]
for name in include:
    path=root/name
    if path.is_file():
        files.append(path)
        continue
    for file in path.rglob('*'):
        rel=file.relative_to(root)
        if not file.is_file() or any(part in exclude for part in rel.parts): continue
        if file.name.startswith('.env') and file.name!='.env.example': continue
        if file.name in {'local.properties','capacitor.config.json','capacitor.plugins.json'} and 'android/app/src/main/assets' in str(rel): continue
        if 'android/app/src/main/assets/public' in str(rel): continue
        if file.suffix.lower() in {'.apk','.aab','.jks','.keystore','.log','.pyc'}: continue
        files.append(file)
patterns=[re.compile(rb'sb_secret_[A-Za-z0-9_]{15,}'),re.compile(rb'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'),re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')]
for file in files:
    if file.stat().st_size<3_000_000 and file.suffix.lower() not in ('.jpg','.jpeg','.png','.jar'):
        if any(pattern.search(file.read_bytes()) for pattern in patterns):
            raise SystemExit('Possible sensitive value detected in '+str(file.relative_to(root)))
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=8) as archive:
    for file in sorted(files): archive.write(file,file.relative_to(root).as_posix())
with zipfile.ZipFile(target) as archive:
    if archive.testzip() is not None: raise SystemExit('Archive validation failed')
    names=archive.namelist()
    if any(name.endswith('.env.local') for name in names): raise SystemExit('Local environment file included')
    print(f'Bundle: {len(names)} files, {target.stat().st_size} bytes')
print('SHA-256: '+hashlib.sha256(target.read_bytes()).hexdigest())
print(target)
