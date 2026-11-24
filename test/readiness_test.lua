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
