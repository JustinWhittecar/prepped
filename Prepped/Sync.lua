-- Sheet sync: the block Raid Ready writes to RaidReadyCharDB.sync, built from Prepped's numbers and
-- written to PreppedCharDB.sync, so the author's sync_sheet.py reads it the same way. Pure: Watch.lua
-- measures the specs and passes the parts in.
local _, ns = ...
local Sync = {}
ns.Sync = Sync

-- The sheet's spec names are Raid Ready's.
local SPEC_KEY = { FERAL_CAT = "cat", FERAL_BEAR = "bear" }
function Sync.specKey(spec) return SPEC_KEY[spec] or spec:lower() end

-- Raid Ready has one weapon row, mainhand (sync_sheet.py ticks it as ench-<spec>-weapon).
local ENCHANT_KEY = { weapon = "mainhand", twohand = "mainhand" }

local function pct(f) return math.floor((f or 0) * 1000 + 0.5) / 10 end

local function ready(r)
  return { gear = r.gear or 0, ench = r.enchants or 0, cons = r.consumables or 0, total = r.pct or 0 }
end

local function slots(list)
  local out = {}
  for i, s in ipairs(list or {}) do out[i] = { slot = s.slot, id = s.id or 0, pct = pct(s.pct) } end
  return out
end

local function enchants(list)
  local out = {}
  for _, e in ipairs(list or {}) do
    local key = ENCHANT_KEY[e.key] or e.key
    if not out[key] then out[key] = { pct = pct(e.pct), enchanted = e.enchanted == true, text = e.text, link = e.link } end
  end
  return out
end

-- Raid Ready's slot rows, in its order and with its labels (smoke.lua reads them back as worn gear).
local ROWS = { { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 15, "Back" }, { 5, "Chest" }, { 9, "Wrist" },
  { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" }, { 11, "Finger 1" }, { 12, "Finger 2" },
  { 13, "Trinket 1" }, { 14, "Trinket 2" }, { 16, "Main Hand" }, { 17, "Off Hand" }, { 18, "Ranged" } }

-- worn, bis: {[inv] = { id, points }}. Each row: the item worn (0 = none) and its points as a share of
-- the slot's BiS, capped at 1. relic: call slot 18 "Relic", as Raid Ready's druid rows do.
function Sync.slotRows(worn, bis, relic)
  worn = setmetatable({}, { __index = worn })
  -- A ring or trinket that is the other slot's BiS goes on that slot's row.
  for _, p in ipairs({ { 11, 12 }, { 13, 14 } }) do
    local a, b = p[1], p[2]
    local wa, wb, ba, bb = worn[a], worn[b], bis[a], bis[b]
    if (wa and bb and wa.id == bb.id) or (wb and ba and wb.id == ba.id) then worn[a], worn[b] = wb, wa end
  end
  local out = {}
  for _, r in ipairs(ROWS) do
    local inv, label = r[1], r[2]
    local w, t = worn[inv], bis[inv]
    if inv ~= 17 or w or t then
      local share = 0
      if w and t and w.id == t.id then
        share = 1
      elseif w and t and t.points > 0 then
        share = math.min(w.points / t.points, 1)
      end
      out[#out + 1] = { slot = (inv == 18 and relic) and "Relic" or label, id = w and w.id or 0, pct = share }
    end
  end
  return out
end

-- The known specs to measure now: the active one always (worn gear is its gear), any other only when
-- the last block has nothing for it. Raid Ready judged the other spec on the best gear you own;
-- Prepped keeps what it measured when you last played it.
function Sync.toMeasure(active, specs, previous)
  local out = {}
  for _, s in ipairs(specs) do
    if s == active or not (previous and previous.ready and previous.ready[Sync.specKey(s)]) then out[#out + 1] = s end
  end
  return out
end

-- opts: at (time()), spec (active SimGear spec), specs (known specs), measured ({[spec] = { readiness =
-- Readiness.compute's result, slots = { slot, id, pct }, enchants = { key, pct, enchanted, text?, link? } }}),
-- cons ({[spec] = {[itemID] = bags + bank}}), owned ({[itemID] = true}), previous (the last block).
function Sync.build(opts)
  local s = { at = opts.at, spec = Sync.specKey(opts.spec), owned = {}, ready = {}, slots = {}, enchants = {}, cons = {} }
  for id in pairs(opts.owned or {}) do s.owned[#s.owned + 1] = id end
  table.sort(s.owned)
  local prev = opts.previous or {}
  for _, spec in ipairs(opts.specs) do
    local key, m = Sync.specKey(spec), opts.measured[spec]
    if m then
      s.ready[key], s.slots[key], s.enchants[key] = ready(m.readiness or {}), slots(m.slots), enchants(m.enchants)
    elseif prev.ready and prev.ready[key] then
      s.ready[key] = prev.ready[key]
      s.slots[key] = prev.slots and prev.slots[key] or {}
      s.enchants[key] = prev.enchants and prev.enchants[key] or {}
    end
    s.cons[key] = (opts.cons or {})[spec] or {}
  end
  return s
end
