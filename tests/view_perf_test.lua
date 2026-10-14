-- The optimised view must draw exactly what 0.4.2 drew. Both views run side by
-- side against a recording UMG mock through the same wheel states; after every
-- frame each widget's final state (visibility, text, colour, font size,
-- opacity, angle, brush, slot position/size) must match, while the new view
-- makes far fewer engine calls. tests/reference/view-0.4.2.lua is the frozen
-- 0.4.2 view and is never shipped.
local root=arg[1]:gsub('/Scripts/model.lua$','')
local function dofile(path) return assert(loadfile(path))() end
local model=dofile(root..'/Scripts/model.lua')
local L=dofile(root..'/Scripts/layout.lua')
local icons=dofile(root..'/Scripts/icons.lua')
local cooldownsModule=dofile(root..'/Scripts/cooldowns.lua')
local fake=0
local realClock=os.clock
os.clock=function() return fake end

local recorder -- the recorder new widgets belong to
local function ser(v)
 if type(v)~='table' then return tostring(v) end
 if v.__id then return 'obj#'..v.__id end
 local keys={}
 for k in pairs(v) do keys[#keys+1]=tostring(k) end
 table.sort(keys)
 local out={}
 for _,k in ipairs(keys) do local x=v[k];if x==nil then x=v[tonumber(k)] end;out[#out+1]=k..'='..ser(x) end
 return '{'..table.concat(out,',')..'}'
end
local function newRecorder() return {calls=0,objects={},n=0} end
local function mock(rec,kind,fields)
 rec.n=rec.n+1
 local o=fields or {}
 o.__id=rec.n;o.__kind=kind;o.__state={};o.__rec=rec
 rec.objects[rec.n]=o
 return setmetatable(o,{__index=function(self,key)
  if key=='Font' then local f=rawget(self,'__font') or {Size=10};return {Size=f.Size,LetterSpacing=f.LetterSpacing,Family='font'} end
  return function(me,...)
   local r=rawget(me,'__rec');r.calls=r.calls+1
   local args={...}
   if key=='GetVisibility' then return me.__state.SetVisibility and tonumber(me.__state.SetVisibility) or 0 end
   if key=='GetDesiredSize' then
    local text=me.__state.SetText or '';local size=(rawget(me,'__font') or {Size=10}).Size
    local lines,width=0,0
    for line in (text..'\n'):gmatch('(.-)\n') do lines=lines+1;width=math.max(width,#line*size*.52) end
    return {X=width,Y=lines*size*1.4}
   end
   if key=='AddChildToCanvas' then local slot=mock(r,'slot');rawset(args[1],'Slot',slot);return slot end
   if key=='SetFont' then rawset(me,'__font',{Size=args[1].Size,LetterSpacing=args[1].LetterSpacing}) end
   if key=='SetText' then me.__state.SetText=args[1].text;return end
   me.__state[key]=ser(#args==1 and args[1] or args)
  end
 end})
end
local function snapshot(rec)
 local out={}
 for i=1,rec.n do
  local o=rec.objects[i]
  local keys={}
  for k in pairs(o.__state) do keys[#keys+1]=k end
  table.sort(keys)
  local parts={o.__kind}
  for _,k in ipairs(keys) do parts[#parts+1]=k..'='..o.__state[k] end
  local f=rawget(o,'__font');if f then parts[#parts+1]='font='..f.Size end
  if rawget(o,'WrapTextAt') then parts[#parts+1]='wrap='..tostring(rawget(o,'WrapTextAt')) end
  out[i]=table.concat(parts,';')
 end
 return out
end
function FText(v) return {text=tostring(v)} end
function StaticConstructObject(class,outer) return mock(recorder,tostring(class)) end

-- Engine data: three runes, one without an Icon field (name-convention fallback).
local textures={}
local function texture(path) if not textures[path] then textures[path]={__id='tex:'..path,IsValid=function() return true end} end;return textures[path] end
local function item(name,withIcon)
 local it={__id='item:'..name,IsValid=function() return true end,GetAddress=function() return name end,
  Name={ToString=function() return 'ITEM_Rune_'..name end},GetFName=function() return {ToString=function() return 'ITEM_Rune_'..name end} end}
 if withIcon then it.Icon=texture('/Game/Icon/'..name) end
 return it
end
local air,law,nature=item('Air',true),item('Law',false),item('Nature',true)
local held={Air=12,Law=1,Nature=0}
local function spellData(costs,tool)
 local module={IsValid=function() return true end,ItemsCostInfo={ForEach=function(_,fn)
  for _,c in ipairs(costs) do fn(nil,{get=function() return {ItemData=c[1],Count=c[2]} end}) end end}}
 return {IsValid=function() return true end,GetModulesOfType=function() return {{get=function() return module end}} end,
  SpecialRequirementsText={ToString=function() return tool or '' end}}
end
local records={}
local function add(id,skill,level,desc,costs,tool,unlocked)
 records[#records+1]={id=id,name=id:gsub('^USD_',''),skill=skill,level=level,description=desc,unlocked=unlocked~=false,
  cooldown=30,data=spellData(costs,tool)}
end
local long=string.rep('A long spell description that wraps over several lines in the tooltip bar. ',4)
add('USD_Windstep','Agility',5,'Dash forward.',{{air,2}})
add('USD_PhaseDash','Agility',44,long,{{air,2},{law,1}},'Logging Axe')
add('USD_Recall','Agility',57,'Return to a spot.',{{law,1},{nature,2},{air,3}},nil,false)
for i=1,7 do add('USD_Mining'..i,'Mining',i*10,'Mining spell '..i..'. '..(i%2==0 and long or ''),{{nature,i}},i==3 and 'Pickaxe' or nil) end
local groups=model.catalogue(records)

local pc=mock(newRecorder(),'pc',{IsValid=function() return true end,GetAddress=function() return 'pc' end})
pc.Pawn={IsValid=function() return true end,GetAddress=function() return 'pawn' end}
local inventory={IsValid=function() return true end,GetOwner=function() return pc end,
 GetItemSlots=function()
  local slots={GetArrayNum=function() return 3 end}
  local list={{air,held.Air},{law,held.Law},{nature,held.Nature}}
  for i,s in ipairs(list) do slots[i]={IsValid=function() return true end,ItemData=s[1],Count=s[2]} end
  return slots
 end,
 GetNumItemsByData=function(_,it) for k,v in pairs(held) do if it.GetAddress()==k then return v end end;return 0 end}
local scans=0
function FindAllOf(name) scans=scans+1;assert(name=='InventoryComponent');return {inventory} end

local viewport={X=1920,Y=1080}
local mouse={X=960,Y=540}
local function makeE(rec)
 local E={}
 function E.valid(x) return x~=nil and x:IsValid() end
 function E.class(path) return path end
 function E.asset(path) if path:find('T_Icon_Rune_') or path:find('/Art/') or path:find('/Icon/') then return texture(path) end end
 function E.create() local root=mock(rec,'panel');root.WidgetTree=mock(rec,'tree');root.IsValid=function() return true end;return root end
 E.render=mock(rec,'render');getmetatable(E.render).__index=function(_,key)
  return function(_,_,path) rec.calls=rec.calls+1;return texture(path) end end
 E.layout=setmetatable({},{__index=function(_,key) return function()
  rec.calls=rec.calls+1
  if key=='GetViewportSize' then return {X=viewport.X,Y=viewport.Y} end
  if key=='GetViewportScale' then return 1 end
  if key=='GetMousePositionOnViewport' then return {X=mouse.X,Y=mouse.Y} end
 end end})
 return E
end

local function instance(path)
 local rec=newRecorder()
 recorder=rec
 local E=makeE(rec)
 local R=dofile(path)(E,model,L)
 local u=R.new(pc,'/mod',icons)
 return {rec=rec,u=u,cool=cooldownsModule.new(),E=E}
end
local old=instance(root..'/tests/reference/view-0.4.2.lua')
local new=instance(root..'/Scripts/view.lua')
assert(old.rec.n==new.rec.n,'same widget tree')

local state=model.new(groups)
local now,frames=100,0
local function compare(label)
 local a,b=snapshot(old.rec),snapshot(new.rec)
 for i=1,#a do
  if a[i]~=b[i] then error(label..': widget '..i..' differs\n0.4.2: '..a[i]..'\nnew:   '..b[i]) end
 end
end
local function frame(message,label,n)
 for _=1,n or 1 do
  frames=frames+1;now=now+.016;fake=fake+.016
  local group=state.groups[state.group];local spell=group and group.spells[state.spell]
  for _,v in ipairs({old,new}) do v.u.resize();v.u.pointer();v.u.draw(state,.016,message,now,v.cool,spell) end
  compare(label..' frame '..frames)
 end
end
local function both(fn) for _,v in ipairs({old,new}) do fn(v) end end
local before={old=old.rec.calls,new=new.rec.calls}
both(function(v) v.u.show() end)
frame(nil,'centre',10)
state.group=1;state.zone='skill';frame(nil,'skill ring',15)
state.group=12;state.zone='skill';frame(nil,'agility',10)
state.zone='spell';state.spell=1;frame(nil,'hover windstep',10)
state.spell=2;frame(nil,'hover phase dash (tool, long tip)',70)
held.Law=0;frame(nil,'rune count drops',70)
both(function(v) v.cool:start(groups[12].spells[1],now) end)
frame(nil,'cooldown ticking',200)
state.spell=3;frame('On cooldown. Ready in 12s.','refusal message',20)
frame(nil,'message cleared',10)
state.zone='bridge';state.spell=nil;frame(nil,'bridge',10)
state.group=2;state.zone='skill';frame(nil,'mining',10)
state.zone='spell';state.spell=1;frame(nil,'mining 1',10)
model.turnPage(state,1);state.zone='spell';state.spell=7;frame(nil,'mining page 2',10)
viewport={X=2560,Y=1600};fake=fake+1;frame(nil,'resize',40)
both(function(v) v.u.hide() end)
-- Reopen: cached tooltips/details must render identically.
both(function(v) v.u.show() end)
state=model.new(groups);frame(nil,'reopen',5)
state.group=12;state.zone='spell';state.spell=2;frame(nil,'reopen phase dash',40)
state.spell=1;frame(nil,'reopen windstep',20)
state.spell=2;frame(nil,'back to phase dash',20)
both(function(v) v.cool:start(groups[12].spells[2],now) end)
frame(nil,'second cooldown',130)
local oldCalls,newCalls=old.rec.calls-before.old,new.rec.calls-before.new
-- Steady state: a wheel left open on one spell with a timer running.
local o0,n0=old.rec.calls,new.rec.calls
frame(nil,'steady',600)
local oldSteady,newSteady=(old.rec.calls-o0)/600,(new.rec.calls-n0)/600
os.clock=realClock
assert(newCalls<oldCalls*.75,('engine calls not reduced enough: %d -> %d'):format(oldCalls,newCalls))
assert(newSteady<=oldSteady*.6,('steady open frame calls: %.2f -> %.2f'):format(oldSteady,newSteady))
print(('PASS: optimised view draws exactly what 0.4.2 drew over %d frames; engine calls %d -> %d (scenario), %.2f -> %.2f per steady open frame'):format(frames,oldCalls,newCalls,oldSteady,newSteady))
