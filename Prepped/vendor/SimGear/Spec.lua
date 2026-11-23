-- Spec: infers the spec from talent points per tree, with a manual override. Per-class trees and
-- names come from Classes.lua; a nil class means Paladin.
-- Pure: talent points are gathered by Client.lua.
local _, ns = ...

local Spec = {}
ns.Spec = Spec

-- Paladin's trees (kept for callers that predate other classes).
Spec.TREES = ns.Classes.PALADIN.trees

-- Short and long names of every spec of every class (spec keys are shared where names match).
Spec.SHORT, Spec.NAME = {}, {}
for _, token in ipairs(ns.Classes.ORDER) do
	local c = ns.Classes[token]
	for k, v in pairs(c.short) do Spec.SHORT[k] = v end
	for k, v in pairs(c.long) do Spec.NAME[k] = v end
end

-- The class's trees, left to right, or an empty list for a class without data.
function Spec.treesOf(class)
	local c = ns.Classes.get(class)
	return c and c.trees or {}
end

-- The class's specs: its trees, unless one tree holds several roles (Druid Feral: Cat and Bear).
function Spec.specsOf(class)
	local c = ns.Classes.get(class)
	return c and (c.specs or c.trees) or {}
end

-- Atlas suffix for a spec's art (talents-background-<class>-<suffix>).
function Spec.art(spec, class)
	local c = ns.Classes.get(class)
	return c and c.art and c.art[spec] or (spec and spec:lower())
end

-- The spec a tree means for this character: the tree itself, or for a tree with several roles the
-- one its form allows (ctx.forms = { cat = true } once Cat Form is available).
function Spec.resolveTree(tree, class, ctx)
	local c = ns.Classes.get(class)
	local rule = c and c.treeSpecs and c.treeSpecs[tree]
	if not rule then return tree end
	local forms = ctx and ctx.forms
	return forms and forms[rule.form] and rule.with or rule.without
end

-- Returns the excluded equip locations (loc -> true) and the reason, or nil for specs without rules.
function Spec.gearRule(spec, class)
	local c = ns.Classes.get(class)
	local rule = c and c.gearRules[spec]
	if not rule and class == nil then
		for _, token in ipairs(ns.Classes.ORDER) do rule = rule or ns.Classes[token].gearRules[spec] end
	end
	if rule then return rule.excluded, rule.reason end
end

-- True when the spec fights with a weapon in each hand (once the character knows Dual Wield).
function Spec.dualWields(spec, class)
	local c = ns.Classes.get(class)
	return c ~= nil and c.dualWield[spec] == true
end

-- True when the spec can hold a weapon in each hand at `level`: Dual Wield is known (`known`), or `level`
-- is a later level than `ownLevel` (a preview) at or past the class trainer's level (Classes
-- dualWieldFrom). A class without one (Shaman: not from the trainer) needs the spell known. The
-- baseline view of another class passes ownLevel 0.
function Spec.canDualWield(spec, class, known, level, ownLevel)
	if not Spec.dualWields(spec, class) then return false end
	if known then return true end
	local from = ns.Classes.get(class).dualWieldFrom
	return from ~= nil and level > ownLevel and level >= from
end

-- Forever puts all three trees on one talent canvas, side by side. Left edge (posX) of each
-- tree, the same for every class. Source: client 1.60.1 TraitNode data (vendor/engine/docs/
-- talent-check-2026-09-17.md); Holy/Prot/Ret order confirmed in game 2026-10-16.
Spec.TREE_X = { 1020, 5020, 9080 }
local X_SLACK = 100     -- nodes can sit slightly left of their tree's edge (e.g. 5030 vs 5020)
local CANVAS_MAX_X = 11000 -- some client nodes carry a stray extra zero; scale those back

-- nodes: list of { posX = n, ranks = n } for the class talent tree.
-- Returns { <tree> = points spent } for the class's three trees.
function Spec.pointsFromNodes(nodes, class)
	local trees = Spec.treesOf(class)
	local points = {}
	for _, tree in ipairs(trees) do points[tree] = 0 end
	for _, node in ipairs(nodes or {}) do
		local x, ranks = node.posX, node.ranks or 0
		if x and ranks > 0 then
			if x > CANVAS_MAX_X then x = x / 10 end
			local tree
			for i, left in ipairs(Spec.TREE_X) do
				if x >= left - X_SLACK then tree = trees[i] end
			end
			if tree then points[tree] = points[tree] + ranks end
		end
	end
	return points
end

-- points: { <tree> = n }; override: a spec name or nil; ctx: { forms = {...} } (Spec.resolveTree).
-- Returns spec, reason. reason is "override", "talents", "no-talents" or "tie". An override for
-- another class's spec is ignored.
function Spec.infer(points, override, class, ctx)
	local trees = Spec.treesOf(class)
	for _, spec in ipairs(Spec.specsOf(class)) do
		if override == spec then return override, "override" end
	end
	points = points or {}
	local best, bestPoints, tie, total = nil, 0, false, 0
	for _, tree in ipairs(trees) do
		local n = points[tree] or 0
		total = total + n
		if n > bestPoints then
			best, bestPoints, tie = tree, n, false
		elseif n == bestPoints and n > 0 then
			tie = true
		end
	end
	if total == 0 then return nil, "no-talents" end
	if tie then return nil, "tie" end
	return Spec.resolveTree(best, class, ctx), "talents"
