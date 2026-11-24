-- Consumables: Prepped's own hand-kept list (SimGear has no consumable data). Pull requests welcome.
-- Values and durations are Forever's as RankedBoost's consumables guide gives them (updated 2026-11-20);
-- item IDs from ProfPlanner's Forever recipe data, Classic IDs for what nobody crafts (Jujus, Winterfall,
-- Rumsey, scrolls; 12820, 21151 and 10310 seen in a Forever character's bags).
--
-- Each entry: id, name, family, stats (SimGear keys and units), duration (seconds), and optionally:
--   claims  the stats it blocks, when that differs from what it scores (health scores as Stamina,
--           10 health = 1 Stamina; mana as Intellect, 15 mana = 1 Intellect)
--   roles   only these roles get it (none = everyone), so a tiny spell weight never puts a caster
--           buff on a melee spec
--   source  an Obtainable filter that leaves it out of the defaults
--   perNight  potions only: how many one raid night calls for
-- Families: flask (one), buff (one per stat: elixirs, scrolls, Jujus, Firewater; a scroll and an elixir
-- of one stat conflict, seen in game 2026-11-23), food (one Well Fed), weapon (one oil or stone),
-- potion (stock only).
-- Not listed yet: the Natural flasks (their bonus counts only in the raid zones) and the Blasted Lands
-- buffs (not confirmed on Forever).
local _, ns = ...

local H, M = 3600, 60
local CASTER, HEALER = { caster = true }, { healer = true }
local SPELL = { caster = true, healer = true }
local PHYSICAL = { melee = true, tank = true, ranged = true }

ns.ConsumableCatalog = {
  -- Flasks: 2 hours, stay on through death
  { id = 13510, name = "Flask of the Titans", family = "flask", stats = { Stamina = 120 }, duration = 2 * H },
  { id = 13512, name = "Flask of Supreme Power", family = "flask", stats = { SpellPower = 150 }, duration = 2 * H, roles = CASTER },
  { id = 13511, name = "Flask of Distilled Wisdom", family = "flask", stats = { Intellect = 133 }, duration = 2 * H, roles = SPELL },

  -- Agility
  { id = 13452, name = "Elixir of the Mongoose", family = "buff", stats = { Agility = 25, MeleeCrit = 2 }, duration = 30 * M },
  { id = 9187, name = "Elixir of Greater Agility", family = "buff", stats = { Agility = 25 }, duration = H },
  { id = 250328, name = "Elixir of Cunning", family = "buff", stats = { Agility = 25, Intellect = 25 }, duration = 30 * M },
  { id = 10309, name = "Scroll of Agility IV", family = "buff", stats = { Agility = 17 }, duration = 30 * M },
  -- Strength
  { id = 9206, name = "Elixir of Greater Strength", family = "buff", stats = { Strength = 25 }, duration = H },
  { id = 250351, name = "Elixir of the Grizzly", family = "buff", stats = { Strength = 25, MeleeCrit = 2 }, duration = 30 * M },
  { id = 250350, name = "Elixir of Ferocity", family = "buff", stats = { Strength = 18, Agility = 18 }, duration = 30 * M },
  { id = 13453, name = "Elixir of Brute Force", family = "buff", stats = { Strength = 18, Stamina = 18 }, duration = H },
  { id = 12451, name = "Juju Power", family = "buff", stats = { Strength = 30 }, duration = 30 * M },
  { id = 10310, name = "Scroll of Strength IV", family = "buff", stats = { Strength = 17 }, duration = 30 * M },
  -- Attack power
  { id = 246948, name = "Distilled Firewater", family = "buff", stats = { AttackPower = 35 }, duration = 20 * M },
  { id = 12820, name = "Winterfall Firewater", family = "buff", stats = { AttackPower = 35 }, duration = 20 * M },
  { id = 12460, name = "Juju Might", family = "buff", stats = { AttackPower = 40 }, duration = 10 * M },
  -- Armor, health, stamina
  { id = 13445, name = "Elixir of Greater Defense", family = "buff", stats = { Armor = 450 }, duration = H },
  { id = 250329, name = "Elixir of the Phalanx", family = "buff", stats = { Armor = 500, Stamina = 40 }, claims = { "Armor", "Health" }, duration = 30 * M },
  { id = 250335, name = "Elixir of Greater Fortitude", family = "buff", stats = { Stamina = 40 }, claims = { "Health" }, duration = 30 * M },
  { id = 10305, name = "Scroll of Protection IV", family = "buff", stats = { Armor = 240 }, duration = 30 * M },
  { id = 10307, name = "Scroll of Stamina IV", family = "buff", stats = { Stamina = 16 }, duration = 30 * M },
  { id = 21151, name = "Rumsey Rum Black Label", family = "buff", stats = { Stamina = 15 }, duration = 15 * M },
  -- Spell power, healing, mana
  { id = 13454, name = "Greater Arcane Elixir", family = "buff", stats = { SpellPower = 35 }, duration = H, roles = SPELL },
  { id = 9264, name = "Elixir of Shadow Power", family = "buff", stats = { ShadowPower = 40 }, duration = 30 * M, roles = CASTER },
  { id = 250343, name = "Elixir of Nature Power", family = "buff", stats = { NaturePower = 40 }, duration = 30 * M, roles = CASTER },
  { id = 21546, name = "Elixir of Holy Power", family = "buff", stats = { HolyPower = 40 }, duration = 30 * M, roles = CASTER },
  { id = 17708, name = "Elixir of Frost Power", family = "buff", stats = { FrostPower = 15 }, duration = 30 * M, roles = CASTER },
  { id = 6373, name = "Elixir of Fire Power", family = "buff", stats = { FirePower = 10 }, duration = 30 * M, roles = CASTER },
  { id = 250333, name = "Greater Cleric's Elixir", family = "buff", stats = { HealingPower = 40 }, duration = 30 * M, roles = HEALER },
  { id = 250337, name = "Elixir of the Owl", family = "buff", stats = { Intellect = 25, SpellCrit = 2 }, duration = 30 * M, roles = SPELL },
  { id = 9179, name = "Elixir of Greater Intellect", family = "buff", stats = { Intellect = 25 }, duration = H, roles = SPELL },
  { id = 13447, name = "Elixir of the Sages", family = "buff", stats = { Intellect = 18, Spirit = 18 }, duration = H, roles = SPELL },
  { id = 10308, name = "Scroll of Intellect IV", family = "buff", stats = { Intellect = 16 }, duration = 30 * M, roles = SPELL },
  { id = 250348, name = "Elixir of the Whale", family = "buff", stats = { Spirit = 25, SpellCrit = 2 }, duration = 30 * M, roles = SPELL },
  { id = 250341, name = "Greater Mageblood Elixir", family = "buff", stats = { Mp5 = 20 }, duration = 30 * M, roles = SPELL },
  { id = 20007, name = "Mageblood Elixir", family = "buff", stats = { Mp5 = 12 }, duration = H, roles = SPELL },

  -- Food: one Well Fed buff, 15 minutes
  { id = 20452, name = "Smoked Desert Dumplings", family = "food", stats = { Strength = 20 }, duration = 15 * M },
  { id = 250072, name = "Swiftstrike Steak", family = "food", stats = { Agility = 20 }, duration = 15 * M },
  { id = 250068, name = "Savory Turtle Stew", family = "food", stats = { Stamina = 20 }, duration = 15 * M },
  { id = 21023, name = "Dirge's Kickin' Chimaerok Chops", family = "food", stats = { Stamina = 25 }, duration = 15 * M },
  { id = 13933, name = "Lobster Stew", family = "food", stats = { SpellPower = 28 }, duration = 15 * M, roles = SPELL },
  { id = 249870, name = "Sage's Tea", family = "food", stats = { HealingPower = 44 }, duration = 15 * M, roles = HEALER },

  -- Weapon oils and stones: 30 minutes
  { id = 18262, name = "Elemental Sharpening Stone", family = "weapon", stats = { MeleeCrit = 2 }, duration = 30 * M, roles = PHYSICAL },
  { id = 20749, name = "Brilliant Wizard Oil", family = "weapon", stats = { SpellPower = 36, HealingPower = 36, SpellCrit = 1 }, duration = 30 * M, roles = SPELL },
  { id = 20748, name = "Brilliant Mana Oil", family = "weapon", stats = { Mp5 = 15, HealingPower = 30 }, duration = 30 * M, roles = HEALER },

  -- Potions: stock only (one shared 2-minute cooldown), counted per night, never reminded
  { id = 13446, name = "Major Healing Potion", family = "potion", stats = {}, perNight = 5, roles = { melee = true, tank = true, ranged = true, feral = true } },
  { id = 13444, name = "Major Mana Potion", family = "potion", stats = {}, perNight = 5, roles = SPELL },
  { id = 5634, name = "Free Action Potion", family = "potion", stats = {}, perNight = 2 },
  { id = 13442, name = "Mighty Rage Potion", family = "potion", stats = {}, perNight = 3, roles = { tank = true } },
}

