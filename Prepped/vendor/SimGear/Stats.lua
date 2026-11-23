-- Stats: turns the client's raw item stat table into canonical stat keys.
-- Pure: no WoW API access. Canonical keys match the sim engine's Stat enum names
-- so generated weight files apply directly.
local _, ns = ...

local Stats = {}
ns.Stats = Stats

-- Client stat key -> canonical key. Only keys confirmed in game via /dump belong here
-- (rule 4); until then every client key is reported as unknown by normalize().
-- "Dps" is an intermediate key that addWeaponDps() turns into a per-hand stat; "Crit" and "Hit"
-- are intermediate keys that normalize() expands via EXPANDS.
-- Confirmed in game 2026-10-16 (GetItemStats output on Forever).
Stats.KEY_MAP = {
	ITEM_MOD_STRENGTH_SHORT = "Strength",
	ITEM_MOD_AGILITY_SHORT = "Agility", -- Agility/Intellect: tooltips of 1121 and 1716, 2026-10-17
	ITEM_MOD_STAMINA_SHORT = "Stamina",
	ITEM_MOD_INTELLECT_SHORT = "Intellect",
	ITEM_MOD_SPIRIT_SHORT = "Spirit",
	-- Confirmed 2026-10-17 from tooltips (items 868, 15056, 12639): ratings, see RATING_PER_POINT.
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Defense",
	ITEM_MOD_DODGE_RATING_SHORT = "Dodge",
	ITEM_MOD_PARRY_RATING_SHORT = "Parry",
	-- 271213 tooltip "chance to Block attacks with a shield by 1.0%" is BLOCK_RATING 5 (block chance,
	-- see RATING_PER_POINT); 16732 "Block Value of your shield by 17" is BLOCK_VALUE 17. A shield's
	-- own "N Block" line is not in GetItemStats at all: the harvest reads it from the tooltip
	-- (Stats.shieldBlockFromLines) and saves it as SHIELD_BLOCK, which no client key uses.
	ITEM_MOD_BLOCK_RATING_SHORT = "Block",
	ITEM_MOD_BLOCK_VALUE_SHORT = "BlockValue",
	SHIELD_BLOCK = "BlockValue",
	-- One rating covers melee and spell (272457, a caster hood: "critical strike by 0.5%"); split by
	-- EXPANDS. Same reading and factors as the engine's importer (tools/database/wowhead_db.go).
	ITEM_MOD_CRIT_RATING_SHORT = "Crit",
	ITEM_MOD_HIT_RATING_SHORT = "Hit",
	ITEM_MOD_ATTACK_POWER_SHORT = "AttackPower",
	ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RangedAttackPower", -- 10510 (a rifle): 14, 2026-10-17
	-- 1716 "damage and healing ... up to 22" is SPELL_POWER; 2721 "healing up to 33 and damage up to
	-- 11" is SPELL_HEALING_DONE 33 + SPELL_DAMAGE_DONE 11. The engine's importer puts spell damage
	-- and spell power in SpellPower and healing in HealingPower.
	ITEM_MOD_SPELL_POWER_SHORT = "SpellPower",
	ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SpellPower",
	ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HealingPower",
	ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "HolyPower",
	ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "ShadowPower", -- in the harvest (58 items, 2026-10-17)
	-- In the harvest too (2026-10-17): 52, 80 and 24 items. Weighed for Mages.
	ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "FirePower",
	ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "FrostPower",
	ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "ArcanePower",
	ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Dps",
	RESISTANCE0_NAME = "Armor", -- resistance school 0 is armor
	-- "Restores N mana per 5 sec." (Shard of the Splithooves 10659: 6, harvest of 14 Nov; cMaNGOS has it as an
	-- equip spell, aura 85): mana income that also runs while casting. Weighted only where a set has Mp5 (phase 117).
	ITEM_MOD_MANA_REGENERATION_SHORT = "Mp5",
	-- Classic Era 1.15 names spell power without _SHORT (Staff of Dominance: ITEM_MOD_SPELL_POWER=39,
	-- /dump in game 2026-10-28); counted only when the _SHORT key isn't there too (Stats.SAME_AS).
	ITEM_MOD_SPELL_POWER = "SpellPower",
}

