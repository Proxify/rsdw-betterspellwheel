-- Plain-data double-tap recast. No engine objects, callbacks or extra loops:
-- main.lua arms it when the native wheel opens and asks it on fresh presses
-- of the open button (Q, or Y / Triangle) while the wheel is open.
local R={MIN_MS=150,MAX_MS=1000,DEFAULT_MS=350}
function R.parse(text)
 local values={}
 for line in (text or ''):gmatch('[^\r\n]+') do
  local k,v=line:match('^%s*([%w]+)%s*=%s*([%w_]+)%s*$')
  if k then values[k]=v end
 end
 -- Missing or old configs stay OFF, like the keyboard shortcuts.
 local cfg={enabled=(values.DoubleTapRecast or ''):lower()=='true',window=R.DEFAULT_MS/1000,warnings={}}
 local ms=values.DoubleTapWindowMs
 if ms then
  local n=tonumber(ms)
  if not n or n%1~=0 then cfg.warnings[#cfg.warnings+1]='Ignored invalid DoubleTapWindowMs'
  else cfg.window=math.max(R.MIN_MS,math.min(R.MAX_MS,n))/1000 end
 end
 local spell=values.DoubleTapSpell
 if spell and spell:lower()~='last' then
  if spell:match('^USD_[%w_]+$') then cfg.spell=spell
  else cfg.warnings[#cfg.warnings+1]='Ignored invalid DoubleTapSpell (use Last or a USD_ spell ID)' end
 end
 return cfg
end
function R.load(path)
 local f=io.open(path,'r')
 if not f then return R.parse('') end
 local text=f:read('a');f:close()
 return R.parse(text)
end
function R.new(cfg,last)
 local r={cfg=cfg,untilTime=-1,last=last}
 -- Called only after the game's own binding opened the wheel.
 function r.arm(now) if cfg.enabled then r.untilTime=now+cfg.window end end
 function r.disarm() r.untilTime=-1 end
 -- A fresh press inside the window is the second tap. It is consumed, so a
 -- third press closes the wheel normally.
 function r.tapped(now,fresh)
  if not fresh or now>r.untilTime then return false end
  r.untilTime=-1
  return true
 end
 -- Only spells the game accepted are remembered (stable spell ID).
 function r.remember(id) if type(id)=='string' then r.last=id end end
 function r.target() return cfg.spell or r.last end
 return r
end
return R
