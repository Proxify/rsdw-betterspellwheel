-- Read-only first client probe. Run from ptr after starting TradeTester in
-- TRADE_TEST or MODTEST. Open Q once and run again to capture the stock wheel.
-- No guessed asset paths, no soft reference reads, no input mode changes.
local pc
for _,p in ipairs(FindAllOf("BP_PlayerController_C") or {}) do
    if p:IsValid() and p:IsLocalController() then pc=p; break end
end
assert(pc and pc.PlayerState:IsValid(), "join a test world first")
local name=pc.PlayerState:GetPlayerName():ToString()
assert(name:lower()=="tradetester", "only TradeTester may be probed")
local lines={"player="..name, "input="..tostring(pc.CurrentInputMode:GetFullName())}
local function add(k,v) lines[#lines+1]=k.."="..tostring(v) end
local component=pc:GetSpellcastingComponent()
add("component",component:GetFullName())
add("radials",component.NumSpellRadials)
add("slots",component.NumSpellSlotsPerRadial)
local perks=pc:GetSkillPerkComponent()
for _,data in ipairs(FindAllOf("UtilitySpellData") or {}) do
    local perk=data.OwningPerk
    if perk:IsValid() then add(data:GetFName():ToString(),perks:IsPerkUnlocked(perk)) end
end
for _,w in ipairs(FindAllOf("WBP_SurvivalSorcery_RadialSelector_C") or {}) do
    add("wheel",w:GetFullName())
    add("computing",w.bComputing)
    add("bookInstance",w.bIsSpellbookInstance)
    add("visibility",w:GetVisibility())
    add("opacity",w:GetRenderOpacity())
    add("cachedSection",w.CachedSectionId)
    add("subdivisions",w.SubdivisionCount)
    add("slices",w.Slices:GetArrayNum())
end
return table.concat(lines,"\n")
