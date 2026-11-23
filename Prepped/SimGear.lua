-- SimGear adapter: reads SimGear Forever's class data (the SimGearForeverData global) into
-- Prepped's shape without writing to it. SimGear's tables share stat pools, so they are
-- referenced, never copied into or modified.
local _, ns = ...
local SimGear = {}
ns.SimGear = SimGear

-- global: SimGearForeverData; class: "DRUID", "WARRIOR"...
-- Returns { items, specs, enchants, setBonusSims, itemEffects, generated } or nil, reason.
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
    itemEffects = c.itemEffects,
    generated = isTable(c.weights.meta) and c.weights.meta.generated or nil,
  }
end
