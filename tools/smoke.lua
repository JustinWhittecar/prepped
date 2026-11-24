-- Smoke run: loads Prepped in .toc order against stubbed WoW API calls and real SimGear class data,
-- fires the load events and prints what the tracker would show. A load check for the glue
-- (Core.lua, UI.lua), not a test: it catches nil errors and wiring mistakes before the game does.
--   luajit tools/smoke.lua [Class] [RaidReady.lua saved variables, for worn items and stock] [raid|-] [SPEC]
local T = dofile("test/lib.lua")
local class = arg[1] or "Druid"
local token = class:upper()
local svPath = arg[2]
local raidMode = arg[3] == "raid"

_G.SimGearForeverData = T.simgearGlobal(class)
-- PREPPED_SV=<Prepped.lua saved variables>: use that character's settings (filters, picks).
if os.getenv("PREPPED_SV") then
  local env = {}
  local chunk = assert(loadfile(os.getenv("PREPPED_SV")))
  setfenv(chunk, env)()
  _G.PreppedCharDB = env.PreppedCharDB
end
-- PREPPED_DB=<account Prepped.lua>: that account's settings and harvest.
if os.getenv("PREPPED_DB") then
  local env = {}
  local chunk = assert(loadfile(os.getenv("PREPPED_DB")))
  setfenv(chunk, env)()
  _G.PreppedDB = env.PreppedDB
end
local data = SimGearForeverData[token]

local svCons
-- Worn gear: the "cat" slot list from Raid Ready's sync block, when given.
local INV = { Head = 1, Neck = 2, Shoulder = 3, Back = 15, Chest = 5, Wrist = 9, Hands = 10, Waist = 6, Legs = 7, Feet = 8,
  ["Finger 1"] = 11, ["Finger 2"] = 12, ["Trinket 1"] = 13, ["Trinket 2"] = 14, ["Main Hand"] = 16, Relic = 18 }
local worn = {}
if svPath then
  local env = {}
  assert(loadfile(svPath, "t", env) or setfenv(assert(loadfile(svPath)), env))()
  local sync = env.RaidReadyCharDB and env.RaidReadyCharDB.sync
  for _, s in ipairs(sync and sync.slots and sync.slots.cat or {}) do
    if INV[s.slot] and s.id > 0 then worn[INV[s.slot]] = s.id end
  end
  _G.RaidReadyCharDB = { groupSpec = env.RaidReadyCharDB.groupSpec }
  svCons = sync and sync.cons
end

-- A frame stub: every method is a no-op unless listed here.
local timers = {}
local frames = {}
local function stub()
  local o = { scripts = {}, shown = false }
  return setmetatable(o, { __index = function(t, k)
    if k == "SetScript" then return function(self, name, fn) self.scripts[name] = fn end end
    if k == "GetStringWidth" or k == "GetWidth" or k == "GetStringHeight" then return function() return 40 end end
    if k == "GetFontString" then return function(self) local fs = rawget(self, "fs") or stub(); rawset(self, "fs", fs); return fs end end
    if k == "CreateFontString" or k == "CreateTexture" then return function() return stub() end end
    if k == "SetText" then return function(self, s) self.text = s end end
    if k == "Show" then return function(self) self.shown = true end end
    if k == "Hide" then return function(self) self.shown = false end end
    if k == "IsShown" then return function(self) return self.shown end end
    if k == "SetShown" then return function(self, v) self.shown = v end end
    if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
    return function() end
  end })
