-- Spell Hotkeys, integrated into BetterSpellWheel.
--
-- Up to 8 slots, each a utility spell + one key. With the wheel OPEN, pressing a slot key binds the
-- spell the pointer is on (read from BetterSpellWheel's own live model state via M.hoveredSpellData()).
-- With the wheel CLOSED, pressing the key casts that spell through M.castSpellData(), which drives the
-- same native path the wheel uses. A small bar above the hotbar shows each slot's icon, key and cooldown.
--
-- READ-ONLY, same promise as the wheel itself: it never writes a game property except the native slot
-- the game writes anyway when a spell is picked, and the HUD widgets it builds itself.
--
-- Origin: this replaces the standalone SpellHotkeys mod (XiiXeno). The cross-mod version read the native
-- radial's CachedSectionId, which BetterSpellWheel never updates, so every bind took the same spell.
-- Integrated here it reads the wheel's real hover state instead.

return function(E, host)
 local H = { slots = {}, flash = {} }
 local NUM_SLOTS = 8
 local TAG = "[BSW Hotkeys] "
 local function log(s) print(TAG .. tostring(s) .. "\n") end
 local warned = {}
 local function logOnce(k, s) if not warned[k] then warned[k] = true; log(s) end end

 local folder = host.folder
 local cfgPath = folder .. "/hotkeys.txt"

 -- Config -----------------------------------------------------------------------------------------
 -- QuickPick: with the wheel OPEN, the number row (1..9 0 - =) picks a skill then a spell, CS-buy-menu
 -- style. The number keys are consumed by the wheel's input while it is open (no hotbar interference)
 -- and read inside the wheel tick; the selection logic lives in main.lua (M.quickPick*).
 -- SlotHotkeys: the per-slot keys (bind on the open wheel, cast when closed) and the on-screen bar.
 -- QuickPick: the number row on the open wheel (see above). Each can be turned off on its own.
 local cfg = { SlotHotkeys = true, ShowHud = true, HideEmptySlots = true, ShowKeyLabels = true,
               ShowCooldownText = true, HudScale = 100, HudX = 0, HudY = 150, QuickPick = true }
 for n = 1, NUM_SLOTS do cfg["Slot" .. n .. "Spell"] = "None"; cfg["Slot" .. n .. "Key"] = "none" end

 local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

 local function loadConfig()
  local f = io.open(cfgPath, "r")
  if not f then return end
  for line in f:lines() do
   line = trim(line)
   if line ~= "" and line:sub(1, 1) ~= "#" then
    local k, v = line:match("^([%w_]+)%s*=%s*(.+)$")
    if k and v and cfg[k] ~= nil then
     v = trim(v:gsub("%s*[#;].*$", ""))
     if type(cfg[k]) == "boolean" then cfg[k] = (v:lower() == "true" or v == "1")
     elseif type(cfg[k]) == "number" then cfg[k] = tonumber(v) or cfg[k]
     else cfg[k] = v end
    end
   end
  end
  f:close()
 end

 local function saveConfigKey(k, v)
  local lines, found = {}, false
  local f = io.open(cfgPath, "r")
  if f then
   for line in f:lines() do
    local lk = line:match("^%s*([%w_]+)%s*=")
    if lk == k then lines[#lines + 1] = k .. " = " .. tostring(v); found = true
    else lines[#lines + 1] = line end
   end
   f:close()
  end
  if not found then lines[#lines + 1] = k .. " = " .. tostring(v) end
  local w = io.open(cfgPath, "w")
  if not w then log("could not write hotkeys.txt"); return end
  w:write(table.concat(lines, "\n"), "\n")
  w:close()
 end

 -- Keys -------------------------------------------------------------------------------------------
 -- Accept UE4SS key names. Mod Menu style names (NUM_PAD_ONE, SPACE_BAR...) are mapped to UE4SS's.
 local KEY_ALIAS = {
  NUM_PAD_ZERO="NUM_ZERO",NUM_PAD_ONE="NUM_ONE",NUM_PAD_TWO="NUM_TWO",NUM_PAD_THREE="NUM_THREE",
  NUM_PAD_FOUR="NUM_FOUR",NUM_PAD_FIVE="NUM_FIVE",NUM_PAD_SIX="NUM_SIX",NUM_PAD_SEVEN="NUM_SEVEN",
  NUM_PAD_EIGHT="NUM_EIGHT",NUM_PAD_NINE="NUM_NINE",
  THUMB_MOUSE_BUTTON="XBUTTON_ONE",THUMB_MOUSE_BUTTON_2="XBUTTON_TWO",MOUSE_4="XBUTTON_ONE",MOUSE_5="XBUTTON_TWO",
  SPACE_BAR="SPACE",ENTER="RETURN",INSERT="INS",DELETE="DEL",
  UP="UP_ARROW",DOWN="DOWN_ARROW",LEFT="LEFT_ARROW",RIGHT="RIGHT_ARROW",
  PERIOD="OEM_PERIOD",COMMA="OEM_COMMA",HYPHEN="OEM_MINUS",EQUALS="OEM_PLUS",SLASH="OEM_TWO",
  BACKSLASH="OEM_FIVE",LEFT_BRACKET="OEM_FOUR",RIGHT_BRACKET="OEM_SIX",SEMICOLON="OEM_ONE",
  APOSTROPHE="OEM_SEVEN",QUOTE="OEM_SEVEN",TILDE="OEM_THREE",
 }
 local KEY_LABEL = {
  NUM_ZERO="N0",NUM_ONE="N1",NUM_TWO="N2",NUM_THREE="N3",NUM_FOUR="N4",NUM_FIVE="N5",NUM_SIX="N6",
  NUM_SEVEN="N7",NUM_EIGHT="N8",NUM_NINE="N9",ZERO="0",ONE="1",TWO="2",THREE="3",FOUR="4",FIVE="5",
  SIX="6",SEVEN="7",EIGHT="8",NINE="9",XBUTTON_ONE="M4",XBUTTON_TWO="M5",MIDDLE_MOUSE_BUTTON="M3",
  SPACE="Spc",RETURN="Ent",TAB="Tab",INS="Ins",DEL="Del",HOME="Hom",END="End",PAGE_UP="PgU",PAGE_DOWN="PgD",
  UP_ARROW="Up",DOWN_ARROW="Dn",LEFT_ARROW="Lt",RIGHT_ARROW="Rt",
  OEM_PERIOD=".",OEM_COMMA=",",OEM_MINUS="-",OEM_PLUS="=",OEM_TWO="/",OEM_FIVE="\\",OEM_FOUR="[",
  OEM_SIX="]",OEM_ONE=";",OEM_SEVEN="'",OEM_THREE="`",
 }
 local function normKey(name)
  if not name then return nil end
  name = tostring(name):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  if name == "" or name == "NONE" then return nil end
  return KEY_ALIAS[name] or name
 end
 local function keyLabel(name)
  local n = normKey(name)
  if not n then return "" end
  return KEY_LABEL[n] or n:gsub("_", ""):sub(1, 3)
 end

 -- UObject helpers --------------------------------------------------------------------------------
 local function valid(o)
  if not o then return false end
  local ok, v = pcall(function() return o:IsValid() end)
  return ok and v
 end
 local function fname(o)
  local ok, n = pcall(function() return o:GetFName():ToString() end)
  return ok and tostring(n) or "?"
 end
 local function fullName(o)
  local ok, n = pcall(function() return o:GetFullName() end)
  return ok and tostring(n) or nil
 end
 local function textOf(ft)
  local ok, s = pcall(function() return ft:ToString() end)
  return ok and tostring(s) or nil
 end

 -- Spell index: asset short name (and display name) -> UtilitySpellData. The set of UtilitySpellData is
 -- fixed within a world, so this is built ONCE per world; H.dropWorld clears it to force a rebuild on the
 -- next world. (A spell the player has not seen yet is already loaded on the data side, so one scan is
 -- enough; if a lookup misses it is retried once in case the scan ran a hair too early.)
 local spellByAsset, spellByName, indexMisses = nil, nil, 0
 local function indexSpells()
  local byAsset, byName = {}, {}
  for _, s in ipairs(FindAllOf("UtilitySpellData") or {}) do
   if valid(s) and not fname(s):find("^Default__") then
    byAsset[fname(s):gsub("^USD_", ""):lower()] = s
    local dn = textOf(s.SpellDisplayName)
    if dn and dn ~= "" then byName[dn:lower()] = s end
   end
  end
  spellByAsset, spellByName = byAsset, byName
 end
 local function spellForName(label)
  if not label or label == "" or label:lower() == "none" then return nil end
  if not spellByAsset then indexSpells(); indexMisses = 0 end
  local l = label:lower()
  local hit = spellByName[l] or spellByAsset[l] or spellByAsset[(l:gsub("%s+", ""))]
  -- A miss right after a world load may mean the scan ran before all assets were present: rebuild once.
  if not hit and indexMisses < 1 then indexMisses = indexMisses + 1; indexSpells(); hit = spellByName[l] or spellByAsset[l] or spellByAsset[(l:gsub("%s+", ""))] end
  return hit
 end

 -- Slots: resolve each configured slot to its spell data. Cheap; rerun when config changes.
 local resolveDirty = true
 local function resolveSlots()
  for n = 1, NUM_SLOTS do
   local label = trim(tostring(cfg["Slot" .. n .. "Spell"] or ""))
   local data = (label ~= "" and label:lower() ~= "none") and spellForName(label) or nil
   local old = H.slots[n]
   if not old or old.label ~= label then
    H.slots[n] = { label = label, data = valid(data) and data or nil, name = label }
    if H.slots[n].data then H.slots[n].name = textOf(data.SpellDisplayName) or label end
   elseif data and not valid(old.data) then
    old.data = data; old.name = textOf(data.SpellDisplayName) or label
   end
  end
  resolveDirty = false
 end

 -- Cooldown remaining (display only), read from the game's LastCastTimeBySpellData on the pawn.
 local function magicComponent(pc)
  local pawn = pc and pc.Pawn
  if not valid(pawn) then return nil end
  local found
  pcall(function()
   local c = pawn:GetComponentByClass(StaticFindObject("/Script/Dominion.PlayerUtilityMagicComponent"))
   if valid(c) then found = c end
  end)
  return found
 end
 local function effectiveCooldown(pc, data)
  local cd = 0
  pcall(function() cd = tonumber(data.CooldownDuration) or 0 end)
  pcall(function()
   local m = data.CooldownModifierPerk
   if valid(m.CooldownPerk) then
    local spc = pc:GetSkillPerkComponent()
    if valid(spc) and spc:IsPerkUnlocked(m.CooldownPerk) then cd = tonumber(m.ModifiedCooldown) or cd end
   end
  end)
  return cd
 end
 -- The last-cast time of every spell, read ONCE per refresh from the pawn's LastCastTimeBySpellData
 -- map, keyed by spell full name. Avoids walking the whole TMap once per slot per frame (8x).
 local castTimes, castTimesAt = {}, -100
 local CD_REFRESH = 0.25            -- seconds between map reads (the bar updates ~4x/second)
 local function refreshCastTimes(pc)
  if os.clock() - castTimesAt < CD_REFRESH then return end
  castTimesAt = os.clock()
  local t = {}
  local magic = magicComponent(pc)
  if magic then
   pcall(function()
    magic.LastCastTimeBySpellData:ForEach(function(k, v)
     local kv = k:get()
     if valid(kv) then local n = fullName(kv); if n then t[n] = tonumber(v:get()) end end
    end)
   end)
  end
  castTimes = t
 end
 local function cooldownRemaining(pc, data, now)
  if not (valid(data) and now) then return 0, 0 end
  local cd = effectiveCooldown(pc, data)
  if cd <= 0 then return 0, 0 end
  local last = castTimes[fullName(data) or ""]
  if not last then return 0, cd end
  local rem = cd - (now - last)
  if rem < 0 then rem = 0 end
  return rem, cd
 end

 -- HUD --------------------------------------------------------------------------------------------
 local VIS_VISIBLE, VIS_COLLAPSED, VIS_HIDDEN, VIS_SHTI = 0, 1, 2, 4
 local SLOT_PX, SLOT_GAP = 60, 6
 local COL_BG      = { R=0.03, G=0.03, B=0.03, A=0.70 }
 local COL_BG_FLASH= { R=0.55, G=0.08, B=0.05, A=0.85 }
 local COL_ICON    = { R=1, G=1, B=1, A=1 }
 local COL_LOCKED  = { R=0.35, G=0.35, B=0.35, A=0.9 }
 local COL_SHADE   = { R=0, G=0, B=0, A=0.7 }
 local COL_TEXT    = { R=0.95, G=0.92, B=0.85, A=1 }
 local COL_KEY     = { R=0.86, G=0.72, B=0.42, A=1 }
 local hud = nil
 local texCache = {}

 local function umg(cls) return StaticFindObject("/Script/UMG." .. cls) end
 local function make(cls, outer, name) return StaticConstructObject(umg(cls), outer, FName(name)) end
 local function newText(outer, name, size, color, justify)
  local tb = make("TextBlock", outer, name)
  pcall(function() tb.Font.Size = size end)
  pcall(function() tb.Font.OutlineSettings.OutlineSize = 1 end)
  pcall(function() tb:SetColorAndOpacity({ SpecifiedColor = color, ColorUseRule = 0 }) end)
  pcall(function() tb:SetShadowOffset({ X = 1, Y = 1 }) end)
  pcall(function() tb:SetShadowColorAndOpacity({ R = 0, G = 0, B = 0, A = 0.8 }) end)
  if justify then pcall(function() tb:SetJustification(justify) end) end
  pcall(function() tb:SetText(FText("")) end)
  pcall(function() tb:SetVisibility(VIS_SHTI) end)
  return tb
 end
 local function spellTexture(data)
  local key = fullName(data) or ""
  local hit = texCache[key]
  if hit == false then return nil end
  if hit and valid(hit) then return hit end
  texCache[key] = nil
  local tex = nil
  pcall(function()
   local ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
   tex = ksl:LoadAsset_Blocking(data.SpellIcon)
  end)
  if not valid(tex) then tex = nil; logOnce("tex" .. key, "no icon texture for " .. key) end
  texCache[key] = tex or false
  return tex
 end
 local function destroyHud()
  if hud and hud.root then pcall(function() hud.root:RemoveFromParent() end) end
  hud = nil; texCache = {}
 end
 local function buildHud()
  destroyHud()
  local gi = FindFirstOf("GameInstance")
  if not valid(gi) then return false end
  local h = { slots = {} }
  local ok, err = pcall(function()
   h.root = make("UserWidget", gi, "BSWHotkeysHUD")
   h.root.WidgetTree = make("WidgetTree", h.root, "BSWHotkeysTree")
   h.canvas = make("CanvasPanel", h.root.WidgetTree, "BSWHotkeysCanvas")
   h.root.WidgetTree.RootWidget = h.canvas
   h.bar = make("HorizontalBox", h.canvas, "BSWHotkeysBar")
   for n = 1, NUM_SLOTS do
    local box = make("SizeBox", h.bar, "HKBox" .. n)
    box:SetWidthOverride(SLOT_PX); box:SetHeightOverride(SLOT_PX)
    local over = make("Overlay", box, "HKOver" .. n)
    box:AddChild(over)
    local function fill(w)
     local s = over:AddChildToOverlay(w)
     pcall(function() s:SetHorizontalAlignment(0); s:SetVerticalAlignment(0) end)
     return s
    end
    local bg = make("Image", over, "HKBg" .. n); bg:SetColorAndOpacity(COL_BG); fill(bg)
    local icon = make("Image", over, "HKIcon" .. n); icon:SetColorAndOpacity(COL_ICON)
    local iconSlot = fill(icon)
    pcall(function() iconSlot:SetPadding({ Left = 4, Top = 4, Right = 4, Bottom = 4 }) end)
    local shade = make("Image", over, "HKShade" .. n); shade:SetColorAndOpacity(COL_SHADE)
    shade:SetRenderTransformPivot({ X = 0.5, Y = 1.0 }); shade:SetRenderScale({ X = 1, Y = 0 }); fill(shade)
    local cdText = newText(over, "HKCd" .. n, 20, COL_TEXT, 1)
    local cdSlot = over:AddChildToOverlay(cdText)
    pcall(function() cdSlot:SetHorizontalAlignment(2); cdSlot:SetVerticalAlignment(2) end)
    local keyText = newText(over, "HKKey" .. n, 12, COL_KEY, 2)
    local keySlot = over:AddChildToOverlay(keyText)
    pcall(function() keySlot:SetHorizontalAlignment(3); keySlot:SetVerticalAlignment(3) end)
    pcall(function() keySlot:SetPadding({ Left = 0, Top = 0, Right = 3, Bottom = 1 }) end)
    local barSlot = h.bar:AddChildToHorizontalBox(box)
    pcall(function() barSlot:SetPadding({ Left = SLOT_GAP / 2, Top = 0, Right = SLOT_GAP / 2, Bottom = 0 }) end)
    for _, w in ipairs({ box, over, bg, icon, shade }) do pcall(function() w:SetVisibility(VIS_SHTI) end) end
    h.slots[n] = { box = box, bg = bg, icon = icon, shade = shade, cdText = cdText, keyText = keyText,
                   lastCd = -1, lastKey = nil, lastIcon = nil, lastLocked = nil, lastFlash = false, visible = true }
   end
   h.barSlot = h.canvas:AddChildToCanvas(h.bar)
   h.barSlot:SetAutoSize(true)
   h.barSlot:SetAnchors({ Minimum = { X = 0.5, Y = 1.0 }, Maximum = { X = 0.5, Y = 1.0 } })
   h.barSlot:SetAlignment({ X = 0.5, Y = 1.0 })
   h.bar:SetRenderTransformPivot({ X = 0.5, Y = 1.0 })
   pcall(function() h.canvas:SetVisibility(VIS_SHTI); h.bar:SetVisibility(VIS_SHTI) end)
   h.root:AddToViewport(60)
  end)
  if not ok then log("could not build the hotkey bar: " .. tostring(err)); return false end
  hud = h; hud.layoutKey = nil
  log("hotkey bar built")
  return true
 end
 local function applyLayout()
  local key = table.concat({ cfg.HudX, cfg.HudY, cfg.HudScale }, "|")
  if hud.layoutKey == key then return end
  hud.layoutKey = key
  local s = (tonumber(cfg.HudScale) or 100) / 100
  pcall(function() hud.barSlot:SetPosition({ X = tonumber(cfg.HudX) or 0, Y = -(tonumber(cfg.HudY) or 150) }) end)
  pcall(function() hud.bar:SetRenderScale({ X = s, Y = s }) end)
 end
 local function setVisible(w, on) pcall(function() w:SetVisibility(on and VIS_SHTI or VIS_COLLAPSED) end) end

 local function updateHud(pc, showBar, now)
  if not hud then return end
  if hud.shown ~= showBar then
   hud.shown = showBar
   pcall(function() hud.canvas:SetVisibility(showBar and VIS_SHTI or VIS_HIDDEN) end)
  end
  if not showBar then return end
  applyLayout()
  refreshCastTimes(pc)          -- read the cast-time map once (throttled), not once per slot
  for n = 1, NUM_SLOTS do
   local w, slot = hud.slots[n], H.slots[n]
   local hasSpell = slot and valid(slot.data)
   local vis = hasSpell or not cfg.HideEmptySlots
   if w.visible ~= vis then w.visible = vis; setVisible(w.box, vis) end
   if vis then
    local iconKey = hasSpell and (fullName(slot.data) or "") or ""
    if w.lastIcon ~= iconKey then
     w.lastIcon = iconKey
     if hasSpell then
      local tex = spellTexture(slot.data)
      if tex then pcall(function() w.icon:SetBrushFromTexture(tex, false) end) end
      setVisible(w.icon, tex ~= nil)
     else setVisible(w.icon, false) end
    end
    local unlocked = true
    if hasSpell then pcall(function() unlocked = pc:GetProgressComponent():IsSpellUnlocked(slot.data) end) end
    local locked = hasSpell and not unlocked
    if w.lastLocked ~= locked then
     w.lastLocked = locked
     pcall(function() w.icon:SetColorAndOpacity(locked and COL_LOCKED or COL_ICON) end)
    end
    local keyStr = cfg.ShowKeyLabels and keyLabel(cfg["Slot" .. n .. "Key"]) or ""
    if w.lastKey ~= keyStr then w.lastKey = keyStr; pcall(function() w.keyText:SetText(FText(keyStr)) end) end
    local rem, cd = 0, 0
    if hasSpell then rem, cd = cooldownRemaining(pc, slot.data, now) end
    rem = tonumber(rem) or 0; cd = tonumber(cd) or 0
    local shown = (rem > 0 and cfg.ShowCooldownText) and tostring(math.ceil(rem)) or ""
    local cdKey = shown .. "|" .. math.floor(rem * 10)
    if w.lastCd ~= cdKey then
     w.lastCd = cdKey
     local frac = (cd > 0) and math.min(1, rem / cd) or 0
     pcall(function() w.shade:SetRenderScale({ X = 1, Y = frac }) end)
     pcall(function() w.cdText:SetText(FText(shown)) end)
    end
    local flashing = (H.flash[n] or 0) > os.clock()
    if w.lastFlash ~= flashing then
     w.lastFlash = flashing
     pcall(function() w.bg:SetColorAndOpacity(flashing and COL_BG_FLASH or COL_BG) end)
    end
   end
  end
 end

 -- Press handling ---------------------------------------------------------------------------------
 -- With the wheel open: bind the hovered spell to the slot (empty / off-slice clears it).
 -- With the wheel closed: cast the slot's spell.
 local function onPress(n)
  if cfg.SlotHotkeys == false then return end          -- slot hotkeys turned off
  local ctx = host.hotkeyContext and host.hotkeyContext() or nil
  if not ctx or not valid(ctx.pc) then return end
  if ctx.open then
   local data = host.hoveredSpellData and host.hoveredSpellData() or nil
   local name = "None"
   if valid(data) then name = textOf(data.SpellDisplayName) or (fname(data):gsub("^USD_", "")) end
   cfg["Slot" .. n .. "Spell"] = name
   saveConfigKey("Slot" .. n .. "Spell", name)
   resolveDirty = true
   H.flash[n] = os.clock() + 0.5
   log(("slot %d bound to %s"):format(n, name))
   return
  end
  -- Closed: cast.
  if ctx.pending then return end
  if resolveDirty then resolveSlots() end
  local slot = H.slots[n]
  if not slot or not valid(slot.data) then H.flash[n] = os.clock() + 0.3; return end
  local okCast = host.castSpellData and host.castSpellData(slot.data) or false
  if not okCast then H.flash[n] = os.clock() + 0.4 end
 end

 -- Key registration. One global dispatcher survives script reloads; it resolves the live mod + hotkeys
 -- from _G, and dispatches by current config at press time (UE4SS has no unregister).
 _G.BetterSpellWheelHotkeyBound = _G.BetterSpellWheelHotkeyBound or {}
 local bound = _G.BetterSpellWheelHotkeyBound
 local function dispatch(name)
  local m = _G.BetterSpellWheel
  local hk = m and m.hotkeys
  if not hk then return end
  for n = 1, NUM_SLOTS do
   if normKey(cfg["Slot" .. n .. "Key"]) == name then
    ExecuteInGameThread(function()
     local ok, err = pcall(hk.onPress, n)
     if not ok then log("slot " .. n .. " error: " .. tostring(err)) end
    end)
   end
  end
 end
 H.onPress = onPress
 local function bindKeys()
  for n = 1, NUM_SLOTS do
   local name = normKey(cfg["Slot" .. n .. "Key"])
   if name and not bound[name] then
    local key = Key[name]
    if not key then
     logOnce("badkey" .. name, "slot " .. n .. ": '" .. tostring(cfg["Slot" .. n .. "Key"]) .. "' is not a UE4SS key name; leave it unbound or pick another")
    else
     local function cb() dispatch(name) end
     local ok = pcall(RegisterKeyBind, key, cb)
     if ok then
      for _, mods in ipairs({ { ModifierKey.SHIFT }, { ModifierKey.CONTROL }, { ModifierKey.ALT },
                              { ModifierKey.SHIFT, ModifierKey.CONTROL } }) do
       pcall(RegisterKeyBind, key, mods, cb)
      end
      bound[name] = true; log("bound " .. name)
     else log("could not bind " .. name) end
    end
   end
  end
 end

 -- Mod Menu live sync. Mod Menu writes changes into hotkeys.txt AND publishes them as shared
 -- variables; we pick them up without a restart. id must match modmenu.json's "id".
 local MODMENU_ID = "BetterSpellWheelHotkeys"
 local mmRev = nil
 local function modMenuSync()
  local ok, rev = pcall(function() return ModRef:GetSharedVariable("ModMenu." .. MODMENU_ID .. ".rev") end)
  if not ok or type(rev) ~= "number" or rev == mmRev then return end
  mmRev = rev
  local keysChanged, anyChanged = false, false
  for k, old in pairs(cfg) do
   local okV, v = pcall(function() return ModRef:GetSharedVariable("ModMenu." .. MODMENU_ID .. "." .. k) end)
   if okV and v ~= nil and type(v) == type(old) and cfg[k] ~= v then
    cfg[k] = v; anyChanged = true
    if k:match("Key$") then keysChanged = true end
    if k:match("Spell$") then resolveDirty = true end
   end
  end
  if keysChanged then bindKeys(); resolveDirty = true end
  if anyChanged then log("settings updated from Mod Menu") end   -- only when one of OUR settings moved
 end

 -- Public tick: called once per BetterSpellWheel tick, with the live context. Keeps the bar in sync.
 function H.tick(ctx)
  pcall(modMenuSync)
  local m = _G.BetterSpellWheel
  if m then m.quickPickEnabled = (cfg.QuickPick ~= false) end
  if not ctx or not valid(ctx.pc) then if hud then destroyHud() end; return end
  if resolveDirty then resolveSlots() end
  -- Slot hotkeys off: no bar at all (tear it down if it was built).
  if cfg.SlotHotkeys == false then if hud then destroyHud() end; return end
  if not hud and cfg.ShowHud then buildHud() end
  local cursor = false
  pcall(function() cursor = ctx.pc.bShowMouseCursor end)
  -- Visible normally; also visible while the wheel is open (so you see what you bind); hidden under menus.
  local show = cfg.ShowHud and (not cursor or ctx.open)
  updateHud(ctx.pc, show, ctx.gameTime)
 end

 function H.dropWorld()
  destroyHud()
  spellByAsset, spellByName, indexMisses = nil, nil, 0
  castTimes, castTimesAt = {}, -100
  resolveDirty = true
 end

 loadConfig()
 bindKeys()
 log("hotkeys loaded (wheel open = bind the hovered spell; wheel closed = cast)")
 return H
end
