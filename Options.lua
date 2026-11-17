-- Aggro Glow: settings GUI (/ag, or Esc > Options > AddOns > Aggro Glow)
local _, ns = ...

local function Changed() if ns.UpdateAll then ns.UpdateAll() end end

local function Label(parent, text, template)
  local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
  fs:SetText(text)
  return fs
end

-- Color swatch -------------------------------------------------------------
local function OpenColorPicker(color, onChange)
  local r, g, b = color[1], color[2], color[3]
  local function apply()
    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
    color[1], color[2], color[3] = nr, ng, nb
    onChange()
  end
  local function cancel(prev)
    if prev then
      color[1] = prev.r or prev[1]; color[2] = prev.g or prev[2]; color[3] = prev.b or prev[3]
    else
      color[1], color[2], color[3] = r, g, b
    end
    onChange()
  end
  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
      swatchFunc = apply, cancelFunc = cancel })
  else
    ColorPickerFrame.func, ColorPickerFrame.cancelFunc = apply, cancel
    ColorPickerFrame.hasOpacity, ColorPickerFrame.previousValues = false, { r = r, g = g, b = b }
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:Show()
  end
end

local function Swatch(parent, key)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(18, 18)
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  b:SetBackdropBorderColor(0.75, 0.75, 0.75)
  b.Refresh = function()
    local c = ns.db.colors[key]
    b:SetBackdropColor(c[1], c[2], c[3])
  end
  b:SetScript("OnClick", function()
    OpenColorPicker(ns.db.colors[key], function() b.Refresh(); Changed() end)
  end)
  b:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(1, 0.82, 0)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Click to change the color"); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.75, 0.75, 0.75); GameTooltip:Hide() end)
  return b
end

local function Button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22); b:SetText(text); b:SetScript("OnClick", onClick)
  return b
end

---------------------------------------------------------------------------
-- Building blocks (placed by offset from the panel's top-left)
---------------------------------------------------------------------------
local PAD = 20

local function At(w, parent, x, y) w:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); return w end

-- a gold section title with a thin line under it
local function Section(parent, text, y)
  At(Label(parent, text, "GameFontNormal"), parent, PAD, y)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 0.12); line:SetHeight(1)
  line:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y - 17)
  line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, y - 17)
  return y - 28
end

local function Note(parent, text, x, y, width)
  local n = At(Label(parent, text, "GameFontDisableSmall"), parent, x, y)
  n:SetWidth(width or 380); n:SetJustifyH("LEFT")
  return n
end

-- slider with its name on the left above it and the value on the right
local function Slider(parent, label, x, y, width, minV, maxV, step, get, set, fmt)
  local name = label and At(Label(parent, label, "GameFontHighlightSmall"), parent, x, y)
  local value = Label(parent, "", "GameFontHighlightSmall")
  local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, label and (y - 16) or y)
  s:SetSize(width, 16)
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(minV, maxV); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
  s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 } })
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  if label then value:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 2)
  else value:SetPoint("LEFT", s, "RIGHT", 6, 0) end
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
  s:SetScript("OnValueChanged", function(_, v)
    set(v); value:SetText(fmt(v)); Changed()
  end)
  s.Refresh = function() s:SetValue(get()); value:SetText(fmt(get())) end
  s.SetActive = function(on)
    s:SetEnabled(on); s:SetAlpha(on and 1 or 0.4); value:SetAlpha(on and 1 or 0.4)
  end
  return s
end

-- checkbox; get/set default to a top-level setting
local function Check(parent, label, x, y, get, set)
  local cb = At(CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate"), parent, x, y)
  cb:SetSize(24, 24)
  if label then
    cb.text = Label(parent, label, "GameFontHighlight")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
  end
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Changed() end)
  cb.Refresh = function() cb:SetChecked(get()) end
  cb.SetActive = function(on)
    cb:SetEnabled(on)
    if cb.text then cb.text:SetFontObject(on and "GameFontHighlight" or "GameFontDisable") end
  end
  return cb
end
local function Setting(key) return function() return ns.db[key] end, function(v) ns.db[key] = v end end

