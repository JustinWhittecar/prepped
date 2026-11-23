-- Consumables: Prepped's own hand-kept list (SimGear has no consumable data). Pull requests welcome.
-- Each entry: id (item), name, slot, stats (SimGear keys and units), duration (seconds),
-- aura (buff spell ID; "Well Fed" = any food buff by name; "weapon" = a temporary weapon enchant),
-- source (an Obtainable filter that hides it as a default: "reputation", "darkmoon"...),
-- roles (only these roles get it; none = everyone), so a tiny weight never makes a caster flask a melee target.
-- Values are Classic 1.12's, not yet checked on Forever. Where a buff has no SimGear stat
-- (health, mana), it is counted as the stat that gives it: 10 health = 1 Stamina, 15 mana = 1 Intellect.
-- The game also checks the item's own spell, so a wrong aura ID here reads as up, never as missing.
local _, ns = ...

local HOUR = 3600

ns.ConsumableCatalog = {
  -- Flasks (2 hours, stay on through death)
  { id = 13510, name = "Flask of the Titans", slot = "flask", stats = { Stamina = 120 }, duration = 2 * HOUR, aura = 17626 },
  { id = 13512, name = "Flask of Supreme Power", roles = { caster = true }, slot = "flask", stats = { SpellPower = 150 }, duration = 2 * HOUR, aura = 17628 },
  { id = 13511, name = "Flask of Distilled Wisdom", roles = { caster = true, healer = true }, slot = "flask", stats = { Intellect = 133 }, duration = 2 * HOUR, aura = 17627 },

  -- Elixirs: one per stat
  { id = 13452, name = "Elixir of the Mongoose", slot = "agility", stats = { Agility = 25, MeleeCrit = 2 }, duration = HOUR, aura = 17538 },
  { id = 9187, name = "Elixir of Greater Agility", slot = "agility", stats = { Agility = 25 }, duration = HOUR, aura = 11334 },
  { id = 9206, name = "Elixir of Giants", slot = "strength", stats = { Strength = 25 }, duration = HOUR, aura = 11405 },
  { id = 12451, name = "Juju Power", slot = "strength", stats = { Strength = 30 }, duration = 30 * 60, aura = 16323 },
  { id = 12460, name = "Juju Might", slot = "ap", stats = { AttackPower = 40 }, duration = 10 * 60, aura = 16329 },
  { id = 12820, name = "Winterfall Firewater", slot = "ap", stats = { AttackPower = 35 }, duration = 20 * 60, aura = 17038 },
  { id = 13445, name = "Elixir of Superior Defense", slot = "armor", stats = { Armor = 450 }, duration = HOUR, aura = 11348 },
  { id = 3825, name = "Elixir of Fortitude", slot = "health", stats = { Stamina = 12 }, duration = HOUR, aura = 3593 },
  { id = 13454, name = "Greater Arcane Elixir", slot = "spellpower", stats = { SpellPower = 35 }, duration = HOUR, aura = 17539 },
  { id = 9264, name = "Elixir of Shadow Power", slot = "school", stats = { ShadowPower = 40 }, duration = 30 * 60, aura = 11474 },
  { id = 21546, name = "Elixir of Greater Firepower", slot = "school", stats = { FirePower = 40 }, duration = 30 * 60, aura = 26276 },
  { id = 17708, name = "Elixir of Frost Power", slot = "school", stats = { FrostPower = 15 }, duration = 30 * 60, aura = 21920 },
  { id = 20007, name = "Mageblood Potion", slot = "mana", stats = { Mp5 = 12 }, duration = HOUR, aura = 24363 },

  -- Scrolls
  { id = 10310, name = "Scroll of Strength IV", slot = "scroll", stats = { Strength = 17 }, duration = 30 * 60, aura = 12179 },
  { id = 10309, name = "Scroll of Agility IV", slot = "scroll", stats = { Agility = 17 }, duration = 30 * 60, aura = 12174 },
  { id = 10305, name = "Scroll of Protection IV", slot = "scroll", stats = { Armor = 240 }, duration = 30 * 60, aura = 12175 },

  -- Food (Well Fed: one at a time) and drink
  { id = 20452, name = "Smoked Desert Dumplings", slot = "food", stats = { Strength = 20 }, duration = 15 * 60, aura = "Well Fed" },
  { id = 13928, name = "Grilled Squid", slot = "food", stats = { Agility = 10 }, duration = 10 * 60, aura = "Well Fed" },
  { id = 21023, name = "Dirge's Kickin' Chimaerok Chops", slot = "food", stats = { Stamina = 25 }, duration = 15 * 60, aura = "Well Fed" },
  { id = 18254, name = "Runn Tum Tuber Surprise", slot = "food", stats = { Intellect = 10 }, duration = 10 * 60, aura = "Well Fed" },
  { id = 13931, name = "Nightfin Soup", slot = "food", stats = { Mp5 = 8 }, duration = 10 * 60, aura = "Well Fed" },
  { id = 21151, name = "Rumsey Rum Black Label", slot = "drink", stats = { Stamina = 15 }, duration = 15 * 60, aura = 25804 },

  -- Weapon oils and stones (30 minutes on the main hand)
  { id = 18262, name = "Elemental Sharpening Stone", roles = { melee = true, tank = true }, slot = "weapon", stats = { MeleeCrit = 2 }, duration = 30 * 60, aura = "weapon" },
  { id = 20749, name = "Brilliant Wizard Oil", roles = { caster = true }, slot = "weapon", stats = { SpellPower = 36, SpellCrit = 1 }, duration = 30 * 60, aura = "weapon" },
  { id = 20748, name = "Brilliant Mana Oil", roles = { healer = true }, slot = "weapon", stats = { HealingPower = 25, Mp5 = 12 }, duration = 30 * 60, aura = "weapon" },

  -- Potions: counted as stock only, never reminded. No stats, so no points; a night is taken
  -- as one potion per 36 minutes (5 in 3 hours), since the shared cooldown isn't the limit.
  { id = 13446, name = "Major Healing Potion", slot = "potion", stats = {}, duration = 36 * 60 },
  { id = 13444, name = "Major Mana Potion", slot = "potion", stats = {}, duration = 36 * 60 },
}

-- Which slots each role uses. A slot whose best item scores nothing for the spec is left out
-- in game, so these lists can be generous.
ns.ConsumableSlots = {
  melee = { "flask", "agility", "strength", "ap", "scroll", "food", "weapon", "potion" },
  feral = { "flask", "agility", "strength", "ap", "scroll", "food", "potion" }, -- no weapon buffs in form
  tank = { "flask", "agility", "strength", "armor", "health", "ap", "scroll", "food", "drink", "weapon", "potion" },
  bear = { "flask", "agility", "strength", "armor", "health", "ap", "scroll", "food", "drink", "potion" },
  ranged = { "flask", "agility", "scroll", "food", "potion" },
  caster = { "flask", "spellpower", "school", "mana", "food", "weapon", "potion" },
  healer = { "flask", "mana", "food", "weapon", "potion" },
}

-- Each spec's role (catalog roles: feral counts as melee, bear as tank).
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
ns.ConsumableRoleGroup = { feral = "melee", bear = "tank" }

-- Mana users take a mana potion, everyone else a healing potion.
ns.ConsumablePotion = { caster = 13444, healer = 13444 }
