-- SimGear adapter: reads SimGear Forever's class data (the SimGearForeverData global) into
-- Prepped's shape without writing to it. SimGear's tables share stat pools, so they are
-- referenced, never copied into or modified.
local _, ns = ...
local SimGear = {}
ns.SimGear = SimGear

-- global: SimGearForeverData; class: "DRUID", "WARRIOR"...
-- Returns { items, specs, enchants, setBonusSims, sets, itemEffects, generated } or nil, reason.
local function isTable(v) return type(v) == "table" end

-- Checks shape, not version numbers: the reason names the first thing that doesn't fit.
local function shapeProblem(global, class)
  if not isTable(global) then return "SimGearForeverData missing (SimGear not installed)" end
  local c = global[class]
  if not isTable(c) then return "no " .. class .. " data (class addon not loaded)" end
  if not (isTable(c.items) and isTable(c.items.items)) then return "items not under items.items" end
  if not (isTable(c.weights) and isTable(c.weights.sets)) then return "weights not under weights.sets" end
  for spec, sets in pairs(c.weights.sets) do
    if not isTable(sets) then return spec .. " weight sets not a list" end
    for i, set in ipairs(sets) do
      if not (isTable(set) and isTable(set.weights) and isTable(set.source)) then
        return spec .. " set " .. i .. " lacks weights or source"
      end
    end
  end
end

function SimGear.load(global, class)
  local problem = shapeProblem(global, class)
  if problem then return nil, problem end
  local c = global[class]
  return {
    items = c.items.items,
    specs = c.weights.sets,
    enchants = c.enchants,
    setBonusSims = c.setBonusSims,
    sets = isTable(c.extras) and isTable(c.extras.sets) and c.extras.sets or nil,
    itemEffects = c.itemEffects,
    generated = isTable(c.weights.meta) and c.weights.meta.generated or nil,
  }
end

-- SimGear's item sets (its extras' sets: { [setID] = { name, items = {ids}, bonuses = { {n, stats,
-- unscored} } } }) in Bis's shape for one weight set: { [setID] = { name, items = {[id] = true},
-- bonuses = { {count, points} } } }. A bonus is worth its simmed value where SimGear has one (sims:
-- { [setID] = { [n] = {v, se} } }, setSims' result), in place of its stats, as Score.setBonusValue
-- does; else value(stats). Bonuses worth nothing, and sets with none left, are left out.
function SimGear.setBonuses(bySet, sims, value)
  local out = {}
  for setID, set in pairs(bySet or {}) do
    local bonuses, simmed = {}, sims and sims[setID]
    for _, b in ipairs(set.bonuses or {}) do
      local s = simmed and simmed[b.n]
      local pts = type(s) == "table" and type(s.v) == "number" and s.v or value(b.stats or {})
      if pts > 0 then bonuses[#bonuses + 1] = { count = b.n, points = pts } end
    end
    if #bonuses > 0 then
      local items = {}
      for _, id in ipairs(set.items or {}) do items[id] = true end
      out[setID] = { name = set.name, items = items, bonuses = bonuses }
    end
  end
  return out
end

-- The set sims for one weight set: those simmed at its level for its spec, as SimGear's
-- Data.attachSetBonuses picks them. raw: the class's setBonusSims; key: the spec's key in weights.sets.
function SimGear.setSims(raw, weightSet, key)
  local src = type(weightSet) == "table" and weightSet.source
  local byLevel = type(raw) == "table" and type(src) == "table" and src.kind == "sim" and raw[src.maxLevel]
  return type(byLevel) == "table" and byLevel[weightSet.spec or key] or nil
end
