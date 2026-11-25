-- Loot alert: one chat line when an item that is BiS for one of your specs drops or comes up for roll.
-- The rule is BiS for the active spec or another talent group's spec, and still worth something: an
-- upgrade test would need a score for every random drop, while BiS is what the tracker already names.
-- Pure: Watch.lua reads the loot window and rolls and passes the IDs in.
local _, ns = ...
local Loot = {}
ns.Loot = Loot

function Loot.itemID(link)
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function gainText(g)
  if g < 0.0005 then return "+<0.1% readiness" end
  return string.format("+%.1f%% readiness", g * 100)
end

-- specs: list, active first, of { label, bis = {[id] = true}, gains = {[id] = share of readiness} or nil
-- when that spec hasn't been measured yet }. A BiS item missing from a measured spec's gains is
-- already worn (or matched), so that spec says nothing. how: "roll" or nil (looted).
-- Returns the line to print, or nil.
function Loot.message(id, link, specs, owned, how)
  if not id or owned then return nil end
  local parts = {}
  for _, s in ipairs(specs) do
    if s.bis[id] then
      if not s.gains then
        parts[#parts + 1] = s.label .. " (gain not measured yet)"
      elseif (s.gains[id] or 0) > 0 then
        parts[#parts + 1] = s.label .. " (" .. gainText(s.gains[id]) .. ")"
      end
    end
  end
  if #parts == 0 then return nil end
  return link .. (how == "roll" and " up for roll" or " dropped") .. ": BiS for " .. table.concat(parts, ", ")
end

-- A tier 0.5 hand-in that dropped: the BiS pieces it leads to (targets, names) and its quest
-- (TradeIns data: quest, turnIn). nil when there's no quest or nothing left to make with it.
function Loot.handInMessage(link, q, targets, how)
  if not q or not targets or #targets == 0 then return nil end
  return link .. (how == "roll" and " up for roll" or " dropped") .. ": hand-in for " .. table.concat(targets, ", ")
    .. " (" .. q.quest .. ", " .. q.turnIn .. ")"
end

-- The specs to check: the active one first, then each talent group's chosen spec, once each.
function Loot.knownSpecs(active, groupSpec)
  local out, seen = {}, {}
  local function add(s) if s and not seen[s] then seen[s] = true; out[#out + 1] = s end end
  add(active)
  local groups = {}
  for g in pairs(groupSpec or {}) do groups[#groups + 1] = g end
  table.sort(groups)
  for _, g in ipairs(groups) do add(groupSpec[g]) end
  return out
end

-- Item gains out of Readiness steps (already shares of readiness), kept per spec between plays.
function Loot.gainsFrom(steps)
  local out = {}
  for _, s in ipairs(steps or {}) do if s.id then out[s.id] = s.gain end end
  return out
end

-- Once per item per 30 seconds: a loot window reopened or a roll and its loot window together.
function Loot.fresh(seen, id, now)
  if seen[id] and now - seen[id] < 30 then return false end
  seen[id] = now
  return true
end
