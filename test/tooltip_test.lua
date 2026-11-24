local T = dofile("test/lib.lua")
local ns = T.load({}, "Tooltip.lua")
local TT = ns.Tooltip

-- Where an item can go -----------------------------------------------------------------------------
local p = TT.placesFor("INVTYPE_HEAD")
T.eq("head: one place", #p, 1)
T.eq("head goes on 1", p[1].inv, 1)
p = TT.placesFor("INVTYPE_ROBE")
T.eq("robe goes on chest", p[1].inv, 5)
p = TT.placesFor("INVTYPE_FINGER")
T.eq("ring: two places", #p, 2)
T.eq("ring first place", p[1].inv, 11)
T.eq("ring second place", p[2].inv, 12)
p = TT.placesFor("INVTYPE_2HWEAPON")
T.eq("two-hander on 16", p[1].inv, 16)
T.eq("two-hander marked", p[1].twoHand, true)
p = TT.placesFor("INVTYPE_WEAPON", false)
T.eq("one-hander without dual wield: main hand only", #p, 1)
p = TT.placesFor("INVTYPE_WEAPON", true)
T.eq("one-hander with dual wield: either hand", #p, 2)
T.eq("second hand is the off hand", p[2].offHand, true)
p = TT.placesFor("INVTYPE_SHIELD")
T.eq("shield on 17", p[1].inv, 17)
T.eq("non-gear has no place", TT.placesFor("INVTYPE_TABARD"), nil)
T.eq("shirts aren't gear either", TT.placesFor("INVTYPE_BODY"), nil)
T.eq("an empty equip location isn't gear", TT.placesFor(""), nil)

-- Single slot: % of BiS against that slot's BiS, the gain capped at BiS as gearPart caps it --------------
local base = { bis = { [1] = 100 }, worn = { [1] = 60 }, total = 1000 }
local function with(t, extra) local o = {} for k, v in pairs(t) do o[k] = v end for k, v in pairs(extra) do o[k] = v end return o end

local r = TT.evaluate(with(base, { places = { { inv = 1, points = 87 } } }))
T.near("87 of 100 BiS points", r.pct, 0.87)
T.near("gain: 27 of 1000 readiness points", r.gain, 0.027)

r = TT.evaluate(with(base, { places = { { inv = 1, points = 130 } } }))
T.near("better than BiS shows above 100%", r.pct, 1.3)
T.near("but gains only up to BiS", r.gain, 0.04)

r = TT.evaluate(with(base, { places = { { inv = 1, points = 40 } } }))
T.near("a downgrade has its %", r.pct, 0.4)
T.eq("and no gain", r.gain, nil)

r = TT.evaluate(with(base, { places = { { inv = 1, points = 60, worn = true } } }))
T.eq("the worn item gains nothing", r.gain, nil)
T.eq("and says it is worn", r.worn, true)

r = TT.evaluate({ bis = { [1] = 100 }, worn = {}, total = 1000, places = { { inv = 1, points = 50 } } })
T.near("an empty slot gains the whole item", r.gain, 0.05)

r = TT.evaluate({ bis = {}, worn = {}, total = 1000, places = { { inv = 1, points = 50 } } })
T.eq("no BiS for the slot: nothing to compare", r, nil)

r = TT.evaluate(with(base, { places = { { inv = 1, points = 70, setGain = 10 } } }))
T.near("a set bonus it completes counts", r.gain, 0.02) -- 10 item + 10 set

r = TT.evaluate(with(base, { places = { { inv = 1, points = 80, setGain = -30 } } }))
T.eq("a set it breaks can make it no upgrade", r.gain, nil)

r = TT.evaluate(with(base, { total = 0, places = { { inv = 1, points = 80 } } }))
T.eq("no readiness total: no gain", r.gain, nil)

-- Pairs: against the weaker BiS piece (the bar to make the pair), replacing the weaker worn one -----------
local rings = { bis = { [11] = 50, [12] = 40 }, worn = { [11] = 45, [12] = 20 }, total = 1000 }
r = TT.evaluate(with(rings, { places = { { inv = 11, points = 36 }, { inv = 12, points = 36 } } }))
T.near("ring % of the weaker BiS ring", r.pct, 0.9)
T.near("replaces the weaker worn ring", r.gain, 0.016) -- min(36+45, 90) - 65
T.eq("the slot it replaces", r.inv, 12)

r = TT.evaluate(with(rings, { places = { { inv = 11, points = 60 }, { inv = 12, points = 60 } } }))
T.near("a pair caps at the BiS pair", r.gain, 0.025) -- min(60+45, 90) - 65

r = TT.evaluate(with(rings, { places = { { inv = 11, points = 30, setGain = 30 }, { inv = 12, points = 30 } } }))
T.eq("a set gain on one side picks that side", r.inv, 11)
T.near("its gain", r.gain, 0.015) -- min(30+20, 90) - 65 + 30

r = TT.evaluate(with(rings, { id = 7, bisIDs = { [11] = 7, [12] = 8 }, places = { { inv = 11, points = 50 }, { inv = 12, points = 50 } } }))
T.near("the stronger BiS ring is 100% of itself, not of the weaker", r.pct, 1)

-- Weapons: one group, BiS of both hands together ------------------------------------------------------------
local staff = { bis = { [16] = 200 }, worn = { [16] = 150 }, wornTwoHand = true, total = 1000 }
r = TT.evaluate(with(staff, { places = { { inv = 16, points = 180, twoHand = true } } }))
T.near("two-hander against a two-hand BiS", r.pct, 0.9)
T.near("two-hander gain", r.gain, 0.03)

local dual = { bis = { [16] = 120, [17] = 80 }, worn = { [16] = 100, [17] = 50 }, total = 1000 }
r = TT.evaluate(with(dual, { places = { { inv = 16, points = 180, twoHand = true } } }))
T.near("two-hander against the BiS pair", r.pct, 0.9)
T.near("it replaces both hands", r.gain, 0.03) -- 180 - 150

r = TT.evaluate(with(dual, { places = { { inv = 17, points = 60, offHand = true } } }))
T.near("off hand against the BiS off hand", r.pct, 0.75)
T.near("off hand gain keeps the main hand", r.gain, 0.01)

r = TT.evaluate(with(staff, { places = { { inv = 16, points = 120 } } }))
T.near("one-hander against a two-hand BiS", r.pct, 0.6)
T.eq("a one-hander alone loses to the staff", r.gain, nil)

r = TT.evaluate(with(staff, { places = { { inv = 17, points = 40, offHand = true } } }))
T.near("off hand with a two-hand BiS: against the two-hander", r.pct, 0.2)
T.eq("an off hand for a staff wearer drops the staff", r.gain, nil)

-- The line ---------------------------------------------------------------------------------------------------
T.eq("line with a gain", TT.line(nil, { pct = 0.874, gain = 0.04 }), "Prepped: 87% of BiS · +4% readiness")
T.eq("small gains keep a decimal", TT.line(nil, { pct = 0.5, gain = 0.004 }), "Prepped: 50% of BiS · +0.4% readiness")
T.eq("a gain under 0.05% shows none", TT.line(nil, { pct = 0.5, gain = 0.0004 }), "Prepped: 50% of BiS")
T.eq("no gain", TT.line(nil, { pct = 0.4 }), "Prepped: 40% of BiS")
T.eq("worn", TT.line(nil, { pct = 1, worn = true }), "Prepped: 100% of BiS · worn")
T.eq("labelled spec", TT.line("Bear", { pct = 0.92, gain = 0.01 }), "Prepped (Bear): 92% of BiS · +1% readiness")
T.eq("never below 0%", TT.line(nil, { pct = -0.2 }), "Prepped: 0% of BiS")
T.eq("unscored", TT.line(nil, nil), "Not scored by Prepped")
T.eq("unscored for a spec", TT.line("Bear", nil), "Not scored by Prepped (Bear)")

T.done()
