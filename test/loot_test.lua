local T = dofile("test/lib.lua")
local ns = T.load({}, "Loot.lua")
local L = ns.Loot

-- Item ID out of a chat link, Forever's |cnIQ quality prefix included.
T.eq("id from link", L.itemID("|cnIQ3:|Hitem:226788:7656:::::::60:1484::14:::::::|h[Feralheart Bands]|h|r"), 226788)
T.eq("id from bare item string", L.itemID("item:15411"), 15411)
T.eq("no id from a non-item link", L.itemID("|Hspell:768|h[Cat Form]|h"), nil)
T.eq("no id from nil", L.itemID(nil), nil)

local LINK = "[Feralheart Cap]"
local cat = { label = "Cat", bis = { [226792] = true, [15411] = true }, gains = { [226792] = 0.0234 } }
local bear = { label = "Bear", bis = { [226792] = true, [13340] = true }, gains = { [226792] = 0.011, [13340] = 0.015 } }

-- BiS for the active spec with a gain: one line, spec and gain in % of readiness.
T.eq("bis for active spec", L.message(226792, LINK, { cat }, false), "[Feralheart Cap] dropped: BiS for Cat (+2.3% readiness)")

-- BiS for two specs: both named, active first, each with its own gain.
T.eq("bis for both specs", L.message(226792, LINK, { cat, bear }, false),
  "[Feralheart Cap] dropped: BiS for Cat (+2.3% readiness), Bear (+1.1% readiness)")

-- Only the other spec wants it: still an alert.
T.eq("bis for other spec only", L.message(13340, "[Cape]", { cat, bear }, false), "[Cape] dropped: BiS for Bear (+1.5% readiness)")

-- A spec whose gains were never measured (never played since install): the gain is said to be unknown, not guessed.
local fresh = { label = "Bear", bis = { [13340] = true } }
T.eq("unmeasured spec", L.message(13340, "[Cape]", { cat, fresh }, false), "[Cape] dropped: BiS for Bear (gain not measured yet)")

-- BiS but no gain left (worn already, or an equal item worn): no alert for that spec.
T.eq("bis already worn", L.message(15411, "[Mark]", { cat }, false), nil)

-- Not BiS for any spec: nothing.
T.eq("not bis", L.message(999, "[Junk]", { cat, bear }, false), nil)

-- Already owned (bags, bank or worn): nothing, whatever the specs say.
T.eq("owned", L.message(226792, LINK, { cat, bear }, true), nil)

-- Rolls say "offered" rather than "dropped".
T.eq("roll wording", L.message(226792, LINK, { cat }, false, "roll"), "[Feralheart Cap] up for roll: BiS for Cat (+2.3% readiness)")

-- A tiny gain still shows as a number, not 0.0.
T.eq("tiny gain", L.message(1, "[X]", { { label = "Cat", bis = { [1] = true }, gains = { [1] = 0.0004 } } }, false),
  "[X] dropped: BiS for Cat (+<0.1% readiness)")

-- Known specs: the active one first, then the talent groups' choices, no repeats.
local specs = L.knownSpecs("FERAL_CAT", { "FERAL_CAT", "FERAL_BEAR" })
T.eq("known specs count", #specs, 2)
T.eq("known specs active first", specs[1], "FERAL_CAT")
T.eq("known specs other", specs[2], "FERAL_BEAR")
specs = L.knownSpecs("FERAL_BEAR", { [1] = "FERAL_CAT", [2] = "FERAL_BEAR" })
T.eq("known specs bear active", specs[1] .. "," .. specs[2], "FERAL_BEAR,FERAL_CAT")
specs = L.knownSpecs("FURY", {})
T.eq("known specs no groups", #specs, 1)
specs = L.knownSpecs(nil, {})
T.eq("known specs none", #specs, 0)

-- Gains snapshot from Readiness steps: item steps only, by item ID.
local g = L.gainsFrom({ { label = "Feralheart Cap", gain = 0.02, id = 226792 }, { label = "Superior Agility on hands", gain = 0.03 } })
T.eq("gains item", g[226792], 0.02)
local n = 0 for _ in pairs(g) do n = n + 1 end
T.eq("gains skip enchant steps", n, 1)

-- Dedupe: the same item within 30 seconds alerts once.
local seen = {}
T.eq("first alert", L.fresh(seen, 1, 100), true)
T.eq("repeat within 30s", L.fresh(seen, 1, 110), false)
T.eq("after 30s", L.fresh(seen, 1, 131), true)
T.eq("other item", L.fresh(seen, 2, 131), true)

T.done()
