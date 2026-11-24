local T = dofile("test/lib.lua")
local ns = T.load({}, "Effects.lua")
local E = ns.Effects

-- Weights as SimGear gives them, in its points; score is SimGear's stat scorer.
local WS = { AttackPower = 0.4, MeleeCrit = 10, Dodge = 15 }
local function score(stats) local s = 0 for k, v in pairs(stats or {}) do s = s + (WS[k] or 0) * v end return s end

-- An attack power equivalent for the spec, in SimGear's points through the spec's own AP weight.
local HEART = { ap = { FERAL_BEAR = 77, FERAL_CAT = 34 } }
T.near("bear AP equivalent", E.value(HEART, "FERAL_BEAR", WS, {}, score), 30.8)
T.eq("a spec it doesn't name gets nothing", E.value(HEART, "BALANCE", WS, {}, score), 0)

-- Stats for every spec (an on-use averaged), less stats the item lists that don't count.
local BREADTH = { stats = { MeleeCrit = 0.33 } }
T.near("averaged on-use crit", E.value(BREADTH, "FERAL_BEAR", WS, {}, score), 3.3)
local CHARM = { stats = { Dodge = 0.5 }, drop = { Dodge = true } }
T.near("listed dodge replaced by its average", E.value(CHARM, "FERAL_BEAR", WS, { Dodge = 20 }, score), 7.5 - 300)

-- Into a weight set's effects: only where SimGear has no value for the item, never written into
-- SimGear's own table.
local simgear = { [11815] = 7.2 }
local overrides = { [11815] = { ap = { FERAL_BEAR = 24 } }, [22321] = HEART }
local items = { [11815] = { stats = {} }, [22321] = { stats = {} } }
local effects = E.merge(simgear, overrides, "FERAL_BEAR", WS, items, score)
T.eq("SimGear's simmed value wins", effects[11815], 7.2)
T.near("gap filled", effects[22321], 30.8)
T.eq("SimGear's table untouched", simgear[22321], nil)

T.done()