-- Client keys that are another key's other name: skipped when that key is in the same item's stats,
-- so no client counts a stat twice.
Stats.SAME_AS = { ITEM_MOD_SPELL_POWER = "ITEM_MOD_SPELL_POWER_SHORT" }

-- Forever stores Classic's "+1%" stats as ratings. Client rating per canonical unit (percentage
-- point; Defense is skill points, 1:1 so it isn't listed). Confirmed 2026-10-17 on a level-22
-- character with GetCombatRatingBonusForCombatRatingValue and matching tooltips: no level scaling
-- at 22 (a TBC-style curve would give far more than 1% there). Level 60 not checked; data/GAPS.md.
-- The engine's importer uses the same factors, measured on 511 crit and 222 hit items.
Stats.RATING_PER_POINT = {
	Crit = 14,
	Hit = 10,
	Dodge = 12,
	Parry = 15,
	Block = 5,
}

-- Intermediate keys that count toward two canonical stats, applied after RATING_PER_POINT.
Stats.EXPANDS = {
	Crit = { "MeleeCrit", "SpellCrit" },
	Hit = { "MeleeHit", "SpellHit" },
}

-- Canonical keys a weight set may use.
Stats.CANONICAL = {
	Strength = true, Agility = true, Stamina = true, Intellect = true, Spirit = true,
	AttackPower = true, MeleeHit = true, MeleeCrit = true,
	SpellPower = true, HolyPower = true, ShadowPower = true, FirePower = true, FrostPower = true, ArcanePower = true, SpellHit = true, SpellCrit = true, HealingPower = true,
	Armor = true, Defense = true, Dodge = true, Parry = true, Block = true, BlockValue = true,
	MainHandDps = true, OffHandDps = true, TwoHandDps = true,
	RangedAttackPower = true, RangedDps = true,
	Mp5 = true,
}

-- Canonical key -> the client's item tooltip strings for it (global names; "%s" is the amount).
-- Confirmed in game 2026-10-17 with /dump: ITEM_MOD_SPELL_POWER "Increases spell power by %s.",
-- ITEM_MOD_CRIT_RATING "Increases your critical strike by %s.", ... One crit line and one hit line
-- count for both melee and spells (EXPANDS). Strength, Agility etc. read plainly ("+5 Agility").
Stats.GEAR_TEXT = {
	SpellPower = { "ITEM_MOD_SPELL_POWER", "ITEM_MOD_SPELL_DAMAGE_DONE" },
	HealingPower = { "ITEM_MOD_SPELL_HEALING_DONE" },
	MeleeCrit = { "ITEM_MOD_CRIT_RATING" }, SpellCrit = { "ITEM_MOD_CRIT_RATING" },
	MeleeHit = { "ITEM_MOD_HIT_RATING" }, SpellHit = { "ITEM_MOD_HIT_RATING" },
	AttackPower = { "ITEM_MOD_ATTACK_POWER" }, RangedAttackPower = { "ITEM_MOD_RANGED_ATTACK_POWER" },
	Defense = { "ITEM_MOD_DEFENSE_SKILL_RATING" }, Dodge = { "ITEM_MOD_DODGE_RATING" },
	BlockValue = { "ITEM_MOD_BLOCK_VALUE" },
	-- School damage: "Increases frost damage done by up to %s." and the like (dumped in game 2026-10-18).
	HolyPower = { "ITEM_MOD_HOLY_DAMAGE_DONE" }, ShadowPower = { "ITEM_MOD_SHADOW_DAMAGE_DONE" },
	FirePower = { "ITEM_MOD_FIRE_DAMAGE_DONE" }, FrostPower = { "ITEM_MOD_FROST_DAMAGE_DONE" },
	ArcanePower = { "ITEM_MOD_ARCANE_DAMAGE_DONE" },
}

