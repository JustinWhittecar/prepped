local T = dofile("test/lib.lua")
local ns = T.load({}, "SimGear.lua")
local S = ns.SimGear

local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

-- The real installed Druid data normalizes into Prepped's shape.
local global = T.simgearGlobal("Druid")
print("source: " .. T.SIMGEAR_DIR .. "/SimGearForever_Druid")
local data, why = S.load(global, "DRUID")
T.eq("loads", why, nil)
local items = count(data and data.items)
print("druid items: " .. items)
T.eq("thousands of items, not a stub", items > 1000, true)
T.eq("cat weight sets", data and type(data.specs.FERAL_CAT), "table")
T.eq("bear weight sets", data and type(data.specs.FERAL_BEAR), "table")
T.eq("generated date is a date", data and tostring(data.generated):match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil, true)

-- Anything not shaped like SimGear's data -> nil and a reason (caller falls back to the backup copy).
local function good()
  return { DRUID = {
    items = { items = { [1] = { stats = {}, slot = "INVTYPE_HEAD" } }, meta = {} },
    weights = { sets = { FERAL_CAT = { { weights = { Agility = 2 }, source = { kind = "sim" } } } },
                meta = { generated = "2026-11-05" } },
  } }
end
T.eq("small good fixture loads", select(2, S.load(good(), "DRUID")), nil)
local cases = {
  { "SimGear not installed", function() return nil end },
  { "class not loaded", function(g) g.DRUID = nil return g end },
  { "weights without sets", function(g) g.DRUID.weights = { FERAL_CAT = {} } return g end },
  { "items not under .items", function(g) g.DRUID.items = { [1] = {} } return g end },
  { "weight set without source", function(g) g.DRUID.weights.sets.FERAL_CAT[1].source = nil return g end },
  { "weight set without weights", function(g) g.DRUID.weights.sets.FERAL_CAT[1].weights = nil return g end },
}
for _, c in ipairs(cases) do
  local d, reason = S.load(c[2](good()), "DRUID")
  T.eq(c[1] .. " -> nil", d, nil)
  T.eq(c[1] .. " -> has a reason", type(reason), "string")
end

-- Every installed class loads, not just Druid.
for _, cls in ipairs({ "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior" }) do
  local key = cls:upper()
  local d, reason = S.load(T.simgearGlobal(cls), key)
  local n = count(d and d.items)
  print(string.format("  %-8s items %5d  specs %d  %s", cls, n, count(d and d.specs), reason or ""))
  T.eq(cls .. " loads", reason, nil)
  T.eq(cls .. " has thousands of items", n > 1000, true)
end

T.done()