-- Each spec's role. Cat takes the melee items plus a mana potion for shifting; bear takes the tank items.
ns.ConsumableRoles = {
  FERAL_CAT = "feral", FERAL_BEAR = "bear", BALANCE = "caster", RESTORATION = "healer",
  BEAST_MASTERY = "ranged", MARKSMANSHIP = "ranged", SURVIVAL = "ranged", SURVIVAL_MELEE = "melee",
  ARCANE = "caster", FIRE = "caster", FROST = "caster",
  HOLY = "healer", PROTECTION = "tank", RETRIBUTION = "melee",
  DISCIPLINE = "healer", SHADOW = "caster", SMITE = "caster",
  ASSASSINATION = "melee", COMBAT = "melee", SUBTLETY = "melee",
  ELEMENTAL = "caster", ENHANCEMENT = "melee", ENHANCEMENT_DW = "melee",
  AFFLICTION = "caster", DEMONOLOGY = "caster", DESTRUCTION = "caster",
  ARMS = "melee", FURY = "melee",
}
-- A role that takes another role's items as well.
ns.ConsumableRoleAlso = { feral = "melee", bear = "tank" }
-- Roles with no weapon buff: a druid in form doesn't swing the weapon an oil or stone is on.
ns.ConsumableNoWeapon = { feral = true, bear = true }
-- Extra potions for a role beyond the catalog's own roles (feral shifts on mana).
ns.ConsumableExtraPotions = { feral = { [13444] = 3 } }

-- Untested on Forever: whether two buffs' crit both count (Mongoose with Grizzly). Until tested,
-- shared crit is a conflict; set to true once confirmed.
ns.ConsumableRules = { critStacks = false }
