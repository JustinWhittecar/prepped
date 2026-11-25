local T = dofile("test/lib.lua")
local ns = T.load({}, "Buffs.lua")
local B = ns.Buffs

local FLASK = { id = 13510, name = "Flask of the Titans" }
local MONGOOSE = { id = 13452, name = "Elixir of the Mongoose" }
-- Slots as Consumables.plan gives them in raid mode: have 1 = buff up, 0 = missing.
local function slots()
  return {
    { slot = "flask", item = FLASK, have = 1, need = 1 },
    { slot = "agility", item = MONGOOSE, have = 0, need = 1 },
  }
end
local function names(list) local o = {} for i, r in ipairs(list) do o[i] = r.item.name end return table.concat(o, ", ") end

-- In a raid: the missing buff is reminded, the active one isn't.
T.eq("raid: missing only", names(B.missing({ instance = "raid", slots = slots(), stock = {} })), "Elixir of the Mongoose")

-- Not in an instance, or in combat: nothing (buffs are checked out of combat).
T.eq("open world: none", #B.missing({ instance = "none", slots = slots(), stock = {} }), 0)
T.eq("in combat: none", #B.missing({ instance = "raid", inCombat = true, slots = slots(), stock = {} }), 0)

-- Raids only: Prepped never reminds in 5-player dungeons (that is DungeonKit's job), whatever is passed.
local noFlask = { { slot = "flask", item = FLASK, have = 0, need = 1 }, { slot = "agility", item = MONGOOSE, have = 0, need = 1 } }
T.eq("dungeon: none", #B.missing({ instance = "party", slots = noFlask, stock = {} }), 0)
T.eq("dungeon, old option set: still none", #B.missing({ instance = "party", dungeons = true, slots = noFlask, stock = {} }), 0)
T.eq("raid asks for the flask", names(B.missing({ instance = "raid", slots = noFlask, stock = {} })), "Flask of the Titans, Elixir of the Mongoose")

-- An unreadable buff is unknown and never nags; potions are stock only, never reminded.
local odd = {
  { slot = "agility", item = MONGOOSE, unknown = true, have = 0, need = 0 },
  { slot = "potion", item = { id = 13446, name = "Major Healing Potion" }, have = 0, need = 1 },
}
T.eq("unknown and potion: none", #B.missing({ instance = "raid", slots = odd, stock = {} }), 0)

-- Each reminder carries the bag count, so the button can say "(none)" instead of doing nothing.
local r = B.missing({ instance = "raid", slots = noFlask, stock = { [13452] = 4 } })
T.eq("flask none in bags", r[1].bags, 0)
T.eq("mongoose in bags", r[2].bags, 4)

T.done()
