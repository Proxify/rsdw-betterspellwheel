-- SpellBranches 0.1.0. Client UI; casting remains entirely native.
local source=debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
local folder=source:match('^(.*)/Scripts/[^/]+$')
assert(folder,'SpellBranches must run from its Scripts directory')
if _G.SpellBranches and _G.SpellBranches.shutdown then _G.SpellBranches.shutdown() end
local M={version='0.1.0',open=false,folder=folder,disabled=false,queue={}}
_G.SpellBranches=M
local model=dofile(folder..'/Scripts/model.lua')
local catalogue=dofile(folder..'/Scripts/catalogue.lua')(model)
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
local view=dofile(folder..'/Scripts/view.lua')(E,model)
local function log(s) print('[SpellBranches] '..s..'\n') end
local cfg={Enabled=true}
local file=io.open(folder..'/config.txt','r')
if file then for line in file:lines() do local k,v=line:match('^%s*(%w+)%s*=%s*(%w+)');if k=='Enabled' then cfg.Enabled=v:lower()~='false' end end;file:close() end
local pc,radial,panel,input,component,ui,state,pending
local lastTime,frame,elapsed=0,0,0
local function nativeOpen() return E.valid(input) and E.valid(pc) and input:IsOpen(pc,21) end
local function controls(on)
 pc.bShowMouseCursor=on
 if on then E.lib:SetInputMode_UIOnlyEx(pc,nil,0,false)
 else E.lib:SetInputMode_GameOnly(pc,true);pc:RefreshInputMode() end
end
local function restore()
 if not pending then return end
 local p=pending;pending=nil
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
 if E.valid(panel) then panel:SetRenderOpacity(1);if nativeOpen() then panel:SetVisibility(0) end end
 if M.open then
  M.open=false
  if state then model.close(state) end
  if nativeOpen() then input:CloseWidgetIfOpen(pc,21,false,false) end
  if E.valid(pc) then controls(false) end
 end
 M.queue={};M.message=nil
end
local function bindWorld()
 local found=FindFirstOf('BP_PlayerController_C')
 if not E.valid(found) or not E.valid(found.Pawn) then
  if M.open then M.close() end
  restore();pc=nil;radial=nil;return false
 end
 if E.valid(pc) and pc:GetAddress()==found:GetAddress() and E.valid(radial) then return true end
 M.close();restore();pc=found;radial=nil;ui=nil
 for _,w in ipairs(FindAllOf('WBP_SurvivalSorcery_RadialSelector_C') or {}) do
  if E.valid(w) and not w.bIsSpellbookInstance and w.Slices:GetArrayNum()>0 then radial=w;break end
 end
 if not E.valid(radial) then return false end
 panel=radial:GetOuter():GetOuter();input=FindFirstOf('InputManagerUIAPI');component=pc:GetSpellcastingComponent()
 if not (E.valid(panel) and E.valid(input) and E.valid(component)) then return false end
 return true
end
local function open()
 restore()
 local groups,errors=catalogue.scan(function(_,data) return pc:GetProgressComponent():IsSpellUnlocked(data) end)
 if #errors>0 then log('Catalogue skipped '..#errors..' unavailable records') end
 state=model.new(groups);M.state=state
 -- Build before suppressing the native wheel, so a missing asset fails open.
 if not ui or not E.valid(ui.root) then ui=view.new(pc,folder,icons) end
 radial:StopRadialSelection();panel:SetVisibility(2);panel:SetRenderOpacity(0)
 M.open=true;M.message=nil;M.hover=nil;M.back=false;M.queue={};M.since=elapsed
 ui.show();controls(true)
 local dpi=E.layout:GetViewportScale(pc)
 pc:SetMouseLocation(math.floor((ui.width/2-220*ui.scale)*dpi),math.floor(ui.height/2*dpi))
