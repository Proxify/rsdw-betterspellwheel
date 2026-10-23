#!/usr/bin/env python3
"""Run Lua 5.4 syntax and interaction checks with the project's lupa venv."""
from pathlib import Path
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for path in sorted(root.rglob("*.lua")):
    error = lua.execute("local f,e=load(...); return e", path.read_text())
    assert error is None, f"{path}: {error}"
lua.globals().arg = lua.table_from([(root / "Scripts/model.lua").as_posix()])
lua.execute((root / "tests/model_test.lua").read_text())
lua.globals().snapshot_path = (root / "tests/live_catalogue_snapshot.lua").as_posix()
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
lua.execute((root / "tests/view_perf_test.lua").read_text())

lua.globals().arg = lua.table_from([(root / "Scripts/model.lua").as_posix()])
lua.execute((root / "tests/art_view_test.lua").read_text())

# Wheel artwork: drawn by Scripts/art.lua into Assets/v2/, valid PNGs, cached.
# Each cropped texture must be byte-identical to its region of the image the
# frozen 0.4.5 generator (tests/reference/art-v1.lua) draws now, with nothing
# non-zero outside the crop and a transparent border (see A.crops).
import hashlib, struct, tempfile, zlib
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
    assert all(raw[y * (w * 4 + 1)] == 0 for y in range(h))  # filter byte None
    return w, h, [raw[y * (w * 4 + 1) + 1:(y + 1) * (w * 4 + 1)] for y in range(h)]
blua = LuaRuntime(unpack_returned_tuples=True, encoding=None)  # PNGs are bytes
art1 = blua.execute(b'return dofile(...)', str(root / 'tests/reference/art-v1.lua').encode())
art2 = blua.execute(b'return dofile(...)', str(root / 'Scripts/art.lua').encode())
names = ['skill', 'skill_active', 'spell', 'spell_active', 'center', 'tooltip']
crops = {n: tuple(art2.crops[n.encode()][k] for k in (1, 2, 3, 4)) for n in names}
ensure1 = blua.eval(b'function(A, d) return A.ensure(d) end')
def files(base):
    return {p.relative_to(base).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(Path(base).rglob('*')) if p.is_file()}
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    ensure = lambda: ensure1(art2, str(tmp).encode())
    # Fresh install: no Assets folder at all.
    assert ensure() == 6 and ensure() == 0
    v1bytes = v2bytes = v1rgba = v2rgba = 0
    for n in names:
        x0, y0, cw, ch = crops[n]
        data = (tmp / 'Assets/v2' / f'{n}.png').read_bytes()
        assert data == art2.textures[n.encode()](), n  # cache holds the drawing
        w, h, rows = png_info(data)
        assert (w, h) == (cw, ch), n
        fw, fh, full = png_info(art1.textures[n.encode()]())
        v1bytes += len(art1.textures[n.encode()]()); v2bytes += len(data)
        v1rgba += fw * fh * 4; v2rgba += w * h * 4
        # Reassemble: crop pasted into a zero frame == the version 1 frame, byte for byte.
        blank = bytes(fw * 4)
        for y in range(fh):
            if y0 <= y < y0 + ch:
                row = blank[:x0 * 4] + rows[y - y0] + blank[(x0 + cw) * 4:]
            else:
                row = blank
            assert row == full[y], f'{n} row {y} differs from the 0.4.5 artwork'
        # Transparent border wherever the crop is inside the frame; where it meets
        # the frame edge (spell_active top row), the opposite edge is transparent.
        zero_col = lambda x: all(r[x * 4:x * 4 + 4] == b'\0\0\0\0' for r in rows)
        zero_row = lambda y: not any(rows[y])
        for edge, inside, ok, opposite in (('left', x0 > 0, lambda: zero_col(0), lambda: zero_col(w - 1)),
                                           ('right', x0 + cw < fw, lambda: zero_col(w - 1), lambda: zero_col(0)),
                                           ('top', y0 > 0, lambda: zero_row(0), lambda: zero_row(h - 1)),
                                           ('bottom', y0 + ch < fh, lambda: zero_row(h - 1), lambda: zero_row(0))):
            assert ok() if inside else opposite(), f'{n} {edge} edge'
    assert v2bytes < v1bytes / 8, (v1bytes, v2bytes)
    print(f'PASS: 6 cropped textures byte-identical to the 0.4.5 artwork after reassembly; '
          f'decoded RGBA {v1rgba} -> {v2rgba} bytes, PNG {v1bytes} -> {v2bytes} bytes')
    v2 = tmp / 'Assets/v2'
    # Damaged or foreign cache files are redrawn; good ones are kept.
    good = files(tmp)
    (v2 / 'spell.png').write_bytes((v2 / 'spell.png').read_bytes()[:5000])   # truncated
    (v2 / 'skill.png').write_bytes((v2 / 'center.png').read_bytes())          # wrong size
    (v2 / 'tooltip.png').unlink()                                             # missing
    assert ensure() == 3 and files(tmp) == good
    (v2 / 'art-version.txt').write_text('1')
    assert ensure() == 6 and files(tmp) == good  # stale stamp redraws everything
    (v2 / 'art-version.txt').unlink()
    assert ensure() == 6 and files(tmp) == good
    # Version 1 caches in Assets/ coexist untouched: switching sources back and
    # forth (hot-reload A/B) never redraws or rewrites either version.
    (tmp / 'Assets/README.txt').write_text('readme')
    assert ensure1(art1, str(tmp).encode()) == 6
    both = files(tmp)
    for _ in range(3):
        assert ensure() == 0 and ensure1(art1, str(tmp).encode()) == 0 and files(tmp) == both
    assert both['Assets/README.txt'] == hashlib.sha256(b'readme').hexdigest()
    assert {k for k in both if not k.startswith('Assets/v2/')} == {f'Assets/{n}.png' for n in names} | {
        'Assets/art-version.txt', 'Assets/README.txt'}
print('PASS: artwork cache in Assets/v2 redraws damaged, missing and stale files only; 0.4.5 caches coexist unchanged across A/B switches')
