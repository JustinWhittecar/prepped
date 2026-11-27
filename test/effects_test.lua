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

-- Stats for one spec only (a healing idol is healing power for Restoration, nothing for Balance).
local HEAL = { specStats = { RESTORATION = { Dodge = 2 } } }
T.near("its spec's stats", E.value(HEAL, "RESTORATION", WS, {}, score), 30)
T.eq("another spec gets nothing", E.value(HEAL, "BALANCE", WS, {}, score), 0)

-- Into a weight set's effects: only where SimGear has no value for the item, never written into
-- SimGear's own table.
local simgear = { [11815] = 7.2 }
local overrides = { [11815] = { ap = { FERAL_BEAR = 24 } }, [22321] = HEART }
local items = { [11815] = { stats = {} }, [22321] = { stats = {} } }
local effects = E.merge(simgear, overrides, "FERAL_BEAR", WS, items, score)
T.eq("SimGear's simmed value wins", effects[11815], 7.2)
T.near("gap filled", effects[22321], 30.8)
T.eq("SimGear's table untouched", simgear[22321], nil)

-- Set bonus sims Prepped doesn't trust (Stormshroud's 3-piece for cat): its own attack power
-- equivalent, in place of SimGear's, for the specs it names; a new table, SimGear's untouched.
local sims = { [142] = { [2] = { v = 3.5 }, [3] = { v = 44.1 } }, [184] = { [5] = { v = 9.3 } } }
local setOverrides = { [142] = { [3] = { ap = { FERAL_CAT = 90 } } }, [999] = { [2] = { ap = { FERAL_CAT = 10 } } } }
local out = E.setSims(sims, setOverrides, "FERAL_CAT", WS)
T.near("overridden bonus", out[142][3].v, 36)
T.eq("other bonus of the set kept", out[142][2].v, 3.5)
T.eq("other sets kept", out[184][5].v, 9.3)
T.near("a set SimGear doesn't sim", out[999] and out[999][2].v, 4)
T.eq("SimGear's table untouched", sims[142][3].v, 44.1)
T.eq("a spec it doesn't name keeps SimGear's", E.setSims(sims, setOverrides, "FERAL_BEAR", WS)[142][3].v, 44.1)

-- The feral idols: SimGear has no value for either, so without these both score 0 and the first
-- idol in its list wins for both forms. Each is worth something only in its own form.
local data = T.load({}, "data/Overrides.lua").EffectOverrides
local FEROCITY, BRUTALITY = data[22397], data[23198]
T.eq("Idol of Ferocity: cat", FEROCITY and E.value(FEROCITY, "FERAL_CAT", WS, {}, score) > 0, true)
T.eq("Idol of Ferocity: nothing for bear", FEROCITY and E.value(FEROCITY, "FERAL_BEAR", WS, {}, score), 0)
T.eq("Idol of Brutality: bear", BRUTALITY and E.value(BRUTALITY, "FERAL_BEAR", WS, {}, score) > 0, true)
T.eq("Idol of Brutality: nothing for cat", BRUTALITY and E.value(BRUTALITY, "FERAL_CAT", WS, {}, score), 0)
local HWS = { HealingPower = 1 }
local function hscore(stats) local v = 0 for k, n in pairs(stats or {}) do v = v + (HWS[k] or 0) * n end return v end
local REJUV, SYNTH = data[22398], data[272429]
local rv = REJUV and E.value(REJUV, "RESTORATION", HWS, {}, hscore) or 0
local sv = SYNTH and E.value(SYNTH, "RESTORATION", HWS, {}, hscore) or 0
T.eq("Idol of Rejuvenation: resto", rv > 0, true)
T.eq("Idol of Synthesis beats it", sv > rv, true)
T.eq("Idol of Synthesis: nothing for cat", SYNTH and E.value(SYNTH, "FERAL_CAT", HWS, {}, hscore), 0)
-- Forever's epic Enchanting idols take a raid reagent (Malleable Essence of Nature).
local excluded = T.load({}, "data/Excluded.lua").Excluded
T.eq("Idol of Swiftness not a Pre-raid target", type(excluded[279250]), "string")
T.eq("Idol of the Ursine Twins not a Pre-raid target", type(excluded[279251]), "string")

T.done()
