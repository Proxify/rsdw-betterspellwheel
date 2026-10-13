"""Shared production file list for the ZIP and Windows installer."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
MOD = 'BetterSpellWheel'

def version():
    return re.search(r"version='([^']+)'", (ROOT / 'Scripts/main.lua').read_text()).group(1)

# CurseForge accepts only these extensions in RSDragonwilds UE4SS mods (a ZIP
# with .png or .md files is rejected). Every release ZIP must pass this check.
ALLOWED_EXTENSIONS = ('.txt', '.lua', '.dll', '.pak', '.utoc', '.ucas')

def check_allowed(names):
    bad = [n for n in names if not n.lower().endswith(ALLOWED_EXTENSIONS)]
    assert not bad, f'not allowed on CurseForge: {bad}'

def production_files():
    files = {f'{MOD}/{p.relative_to(ROOT).as_posix()}': p for p in sorted((ROOT / 'Scripts').rglob('*.lua'))}
    for name in ('config.txt', 'enabled.txt', 'INSTALL.txt'):
        files[f'{MOD}/{name}'] = ROOT / name
    # Shipped under allowed names; the artwork is drawn at runtime into Assets/.
    files[f'{MOD}/README.txt'] = ROOT / 'README.md'
    files[f'{MOD}/LICENSE.txt'] = ROOT / 'LICENSE'
    files[f'{MOD}/NOTICE.txt'] = ROOT / 'NOTICE'
    files[f'{MOD}/Assets/README.txt'] = ROOT / 'Assets' / 'README.txt'
    for p in files.values():
        assert p.is_file() and not p.is_symlink(), p
    check_allowed(files)
    return {name: p.read_bytes() for name, p in files.items()}