end
_G.CreateFrame = function(_, name)
  local f = stub()
  frames[#frames + 1] = f
  if name then _G[name] = f end
  return f
end
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
_G.UnitClass = function() return class, token end
_G.UnitLevel = function() return 60 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.IsInInstance = function() if raidMode then return true, "raid" end return false, "none" end
_G.GetInventoryItemID = function(_, inv) return worn[inv] end
_G.GetInventoryItemLink = function(_, inv) return worn[inv] and ("item:" .. worn[inv] .. "::::::::60") end
local bags = { [13452] = 2, [12820] = 10, [13446] = 5, [20452] = 3 }
-- Raid Ready's synced counts (bags + bank) replace the made-up ones when given.
if svCons then bags = {} for _, c in pairs(svCons) do for id, n in pairs(c) do bags[id] = n end end end
_G.C_Item = {
  GetItemCount = function(id) return bags[id] or 0 end,
  GetItemInfoInstant = function(link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    local it = data.items.items[id]
    return id, nil, nil, it and it.slot
  end,
  GetItemNameByID = function(id) local it = data.items.items[id]; return it and it.name end,
  GetItemSpell = function() return nil end,
  GetItemStats = function(link) return C_Item.statsFor and C_Item.statsFor(link) or {} end,
  GetItemIconByID = function() return 134400 end,
}
_G.IsEquippedItem = function(id) for _, w in pairs(worn) do if w == id then return true end end return false end
local done = { [4182] = true, [4183] = true }
_G.C_QuestLog = { IsQuestFlaggedCompleted = function(q) return done[q] == true end }
_G.IsPlayerSpell = function(s) return s == 768 end -- Cat Form known
_G.C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return id == 17538 and {} or nil end,
  GetAuraDataBySpellName = function() return nil end }
_G.GetWeaponEnchantInfo = function() return false end
_G.InCombatLockdown = function() return false end
_G.UnitIsDeadOrGhost = function() return false end
_G.RegisterStateDriver = function() end
_G.GameTooltip = stub()
_G.GameTooltip_Hide = function() end
_G.UISpecialFrames = {}
_G.tinsert = table.insert
_G.C_AddOns = { GetAddOnMetadata = function() return "0.1.0-dev" end, LoadAddOn = function() return true end }
_G.SlashCmdList = {}
_G.unpack = unpack

-- Load in .toc order, as the game does.
local ns = {}
for l in io.lines("Prepped/Prepped.toc") do
  if not l:match("^#") and l:match("%.lua%s*$") then
    local file = l:gsub("\\", "/"):gsub("%s+$", "")
    assert(loadfile("Prepped/" .. file))("Prepped", ns)
  end
end

local function fire(event, ...)
  for _, f in ipairs(frames) do if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end
end
local function runTimers()
  while #timers > 0 do table.remove(timers, 1)() end
end
fire("ADDON_LOADED", "Prepped")
runTimers()
ns.cdb.collapsed = false
if arg[4] then ns.cdb.groupSpec[1] = arg[4] end
-- PREPPED_WEIGHTS=<choice> (raidready, custom...): score the spec in arg 4 with those weights.
if os.getenv("PREPPED_WEIGHTS") and arg[4] then ns.cdb.weights[arg[4]] = os.getenv("PREPPED_WEIGHTS") end
fire("PLAYER_ENTERING_WORLD")
runTimers()

-- PREPPED_HARVEST=1: run /prep harvest over the Feralheart IDs against a stubbed game that answers
-- with Raid Ready's stats for them (plus a guessed 150 base armor), then recompute.
if os.getenv("PREPPED_HARVEST") then
  local RR = {}
  assert(loadfile(os.getenv("HOME") .. "/raid-ready/RaidReady/Data.lua"))("RaidReady", RR)
  local KEY = { str = "ITEM_MOD_STRENGTH_SHORT", agi = "ITEM_MOD_AGILITY_SHORT", sta = "ITEM_MOD_STAMINA_SHORT",
    int = "ITEM_MOD_INTELLECT_SHORT", defrtng = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" }
  local SLOT = { head = "INVTYPE_HEAD", shoulder = "INVTYPE_SHOULDER", chest = "INVTYPE_CHEST", waist = "INVTYPE_WAIST",
    legs = "INVTYPE_LEGS", feet = "INVTYPE_FEET", wrist = "INVTYPE_WRIST", hands = "INVTYPE_HAND", finger = "INVTYPE_FINGER" }
  local game = {}
  for id, it in pairs(RR.ITEMS) do
    if id >= 226700 and id <= 226900 then
      local raw = { RESISTANCE0_NAME = 150 + (it.stats.armorbonus or 0) }
      for k, v in pairs(it.stats) do if KEY[k] then raw[KEY[k]] = v end end
      game[id] = { name = it.name, slot = SLOT[it.slot], raw = raw }
    end
  end
  local asked = {}
  C_Item.RequestLoadItemDataByID = function(id) asked[id] = (asked[id] or 0) + 1 end
  C_Item.GetItemInfo = function(id)
    local g = game[id]
    if not (g and asked[id]) then return nil end
    return g.name, "item:" .. id, 4, 66, 60, "Armor", "Leather", 1, g.slot, nil, 0, 4, 2, 1, 0, 801
  end
  C_Item.GetItemSetInfo = function(setID) return "Feralheart Guardian" end
  C_Item.statsFor = function(link) local g = game[tonumber(link:match("item:(%d+)"))]; return g and g.raw or {} end
  _G.C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = game[id] and game[id].name }, { leftText = "Classes: Druid" }, { leftText = "(2) Set: +200 Armor." } } } end }
  _G.LOCALIZED_CLASS_NAMES_MALE = { DRUID = "Druid", WARRIOR = "Warrior" }
  _G.GetBuildInfo = function() return "1.60.1" end
  local tick
  C_Timer.NewTicker = function(_, fn) local t = { Cancel = function(self) self.cancelled = true end }; tick = { fn = fn, t = t }; return t end
  ns.Core.harvest(226785, 226810)
  local n = 0
  while not tick.t.cancelled and n < 1000 do tick.fn(); n = n + 1 end
  runTimers()
  local r = ns.db.harvest.records[226801]
  print("set on Faceguard: " .. tostring(r and r.set and r.set.name) .. " · " .. tostring(r and r.set and r.set.bonuses and r.set.bonuses[1].text))
  print("harvested records: " .. (function() local c = 0 for _ in pairs(ns.db.harvest.records) do c = c + 1 end return c end)()
    .. " · merged for " .. token .. ": " .. tostring(ns.Core.foreverCount))
