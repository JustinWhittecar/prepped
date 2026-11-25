local T = dofile("test/lib.lua")
local ns = T.load({}, "SimGear.lua")
local S = ns.SimGear

local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

-- The real installed Druid data normalizes into Prepped's shape.
local global = T.simgearGlobal("Druid")
print("source: " .. (T.DATA == "backup" and "PreppedBackup_Druid/Data.lua (snapshot)" or (T.SIMGEAR_DIR .. "/SimGearForever_Druid")))
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

-- Crafts the reputation filter covers: made from a recipe that needs a reputation (SimGear's reps,
-- or Prepped's reputation list) and binding on pickup (not in SimGear's tradable list).
local craftItems = {
  [1] = { name = "BoP rep craft", sources = { { type = "crafted", recipe = 101 } } },
  [2] = { name = "BoE rep craft", sources = { { type = "crafted", recipe = 102 } } },
  [3] = { name = "BoP craft, recipe from a trainer", sources = { { type = "crafted", recipe = 103 } } },
  [4] = { name = "BoP craft, recipe on Prepped's list", sources = { { type = "crafted", recipe = 104 } } },
  [5] = { name = "Drop", sources = { { type = "drop" } } },
}
local tagged = S.repCrafts(craftItems, { [101] = { 576, 5 }, [102] = { 576, 5 } }, { 2 }, { [104] = 59 })
T.eq("BoP rep craft tagged", tagged[1], 576)
T.eq("BoE rep craft not tagged", tagged[2], nil)
T.eq("trainer recipe not tagged", tagged[3], nil)
T.eq("recipe on Prepped's list", tagged[4], 59)
T.eq("drops not tagged", tagged[5], nil)
T.eq("loads reps and tradable", type(data.reps) == "table" and type(data.tradable) == "table", true)

-- SimGear's reputation items (its reps and factions): each tagged for the reputation filter, given
-- a source naming the faction and standing (BiS drops items with none), and the other side's
-- factions marked so they're never targets.
local reps = { [272059] = { 2798, 4 }, [272200] = { 2799, 5 }, [16000] = { 576, 7 } }
local factions = { [2798] = { name = "Darkspear Raiders", side = "Horde" }, [2799] = { name = "Theramore Expeditionary Force", side = "Alliance" },
  [576] = { name = "Timbermaw Hold" } }
local r = S.repItems(reps, factions, "Alliance")
T.eq("tagged with its faction", r.tagged[272059], 2798)
T.eq("neutral faction tagged", r.tagged[16000], 576)
T.eq("source names faction and standing", r.sources[272200] and r.sources[272200].text, "Theramore Expeditionary Force, Honored")
T.eq("source kind", r.sources[272200] and r.sources[272200].kind, "reputation")
T.eq("exalted", r.sources[16000] and r.sources[16000].text, "Timbermaw Hold, Exalted")
T.eq("other side's faction never a target", r.wrongSide[272059], true)
T.eq("own side's faction allowed", r.wrongSide[272200], nil)
T.eq("neutral faction allowed", r.wrongSide[16000], nil)
T.eq("no side known: nothing ruled out", S.repItems(reps, factions, nil).wrongSide[272059], nil)

-- Items only the other side can get: every source is marked for the other faction (a Horde quest).
local sided = {
  [12544] = { name = "Thrall's Resolve", sources = { { type = "quest", faction = "Horde" } } },
  [2] = { name = "Both sides' quests", sources = { { type = "quest", faction = "Horde" }, { type = "quest", faction = "Alliance" } } },
  [3] = { name = "Horde quest or a drop", sources = { { type = "quest", faction = "Horde" }, { type = "drop" } } },
  [4] = { name = "Alliance quest", sources = { { type = "quest", faction = "Alliance" } } },
  [5] = { name = "No sources", sources = {} },
}
local other = S.otherSide(sided, "Alliance")
T.eq("Horde-only item ruled out", other[12544], true)
T.eq("either side's quest kept", other[2], nil)
T.eq("unsided source kept", other[3], nil)
T.eq("own side kept", other[4], nil)
T.eq("no sources: not this rule's call", other[5], nil)
T.eq("no side known: nothing", S.otherSide(sided, nil)[12544], nil)

