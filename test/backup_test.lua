local T = dofile("test/lib.lua")
local ns = T.load({}, "SimGearShim.lua", "vendor/SimGear/Stats.lua", "vendor/SimGear/HitCap.lua", "vendor/SimGear/Score.lua",
  "Bis.lua", "SimGear.lua", "Backup.lua")
local B = ns.Backup
local L = dofile("tools/backup_lib.lua")

local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

-- Which copy Core uses: live SimGear when its shape fits, else the backup, else a reason naming both.
local function fixture(stamp)
  return { DRUID = {
    items = { items = { [1] = { name = "Hat", slot = "INVTYPE_HEAD", stats = {}, sources = { { type = "drop" } } } } },
    weights = { sets = { FERAL_CAT = { { weights = { Agility = 2 }, source = { kind = "sim", maxLevel = 60 } } } },
                meta = { generated = "2026-11-05" } },
    snapshot = stamp,
  } }
end
local backupLoads = 0
local function backup() backupLoads = backupLoads + 1 return fixture({ built = "2026-11-23", simgearVersion = "0.16.0" }) end
local d, problem = B.choose("DRUID", function() return fixture() end, backup, ns.SimGear.load)
T.eq("live fits -> live", d and d.snapshot, nil)
T.eq("live fits -> no problem", problem, nil)
T.eq("live fits -> backup never loaded", backupLoads, 0)
d, problem = B.choose("DRUID", function() return nil end, backup, ns.SimGear.load)
T.eq("live missing -> backup", d and d.snapshot and d.snapshot.built, "2026-11-23")
T.eq("live missing -> no problem", problem, nil)
T.eq("live missing -> says why live failed", d and d.liveProblem, "SimGearForeverData missing (SimGear not installed)")
local bad = fixture()
bad.DRUID.weights = { FERAL_CAT = {} } -- SimGear reshaped its weights
d = B.choose("DRUID", function() return bad end, backup, ns.SimGear.load)
T.eq("live reshaped -> backup", d and d.snapshot and d.snapshot.simgearVersion, "0.16.0")
-- An addon load failure (disabled, missing) is the reason given, ahead of the shape check's.
d = B.choose("DRUID", function() return nil, "SimGearForever_Druid: DISABLED" end, backup, ns.SimGear.load)
T.eq("load failure named", d and d.liveProblem, "SimGearForever_Druid: DISABLED")
d, problem = B.choose("DRUID", function() return nil end, function() return nil, "PreppedBackup_Druid: MISSING" end, ns.SimGear.load)
T.eq("both missing -> nil", d, nil)
T.eq("both missing -> both reasons", problem, "SimGearForeverData missing (SimGear not installed); backup: PreppedBackup_Druid: MISSING")
d, problem = B.choose("DRUID", function() return nil end, function() return {} end, ns.SimGear.load)
T.eq("backup without the class", problem, "SimGearForeverData missing (SimGear not installed); backup: no DRUID data (class addon not loaded)")
-- A backup without a snapshot stamp is still marked as the backup.
d = B.choose("DRUID", function() return nil end, function() return fixture() end, ns.SimGear.load)
T.eq("unstamped backup still a snapshot", d and type(d.snapshot), "table")

-- The badge: "Snapshot 23 Nov" from the build date.
T.eq("badge date", B.badge({ built = "2026-11-23" }), "Snapshot 23 Nov")
T.eq("badge single-digit day", B.badge({ built = "2026-12-04" }), "Snapshot 4 Dec")
T.eq("badge without a date", B.badge({}), "Snapshot")

-- The level-60 candidate floor: equippable in a slot BiS fills, required level 60 or less, item level 50+.
T.eq("raid-ready head", L.keepItem({ slot = "INVTYPE_HEAD", req = 58, ilvl = 63 }), true)
T.eq("no required level, high item level", L.keepItem({ slot = "INVTYPE_FINGER", req = 0, ilvl = 60 }), true)
T.eq("item level below 50", L.keepItem({ slot = "INVTYPE_HEAD", req = 45, ilvl = 49 }), false)
T.eq("above level 60", L.keepItem({ slot = "INVTYPE_HEAD", req = 61, ilvl = 70 }), false)
T.eq("not a gear slot", L.keepItem({ slot = "INVTYPE_BAG", req = 0, ilvl = 60 }), false)
T.eq("weapon kept", L.keepItem({ slot = "INVTYPE_2HWEAPON", req = 60, ilvl = 66 }), true)
-- No source isn't a reason to drop: Prepped adds vendor, reputation and harvested sources at run time.
T.eq("sourceless kept", L.keepItem({ slot = "INVTYPE_HEAD", req = 60, ilvl = 60, sources = {} }), true)