end

-- PREPPED_VENDOR=1: /prep harvest vendor against a stubbed Pix Xizzix window.
if os.getenv("PREPPED_VENDOR") then
  local stock = { { id = 272396, cost = 100 }, { id = 272408, cost = 75 }, { id = 19024, gold = 250000 } }
  _G.GetMerchantNumItems = function() return #stock end
  _G.GetMerchantItemID = function(i) return stock[i].id end
  _G.C_MerchantFrame = { GetItemInfo = function(i) return { price = stock[i].gold or 0 } end }
  _G.GetMerchantItemCostInfo = function(i) return stock[i].cost and 1 or 0 end
  _G.GetMerchantItemCostItem = function(i) return 134400, stock[i].cost, nil, "Tarnished Undermine Real" end
  _G.UnitName = function() return "Pix Xizzix" end
  _G.GetZoneText = function() return "Booty Bay" end
  ns.Core.harvestVendor()
  runTimers()
  for id, cost in pairs(ns.db.vendors["Pix Xizzix"].items) do print("  vendor item " .. id .. ": " .. cost) end
end

local v = ns.Core.view
if ns.Core.lastError then print("ERROR: " .. tostring(ns.Core.lastError)) os.exit(1) end
local t = ns.Tracker.lines(v.state)
print("spec: " .. tostring(v.spec) .. " · badge: " .. tostring(v.state.badge))
print("header: " .. t.header)
for _, l in ipairs(t.lines) do print(string.format("  [%s] %s", l.kind, l.text)) end
local r = v.readiness
if r and r.pct then
  print(string.format("gear %.0f%% · enchants %s · consumables %s", (r.gear or 0) * 100,
    r.enchants and string.format("%.0f%%", r.enchants * 100) or "-", r.consumables and string.format("%.0f%%", r.consumables * 100) or "-"))
end
if v.buffSlots then
  local list = ns.Buffs.missing({ instance = v.instance, slots = v.buffSlots, stock = bags })
  for _, m in ipairs(list) do print("  buff missing: " .. m.item.name .. " (" .. m.bags .. " in bags)") end
end
SlashCmdList.PREPPED("debug")

-- Build and fill the options window once, as opening it in game does.
ns.UI.toggleOptions()
PreppedOptions.scripts.OnShow(PreppedOptions)
print("options window built")

-- Optional 5th argument: Raid Ready's Data.lua. Prints each slot's Prepped BiS beside Raid Ready's
-- target for the same spec (cat or bear), both scored in SimGear's units for that spec.
if arg[5] then
  local RR = {}
  local chunk = assert(loadfile(arg[5]))
  chunk("RaidReady", RR)
  local rrSpec = (v.spec == "FERAL_BEAR") and "bear" or "cat"
  local targets = RR.TARGETS[rrSpec]
  local ids = {}
  for _, list in pairs(targets) do for _, id in ipairs(list) do ids[#ids + 1] = id end end
  local rep = ns.Core.bisReport(v.spec, ids)
  local INVS = { head = { 1 }, neck = { 2 }, shoulder = { 3 }, back = { 15 }, chest = { 5 }, wrist = { 9 }, hands = { 10 },
    waist = { 6 }, legs = { 7 }, feet = { 8 }, finger = { 11, 12 }, trinket = { 13, 14 }, mainhand = { 16 }, relic = { 18 } }
  local order = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs", "feet", "finger", "trinket", "mainhand", "relic" }
  for _, s in pairs(rep.sets or {}) do print(("set: %s, %d pieces, bonus %.1f"):format(tostring(s.name), s.count, s.points)) end
  print(("\n%-9s %-38s %6s | %-34s %6s"):format("slot", "Prepped BiS", "pts", "Raid Ready", "pts"))
  for _, slot in ipairs(order) do
    for k, inv in ipairs(INVS[slot]) do
      local b = rep.slots[inv]
      local rid = targets[slot] and targets[slot][k]
      local r = rid and rep.items[rid]
      local rname = rid and (r and r.name or ((RR.ITEMS and RR.ITEMS[rid] and RR.ITEMS[rid].name) or ("item " .. rid)) .. " [not in SimGear]") or "-"
      print(("%-9s %-38s %6.1f | %-34s %6s"):format(slot, b and b.name or "-", b and b.points or 0, rname:sub(1, 34),
        r and ("%.1f"):format(r.points) or "-"))
    end
  end
end
