-- Classes: per-class facts the addon needs, as data. Pure.
-- Talent trees sit side by side on one canvas for every class (PosX 1020/5020/9080, vendor/engine/
-- docs/talent-check-2026-09-17.md); `trees` lists them left to right. Paladin's order was confirmed
-- in game 2026-10-16.
local _, ns = ...

local Classes = {}
ns.Classes = Classes

Classes.PALADIN = {
	name = "Paladin",
	trees = { "HOLY", "PROTECTION", "RETRIBUTION" },
	-- Classic talent art per tree (Interface\TalentFrame\<name>-TopLeft and so on), for the panel's bars
	-- (Art.classicFile). Paladin's three match the owner's reference; every class's names are unverified
	-- in game until /dump GetTalentTabInfo on Classic Era (research/plan-2026-10-24-panel-art.md).
	classicArt = { HOLY = "PaladinHoly", PROTECTION = "PaladinProtection", RETRIBUTION = "PaladinCombat" },
	short ={ HOLY = "Holy", PROTECTION = "Prot", RETRIBUTION = "Ret", RETRIBUTION_DUNGEON = "Ret dungeon" },
	long = { HOLY = "Holy", PROTECTION = "Protection", RETRIBUTION = "Retribution", RETRIBUTION_DUNGEON = "Retribution (dungeon)" },
	aliases = {
		holy = "HOLY", prot = "PROTECTION", protection = "PROTECTION",
		ret = "RETRIBUTION", retri = "RETRIBUTION", retribution = "RETRIBUTION",
	},
	-- Equip locations a spec never uses, with the reason shown instead of a score. Prot tanks with a
	-- shield; the Lv20 Prot weights are threat-only (Armor/Block are 0, data/GAPS.md), so without
	-- this rule a two-hander outscores sword and board.
	gearRules = {
		PROTECTION = {
			excluded = { INVTYPE_2HWEAPON = true, INVTYPE_HOLDABLE = true },
			reason = ns.N("Prot uses a shield: not scored"),
		},
	},
	dualWield = {},
	-- What the class can wear and wield: the same lists the item data is filtered by
	-- (pipeline/items/classes.go). Armor learned later carries its trainer level in the item data.
	-- Shown in the Guide's "about" lines for the spec (owner 2026-11-01: a caveat, not a filter).
	simNotes = {
		RETRIBUTION = ns.N("Spell power counts because seals and Judgement scale with it. Armor and survival aren't part of the damage sim, so a cloth piece with a lot of spell damage can score like plate."),
		PROTECTION = ns.N("The level 30, 40 and 50 sims tank a dungeon pack of three elite mobs around your level for 22 s (Righteous Fury, Judgement, Holy Strike, Seal of Righteousness, Consecration, Holy Shield from 40), hitting as hard as typical dungeon trash, not a boss."),
	},
	equip = { weapons = { 0, 1, 4, 5, 6, 7, 8 }, armor = { 0, 1, 2, 3, 4, 6, 7 } },
	gear = { armor = "cloth, leather, mail, plate, shields", weapons = "one- and two-handed axes, maces and swords, polearms", relic = "librams" },
}

