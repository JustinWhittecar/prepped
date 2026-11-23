-- Enchants (phase 106, owner 2026-11-12: "only on the weights tab ... the enchants recommended for every
-- gear slot"): the best Enchanting recipe per gear slot for a weight set, from data/enchants.lua (the
-- client tables, pipeline/enchants). Pure: the Weights tab (Panel.lua) passes the set and the worn links.
-- Procs the engine sims are scored from data/enchants/<CLASS>.lua (phase 107, pipeline/weights/enchants.go);
-- other procs and utility (Minor Speed, resistances) aren't scored and are listed by name, so the page never
-- ranks a stat enchant above one as a fact.
local _, ns = ...

local Enchants = {}
ns.Enchants = Enchants

-- Weapon damage per hit becomes DPS at an assumed speed: no slot has a known weapon here.
Enchants.SPEED = { weapon = 2.6, twohand = 3.5 }

-- Rows of the Enchants page, top to bottom. inv: the inventory slot whose item may carry the enchant.
-- icon: the character pane's empty-slot art.
Enchants.SLOTS = {
	{ key = "back", inv = 15, label = "Back", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Back" },
	{ key = "chest", inv = 5, label = "Chest", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest" },
	{ key = "wrist", inv = 9, label = "Wrist", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists" },
	{ key = "hands", inv = 10, label = "Hands", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands" },
	{ key = "feet", inv = 8, label = "Feet", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet" },
	{ key = "neck", inv = 2, label = "Neck", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck" },
	{ key = "weapon", inv = 16, label = "One-hand", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand" },
	{ key = "twohand", inv = 16, label = "Two-hand", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand" },
	{ key = "shield", inv = 17, label = "Shield", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand" },
	{ key = "offhand", inv = 17, label = "Off hand", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand" },
}

-- The equip locations whose item a slot row is about (for "yours").
local LOCS = {
	weapon = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true },
	twohand = { INVTYPE_2HWEAPON = true },
	shield = { INVTYPE_SHIELD = true },
	offhand = { INVTYPE_HOLDABLE = true },
}
Enchants.LOCS = LOCS

-- Two-handed weapon subclasses (axe, mace, polearm, sword, staff).
local TWO_HANDED = { [1] = true, [5] = true, [6] = true, [8] = true, [10] = true }

local function has(list, pred)
	for _, v in ipairs(list or {}) do
		if pred(v) then return true end
	end
	return false
end

-- The slot rows a class (and spec) can use: a shield row when it wears shields, a two-hand row when it
-- wields a two-hander, an off-hand row unless it can't hold one; a spec's excluded equip locations
-- (Classes gearRules: Prot Paladin has no two-hand or held off-hand) take rows away.
function Enchants.slotsFor(token, spec)
	local class = ns.Classes and ns.Classes[token]
	local equip = class and class.equip or {}
	local rule = class and class.gearRules and spec and class.gearRules[spec]
	local excluded = rule and rule.excluded or {}
	local out = {}
	for _, s in ipairs(Enchants.SLOTS) do
		local ok = true
		if s.key == "twohand" then
			ok = has(equip.weapons, function(v) return TWO_HANDED[v] end) and not excluded.INVTYPE_2HWEAPON
		elseif s.key == "shield" then
			ok = has(equip.armor, function(v) return v == 6 end) and not excluded.INVTYPE_SHIELD
		elseif s.key == "offhand" then
			ok = not equip.noHoldable and not excluded.INVTYPE_HOLDABLE
		end
		if ok then out[#out + 1] = s end
	end
	return out
end

local byEnchant
-- The data row of an enchant ID (the number in an item link), or nil.
function Enchants.byEnchantID(id)
	if not byEnchant then
		byEnchant = {}
		for _, r in ipairs(ns.EnchantData and ns.EnchantData.rows or {}) do byEnchant[r.enchant] = byEnchant[r.enchant] or r end
	end
	return id and byEnchant[id]
end

-- The enchant ID in an item link: the field after the item ID ("item:14200:1886:..."), or nil for none.
function Enchants.enchantOfLink(link)
	if type(link) ~= "string" then return nil end
	local id = tonumber(link:match("item:%-?%d+:(%d+)"))
	if id and id > 0 then return id end
end

-- The stats an enchant adds on a slot: its own, plus weapon damage as DPS for the hand it goes on.
function Enchants.statsOf(row, slotKey)
	local stats = {}
	for k, v in pairs(row.stats or {}) do stats[k] = v end
	if row.damage and row.damage ~= 0 then
		local key = slotKey == "twohand" and "TwoHandDps" or "MainHandDps"
		stats[key] = (stats[key] or 0) + row.damage / (Enchants.SPEED[slotKey] or Enchants.SPEED.weapon)
	end
	return stats
end

local SCHOOLS = { HolyPower = true, FirePower = true, FrostPower = true, ShadowPower = true, ArcanePower = true, NaturePower = true }

-- A school's spell power the set has no weight for at all, while it does weigh spell power: the
-- school split isn't simmed for this spec (Balance, Elemental, Nature), so it can't be scored.
local function unsimmedSchool(stats, weightSet)
	local w = weightSet.weights
	if (w.SpellPower or 0) <= 0 then return nil end
	for k in pairs(stats) do
		if SCHOOLS[k] and w[k] == nil then return k end
	end
end

-- The rows that go on a slot: the slot's own, and Enchant Weapon rows on a two-hander too.
local function candidates(slotKey)
	local out = {}
	for _, r in ipairs(ns.EnchantData and ns.EnchantData.rows or {}) do
		if r.slot == slotKey or (slotKey == "twohand" and r.slot == "weapon") then out[#out + 1] = r end
	end
	return out
end

-- A recipe's sim (phase 107, data/enchants/<CLASS>.lua) for this slot row: { v, se, on }, or nil. A one-hand
-- weapon recipe simmed on a two-hander (on = "twohand") only counts on the two-hand row, and the other way round.
local function simOf(sims, row, slotKey)
	local s = type(sims) == "table" and sims[row.enchant]
	if type(s) ~= "table" or type(s.v) ~= "number" or type(s.se) ~= "number" then return nil end
	if (s.on or row.slot) ~= slotKey then return nil end
	return s
end

-- Recipes with the same stats (and weapon damage) share a group: lower ranks follow the simmed one.
local function groupOf(row)
	local keys = {}
	for k in pairs(row.stats or {}) do keys[#keys + 1] = k end
	if row.damage and row.damage ~= 0 then keys[#keys + 1] = "damage" end
	table.sort(keys)
	return table.concat(keys, ",")
end

-- The best enchants for a slot under a weight set. opts.scale: the weight set's units per Stats-page unit
-- (Plan.scaleOf), so `worth` matches the Stats page; opts.n: list length (3). opts.sims: the enchant sims
-- for the set's spec and level (Gear.enchantSims), opts.raw: the set they were simmed for, before the
-- leveling plan and pins (Gear.pickSet).
-- A sim counts where the stat score can't see it: a proc's worth is its sim (none above twice its standard
-- error is "no measurable gain"); a stat recipe keeps its stat score unless the sim differs from it by more
-- than twice its standard error (caps, mana), then the difference is added, and lower ranks of the same
-- stats scale with it.
-- Returns { best = entry or nil, list = { entry, ... }, procs = { name, ... }, noGain = { name, ... },
-- schools = { name, ... }, utility = { name, ... }, simmed = true when any number came from a sim,
-- nothing = true when no enchant is worth anything }, where entry = { row, stats, value, worth,
-- sim = "proc" | "corrected" | "agrees" | "scaled" or nil, se, seWorth = se in worth units }.
function Enchants.forSlot(slotKey, weightSet, opts)
	opts = opts or {}
	local scale = opts.scale and opts.scale > 0 and opts.scale or 1
	local raw = opts.raw or weightSet
	local out = { list = {}, procs = {}, noGain = {}, schools = {}, utility = {} }
	local scored, factor, later = {}, {}, {}
	local function add(e)
		if e.value > 0 then
			e.worth = e.value / scale
			if e.se then e.seWorth = e.se / scale end
			scored[#scored + 1] = e
		end
	end
	for _, r in ipairs(candidates(slotKey)) do
		local stats = Enchants.statsOf(r, slotKey)
		local sim = simOf(opts.sims, r, slotKey)
		if sim then
			out.simmed = true
			if r.proc or next(stats) == nil then
				if sim.v > 2 * sim.se then
					add({ row = r, stats = stats, value = sim.v, sim = "proc", se = sim.se })
				else
					out.noGain[#out.noGain + 1] = r.name
				end
			else
				local here = ns.Score.value(stats, weightSet)
				local diff = sim.v - ns.Score.value(stats, raw)
				if math.abs(diff) > 2 * sim.se then
					if here > 0 then factor[groupOf(r)] = (here + diff) / here end
					add({ row = r, stats = stats, value = here + diff, sim = "corrected", se = sim.se })
				else
					add({ row = r, stats = stats, value = here, sim = "agrees", se = sim.se })
				end
			end
		elseif r.proc then
			out.procs[#out.procs + 1] = r.name
		elseif unsimmedSchool(stats, weightSet) then
			out.schools[#out.schools + 1] = r.name
		elseif next(stats) == nil then
			out.utility[#out.utility + 1] = r.name
		else
			later[#later + 1] = { row = r, stats = stats }
		end
	end
	-- Unsimmed stat recipes, after the sims: a lower rank follows its group's simmed correction.
	for _, e in ipairs(later) do
		local value = ns.Score.value(e.stats, weightSet)
		local f = factor[groupOf(e.row)]
		if f then
			value = value * f
			e.sim = "scaled"
		end
		e.value = value
		add(e)
	end
	table.sort(scored, function(a, b)
		if math.abs(a.value - b.value) > 1e-9 then return a.value > b.value end
		return a.row.spell < b.row.spell
	end)
	for i = 1, math.min(opts.n or 3, #scored) do out.list[i] = scored[i] end
	out.best = out.list[1]
	out.nothing = out.best == nil
	for _, key in ipairs({ "procs", "noGain", "schools", "utility" }) do table.sort(out[key]) end
	return out
end

-- What a worn item's enchant is, for the "yours" column: "best" (it is the best one), "known" (another
-- enchant in the data; row), "other" (an enchant SimGear doesn't list) or "none" (no enchant).
function Enchants.yours(link, result)
	local id = Enchants.enchantOfLink(link)
	if not id then return "none" end
	local row = Enchants.byEnchantID(id)
	if not row then return "other" end
	if result and result.best and result.best.row.enchant == id then return "best", row end
	return "known", row
end

-- The recipe name without "Enchant <slot> - ": "Superior Agility".
function Enchants.shortName(row)
	return (row.name:gsub("^Enchant [^-]+ %- ", ""))
end
