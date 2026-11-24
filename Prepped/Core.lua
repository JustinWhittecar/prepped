-- Core: reads the game (gear, bags, talents, quests, buffs), feeds the tested modules
-- (SimGear, Bis, Consumables, Readiness, Attune, Tracker, Buffs) and hands the UI one view.
-- Everything here touches WoW's API; the logic it calls is pure and tested.
local ADDON, ns = ...
local Core = {}
ns.Core = Core
_G.Prepped = ns -- for /dump while testing

local LEVEL = 60
local P = "|cff33ccffPrepped:|r "
function Core.print(msg) print(P .. msg) end

-- Saved settings --------------------------------------------------------------------------------
local DB_DEFAULTS = { showTracker = true, scale = 1, buffsRaid = true, buffsDungeon = false, tooltip = true }
local CHAR_DEFAULTS = { collapsed = true, raidHours = 3 }

local function defaults(t, d)
  for k, v in pairs(d) do if t[k] == nil then t[k] = v end end
end

local function initDB()
  PreppedDB = PreppedDB or {}
  PreppedCharDB = PreppedCharDB or {}
  ns.db, ns.cdb = PreppedDB, PreppedCharDB
  defaults(ns.db, DB_DEFAULTS)
  defaults(ns.cdb, CHAR_DEFAULTS)
  ns.cdb.groupSpec = ns.cdb.groupSpec or {} -- talent group -> SimGear spec, chosen or confirmed
  ns.cdb.filters = ns.cdb.filters or {}     -- off by default, but for unconfirmed consumables
  -- Consumables nobody has confirmed on Forever (Jujus) stay out of the defaults until the player says.
  if ns.cdb.filters.unconfirmed == nil then ns.cdb.filters.unconfirmed = true end
  ns.cdb.consumables = ns.cdb.consumables or {} -- [spec][slot] = item ID or "none"
  ns.cdb.weights = ns.cdb.weights or {} -- [spec] = "simgear" (nil), a preset id or "custom"
  ns.cdb.customWeights = ns.cdb.customWeights or {} -- [spec] = { [stat] = AP units }
  -- Moving from Raid Ready: its talent-group choices, once.
  local rr = _G.RaidReadyCharDB
  if not ns.cdb.importedRaidReady and type(rr) == "table" and type(rr.groupSpec) == "table" then
    local map = { cat = "FERAL_CAT", bear = "FERAL_BEAR" }
    for g, s in pairs(rr.groupSpec) do
      if map[s] and not ns.cdb.groupSpec[g] then ns.cdb.groupSpec[g] = map[s] end
    end
    ns.cdb.importedRaidReady = true
  end
end

-- Class data --------------------------------------------------------------------------------------
local function classToken() return select(2, UnitClass("player")) end
local function classAddon(token) return "SimGearForever_" .. token:sub(1, 1) .. token:sub(2):lower() end

local data, dataProblem
-- SimGear's class data, loading its LoadOnDemand addon if nothing has yet. Returns data or nil, reason.
-- SimGear's items plus the Forever items it can't see (ForeverItems.lua): those Prepped keeps in
-- data/ForeverItems.lua and those harvested on this account (/prep harvest), the harvest winning.
-- A new table, so SimGear's own stays untouched.
function Core.withForeverItems(items, token)
  local records = {}
  for id, r in pairs(ns.ForeverItemData or {}) do records[id] = r end
  local h = ns.db and ns.db.harvest
  for id, r in pairs(h and h.records or {}) do records[id] = r end
  -- The class's tier 0.5 sets: which items belong and the bonus lines, for Bis.pick's set pass.
  Core.foreverSets = {}
  for id, r in pairs(records) do
    if r.set and r.classes and r.classes[token] then
      local set = Core.foreverSets[r.set.id] or { name = r.set.name, items = {}, lines = r.set.bonuses or {} }
      set.items[id] = true
      if #(r.set.bonuses or {}) > #set.lines then set.lines = r.set.bonuses end
      Core.foreverSets[r.set.id] = set
    end
  end
  local extra = ns.ForeverItems.forClass(records, token, items, function(raw, loc)
    return ns.Stats.addWeaponDps((ns.Stats.normalize(raw)), loc)
  end)
  local out = items
  if next(extra) then
    out = {}
    for id, item in pairs(items) do out[id] = item end
    for id, item in pairs(extra) do out[id] = item end
  end
  Core.foreverCount = 0
  for _ in pairs(extra) do Core.foreverCount = Core.foreverCount + 1 end
  -- Sources SimGear lacks: captured vendor stock, then this account's captures, then the hand-kept list.
  local sources = {}
  for id, src in pairs(ns.VendorSources or {}) do sources[id] = src end
  for _, v in pairs(ns.db and ns.db.vendors or {}) do
    for id, cost in pairs(v.items or {}) do sources[id] = { kind = "vendor", text = v.name .. ", " .. (v.zone or "?") .. " · " .. cost } end
  end
  for id, src in pairs(ns.ExtraSources or {}) do sources[id] = src end
  return ns.ForeverItems.addSources(out, sources)
end