-- Tree order (Elemental, Enhancement, Restoration) is the Classic layout; confirm in game with
-- /sgf spec on a Shaman. Dual Wield: the client gives Shamans the skill (SkillRaceClassInfo 2455) but
-- never learns it for them automatically (SkillLineAbility 48686, AcquireMethod 3), as with TBC's
-- Enhancement talent; a low-level Shaman can't dual-wield (in game 2026-10-19). So Enhancement gets
-- off-hand weapons only once the client says Dual Wield (674) is known: no dualWieldFrom, so a previewed
-- level never assumes it. The engine's Lv60 Enhancement sim dual-wields.
Classes.SHAMAN = {
	name = "Shaman",
	trees = { "ELEMENTAL", "ENHANCEMENT", "RESTORATION" },
	classicArt = { ELEMENTAL = "ShamanElementalCombat", ENHANCEMENT = "ShamanEnhancement", RESTORATION = "ShamanRestoration" },
	short ={ ELEMENTAL = "Ele", ELEMENTAL_DUNGEON = "Ele dungeon", ENHANCEMENT = "Enh", ENHANCEMENT_DW = "Enh DW", ENHANCEMENT_DUNGEON = "Enh dungeon", ENHANCEMENT_DW_DUNGEON = "Enh DW dungeon", RESTORATION = "Resto" },
	long = { ELEMENTAL = "Elemental", ELEMENTAL_DUNGEON = "Elemental (dungeon)", ENHANCEMENT = "Enhancement", ENHANCEMENT_DW = "Enhancement (dual-wield)", ENHANCEMENT_DUNGEON = "Enhancement (dungeon)", ENHANCEMENT_DW_DUNGEON = "Enhancement (dual-wield, dungeon)", RESTORATION = "Restoration" },
	aliases = {
		ele = "ELEMENTAL", elemental = "ELEMENTAL",
		enh = "ENHANCEMENT", enhance = "ENHANCEMENT", enhancement = "ENHANCEMENT",
		resto = "RESTORATION", restoration = "RESTORATION",
	},
	gearRules = {},
	dualWield = { ENHANCEMENT = true },
	-- Weight sets for a spec once you can dual-wield (Gear setsFor); the spec's own sets hold a two-hander.
	dualWieldSets = { ENHANCEMENT = "ENHANCEMENT_DW" },
	-- Shown in the Guide's "about" lines for the spec.
	simNotes = {
		ENHANCEMENT = ns.N("The level 60 sim holds a two-hander (The Unstoppable Force, Windfury). Shamans don't learn Dual Wield from the trainer: once yours can dual-wield, SimGear switches to a dual-wield sim (Windfury on both hands)."),
	},
	equip = { weapons = { 0, 1, 4, 5, 10, 13, 15 }, armor = { 0, 1, 2, 3, 6, 9 } },
	-- Two-handed axes and maces come from a weapon master although their skill rows carry a flag no other weapon row
	-- has (phase 122, in game 2026-11-16): Orgrimmar's Hanashi and Sayoc offer Two-Handed Axes to a level 1 Shaman,
	-- Thunder Bluff's Ansekhwa Two-Handed Maces. No unsureTrainer: untrained notes name the weapon master.
	gear = { armor = "cloth, leather, mail, shields", weapons = "one- and two-handed axes and maces, staves, fist weapons, daggers", relic = "totems" },
}

-- Feral is one talent tree with two roles: Cat (damage) and Bear (tank). treeSpecs resolves the
-- Feral tree to Cat once the character has Cat Form (decision 2026-10-17), else Bear; the form's
-- level comes from the item data's meta.formFrom (cMaNGOS trainers). Druids can't dual-wield.
Classes.DRUID = {
	name = "Druid",
	trees = { "BALANCE", "FERAL", "RESTORATION" },
	classicArt = { BALANCE = "DruidBalance", FERAL = "DruidFeralCombat", RESTORATION = "DruidRestoration" },
	specs ={ "BALANCE", "FERAL_CAT", "FERAL_BEAR", "RESTORATION" },
	treeSpecs = { FERAL = { form = "cat", with = "FERAL_CAT", without = "FERAL_BEAR" } },
	short = { BALANCE = "Balance", BALANCE_DUNGEON = "Balance dungeon", FERAL_CAT = "Cat", FERAL_CAT_DUNGEON = "Cat dungeon", FERAL_BEAR = "Bear", RESTORATION = "Resto" },
	long = { BALANCE = "Balance", BALANCE_DUNGEON = "Balance (dungeon)", FERAL_CAT = "Feral (Cat)", FERAL_CAT_DUNGEON = "Feral (Cat, dungeon)", FERAL_BEAR = "Feral (Bear)", RESTORATION = "Restoration" },
	aliases = {
		balance = "BALANCE", boomkin = "BALANCE", moonkin = "BALANCE",
		cat = "FERAL_CAT", feral = "FERAL_CAT", bear = "FERAL_BEAR", tank = "FERAL_BEAR",
		resto = "RESTORATION", restoration = "RESTORATION",
	},
	-- Spec art: client atlas suffixes (talents-background-druid-<art>); "feral" confirmed in game 2026-10-17.
	art = { FERAL_CAT = "feral", FERAL_BEAR = "feral" },
	gearRules = {
		FERAL_CAT = { excluded = { INVTYPE_HOLDABLE = true }, reason = ns.N("Feral fights in Cat Form: held off-hands not scored") },
		FERAL_BEAR = { excluded = { INVTYPE_HOLDABLE = true }, reason = ns.N("Feral fights in Bear Form: held off-hands not scored") },
	},
	dualWield = {},
	-- Shown in the Guide's "about" lines for the spec (owner 2026-11-01: the Lv50 Cat set's Intellect).
	simNotes = {
		FERAL_CAT = ns.N("In the level 50 sim, Intellect is mana for Shifting Power (mana into energy), not damage: the sim runs out of mana in a long fight. Below 50 and at 60 it barely counts."),
		FERAL_BEAR = ns.N("The level 30, 40 and 50 sims tank a normal mob two levels above you, hitting as hard as a typical one of its level, not a dungeon boss. Below 40 the sim uses Bear Form, not Dire Bear Form."),
	},
	-- Polearms from level 20 (client SkillRaceClassInfo, Druid row; phase 122). A polearm scores like a staff with
	-- the same stats: in form the paw swings the weapon's DPS rescaled to the form's speed (TwoHandDps), speed adds
	-- nothing, and attack power ignores the weapon (76485be).
	equip = { weapons = { 4, 5, 6, 10, 13, 15 }, armor = { 0, 1, 2, 8 } },
	gear = { armor = "cloth, leather", weapons = "one- and two-handed maces, polearms, staves, fist weapons, daggers", relic = "idols" },
}

