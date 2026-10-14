-- Radial-only view for BetterSpellWheel.
return function(E, model, L)
 local R={}
 local GOLD={R=.86,G=.73,B=.46,A=1}
 local MUTED={R=.56,G=.63,B=.65,A=1}
 local RED={R=.92,G=.32,B=.30,A=1}
 local WHITE={R=.92,G=.92,B=.85,A=1}
 local ENOUGH={R=.25,G=.88,B=.38,A=1}
 local INSUFFICIENT={R=1.0,G=.24,B=.22,A=1}

 function R.new(pc,folder,icons)
  local u={pc=pc,skills={},spells={},textures={},last=''}
  u.root=E.create(pc,'/Game/UI/Panels/WBP_Panel.WBP_Panel_C')
  local tree=u.root.WidgetTree
  local function widget(name) return StaticConstructObject(E.class('/Script/UMG.'..name),tree) end
  local rootCanvas=widget('CanvasPanel');tree.RootWidget=rootCanvas

  local function place(parent,w,b,z)
   local s=parent:AddChildToCanvas(w)
   s:SetPosition({X=b.x,Y=b.y});s:SetSize({X=b.w,Y=b.h});s:SetZOrder(z or 0)
   return s
  end

  u.canvas=widget('CanvasPanel')
  local cs=rootCanvas:AddChildToCanvas(u.canvas)
  cs:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}})
  cs:SetAlignment({X=.5,Y=.5})
  cs:SetSize({X=L.width,Y=L.height})
  u.canvas:SetRenderTransformPivot({X=.5,Y=.5})
  u.canvasSlot=cs;u.offsetY=0

  -- Transparent, hit-testable full-screen shield. Add it AFTER the artwork
  -- canvas and give it the highest Z order: equal-Z siblings can be hit-tested
  -- in reverse insertion order, which made the earlier shield unreliable.
  -- Wheel selection is polled from raw input, so the shield need not forward
  -- clicks to individual icons; it only prevents the game/native UI receiving them.
  local dim=widget('Image')
  dim:SetColorAndOpacity({R=0,G=0,B=0,A=0})
  dim:SetVisibility(0) -- Visible: hit-testable; alpha remains fully transparent.
  local ds=rootCanvas:AddChildToCanvas(dim)
  ds:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
  ds:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
  ds:SetZOrder(100000)
  u.clickShield=dim

  local function img(texture,b,z)
   local im=widget('Image');im:SetVisibility(3)
   if E.valid(texture) then im:SetBrushFromTexture(texture,false) end
   place(u.canvas,im,b,z)
   return im
  end

  local fonts={}
  local function text(value,b,size,style,color,center,wrap)
   if not fonts[style] then
    local donor=StaticConstructObject(E.class('/Game/UI/Common/WBP_DomTextBlock.WBP_DomTextBlock_C'),tree)
    donor:SetStyle(E.class('/Game/UI/Styles/Texts/CUIS_'..style..'.CUIS_'..style..'_C'))
    fonts[style]=donor
   end
   local tb=widget('TextBlock')
   local f=fonts[style].Font;f.Size=size;f.LetterSpacing=0;tb:SetFont(f)
   tb.WrapTextAt=wrap and b.w or 0;tb:SetAutoWrapText(wrap==true)
   tb:SetText(FText(value));tb:SetColorAndOpacity({SpecifiedColor=color or MUTED,ColorUseRule=0})
   tb:SetJustification(center and 1 or 0);tb:SetClipping(1);tb:SetVisibility(3)
   place(u.canvas,tb,b,20)
   return tb
  end

  local function set(tb,value,color)
   tb:SetText(FText(value))
   if color then tb:SetColorAndOpacity({SpecifiedColor=color,ColorUseRule=0}) end
  end

  -- Lua UObject wrappers do not keep textures alive through Unreal GC. Each
  -- cached texture also belongs to a hidden UMG brush retained by this tree.
  -- Otherwise revisiting a branch can synchronously reload its icons.
  u.texturePins={}
  function u.texture(path)
   if not path or path=='' then return nil end
   if not E.valid(u.textures[path]) then
    local texture=E.asset(path)
    u.textures[path]=texture
    if E.valid(texture) then
     local pin=u.texturePins[path]
     if not pin then
      pin=widget('Image');pin:SetVisibility(2)
      rootCanvas:AddChildToCanvas(pin);u.texturePins[path]=pin
     end
     pin:SetBrushFromTexture(texture,false)
    end
   end
   return u.textures[path]
  end

  for _,n in ipairs({'skill','skill_active','spell','spell_active','center','tooltip'}) do
   local t=E.render:ImportFileAsTexture2D(pc,folder..'/Assets/'..n..'.png')
   assert(E.valid(t),'missing ring artwork: '..n)
   u.textures[n]=t
  end

  -- 1440x960 design space, with the radial exactly centered at (720,480).
  local ring={x=296,y=56,w=848,h=848}

  for i,g in ipairs(model.skills) do
   local a=model.skillAngle(i,#model.skills)
   local base=img(u.textures.skill,ring)
   base:SetRenderTransformAngle(math.deg(a))
   local hi=img(u.textures.skill_active,ring)
   hi:SetRenderTransformAngle(math.deg(a));hi:SetRenderOpacity(0)
   local icon=img(u.texture(icons.skills[g.id]),L.icon(model,a,model.geometry.skillRadius,64),10)
   u.skills[i]={highlight=hi,icon=icon,alpha=0}
  end

  for i=1,model.geometry.maxBranch do
   local b=img(u.textures.spell,ring)
   local h=img(u.textures.spell_active,ring)
   local icon=img(nil,{x=0,y=0,w=64,h=64},10)
   local number=text(tostring(i),{x=0,y=0,w=22,h=28},12,'DescriptionTextStyle',MUTED,true,false)
   -- Cooldown strings can be longer than the slot number (e.g. '1m 02s').
   -- Give them their own smaller, wider centred label so the normal index stays crisp.
   local cooldownText=text('',{x=0,y=0,w=64,h=26},12,'DescriptionTextStyle',RED,true,false)
   u.spells[i]={base=b,highlight=h,icon=icon,number=number,cooldownText=cooldownText,alpha=0,
    -- What each widget currently shows, so draw() only calls the engine on change.
    widgets={b,h,icon,number,cooldownText},shown={2,2,2,2,2},want={},numberColor=MUTED,cooldownLabel=''}
   for _,w in ipairs({b,h,icon,number,cooldownText}) do w:SetVisibility(2) end
  end

  img(u.textures.center,ring)

  -- Native-style spell detail panel in the centre of the radial.
  -- Costs are read from the selected UtilitySpellData, so modified rune costs
  -- (including Spell Sliders) are reflected without a second hard-coded table.
  u.detailTitle=text('',{x=520,y=408,w=400,h=30},14,'DescriptionTextStyle',WHITE,true,false)
  u.detailTitle.Slot:SetPosition({X=520,Y=408});u.detailTitle.Slot:SetSize({X=400,Y=30})
  u.detailTitle:SetVisibility(2)
  -- The skill name belongs in the exact centre of the inner wheel, not on
  -- any outer-ring slice. Visibility is controlled in u.draw: only show it
  -- while a spell/inner-ring target is selected.
  u.detailSkill=text('',{x=520,y=464,w=400,h=32},14,'DescriptionTextStyle',WHITE,true,false)
  u.detailSkill.Slot:SetPosition({X=520,Y=464});u.detailSkill.Slot:SetSize({X=400,Y=32})
  u.detailSkill:SetVisibility(2)
  u.costIcons={}
  u.costCounts={}
  u.costFallbacks={}
  u.costNames={}
  u.costEntries={}
  u.costColors={}
  u.inventoryCountCacheAt=0
  for i=1,4 do
   local icon=img(nil,{x=0,y=0,w=34,h=34},30)
   -- Rune name is its own compact label above the icon. Do not print raw UObject
   -- fallback strings in the icon area when the game's icon field is unavailable.
   local fallback=text('',{x=0,y=0,w=46,h=22},7,'DescriptionTextStyle',WHITE,true,false)
   local name=text('',{x=0,y=0,w=62,h=18},7,'DescriptionTextStyle',WHITE,true,false)
   local count=text('',{x=0,y=0,w=42,h=20},12,'DescriptionTextStyle',GOLD,true,false)
   icon:SetVisibility(2);fallback:SetVisibility(2);name:SetVisibility(2);count:SetVisibility(2)
   u.costIcons[i]=icon;u.costFallbacks[i]=fallback;u.costNames[i]=name;u.costCounts[i]=count
  end
  u.requirementsLabel=text('Requirements:',{x=560,y=453,w=320,h=24},13,'DescriptionTextStyle',WHITE,true,false)
  u.requirementsLabel.Slot:SetPosition({X=560,Y=453});u.requirementsLabel.Slot:SetSize({X=320,Y=24})
  u.requirementsLabel:SetVisibility(2)
  -- Optional tool requirement, shown between the heading and rune costs.
  u.toolRequirement=text('',{x=560,y=477,w=320,h=18},10,'DescriptionTextStyle',INSUFFICIENT,true,false)
  u.toolRequirement.Slot:SetPosition({X=560,Y=477});u.toolRequirement.Slot:SetSize({X=320,Y=18})
  u.toolRequirement:SetVisibility(2)

  -- Tooltip bar under the wheel: spell description (what it does).
  -- Tooltip bar artwork: Assets/tooltip.png (780x96 design space).
  u.tipParts={img(u.textures.tooltip,L.tooltip,5)}
  u.tipText=text('',L.tipText,11,'DescriptionTextStyle',WHITE,true,false)
  u.tipAlpha=0;u.tipHas=false;u.tipShown=false
  u.tipAll={u.tipText}
  for _,w in ipairs(u.tipParts) do u.tipAll[#u.tipAll+1]=w end
  for _,w in ipairs(u.tipAll) do w:SetVisibility(2);w:SetRenderOpacity(0) end

  u.root:SetVisibility(2)
  u.root:AddToViewport(9000)

  function u.resize(force)
   local checkAt=os.clock()
   if not force and checkAt-(u.resizeCheckedAt or 0)<.5 then return end
   u.resizeCheckedAt=checkAt
   local v=E.layout:GetViewportSize(pc)
   local dpi=E.layout:GetViewportScale(pc)
   local width,height=v.X/dpi,v.Y/dpi
   local scale=math.min(width/1480,height/1010)
   local changed=width~=u.width or height~=u.height or scale~=u.scale
   u.width,u.height=width,height
   if changed then
    u.scale=scale;u.tipFits={};u.tipFitCount=0
    u.canvas:SetRenderScale({X=scale,Y=scale})
    local off=L.shiftY*scale
    if off~=u.offsetY then u.offsetY=off;u.canvasSlot:SetPosition({X=0,Y=off}) end
   end
  end

  function u.pointer()
   local m=E.layout:GetMousePositionOnViewport(pc)
   return (m.X-u.width/2)/u.scale+L.width/2-L.cx,
          (m.Y-u.height/2-u.offsetY)/u.scale+L.height/2-L.cy
  end

  function u.hide()
   u.root:SetVisibility(2);u.last=''
  end

  -- Warm one icon at a time during world entry, before the player opens the
  -- wheel. The brush pins keep this bounded set resident for the view lifetime.
  local warmPaths={}
  for _,path in pairs(icons.spells) do warmPaths[#warmPaths+1]=path end
  table.sort(warmPaths)
  local warmIndex=1
  function u.warm()
   local path=warmPaths[warmIndex]
   if not path then return true end
   u.texture(path);warmIndex=warmIndex+1
   return warmIndex>#warmPaths
  end

  function u.show()
   u.resize(true);u.root:SetVisibility(3);u.root:SetRenderOpacity(1)
   u.fade=1;u.appliedFade=nil;u.last='';u.branchKey='';u.appliedBranchFade=nil;u.tipAlpha=0;u.tipAppliedAlpha=nil;u.lastSkillLabel=nil;u.lastSkillVisibility=nil;u.detailSkillAppliedOpacity=nil
   u.inventories=nil;u.inventoryCountCacheAt=0
   -- Spell costs, tool text and rune icons are read once per opening.
   -- Measured text fits remain valid across openings; resize invalidates them.
   u.details={}
  end

  local function readField(obj,key)
   local ok,value=pcall(function() return obj[key] end)
   return ok and value or nil
  end

  local function resolveItemIcon(item)
   if not E.valid(item) then return nil end
   -- Rune ItemData assets expose Icon as a soft asset reference. In some UE4SS
   -- builds the soft reference's Get()/ToString() isn't usable, even though the
   -- ItemData object has a stable name such as ITEM_Rune_Law. Try the native
   -- icon convention from the game's ItemData JSON as a fallback.
   local function tryTexture(path)
    if not path or path=='' then return nil end
    local texture=u.texture(path)
    if E.valid(texture) then return texture end
    return nil
   end
   local function runeIconFromName(name)
    if type(name)~='string' or name=='' then return nil end
    name=name:gsub('^.*[%.%/]','')
    local rune=name:match('ITEM_Rune_(%w+)') or name:match('[Rr]une[_%s](%w+)')
    if not rune then return nil end
    local asset='T_Icon_Rune_'..rune
    return tryTexture('/Game/Art/UI/Icons/Resources_ConceptArt/'..asset..'.'..asset)
   end
   -- First use the actual Icon field whenever it can be resolved.
   for _,field in ipairs({'Icon','ItemIcon','IconTexture','InventoryIcon','SmallIcon','Texture','IconAsset'}) do
    local value=readField(item,field)
    if value~=nil then
     local valueValid=false
     local okValid,resultValid=pcall(function() return E.valid(value) end)
     valueValid=okValid and resultValid==true
     if valueValid then return value end
     for _,method in ipairs({'Get','get'}) do
      local ok,result=pcall(function() return value[method](value) end)
      local resultValid=false
      if ok then
       local okCheck,check=pcall(function() return E.valid(result) end)
       resultValid=okCheck and check==true
      end
      if resultValid then return result end
     end
     local path=nil
     local okPath,result=pcall(function() return value:ToString() end)
     if okPath then path=result end
     if not path or path=='' then
      local okName,name=pcall(function() return value:GetPathName() end)
      if okName then path=name end
     end
     if path and path~='' then
      path=path:gsub('^%s+',''):gsub('%s+$','')
      if path:sub(1,1)=='/' then
       local texture=u.texture(path)
       if E.valid(texture) then return texture end
      end
     end
    end
   end
   -- Fall back to the documented Rune icon asset convention. Prefer object
   -- identity/name over localized display text so this works across languages.
   local candidates={}
   pcall(function() candidates[#candidates+1]=item:GetFName():ToString() end)
   pcall(function() candidates[#candidates+1]=item:GetName() end)
   pcall(function() candidates[#candidates+1]=item.InternalName:ToString() end)
   for _,name in ipairs(candidates) do
    local texture=runeIconFromName(name)
    if E.valid(texture) then return texture end
    -- InternalName commonly uses res_rune_law rather than ITEM_Rune_Law.
    local rune=name:match('res_rune_(%w+)')
    if rune then
     local asset='T_Icon_Rune_'..rune:gsub('^(%w)',string.upper)
     texture=tryTexture('/Game/Art/UI/Icons/Resources_ConceptArt/'..asset..'.'..asset)
     if E.valid(texture) then return texture end
    end
   end
   return nil
  end

  -- Query only this player's inventories. A world-wide FindAllOf on first
  -- hover scales with every chest/NPC; reading UItem stacks also creates
  -- avoidable wrappers and risks stale stack objects during inventory updates.
  local function playerRuneCounts(items)
   local result={}
   if not E.valid(u.pc) then return result end
   local owners={u.pc}
   local pawn=u.pc.Pawn
   if E.valid(pawn) then owners[#owners+1]=pawn end
   if not u.inventories then
    u.inventories={}
    local seen={}
    local class=E.class('/Script/Dominion.InventoryComponent')
    for _,owner in ipairs(owners) do
     local ok,refs=pcall(function() return owner:K2_GetComponentsByClass(class) end)
     if ok and type(refs)=='table' then
      for _,ref in ipairs(refs) do
       local inv=ref:get()
       if E.valid(inv) then
        local addr=inv:GetAddress()
        if not seen[addr] then seen[addr]=true;u.inventories[#u.inventories+1]=inv end
       end
      end
     end
    end
   end
   for i,item in ipairs(items) do
    if E.valid(item) then
     local total,known=0,false
     for _,inv in ipairs(u.inventories) do
      if E.valid(inv) then
       local ok,n=pcall(function() return inv:GetNumItemsByData(item) end)
       if ok and type(n)=='number' and n>=0 then total=total+n;known=true end
      end
     end
     if known then result[i]=total end
    end
   end
   return result
  end

  local function updateRuneCountColours(force)
   local now=os.clock()
   if not force and now-(u.inventoryCountCacheAt or 0)<1.0 then return end
   u.inventoryCountCacheAt=now
   local entries=u.costEntries or {}
   if #entries==0 then return end
   local items={}
   for i,e in ipairs(entries) do items[i]=e.item end
   local counts=playerRuneCounts(items)
   for i,e in ipairs(entries) do
    local available=counts[i]
    -- Unknown inventory state shows white.
    local color=available==nil and WHITE or (available>=e.count and ENOUGH or INSUFFICIENT)
    if u.costColors[i]~=color then
     u.costColors[i]=color
     set(u.costCounts[i],tostring(e.count),color)
    end
   end
  end

  local function tooltipFor(spell)
   local d=tostring(spell.description or '')
   d=d:gsub('<[^>]*>',''):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
   local level=tonumber(spell.level)
   if spell.unlocked~=true and level then
    d='Requires '..tostring(spell.skill or '')..' level '..level..'. '..d
   end
   return d
  end

  -- Wrap the tooltip ourselves, then fit it inside L.tipText (the frame drawn by
  -- the bar's inner border): start at size 14 and step down until the measured
  -- text fits both width and height. Short text stays on one centred line.
  local function wrapText(tip,maxChars)
   local lines,cur={},''
   for word in tip:gmatch('%S+') do
    if cur=='' then cur=word
    elseif #cur+1+#word<=maxChars then cur=cur..' '..word
    else lines[#lines+1]=cur;cur=word end
   end
   if cur~='' then lines[#lines+1]=cur end
   return lines
  end

  -- Measuring needs a layout prepass per candidate size; the outcome for a given
  -- text is remembered (until the viewport scale changes) and simply re-applied.
  u.tipFits={}
  local function layoutTip(tip,color)
   local box=L.tipText
   local fit=u.tipFits[tip]
   if fit then
    pcall(function()
     local font=u.tipText.Font;font.Size=fit.size;u.tipText:SetFont(font)
    end)
    set(u.tipText,fit.text,color or WHITE)
    u.tipText.Slot:SetSize({X=box.w,Y=fit.height})
    u.tipText.Slot:SetPosition({X=box.x,Y=box.y+(box.h-fit.height)/2})
    return
   end
   local height=box.h
   local chosen,chosenText,measured
   for _,size in ipairs({14,13,12,11,10,9,8}) do
    local lines=wrapText(tip,math.max(10,math.floor(box.w/(size*.85))))
    pcall(function()
     local font=u.tipText.Font;font.Size=size;u.tipText:SetFont(font)
    end)
    chosen,chosenText=size,table.concat(lines,'\n')
    set(u.tipText,chosenText,color or WHITE)
    pcall(function() u.tipText:ForceLayoutPrepass() end)
    local ok,s=pcall(function() return u.tipText:GetDesiredSize() end)
    local w,h=0,#lines*size*1.6 -- estimate if measuring is unavailable
    measured=ok and s and tonumber(s.Y) and tonumber(s.Y)>0
    if measured then w,h=tonumber(s.X),tonumber(s.Y) end
    height=h
    if w<=box.w and h<=box.h then break end
   end
   height=math.min(height+4,box.h)
   if measured then
    -- Refusal strings can contain changing cooldown values; bound this cache.
    if (u.tipFitCount or 0)>=128 then u.tipFits={};u.tipFitCount=0 end
    u.tipFits[tip]={size=chosen,text=chosenText,height=height}
    u.tipFitCount=(u.tipFitCount or 0)+1
   end
   u.tipText.Slot:SetSize({X=box.w,Y=height})
   u.tipText.Slot:SetPosition({X=box.x,Y=box.y+(box.h-height)/2})
  end

  local function drawDetails(spell)
   local hasSpell=spell~=nil
   u.tipHas=false
   u.detailTitle:SetVisibility(hasSpell and 3 or 2)
   u.requirementsLabel:SetVisibility(hasSpell and 3 or 2)
   u.toolRequirement:SetVisibility(2);u.toolShown=false
   u.requirementsLabel.Slot:SetPosition({X=560,Y=453})
   u.toolRequirement.Slot:SetPosition({X=560,Y=477})
   u.costEntries={}
   for i=1,4 do
    u.costIcons[i]:SetVisibility(2);u.costFallbacks[i]:SetVisibility(2);u.costNames[i]:SetVisibility(2);u.costCounts[i]:SetVisibility(2)
   end
   if not hasSpell then return end
   local title=tostring(spell.name or spell.id or '')
   set(u.detailTitle,title,WHITE)
   local titleSize=14
   if #title>25 then titleSize=8
   elseif #title>20 then titleSize=9
   elseif #title>16 then titleSize=11 end
   pcall(function()
    local font=u.detailTitle.Font
    font.Size=titleSize
    u.detailTitle:SetFont(font)
   end)
   local tip=tooltipFor(spell)
   if tip~='' then layoutTip(tip);u.tipHas=true end
   local skillName=tostring(spell.skill or '')
   set(u.detailSkill,skillName,MUTED)
   -- Skill-label visibility is handled in u.draw (cached by state.zone).
   pcall(function()
    local font=u.detailSkill.Font
    font.Size=10
    u.detailSkill:SetFont(font)
   end)
   local cached=u.details and u.details[spell]
   if not cached then
   local entries={}
   local ok=pcall(function()
    for _,moduleRef in ipairs(spell.data:GetModulesOfType(E.class('/Script/Dominion.SpellModule_CostItems'))) do
     local module=moduleRef:get()
     if E.valid(module) then
      module.ItemsCostInfo:ForEach(function(_,entryRef)
       local entry=entryRef:get()
       if entry and E.valid(entry.ItemData) then
        entries[#entries+1]={item=entry.ItemData,count=tonumber(entry.Count) or tonumber(tostring(entry.Count)) or 0}
       end
      end)
     end
    end
   end)
   if not ok then entries={} end
   -- The game stores the requirement as text on the spell data
   -- (e.g. 'Pickaxe', 'Fishing Rod', 'Logging Axe').
   local toolLabel=''
   pcall(function() toolLabel=spell.data.SpecialRequirementsText:ToString() end)
   toolLabel=tostring(toolLabel or ''):gsub('<[^>]*>',''):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$',''):gsub('%.$','')
   cached={entries=entries,toolLabel=toolLabel}
   if u.details then u.details[spell]=cached end
   end
   local entries,toolLabel=cached.entries,cached.toolLabel
   if toolLabel~='' then
    set(u.toolRequirement,toolLabel,WHITE)
    u.toolRequirement:SetVisibility(3)
    -- Move the heading up to make room for the tool line beneath it.
    u.requirementsLabel.Slot:SetPosition({X=560,Y=427})
    u.toolRequirement.Slot:SetPosition({X=560,Y=459})
    u.toolShown=true
   else u.toolShown=false end
   local count=math.min(#entries,4)
   if count>0 then
    local gap=72
    -- x is the centre of each rune column, so the whole row is centred on
    -- the same (720,480) point as the radial wheel for any rune count.
    local startX=L.cx-((count-1)*gap)/2
    for i=1,count do
     local e=entries[i]
     local x=startX+(i-1)*gap
     local itemName=e.name
     if not itemName then
      itemName='Rune'
      pcall(function() itemName=e.item.Name:ToString() end)
      itemName=tostring(itemName):gsub('^.*[/%.]',''):gsub('_',' ')
      itemName=itemName:gsub('^USD ',''):gsub('^Item ','')
      e.name=itemName
     end
     local nameText=u.costNames[i]
     local rowOffset=u.toolShown and 22 or 0
     nameText.Slot:SetPosition({X=x-34,Y=479+rowOffset});nameText.Slot:SetSize({X=68,Y=18})
     set(nameText,itemName,WHITE);nameText:SetVisibility(3)
     local icon=u.costIcons[i]
     icon.Slot:SetPosition({X=x-17,Y=498+rowOffset});icon.Slot:SetSize({X=34,Y=34})
     local texture=e.texture
     if texture==nil or (texture and not E.valid(texture)) then texture=resolveItemIcon(e.item) or false;e.texture=texture end
     if texture and E.valid(texture) then
      icon:SetBrushFromTexture(texture,false);icon:SetVisibility(3)
     else
      -- Keep the rune name above the slot; never render opaque UObject text.
      icon:SetVisibility(2)
      local fallback=u.costFallbacks[i]
      fallback.Slot:SetPosition({X=x-23,Y=500+rowOffset});fallback.Slot:SetSize({X=46,Y=22})
      set(fallback,'•',WHITE);fallback:SetVisibility(3)
     end
     local countText=u.costCounts[i]
     countText.Slot:SetPosition({X=x-21,Y=534+rowOffset});countText.Slot:SetSize({X=42,Y=20})
     u.costEntries[i]=e
     set(countText,tostring(e.count),WHITE);countText:SetVisibility(3);u.costColors[i]=WHITE
    end
   end
  end

  function u.draw(state,dt,message,now,cooldowns,selectedSpell)
   local fade=1
   if fade>=.995 then fade=1 end
   u.fade=fade
   if fade~=u.appliedFade then
    u.appliedFade=fade
    u.root:SetRenderOpacity(fade)
    if u.detailTitle:GetVisibility()==3 then u.detailTitle:SetRenderOpacity(fade) end
    if u.detailSkill:GetVisibility()==3 then u.detailSkill:SetRenderOpacity(fade);u.detailSkillAppliedOpacity=fade end
    if u.requirementsLabel:GetVisibility()==3 then u.requirementsLabel:SetRenderOpacity(fade) end
    if u.toolRequirement:GetVisibility()==3 then u.toolRequirement:SetRenderOpacity(fade) end
    for i=1,4 do
     if u.costIcons[i]:GetVisibility()==3 then u.costIcons[i]:SetRenderOpacity(fade) end
     if u.costFallbacks[i]:GetVisibility()==3 then u.costFallbacks[i]:SetRenderOpacity(fade) end
     if u.costNames[i]:GetVisibility()==3 then u.costNames[i]:SetRenderOpacity(fade) end
     if u.costCounts[i]:GetVisibility()==3 then u.costCounts[i]:SetRenderOpacity(fade) end
    end
   end

   local group=state.groups[state.group]
   for i,n in ipairs(u.skills) do
    local target=i==state.group and 1 or 0
    n.alpha=target
    if n.appliedAlpha~=n.alpha then n.highlight:SetRenderOpacity(n.alpha);n.appliedAlpha=n.alpha end
    local iconAlpha=(not group or i==state.group) and 1 or .65
    if n.iconAlpha~=iconAlpha then n.icon:SetRenderOpacity(iconAlpha);n.iconAlpha=iconAlpha end
   end

   local branchKey=tostring(state.group)..':'..state.page
   if branchKey~=u.branchKey then u.branchKey=branchKey;u.branchFade=0;u.appliedBranchFade=nil end
   local branchFade=1
   if branchFade>=.995 then branchFade=1 end
   u.branchFade=branchFade

   local detailKey=selectedSpell and (tostring(selectedSpell.id)..':'..tostring(selectedSpell.name)..':'..tostring(selectedSpell.skill)) or 'none'
   -- A refusal (on cooldown, missing runes or tool) replaces the description in
   -- the tooltip bar, in red, until the pointer moves to another target.
   local messageKey=detailKey..'|'..tostring(message)
   if detailKey~=u.detailKey or messageKey~=u.messageKey then
    u.detailKey=detailKey;u.messageKey=messageKey
    drawDetails(selectedSpell)
    if message and message~='' then layoutTip(message,RED);u.tipHas=true end
   end
   local tipTarget=u.tipHas and 1 or 0
   u.tipAlpha=tipTarget
   local ta=u.tipAlpha<.02 and 0 or u.tipAlpha
   local shown=ta>0
   if shown~=u.tipShown then
    u.tipShown=shown
    for _,w in ipairs(u.tipAll) do w:SetVisibility(shown and 3 or 2) end
   end
   if shown and (not u.tipAppliedAlpha or math.abs(ta-u.tipAppliedAlpha)>.005) then
    u.tipAppliedAlpha=ta
    for _,w in ipairs(u.tipAll) do w:SetRenderOpacity(ta) end
   elseif not shown then u.tipAppliedAlpha=0 end

   -- Show the current skill name in the centre while navigating the OUTER
   -- skill ring. Once the player moves into the inner spell ring, hide it so
   -- the centre is reserved for the spell details. Do not alter outer-ring
   -- slice labels or spell names.
   local activeGroup=state.group and state.groups[state.group] or nil
   local skillName=activeGroup and tostring(activeGroup.label or activeGroup.id or '') or ''
   local showSkill=state.zone=='skill' and activeGroup~=nil and skillName~=''
   if showSkill and u.lastSkillLabel~=skillName then
    set(u.detailSkill,skillName,MUTED)
    u.lastSkillLabel=skillName
   end
   local skillVisibility=showSkill and 3 or 2
   if u.lastSkillVisibility~=skillVisibility then
    u.detailSkill:SetVisibility(skillVisibility)
    u.lastSkillVisibility=skillVisibility
   end
   if showSkill and u.detailSkillAppliedOpacity~=u.fade then
    u.detailSkill:SetRenderOpacity(u.fade)
    u.detailSkillAppliedOpacity=u.fade
   end
   updateRuneCountColours(false)

   local cooldownTick=math.ceil(tonumber(now) or 0)
   local key=branchKey..':'..tostring(state.spell)..':'..tostring(message)..':'..tostring(cooldownTick)
   if key~=u.last then
    u.last=key
    local b=model.branch(state)

    for i,n in ipairs(u.spells) do
     local visible=b and i<=b.count
     local cooldown=false
     if visible then
      local d=group.spells[b.first+i-1]
      local a=b.center-b.span/2+b.step*(i-.5)
      if n.angle~=a then
       n.angle=a
       n.base:SetRenderTransformAngle(math.deg(a))
       n.highlight:SetRenderTransformAngle(math.deg(a))
       local iconBox=L.icon(model,a,model.geometry.spellRadius,64)
       n.icon.Slot:SetPosition({X=iconBox.x,Y=iconBox.y})
       local x,y=model.point(a,385)
       n.number.Slot:SetPosition({X=L.cx+x-11,Y=L.cy+y-14})
       n.cooldownText.Slot:SetPosition({X=L.cx+x-32,Y=L.cy+y-13})
       n.cooldownText.Slot:SetSize({X=64,Y=26})
      end
      n.active=state.spell==b.first+i-1
      n.unlocked=d.unlocked

      local t=u.texture(icons.spells[d.id]) or u.texture(icons.skills[group.id])
      if E.valid(t) and not rawequal(t,n.texture) then n.texture=t;n.icon:SetBrushFromTexture(t,false) end
      local remaining=cooldowns and cooldowns:remaining(d,now) or 0
      cooldown=remaining>0
      local color=n.active and GOLD or MUTED
      if n.numberColor~=color then n.numberColor=color;set(n.number,tostring(i),color) end
      if cooldown then
       local label=cooldowns:format(remaining)
       if n.cooldownLabel~=label then n.cooldownLabel=label;set(n.cooldownText,label,RED) end
      end
     end
     n.cooldown=cooldown
     -- Same final visibility as before: hidden slots hide all five widgets; a
     -- slot on cooldown shows its timer in place of its number.
     local v=visible and 3 or 2
     local want=n.want
     want[1],want[2],want[3]=v,v,v
     want[4]=visible and (cooldown and 2 or 3) or 2
     want[5]=visible and (cooldown and 3 or 2) or 2
     for k,w in ipairs(n.widgets) do
      if n.shown[k]~=want[k] then n.shown[k]=want[k];w:SetVisibility(want[k]) end
     end
    end
   end

   if u.appliedBranchFade~=branchFade then
    u.appliedBranchFade=branchFade
    for _,n in ipairs(u.spells) do
     n.base:SetRenderOpacity(branchFade)
     n.number:SetRenderOpacity(branchFade)
     n.cooldownText:SetRenderOpacity(branchFade)
     n.icon:SetRenderOpacity(branchFade*(n.unlocked and 1 or .3))
    end
   end
   for _,n in ipairs(u.spells) do
    local target=n.active and 1 or 0
    n.alpha=target
    local highlightAlpha=n.alpha*branchFade
    if n.appliedHighlightAlpha~=highlightAlpha then
     n.highlight:SetRenderOpacity(highlightAlpha)
     n.appliedHighlightAlpha=highlightAlpha
    end
   end
  end

  return u
 end
 return R
end