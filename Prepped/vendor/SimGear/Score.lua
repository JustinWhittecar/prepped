-- Score: weights x stats, and % change versus what is equipped.
-- Pure: callers pass fully loaded stat tables (rule 6); no WoW API access.
local _, ns = ...

local Score = {}
ns.Score = Score

-- Inventory slot IDs.
local MAINHAND, OFFHAND = 16, 17

-- Equip location -> how the item is compared.
local SINGLE = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
	INVTYPE_CLOAK = 15, INVTYPE_RELIC = 18,
	INVTYPE_RANGED = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_THROWN = 18,
}
local PAIRED = {
	INVTYPE_FINGER = { 11, 12 },
	INVTYPE_TRINKET = { 13, 14 },
}
local MAIN_HAND_TYPES = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local OFF_HAND_TYPES = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true }
-- Off-hand partners for a dual-wielder: a one-hander can go in the off hand too.
local DW_PARTNER_TYPES = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_WEAPON = true }

-- Picks the weight set from a spec's list whose level range is nearest to `level`.
-- Sets without a level range apply at any level. Ties go to the lower bracket.
function Score.pickSet(sets, level)
	local best, bestDistance
	for _, set in ipairs(sets or {}) do
		local lo, hi = set.source.minLevel, set.source.maxLevel
		local distance = 0
		if lo and level < lo then distance = lo - level
		elseif hi and level > hi then distance = level - hi end
		-- A tie (level 35 between the Lv30 and Lv40 sets) goes to the lower set whatever the list order:
		-- the player hasn't reached the higher one's talents, ranks and gear yet. Two sets of the same
		-- level (Feral Cat's measured and simmed Lv30) go to the simmed one; the other still lends its
		-- survival layer (Plan.leveling).
		local bestLo = bestDistance and (best.source.minLevel or 0)
		if not bestDistance or distance < bestDistance
			or (distance == bestDistance and ((lo or 0) < bestLo
				or ((lo or 0) == bestLo and set.source.kind == "sim" and best.source.kind ~= "sim"))) then
			best, bestDistance = set, distance
		end
	end
	return best
end

-- The weight one point of stats[key] gets. An item reading "healing up to 33 and damage up to 11"
-- (2721) has HealingPower 33 and SpellPower 11 (Stats.lua): its spell power is the damage part only,
-- so a set that weighs healing doesn't count it on top. "Damage and healing up to 16" is SpellPower
-- alone and heals by the same 16 (owner's dump, level 2 Paladin, 2026-10-23: healing 11 to 27,
-- Holy damage 0 to 16).
function Score.weightOf(stats, key, weightSet)
	local w = weightSet.weights[key] or 0
	if key == "SpellPower" and (stats.HealingPower or 0) > 0 and (weightSet.weights.HealingPower or 0) > 0 then return 0 end
	return w
end

-- Sum of stats[k] * weights[k]. Refuses weight sets without a source so every number is traceable.
function Score.value(stats, weightSet)
	assert(type(weightSet) == "table" and type(weightSet.source) == "table",
		"weight set has no source; refusing to score untraceable weights")
	local total = 0
	for key, amount in pairs(stats or {}) do
		total = total + amount * Score.weightOf(stats, key, weightSet)
	end
	return total
end

-- A trinket effect's worth beyond its stats, simmed at 60 for that set (set.effects, pipeline
-- weights/trinkets.go), or 0.
function Score.effectOf(itemID, weightSet)
	local effects = weightSet and weightSet.effects
	return effects and itemID and effects[itemID] or 0
end

-- A random suffix item's choices for this set: { prop, name, stats (base + suffix), value, chance,
-- rolls } per suffix name it rolls, best value first, or nil when it rolls none. Equal values (Score.sameValue)
-- are a tie, not a ranking: the more common one in Classic goes first (cMaNGOS odds, the only ones we have),
-- then known odds before unknown (chance 0), then the lower suffix ID (phase 124, tester 2026-11-20: Falcon
-- topped Monkey and Wolf on the suffix ID alone). Advisor.withSuffix names the ties.
-- suffixes: the class's extras (pipeline/items -extras: groups, suffixes). An item rolls a suffix in
-- several sizes (Thistlefur Cap: four "of the Owl" rolls), so a name counts with its average roll,
-- weighted by chance, not its best; prop is the roll nearest that average (for the item link).
-- chance: share of drops with that suffix name, in % (0: seen in game, odds unknown); rolls: how many sizes it comes in.
-- A value rounded to 9 significant digits: two suffixes whose stats are worth the same (Agility + Intellect
-- and Agility + Stamina when both carry the same weight) can differ in the last bits of a float sum.
function Score.tieKey(value)
	return tonumber(string.format("%.9g", value))