-- Tree order (Beast Mastery, Marksmanship, Survival) is the Classic layout; confirm in game with
-- /sgf spec on a Hunter. Gear from the client's SkillRaceClassInfo: Dual Wield and Polearms from
-- level 20, Mail from 40 (the item data's meta.armorFrom). Slot 18 is the ranged weapon.
Classes.HUNTER = {
	name = "Hunter",
	trees = { "BEAST_MASTERY", "MARKSMANSHIP", "SURVIVAL" },
	classicArt = { BEAST_MASTERY = "HunterBeastMastery", MARKSMANSHIP = "HunterMarksmanship", SURVIVAL = "HunterSurvival" },
	-- SURVIVAL_MELEE is the release engine's melee Survival rotation: experimental, picked by hand only
	-- (/sgf spec svmelee), never inferred from talents; Survival stays ranged until the launch meta is
	-- known (owner decision 2026-10-21, research/plan-engine-rebase-2026-10-21.md Q4).
	specs = { "BEAST_MASTERY", "MARKSMANSHIP", "SURVIVAL", "SURVIVAL_MELEE" },
	short = { BEAST_MASTERY = "BM", MARKSMANSHIP = "MM", SURVIVAL = "SV", SURVIVAL_MELEE = "SVmelee",
		BEAST_MASTERY_DUNGEON = "BM dungeon", MARKSMANSHIP_DUNGEON = "MM dungeon", SURVIVAL_DUNGEON = "SV dungeon", SURVIVAL_MELEE_DUNGEON = "SVmelee dungeon" },
	-- "(ranged)" (phase 91, the review): SURVIVAL is simmed as a ranged Hunter; the melee rotation is SURVIVAL_MELEE.
	long = { BEAST_MASTERY = "Beast Mastery", MARKSMANSHIP = "Marksmanship", SURVIVAL = "Survival (ranged)",
		SURVIVAL_MELEE = "Survival (melee)", BEAST_MASTERY_DUNGEON = "Beast Mastery (dungeon)", MARKSMANSHIP_DUNGEON = "Marksmanship (dungeon)",
		SURVIVAL_DUNGEON = "Survival (ranged, dungeon)", SURVIVAL_MELEE_DUNGEON = "Survival (melee, dungeon)" },
	aliases = {
		bm = "BEAST_MASTERY", beast = "BEAST_MASTERY", beastmastery = "BEAST_MASTERY",
		mm = "MARKSMANSHIP", marks = "MARKSMANSHIP", marksmanship = "MARKSMANSHIP",
		sv = "SURVIVAL", surv = "SURVIVAL", survival = "SURVIVAL",
		svmelee = "SURVIVAL_MELEE", survmelee = "SURVIVAL_MELEE",
	},
	-- Spec art: client atlas suffixes (talents-background-hunter-<art>); not yet checked in game.
	art = { BEAST_MASTERY = "beastmastery", SURVIVAL_MELEE = "survival" },
	gearRules = {},
	-- Specs picked by hand on a tree's talents: they refine that tree (Spec.treeOf, Spec.scoring).
	specTree = { SURVIVAL_MELEE = "SURVIVAL" },
	-- The short name keeps the header's spec button and the Guide title inside their space; the
	-- "experimental" label lives here and in the spec menu (owner's screenshot, 2026-10-23).
	simNotes = {
		SURVIVAL_MELEE = ns.N("Experimental: the engine's melee Survival rotation, picked by hand only (/sgf spec svmelee). The pet tanks while you melee; from 40, Hunter's Mark lets Mongoose Bite open."),
		BEAST_MASTERY = ns.N("The level 30, 40 and 50 sims kill a normal mob two levels above you with a leveling rotation (Hunter's Mark, Serpent Sting, from 40 Summon Hawk, then Arcane Shot, Auto Shot and the pet), then wait 40 s before the next pull. Mana comes back in that time, so Agility leads; Intellect and Spirit count through the leveling survival bonus only."),
		MARKSMANSHIP = ns.N("The level 30, 40 and 50 sims kill a normal mob two levels above you with a leveling rotation (Hunter's Mark, Serpent Sting, Arcane Shot to open, Auto Shot and the pet), then wait 40 s before the next pull. Mana comes back in that time, so Agility leads; Intellect counts through Careful Aim and the leveling survival bonus."),
		SURVIVAL = ns.N("The level 30, 40 and 50 sims kill a normal mob two levels above you with a leveling rotation (Hunter's Mark, Serpent Sting, Arcane Shot to open, Auto Shot and the pet), then wait 40 s before the next pull. Mana comes back in that time, so Agility leads; Intellect and Spirit count through the leveling survival bonus only."),
	},
	experimental = { SURVIVAL_MELEE = true },
	dualWield = { BEAST_MASTERY = true, MARKSMANSHIP = true, SURVIVAL = true, SURVIVAL_MELEE = true },
	dualWieldFrom = 20, -- client SkillRaceClassInfo (pipeline/items/classes.go: Dual Wield from 20)
	equip = { weapons = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18 }, armor = { 0, 1, 2, 3 }, noHoldable = true },
	gear = { armor = "cloth, leather, mail", weapons = "one- and two-handed axes and swords, polearms, staves, fist weapons, daggers",
		ranged = "bows, guns, crossbows",
		note = ns.N("Your pet, ammo and quiver are not scored: SimGear ranks your own gear only.") },
}

-- Tree order (Discipline, Holy, Shadow) confirmed by the user 2026-10-18 (the in-game talent frame);
-- spec art checked in game the same day. Smite is the engine's damage build on Discipline talents
-- (sim/priest/smite); it is picked by hand only, since its talents look like a Discipline healer's
-- (decision 2026-10-18). Slot 18 holds a wand.
Classes.PRIEST = {
	name = "Priest",
	trees = { "DISCIPLINE", "HOLY", "SHADOW" },
	classicArt = { DISCIPLINE = "PriestDiscipline", HOLY = "PriestHoly", SHADOW = "PriestShadow" },
	specs = { "DISCIPLINE", "HOLY", "SHADOW", "SMITE" },
	short = { DISCIPLINE = "Disc", HOLY = "Holy", SHADOW = "Shadow", SHADOW_DUNGEON = "Shadow dungeon", SMITE = "Smite", SMITE_DUNGEON = "Smite dungeon" },
	long = { DISCIPLINE = "Discipline", HOLY = "Holy", SHADOW = "Shadow", SHADOW_DUNGEON = "Shadow (dungeon)", SMITE = "Smite (damage)", SMITE_DUNGEON = "Smite (damage, dungeon)" },
	specTree = { SMITE = "DISCIPLINE" }, -- Smite is picked by hand on Discipline talents
	aliases = {
		disc = "DISCIPLINE", discipline = "DISCIPLINE", holy = "HOLY",
		shadow = "SHADOW", sp = "SHADOW", smite = "SMITE",
	},
	-- Spec art: client atlas suffixes (talents-background-priest-<art>); all three exist (2026-10-18).
	art = { SMITE = "discipline" },
	gearRules = {},
	dualWield = {},
	equip = { weapons = { 4, 10, 15, 19 }, armor = { 0, 1 } },
	gear = { armor = "cloth", weapons = "one-handed maces, staves, daggers", ranged = "wands" },
}

-- Tree order (Arcane, Fire, Frost) confirmed by the user 2026-10-18. Slot 18 holds a wand.
Classes.MAGE = {
	name = "Mage",
	trees = { "ARCANE", "FIRE", "FROST" },
	classicArt = { ARCANE = "MageArcane", FIRE = "MageFire", FROST = "MageFrost" },
	short = { ARCANE = "Arcane", FIRE = "Fire", FROST = "Frost", FROST_DUNGEON = "Frost dungeon", ARCANE_DUNGEON = "Arcane dungeon", FIRE_DUNGEON = "Fire dungeon" },
	long = { ARCANE = "Arcane", FIRE = "Fire", FROST = "Frost", FROST_DUNGEON = "Frost (dungeon)", ARCANE_DUNGEON = "Arcane (dungeon)", FIRE_DUNGEON = "Fire (dungeon)" },
	aliases = { arcane = "ARCANE", fire = "FIRE", frost = "FROST" },
	-- Spec art: client atlas suffixes (talents-background-mage-<art>); all three exist (2026-10-18).
	art = {},
	gearRules = {},
	dualWield = {},
	equip = { weapons = { 7, 10, 15, 19 }, armor = { 0, 1 } },
	gear = { armor = "cloth", weapons = "one-handed swords, staves, daggers", ranged = "wands" },
}

-- Tree order (Arms, Fury, Protection) and spec art confirmed by the user 2026-10-18. Gear from the
-- client's SkillRaceClassInfo: Dual Wield and Polearms from level 20, Plate from 40 (the item data's
-- meta.armorFrom). Fury dual-wields in the engine (sim/warrior/dps_warrior); Arms uses a two-hander.
-- Prot tanks with a shield, and its weights are threat-only for now (data/GAPS.md), so two-handers
-- and held off-hands are left out as for Prot Paladin. Slot 18 is a stat stick (bow, gun, crossbow, thrown).
Classes.WARRIOR = {
	name = "Warrior",
	trees = { "ARMS", "FURY", "PROTECTION" },
	classicArt = { ARMS = "WarriorArms", FURY = "WarriorFury", PROTECTION = "WarriorProtection" },
	short = { ARMS = "Arms", FURY = "Fury", PROTECTION = "Prot" },
	long = { ARMS = "Arms", FURY = "Fury", PROTECTION = "Protection" },
	aliases = { arms = "ARMS", fury = "FURY", prot = "PROTECTION", protection = "PROTECTION", tank = "PROTECTION" },
	-- Spec art: client atlas suffixes (talents-background-warrior-<art>); all three exist (2026-10-18).
	art = {},
	gearRules = {
		PROTECTION = {
			excluded = { INVTYPE_2HWEAPON = true, INVTYPE_HOLDABLE = true },
			reason = ns.N("Prot uses a shield: not scored"),
		},
	},
	dualWield = { FURY = true },
	dualWieldFrom = 20, -- client SkillRaceClassInfo (pipeline/items/classes.go: Dual Wield from 20)
	-- Every Warrior can dual-wield from 20, but only Fury is simmed with two weapons: Arms is simmed with
	-- a two-hander (Mortal Strike), and its off-hand DPS weighs 0. Shown in the Guide and the off-hand list.
	simNotes = {
		ARMS = ns.N("Arms is simmed with a two-hander: Mortal Strike and slow, heavy weapons. Dual wielding isn't scored for Arms (off-hand weapon damage weighs 0), so SimGear recommends a two-hander. Pick Fury in the spec picker to see dual-wield off hands. The level 30 sim has no Mortal Strike yet: it comes at 40."),
		PROTECTION = ns.N("The level 30, 40 and 50 sims tank a normal mob two levels above you, hitting as hard as a typical one of its level, not a dungeon boss."),
	},
	equip = { weapons = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }, armor = { 0, 1, 2, 3, 4, 6 } },
	gear = { armor = "cloth, leather, mail, plate, shields",
		weapons = "one- and two-handed axes, maces and swords, polearms, staves, fist weapons, daggers",
		ranged = "bows, guns, crossbows, thrown",
		note = ns.N("Your ranged weapon is scored on its stats only: you shoot it to pull, not for damage.") },
}

