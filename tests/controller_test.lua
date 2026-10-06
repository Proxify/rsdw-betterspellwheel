local model=dofile(arg[1])
local C=dofile(arg[1]:gsub('model.lua$','controller.lua'))(model)
local records={}
for _,g in ipairs(model.skills) do for i=1,9 do records[#records+1]={skill=g.id,id=g.id..i,name='Spell '..i,level=i,unlocked=i~=2} end end
local state=model.new(model.catalogue(records));local c=C.new();local t=0
local function step(s,dt)t=t+(dt or .016);return C.step(c,state,s or {},t)end
-- Drift cannot choose a skill; every sector has a stable directional target.
step({x=.1,y=.1});assert(not state.group)
for i=1,12 do local x,y=model.point(model.skillAngle(i,12),1);step({x=x,y=-y});assert(state.group==i)end
-- Neutral does not lose the highlight, and release never casts.
step();assert(state.group==12 and not state.spell)
assert(step({accept=true})=='enter');assert(state.spell==1)
assert(step({accept=true},1)==nil and state.spell==1)
step();assert(step({accept=true})=='select');step()
-- Locked spells stay browsable; the native adapter still decides whether to cast.
step({right=true});assert(state.spell==2);assert(model.selection(state)==nil)
step({right=true},.1);assert(state.spell==2)
step({right=true},.3);assert(state.spell==3)
step({right=true},.13);assert(state.spell==4)
step();step({left=true});assert(state.spell==3);step()
-- Page changes cannot retain an out-of-page spell.
step({next=true});assert(state.page==2 and state.spell==7)
step();step({left=true});assert(state.spell==9);step()
step({previous=true});assert(state.page==1 and state.spell==1);step()
-- Back returns to the same skill, without casting or re-entering from a held key.
assert(step({back=true})=='back');assert(c.stage=='skills' and not state.spell)
assert(step({back=true})==nil);step();assert(step({back=true})=='close');step()
-- Opening with A held must not consume it; requires a fresh press.
c=C.new();state=model.new(model.catalogue(records));model.setGroup(state,1)
C.prime(c,{accept=true});assert(step({accept=true})==nil and c.stage=='skills')
step();assert(step({accept=true})=='enter')
-- A held stick crossing from skills to spells must first return to neutral.
c=C.new();state=model.new(model.catalogue(records))
step({x=1});assert(state.group==4)
step({x=1,accept=true});assert(c.stage=='spells' and state.spell==1)
step({x=1},1);assert(state.spell==1)
step();step({x=1});assert(state.spell==2)
-- Empty categories cannot enter/cast; D-pad wraps predictably.
c=C.new();state=model.new(model.catalogue({}));step({left=true});assert(state.group==12)
step();assert(step({accept=true})==nil and c.stage=='skills')
print('PASS: controller sectors, drift, neutral latch, stage transition, repeat, pagination, lock, empty group, back and held-confirm guards')
