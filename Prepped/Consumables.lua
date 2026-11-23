-- Consumable plan: per slot the target consumable, how many one raid night needs, how many
-- the player has, and the points that earns. Points come from the injected `score(stats)`.
local _, ns = ...
local Consumables = {}
ns.Consumables = Consumables

-- opts: catalog (list of entries), slots (the spec's slot names), score (stats -> points),
-- stock ({[itemID] = count}), raidHours.
function Consumables.plan(opts)
  local plan = { slots = {}, have = 0, bis = 0 }
  for i, slot in ipairs(opts.slots) do
    local override = opts.overrides and opts.overrides[slot]
    local target, best
    if override ~= "none" then
      for _, entry in ipairs(opts.catalog) do
        if entry.slot == slot then
          if entry.id == override then
            target, best = entry, math.huge -- an explicit pick wins, filters or not
          elseif not (entry.source and opts.filters and opts.filters[entry.source]) then
            local pts = opts.score(entry.stats)
            if not best or pts > best then target, best = entry, pts end
          end
        end
      end
    end
    local row = { slot = slot, item = target, have = 0, points = 0, max = 0, need = 0 }
    if target and opts.auras then
      -- In a raid: the buff is up or it isn't; an unreadable aura is left out of the score.
      local up = opts.auras[target.aura]
      if up == "unknown" then
        row.unknown = true
      else
        row.need, row.have = 1, up and 1 or 0
        row.max = opts.score(target.stats)
        row.points = row.max * row.have
      end
    elseif target then
      row.need = math.ceil(opts.raidHours * 3600 / target.duration)
      row.have = opts.stock[target.id] or 0
      row.max = opts.score(target.stats)
      row.points = row.max * math.min(row.have, row.need) / row.need
    end
    plan.slots[i] = row
    plan.have = plan.have + row.points
    plan.bis = plan.bis + row.max
  end
  return plan
end
