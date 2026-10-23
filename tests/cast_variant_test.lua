-- Casting handoff experiment (development only): legacy / restore-only / same-slot.
-- Runs the real adapter against a native-UI simulation like runtime_test.lua. Counts
-- are calls made on simulated objects: they prove the Lua paths, not engine timing.
local realDofile,realOpen=dofile,io.open
-- Other tests in this Lua state may have registered the key dispatcher already.
_G.BetterSpellWheelKeyDispatcher=nil;_G.BetterSpellWheelCooldownHook=nil;_G.BetterSpellWheel=nil
local root=arg[1]:gsub('/Scripts/model.lua$','')
local model=realDofile(root..'/Scripts/model.lua')
local clock,book,native,aim,denied,instant,notifyFails=0,0,false,false,false,false,false
local realClock=os.clock
os.clock=function() return clock end
local x,y=0,0
local padSample={}
local devOn=true
io.open=function(path,mode)
 if path:match('/dev%.txt$') then
  if not devOn then return nil end
  return {read=function() return '/nonexistent-bsw-dev/' end,close=function() end}
 end
 return realOpen(path,mode)
end
-- n: per-category counts of calls on the cast's objects (spell data, slots, radial methods)
local n={}
local function count(k) n[k]=(n[k] or 0)+1 end
local function obj(id,counted)
 return {IsValid=function() if counted then count('IsValid') end;return true end,
  GetAddress=function() if counted then count('GetAddress') end;return id end,
  GetFName=function()return {ToString=function()return id end}end}
end
local empty={IsValid=function()count('IsValid');return false end}
local original=obj('original',true);local spell=obj('spell',true);local other=obj('other',true);local newer=obj('server-update',true)
spell.GetModulesOfType=function()return{}end
local record={id='test',name='Test Spell',skill='Woodcutting',level=1,unlocked=true,data=spell,cooldown=0,description='Test'}
local pc=obj('pc');pc.Pawn=obj('pawn');pc.PlayerState=obj('state');pc.CurrentInputMode=obj('DIM_Gameplay')
function pc:GetSkillPerkComponent()return obj("perks")end
function pc:GetProgressComponent()return {IsSpellUnlocked=function()return record.unlocked end}end
function pc:RefreshInputMode()end
function pc:SetMouseLocation()end
local slots={}
local component=obj('component');component.NumSpellSlotsPerRadial=12
-- SelectedSpells reads/writes are counted (each is an engine array access in game).
component.SelectedSpells=setmetatable({},{__index=function(_,i)count('slotRead');return slots[i] end,
 __newindex=function(_,i,v)count('slotWrite');slots[i]=v end})
local function resetSlots() for i=1,48 do slots[i]=original end end
resetSlots()
function component:Client_NotifySelectedSpell(d,slot)
 count('notify')
 if notifyFails then notifyFails=false;return end -- the first notify silently doesn't take
 slots[book*12+slot+1]=d or empty
end
function component:CancelSpellcasting()pc.CurrentInputMode=obj('DIM_Gameplay')end
function pc:GetSpellcastingComponent()return component end
local panel=obj('panel')
function panel:SetRenderOpacity()end;function panel:SetVisibility()end;function panel:SetRenderTranslation()end
function panel:GetClass()return {GetFName=function()return {ToString=function()return 'WBP_Spellcasting_MainPanel_C' end}end}end
function panel:GetFullName()return 'WBP_Spellcasting_MainPanel_C /Engine/Transient.Panel_0' end
local radial=obj('radial');radial.Slices={GetArrayNum=function()return 12 end};radial.RadialSlice_0={SpellSlotNum=0}
radial.SpellbookSelector={RadioGroup={GetSelectedValue=function()count('bookRead');return book end}}
radial.RequirementText={GetText=function()return {ToString=function()return denied and 'Air rune' or '-' end}end}
function radial:GetOuter()return {GetOuter=function()return panel end}end
function radial:GetFullName()return 'WBP_SurvivalSorcery_RadialSelector_C /Engine/Transient.GameEngine_0.Radial_0' end
function radial:StopRadialSelection()end
local highlighted
function radial:HighlightSlice(i)count('highlight');highlighted=i end
function radial:InvalidSelectAudioTrigger()end
local selectedData -- what the native selector would cast: slot 0 of the visible book
function radial:SelectSlice()
 count('select')
 assert(highlighted==0 and radial.CachedSectionId==0,'always section/slice 0')
 selectedData=slots[book*12+radial.RadialSlice_0.SpellSlotNum+1]
 if denied then return end
 native=false
 if instant then return end
 pc.CurrentInputMode=obj(aim and 'DIM_SpellPlacementMode' or 'DIM_SpellcastingMode')
