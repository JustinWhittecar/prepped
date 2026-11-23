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
local DB_DEFAULTS = { showTracker = true, scale = 1, buffsRaid = true, buffsDungeon = false }
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
  ns.cdb.filters = ns.cdb.filters or {}     -- all off by default
  ns.cdb.consumables = ns.cdb.consumables or {} -- [spec][slot] = item ID or "none"
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
function Core.data()
  if data or dataProblem then return data, dataProblem end
  local token = classToken()
  if not (_G.SimGearForeverData and _G.SimGearForeverData[token]) and C_AddOns and C_AddOns.LoadAddOn then
    local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, classAddon(token))
    if ok and not loaded and reason then dataProblem = classAddon(token) .. ": " .. tostring(reason) end
  end
  local d, why = ns.SimGear.load(_G.SimGearForeverData, token)
  if d then data, dataProblem = d, nil else dataProblem = dataProblem or why end
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
  if setCache[key] ~= nil then return setCache[key] or nil end
  local raw = d.specs[key] and ns.Score.pickSet(d.specs[key], LEVEL)
  if not raw then setCache[key] = false; return nil end
  local src = raw.source
  local byLevel = src.kind == "sim" and type(d.itemEffects) == "table" and d.itemEffects[src.maxLevel]
  local sims = type(byLevel) == "table" and byLevel[raw.spec or key]
  local ws = raw
  if type(sims) == "table" then
    local effects = {}
    for id, v in pairs(raw.effects or {}) do effects[id] = v end
    for id, e in pairs(sims) do
      if type(e) == "table" and type(e.v) == "number" and effects[id] == nil then effects[id] = e.v end
    end
    ws = setmetatable({ effects = effects }, { __index = raw })
  end
  setCache[key] = { ws = ws, raw = raw, key = key }
  return setCache[key]
end

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
local function bisFor(spec, set)
  local f = ns.cdb.filters
  local key = set.key .. ":" .. tostring(f.reputation) .. tostring(f.profession) .. tostring(f.pvp) .. tostring(f.darkmoon)
  if bisCache[key] then return bisCache[key] end
  local token = classToken()
  bisCache[key] = ns.Bis.pick({
    items = itemsFor(spec), weightSet = set.ws, filters = f,
    tagged = { reputation = ns.Lists.reputation, profession = ns.Lists.profession, darkmoon = ns.Lists.darkmoon,
      unavailable = unavailableItems() },
    dualWield = ns.Spec.canDualWield(spec, token, knows(674), LEVEL, LEVEL),
  })
  return bisCache[key]
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
  return { have = have, bis = max }, todos, rows, worn
end

-- Enchants ----------------------------------------------------------------------------------------------
local function enchantPart(spec, set, worn)
  prepareEnchants()
  local d, token = Core.data(), classToken()
  local raw = set.raw
  local byLevel = raw.source.kind == "sim" and type(d.enchants) == "table" and d.enchants[raw.source.maxLevel]
  local sims = type(byLevel) == "table" and byLevel[raw.spec or set.key] or nil
  local bis = bisFor(spec, set)
  local have, max, todos = 0, 0, {}
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
      end
    end
  end
  return { have = have, bis = max }, todos
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

local function buffStatus(entry)
  if entry.aura == "Well Fed" then
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return "unknown" end
    local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", "Well Fed", "HELPFUL")
    if not ok or secret(a) then return "unknown" end
    return a ~= nil
  elseif entry.aura == "weapon" then
    local ok, has = pcall(GetWeaponEnchantInfo)
    if not ok or secret(has) then return "unknown" end
    return has == true
  end
  local ids = { entry.aura }
  local _, sid = C_Item.GetItemSpell(entry.id)
  if sid and sid ~= entry.aura then ids[#ids + 1] = sid end
  local unknown = false
  for _, s in ipairs(ids) do
    local r = auraUp(s)
    if r == true then return true end
    if r == "unknown" then unknown = true end
  end
  return unknown and "unknown" or false
end

-- The spec's consumable role, its slots and the catalog entries open to it.
function Core.consumablesFor(spec)
  local role = ns.ConsumableRoles[spec] or "melee"
  local group = ns.ConsumableRoleGroup[role] or role
  local catalog = {}
  for _, e in ipairs(ns.ConsumableCatalog) do
    if not e.roles or e.roles[group] then catalog[#catalog + 1] = e end
  end
  return ns.ConsumableSlots[role], catalog, role
end

local function consumablePlan(spec, set, inRaid)
  local slots, catalog, role = Core.consumablesFor(spec)
  local stock, auras = {}, nil
  for _, e in ipairs(catalog) do stock[e.id] = itemCount(e.id, true) end
  local overrides = {}
  for k, v in pairs(ns.cdb.consumables[spec] or {}) do overrides[k] = v end
  overrides.potion = overrides.potion or ns.ConsumablePotion[role] or 13446
  if inRaid then
    auras = {}
    for _, e in ipairs(catalog) do
      if e.aura and auras[e.aura] == nil then auras[e.aura] = buffStatus(e) end
    end
  end
  local plan = ns.Consumables.plan({
    catalog = catalog, slots = slots, stock = stock, raidHours = ns.cdb.raidHours,
    overrides = overrides, filters = ns.cdb.filters, auras = auras,
    score = function(stats) return ns.Score.value(stats, set.ws) end,
  })
  -- A slot whose best item does nothing for the spec isn't shown (potions are kept: stock only).
  local shown = {}
  for _, s in ipairs(plan.slots) do
    if s.item and (s.max > 0 or s.slot == "potion" or s.unknown) then shown[#shown + 1] = s end
  end
  return plan, shown, stock
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

-- Everything the tracker, buff bar and /pr commands show. Rebuilt on every change.
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
    state.badge = d and "No weights for this spec" or "SimGear not installed"
    view.problem = problem
    return view
  end
  state.badge = ns.Score.isPlaceholder(set.ws) and "Estimated weights" or "SimGear live"
  local gear, gearTodos, rows, worn = gearPart(spec, set)
  local ench, enchTodos = enchantPart(spec, set, worn)
  local plan, shown = consumablePlan(spec, set, false)
  local steps = {}
  for _, t in ipairs(gearTodos) do steps[#steps + 1] = t end
  for _, t in ipairs(enchTodos) do steps[#steps + 1] = t end
  local r = ns.Readiness.compute({ gear = gear, enchants = ench, consumables = { have = plan.have, bis = plan.bis } }, steps)
  state.prep, state.todos, state.consumables = r.pct, r.steps, shown
  view.readiness, view.rows, view.set = r, rows, set
  if inRaid or (inInstance and kind == "party") then
    local raidPlan, raidShown = consumablePlan(spec, set, true)
    local now = ns.Readiness.compute({ gear = gear, enchants = ench, consumables = { have = raidPlan.have, bis = raidPlan.bis } })
    state.raidNow = now.pct
    view.buffSlots = raidShown
  end
  return view
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
      view = { state = { level = UnitLevel("player"), badge = "Error: /pr debug" } }
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
