-- Threat Detection Engine: listens to native threat + nameplate events and drives
-- Registry -> State -> Renderer.
local _, ns = ...
local R, S, V = ns.Registry, ns.State, ns.Renderer


local function UpdateUnit(unit)
  local plate = R.Get(unit)
  if not plate then return end
  local st = S.Update(unit)
  -- "Only show in a party or raid": solo, nothing glows (preview still works)
  -- (your pet tanking counts too: that's usually solo)
  if ns.db.onlyInGroup and not IsInGroup() and S.Mode() ~= "pet" and not ns.preview then st = { kind = "none" } end
  -- Preview mode: show a look ("secure" or "lost") on your target's nameplate.
  if ns.preview then
    local isTarget = UnitIsUnit(unit, "target")
    if ns.Readable(isTarget) and isTarget then st = { kind = ns.preview, pct = 42, closest = (ns.preview == "secure") and 35 or 86 } end
  end
  V.Render(plate, st)
end

local function UpdateAll()
  for unit in R.Each() do UpdateUnit(unit) end
end
ns.UpdateAll = UpdateAll

S.onTransition = function(unit, old, new)
  ns.Dbg(unit, old.kind, "->", new.kind)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "ADDON_LOADED" then
    if unit ~= ns.name then return end
    ns.LoadDB(); R.Scan(); ns.CreateOptions()
    for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
      "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
      "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE",
      "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_PET" }) do
      ev:RegisterEvent(e)
    end
    C_Timer.NewTicker(0.25, UpdateAll) -- safety net for missed updates
    ns.Print("loaded. Type |cffffff00/ag|r for commands.")
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    R.Add(unit); UpdateUnit(unit)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    V.Hide(R.Remove(unit)); S.Clear(unit)
  elseif event == "UNIT_THREAT_LIST_UPDATE" and unit and R.Get(unit) then
    UpdateUnit(unit)
  elseif event == "PLAYER_ENTERING_WORLD" then
    R.Scan(); UpdateAll()
  else
    UpdateAll()
  end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local TOGGLES = { icon = "showIcon", percent = "showPercent" }

SLASH_AGGROGLOW1 = "/ag"
SLASH_AGGROGLOW2 = "/aggroglow"
SlashCmdList.AGGROGLOW = function(msg)
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  local db = ns.db
  if cmd == "" or cmd == "config" or cmd == "options" then
    local ok, e = pcall(ns.OpenOptions)
    if not ok then ns.Print("settings error: " .. tostring(e)) end
    return
  elseif TOGGLES[cmd] then
    db[TOGGLES[cmd]] = not db[TOGGLES[cmd]]
    ns.Print(cmd .. " " .. (db[TOGGLES[cmd]] and "on" or "off"))
  elseif cmd == "aggro" then
    db.states.aggro.show = not db.states.aggro.show
    ns.Print("stable glow " .. (db.states.aggro.show and "on" or "off"))
  elseif cmd == "tip" then
    -- can an addon read the threat line Blizzard puts in unit tooltips? (data API, and the tooltip on screen)
    local sec = ns.isSecret
    local function show(v) if sec(v) then return "hidden" end return tostring(v) end
    ns.Print("tooltip probe (" .. (InCombatLockdown() and "in combat" or "out of combat") .. "):")
    local function lineHasThreat(t) return type(t) == "string" and (t:find("%%") or t:lower():find("threat")) end
    for _, unit in ipairs({ "target", "mouseover", "nameplate1", "nameplate2" }) do
      if UnitExists(unit) then
        if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then print("  data API: not in this client"); break end
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if not ok then print("  " .. unit .. ": refused (" .. tostring(data) .. ")")
        elseif data == nil then print("  " .. unit .. ": no data")
        elseif sec(data) then print("  " .. unit .. ": hidden")
        else
          local lines, found = data.lines or {}, nil
          for i, l in ipairs(lines) do
            local okT, t = pcall(function() return l.leftText end)
            local okR, r = pcall(function() return l.rightText end)
            if (okT and sec(t)) or (okR and sec(r)) then found = found or ("line " .. i .. " hidden") end
            if okT and not sec(t) and lineHasThreat(t) then found = "line " .. i .. ": " .. t .. (okR and r and (" | " .. show(r)) or "") end
            if okR and not sec(r) and lineHasThreat(r) then found = "line " .. i .. ": " .. show(t) .. " | " .. r end
          end
          print(format("  %s: %d line(s), threat line: %s", unit, #lines, found or "none found"))
        end
      end
    end
    -- the tooltip on screen (hover an enemy while typing this, or bind it to a macro)
    if GameTooltip and GameTooltip:IsShown() then
      for i = 1, GameTooltip:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
          local fs = _G["GameTooltipText" .. side .. i]
          local ok, t = pcall(function() return fs and fs:GetText() end)
          if ok and (sec(t) or lineHasThreat(t)) then print(format("  on screen, line %d (%s): %s", i, side:lower(), show(t))) end
        end
      end
    else
      print("  on screen: no tooltip shown (make a macro with /ag tip and press it while hovering an enemy)")
    end
    return
  elseif cmd == "debug" then
    ns.debug = not ns.debug
    ns.Print("debug " .. (ns.debug and "ON" or "OFF"))
    if ns.debug then
      local function show(v) return ns.isSecret(v) and "<hidden>" or tostring(v) end
      local n = 0
      local tank = S.TankUnit()
      local mode = S.Mode()
      ns.Dbg("following:", tank == "pet" and "your pet" or tank == "player" and "you" or "nobody (no pet out)",
        "| glows:", mode == "pet" and "your pet's aggro" or mode == "dps" and "you, not the tank" or "you, the tank",
        "| role:", S.Role(true) or "not set")
      for unit in R.Each() do
        n = n + 1
        local t, s, p = UnitDetailedThreatSituation(tank or "player", unit)
        local st = S.Get(unit)
        ns.Dbg(unit, "isTanking=" .. show(t), "status=" .. show(s), "pct=" .. show(p),
          "tooltip=" .. tostring(S.TooltipPct and S.TooltipPct(unit) or "none"),
          "-> " .. (st and st.kind or "?") .. (st and st.via and (" (from " .. st.via .. ")") or ""))
        local plate = R.Get(unit)
        local okI, info = pcall(V.TextInfo, plate)
        ns.Dbg("   ", okI and info or ("text check failed: " .. tostring(info)))
      end
      ns.Dbg("nameplates tracked:", n, "| client can show hidden values:",
        V.HasSecretSupport() and "yes" or "no",
        "| hidden threat % checks:", ns.curveState)
    end
  else
    ns.Print("/ag (settings)  -  /ag icon | percent | aggro  -  /ag debug")
    return
  end
  UpdateAll()
end