end
local input=obj('input');function input:IsOpen()return native end
function input:GetFullName()return 'InputManagerUIAPI /Engine/Transient.GameEngine_0.InputManagerUIAPI_1' end
function input:CloseWidgetIfOpen()native=false;pc.CurrentInputMode=obj('DIM_Gameplay')end
local lib=obj('lib');function lib:SetInputMode_GameOnly()end;function lib:SetInputMode_GameAndUIEx()end
function lib:GetGameTimeInSeconds()return clock end
function lib:GetViewportScale()return 1 end
local PC_PATH='/Game/Maps/W.W:PersistentLevel.BP_PlayerController_C_0'
function pc:GetFullName()return 'BP_PlayerController_C '..PC_PATH end
function StaticFindObject(path)
 if path=='/Engine/Transient.Panel_0' then return panel end
 if path==PC_PATH then return pc end
 return lib
end
function LoadAsset()return lib end
function FindFirstOf(name)if name=='BP_PlayerController_C' then return pc else return input end end
local magic=obj('magic');function magic:GetOwner()return pc.Pawn end
function magic:GetFullName()return 'PlayerUtilityMagicComponent /x' end
magic.LastCastTimeBySpellData={ForEach=function()end}
pc.Pawn.GetComponentByClass=function()return magic end
function FindAllOf(name)if name=='PlayerUtilityMagicComponent' then return {magic} end;if name=='InputManagerUIAPI' then return {input} end;return {radial}end
local callback,keys,keyBinds,hooks,views={},{},0,0,0
function RegisterKeyBind(key,fn)keyBinds=keyBinds+1;keys[key]=fn end
function RegisterHook()hooks=hooks+1 end
function LoopInGameThreadWithDelay(_,fn)callback=fn;return 1 end
function CancelDelayedAction()end
function dofile(path)
 if path:find('/input.lua',1,true)then return function()return {new=function()return {
  sample=function()local s={x=0,y=0};for k,v in pairs(padSample)do s[k]=v end;return s end, device=function()return false,'xbox' end,
  capture=function()end,release=function()end,shutdown=function()end,
 }end}end end
 if path:find('/catalogue.lua',1,true)then return function()return {scan=function()return model.catalogue({record}),{}end,
  refresh=function(groups,isUnlocked) -- as catalogue.refresh (hover unlock refresh, PR6 port)
   for _,group in ipairs(groups)do group.available=0
    for _,r in ipairs(group.spells)do r.unlocked=isUnlocked(r)==true;if r.unlocked then group.available=group.available+1 end end end
   return groups end}end end
 if path:find('/view.lua',1,true)then return function()return {new=function()
  views=views+1
  return {root=obj("root"),width=1920,height=1080,scale=1,offsetY=0,show=function()end,hide=function()end,resize=function()end,pointer=function()return x,y end,draw=function()end}
 end}end end
 return realDofile(path)
end
local mod
local function ticks(k)for _=1,k or 1 do clock=clock+.016;callback();assert(not mod.disabled,'adapter disabled')end end
local function load(dev)
 if mod then mod.shutdown() end
 devOn=dev;mod=realDofile(root..'/Scripts/main.lua');ticks(340);return mod
