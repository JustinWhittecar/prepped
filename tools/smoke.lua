-- Smoke run: loads Prepped in .toc order against stubbed WoW API calls and real SimGear class data,
-- fires the load events and prints what the tracker would show. A load check for the glue
-- (Core.lua, UI.lua), not a test: it catches nil errors and wiring mistakes before the game does.
--   luajit tools/smoke.lua [Class] [RaidReady.lua saved variables, for worn items and stock] [raid|-] [SPEC]
local T = dofile("test/lib.lua")
local class = arg[1] or "Druid"
local token = class:upper()
local svPath = arg[2] ~= "-" and arg[2] or nil -- "-": none, to reach the later arguments
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
-- PREPPED_BACKUP=missing (or 1): SimGear's class addon won't load, so Core falls back to the backup
-- copy (PreppedBackup_<Class>/ in the repo). PREPPED_BACKUP=reshaped: SimGear loads but its weights
-- aren't where the adapter looks. PREPPED_BACKUP=none: neither loads. The stubs below still read
-- SimGear's items for names and slots.
local backupMode = os.getenv("PREPPED_BACKUP")
if backupMode == "1" then backupMode = "missing" end
if backupMode == "missing" or backupMode == "none" then _G.SimGearForeverData = nil
elseif backupMode == "reshaped" then
  local copy = {}
  for k, v in pairs(data) do copy[k] = v end
  copy.weights = { FERAL_CAT = {} }
  _G.SimGearForeverData = { [token] = copy }
end

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
    if k == "GetFrameLevel" then return function() return 1 end end
    if k == "GetText" then return function(self) return self.text end end
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
-- PREPPED_BAGS="16720=1,16706=1": more bag/bank counts, e.g. tier 0.5 hand-ins.
for id, n in (os.getenv("PREPPED_BAGS") or ""):gmatch("(%d+)=(%d+)") do bags[tonumber(id)] = tonumber(n) end
_G.C_Item = {
  GetItemCount = function(id) return bags[id] or 0 end,
  GetItemInfoInstant = function(link)
    local id = tonumber(tostring(link):match("item:(%d+)")) or tonumber(link)
    -- Prepped's merged items (Forever's too) once loaded, then SimGear's, then the tooltip check's extras.
    local merged = _G.Prepped and _G.Prepped.Core and _G.Prepped.Core.data() and _G.Prepped.Core.data().items
    local it = (merged and merged[id]) or data.items.items[id]
    local slot = (it and it.slot) or (C_Item.extraSlots and C_Item.extraSlots[id])
    return id, nil, nil, slot
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
_G.C_AddOns = { GetAddOnMetadata = function() return "0.1.0-dev" end, LoadAddOn = function(name)
  if (backupMode == "missing" or backupMode == "none") and name:find("^SimGearForever") then return false, "MISSING" end
  if backupMode == "none" and name:find("^PreppedBackup_") then return false, "DISABLED" end
  if name:find("^PreppedBackup_") then
    -- Load it as the game does: its .toc's files, with (addon name, ns).
    local ns = {}
    for l in io.lines(name .. "/" .. name .. ".toc") do
      if not l:match("^#") and l:match("%.lua%s*$") then assert(loadfile(name .. "/" .. l:gsub("%s+$", "")))(name, ns) end
    end
    print("loaded " .. name .. " (backup copy)")
  end
  return true
end }
_G.SlashCmdList = {}
local tooltipHook
_G.Enum = { TooltipDataType = { Item = 0 } }
_G.TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipHook = fn end }
local shiftDown = false
_G.IsShiftKeyDown = function() return shiftDown end
_G.unpack = unpack
-- The character sheet the slot panel docks to (frame stubs, so hooks are no-ops).
_G.CharacterFrame = CreateFrame("Frame", "CharacterFrame")
_G.PaperDollFrame = CreateFrame("Frame", "PaperDollFrame")
_G.time = os.time
_G.GetTime = os.clock

