#!/usr/bin/env python3
"""Run Lua 5.4 syntax and interaction checks with the project's lupa venv."""
from pathlib import Path
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for path in sorted(root.rglob("*.lua")):
    error = lua.execute("local f,e=load(...); return e", path.read_text())
    assert error is None, f"{path}: {error}"
lua.globals().arg = lua.table_from([str(root / "Scripts/model.lua")])
lua.execute((root / "tests/model_test.lua").read_text())
lua.globals().snapshot_path = str(root / "tests/live_catalogue_snapshot.lua")
lua.execute("""
local model = dofile(arg[1])
local records = dofile(snapshot_path)
local groups = model.catalogue(records)
assert(#records == 39 and #groups == 12)
local checked = 0
for _,group in ipairs(groups) do
    for _,spell in ipairs(group.spells) do
        assert(spell.skill == group.id, spell.id)
        checked = checked + 1
    end
end
assert(checked == 39)
assert(groups[12].spells[1].id == 'USD_Windstep')
assert(#groups[8].spells == 4 and #groups[12].spells == 3)
print('PASS: all 39 progression records, including Windstep in Agility')
""")
lua.execute((root / "tests/catalogue_test.lua").read_text())
lua.execute((root / "tests/layout_test.lua").read_text())
lua.execute((root / "tests/controller_test.lua").read_text())
lua.execute((root / "tests/input_test.lua").read_text())
lua.execute((root / "tests/runtime_test.lua").read_text())

# Wheel artwork: drawn by Scripts/art.lua into Assets/, valid PNGs, cached.
import struct, tempfile, zlib
def png_info(data):
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, ihdr = 8, b'', None
    while pos < len(data):
        n, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        assert struct.unpack('>I', data[pos + 8 + n:pos + 12 + n])[0] == zlib.crc32(kind + body), kind
        if kind == b'IHDR': ihdr = struct.unpack('>IIBBBBB', body)
        if kind == b'IDAT': idat += body
        pos += 12 + n
    w, h = ihdr[0], ihdr[1]
    raw = zlib.decompress(idat)
    assert ihdr[2:5] == (8, 6, 0) and len(raw) == h * (w * 4 + 1)
    return w, h, raw
with tempfile.TemporaryDirectory() as tmp:
    (Path(tmp) / 'Assets').mkdir()
    art = lua.execute('return dofile(...)', str(root / 'Scripts/art.lua'))
    ensure = lua.eval('function(A, d) return A.ensure(d) end')
    assert ensure(art, tmp) == 6 and ensure(art, tmp) == 0
    sizes = {'skill': (848, 848), 'skill_active': (848, 848), 'spell': (848, 848), 'spell_active': (848, 848),
             'center': (848, 848), 'tooltip': (1560, 192)}
    for name, size in sizes.items():
        w, h, raw = png_info((Path(tmp) / 'Assets' / f'{name}.png').read_bytes())
        assert (w, h) == size, name
        def alpha(x, y): return raw[y * (w * 4 + 1) + 1 + x * 4 + 3]
        assert alpha(0, 0) == 0, name  # corners stay transparent
    w, h, raw = png_info((Path(tmp) / 'Assets' / 'skill.png').read_bytes())
    assert raw[(424 - 200) * (w * 4 + 1) + 1 + 424 * 4 + 3] > 200  # inside the north skill sector
    (Path(tmp) / 'Assets' / 'art-version.txt').write_text('0')
    assert ensure(art, tmp) == 6  # a new art version redraws everything
print('PASS: wheel artwork drawn as valid PNGs (6 textures), cached, redrawn on version change')