end
local function open() native=true;x,y=0,0;ticks(4);assert(mod.open);x,y=0,-202;ticks(20);x,y=0,-344;ticks(2) end
local function finish() pc.CurrentInputMode=obj('DIM_Gameplay');ticks(25) end
-- One cast; returns the counts for the select key press through the end of the cast.
local function cast(how)
 open();n={}
 keys[1]();ticks(1)
 assert(selectedData==spell,'the native selector casts the chosen spell')
 if how=='cancel' then ticks(3);padSample={back=true};ticks(2);padSample={};component:CancelSpellcasting();ticks(25)
 elseif how=='confirm' then ticks(3);padSample={mouseLeft=true};ticks(2);padSample={};finish()
 elseif how~='refused' then finish() end
 local counts=n;n={};return counts
end
local function last() local r=mod.castDev.receipts();return r[#r] end
local function slotsAre(expect) for i=1,48 do assert(slots[i]==(expect[i] or original),'unexpected slot '..i) end end
local function set(v) local ok,why=mod.castDev.set(v);assert(ok,why) end

-- Gating: without dev.txt there is no experiment API and casts use the legacy path.
load(false);assert(mod.castDev==nil,'no castDev without dev.txt')
instant=true;slots[1]=spell
local c=cast();assert(c.notify==2,'release build: legacy notify+restore even when slot 0 already holds the spell')
resetSlots()
local function line(label,k) local t=0;for _,v in pairs(k) do t=t+v end
 return string.format('%-35s notify=%d highlight=%d slotRead=%d slotWrite=%d bookRead=%d IsValid=%d GetAddress=%d total=%d',label,
  k.notify or 0,k.highlight or 0,k.slotRead or 0,k.slotWrite or 0,k.bookRead or 0,k.IsValid or 0,k.GetAddress or 0,t) end
local m=cast()
local releaseLines={line('release (no dev.txt) hit',c),line('release (no dev.txt) miss',m)}
assert((c.IsValid or 0)==9 and (c.GetAddress or 0)==6 and (m.IsValid or 0)==9 and (m.GetAddress or 0)==6,'release: no slot-0 eligibility compare')
print('PASS: cast experiment is absent without dev.txt; release default is the legacy handoff')

-- Exact offline call counts per variant and path (simulation; not timing).
local summary={}
local function measure(variant,label,prep,expectPath,expectWarm)
 resetSlots();prep()
 local before={};for i=1,48 do before[i]=slots[i] end
 local counts=cast()
 local r=last()
 assert(r.variant==variant and r.path==expectPath and r.warm==expectWarm and r.status=='finished',
  variant..' '..label..': got '..tostring(r.path)..' warm='..tostring(r.warm)..' '..tostring(r.status))
 assert(r.notifies==(counts.notify or 0),'receipt counts the whole cast (bind and restore)')
 slotsAre(before)
 local total=0;for _,v in pairs(counts) do total=total+v end
 summary[#summary+1]=string.format('%-12s %-22s path=%-12s notify=%d highlight=%d slotRead=%d slotWrite=%d bookRead=%d IsValid=%d GetAddress=%d total=%d',
  variant,label,expectPath,counts.notify or 0,counts.highlight or 0,counts.slotRead or 0,counts.slotWrite or 0,counts.bookRead or 0,counts.IsValid or 0,counts.GetAddress or 0,total)
 return counts,r
end
local hit=function() slots[1]=spell end
local miss=function() end
local results={}
for _,variant in ipairs({'legacy','restore-only','same-slot'}) do
 load(true);set(variant);book=0;instant=true
 local warmPath=variant=='same-slot' and 'reuse' or (variant=='restore-only' and 'skip-restore' or 'legacy')
 local coldPath=variant=='same-slot' and 'cold' or warmPath
 results[variant]={
  coldHit=measure(variant,'hit, first cast',hit,coldPath,false),
  warmHit=measure(variant,'hit, warmed',hit,warmPath,true),
  miss=measure(variant,'miss',miss,'legacy',true),
 }
 notifyFails=true;results[variant].retry=measure(variant,'miss, notify ignored',miss,'legacy',true)
end
local L,R,S=results.legacy,results['restore-only'],results['same-slot']
assert(L.warmHit.notify==2 and R.warmHit.notify==1 and (S.warmHit.notify or 0)==0,'hit notifies legacy2/restore-only1/same-slot0')
assert(S.coldHit.notify==2,'same-slot first handoff is the full legacy one')
assert(L.miss.notify==2 and R.miss.notify==2 and S.miss.notify==2,'misses: legacy notify+restore in every variant')
assert(L.retry.notify==3 and R.retry.notify==3 and S.retry.notify==3,'ignored notify: forced write, second notify, restore')
assert((S.warmHit.highlight or 0)==1,'same-slot reuse keeps HighlightSlice(0)')
print('Offline per-cast counts (simulated objects, select key through cast end):')
for _,l in ipairs(releaseLines) do print('  '..l) end
for _,line in ipairs(summary) do print('  '..line) end
print('PASS: hit notifies legacy2/restore-only1/same-slot0 (warm), cold and miss fall back to legacy (2), ignored notify retries (3)')

-- Every book: hits and misses keep all 48 assignments; the selector casts the chosen spell.
for _,variant in ipairs({'legacy','restore-only','same-slot'}) do
 load(true);set(variant);instant=true
 for b=0,3 do
  book=b
  for _=1,2 do -- second cast on the book is warm
   resetSlots();slots[b*12+1]=spell;cast();slotsAre({[b*12+1]=spell})
   resetSlots();cast();slotsAre({})
  end
 end
 book=0
end
print('PASS: all four books, hits and misses, every variant: assignments unchanged, chosen spell cast')

-- Pending semantics with reuse: cancel, confirm, refusal, closed cooldown, newer update.
load(true);set('same-slot');book=0;instant=false;aim=true;record.cooldown=30
local function cd() return mod.cooldowns:remaining(record,clock) end
resetSlots();slots[1]=spell;cast();assert(last().path=='cold')
cast('cancel');assert(last().path=='reuse' and last().cancelled and cd()==0,'reused cancelled aim: no cooldown');slotsAre({[1]=spell})
cast('confirm');assert(last().path=='reuse' and last().confirmed and cd()>25,'reused confirmed aim starts cooldown');slotsAre({[1]=spell})
mod.cooldowns:clear(record)
-- closed wheel: cooldown notice after the reuse cast closes
mod.cooldownNotices[#mod.cooldownNotices+1]={address='spell',since=10};ticks();assert(math.abs(cd()-20)<.1,'closed: notice applied')
mod.cooldowns:clear(record)
-- refusal keeps the wheel open, is a complete 'refused' receipt, writes nothing
denied=true;cast('refused');assert(mod.open and last().status=='refused' and last().path=='reuse');keys[0x1B]();ticks();denied=false
slotsAre({[1]=spell})
-- a newer server update during a reused pending cast is kept
open();keys[1]();ticks(1);assert(last().path=='reuse');slots[1]=newer;finish();slotsAre({[1]=newer})
-- restore-only: the same
set('restore-only');resetSlots();slots[1]=spell
open();keys[1]();ticks(1);assert(last().path=='skip-restore');slots[1]=newer;finish();slotsAre({[1]=newer})
-- legacy: also keeps it (existing behavior)
set('legacy');resetSlots();open();keys[1]();ticks(1);slots[1]=newer;finish();slotsAre({[1]=newer})
record.cooldown=0;aim=false;instant=true
print('PASS: reuse/skip-restore keep cancel, confirm cooldown, refusal, closed notices and newer server updates')

-- Warm guard: first cast, book change at select, book change seen at open, during pending,
-- rebind and reload all fall back to the full handoff.
load(true);set('same-slot');resetSlots();slots[1]=spell;slots[13]=spell;book=0
cast();assert(last().path=='cold','first cast after load')
cast();assert(last().path=='reuse')
book=1;cast();assert(last().path=='cold','book changed at select')
book=0;cast();assert(last().path=='cold','back to book 0: re-warm')
cast();assert(last().path=='reuse')
book=2;open();keys[0x1B]();ticks();book=0 -- an open on another book, no cast
cast();assert(last().path=='cold','book change seen at an open drops the warm state')
cast();assert(last().path=='reuse')
open();keys[1]();ticks(1);assert(last().path=='reuse');book=1;finish();book=0 -- book change during a reused pending cast
slotsAre({[1]=spell,[13]=spell})
cast();assert(last().path=='cold','book change seen when the cast ends drops the warm state; nothing written')
cast();assert(last().path=='reuse')
cast();assert(last().path=='reuse')
local pawn=pc.Pawn;pc.Pawn=obj('pawn-2');pc.Pawn.GetComponentByClass=pawn.GetComponentByClass;ticks(340)
cast();assert(last().path=='cold','new pawn (respawn) drops the warm state')
cast();assert(last().path=='reuse')
pc.Pawn=nil;ticks(20);pc.Pawn=pawn;ticks(340)
cast();assert(last().path=='cold','unbind/rebind drops the warm state')
load(true);assert(mod.castDev.status().variant=='legacy','reload starts at legacy');set('same-slot')
cast();assert(last().path=='cold','reload drops the warm state')
-- Per-open cost of the same-slot open-time book check (only while warm); none for other variants.
for _,variant in ipairs({'legacy','restore-only','same-slot'}) do
 set(variant);book=0;resetSlots();cast();n={};open();local reads=n.bookRead or 0;keys[0x1B]();ticks()
 assert(reads==(variant=='same-slot' and 1 or 0),variant..' open-time book reads '..reads)
end
print('PASS: warm guard resets on load, book change at select, open or cast end, new pawn, rebind and reload; a pending book change writes nothing')

-- Empty/invalid slot-0 entries are misses (never GetAddress on them); a slot-0 widget
-- with a non-zero SpellSlotNum uses that relative slot; a held click doesn't confirm.
for _,variant in ipairs({'restore-only','same-slot'}) do
 load(true);set(variant);book=1;instant=true;resetSlots()
 slots[13]=empty;cast();cast();assert(last().path=='legacy' and not last().eligible);slotsAre({[13]=empty})
 radial.RadialSlice_0.SpellSlotNum=5;resetSlots();slots[18]=spell
 cast();assert(last().path==(variant=='same-slot' and 'cold' or 'skip-restore'),'slot 0 maps to a new relative slot: full handoff first')
 cast();assert(last().index==18 and last().eligible and last().path==(variant=='same-slot' and 'reuse' or 'skip-restore'),'relative slot 5 of book 1')
 slotsAre({[18]=spell})
 radial.RadialSlice_0.SpellSlotNum=0;book=0;resetSlots()
end
load(true);set('same-slot');resetSlots();slots[1]=spell;instant=false;aim=true;record.cooldown=30;cast()
open();padSample={mouseLeft=true};keys[1]();ticks(3);assert(last().path=='reuse')
padSample={};ticks(2);assert(mod.cooldowns:remaining(record,clock)==0,'held click is not a confirmation')
padSample={mouseLeft=true};ticks(2);padSample={};finish();assert(last().confirmed and mod.cooldowns:remaining(record,clock)>25,'fresh click confirms')
mod.cooldowns:clear(record);record.cooldown=0;aim=false;instant=true;resetSlots()
print('PASS: empty/invalid slot 0 is a miss; non-zero relative slot index; held click needs release before confirm (reuse)')
-- Measurement off: same paths and notifies, no receipts, no clocks, no diagnostic compare.
local missLines={}
do
 local expect={legacy={hit=2,miss=2},['restore-only']={hit=1,miss=2},['same-slot']={hit=0,miss=2}}
 local compares={legacy={hit=0,miss=0},['restore-only']={hit=2,miss=2},['same-slot']={hit=2,miss=2}} -- IsValid beyond the release 9
 for _,variant in ipairs({'legacy','restore-only','same-slot'}) do
  load(true);set(variant);book=0;instant=true;resetSlots();slots[1]=spell;cast() -- warm
  assert(mod.castDev.measure(false));local casts=mod.castDev.status().casts
  local h=cast();resetSlots();local m=cast()
  assert(mod.castDev.status().casts==casts,'measurement off: no receipts')
  assert((h.notify or 0)==expect[variant].hit and (m.notify or 0)==expect[variant].miss,variant..' same notifies with measurement off')
  assert((m.IsValid or 0)==9+compares[variant].miss and (m.GetAddress or 0)==6+compares[variant].miss,variant..' miss: release counts plus only the in-path compare')
  missLines[#missLines+1]=line(variant..' measure off, hit',h);missLines[#missLines+1]=line(variant..' measure off, miss',m)
  assert(mod.castDev.measure(true));resetSlots();slots[1]=spell;cast()
  assert(mod.castDev.status().casts==casts+1,'measurement on again: receipts resume')
 end
 instant=false;aim=true;open();keys[1]();ticks(1)
 assert(not mod.castDev.measure(false),'measure switch refused while pending');finish();aim=false;instant=true
end
for _,l in ipairs(missLines) do print('  '..l) end
print('PASS: measurement off keeps each variant\'s path and notifies, records no receipts and no legacy diagnostic compare; on resumes')
-- Variant changes: refused while open, pending, unbound, retired or disabled; never rebuild UI or hooks.
load(true);local v0,k0,h0=views,keyBinds,hooks
open();assert(not mod.castDev.set('restore-only'),'refused while open');keys[0x1B]();ticks()
instant=false;aim=true;open();keys[1]();ticks(1)
local ok,why=mod.castDev.set('restore-only');assert(not ok and why:find('pending'),why)
local refusedMid=mod.castDev.reset();assert(not refusedMid,'reset refused while pending')
finish();aim=false;instant=true
assert(not mod.castDev.set('bogus'))
set('restore-only');set('same-slot');set('legacy')
assert(views==v0 and keyBinds==k0 and hooks==h0,'variant change rebuilds no view and registers no binds/hooks')
local st=mod.castDev.status();assert(st.busy=='idle' and st.refusals==4,'refusals counted: '..tostring(st.refusals))
pawn=pc.Pawn;pc.Pawn=nil;ticks(20);ok,why=mod.castDev.set('same-slot');assert(not ok,'refused while unbound');pc.Pawn=pawn;ticks(340)
local old=mod;load(true);ok,why=old.castDev.set('same-slot');assert(not ok and why:find('retired'),why)
mod.disabled=true;ok,why=mod.castDev.set('same-slot');assert(not ok and why:find('disabled'),why);mod.disabled=false
print('PASS: variant switch refused while open/pending/unbound/retired/disabled; no UI rebuild or new hooks')

-- Receipts: shutdown mid-cast is 'aborted'; the ring is bounded at 256; CSV export.
load(true);set('same-slot');resetSlots();aim=true;instant=false
open();keys[1]();ticks(1);mod.shutdown();assert(mod.castDev.receipts()[1].status=='aborted','shutdown: aborted, not a sample')
assert(mod.castDev.receipts()[1].notifies==2,'aborted cast still counts its restore')
load(true);aim=false;instant=true
for _=1,300 do cast() end
st=mod.castDev.status();local rs=mod.castDev.receipts()
assert(#rs==256 and st.overflow==44 and rs[1].seq==45 and rs[256].seq==300,'ring bounded at 256')
local csv=mod.castDev.csv();local rows=0;for _ in csv:gmatch('[^\n]+') do rows=rows+1 end
assert(rows==257,'header + 256 rows')
assert(csv:match('^seq,variant,spell,book,index,warm,eligible,eligibilityInPath,path,status,complete,'),'csv header')
assert(csv:find('\n300,legacy,test,0,1,1,0,0,legacy,finished,1,',1,true),'csv row')
assert(mod.castDev.report():find('clock=lua os.clock casts=300 overflow=44',1,true))
assert(mod.castDev.reset() and mod.castDev.status().casts==0)
print('PASS: aborted receipts are not samples; ring bounded at 256 with overflow count; CSV and summary export')
mod.shutdown()
io.open=realOpen;os.clock=realClock;dofile=realDofile
