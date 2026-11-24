-- Forever items SimGear can't see: its pipeline asks the game only about IDs in the client's own
-- item table, and Forever sends some items (the tier 0.5 upgrade sets, 2267xx) from the server
-- only. Prepped asks the game about them itself (/prep harvest) and keeps what comes back raw:
-- name, slot, levels, the "Classes:" line and GetItemStats' stats. This module is pure.
local _, ns = ...
local ForeverItems = {}
ns.ForeverItems = ForeverItems

-- The classes on a tooltip's "Classes: A, B" line, as tokens ({DRUID = true}); nil without one.
-- tokens: localized class name -> class token.
function ForeverItems.classesFrom(lines, tokens)
  for _, line in ipairs(lines or {}) do
    local list = type(line) == "string" and line:match("^Classes: (.+)$")
    if list then
      local out = {}
      for name in list:gmatch("[^,]+") do
        local token = tokens[(name:gsub("^%s+", ""):gsub("%s+$", ""))]
        if token then out[token] = true end
      end
      return out
    end
  end
  return nil
end

-- A harvested record. info: name, quality, itemLevel, minLevel, equipLoc (GetItemInfo's fields);
-- raw: GetItemStats' table; classes: classesFrom's result or nil (any class).
-- set (optional): { id, name, bonuses } from GetItemInfo's set ID and setBonusesFrom.
function ForeverItems.record(info, raw, classes, set)
  return { name = info.name, quality = info.quality, ilvl = info.itemLevel, req = info.minLevel,
    slot = info.equipLoc, classes = classes, raw = raw or {}, set = set }
end

-- SimGear-shaped items ({name, slot, stats, req, ilvl, quality}) for one class: the records it can
-- use that equip somewhere and that SimGear doesn't already have. Only class-restricted records
-- count, since without SimGear's armor rules Prepped can't tell who wears an unrestricted one.
-- Each gets one source (kind "forever", text = the record's source note if any): it was found in game.
-- normalize: raw stats -> SimGear stats (Stats.normalize plus weapon DPS in the game).
function ForeverItems.forClass(records, token, have, normalize)
  local out = {}
  for id, r in pairs(records or {}) do
    if not have[id] and r.classes and r.classes[token] and r.slot and r.slot ~= "" then
      out[id] = { name = r.name, slot = r.slot, stats = normalize(r.raw, r.slot), req = r.req, ilvl = r.ilvl,
        quality = r.quality, sources = { { kind = "forever", text = r.source } }, forever = true }
    end
  end
  return out
end

-- Sources SimGear lacks: items with no source get Prepped's ({[id] = {kind, text}}), as copies, since
-- SimGear's tables are shared. Items with sources keep their own; extra IDs not in items are ignored.
-- Returns items itself when nothing changes.
function ForeverItems.addSources(items, extra)
  local changed
  for id, src in pairs(extra or {}) do
    local item = items[id]
    if item and not (type(item.sources) == "table" and #item.sources > 0) then
      changed = changed or {}
      local copy = {}
      for k, v in pairs(item) do copy[k] = v end
      copy.sources = { src }
      changed[id] = copy
    end
  end
  if not changed then return items end
  local out = {}
  for id, item in pairs(items) do out[id] = changed[id] or item end
  return out
end

-- A vendor price as text: "100 Tarnished Undermine Real", "2 Arcanite Bar + 25g", "15s".
-- copper: the gold price; costs: { {amount, name} } for currencies and items.
function ForeverItems.costText(copper, costs)
  local parts = {}
  for _, c in ipairs(costs or {}) do parts[#parts + 1] = c.amount .. " " .. c.name end
  copper = copper or 0
  if copper > 0 then
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local money = g > 0 and (g .. "g") or s > 0 and (s .. "s") or (c .. "c")
    parts[#parts + 1] = money
  end
  return table.concat(parts, " + ")
end

-- A set's bonuses from an item's tooltip lines ("(2) Set: +200 Armor."): { {count, text} } in
-- tooltip order, nil when there are none. Kept as text: scoring them is a separate step.
function ForeverItems.setBonusesFrom(lines)
  local out
  for _, line in ipairs(lines or {}) do
    local n, text
    if type(line) == "string" then n, text = line:match("^%((%d+)%) Set: (.+)$") end
    if n then
      out = out or {}
      out[#out + 1] = { count = tonumber(n), text = text }
    end
  end
  return out
end

-- A set bonus line as SimGear stats, or nil when Prepped can't read it (procs, resistances): those
-- count as nothing, like an unsimmed trinket.
local BONUS = {
  { "^%+(%d+) Attack Power", "AttackPower" },
  { "^%+(%d+) Strength", "Strength" }, { "^%+(%d+) Agility", "Agility" }, { "^%+(%d+) Stamina", "Stamina" },
  { "^%+(%d+) Intellect", "Intellect" }, { "^%+(%d+) Spirit", "Spirit" }, { "^%+(%d+) Armor", "Armor" },
  { "^Restores (%d+) mana per 5 sec", "Mp5" },
  { "^Increases damage and healing done by magical spells and effects by up to (%d+)", "SpellPower" },
}
function ForeverItems.bonusStats(text)
  for _, b in ipairs(BONUS) do
    local n = text:match(b[1])
    if n then return { [b[2]] = tonumber(n) } end
  end
  return nil
end

-- Forever's sets (Core.foreverSets: { [setID] = { name, items = {[id] = true}, lines = { {count, text} } } })
-- in Bis's shape: each line worth value(bonusStats) when Prepped can read it; else, where sameAs
-- names the same bonus on a SimGear set ({ [setID] = { [count] = {set, n} } }), that bonus's simmed
-- value from sims (SimGear.setSims' result). Lines worth nothing, and sets with none, are left out.
function ForeverItems.setBonuses(fsets, value, sameAs, sims)
  local out = {}
  for setID, fs in pairs(fsets or {}) do
    local bonuses = {}
    for _, line in ipairs(fs.lines or {}) do
      local stats = ForeverItems.bonusStats(line.text)
      local pts = stats and value(stats) or 0
      local ref = not stats and sameAs and sameAs[setID] and sameAs[setID][line.count]
      local sim = ref and sims and sims[ref.set] and sims[ref.set][ref.n]
      if type(sim) == "table" and type(sim.v) == "number" then pts = sim.v end
      if pts > 0 then bonuses[#bonuses + 1] = { count = line.count, points = pts } end
    end
    if #bonuses > 0 then out[setID] = { name = fs.name, items = fs.items, bonuses = bonuses } end
  end
  return out
end