-- PvP rank gear names its side only in the vendor's zone ("Horde PVP Barracks").
local pvp = S.otherSide({
  [16550] = { name = "Warlord's Dragonhide Helmet", sources = { { type = "vendor", zone = "Horde PVP Barracks" } } },
  [16451] = { name = "Field Marshal's Dragonhide Helmet", sources = { { type = "vendor", zone = "Alliance PVP Barracks" } } },
}, "Alliance")
T.eq("Horde barracks vendor ruled out", pvp[16550], true)
T.eq("Alliance barracks vendor kept", pvp[16451], nil)

-- Crafts that bind on pickup, for the profession filter: crafted and not in SimGear's tradable list.
-- Forever's own crafts (Legionite Glaive, 250619) are missing from Prepped's cMaNGOS list.
local bop = S.bopCrafts({
  [250619] = { name = "Legionite Glaive", sources = { { type = "crafted", recipe = 251471 } } },
  [252484] = { name = "Timbermaw Tunic", sources = { { type = "crafted", recipe = 252893 } } },
  [13340] = { name = "Cape of the Black Baron", sources = { { type = "drop" } } },
}, { 252484 })
T.eq("BoP craft tagged", bop[250619], true)
T.eq("tradable craft not tagged", bop[252484], nil)
T.eq("drop not tagged", bop[13340], nil)

-- World boss loot (a raid group's kill, not Pre-raid gear): items whose every source is a drop
-- from one of the bosses named.
local bosses = { [14889] = "Emeriss", [12397] = "Lord Kazzak" }
local wb = S.dropsOnlyFrom({
  [20624] = { name = "Ring of the Unliving", sources = { { type = "drop", id = 14889 } } },
  [2] = { name = "Kazzak or a quest", sources = { { type = "drop", id = 12397 }, { type = "quest", id = 99 } } },
  [3] = { name = "Dungeon drop", sources = { { type = "drop", id = 10440 } } },
  [4] = { name = "No sources", sources = {} },
}, bosses)
T.eq("world boss only", wb[20624], "Emeriss")
T.eq("another way to get it", wb[2], nil)
T.eq("other drops kept", wb[3], nil)
T.eq("no sources: not this rule's call", wb[4], nil)

-- Quests SimGear found only in cMaNGOS, not in Forever's client: their rewards aren't on Forever
-- when no other source gives them.
local q = S.cmangosQuestOnly({
  [22066] = { name = "Sorcerer's Gloves", sources = { { type = "quest", origin = "cmangos" }, { type = "quest", origin = "cmangos" } } },
  [2] = { name = "Client quest", sources = { { type = "quest", origin = "client" } } },
  [3] = { name = "cMaNGOS quest or a drop", sources = { { type = "quest", origin = "cmangos" }, { type = "drop", origin = "cmangos" } } },
  [4] = { name = "No sources", sources = {} },
})
T.eq("cMaNGOS-only quest reward", q[22066], true)
T.eq("Forever's client quest kept", q[2], nil)
T.eq("another source kept", q[3], nil)
T.eq("no sources: not this rule's call", q[4], nil)

-- Raid loot: items whose every source is in a raid (Onyxia's Eskhandar's Collar) aren't Pre-raid gear.
local raid = S.raidOnly({
  [18205] = { name = "Eskhandar's Collar", sources = { { type = "boss", id = 10184, instance = "raid" } } },
  [2] = { name = "Raid or dungeon", sources = { { type = "boss", instance = "raid" }, { type = "boss", instance = "dungeon" } } },
  [3] = { name = "Dungeon boss", sources = { { type = "boss", instance = "dungeon" } } },
  [4] = { name = "No sources", sources = {} },
  [5] = { name = "Quest", sources = { { type = "quest" } } },
})
T.eq("raid only", raid[18205], true)
T.eq("also in a dungeon: kept", raid[2], nil)
T.eq("dungeon kept", raid[3], nil)
T.eq("no sources: not this rule's call", raid[4], nil)
T.eq("quest kept", raid[5], nil)

T.done()
