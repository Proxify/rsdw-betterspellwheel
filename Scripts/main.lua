-- BetterSpellWheel 0.4.4. Client UI; casting remains entirely native.
local source=debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
local folder=source:match('^(.*)/Scripts/[^/]+$')
assert(folder,'BetterSpellWheel must run from its Scripts directory')
if _G.BetterSpellWheel and _G.BetterSpellWheel.shutdown then _G.BetterSpellWheel.shutdown() end
local M={version='0.4.6',open=false,folder=folder,disabled=false,queue={}}
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
-- UE4SS 3.0.1 (the current stable release) has no hashed StaticFindObject: each
-- call walks every UObject, about 12 ms on a reporter's Ryzen 7 7700X (0.4.5 log,
-- 2026-10-17), and a per-tick lookup halved their frame rate. Experimental UE4SS
-- builds hash it (3 us). So nothing below looks an object up per tick, hover or
-- opening: native (/Script) classes live for the whole process and are found once.
local nativeClasses={}
function E.class(path)
 local c=nativeClasses[path]
 if E.valid(c) then return c end
 c=StaticFindObject(path)
 if not E.valid(c) then LoadAsset(path:gsub('_C$',''));c=StaticFindObject(path) end
 assert(E.valid(c),'Missing class '..path)
 if path:sub(1,8)=='/Script/' then nativeClasses[path]=c end
 return c
end
E.lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
E.layout=StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary')
E.render=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
E.clock=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
E.stats=StaticFindObject('/Script/Engine.Default__GameplayStatics')
E.subsystems=StaticFindObject('/Script/Engine.Default__SubsystemBlueprintLibrary')
-- A local-player subsystem (input type, Enhanced Input) of this controller,
-- asked from the engine instead of a FindFirstOf scan of every object.
function E.localSubsystem(pc,path)
 local s
 if E.valid(E.subsystems) and E.valid(pc) then
  pcall(function() s=E.subsystems:GetLocalPlayerSubSystemFromPlayerController(pc,E.class(path)) end)
 end
 if E.valid(s) then return s end
 return FindFirstOf(path:match('[^.]+$'))
end
function E.create(pc,path) return E.lib:Create(pc,E.class(path),pc) end
local layout=dofile(folder..'/Scripts/layout.lua')
local inputAdapter=dofile(folder..'/Scripts/input.lua')(E)
-- The wheel artwork is drawn on first launch and cached in Assets/v2/ (no image
-- files are shipped). If this fails the view can't load its textures and the
-- mod falls back to the native wheel.
local artOk,art=pcall(dofile,folder..'/Scripts/art.lua')
local view=dofile(folder..'/Scripts/view.lua')(E,model,layout,artOk and art or nil)
do
 local ok,drawn=pcall(function() assert(artOk,art);return art.ensure(folder) end)
 if not ok then print('[BetterSpellWheel] Could not draw wheel artwork: '..tostring(drawn)..'\n')
 elseif drawn>0 then print('[BetterSpellWheel] Drew '..drawn..' wheel textures\n') end
end
local function log(s) print('[BetterSpellWheel] '..s..'\n') end -- errors and one-off warnings only
local cfg={Enabled=true,ControllerPrompts="auto",KeepNativeHidden=true,ShowCooldowns=true}
local file=io.open(folder..'/config.txt','r')
if file then for line in file:lines() do local k,v=line:match('^%s*(%w+)%s*=%s*(%w+)');if k=='Enabled' then cfg.Enabled=v:lower()~='false' elseif k=='ControllerPrompts' and (v:lower()=='xbox' or v:lower()=='playstation') then cfg.ControllerPrompts=v:lower() elseif k=='KeepNativeHidden' then cfg.KeepNativeHidden=v:lower()~='false' elseif k=='ShowCooldowns' then cfg.ShowCooldowns=v:lower()~='false' elseif k=='PerfLog' then cfg.PerfLog=v:lower()=='true' end end;file:close() end
M.cfg=cfg
-- Opt-in profiler (PerfLog=true in config.txt): once a second, logs the time the
-- mod spent on the game thread (total, worst tick, per section), the frame time,
-- object-scan calls and the Lua heap. Off by default: no cost when off.
local perf
do
 -- A previous load's counting wrappers are removed first (script reloads).
 local original=_G.BetterSpellWheelOriginals
 if original then for name,fn in pairs(original) do _G[name]=fn end;_G.BetterSpellWheelOriginals=nil end
 if cfg.PerfLog then
  original={FindAllOf=FindAllOf,FindFirstOf=FindFirstOf,StaticFindObject=StaticFindObject}
  _G.BetterSpellWheelOriginals=original
  perf={since=os.clock(),ticks=0,total=0,max=0,sections={},calls={},frames=0,frameSum=0,frameMax=0}
  for name,fn in pairs(original) do
   _G[name]=function(...) perf.calls[name]=(perf.calls[name] or 0)+1;return fn(...) end
  end
 end
end
M.perf=perf
local perfTick
local function mark(name)
 local now=os.clock()
 perf.sections[name]=(perf.sections[name] or 0)+(now-perf.last);perf.last=now
end
local pc,radial,panel,input,component,ui,state,pending,device,pad,catalogueGroups
local unlockRefreshAt={}
local nativeWasOpen=false
M.radial=nil
local openWasDown=false
local pointerX,pointerY
-- Gamepad X / Square while the wheel is open hands over to the game's emote wheel.
local emoteWasDown=false
local emoteHandoffAt=nil
local emoteWheelActive=false
local emoteWheelSeen=false -- native emote mode has been observed since the handoff
local lastTime,frame,elapsed,lastSync=0,0,0,0
M.cooldowns=cooldowns
local function nativeOpen() return E.valid(input) and E.valid(pc) and input:IsOpen(pc,21) end   -- (input: a live instance, bindWorld)
local function sameObject(a,b)
 if not E.valid(a) or not E.valid(b) then return false end
 local oka,aa=pcall(function() return a:GetAddress() end)
 local okb,bb=pcall(function() return b:GetAddress() end)
 return oka and okb and aa==bb
end