-- "< value >": a selector that looks adjustable; click the arrows or the box (right-click goes back)
local function Selector(parent, x, y, width, options, get, set)
  local f = At(CreateFrame("Frame", nil, parent), parent, x, y)
  f:SetSize(width, 26)
  local function arrow(dir)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(26, 26)
    local base = dir < 0 and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-"
    b:SetNormalTexture(base .. "Up"); b:SetPushedTexture(base .. "Down"); b:SetDisabledTexture(base .. "Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    return b
  end
  local prev, next = arrow(-1), arrow(1)
  prev:SetPoint("LEFT"); next:SetPoint("RIGHT")
  local box = CreateFrame("Button", nil, f, "BackdropTemplate")
  box:SetPoint("LEFT", prev, "RIGHT", 2, 0); box:SetPoint("RIGHT", next, "LEFT", -2, 0); box:SetHeight(24)
  box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  box:SetBackdropColor(0, 0, 0, 0.45); box:SetBackdropBorderColor(1, 1, 1, 0.2)
  box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("LEFT", 8, 0); text:SetPoint("RIGHT", -8, 0)
  box:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0, 0.8) end)
  box:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.2) end)
  local function step(d)
    local i = 1
    for k, o in ipairs(options) do if o[1] == get() then i = k end end
    i = (i - 1 + d) % #options + 1
    set(options[i][1]); f.Refresh(); Changed()
  end
  prev:SetScript("OnClick", function() step(-1) end)
  next:SetScript("OnClick", function() step(1) end)
  box:SetScript("OnClick", function(_, mouse) step(mouse == "RightButton" and -1 or 1) end)
  f.Refresh = function()
    for _, o in ipairs(options) do if o[1] == get() then text:SetText(o[2]) end end
  end
  return f
end

local function pctFmt(v) return math.floor(v * 100 + 0.5) .. "%" end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local STATES = {
  { "aggro",    "Stable",    "The tank has aggro, safely." },
  { "unstable", "Unstable",  "The tank has aggro, but someone is close to pulling it." },
  { "nothreat", "No threat", "Engaged with you or your group, but not on the tank." },
}

