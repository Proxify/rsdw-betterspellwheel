-- Shared design-space bounds (1440x960).
local L={width=1440,height=960,cx=720,cy=480}
-- Whole wheel is lifted by shiftY (design units) to free a tooltip bar underneath.
L.shiftY=-70
-- tooltip.png is 1560x192 but its artwork only spans x=245..1314 (transparent
-- padding either side), so the image box is scaled from the artwork width.
-- TIP_ART_W is the on-screen width of the visible bar in design units.
local TIP_ART_W=700
local s=TIP_ART_W/(1314-245)
L.tooltip={x=720-779.5*s,y=898,w=1560*s,h=192*s}
-- Text frame = inside the inner gold border, between the tip diamonds and under
-- the top diamond (png px x 335..1225, y 48..152).
L.tipText={x=L.tooltip.x+335*s,y=L.tooltip.y+48*s,w=890*s,h=104*s}
function L.icon(model,angle,radius,size)
 local x,y=model.point(angle,radius)
 return {x=L.cx+x-size/2,y=L.cy+y-size/2,w=size,h=size}
end
return L