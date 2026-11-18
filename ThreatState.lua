-- Threat State: reads the client's native threat info for each unit and tracks transitions.
--
-- Native API (values may be hidden by the client in some content):
--   UnitDetailedThreatSituation("player", unit) -> isTanking, status, scaledPercent
--   UnitThreatSituation(groupUnit, unit)        -> status or nil (nil = not on its threat list)
-- status: 0 = not tanking, lower threat   1 = not tanking, higher threat (about to pull)
--         2 = tanking, someone is close    3 = tanking securely
local _, ns = ...
local S = {}
ns.State = S

local isSecret, Readable = ns.isSecret, ns.Readable
local states = {}           -- unit -> last state
S.onTransition = nil        -- function(unit, old, new)

local function GroupUnits()
  local list = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do list[#list + 1] = "raid" .. i end
  elseif IsInGroup() then
    for i = 1, GetNumSubgroupMembers() do list[#list + 1] = "party" .. i end
  end
  return list
end

local function PetOut()
  local e = UnitExists("pet")
  if not Readable(e) or not e then return false end
  local dead = UnitIsDead("pet")
  return not (Readable(dead) and dead)
end

-- Whose aggro the glows follow: you, or your pet (setting "tank").
function S.TankUnit()
  local t = ns.db.tank or "auto"
  if t == "me" then return "player" end
  if t == "pet" then return PetOut() and "pet" or nil end
  return PetOut() and "pet" or "player"
end

-- Are you the tank? "tank" / "dps" as set, or on "auto": your group-finder role in a group (your
-- spec's role if none is assigned), and the tank when you're solo (enemies come to you anyway).
function S.IsTankRole()
  local r = ns.db.role or "auto"
  if r == "tank" then return true end
  if r == "dps" then return false end
  if not (IsInGroup and IsInGroup()) then return true end
  local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
  if role == "TANK" then return true end
  if role == "DAMAGER" or role == "HEALER" then return false end
  local ok, spec = pcall(function() return GetSpecialization and GetSpecialization() end)
  if ok and spec then
    local okR, sr = pcall(GetSpecializationRole, spec)
    if okR and sr then return sr == "TANK" end
  end
  return true
end

-- Which glows to show: "pet" (your pet's aggro), "tank" (yours, as the tank) or "dps" (yours, as
-- someone who doesn't want it). On Auto your pet counts unless you're in a group as a non-tank.
function S.Mode()
  local t = ns.db.tank or "auto"
  if t == "pet" then return "pet" end
  local tankRole = S.IsTankRole()
  if t == "auto" and PetOut() and (tankRole or not (IsInGroup and IsInGroup())) then return "pet" end
  return tankRole and "tank" or "dps"
end

-- Everyone else whose threat could pull an enemy off the tank: you, your pet, your group.
local function Others(tank)
  local list = GroupUnits()
  if tank ~= "player" then list[#list + 1] = "player" end
  if tank ~= "pet" and PetOut() then list[#list + 1] = "pet" end
  return list
end

-- Returns a state table (from the tank's point of view - you or your pet):
--   kind = "none"      not engaged with the tank, you or your group
--        | "secure"    the tank has aggro, safely
--        | "insecure"  the tank has aggro, someone is close
--        | "pulling"   the tank doesn't, but is about to
--        | "lost"      engaged, the tank doesn't have aggro
--        | "hidden"    the client hides the values; .isTanking may be a hidden boolean
--   pct  = the tank's threat % (number) when readable;  tank = "player" / "pet"
-- Highest threat anyone else has on `unit`, as % of what they'd need to pull it (100 = pulls).
-- Readable values only; hidden ones are returned separately for the client to evaluate.
local function OthersThreat(unit, tank)
  local best, hidden = nil, {}
  for _, g in ipairs(Others(tank)) do
    local _, _, p = UnitDetailedThreatSituation(g, unit)
    if isSecret(p) then hidden[#hidden + 1] = p
    elseif p and (not best or p > best) then best = p end
  end
  return best, hidden
end

-- Your threat % on a unit, read from the threat line Blizzard puts in its tooltip ("85% Threat").
-- The game hides threat values from addons in combat, but this tooltip line stays readable.
-- Cached briefly per unit: building a tooltip on every refresh would be wasteful.
local tipCache = {}
local TIP_TTL = 0.3
function S.TooltipPct(unit)
  if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
  local now = GetTime()
  local c = tipCache[unit]
  if c and now - c.t < TIP_TTL then return c.pct end
  local pct
  local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
  if ok and type(data) == "table" and not isSecret(data) then
    for _, l in ipairs(data.lines or {}) do
      local okT, t = pcall(function() return l.leftText end)
      if okT and type(t) == "string" and not isSecret(t) then
        local n = t:match("^%s*(%d+)%%")
        if n then pct = tonumber(n) end
      end
    end
  end
  tipCache[unit] = { t = now, pct = pct }
  return pct
end
function S.ForgetTooltip(unit) tipCache[unit] = nil end

-- Not the tank: your own threat, read the other way round.
--   secure   = safe: it's on someone else and you're well below them   (green by default)
--   insecure = close: you're at or above the warning % of pulling it  (orange)
--   lost     = on you: you pulled it                                   (red)
local function EvaluateDps(unit)
  local warn = ns.db.unstableAt or 80
  local isTanking, status, pct = UnitDetailedThreatSituation("player", unit)
  if isSecret(isTanking) or isSecret(status) then
    local tp = S.TooltipPct(unit)
    if tp then
      if tp >= 100 then return { kind = "lost", pct = tp, dps = true, via = "tooltip" } end
      if tp >= warn then return { kind = "insecure", pct = tp, dps = true, via = "tooltip" } end
      return { kind = "secure", pct = tp, dps = true, via = "tooltip" }
    end
    return { kind = "hidden", isTanking = isTanking, dps = true }
  end
  pct = Readable(pct) and pct or nil
  if status == 3 or status == 2 then return { kind = "lost", pct = pct, dps = true } end
  if status == 1 or (pct and pct >= warn) then return { kind = "insecure", pct = pct, dps = true } end
  if status ~= nil then return { kind = "secure", pct = pct, dps = true } end
  -- not on your threat list: fighting your group (it's on someone else)?
  local others = GroupUnits()
  if PetOut() then others[#others + 1] = "pet" end
  for _, g in ipairs(others) do
    local s2 = UnitThreatSituation(g, unit)
    if isSecret(s2) or s2 ~= nil then return { kind = "secure", pct = 0, dps = true } end
  end
  return { kind = "none" }
end

local function Evaluate(unit)
  if not UnitExists(unit) then return { kind = "none" } end
  local canAttack = UnitCanAttack("player", unit)
  if Readable(canAttack) and not canAttack then return { kind = "none" } end
  local dead = UnitIsDead(unit)
  if Readable(dead) and dead then return { kind = "none" } end

  local mode = S.Mode()
  if mode == "dps" then return EvaluateDps(unit) end
  local tank = (mode == "pet") and (PetOut() and "pet" or nil) or "player"
  if not tank then return { kind = "none" } end -- "My pet" chosen, but no pet out

  local isTanking, status, pct = UnitDetailedThreatSituation(tank, unit)
  if isSecret(isTanking) or isSecret(status) then
    -- Hidden values. When the glows follow you, the tooltip's threat line still says how much
    -- threat you have: 100% = it's on you; below that, how close you are to pulling it.
    -- (It can't tell "someone's about to take it from you": it only knows your own threat.)
    if tank == "player" then
      local tp = S.TooltipPct(unit)
      if tp then
        if tp >= 100 then return { kind = "secure", pct = 100, tank = tank, via = "tooltip" } end
        if tp >= (ns.db.unstableAt or 80) then return { kind = "pulling", pct = tp, tank = tank, via = "tooltip" } end
        return { kind = "lost", pct = tp, tank = tank, via = "tooltip" }
      end
    end
    -- Your pet tanks: the tooltip's threat line is YOUR threat, i.e. how close you are to pulling
    -- it off your pet. 100% = it's on you (red); at the warning % = you're catching up (orange
    -- while your pet still has it); below that, the hidden "pet is tanking" flag decides.
    local _, others = OthersThreat(unit, tank)
    if tank == "pet" then
      local tp = S.TooltipPct(unit)
      if tp and tp >= 100 then return { kind = "lost", pct = tp, tank = tank, via = "tooltip" } end
      if tp and tp >= (ns.db.unstableAt or 80) then
        return { kind = "hidden", isTanking = isTanking, others = others, tank = tank, warn = true, pct = tp, via = "tooltip" }
      end
    end
    return { kind = "hidden", isTanking = isTanking, others = others, tank = tank }
  end
  pct = Readable(pct) and pct or nil

  if status ~= nil then
    if status == 3 or status == 2 then
      -- The tank has aggro. It's unstable if the game says so, or anyone else is at or above
      -- the "unstable" threshold of pulling it off the tank.
      local closest = OthersThreat(unit, tank)
      local unstable = status == 2 or (closest and closest >= (ns.db.unstableAt or 80))
      return { kind = unstable and "insecure" or "secure", pct = pct, closest = closest, tank = tank }
    end
    if status == 1 then return { kind = "pulling", pct = pct, tank = tank } end
    -- not on the tank yet, but close to the warning threshold of pulling it
    if pct and pct >= (ns.db.unstableAt or 80) then return { kind = "pulling", pct = pct, tank = tank } end
    return { kind = "lost", pct = pct, tank = tank }
  end

  -- Not on the tank's threat list: is it fighting anyone else (you, your pet, your group)?
  for _, g in ipairs(Others(tank)) do
    local s = UnitThreatSituation(g, unit)
    if isSecret(s) then return { kind = "hidden", isTanking = false, tank = tank } end
    if s ~= nil then return { kind = "lost", pct = 0, tank = tank } end
  end
  return { kind = "none" }
end

local HAS_AGGRO = { secure = true, insecure = true }

function S.Update(unit)
  local new = Evaluate(unit)
  local old = states[unit]
  states[unit] = new
  if S.onTransition and old and old.kind ~= new.kind then
    S.onTransition(unit, old, new, HAS_AGGRO[old.kind] and not HAS_AGGRO[new.kind] and new.kind ~= "none")
  end
  return new
end

function S.Get(unit) return states[unit] end
function S.Clear(unit) states[unit] = nil end
