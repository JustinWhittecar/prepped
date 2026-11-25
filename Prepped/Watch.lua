-- Glue for the loot alert (Loot.lua) and the sheet sync block (Sync.lua): game events and Core's
-- refreshes in, one chat line or PreppedCharDB.sync out. The logic is in the pure files.
local ADDON, ns = ...
local Core, Loot, Sync = ns.Core, ns.Loot, ns.Sync

local function knownSpecs()
  return Loot.knownSpecs((Core.spec()), ns.cdb.groupSpec)
end

-- After every refresh, as Raid Ready writes its block on every refresh: the active spec measured on
-- what you wear, its item gains kept for the loot alert, and the sync block written.
local function onRefresh()
  if not ns.cdb then return end
  local active = Core.spec()
  if not active then return end
  local specs = knownSpecs()
  local prev = ns.cdb.sync
  local measured, cons, owned = {}, {}, {}
  for _, spec in ipairs(Sync.toMeasure(active, specs, prev)) do measured[spec] = Core.measure(spec) end
  ns.cdb.lootGains = ns.cdb.lootGains or {}
  if measured[active] then ns.cdb.lootGains[active] = Loot.gainsFrom(measured[active].readiness.steps) end
  for _, spec in ipairs(specs) do
    -- Counts and BiS for a carried-over spec are cheap to redo; its gear numbers are not redone on worn gear.
    local m = measured[spec] or Core.measure(spec)
    if m then
      cons[spec] = m.cons
      for id in pairs(m.bis) do if Core.owns(id) then owned[id] = true end end
    end
  end
  ns.cdb.sync = Sync.build({ at = time(), spec = active, specs = specs, measured = measured, cons = cons,
    owned = owned, previous = prev })
end
table.insert(Core.listeners, function()
  local ok, err = pcall(onRefresh)
  if not ok then Core.lastError = err end
end)

-- Loot alert: off unless chosen (options window), chat only.
local seen = {}
local function alert(link, how)
  local id = Loot.itemID(link)
  if not id or not Loot.fresh(seen, id, GetTime()) then return end
  local list = {}
  for _, spec in ipairs(knownSpecs()) do
    local rep = Core.bisReport(spec)
    if rep then
      local bis = {}
      for _, b in pairs(rep.slots) do bis[b.id] = true end
      list[#list + 1] = { label = ns.Spec.SHORT[spec] or spec, bis = bis, gains = ns.cdb.lootGains and ns.cdb.lootGains[spec] }
    end
  end
  local msg = Loot.message(id, link, list, Core.owns(id), how)
  -- Not BiS itself, but a tier 0.5 hand-in for a BiS piece (a Wildheart Kilt in Stratholme).
  if not msg then
    local specs = knownSpecs()
    local q, targets = Core.handIn(id, specs, function(spec)
      local rep = Core.bisReport(spec)
      local ids = {}
      for inv, b in pairs(rep and rep.slots or {}) do ids[inv] = b.id end
      return ids
    end)
    -- Already holding enough of it (a second Wildheart Cowl): nothing to say.
    if q then
      for _, n in ipairs(Core.tradeInStatus(q).needs) do
        if n.id == id and n.have >= n.n then q = nil end
      end
    end
    msg = Loot.handInMessage(link, q, targets, how)
  end
  if msg then Core.print(msg) else seen[id] = nil end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, a1)
  if event == "ADDON_LOADED" then
    if a1 ~= ADDON then return end
    if ns.db.lootAlert == nil then ns.db.lootAlert = false end
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("START_LOOT_ROLL")
    return
  end
  if not (ns.db and ns.db.lootAlert) then return end
  if event == "LOOT_OPENED" then
    for i = 1, GetNumLootItems() do
      local link = GetLootSlotLink(i)
      if link then pcall(alert, link) end
    end
  elseif event == "START_LOOT_ROLL" then
    local link = GetLootRollItemLink(a1)
    if link then pcall(alert, link, "roll") end
  end
end)
