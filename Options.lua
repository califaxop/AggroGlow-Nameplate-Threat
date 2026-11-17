-- Aggro Glow: settings GUI (/ag, or Esc > Options > AddOns > Aggro Glow)
local _, ns = ...

local function Changed() if ns.UpdateAll then ns.UpdateAll() end end

local function Label(parent, text, template)
  local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
  fs:SetText(text)
  return fs
end

local function Header(parent, text, anchor, y)
  local h = Label(parent, text, "GameFontNormal")
  h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -16)
  return h
end

-- Slider -------------------------------------------------------------------
local function Slider(parent, label, minV, maxV, step, get, set, fmt, anchor)
  local text = Label(parent, "", "GameFontHighlight")
  text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
  local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  s:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -6)
  s:SetSize(240, 16)
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(minV, maxV); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
  s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 } })
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
  s:SetScript("OnValueChanged", function(_, v)
    set(v); text:SetText(label .. ": " .. fmt(v)); Changed()
  end)
  s.Refresh = function() s:SetValue(get()); text:SetText(label .. ": " .. fmt(get())) end
  s.bottom = s
  return s
end

-- Checkbox -----------------------------------------------------------------
local function Check(parent, label, key, anchor, x)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, -4)
  local l = Label(parent, label, "GameFontHighlight")
  l:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  cb:SetScript("OnClick", function(self) ns.db[key] = self:GetChecked() and true or false; Changed() end)
  cb.Refresh = function() cb:SetChecked(ns.db[key]) end
  return cb
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

local function Swatch(parent, label, key, anchor)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(20, 20)
  b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  b:SetBackdropBorderColor(0.8, 0.8, 0.8)
  local l = Label(parent, label, "GameFontHighlight")
  l:SetPoint("LEFT", b, "RIGHT", 8, 0)
  b.Refresh = function()
    local c = ns.db.colors[key]
    b:SetBackdropColor(c[1], c[2], c[3])
  end
  b:SetScript("OnClick", function()
    OpenColorPicker(ns.db.colors[key], function() b.Refresh(); Changed() end)
  end)
  return b
end

local function Button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22); b:SetText(text); b:SetScript("OnClick", onClick)
  return b
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function BuildPanel(panel)
  local refreshers = {}
  local function track(w) refreshers[#refreshers + 1] = w; return w end

  local title = Label(panel, "Aggro Glow", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)

  -- Glow
  local h1 = Header(panel, "Glow", title, -14)
  local lossA = track(Slider(panel, "Flashing glow strength", 0.1, 1, 0.05,
    function() return ns.db.glowAlpha end, function(v) ns.db.glowAlpha = v end,
    function(v) return math.floor(v * 100 + 0.5) .. "%" end, h1))
  local aggroA = track(Slider(panel, "Aggro glow strength", 0.05, 1, 0.05,
    function() return ns.db.aggroAlpha end, function(v) ns.db.aggroAlpha = v end,
    function(v) return math.floor(v * 100 + 0.5) .. "%" end, lossA))
  local speed = track(Slider(panel, "Flash speed", 0.15, 1, 0.05,
    function() return ns.db.flashSpeed end, function(v) ns.db.flashSpeed = v end,
    function(v) return format("%.2fs", v) end, aggroA))
  local thr = track(Slider(panel, "Unstable when someone reaches", 50, 100, 5,
    function() return ns.db.unstableAt end, function(v) ns.db.unstableAt = math.floor(v + 0.5) end,
    function(v) return math.floor(v + 0.5) .. "% of pulling it" end, speed))

  -- Colors
  local h2 = Header(panel, "Colors", thr, -22)
  local c1 = track(Swatch(panel, "Stable: you have aggro", "aggro", h2))
  local c2 = track(Swatch(panel, "Unstable: someone is close (flashing)", "unstable", c1))
  local c3 = track(Swatch(panel, "No threat: it's not on you (flashing)", "nothreat", c2))

  -- Whose aggro
  local hT = Header(panel, "Whose aggro to show", c3, -16)
  local TANKS = { { "auto", "Auto: my pet when it's out, else me" }, { "me", "Me" }, { "pet", "My pet" } }
  local tankBtn = Button(panel, "", 260, nil)
  tankBtn:SetPoint("TOPLEFT", hT, "BOTTOMLEFT", 0, -6)
  tankBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  tankBtn.Refresh = function()
    for _, t in ipairs(TANKS) do if t[1] == (ns.db.tank or "auto") then tankBtn:SetText(t[2]) end end
  end
  tankBtn:SetScript("OnClick", function(_, mouse)
    local i = 1
    for k, t in ipairs(TANKS) do if t[1] == (ns.db.tank or "auto") then i = k end end
    i = i + (mouse == "RightButton" and -1 or 1)
    if i < 1 then i = #TANKS elseif i > #TANKS then i = 1 end
    ns.db.tank = TANKS[i][1]; tankBtn.Refresh(); Changed()
  end)
  track(tankBtn)
  local tNote = Label(panel, "With your pet as the tank, the glows show your pet's aggro: you and your group count as \"someone close\".", "GameFontDisableSmall")
  tNote:SetPoint("TOPLEFT", tankBtn, "BOTTOMLEFT", 0, -6); tNote:SetWidth(340); tNote:SetJustifyH("LEFT")

  -- Show
  local h3 = Header(panel, "Show", tNote, -16)
  local k0 = track(Check(panel, "Only show in a party or raid (or when my pet tanks)", "onlyInGroup", h3))
  local k1 = track(Check(panel, "Steady glow when your aggro is stable", "showAggroGlow", k0))
  local k2 = track(Check(panel, "Separate glow when your aggro is unstable", "showUnstable", k1))
  local k3 = track(Check(panel, "\"!\" icon while aggro isn't stable", "showIcon", k2))
  local k4 = track(Check(panel, "Your threat % beside the nameplate", "showPercent", k3))

  -- Preview: show a state on your target's nameplate
  local buttons = {}
  local MODES = { { "secure", "Stable" }, { "insecure", "Unstable" }, { "lost", "No threat" } }
  local function SetPreview(mode)
    ns.preview = (ns.preview ~= mode) and mode or nil
    for i, m in ipairs(MODES) do
      buttons[i]:SetText(ns.preview == m[1] and "Stop" or ("Preview: " .. m[2]))
    end
    if ns.preview then ns.Print("preview on: target an enemy with its nameplate visible.") end
    Changed()
  end
  for i, m in ipairs(MODES) do
    local b = Button(panel, "Preview: " .. m[2], 112, function() SetPreview(m[1]) end)
    if i == 1 then b:SetPoint("TOPLEFT", k4, "BOTTOMLEFT", 0, -16)
    else b:SetPoint("LEFT", buttons[i - 1], "RIGHT", 6, 0) end
    buttons[i] = b
  end
  panel:HookScript("OnHide", function() if ns.preview then SetPreview(ns.preview) end end)
  local pAggro = buttons[1]

  local reset = Button(panel, "Reset to defaults", 140, function()
    ns.ResetDB()
    for _, w in ipairs(refreshers) do w.Refresh() end
    Changed()
  end)
  reset:SetPoint("TOPLEFT", pAggro, "BOTTOMLEFT", 0, -8)

  local hint = Label(panel, "/ag debug shows what threat data the game gives addons.", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -12)

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
    window:SetSize(400, 810)
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
