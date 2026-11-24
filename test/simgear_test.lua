local T = dofile("test/lib.lua")
local ns = T.load({}, "SimGear.lua")
local S = ns.SimGear

local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

-- The real installed Druid data normalizes into Prepped's shape.
local global = T.simgearGlobal("Druid")
print("source: " .. T.SIMGEAR_DIR .. "/SimGearForever_Druid")
local data, why = S.load(global, "DRUID")
T.eq("loads", why, nil)
local items = count(data and data.items)
print("druid items: " .. items)
T.eq("thousands of items, not a stub", items > 1000, true)
T.eq("cat weight sets", data and type(data.specs.FERAL_CAT), "table")
T.eq("bear weight sets", data and type(data.specs.FERAL_BEAR), "table")
T.eq("generated date is a date", data and tostring(data.generated):match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil, true)

-- Anything not shaped like SimGear's data -> nil and a reason (caller falls back to the backup copy).
local function good()
  return { DRUID = {
    items = { items = { [1] = { stats = {}, slot = "INVTYPE_HEAD" } }, meta = {} },
    weights = { sets = { FERAL_CAT = { { weights = { Agility = 2 }, source = { kind = "sim" } } } },
                meta = { generated = "2026-11-05" } },
  } }
end
T.eq("small good fixture loads", select(2, S.load(good(), "DRUID")), nil)
local cases = {
  { "SimGear not installed", function() return nil end },
  { "class not loaded", function(g) g.DRUID = nil return g end },
  { "weights without sets", function(g) g.DRUID.weights = { FERAL_CAT = {} } return g end },
  { "items not under .items", function(g) g.DRUID.items = { [1] = {} } return g end },
  { "weight set without source", function(g) g.DRUID.weights.sets.FERAL_CAT[1].source = nil return g end },
  { "weight set without weights", function(g) g.DRUID.weights.sets.FERAL_CAT[1].weights = nil return g end },
}
for _, c in ipairs(cases) do
  local d, reason = S.load(c[2](good()), "DRUID")
  T.eq(c[1] .. " -> nil", d, nil)
  T.eq(c[1] .. " -> has a reason", type(reason), "string")
end

-- Every installed class loads, not just Druid.
for _, cls in ipairs({ "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior" }) do
  local key = cls:upper()
  local d, reason = S.load(T.simgearGlobal(cls), key)
  local n = count(d and d.items)
  print(string.format("  %-8s items %5d  specs %d  %s", cls, n, count(d and d.specs), reason or ""))
  T.eq(cls .. " loads", reason, nil)
  T.eq(cls .. " has thousands of items", n > 1000, true)
end

-- SimGear's item sets in Bis's shape for one weight set: each bonus worth its simmed value where
-- SimGear sims it (a proc no stat covers), else its stats' value; bonuses worth nothing left out.
local function value(stats) local v = 0 for k, n in pairs(stats) do v = v + ({ AttackPower = 0.5, SpellPower = 0.1 })[k] * n end return v end
local bySet = {
  [184] = { name = "Shadowcraft Armor", items = { 16713, 16711 }, bonuses = {
    { n = 2, stats = { AttackPower = 40 } }, { n = 4, stats = {}, unscored = true }, { n = 6, stats = {}, unscored = true } } },
  [144] = { name = "Ironfeather Armor", items = { 15066, 15067 }, bonuses = { { n = 2, stats = { SpellPower = 20 } } } },
  [65] = { name = "Spider's Kiss", items = { 13218, 13183 }, bonuses = { { n = 2, stats = {}, unscored = true } } },
}
local sims = { [184] = { [4] = { v = 9.264, se = 0.27 } } }
local sets = S.setBonuses(bySet, sims, value)
T.eq("items as a lookup", sets[184] and sets[184].items[16711], true)
T.eq("name", sets[184] and sets[184].name, "Shadowcraft Armor")
T.eq("stat bonus and simmed proc", sets[184] and #sets[184].bonuses, 2)
T.eq("stat bonus points", sets[184] and sets[184].bonuses[1].points, 20)
T.eq("simmed bonus points", sets[184] and sets[184].bonuses[2].count, 4)
T.near("simmed value", sets[184] and sets[184].bonuses[2].points, 9.264)
T.near("another set's stats", sets[144] and sets[144].bonuses[1].points, 2)
T.eq("nothing scorable -> no set", sets[65], nil)
T.eq("no sims for the spec", S.setBonuses(bySet, nil, value)[184] and #S.setBonuses(bySet, nil, value)[184].bonuses, 1)
-- The sims for a weight set: the level and spec it was simmed on, as SimGear attaches them.
local raw = { [60] = { meta = {}, FERAL_CAT = sims } }
T.eq("sims for a sim set", S.setSims(raw, { spec = "FERAL_CAT", source = { kind = "sim", maxLevel = 60 } }, "FERAL_CAT"), sims)
T.eq("by the list's spec key", S.setSims(raw, { source = { kind = "sim", maxLevel = 60 } }, "FERAL_CAT"), sims)
T.eq("none for another level", S.setSims(raw, { source = { kind = "sim", maxLevel = 40 } }, "FERAL_CAT"), nil)
T.eq("none for a non-sim set", S.setSims(raw, { source = { kind = "guide", maxLevel = 60 } }, "FERAL_CAT"), nil)

T.done()
