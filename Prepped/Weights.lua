-- Stat weights the player chooses in place of SimGear's: a preset (data/Weights.lua) or their own.
-- Chosen weights are in attack power units (1 AP = 1), the way sims and spreadsheets give them;
-- Prepped scores in SimGear's points, so they're scaled to SimGear's own worth of one AP. Pure.
local _, ns = ...
local Weights = {}
ns.Weights = Weights

-- The stat both tables weigh that anchors the scale: attack power, else spell or healing power.
local ANCHORS = { "AttackPower", "SpellPower", "HealingPower" }
local function anchor(a, b)
  for _, k in ipairs(ANCHORS) do
    if (a[k] or 0) > 0 and (b[k] or 0) > 0 then return k end
  end
end

-- Your weights in SimGear's points: each times SimGear's anchor weight over yours. A new table.
-- Without a shared anchor they're taken as given.
function Weights.scaled(mine, simgear)
  local k = anchor(mine, simgear)
  local scale = k and simgear[k] / mine[k] or 1
  local out = {}
  for stat, v in pairs(mine) do out[stat] = v * scale end
  return out
end

-- SimGear's weights in attack power units (anchor = 1), to start your own from.
function Weights.inAP(simgear)
  local k
  for _, a in ipairs(ANCHORS) do if (simgear[a] or 0) > 0 then k = a; break end end
  local scale = k and 1 / simgear[k] or 1
  local out = {}
  for stat, v in pairs(simgear) do if v ~= 0 then out[stat] = v * scale end end
  return out
end

-- "agility 2.5" -> "Agility", 2.5: a stat SimGear weighs (any case) and a value of 0 or more.
function Weights.parseEdit(text, simgear)
  local name, num = (text or ""):match("^%s*(%a+)%s+(%S+)%s*$")
  local v = tonumber(num)
  if not (name and v and v >= 0) then return nil end
  for stat in pairs(simgear) do
    if stat:lower() == name:lower() then return stat, v end
  end
  return nil
end

-- The choices for a spec: SimGear's, the spec's presets, then Custom. { id, name }.
function Weights.choices(spec, presets)
  local out = { { id = "simgear", name = "SimGear (simmed)" } }
  for _, p in ipairs(presets and presets[spec] or {}) do out[#out + 1] = { id = p.id, name = p.name } end
  out[#out + 1] = { id = "custom", name = "Custom" }
  return out
end

-- A choice's { id, name, weights (AP units) }, or nil for SimGear's own (also for a choice that
-- no longer exists). custom: { [spec] = weights }; not set yet, Custom starts from SimGear's.
function Weights.resolve(choice, spec, presets, custom, simgear)
  if choice == "custom" then
    return { id = "custom", name = "Custom", weights = custom and custom[spec] or Weights.inAP(simgear) }
  end
  for _, p in ipairs(presets and presets[spec] or {}) do
    if p.id == choice then return p end
  end
  return nil
end

-- Readable stat names for the Custom panel; anything else is split at its capitals.
local LABELS = {
  AttackPower = "Attack power", MeleeCrit = "Crit (per 1%)", MeleeHit = "Hit (per 1%)",
  SpellCrit = "Spell crit (per 1%)", SpellHit = "Spell hit (per 1%)", SpellPower = "Spell power",
  HealingPower = "Healing power", MainHandDps = "Main-hand DPS", OffHandDps = "Off-hand DPS",
  TwoHandDps = "Two-hand DPS", RangedDps = "Ranged DPS", Dodge = "Dodge (per 1%)", Parry = "Parry (per 1%)",
  Block = "Block (per 1%)", Defense = "Defense skill", Mp5 = "Mana per 5 sec",
}
function Weights.label(stat)
  return LABELS[stat] or stat:gsub("(%l)(%u)", "%1 %2")
end

-- The Custom panel's rows: { stat, label, value (yours, AP units; 0 if missing) } for each stat
-- SimGear weighs, biggest SimGear weight first.
function Weights.rows(simgear, mine)
  local out = {}
  for stat, w in pairs(simgear) do
    if w ~= 0 then out[#out + 1] = { stat = stat, label = Weights.label(stat), value = mine[stat] or 0, w = w } end
  end
  table.sort(out, function(a, b) if a.w ~= b.w then return a.w > b.w end return a.stat < b.stat end)
  return out
end

-- One stat typed in the panel: a new table with it set ("" = 0), or nil for a bad number.
function Weights.withValue(weights, stat, text)
  text = (text or ""):match("^%s*(.-)%s*$")
  local v = text == "" and 0 or tonumber(text)
  if not v or v < 0 then return nil end
  local out = {}
  for k, w in pairs(weights) do out[k] = w end
  out[stat] = v
  return out
end
