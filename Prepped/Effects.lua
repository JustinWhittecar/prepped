-- Item effects SimGear doesn't value (bear has no simmed trinkets at all): Prepped's override table
-- (data/Overrides.lua), turned into SimGear's points for one spec. Pure.
local _, ns = ...
local Effects = {}
ns.Effects = Effects

-- One override's points for a spec. entry: ap ({[spec] = attack power equivalent}), stats (counted
-- for every spec, e.g. an on-use averaged), drop ({[stat] = true}: stats the item lists that don't
-- count). ws: the spec's SimGear weights; itemStats: the item's own stats; score: stats -> points.
function Effects.value(entry, spec, ws, itemStats, score)
  local v = 0
  local ap = entry.ap and entry.ap[spec]
  if ap then v = v + ap * (ws.AttackPower or 0) end
  if entry.stats then v = v + score(entry.stats) end
  if entry.drop then
    local dropped = {}
    for k in pairs(entry.drop) do dropped[k] = itemStats and itemStats[k] end
    v = v - score(dropped)
  end
  return v
end

-- A spec's effects: SimGear's, plus an override's value for each item SimGear has none for.
-- A new table; items: {[id] = {stats}} for the dropped stats.
function Effects.merge(simgear, overrides, spec, ws, items, score)
  local out = {}
  for id, v in pairs(simgear or {}) do out[id] = v end
  for id, entry in pairs(overrides or {}) do
    if out[id] == nil then
      local item = items and items[id]
      local v = Effects.value(entry, spec, ws, item and item.stats, score)
      if v ~= 0 then out[id] = v end
    end
  end
  return out
end