-- The native selector is suppressed at its visibility request, before it renders.
-- Hide the radial's grandparent panel, exactly like 0.3.0. The radial itself is
-- left live so its slices keep processing notify/highlight/select normally.
-- The game can animate/reset the panel's opacity and visibility on open and close.
-- With KeepNativeHidden (default) the panel is parked far off-screen with a render
-- translation at bind and close (the game doesn't animate that) and not re-hidden
-- on open or every few frames (PR6). PROVISIONAL: needs the native no-flash check
-- (first open, reopen, after a cast or emote, resolution change, respawn).
-- With KeepNativeHidden=false, visibility and opacity are still re-asserted.
-- The native panel is a game-owned widget that can be destroyed and rebuilt
-- (HUD changes, casting modes). Calling a UFunction on a freed widget is a
-- native fault pcall can't catch: a 0.4.0 test build crashed in
-- panel:SetVisibility while re-hiding it every tick. So: touch it only while
-- the wheel is open (and once on bind/close), and confirm it is still a live
-- object right before each write. The check is a lookup of its own object
-- path (a hash lookup on experimental UE4SS, a full object walk on 3.0.1); a
-- class scan is the fallback if that form doesn't resolve. One tick never
-- checks it twice: the game can't free it during our tick (0.4.7).
local panelPath,panelClass,panelAddr,panelFast
local tickId,inTick,panelSeenTick=0,false,nil
local function rememberPanel()
 panelPath,panelClass,panelAddr,panelFast,panelSeenTick=nil,nil,nil,nil,nil
 pcall(function()
  panelAddr=panel:GetAddress()
  panelClass=panel:GetClass():GetFName():ToString()
  panelPath=panel:GetFullName():match('^%S+%s+(.+)$')
 end)
end
local function panelAlive()
 if not panelAddr then return false end
 if inTick and panelSeenTick==tickId then return true end
 if panelFast~=false and panelPath then
  local ok,o=pcall(StaticFindObject,panelPath)
  if ok and o and o:IsValid() and o:GetAddress()==panelAddr then panelFast=true;panelSeenTick=inTick and tickId or nil;return true end
  if panelFast then panel,radial,panelAddr=nil,nil,nil;return false end
 end
 local ok,list=pcall(FindAllOf,panelClass)
 if ok and type(list)=='table' then
  for _,w in ipairs(list) do if w:GetAddress()==panelAddr then panelFast=false;panelSeenTick=inTick and tickId or nil;return true end end
 end
 -- Gone: drop the cached widgets so bindWorld finds the new ones.
 panel,radial,panelAddr=nil,nil,nil
 return false
end
local function keepNativeOffscreen()
 if not (cfg.KeepNativeHidden and panelAlive()) then return end
 pcall(function() panel:SetRenderOpacity(0) end)
 pcall(function() panel:SetRenderTranslation({X=-20000,Y=-20000}) end)
end
local function hideNativeWheel(panelIsAlive)
 if cfg.KeepNativeHidden then return end
 if not panelIsAlive and not panelAlive() then return end
 pcall(function() panel:SetVisibility(2) end)
 pcall(function() panel:SetRenderOpacity(0) end)
end
-- KeepNativeHidden (default on): the native panel stays at opacity 0 permanently,
-- so neither the open nor the close of the native wheel can ever flash on screen.
-- Set KeepNativeHidden=false in config.txt to restore opacity after each cast/close.
local function restoreNativePanel()
 if panelAlive() then
  pcall(function() panel:SetRenderOpacity(1) end)
  pcall(function() panel:SetRenderTranslation({X=0,Y=0}) end)
 end
end
local function showNativePanel()
 if cfg.KeepNativeHidden then return end
 restoreNativePanel()
end
local function controls(on)
 pc.bShowMouseCursor=on
 if on then
  if device then device.capture() end
  E.lib:SetInputMode_GameAndUIEx(pc,nil,0,false,false)
  pc.bShowMouseCursor=state.input~='controller'
 else
  if device then device.release() end
  -- Preserve the original, working handoff. The native spell selector must
  -- receive input after the custom wheel releases ownership.
  -- Never flush held gameplay keys on handoff; flushing can leave movement
  -- appearing paused until the player taps the movement key again.
  E.lib:SetInputMode_GameOnly(pc,false)
  pc:RefreshInputMode()
 end
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
    -- The notify can silently fail to take; if our spell is still in the slot,
    -- write the original back directly so the next cast starts from a clean slot.
    local after=p.component.SelectedSpells[p.index]
    if E.valid(after) and sameObject(after,p.spell) then
     pcall(function() p.component.SelectedSpells[p.index]=p.original end)
    end
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
 nativeWasOpen=false
 if cfg.KeepNativeHidden then keepNativeOffscreen()
 else restoreNativePanel() end
 if panelAlive() and nativeOpen() then pcall(function() panel:SetVisibility(0) end) end
 if M.open then
  M.open=false
  if state then model.close(state) end
  -- This is the important part of the original close lifecycle: close the
  -- native widget first, then hand input/mouse ownership back to the game.
  if E.valid(input) and E.valid(pc) then
   pcall(function() input:CloseWidgetIfOpen(pc,21,false,false) end)
  end
  if E.valid(pc) then controls(false) end
 end
 M.queue={};M.message=nil
end
-- FindFirstOf walks the whole UObject array (hundreds of thousands of objects).
-- It runs only to find the first controller, and every BIND_RETRY seconds while
-- unbound (menus, loading) until the local player is known.
-- The bound controller is checked every tick. 0.4.2-0.4.6 looked it up by its
-- object path: on UE4SS 3.0.1 that walks every object, about 12 ms per tick.
-- 0.4.7 reads the engine's own record instead. The local player (owned by the
-- game instance for the whole session) holds the current controller in a
-- UPROPERTY, which never points at a freed controller (GC clears it or keeps the
-- object). That is a property read: a replaced or removed controller is noticed
-- on the next tick, and the new one is taken from it too, with no scan. Without
-- a verified local player, the path check and a rescan every BIND_VERIFY
-- seconds remain (0.4.6 behaviour).
local BIND_VERIFY,BIND_RETRY=2,.25
local scannedAt=-1e9
local localPlayer,pcAnchored,pcPath,pcAddr,pawnAddrBound
-- the controller's local player, if that player's current controller is this one
local function playerOf(controller)
 local lp
 pcall(function()
  local p=controller.Player
  local current=E.valid(p) and p.PlayerController
  if E.valid(current) and current:GetAddress()==controller:GetAddress() then lp=p end
 end)
 return lp
