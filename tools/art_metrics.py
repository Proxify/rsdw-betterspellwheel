#!/usr/bin/env python3
"""Local artwork-generation microbenchmark: 0.4.5 (tests/reference/art-v1.lua) vs
current Scripts/art.lua. Fresh A.ensure() into a new TemporaryDirectory per run,
interleaved. Measures only offline drawing/PNG encoding in this Lua runtime; it is
not game FPS or in-game performance evidence. Needs lupa (Lua 5.4)."""
from pathlib import Path
import sys, tempfile, time
from lupa.lua54 import LuaRuntime
root = Path(__file__).resolve().parents[1]
rounds = int(sys.argv[1]) if len(sys.argv) > 1 else 5
lua = LuaRuntime(unpack_returned_tuples=True, encoding=None)
mods = {'0.4.5 v1': root / 'tests/reference/art-v1.lua', 'cropped v2': root / 'Scripts/art.lua'}
arts = {k: lua.execute(b'return dofile(...)', str(p).encode()) for k, p in mods.items()}
ensure = lua.eval(b'function(A, d) return A.ensure(d) end')
times = {k: [] for k in mods}
sizes = {}
for _ in range(rounds):
    for k, art in arts.items():
        with tempfile.TemporaryDirectory() as tmp:
            t = time.perf_counter(); drawn = ensure(art, tmp.encode()); times[k].append(time.perf_counter() - t)
            assert drawn == 6
            sizes[k] = sum(p.stat().st_size for p in Path(tmp).rglob('*.png'))
for k in mods:
    ts = sorted(times[k])
    print(f'{k}: PNG bytes {sizes[k]:,}; fresh ensure ms ' + ' '.join(f'{x*1000:.0f}' for x in times[k])
          + f' (median {ts[len(ts)//2]*1000:.0f})')
