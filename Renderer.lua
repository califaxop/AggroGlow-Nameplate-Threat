-- Nameplate Renderer: a separate indicator anchored to Blizzard's nameplate.
-- Blizzard's health bar is never changed. The glow reuses the nameplate's own
-- selection-border art (copied, tinted), so it matches the game's look and lines up exactly.
--   stable    : green  -> the tank has aggro, safely
--   unstable  : orange -> the tank has aggro, but someone is close to taking it
--   no threat : red    -> engaged with you or your party, but it isn't on the tank
-- Each glow can be shown or not, flashing or steady, at its own strength (settings).
local _, ns = ...
local V = {}
ns.Renderer = V

local isSecret = ns.isSecret
local indicators = {}   -- plate -> indicator frame
local TEXT_LEVEL = 30   -- % and "!" sit this many frame levels above the health bar (over debuff icons)

-- show at most 100%; a hidden (secret) value can't be compared, so it passes through as is
local function Cap(v)
  if isSecret(v) or type(v) ~= "number" then return v end
  return v > 100 and 100 or v
end

local function HealthBarOf(plate)
  local uf = plate.UnitFrame
  if not uf then return plate end
  return uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar) or uf
end

-- Forever's nameplate target border art. Used as our glow so it matches the game's look.
local BORDER_ATLAS = "UI-HUD-CoolDownManager-Selected-yellow"

-- Make a texture with the border art, sitting exactly where Blizzard's border sits.
-- We never read the border's position (the client forbids measuring it); we just
-- anchor to it, or to the health bar if that's refused.
local function BorderTexture(parent, bar, layer, sublevel)
  local t = parent:CreateTexture(nil, layer, nil, sublevel)
  local src = bar.selectedBorder
  local atlas
  if type(src) == "table" and src.GetAtlas then
    local ok, a = pcall(src.GetAtlas, src)
    if ok and type(a) == "string" and not ns.isSecret(a) then atlas = a end
  end
  if not (atlas and pcall(t.SetAtlas, t, atlas)) then
    if not pcall(t.SetAtlas, t, BORDER_ATLAS) then return nil end
  end
  local anchored = type(src) == "table" and pcall(t.SetAllPoints, t, src)
  if not anchored then
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
    t:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
  end
  return t
end

-- Fallback when the nameplate has no selection border: a clean outline around the bar.
local function OutlineGlow(parent, bar)
  local g = { textures = {} }
  local edges = {
    { "TOPLEFT", "TOPLEFT", -2, 2, "TOPRIGHT", "TOPRIGHT", 2, 0, "h" },
    { "BOTTOMLEFT", "BOTTOMLEFT", -2, -2, "BOTTOMRIGHT", "BOTTOMRIGHT", 2, 0, "h" },
    { "TOPLEFT", "TOPLEFT", -2, 2, "BOTTOMLEFT", "BOTTOMLEFT", 0, -2, "v" },
    { "TOPRIGHT", "TOPRIGHT", 2, 2, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, -2, "v" },
  }
  for _, e in ipairs(edges) do
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetPoint(e[1], bar, e[2], e[3], e[4])
    t:SetPoint(e[5], bar, e[6], e[7], e[8])
    if e[9] == "h" then t:SetHeight(2) else t:SetWidth(2) end
    g.textures[#g.textures + 1] = t
  end
  return g
end

-- One glow = the nameplate's border art, tinted, plus a soft additive copy.
local function MakeGlow(holder, bar)
  local base = BorderTexture(holder, bar, "OVERLAY", 6)
  local soft = base and BorderTexture(holder, bar, "OVERLAY", 7)
  if not (base and soft) then return OutlineGlow(holder, bar) end
  soft:SetBlendMode("ADD")
  return { textures = { base, soft }, soft = soft }
end

local function TintGlow(g, c, alpha)
  for _, t in ipairs(g.textures) do
    t:SetDesaturated(true) -- the source art is yellow; strip it so our color shows true
    t:SetVertexColor(c[1], c[2], c[3], alpha)
  end
  if g.soft then g.soft:SetAlpha(alpha * 0.6) end
end

-- A flashing glow: the holder's alpha is controlled by state (or by the client when values
-- are hidden); only the inner frame flashes, so the two never fight each other.
local function MakeFlash(f, bar)
  local holder = CreateFrame("Frame", nil, f)
  holder:SetAllPoints()
  local inner = CreateFrame("Frame", nil, holder)
  inner:SetAllPoints()
  local glow = MakeGlow(inner, bar)
  local anim = inner:CreateAnimationGroup()
  anim:SetLooping("BOUNCE")
  local a = anim:CreateAnimation("Alpha")
  a:SetFromAlpha(1); a:SetToAlpha(0.15); a:SetSmoothing("IN_OUT")
  -- the "!" sits on its own raised layer so the plate's debuff icons can't cover it; still a
  -- child of holder, so it shows and hides with its glow
  local top = CreateFrame("Frame", nil, holder)
  top:SetAllPoints(); top:SetFrameLevel(bar:GetFrameLevel() + TEXT_LEVEL)
  local icon = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  icon:SetPoint("LEFT", bar, "RIGHT", 22, 0)
  icon:SetText("!")
  holder:Hide()
  return { holder = holder, glow = glow, anim = anim, alpha = a, icon = icon }
