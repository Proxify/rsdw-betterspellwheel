-- BetterSpellWheel 0.4.0. Client UI; casting remains entirely native.
local source=debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
local folder=source:match('^(.*)/Scripts/[^/]+$')
assert(folder,'BetterSpellWheel must run from its Scripts directory')
if _G.BetterSpellWheel and _G.BetterSpellWheel.shutdown then _G.BetterSpellWheel.shutdown() end
local M={version='0.4.1',open=false,folder=folder,disabled=false,queue={}}
_G.BetterSpellWheel=M
local model=dofile(folder..'/Scripts/model.lua')
local controller=dofile(folder..'/Scripts/controller.lua')(model)
local catalogue=dofile(folder..'/Scripts/catalogue.lua')(model)
local cooldowns=dofile(folder..'/Scripts/cooldowns.lua').new()
local icons=dofile(folder..'/Scripts/icons.lua')
local E={}
function E.valid(x) return x~=nil and x:IsValid() end
function E.asset(path)
 local a=StaticFindObject(path)
 if not E.valid(a) then a=LoadAsset(path) end
 return E.valid(a) and a or nil
end
function E.class(path)
 local c=StaticFindObject(path)
 if not E.valid(c) then LoadAsset(path:gsub('_C$',''));c=StaticFindObject(path) end
 assert(E.valid(c),'Missing class '..path);return c
end
E.lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
E.layout=StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary')
E.render=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
E.clock=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
function E.create(pc,path) return E.lib:Create(pc,E.class(path),pc) end
local layout=dofile(folder..'/Scripts/layout.lua')
local inputAdapter=dofile(folder..'/Scripts/input.lua')(E)
local view=dofile(folder..'/Scripts/view.lua')(E,model,layout)
local function log(s) print('[BetterSpellWheel] '..s..'\n') end
local cfg={Enabled=true,ControllerPrompts="auto"}
local file=io.open(folder..'/config.txt','r')
if file then for line in file:lines() do local k,v=line:match('^%s*(%w+)%s*=%s*(%w+)');if k=='Enabled' then cfg.Enabled=v:lower()~='false' elseif k=='ControllerPrompts' and (v:lower()=='xbox' or v:lower()=='playstation') then cfg.ControllerPrompts=v:lower() end end;file:close() end
local pc,radial,panel,input,component,ui,state,pending,device,pad
local cachedGroups,lastCatalogueRefresh= nil,nil
local uiBuildErrorLogged=false
local pointerX,pointerY
local lastTime,frame,elapsed,renderDt=0,0,0,0
M.cooldowns=cooldowns
function M.auditLayout() return ui and ui.audit() or {'wheel not built'} end
local function nativeOpen() return E.valid(input) and E.valid(pc) and input:IsOpen(pc,21) end
local function gameTime()
 local ok,value=pcall(function() return E.clock:GetGameTimeInSeconds(pc) end)
 local number=ok and tonumber(value)
 return number or elapsed
end
local function ensureUi()
 if ui and E.valid(ui.root) then return true end
 local ok,result=pcall(function() return view.new(pc,folder,icons) end)
 if ok then
  ui=result;uiBuildErrorLogged=false
  return true
 end
 if not uiBuildErrorLogged then
  log('Waiting to build custom wheel: '..tostring(result));uiBuildErrorLogged=true
 end
 return false
end
local function suppressNativeWheel()
 if E.valid(panel) then panel:SetRenderOpacity(0);panel:SetVisibility(2) end
end
local function inputModeName()
 local mode=pc.CurrentInputMode
 return E.valid(mode) and mode:GetFName():ToString() or ''
end
local function isCastingMode(name)
 return name:find('SpellPlacement') or name:find('Spellcasting')