end
local function rememberPc()
 pcPath,pcAddr,pcAnchored=nil,nil,false
 pcall(function() pcAddr=pc:GetAddress() end)
 if not pcAddr then return end
 local lp=playerOf(pc)
 if lp then localPlayer,pcAnchored=lp,true;return end
 pcall(function()
  local path=pc:GetFullName():match('^%S+%s+(.+)$')
  -- Only use the path if it resolves to this very controller.
  local o=StaticFindObject(path)
  if o and o:IsValid() and o:GetAddress()==pcAddr then pcPath=path end
 end)
 log('controller check: no verified local player, using path lookups')
end
local function pcAlive()
 if not pcAddr then return false end
 if pcAnchored then
  local ok,same=pcall(function()
   local current=E.valid(localPlayer) and localPlayer.PlayerController
   return E.valid(current) and current:GetAddress()==pcAddr
  end)
  return ok and same==true
 end
 -- Without a usable path there is no safe cheap check: rescan (0.4.2 behaviour).
 if not pcPath then return false end
 local ok,o=pcall(StaticFindObject,pcPath)
 return ok and o~=nil and o:IsValid() and o:GetAddress()==pcAddr
end
-- The world's player controller: the local player's own once it is known.
local function currentController()
 if E.valid(localPlayer) then
  local c
  pcall(function() c=localPlayer.PlayerController end)
  if not E.valid(c) then return nil end
  local ok,name=pcall(function() return c:GetClass():GetFName():ToString() end)
  return ok and name=='BP_PlayerController_C' and c or nil
 end
 localPlayer=nil
 return FindFirstOf('BP_PlayerController_C')
end
local function samePawn()
 local ok,same=pcall(function() local p=pc.Pawn;return E.valid(p) and p:GetAddress()==pawnAddrBound end)
 return ok and same==true