end

---------------------------------------------------------------------------
-- Hidden threat %: the client can turn a hidden number into a hidden on/off through a
-- "curve" without the addon reading it. Step curve: below the threshold -> 0, at/above -> 1.
-- If this client doesn't support it, ns.curveState becomes "unsupported" and we fall back.
---------------------------------------------------------------------------
local curve, curveAt
ns.curveState = "untested"
local function ThresholdCurve()
  local at = ns.db.unstableAt or 80
  if curve and curveAt == at then return curve end
  if not (C_CurveUtil and C_CurveUtil.CreateCurve) then ns.curveState = "unsupported"; return nil end
  local ok, c = pcall(C_CurveUtil.CreateCurve)
  if not ok or not c then ns.curveState = "unsupported"; return nil end
  if Enum and Enum.LuaCurveType and c.SetType then pcall(c.SetType, c, Enum.LuaCurveType.Step) end
  local ok1 = pcall(c.AddPoint, c, 0, 0)
  local ok2 = pcall(c.AddPoint, c, at, 1)
  if not (ok1 and ok2) then ns.curveState = "unsupported"; return nil end
  curve, curveAt = c, at
  return curve
end

-- Set `frame`'s alpha to 1 when the hidden percentage is at/above the threshold, else 0.
local function GateFromHiddenPct(frame, pct)
  local c = ThresholdCurve()
  if not c then return false end
  local ok, v = pcall(c.Evaluate, c, pct)
  if ok and v ~= nil and pcall(frame.SetAlpha, frame, v) then
    ns.curveState = "works"
    return true
  end
  ns.curveState = "unsupported"
  return false
end

local MAX_GATES = 5 -- party members + pet

local function Create(plate)
  local bar = HealthBarOf(plate)
  local f = CreateFrame("Frame", nil, plate)
  f:SetFrameLevel(bar:GetFrameLevel() + 2) -- just above Blizzard's bar/border

  f:SetAllPoints(bar)

  f.aggro    = MakeFlash(f, bar)  -- stable
  f.unstable = MakeFlash(f, bar)  -- unstable
  f.nothreat = MakeFlash(f, bar)  -- no threat

  -- hidden-value mode: one unstable glow per group member, each switched on by the client
  -- when *that* member's hidden threat % reaches the threshold; all inside a holder that the
  -- client shows only while you're tanking.
  f.hidTank = CreateFrame("Frame", nil, f)
  f.hidTank:SetAllPoints()
  f.gates = {}
  for i = 1, MAX_GATES do
    local gate = CreateFrame("Frame", nil, f.hidTank)
    gate:SetAllPoints()
    local fl = MakeFlash(gate, bar)
    f.gates[i] = { frame = gate, flash = fl }
  end
  f.hidTank:Hide()

  f.top = CreateFrame("Frame", nil, f) -- above the plate's debuff icons
  f.top:SetAllPoints(); f.top:SetFrameLevel(bar:GetFrameLevel() + TEXT_LEVEL)
  f.pct = f.top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.bar = bar


  f.pct:Hide()
  return f
end

local function StyleFlash(fl, c, alpha, speed, showIcon)
  TintGlow(fl.glow, c, alpha)
  fl.icon:SetTextColor(c[1], c[2], c[3])
  fl.icon:SetShown(showIcon)
  if fl.alpha:GetDuration() ~= speed then fl.alpha:SetDuration(speed) end
end