-- Loads a LoadOnDemand addon unless `global` already has the class. Returns the global, and why the
-- load failed if it did (DISABLED, MISSING...).
local function loadFor(addon, globalName, token)
  local why
  if not (type(_G[globalName]) == "table" and _G[globalName][token]) and C_AddOns and C_AddOns.LoadAddOn then
    local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, addon)
    if ok and not loaded and reason then why = addon .. ": " .. tostring(reason) end
  end
  return _G[globalName], why
end

function Core.data()
  if data or dataProblem then return data, dataProblem end
  local token = classToken()
  -- SimGear's data read live; Prepped's snapshot (PreppedBackup_<Class>) only when that fails.
  local d, why = ns.Backup.choose(token,
    function() return loadFor(classAddon(token), "SimGearForeverData", token) end,
    function() return loadFor("PreppedBackup_" .. token:sub(1, 1) .. token:sub(2):lower(), "PreppedBackupData", token) end,
    ns.SimGear.load)
  if d then
    data, dataProblem = d, nil
    data.items = Core.withForeverItems(d.items, token)
    -- Reputation items: SimGear's reps give the faction and standing (a source where it has none),
    -- the other side's factions and quests are never targets, and crafts from reputation recipes that bind
    -- on pickup join the reputation filter.
    local side = UnitFactionGroup and UnitFactionGroup("player")
    local rep = ns.SimGear.repItems(d.reps, d.factions, side)
    for id in pairs(ns.SimGear.otherSide(data.items, side)) do rep.wrongSide[id] = true end
    data.items = ns.ForeverItems.addSources(data.items, rep.sources)
    local tagged = {}
    for id, f in pairs(ns.Lists.reputation or {}) do tagged[id] = f end
    for id, f in pairs(rep.tagged) do tagged[id] = f end
    for id, f in pairs(ns.SimGear.repCrafts(data.items, d.reps, d.tradable, ns.Lists.reputation)) do tagged[id] = f end
    data.repTagged, data.wrongSide = tagged, rep.wrongSide
    -- Crafts that bind on pickup: cMaNGOS's list plus Forever's own crafts SimGear marks BoP.
    local prof = {}
    for id in pairs(ns.Lists.profession or {}) do prof[id] = true end
    for id in pairs(ns.SimGear.bopCrafts(data.items, d.tradable)) do prof[id] = true end
    data.profTagged = prof
  else
    dataProblem = why
  end
  return data, dataProblem
end

-- Items Forever doesn't offer before raids, whatever the filters: the generated raid-only list and
-- the hand-kept exclusions.
local unavailable
local function unavailableItems()
  if unavailable then return unavailable end
  unavailable = {}
  for id in pairs(ns.Lists.raidOnly or {}) do unavailable[id] = true end
  for id in pairs(ns.Excluded or {}) do unavailable[id] = true end
  local d = Core.data()
  for id in pairs(d and d.wrongSide or {}) do unavailable[id] = true end
  for id in pairs(d and ns.SimGear.dropsOnlyFrom(d.items, ns.WorldBosses or {}) or {}) do unavailable[id] = true end
  for id in pairs(d and ns.SimGear.dropsOnlyFrom(d.items, ns.AbyssalCouncil or {}) or {}) do unavailable[id] = true end
  for id in pairs(d and ns.SimGear.cmangosQuestOnly(d.items) or {}) do unavailable[id] = true end
  return unavailable
end

