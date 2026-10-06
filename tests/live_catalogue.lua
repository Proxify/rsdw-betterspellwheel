-- Run through srvr on MODTEST. Read-only: no characters, saves or inventories
-- are changed. Pass only after copying this mod to D:\rsdw-mods\mods.
local root = "D:/rsdw-mods/mods/SpellBranches/"
local model = dofile(root.."Scripts/model.lua")
local catalogue = dofile(root.."Scripts/catalogue.lua")(model)
local groups, errors = catalogue.scan()
assert(#errors == 0, table.concat(errors, "\n"))
local expected = {Woodcutting=3, Mining=3, Artisan=4, Construction=3, Farming=4,
    Cooking=2, Fishing=3, Runecrafting=5, Magic=4, Attack=4, Ranged=2, Agility=2}
local count, report, seen = 0, {}, {}
local fixture = {"-- Read-only MODTEST snapshot, 2026-10-05; Dragonwilds 1.0.", "return {"}
for _,group in ipairs(groups) do
    assert(#group.spells == expected[group.id], "unexpected spell count: "..group.id)
    assert(group.available == 0, "scan without player must fail closed")
    report[#report+1] = group.label..": "..#group.spells
    for _,spell in ipairs(group.spells) do
        assert(not seen[spell.id], "duplicate spell")
        assert(spell.data:IsValid(), "invalid data")
        assert(spell.level > 0 and spell.level <= 99, "bad required level")
        assert(spell.description ~= "", "missing description")
        seen[spell.id], count = true, count+1
        fixture[#fixture+1] = string.format(" {id=%q, name=%q, skill=%q, perk=%q, level=%d, unlocked=false},",
            spell.id, spell.name, spell.skill, spell.perk, spell.level)
    end
end
assert(count == 39, "unexpected total: "..count)
fixture[#fixture+1] = "}"
local file = assert(io.open(root.."tests/live_catalogue_snapshot.lua", "w"))
file:write(table.concat(fixture,"\n"),"\n"); file:close()
return "PASS: "..count.." spells in "..#groups.." skills; no soft references or game state changed\n"..table.concat(report,"\n")