-- Wording seen on item tooltips that no client string carries, shown before GEAR_TEXT's. Spell power
-- items read "Increases damage and healing done by magical spells and effects by up to N." (1716 on
-- 2026-10-17; Defias Mage Staff and Spidersilk Boots on 2026-10-18), while ITEM_MOD_SPELL_POWER is
-- "Increases spell power by %s." (dumped 2026-10-18).
Stats.TOOLTIP_TEXT = {
	SpellPower = { "Increases damage and healing done by magical spells and effects by up to %s." },
}

-- The Lua pattern for a client template with one "%d" or "%s" amount, anchored at both ends, or nil.
local function templatePattern(template)
	if type(template) ~= "string" then return nil end
	local before, after = template:match("^(.-)%%[ds](.*)$")
	if not before then return nil end
	local function escape(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
	return "^" .. escape(before) .. "(%d+)" .. escape(after) .. "$"
end

-- Pure: a shield's own block value from its tooltip lines ("11 Block" on 271213), or nil. template is
-- the client's SHIELD_BLOCK_TEMPLATE ("%d Block"); "N Block" is tried when it's missing. Callers pass
-- no secret text.
function Stats.shieldBlockFromLines(lines, template)
	local patterns = { "^(%d+) Block$" }
	local fromTemplate = templatePattern(template)
	if fromTemplate then table.insert(patterns, 1, fromTemplate) end
	for _, line in ipairs(lines or {}) do
		local text = line.leftText
		if type(text) == "string" then
			text = text:gsub("^%s+", ""):gsub("%s+$", "")
			for _, pattern in ipairs(patterns) do
				local n = tonumber(text:match(pattern))
				if n and n > 0 then return n end
			end
		end
	end
end

-- Pure: a weapon's speed in seconds from its tooltip lines (the damage line's right text, "Speed 2.60"),
-- or nil. label is the client's SPEED ("Speed"); "Speed" is tried when it's missing. Callers pass no
-- secret text.
function Stats.weaponSpeedFromLines(lines, label)
	local labels = { "Speed" }
	if type(label) == "string" and label ~= "Speed" then table.insert(labels, 1, label) end
	for _, line in ipairs(lines or {}) do
		local text = line.rightText
		if type(text) == "string" then
			text = text:gsub("^%s+", ""):gsub("%s+$", "")
			for _, l in ipairs(labels) do
				local amount = text:match("^" .. l:gsub("%p", "%%%0") .. "%s+(%d+[%.,]?%d*)$")
				local n = amount and tonumber((amount:gsub(",", ".")))
				if n and n > 0 and n < 10 then return n end
			end
		end
	end
end

