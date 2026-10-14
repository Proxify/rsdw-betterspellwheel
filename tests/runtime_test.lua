-- Run the real adapter against a small native-UI simulation. Native rendering and
-- spell behavior are separately checked in-game; this protects slot ownership.
local realDofile=dofile
local root=arg[1]:gsub('/Scripts/model.lua$','')
local model=realDofile(root..'/Scripts/model.lua')
local clock,book,native,aim,denied,instant=0,0,false,false,false,false
local realClock=os.clock
os.clock=function() return clock end
local x,y=0,0
local padSample,usingPad={},false
local captured=false
local function obj(id)
 return {IsValid=function() return true end,GetAddress=function()return id end,GetFName=function()return {ToString=function()return id end}end}
end
local empty={IsValid=function()return false end}
local original=obj('original');local spell=obj('spell');local newer=obj('server-update')
spell.GetModulesOfType=function()return{}end
local record={id='test',name='Test Spell',skill='Woodcutting',level=1,unlocked=true,data=spell,cooldown=0,description='Test'}
local pc=obj('pc');pc.Pawn=obj('pawn');pc.PlayerState=obj('state');pc.CurrentInputMode=obj('DIM_Gameplay')
function pc:GetSkillPerkComponent()return obj("perks")end
function pc:GetProgressComponent()return {IsSpellUnlocked=function()return record.unlocked end}end
function pc:RefreshInputMode()end
function pc:SetMouseLocation()end
local calls=0
local component=obj('component');component.SelectedSpells={};component.NumSpellSlotsPerRadial=12
for i=1,48 do component.SelectedSpells[i]=original end
function component:Client_NotifySelectedSpell(d,slot) calls=calls+1;self.SelectedSpells[book*12+slot+1]=d or empty end
function component:CancelSpellcasting()pc.CurrentInputMode=obj('DIM_Gameplay')end
function pc:GetSpellcastingComponent()return component end
local panel=obj('panel');local panelAlive,panelWrites=true,0
function panel:SetRenderOpacity()panelWrites=panelWrites+1 end;function panel:SetVisibility()panelWrites=panelWrites+1 end
function panel:SetRenderTranslation()panelWrites=panelWrites+1 end
function panel:GetClass()return {GetFName=function()return {ToString=function()return 'WBP_Spellcasting_MainPanel_C' end}end}end
function panel:GetFullName()return 'WBP_Spellcasting_MainPanel_C /Engine/Transient.Panel_0' end
local radial=obj('radial');radial.Slices={GetArrayNum=function()return 12 end};radial.RadialSlice_0={SpellSlotNum=0}
radial.SpellbookSelector={RadioGroup={GetSelectedValue=function()return book end}}
radial.RequirementText={GetText=function()return {ToString=function()return '-'end}end}
function radial:GetOuter()return {GetOuter=function()return panel end}end
function radial:StopRadialSelection()end
function radial:HighlightSlice()end
function radial:InvalidSelectAudioTrigger()end
function radial:SelectSlice()
 if denied then return end
 native=false
 if instant then return end
 pc.CurrentInputMode=obj(aim and 'DIM_SpellPlacementMode' or 'DIM_SpellcastingMode')
end
local input=obj('input');function input:IsOpen()return native end
function input:CloseWidgetIfOpen()native=false;pc.CurrentInputMode=obj('DIM_Gameplay')end
local lib=obj('lib');function lib:SetInputMode_UIOnlyEx()end;function lib:SetInputMode_GameOnly()end
function lib:SetInputMode_GameAndUIEx()end
function lib:GetGameTimeInSeconds()return clock end
function lib:GetViewportScale()return 1 end
-- Long-lived objects are re-resolved by object path (hash lookup), as in game.
local PC_PATH,MAGIC_PATH='/Game/Maps/W.W:PersistentLevel.BP_PlayerController_C_0','/Game/Maps/W.W:PersistentLevel.Char_0.Magic'
local pcAtPath -- nil: the controller itself; false: gone; or a replacement object
function pc:GetFullName()return 'BP_PlayerController_C '..PC_PATH end
local magicComponentLookups=0
function StaticFindObject(path)
 if path=='/Engine/Transient.Panel_0' then return panelAlive and panel or nil end
 if path==PC_PATH then if pcAtPath==nil then return pc end;return pcAtPath or nil end
 if path==MAGIC_PATH then return magicAtPath end
 return lib
