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
  if ns.db.onlyInGroup and not IsInGroup() and S.TankUnit() ~= "pet" and not ns.preview then st = { kind = "none" } end
  -- Preview mode: show a look ("secure" or "lost") on your target's nameplate.
  if ns.preview then
    local isTarget = UnitIsUnit(unit, "target")
    if ns.Readable(isTarget) and isTarget then st = { kind = ns.preview, pct = 42 } end
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
local TOGGLES = { icon = "showIcon", percent = "showPercent", aggro = "showAggroGlow" }

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
  elseif cmd == "alpha" and tonumber(arg) then
    db.glowAlpha = math.max(0.1, math.min(1, tonumber(arg))); ns.Print("glow strength " .. db.glowAlpha)
  elseif cmd == "debug" then
    ns.debug = not ns.debug
    ns.Print("debug " .. (ns.debug and "ON" or "OFF"))
    if ns.debug then
      local function show(v) return ns.isSecret(v) and "<hidden>" or tostring(v) end
      local n = 0
      local tank = S.TankUnit()
      ns.Dbg("following:", tank == "pet" and "your pet" or tank == "player" and "you" or "nobody (no pet out)")
      for unit in R.Each() do
        n = n + 1
        local t, s, p = UnitDetailedThreatSituation(tank or "player", unit)
        local st = S.Get(unit)
        ns.Dbg(unit, "isTanking=" .. show(t), "status=" .. show(s), "pct=" .. show(p),
          "-> " .. (st and st.kind or "?"))
      end
      ns.Dbg("nameplates tracked:", n, "| client can show hidden values:",
        V.HasSecretSupport() and "yes" or "no",
        "| hidden threat % checks:", ns.curveState)
    end
  else
    ns.Print("/ag (settings)  -  /ag icon | percent | aggro  -  /ag alpha <0.1-1>  -  /ag debug")
    return
  end
  UpdateAll()
end
