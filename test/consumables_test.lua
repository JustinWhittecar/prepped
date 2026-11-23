local T = dofile("test/lib.lua")
local ns = T.load({}, "Consumables.lua")
local C = ns.Consumables

local TITANS = { id = 13510, name = "Flask of the Titans", slot = "flask", stats = { HEALTH = 400 }, duration = 7200 }
local function score(stats) return stats.HEALTH and stats.HEALTH / 10 or 0 end

-- Needed = ceil(raid length / duration): a 2-hour flask on a 3-hour night needs 2.
local plan = C.plan({
  catalog = { TITANS }, slots = { "flask" }, score = score,
  stock = {}, raidHours = 3,
})
local flask = plan.slots[1]
T.eq("slot", flask.slot, "flask")
T.eq("default target", flask.item and flask.item.id, 13510)
T.eq("needed", flask.need, 2)
T.eq("have", flask.have, 0)
T.eq("full points", flask.max, 40)
T.eq("earned points", flask.points, 0)

-- Partial stock counts partially: 1 of the 2 needed is half the points.
local function flaskWith(count)
  return C.plan({ catalog = { TITANS }, slots = { "flask" }, score = score,
    stock = { [13510] = count }, raidHours = 3 }).slots[1]
end
T.eq("1 of 2 -> half points", flaskWith(1).points, 20)
T.eq("2 of 2 -> full points", flaskWith(2).points, 40)
T.eq("5 of 2 -> capped at full", flaskWith(5).points, 40)

-- Default target is the highest-scoring consumable for the slot, price ignored.
local MONGOOSE = { id = 13452, name = "Elixir of the Mongoose", slot = "agility", stats = { AGI = 25, CRIT = 2 }, duration = 3600 }
local GREATER_AGI = { id = 9187, name = "Elixir of Greater Agility", slot = "agility", stats = { AGI = 25 }, duration = 3600 }
local function agiScore(stats) return (stats.AGI or 0) + (stats.CRIT or 0) * 10 end
local agi = C.plan({ catalog = { MONGOOSE, GREATER_AGI }, slots = { "agility" }, score = agiScore,
  stock = { [9187] = 3 }, raidHours = 3 }).slots[1]
T.eq("top scorer is the default", agi.item.id, 13452)
T.eq("stock of the other elixir doesn't count", agi.have, 0)
T.eq("needs 3 one-hour elixirs", agi.need, 3)

-- Override: the chosen consumable is the target, counted at its own points.
local function agiWith(override)
  return C.plan({ catalog = { MONGOOSE, GREATER_AGI }, slots = { "agility" }, score = agiScore,
    stock = { [9187] = 3 }, raidHours = 3, overrides = { agility = override } }).slots[1]
end
local picked = agiWith(9187)
T.eq("override is the target", picked.item.id, 9187)
T.eq("override counted at its own points", picked.max, 25)
T.eq("override stock counts", picked.points, 25)
-- "None": the slot asks for nothing and adds nothing to the BiS total.
local none = agiWith("none")
T.eq("none -> no target", none.item, nil)
T.eq("none -> no max", none.max, 0)

-- Totals across slots feed Readiness's consumables part.
local function bothScore(stats) return score(stats) + agiScore(stats) end
local both = C.plan({ catalog = { TITANS, MONGOOSE }, slots = { "flask", "agility" }, score = bothScore,
  stock = { [13510] = 1, [13452] = 3 }, raidHours = 3 })
T.eq("total have", both.have, 65) -- flask 20 of 40 + Mongoose 45 of 45
T.eq("total bis", both.bis, 85)

-- Inside a raid instance a slot counts by its active buff, not by stock.
TITANS.aura = 17626
MONGOOSE.aura = 17538
local function raid(auras)
  return C.plan({ catalog = { TITANS, MONGOOSE }, slots = { "flask", "agility" }, score = bothScore,
    stock = { [13510] = 5, [13452] = 5 }, raidHours = 3, auras = auras })
end
local r = raid({ [17626] = true })
T.eq("flask up -> full", r.slots[1].points, 40)
T.eq("mongoose down -> nothing, stock ignored", r.slots[2].points, 0)
T.eq("raid have", r.have, 40)
T.eq("raid bis", r.bis, 85)
-- An unreadable aura: not scored either way, flagged so no reminder fires.
r = raid({ [17626] = true, [17538] = "unknown" })
T.eq("unknown flagged", r.slots[2].unknown, true)
T.eq("unknown left out of bis", r.bis, 40)
T.eq("unknown left out of have", r.have, 40)

-- Filters: the default skips consumables the player has excluded (here, a reputation reward).
local REP_ELIXIR = { id = 90001, name = "Test reputation elixir", slot = "agility", stats = { AGI = 60 }, duration = 3600, source = "reputation" }
local function agiFiltered(filters)
  return C.plan({ catalog = { MONGOOSE, REP_ELIXIR }, slots = { "agility" }, score = agiScore,
    stock = {}, raidHours = 3, filters = filters }).slots[1]
end
T.eq("no filter -> rep elixir wins", agiFiltered(nil).item.id, 90001)
T.eq("reputation excluded -> Mongoose", agiFiltered({ reputation = true }).item.id, 13452)

T.done()
