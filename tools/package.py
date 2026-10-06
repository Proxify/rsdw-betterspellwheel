#!/usr/bin/env python3
"""Build a standalone archive, excluding all development inputs."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
import re
root = Path(__file__).resolve().parents[1]
version = re.search(r"version='([^']+)'", (root / 'Scripts/main.lua').read_text()).group(1)
dist = root.parents[1] / 'dist'
dist.mkdir(exist_ok=True)
archive = dist / f'SpellBranches-{version}.zip'
files = sorted((root / 'Scripts').glob('*.lua')) + sorted((root / 'Assets').glob('*.png'))
files += [root / name for name in ('config.txt', 'README.md', 'enabled.txt')]
with ZipFile(archive, 'w', ZIP_DEFLATED) as z:
    for path in files:
        z.write(path, Path('SpellBranches') / path.relative_to(root))
with ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist()) == len(files)
    assert all('/tests/' not in n and '/data/' not in n and not n.endswith('dev.txt') for n in z.namelist())
print(f'{archive} ({len(files)} files, {archive.stat().st_size:,} bytes)')