end

function Score.sameValue(a, b)
	return Score.tieKey(a) == Score.tieKey(b)
end

local function suffixOptions(item, suffixes, weightSet, group)
	local byName, order = {}, {}
	for _, pc in ipairs(group) do
		local def = suffixes.suffixes[pc[1]]
		if def then
			local o = byName[def.name]
			if not o then
				o = { name = def.name, chance = 0, rolls = {} }
				byName[def.name] = o
				order[#order + 1] = o
			end
			o.chance = o.chance + pc[2]
			o.rolls[#o.rolls + 1] = { prop = pc[1], chance = pc[2], value = Score.value(def.stats, weightSet), stats = def.stats }
		end
	end
	local out = {}
	for _, o in ipairs(order) do
		-- Chance 0: a suffix only seen in game (pipeline -extras, from the recorder), its odds unknown:
		-- its sizes count equally.
		local total = 0
		for _, r in ipairs(o.rolls) do
			r.weight = o.chance > 0 and r.chance or 1
			total = total + r.weight
		end
		if total > 0 then
			local stats = {}
			for k, v in pairs(item.stats or {}) do stats[k] = v end
			for _, r in ipairs(o.rolls) do
				for k, v in pairs(r.stats) do stats[k] = (stats[k] or 0) + v * r.weight / total end
			end
			local avg = 0
			for _, r in ipairs(o.rolls) do avg = avg + r.value * r.weight end
			avg = avg / total
			local near
			for _, r in ipairs(o.rolls) do
				local d, nd = math.abs(r.value - avg), near and math.abs(near.value - avg)
				if not near or d < nd - 1e-9 or (math.abs(d - nd) <= 1e-9 and r.prop < near.prop) then
					near = r
				end
			end
			out[#out + 1] = { prop = near.prop, name = o.name, stats = stats, value = Score.value(stats, weightSet), chance = o.chance, rolls = #o.rolls }
		end
	end
	if #out == 0 then return nil end
	for _, o in ipairs(out) do o.tieKey = Score.tieKey(o.value) end
	table.sort(out, function(a, b)
		if a.tieKey ~= b.tieKey then return a.tieKey > b.tieKey end
		if a.chance ~= b.chance then return a.chance > b.chance end
		return a.prop < b.prop
	end)
	return out
end

-- Memo: suffixes table -> weight set -> item -> options (false: none). All three are long-lived and the
-- answer depends on nothing else, so the panel's 19 lists per refresh and later refreshes reuse it (it
-- was most of a refresh's time: 2026-11-03). Weak keys: a re-planned set or reloaded data drops out.
-- Callers only read the options.
local suffixMemo = setmetatable({}, { __mode = "k" })

local function weakTable() return setmetatable({}, { __mode = "k" }) end

function Score.suffixOptions(item, suffixes, weightSet)
	local group = item and item.suffixGroup and suffixes and suffixes.groups and suffixes.groups[item.suffixGroup]
	if not group then return nil end
	local bySet = suffixMemo[suffixes]
	if not bySet then bySet = weakTable() suffixMemo[suffixes] = bySet end
	local byItem = bySet[weightSet]
	if not byItem then byItem = weakTable() bySet[weightSet] = byItem end
	local known = byItem[item]
	if known == nil then
		known = suffixOptions(item, suffixes, weightSet, group) or false
		byItem[item] = known
	end
	return known or nil
end

-- Weapon speed (phase 60). At the same DPS a slow weapon hits harder per swing, which instant attacks
-- (normalized speed), extra attacks and PPM procs reward. The weight set's speedCurves (pipeline
-- weights/speed.go) give, per hand, the DPS change per second of speed, a line fitted through sims at
-- 60; it is counted from the weapon kind's normalized speed and clamped to the speeds simmed for it.
Score.SPEED_KINDS = {
	twoHand = { ref = 3.3, min = 2.8, max = 3.9 }, oneHand = { ref = 2.4, min = 1.5, max = 2.9 },
	dagger = { ref = 1.7, min = 1.3, max = 1.9 }, ranged = { ref = 2.8, min = 2.0, max = 3.2 },
}
local CURVE_OF = { MainHandDps = "mainHand", TwoHandDps = "mainHand", OffHandDps = "offHand", RangedDps = "ranged" }

function Score.speedKind(item, key)
	if key == "RangedDps" then return "ranged" end
	if item.equipLoc == "INVTYPE_2HWEAPON" then return "twoHand" end
	return item.dagger and "dagger" or "oneHand"
end

-- The multiplier on the item's `key` weapon DPS for its speed: 1 without a speed or a curve.
function Score.speedFactor(item, key, weightSet)
	local curves = weightSet and weightSet.speedCurves
	local curve = curves and CURVE_OF[key] and curves[CURVE_OF[key]]
	local speed = item and item.speed
	if type(curve) ~= "table" or type(curve.perSecond) ~= "number" or curve.perSecond == 0
		or type(speed) ~= "number" or speed <= 0 then
		return 1
	end
	local k = Score.SPEED_KINDS[Score.speedKind(item, key)]
	return 1 + curve.perSecond * (math.min(math.max(speed, k.min), k.max) - k.ref)
end

-- What the item's speed adds to (or takes from) its value: its weapon DPS value x (factor - 1), and the key.
function Score.speedValue(item, weightSet)
	local stats = item and item.stats
	if not stats or not item.speed then return 0 end
	for key in pairs(CURVE_OF) do
		local dps = stats[key]
		if dps and dps > 0 then
			return dps * Score.weightOf(stats, key, weightSet) * (Score.speedFactor(item, key, weightSet) - 1), key
		end
	end
	return 0
end

local function itemValue(item, weightSet)
	if not item then return 0 end
	return Score.value(item.stats, weightSet) + Score.speedValue(item, weightSet) + Score.effectOf(item.itemID, weightSet)
end

-- The item as it counts in the off hand: a one-hander's weapon DPS is filed as MainHandDps (Stats, by
-- equip location), but in the off hand it weighs as OffHandDps (a dual-wielder's off hand is worth
-- 2-3.6x less per DPS, audit 2026-10-19). Other items come back unchanged.
function Score.inOffHand(item)
	local dps = item and item.stats and item.stats.MainHandDps
	if not dps then return item end
	local stats = {}
	for k, v in pairs(item.stats) do stats[k] = v end
	stats.MainHandDps, stats.OffHandDps = nil, (stats.OffHandDps or 0) + dps
	local copy = {}
	for k, v in pairs(item) do copy[k] = v end
	copy.stats = stats
	return copy
end
local inOffHand = Score.inOffHand

local function isTwoHand(item)
	return item ~= nil and item.equipLoc == "INVTYPE_2HWEAPON"
end

-- Adds pct and status. A preset status (e.g. "needs-partner") is kept, but pct is still filled in.
local function finish(result)
	if result.oldValue <= 0 then
		result.status = result.status or "no-baseline"
		return result
	end
	result.pct = (result.newValue - result.oldValue) / result.oldValue
	result.status = result.status or (result.pct > 0 and "upgrade" or "downgrade")
	return result
end

-- The best-scoring item in `bags` whose equip location is in `locs` and not in `excluded`, with its
-- value, or nil. off: valued as it counts in the off hand.
local function bestFromBags(bags, locs, excluded, weightSet, off)
	local best, bestValue
	for _, item in ipairs(bags or {}) do
		if locs[item.equipLoc] and not (excluded and excluded[item.equipLoc]) then
			local v = itemValue(off and inOffHand(item) or item, weightSet)
			if not best or v > bestValue then best, bestValue = item, v end
		end
	end
	return best, bestValue
end

-- Weapons compare the whole main hand + off hand pair: a two-hander against both equipped hands,
-- and a one-hander or off hand against an equipped two-hander together with the best partner from
-- your bags (result.partner); with no partner in the bags it is scored alone ("needs-partner").
-- With opts.dualWield a one-hander (INVTYPE_WEAPON) may also replace the off hand: opts.hand
-- "main" or "off" picks the hand, otherwise the better of the two (result.hand = "off" when used).
local function compareWeapon(candidate, equipped, weightSet, opts)
	local mh, oh = equipped[MAINHAND], equipped[OFFHAND]
	local cand = itemValue(candidate, weightSet)
	local ohValue = itemValue(inOffHand(oh), weightSet)
	local result = {
		replaces = { MAINHAND, OFFHAND },
		oldValue = itemValue(mh, weightSet) + ohValue,
	}
	local loc = candidate.equipLoc
	local partnerLocs, partnerOff
	if loc == "INVTYPE_2HWEAPON" then
		result.newValue = cand
	elseif MAIN_HAND_TYPES[loc] then
		result.replaces = { MAINHAND }
		if isTwoHand(mh) then
			partnerLocs, partnerOff = opts.dualWield and DW_PARTNER_TYPES or OFF_HAND_TYPES, true
		else
			local asMain = cand + ohValue
			local asOff = opts.dualWield and loc == "INVTYPE_WEAPON" and itemValue(mh, weightSet) + itemValue(inOffHand(candidate), weightSet) or nil
			if asOff and (opts.hand == "off" or (opts.hand ~= "main" and asOff > asMain)) then
				result.replaces, result.newValue, result.hand = { OFFHAND }, asOff, "off"
			else
				result.newValue = asMain
			end
		end
	elseif OFF_HAND_TYPES[loc] then
		result.replaces = { OFFHAND }
		if isTwoHand(mh) then
			result.replaces = { MAINHAND }
			partnerLocs = MAIN_HAND_TYPES
		else
			result.newValue = itemValue(mh, weightSet) + itemValue(inOffHand(candidate), weightSet)
		end
	else
		return nil
	end
	if partnerLocs then
		-- The best partner doesn't depend on the candidate: opts.partnerMemo (one list's opts, see
		-- Advisor.top) keeps it per partner type instead of searching the bags for every candidate.
		local memo = opts.partnerMemo
		local known = memo and memo[partnerLocs]
		local partner, value
		if known then
			partner, value = known[1] or nil, known[2]
		else
			partner, value = bestFromBags(opts.bags, partnerLocs, opts.excluded, weightSet, partnerOff)
			if memo then memo[partnerLocs] = { partner or false, value } end
		end
		if partner then
			result.partner, result.newValue, result.partnerOff = partner, cand + value, partnerOff
		else
			result.newValue, result.status = cand, "needs-partner"
		end
	end
	return finish(result)