-- Enchant recipes whose formula only drops in a raid aren't targets. Prepped's own copy of the
-- enchant table is filtered once; the full list stays for reading what you wear.
local enchantByID
local function prepareEnchants()
  if enchantByID then return end
  enchantByID = {}
  local all, keep = ns.EnchantData.rows, {}
  for _, r in ipairs(all) do
    enchantByID[r.enchant] = enchantByID[r.enchant] or r
    if not (r.formula and unavailableItems()[r.formula.item]) then keep[#keep + 1] = r end
  end
  ns.EnchantData.rows = keep
end

-- Spec ----------------------------------------------------------------------------------------------
function Core.talentGroup()
  local f = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup
  local ok, n = pcall(function() return f and f() end)
  return ok and type(n) == "number" and n or 1
end

local function knows(spell) return IsPlayerSpell and IsPlayerSpell(spell) == true end

-- Talent points per tree, as SimGear reads them (C_Traits; Forever has no GetTalentTabInfo).
local function talentPoints()
  if not (C_ClassTalents and C_Traits) then return nil end
  local configID = C_ClassTalents.GetActiveConfigID()
  local config = configID and C_Traits.GetConfigInfo(configID)
  local treeID = config and config.treeIDs and config.treeIDs[1]
  if not treeID then return nil end
  local nodes = {}
  for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
    local info = C_Traits.GetNodeInfo(configID, nodeID)
    if info then nodes[#nodes + 1] = { posX = info.posX, ranks = info.ranksPurchased } end
  end
  return ns.Spec.pointsFromNodes(nodes, classToken())
end

-- The spec scored now, and the choices to offer when talents don't settle it (nil when they do).
-- A tree with two roles (Feral: Cat and Bear) always asks once per talent group.
function Core.spec()
  local token, group = classToken(), Core.talentGroup()
  local chosen = ns.cdb.groupSpec[group]
  local okPoints, points = pcall(talentPoints)
  local detected, reason = ns.Spec.infer(okPoints and points or nil, nil, token, { forms = { cat = knows(768) } })
  if chosen then return chosen, nil, "chosen" end
  local c = ns.Classes.get(token)
  local tree = detected and ns.Spec.treeOf(detected, token)
  local rule = c and c.treeSpecs and tree and c.treeSpecs[tree]
  local options = {}
  if rule then
    options = { rule.with, rule.without }
  elseif not detected then
    for _, s in ipairs(ns.Spec.specsOf(token)) do if not (c.specTree and c.specTree[s]) then options[#options + 1] = s end end
  end
  local choices
  if #options > 0 then
    choices = {}
    for i, s in ipairs(options) do choices[i] = { label = ns.Spec.SHORT[s] or s, spec = s } end
  end
  return detected or (options[1]), choices, reason
end

function Core.setSpec(spec, group)
  ns.cdb.groupSpec[group or Core.talentGroup()] = spec
  Core.changed()
end

-- The weight-set key: a Shaman that can dual-wield scores Enhancement on the dual-wield sim.
local function setKey(spec, token)
  local c = ns.Classes.get(token)
  local dw = c and c.dualWieldSets and c.dualWieldSets[spec]
  if dw and knows(674) then return dw end
  return spec
end

-- SimGear's level-60 weight set for a spec, with its simmed item effects layered on without
-- writing into SimGear's tables (a proxy whose `effects` merges both).
local setCache = {}
local function weightSet(spec)
  local d = Core.data()
  if not d then return nil end
  local token = classToken()
  local key = setKey(spec, token)
  local choice = ns.cdb.weights[spec] or "simgear"
  local id = key .. ":" .. choice
  if setCache[id] ~= nil then return setCache[id] or nil end
  local raw = d.specs[key] and ns.Score.pickSet(d.specs[key], LEVEL)
  if not raw then setCache[id] = false; return nil end
  local src = raw.source
  local byLevel = src.kind == "sim" and type(d.itemEffects) == "table" and d.itemEffects[src.maxLevel]
  local sims = type(byLevel) == "table" and byLevel[raw.spec or key]
  local effects = {}
  for eid, v in pairs(raw.effects or {}) do effects[eid] = v end
  if type(sims) == "table" then
    for eid, e in pairs(sims) do
      if type(e) == "table" and type(e.v) == "number" and effects[eid] == nil then effects[eid] = e.v end
    end
  end
  local ws = setmetatable({}, { __index = raw })
  -- Weights the player chose (a preset or Custom, in AP units) replace SimGear's, scaled to its
  -- points so its simmed trinkets and set bonuses keep their worth (data/Weights.lua).
  local chosen = ns.Weights.resolve(choice, spec, ns.WeightPresets, ns.cdb.customWeights, raw.weights or {})
  if chosen then
    ws.weights = ns.Weights.scaled(chosen.weights, raw.weights or {})
    ws.source = { kind = "chosen", name = chosen.name, maxLevel = raw.source.maxLevel, from = raw.source }
  end
  -- Prepped's overrides fill what SimGear doesn't value (data/Overrides.lua).
  ws.effects = ns.Effects.merge(effects, ns.EffectOverrides, spec, ws.weights, d.items,
    function(stats) return ns.Score.value(stats, ws) end)
  setCache[id] = { ws = ws, raw = raw, key = key, id = id, weights = chosen }
  return setCache[id]
end
Core.weightSetFor = weightSet

-- Gear ------------------------------------------------------------------------------------------------
local GetItemStatsFn = (C_Item and C_Item.GetItemStats) or GetItemStats
local function itemCount(id, bank) return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, bank)) or 0 end

-- A worn item as SimGear scores it: SimGear's own record by ID, or the game's stat reader for a
-- random-suffix roll or an item SimGear doesn't have. nil when there's nothing in the slot.
local function wornItem(inv, items)
  local link = GetInventoryItemLink("player", inv)
  if not link then return nil end
  local id = GetInventoryItemID("player", inv)
  local item = items[id]
  if item and not ns.Stats.linkSuffix(link) then return { id = id, item = item, link = link } end
  local raw = GetItemStatsFn and GetItemStatsFn(link)
  local _, _, _, loc = C_Item.GetItemInfoInstant(link)
  if not raw then return { id = id, link = link, unread = true } end
  local stats = ns.Stats.addWeaponDps((ns.Stats.normalize(raw)), loc)
  return { id = id, link = link, item = { name = C_Item.GetItemNameByID(id), slot = loc, stats = stats } }
end

local function points(id, item, ws)
  if not item then return 0 end
  return ns.Score.value(item.stats, ws) + ns.Score.effectOf(id, ws)
end

-- The items a spec can be given: its class data less the equip locations it never uses (gear rules).
local itemsCache = {}
local function itemsFor(spec)
  if itemsCache[spec] then return itemsCache[spec] end
  local d = Core.data()
  local excluded = ns.Spec.gearRule(spec, classToken())
  local out = d.items
  if excluded then
    out = {}
    for id, item in pairs(d.items) do if not excluded[item.slot] then out[id] = item end end
  end
  itemsCache[spec] = out
  return out
end

local bisCache = {}

-- After a harvest: rebuild the item list and every BiS from it.
function Core.resetItems()
  data, dataProblem, unavailable = nil, nil, nil
  for k in pairs(itemsCache) do itemsCache[k] = nil end
  for k in pairs(bisCache) do bisCache[k] = nil end
end
-- The item sets BiS and gear points count for a weight set: SimGear's (its stats and simmed
-- bonuses), then Forever's harvested ones (data/Overrides.lua borrows SimGear's sims for their procs).
local function setsFor(set)
  local d = Core.data()
  local value = function(stats) return ns.Score.value(stats, set.ws) end
  local sims = d and ns.SimGear.setSims(d.setBonusSims, set.raw, set.key)
  sims = ns.Effects.setSims(sims, ns.SetBonusOverrides, set.key, set.ws.weights)
  local out = ns.SimGear.setBonuses(d and d.sets, sims, value)
  for setID, s in pairs(ns.ForeverItems.setBonuses(Core.foreverSets, value, ns.SetBonusSameAs, sims)) do
    out[setID] = s
  end
  return out