-- Load in .toc order, as the game does.
local ns = {}
_G.PREPPED_NS = ns -- for tools that build on this run (tools/bis_audit.lua)
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
-- PREPPED_BIS_POINTS=1: each slot's BiS points, for comparing live against the backup (equal items,
-- such as both sides' PvP sets, tie, and BiS takes either).
if os.getenv("PREPPED_BIS_POINTS") then
  for inv = 1, 18 do
    local row = v.rows and v.rows[inv]
    if row then print(string.format("bis %2d %8.3f %s", inv, row.bis.points or 0, tostring(row.bis.item.name))) end
  end
end

-- Build and fill the options window once, as opening it in game does.
ns.UI.toggleOptions()
PreppedOptions.scripts.OnShow(PreppedOptions)
print("options window built")
-- Stat weights: Custom opens the panel beside the window, one box per stat SimGear weighs; typing
-- a value and leaving the box saves it to Custom. Then back to the spec's own.
do
  local spec = ns.Core.spec()
  ns.cdb.weights[spec] = "custom"
  ns.Core.settingsChanged()
  PreppedOptions.refresh()
  local p = PreppedWeights
  local box = p.rows[1] and p.rows[1].box
  print(string.format("weights panel: %s, %d rows, first %s = %s", p.shown and "shown" or "HIDDEN", #p.rows,
    tostring(p.rows[1] and p.rows[1].label.text), tostring(box and box.text)))
  box:SetText("7.5")
  box.scripts.OnEditFocusLost(box)
  print("  edited: " .. box.stat .. " = " .. tostring(ns.cdb.customWeights[spec][box.stat]))
  ns.cdb.weights[spec], ns.cdb.customWeights[spec] = nil, nil
  ns.Core.settingsChanged()
  PreppedOptions.refresh()
  print("  back to SimGear: panel " .. (p.shown and "STILL SHOWN" or "hidden"))
end

-- Item tooltip lines through the real hook, for a few items: Forever and SimGear pieces, one SimGear
-- lacks (a made-up head with no stats: must say "Not scored by Prepped"), and an elixir (no line).
-- 226792 also as the game would show it to a non-Druid: a leather head with stats and "Classes: Druid".
C_Item.extraSlots = { [999999] = "INVTYPE_HEAD", [226792] = "INVTYPE_HEAD" }
_G.LOCALIZED_CLASS_NAMES_MALE = _G.LOCALIZED_CLASS_NAMES_MALE or { DRUID = "Druid", HUNTER = "Hunter", WARRIOR = "Warrior" }
local statsFor = C_Item.statsFor
C_Item.statsFor = function(link)
  if link:match("item:226792:") then return { ITEM_MOD_AGILITY_SHORT = 20, ITEM_MOD_STAMINA_SHORT = 15 } end
  return statsFor and statsFor(link) or {}