end

local function sameItem(a, b)
	return a ~= nil and b ~= nil and a.itemID ~= nil and a.itemID == b.itemID
end

local function hitOf(item, key)
	return item and item.stats and item.stats[key] or 0
end

-- One capped stat (HitCap pools for `key`): the replaced items' amount and the new items' amount are
-- each valued on top of what you'd have without the replaced items. Returns true when that changed a value.
local function applyCap(result, candidate, equipped, weightSet, pools, key)
	if not pools then return false end
	local removed = 0
	for _, slot in ipairs(result.replaces or {}) do removed = removed + hitOf(equipped[slot], key) end
	local added = hitOf(candidate, key) + hitOf(result.partner, key)
	local oldFix = ns.HitCap.correction(pools, key, weightSet, removed, removed)
	local newFix = ns.HitCap.correction(pools, key, weightSet, removed, added)
	if oldFix == 0 and newFix == 0 then return false end
	result.oldValue, result.newValue = result.oldValue + oldFix, result.newValue + newFix
	return true
end

-- Cap-aware hit (HitCap), so hit past the cap counts 0, and for tank sets Defense past the crit cap at
-- its past-cap weight (HitCap.defensePools). hit = { player, target } (HitCap.pools). Sets result.hitCap
-- and result.defenseCap (the Defense skill of the cap, e.g. 440) when a cap changed a value.
local function capHit(result, candidate, equipped, weightSet, hit)
	if not result or result.status == "equipped" then return result end
	local HitCap = ns.HitCap
	local changed = false
	local pools, key = HitCap.pools(weightSet, hit.player, hit.target)
	if applyCap(result, candidate, equipped, weightSet, pools, key) then
		result.hitCap = HitCap.capOf(pools)
		changed = true
	end
	pools, key = HitCap.defensePools(weightSet, hit.player, hit.target)
	if applyCap(result, candidate, equipped, weightSet, pools, key) then
		result.defenseCap = 5 * (hit.player.level or 0) + pools[1].cap
		changed = true
	end
	if not changed then return result end
	if result.status ~= "empty-slot" then
		if result.status ~= "needs-partner" then result.status = nil end
		result.pct = nil
		finish(result)
	end
	return result
