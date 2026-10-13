-- Reusable, measured UMG layout. No widget is detached after creation.
return function(E, model, L)
 local R={}
 local GOLD={R=.86,G=.73,B=.46,A=1}
 local MUTED={R=.56,G=.63,B=.65,A=1}
 local WHITE={R=.92,G=.92,B=.85,A=1}
 local RED={R=.95,G=.49,B=.42,A=1}
 function R.new(pc,folder,icons)
  local u={pc=pc,skills={},spells={},rows={},textures={},last='',fitCache={},textNodes={}}
  u.root=E.create(pc,'/Game/UI/Panels/WBP_Panel.WBP_Panel_C')
  local tree=u.root.WidgetTree
  local function widget(name) return StaticConstructObject(E.class('/Script/UMG.'..name),tree) end
  local rootCanvas=widget('CanvasPanel');tree.RootWidget=rootCanvas
  local function place(parent,w,b,z)
   local s=parent:AddChildToCanvas(w);s:SetPosition({X=b.x,Y=b.y});s:SetSize({X=b.w,Y=b.h});s:SetZOrder(z or 0);return s
  end
  local dim=widget('Image');dim:SetColorAndOpacity({R=.012,G=.022,B=.028,A=.96})
  local ds=rootCanvas:AddChildToCanvas(dim)
  ds:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}});ds:SetOffsets({Left=0,Top=0,Right=0,Bottom=0});dim:SetVisibility(2)
  u.canvas=widget('CanvasPanel')
  local cs=rootCanvas:AddChildToCanvas(u.canvas)
  cs:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}});cs:SetAlignment({X=.5,Y=.5});cs:SetSize({X=L.width,Y=L.height})
  u.canvas:SetRenderTransformPivot({X=.5,Y=.5})
  local function img(texture,b,z)
   local im=widget('Image');im:SetVisibility(3)
   if E.valid(texture) then im:SetBrushFromTexture(texture,false) end
   place(u.canvas,im,b,z);return im
  end
  local fonts={}
  local function text(value,b,size,style,color,center,wrap,id)
   if not fonts[style] then
    local donor=StaticConstructObject(E.class('/Game/UI/Common/WBP_DomTextBlock.WBP_DomTextBlock_C'),tree)
    donor:SetStyle(E.class('/Game/UI/Styles/Texts/CUIS_'..style..'.CUIS_'..style..'_C'));fonts[style]=donor
   end
   local tb=widget('TextBlock')
   local f=fonts[style].Font;f.Size=size;f.LetterSpacing=0;tb:SetFont(f)
   tb.WrapTextAt=wrap and b.w or 0;tb:SetAutoWrapText(wrap==true)
   tb:SetText(FText(value));tb:SetColorAndOpacity({SpecifiedColor=color or MUTED,ColorUseRule=0})
   tb:SetJustification(center and 1 or 0);tb:SetClipping(1);tb:SetVisibility(3)
   place(u.canvas,tb,b,20)
   u.textNodes[#u.textNodes+1]={widget=tb,box=b,id=id or value}
   return tb
  end
  local function set(tb,value,color)
   tb:SetText(FText(value))
   if color then tb:SetColorAndOpacity({SpecifiedColor=color,ColorUseRule=0}) end
  end
  local function fit(tb,value,b,size,minimum,color)
   set(tb,value,color)
   local cacheKey=tostring(value)..'|'..tostring(b.w)..'|'..tostring(b.h)..'|'..tostring(size)..'|'..tostring(minimum or size)
   local cached=u.fitCache[cacheKey]
   if cached then
    local f=tb.Font;f.Size=cached;tb:SetFont(f)
    return
   end
   -- Measure once. The old decrementing loop could force several Slate
   -- layout passes for every title and description when changing skills.
   -- Scale from the measured bounds instead of synchronously remeasuring at
   -- every candidate font size.
   local f=tb.Font;f.Size=size;tb:SetFont(f);tb:ForceLayoutPrepass()
   local d=tb:GetDesiredSize();local fitted=size
   if d.X>b.w+.5 and d.X>0 then fitted=math.floor(size*b.w/d.X) end
   if d.Y>b.h+.5 and d.Y>0 then fitted=math.min(fitted,math.floor(size*b.h/d.Y)) end
   u.fitCache[cacheKey]=math.max(minimum or size,math.min(size,fitted))
   f=tb.Font;f.Size=u.fitCache[cacheKey];tb:SetFont(f)
  end
  function u.texture(path)
   if not path or path=='' then return nil end
   if not E.valid(u.textures[path]) then u.textures[path]=E.asset(path) end
   return u.textures[path]
  end
  for _,n in ipairs({'skill','skill_active','spell','spell_active','center'}) do
   local t=E.render:ImportFileAsTexture2D(pc,folder..'/Assets/'..n..'.png')
   assert(E.valid(t),'missing ring artwork: '..n);u.textures[n]=t
  end
  text('BETTER SPELL WHEEL',{x=962,y=8,w=396,h=58},22,'PlayerListTitleTextStyle',GOLD,true,false,'brand')
  text('CHOOSE A SKILL.  FOLLOW ITS MAGIC.',{x=962,y=72,w=396,h=26},10,'DescriptionTextStyle',MUTED,true,false,'tagline')
    local ring={x=296,y=56,w=848,h=848}
  for i,g in ipairs(model.skills) do
   local a=model.skillAngle(i,#model.skills)
   local base=img(u.textures.skill,ring);base:SetRenderTransformAngle(math.deg(a))
   local hi=img(u.textures.skill_active,ring);hi:SetRenderTransformAngle(math.deg(a));hi:SetRenderOpacity(0)
   local icon=img(u.texture(icons.skills[g.id]),L.icon(model,a,model.geometry.skillRadius,64),10)
   u.skills[i]={highlight=hi,icon=icon,alpha=0}
  end
  for i=1,model.geometry.maxBranch do
   local b=img(u.textures.spell,ring);local h=img(u.textures.spell_active,ring)
   local icon=img(nil,{x=0,y=0,w=64,h=64},10)
    local number=text(tostring(i),{x=0,y=0,w=72,h=28},12,'DescriptionTextStyle',MUTED,true,false,'wheel number '..i)
   u.spells[i]={base=b,highlight=h,icon=icon,number=number,alpha=0}
   for _,w in ipairs({b,h,icon,number}) do w:SetVisibility(2) end
  end
  img(u.textures.center,ring)
  u.centerIcon=img(nil,{x=472,y=398,w=56,h=56},10);u.centerIcon:SetVisibility(2)
  -- A small diamond gives controller users a direct, visible target without
  -- introducing a mouse cursor into the normal mouse flow.
  u.cursor=widget('Border');u.cursor:SetBrushColor({R=GOLD.R,G=GOLD.G,B=GOLD.B,A=.95})
  u.cursorSlot=place(u.canvas,u.cursor,{x=0,y=0,w=22,h=22},30)
  u.cursor:SetRenderTransformPivot({X=.5,Y=.5});u.cursor:SetRenderTransformAngle(45)
  u.cursorCore=widget('Border');u.cursorCore:SetBrushColor({R=.06,G=.04,B=.025,A=1})
  u.cursorCoreSlot=place(u.canvas,u.cursorCore,{x=0,y=0,w=8,h=8},31)
  u.cursorCore:SetRenderTransformPivot({X=.5,Y=.5});u.cursorCore:SetRenderTransformAngle(45)
  u.cursor:SetVisibility(2);u.cursorCore:SetVisibility(2)
  local centerTitleBox={x=394,y=478,w=212,h=42}
  u.centerTitle=text('Choose a skill',centerTitleBox,20,'PlayerListTitleTextStyle',GOLD,true,false,'center title')
  u.centerMeta=text('Move onto an icon',{x=410,y=531,w=180,h=46},12,'PlayerListDescriptionTextStyle',MUTED,true,true,'center meta')
  local panel=img(nil,L.panel);panel:SetColorAndOpacity({R=.02,G=.035,B=.045,A=.78})
  local border=img(nil,{x=942,y=110,w=2,h=800});border:SetColorAndOpacity({R=.66,G=.52,B=.29,A=.6})
    panel:SetVisibility(2);border:SetVisibility(2)
  u.heading=text('YOUR SPELLBOOK',L.heading,24,'HeaderTextStyle',WHITE,false,false,'heading')
  u.meta=text('Twelve skills. One gesture.',L.meta,12,'DescriptionTextStyle',MUTED,false,false,'meta')
  for i=1,model.geometry.maxBranch do
   local b,nb,tb,lb=L.row(i)
   local bg=img(nil,b);bg:SetColorAndOpacity({R=.19,G=.16,B=.09,A=.85})
   local number=text(tostring(i),nb,15,'PlayerListDescriptionTextStyle',GOLD,false,false,'row number '..i)
   local title=text('',tb,16,'PlayerListDescriptionTextStyle',WHITE,false,false,'row title '..i)
   local level=text('',lb,11,'DescriptionTextStyle',MUTED,false,false,'row level '..i)
   u.rows[i]={bg=bg,number=number,title=title,level=level,titleBox=tb,levelBox=lb}
   for _,w in ipairs({bg,number,title,level}) do w:SetVisibility(2) end
  end
  u.empty=text('Hover an inner icon to explore a skill.\n\nIts spells appear in the outer ring.\nThe numbers match this list.',{x=962,y=244,w=380,h=224},17,'PlayerListDescriptionTextStyle',MUTED,false,true,'intro')
    local divider=img(nil,{x=962,y=489,w=396,h=1});divider:SetColorAndOpacity({R=.66,G=.52,B=.29,A=.6});divider:SetVisibility(2)
  u.title=text('Find your next spell.',L.title,25,'HeaderTextStyle',GOLD,false,true,'spell title')
  u.body=text('Move outward to select a spell. Click to use the game\'s normal casting controls.',L.body,16,'PlayerListDescriptionTextStyle',WHITE,false,true,'description')
  u.cost=text('',L.cost,13,'PlayerListDescriptionTextStyle',MUTED,false,true,'cost')
  u.status=text('',L.status,13,'PlayerListDescriptionTextStyle',GOLD,false,true,'status')
  u.hint=text('LMB  Select     RMB  Back     Q / ESC  Close',{x=300,y=920,w=1040,h=28},13,'WorldInputLabelStyle',MUTED,true,false,'controls')
    for _,n in ipairs(u.textNodes) do n.widget:SetVisibility(2) end
    u.centerIcon:SetVisibility(2)
    u.root:SetVisibility(2);u.root:AddToViewport(9000)
  function u.resize()
   local v=E.layout:GetViewportSize(pc);local dpi=E.layout:GetViewportScale(pc)
   local width,height=v.X/dpi,v.Y/dpi;local scale=math.min(width/1480,height/1010)
   if u.width==width and u.height==height and u.scale==scale then return end
   u.width,u.height,u.scale=width,height,scale
   u.canvas:SetRenderScale({X=u.scale,Y=u.scale})
  end
  function u.pointer()
   local m=E.layout:GetMousePositionOnViewport(pc)
   return (m.X-u.width/2)/u.scale+L.width/2-L.cx,(m.Y-u.height/2)/u.scale+L.height/2-L.cy
  end
  function u.hide()
   u.cursor:SetVisibility(2);u.cursorCore:SetVisibility(2);u.root:SetVisibility(2)
   u.last='';u.branchKey='';u.branchDataKey=nil;u.visualGroup=nil;u.visualSpell=nil;u.visualCooldownTick=nil;u.cursorShown=false
  end
  function u.show()
   u.resize();u.cursor:SetVisibility(2);u.cursorCore:SetVisibility(2);u.root:SetVisibility(3)
   -- The wheel is already fully laid out. Avoid fading every widget on the
   -- first frames after opening, which causes a burst of Slate invalidation.
   u.root:SetRenderOpacity(1);u.last='';u.branchKey='';u.branchDataKey=nil
   u.visualGroup=nil;u.visualSpell=nil;u.visualCooldownTick=nil;u.cursorShown=false
  end
  function u.audit()
   u.root:ForceLayoutPrepass()
   local errors={}
   for _,n in ipairs(u.textNodes) do
    if n.widget:GetVisibility()==3 then
     local size=n.widget:GetDesiredSize()
     if size.X>n.box.w+.5 or size.Y>n.box.h+.5 then errors[#errors+1]=n.id..': '..size.X..'x'..size.Y..' > '..n.box.w..'x'..n.box.h end
    end
   end
   return errors
  end
  function u.draw(state,dt,message,cost,status,now,cooldowns)
   local pad=state.input=='controller'
   local browsing=state.controllerStage=='spells'
   local accept=state.padStyle=='playstation' and 'Cross' or 'A'
   local cast=state.padStyle=='playstation' and 'R2' or 'RT'
   local back=state.padStyle=='playstation' and 'Circle' or 'B'
   local cursor=pad and state.cursorVisible and state.cursorX and state.cursorY
   if cursor then
    local cursorX,cursorY=L.cx+state.cursorX-11,L.cy+state.cursorY-11
    if u.cursorX~=cursorX or u.cursorY~=cursorY then
     u.cursorX,u.cursorY=cursorX,cursorY
     u.cursorSlot:SetPosition({X=cursorX,Y=cursorY})
     u.cursorCoreSlot:SetPosition({X=cursorX+7,Y=cursorY+7})
    end
    if not u.cursorShown then
     u.cursorShown=true;u.cursor:SetVisibility(3);u.cursorCore:SetVisibility(3)
    end
   elseif u.cursorShown then
    u.cursorShown=false
    u.cursor:SetVisibility(2);u.cursorCore:SetVisibility(2)
   end
   local group=state.groups[state.group];local spell=group and group.spells[state.spell]
   local groupChanged=state.group~=u.visualGroup
   if groupChanged then
    u.visualGroup=state.group
    for i,n in ipairs(u.skills) do
     local selected=i==state.group
     n.alpha=selected and 1 or 0
     n.highlight:SetRenderOpacity(n.alpha)
     n.icon:SetRenderOpacity((not group or selected) and 1 or .65)
    end
   end
   local branchKey=tostring(state.group)..':'..state.page
   local branchChanged=branchKey~=u.branchKey
   if branchChanged then u.branchKey=branchKey end
   -- Cooldowns change without changing the selected spell. Rebuild the text
   -- once per second so the list and detail panel stay readable without
   -- invalidating the whole widget tree every frame.
   local cooldownTick=math.ceil(tonumber(now) or 0)
   local branchDataKey=branchKey..':'..tostring(cooldownTick)..':'..tostring(pad)
   local key=branchKey..':'..tostring(state.spell)..':'..tostring(message)..':'..tostring(cost)..':'..tostring(status)..':'..tostring(cooldownTick)..':'..tostring(pad)..':'..tostring(browsing)..':'..accept..':'..cast
   if key~=u.last then
    u.last=key
    branchChanged=branchDataKey~=u.branchDataKey
    if branchChanged then u.branchDataKey=branchDataKey end
    local b=model.branch(state)
    for i,n in ipairs(u.spells) do
     local row=u.rows[i];local visible=b and i<=b.count
    if branchChanged then for _,w in ipairs({n.base,n.highlight,n.icon,n.number}) do w:SetVisibility(visible and 3 or 2) end end
     if visible then
      local d=group.spells[b.first+i-1];local a=b.center-b.span/2+b.step*(i-.5)
       n.active=state.spell==b.first+i-1
       if branchChanged then
        n.base:SetRenderTransformAngle(math.deg(a));n.highlight:SetRenderTransformAngle(math.deg(a))
        n.unlocked=d.unlocked
        n.remaining=cooldowns and cooldowns:remaining(d,now) or 0
        n.cooldown=n.remaining>0
        local iconBox=L.icon(model,a,model.geometry.spellRadius,64)
        n.icon.Slot:SetPosition({X=iconBox.x,Y=iconBox.y})
        local x,y=model.point(a,385);n.number.Slot:SetPosition({X=L.cx+x-36,Y=L.cy+y-14})
        local t=u.texture(icons.spells[d.id]) or u.texture(icons.skills[group.id]);if E.valid(t) then n.icon:SetBrushFromTexture(t,false) end
        set(n.number,n.cooldown and cooldowns:format(n.remaining) or tostring(i),n.cooldown and RED or (n.active and GOLD or MUTED))
        fit(row.title,d.name,row.titleBox,16,12,d.unlocked and WHITE or MUTED)
        fit(row.level,n.cooldown and ('CD '..cooldowns:format(n.remaining)) or ('Lv '..d.level),row.levelBox,11,8,n.cooldown and RED or (d.unlocked and MUTED or GOLD))
       else
        set(n.number,n.cooldown and cooldowns:format(n.remaining) or tostring(i),n.cooldown and RED or (n.active and GOLD or MUTED))
       end
     end
    end
    set(u.empty,pad and 'Move the right stick onto a skill, then out to a spell.\n\nPress '..cast..' to cast it.' or 'Hover an inner icon to explore a skill.\n\nIts spells appear in the outer ring.\nThe numbers match this list.')
     if group then
        local t=u.texture(icons.skills[group.id]);if E.valid(t) then u.centerIcon:SetBrushFromTexture(t,false) end
     fit(u.centerTitle,group.label,centerTitleBox,20,16,GOLD)
     set(u.centerMeta,group.available..' / '..#group.spells..' unlocked')
     fit(u.heading,group.label,L.heading,24,20,WHITE)
     set(u.meta,#group.spells..' spells  /  '..group.available..' unlocked')
     fit(u.title,spell and spell.name or 'Choose a spell',L.title,25,20,GOLD)
     fit(u.body,spell and spell.description or (pad and ('Move the cursor to an outer spell. '..cast..' casts it; '..back..' returns to skills.') or 'Move to a numbered outer icon. Return to the inner ring to change skills.'),L.body,16,12,WHITE)
     fit(u.cost,cost or '',L.cost,13,11,MUTED)
     local remaining=cooldowns and spell and cooldowns:remaining(spell,now) or 0
     local spellStatus=remaining>0 and ('On cooldown  ·  ready in '..cooldowns:format(remaining)) or (spell and (spell.unlocked and (pad and cast..'  Cast spell' or 'LMB  Select spell') or 'Unlock at level '..spell.level) or (pad and accept..'  Choose skill' or 'Move outward to explore'))
     fit(u.status,message or status or spellStatus,L.status,13,11,message and RED or (remaining>0 and RED or GOLD))
    else
    fit(u.centerTitle,'Choose a skill',centerTitleBox,20,16,GOLD);set(u.centerMeta,pad and 'Stick / D-pad' or 'Move onto an icon')
     fit(u.heading,'YOUR SPELLBOOK',L.heading,24,20,WHITE);set(u.meta,'Twelve skills. One gesture.')
     fit(u.title,'Find your next spell.',L.title,25,20,GOLD)
    fit(u.body,pad and ('Move the cursor onto a spell, then press '..cast..' to cast it.') or 'Move outward to select a spell. Click to use the game\'s normal casting controls.',L.body,16,12,WHITE)
     set(u.cost,'');fit(u.status,message or '',L.status,13,11,RED)
    end
    set(u.hint,pad and ('Stick / D-pad  Browse     '..accept..(browsing and '  Select' or '  Choose')..(browsing and ('     '..cast..'  Cast') or '')..'     '..back..(browsing and '  Back' or '  Close')..(model.pages(state)>1 and (state.padStyle=='playstation' and '     L1 / R1  Page' or '     LB / RB  Page') or '')) or ('LMB  Select     RMB  Back     Q / ESC  Close'..(model.pages(state)>1 and '     F / G  Page '..state.page..' / '..model.pages(state) or '')))
   end
   local spellVisualChanged=state.spell~=u.visualSpell or branchChanged or cooldownTick~=u.visualCooldownTick
   if spellVisualChanged then
    u.visualSpell=state.spell;u.visualCooldownTick=cooldownTick
    for _,n in ipairs(u.spells) do
     n.base:SetRenderOpacity(1);n.number:SetRenderOpacity(1)
     n.icon:SetRenderOpacity(n.unlocked and (n.cooldown and .55 or 1) or .3)
     n.alpha=n.active and 1 or 0
     n.highlight:SetRenderOpacity(n.alpha)
    end
   end
  end
  return u
 end
 return R
end
