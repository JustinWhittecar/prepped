-- BiS target: the highest-scoring item per inventory slot, scored with SimGear's own Score.
local _, ns = ...
local Bis = {}
ns.Bis = Bis

-- Equip location -> the inventory slots it fills (two for rings and trinkets).
local SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_CLOAK = { 15 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local MAIN_HAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local OFF_HAND = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true }

local LEVEL = 60

-- Whether the player's filters exclude this item. PvP comes from SimGear's own fields;
-- SimGear doesn't mark reputation or profession bind-on-pickup items, so those come from
-- Prepped's lists (tagged.reputation, tagged.profession: {[id] = true}). tagged.unavailable
-- is always excluded.
local function excluded(id, item, filters, tagged)
  -- Not obtainable before raids on Forever, whatever the filters (data/Excluded.lua).
  if tagged and tagged.unavailable and tagged.unavailable[id] then return true end
  if not filters then return false end
  if filters.pvp and (item.pvp or item.pvpRank) then return true end
  for _, kind in ipairs({ "reputation", "profession", "darkmoon" }) do
    if filters[kind] and tagged and tagged[kind] and tagged[kind][id] then return true end
  end
  return false
end

local function value(id, item, weightSet)
  -- SimGear's data has no weapon speeds, so speed adds nothing here (Score.speedValue is 0).
  return ns.Score.value(item.stats, weightSet) + ns.Score.effectOf(id, weightSet)
end

-- The best candidate in `list` other than `notID`.
local function best(list, notID)
  for _, c in ipairs(list) do if c.id ~= notID then return c end end
end

-- Best first; on a tie, an item marked tie (one you wear, for Outfit) comes first.
local function byPoints(a, b)
  if a.points ~= b.points then return a.points > b.points end
  return (a.tie or 0) > (b.tie or 0)
end

-- Slots 16 and 17: the best two-hander against the best main hand + off hand pair.
-- A one-hander goes in the off hand only for a dual wielder, valued as SimGear values an off hand.
local function offHandOf(c, weightSet)
  return { id = c.id, item = c.item, points = value(c.id, ns.Score.inOffHand(c.item), weightSet), locked = c.locked, tie = c.tie }
end

