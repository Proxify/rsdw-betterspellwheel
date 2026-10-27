local root=arg[1]:gsub('/Scripts/model.lua$','')
local down,axes={},{}
local mapAdded,mapRemoved,enabled,disabled,destroyed=0,0,0,0,0
local function obj(t)t=t or {};t.IsValid=function()return true end;return t end
local pc=obj({GetInputAnalogKeyState=function(_,k)return axes[k.KeyName] or 0 end,IsInputKeyDown=function(_,k)return down[k.KeyName] or false end})
local actor=obj({EnableInput=function()enabled=enabled+1 end,DisableInput=function()disabled=disabled+1 end,K2_DestroyActor=function()destroyed=destroyed+1 end})
local mappings={}
local map=obj({MapKey=function(_,a,k)assert(a.bConsumeInput);mappings[k.KeyName]=true end})
local lastIgnore
local sub=obj({AddMappingContext=function(_,m,p,o)assert(m==map and p==1000000 and o.bForceImmediately and o.bIgnoreAllPressedKeysUntilRelease);mapAdded=mapAdded+1 end,
 RemoveMappingContext=function(_,m,o)assert(m==map);lastIgnore=o.bIgnoreAllPressedKeysUntilRelease;mapRemoved=mapRemoved+1 end})
local currentType=1
local common=obj({GetCurrentInputType=function()return currentType end,GetCurrentGamepadName=function()return {ToString=function()return 'PS5' end}end})
local oldFind,oldStatic,oldConstruct,oldFName=FindFirstOf,StaticFindObject,StaticConstructObject,FName
function FName(x)return x end
function FindFirstOf(n)return n=='CommonInputSubsystem' and common or sub end
function StaticFindObject()return obj({BeginDeferredActorSpawnFromClass=function()return actor end,FinishSpawningActor=function()return actor end})end
function StaticConstructObject(c)if c:find('InputMappingContext')then return map end;return obj()end
local E={valid=function(x)return x and x:IsValid()end,class=function(p)return p end}
local I=dofile(root..'/Scripts/input.lua')(E);local input=I.new(pc)
local pad,style=input.device();assert(pad and style=='playstation')
input.capture();input.capture();assert(enabled==1 and mapAdded==1)
-- Movement stays live while the wheel is open: no blanket actor block, and
-- the left stick, mouse and X/Square (native emote wheel) are never consumed.
assert(actor.bBlockInput==false and actor.InputPriority==1000000)
assert(mappings.Gamepad_FaceButton_Right and mappings.Gamepad_FaceButton_Top and mappings.Gamepad_Special_Right)
assert(mappings.Gamepad_RightX and mappings.Gamepad_RightY and mappings.Gamepad_Right2D,'right stick drives the wheel, not the camera')
assert(not mappings.Gamepad_LeftX and not mappings.Gamepad_LeftY and not mappings.MouseX and not mappings.Gamepad_FaceButton_Left)
-- Only the right stick navigates; a pushed left stick (walking) is ignored.
axes.Gamepad_LeftX=1;axes.Gamepad_RightX=.8;axes.Gamepad_RightY=.3
local s=input.sample();assert(s.x==.8 and s.y==.3)
-- Perf: a full sample makes 17 engine queries (the left stick isn't read),
-- a pending cast's confirm/cancel sample only the keys it reads.
local queries=0
local isDown,analogState=pc.IsInputKeyDown,pc.GetInputAnalogKeyState
pc.IsInputKeyDown=function(...)queries=queries+1;return isDown(...)end
pc.GetInputAnalogKeyState=function(...)queries=queries+1;return analogState(...)end
input.sample();assert(queries==17,'full sample queries '..queries)
queries=0;down.Gamepad_Special_Right=true;local c=input.sample({'accept','mouseLeft','back','close','toggle'})
assert(queries==5 and c.close and not c.accept,'subset sample');down.Gamepad_Special_Right=false
pc.IsInputKeyDown,pc.GetInputAnalogKeyState=isDown,analogState
-- The click/button that cast must be released and stay released 8 ticks.
down.Gamepad_FaceButton_Bottom=true;input.release();assert(input.draining and mapRemoved==0 and disabled==0)
down.Gamepad_FaceButton_Bottom=false
for _=1,7 do input.release();assert(input.draining and mapRemoved==0) end
input.release();assert(not input.draining and mapRemoved==1 and disabled==1 and lastIgnore==true)
down.LeftMouseButton=true;input.capture();input.release();assert(input.draining and mapRemoved==1)
down.LeftMouseButton=false;for _=1,8 do input.release() end;assert(mapRemoved==2)
-- Emote handoff passes the held X through to the game.
input.capture();input.release(true,true);assert(mapRemoved==3 and lastIgnore==false)
-- The drain reads only the 5 buttons it waits on (17 before), with unchanged
-- timing: each of them (Y/top counts as close) holds the handoff until it
-- has been up for 8 ticks; other held keys never did and still don't.
queries=0
pc.IsInputKeyDown=function(...)queries=queries+1;return isDown(...)end
pc.GetInputAnalogKeyState=function(...)queries=queries+1;return analogState(...)end
local removed=mapRemoved
for _,key in ipairs({'Gamepad_FaceButton_Bottom','Gamepad_FaceButton_Right','Gamepad_Special_Right','Gamepad_FaceButton_Top','LeftMouseButton'}) do
 input.capture();down[key]=true
 queries=0;for _=1,20 do input.release();assert(input.draining and mapRemoved==removed,key..' held keeps input captured') end
 assert(queries==20*5,key..' drain queries '..queries)
 down[key]=false
 for _=1,7 do input.release();assert(input.draining and mapRemoved==removed,key..' quiet ticks') end
 queries=0;input.release();assert(queries==5 and not input.draining and mapRemoved==removed+1 and lastIgnore==true,key..' released on tick 8')
 removed=mapRemoved
end
input.capture();down.Gamepad_DPad_Up=true;down.Gamepad_RightShoulder=true;axes.Gamepad_RightX=1
for _=1,8 do input.release() end;assert(mapRemoved==removed+1,'non-drain keys do not hold the handoff')
down.Gamepad_DPad_Up=false;down.Gamepad_RightShoulder=false;removed=mapRemoved
input.capture();down.Gamepad_FaceButton_Bottom=true;queries=0;input.release(true);assert(queries==0 and mapRemoved==removed+1,'forced release reads nothing')
down.Gamepad_FaceButton_Bottom=false
queries=0;input.sample();assert(queries==17,'navigation still samples all 17 keys')
pc.IsInputKeyDown,pc.GetInputAnalogKeyState=isDown,analogState
input.capture();down.Gamepad_FaceButton_Right=true;input.shutdown();assert(mapRemoved==removed+2 and destroyed==1)
-- 0.4.7: with E.localSubsystem, both local-player subsystems come from the
-- engine for this controller; no FindFirstOf/StaticFindObject (each a walk of
-- every object on pre-September-2026 UE4SS).
local scans,asked=0,{}
FindFirstOf=function()scans=scans+1;return sub end
StaticFindObject=function()scans=scans+1;return obj({BeginDeferredActorSpawnFromClass=function()return actor end,FinishSpawningActor=function()return actor end})end
local E2={valid=E.valid,class=E.class,stats=obj({BeginDeferredActorSpawnFromClass=function()return actor end,FinishSpawningActor=function()return actor end}),
 localSubsystem=function(p,path)assert(p==pc);asked[#asked+1]=path;return path:find('CommonInput',1,true) and common or sub end}
local input2=dofile(root..'/Scripts/input.lua')(E2).new(pc)
local pad2,style2=input2.device();assert(pad2 and style2=='playstation')
input2.capture();input2.shutdown()
assert(scans==0,'input subsystems without object scans, got '..scans)
assert(asked[1]=='/Script/CommonInput.CommonInputSubsystem' and asked[2]=='/Script/EnhancedInput.EnhancedInputLocalPlayerSubsystem','asked for the local player subsystems')
FindFirstOf,StaticFindObject,StaticConstructObject,FName=oldFind,oldStatic,oldConstruct,oldFName
print('PASS: raw input, right-stick-only navigation, movement passthrough, scoped mapping, B/Y interception, quiet-tick release drain (5 queries per tick), emote passthrough and forced shutdown cleanup')
