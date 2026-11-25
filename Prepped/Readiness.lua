-- Readiness score: gear, enchants and consumables in one unit (score points for the spec),
-- against the same total at full BiS.
local _, ns = ...
local Readiness = {}
ns.Readiness = Readiness

local PARTS = { "gear", "enchants", "consumables" }

-- A slot's enchant goes on the slot's BiS item, so it waits until after that item's step: each
-- enchant step that would come first moves to just after it. Other steps keep their order.
local function enchantsAfterGear(steps)
  local out = {}
  local held = {} -- [inv] = enchant steps waiting for that slot's gear
  local gearAt = {}
  for _, s in ipairs(steps) do if s.kind == "gear" and s.inv then gearAt[s.inv] = true end end
  for _, s in ipairs(steps) do
    if s.kind == "enchant" and s.inv and gearAt[s.inv] then
      held[s.inv] = held[s.inv] or {}
      table.insert(held[s.inv], s)
    else
      out[#out + 1] = s
      if s.kind == "gear" and s.inv and held[s.inv] then
        for _, e in ipairs(held[s.inv]) do out[#out + 1] = e end
        held[s.inv] = nil
      end
      if s.kind == "gear" and s.inv then gearAt[s.inv] = nil end
    end
  end
  return out
end

-- steps: optional list of { label, gain, id?, inv?, kind? } with gain in score points (id: the item,
-- if any; inv + kind "gear"/"enchant": which slot it is for, so an enchant follows its slot's item).
function Readiness.compute(parts, steps)
  local result, have, bis = {}, 0, 0
  for _, name in ipairs(PARTS) do
    local p = parts[name]
    have = have + p.have
    bis = bis + p.bis
    if p.bis > 0 then result[name] = p.have / p.bis end
  end

  result.steps = {}
  if bis <= 0 then return result end -- nothing scored: no number at all
  result.pct = have / bis

  for i, s in ipairs(steps or {}) do
    result.steps[i] = { label = s.label, gain = s.gain / bis, id = s.id, inv = s.inv, kind = s.kind }
  end
  table.sort(result.steps, function(a, b) return a.gain > b.gain end)
  result.steps = enchantsAfterGear(result.steps)
  result.next = result.steps[1]
  return result
end
