-- Consumable plan: which consumables one raid night calls for, how many it needs, how many the
-- player has, and the points that earns. Points come from the injected `score(stats)`.
local _, ns = ...
local Consumables = {}
ns.Consumables = Consumables

-- Families that hold one consumable at a time.
local SINGLE = { "flask", "food", "weapon" }

local function newRow(entry, slot, opts)
  local row = { slot = slot, item = entry, have = 0, points = 0, max = 0, need = 0 }
  if opts.auras then
    -- In a raid: the buff is up or it isn't; an unreadable one is left out of the score.
    local up = opts.auras[entry.id]
    if up == "unknown" then
      row.unknown = true
    else
      row.need, row.have = 1, up and 1 or 0
      row.max = opts.score(entry.stats)
      row.points = row.max * row.have
    end
  else
    row.need = math.ceil(opts.raidHours * 3600 / entry.duration)
    row.have = opts.stock[entry.id] or 0
    row.max = opts.score(entry.stats)
    row.points = row.max * math.min(row.have, row.need) / row.need
  end
  return row
end

-- Whether the player's Obtainable filters leave this entry out of the defaults.
local function excluded(e, opts)
  return e.source ~= nil and opts.filters ~= nil and opts.filters[e.source] == true
end

-- The best entry of a single family, or the player's pick ("none" = nothing).
local function single(family, opts)
  local pick = opts.picks and opts.picks[family]
  if pick == "none" then return nil end
  local target, best
  for _, e in ipairs(opts.catalog) do
    if e.family == family then
      if e.id == pick then return e end
      local pts = opts.score(e.stats)
      if not excluded(e, opts) and (not best or pts > best) then target, best = e, pts end
    end
  end
  return target
end

-- Crit from two buffs may not both count on Forever (untested); opts.critStacks says it does.
local CRIT = { MeleeCrit = true, SpellCrit = true }

-- The stats a buff claims: its own `claims` list when the catalog gives one (a health buff scores
-- as Stamina but blocks only health), else every stat it raises; crit is left out when crit stacks.
local function claims(e, opts)
  local out = {}
  local keys = e.claims
  if not keys then
    keys = {}
    for k in pairs(e.stats) do keys[#keys + 1] = k end
  end
  for _, k in ipairs(keys) do if not (opts.critStacks and CRIT[k]) then out[#out + 1] = k end end
  return out
end
Consumables.claims = claims

local function overlaps(keys, used)
  for _, k in ipairs(keys) do if used[k] then return true end end
  return false
end

-- Buffs: one per stat, so two buffs that share any stat never both count. Returns the combination
-- worth the most points, searched exhaustively (a handful of candidates score for any one spec).
-- Picks by stat: a picked buff is planned first and its stats are taken; "none" blocks a stat.
local function picked(opts)
  local forced, used, isFamily = {}, {}, {}
  for _, f in ipairs(SINGLE) do isFamily[f] = true end
  for key, pick in pairs(opts.picks or {}) do
    if not isFamily[key] then
      if pick == "none" then
        used[key] = true
      else
        for _, e in ipairs(opts.catalog) do
          if e.id == pick and e.family == "buff" and not forced[e] then
            forced[e] = true
            forced[#forced + 1] = e
            for _, k in ipairs(claims(e, opts)) do used[k] = true end
          end
        end
      end
    end
  end
  return forced, used
end

local function bestBuffs(opts)
  local forced, used = picked(opts)
  local cands = {}
  for _, e in ipairs(opts.catalog) do
    if e.family == "buff" and not forced[e] and not excluded(e, opts) then
      local pts, keys = opts.score(e.stats), claims(e, opts)
      if pts > 0 and not overlaps(keys, used) then cands[#cands + 1] = { e = e, pts = pts, keys = keys } end
    end
  end
  table.sort(cands, function(a, b) return a.pts > b.pts end)
  -- rest[i] = the points of candidates i.. together: no combination from i on can beat that.
  local rest = { [#cands + 1] = 0 }
  for i = #cands, 1, -1 do rest[i] = rest[i + 1] + cands[i].pts end
  local best, bestPts, chosen = {}, 0, {}
  local function search(i, total)
    if total > bestPts then
      bestPts, best = total, {}
      for j, e in ipairs(chosen) do best[j] = e end
    end
    if i > #cands or total + rest[i] <= bestPts then return end
    local c = cands[i]
    if not overlaps(c.keys, used) then
      for _, k in ipairs(c.keys) do used[k] = true end
      chosen[#chosen + 1] = c.e
      search(i + 1, total + c.pts)
      chosen[#chosen] = nil
      for _, k in ipairs(c.keys) do used[k] = nil end
    end
    search(i + 1, total)
  end
  search(1, 0)
  for i, e in ipairs(forced) do table.insert(best, i, e) end
  return best
end

-- opts: catalog (entries: id, name, family, stats, duration, claims?, perNight? for potions), score (stats -> points),
-- stock ({[itemID] = count}), raidHours, filters ({[source] = true}: left out of defaults), picks ({[family or stat] = itemID | "none"}),
-- auras ({[itemID] = true | false | "unknown"}: inside a raid), critStacks (two buffs' crit both count).
-- Returns { rows = { slot, item, have, need, points, max, unknown? }, have, bis }.
function Consumables.plan(opts)
  local plan = { rows = {}, have = 0, bis = 0 }
  local function add(row)
    plan.rows[#plan.rows + 1] = row
    plan.have = plan.have + row.points
    plan.bis = plan.bis + row.max
  end
  for _, family in ipairs(SINGLE) do
    local e = single(family, opts)
    if e then add(newRow(e, family, opts)) end
  end
  for _, e in ipairs(bestBuffs(opts)) do add(newRow(e, "buff", opts)) end
  -- Potions: stock only (a shared cooldown, not a buff), so a count per night and no points.
  for _, e in ipairs(opts.catalog) do
    if e.family == "potion" then
      add({ slot = "potion", item = e, need = e.perNight, have = opts.stock[e.id] or 0, points = 0, max = 0 })
    end
  end
  return plan
end
