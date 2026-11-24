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

local function byPoints(a, b) return a.points > b.points end

-- Slots 16 and 17: the best two-hander against the best main hand + off hand pair.
-- A one-hander goes in the off hand only for a dual wielder, valued as SimGear values an off hand.
local function pickWeapons(bis, cands, weightSet, dualWield)
  local twoHand, mains, offs = nil, {}, {}
  for _, c in ipairs(cands) do
    local loc = c.item.slot
    if loc == "INVTYPE_2HWEAPON" then
      if not twoHand or c.points > twoHand.points then twoHand = c end
    end
    if MAIN_HAND[loc] then mains[#mains + 1] = c end
    if OFF_HAND[loc] or (dualWield and loc == "INVTYPE_WEAPON") then
      offs[#offs + 1] = { id = c.id, item = c.item, points = value(c.id, ns.Score.inOffHand(c.item), weightSet) }
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
  if twoHand and (not main or twoHand.points >= pair) then
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

-- Set bonuses: per set, swap single slots to its best piece, cheapest swap first, as far as the
-- bonuses gained outweigh the points lost. Pairs (rings, trinkets) and weapons count when already
-- set pieces but aren't swapped. Records bis.sets[setID] = { count, points }.
local function applySets(bis, ranked, sets)
  bis.sets = {}
  for setID, set in pairs(sets or {}) do
    local have, options = 0, {}
    for _, list in pairs(ranked) do
      if #list.slots == 1 then
        local slot, cur = list.slots[1], bis[list.slots[1]]
        if cur and set.items[cur.id] then
          have = have + 1
        else
          for _, c in ipairs(list) do
            if set.items[c.id] then options[#options + 1] = { slot = slot, c = c, loss = (cur and cur.points or 0) - c.points }; break end
          end
        end
      else
        for _, slot in ipairs(list.slots) do if bis[slot] and set.items[bis[slot].id] then have = have + 1 end end
      end
    end
    for _, slot in ipairs({ 16, 17 }) do if bis[slot] and set.items[bis[slot].id] then have = have + 1 end end
    table.sort(options, function(a, b) return a.loss < b.loss end)
    local bestN, bestValue, lost = 0, Bis.setBonusAt(set, have), 0
    for j, o in ipairs(options) do
      lost = lost + o.loss
      local v = Bis.setBonusAt(set, have + j) - lost
      if v > bestValue then bestN, bestValue = j, v end
    end
    for j = 1, bestN do bis[options[j].slot] = options[j].c end
    bis.sets[setID] = { count = have + bestN, points = Bis.setBonusAt(set, have + bestN) }
  end
end

-- opts: items ({[id] = SimGear item}), weightSet, filters ({pvp, reputation, profession, darkmoon}), tagged,
-- dualWield (the class can use a one-hander in the off hand), sets ({[setID] = {items = {[id] = true},
-- bonuses = {{count, points}}}}: bonuses in the spec's points).
-- Returns {[inventory slot] = { id, item, points }}, plus sets = {[setID] = {count, points}}.
function Bis.pick(opts)
  -- Rank candidates per group of slots (chest and robe share slot 5, so group by the slot list).
  local ranked, weapons = {}, {}
  for id, item in pairs(opts.items) do
    -- No known source: a test item, unreleased raid loot or a Forever item not yet found in game.
    local known = type(item.sources) == "table" and #item.sources > 0
    if known and (item.req or 0) <= LEVEL and not excluded(id, item, opts.filters, opts.tagged) then
      local c = { id = id, item = item, points = value(id, item, opts.weightSet) }
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
  local bis = {}
  for _, list in pairs(ranked) do
    table.sort(list, byPoints)
    -- A pair of slots takes items of different names: one quest chain gives the same-named
    -- ring at each step, and only one of them can be held.
    local taken, i = {}, 1
    for _, c in ipairs(list) do
      local slot = list.slots[i]
      if not slot then break end
      if not taken[c.item.name or c.id] then
        bis[slot], taken[c.item.name or c.id], i = c, true, i + 1
      end
    end
  end
  pickWeapons(bis, weapons, opts.weightSet, opts.dualWield)
  applySets(bis, ranked, opts.sets)
  return bis
end