end

-- Your worn gear's score with its hit capped (as Score.compare with opts.hit): the sum of Score.value
-- over `items`, corrected for the hit past the cap. offHand(inv, item) gives the item as it counts.
function Score.wornValue(items, weightSet, hit, offHand)
	local total, gearHit, gearDef = 0, 0, 0
	local pools, key, defPools, defKey
	if hit then
		pools, key = ns.HitCap.pools(weightSet, hit.player, hit.target)
		defPools, defKey = ns.HitCap.defensePools(weightSet, hit.player, hit.target)
	end
	for inv, item in pairs(items or {}) do
		total = total + itemValue(offHand and offHand(inv, item) or item, weightSet)
		if key then gearHit = gearHit + hitOf(item, key) end
		if defKey then gearDef = gearDef + hitOf(item, defKey) end
	end
	if pools then total = total + ns.HitCap.correction(pools, key, weightSet, gearHit, gearHit) end
	if defPools then total = total + ns.HitCap.correction(defPools, defKey, weightSet, gearDef, gearDef) end
	return total
end

-- An item's own score as Score.wornValue counts it (stats, weapon speed, simmed effect), before any cap.
Score.itemValue = itemValue

-- The capped stats of a set's hit cap and Defense cap (HitCap.pools, HitCap.defensePools): { hitKey, defenseKey },
-- each nil when the set has none or hit is nil. For Advisor.bestSet, which adds items up itself.
function Score.capKeys(weightSet, hit)
	if not (hit and ns.HitCap) then return {} end
	local pools, key = ns.HitCap.pools(weightSet, hit.player, hit.target)
	local defPools, defKey = ns.HitCap.defensePools(weightSet, hit.player, hit.target)
	return { hit = pools and key or nil, defense = defPools and defKey or nil, pools = pools, defPools = defPools }
