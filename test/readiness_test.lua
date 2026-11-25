local T = dofile("test/lib.lua")
local ns = T.load({}, "Readiness.lua")
local R = ns.Readiness

-- BiS gear but no enchants or consumables: gear is only its share of the total, not 100%.
local r = R.compute({
  gear        = { have = 100, bis = 100 },
  enchants    = { have = 0,   bis = 20 },
  consumables = { have = 0,   bis = 30 },
})
T.near("BiS gear alone = gear share of total", r.pct, 100 / 150)

-- Breakdown: each part as a share of its own maximum.
r = R.compute({
  gear        = { have = 80, bis = 100 },
  enchants    = { have = 10, bis = 20 },
  consumables = { have = 30, bis = 30 },
})
T.near("total", r.pct, 0.8) -- 120 / 150
T.near("gear share", r.gear, 0.8)
T.near("enchant share", r.enchants, 0.5)
T.near("consumable share", r.consumables, 1.0)

-- Steps: gains in points become gains in % of readiness, biggest first.
r = R.compute({
  gear        = { have = 80, bis = 100 },
  enchants    = { have = 10, bis = 20 },
  consumables = { have = 30, bis = 30 },
}, {
  { label = "Elixir of the Mongoose", gain = 3 },
  { label = "Superior Agility on bracers", gain = 4.5 },
  { label = "Hand of Justice", gain = 1, id = 11815 },
})
T.eq("biggest next step", r.next.label, "Superior Agility on bracers")
T.near("its gain in %", r.next.gain, 0.03) -- 4.5 of 150 BiS points
T.eq("steps ordered", r.steps[2].label, "Elixir of the Mongoose")
T.near("second gain in %", r.steps[2].gain, 0.02)
T.eq("a step keeps its item id", r.steps[3].id, 11815)

-- A slot's enchant always comes after the slot's BiS item, however big its gain: the enchant goes on
-- the new item. Steps for other slots keep their order.
r = R.compute({
  gear        = { have = 80, bis = 100 },
  enchants    = { have = 0,  bis = 20 },
  consumables = { have = 0,  bis = 0 },
}, {
  { label = "Crusader on main hand", gain = 6, inv = 16, kind = "enchant" },
  { label = "Agility on bracers", gain = 5, inv = 9, kind = "enchant" },
  { label = "Mongoose", gain = 3 },
  { label = "Bonecrusher", gain = 2, inv = 16, kind = "gear", id = 18420 },
})
local order = {}
for i, s in ipairs(r.steps) do order[i] = s.label end
T.eq("enchant after its slot's BiS", table.concat(order, ", "), "Agility on bracers, Mongoose, Bonecrusher, Crusader on main hand")
T.eq("next is not the moved enchant", r.next.label, "Agility on bracers")

-- Tier 0.5 pieces come from one quest chain: they take their turns in chain order (chain = the quest's
-- step), in the places the gain sort gave tier 0.5 steps. Other steps keep their places.
r = R.compute({
  gear        = { have = 80, bis = 100 },
  enchants    = { have = 0,  bis = 20 },
  consumables = { have = 0,  bis = 0 },
}, {
  { label = "Feralheart Cap", gain = 8, inv = 1, kind = "gear", chain = 4 },
  { label = "Timbermaw Tunic", gain = 6, inv = 5, kind = "gear" },
  { label = "Feralheart Epaulets", gain = 2, inv = 3, kind = "gear", chain = 3 },
  { label = "Agility on head", gain = 1.5, inv = 1, kind = "enchant" },
  { label = "Feralheart Walkers", gain = 1, inv = 8, kind = "gear", chain = 3 },
})
order = {}
for i, s in ipairs(r.steps) do order[i] = s.label end
T.eq("tier 0.5 in chain order", table.concat(order, ", "),
  "Feralheart Epaulets, Timbermaw Tunic, Feralheart Walkers, Feralheart Cap, Agility on head")

-- A part with nothing at BiS (no data, or no slots for the spec) has no share, never NaN.
r = R.compute({
  gear        = { have = 50, bis = 100 },
  enchants    = { have = 0,  bis = 0 },
  consumables = { have = 0,  bis = 0 },
})
T.eq("empty part has no share", r.enchants, nil)
T.near("total from the parts that exist", r.pct, 0.5)

-- Nothing scored at all: no readiness number.
r = R.compute({
  gear        = { have = 0, bis = 0 },
  enchants    = { have = 0, bis = 0 },
  consumables = { have = 0, bis = 0 },
}, { { label = "x", gain = 1 } })
T.eq("nothing scored -> no pct", r.pct, nil)
T.eq("nothing scored -> no next step", r.next, nil)

T.done()
