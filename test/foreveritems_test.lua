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

-- Sources SimGear lacks (vendor items such as the Undermine Reals gear): an item with no source
-- gets Prepped's, as a copy (SimGear's tables are shared); one with sources keeps its own.
local sgItems = {
  [272396] = { name = "Shifter's Belt", slot = "INVTYPE_WAIST", stats = {}, sources = {} },
  [13340] = { name = "Cape of the Black Baron", slot = "INVTYPE_CLOAK", stats = {}, sources = { { kind = "drop" } } },
}
local extra = { [272396] = { kind = "vendor", text = "Pix Xizzix, Booty Bay · 100 Tarnished Undermine Reals" },
  [13340] = { kind = "vendor", text = "should not replace" }, [99999] = { kind = "vendor", text = "not an item here" } }
local merged = F.addSources(sgItems, extra)
T.eq("vendor source added", merged[272396].sources[1].text, "Pix Xizzix, Booty Bay · 100 Tarnished Undermine Reals")
T.eq("SimGear's table untouched", #sgItems[272396].sources, 0)
T.eq("own sources kept", merged[13340].sources[1].kind, "drop")
T.eq("no new items", merged[99999], nil)

-- A vendor's price as text: currencies and items it costs, then gold.
T.eq("currency cost", F.costText(0, { { amount = 100, name = "Tarnished Undermine Real" } }), "100 Tarnished Undermine Real")
T.eq("gold and item", F.costText(250000, { { amount = 2, name = "Arcanite Bar" } }), "2 Arcanite Bar + 25g")
T.eq("gold only", F.costText(1500, {}), "15s")

-- A set's bonuses from tooltip lines: "(n) Set: text", in order; nil when the item has none.
local lines = { "Feralheart Faceguard", "Classes: Druid", "Feralheart Guardian (1/8)", "  Feralheart Faceguard",
  "(2) Set: +200 Armor.", "(4) Set: Increases your chance to dodge by 1%.", "(6) Set: +20 Stamina." }
local bonuses = F.setBonusesFrom(lines)
T.eq("three bonuses", bonuses and #bonuses, 3)
T.eq("count", bonuses and bonuses[2].count, 4)
T.eq("text", bonuses and bonuses[2].text, "Increases your chance to dodge by 1%.")
T.eq("no set", F.setBonusesFrom({ "Cloak of Warding", "Binds when picked up" }), nil)

-- A bonus line as SimGear stats; nil for one Prepped can't read (procs, resistances).
T.eq("attack power", F.bonusStats("+40 Attack Power.") and F.bonusStats("+40 Attack Power.").AttackPower, 40)
T.eq("strength", F.bonusStats("+20 Strength.") and F.bonusStats("+20 Strength.").Strength, 20)
T.eq("mana regen", F.bonusStats("Restores 8 mana per 5 sec.") and F.bonusStats("Restores 8 mana per 5 sec.").Mp5, 8)
local sp = F.bonusStats("Increases damage and healing done by magical spells and effects by up to 23.")
T.eq("spell power", sp and sp.SpellPower, 23)
T.eq("resistances not read", F.bonusStats("+8 All Resistances."), nil)
T.eq("proc not read", F.bonusStats("Chance on melee attack to restore 20 Energy."), nil)

T.done()
