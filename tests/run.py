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