-- Tree order (Affliction, Demonology, Destruction) is the Classic layout; confirm in game with the
-- talent frame and /sgf spec on a Warlock, with the talents-background-warlock-* atlases (not yet
-- checked). Demonology is the engine's Demonic Pact build, Destruction its Shadow and Flame build
-- (sim/warlock/dps). Slot 18 holds a wand.
Classes.WARLOCK = {
	name = "Warlock",
	trees = { "AFFLICTION", "DEMONOLOGY", "DESTRUCTION" },
	classicArt = { AFFLICTION = "WarlockCurses", DEMONOLOGY = "WarlockSummoning", DESTRUCTION = "WarlockDestruction" },
	short = { AFFLICTION = "Affli", DEMONOLOGY = "Demo", DESTRUCTION = "Destro", AFFLICTION_DUNGEON = "Affli dungeon",
		DEMONOLOGY_DUNGEON = "Demo dungeon", DESTRUCTION_DUNGEON = "Destro dungeon" },
	long = { AFFLICTION = "Affliction", DEMONOLOGY = "Demonology", DESTRUCTION = "Destruction", AFFLICTION_DUNGEON = "Affliction (dungeon)",
		DEMONOLOGY_DUNGEON = "Demonology (dungeon)", DESTRUCTION_DUNGEON = "Destruction (dungeon)" },
	aliases = {
		affli = "AFFLICTION", aff = "AFFLICTION", affliction = "AFFLICTION",
		demo = "DEMONOLOGY", demonology = "DEMONOLOGY",
		destro = "DESTRUCTION", destruction = "DESTRUCTION",
	},
	art = {},
	gearRules = {},
	dualWield = {},
	equip = { weapons = { 7, 10, 15, 19 }, armor = { 0, 1 } },
	gear = { armor = "cloth", weapons = "one-handed swords, staves, daggers", ranged = "wands",
		note = ns.N("Your demon is not scored: SimGear ranks your own gear only.") },
}

