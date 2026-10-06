local root=arg[1]:gsub('/Scripts/model.lua$','')
local model=dofile(root..'/Scripts/model.lua')
local L=dofile(root..'/Scripts/layout.lua')
local checks=0
local function inside(box,angle,ri,ro,half)
 for _,dx in ipairs({0,box.w})do for _,dy in ipairs({0,box.h})do
  local x,y=box.x+dx-L.cx,box.y+dy-L.cy
  local r=math.sqrt(x*x+y*y)
  assert(r>ri and r<ro,'glyph/icon crosses radial edge')
  assert(math.abs(model.delta(model.angle(x,y),angle))<half,'glyph/icon crosses neighboring slice')
  checks=checks+1
 end end
end
for i=1,12 do
 local a=model.skillAngle(i,12)
 inside(L.icon(model,a,model.geometry.skillRadius,64),a,132,264,math.rad(14.3))
 for count=1,6 do for j=1,count do
  local b=a-math.rad(20)*count/2+math.rad(20)*(j-.5)
  inside(L.icon(model,b,model.geometry.spellRadius,64),b,282,408,math.rad(9.3))
  local x,y=model.point(b,385)
  inside({x=L.cx+x-11,y=L.cy+y-14,w=22,h=28},b,282,408,math.rad(9.3))
 end end
end
local function disjoint(a,b)
 assert(a.x+a.w<=b.x or b.x+b.w<=a.x or a.y+a.h<=b.y or b.y+b.h<=a.y,'text rectangles overlap')
 checks=checks+1
end
local boxes={L.heading,L.meta,L.title,L.body,L.cost,L.status}
for i=1,6 do local _,n,t,l=L.row(i);boxes[#boxes+1]=n;boxes[#boxes+1]=t;boxes[#boxes+1]=l end
for i,a in ipairs(boxes)do
 assert(a.x> L.cx+model.geometry.branchOuter+24,'panel crowds outer wheel')
 assert(a.y>=0 and a.y+a.h<920,'panel text reaches footer')
 for j=i+1,#boxes do disjoint(a,boxes[j])end
end
print('PASS: '..checks..' layout containment and text separation checks')