local function pickWeapons(bis, cands, weightSet, dualWield, pin16, pin17)
  -- Your picks: a pinned two-hander fills both hands; a pinned hand keeps the best item for the other.
  if pin16 and pin16.item.slot == "INVTYPE_2HWEAPON" then bis[16] = pin16; return end
  if pin16 or pin17 then
    local mainBest, offBest
    for _, c in ipairs(cands) do
      local loc = c.item.slot
      if not pin16 and MAIN_HAND[loc] and c.id ~= (pin17 and pin17.id) and (not mainBest or c.points > mainBest.points) then mainBest = c end
      if not pin17 and (OFF_HAND[loc] or (dualWield and loc == "INVTYPE_WEAPON")) and c.id ~= (pin16 and pin16.id) then
        local o = offHandOf(c, weightSet)
        if not offBest or o.points > offBest.points then offBest = o end
      end
    end
    bis[16] = pin16 or mainBest
    bis[17] = pin17 and offHandOf(pin17, weightSet) or offBest
    return
  end
  local twoHand, mains, offs = nil, {}, {}
  for _, c in ipairs(cands) do
    local loc = c.item.slot
    if loc == "INVTYPE_2HWEAPON" then
      if not twoHand or byPoints(c, twoHand) then twoHand = c end
    end
    if MAIN_HAND[loc] then mains[#mains + 1] = c end
    if OFF_HAND[loc] or (dualWield and loc == "INVTYPE_WEAPON") then
      offs[#offs + 1] = offHandOf(c, weightSet)
    end
  end
  table.sort(mains, byPoints)
  table.sort(offs, byPoints)
  -- The best pair has either the best main hand or the best off hand in it.
  local main, off, pair = nil, nil, -math.huge
  for _, m in ipairs({ mains[1], offs[1] and best(mains, offs[1].id) }) do
    local o = best(offs, m.id)
    local total = m.points + (o and o.points or 0)
    if total > pair then main, off, pair = m, o, total end
  end
  local mainTie = main and math.max(main.tie or 0, off and off.tie or 0) or 0
  if twoHand and (not main or twoHand.points > pair or (twoHand.points == pair and (twoHand.tie or 0) >= mainTie)) then
    bis[16] = twoHand
  else
    bis[16], bis[17] = main, off
  end
end

-- A set's bonus points with n pieces worn.
function Bis.setBonusAt(set, n)
  local v = 0
  for _, b in ipairs(set.bonuses or {}) do if b.count <= n then v = v + b.points end end
  return v
end

-- A set's pieces among the picks, each item once.
local function piecesIn(bis, set)
  local seen, n = {}, 0
  for slot = 1, 18 do
    local b = bis[slot]
    if b and set.items[b.id] and not seen[b.id] then seen[b.id], n = true, n + 1 end
  end
  return n
end

-- The picks' worth: item points plus every set's bonus at the pieces it has.
local function outfitValue(bis, sets, ids)
  local v = 0
  for slot = 1, 18 do if bis[slot] then v = v + (bis[slot].points or 0) end end
  for _, id in ipairs(ids) do v = v + Bis.setBonusAt(sets[id], piecesIn(bis, sets[id])) end
  return v
end

-- Set bonuses: single slots swap to a set's best piece, cheapest first, as far as the whole
-- outfit (items plus every set's bonuses, so breaking another set counts) gains. The best set's
-- swaps go in first, then the rest are weighed again, until nothing gains. Pairs (rings, trinkets)
-- and weapons count when already set pieces but aren't swapped. Records bis.sets[setID] = { count,
-- points } for each set with a piece in the picks.
local function applySets(bis, ranked, sets)
  bis.sets = {}
  local ids = {}
  for id in pairs(sets or {}) do ids[#ids + 1] = id end
  table.sort(ids, function(x, y) return tostring(x) < tostring(y) end)
  local current = outfitValue(bis, sets, ids)
  for _ = 1, #ids do
    local best
    for _, setID in ipairs(ids) do
      local set, options = sets[setID], {}
      for _, list in pairs(ranked) do
        local slot = #list.slots == 1 and list.slots[1]
        local cur = slot and bis[slot]
        if slot and not (cur and (cur.locked or set.items[cur.id])) then
          for _, c in ipairs(list) do
            if set.items[c.id] then options[#options + 1] = { slot = slot, c = c, loss = (cur and cur.points or 0) - c.points }; break end
          end
        end
      end
      table.sort(options, function(x, y) if x.loss ~= y.loss then return x.loss < y.loss end return x.slot < y.slot end)
      local saved = {}
      for j, o in ipairs(options) do
        saved[j] = bis[o.slot]
        bis[o.slot] = o.c
        local v = outfitValue(bis, sets, ids)
        if v > (best and best.value or current) + 1e-9 then best = { value = v, options = options, n = j } end
      end
      for j = #options, 1, -1 do bis[options[j].slot] = saved[j] end
    end
    if not best then break end
    for j = 1, best.n do bis[best.options[j].slot] = best.options[j].c end
    current = best.value
  end
  for _, setID in ipairs(ids) do
    local n = piecesIn(bis, sets[setID])
    if n > 0 then bis.sets[setID] = { count = n, points = Bis.setBonusAt(sets[setID], n) } end
  end
end

-- Candidates ranked per group of slots (chest and robe share slot 5, so grouped by the slot list),
-- and the weapons, from the items the filters allow. opts.owned: the items are ones you have, so
-- no source is needed and no filter applies.
local function rank(opts)
  local ranked, weapons = {}, {}
  for id, item in pairs(opts.items) do
    -- No known source: a test item, unreleased raid loot or a Forever item not yet found in game.
    local known = opts.owned or (type(item.sources) == "table" and #item.sources > 0)
    if known and (item.req or 0) <= LEVEL and (opts.owned or not excluded(id, item, opts.filters, opts.tagged)) then
      local c = { id = id, item = item, points = value(id, item, opts.weightSet), tie = opts.prefer and opts.prefer[id] and 1 or nil }
      local slots = SLOTS[item.slot]
      if slots then
        local list = ranked[slots[1]] or { slots = slots }
        ranked[slots[1]] = list
        list[#list + 1] = c
      elseif item.slot == "INVTYPE_2HWEAPON" or MAIN_HAND[item.slot] or OFF_HAND[item.slot] then
        weapons[#weapons + 1] = c
      end
    end
  end
  for _, list in pairs(ranked) do table.sort(list, byPoints) end
  return ranked, weapons
end

-- Whether an item can go in an inventory slot (a one-hander in the off hand only for a dual wielder).
function Bis.fits(item, inv, dualWield)
  local loc = item.slot
  if inv == 16 then return loc == "INVTYPE_2HWEAPON" or MAIN_HAND[loc] or false end
  if inv == 17 then return OFF_HAND[loc] or (dualWield and loc == "INVTYPE_WEAPON") or false end
  for _, s in ipairs(SLOTS[loc] or {}) do if s == inv then return true end end
  return false
end

local fits = Bis.fits

-- opts.locked ({[inv] = id}): your picks, as candidates marked locked. Any item in opts.items that
-- fits the slot counts, filtered or not (you chose it); anything else is ignored.
local function pins(opts)
  local out = {}
  for inv, id in pairs(opts.locked or {}) do
    local item = opts.items[id]
    if item and fits(item, inv, opts.dualWield) then
      out[inv] = { id = id, item = item, points = value(id, item, opts.weightSet), locked = true }
    end
  end
  return out
end

-- The choices for one inventory slot, best first: what the filters allow, for the pick menu.
-- The main hand lists two-handers too; the off hand is valued as an off hand.
function Bis.candidates(opts, inv)
  local ranked, weapons = rank(opts)
  local out = {}
  if inv == 16 or inv == 17 then
    for _, c in ipairs(weapons) do
      if fits(c.item, inv, opts.dualWield) then out[#out + 1] = inv == 17 and offHandOf(c, opts.weightSet) or c end
    end
    table.sort(out, byPoints)
    return out
  end
  for _, list in pairs(ranked) do
    for _, s in ipairs(list.slots) do
      if s == inv then for i, c in ipairs(list) do out[i] = c end end
    end
  end
  return out
end

-- opts: items ({[id] = SimGear item}), weightSet, filters ({pvp, reputation, profession, darkmoon}), tagged,
-- dualWield (the class can use a one-hander in the off hand), unique ({[id] = group}: one per group),
-- locked ({[inv] = id}: your picks, which take the slot), owned (the items are what you have: no source
-- or filter checks), prefer ({[id] = true}: wins a tie, e.g. what you wear), sets ({[setID] = {items = {[id] = true},
-- bonuses = {{count, points}}}}: bonuses in the spec's points).
-- Returns {[inventory slot] = { id, item, points }}, plus sets = {[setID] = {count, points}}.
function Bis.pick(opts)
  local ranked, weapons = rank(opts)
  local pinned = pins(opts)
  local bis = {}
  for _, list in pairs(ranked) do
    -- A pair of slots takes items of different names (one quest chain gives the same-named
    -- ring at each step, and only one of them can be held) and one item per unique-equipped group.
    -- Pinned slots are filled first and count as taken.
    local taken, open = {}, {}
    local function take(slot, c)
      bis[slot], taken[c.item.name or c.id], taken[c.id] = c, true, true
      local group = opts.unique and opts.unique[c.id]
      if group then taken["unique:" .. group] = true end
    end
    for _, slot in ipairs(list.slots) do
      if pinned[slot] then take(slot, pinned[slot]) else open[#open + 1] = slot end
    end
    local i = 1
    for _, c in ipairs(list) do
      local slot = open[i]
      if not slot then break end
      local group = opts.unique and opts.unique[c.id]
      if not taken[c.id] and not taken[c.item.name or c.id] and not (group and taken["unique:" .. group]) then
        take(slot, c)
        i = i + 1
      end
    end
  end
  -- A pinned slot with no other candidates in its group (a filtered-out item, say).
  for inv, c in pairs(pinned) do if inv ~= 16 and inv ~= 17 then bis[inv] = c end end
  pickWeapons(bis, weapons, opts.weightSet, opts.dualWield, pinned[16], pinned[17])
  applySets(bis, ranked, opts.sets)
  return bis
end