end
local function cacheCatalogue()
 if cachedGroups then return true end
 local ok,groups,errors=pcall(function()
  return catalogue.scan(function(_,data) return pc:GetProgressComponent():IsSpellUnlocked(data) end,pc:GetSkillPerkComponent())
 end)
 if not ok then
  if not uiBuildErrorLogged then log('Waiting to cache spell catalogue: '..tostring(groups));uiBuildErrorLogged=true end
  return false
 end
 cachedGroups=groups
 lastCatalogueRefresh=elapsed
 if #errors>0 then log('Catalogue skipped '..#errors..' unavailable records') end
 return true
end
local function refreshCatalogue()
 if not cachedGroups then return false end
 if not lastCatalogueRefresh or elapsed-lastCatalogueRefresh>=5 then
  catalogue.refresh(cachedGroups,function(record)
   return pc:GetProgressComponent():IsSpellUnlocked(record.data)
  end)
  lastCatalogueRefresh=elapsed
 end
 return true
end
local function controls(on)
 pc.bShowMouseCursor=on
 if on then
  device.capture()
  E.lib:SetInputMode_GameAndUIEx(pc,nil,0,false,false)
  pc.bShowMouseCursor=state.input~='controller'
 else
  if device then device.release() end
  E.lib:SetInputMode_GameOnly(pc,false);pc:RefreshInputMode()
 end
end
local function restore()
 if not pending then return end
 local p=pending;pending=nil;M.pending=nil;M.cancelRequested=nil
 if E.valid(p.component) then
  -- Never overwrite a newer update from the game/server.
  local current=p.component.SelectedSpells[p.index]
  if E.valid(current) and E.valid(p.spell) and current:GetAddress()==p.spell:GetAddress() then
   if E.valid(radial) and radial.SpellbookSelector.RadioGroup:GetSelectedValue()==p.book then
    p.component:Client_NotifySelectedSpell(E.valid(p.original) and p.original or nil,p.slot)
   else
    -- A native book switch changes the notification's relative offset. Repair
    -- only our old absolute array entry; the visible book is left untouched.
    p.component.SelectedSpells[p.index]=p.original
   end
  end
 end
end
function M.close()
 if ui and E.valid(ui.root) then ui.hide() end
 if M.open then
  M.open=false
  if state then model.close(state) end
  if nativeOpen() and not M.suppressQUntilRelease then input:CloseWidgetIfOpen(pc,21,false,false) end
  -- Q is also the native wheel toggle. Keep our high-priority input capture
  -- until Q is released, otherwise the same key event can reopen the legacy
  -- wheel after this custom wheel closes.
  if E.valid(pc) and not M.suppressQUntilRelease then controls(false) end
 end
 -- Keep the native wheel hidden through its close transition. Restoring its
 -- opacity here creates the one-frame flash seen when Q/Esc closes the mod.
 suppressNativeWheel()
 M.nativeSuppressedUntil=elapsed+.30
 M.queue={};M.message=nil
end
local function bindWorld()
 local found=FindFirstOf('BP_PlayerController_C')
 if not E.valid(found) or not E.valid(found.Pawn) then
  if M.open then M.close() end
  restore();if device then device.shutdown();device=nil end;pc=nil;radial=nil;return false
 end
  if E.valid(pc) and pc:GetAddress()==found:GetAddress() and E.valid(radial) then
   if not M.open and not pending then
    if not ensureUi() or not cacheCatalogue() then return false end
    refreshCatalogue()
    suppressNativeWheel()
  end
  return true
 end
  M.close();restore();if device then device.shutdown() end;pc=found;device=inputAdapter.new(pc);radial=nil;ui=nil;cachedGroups=nil;lastCatalogueRefresh=nil
 for _,w in ipairs(FindAllOf('WBP_SurvivalSorcery_RadialSelector_C') or {}) do
  if E.valid(w) and not w.bIsSpellbookInstance and w.Slices:GetArrayNum()>0 then radial=w;break end
 end
 if not E.valid(radial) then return false end
 panel=radial:GetOuter():GetOuter();input=FindFirstOf('InputManagerUIAPI');component=pc:GetSpellcastingComponent()
 if not (E.valid(panel) and E.valid(input) and E.valid(component)) then return false end
 if not M.open and not pending then
  -- Build the replacement while the native wheel is closed, then keep the
  -- native panel hidden so its open animation cannot flash for one frame.
  if not ensureUi() or not cacheCatalogue() then return false end
  refreshCatalogue()
  suppressNativeWheel()
 end
 return true
