-- The pure part of tools/build_backup.lua: which of SimGear's class data the backup copy keeps,
-- and writing it back out as Lua. Tested in test/backup_test.lua.
local L = {}

local LEVEL = 60
-- A level-60 candidate is gear for a slot BiS fills, wearable at 60 (required level 60 or less), and
-- either at the item level floor or among the best DEPTH for its slot under some spec's level-60
-- weights. The floor keeps the depth the filters (reputation, profession, PvP, the other side) and
-- chosen weights need; the ranking keeps the few low-level items that still win, such as Forever's
-- item level 10 Totem of Charged Flames and Stormcloth Vest (45). Checked against live data for every
-- class and spec (test/backup_test.lua). Sources aren't checked: Prepped adds vendor, reputation and
-- harvested ones at run time (Core).
L.ILVL_FLOOR = 50
L.DEPTH = 25

-- Equip location -> the group it competes in (one per inventory slot, chest and robe together;
-- weapons by hand). Shirts, tabards, bags and ammo never score, and a worn one SimGear lacks is read
-- from the game's stats anyway.
local GROUP = {}
for _, s in ipairs({ "HEAD", "NECK", "SHOULDER", "CHEST", "WAIST", "LEGS", "FEET", "WRIST", "HAND", "CLOAK",
  "FINGER", "TRINKET", "2HWEAPON" }) do GROUP["INVTYPE_" .. s] = s end
GROUP.INVTYPE_ROBE = "CHEST"
for _, s in ipairs({ "RANGED", "RANGEDRIGHT", "THROWN", "RELIC" }) do GROUP["INVTYPE_" .. s] = "RANGED" end
for _, s in ipairs({ "WEAPON", "WEAPONMAINHAND" }) do GROUP["INVTYPE_" .. s] = "MAINHAND" end
for _, s in ipairs({ "SHIELD", "HOLDABLE", "WEAPONOFFHAND" }) do GROUP["INVTYPE_" .. s] = "OFFHAND" end

local function wearable(item)
  return GROUP[item.slot] ~= nil and (item.req or 0) <= LEVEL
end

-- Without rankings: the floor alone.
function L.keepItem(item)
  return wearable(item) and (item.ilvl or 0) >= L.ILVL_FLOOR
end

local function byLevel(t, levels)
  if type(t) ~= "table" then return nil end
  local out = {}
  for level in pairs(levels) do out[level] = t[level] end
  return out
end

-- A weight set with its simmed item effects layered on, as Core.weightSetFor scores with.
local function withEffects(set, itemEffects, spec)
  local src = set.source
  local byLvl = src.kind == "sim" and type(itemEffects) == "table" and itemEffects[src.maxLevel]
  local sims = type(byLvl) == "table" and byLvl[set.spec or spec]
  local effects = {}
  for id, v in pairs(set.effects or {}) do effects[id] = v end
  for id, e in pairs(type(sims) == "table" and sims or {}) do
    if type(e) == "table" and type(e.v) == "number" and effects[id] == nil then effects[id] = e.v end
  end
  return setmetatable({ effects = effects }, { __index = set })
end