end
-- World entry settle (0.4.5): a client crashed ~2 s after joining a server (native AV reading 0x0 under ProcessEvent,
-- called from UE4SS; 3 of 10 joins with BetterSpellWheel, 0 without, 2026-10-15). In the first seconds of a world the
-- previous (menu) world's UI objects are still around and IsValid() stays true for them until garbage collection, and
-- the HUD is still being built. Nothing is called on the world until the player's pawn has been there SETTLE seconds,
-- and only live, non-default, not pending-kill objects are bound (the Together mod's rule since 2.0).
local SETTLE=5
local pawnSeen,pawnSince=nil,nil
-- a live instance of a class: not a Default__/archetype object, not pending kill
local function liveOf(className, widget)
 for _,o in ipairs(FindAllOf(className) or {}) do
  local ok,name=pcall(function() return o:GetFullName() end)
  if ok and type(name)=='string' and not name:find('Default__',1,true) and (not widget or name:find(' /Engine/Transient.',1,true)) and E.alive(o) then
   if not widget then return o end
   local okW,good=pcall(function() return not o.bIsSpellbookInstance and o.Slices:GetArrayNum()>0 end)
   if okW and good then return o end
  end
 end
end
local function bindWorld()
 if pc and radial then
  if (pcAnchored or elapsed-scannedAt<BIND_VERIFY) and pcAlive() and samePawn() and E.valid(radial) then return true end
 elseif elapsed-scannedAt<BIND_RETRY and not (M.open or pending) then
  -- (While the wheel is open or a cast is pending, rebind/close at once.)
  return false
 end
 scannedAt=elapsed
 local found=currentController()
 if not E.valid(found) or not E.valid(found.Pawn) then
  if M.open then M.close() end
  restore();if device then device.shutdown();device=nil end;pc=nil;radial=nil;M.radial=nil
  pcPath,pcAddr,pcAnchored,pawnAddrBound=nil,nil,false,nil
  catalogueGroups=nil;unlockRefreshAt={}
  pawnSeen,pawnSince=nil,nil
  return false
 end
 -- (settle: the same pawn for SETTLE s before anything else is read or called)
 local okP,pawnAddr,pawnOnly=pcall(function() local a=found.Pawn:GetAddress();return found:GetAddress()..':'..a,a end)
 if not okP then return false end
 -- A new pawn (respawn, travel) with the same controller skips the rebind below, so
 -- the per-world catalogue cache is dropped here too.
 if pawnSeen~=pawnAddr then
  pawnSeen,pawnSince=pawnAddr,elapsed;catalogueGroups=nil;unlockRefreshAt={};if M.open then pcall(M.close) end
  if pc and pcAddr==found:GetAddress() then pawnAddrBound=pawnOnly end
  return false
 end
 if elapsed-pawnSince<SETTLE then return false end
 if E.valid(pc) and pc:GetAddress()==found:GetAddress() and E.valid(radial) then pawnAddrBound=pawnOnly;return true end
 M.close();restore();if device then device.shutdown() end;pc=found;device=inputAdapter.new(pc);radial=nil;ui=nil;nativeWasOpen=false
 rememberPc();pawnAddrBound=pawnOnly
 -- A previous world's catalogue must not be polled in the background.
 state=nil;M.state=nil;catalogueGroups=nil;unlockRefreshAt={}
 radial=liveOf('WBP_SurvivalSorcery_RadialSelector_C',true)
 M.radial=radial
 if not E.alive(radial) or not E.alive(pc) then radial=nil;M.radial=nil;return false end
 panel=nil;pcall(function() panel=radial:GetOuter():GetOuter() end)
 input=liveOf('InputManagerUIAPI',false)
 if not (E.alive(panel) and E.alive(input)) then radial=nil;M.radial=nil;return false end
 component=nil;pcall(function() component=pc:GetSpellcastingComponent() end)
 if E.valid(panel) then rememberPanel() end
 if not E.alive(component) then radial=nil;M.radial=nil;return false end
 log('bound to the world ('..SETTLE..' s after the player arrived)')
 -- Pre-hide at opacity 0 so the first native open never renders a visible frame.
 keepNativeOffscreen()
 -- Do not hide or detach the native radial during world binding. It is only
 -- suppressed in response to the spell-wheel open lifecycle.
 return true
end
 local function gameTime()
  return E.clock:GetGameTimeInSeconds(pc)
 end

-- Native cooldown sync. PlayerUtilityMagicComponent.LastCastTimeBySpellData
-- (TMap<UtilitySpellData*,float>) holds the time each spell was last cast, so
-- cooldowns started before loading in, or outside this wheel, show correctly.
-- Its clock is the world time; GameState:GetServerWorldTimeSeconds() is the
-- fallback when a stamp lies in the client's future (server-stamped casts).
-- Pending-kill aware validity (respawn, travel): skip rather than read.
function E.alive(x)
 if not E.valid(x) then return false end
 local ok,alive=pcall(function() return E.clock:IsValid(x) end)
 return ok and alive==true
end
-- The magic component is asked from the live pawn each time (GetComponentByClass,
-- a short walk of the pawn's own components), never kept as a userdata. 0.4.7:
-- no object-path lookup either (a full object walk on UE4SS 3.0.1). A FindAllOf
-- scan is the fallback if the pawn doesn't return it.
local function magicComponent()
 local pawn=pc and pc.Pawn
 if not E.alive(pawn) then return nil end
 local found
 pcall(function()
  local c=pawn:GetComponentByClass(E.class('/Script/Dominion.PlayerUtilityMagicComponent'))
  if E.alive(c) and sameObject(c:GetOwner(),pawn) then found=c end
 end)
 if not found then
  for _,c in ipairs(FindAllOf('PlayerUtilityMagicComponent') or {}) do
   if E.valid(c) and sameObject(c:GetOwner(),pawn) then found=c;break end
  end
 end
 return found
end
local function nativeCastTimes()
 local times={}
 local magic=magicComponent()
 if not magic then return times end
 pcall(function()
  magic.LastCastTimeBySpellData:ForEach(function(k,v)
   local data=k:get()
   if E.valid(data) then times[data:GetAddress()]=v:get() end
  end)
 end)
 return times
end
local function serverTime()
 local ok,t=pcall(function() return E.stats:GetGameState(pc):GetServerWorldTimeSeconds() end)
 return ok and tonumber(t) or nil
end
-- The spell's cooldown, read from its data asset (other mods may change
-- UUtilitySpellData.CooldownDuration at any time) once per wheel opening, adjusted
-- by its modifier perk. Falls back to the catalogue value. 0 means no cooldown.
local durations=setmetatable({},{__mode='k'}) -- record -> seconds, reset on open
local function liveCooldown(spell)
 local cached=spell and durations[spell]
 if cached then return cached end
 local value=spell and spell.cooldown
 local data=spell and spell.data
 if E.valid(data) then
  pcall(function()
   local base=data.CooldownDuration
   if type(base)~='number' then return end
   value=base
   if base<=0 then return end
   local perk=data.CooldownModifierPerk.CooldownPerk
   if not E.valid(perk) then return end
   local perks=E.valid(pc) and pc:GetSkillPerkComponent()
   if E.valid(perks) and perks:IsPerkUnlocked(perk) then value=data.CooldownModifierPerk.ModifiedCooldown end
  end)
 end
 local duration=cooldowns:duration({cooldown=value})
 if spell then durations[spell]=duration end
 return duration
end
M.liveCooldown=liveCooldown
function M.syncNativeCooldowns(groups,now)
 if not cfg.ShowCooldowns then cooldowns:reset();return 0 end
 local times=nativeCastTimes()
 local server=nil
 local synced=0
 for _,group in ipairs(groups or {}) do
  for _,spell in ipairs(group.spells) do
   local cast=E.valid(spell.data) and times[spell.data:GetAddress()]
   -- Without a cast time and without a timer there is nothing to update.
   local duration=(cast or cooldowns.untilById[spell.id]) and liveCooldown(spell) or 0
   -- A waived spell: the game accepted it while a cooldown was shown, so it
   -- doesn't enforce one here (a no-cooldown mod, Creative worlds).
   if duration<=0 or cooldowns:isWaived(spell) then cooldowns:clear(spell)
   elseif cast then
    local since=now-cast
    if since<-1 then server=server or serverTime();if server then since=server-cast end end
    if since>=-1 then
     cooldowns:sync(spell,now,duration-math.max(0,since));synced=synced+1
    end
   end
  end
 end
 return synced
end
-- The server tells the client how long ago a refused spell was cast. This is
-- the game's own refusal: the spell's estimates are trusted again.
-- The hook only records the notice; tick() applies it on the game thread.
M.cooldownNotices={}
if not _G.BetterSpellWheelCooldownHook then
 _G.BetterSpellWheelCooldownHook=pcall(RegisterHook,'/Script/Dominion.PlayerUtilityMagicComponent:Client_NotifySpellOnCooldown',function(_,data,since)
  local m=_G.BetterSpellWheel
  if not m or not m.cooldownNotices then return end
  pcall(function()
   local d=data:get()
   if d and d:IsValid() then m.cooldownNotices[#m.cooldownNotices+1]={address=d:GetAddress(),since=since:get()} end
  end)
 end)
end
local refusedId -- the spell the game last refused through the wheel
local function applyCooldownNotices(groups,now)
 if #M.cooldownNotices==0 then return end
 local notices=M.cooldownNotices;M.cooldownNotices={}
 for _,n in ipairs(notices) do
  for _,group in ipairs(groups or {}) do
   for _,spell in ipairs(group.spells) do
    if E.valid(spell.data) and spell.data:GetAddress()==n.address then
     cooldowns:trust(spell)
     local remaining=liveCooldown(spell)-(tonumber(n.since) or 0)
     if cfg.ShowCooldowns then cooldowns:sync(spell,now,remaining) end
     if M.open and refusedId==spell.id then
      M.message=(cfg.ShowCooldowns and remaining>.5) and 'On cooldown. Ready in '..cooldowns:format(remaining)..'.' or 'On cooldown.'
     end
    end
   end
  end
 end
end
-- Start the display timer for a cast the game accepted (never for a spell
-- whose live cooldown is 0, or one the game has shown it doesn't enforce).
local function startCooldown(spell)
 if not cfg.ShowCooldowns or not spell then return end
 local duration=liveCooldown(spell)
 if duration<=0 then cooldowns:clear(spell);return end
 cooldowns:start({id=spell.id,cooldown=duration},gameTime())
end

-- Success sound: the native selector plays its SelectSFX property from the
-- SelectedAudioTrigger event. Blank it only around SelectSlice() so successful
-- casts are silent. Failure audio uses StaminaFailedSFX (InvalidSelectAudioTrigger)
-- and is untouched. The original asset is always put back.
local mutedRadial,mutedSFX,mutedAt
local function unmuteSelectSound()
 if mutedSFX~=nil and E.valid(mutedRadial) and E.valid(mutedSFX) then
  pcall(function() mutedRadial.SelectSFX=mutedSFX end)
 end
 mutedRadial,mutedSFX,mutedAt=nil,nil,nil
end
local function muteSelectSound()
 unmuteSelectSound()
 if not E.valid(radial) then return end
 local ok,cur=pcall(function() return radial.SelectSFX end)
 if ok and E.valid(cur) then
  mutedRadial,mutedSFX,mutedAt=radial,cur,elapsed
  pcall(function() radial.SelectSFX=nil end)
 end
end

local slotWarnings=0
local function slotName(x)
 if not E.valid(x) then return 'nil' end
 local ok,n=pcall(function() return x:GetFName():ToString() end)
 return ok and n or '?'
end
-- Bind spell into native slot 0 and verify it took. If the component array does
-- not hold the spell after notify+highlight, force-write it and rebuild the slice.
local function bindSlot(spell,slot,index)
 component:Client_NotifySelectedSpell(spell.data,slot)
 radial.CachedSectionId=0;radial:HighlightSlice(0)
 if sameObject(component.SelectedSpells[index],spell.data) then return end
 if slotWarnings<5 then
  slotWarnings=slotWarnings+1
  log('slot mismatch after notify: wanted '..tostring(spell.id)..', slot holds '..slotName(component.SelectedSpells[index]))
 end
 pcall(function() component.SelectedSpells[index]=spell.data end)
 pcall(function() radial:StopRadialSelection() end)
 component:Client_NotifySelectedSpell(spell.data,slot)
 radial.CachedSectionId=0;radial:HighlightSlice(0)
 if slotWarnings<5 and not sameObject(component.SelectedSpells[index],spell.data) then
  slotWarnings=slotWarnings+1
  log('slot mismatch persists after forced write: '..tostring(spell.id))
 end
end

-- Keys read while a cast is pending (confirm / cancel), for emote hand-off and
-- for the open key: each key query is an engine call, so only these are read.
local CAST_KEYS,EMOTE_KEYS,OPEN_KEYS={'accept','mouseLeft','back','close','toggle'},{'emote'},{'open'}
local function setSpellUnlocked(group,spell,unlocked)
 unlocked=unlocked==true
 if (spell.unlocked==true)==unlocked then return end
 spell.unlocked=unlocked
 group.available=math.max(0,(group.available or 0)+(unlocked and 1 or -1))
end
-- The catalogue is scanned once per world (two FindAllOf scans; PR6). Unlocks made
-- since are picked up per hovered skill at most every 10 s, and at selection.
-- Cooldown durations are not taken from it: liveCooldown re-reads each spell's
-- data asset and perk on every open.
local function refreshGroupUnlocks(group)
 if not group or elapsed-(unlockRefreshAt[group.id] or -1e9)<10 then return end
 if not pcAlive() then return end
 local progress=pc:GetProgressComponent()
 catalogue.refresh({group},function(spell) return progress:IsSpellUnlocked(spell.data) end)
 unlockRefreshAt[group.id]=elapsed
end
local function open()
 unmuteSelectSound()
 -- This is called from the native spell-wheel open lifecycle (or its
 -- state-transition fallback). Replace only the spell selector's visuals; keep
 -- the game-owned selector object alive for spell selection/casting internals.
 -- If the native panel was rebuilt, rebind first instead of using stale widgets.
 if not panelAlive() then return end
 if perf then mark('openPanelCheck') end
 hideNativeWheel(true)
 if perf then mark('openHide') end
 openWasDown=device and device.sample(OPEN_KEYS).open==true or false
 restore()
 durations=setmetatable({},{__mode='k'}) -- read each spell's cooldown afresh
 if not catalogueGroups then
  local errors
  catalogueGroups,errors=catalogue.scan(function(_,data) return pc:GetProgressComponent():IsSpellUnlocked(data) end,pc:GetSkillPerkComponent())
  for _,group in ipairs(catalogueGroups) do unlockRefreshAt[group.id]=elapsed end
 end
 if perf then mark('openCatalogue') end
 local groups=catalogueGroups
  -- Sync cooldowns from the game's own last-cast times as the wheel opens.
  local openedAt=gameTime()
  pcall(M.syncNativeCooldowns,groups,openedAt)
  applyCooldownNotices(groups,openedAt)
  lastSync=elapsed;refusedId=nil
 if perf then mark('openCooldown') end
 state=model.new(groups);M.state=state
 pad=controller.new()
 local usingPad,style=device.device();state.input=usingPad and 'controller' or 'mouse';state.padStyle=cfg.ControllerPrompts~='auto' and cfg.ControllerPrompts or style
 controller.prime(pad,device.sample());state.controllerStage=pad.stage
 if perf then mark('openSetup') end
 -- Build the custom view after the native wheel has been suppressed.
 if not ui or not E.valid(ui.root) then ui=view.new(pc,folder,icons) end
 -- Native wheel suppression already happened at the very start of open().
 radial:StopRadialSelection()
 M.open=true;M.message=nil;M.hover=nil;M.back=false;M.queue={};M.since=elapsed
 if ui then ui.last='' end
 ui.show()
 if perf then mark('openView') end
 emoteHandoffAt=nil;emoteWheelActive=false;emoteWheelSeen=false
 emoteWasDown=device.sample(EMOTE_KEYS).emote==true
 local dpi=E.layout:GetViewportScale(pc)
 -- Start at the wheel's centre (the dead zone), so opening never pre-selects a skill.
 pc:SetMouseLocation(math.floor(ui.width/2*dpi),math.floor((ui.height/2+ui.offsetY)*dpi))
 pointerX,pointerY=ui.pointer()
 controls(true)
 if perf then mark('openInput') end
end
local function selectSpell()
 if not panelAlive() then M.close();return end
 local group=state and state.groups[state.group]
 local selected=group and state.spell and group.spells[state.spell]
 if selected then
  local unlocked=pc:GetProgressComponent():IsSpellUnlocked(selected.data)
  setSpellUnlocked(group,selected,unlocked)
 end
 local spell,reason=model.selection(state)
 if not spell then
  if reason=='locked' then M.message='This spell has not been unlocked yet.';radial:InvalidSelectAudioTrigger() end
  return
 end
 -- (model.selection returns the hovered spell checked above; anything else is checked here)
 if spell~=selected and not pc:GetProgressComponent():IsSpellUnlocked(spell.data) then M.message='This spell has not been unlocked yet.';return end
 -- The game is authoritative for cooldowns: never refuse a cast on the wheel's
 -- own estimate (other mods, e.g. UtilitySpellsNoCooldown, change the game's
 -- cast times). Always attempt it; the game refuses it if it must.
 local estimate=cooldowns:remaining(spell,gameTime())
 -- Preserve the proven 0.3.2 casting handoff: write the custom-selected spell
 -- into native slot 0, select native slice 0, then let the game's normal
 -- selector/casting path run. Mapping the custom wheel index to a native slice
 -- here reintroduced dependence on the native wheel's scroll/section state.
 local slot=radial.RadialSlice_0.SpellSlotNum
 local book=radial.SpellbookSelector.RadioGroup:GetSelectedValue()
 local index=book*component.NumSpellSlotsPerRadial+slot+1
 pending={component=component,original=component.SelectedSpells[index],spell=spell.data,spellId=spell.id,record=spell,slot=slot,index=index,book=book,since=elapsed}
 -- EUtilitySpellCastType::Instant (0) still enters SpellcastingMode for its
 -- animation. It needs no second click; Placed/Aimed/AllowMovementThenCastInstant
 -- do. Keep an unknown type conservative if the data cannot be read.
 pcall(function() pending.instant=spell.data.CastType==0 end)
 bindSlot(spell,slot,index)
 -- Keep the original ordering: release wheel input before native selection.
 controls(false)
 muteSelectSound()
 local selOk,selErr=pcall(function() radial:SelectSlice() end)
 if not selOk then unmuteSelectSound();error(selErr) end
 local requirement=radial.RequirementText:GetText():ToString()
 -- Some failed casts close the native wheel rather than leaving it open. The
 -- requirement label is the game's own reason for rejecting a spell (e.g. runes).
 local requirementFailed=requirement~='' and requirement~='-'
 if nativeOpen() or requirementFailed then
  -- The game refused the cast: its reason, with our time left if we have one.
  refusedId=spell.id
  M.message='Unable to cast. Check runes, equipment and cooldown.'
  if requirementFailed then M.message='Requires '..requirement
  else
   -- No stated reason: it may be a cooldown, so the game's cast times count again.
   cooldowns:trust(spell);pcall(M.syncNativeCooldowns,{{spells={spell}}},gameTime())
  end
  local remaining=cooldowns:remaining(spell,gameTime())
  if not requirementFailed and remaining>.5 then M.message='On cooldown. Ready in '..cooldowns:format(remaining)..'.' end
  local reqLower=requirement:lower()
  if reqLower:find('cooldown',1,true) or reqLower:find('cool down',1,true) or reqLower:find('ready in',1,true) then
   cooldowns:trust(spell)
   if remaining<=0 then startCooldown(spell) end
  end
  restore();radial:StopRadialSelection();controls(true)
 else
  -- The game accepted a spell our timer said was on cooldown: the timer was
  -- wrong (e.g. a no-cooldown mod). Drop it and stop estimating this spell.
  if estimate>.5 then cooldowns:waive(spell) end
  -- The native selection has been accepted. Close only the custom wheel and
  -- return mouse/input ownership to gameplay; keep `pending` alive so targeted
  -- spells can finish/cancel and cooldown handling can still run in tick().
  -- Do not call M.close(): it closes the native widget and would disrupt aiming.
  M.open=false
  if ui and E.valid(ui.root) then ui.hide() end
  if state then model.close(state) end
  -- Do not call controls(false) here: SelectSlice may already have entered
  -- the native SpellPlacement/Spellcasting mode, which must retain ownership.
  local mode=pc.CurrentInputMode
  local name=E.valid(mode) and mode:GetFName():ToString() or ''
  if name:find('SpellPlacement') or name:find('Spellcasting') then
   -- Aim/placement spells are only successful after the native confirm input.
   pending.awaitingConfirm=true
   local sample=device.sample(CAST_KEYS)
   pending.confirmArmed=not (sample.accept or sample.mouseLeft)
   pending.cancelArmed=not (sample.back or sample.close)
  else
   -- On the first spell use after launch, SelectSlice can return before the
   -- native targeting input mode has finished initializing. Don't classify
   -- that one early mode sample as an instant cast; let tick() observe the
   -- resulting mode before deciding whether a cooldown is warranted.
   pending.detectingMode=true
  end
  M.open=false
  model.close(state)
  if ui and E.valid(ui.root) then ui.hide() end
  showNativePanel()
  M.queue={}
 end
end
local ESCAPE,RIGHT_MOUSE -- key structs, made once on first use
local NO_ACTIONS={}
local PAD_KEYS={'accept','back','close','previous','next','up','down','left','right'}
-- After a cast through the wheel or a cooldown notice, the game's cast times are
-- followed for WATCH seconds with the wheel closed (cast completion and server
-- replies arrive after it closes). Otherwise nothing is polled while closed:
-- opening the wheel syncs from the game straight away.
local WATCH=10
local watchUntil=-1e9
local lastTickClock=os.clock()
local function tick()
 local clockNow=os.clock()
 elapsed=elapsed+math.max(0,clockNow-lastTickClock);lastTickClock=clockNow
 frame=frame+1
 if not cfg.Enabled or M.disabled then return end
 -- Bind objects without modifying visibility. The lifecycle hook below is
 -- responsible for replacing the spell selector only when the game opens it.
 local bound=bindWorld()
 if perf then mark('bind') end
 if not bound then return end
 -- The emote wheel is a separate native UI. If the player opens it while
 -- BetterSpellWheel is active, yield input ownership without resetting the
 -- game's input mode (controls(false) would force GameOnly and dismiss emotes).
 if M.open and E.valid(pc) and sameObject(pc.CurrentInputMode,pc.EmotesInputMode) then
  M.open=false
  if state then model.close(state) end
  if ui and E.valid(ui.root) then ui.hide() end
  if device then device.release(true,true) end
  M.queue={}
  return
 end
 -- Once the native open lifecycle has handed ownership to BetterSpellWheel,
 -- the native IsOpen flag is no longer authoritative: the game's input mode
 -- can clear it during takeover. Closing is handled by the replacement's own
 -- close input or by an explicit mod shutdown, not by that transient flag.
 if device.draining then device.release() end
 -- Put the select sound back shortly after the cast, in case the native audio
 -- event fires a frame or two after SelectSlice() returns.
 if mutedSFX~=nil and elapsed-(mutedAt or 0)>.3 then unmuteSelectSound() end
 if pending then
  local mode=pc.CurrentInputMode
  local name=E.valid(mode) and mode:GetFName():ToString() or ''
  local targetingMode=name:find('SpellPlacement') or name:find('Spellcasting')
  if pending.detectingMode and targetingMode then
   -- Targeting can become visible one or more frames after SelectSlice().
   pending.detectingMode=false
   pending.awaitingConfirm=true
   local initialSample=device.sample(CAST_KEYS)
   pending.confirmArmed=not (initialSample.accept or initialSample.mouseLeft)
   pending.cancelArmed=not (initialSample.back or initialSample.close)
  end
  if pending.awaitingConfirm then
   local sample=device.sample(CAST_KEYS)
   -- Native targeting can be cancelled with keyboard Escape or mouse-right
   -- as well as the controller back/close buttons. These two inputs are not
   -- part of the wheel's navigation mapping, so sample them directly here.
   -- An instant spell's animation can't be cancelled: its cast stands.
   local cancelNow=false
   if not pending.instant then
    cancelNow=sample.back or sample.close
    if not ESCAPE then pcall(function() ESCAPE,RIGHT_MOUSE={KeyName=FName('Escape')},{KeyName=FName('RightMouseButton')} end) end
    pcall(function() cancelNow=cancelNow or pc:IsInputKeyDown(ESCAPE) end)
    pcall(function() cancelNow=cancelNow or pc:IsInputKeyDown(RIGHT_MOUSE) end)
   end
   if cancelNow then
    pending.cancelled=true
   elseif not pending.cancelArmed then
    pending.cancelArmed=true
   end
   if not pending.cancelled then
    if not pending.confirmArmed then
     pending.confirmArmed=not (sample.accept or sample.mouseLeft)
    elseif sample.accept or sample.mouseLeft then
     pending.confirmed=true
     pending.confirmedAt=pending.confirmedAt or elapsed
    end
   end
  end
  if elapsed-pending.since>.15 and not targetingMode then
   -- Targeted spells only start an estimated cooldown if we observed the
   -- player's confirmation input. Leaving targeting mode alone is not proof
   -- of a successful cast: the player may have cancelled it.
   if pending.awaitingConfirm then
    if (pending.confirmed or pending.instant) and not pending.cancelled then
     startCooldown(pending.record)
    end
   elseif pending.detectingMode then
    -- No targeting mode appeared during the initialization window, so this
    -- was an instant cast. Start its cooldown after the mode has settled.
    startCooldown(pending.record)
   end
   restore()
  end
 end
 if perf then mark('pending') end
 -- Cast completion and server replies normally arrive AFTER the wheel closes.
 -- Keep consuming authoritative cooldown data without requiring another open
 -- or hover. Unconfirmed/cancelled targeting still creates no local estimate.
 if pending then watchUntil=elapsed+WATCH end
 if state then
  if M.cooldownNotices[1] then
   watchUntil=elapsed+WATCH
   applyCooldownNotices(state.groups,gameTime())
  end
  if (M.open or elapsed<watchUntil) and elapsed-lastSync>=1 then
   lastSync=elapsed
   pcall(M.syncNativeCooldowns,state.groups,gameTime())
  end
 end
 if perf then mark('cooldown') end
 if not M.open and (emoteWheelActive or emoteHandoffAt) then
  local sample=device.sample(EMOTE_KEYS)
  local t=os.clock()
  -- Switch back from the native emote wheel with a fresh X / Square press.
  -- Don't rely solely on CurrentInputMode: some builds keep reporting the prior
  -- mode while the native emote wheel is displayed. This flag is set only when
  -- BetterSpellWheel hands off to emotes, so gameplay presses remain unaffected.
  if emoteWheelActive and sample.emote and not emoteWasDown then
   emoteWasDown=true
   emoteWheelActive=false
   emoteHandoffAt=nil
   if perf then mark('closed') end
   open()
   if perf then mark('openWheel') end
   return
  end
  emoteWasDown=sample.emote==true
  -- Once the emote wheel has opened and then closed again, a later X press
  -- belongs to the game and must not bring the spell wheel back.
  if emoteWheelActive then
   if E.valid(pc) and sameObject(pc.CurrentInputMode,pc.EmotesInputMode) then emoteWheelSeen=true
   elseif emoteWheelSeen then emoteWheelActive=false;emoteWheelSeen=false end
  end
  -- A handed-over emote press: if the game did not switch to its emote mode,
  -- give gameplay input back so we never leave the UI input mode behind.
  if emoteHandoffAt then
   if E.valid(pc) and sameObject(pc.CurrentInputMode,pc.EmotesInputMode) then emoteHandoffAt=nil
   elseif t-emoteHandoffAt>.6 then emoteHandoffAt=nil;emoteWheelActive=false;controls(false) end
  end
 end
 if not M.open then
  -- Construct the retained view and warm its icons while closed, during world
  -- entry. Never move asset loads into the high-frequency hover path.
  if not pending then
   if not ui or not E.valid(ui.root) then ui=view.new(pc,folder,icons)
   elseif ui.warm then ui.warm() end
  end
  -- (Closed and not handing over to emotes: no input is sampled at all.)
  -- Native-input takeover: let the game's own Q / controller binding open the
  -- spell wheel, then replace only its radial visuals. Do not synthesize a
  -- separate Q toggle or interpret Y taps ourselves (Y may also mount).
  local isNativeOpen=nativeOpen()
  if isNativeOpen and not nativeWasOpen then
   nativeWasOpen=true
   if perf then mark('closed') end
   open()
   if perf then mark('openWheel') end
   return
  elseif not isNativeOpen and not M.open then
   nativeWasOpen=false
  end
  -- Legacy keybind dispatchers can survive UE4SS script reloads. Ignore their
  -- old 'toggle'/'open' queue entries; native state above is the only opener.
  if M.queue[1]~=nil then M.queue={} end
  if perf then mark('closed') end
  return
 end
 if not E.valid(ui.root) then M.close();return end
 local now=E.clock:GetGameTimeInSeconds(pc)
 local dt=math.min(.05,math.max(.001,now-lastTime));lastTime=now
 ui.resize()
 local x,y=ui.pointer()
 local sample=device.sample()
 -- Q is the native keyboard toggle. Once the open press has been released,
 -- a fresh Q press closes the replacement without depending on IsOpen(pc,21).
 if sample.open and not openWasDown then openWasDown=true;M.close();return end
 openWasDown=sample.open==true
 -- X / Square: hand over to the game's native emote wheel (its binding is not
 -- consumed by our input context, so it receives the press itself).
 if sample.emote and not emoteWasDown then
  emoteWasDown=true;emoteHandoffAt=os.clock();emoteWheelActive=true;emoteWheelSeen=false
  M.open=false
  if state then model.close(state) end
  if ui and E.valid(ui.root) then ui.hide() end
  if device then device.release(true,true) end
  M.queue={}
  return
 end
 emoteWasDown=sample.emote==true
 local moved=(pointerX and ((x-pointerX)^2+(y-pointerY)^2)>9) or math.abs(sample.mx or 0)>.5 or math.abs(sample.my or 0)>.5
 pointerX,pointerY=x,y
 local padActivity=sample.x*sample.x+sample.y*sample.y>=controller.deadzone^2
 for _,k in ipairs(PAD_KEYS) do if sample[k] then padActivity=true end end
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
 if hover~=M.hover then
  M.hover=hover;M.message=nil
  refreshGroupUnlocks(group)
 end
 local queue=M.queue
 if queue[1]==nil then queue=NO_ACTIONS else M.queue={} end
 for _,action in ipairs(queue) do
  if action=='toggle' or action=='close' then M.close();return
  elseif action=='back' then state.group=nil;state.spell=nil;state.candidate=nil;state.page=1;M.message=nil;M.back=true
  elseif action=='previous' then model.turnPage(state,-1)
  elseif action=='next' then model.turnPage(state,1)
  elseif action=='select' and elapsed-M.since>.15 then
   if perf then mark('input') end
   selectSpell()
   if perf then mark('select') end
   if not M.open then return end
  end
 end
 -- Game HUD activation can restore game input underneath custom UI.
 if frame%12==0 or pc.bShowMouseCursor~=(state.input~='controller') then controls(true) end
 -- The game's open animation can reset the panel: re-hide it a few times a second.
 if frame%12==0 then hideNativeWheel() end
 if perf then mark('input') end
 ui.draw(state,dt,M.message,now,cooldowns,spell)
 if perf then mark('draw') end
end
function M.shutdown()
 unmuteSelectSound()
 M.close()
 restoreNativePanel()
 M.radial=nil
 if pending and E.valid(component) then component:CancelSpellcasting() end
 restore()
 if device then device.shutdown() end
 if M.handle then CancelDelayedAction(M.handle);M.handle=nil end
end
-- Q is a mod-level toggle. Register the dispatcher once so script reloads
-- do not leave an old Q callback behind; the callback always resolves the
-- current BetterSpellWheel instance from _G.
if not _G.BetterSpellWheelKeyDispatcher then
 _G.BetterSpellWheelKeyDispatcher=true
 -- Q toggles only the custom wheel; it never opens or restores the native wheel.
 -- Q is intentionally not rebound: the game's native spell-wheel action owns it.
 RegisterKeyBind(0x1B,function() local m=_G.BetterSpellWheel;if m and m.open then m.queue[#m.queue+1]='close' end end)
 RegisterKeyBind(1,function() local m=_G.BetterSpellWheel;if m and m.open then m.queue[#m.queue+1]='select' end end)
 RegisterKeyBind(2,function() local m=_G.BetterSpellWheel;if m and m.open then m.queue[#m.queue+1]='back' end end)
 RegisterKeyBind(0x46,function() local m=_G.BetterSpellWheel;if m and m.open then m.queue[#m.queue+1]='previous' end end)
 RegisterKeyBind(0x47,function() local m=_G.BetterSpellWheel;if m and m.open then m.queue[#m.queue+1]='next' end end)
end
perfTick=function(started)
 local now=os.clock()
 local spent=now-started
 perf.ticks=perf.ticks+1;perf.total=perf.total+spent;perf.max=math.max(perf.max,spent)
 pcall(function()
  if pc and radial and pcAlive() then
   local dt=E.stats:GetWorldDeltaSeconds(pc)
   perf.frames=perf.frames+1;perf.frameSum=perf.frameSum+dt;perf.frameMax=math.max(perf.frameMax,dt)
  end
 end)
 local window=now-perf.since
 if window<1 then return end
 local parts={}
 for name,t in pairs(perf.sections) do parts[#parts+1]=string.format('%s=%.3f',name,t*1000/window) end
 table.sort(parts)
 local calls={}
 for name,n in pairs(perf.calls) do calls[#calls+1]=string.format('%s=%d',name,n) end
 table.sort(calls)
 local frame=perf.frames>0 and perf.frameSum/perf.frames or 0
 log(string.format('perf %s ticks=%d busy=%.3fms/s worst=%.3fms [%s] frame=%.2fms(%.1ffps) worstFrame=%.1fms calls[%s] heap=%.0fKB',
  M.open and 'open' or (pending and 'casting' or 'closed'),perf.ticks,perf.total*1000/window,perf.max*1000,table.concat(parts,' '),
  frame*1000,frame>0 and 1/frame or 0,perf.frameMax*1000,table.concat(calls,' '),collectgarbage('count')))
 perf.since=now;perf.ticks=0;perf.total=0;perf.max=0;perf.sections={};perf.calls={};perf.frames=0;perf.frameSum=0;perf.frameMax=0
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
M.handle=LoopInGameThreadWithDelay(1,function()
 if devPoll and frame%6==0 then pcall(devPoll) end
 if _G.BetterSpellWheel~=M then return end
 local clockNow=os.clock()
 if not M.open and not pending and clockNow-lastTickClock<.0159 then return end
 local started=perf and clockNow
 if perf then perf.last=started end
 tickId=tickId+1;inTick=true
 local ok,err=pcall(tick)
 inTick=false
 if perf then perfTick(started) end
 if not ok then
  log('Disabled after error; restoring native controls: '..tostring(err));M.disabled=true
  pcall(M.close);pcall(restoreNativePanel);pcall(restore);if device then pcall(device.shutdown) end
 end
end)
log('Loaded '..M.version..'. Open the spell wheel with your normal key (Q).')
return M