end

-- The amount of one capped stat on an item (0 when none).
Score.hitOf = hitOf

-- What the caps take off (or add to) an outfit carrying gearHit hit and gearDef Defense in all, worn instead of
-- the gear you wear now (wornHit, wornDef: its amounts, which the player's current hit and Defense include).
-- Score.wornValue is the case outfit = worn gear. caps: Score.capKeys.
function Score.capCorrection(caps, weightSet, wornHit, gearHit, wornDef, gearDef)
	local fix = 0
	if caps.hit then fix = fix + ns.HitCap.correction(caps.pools, caps.hit, weightSet, wornHit, gearHit) end
	if caps.defense then fix = fix + ns.HitCap.correction(caps.defPools, caps.defense, weightSet, wornDef, gearDef) end
	return fix
end

local compareLinear

-- An effect SimGear doesn't score makes the % count stats only (owner 2026-10-28,
-- research/grill-2026-10-28.md Q5): effectNew = the candidate's kind, so its gain is a floor;
-- effectWorn = { kind, slot } for the first worn item it replaces that has one, so it is no plain upgrade.
local setFullySimmed

-- An item's unscored-effect kind, or nil: a "set" mark goes once the sim scores every unscored bonus of its set
-- for this weight set (phase 129, Score.setBonusValue).
local function effectKind(id, effects, weightSet, sets)
	local kind = id and effects[id]
	if kind == "set" and sets and setFullySimmed(id, sets, weightSet) then return nil end
	return kind
end

local function markEffects(result, candidate, equipped, effects, weightSet, sets)
	if result.status == "equipped" then return end
	result.effectNew = effectKind(candidate.itemID, effects, weightSet, sets)
	for _, slot in ipairs(result.replaces or {}) do
		local worn = equipped[slot]
		local kind = worn and effectKind(worn.itemID, effects, weightSet, sets)
		if kind then
			result.effectWorn = { kind = kind, slot = slot }
			return
		end
	end
end

-- Item set bonuses (phase 45, owner 2026-10-29): an item can be weaker alone and better once it
-- completes a 2-piece. sets = { bySet = { [setID] = { name, items, bonuses = { { n, stats, unscored } } } },
-- ofItem = { [itemID] = setID } } (Data.lua, from the extras; pipeline/items/sets.go). Only a bonus's
-- stats count; the part of a bonus no stat covers stays marked by the "set" effect (markEffects).
-- Limits: bonus hit counts linearly (not against the cap), and which ring or trinket a candidate
-- replaces ignores sets.

-- A set bonus's worth for this weight set: its simmed value where the set sims have one (phase 129: bonuses no stat
-- covers, data/effects/<CLASS>_sets.lua, attached as weightSet.setBonuses[setID][n] by Data.attachSetBonuses), in
-- place of its stats; else its stats' value.
function Score.setBonusValue(setID, bonus, weightSet)
	local sims = weightSet.setBonuses and weightSet.setBonuses[setID]
	local simmed = sims and sims[bonus.n]
	if type(simmed) == "number" then return simmed end
	return Score.value(bonus.stats, weightSet)
