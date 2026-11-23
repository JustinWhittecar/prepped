-- Readiness score: gear, enchants and consumables in one unit (score points for the spec),
-- against the same total at full BiS.
local _, ns = ...
local Readiness = {}
ns.Readiness = Readiness

local PARTS = { "gear", "enchants", "consumables" }

-- steps: optional list of { label, gain } with gain in score points.
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
    result.steps[i] = { label = s.label, gain = s.gain / bis }
  end
  table.sort(result.steps, function(a, b) return a.gain > b.gain end)
  result.next = result.steps[1]
  return result
end
