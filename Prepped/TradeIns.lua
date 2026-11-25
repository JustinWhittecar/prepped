-- TradeIns: tier 0.5 hand-ins. Forever's tier 0.5 pieces come from four quests per class (Deliana,
-- Ironforge / Mokvar, Orgrimmar), each taking dungeon set pieces and sometimes gold and samples.
-- data/TradeIns.lua (ns.TradeInData) lists them; this works out what a piece still needs. Pure.
local _, ns = ...
local TradeIns = {}
ns.TradeIns = TradeIns

local SAME = { INVTYPE_ROBE = "INVTYPE_CHEST" }

-- The quest that gives a class's tier 0.5 piece for an equip slot on a side, or nil.
function TradeIns.forSlot(data, token, faction, loc)
  loc = SAME[loc] or loc
  for _, q in ipairs((data or {})[token] or {}) do
    if q.faction == faction then
      for _, s in ipairs(q.slots) do if s == loc then return q end end
    end
  end
end

-- The quests on a side that take an item.
function TradeIns.usedFor(data, token, faction, id)
  local out = {}
  for _, q in ipairs((data or {})[token] or {}) do
    if q.faction == faction then
      for _, n in ipairs(q.needs) do if n.id == id then out[#out + 1] = q; break end end
    end
  end
  return out
end

local function needText(n) return (n.n > 1 and (n.n .. " ") or "") .. n.name end

function TradeIns.sourceText(q)
  local parts = {}
  for i, n in ipairs(q.needs) do parts[i] = needText(n) end
  if (q.money or 0) > 0 then parts[#parts + 1] = math.floor(q.money / 10000) .. "g" end
  return "Quest: " .. q.quest .. " (" .. q.turnIn .. ") · hand in " .. table.concat(parts, " + ")
end

-- count(id): how many you have (bags and bank). done: the quest is already done, so the pieces are
-- bought from the turn-in NPC instead. afterDone: the quest it follows (q.after) is done, so it is open.
-- Returns { quest, done, open, needs = { {id, name, n, have} }, missing, ready }.
function TradeIns.status(q, count, done, afterDone)
  local st = { quest = q, done = done and true or false, open = (not q.after) or afterDone and true or false, needs = {}, missing = {} }
  for i, n in ipairs(q.needs) do
    local have = done and n.n or math.min(count(n.id) or 0, n.n)
    st.needs[i] = { id = n.id, name = n.name, n = n.n, have = have }
    if have < n.n then st.missing[#st.missing + 1] = st.needs[i] end
  end
  st.ready = #st.missing == 0
  return st
end

-- The to-do text for a tier 0.5 piece you don't have.
function TradeIns.label(name, st)
  local q = st.quest
  if st.done then return name .. ": buy from " .. q.turnIn .. " (quest done)" end
  if st.ready and st.open then return name .. ": turn in " .. q.quest .. " (" .. q.turnIn .. ")" end
  if st.ready then return name .. ": hand-ins ready, " .. q.quest .. " opens after " .. q.after.quest end
  local parts = {}
  for i, n in ipairs(st.missing) do parts[i] = n.n > 1 and (n.name .. " " .. n.have .. "/" .. n.n) or n.name end
  return name .. ": need " .. table.concat(parts, ", ")
end

-- The tooltip line on a hand-in item. targets: names of the BiS pieces it leads to.
function TradeIns.tooltipLine(q, targets)
  local where = q.quest .. " (" .. q.turnIn .. ")"
  if targets and #targets > 0 then return "Prepped: hand in at " .. where .. " for " .. table.concat(targets, ", ") end
  return "Prepped: tier 0.5 hand-in for " .. where
end
