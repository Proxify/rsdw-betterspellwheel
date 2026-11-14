-- Read-only artwork census on an owned TEST client. Run through the existing
-- BetterSpellWheel game-thread console after opening the wheel once and letting
-- icon prewarming finish. No soft references, unlocks, casts or save changes.
-- This proves discoverability/loaded textures, not pixels or mouse interaction.
local mod=assert(_G.BetterSpellWheel,'BetterSpellWheel is not loaded')
assert(not mod.disabled,'BetterSpellWheel is disabled')
local pc
for _,candidate in ipairs(FindAllOf('BP_PlayerController_C') or {}) do
 if candidate:IsValid() and candidate:IsLocalController() then pc=candidate;break end
end
assert(pc and pc.PlayerState:IsValid(),'join the owned TEST World first')
local player=pc.PlayerState:GetPlayerName():ToString():lower()
assert(player=='tradetester' or player=='tradetesterb','TEST character required')
local state=assert(mod.state,'open the wheel once before this probe')
local icons=dofile(mod.folder..'/Scripts/icons.lua')
local lines={'version='..mod.version,'player='..player}
local missing,seen,total={}, {},0
local function check(id,path)
 if not path then missing[#missing+1]=id..': no explicit native artwork';return end
 -- The normal view's retained native brushes own the warmed textures. Reuse
 -- those assets; do not load unbounded objects or add a polling loop here.
 local texture=StaticFindObject(path)
 if not texture or not texture:IsValid() then
  missing[#missing+1]=id..': texture not loaded (wait for normal warmup)';return
 end
 lines[#lines+1]=id..'\t'..texture:GetFullName()
end
for _,group in ipairs(state.groups) do
 check(group.id,icons.skills[group.id])
 for _,spell in ipairs(group.spells) do
  assert(not seen[spell.id],'duplicate spell identity')
  seen[spell.id]=true;total=total+1
  check(spell.id,icons.spells[spell.id])
 end
end
lines[#lines+1]='discoveredSpells='..total
lines[#lines+1]='earthDiscovered='..tostring(seen.USD_EnchantWeapon_Earth==true)
lines[#lines+1]='missingArtwork='..#missing
for _,problem in ipairs(missing) do lines[#lines+1]='MISSING '..problem end
assert(seen.USD_EnchantWeapon_Earth,'Earth enchantment absent from the current native catalogue\n'..table.concat(lines,'\n'))
assert(#missing==0,table.concat(lines,'\n'))
return table.concat(lines,'\n')
