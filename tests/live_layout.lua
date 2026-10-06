-- Run in the BetterSpellWheel test console with the wheel open as TradeTester.
-- Moves the test pointer only; checks Slate text bounds and native progression.
local M=assert(BetterSpellWheel)
local pc=FindFirstOf('BP_PlayerController_C')
assert(pc:IsValid() and pc.PlayerState:GetPlayerName():ToString():lower()=='tradetester','test character required')
assert(M.open and not M.disabled and M.state.group==nil,'open a fresh wheel first')
local model=dofile(M.folder..'/Scripts/model.lua')
local layout=StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary')
local v=layout:GetViewportSize(pc);local dpi=layout:GetViewportScale(pc)
local scale=math.min(v.X/dpi/1480,v.Y/dpi/1010)*dpi
local cx,cy=v.X/2-220*scale,v.Y/2
local tasks={{name='Neutral',x=cx,y=cy}}
for g,group in ipairs(M.state.groups) do
 local a=model.skillAngle(g,#M.state.groups)
 local x,y=model.point(a,202)
 tasks[#tasks+1]={name=group.id,g=g,x=cx+x*scale,y=cy+y*scale}
 local count=#group.spells
 for s,spell in ipairs(group.spells) do
  local sa=a+math.rad(20)*(s-(count+1)/2)
  x,y=model.point(sa,344)
  tasks[#tasks+1]={name=group.id..' / '..spell.name,g=g,s=s,x=cx+x*scale,y=cy+y*scale}
 end
end
local job={index=1,move=true,lines={},errors=0,done=false}
_G.SBLayoutAudit=job
job.handle=LoopInGameThreadWithDelay(200,function()
 local task=tasks[job.index]
 if not task then
  job.done=true
  job.lines[#job.lines+1]=string.format('TOTAL: %d states, %d errors',#tasks,job.errors)
  local f=assert(io.open(M.folder..'/tests/live-layout-result.txt','w'))
  f:write(table.concat(job.lines,'\n'),'\n');f:close()
  CancelDelayedAction(job.handle);return
 end
 if job.move then pc:SetMouseLocation(math.floor(task.x),math.floor(task.y));job.move=false;return end
 local errors=M.auditLayout()
 if M.disabled or not M.open then errors[#errors+1]='wheel unavailable' end
 if M.state.group~=task.g or M.state.spell~=task.s then
  errors[#errors+1]='selection mismatch: '..tostring(M.state.group)..'/'..tostring(M.state.spell)
 end
 job.errors=job.errors+#errors
 job.lines[#job.lines+1]=task.name..': '..(#errors==0 and 'PASS' or table.concat(errors,'; '))
 job.index=job.index+1;job.move=true
end)
return 'Started '..#tasks..' states; query SBLayoutAudit.done/errors'
