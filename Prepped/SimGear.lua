-- SimGear adapter: reads SimGear Forever's class data (the SimGearForeverData global) into
-- Prepped's shape without writing to it. SimGear's tables share stat pools, so they are
-- referenced, never copied into or modified.
local _, ns = ...
local SimGear = {}
ns.SimGear = SimGear

-- global: SimGearForeverData; class: "DRUID", "WARRIOR"...
-- Returns { items, specs, enchants, setBonusSims, sets, reps, factions, tradable, itemEffects, generated } or nil, reason.
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
    reps = isTable(c.extras) and isTable(c.extras.reps) and c.extras.reps or nil,
    factions = isTable(c.extras) and isTable(c.extras.factions) and c.extras.factions or nil,
    tradable = isTable(c.extras) and isTable(c.extras.tradable) and c.extras.tradable or nil,
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

-- Crafted items that bind on pickup and come from a recipe that needs a reputation: the
-- reputation filter covers them, since only the player who earned the standing can make them.
-- items: SimGear's; reps: its { [id] = { faction, rank } }; tradable: its list of IDs that don't
-- bind on pickup; repList: Prepped's { [id] = faction } (data/Lists.lua). Returns { [id] = faction }.
function SimGear.repCrafts(items, reps, tradable, repList)
  local free = {}
  for _, id in ipairs(tradable or {}) do free[id] = true end
  local out = {}
  for id, item in pairs(items or {}) do
    if not free[id] then
      for _, src in ipairs(type(item.sources) == "table" and item.sources or {}) do
        local r = src.type == "crafted" and src.recipe
        local rep = r and reps and reps[r]
        local faction = (type(rep) == "table" and rep[1]) or (r and repList and repList[r])
        if faction then out[id] = faction; break end
      end
    end
  end
  return out
end

-- SimGear's reputation items (reps: { [id] = { faction, rank 3-7 } }, factions: { [id] = { name, side } }):
-- tagged = { [id] = faction } for the reputation filter; sources = { [id] = { kind = "reputation",
-- text = "Faction, Rank" } } for items with none (ForeverItems.addSources); wrongSide = { [id] = true }
-- for factions of the other side than `side` ("Alliance"/"Horde"; nil rules nothing out).
local RANKS = { [3] = "Neutral", [4] = "Friendly", [5] = "Honored", [6] = "Revered", [7] = "Exalted" }
function SimGear.repItems(reps, factions, side)
  local out = { tagged = {}, sources = {}, wrongSide = {} }
  for id, r in pairs(reps or {}) do
    local faction = type(r) == "table" and r[1]
    if faction then
      local f = factions and factions[faction] or {}
      out.tagged[id] = faction
      out.sources[id] = { kind = "reputation", text = (f.name or ("faction " .. faction)) .. ", " .. (RANKS[r[2]] or "?") }
      if side and f.side and f.side ~= side then out.wrongSide[id] = true end
    end
  end
  return out
end

-- A source's side: its faction, or for PvP rank gear the vendor's zone ("Horde PVP Barracks").
local function sourceSide(src)
  return src.faction or (type(src.zone) == "string" and src.zone:match("^(%a+) PVP Barracks$"))
end

-- Items only the other side can get: every source names a side, and none is `side`.
-- Returns { [id] = true }; nothing when side is unknown.
function SimGear.otherSide(items, side)
  local out = {}
  if not side then return out end
  for id, item in pairs(items or {}) do
    local srcs = type(item.sources) == "table" and item.sources or {}
    local other = #srcs > 0
    for _, src in ipairs(srcs) do
      local s = sourceSide(src)
      if not s or s == side then other = false; break end
    end
    if other then out[id] = true end
  end
  return out
end

-- Crafted items that bind on pickup (not in SimGear's tradable list), for the profession filter:
-- Prepped's cMaNGOS list misses Forever's own crafts. Returns { [id] = true }.
function SimGear.bopCrafts(items, tradable)
  local free = {}
  for _, id in ipairs(tradable or {}) do free[id] = true end
  local out = {}
  for id, item in pairs(items or {}) do
    if not free[id] then
      for _, src in ipairs(type(item.sources) == "table" and item.sources or {}) do
        if src.type == "crafted" then out[id] = true; break end
      end
    end
  end
  return out
end

-- Items whose every source is a drop from one of `npcs` ({ [npc ID] = name }), e.g. world bosses:
-- { [id] = the boss's name }.
function SimGear.dropsOnlyFrom(items, npcs)
  local out = {}
  for id, item in pairs(items or {}) do
    local srcs = type(item.sources) == "table" and item.sources or {}
    local boss = #srcs > 0
    for _, src in ipairs(srcs) do
      if not (src.type == "drop" and npcs[src.id]) then boss = false; break end
      boss = npcs[src.id]
    end
    if boss then out[id] = boss end
  end
  return out
end

-- Items whose every source is a quest SimGear found only in cMaNGOS, not in Forever's own client
-- (classic tier 0.5 quests, the AQ war, Darkmoon deck turn-ins): not on Forever. { [id] = true }.
function SimGear.cmangosQuestOnly(items)
  local out = {}
  for id, item in pairs(items or {}) do
    local srcs = type(item.sources) == "table" and item.sources or {}
    local only = #srcs > 0
    for _, src in ipairs(srcs) do
      if not (src.type == "quest" and src.origin == "cmangos") then only = false; break end
    end
    if only then out[id] = true end
  end
  return out
end
