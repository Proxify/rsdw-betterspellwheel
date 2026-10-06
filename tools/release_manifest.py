"""Shared production file list for the ZIP and Windows installer."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
MOD = 'BetterSpellWheel'

def version():
    return re.search(r"version='([^']+)'", (ROOT / 'Scripts/main.lua').read_text()).group(1)

def production_files():
    files = sorted((ROOT / 'Scripts').rglob('*.lua')) + sorted((ROOT / 'Assets').rglob('*.png'))
    files += [ROOT / name for name in ('config.txt', 'README.md', 'enabled.txt', 'INSTALL.txt')]
    for p in files:
        assert p.is_file() and not p.is_symlink(), p
    return {f'{MOD}/{p.relative_to(ROOT).as_posix()}': p.read_bytes() for p in files}