-- Tree order (Assassination, Combat, Subtlety) confirmed in the talent frame 2026-10-18; the
-- talents-background-rogue-assassination atlas exists (dumped), combat and subtlety show there too. Each spec is one engine
-- Forever suite (sim/rogue/dps_rogue): Assassination = Mutilate, Combat = Sinister Strike with swords
-- (user choice 2026-10-18; Combat Daggers left out), Subtlety = Hemorrhage. All three dual-wield once
-- Dual Wield (level 10) is known.
Classes.ROGUE = {
	name = "Rogue",
	trees = { "ASSASSINATION", "COMBAT", "SUBTLETY" },
	classicArt = { ASSASSINATION = "RogueAssassination", COMBAT = "RogueCombat", SUBTLETY = "RogueSubtlety" },
	short = { ASSASSINATION = "Assa", COMBAT = "Combat", SUBTLETY = "Sub" },
	long = { ASSASSINATION = "Assassination", COMBAT = "Combat", SUBTLETY = "Subtlety" },
	aliases = {
		assa = "ASSASSINATION", assassination = "ASSASSINATION", mut = "ASSASSINATION", mutilate = "ASSASSINATION",
		combat = "COMBAT", swords = "COMBAT",
		sub = "SUBTLETY", subtlety = "SUBTLETY", hemo = "SUBTLETY",
	},
	art = {},
	gearRules = {},
	dualWield = { ASSASSINATION = true, COMBAT = true, SUBTLETY = true },
	dualWieldFrom = 10, -- client SkillRaceClassInfo: Dual Wield, class mask 8, MinLevel 10
	equip = { weapons = { 0, 2, 3, 4, 7, 13, 15, 16, 18 }, armor = { 0, 1, 2 }, noHoldable = true },
	gear = { armor = "cloth, leather",
		weapons = "one-handed axes, maces and swords, fist weapons, daggers",
		ranged = "bows, guns, crossbows, thrown",
		note = ns.N("Assassination and Subtlety are simmed with daggers: Mutilate and Backstab need a dagger in the main hand, which the scores can't see. Your ranged weapon is scored on its stats only.") },
}

