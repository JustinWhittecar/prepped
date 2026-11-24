local T = dofile("test/lib.lua")
local ns = T.load({}, "Sync.lua")
local S = ns.Sync

-- Spec keys: the sheet knows Raid Ready's cat and bear; any other spec is its SimGear key in lower case.
T.eq("cat key", S.specKey("FERAL_CAT"), "cat")
T.eq("bear key", S.specKey("FERAL_BEAR"), "bear")
T.eq("other key", S.specKey("FURY"), "fury")

local LINK = "|cnIQ3:|Hitem:15063:8206:::::::60|h[Devilsaur Gauntlets]|h|r"
local catMeasured = {
  readiness = { pct = 0.684, gear = 0.8, enchants = 0, consumables = 0.44 },
  slots = { { slot = "Head", id = 226792, pct = 0.6449 }, { slot = "Neck", id = 15411, pct = 1 } },
  enchants = {
    { key = "hands", pct = 0.6667, enchanted = true, text = "Agility", link = LINK },
    { key = "twohand", pct = 0, enchanted = false, link = "item:943" },
    { key = "back", pct = 0, enchanted = false },
  },
}

local s = S.build({
  at = 1795501681, spec = "FERAL_CAT", specs = { "FERAL_CAT", "FERAL_BEAR" },
  measured = { FERAL_CAT = catMeasured },
  cons = { FERAL_CAT = { [13452] = 1, [12820] = 22 }, FERAL_BEAR = { [13445] = 48 } },
  owned = { [15411] = true, [13340] = true },
})