local function BuildPanel(panel)
  local refreshers = {}
  local function track(w) refreshers[#refreshers + 1] = w; return w end

  At(Label(panel, "Aggro Glow", "GameFontNormalLarge"), panel, PAD, -18)
  Note(panel, "Threat glows on enemy nameplates.", PAD, -40)

  -- Whose aggro ------------------------------------------------------------
  local y = Section(panel, "Choose whose aggro to show", -66)
  track(Selector(panel, PAD, y, 330,
    { { "auto", "Auto: my pet when it's out, else me" }, { "me", "Me" }, { "pet", "My pet" } },
    function() return ns.db.tank or "auto" end, function(v) ns.db.tank = v end))
  Note(panel, "Click the arrows or the box to change it. With your pet as the tank, you and your group count as \"someone close\".", PAD, y - 32)

  -- Glows ------------------------------------------------------------------
  y = Section(panel, "Glows", y - 70)
  local COL_SHOW, COL_FLASH, COL_STR = 196, 246, 296
  At(Label(panel, "Show", "GameFontDisableSmall"), panel, COL_SHOW, y)
  At(Label(panel, "Flash", "GameFontDisableSmall"), panel, COL_FLASH, y)
  At(Label(panel, "Strength", "GameFontDisableSmall"), panel, COL_STR, y)
  y = y - 16
  for _, s in ipairs(STATES) do
    local key = s[1]
    local function st() return ns.db.states[key] end
    local sw = track(At(Swatch(panel, key), panel, PAD, y - 3))
    local name = Label(panel, s[2], "GameFontHighlight")
    name:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    -- tooltip on the name explains the state
    local hit = CreateFrame("Frame", nil, panel)
    hit:SetPoint("TOPLEFT", name, "TOPLEFT", -2, 2); hit:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 2, -2)
    hit:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(s[2]); GameTooltip:AddLine(s[3], 1, 1, 1, true); GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local str = track(Slider(panel, nil, COL_STR, y - 4, 90, 0.05, 1, 0.05,
      function() return st().alpha end, function(v) st().alpha = v end, pctFmt))
    local flash = track(Check(panel, nil, COL_FLASH + 2, y,
      function() return st().flash end, function(v) st().flash = v end))
    local show = track(Check(panel, nil, COL_SHOW + 2, y,
      function() return st().show end, function(v)
        st().show = v; flash.SetActive(v); str.SetActive(v)
      end))
    local refresh = show.Refresh
    show.Refresh = function() refresh(); flash.SetActive(st().show); str.SetActive(st().show) end
    y = y - 30
  end

  track(Slider(panel, "Flash speed", PAD, y - 6, 180, 0.15, 1, 0.05,
    function() return ns.db.flashSpeed end, function(v) ns.db.flashSpeed = v end,
    function(v) return format("%.2fs per flash", v) end))
  track(Slider(panel, "Unstable at", 220, y - 6, 180, 50, 100, 5,
    function() return ns.db.unstableAt end, function(v) ns.db.unstableAt = math.floor(v + 0.5) end,
    function(v) return math.floor(v + 0.5) .. "% of pulling" end))

  -- Display ----------------------------------------------------------------
  y = Section(panel, "Display", y - 56)
  track(Check(panel, "Only in a party or raid (or when my pet tanks)", PAD, y, Setting("onlyInGroup")))
  track(Check(panel, "\"!\" icon while aggro isn't stable", PAD, y - 26, Setting("showIcon")))
  local stablePct = Check(panel, "Also while aggro is stable", PAD + 24, y - 78, Setting("showPercentStable"))
  local pct = track(Check(panel, "Threat % beside the nameplate", PAD, y - 52, function() return ns.db.showPercent end,
    function(v) ns.db.showPercent = v; stablePct.SetActive(v) end))
  track(stablePct)
  local pr = pct.Refresh
  pct.Refresh = function() pr(); stablePct.SetActive(ns.db.showPercent) end
  Note(panel, "While the tank holds aggro, the % shows how close the next person is to pulling it.", PAD + 52, y - 102, 340)

  -- Preview ----------------------------------------------------------------
  y = Section(panel, "Preview on your target", y - 138)
  local buttons = {}
  local MODES = { { "secure", "Stable" }, { "insecure", "Unstable" }, { "lost", "No threat" } }
  local function SetPreview(mode)
    ns.preview = (ns.preview ~= mode) and mode or nil
    for i, m in ipairs(MODES) do buttons[i]:SetText(ns.preview == m[1] and "Stop" or m[2]) end
    if ns.preview then ns.Print("preview on: target an enemy with its nameplate visible.") end
    Changed()
  end
  for i, m in ipairs(MODES) do
    buttons[i] = At(Button(panel, m[2], 100, function() SetPreview(m[1]) end), panel, PAD + (i - 1) * 106, y)
  end
  panel:HookScript("OnHide", function() if ns.preview then SetPreview(ns.preview) end end)

  local reset = Button(panel, "Reset to defaults", 140, function()
    ns.ResetDB()
    for _, w in ipairs(refreshers) do w.Refresh() end
    Changed()
  end)
  At(reset, panel, PAD, y - 40)
  Note(panel, "/ag debug shows what threat data the game gives addons.", PAD + 150, y - 45, 230)

  panel:HookScript("OnShow", function() for _, w in ipairs(refreshers) do w.Refresh() end end)
  return panel
end

---------------------------------------------------------------------------
-- Esc > Options > AddOns entry, and the /ag window
---------------------------------------------------------------------------
local category, settingsPanel, window

function ns.CreateOptions()
  if settingsPanel then return end
  settingsPanel = CreateFrame("Frame")
  settingsPanel.name = "Aggro Glow"
  local ok, e = pcall(BuildPanel, settingsPanel)
  if not ok then ns.Print("settings panel failed: " .. tostring(e)); return end
  pcall(function()
    if Settings and Settings.RegisterCanvasLayoutCategory then
      category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
      Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
      InterfaceOptions_AddCategory(settingsPanel)
    end
  end)
end

function ns.OpenOptions()
  if not window then
    window = CreateFrame("Frame", "AggroGlowOptionsWindow", UIParent, "BackdropTemplate")
    window:SetSize(460, 660)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    window:SetMovable(true); window:EnableMouse(true); window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "AggroGlowOptionsWindow") -- Esc closes it
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    local inner = CreateFrame("Frame", nil, window)
    inner:SetPoint("TOPLEFT", 8, -8); inner:SetPoint("BOTTOMRIGHT", -8, 8)
    local ok, e = pcall(BuildPanel, inner)
    if not ok then window:Hide(); window = nil; ns.Print("settings failed: " .. tostring(e)); return end
    window:Hide()
  end
  -- shrink to fit smaller screens (the window is tall)
  window:SetScale(math.max(0.5, math.min(1, (UIParent:GetHeight() - 40) / window:GetHeight())))
  window:SetShown(not window:IsShown())
end
