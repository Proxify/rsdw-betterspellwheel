-- Cropped ring artwork must land exactly where the 0.4.5 full 848x848 frame put
-- the same texels, at every angle, in both placement modes. A UMG render
-- transform maps a widget-local point q to P + S*pivot + Rot(angle)(q - S*pivot)
-- (P slot position, S slot size; positive angles turn clockwise on screen,
-- as model.point assumes). The full frame sat at (296,56), size 848, pivot .5.
local root=arg[1]:gsub('/Scripts/model.lua$','')
local function dofile(path) return assert(loadfile(path))() end
local model=dofile(root..'/Scripts/model.lua')
local L=dofile(root..'/Scripts/layout.lua')
local icons=dofile(root..'/Scripts/icons.lua')
local art=dofile(root..'/Scripts/art.lua')
local records=dofile(root..'/tests/live_catalogue_snapshot.lua')
for _,r in ipairs(records) do r.unlocked=true end
local groups=model.catalogue(records)

local objects
local function mock(kind)
 local o={kind=kind,calls={}}
 objects[#objects+1]=o
 return setmetatable(o,{__index=function(_,key)
  if key=='Font' then return {Size=10} end
  return function(me,...)
   local args={...}
   me.calls[key]=args
   if key=='AddChildToCanvas' then local slot=mock('slot');args[1].Slot=slot;return slot end
   if key=='GetVisibility' then return me.calls.SetVisibility and me.calls.SetVisibility[1] or 0 end
   if key=='GetDesiredSize' then return {X=10,Y=10} end
  end
 end})
end
function FText(v) return v end
function StaticConstructObject(class) return mock(class) end
local E={}
function E.valid(x) return x~=nil end
function E.class(path) return path end
function E.asset(path) return {path=path} end
function E.create() local r=mock('panel');r.WidgetTree=mock('tree');return r end
E.render={ImportFileAsTexture2D=function(_,_,path) return {path=path} end}
E.layout={GetViewportSize=function() return {X=1920,Y=1080} end,GetViewportScale=function() return 1 end,
 GetMousePositionOnViewport=function() return {X=960,Y=540} end}

local function rot(a,x,y) local c,s=math.cos(a),math.sin(a);return x*c-y*s,x*s+y*c end
-- Design-space position of frame texel point (u,v) for the 0.4.5 full frame.
local function full(a,u,v) local x,y=rot(a,u-424,v-424);return 296+424+x,56+424+y end
-- Same point for a placed crop widget.
local function placed(w,name,a,u,v)
 local c=art.crops[name]
 local P,S=w.Slot.calls.SetPosition[1],w.Slot.calls.SetSize[1]
 assert(S.X==c[3] and S.Y==c[4],name..' slot size is the crop size')
 local pv=w.calls.SetRenderTransformPivot and w.calls.SetRenderTransformPivot[1] or {X=.5,Y=.5}
 local px,py=S.X*pv.X,S.Y*pv.Y
 local x,y=rot(a,u-c[1]-px,v-c[2]-py)
 return P.X+px+x,P.Y+py+y
end
local checks=0
local function same(w,name,a,label)
 local c=art.crops[name]
 for _,q in ipairs({{c[1],c[2]},{c[1]+c[3],c[2]},{c[1],c[2]+c[4]},{c[1]+c[3],c[2]+c[4]},{c[1]+c[3]/2,c[2]+c[4]/2},{c[1]+.5,c[2]+7.5}}) do
  local x1,y1=full(a,q[1],q[2]);local x2,y2=placed(w,name,a,q[1],q[2])
  assert(math.abs(x1-x2)<1e-9 and math.abs(y1-y2)<1e-9,
   ('%s %s angle %.4f: (%.6f,%.6f) vs full frame (%.6f,%.6f)'):format(label,name,math.deg(a),x2,y2,x1,y1))
  checks=checks+1
 end
end
local function brush(w) local b=w.calls.SetBrushFromTexture;return b and b[1] and b[1].path end
local function byTexture(name)
 local out={}
 for _,o in ipairs(objects) do if brush(o)==art.path('/mod',name) then out[#out+1]=o end end
 return out
end

local function run(mode)
 objects={}
 local R=dofile(root..'/Scripts/view.lua')(E,model,L,art)
 R.placement=mode
 local u=R.new(mock('pc'),'/mod',icons)
 -- Every texture comes from this version's cache folder.
 for _,n in ipairs(art.names) do assert(u.textures[n].path=='/mod/Assets/v2/'..n..'.png',n) end
 -- Skill ring: 12 bases + 12 highlights at their fixed angles.
 for _,name in ipairs({'skill','skill_active'}) do
  local ws=byTexture(name);assert(#ws==#model.skills,name..' count')
  for i,w in ipairs(ws) do
   local a=model.skillAngle(i,#model.skills)
   assert(w.calls.SetRenderTransformAngle[1]==math.deg(a),name..' angle')
   same(w,name,a,mode..' skill '..i)
  end
 end
 -- Spell branches: drive the real draw through every group and page.
 local state=model.new(groups);local angles=0
 for gi,g in ipairs(state.groups) do
  state.group=gi;state.zone='spell';state.page=1
  for page=1,model.pages(state) do
   state.page=page;state.spell=nil
   u.show();u.draw(state,.016,nil,100,nil,nil)
   local b=model.branch(state)
   for i=1,b.count do
    local n=u.spells[i]
    local a=b.center-b.span/2+b.step*(i-.5)
    assert(n.angle==a)
    same(n.base,'spell',a,mode..' '..g.id..' page '..page..' slot '..i)
    same(n.highlight,'spell_active',a,mode..' '..g.id..' page '..page..' slot '..i)
    angles=angles+1
   end
  end
 end
 assert(angles==#records,'every spell slot angle checked: '..angles)
 -- Unrotated centre disc and tooltip bar: the texels keep their full-frame spots.
 local ctr=byTexture('center');assert(#ctr==1)
 same(ctr[1],'center',0,mode..' centre')
 local tip=u.tipParts[1];local tc,ts=art.crops.tooltip,L.tooltip.w/1560
 local P,S=tip.Slot.calls.SetPosition[1],tip.Slot.calls.SetSize[1]
 -- Corners and every texel centre along both axes (odd crop offset 241 included).
 local qs={{tc[1],tc[2]},{tc[1]+tc[3],tc[2]+tc[4]}}
 for i=0,tc[3]-1 do qs[#qs+1]={tc[1]+i+.5,tc[2]+.5} end
 for j=0,tc[4]-1 do qs[#qs+1]={tc[1]+.5,tc[2]+j+.5} end
 for _,q in ipairs(qs) do
  local fx,fy=L.tooltip.x+q[1]*ts,L.tooltip.y+q[2]*L.tooltip.h/192
  local cx,cy=P.X+(q[1]-tc[1])*S.X/tc[3],P.Y+(q[2]-tc[2])*S.Y/tc[4]
  assert(math.abs(fx-cx)<1e-9 and math.abs(fy-cy)<1e-9,'tooltip crop placement')
 end
 -- Pointer mapping and icon targets are untouched (hit-testing is analytic in model.lua).
 local px,py=u.pointer();assert(math.abs(px)<1e-9 and math.abs(py+L.shiftY)<1e-9,'pointer: screen centre is the lifted wheel centre')
 for i,s in ipairs(u.skills) do
  local box=L.icon(model,model.skillAngle(i,#model.skills),model.geometry.skillRadius,64)
  local p=s.icon.Slot.calls.SetPosition[1];assert(p.X==box.x and p.Y==box.y,'skill icon '..i)
 end
 -- Any angle, using the view's own placement for that angle.
 local ws={spell=u.spells[1].base,spell_active=u.spells[1].highlight}
 for deg=0,359 do
  local a=math.rad(deg)
  for name,w in pairs(ws) do
   if mode~='pivot' then w.Slot.calls.SetPosition={R.turnedPosition(name,a)} end
   same(w,name,a,mode..' sweep')
  end
 end
 return u
end
run('pivot');run('offset')
print(('PASS: cropped ring art matches the 848 px frame placement at all spell/skill angles and a 360-degree sweep, pivot and offset modes (%d point checks)'):format(checks))
