local root=arg[1]:gsub('/Scripts/model.lua$','')
local down,axes={},{}
local mapAdded,mapRemoved,enabled,disabled,destroyed=0,0,0,0,0
local function obj(t)t=t or {};t.IsValid=function()return true end;return t end
local pc=obj({GetInputAnalogKeyState=function(_,k)return axes[k.KeyName] or 0 end,IsInputKeyDown=function(_,k)return down[k.KeyName] or false end})
local actor=obj({EnableInput=function()enabled=enabled+1 end,DisableInput=function()disabled=disabled+1 end,K2_DestroyActor=function()destroyed=destroyed+1 end})
local mappings={}
local map=obj({MapKey=function(_,a,k)assert(a.bConsumeInput);mappings[k.KeyName]=true end})
local sub=obj({AddMappingContext=function(_,m,p,o)assert(m==map and p==1000000 and o.bForceImmediately);mapAdded=mapAdded+1 end,
 RemoveMappingContext=function(_,m,o)assert(m==map and o.bIgnoreAllPressedKeysUntilRelease);mapRemoved=mapRemoved+1 end})
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
assert(actor.bBlockInput and actor.InputPriority==1000000)
assert(mappings.Gamepad_FaceButton_Right and mappings.Gamepad_FaceButton_Top and mappings.Gamepad_Special_Right)
assert(not mappings.Gamepad_LeftX and not mappings.Gamepad_RightY)
axes.Gamepad_RightX=.8;assert(input.sample().x==.8)
down.Gamepad_FaceButton_Bottom=true;input.release();assert(input.draining and mapRemoved==0 and disabled==0)
down.Gamepad_FaceButton_Bottom=false;input.release();assert(not input.draining and mapRemoved==1 and disabled==1)
input.capture();down.Gamepad_FaceButton_Right=true;input.shutdown();assert(mapRemoved==2 and disabled==2 and destroyed==1)
FindFirstOf,StaticFindObject,StaticConstructObject,FName=oldFind,oldStatic,oldConstruct,oldFName
print('PASS: raw input, controller prompts, scoped mapping priority, B/Y interception, release drain and forced shutdown cleanup')
