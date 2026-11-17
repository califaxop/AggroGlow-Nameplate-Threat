-- Aggro Glow: settings window (/ag, or Esc > Options > AddOns > Aggro Glow), drawn in the same
-- style as XP Planner and Spell Glow (see UI.lua).
local _, ns = ...
local UI = ns.UI

local function Changed() if ns.UpdateAll then ns.UpdateAll() end end
local function S(key) return { function() return ns.db[key] end, function(v) ns.db[key] = v end } end
local function pctFmt(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Color swatch ---------------------------------------------------------------
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
  b:SetSize(16, 16)
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  local hover = false
  local function paint(th)
    th = th or UI.Theme()
    local c = ns.db and ns.db.colors[key]
    if c then b:SetBackdropColor(c[1], c[2], c[3]) end
    b:SetBackdropBorderColor(UI.RGB(hover and th.title or th.accent))
  end
  UI.Skin(paint)
  b.Refresh = function() paint() end
  b:SetScript("OnClick", function()
    OpenColorPicker(ns.db.colors[key], function() b.Refresh(); Changed() end)
  end)
  b:SetScript("OnEnter", function(self)
    hover = true; paint()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Click to change the color"); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() hover = false; paint(); GameTooltip:Hide() end)
  return b
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local STATES = {
  { "aggro",    "Stable",    "The tank has aggro, safely." },
  { "unstable", "Unstable",  "Someone is close to pulling it off the tank, or it's about to land on the tank (the tank is at or above the warning % of pulling it)." },
  { "nothreat", "No threat", "Engaged with you or your group, but not on the tank, and the tank isn't close to pulling it." },
}
local W_ = 420 -- content width

local function BuildPanel(panel)
  local refreshers = {}
  local function track(w) refreshers[#refreshers + 1] = w; return w end
  local function at(w, x, y) w:SetPoint("TOPLEFT", x, y); return w end

  local title = at(UI.Text(panel, "title", "Aggro Glow"), 26, -20)
  UI.Text(panel, "note", "Threat glows on enemy nameplates."):SetPoint("LEFT", title, "RIGHT", 10, -1)

  -- Whose aggro ------------------------------------------------------------
  at(UI.Section(panel, "Choose whose aggro to show", W_), 26, -54)
  track(at(UI.Selector(panel, 330, { { "auto", "Auto: my pet when it's out, else me" }, { "me", "Me" }, { "pet", "My pet" } },
    { function() return ns.db.tank or "auto" end, function(v) ns.db.tank = v end }, Changed,
    "Click, or use the arrows, to change it."), 26, -84))
  local n1 = at(UI.Text(panel, "note", "With your pet as the tank, you and your group count as \"someone close\"."), 26, -112)
  n1:SetWidth(W_)

  -- Glows ------------------------------------------------------------------
  at(UI.Section(panel, "Glows", W_), 26, -140)
  local COL_SHOW, COL_FLASH, COL_STR = 196, 246, 296
  at(UI.Text(panel, "note", "Show"), 26 + COL_SHOW - 4, -170)
  at(UI.Text(panel, "note", "Flash"), 26 + COL_FLASH - 4, -170)
  at(UI.Text(panel, "note", "Strength"), 26 + COL_STR, -170)
  local y = -188
  for _, st in ipairs(STATES) do
    local key = st[1]
    local function s() return ns.db.states[key] end
    local sw = track(at(Swatch(panel, key), 26, y - 4))
    local name = UI.Text(panel, "line", st[2]); name:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    local hit = CreateFrame("Frame", nil, panel)
    hit:SetPoint("TOPLEFT", name, "TOPLEFT", -2, 2); hit:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 2, -2)
    hit:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(st[2]); GameTooltip:AddLine(st[3], 1, 1, 1, true); GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local str = track(at(UI.Slider(panel, "", 124, 0.05, 1, 0.05,
      { function() return s().alpha end, function(v) s().alpha = v end }, pctFmt, Changed), 26 + COL_STR, y + 14))
    local flash = track(at(UI.Check(panel, "", { function() return s().flash end, function(v) s().flash = v end }, 20, Changed),
      26 + COL_FLASH, y - 2))
    local show
    show = track(at(UI.Check(panel, "", { function() return s().show end, function(v) s().show = v end }, 20, function()
      Changed(); show.Refresh()
    end), 26 + COL_SHOW, y - 2))
    local r = show.Refresh
    show.Refresh = function() r(); flash.SetActive(s().show); str:SetAlpha(s().show and 1 or 0.4) end
    y = y - 32
  end
  track(at(UI.Slider(panel, "Flash speed", 196, 0.15, 1, 0.05, S("flashSpeed"),
    function(v) return format("%.2fs per flash", v) end, Changed), 26, y - 6))
  track(at(UI.Slider(panel, "Warn at", 200, 50, 100, 5,
    { function() return ns.db.unstableAt end, function(v) ns.db.unstableAt = math.floor(v + 0.5) end },
    function(v) return math.floor(v + 0.5) .. "% of pulling" end, Changed), 246, y - 6))

  -- Display ----------------------------------------------------------------
  y = y - 56
  at(UI.Section(panel, "Display", W_), 26, y); y = y - 32
  track(at(UI.Check(panel, "Only in a party or raid (or when my pet tanks)", S("onlyInGroup"), W_, Changed), 26, y))
  local iconDist
  local icon
  icon = track(at(UI.Check(panel, "\"!\" icon while aggro isn't stable", S("showIcon"), W_, function()
    Changed(); icon.Refresh()
  end), 26, y - 24))
  -- where the "!" sits: from the health bar, or from the end of the % when that's on the right too
  local function iconKey()
    return (ns.db.percentSide == "right" and ns.db.showPercent) and "iconGapAfterPct" or "iconOffsetX"
  end
  iconDist = track(at(UI.Slider(panel, "\"!\" distance from the nameplate", 300, 0, 80, 1,
    { function() return ns.db[iconKey()] end, function(v) ns.db[iconKey()] = v end },
    function(v) return v .. " px" end, Changed, 1), 50, y - 50))
  local ir = icon.Refresh
  icon.Refresh = function()
    ir(); iconDist.Refresh(); iconDist:SetAlpha(ns.db.showIcon and 1 or 0.4)
  end
  local stablePct = UI.Check(panel, "Also while aggro is stable", S("showPercentStable"), 300, Changed)
  local pct
  pct = track(at(UI.Check(panel, "Threat % beside the nameplate", S("showPercent"), 250, function()
    Changed(); pct.Refresh(); icon.Refresh()
  end), 26, y - 94))
  local dist -- created below; the side switch refreshes the distance (it's kept per side)
  local side = track(at(UI.Toggle(panel, 120, { { "left", "On the left" }, { "right", "On the right" } }, S("percentSide"),
    function() Changed(); if dist then dist.Refresh() end; icon.Refresh() end, "Which side of the nameplate the % sits on. Click to switch."), 26 + 290, y - 93))
  track(at(stablePct, 50, y - 118))
  local pr = pct.Refresh
  pct.Refresh = function()
    pr(); stablePct.SetActive(ns.db.showPercent); side.SetActive(ns.db.showPercent); side.Refresh()
    if dist then dist:SetAlpha(ns.db.showPercent and 1 or 0.4) end
  end
  local n2 = at(UI.Text(panel, "note", "Read from the game's threat values, or from the threat line in each enemy's tooltip when the game hides them in combat. While you hold aggro, it's how close the next person is when the game shows that, otherwise 100%."), 72, y - 142)
  n2:SetWidth(W_ - 46)
  -- where the % sits: its distance from the bar, kept per side
  local function sideKey() return ns.db.percentSide == "right" and "percentOffsetRight" or "percentOffsetLeft" end
  dist = track(at(UI.Slider(panel, "% distance from the nameplate", 300, 0, 80, 1,
    { function() return ns.db[sideKey()] end, function(v) ns.db[sideKey()] = v end },
    function(v) return v .. " px" end, Changed, 1), 50, y - 186))
  track(at(UI.Check(panel, "FlareUI style for this window (needs FlareUI)", S("flareStyle"), W_, function() UI.Restyle() end), 26, y - 232))

  -- Preview ----------------------------------------------------------------
  y = y - 268
  at(UI.Section(panel, "Preview on your target", W_), 26, y); y = y - 32
  local buttons = {}
  local MODES = { { "secure", "Stable" }, { "insecure", "Unstable" }, { "lost", "No threat" } }
  local function SetPreview(mode)
    ns.preview = (ns.preview ~= mode) and mode or nil
    for i, m in ipairs(MODES) do buttons[i].SetLabel(ns.preview == m[1] and "Stop" or m[2]) end
    if ns.preview then ns.Print("preview on: target an enemy with its nameplate visible.") end
    Changed()
  end
  for i, m in ipairs(MODES) do
    buttons[i] = at(UI.Button(panel, m[2], 100, function() SetPreview(m[1]) end), 26 + (i - 1) * 106, y)
  end
  panel:HookScript("OnHide", function() if ns.preview then SetPreview(ns.preview) end end)

  local reset = at(UI.Button(panel, "Reset to defaults", 140, function()
    ns.ResetDB(); UI.Restyle()
    for _, w in ipairs(refreshers) do w.Refresh() end
    Changed()
  end), 26, y - 40)
  local hint = UI.Text(panel, "note", "/ag debug shows what threat data the game gives addons.")
  hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)

  panel:HookScript("OnShow", function() for _, w in ipairs(refreshers) do w.Refresh() end end)
  panel.height = -(y - 40 - 22 - 24)
  return panel
end

---------------------------------------------------------------------------
-- Esc > Options > AddOns entry, and the /ag window
---------------------------------------------------------------------------
local window

function ns.CreateOptions()
  local p = CreateFrame("Frame"); p.name = "Aggro Glow"
  pcall(function()
    local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16); t:SetText("Aggro Glow")
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetSize(200, 24); b:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -12); b:SetText("Open Aggro Glow settings")
    b:SetScript("OnClick", function()
      if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
      if not (window and window:IsShown()) then ns.OpenOptions() end
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
      Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(p, p.name))
    elseif InterfaceOptions_AddCategory then
      InterfaceOptions_AddCategory(p)
    end
  end)
end

function ns.OpenOptions()
  if not window then
    window = UI.Window("AggroGlowOptionsWindow", 472, 600)
    window:SetPoint("CENTER")
    local ok, e = pcall(BuildPanel, window)
    if not ok then window:Hide(); window = nil; ns.Print("settings failed: " .. tostring(e)); return end
    window:SetHeight(window.height or 600)
    window:Hide()
  end
  UI.Restyle()
  -- shrink to fit smaller screens
  window:SetScale(math.max(0.5, math.min(1, (UIParent:GetHeight() - 40) / window:GetHeight())))
  window:SetShown(not window:IsShown())
end