-- the % on the chosen side of the nameplate; the "!" moves further out when they share a side
local function PlaceText(f)
  local db = ns.db
  local side = db.percentSide == "right" and "right" or "left"
  local dx = side == "right" and (db.percentOffsetRight or 40) or (db.percentOffsetLeft or 6)
  local dy = 0
  local afterPct = side == "right" and db.showPercent
  local ix = afterPct and (db.iconGapAfterPct or 6) or (db.iconOffsetX or 22)
  local iy = 0
  local key = side .. dx .. ":" .. dy .. ":" .. tostring(afterPct) .. ix .. ":" .. iy
  if f.placedKey == key then return end
  f.placedKey, f.side = key, side
  f.pct:ClearAllPoints()
  if side == "right" then
    -- default 40: past the level box that sits right of the health bar
    f.pct:SetPoint("LEFT", f.bar, "RIGHT", dx, dy); f.pct:SetJustifyH("LEFT")
  else
    f.pct:SetPoint("RIGHT", f.bar, "LEFT", -dx, dy); f.pct:SetJustifyH("RIGHT")
  end
  -- the "!" sits after the % when they share the right side
  local function placeIcon(icon)
    icon:ClearAllPoints()
    if afterPct then icon:SetPoint("LEFT", f.pct, "RIGHT", ix, iy)
    else icon:SetPoint("LEFT", f.bar, "RIGHT", ix, iy) end
  end
  for _, fl in ipairs({ f.unstable, f.nothreat }) do placeIcon(fl.icon) end
  for _, g in ipairs(f.gates) do placeIcon(g.flash.icon) end
end

