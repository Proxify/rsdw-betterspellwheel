#!/usr/bin/env python3
"""Build the mod ZIP with installation instructions; the setup EXE is separate."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
import argparse
from release_manifest import ROOT, MOD, version, production_files
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, default=ROOT / 'dist')
dist = parser.parse_args().output_dir
dist.mkdir(parents=True, exist_ok=True)
archive = dist / f'{MOD}-{version()}.zip'
files = production_files()
files['INSTALL.txt'] = (ROOT / 'INSTALL.txt').read_bytes()
with ZipFile(archive, 'w', ZIP_DEFLATED) as z:
    for name, body in files.items():
        z.writestr(name, body)
with ZipFile(archive) as z:
    assert z.testzip() is None
    assert set(z.namelist()) == set(files)
    for name, body in files.items():
        assert z.read(name) == body
    assert not any(n.endswith(('.exe', 'dev.txt')) or '/tests/' in n or '/data/' in n for n in z.namelist())
print(f'{archive} ({len(files)} files, {archive.stat().st_size:,} bytes)')
