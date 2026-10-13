-- Engine-independent controller navigation. No release-to-cast, and a held
-- confirm can never both enter a skill and cast its first spell.
return function(model)
 -- spellWiden: joystick-only stretch of the outer spell slices (1 = same as mouse).
 -- 1.6 makes each slice ~32 degrees of stick travel instead of 20. Mouse is unaffected.
 local C={deadzone=.28,releaseZone=.20,repeatDelay=.36,repeatInterval=.12,spellWiden=1.6}
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
   local angle=model.angle(x,y)
   local step=math.pi*2/#state.groups
   local index=math.floor((angle+step/2)%(math.pi*2)/step)+1
   if state.group and math.abs(model.delta(angle,model.skillAngle(state.group,#state.groups)))<step/2+model.geometry.hysteresis then index=state.group end
   model.setGroup(state,index);state.zone='skill'
  end
  local direction=0
  if s.right or s.down then direction=1 elseif s.left or s.up then direction=-1 end
  local analogRadial = c.stage=='spells' and direction==0 and c.neutral and r>=C.deadzone
  if analogRadial then
   -- Match the inner skill ring's radial joystick behaviour: stick angle selects
   -- a spell slice directly instead of repeatedly stepping through neighbours.
   -- Keep the current selection when the stick returns to centre so confirm can
   -- still be pressed separately, just as it can after D-pad navigation.
   local branch=model.branch(state)
   if branch and branch.count>0 then
    local angle=model.angle(x,y)
    -- Compress the stick angle into slice space so every slice is spellWiden times wider.
    local d=model.delta(angle,branch.center)/C.spellWiden
    if math.abs(d)<branch.span/2 then
     local index=math.floor((d+branch.span/2)/branch.step)
     local candidate=branch.first+index
     local previous=state.spell
     if previous and candidate~=previous then
      local oldIndex=previous-branch.first
      if oldIndex>=0 and oldIndex<branch.count then
       local oldCenter=-branch.span/2+branch.step*(oldIndex+0.5)
       if math.abs(d-oldCenter)<branch.step/2+model.geometry.spellHysteresis then
        candidate=previous
       end
      end
     end
     state.spell=candidate
     state.zone='spell'
    else
     state.spell=nil
     state.zone='bridge'
    end
   end
   c.direction=0
  else
   -- D-pad navigation remains step-based. Its direction is intentionally
   -- inverted to preserve the corrected outer-ring D-pad behaviour.
   if c.stage=='spells' then direction=-direction end
   if direction==0 then c.direction=0
   elseif direction~=c.direction or now>=c.nextRepeat then
    browse(state,c,direction)
    c.nextRepeat=now+(direction~=c.direction and C.repeatDelay or C.repeatInterval)
    c.direction=direction
   end
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