-- the glow settings in use: yours as the tank (or your pet's), or yours when you're not the tank
local function Sets(dps)
  local db = ns.db
  if dps then return db.statesDps, db.colorsDps end
  return db.states, db.colors
end

local function Style(f, dps)
  PlaceText(f)
  local db = ns.db
  local st, col = Sets(dps)
  StyleFlash(f.aggro, col.aggro, st.aggro.alpha, st.aggro.speed or 0.5, false)
  StyleFlash(f.unstable, col.unstable, st.unstable.alpha, st.unstable.speed or 0.35, db.showIcon)
  StyleFlash(f.nothreat, col.nothreat, st.nothreat.alpha, st.nothreat.speed or 0.25, db.showIcon)
  for _, g in ipairs(f.gates) do StyleFlash(g.flash, col.unstable, st.unstable.alpha, st.unstable.speed or 0.35, db.showIcon) end
end

-- on: the glow is visible; flashing: it pulses (else it stays steady)
local function ShowFlash(fl, on, flashing)
  fl.holder:SetShown(on)
  local pulse = on and flashing
  if pulse and not fl.anim:IsPlaying() then fl.anim:Play()
  elseif not pulse and fl.anim:IsPlaying() then fl.anim:Stop() end
end

local function HideGates(f)
  f.hidTank:Hide()
  for _, g in ipairs(f.gates) do ShowFlash(g.flash, false) end
end

local function HideAll(f)
  ShowFlash(f.aggro, false); ShowFlash(f.unstable, false); ShowFlash(f.nothreat, false); f.pct:Hide()
  HideGates(f)
end

function V.Render(plate, state)
  if not plate then return end
  local f = indicators[plate]
  if not f then f = Create(plate); indicators[plate] = f end
  local dps = state and state.dps or false
  Style(f, dps)
  local db = ns.db
  local st, col = Sets(dps)
  local kind = state and state.kind or "none"

  f.aggro.holder:SetAlpha(1); f.unstable.holder:SetAlpha(1); f.nothreat.holder:SetAlpha(1)

  if kind == "none" then HideAll(f); return end

  if kind == "hidden" then
    -- Threat values are hidden: the client shows/hides each glow from the hidden
    -- "am I tanking" flag. It can't tell stable from unstable, so tanking = stable here.
    local t = state.isTanking
    ShowFlash(f.unstable, false)
    if dps then
      HideGates(f); f.pct:Hide()
      if f.SetAlphaFromBoolean and (isSecret(t) or t ~= nil) then
        ShowFlash(f.aggro, st.aggro.show, st.aggro.flash)
        f.aggro.holder:SetAlphaFromBoolean(t, 0, 1)
        ShowFlash(f.nothreat, st.nothreat.show, st.nothreat.flash)
        f.nothreat.holder:SetAlphaFromBoolean(t, 1, 0)
      else
        ShowFlash(f.aggro, false); ShowFlash(f.nothreat, false)
      end
      return
    end
    if state.warn and f.SetAlphaFromBoolean and (isSecret(t) or t ~= nil) then
      -- your pet tanks and you're catching up (from the tooltip): orange while your pet has it,
      -- red if it doesn't
      ShowFlash(f.aggro, false)
      ShowFlash(f.unstable, st.unstable.show, st.unstable.flash)
      f.unstable.holder:SetAlphaFromBoolean(t, 1, 0)
      ShowFlash(f.nothreat, st.nothreat.show, st.nothreat.flash)
      f.nothreat.holder:SetAlphaFromBoolean(t, 0, 1)
      HideGates(f)
      if db.showPercent and state.pct then
        local c = col.unstable
        f.pct:SetAlpha(1); f.pct:SetFormattedText("%d%%", Cap(state.pct)); f.pct:SetTextColor(c[1], c[2], c[3]); f.pct:Show()
      else
        f.pct:Hide()
      end
      return
    end
    if f.SetAlphaFromBoolean and (isSecret(t) or t ~= nil) then
      ShowFlash(f.aggro, st.aggro.show, st.aggro.flash)
      f.aggro.holder:SetAlphaFromBoolean(t, 1, 0)
      ShowFlash(f.nothreat, st.nothreat.show, st.nothreat.flash)
      f.nothreat.holder:SetAlphaFromBoolean(t, 0, 1)
      -- (as the tank yourself it's just holding / lost; the old "someone's close" gates are off)
      local others = state.others or {}
      if state.tank == "pet" and st.unstable.show and #others > 0 and ns.curveState ~= "unsupported" then
        f.hidTank:Show()
        f.hidTank:SetAlphaFromBoolean(t, 1, 0)
        for i, g in ipairs(f.gates) do
          local p = others[i]
          if p ~= nil and GateFromHiddenPct(g.frame, p) then ShowFlash(g.flash, true, st.unstable.flash)
          else ShowFlash(g.flash, false) end
        end
      else
        HideGates(f)
      end
    else
      ShowFlash(f.aggro, false); ShowFlash(f.nothreat, false); HideGates(f)
    end
    f.pct:Hide() -- hidden values and no tooltip line: no number to show
    return
  end

  -- readable values: three states
  HideGates(f)
  -- with your pet as the tank, "pulling" means it's on you and your pet is winning it back: still red
  if kind == "pulling" and state.tank == "pet" then kind = "lost" end
  -- you're the tank: just holding it or not
  local meTank = not dps and state.tank == "player"
  if meTank then
    if kind == "insecure" then kind = "secure" elseif kind == "pulling" then kind = "lost" end
  end
  -- unstable: the tank's hold is slipping, or (pulling) it's about to land on the tank
  if kind == "insecure" and not st.unstable.show then kind = "secure" end
  if kind == "pulling" and not st.unstable.show then kind = "lost" end
  local stable   = (kind == "secure")
  local unstable = (kind == "insecure" or kind == "pulling")
  local noThreat = (kind == "lost")
  ShowFlash(f.aggro, stable and st.aggro.show, st.aggro.flash)
  ShowFlash(f.unstable, unstable, st.unstable.flash)
  ShowFlash(f.nothreat, noThreat and st.nothreat.show, st.nothreat.flash)

  -- threat %: yours when you're not the tank; with a pet tanking, how close you are to pulling it
  local pct, color
  if db.showPercent and not meTank then -- the % is for when you're not the tank (or your pet tanks)
    if noThreat then pct, color = state.pct, col.nothreat
    elseif kind == "pulling" then pct, color = state.pct, col.unstable
    elseif unstable then pct, color = state.closest or state.pct, col.unstable
    elseif stable and db.showPercentStable then pct, color = state.closest or state.pct, col.aggro end
  end
  if pct then
    f.pct:SetAlpha(1)
    f.pct:SetFormattedText("%d%%", Cap(pct)); f.pct:SetTextColor(color[1], color[2], color[3]); f.pct:Show()
  else
    f.pct:Hide()
  end
end

function V.Hide(plate)
  local f = plate and indicators[plate]
  if f then HideAll(f) end
end

V.HasSecretSupport = function() return UIParent.SetAlphaFromBoolean ~= nil end
