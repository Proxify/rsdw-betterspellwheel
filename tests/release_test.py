#!/usr/bin/env python3
"""Verify the delivered ZIP and executable contain identical production bytes."""
from pathlib import Path
from zipfile import ZipFile
import importlib.util
import hashlib
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from release_manifest import production_files, version
spec=importlib.util.spec_from_file_location('installer_build',root/'installer/build.py')
build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
archive, exe=map(Path,sys.argv[1:3])
expected=production_files()
with ZipFile(archive) as z:
    assert z.testzip() is None
    assert set(z.namelist())==set(expected)|{'INSTALL.txt'}
    assert z.read('INSTALL.txt')==(root/'INSTALL.txt').read_bytes()
    for name, body in expected.items(): assert z.read(name)==body,name
    assert not any(n.lower().endswith('.exe') for n in z.namelist())
payload=build.unpack(exe.read_bytes())
assert payload['VERSION'].decode()==version()
assert {n:b for n,b in payload.items() if n.startswith('BetterSpellWheel/')}==expected
assert set(payload)==set(expected)|{'VERSION','dwmapi.dll','UE4SS.dll','UE4SS-settings.ini','UE4SS-LICENSE.txt'}
# A truncated footer must not be accepted as a valid installer.
try: build.unpack(exe.read_bytes()[:-1])
except (AssertionError,ValueError): pass
else: raise AssertionError('truncated installer accepted')
for p in [archive,exe]: print(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name)
print(f'PASS: {len(expected)} production files match source in ZIP and EXE; root INSTALL.txt present; EXE separate')
