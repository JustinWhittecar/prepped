-- Item effects SimGear doesn't value (bear has no simmed trinkets at all): Prepped's override table
-- (data/Overrides.lua), turned into SimGear's points for one spec. Pure.
local _, ns = ...
local Effects = {}
ns.Effects = Effects

-- One override's points for a spec. entry: ap ({[spec] = attack power equivalent}), stats (counted
-- for every spec, e.g. an on-use averaged), specStats ({[spec] = stats}: one spec only), drop ({[stat] = true}: stats the item lists that don't
-- count). ws: the spec's SimGear weights; itemStats: the item's own stats; score: stats -> points.
function Effects.value(entry, spec, ws, itemStats, score)
  local v = 0
  local ap = entry.ap and entry.ap[spec]
  if ap then v = v + ap * (ws.AttackPower or 0) end
  if entry.stats then v = v + score(entry.stats) end
  local own = entry.specStats and entry.specStats[spec]
  if own then v = v + score(own) end
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

-- A weight set's set bonus sims ({ [setID] = { [n] = {v} } }, SimGear.setSims' result) with
-- Prepped's overrides ({ [setID] = { [n] = { ap = {[spec] = AP equivalent} } } }) in place of
-- SimGear's values for the specs they name. A new table; SimGear's is never written.
function Effects.setSims(sims, overrides, spec, ws)
  local out = {}
  for setID, bonuses in pairs(sims or {}) do
    out[setID] = {}
    for n, e in pairs(bonuses) do out[setID][n] = e end
  end
  for setID, bonuses in pairs(overrides or {}) do
    for n, entry in pairs(bonuses) do
      local ap = entry.ap and entry.ap[spec]
      if ap then
        out[setID] = out[setID] or {}
        out[setID][n] = { v = ap * (ws.AttackPower or 0), override = true }
      end
    end
  end
  return out
end