end

local function bisFor(spec, set)
  local f = ns.cdb.filters
  local key = set.id .. ":" .. tostring(f.reputation) .. tostring(f.profession) .. tostring(f.pvp) .. tostring(f.darkmoon)
  if bisCache[key] then return bisCache[key] end
  local token = classToken()
  bisCache[key] = ns.Bis.pick({
    items = itemsFor(spec), weightSet = set.ws, filters = f,
    tagged = { reputation = Core.data().repTagged or ns.Lists.reputation, profession = Core.data().profTagged or ns.Lists.profession, darkmoon = ns.Lists.darkmoon,
      unavailable = unavailableItems() },
    dualWield = ns.Spec.canDualWield(spec, token, knows(674), LEVEL, LEVEL),
    sets = setsFor(set),
    unique = ns.UniqueEquipped,
  })
  return bisCache[key]
end

-- For /prep bis and comparisons: each slot's target with its points, and the points of any other
-- items asked about (nil when SimGear doesn't have the item), in the spec's own units.
function Core.bisReport(spec, ids)
  local d = Core.data()
  local set = d and weightSet(spec)
  if not set then return nil end
  local out = { slots = {}, items = {} }
  local bis = bisFor(spec, set)
  for inv, b in pairs(bis) do
    if type(inv) == "number" then out.slots[inv] = { id = b.id, name = b.item.name, points = b.points } end
  end
  out.sets = {}
  local sets = setsFor(set)
  for setID, s in pairs(bis.sets or {}) do
    out.sets[setID] = { name = sets[setID] and sets[setID].name, count = s.count, points = s.points }
  end
  for _, id in ipairs(ids or {}) do
    local item = d.items[id]
    out.items[id] = item and { name = item.name, slot = item.slot, points = points(id, item, set.ws) } or false
  end
  return out
end

local SINGLE = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 15, 18 }
local PAIRS = { { 11, 12 }, { 13, 14 } }
Core.SLOT_NAME = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
  [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket", [15] = "Back",
  [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }

-- Gear points against BiS, slot group by slot group (a worn item counts up to its BiS's points),
-- and the to-dos: each BiS item you don't wear, with the points it would add.
local function gearPart(spec, set)
  local d = Core.data()
  local ws, bis = set.ws, bisFor(spec, set)
  local worn = {}
  for inv = 1, 18 do worn[inv] = wornItem(inv, d.items) end
  local function wp(inv)
    local w = worn[inv]
    if not w then return 0 end
    if inv == 17 and w.item then return points(w.id, ns.Score.inOffHand(w.item), ws) end
    return points(w.id, w.item, ws)
  end
  local function wears(id) for inv = 1, 18 do if worn[inv] and worn[inv].id == id then return true end end end
  -- Each worn slot as the score sees it, for the slot panel (unread: no stats to score).
  local scored = {}
  for inv = 1, 18 do
    local w = worn[inv]
    if w then
      scored[inv] = { id = w.id, name = (w.item and w.item.name) or C_Item.GetItemNameByID(w.id), points = wp(inv), unread = w.unread }
    end
  end
  local have, max, todos, rows = 0, 0, {}, {}
  local function todo(b, gain, inv)
    if gain <= 0 or wears(b.id) then return end
    local name = b.item.name or ("item " .. b.id)
    local owned = itemCount(b.id, true) > 0
    todos[#todos + 1] = { label = (owned and "Equip " or "") .. name, gain = gain, id = b.id, slot = Core.SLOT_NAME[inv] }
  end
  for _, inv in ipairs(SINGLE) do
    local b = bis[inv]
    if b then
      local h = math.min(wp(inv), b.points)
      have, max = have + h, max + b.points
      rows[inv] = { bis = b, pct = b.points > 0 and h / b.points or 1 }
      todo(b, b.points - h, inv)
    end
  end
  for _, pair in ipairs(PAIRS) do
    local a, c = bis[pair[1]], bis[pair[2]]
    local bp = (a and a.points or 0) + (c and c.points or 0)
    local h = math.min(wp(pair[1]) + wp(pair[2]), bp)
    have, max = have + h, max + bp
    local low = math.min(wp(pair[1]), wp(pair[2]))
    for _, b in ipairs({ a, c }) do if b then todo(b, b.points - low, pair[1]) end end
  end
  local b16, b17 = bis[16], bis[17]
  local bw = (b16 and b16.points or 0) + (b17 and b17.points or 0)
  local hw = math.min(wp(16) + wp(17), bw)
  have, max = have + hw, max + bw
  if b16 and not b17 then
    todo(b16, bw - hw, 16)
  else
    if b16 then todo(b16, b16.points - math.min(wp(16), b16.points), 16) end
    if b17 then todo(b17, b17.points - math.min(wp(17), b17.points), 17) end
  end
  -- Set bonuses: BiS's count toward the maximum, the pieces you wear toward what you have.
  local sets = setsFor(set)
  for setID, s in pairs(bis.sets or {}) do
    local n = 0
    for inv = 1, 18 do if worn[inv] and sets[setID].items[worn[inv].id] then n = n + 1 end end
    have = have + math.min(ns.Bis.setBonusAt(sets[setID], n), s.points)
    max = max + s.points
  end
  return { have = have, bis = max }, todos, rows, worn, scored -- scored: each worn slot's {id, name, points, unread} (slot panel, sheet sync)
end

-- Enchants ----------------------------------------------------------------------------------------------
local function enchantPart(spec, set, worn)
  prepareEnchants()
  local d, token = Core.data(), classToken()
  local raw = set.raw
  local byLevel = raw.source.kind == "sim" and type(d.enchants) == "table" and d.enchants[raw.source.maxLevel]
  local sims = type(byLevel) == "table" and byLevel[raw.spec or set.key] or nil
  local bis = bisFor(spec, set)
  local have, max, todos, slots = 0, 0, {}, {}
  for _, s in ipairs(ns.Enchants.slotsFor(token, spec)) do
    -- Weapon rows follow the BiS weapon: two-hand or one-hand on 16, a shield on 17.
    local target = bis[s.inv]
    local loc = target and target.item.slot
    local fits = target and (not ns.Enchants.LOCS[s.key] or ns.Enchants.LOCS[s.key][loc])
    if fits then
      local r = ns.Enchants.forSlot(s.key, set.ws, { sims = sims, raw = raw, n = 50 })
      local best = r.best and r.best.value or 0
      local w = worn[s.inv]
      local id = w and ns.Enchants.enchantOfLink(w.link)
      local h, known = 0, true
      if id then
        known = false
        for _, e in ipairs(r.list) do if e.row.enchant == id then h, known = e.value, true end end
        if not known and enchantByID[id] then
          h, known = ns.Score.value(ns.Enchants.statsOf(enchantByID[id], s.key), set.ws), true
        end
      end
      -- An enchant Prepped can't read is left out, not guessed at.
      if known and best > 0 then
        h = math.min(h, best)
        have, max = have + h, max + best
        if best - h > 0 then
          todos[#todos + 1] = { label = ns.Enchants.shortName(r.best.row) .. " on " .. s.label:lower(), gain = best - h }
        end
        slots[#slots + 1] = { key = s.key, pct = h / best, enchanted = id ~= nil, link = w and w.link,
          text = id and enchantByID[id] and ns.Enchants.shortName(enchantByID[id]) or nil }
      end
    end
  end
  return { have = have, bis = max }, todos, slots
end

-- Consumables and buffs ----------------------------------------------------------------------------------
local function secret(v) return issecretvalue and issecretvalue(v) end

-- true = up, false = not up, "unknown" = can't tell.
local function auraUp(spellID)
  if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return "unknown" end
  local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
  if not ok or secret(a) then return "unknown" end
  return a ~= nil
end

-- Whether a consumable's buff is up: food by the Well Fed buff, an oil or stone by the weapon's
-- temporary enchant, anything else by the buff the item's own spell gives.
local function buffStatus(entry)
  if entry.family == "food" then
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return "unknown" end
    local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", "Well Fed", "HELPFUL")
    if not ok or secret(a) then return "unknown" end
    return a ~= nil
  elseif entry.family == "weapon" then
    local ok, has = pcall(GetWeaponEnchantInfo)
    if not ok or secret(has) then return "unknown" end
    return has == true
  end
  local _, sid = C_Item.GetItemSpell(entry.id)
  if not sid then return "unknown" end -- item not loaded yet: never nag on a guess
  return auraUp(sid)
end

-- The spec's consumable role and the catalog entries open to it: its role's, the role it also takes
-- (cat: melee), no weapon buff in feral forms, and the role's extra potions.
function Core.consumablesFor(spec)
  local role = ns.ConsumableRoles[spec] or "melee"
  local also = ns.ConsumableRoleAlso[role]
  local extra = ns.ConsumableExtraPotions[role] or {}
  local catalog = {}
  for _, e in ipairs(ns.ConsumableCatalog) do
    local open = not e.roles or e.roles[role] or (also and e.roles[also])
    if e.family == "weapon" and ns.ConsumableNoWeapon[role] then open = false end
    if open then
      catalog[#catalog + 1] = e
    elseif extra[e.id] then
      local copy = {}
      for k, v in pairs(e) do copy[k] = v end
      copy.perNight = extra[e.id]
      catalog[#catalog + 1] = copy
    end
  end
  return catalog, role
end

local function consumablePlan(spec, set, inRaid)
  local catalog = Core.consumablesFor(spec)
  local stock, auras = {}, nil
  for _, e in ipairs(catalog) do stock[e.id] = itemCount(e.id, true) end
  if inRaid then
    auras = {}
    for _, e in ipairs(catalog) do if e.family ~= "potion" then auras[e.id] = buffStatus(e) end end
  end
  local plan = ns.Consumables.plan({
    catalog = catalog, stock = stock, raidHours = ns.cdb.raidHours,
    picks = ns.cdb.consumables[spec], filters = ns.cdb.filters, auras = auras,
    critStacks = ns.ConsumableRules.critStacks,
    score = function(stats) return ns.Score.value(stats, set.ws) end,
  })
  -- A row worth nothing to the spec isn't shown (potions are kept: stock only).
  local shown = {}
  for _, r in ipairs(plan.rows) do
    if r.max > 0 or r.slot == "potion" or r.unknown then shown[#shown + 1] = r end
  end
  return plan, shown, stock
end

-- Item tooltips (ItemTooltip.lua) ----------------------------------------------------------------------
-- A spec's BiS and worn points per slot, its readiness total and a scorer for any item, built the way
-- Core.compute builds the score. nil when the spec has no weights.
function Core.specContext(spec)
  local d = Core.data()
  local set = d and spec and weightSet(spec)
  if not set then return nil end
  local token = classToken()
  local gear, _, _, worn = gearPart(spec, set)
  local ench = enchantPart(spec, set, worn)
  local plan = consumablePlan(spec, set, false)
  local bis = bisFor(spec, set)
  local ctx = { spec = spec, token = token, total = gear.bis + ench.bis + plan.bis, bis = {}, bisIDs = {}, worn = {}, wornIDs = {},
    sets = setsFor(set), bisSets = bis.sets or {}, excluded = ns.Spec.gearRule(spec, token),
    dualWield = ns.Spec.canDualWield(spec, token, knows(674), LEVEL, LEVEL) }
  for inv = 1, 18 do
    if bis[inv] then ctx.bis[inv], ctx.bisIDs[inv] = bis[inv].points, bis[inv].id end
    local w = worn[inv]
    if w then
      ctx.wornIDs[inv] = w.id
      ctx.worn[inv] = (inv == 17 and w.item) and points(w.id, ns.Score.inOffHand(w.item), set.ws) or points(w.id, w.item, set.ws)
      if inv == 16 and w.item and w.item.slot == "INVTYPE_2HWEAPON" then ctx.wornTwoHand = true end
    end
  end
  -- An item as the spec scores it: SimGear's record, or the game's stats for a random-suffix roll or an
  -- item SimGear lacks (as worn items are read). nil when there is nothing to read.
  function ctx.item(id, link)
    local item = d.items[id]
    if item and not (link and ns.Stats.linkSuffix(link)) then return item end
    local raw = link and GetItemStatsFn and GetItemStatsFn(link)
    if not (raw and next(raw)) then return nil end
    local _, _, _, loc = C_Item.GetItemInfoInstant(link)
    return { name = C_Item.GetItemNameByID(id), slot = loc, stats = ns.Stats.addWeaponDps((ns.Stats.normalize(raw)), loc) }
  end
  function ctx.points(id, item, offHand)
    return points(id, offHand and ns.Score.inOffHand(item) or item, set.ws)
  end
  ctx.setBonusAt = ns.Bis.setBonusAt
  return ctx
end

-- The whole view ---------------------------------------------------------------------------------------------
local function blockers()
  return ns.Attune.blockers({
    raids = { "ONYXIA" }, -- the raids open on Forever, whatever the content target
    faction = UnitFactionGroup("player"),
    itemPlace = function(id)
      if (IsEquippedItem and IsEquippedItem(id)) or itemCount(id, false) > 0 then return "bags" end
      if itemCount(id, true) > 0 then return "bank" end
    end,
    questDone = function(q) return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q) or false end,
  })
end

-- Everything the tracker, buff bar and /prep commands show. Rebuilt on every change.
function Core.compute()
  local level = UnitLevel("player")
  local inInstance, kind = IsInInstance()
  if Core.buffTest then inInstance, kind = true, "raid" end
  local inRaid = inInstance and kind == "raid"
  local state = { level = level, collapsed = ns.cdb.collapsed, inRaid = inRaid, blockers = blockers() }
  local view = { state = state, instance = inInstance and kind or "none" }
  local spec, choices = Core.spec()
  state.specChoices = (level >= LEVEL) and choices or nil
  view.spec = spec
  local d, problem = Core.data()
  local set = d and spec and weightSet(spec)
  if not set then
    state.badge = d and "No weights for this spec" or "No gear data" -- neither SimGear nor the backup loaded
    view.problem = problem
    return view
  end
  -- Backup data says so even when the weights are estimates: both are worth knowing.
  local estimated = ns.Score.isPlaceholder(set.ws) and "Estimated weights"
  if d.snapshot then
    state.badge = ns.Backup.badge(d.snapshot) .. (estimated and (" · " .. estimated) or "")
  else
    state.badge = estimated or "SimGear live"
  end
  local gear, gearTodos, rows, worn, scored = gearPart(spec, set)
  local ench, enchTodos = enchantPart(spec, set, worn)
  local plan, shown = consumablePlan(spec, set, false)
  local steps = {}
  for _, t in ipairs(gearTodos) do steps[#steps + 1] = t end
  for _, t in ipairs(enchTodos) do steps[#steps + 1] = t end
  local r = ns.Readiness.compute({ gear = gear, enchants = ench, consumables = { have = plan.have, bis = plan.bis } }, steps)
  state.prep, state.todos, state.consumables = r.pct, r.steps, shown
  view.consumableRows = plan.rows
  view.readiness, view.rows, view.set = r, rows, set
  view.slotData = { bis = bisFor(spec, set), worn = scored, total = gear.bis + ench.bis + plan.bis }
  if inRaid or (inInstance and kind == "party") then
    local raidPlan, raidShown = consumablePlan(spec, set, true)
    local now = ns.Readiness.compute({ gear = gear, enchants = ench, consumables = { have = raidPlan.have, bis = raidPlan.bis } })
    state.raidNow = now.pct
    view.buffSlots = raidShown
  end
  return view
end

-- One spec measured against what you wear now, for the sheet sync and the loot alert (Watch.lua):
-- readiness with its steps, Raid Ready-style slot rows, each enchant row, consumable counts (bags +
-- bank) and the BiS item IDs. nil when the spec has no weights.
function Core.measure(spec)
  local d = Core.data()
  local set = d and spec and weightSet(spec)
  if not set then return nil end
  local gear, gearTodos, _, worn, wornPts = gearPart(spec, set)
  local ench, enchTodos, enchRows = enchantPart(spec, set, worn)
  local plan, _, stock = consumablePlan(spec, set, false)
  local steps = {}
  for _, t in ipairs(gearTodos) do steps[#steps + 1] = t end
  for _, t in ipairs(enchTodos) do steps[#steps + 1] = t end
  local r = ns.Readiness.compute({ gear = gear, enchants = ench, consumables = { have = plan.have, bis = plan.bis } }, steps)
  local bis, bisPts, bisIDs = bisFor(spec, set), {}, {}
  for inv, b in pairs(bis) do
    if type(inv) == "number" then bisPts[inv], bisIDs[b.id] = { id = b.id, points = b.points }, true end
  end
  -- Counts for every consumable open to the spec, not just the planned stack: the sheet looks up its
  -- own picks by item ID, and those can differ from Prepped's.
  local cons = {}
  for id, n in pairs(stock) do cons[id] = n end
  local relic = bis[18] and bis[18].item.slot == "INVTYPE_RELIC"
  return { readiness = r, slots = ns.Sync.slotRows(wornPts, bisPts, relic), enchants = enchRows, cons = cons, bis = bisIDs }
end

-- In bags, bank or worn: what Raid Ready counted as owned.
function Core.owns(id)
  if itemCount(id, true) > 0 then return true end
  for inv = 1, 19 do if GetInventoryItemID("player", inv) == id then return true end end
  return false
end

-- Refresh plumbing: changes are batched, then every listener redraws from one compute.
Core.listeners = {}
local pending = false
function Core.changed(full)
  if full then bisCache, itemsCache, setCache = {}, {}, {} end
  if pending then return end
  pending = true
  C_Timer.After(0.3, function()
    pending = false
    local ok, view = pcall(Core.compute)
    if not ok then
      Core.lastError = view
      view = { state = { level = UnitLevel("player"), badge = "Error: /prep debug" } }
    end
    Core.view = view
    for _, fn in ipairs(Core.listeners) do
      local okL, err = pcall(fn, view)
      if not okL then Core.lastError = err end
    end
  end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    initDB()
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED",
      "BANKFRAME_CLOSED", "QUEST_TURNED_IN", "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_LEVEL_UP",
      "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA", "SPELLS_CHANGED" }) do
      pcall(self.RegisterEvent, self, e)
    end
    pcall(self.RegisterUnitEvent, self, "UNIT_AURA", "player")
    pcall(self.RegisterUnitEvent, self, "UNIT_INVENTORY_CHANGED", "player")
    if ns.UI and ns.UI.onLoad then ns.UI.onLoad() end
    return
  end
  -- New talents or spells can change the weight set (dual wield, cat form).
  Core.changed(event == "TRAIT_CONFIG_UPDATED" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "SPELLS_CHANGED"
    or event == "PLAYER_LEVEL_UP")
end)

-- Settings that change BiS call this.
function Core.settingsChanged() Core.changed(true) end


-- /prep harvest [from to]: asks the game about every item ID in a range (by default the tier 0.5
-- sets, 226700-226900) and saves what comes back to PreppedDB.harvest. Forever sends these items
-- from the server, so the game is the only source. Saved on /reload, used from then on.
local HARVEST_FROM, HARVEST_TO = 226700, 226900
local IN_FLIGHT, TICK, PATIENCE = 40, 0.2, 25 -- PATIENCE ticks without an answer = no such item

function Core.harvest(from, to)
  if Core.harvesting then Core.print("harvest already running"); return end
  from, to = from or HARVEST_FROM, to or HARVEST_TO
  if to < from or to - from > 20000 then Core.print("harvest: give a range of at most 20000 IDs"); return end
  local tokens = {}
  for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do tokens[name] = token end
  for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do tokens[name] = token end
  ns.db.harvest = ns.db.harvest or { records = {} }
  local h = ns.db.harvest
  h.records = h.records or {}
  h.build = select(1, GetBuildInfo())
  h.ranges = h.ranges or {}
  h.ranges[#h.ranges + 1] = from .. "-" .. to
  local nextID, waiting, found, none = from, {}, 0, 0
  Core.harvesting = true
  Core.print(("harvest: asking the game about items %d-%d..."):format(from, to))
  local function tooltipLines(id)
    local ok, t = pcall(C_TooltipInfo.GetItemByID, id)
    local lines = {}
    if ok and t and t.lines then for _, l in ipairs(t.lines) do lines[#lines + 1] = l.leftText end end
    return lines
  end
  local ticker
  ticker = C_Timer.NewTicker(TICK, function()
    while nextID <= to and #waiting < IN_FLIGHT do
      pcall(C_Item.RequestLoadItemDataByID, nextID)
      waiting[#waiting + 1] = { id = nextID, ticks = 0 }
      nextID = nextID + 1
    end
    for i = #waiting, 1, -1 do
      local w = waiting[i]
      w.ticks = w.ticks + 1
      local name, link, quality, itemLevel, minLevel, _, _, _, equipLoc, _, _, _, _, _, _, setID = C_Item.GetItemInfo(w.id)
      if name and link then
        local raw = GetItemStatsFn and GetItemStatsFn(link) or {}
        local lines = tooltipLines(w.id)
        local classes = ns.ForeverItems.classesFrom(lines, tokens)
        local set
        if setID and setID > 0 then
          local setName = C_Item.GetItemSetInfo and C_Item.GetItemSetInfo(setID)
          set = { id = setID, name = setName, bonuses = ns.ForeverItems.setBonusesFrom(lines) }
        end
        h.records[w.id] = ns.ForeverItems.record({ name = name, quality = quality, itemLevel = itemLevel,
          minLevel = minLevel, equipLoc = equipLoc }, raw, classes, set)
        found = found + 1
        table.remove(waiting, i)
      elseif w.ticks >= PATIENCE then
        none = none + 1
        table.remove(waiting, i)
      end
    end
    if nextID > to and #waiting == 0 then
      ticker:Cancel()
      Core.harvesting = false
      Core.resetItems()
      Core.changed(true)
      Core.print(("harvest done: %d items, %d IDs with nothing. In use now; /reload to save them."):format(found, none))
    end
  end)
end

-- /prep harvest vendor, with a vendor's window open: records every item it sells and the price,
-- saved to PreppedDB.vendors. SimGear gives no source for vendor gear such as the Undermine Reals
-- items, so without this Prepped never targets them.
function Core.harvestVendor()
  local n = GetMerchantNumItems and GetMerchantNumItems() or 0
  if n == 0 then
    Core.print("harvest vendor: no vendor items to read (open the vendor's window, then type the command)")
    return
  end
  local name = UnitName("npc") or "Vendor"
  local entry = { name = name, zone = GetZoneText and GetZoneText() or nil, items = {} }
  local count = 0
  for i = 1, n do
    local id = GetMerchantItemID(i)
    if id then
      local copper = 0
      if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
        if ok and type(info) == "table" then copper = info.price or 0 end
      elseif GetMerchantItemInfo then
        copper = select(3, GetMerchantItemInfo(i)) or 0
      end
      local costs = {}
      local nCosts = GetMerchantItemCostInfo and GetMerchantItemCostInfo(i) or 0
      for j = 1, nCosts do
        local _, amount, link, currency = GetMerchantItemCostItem(i, j)
        local costName = currency or (link and C_Item.GetItemInfo(link)) or "?"
        costs[#costs + 1] = { amount = amount or 0, name = costName }
      end
      entry.items[id] = ns.ForeverItems.costText(copper, costs)
      count = count + 1
    end
  end
  ns.db.vendors = ns.db.vendors or {}
  ns.db.vendors[name] = entry
  Core.resetItems()
  Core.changed(true)
  Core.print(("harvest vendor: %d items from %s. In use now; /reload to save them."):format(count, name))
end
