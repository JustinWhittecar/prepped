-- Slot panel view: one row per equipment slot (worn item against the spec's BiS) and the detail
-- lines for the selected slot. Pure: SlotPanelUI.lua draws whatever this returns.
local _, ns = ...
local SlotPanel = {}
ns.SlotPanel = SlotPanel

-- Paper-doll order: the left column, the right column, then the weapons.
SlotPanel.ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
SlotPanel.LABEL = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
  [9] = "Wrist", [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back",
  [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }

local LEVEL = 60
local STAR = "★"
local PICK = "⚑" -- your pick (SlotPanelUI draws it as a lock)
local NOT_SCORED = "Not scored by Prepped"

local function pct(x) return math.floor(x * 100 + 0.5) .. "%" end

-- A gain in readiness: "+3%", "+<1%" when it rounds to nothing, "" when there's none.
local function gainText(g)
  if not g or g <= 0 then return "" end
  local whole = math.floor(g * 100 + 0.5)
  return whole < 1 and "+<1%" or ("+" .. whole .. "%")
end

-- Sources --------------------------------------------------------------------------------------------
local KIND = { quest = "Quest", boss = "Boss", vendor = "Vendor", drop = "Drop", chest = "Chest" }

-- One source as text: Prepped's own ({ text }) as is, SimGear's records the way SimGear words them.
-- tradable: the item can be traded (not bound on pickup), so a craft can also be bought.
function SlotPanel.sourceText(src, tradable)
  if src.text then return src.text end
  if src.type == "crafted" then
    return "Crafted: " .. tostring(src.name) .. (src.skill and (" " .. src.skill) or "") .. (tradable and " · or Auction House" or "")
  end
  if src.type == "world" then return src.note or "World drop" end
  local text = (KIND[src.type] or tostring(src.type)) .. ": " .. (src.name or "dungeon mobs")
  local where = {}
  if src.zone then where[#where + 1] = src.zone end
  if src.type == "quest" and src.level then where[#where + 1] = "Lv" .. src.level end
  if src.origin == "lead" or src.unconfirmed then where[#where + 1] = "unconfirmed" end
  if #where > 0 then text = text .. " (" .. table.concat(where, ", ") .. ")" end
  if src.chance and src.chance > 0 then
    text = text .. (src.chance < 0.001 and " <0.1%" or string.format(" %.1f%%", src.chance * 100))
  end
  return text
end

-- An item's first two sources, then "+n more".
function SlotPanel.sourcesText(item, tradable)
  local srcs = type(item.sources) == "table" and item.sources or {}
  if #srcs == 0 then return "Source unknown" end
  local parts = {}
  for i = 1, math.min(2, #srcs) do parts[i] = SlotPanel.sourceText(srcs[i], tradable) end
  if #srcs > 2 then parts[#parts + 1] = "+" .. (#srcs - 2) .. " more" end
  return table.concat(parts, "; ")
end

-- Rows ------------------------------------------------------------------------------------------------
-- A ring or trinket pair: a worn BiS item keeps its target in whichever slot it sits, and the
-- other target goes to the other slot. Returns { [inv] = bis entry }.
local function pairTargets(a, c, bis, worn)
  local out, left = {}, {}
  for _, b in ipairs({ bis[a], bis[c] }) do left[#left + 1] = b end
  for _, inv in ipairs({ a, c }) do
    local w = worn[inv]
    for i, b in ipairs(left) do
      if w and b.id == w.id then out[inv] = b; table.remove(left, i); break end
    end
  end
  for _, inv in ipairs({ a, c }) do
    if not out[inv] then out[inv] = table.remove(left, 1) end
  end
  return out
end

-- bop: { [id] = true } for crafts bound on pickup, or nil when unknown.
local function row(inv, target, wornPts, w, total, auto, bop)
  local r = { inv = inv, label = SlotPanel.LABEL[inv], gainText = "", pctText = "" }
  if w then r.wornID, r.wornName, r.unread = w.id, w.name, w.unread end
  if not target then
    r.pctText, r.bisText = "No target", "No target for this slot"
    return r
  end
  r.bisID, r.bisName = target.id, target.item.name or ("item " .. target.id)
  r.isBis = w ~= nil and w.id == target.id
  r.pinned = target.locked or nil
  if r.pinned and auto and auto.id ~= target.id then r.autoName = auto.item.name or ("item " .. auto.id) end
  r.bisText = (r.isBis and (STAR .. " ") or "") .. (r.pinned and (PICK .. " ") or "") .. r.bisName
  r.source = SlotPanel.sourcesText(target.item, bop ~= nil and not bop[target.id])
  if w and w.unread then
    r.pctText = NOT_SCORED
    return r
  end
  -- A target that scores nothing for the spec gives no share to show.
  if target.points <= 0 then return r end
  local have = math.min(wornPts, target.points)
  r.pct = have / target.points
  r.pctText = pct(r.pct)
  if total and total > 0 then
    r.gain = (target.points - have) / total
    r.gainText = gainText(r.gain)
  end
  return r
end

-- view: Core.view. Its slotData = { bis = Bis.pick's result, worn = { [inv] = { id, name, points,
-- unread } }, total = readiness points at full BiS }. Returns { badge, spec, rows = { row per slot,
-- paper-doll order } }; no rows when there's no data to score with.
function SlotPanel.build(view)
  local state = view.state or {}
  local out = { badge = state.badge, spec = view.spec, rows = {} }
  -- Like the tracker: nothing to score against below 60.
  if state.level and state.level < LEVEL then out.note = "Prepped activates at 60"; return out end
  local sd = view.slotData
  if not sd then out.note = SlotPanel.badgeHelp(state.badge); return out end
  local bis, worn, total, auto = sd.bis or {}, sd.worn or {}, sd.total, sd.auto or {}
  local function pts(inv) return worn[inv] and worn[inv].points or 0 end
  local targets = {}
  for _, inv in ipairs({ 1, 2, 3, 5, 6, 7, 8, 9, 10, 15, 18 }) do targets[inv] = bis[inv] end
  for inv, b in pairs(pairTargets(11, 12, bis, worn)) do targets[inv] = b end
  for inv, b in pairs(pairTargets(13, 14, bis, worn)) do targets[inv] = b end
  local twoHand = bis[16] and not bis[17] and bis[16].item.slot == "INVTYPE_2HWEAPON"
  targets[16], targets[17] = bis[16], bis[17]
  for _, inv in ipairs(SlotPanel.ORDER) do
    local r
    if inv == 16 and twoHand then
      -- Against a two-hander, both worn hands count (as the gear score counts them).
      r = row(inv, targets[16], pts(16) + pts(17), worn[16], total, auto[16], sd.bop)
      if worn[17] and worn[17].unread then r.unread, r.pct, r.pctText, r.gain, r.gainText = true, nil, NOT_SCORED, nil, "" end
    elseif inv == 17 and twoHand then
      r = row(inv, nil, 0, worn[17], total)
      r.pctText, r.bisText = "", "Two-hander: see main hand"
    else
      r = row(inv, targets[inv], pts(inv), worn[inv], total, auto[inv], sd.bop)
    end
    out.rows[#out.rows + 1] = r
  end
  return out
end

-- The slot to show before any hover: the biggest gain, else the first row.
function SlotPanel.defaultSlot(rows)
  local best
  for _, r in ipairs(rows) do
    if r.gain and r.gain > 0 and (not best or r.gain > best.gain) then best = r end
  end
  best = best or rows[1]
  return best and best.inv
end

-- The selected slot's lines: { { kind = "title"|"worn"|"bis"|"gain"|"source", text } }.
function SlotPanel.detail(r)
  local lines = { { kind = "title", text = r.label } }
  local wornName = r.wornName or (r.wornID and ("item " .. r.wornID)) or "nothing"
  local target = r.pinned and "your pick" or "BiS"
  if r.isBis then
    lines[#lines + 1] = { kind = "worn", text = "Worn: " .. STAR .. " " .. wornName .. " (" .. target .. ")" }
    if r.autoName then lines[#lines + 1] = { kind = "bis", text = "Prepped's BiS: " .. r.autoName } end
  else
    local how = r.unread and NOT_SCORED or (r.pct and (r.pctText .. " of " .. target))
    lines[#lines + 1] = { kind = "worn", text = "Worn: " .. wornName .. (how and (" (" .. how .. ")") or "") }
    if r.pinned then
      lines[#lines + 1] = { kind = "bis", text = "Your pick: " .. r.bisName }
      if r.autoName then lines[#lines + 1] = { kind = "bis", text = "Prepped's BiS: " .. r.autoName } end
    else
      lines[#lines + 1] = { kind = "bis", text = r.bisName and ("BiS: " .. r.bisName) or r.bisText }
    end
    if r.gainText ~= "" then lines[#lines + 1] = { kind = "gain", text = "Upgrade: " .. r.gainText .. " readiness" } end
  end
  if r.source then lines[#lines + 1] = { kind = "source", text = "Source: " .. r.source } end
  return lines
end

-- What a data status badge means, for its hover.
function SlotPanel.badgeHelp(badge)
  if badge == "SimGear live" then return "Scores use SimGear Forever's data, read live." end
  if badge == "Estimated weights" then
    return "SimGear's weights for this spec are placeholders, not sims: treat the score as rough."
  end
  local date = badge and badge:match("^Snapshot (.+)$")
  if date then return "SimGear isn't loaded: scores use Prepped's saved copy of its data (" .. date .. ")." end
  if badge == "SimGear not installed" then return "Install SimGear Forever: Prepped scores gear with its data." end
  if badge == "No weights for this spec" then return "SimGear has no stat weights for this spec, so nothing is scored." end
  return "Something went wrong: /prep debug shows the error."
end

