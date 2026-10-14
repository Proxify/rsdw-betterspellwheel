local model = dofile(assert(arg[1], "pass Scripts/model.lua"))
local checks = 0
local function eq(a,b,why)
    checks=checks+1
    assert(a==b, (why or "mismatch")..": expected "..tostring(b)..", got "..tostring(a))
end
local function near(a,b,why) checks=checks+1; assert(math.abs(a-b)<1e-8, why) end
local function spell(id, skill, level, unlocked)
    return {id=id, name=id, skill=skill, level=level, unlocked=unlocked}
end
local records = {spell("second","Woodcutting",27,true),spell("first","Woodcutting",11,true),
    spell("locked","Woodcutting",50,false),spell("mining","Mining",11,true),
    spell("internal","Unknown",1,true),spell("first","Woodcutting",11,true),
    {id="", name="", skill="Woodcutting"}}
for i=1,8 do records[#records+1]=spell("rune"..i,"Runecrafting",i,true) end
local groups=model.catalogue(records)
eq(#groups,12,"stable skill positions")
eq(#groups[1].spells,3,"duplicates and empty records excluded")
eq(groups[1].spells[1].id,"first","level ordering")
eq(groups[1].available,2,"locked entries stay visible but unavailable")
eq(#groups[3].spells,0,"empty skills retain their position")
for kind,id in pairs({[1]="Agility",[2]="Artisan",[3]="Attack",[4]="Construction",[5]="Cooking",[8]="Magic",[9]="Mining",[10]="Ranged",[11]="Runecrafting",[13]="Woodcutting",[14]="Farming",[16]="Fishing"}) do
    eq(model.skillFromType(kind),id,"reflected skill type")
end
eq(model.skillFromType(0),nil,"invalid skill type")
eq(model.skillFromType(15),nil,"utility excluded")
local legacy=model.catalogue({{id="wind",name="Windstep",perk="PerkV2_Runecraftng_Windstep"}})
eq(#legacy[8].spells,0,"historical asset name cannot assign ownership")
near(model.angle(0,-1),0,"twelve o'clock")
near(model.angle(1,0),math.pi/2,"three o'clock")
near(model.delta(0,math.pi*2-0.1),0.1,"wrap across north")
local s=model.new(groups)
model.update(s,0,-202,0)
eq(s.group,1,"skill selected on the first pointer sample")
model.update(s,0,-202,0.06)
eq(s.group,1,"hover opens branch")
eq(model.selection(s),nil,"skill hover never selects a spell")
local branch=model.branch(s)
eq(branch.count,3)
-- One pointer sample must select a target; hysteresis remains spatial.
local function at(angle,radius,time)
    local x,y=model.point(angle,radius)
    model.update(s,x,y,time or 1)
end
at(-branch.step,344)
eq(model.selection(s).id,"first","left side of north-crossing fan")
at(branch.step,344)
local selected,reason=model.selection(s)
eq(selected,nil,"locked cannot be selected")
eq(reason,"locked","locked feedback")
eq(s.group,1,"outer fan stays latched across other skill angles")
at(0,344)
eq(model.selection(s).id,"second")
at(0,240)
eq(model.selection(s),nil,"inner ring does not reuse last spell")
at(0,433)
eq(model.selection(s),nil,"outside wheel does not reuse last spell")
at(0,0)
eq(model.selection(s),nil,"center does not reuse last spell")
eq(s.group,1,"center keeps branch available")
at(branch.span/2,344)
eq(model.selection(s),nil,"fan boundary is not a target")
at(math.pi/12+math.rad(4),202,2)
at(math.pi/12+math.rad(4),202,2.1)
eq(s.group,1,"hysteresis at skill border")
eq(model.geometry.outer,model.geometry.branchInner,"no dead band between the rings")
at(math.pi/6,202,3)
at(math.pi/6,202,3.1)
eq(s.group,2,"return to inner ring switches branch")
model.setGroup(s,8)
eq(model.pages(s),2,"overflow is paged, never truncated")
model.turnPage(s,1)
eq(s.page,2)
eq(model.branch(s).count,2)
at(model.branch(s).center-model.branch(s).step/2,344)
eq(model.selection(s).id,"rune7")
model.turnPage(s,1)
eq(s.page,1,"pages wrap forward")
model.turnPage(s,-1)
eq(s.page,2,"pages wrap backward")
eq(model.selection(s),nil,"page change clears selection")
model.setGroup(s,3)
eq(s.page,1,"changing skill resets page")
eq(model.branch(s).count,0)
at(model.branch(s).center,344)
eq(model.selection(s),nil,"empty branch is safe")
model.setGroup(s,1)
model.close(s)
at(0,344)
eq(model.selection(s),nil,"closed wheel never selects")
eq(s.group,nil)
local empty=model.new({})
model.update(empty,0,-200,0)
eq(model.selection(empty),nil,"empty catalogue is safe")
-- A pointer that jumps directly outside first chooses the skill, and
-- cannot click a stale spell from the previous open.
s=model.new(groups)
local nx,ny=model.point(0,344)
model.update(s,nx,ny,0)
eq(s.group,1)
eq(model.selection(s),nil)
model.update(s,nx,ny,0.06)
eq(s.group,1)
at(0,344,0.08)
eq(model.selection(s).id,"second")
-- Exercise every angular position, including the +/-pi seam.
for i=1,#groups do
    model.setGroup(s,i)
    local b=model.branch(s)
    for j=1,b.count do
        at(b.center-b.span/2+b.step*(j-0.5),344)
        eq(s.spell,j,"fan hit test "..i..":"..j)
    end
    -- Spell hysteresis: a pointer just past a slice edge keeps the previous spell.
    if b.count>1 then
        at(b.center-b.span/2+b.step*0.5,344)
        at(b.center-b.span/2+b.step+math.rad(2),344)
        eq(s.spell,1,"spell hysteresis "..i)
    end
end
print("PASS: "..checks.." radial and catalogue checks")

-- Rapid movement across every skill is handled in the same sample, with no
-- requirement for elapsed time. The selected spell is always cleared.
s=model.new(groups)
for lap=1,3 do
 for i=1,#groups do
  local x,y=model.point(model.skillAngle(i,#groups),202)
  model.update(s,x,y,0)
  eq(s.group,i,'instant skill transition')
  eq(model.selection(s),nil,'skill change cannot cast the previous spell')
 end
end
