-- Equip best: the moves that turn what you wear into the best outfit from what you own. Pure: Core
-- picks the outfit (Bis.pick over your bags and worn gear), Equip.lua makes the moves.
local _, ns = ...
local Outfit = {}
ns.Outfit = Outfit

local SINGLE = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 15, 18 }
local PAIRS = { { 11, 12 }, { 13, 14 } }

-- best: Bis.pick's result ({[inv] = { id = key, item }}), keys as in worn ({[inv] = key}). Returns the
-- moves in order, { { inv, key } }: only slots whose best isn't already worn there and scores above 0
-- for the spec, never one that would empty a slot. A ring or trinket you already wear in either slot of its pair stays put.
-- A two-hander is one move (the game takes off the off hand); a pair goes main hand first.
function Outfit.plan(best, worn)
  local moves = {}
  local function move(inv, key) moves[#moves + 1] = { inv = inv, key = key } end
  local function worth(b) return b and (b.points or 0) > 0 end
  for _, inv in ipairs(SINGLE) do
    local b = best[inv]
    if worth(b) and b.id ~= worn[inv] then move(inv, b.id) end
  end
  for _, pair in ipairs(PAIRS) do
    local chosen, kept, free = {}, {}, {}
    for _, inv in ipairs(pair) do if worth(best[inv]) then chosen[#chosen + 1] = best[inv].id end end
    for _, inv in ipairs(pair) do
      local keep = false
      for _, key in ipairs(chosen) do if worn[inv] == key and not kept[key] then kept[key], keep = true, true; break end end
      if not keep then free[#free + 1] = inv end
    end
    for _, key in ipairs(chosen) do
      if not kept[key] then move(table.remove(free, 1), key) end
    end
  end
  local main, off = best[16], best[17]
  if worth(main) and main.id ~= worn[16] then move(16, main.id) end
  if worth(off) and off.id ~= worn[17] then move(17, off.id) end
  return moves
end
