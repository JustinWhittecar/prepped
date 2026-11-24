local T = dofile("test/lib.lua")
local ns = T.load({}, "ForeverItems.lua")
local F = ns.ForeverItems

-- The tooltip's "Classes:" line gives the classes that can use an item, as class tokens.
local TOKENS = { Druid = "DRUID", Warrior = "WARRIOR", Paladin = "PALADIN" }
local c = F.classesFrom({ "Feralheart Faceguard", "Binds when picked up", "Classes: Druid", "Durability 70 / 70" }, TOKENS)
T.eq("one class", c and c.DRUID, true)
c = F.classesFrom({ "x", "Classes: Warrior, Paladin" }, TOKENS)
T.eq("two classes", c and c.WARRIOR and c.PALADIN, true)
T.eq("no Classes line", F.classesFrom({ "Cloak of Warding", "Binds when picked up" }, TOKENS), nil)

-- A harvested record: what the game reported, kept raw (stats as GetItemStats gives them).
local rec = F.record({ name = "Feralheart Faceguard", quality = 4, itemLevel = 66, minLevel = 60, equipLoc = "INVTYPE_HEAD" },
  { ITEM_MOD_STRENGTH_SHORT = 18, RESISTANCE0_NAME = 200 }, { DRUID = true })
T.eq("record name", rec.name, "Feralheart Faceguard")
T.eq("record slot", rec.slot, "INVTYPE_HEAD")
T.eq("record req", rec.req, 60)
T.eq("record raw stats", rec.raw.RESISTANCE0_NAME, 200)

-- For a class: SimGear-shaped items for the records that class can use and SimGear doesn't have,
-- stats normalized by the injected normalizer.
local function normalize(raw)
  local out = {}
  if raw.ITEM_MOD_STRENGTH_SHORT then out.Strength = raw.ITEM_MOD_STRENGTH_SHORT end
  if raw.RESISTANCE0_NAME then out.Armor = raw.RESISTANCE0_NAME end
  return out
end
local records = {
  [226801] = rec,
  [226900] = F.record({ name = "Warrior thing", quality = 4, itemLevel = 66, minLevel = 60, equipLoc = "INVTYPE_HEAD" },
    { ITEM_MOD_STRENGTH_SHORT = 20 }, { WARRIOR = true }),
  [226902] = F.record({ name = "Not wearable", quality = 1, itemLevel = 1, minLevel = 1, equipLoc = "" }, {}, { DRUID = true }),
  [18531] = F.record({ name = "Unyielding Maul", quality = 3, itemLevel = 61, minLevel = 56, equipLoc = "INVTYPE_2HWEAPON" },
    { ITEM_MOD_STRENGTH_SHORT = 1 }, { DRUID = true }),
}
local have = { [18531] = { name = "Unyielding Maul (SimGear)" } }
local items = F.forClass(records, "DRUID", have, normalize)
T.eq("druid gets its item", items[226801] and items[226801].name, "Feralheart Faceguard")
T.eq("normalized stats", items[226801] and items[226801].stats.Armor, 200)
T.eq("has a source, so BiS can target it", items[226801] and #items[226801].sources, 1)
T.eq("source says where it came from", items[226801] and items[226801].sources[1].kind, "forever")
T.eq("slot carried", items[226801] and items[226801].slot, "INVTYPE_HEAD")
T.eq("other class left out", items[226900], nil)
T.eq("nothing to equip left out", items[226902], nil)
T.eq("SimGear's own record wins", items[18531], nil)

T.done()
