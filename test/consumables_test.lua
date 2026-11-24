local T = dofile("test/lib.lua")
local ns = T.load({}, "Consumables.lua")
local C = ns.Consumables

-- Stat weights for these tests (SimGear keys): 1 point per Agility or Strength, 10 per % crit,
-- 0.1 per health point, 0.5 per attack power.
local W = { Agility = 1, Strength = 1, MeleeCrit = 10, Health = 0.1, AttackPower = 0.5 }
local function score(stats)
  local s = 0
  for k, v in pairs(stats) do s = s + (W[k] or 0) * v end
  return s
end
local function plan(opts)
  opts.score = opts.score or score
  opts.stock = opts.stock or {}
  opts.raidHours = opts.raidHours or 3
  return C.plan(opts)
end
-- The row a plan gives for an item, or for a family.
local function rowOf(p, id)
  for _, r in ipairs(p.rows) do if r.item and r.item.id == id then return r end end
end
local function familyRow(p, family)
  for _, r in ipairs(p.rows) do if r.slot == family then return r end end
end
local function names(p, family)
  local o = {}
  for _, r in ipairs(p.rows) do if r.slot == family and r.item then o[#o + 1] = r.item.name end end
  table.sort(o)
  return table.concat(o, ", ")
end

local TITANS = { id = 13510, name = "Flask of the Titans", family = "flask", stats = { Health = 400 }, duration = 7200 }

-- Needed = ceil(raid length / duration): a 2-hour flask on a 3-hour night needs 2.
local p = plan({ catalog = { TITANS } })
local flask = familyRow(p, "flask")
T.eq("flask row", flask and flask.item.id, 13510)
T.eq("needed", flask.need, 2)
T.eq("have", flask.have, 0)
T.eq("full points", flask.max, 40)
T.eq("earned points", flask.points, 0)

-- Partial stock counts partially: 1 of the 2 needed is half the points.
local function flaskWith(count) return familyRow(plan({ catalog = { TITANS }, stock = { [13510] = count } }), "flask") end
T.eq("1 of 2 -> half points", flaskWith(1).points, 20)
T.eq("2 of 2 -> full points", flaskWith(2).points, 40)
T.eq("5 of 2 -> capped at full", flaskWith(5).points, 40)

-- One flask: the highest-scoring one, price ignored; a pick overrides it, "none" drops it.
local WEAK = { id = 1, name = "Weak flask", family = "flask", stats = { Health = 100 }, duration = 7200 }
T.eq("best flask", familyRow(plan({ catalog = { WEAK, TITANS } }), "flask").item.id, 13510)
T.eq("picked flask", familyRow(plan({ catalog = { WEAK, TITANS }, picks = { flask = 1 } }), "flask").item.id, 1)
T.eq("flask none", familyRow(plan({ catalog = { WEAK, TITANS }, picks = { flask = "none" } }), "flask"), nil)

-- Totals across rows feed Readiness's consumables part.
local MONGOOSE = { id = 13452, name = "Elixir of the Mongoose", family = "buff", stats = { Agility = 25, MeleeCrit = 2 }, duration = 1800 }
local both = plan({ catalog = { TITANS, MONGOOSE }, stock = { [13510] = 1, [13452] = 6 } })
T.eq("mongoose needs 6 half-hour elixirs", rowOf(both, 13452).need, 6)
T.eq("total have", both.have, 65) -- flask 20 of 40 + Mongoose 45 of 45
T.eq("total bis", both.bis, 85)

-- Inside a raid instance a row counts by its active buff (by item), not by stock.
local function raid(auras)
  return plan({ catalog = { TITANS, MONGOOSE }, stock = { [13510] = 5, [13452] = 5 }, auras = auras })
end
local r = raid({ [13510] = true })
T.eq("flask up -> full", rowOf(r, 13510).points, 40)
T.eq("mongoose down -> nothing, stock ignored", rowOf(r, 13452).points, 0)
T.eq("raid have", r.have, 40)
T.eq("raid bis", r.bis, 85)
-- An unreadable buff: not scored either way, flagged so no reminder fires.
r = raid({ [13510] = true, [13452] = "unknown" })
T.eq("unknown flagged", rowOf(r, 13452).unknown, true)
T.eq("unknown left out of bis", r.bis, 40)
T.eq("unknown left out of have", r.have, 40)

-- One buff per stat, whatever kind: an elixir and a scroll of the same stat conflict (seen in game
-- 2026-11-23), so only the better one is planned. Different stats stack. A buff worth nothing is left out.
local GREATER_AGI = { id = 9187, name = "Elixir of Greater Agility", family = "buff", stats = { Agility = 25 }, duration = 3600 }
local SCROLL_AGI = { id = 10309, name = "Scroll of Agility IV", family = "buff", stats = { Agility = 17 }, duration = 1800 }
local GREATER_STR = { id = 9206, name = "Elixir of Greater Strength", family = "buff", stats = { Strength = 25 }, duration = 3600 }
local MANA = { id = 20007, name = "Mageblood Elixir", family = "buff", stats = { Mp5 = 12 }, duration = 3600 }
local stack = plan({ catalog = { SCROLL_AGI, GREATER_AGI, MONGOOSE, GREATER_STR, MANA } })
T.eq("best per stat", names(stack, "buff"), "Elixir of Greater Strength, Elixir of the Mongoose")

-- The best combination, not the best item first: a two-stat elixir worth 60 blocks both
-- Mongoose (45) and Greater Strength (25), which together are worth 70.
local TWO_STAT = { id = 90002, name = "Test two-stat elixir", family = "buff", stats = { Agility = 30, Strength = 30 }, duration = 1800 }
T.eq("best combination", names(plan({ catalog = { TWO_STAT, MONGOOSE, GREATER_STR } }), "buff"),
  "Elixir of Greater Strength, Elixir of the Mongoose")

-- Crit: whether Mongoose's and Grizzly's +2% crit both count is untested, so by default a shared
-- crit stat is a conflict; once tested, critStacks lets them both in.
local GRIZZLY = { id = 90003, name = "Elixir of the Grizzly", family = "buff", stats = { Strength = 25, MeleeCrit = 2 }, duration = 1800 }
local function buffCount(p) local n = 0 for _, row in ipairs(p.rows) do if row.slot == "buff" then n = n + 1 end end return n end
T.eq("shared crit conflicts by default", buffCount(plan({ catalog = { MONGOOSE, GRIZZLY } })), 1)
T.eq("critStacks lets both in", buffCount(plan({ catalog = { MONGOOSE, GRIZZLY }, critStacks = true })), 2)

-- A pick per stat (the options dropdowns): the picked buff is planned, and the rest is planned around it.
-- Scroll of Agility for Agility rules out Mongoose, which frees crit for Grizzly.
T.eq("picked scroll", names(plan({ catalog = { MONGOOSE, SCROLL_AGI, GREATER_STR, GRIZZLY }, picks = { Agility = 10309 } }), "buff"),
  "Elixir of the Grizzly, Scroll of Agility IV")
-- "none" for a stat: nothing that raises it.
T.eq("no agility", names(plan({ catalog = { MONGOOSE, GREATER_AGI, GREATER_STR }, picks = { Agility = "none" } }), "buff"),
  "Elixir of Greater Strength")

-- Filters: the defaults skip what the player has excluded (here a reputation reward); a pick still wins.
local REP_ELIXIR = { id = 90001, name = "Test reputation elixir", family = "buff", stats = { Agility = 60 }, duration = 3600, source = "reputation" }
local REP_FLASK = { id = 90004, name = "Test reputation flask", family = "flask", stats = { Health = 900 }, duration = 7200, source = "reputation" }
local function filtered(filters, picks)
  return plan({ catalog = { MONGOOSE, REP_ELIXIR, TITANS, REP_FLASK }, filters = filters, picks = picks })
end
T.eq("no filter -> rep elixir", names(filtered(nil), "buff"), "Test reputation elixir")
T.eq("reputation excluded -> Mongoose", names(filtered({ reputation = true }), "buff"), "Elixir of the Mongoose")
T.eq("reputation excluded -> Titans", familyRow(filtered({ reputation = true }), "flask").item.id, 13510)
T.eq("pick beats filter", names(filtered({ reputation = true }, { Agility = 90001 }), "buff"), "Test reputation elixir")

-- What a buff blocks can differ from how it scores: Greater Fortitude's health scores as Stamina
-- (SimGear has no health stat) but blocks only other health buffs, so Rumsey Rum's Stamina still fits.
W.Stamina = 1
local FORTITUDE = { id = 250335, name = "Elixir of Greater Fortitude", family = "buff", stats = { Stamina = 40 }, claims = { "Health" }, duration = 1800 }
local RUMSEY = { id = 21151, name = "Rumsey Rum Black Label", family = "buff", stats = { Stamina = 15 }, duration = 900 }
T.eq("claims decide conflicts", names(plan({ catalog = { FORTITUDE, RUMSEY } }), "buff"),
  "Elixir of Greater Fortitude, Rumsey Rum Black Label")

-- Potions are stock only: each listed potion is a row needing its per-night count, worth no points.
local HEALING = { id = 13446, name = "Major Healing Potion", family = "potion", stats = {}, perNight = 5 }
local FREE_ACTION = { id = 5634, name = "Free Action Potion", family = "potion", stats = {}, perNight = 2 }
local pots = plan({ catalog = { TITANS, HEALING, FREE_ACTION }, stock = { [13446] = 3, [5634] = 4 } })
T.eq("healing need", rowOf(pots, 13446) and rowOf(pots, 13446).need, 5)
T.eq("healing have", rowOf(pots, 13446) and rowOf(pots, 13446).have, 3)
T.eq("free action listed too", rowOf(pots, 5634) and rowOf(pots, 5634).slot, "potion")
T.eq("potions add no points", pots.bis, 40)

T.done()
