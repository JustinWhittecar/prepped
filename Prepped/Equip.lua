-- Equip best: puts on the best outfit from your bags for the spec Prepped is scoring (Core.bestOwned),
-- one item at a time. Out of combat only; bind-on-equip items are left in the bags.
local _, ns = ...
local Equip = {}
ns.Equip = Equip
local Core = ns.Core

local STEP = 0.3 -- seconds between moves, so each swap lands before the next (a two-hander frees the off hand)
local running

local function names(list) return table.concat(list, ", ") end

function Equip.best()
  if running then return end
  if InCombatLockdown() then Core.print("equip best: not in combat"); return end
  local spec = Core.view and Core.view.spec
  local plan = spec and Core.bestOwned(spec)
  if not plan then Core.print("equip best: nothing to score this spec with yet"); return end
  local specName = ns.Spec.NAME[spec] or spec
  local skippedNote = #plan.skipped > 0
    and (" Left in your bags (equipping binds them): " .. names(plan.skipped) .. ".") or ""
  if #plan.moves == 0 then
    Core.print("equip best: you're already wearing your best gear for " .. specName .. "." .. skippedNote)
    return
  end
  running = true
  local done, i = {}, 0
  local function step()
    i = i + 1
    local m = plan.moves[i]
    if not m then
      running = false
      Core.print("equip best (" .. specName .. "): " .. names(done) .. "." .. skippedNote)
      return
    end
    if InCombatLockdown() then
      running = false
      Core.print("equip best: stopped by combat" .. (#done > 0 and (" after " .. names(done)) or "") .. ".")
      return
    end
    EquipItemByName(m.link, m.inv)
    done[#done + 1] = m.name or m.link
    C_Timer.After(STEP, step)
  end
  step()
end
