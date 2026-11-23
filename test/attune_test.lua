local T = dofile("test/lib.lua")
local ns = T.load({}, "data/Attunements.lua", "Attune.lua")
local A = ns.Attune

-- The world the blockers read: where the amulet is and which quests are done.
local function blockers(faction, where, done)
  return A.blockers({
    raids = { "ONYXIA" },
    faction = faction,
    itemPlace = function(id) return id == 16309 and where or nil end, -- "bags", "bank" or nil
    questDone = function(q) return done[q] == true end,
  })
end

-- Amulet carried: nothing blocks Onyxia.
T.eq("amulet in bags -> no blocker", #blockers("Alliance", "bags", {}), 0)

-- No amulet, chain not started: one blocker, with the first step of the player's own faction's chain.
local b = blockers("Alliance", nil, {})
T.eq("one blocker", #b, 1)
T.eq("blocker text", b[1] and b[1].text, "Blocked: Drakefire Amulet missing for Onyxia")
T.eq("Alliance chain length", b[1] and b[1].total, 16)
T.eq("nothing done", b[1] and b[1].done, 0)
T.eq("next step", b[1] and b[1].next, "Dragonkin Menace")

-- Part way: the next step is the first quest not done.
b = blockers("Alliance", nil, { [4182] = true, [4183] = true, [4184] = true })
T.eq("3 done", b[1] and b[1].done, 3)
T.eq("next after 3", b[1] and b[1].next, "The True Masters")
b = blockers("Alliance", nil, { [4182] = true, [4183] = true, [4184] = true, [4185] = true, [4186] = true, [4223] = true, [4224] = true })
T.eq("next after the True Masters", b[1] and b[1].next, "Marshal Windsor")

-- Horde gets the Horde chain.
b = blockers("Horde", nil, { [4903] = true })
T.eq("Horde chain length", b[1] and b[1].total, 14)
T.eq("Horde next step", b[1] and b[1].next, "Eitrigg's Wisdom")

-- In the bank: still blocked, the amulet has to be carried.
b = blockers("Alliance", "bank", {})
T.eq("bank -> blocker", b[1] and b[1].text, "Blocked: Drakefire Amulet is in your bank (carry it into Onyxia)")
T.eq("bank -> no quest step", b[1] and b[1].next, nil)

-- A raid without an attunement adds nothing.
T.eq("no attunement for Barrow Deeps", #A.blockers({ raids = { "BARROW_DEEPS" }, faction = "Alliance",
  itemPlace = function() end, questDone = function() return false end }), 0)

T.done()
