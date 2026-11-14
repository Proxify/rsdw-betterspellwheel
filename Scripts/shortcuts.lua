-- Plain-data keyboard shortcuts. No callbacks, engine objects or extra loops.
local S={labels={'1','2','3','4','5','6','7','8','9','0','-','='},
 numbers={'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Zero','Hyphen','Equals'}}
-- Deliberately exclude movement, wheel, inventory and number-row bindings.
-- Players must choose keys unused by their own game/other-mod configuration.
local allowed={Z=true,X=true,C=true,V=true}
for i=1,8 do allowed['F'..i]=true end
function S.parse(text)
 local values={}
 for line in (text or ''):gmatch('[^\r\n]+') do
  local k,v=line:match('^%s*([%w]+)%s*=%s*([%w_]+)%s*$')
  if k then values[k]=v end
 end
 local cfg={quick=values.QuickPick=='true',slots=values.SlotHotkeys=='true',keys={},ids={},warnings={}}
 local used={}
 for i=1,8 do
  local key=(values['Slot'..i..'Key'] or 'None'):upper()
  if key~='NONE' then
   if not allowed[key] or used[key] then cfg.warnings[#cfg.warnings+1]='Ignored invalid or duplicate Slot'..i..'Key'
   else cfg.keys[i]=key;used[key]=true end
  end
  local id=values['Slot'..i..'Spell']
  if id and id:match('^USD_[%w_]+$') then cfg.ids[i]=id end
 end
 return cfg
end
function S.load(path)
 local f=io.open(path,'r')
 if not f then return S.parse('') end -- old installs and missing settings stay OFF
 local text=f:read('a');f:close()
 return S.parse(text)
end
function S.save(path,slot,id)
 if type(slot)~='number' or slot%1~=0 or slot<1 or slot>8 then return nil,'Invalid slot' end
 if id~=nil and (type(id)~='string' or not id:match('^USD_[%w_]+$')) then return nil,'Invalid spell ID' end
 local f=io.open(path,'r');if not f then return nil,'Cannot read config.txt' end
 local original=f:read('a');f:close()
 local key='Slot'..slot..'Spell'
 local lines={}
 for line in (original:gsub('\r\n','\n'):gsub('\n+$','')..'\n'):gmatch('(.-)\n') do
  if not line:match('^%s*'..key..'%s*=') then lines[#lines+1]=line end
 end
 lines[#lines+1]=key..'='..(id or 'None')
 local tmp,bak=path..'.shortcuts.tmp',path..'.shortcuts.bak'
 -- An interrupted write requires recovery, never silently overwrite its backup.
 local old=io.open(bak,'r');if old then old:close();return nil,'Recover config.txt.shortcuts.bak before saving' end
 f=io.open(tmp,'w');if not f then return nil,'Cannot write shortcut settings' end
 local ok=f:write(table.concat(lines,'\n')..'\n');local closed=f:close()
 if not ok or not closed then os.remove(tmp);return nil,'Could not finish writing settings' end
 f=io.open(path,'r');local current=f and f:read('a');if f then f:close() end
 if current~=original then os.remove(tmp);return nil,'Config changed; reload before assigning' end
 if not os.rename(path,bak) then os.remove(tmp);return nil,'Cannot back up config.txt' end
 if not os.rename(tmp,path) then
  local restored=os.rename(bak,path);os.remove(tmp)
  return nil,restored and 'Settings unchanged: replacement failed' or 'Restore config.txt.shortcuts.bak before continuing'
 end
 os.remove(bak)
 return true
end
function S.new(cfg,model)
 local s={cfg=cfg,buttons={},stage='skills',untilTime=0,primed=false}
 function s.reset(sample)
  s.buttons=sample or {};s.stage='skills';s.untilTime=0;s.primed=sample~=nil
 end
 -- Context boundaries prime held keys rather than treating them as fresh presses.
 function s.edges(sample,active)
  local edges={}
  if active and s.primed and not sample.shortcutModifier then
   for k,v in pairs(sample) do if v==true and not s.buttons[k] then edges[k]=true end end
  end
  s.buttons=sample;s.primed=true
  return edges
 end
 function s.quick(state,edges,now,yielded)
  if not cfg.quick then return end
  if yielded or now>s.untilTime then s.stage='skills' end
  state.quickStage=s.stage
  for i=1,12 do
   if edges['quick'..i] then
    if s.stage=='skills' then
     if model.setGroup(state,i) then
      state.zone='skill';s.stage='spells';s.untilTime=now+4;state.quickStage='spells'
      return 'group'
     end
    else
     local branch=model.branch(state)
     if branch and i<=branch.count then
      state.spell=branch.first+i-1;state.zone='spell';s.stage='skills';state.quickStage='skills'
      return 'select'
     end
    end
    return -- simultaneous keys never pick a group AND cast
   end
  end
 end
 function s.slot(edges)
  if cfg.slots then for i=1,8 do if cfg.keys[i] and edges['slot'..i] then return i end end end
 end
 function s.find(groups,id)
  if not id then return end
  for gi,g in ipairs(groups or {}) do for si,spell in ipairs(g.spells) do
   if spell.id==id then return gi,si end
  end end
 end
 return s
end
return S
