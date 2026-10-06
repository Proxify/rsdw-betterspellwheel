-- Engine-independent controller navigation. No release-to-cast, and a held
-- confirm can never both enter a skill and cast its first spell.
return function(model)
 local C={deadzone=.28,releaseZone=.20,repeatDelay=.36,repeatInterval=.12}
 function C.new()
  return {stage='skills',buttons={},neutral=true,direction=0,nextRepeat=0}
 end
 function C.prime(c,sample)
  c.buttons=sample or {};c.neutral=false;c.direction=0
 end
 local function browse(state,c,direction)
  if c.stage=='skills' then
   model.setGroup(state,((state.group or (direction>0 and 0 or 1))-1+direction)%#state.groups+1)
   state.zone='skill'
  else
   local b=model.branch(state)
   if b and b.count>0 then
    state.spell=b.first+((state.spell or b.first)-b.first+direction)%b.count
    state.zone='spell'
   end
  end
 end
 function C.step(c,state,s,now)
  local pressed={}
  for _,k in ipairs({'accept','back','close','previous','next'}) do pressed[k]=s[k] and not c.buttons[k] end
  c.buttons=s
  local x,y=s.x or 0,s.y or 0
  local r=math.sqrt(x*x+y*y)
  if r<C.releaseZone then c.neutral=true end
  if pressed.close then return 'close' end
  if pressed.back then
   if c.stage=='skills' then return 'close' end
   c.stage='skills';state.spell=nil;state.zone='skill';c.neutral=false;c.direction=0
   return 'back'
  end
  if c.stage=='skills' and c.neutral and r>=C.deadzone then
   local angle=model.angle(x,-y)
   local step=math.pi*2/#state.groups
   local index=math.floor((angle+step/2)%(math.pi*2)/step)+1
   if state.group and math.abs(model.delta(angle,model.skillAngle(state.group,#state.groups)))<step/2+model.geometry.hysteresis then index=state.group end
   model.setGroup(state,index);state.zone='skill'
  end
  local direction=0
  if s.right or s.down then direction=1 elseif s.left or s.up then direction=-1 end
  if c.stage=='spells' and direction==0 and c.neutral and r>=C.deadzone then
   direction=(math.abs(x)>=math.abs(y) and x or -y)>=0 and 1 or -1
  end
  if direction==0 then c.direction=0
  elseif direction~=c.direction or now>=c.nextRepeat then
   browse(state,c,direction)
   c.nextRepeat=now+(direction~=c.direction and C.repeatDelay or C.repeatInterval)
   c.direction=direction
  end
  if c.stage=='spells' and (pressed.previous or pressed.next) then
   model.turnPage(state,pressed.previous and -1 or 1)
   local b=model.branch(state);state.spell=b and b.count>0 and b.first or nil
   state.zone=state.spell and 'spell' or 'skill'
  end
  if pressed.accept then
   if c.stage=='spells' then return 'select' end
   local b=model.branch(state)
   if b and b.count>0 then
    c.stage='spells';state.spell=b.first;state.zone='spell';c.neutral=false;c.direction=0
    return 'enter'
   end
  end
 end
 return C
end
