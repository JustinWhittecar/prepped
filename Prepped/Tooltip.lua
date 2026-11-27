-- Tooltip: the one line Prepped adds to an item's tooltip, worked out the way gearPart counts gear.
-- "% of BiS" is the item's points over its slot's BiS points; "+N% readiness" is what replacing the
-- worn item would add to readiness, with each slot group capped at BiS as the score caps it.
local _, ns = ...
local Tooltip = {}
ns.Tooltip = Tooltip

local SINGLE = {
  INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
  INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
  INVTYPE_CLOAK = 15, INVTYPE_RANGED = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_THROWN = 18, INVTYPE_RELIC = 18,
}
local PAIR = { INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 } }
local PARTNER = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }
local MAIN_HAND = { INVTYPE_WEAPONMAINHAND = true }
local OFF_HAND = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true }

-- The inventory slots an equip location can go in, or nil for anything that isn't scored gear
-- (shirts, tabards, bags). A one-hander goes in the off hand too for a dual wielder.
function Tooltip.placesFor(loc, dualWield)
  if SINGLE[loc] then return { { inv = SINGLE[loc] } } end
  if PAIR[loc] then return { { inv = PAIR[loc][1] }, { inv = PAIR[loc][2] } } end
  if loc == "INVTYPE_2HWEAPON" then return { { inv = 16, twoHand = true } } end
  if MAIN_HAND[loc] then return { { inv = 16 } } end
  if OFF_HAND[loc] then return { { inv = 17, offHand = true } } end
  if loc == "INVTYPE_WEAPON" then
    if dualWield then return { { inv = 16 }, { inv = 17, offHand = true } } end
    return { { inv = 16 } }
  end
  return nil
end

local function n(v) return v or 0 end

-- What one place is worth against BiS: { pct, delta } in the spec's points, or nil with no BiS there.
-- opts.bis and opts.worn are points per inventory slot; wornTwoHand says slot 16 holds a two-hander.
local function place(opts, pl)
  local bis, worn, inv = opts.bis, opts.worn, pl.inv
  local p = pl.points
  if inv == 16 or inv == 17 then
    local bw = n(bis[16]) + n(bis[17])
    if bw <= 0 then return nil end
    local ref
    if pl.twoHand then ref = bw
    elseif inv == 17 and n(bis[17]) > 0 then ref = bis[17]
    else ref = n(bis[16]) end -- a one-hander against a two-hand BiS: against the two-hander
    local new
    if pl.twoHand then new = p
    elseif opts.wornTwoHand then new = p -- either hand displaces the worn two-hander
    else new = p + n(worn[inv == 16 and 17 or 16]) end
    local old = n(worn[16]) + n(worn[17])
    return ref > 0 and p / ref or nil, math.min(new, bw) - math.min(old, bw)
  end
  local other = PARTNER[inv]
  if other then
    local a, b = bis[inv], bis[other]
    if not (a or b) then return nil end
    local bp = n(a) + n(b)
    -- The weaker BiS piece is the bar an item has to reach to belong in the pair.
    local ref = (a and b) and math.min(a, b) or (a or b)
    -- A BiS piece itself is measured against its own points.
    local ids = opts.bisIDs or {}
    if opts.id and ids[inv] == opts.id then ref = n(a) elseif opts.id and ids[other] == opts.id then ref = n(b) end
    local old = n(worn[inv]) + n(worn[other])
    return ref > 0 and p / ref or nil, math.min(p + n(worn[other]), bp) - math.min(old, bp)
  end
  local b = bis[inv]
  if not b then return nil end
  return b > 0 and p / b or nil, math.min(p, b) - math.min(n(worn[inv]), b)
end

-- opts: places ({ inv, points, twoHand?, offHand?, worn?, setGain? }: where the item can go, its
-- points there, whether it is the item worn there, and the set bonus points equipping it there adds
-- or loses), bis and worn ({[inv] = points}), wornTwoHand, total (readiness points at full BiS),
-- id and bisIDs ({[inv] = item ID}) so a BiS ring or trinket is measured against itself.
-- Returns { pct, gain (fraction of readiness, nil unless an upgrade), inv, worn } for the best place,
-- or nil when the spec has no BiS for the slot.
function Tooltip.evaluate(opts)
  local best
  for _, pl in ipairs(opts.places or {}) do
    local pct, delta = place(opts, pl)
    if pct or delta then
      if pl.worn then delta = 0 end
      delta = delta + (pl.worn and 0 or n(pl.setGain))
      if not best or delta > best.delta then best = { pct = pct, delta = delta, inv = pl.inv, worn = pl.worn } end
    end
  end
  if not best then return nil end
  local total = n(opts.total)
  if best.delta > 0 and total > 0 then best.gain = best.delta / total end
  best.delta = nil
  return best
end

local function pctText(x)
  if x >= 0.01 then return string.format("%d%%", math.floor(x * 100 + 0.5)) end
  return string.format("%.1f%%", x * 100)
end

-- Whether an item is an upgrade on what you wear: a readiness gain big enough for the line to show it.
-- The tooltip's arrow and the bag icons' arrow both use this.
local SHOWN_GAIN = 0.0005
function Tooltip.isUpgrade(r)
  return type(r) == "table" and not r.worn and r.gain ~= nil and r.gain >= SHOWN_GAIN
end

-- The tooltip text. label: a spec's short name, for the other spec's line; nil for the active one.
-- r: Tooltip.evaluate's result, or nil for an item Prepped can't score. arrow: put before an upgrade's line.
function Tooltip.line(label, r, arrow)
  local who = label and (" (" .. label .. ")") or ""
  if not r or not r.pct then return "Not scored by Prepped" .. who end
  local s = "Prepped" .. who .. ": " .. string.format("%d%%", math.floor(math.max(r.pct, 0) * 100 + 0.5)) .. " of BiS"
  if r.worn then
    s = s .. " · worn"
  elseif Tooltip.isUpgrade(r) then
    s = s .. " · +" .. pctText(r.gain) .. " readiness"
    if arrow then s = arrow .. s end
  end
  return s
end
