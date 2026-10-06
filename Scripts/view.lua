-- Reusable UMG tree. Geometry, pointer hit tests and art use one design space.
-- No widget is detached after creation (focused-widget removal crashes UE4SS).
return function(E, model)
 local R={}
 local GOLD={R=.82,G=.70,B=.44,A=1}
 local INK={R=.72,G=.75,B=.72,A=1}
 local WHITE={R=.93,G=.91,B=.82,A=1}
 local RED={R=.89,G=.43,B=.36,A=1}
  function R.new(pc,folder,icons)
  local u={pc=pc,skills={},spells={},textures={},last=""}
  u.root=E.create(pc,"/Game/UI/Panels/WBP_Panel.WBP_Panel_C")
  local tree=u.root.WidgetTree
  local function widget(name) return StaticConstructObject(E.class("/Script/UMG."..name),tree) end
  local rootCanvas=widget("CanvasPanel");tree.RootWidget=rootCanvas
  local function place(parent,w,x,y,width,height)
   local s=parent:AddChildToCanvas(w);s:SetPosition({X=x,Y=y});s:SetSize({X=width,Y=height});return s
  end
  local dim=widget("Image");dim:SetColorAndOpacity({R=.015,G=.022,B=.028,A=.88})
  local ds=rootCanvas:AddChildToCanvas(dim)
  ds:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
  ds:SetOffsets({Left=0,Top=0,Right=0,Bottom=0});dim:SetVisibility(3)
  u.canvas=widget("CanvasPanel")
  local cs=rootCanvas:AddChildToCanvas(u.canvas)
  cs:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}})
  cs:SetAlignment({X=.5,Y=.5});cs:SetSize({X=1440,Y=960})
  u.canvas:SetRenderTransformPivot({X=.5,Y=.5})
  local function img(texture,x,y,w,h)
   local im=widget("Image");im:SetVisibility(3)
   if E.valid(texture) then im:SetBrushFromTexture(texture,false) end
   place(u.canvas,im,x,y,w,h);return im
  end
  local fonts={}
  local function text(value,x,y,w,h,size,style,color,center)
   if not fonts[style] then
    local donor=StaticConstructObject(E.class("/Game/UI/Common/WBP_DomTextBlock.WBP_DomTextBlock_C"),tree)
    donor:SetStyle(E.class("/Game/UI/Styles/Texts/CUIS_"..style..".CUIS_"..style.."_C"))
    fonts[style]=donor
   end
   local tb=widget("TextBlock")
   local font=fonts[style].Font;font.Size=size;font.LetterSpacing=0;tb:SetFont(font)
   tb:SetText(FText(value));tb:SetAutoWrapText(true)
   tb:SetColorAndOpacity({SpecifiedColor=color or INK,ColorUseRule=0})
   tb:SetJustification(center and 1 or 0);tb:SetVisibility(3)
   local slot=place(u.canvas,tb,x,y,w,h);slot:SetZOrder(20);return tb
  end
  function u.set(tb,value,color)
   tb:SetText(FText(value))
   if color then tb:SetColorAndOpacity({SpecifiedColor=color,ColorUseRule=0}) end
  end
  function u.texture(path)
   if not path or path=="" then return nil end
   if not E.valid(u.textures[path]) then u.textures[path]=E.asset(path) end
   return u.textures[path]
  end
  for _,n in ipairs({"skill","skill_active","spell","spell_active","center"}) do
   local t=E.render:ImportFileAsTexture2D(pc,folder.."/Assets/"..n..".png")
   assert(E.valid(t),"missing ring artwork: "..n);u.textures[n]=t
  end
  text("S P E L L B R A N C H E S",250,6,500,35,24,"PlayerListTitleTextStyle",GOLD,true)
  text("YOUR SKILLS.  YOUR MAGIC.",260,45,480,30,12,"DescriptionTextStyle",INK,true)
  -- Ring images are rotated around the same center as the pointer model.
  for i,g in ipairs(model.skills) do
   local angle=model.skillAngle(i,#model.skills)
   local base=img(u.textures.skill,76,56,848,848);base:SetRenderTransformAngle(math.deg(angle))
   local hi=img(u.textures.skill_active,76,56,848,848);hi:SetRenderTransformAngle(math.deg(angle));hi:SetRenderOpacity(0)
   local x,y=model.point(angle,model.geometry.skillRadius-9)
   local icon=img(u.texture(icons.skills[g.id]),500+x-23,480+y-31,46,46);icon.Slot:SetZOrder(10)
   local label=text(g.label:upper(),500+x-72,480+y+19,144,30,12,"DescriptionTextStyle",INK,true)
   u.skills[i]={base=base,highlight=hi,icon=icon,label=label,alpha=0}
  end
  for i=1,model.geometry.maxBranch do
   local b=img(u.textures.spell,76,56,848,848)
   local h=img(u.textures.spell_active,76,56,848,848)
   local icon=img(nil,0,0,48,48);icon.Slot:SetZOrder(10)
   local label=text("",0,0,140,48,12,"PlayerListDescriptionTextStyle",WHITE,true)
   local level=text("",0,0,100,22,11,"DescriptionTextStyle",INK,true)
   u.spells[i]={base=b,highlight=h,icon=icon,label=label,level=level,alpha=0}
   for _,w in ipairs({b,h,icon,label,level}) do w:SetVisibility(2) end
  end
  img(u.textures.center,76,56,848,848)
  u.centerIcon=img(nil,476,411,48,48);u.centerIcon:SetVisibility(2)
  u.centerTitle=text("CHOOSE A SKILL",396,472,208,56,18,"PlayerListTitleTextStyle",GOLD,true)
  u.centerMeta=text("Move outward to explore",412,534,176,40,12,"PlayerListDescriptionTextStyle",INK,true)
  -- Details stay in one place; long spell names never cover neighboring slices.
  local line=img(nil,950,292,400,1);line:SetColorAndOpacity({R=.78,G=.64,B=.38,A=.55})
  u.eyebrow=text("SKILL SPELLBOOK",950,242,400,44,13,"DescriptionTextStyle",GOLD)
  u.title=text("Choose a skill",950,319,400,110,32,"HeaderTextStyle",WHITE)
  u.body=text("Hover a skill to reveal its spells. Move into the outer ring to choose one.",950,435,400,215,18,"PlayerListDescriptionTextStyle",INK)
  u.cost=text("",950,675,400,72,15,"PlayerListDescriptionTextStyle",GOLD)
  u.status=text("",950,770,400,75,16,"PlayerListDescriptionTextStyle",INK)
  local lower=img(nil,950,858,400,1);lower:SetColorAndOpacity({R=.78,G=.64,B=.38,A=.35})
  text("DISCOVER • SELECT • CAST",950,883,400,24,12,"DescriptionTextStyle",INK)
  u.hint=text("LMB  Select spell     RMB  Back to skills     Q / ESC  Close",205,920,1110,36,14,"WorldInputLabelStyle",INK,true)
  u.root:SetVisibility(2);u.root:AddToViewport(9000)
  function u.resize()
   local v=E.layout:GetViewportSize(pc);local dpi=E.layout:GetViewportScale(pc)
   u.width,u.height=v.X/dpi,v.Y/dpi
   u.scale=math.min(u.width/1480,u.height/1010)
   u.canvas:SetRenderScale({X=u.scale,Y=u.scale})
  end
  function u.pointer()
   local m=E.layout:GetMousePositionOnViewport(pc)
   return (m.X-u.width/2)/u.scale+720-500,(m.Y-u.height/2)/u.scale+480-480
  end
  function u.hide() u.root:SetVisibility(2);u.last="" end
  function u.show() u.resize();u.root:SetVisibility(3);u.root:SetRenderOpacity(0);u.fade=0;u.last="" end
  function u.draw(state,dt,message,cost,status)
   u.fade=math.min(1,(u.fade or 0)+dt/0.12);u.root:SetRenderOpacity(u.fade)
   local group=state.groups[state.group]
   local spell=group and group.spells[state.spell]
   for i,node in ipairs(u.skills) do
    local target=i==state.group and 1 or 0
    node.alpha=node.alpha+(target-node.alpha)*math.min(1,dt*20)
    node.highlight:SetRenderOpacity(node.alpha)
   end
   local key=tostring(state.group)..":"..state.page..":"..tostring(state.spell)..":"..tostring(message)..":"..tostring(cost)..":"..tostring(status)
   if key~=u.last then
    u.last=key
    local b=model.branch(state)
    for i,node in ipairs(u.spells) do
     local visible=b and i<=b.count
     for _,w in ipairs({node.base,node.highlight,node.icon,node.label,node.level}) do w:SetVisibility(visible and 3 or 2) end
     if visible then
      local d=group.spells[b.first+i-1]
      local angle=b.center-b.span/2+b.step*(i-.5)
      local x,y=model.point(angle,model.geometry.spellRadius-12)
      node.base:SetRenderTransformAngle(math.deg(angle));node.highlight:SetRenderTransformAngle(math.deg(angle))
      node.highlight:SetRenderOpacity(state.spell==b.first+i-1 and 1 or 0)
      local t=u.texture(icons.spells[d.id]) or u.texture(icons.skills[group.id])
      if E.valid(t) then node.icon:SetBrushFromTexture(t,false) end
      node.icon:SetRenderOpacity(d.unlocked and 1 or .34)
      node.icon.Slot:SetPosition({X=500+x-24,Y=480+y-40})
      node.label.Slot:SetPosition({X=500+x-70,Y=480+y+12})
      node.level.Slot:SetPosition({X=500+x-50,Y=480+y-62})
      u.set(node.label,d.name,d.unlocked and WHITE or INK)
      u.set(node.level,d.unlocked and "" or "LV "..d.level,GOLD)
     end
    end
    if group then
     local t=u.texture(icons.skills[group.id]);if E.valid(t) then u.centerIcon:SetBrushFromTexture(t,false);u.centerIcon:SetVisibility(3) end
     u.set(u.centerTitle,group.label)
     u.set(u.centerMeta,group.available.." / "..#group.spells.." unlocked")
     u.set(u.eyebrow,group.label:upper()..(spell and "  /  LEVEL "..spell.level or "  /  SPELLS"))
     local title=spell and spell.name or group.label
     local tf=u.title.Font;tf.Size=#title>20 and 26 or 32;u.title:SetFont(tf)
     local bf=u.body.Font;bf.Size=spell and #spell.description>180 and 16 or 18;u.body:SetFont(bf)
     u.set(u.title,title)
     u.set(u.body,spell and spell.description or "Move outward to choose a spell. Return to the inner ring to explore another skill.")
     u.set(u.cost,cost or "")
     u.set(u.status,message or status or (spell and (spell.unlocked and "LMB  Select spell" or "Unlock at level "..spell.level) or "Explore the outer branch"),message and RED or GOLD)
    else
     u.centerIcon:SetVisibility(2);u.set(u.centerTitle,"CHOOSE A SKILL");u.set(u.centerMeta,"Move outward to explore")
     u.set(u.eyebrow,"SKILL SPELLBOOK");local tf=u.title.Font;tf.Size=32;u.title:SetFont(tf);local bf=u.body.Font;bf.Size=18;u.body:SetFont(bf);u.set(u.title,"Choose a skill")
     u.set(u.body,"Hover a skill to reveal its spells. Move into the outer ring to choose one.");u.set(u.cost,"");u.set(u.status,message or "")
    end
    u.set(u.hint,"LMB  Select spell     RMB  Back to skills     Q / ESC  Close"..(model.pages(state)>1 and "     F / G  Branch page" or ""))
   end
  end
  return u
 end
 return R
end
