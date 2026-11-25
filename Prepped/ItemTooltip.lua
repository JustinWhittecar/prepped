-- ItemTooltip: hooks the game's item tooltips and adds Prepped's one line (Tooltip.lua works it out).
-- The active spec always; the other talent group's spec while Shift is held.
local _, ns = ...
local Core, TT = ns.Core, ns.Tooltip
local IT = {}
ns.ItemTooltip = IT

local UNSCORED, SKIP = "unscored", "skip"

-- Per spec: its context, and each item's result. Every recompute (gear, bags, talents, settings,
-- Core.changed(true)) starts both again, since worn gear moves the gain.
local contexts, results = {}, {}
function IT.reset() contexts, results = {}, {} end
table.insert(Core.listeners, IT.reset)

local function context(spec)
  if contexts[spec] == nil then contexts[spec] = Core.specContext(spec) or false end
  return contexts[spec] or nil
end

-- Set bonus points gained or lost by putting item `id` in `inv` (both hands for a two-hander),
-- counted as gearPart counts them: only BiS's sets, each capped at BiS's bonus.
local function setGain(ctx, id, inv, twoHand)
  -- The worn slots it empties: its own, the off hand for a two-hander, the two-hander for an off hand.
  local out = { inv }
  if twoHand then out[2] = 17 elseif inv == 17 and ctx.wornTwoHand then out[2] = 16 end
  local gain = 0
  for setID, s in pairs(ctx.bisSets) do
    local set = ctx.sets[setID]
    if set then
      local n = 0
      for slot = 1, 18 do if ctx.wornIDs[slot] and set.items[ctx.wornIDs[slot]] then n = n + 1 end end
      local after = n
      for _, slot in ipairs(out) do if ctx.wornIDs[slot] and set.items[ctx.wornIDs[slot]] then after = after - 1 end end
      if set.items[id] then after = after + 1 end
      gain = gain + math.min(ctx.setBonusAt(set, after), s.points) - math.min(ctx.setBonusAt(set, n), s.points)
    end
  end
  return gain
end

-- Localized class name -> token, for the tooltip's "Classes:" line.
local classTokens
local function tokens()
  if classTokens then return classTokens end
  classTokens = {}
  for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do classTokens[name] = token end
  for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do classTokens[name] = token end
  return classTokens
end

-- Whether another class's item: Forever's records say so, or the tooltip's "Classes:" line does.
-- Such an item can have stats the game reads, but it is never this character's gear.
local function otherClass(id, token, lines)
  local h = ns.db and ns.db.harvest and ns.db.harvest.records
  local r = (h and h[id]) or (ns.ForeverItemData and ns.ForeverItemData[id])
  local classes = (r and r.classes) or ns.ForeverItems.classesFrom(lines, tokens())
  return classes ~= nil and next(classes) ~= nil and not classes[token]
end

-- An item's result for a spec: Tooltip.evaluate's table, UNSCORED, or SKIP (not gear for this spec).
-- lines: the tooltip's left texts, for its class restriction.
function IT.evaluate(spec, id, link, lines)
  local ctx = context(spec)
  if not ctx then return UNSCORED end
  local _, _, _, loc, _, classID, subclassID = C_Item.GetItemInfoInstant(link or id)
  local places = TT.placesFor(loc, ctx.dualWield)
  if not places then return SKIP end
  if ns.Classes.barredType(ctx.token, { classID = classID, subclassID = subclassID, equipLoc = loc }) then return SKIP end
  if ctx.excluded and ctx.excluded[loc] then return SKIP end
  if otherClass(id, ctx.token, lines) then return SKIP end
  local item = ctx.item(id, link)
  if not item then return UNSCORED end
  local worn = false
  for _, pl in ipairs(places) do if ctx.wornIDs[pl.inv] == id then worn = true end end
  for _, pl in ipairs(places) do
    pl.points = ctx.points(id, item, pl.offHand)
    pl.worn = worn
    pl.setGain = setGain(ctx, id, pl.inv, pl.twoHand)
  end
  return TT.evaluate({ id = id, bisIDs = ctx.bisIDs, places = places, bis = ctx.bis, worn = ctx.worn, wornTwoHand = ctx.wornTwoHand, total = ctx.total }) or SKIP