end
local function tipFor(id)
  local out = {}
  local tip = { GetItem = function() return "item " .. id, "item:" .. id .. "::::::::60" end,
    AddLine = function(_, text) out[#out + 1] = text end }
  tooltipHook(tip, { id = id, lines = { { leftText = "item " .. id }, id == 226792 and { leftText = "Classes: Druid" } or nil } })
  return #out > 0 and table.concat(out, " | ") or "(no line)"
end
local other = ns.ItemTooltip.otherSpec(v.spec)
if not other then
  for _, s in ipairs(ns.Spec.specsOf(token)) do if s ~= v.spec and ns.Core.weightSetFor(s) then other = s break end end
  ns.cdb.groupSpec[2] = other
end
print("tooltip lines (active " .. tostring(v.spec) .. ", other group " .. tostring(other) .. "):")
for _, id in ipairs({ 226792, 13340, 15062, 13098, 11815, 999999, 13452, 16719, 16720 }) do
  shiftDown = false
  local plain = tipFor(id)
  shiftDown = true
  print(("  %6d %s\n         shift: %s"):format(id, plain, tipFor(id)))
end
shiftDown = false
ns.db.tooltip = false
print("  tooltip off: " .. tipFor(13340))
ns.db.tooltip = true
if ns.Core.lastError then print("ERROR: " .. tostring(ns.Core.lastError)) os.exit(1) end
-- Dock and fill the slot panel, as opening the character sheet does, and print its rows.
fire("PLAYER_LOGIN")
ns.SlotPanelUI.dock()
if ns.Core.lastError then print("ERROR: " .. tostring(ns.Core.lastError)) os.exit(1) end
local sp = ns.SlotPanel.build(v)
print("slot panel: " .. tostring(sp.badge) .. (sp.note and (" · " .. sp.note) or ""))
for _, r in ipairs(sp.rows) do
  print(string.format("  %-9s %-40s %s %s", r.label, r.bisText, r.pctText, r.gainText))
end
local sel = sp.rows[1] and ns.SlotPanel.defaultSlot(sp.rows)
for _, r in ipairs(sp.rows) do
  if r.inv == sel then for _, l in ipairs(ns.SlotPanel.detail(r)) do print("    " .. l.text) end end
end
-- PREPPED_PICKS="7=15062,10=15063": your picks, set the way /prep pick sets them, then the panel again.
if os.getenv("PREPPED_PICKS") then
  for inv, id in os.getenv("PREPPED_PICKS"):gmatch("(%d+)=(%d+)") do
    ns.UI.pick(ns.UI.slotKey(tonumber(inv)) .. " |cff1eff00|Hitem:" .. id .. "::::::::60:::::|h[x]|h|r")
  end
  ns.UI.pick("head 999999") -- unknown item: refused
  ns.UI.pick("legs 13340")  -- wrong slot: refused
  runTimers()
  if ns.Core.lastError then print("ERROR: " .. tostring(ns.Core.lastError)) os.exit(1) end
  v = ns.Core.view
  print("readiness with picks: " .. string.format("%.1f%%", (v.readiness.pct or 0) * 100))
  sp = ns.SlotPanel.build(v)
  for _, r in ipairs(sp.rows) do
    if r.pinned then
      print(string.format("  %-9s %-40s %s %s", r.label, r.bisText, r.pctText, r.gainText))
      for _, l in ipairs(ns.SlotPanel.detail(r)) do print("    " .. l.text) end
    end
  end
  for setID, st in pairs(v.slotData.bis.sets or {}) do print("  set " .. setID .. ": " .. st.count .. " pieces, " .. string.format("%.1f", st.points)) end
  local list, auto = ns.Core.pickChoices(v.spec, 7, 5)
  print("pick menu, legs (auto " .. tostring(auto) .. "):")
  for _, c in ipairs(list) do print(string.format("  %6d %-34s %.0f%%", c.id, c.name, (c.share or 0) * 100)) end
  ns.UI.pick("")
end
-- Sheet sync block (Watch.lua), as sync_sheet.py reads it.
local sync = ns.cdb.sync
if not sync then print("ERROR: no sync block written") os.exit(1) end
local keys = {}
for k, r in pairs(sync.ready) do
  local en = 0 for _ in pairs(sync.enchants[k] or {}) do en = en + 1 end
  keys[#keys + 1] = string.format("%s gear %.3f ench %.3f cons %.3f total %.3f, %d slots, %d enchants", k, r.gear, r.ench, r.cons,
    r.total, #(sync.slots[k] or {}), en)
end
table.sort(keys)
print("sync: spec " .. sync.spec .. ", " .. #sync.owned .. " owned BiS items")
for _, l in ipairs(keys) do print("  sync " .. l) end

-- Loot alert: a BiS item you don't own in the loot window and up for roll, then junk (no line).
local target
for _, st in ipairs(v.readiness and v.readiness.steps or {}) do
  if st.id and not ns.Core.owns(st.id) then target = st.id break end
end
ns.db.lootAlert = true
if target then
  _G.GetNumLootItems = function() return 2 end
  _G.GetLootSlotLink = function(i) return i == 1 and ("item:" .. target) or "item:2589" end
  _G.GetLootRollItemLink = function() return "item:" .. target end
  fire("LOOT_OPENED")
  GetTime = function() return os.clock() + 60 end -- past the 30-second repeat guard
  fire("START_LOOT_ROLL", 1)
else
  print("loot alert: no unowned BiS item to try")
end
ns.db.lootAlert = false

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
