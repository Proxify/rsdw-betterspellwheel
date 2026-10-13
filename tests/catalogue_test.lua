local root=arg[1]:gsub('/Scripts/model.lua$','')
local model=dofile(root..'/Scripts/model.lua')
local scan=dofile(root..'/Scripts/catalogue.lua')(model)
local function value(s)return {ToString=function()return s end}end
local perk={IsValid=function()return true end,GetFullName=function()return 'PerkV2_Runecraftng_Windstep' end,
 PerkDescription=value('A legacy name is not skill ownership.'),PerkUnlockInfo={RequiredSkillLevel=5}}
setmetatable(perk.PerkUnlockInfo,{__index=function()error('must not marshal AssociatedSkill')end})
local data={IsValid=function()return true end,OwningPerk=perk,GetFName=function()return value('USD_Windstep')end,
 SpellDisplayName=value('Windstep'),CooldownDuration=3}
local agility={IsValid=function()return true end,SkillType=1,MaxLevel=99,Name=value('Agilité')}
local rc={IsValid=function()return true end,SkillType=11,MaxLevel=99,Name=value('Création de runes')}
local oldFind=FindAllOf
function FindAllOf(kind)return kind=='SkillData' and {agility,rc} or {data}end
local component={IsValid=function()return true end,GetPerksUnlockedAtLevelForSkill=function(_,skill,level,previous)
 assert(level==99 and previous==0)
 return skill==agility and {{get=function()return perk end}} or {}
end}
local groups,errors=scan.scan(function(_,d)assert(d==data);return true end,component)
assert(#errors==0 and #groups[8].spells==0 and #groups[12].spells==1)
assert(groups[12].spells[1].id=='USD_Windstep' and groups[12].available==1)
local locked=scan.scan(nil,component);assert(locked[12].available==0)
assert(groups[12].spells[1].cooldown==3,'no modifier perk: base cooldown')
-- An unlocked cooldown modifier perk shortens the cooldown; a locked one doesn't.
local cdPerk={IsValid=function()return true end}
data.CooldownModifierPerk={CooldownPerk=cdPerk,ModifiedCooldown=1.5}
local owned=false
component.IsPerkUnlocked=function(_,p)assert(p==cdPerk);return owned end
assert(scan.scan(nil,component)[12].spells[1].cooldown==3,'locked modifier perk keeps base cooldown')
owned=true
local fast=scan.scan(nil,component)[12].spells[1]
assert(fast.cooldown==1.5 and fast.baseCooldown==3,'unlocked modifier perk shortens cooldown')
assert(not pcall(scan.scan,nil,nil),'unavailable progression must not guess by filename')
FindAllOf=oldFind
print('PASS: catalogue uses native progression despite legacy filenames and localized skill names; perk-adjusted cooldowns')
