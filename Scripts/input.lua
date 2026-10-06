-- Keep raw engine key state available while blocking lower gameplay/native
-- wheel bindings. UIOnly would discard the controller input we need to read.
return function(E)
 local I={}
 local names={mx='MouseX',my='MouseY',x='Gamepad_LeftX',y='Gamepad_LeftY',rx='Gamepad_RightX',ry='Gamepad_RightY',q='Q',
  accept='Gamepad_FaceButton_Bottom',back='Gamepad_FaceButton_Right',close='Gamepad_Special_Right',
  toggle='Gamepad_FaceButton_Top',previous='Gamepad_LeftShoulder',next='Gamepad_RightShoulder',
  up='Gamepad_DPad_Up',down='Gamepad_DPad_Down',left='Gamepad_DPad_Left',right='Gamepad_DPad_Right',
  confirm='Gamepad_RightTrigger',cancel='Gamepad_LeftTrigger',
  mouseConfirm='LeftMouseButton',mouseCancel='RightMouseButton',escape='Escape'}
 local keys={}
 for k,n in pairs(names) do keys[k]={KeyName=FName(n)} end
 function I.new(pc)
  local i={pc=pc}
  function i.sample()
   local s={}
   for k,key in pairs(keys) do
    if k=='x' or k=='y' or k=='rx' or k=='ry' or k=='mx' or k=='my' then s[k]=pc:GetInputAnalogKeyState(key)
    else s[k]=pc:IsInputKeyDown(key) end
   end
   if s.rx*s.rx+s.ry*s.ry>s.x*s.x+s.y*s.y then s.x,s.y=s.rx,s.ry end
   s.close=s.close or s.toggle
   return s
  end
  function i.device()
   local sub=FindFirstOf('CommonInputSubsystem')
   if not E.valid(sub) then return false,'xbox' end
   local name=sub:GetCurrentGamepadName():ToString():lower()
   return sub:GetCurrentInputType()==1,(name:find('ps') or name:find('playstation') or name:find('dualsense') or name:find('dualshock')) and 'playstation' or 'xbox'
  end
  function i.capture()
   if not E.valid(i.actor) then
    local gs=StaticFindObject('/Script/Engine.Default__GameplayStatics')
    local tr={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
    i.actor=gs:BeginDeferredActorSpawnFromClass(pc,E.class('/Script/Engine.Actor'),tr,1,pc,0)
    assert(E.valid(i.actor),'Could not create wheel input blocker')
    i.actor.bBlockInput=false
    i.actor.InputPriority=1000000
    i.actor=gs:FinishSpawningActor(i.actor,tr,0)
   end
   if not E.valid(i.mapping) then
    i.sub=FindFirstOf('EnhancedInputLocalPlayerSubsystem')
    assert(E.valid(i.sub),'Missing local input subsystem')
    i.mapping=StaticConstructObject(E.class('/Script/EnhancedInput.InputMappingContext'),pc)
    i.action=StaticConstructObject(E.class('/Script/EnhancedInput.InputAction'),i.mapping)
    i.action.bConsumeInput=false
    -- Native UI actions (especially B/back) run ahead of the actor input stack.
    -- Consume their mappings while reading their raw keys ourselves.
    for k,key in pairs(keys) do
     if k~='x' and k~='y' and k~='rx' and k~='ry' and k~='mx' and k~='my' then i.mapping:MapKey(i.action,key) end
    end
   end
   if not i.captured then
    i.actor:EnableInput(pc)
    i.sub:AddMappingContext(i.mapping,1000000,{bIgnoreAllPressedKeysUntilRelease=false,bForceImmediately=true,bNotifyUserSettings=false})
    i.captured=true
   end
   i.draining=false
  end
  function i.release(force)
   if not i.captured then return end
   local s=not force and i.sample() or {}
   -- Do not leak the button that cast/closed the wheel into gameplay or the
   -- native spell-confirmation screen. Unblock as soon as it is released.
    if s.accept or s.back or s.close or s.q then i.draining=true
    return end
   if E.valid(i.actor) and E.valid(pc) then i.actor:DisableInput(pc) end
   if E.valid(i.sub) and E.valid(i.mapping) then
    i.sub:RemoveMappingContext(i.mapping,{bIgnoreAllPressedKeysUntilRelease=false,bForceImmediately=true,bNotifyUserSettings=false})
   end
   i.captured=false
   i.draining=false
  end
  function i.shutdown()
   i.release(true)
   if E.valid(i.actor) then i.actor:K2_DestroyActor() end
   i.actor=nil
   i.mapping=nil
   i.action=nil
   i.sub=nil
  end
  return i
 end
 return I
end