end
local function costText(spell)
 if not spell then return '' end
 local parts={}
 for _,v in ipairs(spell.data:GetModulesOfType(E.class('/Script/Dominion.SpellModule_CostItems'))) do
  v:get().ItemsCostInfo:ForEach(function(_,p)
   local c=p:get()
   if E.valid(c.ItemData) then parts[#parts+1]=c.Count..' '..c.ItemData.Name:ToString() end
  end)
 end
 local s=#parts>0 and ('BASE COST  '..table.concat(parts,'  ·  ')) or 'No rune cost'
 if spell.cooldown>0 then s=s..'\nCOOLDOWN  '..string.format('%gs',spell.cooldown) end
 return s
end
local function selectSpell()
 local spell,reason=model.selection(state)
 if not spell then
  if reason=='locked' then M.message='This spell has not been unlocked yet.';radial:InvalidSelectAudioTrigger() end
  return
 end
 if not pc:GetProgressComponent():IsSpellUnlocked(spell.data) then M.message='This spell has not been unlocked yet.';return end
 local slot=radial.RadialSlice_0.SpellSlotNum
 local book=radial.SpellbookSelector.RadioGroup:GetSelectedValue()
 local index=book*component.NumSpellSlotsPerRadial+slot+1
 pending={component=component,original=component.SelectedSpells[index],spell=spell.data,slot=slot,index=index,book=book,since=elapsed}
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
  -- Aimed/placed spells reread the slot on confirmation. Restore only after
  -- the native casting/placement mode has ended, including cancellation.
  M.open=false;model.close(state);ui.hide();panel:SetRenderOpacity(1);M.queue={}
 end
end
local function tick()
 frame=frame+1;elapsed=elapsed+.016
 if not cfg.Enabled or M.disabled then return end
 if not M.open and not pending and frame%2~=0 then return end
 if not bindWorld() then return end
 if pending then
  local mode=pc.CurrentInputMode
  local name=E.valid(mode) and mode:GetFName():ToString() or ''
  if elapsed-pending.since>.15 and not name:find('SpellPlacement') and not name:find('Spellcasting') then restore() end
 end
 if not M.open then if nativeOpen() then open() end;return end
 if not nativeOpen() then M.close();return end
 if not E.valid(ui.root) then M.close();return end
 local now=E.clock:GetGameTimeInSeconds(pc)
 local dt=math.min(.05,math.max(.001,now-lastTime));lastTime=now
 ui.resize()
 local x,y=ui.pointer()
 if M.back and x*x+y*y<model.geometry.outer^2 then M.back=false end
 if not M.back then model.update(state,x,y,now) end
 local group=state.groups[state.group];local spell=group and group.spells[state.spell]
 local hover=spell and spell.id or tostring(state.group)
 if hover~=M.hover then M.hover=hover;M.message=nil;M.cost=costText(spell) end
 local queue=M.queue;M.queue={}
 for _,action in ipairs(queue) do
  if action=='close' then M.close();return
  elseif action=='back' then state.group=nil;state.spell=nil;state.candidate=nil;state.page=1;M.message=nil;M.back=true
  elseif action=='previous' then model.turnPage(state,-1)
  elseif action=='next' then model.turnPage(state,1)
  elseif action=='select' and elapsed-M.since>.15 then selectSpell();if not M.open then return end end
 end
 -- Game HUD activation can restore game input underneath custom UI.
 if frame%12==0 or not pc.bShowMouseCursor then controls(true) end
 panel:SetVisibility(2);panel:SetRenderOpacity(0)
 ui.draw(state,dt,M.message,M.cost)
end
function M.shutdown()
 M.close()
 if pending and E.valid(component) then component:CancelSpellcasting() end
 restore()
 if M.handle then CancelDelayedAction(M.handle);M.handle=nil end
end
-- Key callbacks only queue plain data; every UObject operation runs on game thread.
if not _G.SpellBranchesKeys then
 _G.SpellBranchesKeys=true
 for key,action in pairs({[1]='select',[2]='back',[0x51]='close',[0x1B]='close',[0x46]='previous',[0x47]='next'}) do
  RegisterKeyBind(key,function() local m=_G.SpellBranches;if m and m.open then m.queue[#m.queue+1]=action end end)
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
  local fn,err=load(code,'SpellBranches dev','t',_G)
  local ok,result=false,err
  if fn then ok,result=xpcall(fn,debug.traceback) end
  local out=assert(io.open(dir..'out.tmp','w'))
  out:write((ok and '=> ' or 'ERROR: ')..tostring(result));out:close()
  os.remove(dir..'out.txt');os.rename(dir..'out.tmp',dir..'out.txt')
 end
end
M.handle=LoopInGameThreadWithDelay(16,function()
 if devPoll and frame%6==0 then pcall(devPoll) end
 if _G.SpellBranches~=M then return end
 local ok,err=pcall(tick)
 if not ok then
  log('Disabled after error; restoring native controls: '..tostring(err));M.disabled=true
  pcall(M.close);pcall(restore)
 end
end)
log('Loaded '..M.version..'. Open the spell wheel with your normal key (Q).')
return M
