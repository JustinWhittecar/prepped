-- Buff reminders: which consumables the buff bar asks for right now.
-- Pure: works from Consumables.plan's raid-mode slots (have 1 = buff up, 0 = missing).
local _, ns = ...
local Buffs = {}
ns.Buffs = Buffs

-- opts: instance ("raid" | "party" | "none"), slots (Consumables.plan slots read from auras),
-- stock ({[itemID] = count in bags}), inCombat, mode: the bar's setting, "never", "instances" (the
-- default: raids and 5-player dungeons) or "always" (anywhere). Never in combat, and never a flask in
-- a 5-player dungeon. Returns a list of { slot, item, bags } in slot order.
local INSTANCES = { raid = true, party = true }
function Buffs.missing(opts)
  local out = {}
  local mode = opts.mode or "instances"
  if opts.inCombat or mode == "never" or (mode ~= "always" and not INSTANCES[opts.instance]) then return out end
  for _, s in ipairs(opts.slots) do
    -- Potions are counted as stock, never reminded; an unreadable buff is unknown and triggers nothing.
    local wanted = s.slot ~= "potion" and not s.unknown and not (s.slot == "flask" and opts.instance == "party")
    if wanted and s.item and s.have == 0 then out[#out + 1] = { slot = s.slot, item = s.item, bags = opts.stock[s.item.id] or 0 } end
  end
  return out
end
