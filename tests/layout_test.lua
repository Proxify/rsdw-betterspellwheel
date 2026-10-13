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
-- Cooldown labels replace the slot number on the same outer-ring point.
for i=1,12 do
 local a=model.skillAngle(i,12)
 for count=1,6 do for j=1,count do
  local b=a-math.rad(20)*count/2+math.rad(20)*(j-.5)
  local x,y=model.point(b,385)
  inside({x=L.cx+x-32,y=L.cy+y-13,w=64,h=26},b,282,432,math.rad(10))
 end end
end
-- Radial-only layout: the wheel is centred, lifted by shiftY, with the tooltip
-- bar underneath. Everything must stay on screen; the screen fit adds a 20/25
-- design-unit margin (scale=min(w/1480,h/1010)).
assert(L.cx==L.width/2,'wheel is centred')
local top=L.cy-408+L.shiftY
assert(top>=-25,'wheel art leaves the top of the screen')
local tipArtBottom=L.tooltip.y+174*L.tooltip.h/192+L.shiftY
assert(tipArtBottom<=L.height+25,'tooltip bar leaves the bottom of the screen')
assert(L.tooltip.y+18*L.tooltip.h/192>=L.cy+408,'tooltip bar overlaps the wheel art')
local t,b=L.tipText,L.tooltip
assert(t.x>=b.x and t.y>=b.y and t.x+t.w<=b.x+b.w and t.y+t.h<=b.y+b.h,'tooltip text frame outside the bar')
assert(math.abs((t.x+t.w/2)-L.cx)<1,'tooltip text centred under the wheel')
checks=checks+6
print('PASS: '..checks..' layout containment and screen-fit checks')