-- Each class's `equip` is the item data's filter (pipeline/items/classes.go; a Go test keeps them equal):
-- client Item.SubclassID lists. The types a class can be barred from, as the tooltip names them. Anything
-- else (fishing poles, miscellaneous weapons, cloth, jewelry) any class can equip.
local WEAPON_TYPE = {
	[0] = ns.N("one-handed axes"), [1] = ns.N("two-handed axes"), [2] = ns.N("bows"), [3] = ns.N("guns"),
	[4] = ns.N("one-handed maces"), [5] = ns.N("two-handed maces"), [6] = ns.N("polearms"),
	[7] = ns.N("one-handed swords"), [8] = ns.N("two-handed swords"), [10] = ns.N("staves"),
	[13] = ns.N("fist weapons"), [15] = ns.N("daggers"), [16] = ns.N("thrown weapons"),
	[18] = ns.N("crossbows"), [19] = ns.N("wands"),
}
local ARMOR_TYPE = {
	[2] = ns.N("leather armor"), [3] = ns.N("mail armor"), [4] = ns.N("plate armor"), [6] = ns.N("shields"),
	[7] = ns.N("librams"), [8] = ns.N("idols"), [9] = ns.N("totems"),
}

local function listed(list, id)
	for _, x in ipairs(list) do
		if x == id then return true end
	end
	return false
