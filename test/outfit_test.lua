local T = dofile("test/lib.lua")
local ns = T.load({}, "SimGearShim.lua", "vendor/SimGear/Stats.lua", "vendor/SimGear/HitCap.lua", "vendor/SimGear/Score.lua",
  "Bis.lua", "Outfit.lua")
local O, B = ns.Outfit, ns.Bis

local function c(key, slot) return { id = key, item = { slot = slot or "INVTYPE_HEAD" }, points = 1 } end
local function invs(moves)
  local out = {}
  for _, m in ipairs(moves) do out[#out + 1] = m.inv .. "=" .. tostring(m.key) end
  return table.concat(out, " ")
end

-- Single slots: only where the best differs from what's worn, and never to empty a slot.
T.eq("worn is best: nothing", invs(O.plan({ [1] = c("A") }, { [1] = "A" })), "")
T.eq("better head", invs(O.plan({ [1] = c("B") }, { [1] = "A" })), "1=B")
T.eq("empty slot filled", invs(O.plan({ [5] = c("C", "INVTYPE_CHEST") }, {})), "5=C")
T.eq("nothing worth wearing: slot left empty", invs(O.plan({ [18] = { id = "I", item = { slot = "INVTYPE_RELIC" }, points = 0 } }, {})), "")
T.eq("no best: slot kept", invs(O.plan({}, { [1] = "A" })), "")

-- Rings and trinkets: a chosen item already worn stays where it is; the new one takes the other slot.
local R = "INVTYPE_FINGER"
T.eq("worn ring kept in place", invs(O.plan({ [11] = c("A", R), [12] = c("N", R) }, { [11] = "X", [12] = "A" })), "11=N")
T.eq("both worn, swapped order: nothing", invs(O.plan({ [11] = c("A", R), [12] = c("B", R) }, { [11] = "B", [12] = "A" })), "")
T.eq("two new rings", invs(O.plan({ [11] = c("N", R), [12] = c("M", R) }, { [11] = "X", [12] = "Y" })), "11=N 12=M")

-- Weapons: a two-hander replaces both hands in one move; a pair goes main hand first.
local TWO, ONE, HOLD = "INVTYPE_2HWEAPON", "INVTYPE_WEAPON", "INVTYPE_HOLDABLE"
T.eq("two-hander over a pair", invs(O.plan({ [16] = c("S", TWO) }, { [16] = "M", [17] = "H" })), "16=S")
T.eq("pair over a two-hander, main hand first", invs(O.plan({ [16] = c("M", ONE), [17] = c("H", HOLD) }, { [16] = "S" })), "16=M 17=H")
T.eq("same two-hander: nothing", invs(O.plan({ [16] = c("S", TWO) }, { [16] = "S" })), "")

-- Bis.pick over what you own: no sources needed, filters off, and a tie keeps what you wear.
local CAT = { weights = { Agility = 2 }, source = { kind = "sim" } }
local owned = {
  [1] = { slot = "INVTYPE_HEAD", stats = { Agility = 10 } },  -- worn
  [2] = { slot = "INVTYPE_HEAD", stats = { Agility = 10 } },  -- in bags, same score
  [3] = { slot = "INVTYPE_CHEST", stats = { Agility = 5 } },
}
local bis = B.pick({ items = owned, weightSet = CAT, owned = true, prefer = { [1] = true } })
T.eq("owned items need no source", bis[5] and bis[5].id, 3)
T.eq("tie keeps the worn head", bis[1] and bis[1].id, 1)
T.eq("without owned, sourceless items are skipped", B.pick({ items = owned, weightSet = CAT })[5], nil)
T.eq("prefer doesn't change the points", bis[1].points, 20)

T.done()
