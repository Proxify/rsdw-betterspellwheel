-- Run the real adapter against a small native-UI simulation. Native rendering and
-- spell behavior are separately checked in-game; this protects slot ownership.
local realDofile=dofile
local root=arg[1]:gsub('/Scripts/model.lua$','')
local model=realDofile(root..'/Scripts/model.lua')
local clock,book,native,aim,denied=0,0,false,false,false
local x,y=0,0
local function obj(id)
 return {IsValid=function() return true end,GetAddress=function()return id end,GetFName=function()return {ToString=function()return id end}end}
end
local empty={IsValid=function()return false end}
local original=obj('original');local spell=obj('spell');local newer=obj('server-update')
spell.GetModulesOfType=function()return{}end
local record={id='test',name='Test Spell',skill='Woodcutting',level=1,unlocked=true,data=spell,cooldown=0,description='Test'}
local pc=obj('pc');pc.Pawn=obj('pawn');pc.PlayerState=obj('state');pc.CurrentInputMode=obj('DIM_Gameplay')
function pc:GetProgressComponent()return {IsSpellUnlocked=function()return record.unlocked end}end
function pc:RefreshInputMode()end
function pc:SetMouseLocation()end
local calls=0
local component=obj('component');component.SelectedSpells={};component.NumSpellSlotsPerRadial=12
for i=1,48 do component.SelectedSpells[i]=original end
function component:Client_NotifySelectedSpell(d,slot) calls=calls+1;self.SelectedSpells[book*12+slot+1]=d or empty end
function component:CancelSpellcasting()pc.CurrentInputMode=obj('DIM_Gameplay')end
function pc:GetSpellcastingComponent()return component end
local panel=obj('panel');function panel:SetRenderOpacity()end;function panel:SetVisibility()end
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
 pc.CurrentInputMode=obj(aim and 'DIM_SpellPlacementMode' or 'DIM_SpellcastingMode')
end
local input=obj('input');function input:IsOpen()return native end
function input:CloseWidgetIfOpen()native=false;pc.CurrentInputMode=obj('DIM_Gameplay')end
local lib=obj('lib');function lib:SetInputMode_UIOnlyEx()end;function lib:SetInputMode_GameOnly()end
function lib:GetGameTimeInSeconds()return clock end
function lib:GetViewportScale()return 1 end
function StaticFindObject()return lib end
function LoadAsset()return lib end
function FindFirstOf(name)if name=='BP_PlayerController_C' then return pc else return input end end
function FindAllOf()return {radial}end
local failView=false
local callback,keys
keys={};function RegisterKeyBind(key,fn)keys[key]=fn end
function LoopInGameThreadWithDelay(_,fn)callback=fn;return 1 end
function CancelDelayedAction()end
function dofile(path)
 if path:find('/catalogue.lua',1,true)then return function()return {scan=function()return model.catalogue({record}),{}end}end end
 if path:find('/view.lua',1,true)then return function()return {new=function()
  assert(not failView,'test missing artwork')
  return {root=obj('root'),width=1920,height=1080,scale=1,show=function()end,hide=function()end,resize=function()end,pointer=function()return x,y end,draw=function()end}
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
keys[0x51]();ticks();assert(not mod.open)
-- Reload/shutdown during targeting cancels and restores before stopping.
open();select();sameSlots(1,spell);mod.shutdown();sameSlots()
failView=true;mod=realDofile(root..'/Scripts/main.lua');native=true
for _=1,4 do callback() end
assert(mod.disabled and native and not mod.open,'view failure must leave native wheel available')
print('PASS: native adapter denial, four-book offsets, pending aim/cancel, empty slot, concurrent update, lock, deadzone, shutdown and native fallback checks')
