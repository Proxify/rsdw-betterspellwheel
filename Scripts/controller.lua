-- Simple controller navigation. The right stick moves a cursor around the
-- wheel; the normal radial model decides when a skill or spell is hovered.
return function(model)
 local C={deadzone=.28,releaseZone=.20,repeatDelay=.18,repeatInterval=.08,
  cursorSpeed=1350,selectedCursorSpeed=843.75,cursorResponse=3}
 function C.new()
  return {stage='skills',buttons={},neutral=true,direction=0,nextRepeat=0,
   stickEngaged=false}
 end
 function C.prime(c,sample)
  c.buttons=sample or {};c.neutral=false;c.direction=0
 end
 local function clear(state)
  state.group,state.spell,state.candidate=nil,nil,nil
  state.page,state.zone=1,'center'
 end
 local function browse(state,c,direction)
  if c.stage=='spells' and state.group then
   local b=model.branch(state)
   if b and b.count>0 then
    state.spell=b.first+((state.spell or b.first)-b.first+direction)%b.count
    state.zone='spell'
   end
  else
   model.setGroup(state,((state.group or (direction>0 and 0 or 1))-1+direction)%#state.groups+1)
   state.zone='skill'
  end
 end
 local function moveCursor(state,x,y,r,dt)
  local stickDistance=math.max(0,math.min(1,(r-C.releaseZone)/(1-C.releaseZone)))
  local baseSpeed=state.group and C.selectedCursorSpeed or C.cursorSpeed
  local speed=baseSpeed*stickDistance^C.cursorResponse
  local nextX=(state.cursorX or 0)+x*speed*dt
  local nextY=(state.cursorY or 0)-y*speed*dt
  local radius=math.sqrt(nextX*nextX+nextY*nextY)
  if radius>model.geometry.branchOuter then
   local scale=model.geometry.branchOuter/radius
   nextX,nextY=nextX*scale,nextY*scale
   radius=model.geometry.branchOuter
  end
  state.cursorX,state.cursorY=nextX,nextY
  state.cursorRadius=radius
  state.cursorAngle=radius>1 and model.angle(nextX,nextY) or model.angle(x,-y)
  state.cursorVisible=true
 end
 local function updateHover(state,now)
  if not state.cursorX or not state.cursorY then return end
  model.update(state,state.cursorX,state.cursorY,now)
  local radius=state.cursorRadius or math.sqrt(state.cursorX*state.cursorX+state.cursorY*state.cursorY)
  if radius>=model.geometry.branchInner and state.group then
   local spell=model.nearestSpell(state,state.cursorX,state.cursorY)
   if spell then state.spell,state.zone=spell,'spell' end
  end
 end
 function C.step(c,state,s,now)
  local dt=c.lastTime and math.max(0,math.min(.1,now-c.lastTime)) or .016
  c.lastTime=now
  local pressedAccept=s.accept and not c.buttons.accept
  local pressedConfirm=s.confirm and not c.buttons.confirm
  local pressedBack=s.back and not c.buttons.back
  local pressedClose=s.close and not c.buttons.close
  local pressedPrevious=s.previous and not c.buttons.previous
  local pressedNext=s.next and not c.buttons.next
  c.buttons=s
  local x,y=s.x or 0,s.y or 0
  local r=math.sqrt(x*x+y*y)
  if r>=C.deadzone then
   c.stickEngaged=true
   moveCursor(state,x,y,r,dt)
   if c.neutral then updateHover(state,now) end
  elseif r<C.releaseZone then
   if c.stickEngaged then
    c.stickEngaged=false
    -- Releasing never moves the cursor. Keep an outer spell available for
    -- casting; only an inner-area release clears the category.
    if (state.cursorRadius or 0)<model.geometry.inner then
     clear(state);c.stage='skills';c.direction=0
    end
   end
   c.neutral=true
  end
  c.stage=state.zone=='spell' and 'spells' or 'skills'
  if pressedClose then return 'close' end
  if pressedBack then
   if c.stage=='spells' or state.group then
    clear(state);c.stage='skills';c.neutral=false
    return 'back'
   end
   return 'close'
  end
  local direction=0
  if s.right or s.down then direction=1 elseif s.left or s.up then direction=-1 end
  if direction==0 then c.direction=0
  elseif direction~=c.direction or now>=c.nextRepeat then
   browse(state,c,direction)
   c.nextRepeat=now+(direction~=c.direction and C.repeatDelay or C.repeatInterval)
   c.direction=direction
  end
  if c.stage=='spells' and (pressedPrevious or pressedNext) then
   model.turnPage(state,pressedPrevious and -1 or 1)
   local b=model.branch(state)
   state.spell=b and b.count>0 and b.first or nil
   state.zone=state.spell and 'spell' or 'skill'
  end
  if pressedAccept or pressedConfirm then
   if c.stage=='spells' and state.zone=='spell' then
    return 'select'
   end
   -- Keep D-pad-only browsing usable as a fallback. Right-stick users do
   -- not need this path because the cursor reaches spells directly.
   if c.stage=='skills' then
    local b=model.branch(state)
    if b and b.count>0 then
     c.stage='spells';state.spell=b.first;state.zone='spell'
     return 'enter'
    end
   end
  end
 end
 return C
end