end

-- The talent tree a spec belongs to: Feral for Cat and Bear (treeSpecs), Survival for Survival
-- (melee), Discipline for Smite (specTree); every other spec is its own tree.
function Spec.treeOf(spec, class)
	local c = ns.Classes.get(class)
	if not (c and spec) then return spec end
	if c.specTree and c.specTree[spec] then return c.specTree[spec] end
	for tree, rule in pairs(c.treeSpecs or {}) do
		if rule.with == spec or rule.without == spec then return tree end
	end
	return spec
end

-- The spec tooltips, arrows, quest ticks and loot rolls score for. pick: the spec picked in the panel
-- or with /sgf spec (charDB().specOverride), or nil; followPick: the "Tooltips use the spec you pick"
-- option. Returns spec, reason, browsing:
--   followPick and a pick: the pick ("override"), as before 2026-10-23.
--   a pick on the tree your talents point to (Cat or Bear on Feral, Smite on Discipline, Survival
--   (melee) on Survival): the pick ("refined"), so those keep working without the option.
--   a pick of another tree: your talents ("talents"); browsing = the pick, which shows in the panel only.
--   no talent points yet, or tied trees: the pick when there is one ("override"), else nil as Spec.infer.
function Spec.scoring(points, pick, followPick, class, ctx)
	local valid = false
	for _, spec in ipairs(Spec.specsOf(class)) do
		if pick == spec then valid = true end
	end
	if not valid then pick = nil end
	if pick and followPick then return pick, "override" end
	local spec, reason = Spec.infer(points, nil, class, ctx)
	if not spec then
		if pick then return pick, "override" end
		return nil, reason
	end
	if not pick or pick == spec then return spec, pick and "override" or reason end
	if Spec.treeOf(pick, class) == Spec.treeOf(spec, class) then return pick, "refined" end
	return spec, reason, pick
end

-- Parses a /sgf spec argument. Returns ok, value: value is a tree name, or false for "auto"
-- (clear the override). ok is false for unrecognised input.
function Spec.parseOverride(arg, class)
	arg = arg and arg:lower():match("^%s*(.-)%s*$") or ""
	if arg == "auto" then return true, false end
	local c = ns.Classes.get(class)
	local tree = c and c.aliases[arg]
	if tree then return true, tree end
	return false
end

-- Off-specs (phase 126 C1): charDB().offSpec holds none (nil), one spec (a string, as before) or several
-- (a list, in the class's spec order). Pure: the list of them, leaving out main (your scored spec) and
-- repeats.
function Spec.offSpecList(value, main)
	local raw = type(value) == "string" and { value } or (type(value) == "table" and value or {})
	local out, seen = {}, {}
	for _, spec in ipairs(raw) do
		if type(spec) == "string" and spec ~= main and not seen[spec] then
			seen[spec] = true
			out[#out + 1] = spec
		end
	end
	return out
end

-- Pure: the value to save for a list: nil, a string, or the list in the class's spec order.
function Spec.offSpecValue(list, class)
	local on = {}
	for _, spec in ipairs(list or {}) do on[spec] = true end
	local out = {}
	for _, spec in ipairs(Spec.specsOf(class)) do
		if on[spec] then out[#out + 1] = spec end
	end
	if #out == 0 then return nil end
	if #out == 1 then return out[1] end
	return out
end

-- Pure: /sgf offspec <spec>: adds it, or takes it out when it's there already. Returns the new value.
function Spec.toggleOffSpec(value, spec, class)
	local list, found = {}, false
	for _, s in ipairs(Spec.offSpecList(value)) do
		if s == spec then found = true else list[#list + 1] = s end
	end
	if not found then list[#list + 1] = spec end
	return Spec.offSpecValue(list, class)
end

-- The off-specs after current for the Options button: none, each of the class's other specs alone in
-- order, then all of them (when there are two or more), then none again.
function Spec.nextOffSpec(current, class, main)
	local list = {}
	for _, spec in ipairs(Spec.specsOf(class)) do
		if spec ~= main then list[#list + 1] = spec end
	end
	local now = Spec.offSpecList(current, main)
	if #now == 0 then return current == nil and list[1] or nil end -- a saved one now your main spec: none
	if #now == 1 then
		for i, spec in ipairs(list) do
			if spec == now[1] then
				if list[i + 1] then return list[i + 1] end
				return #list >= 2 and Spec.offSpecValue(list, class) or nil
			end
		end
	end
	return nil
end

-- Pure: "Prot, Holy" for messages and reports, or nil for none.
function Spec.offSpecNames(value, main)
	local names = {}
	for _, spec in ipairs(Spec.offSpecList(value, main)) do names[#names + 1] = Spec.SHORT[spec] or spec end
	return #names > 0 and table.concat(names, ", ") or nil
end

-- "holy|prot|ret" for a class's /sgf spec usage line.
function Spec.usage(class)
	local parts = {}
	local c = ns.Classes.get(class)
	for _, spec in ipairs(Spec.specsOf(class)) do parts[#parts + 1] = (c.short[spec] or spec):lower() end
	return table.concat(parts, "|")
end