end

-- The line for a spec, or nil for none. label: nil for the active spec.
function IT.lineFor(spec, id, link, label, lines)
  local bySpec = results[spec] or {}
  results[spec] = bySpec
  local key = (link and ns.Stats.linkSuffix(link)) and link or id
  if bySpec[key] == nil then
    local ok, r = pcall(IT.evaluate, spec, id, link, lines)
    if not ok then Core.lastError = r; r = SKIP end
    bySpec[key] = r
  end
  local r = bySpec[key]
  if r == SKIP then return nil end
  return TT.line(label, r ~= UNSCORED and r or nil), r == UNSCORED
end

-- The other talent group's spec, when the player has set one and it differs.
function IT.otherSpec(active)
  local other = ns.cdb and ns.cdb.groupSpec and ns.cdb.groupSpec[Core.talentGroup() == 1 and 2 or 1]
  if other and other ~= active then return other end
end

-- On a tier 0.5 hand-in (a Wildheart Kilt...): the quest that takes it and the BiS pieces it leads to,
-- for this spec and the other talent group's. nil when it isn't one, or its quest is done.
function IT.handInLine(id)
  local spec = Core.view and Core.view.spec
  if not spec then return nil end
  local q, targets = Core.handIn(id, { spec, IT.otherSpec(spec) }, function(s)
    local ctx = context(s)
    return ctx and ctx.bisIDs
  end)
  return q and ns.TradeIns.tooltipLine(q, targets) or nil
end

-- Where to get an item whose source Prepped supplies (Pix Xizzix's Undermine stock, tier 0.5 quests,
-- reputation vendors): SimGear has none for these, so no other tooltip says. nil for the rest.
function IT.sourceLine(id)
  local d = Core.data()
  local item = d and d.items[id]
  if not (item and item.addedSource) then return nil end
  return "Source: " .. ns.SlotPanel.sourcesText(item)
end

local function secret(v) return issecretvalue and issecretvalue(v) end

local function addLines(tooltip, data)
  if not (ns.db and ns.db.tooltip) then return end
  local spec = Core.view and Core.view.spec
  local id = data and data.id
  if not spec or not id or secret(id) then return end
  local link = tooltip.GetItem and select(2, tooltip:GetItem())
  if secret(link) then link = nil end
  local function add(text, unscored)
    if not text then return end
    if unscored then tooltip:AddLine(text, 0.6, 0.6, 0.6) else tooltip:AddLine(text, 0.2, 0.8, 1) end
  end
  local lines = {}
  for _, l in ipairs(type(data.lines) == "table" and data.lines or {}) do
    if type(l.leftText) == "string" and not secret(l.leftText) then lines[#lines + 1] = l.leftText end
  end
  local other = IT.otherSpec(spec)
  local shift = IsShiftKeyDown and IsShiftKeyDown()
  -- With Shift held both lines carry their spec's name, so they can't be mixed up.
  local short = ns.Spec.SHORT
  add(IT.lineFor(spec, id, link, (shift and other) and (short[spec] or spec) or nil, lines))
  if shift and other then add(IT.lineFor(other, id, link, short[other] or other, lines)) end
  add(IT.handInLine(id))
  local src = IT.sourceLine(id)
  if src then tooltip:AddLine(src, 0.8, 0.8, 0.8, true) end
end
IT.addLines = addLines

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    local ok, err = pcall(addLines, tooltip, data)
    if not ok then Core.lastError = err end
  end)
end

-- Shift pressed or let go over an item: redraw the tooltip so the other spec's line comes and goes.
local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "MODIFIER_STATE_CHANGED")
ev:SetScript("OnEvent", function(_, _, key)
  if not (key == "LSHIFT" or key == "RSHIFT") or not (ns.db and ns.db.tooltip) then return end
  local tip = GameTooltip
  if tip and tip:IsShown() and tip.GetItem and tip:GetItem() and tip.RefreshData then pcall(tip.RefreshData, tip) end
end)