end
function LoadAsset()return lib end
function FindFirstOf(name)if name=='BP_PlayerController_C' then return pc else return input end end
local castTimes={}
local magic=obj('magic');function magic:GetOwner()return pc.Pawn end
function magic:GetFullName()return 'PlayerUtilityMagicComponent '..MAGIC_PATH end
magicAtPath=magic
pc.Pawn.GetComponentByClass=function()magicComponentLookups=magicComponentLookups+1;return magic end
magic.LastCastTimeBySpellData={ForEach=function(_,fn)for d,t in pairs(castTimes)do fn({get=function()return d end},{get=function()return t end})end end}
function FindAllOf(name)if name=='PlayerUtilityMagicComponent' then return {magic} end;return {radial}end
local failView=false
local callback,keys
keys={};function RegisterKeyBind(key,fn)keys[key]=fn end
function LoopInGameThreadWithDelay(_,fn)callback=fn;return 1 end
function CancelDelayedAction()end
function dofile(path)
 if path:find('/input.lua',1,true)then return function()return {new=function()return {
  sample=function()local s={x=0,y=0};for k,v in pairs(padSample)do s[k]=v end;return s end, device=function()return usingPad,'xbox' end,
  capture=function()captured=true end,release=function()captured=false end,shutdown=function()captured=false end,
 }end}end end
 if path:find('/catalogue.lua',1,true)then return function()return {scan=function()return model.catalogue({record}),{}end}end end
 if path:find('/view.lua',1,true)then return function()return {new=function()
  assert(not failView,'test missing artwork')
  return {root=obj("root"),width=1920,height=1080,scale=1,offsetY=0,show=function()end,hide=function()end,resize=function()end,pointer=function()return x,y end,draw=function()end}
 end}end end
 return realDofile(path)
end
local mod=realDofile(root..'/Scripts/main.lua')
local function ticks(n)for _=1,n or 1 do clock=clock+.016;callback();assert(not mod.disabled,'adapter disabled')end end
local function open()
 native=true;x,y=0,0;ticks(4);assert(mod.open)
 x,y=0,-202;ticks(20);x,y=0,-344;ticks(2)
end
local function select()keys[1]();ticks(1)end
local function finish()pc.CurrentInputMode=obj('DIM_Gameplay');ticks(25)end
local function sameSlots(expectedIndex,expected)
 for i=1,48 do assert(component.SelectedSpells[i]==(i==expectedIndex and expected or original),'unexpected slot '..i)end
