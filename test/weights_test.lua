local T = dofile("test/lib.lua")
local ns = T.load({}, "Weights.lua")
local W = ns.Weights

-- Weights you choose (a preset or your own) are in attack power units: 1 AP = 1. Prepped scores in
-- SimGear's points, where its simmed trinkets and set bonuses live, so they're scaled until 1 AP is
-- worth what SimGear says: here 0.2 points, so Agility 2.5 AP -> 0.5 points.
local SIMGEAR = { AttackPower = 0.2, Agility = 0.6, MeleeCrit = 6.4 }
local mine = { AttackPower = 1, Agility = 2.5, MeleeCrit = 30 }
local out = W.scaled(mine, SIMGEAR)
T.near("agility", out.Agility, 0.5)
T.near("attack power matches SimGear's", out.AttackPower, 0.2)
T.near("crit", out.MeleeCrit, 6)
T.eq("yours untouched", mine.Agility, 2.5)
T.eq("a stat you don't weigh counts nothing", out.Stamina, nil)

-- A caster has no attack power weight: spell power anchors instead.
out = W.scaled({ SpellPower = 1, Intellect = 0.5 }, { SpellPower = 0.05, Intellect = 0.02 })
T.near("caster anchored on spell power", out.Intellect, 0.025)
-- Nothing to anchor on: taken as given.
out = W.scaled({ Dodge = 10 }, { Agility = 1 })
T.eq("no anchor -> as given", out.Dodge, 10)

-- SimGear's weights in the same attack power units, to start your own from.
local ap = W.inAP(SIMGEAR)
T.near("SimGear's agility in AP", ap.Agility, 3)
T.eq("SimGear's AP is 1", ap.AttackPower, 1)

-- A typed edit ("agility 2.5"): the stat as SimGear names it, and its value; nil for a bad one.
local stat, v = W.parseEdit("agility 2.5", SIMGEAR)
T.eq("stat by any case", stat, "Agility")
T.eq("value", v, 2.5)
stat, v = W.parseEdit("meleecrit 0", SIMGEAR)
T.eq("zero allowed", v, 0)
T.eq("unknown stat", W.parseEdit("luck 3", SIMGEAR), nil)
T.eq("no number", W.parseEdit("agility lots", SIMGEAR), nil)
T.eq("negative refused", W.parseEdit("agility -1", SIMGEAR), nil)

-- The choices for a spec, in order: SimGear's, its presets, then Custom; and the weights a choice
-- gives (nil = SimGear's own).
local presets = { FERAL_CAT = { { id = "raidready", name = "Raid Ready (MythicSim)", weights = mine } } }
local list = W.choices("FERAL_CAT", presets)
T.eq("three choices", #list, 3)
T.eq("SimGear first", list[1].id, "simgear")
T.eq("preset next", list[2].name, "Raid Ready (MythicSim)")
T.eq("custom last", list[3].id, "custom")
T.eq("a spec with no preset: SimGear and Custom", #W.choices("BALANCE", presets), 2)
T.eq("SimGear's -> nil", W.resolve("simgear", "FERAL_CAT", presets, {}, SIMGEAR), nil)
T.eq("preset's weights", W.resolve("raidready", "FERAL_CAT", presets, {}, SIMGEAR).weights.Agility, 2.5)
T.eq("custom: yours", W.resolve("custom", "FERAL_CAT", presets, { FERAL_CAT = { AttackPower = 1, Agility = 9 } }, SIMGEAR).weights.Agility, 9)
T.near("custom not set yet: starts from SimGear's", W.resolve("custom", "BALANCE", presets, {}, SIMGEAR).weights.Agility, 3)
T.eq("an unknown choice -> SimGear's", W.resolve("gone", "FERAL_CAT", presets, {}, SIMGEAR), nil)

T.done()
