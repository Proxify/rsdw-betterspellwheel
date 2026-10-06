-- Shared, testable design-space bounds. Wheel targets contain icons + a number;
-- full names belong in the fixed-width spell roster, never across slice edges.
local L={width=1440,height=960,cx=500,cy=480}
L.panel={x=942,y=110,w=440,h=800}
L.heading={x=962,y=126,w=396,h=54}
L.meta={x=962,y=186,w=396,h=28}
L.title={x=962,y=512,w=396,h=68}
L.body={x=962,y=596,w=396,h=154}
L.cost={x=962,y=772,w=396,h=70}
L.status={x=962,y=860,w=396,h=44}
function L.row(i)
 local y=224+(i-1)*44
 return {x=954,y=y-3,w=412,h=40},
  {x=964,y=y,w=26,h=32}, {x=1002,y=y,w=290,h=32}, {x=1302,y=y+4,w=54,h=26}
end
function L.icon(model,angle,radius,size)
 local x,y=model.point(angle,radius)
 return {x=L.cx+x-size/2,y=L.cy+y-size/2,w=size,h=size}
end
return L