-- Top level: the same fields Raid Ready writes.
T.eq("at", s.at, 1795501681)
T.eq("spec", s.spec, "cat")
-- owned: a sorted list of item IDs, as Raid Ready writes it.
T.eq("owned count", #s.owned, 2)
T.eq("owned sorted", s.owned[1] .. "," .. s.owned[2], "13340,15411")

-- ready: fractions, under Raid Ready's names (ench, cons, total).
T.near("ready gear", s.ready.cat.gear, 0.8)
T.near("ready ench", s.ready.cat.ench, 0)
T.near("ready cons", s.ready.cat.cons, 0.44)
T.near("ready total", s.ready.cat.total, 0.684)

-- slots: a list of the worn item and its share of the slot's BiS, pct in percent to one decimal.
T.eq("slot label", s.slots.cat[1].slot, "Head")
T.eq("slot id", s.slots.cat[1].id, 226792)
T.eq("slot pct rounded", s.slots.cat[1].pct, 64.5)
T.eq("slot full", s.slots.cat[2].pct, 100)

-- enchants: by slot key, Prepped's weapon rows under Raid Ready's mainhand.
T.eq("enchant pct", s.enchants.cat.hands.pct, 66.7)
T.eq("enchant enchanted", s.enchants.cat.hands.enchanted, true)
T.eq("enchant text", s.enchants.cat.hands.text, "Agility")
T.eq("enchant link", s.enchants.cat.hands.link, LINK)
T.eq("two-hand row is mainhand", s.enchants.cat.mainhand.pct, 0)
T.eq("no twohand key", s.enchants.cat.twohand, nil)
T.eq("unenchanted", s.enchants.cat.back.enchanted, false)
T.eq("no text when none", s.enchants.cat.back.text, nil)

-- cons: fresh counts for every known spec.
T.eq("cons cat", s.cons.cat[12820], 22)
T.eq("cons bear", s.cons.bear[13445], 48)

-- A known spec never measured and with nothing to carry over: absent, not invented.
T.eq("bear ready absent", s.ready.bear, nil)
T.eq("bear slots absent", s.slots.bear, nil)

-- Next write while Bear is active: Cat's ready, slots and enchants carry over from the last block
-- (what you wore as Cat), Bear's are fresh.
local bearMeasured = { readiness = { pct = 0.71, gear = 0.77, enchants = 0.57, consumables = 0.7 }, slots = {}, enchants = {} }
local s2 = S.build({
  at = 1795509999, spec = "FERAL_BEAR", specs = { "FERAL_BEAR", "FERAL_CAT" },
  measured = { FERAL_BEAR = bearMeasured },
  cons = { FERAL_CAT = { [12820] = 20 }, FERAL_BEAR = { [13445] = 40 } },
  owned = {}, previous = s,
})
T.eq("spec now bear", s2.spec, "bear")
T.near("bear fresh", s2.ready.bear.total, 0.71)
T.near("cat carried", s2.ready.cat.total, 0.684)
T.eq("cat slots carried", s2.slots.cat[1].pct, 64.5)
T.eq("cat enchants carried", s2.enchants.cat.hands.pct, 66.7)
-- Counts are never carried: bags change whatever the spec.
T.eq("cat cons fresh", s2.cons.cat[12820], 20)
-- A spec no longer known (its talent group changed) is dropped, not carried forever.
local s3 = S.build({ at = 1, spec = "FERAL_BEAR", specs = { "FERAL_BEAR" }, measured = { FERAL_BEAR = bearMeasured },
  cons = {}, owned = {}, previous = s2 })
T.eq("dropped spec", s3.ready.cat, nil)

-- Missing parts (nothing scored for enchants): 0, as Raid Ready writes it.
local s4 = S.build({ at = 1, spec = "FURY", specs = { "FURY" },
  measured = { FURY = { readiness = { gear = 0.5 }, slots = {}, enchants = {} } }, cons = {}, owned = {} })
T.eq("missing ench is 0", s4.ready.fury.ench, 0)
T.eq("missing total is 0", s4.ready.fury.total, 0)

-- Needs: which known specs have to be measured now (the active one always; others when nothing carries over).
local need = S.toMeasure("FERAL_CAT", { "FERAL_CAT", "FERAL_BEAR" }, s)
T.eq("measure active", need[1], "FERAL_CAT")
T.eq("measure uncarried other", need[2], "FERAL_BEAR")
need = S.toMeasure("FERAL_CAT", { "FERAL_CAT", "FERAL_BEAR" }, s2)
T.eq("carried other not measured", #need, 1)

-- Slot rows from worn items and BiS, in Raid Ready's order and labels.
local worn = { [1] = { id = 10, points = 50 }, [11] = { id = 21, points = 30 }, [12] = { id = 22, points = 40 },
  [16] = { id = 943, points = 80 } }
local bis = { [1] = { id = 11, points = 100 }, [2] = { id = 12, points = 20 }, [11] = { id = 22, points = 40 },
  [12] = { id = 23, points = 60 }, [16] = { id = 944, points = 100 }, [18] = { id = 30, points = 10 } }
local rows = S.slotRows(worn, bis, true)
local function row(label) for _, r in ipairs(rows) do if r.slot == label then return r end end end
T.eq("first row head", rows[1].slot, "Head")
T.eq("head worn id", row("Head").id, 10)
T.near("head pct", row("Head").pct, 0.5)
T.eq("empty slot id 0", row("Neck").id, 0)
T.near("empty slot pct 0", row("Neck").pct, 0)
-- A ring worn in slot 12 that is slot 11's BiS sits on slot 11's row, as Raid Ready pairs them.
T.eq("ring paired id", row("Finger 1").id, 22)
T.near("ring paired pct", row("Finger 1").pct, 1)
T.eq("other ring", row("Finger 2").id, 21)
T.near("other ring pct", row("Finger 2").pct, 0.5)
T.near("weapon pct", row("Main Hand").pct, 0.8)
-- No off-hand BiS and nothing worn there: no row (a two-hander, as Raid Ready's druid rows).
T.eq("no off hand row", row("Off Hand"), nil)
T.eq("relic label", row("Relic").id, 0)
T.eq("ranged label for others", (function() for _, r in ipairs(S.slotRows(worn, bis, false)) do if r.slot == "Ranged" then return true end end end)(), true)
-- Worn better than BiS (a set piece scored alone): capped at 100%.
rows = S.slotRows({ [1] = { id = 10, points = 150 } }, { [1] = { id = 11, points = 100 } }, true)
T.near("capped", row("Head").pct, 1)
T.eq("labels count", #S.slotRows({}, {}, true), 16)

T.done()