end
-- Denied cast retains the UI and all slots.
denied=true;open();select();assert(mod.open);sameSlots();keys[0x1B]();ticks();assert(not mod.open)
-- Book two uses array index 13, while the native notification takes relative 0.
denied=false;aim=true;book=1;open();select();assert(not mod.open);sameSlots(13,spell)
ticks(50);sameSlots(13,spell);finish();sameSlots()
-- Cancelling native placement restores the book, too.
open();select();component:CancelSpellcasting();ticks(25);sameSlots()
-- Empty slots round-trip correctly (including the fourth book).
book=3;component.SelectedSpells[37]=empty;open();select();sameSlots(37,spell);finish();sameSlots(37,empty)
component.SelectedSpells[37]=original
-- A newer server update wins over our saved slot.
book=0;open();select();component.SelectedSpells[1]=newer;finish();sameSlots(1,newer);component.SelectedSpells[1]=original
-- Changing books during targeting must restore the old book, not clobber the new one.
book=1;open();select();sameSlots(13,spell);book=2;finish();sameSlots();book=0
-- Locked entries and non-target areas never start a temporary selection.
record.unlocked=false;open();local before=calls;select();assert(calls==before and mod.open)
record.unlocked=true;x,y=0,0;ticks();select();assert(calls==before)
padSample={open=true};ticks();assert(not mod.open);padSample={}
-- Reload/shutdown during targeting cancels and restores before stopping.
open();select();sameSlots(1,spell);mod.shutdown();sameSlots()
-- Cooldown timers: only a confirmed aimed cast or an instant cast starts one;
-- a cancelled aim does not. The timer is display-only and never blocks a cast.
mod=realDofile(root..'/Scripts/main.lua');ticks(40)
record.cooldown=30;aim=true;book=0
local function cd()return mod.cooldowns:remaining(record,clock)end
open();select();ticks(3);component:CancelSpellcasting();ticks(25);assert(cd()==0,'cancelled aim starts no cooldown');sameSlots()
open();select();ticks(3);padSample={mouseLeft=true};ticks(2);padSample={};finish();assert(cd()>25,'confirmed aim starts cooldown');sameSlots()
mod.cooldowns:clear(record);aim=false;instant=true
open();select();ticks(25);assert(cd()>25,'instant cast starts cooldown');sameSlots()
-- Instant spells can spend their animation in SpellcastingMode, without a
-- second confirmation or a replicated cast-time entry on a joined client.
mod.cooldowns:clear(record);instant=false;spell.CastType=0
open();select();ticks(3);finish()
assert(cd()>25,'instant animation starts timer without another click or native stamp');sameSlots()
mod.cooldowns:clear(record);spell.CastType=3
open();select();ticks(3);finish()
assert(cd()==0,'movement-then-cast still requires confirmation')
spell.CastType=nil;instant=true
open();select();ticks(25)
-- The game decides: a spell the estimate shows on cooldown is still attempted.
-- When the game refuses it, the wheel stays open and says when it's ready.
denied=true;before=calls;open();select();assert(calls>before and mod.open,'the native attempt is made, not blocked by the estimate')
assert(mod.message:find('On cooldown'),'cooldown message after the game refused');assert(cd()>20,'a refusal keeps the timer');keys[0x1B]();ticks();denied=false
-- Native sync: a cast stamped in the game's LastCastTimeBySpellData (e.g. before
-- loading in) shows its remaining time when the wheel opens; expired ones clear.
mod.cooldowns:clear(record);castTimes[spell]=clock-10
open();assert(math.abs(cd()-20)<1,'synced from the native cast time');keys[0x1B]();ticks()
castTimes[spell]=clock-40;open();assert(cd()==0,'expired native cooldown is clear');keys[0x1B]();ticks()
castTimes={};instant=false;record.cooldown=0;mod.shutdown()
-- A cast may complete without a second sampled click (animation or native
-- input). The game's timestamp must reach the timer with the wheel CLOSED.
mod=realDofile(root..'/Scripts/main.lua');ticks(40)
record.cooldown=30;aim=false;instant=false
open();select();ticks(3);castTimes[spell]=clock;finish();ticks(70)
assert(not mod.open and cd()>27,'closed wheel observes completed native cast')
-- Server cooldown notices can arrive after the wheel closes, too.
mod.cooldowns:clear(record);castTimes={}
mod.cooldownNotices[#mod.cooldownNotices+1]={address='spell',since=10};ticks()
assert(not mod.open and math.abs(cd()-20)<.1,'closed wheel applies server notice')
mod.shutdown();record.cooldown=0
-- 0.4.2 (report: cooldowns shown and casts refused with UtilitySpellsNoCooldown on
-- a client). That mod rewrites LastCastTimeBySpellData to -1e9 every 500 ms, so the
-- game accepts every cast; on a joined client the map may hold no entry at all.
mod=realDofile(root..'/Scripts/main.lua');ticks(40)
record.cooldown=30;instant=true;aim=false;book=0
-- (a) No native entry (joined client): the first cast starts the estimate...
open();select();ticks(25);assert(cd()>25,'first cast starts the estimate')
-- ...but the game accepts the next cast: it must be attempted, and the estimate dropped.
before=calls;open();select();assert(calls>before and not mod.open,'game-accepted cast goes through');ticks(25)
assert(cd()==0,'accepted while the estimate ran: estimate dropped, no new timer')
open();assert(cd()==0,'still nothing shown on the next open');select();ticks(25);assert(cd()==0,'no timer on later casts');sameSlots()
-- (b) A real refusal from the game (its cooldown notice) shows the game's time again.
denied=true;open();select();assert(mod.open)
mod.cooldownNotices[#mod.cooldownNotices+1]={address='spell',since=10};ticks()
assert(math.abs(cd()-20)<1,'the notice sets the remaining time');assert(mod.message:find('On cooldown'),'notice message');keys[0x1B]();ticks();denied=false
mod.cooldowns:clear(record);open();select();ticks(25);assert(cd()>25,'after a refusal the estimate is trusted again')
-- (b2) Once waived, the game's own cast times don't bring the timer back (Creative
-- worlds and no-cooldown setups record casts but don't enforce them)...
mod.cooldowns:waive(record);castTimes[spell]=clock-1;open();assert(cd()==0,'waived: native stamp ignored');keys[0x1B]();ticks()
-- ...until the game refuses the spell: then its cast time shows again.
denied=true;open();select();assert(mod.open and cd()>25,'refusal: native time trusted again');assert(mod.message:find('On cooldown'),'refusal message with time')
keys[0x1B]();ticks();denied=false;castTimes={};mod.cooldowns:clear(record)
-- (c) Solo/host with the mod: the native stamp is rewritten to -1e9: nothing shown.
castTimes[spell]=-1e9;open();assert(cd()==0,'rewritten native stamp clears the estimate');select();assert(not mod.open);ticks(25)
castTimes={};mod.cooldowns:clear(record)
-- (d) The duration is read live from the data asset: zero (another mod) = no cooldown.
spell.CooldownDuration=0;open();select();ticks(25);assert(cd()==0,'live duration 0 starts no timer')
castTimes[spell]=clock-1;open();assert(cd()==0,'live duration 0 ignores native stamps');keys[0x1B]();ticks();castTimes={}
spell.CooldownDuration=40;open();select();ticks(25);assert(cd()>35 and cd()<=40,'live duration used, not the catalogue value')
spell.CooldownDuration=nil;mod.cooldowns:clear(record)
-- (e) ShowCooldowns=false: no timers, no cooldown text; casts still go to the game.
mod.cfg.ShowCooldowns=false;open();select();ticks(25);assert(cd()==0,'overlay off: no timer')
castTimes[spell]=clock-1;open();assert(cd()==0,'overlay off: no native sync');keys[0x1B]();ticks();castTimes={}
denied=true;open();select();mod.cooldownNotices[#mod.cooldownNotices+1]={address='spell',since=1};ticks()
assert(cd()==0 and not (mod.message or ''):find('Ready in'),'overlay off: no countdown text');keys[0x1B]();ticks();denied=false
mod.cfg.ShowCooldowns=true
castTimes={};instant=false;record.cooldown=0;mod.shutdown()
-- A destroyed native panel is never written to again (native fault, 0.4.0
-- crash dump 2026-10-12), the mod stays enabled, and a live panel is used again.
mod=realDofile(root..'/Scripts/main.lua');ticks(40)
open();assert(mod.open)
panelAlive=false;local writes=panelWrites
ticks(60);assert(panelWrites==writes,'no writes to a dead panel');assert(not mod.disabled)
select();assert(panelWrites==writes and not mod.disabled,'selecting with a dead panel is safe')
native=false;ticks(30)
panelAlive=true;native=true;ticks(30);assert(mod.open,'reopens once the panel is live again');keys[0x1B]();ticks();mod.shutdown()
-- Controller opens via native wheel, selects a skill, enters, and casts once.
mod=realDofile(root..'/Scripts/main.lua');usingPad=true;padSample={};native=true;x,y=0,0;ticks(20)
assert(mod.open and captured and mod.state.input=='controller')
padSample={x=0,y=-1};ticks(2);assert(mod.state.group==1 and not mod.state.spell)
padSample={accept=true};ticks();assert(mod.open and mod.state.spell==1)
ticks(20);sameSlots() -- a held A must not cast the highlighted first spell
padSample={};ticks();padSample={accept=true};ticks();assert(not mod.open);sameSlots(1,spell)
padSample={};finish();sameSlots()
-- B first backs out of spells, then closes; held B cannot do both.
native=true;ticks(20);padSample={x=0,y=-1};ticks();padSample={accept=true};ticks()
padSample={};ticks();padSample={back=true};ticks();assert(mod.open and not mod.state.spell)
ticks(20);assert(mod.open);padSample={};ticks();padSample={back=true};ticks();assert(not mod.open)
-- Mouse takes over only after real movement, not its stationary cached location.
padSample={};native=true;ticks(20);padSample={x=0,y=-1};ticks();padSample={};ticks()
assert(mod.state.input=='controller');x,y=0,-202;ticks(20);assert(mod.state.input=='mouse')
x,y=0,-344;ticks();select();assert(not mod.open);padSample={};finish();sameSlots()
-- Hidden-cursor handoff also works from raw MouseX without position change.
usingPad=true;padSample={};native=true;ticks(20);assert(mod.state.input=='controller')
padSample={mx=4};ticks();assert(mod.state.input=='mouse')
usingPad=false;padSample={};mod.shutdown()
-- 0.4.3 review: an instant spell's animation can't be cancelled, so a back/Esc
-- press during it does not stop its timer.
mod=realDofile(root..'/Scripts/main.lua');ticks(40)
record.cooldown=30;aim=false;instant=false;spell.CastType=0
open();select();ticks(3);padSample={back=true};ticks(2);padSample={};finish()
assert(cd()>25,'instant cast ignores cancel input');sameSlots()
spell.CastType=nil;mod.cooldowns:clear(record)
-- Perf: a closed wheel scans no objects, reads no game time and samples no input.
local counts={}
local function counted(name,fn) return function(...) counts[name]=(counts[name] or 0)+1;return fn(...) end end
local findAll,findFirst,gameTimeFn,isOpen=FindAllOf,FindFirstOf,lib.GetGameTimeInSeconds,input.IsOpen
FindAllOf=counted('FindAllOf',findAll);FindFirstOf=counted('FindFirstOf',findFirst)
lib.GetGameTimeInSeconds=counted('GetGameTimeInSeconds',gameTimeFn);input.IsOpen=counted('IsOpen',isOpen)
mod.shutdown();mod=realDofile(root..'/Scripts/main.lua');ticks(40)
open();keys[0x1B]();ticks();assert(not mod.open and mod.state)
ticks(700) -- past the post-activity cooldown watch window
counts={}
ticks(625) -- ten seconds
assert((counts.FindAllOf or 0)==0,'closed wheel: no FindAllOf')
assert((counts.FindFirstOf or 0)<=5,'closed wheel: controller re-verified at most every 2 s, got '..tostring(counts.FindFirstOf))
assert((counts.GetGameTimeInSeconds or 0)==0,'closed wheel: no game-time reads without a notice or a recent cast')
assert(counts.IsOpen==625,'closed wheel: one native open check per tick')
-- The controller is checked by path every tick: a replacement or removal at
-- that path is noticed on the next tick, not after the 2 s verification.
counts={};pcAtPath=obj('pc-replacement');ticks();assert(counts.FindFirstOf==1,'replaced controller: rescan at once')
pcAtPath=nil;ticks(130);counts={};pcAtPath=false;ticks();assert(counts.FindFirstOf==1,'controller path gone: rescan at once')
pcAtPath=nil;ticks(130)
-- ...but a notice arriving while closed is still applied, and opening syncs at once.
record.cooldown=30
mod.cooldownNotices[#mod.cooldownNotices+1]={address='spell',since=10};ticks()
assert(math.abs(cd()-20)<.1,'closed: queued notice applied')
mod.cooldowns:clear(record);castTimes[spell]=clock-5;counts={}
open();assert(math.abs(cd()-25)<1,'open syncs immediately');keys[0x1B]();ticks()
castTimes={};mod.cooldowns:clear(record);record.cooldown=0
-- The magic component comes from the pawn, then from its path; a new pawn
-- (respawn) is looked up again. No FindAllOf in either case.
counts={};magicComponentLookups=0;record.cooldown=30;aim=false;instant=true
open();select();ticks(25);keys[0x1B]();ticks(130)
assert((counts.FindAllOf or 0)==0 and magicComponentLookups<=1,'magic component resolved by the pawn, then by path')
local lookups=magicComponentLookups
local oldPawn=pc.Pawn;pc.Pawn=obj('pawn-2');pc.Pawn.GetComponentByClass=oldPawn.GetComponentByClass
open();keys[0x1B]();ticks()
assert(magicComponentLookups==lookups+1 and (counts.FindAllOf or 0)==0,'new pawn: component looked up again')
pc.Pawn=oldPawn;instant=false;record.cooldown=0;mod.cooldowns:clear(record)
-- Unbound (menu/loading): the controller scan is retried a few times a second, not per tick.
local pawn=pc.Pawn;pc.Pawn=nil;ticks(5);counts={}
ticks(125)
assert((counts.FindFirstOf or 0)<=9 and (counts.FindAllOf or 0)==0,'unbound: throttled scans, got '..tostring(counts.FindFirstOf))
pc.Pawn=pawn;ticks(40);native=true;ticks(4);assert(mod.open,'rebinds after the pawn returns');keys[0x1B]();ticks()
mod.shutdown()
FindAllOf,FindFirstOf,lib.GetGameTimeInSeconds,input.IsOpen=findAll,findFirst,gameTimeFn,isOpen
failView=true;mod=realDofile(root..'/Scripts/main.lua');native=true
for _=1,4 do clock=clock+.02;callback() end
assert(mod.disabled and native and not mod.open,'view failure must leave native wheel available')
print('PASS: native adapter denial, four-book offsets, pending aim/cancel, empty slot, concurrent update, lock, deadzone, shutdown and native fallback checks')

os.clock=realClock