end

-- True when every unscored bonus of the item's set has a simmed value for this weight set.
function setFullySimmed(id, sets, weightSet)
	local setID = sets.ofItem and sets.ofItem[id]
	local set = setID and sets.bySet[setID]
	local sims = set and weightSet.setBonuses and weightSet.setBonuses[setID]
	if not sims then return false end
	for _, bonus in ipairs(set.bonuses or {}) do
		if bonus.unscored and type(sims[bonus.n]) ~= "number" then return false end
	end
	return true
end
Score.setFullySimmed = setFullySimmed

-- Set ID -> pieces among `ids`, each item ID once (two copies of a ring count as one piece).
local function piecesOf(ids, sets)
	local seen, count = {}, {}
	for _, id in ipairs(ids) do
		local set = id and not seen[id] and sets.ofItem[id]
		if set then
			seen[id] = true
			count[set] = (count[set] or 0) + 1
		end
	end
	return count
end

-- What a swap does to your set bonuses: the value it adds (negative when it breaks a bonus) and the
-- sets it changes, by name: { name, size, worn, after, gained = {bonus}, lost = {bonus}, value, id, simmed = { bonus sizes valued by their sim } }.
-- before, after: the item IDs worn before and after.
function Score.setChanges(before, after, sets, weightSet)
	local a, b = piecesOf(before, sets), piecesOf(after, sets)
	local ids = {}
	for id in pairs(a) do ids[id] = true end
	for id in pairs(b) do ids[id] = true end
	local delta, changes = 0, {}
	for setID in pairs(ids) do
		local set, was, now = sets.bySet[setID], a[setID] or 0, b[setID] or 0
		if set and was ~= now then
			local c = { name = set.name, size = #(set.items or {}), worn = was, after = now, gained = {}, lost = {}, value = 0, id = setID, simmed = {} }
			for _, bonus in ipairs(set.bonuses or {}) do
				local v = Score.setBonusValue(setID, bonus, weightSet)
				local sims = weightSet.setBonuses and weightSet.setBonuses[setID]
				local isSim = sims and type(sims[bonus.n]) == "number"
				if now >= bonus.n and was < bonus.n then
					c.gained[#c.gained + 1], c.value = bonus, c.value + v
					if isSim then c.simmed[#c.simmed + 1] = bonus.n end
				elseif was >= bonus.n and now < bonus.n then
					c.lost[#c.lost + 1], c.value = bonus, c.value - v
					if isSim then c.simmed[#c.simmed + 1] = bonus.n end
				end
			end
			if #c.gained + #c.lost > 0 then
				changes[#changes + 1] = c
				delta = delta + c.value
			end
		end
	end
	table.sort(changes, function(x, y) return x.name < y.name end)
	return delta, changes
end

-- Adds the set bonuses a compare() result gains or breaks to its new value (result.setDelta,
-- result.sets) and recomputes its %.
local function applySets(result, candidate, equipped, weightSet, sets)
	if not result or result.status == "equipped" then return result end
	local replaced = {}
	for _, slot in ipairs(result.replaces or {}) do replaced[slot] = true end
	local before, after = {}, {}
	for slot, item in pairs(equipped) do
		before[#before + 1] = item.itemID
		if not replaced[slot] then after[#after + 1] = item.itemID end
	end
	after[#after + 1] = candidate.itemID
	if result.partner then after[#after + 1] = result.partner.itemID end
	local delta, changes = Score.setChanges(before, after, sets, weightSet)
	if #changes == 0 then return result end
	result.sets, result.setDelta = changes, delta
	if delta == 0 then return result end
	result.newValue = result.newValue + delta
	if result.status ~= "empty-slot" then
		if result.status ~= "needs-partner" then result.status = nil end
		result.pct = nil
		finish(result)
	end
	return result
end

-- candidate: { itemID, equipLoc, stats }; equipped: slot ID -> item of the same shape.
-- opts (optional): { bags = {items}, excluded = { equipLoc = true }, dualWield = bool, hand = "main"|"off" }
-- for weapon partners and dual wielding, hit = { player, target } for cap-aware hit (HitCap.pools;
-- without it hit counts linearly), and effects = { [itemID] = "proc"|"equip"|"set" } (the class
-- data's extras: effects SimGear doesn't score; sets result.effectNew and effectWorn, above), and
-- sets = the class's item sets (Data.lua; adds the bonuses a swap gains or breaks: setDelta, sets).
-- Returns { status, pct, newValue, oldValue, replaces, partner, hitCap } or nil if the item has no gear slot.
-- status: "upgrade", "downgrade", "equipped", "empty-slot", "no-baseline", "needs-partner".
function Score.compare(candidate, equipped, weightSet, opts)
	equipped = equipped or {}
	local result = compareLinear(candidate, equipped, weightSet, opts)
	if opts and opts.hit then result = capHit(result, candidate, equipped, weightSet, opts.hit) end
	if opts and opts.sets then result = applySets(result, candidate, equipped, weightSet, opts.sets) end
	-- Curated, measured and placeholder weights aren't exact enough for a decimal (Score.pctText);
	-- simmed ones, and the player's own imported MythicSim weights, are, unless the leveling plan's
	-- survival layer or the player's pins (Plan.lua) are in them.
	local src = weightSet.source or {}
	local kind = src.kind
	if result then
		result.rough = (kind ~= "sim" and kind ~= "imported") or src.pins ~= nil or (ns.Plan ~= nil and ns.Plan.adds(weightSet))
		result.estimate = Score.isPlaceholder(weightSet) or nil
		if opts and opts.effects then markEffects(result, candidate, equipped, opts.effects, weightSet, opts.sets) end
	end
	return result
end

-- The healer sets' weights are hand-picked placeholders (healing can't be simmed yet): their results
-- show a ranking word, not a % (result.estimate; owner 2026-10-28, research/grill-2026-10-28.md Q16).
-- The other curated sets are worked out from the sims and the client data and keep their %.
Score.PLACEHOLDER_LABEL = "placeholder, not derived"
function Score.isPlaceholder(weightSet)
	local src = weightSet and weightSet.source
	return src ~= nil and src.kind == "curated" and src.label == Score.PLACEHOLDER_LABEL
end

-- A compare() result's % as text, without the % sign: one decimal from simmed weights below 10%
-- ("4.2"), a whole number from 10% up ("12") and from any other weights (result.rough: "4"). signed
-- adds + or - ("+4.2", "-4").
-- From 10% up a decimal is false precision ("+12%", not "+12.3%"; owner 2026-10-28, was 100%). 9.95
-- and up would print "10.0" with a decimal, so it is whole too.
Score.WHOLE_FROM = 9.95
function Score.pctText(result, signed)
	local pct = result.pct * 100
	if result.rough or math.abs(pct) >= Score.WHOLE_FROM then
		local whole = math.floor(math.abs(pct) + 0.5)
		if not signed then return string.format("%d", whole) end
		return (pct < 0 and whole > 0 and "-" or "+") .. whole
	end
	if signed then return string.format("%+.1f", pct) end
	return string.format("%.1f", math.abs(pct))
end

function compareLinear(candidate, equipped, weightSet, opts)
	local loc = candidate.equipLoc

	for _, item in pairs(equipped) do
		if sameItem(candidate, item) then
			return { status = "equipped", newValue = itemValue(candidate, weightSet), oldValue = itemValue(item, weightSet) }
		end
	end

	local slot = SINGLE[loc]
	if slot then
		local current = equipped[slot]
		if not current then
			return { status = "empty-slot", replaces = { slot }, newValue = itemValue(candidate, weightSet), oldValue = 0 }
		end
		return finish({ replaces = { slot }, newValue = itemValue(candidate, weightSet), oldValue = itemValue(current, weightSet) })
	end

	local pair = PAIRED[loc]
	if pair then
		local a, b = equipped[pair[1]], equipped[pair[2]]
		local newValue = itemValue(candidate, weightSet)
		if not a or not b then
			return { status = "empty-slot", replaces = { a and pair[2] or pair[1] }, newValue = newValue, oldValue = 0 }
		end
		local va, vb = itemValue(a, weightSet), itemValue(b, weightSet)
		local weaker, weakerValue = pair[1], va
		if vb < va then weaker, weakerValue = pair[2], vb end
		return finish({ replaces = { weaker }, newValue = newValue, oldValue = weakerValue })
	end

	return compareWeapon(candidate, equipped, weightSet, opts or {})
end

-- The set's kind as shown: "curated placeholder" for hand-chosen sets (healers: their label says
-- "placeholder, not derived"), so they don't read like derived curated sets.
function Score.kindText(src)
	local kind = tostring(src.kind or "unknown")
	if src.label and src.label:find("placeholder", 1, true) then kind = kind .. " placeholder" end
	return kind
end

-- "Ret (sim Lv60, engine abc123)", "Holy (curated Lv18-22)" or "Holy (curated placeholder)"; ", for a
-- Human" at the end when the set is adjusted for your race.
local function sourceText(weightSet)
	local src = weightSet.source
	local short = ns.Spec and ns.Spec.SHORT[weightSet.spec] or tostring(weightSet.spec)
	local levels = ""
	if src.minLevel and src.maxLevel then
		levels = src.minLevel == src.maxLevel and string.format(" Lv%d", src.minLevel)
			or string.format(" Lv%d-%d", src.minLevel, src.maxLevel)
	end
	local origin
	if src.kind == "sim" then
		origin = string.format("sim%s, engine %s", levels, tostring(src.engine))
	else
		origin = Score.kindText(src) .. levels
	end
	-- Adjusted for your race (Race.adjust): said next to every number, like the rest of the source.
	if src.raceAdjust then origin = origin .. ", for " .. ns.Race.withArticle(src.raceAdjust.player) end
	-- The leveling plan (Plan.apply): how much survival counts, and how far the handover to the raid
	-- sim has gone; then the stats the player set (Plan.pin).
	local plan = src.plan
	if plan and plan.t < 1 then
		origin = origin .. string.format(", solo %d%%", math.floor(plan.share * 100 + 0.5))
		if plan.t > 0 then origin = origin .. string.format(", raid sim %d%%", math.floor(plan.t * 100 + 0.5)) end
	end
	if src.pins then
		local names = {}
		for i, k in ipairs(src.pins) do names[i] = ns.Advisor and ns.Advisor.STAT_NAME[k] or k end
		origin = origin .. ", edited by you: " .. table.concat(names, ", ")
	end
	return short .. " (" .. origin .. ")"
end
Score.sourceText = sourceText

-- The compact tooltip's grey tag (phase 64): "Ret sim 60", "Ret curated 20-29", "Holy placeholder",
-- "Ret imported", with " edited" for stats the player set (phase 126 C2; was " custom"). Engine, race and plan stay on Shift (sourceText).
function Score.shortSource(weightSet)
	local src = weightSet.source or {}
	local short = ns.Spec and ns.Spec.SHORT[weightSet.spec] or tostring(weightSet.spec)
	local kind = tostring(src.kind or "unknown")
	local levels = ""
	if src.label and src.label:find("placeholder", 1, true) then
		kind = "placeholder"
	elseif src.minLevel and src.maxLevel then
		levels = src.minLevel == src.maxLevel and string.format(" %d", src.minLevel) or string.format(" %d-%d", src.minLevel, src.maxLevel)
	end
	return short .. " " .. kind .. levels .. (src.pins and " edited" or "")
end

-- Formats e.g. "+4.2% Ret (sim Lv18-22, engine abc123)" or "+1.0% Holy (curated Lv18-22)".
-- Returns nil when the result has no percentage.
function Score.label(result, weightSet)
	if not result or not result.pct then return nil end
	-- A placeholder set's result: the source alone, no % (Score.isPlaceholder).
	if result.estimate then return sourceText(weightSet) end
	return string.format("%s%% %s", Score.pctText(result, true), sourceText(weightSet))
end

-- One readable line for any compare() result, always naming the weight source.
function Score.describe(result, weightSet)
	local src = sourceText(weightSet)
	local status = result.status
	if status == "equipped" then
		return string.format(ns.L("Equipped. Score %.1f %s"), result.newValue, src)
	elseif status == "empty-slot" then
		return string.format(ns.L("Fills an empty slot. Score %.1f %s"), result.newValue, src)
	elseif status == "no-baseline" then
		return string.format(ns.L("Equipped item scores 0, so no %%. New score %.1f %s"), result.newValue, src)
	elseif status == "needs-partner" then
		return string.format(ns.L("%s - needs a one-hander and off hand to replace your two-hander"), Score.label(result, weightSet))
	elseif result.partner then
		return string.format(ns.L("%s with %s from your bags (score %.1f vs %.1f)"), Score.label(result, weightSet),
			result.partner.link or ns.L("a partner"), result.newValue, result.oldValue)
	end
	return string.format(ns.L("%s (score %.1f vs %.1f)"), Score.label(result, weightSet), result.newValue, result.oldValue)
end
