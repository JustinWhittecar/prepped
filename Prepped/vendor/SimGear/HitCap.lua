-- HitCap: hit is worth its weight only up to the cap (research/plan-hitcap-2026-10-21.md).
-- Pure: callers pass the player's current hit; no WoW API access.
local _, ns = ...

local HitCap = {}
ns.HitCap = HitCap

-- Hit (percent) that removes every miss, by target level minus player level, from the sim engine's
-- attack tables (MythicSim oct21-release 62b7445d1c, MIT: sim/core/target.go setupAttackTables).
-- Physical: base miss 5 / 5.5 / 6 / 8%, plus 1% hit suppression against +3; weapon skill assumed
-- maxed (5 per level). Spell: base miss 4 / 5 / 6 / 17%, at least 1% always misses. The spell table is
-- the engine's for a level-60 attacker, used by level difference at every level (data/GAPS.md).
HitCap.PHYSICAL = { [0] = 5, [1] = 5.5, [2] = 6, [3] = 9 }
HitCap.SPELL = { [0] = 3, [1] = 4, [2] = 5, [3] = 16 }
-- Dual-wield white swings miss 19% more (engine sim/core/spell_outcome.go GetPhysicalMissChance), so
-- for a dual wielder hit keeps some value up to the physical cap + 19.
HitCap.DUAL_WIELD_EXTRA = 19

-- Options "Hit cap against": the target's level over yours. "auto": a dungeon boss (+2) while
-- leveling, a raid boss (+3) at 60.
HitCap.TARGETS = { same = 0, dungeon = 2, raid = 3 }
HitCap.ORDER = { "auto", "same", "dungeon", "raid" }
HitCap.LABELS = {
	auto = ns.N("a dungeon boss while leveling, a raid boss at 60"),
	same = ns.N("a target of your level"),
	dungeon = ns.N("a dungeon boss (2 levels above you)"),
	raid = ns.N("a raid boss (3 levels above you)"),
}

-- The setting after `target` in ORDER (the Options button cycles through them).
function HitCap.nextTarget(target)
	for i, t in ipairs(HitCap.ORDER) do
		if t == (target or "auto") then return HitCap.ORDER[i % #HitCap.ORDER + 1] end
	end
	return "auto"
end

function HitCap.levelDiff(level, target)
	local d = HitCap.TARGETS[target]
	if d then return d end
	return (level or 0) >= 60 and 3 or 2
end

-- The value of the hit between `from` and `to` percent on one pool: `weight` per 1% up to `cap`,
-- `past` per 1% from there to `pastTo` (dual wielders), nothing beyond.
local function span(from, to, weight, cap, past, pastTo)
	local function seg(lo, hi) return math.max(0, math.min(to, hi) - math.max(from, lo)) end
	local v = weight * seg(-math.huge, cap)
	if past and pastTo then v = v + past * seg(cap, pastTo) end
	return v
end
HitCap.span = span

-- The hit pools a weight set prices, with the player's state: a list of { weight, have, cap, past,
-- pastTo }. Sim sets split hit into its melee and spell parts (hitParts, pipeline/weights/hitcap.go);
-- other sets price their one hit key on its own pool. nil when the set has no hit weight.
-- player = { level, melee, ranged, spell (percent), dualWield, ranged pool for Hunters (rangedPool) }.
function HitCap.pools(weightSet, player, target)
	local w = weightSet.weights
	local key = w.MeleeHit and "MeleeHit" or (w.SpellHit and "SpellHit")
	if not key or w[key] == 0 then return nil end
	local diff = HitCap.levelDiff(player.level, target)
	local physicalHave = player.rangedPool and player.ranged or player.melee
	local function physical(weight)
		local p = { weight = weight, have = physicalHave or 0, cap = HitCap.PHYSICAL[diff] }
		local pc = weightSet.hitPastCap
		if pc and player.dualWield and not player.rangedPool then
			p.past, p.pastTo = pc.MeleeHit, HitCap.PHYSICAL[diff] + HitCap.DUAL_WIELD_EXTRA
		end
		return p
	end
	local function spell(weight)
		return { weight = weight, have = player.spell or 0, cap = HitCap.SPELL[diff] }
	end
	local parts = weightSet.hitParts
	local sum = parts and (parts.MeleeHit or 0) + (parts.SpellHit or 0) or 0
	if sum > 0 then
		-- Scaled to add up to the set's hit weight exactly (the file rounds each to 6 digits).
		local m = w[key] * (parts.MeleeHit or 0) / sum
		return { physical(m), spell(w[key] - m) }, key
	end
	return { key == "MeleeHit" and physical(w[key]) or spell(w[key]) }, key
end

-- What `amount`% of gear hit adds when the gear in question (`removed`% of it) is taken off first:
-- the capped value minus the linear value Score.value already counted (weight x amount).
-- Returns the correction to add, or 0.
function HitCap.correction(pools, key, weightSet, removed, amount)
	if not pools or amount == 0 then return 0 end
	local capped = 0
	for _, p in ipairs(pools) do
		local base = p.have - removed
		capped = capped + span(base, base + amount, p.weight, p.cap, p.past, p.pastTo)
	end
	local fix = capped - weightSet.weights[key] * amount
	-- Under the cap the two agree up to float rounding; report that as no correction.
	if math.abs(fix) <= 1e-9 * math.max(1, math.abs(weightSet.weights[key] * amount)) then return 0 end
	return fix
end

-- Defense cap (phase 61): the bonus Defense over 5 x your level that leaves an attacker `diff` levels
-- above you no crits. Its crit chance is 5% + 0.2% a level, and each Defense point takes 0.04% off
-- (engine-70707 sim/core/target.go and unit.go; Classic's 440 at 60 against a level-63 boss).
function HitCap.defenseCap(diff)
	return 125 + 5 * diff
end

-- The Defense pool of a tank set with defensePastCap (pipeline/weights/defcap.go): { { weight, have, cap,
-- past, pastTo } }, "Defense", in the shape HitCap.correction takes. player.defense is your bonus Defense
-- (Client.defenseBonus). nil when the set has no past-cap value or your Defense is unknown.
function HitCap.defensePools(weightSet, player, target)
	local w, pc = weightSet.weights.Defense, weightSet.defensePastCap
	if not (w and w > 0 and pc and pc.Defense and player and player.defense) then return nil end
	local cap = HitCap.defenseCap(HitCap.levelDiff(player.level, target))
	return { { weight = w, have = player.defense, cap = cap, past = pc.Defense, pastTo = math.huge } }, "Defense"
end

-- The cap the tooltip names: the pool that carries most of the hit weight.
function HitCap.capOf(pools)
	local best
	for _, p in ipairs(pools or {}) do
		if not best or p.weight > best.weight then best = p end
	end
	return best and best.cap
end
