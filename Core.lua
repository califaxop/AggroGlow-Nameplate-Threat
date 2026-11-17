-- Aggro Glow: shared namespace, settings and helpers.
local ADDON, ns = ...
ns.name = ADDON

ns.isSecret = issecretvalue or function() return false end
function ns.Readable(v) return v ~= nil and not ns.isSecret(v) end

ns.DEFAULTS = {
  -- the three glows: shown or not, flashing or steady, and how strong
  states = {
    aggro    = { show = true, flash = false, alpha = 0.6 },  -- stable: the tank has aggro, safely
    unstable = { show = true, flash = true,  alpha = 0.8 },  -- unstable: someone is close to pulling it
    nothreat = { show = true, flash = true,  alpha = 0.8 },  -- no threat: engaged, but not on the tank
  },
  unstableAt        = 80,    -- unstable once someone has this % of the threat needed to pull it off you
  showIcon          = false, -- "!" while aggro isn't stable
  showPercent       = false, -- threat % beside the nameplate
  showPercentStable = false, -- ...also while aggro is stable
  onlyInGroup       = false, -- only glow while you're in a party or raid (or your pet is the tank)
  tank              = "auto",  -- whose aggro the glows follow: "auto" (your pet when it's out), "me", "pet"
  flashSpeed        = 0.35,  -- seconds per flash (no threat flashes a bit faster, stable a bit slower)
  flareStyle        = true,  -- settings window in FlareUI's style when FlareUI is installed
  colors = {
    aggro    = { 0.35, 1.00, 0.45 },  -- stable
    unstable = { 1.00, 0.50, 0.05 },  -- unstable
    nothreat = { 1.00, 0.15, 0.10 },  -- no threat
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
  local db = AggroGlowDB
  local v = db.version
  if v ~= 3 and v ~= 4 and v ~= 5 then wipe(db) end -- older designs: start fresh
  if v == 3 and db.colors then
    -- 3 -> 4: the old orange "not stable" colour becomes the "unstable" colour; settings kept
    db.colors.unstable = db.colors.unstable or db.colors.loss
    db.colors.loss = nil
  end
  if (v == 3 or v == 4) and db.states == nil then
    -- 4 -> 5: one show / flash / strength setting per glow
    db.states = {
      aggro    = { show = db.showAggroGlow ~= false, flash = false, alpha = db.aggroAlpha or 0.6 },
      unstable = { show = db.showUnstable ~= false, flash = true, alpha = db.glowAlpha or 0.8 },
      nothreat = { show = true, flash = true, alpha = db.glowAlpha or 0.8 },
    }
    db.showAggroGlow, db.showUnstable, db.aggroAlpha, db.glowAlpha = nil, nil, nil, nil
  end
  db.version = 5
  for k, d in pairs(ns.DEFAULTS) do
    if db[k] == nil then db[k] = Copy(d) end
  end
  for _, group in ipairs({ "colors", "states" }) do
    for k, d in pairs(ns.DEFAULTS[group]) do
      if db[group][k] == nil then db[group][k] = Copy(d) end
      if group == "states" then
        for f, x in pairs(d) do if db.states[k][f] == nil then db.states[k][f] = x end end
      end
    end
  end
  ns.db = db
end

function ns.ResetDB()
  wipe(AggroGlowDB)
  ns.LoadDB()
end