end

-- The skill spell for each weapon type (client SkillLineAbility, 70938; a Go test checks them), for "has this
-- character trained it" (IsPlayerSpell), and the names in the item data's prof / meta.weaponFrom.
local WEAPON_SPELL = { [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200, [7] = 201, [8] = 202,
	[10] = 227, [13] = 15590, [15] = 1180, [16] = 2567, [18] = 5011, [19] = 5009 }
Classes.WEAPON_SPELL = WEAPON_SPELL
local WEAPON_KEY = { [0] = "1H axe", [1] = "2H axe", [2] = "bow", [3] = "gun", [4] = "1H mace", [5] = "2H mace", [6] = "polearm",
	[7] = "1H sword", [8] = "2H sword", [10] = "staff", [13] = "fist weapon", [15] = "dagger", [16] = "thrown", [18] = "crossbow", [19] = "wand" }
-- The skill's name, as the trainer lists it.
local WEAPON_SKILL = {
	[0] = ns.N("One-Handed Axes"), [1] = ns.N("Two-Handed Axes"), [2] = ns.N("Bows"), [3] = ns.N("Guns"),
	[4] = ns.N("One-Handed Maces"), [5] = ns.N("Two-Handed Maces"), [6] = ns.N("Polearms"), [7] = ns.N("One-Handed Swords"),
	[8] = ns.N("Two-Handed Swords"), [10] = ns.N("Staves"), [13] = ns.N("Fist Weapons"), [15] = ns.N("Daggers"),
	[16] = ns.N("Thrown"), [18] = ns.N("Crossbows"), [19] = ns.N("Wands"),
}
-- The item data's name of a weapon prof ("polearm") -> its skill name ("Polearms").
function Classes.weaponSkillName(prof)
	for sub, key in pairs(WEAPON_KEY) do
		if key == prof then return WEAPON_SKILL[sub] end
	end
	return nil
end

-- The type of item the class can never equip that this item is, or nil: it can, or the client didn't
-- say (item = { classID, subclassID, equipLoc }, Client.readCachedItem). Unknown never bars an item.
-- By class, not by skill: armor and weapons learned later (item data's prof) and untrained weapons aren't
-- barred here; Classes.weaponState tells those apart.
function Classes.barredType(token, item)
	local class = token and Classes[token]
	local equip = type(class) == "table" and class.equip
	if not (equip and item) then return nil end
	if equip.noHoldable and item.equipLoc == "INVTYPE_HOLDABLE" then return ns.N("held-in-off-hand items") end
	local names, list
	if item.classID == 2 then names, list = WEAPON_TYPE, equip.weapons
	elseif item.classID == 4 then names, list = ARMOR_TYPE, equip.armor
	else return nil end
	local name = names[item.subclassID]
	if name and not listed(list, item.subclassID) then return name end
	return nil
end

-- Armor slots where the armor type is a choice. Cloaks are cloth for every class, so they're not here.
local ARMOR_SLOTS = {
	INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true, INVTYPE_WRIST = true,
	INVTYPE_HAND = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true,
}

-- The armor type (client subclassID: 1 cloth, 2 leather, 3 mail, 4 plate) of an item in one of those slots
-- (kind = { classID, subclassID } from the client, Client.itemKind), or nil: unknown, or not such a slot.
function Classes.armorType(kind, equipLoc)
	if kind and kind.classID == 4 and ARMOR_SLOTS[equipLoc] then return kind.subclassID end
	return nil
end

-- "Best in your armor" (phase 86, owner 2026-11-07): melee and tank specs, where a cloth or lighter piece on
-- top of a list may be a surprise. true: every spec of the class. Healers and casters wear what they like.
local OWN_ARMOR_SPECS = {
	PALADIN = { PROTECTION = true, RETRIBUTION = true },
	SHAMAN = { ENHANCEMENT = true, ENHANCEMENT_DW = true },
	WARRIOR = true, ROGUE = true, HUNTER = true,
	DRUID = { FERAL_CAT = true, FERAL_BEAR = true },
}
local ARMOR_KEY = { [3] = "mail", [4] = "plate" } -- names in the item data's meta.armorFrom
local OWN_LABEL = {
	[4] = ns.N("Best in plate or mail:"), [3] = ns.N("Best in mail or leather:"), [2] = ns.N("Best in leather:"),
}

-- The spec's own armor at a level: { [subclassID] = true } for the heaviest type the class wears by then and
-- the one below it (never cloth), and the line's label; nil for specs not in OWN_ARMOR_SPECS.
-- meta: the class item data's meta (armorFrom: trainer levels, e.g. mail = 40 for a Shaman).
function Classes.ownArmor(token, spec, level, meta)
	local specs, info = OWN_ARMOR_SPECS[token], Classes[token]
	if not (specs and info and info.equip) or (specs ~= true and not specs[spec]) then return nil end
	local from = meta and meta.armorFrom or {}
	local heaviest
	for t = 4, 2, -1 do
		local at = ARMOR_KEY[t] and from[ARMOR_KEY[t]]
		if listed(info.equip.armor, t) and not (at and level and level < at) then heaviest = t break end
	end
	if not heaviest then return nil end
	local own = { [heaviest] = true }
	if heaviest > 2 then own[heaviest - 1] = true end
	return own, OWN_LABEL[heaviest]
end

function Classes.canEquip(token, item)
	return Classes.barredType(token, item) == nil
end

-- Three questions about a weapon, kept apart (phase 122):
--   "barred"            the class can never learn it (Classes.barredType);
--   "later", level      the class learns it, but not before `level` (meta.weaponFrom: Polearms 20);
--   "untrained", skill  learnable now, but this character hasn't trained it (knows(spell) == false);
--   nil                 usable, not a weapon, or unknown (unknown never bars or labels an item).
-- item = { classID, subclassID, equipLoc }; level: the level asked about (the player's, or a previewed one);
-- meta: the class item data's meta; knows: spellID -> true/false/nil (Client.knowsWeaponSpell), or nil to
-- leave training out (a previewed level: you'd train it by then).
function Classes.weaponState(token, item, level, meta, knows)
	if not item or item.classID ~= 2 or item.subclassID == nil then return nil end
	if Classes.barredType(token, item) then return "barred" end
	local from = meta and meta.weaponFrom and meta.weaponFrom[WEAPON_KEY[item.subclassID]]
	if from and level and level < from then return "later", from end
	local spell = WEAPON_SPELL[item.subclassID]
	if knows and spell and knows(spell) == false then
		local class = token and Classes[token]
		local unsure = type(class) == "table" and class.unsureTrainer and class.unsureTrainer[item.subclassID] or false
		return "untrained", WEAPON_SKILL[item.subclassID], unsure
	end
	return nil
end

-- A grey line for a weapon you can't wield yet, or nil: "Not trained yet: a weapon master teaches Polearms." or
-- "Polearms: you can learn it at level 20 (weapon master)". unsure: how the class learns it isn't confirmed
-- (Classes.<class>.unsureTrainer), so no trainer is named.
function Classes.weaponNote(state, value, skill, unsure)
	if state == "untrained" and unsure then
		return string.format(ns.L("Not known yet: %s (how you learn it isn't confirmed)."), ns.L(value))
	elseif state == "untrained" then
		return string.format(ns.L("Not trained yet: a weapon master teaches %s."), ns.L(value))
	elseif state == "later" then
		return string.format(ns.L("%s: you can learn it at level %d (weapon master)."), ns.L(skill or "?"), value)
	end
	return nil
end

-- The skill name of a weapon item (for weaponNote), or nil.
function Classes.weaponSkill(item)
	return item and item.classID == 2 and WEAPON_SKILL[item.subclassID] or nil
end

-- "No use for you: Paladins can't equip staves", or nil when the class can equip the item.
function Classes.equipReason(token, item)
	local barred = Classes.barredType(token, item)
	return barred and string.format(ns.L("No use for you: %ss can't equip %s"), Classes[token].name, ns.L(barred)) or nil
end

-- Class tokens in display order.
Classes.ORDER = { "PALADIN", "SHAMAN", "DRUID", "HUNTER", "PRIEST", "MAGE", "WARRIOR", "WARLOCK", "ROGUE" }

-- The class table for a token, or nil for a class without data yet. A nil token means Paladin, the
-- addon's first class (callers and tests that predate other classes).
function Classes.get(token)
	if token == nil then return Classes.PALADIN end
	local c = Classes[token]
	return type(c) == "table" and c.trees and c or nil
end
