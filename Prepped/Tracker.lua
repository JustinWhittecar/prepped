-- Tracker view: the header and the ordered lines the tracker shows. Pure: no frames here;
-- the UI draws whatever this returns.
local _, ns = ...
local Tracker = {}
ns.Tracker = Tracker

local LEVEL = 60

-- A share (0..1) as a whole percent, half up.
local function pct(x) return math.floor(x * 100 + 0.5) .. "%" end

local function header(state)
  local parts = {}
  if state.inRaid and state.raidNow then parts[1] = "Raid now " .. pct(state.raidNow) end
  parts[#parts + 1] = state.prep and ("Prep " .. pct(state.prep)) or "Prep: not scored"
  if state.badge then parts[#parts + 1] = state.badge end
  return table.concat(parts, " · ")
end

local MAX_BLOCKERS = 3

local function addBlockers(lines, blockers)
  for i, b in ipairs(blockers or {}) do
    if i > MAX_BLOCKERS then
      lines[#lines + 1] = { kind = "more", text = "+" .. (#blockers - MAX_BLOCKERS) .. " more" }
      return
    end
    local text = b.text
    if b.total and b.total > 0 then
      text = text .. " (" .. b.done .. "/" .. b.total .. (b.next and (", next: " .. b.next) or "") .. ")"
    end
    lines[#lines + 1] = { kind = "blocker", text = text }
  end
end

local function addConsumables(lines, slots)
  for _, c in ipairs(slots or {}) do
    if c.item and not c.unknown and c.have < c.need then
      lines[#lines + 1] = { kind = "consumable", text = c.item.name .. " " .. c.have .. "/" .. c.need, itemID = c.item.id }
    end
  end
end

local MAX_GEAR = 8

-- A gain in readiness: "+3%", or "+<1%" when it rounds to nothing.
local function gainText(g)
  local whole = math.floor(g * 100 + 0.5)
  return whole < 1 and "+<1%" or ("+" .. whole .. "%")
end

local function addGear(lines, todos)
  for i, t in ipairs(todos or {}) do
    if i > MAX_GEAR then return end
    lines[#lines + 1] = { kind = "gear", text = t.label .. " (" .. gainText(t.gain) .. ")", itemID = t.id }
  end
end

-- state: level, prep (readiness 0..1 or nil), badge (data status), blockers (Attune.blockers),
-- consumables (Consumables.plan slots), todos (Readiness steps, biggest first),
-- inRaid + raidNow (readiness from active buffs), collapsed,
-- specChoices ({ { label, spec } } when the spec can't be detected).
-- Returns { header = string, lines = { { kind, text } } }.
function Tracker.lines(state)
  if (state.level or 0) < LEVEL then
    return { header = "Prepped: activates at 60", lines = {} }
  end
  local lines = {}
  -- Spec unclear: ask in the tracker, never a popup. Shown even collapsed, which is how it starts.
  if state.specChoices and not state.inRaid then
    lines[1] = { kind = "choose", text = "Choose spec:", buttons = state.specChoices }
  end
  -- In a raid the buff bar carries the message; collapsed (first run, or by the player) = header only.
  if state.inRaid or state.collapsed then return { header = header(state), lines = lines } end
  addBlockers(lines, state.blockers)
  addConsumables(lines, state.consumables)
  addGear(lines, state.todos)
  return { header = header(state), lines = lines }
end
