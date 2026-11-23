local T = dofile("test/lib.lua")
local ns = T.load({}, "SimGearShim.lua", "vendor/SimGear/Stats.lua", "vendor/SimGear/HitCap.lua", "vendor/SimGear/Score.lua", "Bis.lua")
local B = ns.Bis

local CAT = { weights = { Agility = 2, Strength = 2, Stamina = 0.5 }, source = { kind = "sim" } }
local function item(slot, stats, extra)
  local it = { slot = slot, stats = stats, req = 60, sources = { { type = "boss" } } }
  for k, v in pairs(extra or {}) do it[k] = v end
  return it
end

-- Each slot gets its highest-scoring item.
local items = {
  [101] = item("INVTYPE_HEAD", { Agility = 20 }),             -- 40
  [102] = item("INVTYPE_HEAD", { Agility = 10, Stamina = 30 }), -- 35
  [201] = item("INVTYPE_HAND", { Strength = 5 }),            -- 10
}
local bis = B.pick({ items = items, weightSet = CAT })
T.eq("head is the top scorer", bis[1] and bis[1].id, 101)
T.eq("head points", bis[1] and bis[1].points, 40)
T.eq("hands", bis[10] and bis[10].id, 201)
T.eq("no item -> empty slot", bis[5], nil)

-- Rings and trinkets: the two best different items fill the pair of slots.
bis = B.pick({ items = {
  [301] = item("INVTYPE_FINGER", { Agility = 10 }), -- 20
  [302] = item("INVTYPE_FINGER", { Agility = 15 }), -- 30
  [303] = item("INVTYPE_FINGER", { Agility = 5 }),  -- 10
  [401] = item("INVTYPE_TRINKET", { Strength = 8 }),
}, weightSet = CAT })
T.eq("ring 1 = best", bis[11] and bis[11].id, 302)
T.eq("ring 2 = second best", bis[12] and bis[12].id, 301)
T.eq("one trinket fills slot 13", bis[13] and bis[13].id, 401)
T.eq("no second trinket", bis[14], nil)

-- Trinket effects simmed by SimGear count on top of stats.
local CAT_FX = { weights = CAT.weights, source = CAT.source, effects = { [502] = 50 } }
bis = B.pick({ items = {
  [501] = item("INVTYPE_TRINKET", { Agility = 10 }), -- 20
  [502] = item("INVTYPE_TRINKET", {}),               -- 0 + effect 50
  [503] = item("INVTYPE_TRINKET", { Agility = 5 }),  -- 10
}, weightSet = CAT_FX })
T.eq("proc trinket first", bis[13] and bis[13].id, 502)
T.eq("its points include the effect", bis[13] and bis[13].points, 50)
T.eq("stat trinket second", bis[14] and bis[14].id, 501)