-- IDs among the best DEPTH of each group under one weight set (a one-hander also as an off hand).
local function topIDs(items, ws, Score, keep)
  local groups = {}
  local function add(group, id, points)
    local g = groups[group] or {}
    groups[group] = g
    g[#g + 1] = { id = id, points = points }
  end
  for id, item in pairs(items) do
    local effect = Score.effectOf(id, ws)
    add(GROUP[item.slot], id, Score.value(item.stats, ws) + effect)
    if item.slot == "INVTYPE_WEAPON" then add("OFFHAND", id, Score.value(Score.inOffHand(item).stats, ws) + effect) end
  end
  for _, g in pairs(groups) do
    table.sort(g, function(a, b) if a.points ~= b.points then return a.points > b.points end return a.id < b.id end)
    -- Ties at the cut stay in: BiS picks among equals in table order.
    local cut = g[math.min(L.DEPTH, #g)].points
    for _, c in ipairs(g) do
      if c.points < cut then break end
      keep[c.id] = true
    end
  end
end

-- c: one class's SimGearForeverData entry; Score: SimGear's (pickSet, value, effectOf, inOffHand);
-- stamp: { built, simgearVersion, ... }. Returns a new table in the same shape (SimGear.load reads it
-- unchanged) holding what Prepped reads: the candidates, each spec's level-60 weight set, the
-- enchant, item effect and set bonus sims at the levels those sets were simmed on, and the extras
-- SimGear.load exposes. c is left untouched.
function L.trim(c, Score, stamp)
  local sets, levels = {}, {}
  for spec, list in pairs(c.weights.sets) do
    local set = Score.pickSet(list, LEVEL)
    if set then
      sets[spec] = { set }
      if set.source.maxLevel then levels[set.source.maxLevel] = true end
    end
  end
  local gear, keep = {}, {}
  for id, item in pairs(c.items.items) do
    if wearable(item) then
      gear[id] = item
      if L.keepItem(item) then keep[id] = true end
    end
  end
  for spec, list in pairs(sets) do topIDs(gear, withEffects(list[1], c.itemEffects, spec), Score, keep) end
  local items = {}
  for id in pairs(keep) do items[id] = gear[id] end
  local x = type(c.extras) == "table" and c.extras or {}
  local tradable
  if type(x.tradable) == "table" then
    tradable = {}
    for _, id in ipairs(x.tradable) do if items[id] then tradable[#tradable + 1] = id end end
  end
  return {
    items = { items = items },
    weights = { meta = c.weights.meta, sets = sets },
    enchants = byLevel(c.enchants, levels),
    itemEffects = byLevel(c.itemEffects, levels),
    setBonusSims = byLevel(c.setBonusSims, levels),
    -- reps stays whole: it's keyed by recipe as well as item (SimGear.repCrafts).
    extras = { sets = x.sets, reps = x.reps, factions = x.factions, tradable = tradable },
    snapshot = stamp,
  }
end

-- Lua source ------------------------------------------------------------------------------------------
local KEYWORDS = {}
for w in ("and break do else elseif end false for function if in local nil not or repeat return then true until while"):gmatch("%a+") do
  KEYWORDS[w] = true
end

local function number(n)
  if n ~= n or n == math.huge or n == -math.huge then error("can't write " .. tostring(n)) end
  if n == math.floor(n) and math.abs(n) < 2 ^ 53 then return string.format("%d", n) end
  for digits = 14, 17 do
    local s = string.format("%." .. digits .. "g", n)
    if tonumber(s) == n then return s end
  end
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end -- numbers before strings
    return a < b
  end)
  return keys
end

-- v as a Lua expression. Tables nested less than `breaks` deep put one entry per line (so a file
-- of items has one item per line); deeper ones stay on one line. Keys in a fixed order, so the same
-- data always writes the same text. Tables SimGear shares are written out at each use.
function L.serialize(v, breaks, depth, seen)
  local tv = type(v)
  if tv == "number" then return number(v) end
  if tv == "string" then return (string.format("%q", v):gsub("\\\n", "\\n")) end
  if tv == "boolean" then return tostring(v) end
  if tv ~= "table" then error("can't write a " .. tv) end
  breaks, depth, seen = breaks or 0, depth or 0, seen or {}
  if seen[v] then error("cycle in table") end
  seen[v] = true
  local n = 0 -- the list part: 1..n with no holes (# is undefined with holes)
  while v[n + 1] ~= nil do n = n + 1 end
  local parts = {}
  for i = 1, n do parts[i] = L.serialize(v[i], breaks, depth + 1, seen) end
  for _, k in ipairs(sortedKeys(v)) do
    if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
      local key
      if type(k) == "string" and k:match("^[%a_][%w_]*$") and not KEYWORDS[k] then key = k
      else key = "[" .. L.serialize(k) .. "]" end
      parts[#parts + 1] = key .. " = " .. L.serialize(v[k], breaks, depth + 1, seen)
    end
  end
  seen[v] = nil
  if #parts == 0 then return "{}" end
  if depth < breaks then
    local pad = string.rep("\t", depth + 1)
    return "{\n" .. pad .. table.concat(parts, ",\n" .. pad) .. ",\n" .. string.rep("\t", depth) .. "}"
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

return L