-- Returns stats (canonical key -> number) and a sorted list of client keys that had no mapping.
-- keyMap defaults to Stats.KEY_MAP, perPoint to Stats.RATING_PER_POINT.
function Stats.normalize(raw, keyMap, perPoint)
	keyMap = keyMap or Stats.KEY_MAP
	perPoint = perPoint or Stats.RATING_PER_POINT
	local stats, unknown = {}, {}
	for key, amount in pairs(raw or {}) do
		local canonical = keyMap[key]
		local twin = Stats.SAME_AS[key]
		if twin and raw[twin] ~= nil then
			-- counted under its other name
		elseif canonical and type(amount) == "number" then
			stats[canonical] = (stats[canonical] or 0) + amount
		else
			unknown[#unknown + 1] = key
		end
	end
	for canonical, per in pairs(perPoint) do
		if stats[canonical] then stats[canonical] = stats[canonical] / per end
	end
	for key, targets in pairs(Stats.EXPANDS) do
		local amount = stats[key]
		if amount then
			stats[key] = nil
			for _, target in ipairs(targets) do
				stats[target] = (stats[target] or 0) + amount
			end
		end
	end
	table.sort(unknown)
	return stats, unknown
end

local DPS_KEY_BY_EQUIPLOC = {
	INVTYPE_2HWEAPON = "TwoHandDps",
	INVTYPE_WEAPON = "MainHandDps", -- paladins can't dual-wield, so one-handers go in the main hand
	INVTYPE_WEAPONMAINHAND = "MainHandDps",
	INVTYPE_WEAPONOFFHAND = "OffHandDps",
	-- Bows (RANGED), guns and crossbows (RANGEDRIGHT), thrown: the ranged slot.
	INVTYPE_RANGED = "RangedDps", INVTYPE_RANGEDRIGHT = "RangedDps", INVTYPE_THROWN = "RangedDps",
}

-- Moves the intermediate "Dps" stat to the per-hand stat for this equip location.
-- Returns the same table. Non-weapons just lose the intermediate key.
function Stats.addWeaponDps(stats, equipLoc)
	local dps = stats.Dps
	stats.Dps = nil
	local key = DPS_KEY_BY_EQUIPLOC[equipLoc]
	if dps and key then
		stats[key] = (stats[key] or 0) + dps
	end
	return stats
end

-- An item link's random suffix id, or nil when it has none (0, missing, or not an item link). Classic
-- links hold it in the field after the item id, enchant and four gems ("item:14200:0:0:0:0:0:776");
-- Forever leaves that empty and sends a bonus list: field 13 counts the IDs that follow
-- ("item:4567::::::::16:1486::1:1:12724:1:28:5244", Seen.suffixesOf). Gives the first bonus ID: every one
-- recorded so far is a suffix, and any other would change the item too, so the client's read still holds.
function Stats.linkSuffix(link)
	if type(link) ~= "string" then return nil end
	local suffix = tonumber(link:match("item:%-?%d+:[^:|]*:[^:|]*:[^:|]*:[^:|]*:[^:|]*:(%-?%d+)"))
	if suffix and suffix ~= 0 then return suffix end
	local count, bonus = link:match("item:%-?%d+" .. string.rep(":[^:|]*", 11) .. ":(%d+):(%d+)")
	if tonumber(count) and tonumber(count) > 0 and tonumber(bonus) > 0 then return tonumber(bonus) end
end

-- Scores an item from the item DB when it has one, so the tooltip and the panel see the same stats:
-- Era's client has Ironbark Staff at 41 spell power, the DB (the Forever harvest) at 88, and the item
-- read +361% in the panel and -77% in its tooltip (owner, 2026-10-28). The client's stats stay for a
-- random suffix roll (they hold that exact roll) and for Classic stand-ins (the client's copy is the
-- real item, the stand-in a cMaNGOS guess; owner 2026-10-29). Sets read.statsFrom ("db" or "client")
-- and, on "db", read.clientStats. Returns read.
function Stats.preferDb(read, db)
	read.statsFrom = "client"
	local item = db and db.items and db.items[read.itemID]
	-- Weapon speed (Score.speedFactor) holds whatever its stats: a stand-in's or a suffix roll's too.
	if type(item) == "table" then read.speed, read.dagger = item.speed, item.dagger end
	if type(item) ~= "table" or type(item.stats) ~= "table" or item.classic or Stats.linkSuffix(read.link) then
		return read
	end
	local stats = {}
	for key, amount in pairs(item.stats) do stats[key] = amount end
	read.clientStats, read.stats, read.statsFrom = read.stats, stats, "db"
	return read
end

-- The stats where two stat tables differ, as a sorted list of { key, a, b } (a missing stat is 0).
function Stats.differences(a, b)
	local out, seen = {}, {}
	a, b = a or {}, b or {}
	local function add(key)
		if seen[key] then return end
		seen[key] = true
		local x, y = a[key] or 0, b[key] or 0
		if math.abs(x - y) > 0.01 then out[#out + 1] = { key = key, a = x, b = y } end
	end
	for key in pairs(a) do add(key) end
	for key in pairs(b) do add(key) end
	table.sort(out, function(p, q) return p.key < q.key end)
	return out
end