-- Filters: excluded kinds of item never become the target.
local heads = {
  [601] = item("INVTYPE_HEAD", { Agility = 30 }, { pvpRank = 10 }), -- 60, PvP rank reward
  [602] = item("INVTYPE_HEAD", { Agility = 25 }, { pvp = true }),   -- 50, PvP item
  [603] = item("INVTYPE_HEAD", { Agility = 20 }),                   -- 40, reputation (per Prepped's list)
  [604] = item("INVTYPE_HEAD", { Agility = 15 }),                   -- 30, profession BoP (per list)
  [605] = item("INVTYPE_HEAD", { Agility = 10 }),                   -- 20, Darkmoon Faire (per list)
  [606] = item("INVTYPE_HEAD", { Agility = 5 }),                    -- 10
}
local tagged = { reputation = { [603] = true }, profession = { [604] = true }, darkmoon = { [605] = true } }
local function head(filters) return B.pick({ items = heads, weightSet = CAT, filters = filters, tagged = tagged })[1].id end
T.eq("no filters -> PvP rank head", head(nil), 601)
T.eq("pvp excluded -> reputation head", head({ pvp = true }), 603)
T.eq("pvp + reputation excluded", head({ pvp = true, reputation = true }), 604)
T.eq("pvp, reputation, profession excluded", head({ pvp = true, reputation = true, profession = true }), 605)
T.eq("darkmoon excluded too", head({ pvp = true, reputation = true, profession = true, darkmoon = true }), 606)

-- Items above level 60 never count.
bis = B.pick({ items = { [701] = item("INVTYPE_NECK", { Agility = 99 }, { req = 61 }), [702] = item("INVTYPE_NECK", { Agility = 1 }) }, weightSet = CAT })
T.eq("level 61 item skipped", bis[2] and bis[2].id, 702)

-- Weapons: a two-hander against the best main hand + off hand pair.
local MELEE = { weights = { Agility = 2, TwoHandDps = 10, MainHandDps = 10, OffHandDps = 3, RangedDps = 1 }, source = { kind = "sim" } }
local function weapons(extra, dualWield)
  local list = {
    [801] = item("INVTYPE_2HWEAPON", { TwoHandDps = 20 }),   -- 200
    [802] = item("INVTYPE_WEAPON", { MainHandDps = 15 }),    -- 150 in the main hand
    [803] = item("INVTYPE_WEAPON", { MainHandDps = 12 }),    -- 120 main, 36 off hand
    [804] = item("INVTYPE_BOW", { RangedDps = 30 }),         -- not a real equip loc: ignored
    [805] = item("INVTYPE_RANGED", { RangedDps = 30 }),      -- 30
  }
  for id, it in pairs(extra) do list[id] = it end
  return B.pick({ items = list, weightSet = MELEE, dualWield = dualWield })
end
bis = weapons({ [811] = item("INVTYPE_HOLDABLE", { Agility = 30 }) }) -- 150 + 60 = 210 beats 200
T.eq("1H + held item beats 2H: main", bis[16] and bis[16].id, 802)
T.eq("1H + held item beats 2H: off", bis[17] and bis[17].id, 811)
bis = weapons({ [811] = item("INVTYPE_HOLDABLE", { Agility = 20 }) }) -- 150 + 40 = 190 loses to 200
T.eq("2H wins", bis[16] and bis[16].id, 801)
T.eq("2H leaves the off hand empty", bis[17], nil)
T.eq("ranged slot", bis[18] and bis[18].id, 805)
bis = weapons({}, false)
T.eq("no dual wield: 1H never in the off hand", bis[16] and bis[16].id, 801)
bis = weapons({}, true) -- 150 + 36 = 186 loses to 200
T.eq("dual wield pair loses to 2H", bis[16] and bis[16].id, 801)
bis = weapons({ [801] = item("INVTYPE_2HWEAPON", { TwoHandDps = 18 }) }, true) -- 180 < 186
T.eq("dual wield: main", bis[16] and bis[16].id, 802)
T.eq("dual wield: second weapon in the off hand", bis[17] and bis[17].id, 803)
T.eq("off hand valued as off hand", bis[17] and bis[17].points, 36)

-- An item with no known source is never the target: Prepped couldn't say where to get it.
bis = B.pick({ items = {
  [901] = { slot = "INVTYPE_WAIST", stats = { Agility = 50 }, req = 60, sources = {} },
  [902] = item("INVTYPE_WAIST", { Agility = 5 }, { sources = { { type = "boss", name = "Lord Roccor" } } }),
}, weightSet = CAT })
T.eq("sourceless item skipped", bis[6] and bis[6].id, 902)

-- One quest chain hands out the same-named ring at each step (Bronze Dragonflight signet): only one fits.
bis = B.pick({ items = {
  [951] = item("INVTYPE_FINGER", { Agility = 24 }, { name = "Signet Ring of the Bronze Dragonflight" }),
  [952] = item("INVTYPE_FINGER", { Agility = 22 }, { name = "Signet Ring of the Bronze Dragonflight" }),
  [953] = item("INVTYPE_FINGER", { Agility = 10 }, { name = "Tarnished Elven Ring" }),
}, weightSet = CAT })
T.eq("best signet in ring 1", bis[11] and bis[11].id, 951)
T.eq("ring 2 is a different ring", bis[12] and bis[12].id, 953)

-- Unavailable items (raid-kill rewards, content Forever hasn't opened) are excluded whatever the filters say.
bis = B.pick({ items = {
  [961] = item("INVTYPE_NECK", { Agility = 40 }, { name = "Onyxia Tooth Pendant" }),
  [962] = item("INVTYPE_NECK", { Agility = 10 }),
}, weightSet = CAT, tagged = { unavailable = { [961] = "Onyxia head quest" } } })
T.eq("unavailable skipped with no filters", bis[2] and bis[2].id, 962)

-- Real data: cat and bear BiS at 60 from the installed SimGear Druid data.
local SG = T.load(ns, "SimGear.lua").SimGear
local data = assert(SG.load(T.simgearGlobal("Druid"), "DRUID"))
print("source: SimGear Druid data, generated " .. tostring(data.generated))
for _, spec in ipairs({ "FERAL_CAT", "FERAL_BEAR" }) do
  local real = B.pick({ items = data.items, weightSet = ns.Score.pickSet(data.specs[spec], 60), filters = { pvp = true } })
  local filled, sourceless = 0, 0
  for slot = 1, 18 do
    local b = real[slot]
    if b then
      filled = filled + 1
      if #b.item.sources == 0 then sourceless = sourceless + 1 end
    end
  end
  T.eq(spec .. ": every pick has a source", sourceless, 0)
  T.eq(spec .. ": rings differ by name", real[11] and real[12] and real[11].item.name ~= real[12].item.name, true)
  T.eq(spec .. ": at least 16 of slots 1-18 filled", filled >= 16, true)
end

-- Real data with Prepped's lists: filters on -> no reputation, profession or PvP item is BiS.
T.load(ns, "data/Lists.lua", "data/Excluded.lua")
print("lists: " .. ns.Lists.source)
local UNAVAILABLE = {}
for id, why in pairs(ns.Lists.raidOnly) do UNAVAILABLE[id] = why end
for id, why in pairs(ns.Excluded) do UNAVAILABLE[id] = why end
local TAGGED = os.getenv("NO_LISTS") and {} or { reputation = ns.Lists.reputation, profession = ns.Lists.profession, darkmoon = ns.Lists.darkmoon, unavailable = UNAVAILABLE }
for _, spec in ipairs({ "FERAL_CAT", "FERAL_BEAR" }) do
  local real = B.pick({ items = data.items, weightSet = ns.Score.pickSet(data.specs[spec], 60),
    filters = { pvp = true, reputation = true, profession = true, darkmoon = true }, tagged = TAGGED })
  local bad = {}
  for slot = 1, 18 do
    local b = real[slot]
    if b and (ns.Lists.reputation[b.id] or ns.Lists.darkmoon[b.id] or UNAVAILABLE[b.id] or ns.Lists.profession[b.id] or b.item.pvp or b.item.pvpRank) then bad[#bad + 1] = b.item.name end
  end
  T.eq(spec .. ": filtered picks", table.concat(bad, ", "), "")
end

T.done()
