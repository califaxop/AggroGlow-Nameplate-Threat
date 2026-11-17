-- Aggro Glow: shared namespace, settings and helpers.
local ADDON, ns = ...
ns.name = ADDON

ns.isSecret = issecretvalue or function() return false end
function ns.Readable(v) return v ~= nil and not ns.isSecret(v) end

ns.DEFAULTS = {
  glowAlpha     = 0.8,   -- strength of the flashing glows (unstable / no threat)
  aggroAlpha    = 0.6,   -- strength of the steady "stable aggro" glow
  showAggroGlow = true,  -- steady glow on enemies you hold securely
  showUnstable  = true,  -- separate flashing glow while your aggro is unstable
  unstableAt    = 80,    -- unstable once someone has this % of the threat needed to pull it off you
  showIcon      = false, -- "!" while your aggro isn't stable
  showPercent   = false, -- your threat % beside the nameplate
  onlyInGroup   = false, -- only glow while you're in a party or raid (or your pet is the tank)
  tank          = "auto",  -- whose aggro the glows follow: "auto" (your pet when it's out), "me", "pet"
  flashSpeed    = 0.35,  -- seconds per flash (no threat flashes a bit faster)
  colors = {
    aggro    = { 0.35, 1.00, 0.45 },  -- stable: you have aggro, safely
    unstable = { 1.00, 0.50, 0.05 },  -- unstable: you have aggro, someone is close
    nothreat = { 1.00, 0.15, 0.10 },  -- no threat: engaged, but it isn't on you
  },
}

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end
ns.Copy = Copy

ns.debug = false
function ns.Print(...) print("|cffff7744Aggro Glow:|r", ...) end
function ns.Dbg(...) if ns.debug then print("|cffff7744AG|r", ...) end end

function ns.LoadDB()
  AggroGlowDB = AggroGlowDB or {}
  local v = AggroGlowDB.version
  if v ~= 3 and v ~= 4 then wipe(AggroGlowDB) end -- older designs: start fresh
  if v == 3 and AggroGlowDB.colors then
    -- 3 -> 4: the old orange "not stable" colour becomes the "unstable" colour; settings kept
    AggroGlowDB.colors.unstable = AggroGlowDB.colors.unstable or AggroGlowDB.colors.loss
    AggroGlowDB.colors.loss = nil
  end
  AggroGlowDB.version = 4
  for k, v in pairs(ns.DEFAULTS) do
    if AggroGlowDB[k] == nil then AggroGlowDB[k] = Copy(v) end
  end
  for k, v in pairs(ns.DEFAULTS.colors) do
    if AggroGlowDB.colors[k] == nil then AggroGlowDB.colors[k] = Copy(v) end
  end
  ns.db = AggroGlowDB
end

function ns.ResetDB()
  wipe(AggroGlowDB)
  ns.LoadDB()
end