-- Trimming a class: the candidates, each spec's level-60 weight set, and only the levels it reads.
-- Below the floor an item stays only if it ranks in the best L.DEPTH for its slot under some spec.
local oldDepth = L.DEPTH
L.DEPTH = 2
local raw = {
  items = { meta = { generated = "2026-11-22", mobHit = {} }, items = {
    [10] = { name = "Old", slot = "INVTYPE_HEAD", req = 20, ilvl = 25, stats = { Agility = 1 }, sources = {} },
    [11] = { name = "New", slot = "INVTYPE_HEAD", req = 60, ilvl = 63, stats = { Agility = 30 }, sources = {} },
    [12] = { name = "Also new", slot = "INVTYPE_HEAD", req = 60, ilvl = 60, stats = { Agility = 20 }, sources = {} },
    [13] = { name = "Old but strong", slot = "INVTYPE_RELIC", req = 1, ilvl = 10, stats = { Agility = 5 }, sources = {} },
    [14] = { name = "Old proc trinket", slot = "INVTYPE_TRINKET", req = 40, ilvl = 45, stats = {}, sources = {} },
    [15] = { name = "Old shirt", slot = "INVTYPE_BODY", req = 1, ilvl = 60, stats = { Agility = 50 }, sources = {} } } },
  weights = { meta = { generated = "2026-11-05" }, sets = {
    FERAL_CAT = { { source = { kind = "sim", minLevel = 50, maxLevel = 50 }, weights = { Agility = 1 } },
                  { source = { kind = "sim", minLevel = 60, maxLevel = 60 }, weights = { Agility = 2 } } },
    FERAL_CAT_DUNGEON = { { source = { kind = "sim", minLevel = 40, maxLevel = 40 }, weights = { Agility = 3 } },
                          { source = { kind = "sim", minLevel = 50, maxLevel = 50 }, weights = { Agility = 4 } } } } },
  itemEffects = { [40] = {}, [60] = { FERAL_CAT = { [14] = { v = 40, se = 1 } } } },
  enchants = { [40] = { X = {} }, [50] = { X = {} }, [60] = { X = {} } },
  setBonusSims = { [60] = { FERAL_CAT = {} } },
  extras = { sets = { [1] = {} }, reps = { [11] = { 576, 5 }, [99] = { 576, 6 } }, factions = { [576] = {} },
             tradable = { 10, 11 }, suffixes = { big = true } },
}
local out = L.trim(raw, ns.Score, { built = "2026-11-23", simgearVersion = "0.16.0" })
L.DEPTH = oldDepth
T.eq("old item outranked: dropped", out.items.items[10], nil)
T.eq("new items kept", out.items.items[11] ~= nil and out.items.items[12] ~= nil, true)
T.eq("old item that ranks: kept", out.items.items[13] and out.items.items[13].name, "Old but strong")
T.eq("old item whose simmed effect ranks: kept", out.items.items[14] ~= nil, true)
T.eq("not a gear slot: dropped", out.items.items[15], nil)
T.eq("one weight set per spec", #out.weights.sets.FERAL_CAT, 1)
T.eq("the level-60 one", out.weights.sets.FERAL_CAT[1].weights.Agility, 2)
T.eq("dungeon spec: its nearest set to 60", out.weights.sets.FERAL_CAT_DUNGEON[1].weights.Agility, 4)
T.eq("weights meta kept (the generated date)", out.weights.meta.generated, "2026-11-05")
T.eq("enchants: levels the kept sets read", out.enchants[60] ~= nil and out.enchants[50] ~= nil, true)
T.eq("enchants: other levels dropped", out.enchants[40], nil)
T.eq("set sims kept", type(out.setBonusSims[60].FERAL_CAT), "table")
T.eq("item effects at the kept levels", out.itemEffects[60] ~= nil and out.itemEffects[40] == nil, true)
T.eq("reps kept whole (recipes too)", out.extras.reps[99] ~= nil, true)
T.eq("tradable: kept items only", #out.extras.tradable == 1 and out.extras.tradable[1], 11)
T.eq("no item effects -> none", L.trim({ items = { items = {} }, weights = { sets = {} } }, ns.Score, {}).itemEffects, nil)
T.eq("extras Prepped doesn't read dropped", out.extras.suffixes, nil)
T.eq("snapshot stamp", out.snapshot.built, "2026-11-23")
T.eq("trim leaves the source alone", raw.items.items[10] ~= nil and #raw.weights.sets.FERAL_CAT, 2)
T.eq("trimmed loads through the adapter", select(2, ns.SimGear.load({ DRUID = out }, "DRUID")), nil)

-- Writing: Lua source that reads back to the same values, keys in a fixed order.
local val = { b = 1, a = { 1, 2, 3 }, [5] = "x\ny", [2] = 0.1, ["two words"] = true, ["end"] = -3.25 }
local src = L.serialize(val)
local back = assert(loadstring("return " .. src))()
T.eq("round trip string", back[5], "x\ny")
T.eq("round trip float", back[2], 0.1)
T.eq("round trip list", back.a[3], 3)
T.eq("round trip odd key", back["two words"], true)
T.eq("round trip keyword key", back["end"], -3.25)
T.eq("same input, same text", L.serialize(val), src)
T.eq("shortest float", L.serialize(0.1), "0.1")
T.eq("cycles refused", pcall(L.serialize, (function() local t = {} t.t = t return t end)()), false)

-- Real data: for every class and spec, the backup's BiS at 60 (sets included) is the live one, with
-- PvP filtered and with every filter on (the depth below the top picks), so the candidate rule never
-- drops a pick. A pick missing from the backup names the item.
T.load(ns, "data/Lists.lua", "data/Excluded.lua")
local UNAVAILABLE = {}
for id in pairs(ns.Lists.raidOnly) do UNAVAILABLE[id] = true end
for id in pairs(ns.Excluded) do UNAVAILABLE[id] = true end
local MODES = {
  { name = "pvp filtered", filters = { pvp = true } },
  { name = "all filters", filters = { pvp = true, reputation = true, profession = true, darkmoon = true },
    tagged = { reputation = ns.Lists.reputation, profession = ns.Lists.profession, darkmoon = ns.Lists.darkmoon, unavailable = UNAVAILABLE } },
}
local CLASSES = { "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior" }
for _, cls in ipairs(CLASSES) do
  local token = cls:upper()
  local live = T.simgearGlobal(cls)[token]
  local trimmed = L.trim(live, ns.Score, { built = "test" })
  local a = assert(ns.SimGear.load({ [token] = live }, token))
  local b = assert(ns.SimGear.load({ [token] = trimmed }, token))
  local diffs, specs = {}, 0
  for spec, sets in pairs(a.specs) do for _, mode in ipairs(MODES) do
    local ws = ns.Score.pickSet(sets, 60)
    local value = function(stats) return ns.Score.value(stats, ws) end
    local function bis(dd)
      local sims = ns.SimGear.setSims(dd.setBonusSims, ws, spec)
      return ns.Bis.pick({ items = dd.items, weightSet = ws, filters = mode.filters, tagged = mode.tagged, sets = ns.SimGear.setBonuses(dd.sets, sims, value) })
    end
    local pa, pb = bis(a), bis(b)
    if mode == MODES[1] then specs = specs + 1 end
    -- Equal items (Highlander's and Defiler's shoulders) tie, and BiS takes either in table order:
    -- compare points per slot group (rings, trinkets and weapons together) and the set bonuses.
    local function pts(p, slots) local v = 0 for _, s in ipairs(slots) do v = v + (p[s] and p[s].points or 0) end return v end
    local function names(p, slots)
      local o = {}
      for _, s in ipairs(slots) do o[#o + 1] = p[s] and (p[s].item.name .. " ilvl " .. tostring(p[s].item.ilvl)) or "-" end
      return table.concat(o, " + ")
    end
    for _, slots in ipairs({ { 1 }, { 2 }, { 3 }, { 5 }, { 6 }, { 7 }, { 8 }, { 9 }, { 10 }, { 15 }, { 11, 12 }, { 13, 14 }, { 16, 17 }, { 18 } }) do
      if math.abs(pts(pa, slots) - pts(pb, slots)) > 1e-6 then
        diffs[#diffs + 1] = spec .. " (" .. mode.name .. ") slots " .. table.concat(slots, "/") .. ": live " .. names(pa, slots) .. " vs backup " .. names(pb, slots)
      end
    end
    local function setPts(p) local v = 0 for _, s in pairs(p.sets or {}) do v = v + s.points end return v end
    if math.abs(setPts(pa) - setPts(pb)) > 1e-6 then diffs[#diffs + 1] = spec .. " (" .. mode.name .. ") set bonuses differ" end
  end end
  print(string.format("  %-8s live %5d -> backup %5d items, %d specs compared", cls, count(a.items), count(b.items), specs))
  T.eq(cls .. ": backup BiS = live BiS", table.concat(diffs, "; "), "")
end

-- The committed backup addons load through the adapter, as Core loads them.
for _, cls in ipairs(CLASSES) do
  local env = setmetatable({}, { __index = _G })
  local f = io.open("PreppedBackup_" .. cls .. "/Data.lua")
  T.eq(cls .. " backup addon present", f ~= nil, true)
  if f then
    f:close()
    local chunk = assert(loadfile("PreppedBackup_" .. cls .. "/Data.lua"))
    setfenv(chunk, env)("PreppedBackup_" .. cls, {})
    local dd, why = ns.SimGear.load(rawget(env, "PreppedBackupData"), cls:upper())
    T.eq(cls .. " backup addon loads", why, nil)
    T.eq(cls .. " backup addon stamped", dd and rawget(env, "PreppedBackupData")[cls:upper()].snapshot.built ~= nil, true)
  end
end

T.done()
