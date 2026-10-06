#!/usr/bin/env python3
"""Build a standalone archive, excluding all development inputs."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
import argparse
import re
root = Path(__file__).resolve().parents[1]
version = re.search(r"version='([^']+)'", (root / 'Scripts/main.lua').read_text()).group(1)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, default=root / 'dist')
dist = parser.parse_args().output_dir
dist.mkdir(exist_ok=True)
archive = dist / f'BetterSpellWheel-{version}.zip'
files = sorted((root / 'Scripts').glob('*.lua')) + sorted((root / 'Assets').glob('*.png'))
files += [root / name for name in ('config.txt', 'README.md', 'enabled.txt')]
with ZipFile(archive, 'w', ZIP_DEFLATED) as z:
    for path in files:
        z.write(path, Path('BetterSpellWheel') / path.relative_to(root))
with ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist()) == len(files)
    assert all('/tests/' not in n and '/data/' not in n and not n.endswith('dev.txt') for n in z.namelist())
print(f'{archive} ({len(files)} files, {archive.stat().st_size:,} bytes)')
