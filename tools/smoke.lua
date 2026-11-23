-- Smoke run: loads Prepped in .toc order against stubbed WoW API calls and real SimGear class data,
-- fires the load events and prints what the tracker would show. A load check for the glue
-- (Core.lua, UI.lua), not a test: it catches nil errors and wiring mistakes before the game does.
--   luajit tools/smoke.lua [Class] [RaidReady.lua saved variables, for worn item IDs] [raid]
local T = dofile("test/lib.lua")
local class = arg[1] or "Druid"
local token = class:upper()
local svPath = arg[2]
local raidMode = arg[3] == "raid"

_G.SimGearForeverData = T.simgearGlobal(class)
local data = SimGearForeverData[token]

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
end

-- A frame stub: every method is a no-op unless listed here.
local timers = {}
local frames = {}
local function stub()
  local o = { scripts = {}, shown = false }
  return setmetatable(o, { __index = function(t, k)
    if k == "SetScript" then return function(self, name, fn) self.scripts[name] = fn end end
    if k == "GetStringWidth" or k == "GetWidth" then return function() return 40 end end
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
_G.C_Item = {
  GetItemCount = function(id) return bags[id] or 0 end,
  GetItemInfoInstant = function(link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    local it = data.items.items[id]
    return id, nil, nil, it and it.slot
  end,
  GetItemNameByID = function(id) local it = data.items.items[id]; return it and it.name end,
  GetItemSpell = function() return nil end,
  GetItemStats = function() return {} end,
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
fire("PLAYER_ENTERING_WORLD")
runTimers()

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
