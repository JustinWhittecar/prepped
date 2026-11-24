local T = dofile("test/lib.lua")
local A = dofile("tools/audit_lib.lua")

local function has(list, pat)
  for _, f in ipairs(list) do if f:find(pat, 1, true) then return true end end
  return false
end

-- A dungeon boss drop at a normal rate: nothing to look at.
local f = A.flags({ sources = { { type = "boss", origin = "cmangos", name = "Baron Rivendare", zone = "Stratholme", instance = "dungeon", chance = 0.11 } } })
T.eq("ordinary boss drop", #f, 0)

-- Rare: every source with a known chance is under 2%.
f = A.flags({ sources = { { type = "chest", origin = "cmangos", name = "Secret Safe", zone = "Blackrock Depths", chance = 0.002 },
  { type = "drop", origin = "cmangos", name = "Warbringer Construct", chance = 0.0002 } } })
T.eq("rare drop flagged", has(f, "rare: best chance 0.2%"), true)
-- One good source is enough.
f = A.flags({ sources = { { type = "drop", chance = 0.001 }, { type = "quest", origin = "client", name = "In Dreams" } } })
T.eq("a quest as well: not rare", has(f, "rare"), false)

-- Kinds that deserve a look when they're the only way to get it.
T.eq("world drop only", has(A.flags({ sources = { { type = "world", origin = "cmangos" } } }), "world drop only"), true)
T.eq("open-world mob only", has(A.flags({ sources = { { type = "drop", origin = "cmangos", name = "Emeriss", chance = 0.1 } } }), "open-world mob only"), true)
T.eq("dungeon mob is not open-world", has(A.flags({ sources = { { type = "drop", instance = "dungeon", chance = 0.1 } } }), "open-world"), false)
T.eq("quest only in cMaNGOS", has(A.flags({ sources = { { type = "quest", origin = "cmangos", name = "Cenarion Battlegear" } } }), "quest only in cMaNGOS"), true)
T.eq("community reports only", has(A.flags({ sources = { { type = "boss", origin = "seen" }, { type = "drop", origin = "lead" } } }), "community reports only"), true)
T.eq("Prepped's own sources were found in game: not flagged", #A.flags({ sources = { { kind = "vendor", text = "Pix Xizzix" } } }), 0)
T.eq("no source", has(A.flags({ sources = {} }), "no source"), true)

-- A source in a line: kind, name, where, chance.
T.eq("source text", A.sourceText({ type = "boss", origin = "cmangos", name = "Baron Rivendare", zone = "Stratholme", chance = 0.1105 }),
  "boss Baron Rivendare (Stratholme) 11.1% [cmangos]")
T.eq("Prepped source text", A.sourceText({ kind = "reputation", text = "Timbermaw Hold, Exalted" }), "reputation: Timbermaw Hold, Exalted")

T.done()
