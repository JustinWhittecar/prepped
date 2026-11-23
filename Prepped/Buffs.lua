-- Buff reminders: which consumables the buff bar asks for right now.
-- Pure: works from Consumables.plan's raid-mode slots (have 1 = buff up, 0 = missing).
local _, ns = ...
local Buffs = {}
ns.Buffs = Buffs

-- opts: instance ("raid" | "party" | "none"), slots (Consumables.plan slots read from auras),
-- stock ({[itemID] = count in bags}), inCombat, dungeons (option: remind in 5-player dungeons).
-- Returns a list of { slot, item, bags } in slot order.
function Buffs.missing(opts)
  local out = {}
  if opts.inCombat then return out end
  local raid = opts.instance == "raid"
  if not raid and not (opts.instance == "party" and opts.dungeons) then return out end
  for _, s in ipairs(opts.slots) do
    -- A flask is for raids only; potions are counted as stock, never reminded;
    -- an unreadable buff is unknown and triggers nothing.
    local wanted = (raid or s.slot ~= "flask") and s.slot ~= "potion" and not s.unknown
    if wanted and s.item and s.have == 0 then out[#out + 1] = { slot = s.slot, item = s.item, bags = opts.stock[s.item.id] or 0 } end
  end
  return out
end