end
local function open()
 restore()
 if not cachedGroups then return end
 local groups=cachedGroups
 state=model.new(groups);M.state=state
 pad=controller.new()
 local usingPad,style=device.device();state.input=usingPad and 'controller' or 'mouse';state.padStyle=cfg.ControllerPrompts~='auto' and cfg.ControllerPrompts or style
 controller.prime(pad,device.sample());state.controllerStage=pad.stage
 -- Build before suppressing the native wheel, so a missing asset fails open.
 if not ensureUi() then return end
 radial:StopRadialSelection();panel:SetVisibility(2);panel:SetRenderOpacity(0)
 M.open=true;M.message=nil;M.hover=nil;M.back=false;M.queue={};M.since=elapsed;renderDt=0
 ui.show();controls(true)
 local dpi=E.layout:GetViewportScale(pc)
 pc:SetMouseLocation(math.floor(ui.width/2*dpi),math.floor(ui.height/2*dpi))
 pointerX,pointerY=ui.pointer()
end
local function costText(spell,now)
 if not spell then return '' end
 local parts={}
 for _,v in ipairs(spell.data:GetModulesOfType(E.class('/Script/Dominion.SpellModule_CostItems'))) do
  v:get().ItemsCostInfo:ForEach(function(_,p)
   local c=p:get()
   if E.valid(c.ItemData) then parts[#parts+1]=c.Count..' '..c.ItemData.Name:ToString() end
  end)
 end
 local s=#parts>0 and ('BASE COST  '..table.concat(parts,'  ·  ')) or 'No rune cost'
 local duration=cooldowns:duration(spell)
 if duration>0 then
  local remaining=cooldowns:remaining(spell,now)
  s=s..'\nCOOLDOWN  '..string.format('%gs',duration)..'  ·  '..(remaining>0 and ('READY IN '..cooldowns:format(remaining)) or 'READY')
 end
 return s
end
local function selectSpell()
 local spell,reason=model.selection(state)
 if not spell then
  if reason=='locked' then M.message='This spell has not been unlocked yet.';radial:InvalidSelectAudioTrigger() end
  return
 end
 if not pc:GetProgressComponent():IsSpellUnlocked(spell.data) then M.message='This spell has not been unlocked yet.';return end
 local remaining=cooldowns:remaining(spell,gameTime())
 if remaining>0 then
  M.message='On cooldown. Ready in '..cooldowns:format(remaining)..'.'
  radial:InvalidSelectAudioTrigger()
  return
 end
 local slot=radial.RadialSlice_0.SpellSlotNum
 local book=radial.SpellbookSelector.RadioGroup:GetSelectedValue()
 local index=book*component.NumSpellSlotsPerRadial+slot+1
 pending={component=component,original=component.SelectedSpells[index],spell=spell.data,slot=slot,index=index,book=book,since=elapsed}
 M.pending=pending
 component:Client_NotifySelectedSpell(spell.data,slot)
 radial.CachedSectionId=0;radial:HighlightSlice(0)
 -- Use native selection: requirements, cooldowns, rune costs and targeting.
 controls(false);radial:SelectSlice()
 if nativeOpen() then
  local requirement=radial.RequirementText:GetText():ToString()
    M.message='Unable to cast. Check runes, equipment and cooldown.'
  if requirement~='' and requirement~='-' then M.message='Requires '..requirement end
  restore();radial:StopRadialSelection();controls(true)
  else
   -- Start a provisional timer immediately so the wheel can show feedback
   -- while native targeting is active. A cancellation removes it below.
   cooldowns:start(spell,gameTime())
   local modeName=inputModeName()
   if isCastingMode(modeName) then
    pending.awaitingConfirm=true
    pending.cooldownStarted=true
    local sample=device.sample()
    pending.confirmArmed=not (sample.confirm or sample.mouseConfirm)
    pending.cancelArmed=not (sample.cancel or sample.mouseCancel or sample.escape or sample.back or sample.close)
   else
    -- Instant spells have already been accepted and cast by native selection.
   end
   -- Aimed/placed spells reread the slot on confirmation. Restore only after
  -- the native casting/placement mode has ended, including cancellation.
  M.open=false;model.close(state);ui.hide();panel:SetRenderOpacity(1);M.queue={}
 end
end
local function tick()
 frame=frame+1;elapsed=elapsed+.016
 if not cfg.Enabled or M.disabled then return end
 -- The replacement is already built and hidden natively. Poll idle state at
 -- roughly frame rate; input and UI work run faster only while the wheel is open.
 if not M.open and not pending and not (device and device.draining) and frame%2~=0 then return end
 if not bindWorld() then return end
 if device.draining then device.release() end
 if pending then
   if pending.awaitingConfirm then
    local sample=device.sample()
    if not pending.confirmArmed then
     pending.confirmArmed=not (sample.confirm or sample.mouseConfirm)
    elseif sample.confirm or sample.mouseConfirm then
     pending.confirmed=true
    end
    if not pending.cancelArmed then
     pending.cancelArmed=not (sample.cancel or sample.mouseCancel or sample.escape or sample.back or sample.close)
    elseif sample.cancel or sample.mouseCancel or sample.escape or sample.back or sample.close then
     pending.cancelled=true
    end
    if M.cancelRequested then pending.cancelled=true;M.cancelRequested=nil end
   end
   local name=inputModeName()
   if elapsed-pending.since>.15 and not isCastingMode(name) then
    if pending.awaitingConfirm and pending.cancelled then cooldowns:clear(pending.spell) end
    restore()
   end
 end
 if not M.open then
  if M.nativeSuppressedUntil then
   if nativeOpen() and not M.suppressQUntilRelease then input:CloseWidgetIfOpen(pc,21,false,false) end
   suppressNativeWheel()
   if M.suppressQUntilRelease and not device.sample().q then
    M.suppressQUntilRelease=false
    controls(false)
    M.reopenAfter=elapsed+.2
   end
   if elapsed<M.nativeSuppressedUntil then return end
   M.nativeSuppressedUntil=nil
  end
  if M.suppressQUntilRelease then
    if device.sample().q then
       if nativeOpen() then input:CloseWidgetIfOpen(pc,21,false,false);suppressNativeWheel() end
     return
    end
   M.suppressQUntilRelease=false;controls(false);M.reopenAfter=elapsed+.2
  end
  if M.reopenAfter then
    if nativeOpen() then
     input:CloseWidgetIfOpen(pc,21,false,false)
       suppressNativeWheel()
     return
    end
   if elapsed<M.reopenAfter then return end
   M.reopenAfter=nil
  end
  if nativeOpen() then open() end
  return
 end
 if not nativeOpen() then M.close();return end
 if not E.valid(ui.root) then M.close();return end
 local now=gameTime()
 local dt=math.min(.05,math.max(.001,now-lastTime));lastTime=now
 renderDt=renderDt+dt
 local x,y=ui.pointer()
 local sample=device.sample()
 local moved=(pointerX and ((x-pointerX)^2+(y-pointerY)^2)>9) or math.abs(sample.mx or 0)>.5 or math.abs(sample.my or 0)>.5
 pointerX,pointerY=x,y
 local padActivity=sample.x*sample.x+sample.y*sample.y>=controller.deadzone^2
 for _,k in ipairs({'accept','back','close','previous','next','up','down','left','right'}) do if sample[k] then padActivity=true end end
 if padActivity and state.input~='controller' then
  state.input='controller';pad=controller.new();state.spell=nil;M.back=false
  local _,style=device.device();state.padStyle=cfg.ControllerPrompts~='auto' and cfg.ControllerPrompts or style
 elseif moved and not padActivity and state.input~='mouse' then
  state.input='mouse';state.spell=nil;M.back=false
 end
 if state.input=='controller' then
  local action=controller.step(pad,state,sample,now)
  state.controllerStage=pad.stage
  if action=='select' or action=='close' then M.queue[#M.queue+1]=action end
  if action=='back' or action=='enter' then M.message=nil end
 else
  controller.prime(pad,sample)
  if M.back and x*x+y*y<model.geometry.outer^2 then M.back=false end
  if not M.back then model.update(state,x,y,now) end
 end
 local group=state.groups[state.group];local spell=group and group.spells[state.spell]
 local hover=spell and spell.id or tostring(state.group)
 local cooldownTick=math.ceil(now)
 if hover~=M.hover or cooldownTick~=M.cooldownTick then
  local changed=hover~=M.hover
  M.hover=hover;M.cooldownTick=cooldownTick
  if changed then M.message=nil end
  M.cost=costText(spell,now)
 end
 local queue=M.queue;M.queue={}
 for _,action in ipairs(queue) do
  if action=='close' then M.close();return
  elseif action=='back' then state.group=nil;state.spell=nil;state.candidate=nil;state.page=1;M.message=nil;M.back=true
  elseif action=='previous' then model.turnPage(state,-1)
  elseif action=='next' then model.turnPage(state,1)
  elseif action=='select' and elapsed-M.since>.15 then selectSpell();if not M.open then return end end
 end
 -- Game HUD activation can restore game input underneath custom UI.
 if frame%12==0 or pc.bShowMouseCursor~=(state.input~='controller') then controls(true) end
 if frame%2==0 then
  panel:SetVisibility(2);panel:SetRenderOpacity(0)
  ui.resize()
  ui.draw(state,renderDt,M.message,M.cost,nil,now,cooldowns)
  renderDt=0
 end
end
function M.shutdown()
 M.close()
 if pending and E.valid(component) then component:CancelSpellcasting() end
 restore()
 if device then device.shutdown() end
 if M.handle then CancelDelayedAction(M.handle);M.handle=nil end
end
-- Key callbacks only queue plain data; every UObject operation runs on game thread.
if not _G.BetterSpellWheelKeys then
 _G.BetterSpellWheelKeys=true
 for key,action in pairs({[1]='select',[2]='back',[0x51]='close',[0x1B]='close',[0x46]='previous',[0x47]='next'}) do
  local boundKey,boundAction=key,action
  RegisterKeyBind(boundKey,function()
   local m=_G.BetterSpellWheel
   if m and m.open then
    if boundKey==0x51 then m.suppressQUntilRelease=true end
    m.queue[#m.queue+1]=boundAction
   elseif m and m.pending and boundKey==0x1B then
    m.cancelRequested=true
   end
  end)
 end
end
-- Opt-in development console; dev.txt is never included in release archives.
local devPoll
local devFile=io.open(folder..'/dev.txt','r')
if devFile then
 local dir=devFile:read('a'):match('^%s*(.-)%s*$');devFile:close()
 devPoll=function()
  local f=io.open(dir..'in.lua','r');if not f then return end
  local code=f:read('a');f:close();os.remove(dir..'in.lua')
  local fn,err=load(code,'BetterSpellWheel dev','t',_G)
  local ok,result=false,err
  if fn then ok,result=xpcall(fn,debug.traceback) end
  local out=assert(io.open(dir..'out.tmp','w'))
  out:write((ok and '=> ' or 'ERROR: ')..tostring(result));out:close()
  os.remove(dir..'out.txt');os.rename(dir..'out.tmp',dir..'out.txt')
 end
end
M.handle=LoopInGameThreadWithDelay(8,function()
 if devPoll and frame%6==0 then pcall(devPoll) end
 if _G.BetterSpellWheel~=M then return end
 local ok,err=pcall(tick)
 if not ok then
  log('Disabled after error; restoring native controls: '..tostring(err));M.disabled=true
  pcall(M.close);pcall(restore);if device then pcall(device.shutdown) end
 end
end)
log('Loaded '..M.version..'. Open the spell wheel with your normal key (Q).')
return M
