-- UI: the tracker, the buff bar, the options window, /prep and the addon compartment button.
-- Draws whatever Core.compute and the pure modules return; no scoring here.
local ADDON, ns = ...
local UI = {}
ns.UI = UI
local Core = ns.Core

local FONT = "Fonts\\FRIZQT__.TTF"
local function text(parent, size, r, g, b)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 12, "")
  fs:SetTextColor(r or 1, g or 1, b or 1)
  fs:SetJustifyH("LEFT")
  return fs
end

local function backdrop(f)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  f:SetBackdropColor(0.05, 0.05, 0.07, 0.75)
  f:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.9)
end

local function savePos(frame, key)
  local a, _, b, x, y = frame:GetPoint()
  ns.db[key] = { a, b, x, y }
end

local function placeAt(frame, key, default)
  frame:ClearAllPoints()
  local p = ns.db[key]
  if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint(unpack(default)) end
end

-- Tracker -------------------------------------------------------------------------------------------
local TRACKER_DEFAULT = { "RIGHT", UIParent, "RIGHT", -260, 120 }
local WIDTH, LINE = 300, 16
local COLORS = { blocker = { 1, 0.45, 0.45 }, more = { 0.7, 0.7, 0.7 }, consumable = { 1, 0.82, 0 }, gear = { 1, 1, 1 },
  choose = { 0.35, 0.8, 1 } }

local tracker
local function pct(x) return math.floor(x * 100 + 0.5) .. "%" end

local function headerTooltip(self)
  local v = Core.view
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("Prepped")
  local r = v and v.readiness
  if r and r.pct then
    GameTooltip:AddLine("Readiness " .. pct(r.pct) .. " for " .. (ns.Spec.NAME[v.spec] or v.spec or "?"), 1, 1, 1)
    for _, part in ipairs({ { "gear", "Gear" }, { "enchants", "Enchants" }, { "consumables", "Consumables" } }) do
      local share = r[part[1]]
      GameTooltip:AddDoubleLine(part[2], share and pct(share) or "not scored", 0.8, 0.8, 0.8, 1, 1, 1)
    end
    if r.next then GameTooltip:AddLine("Biggest next step: " .. r.next.label, 0.4, 1, 0.4, true) end
  end
  local badge = v and v.state and v.state.badge
  if badge == "SimGear live" then
    GameTooltip:AddLine("Scores use SimGear Forever's data, read live.", 0.6, 0.6, 0.6, true)
  elseif badge == "Estimated weights" then
    GameTooltip:AddLine("SimGear's weights for this spec are placeholders, not sims: treat the score as rough.", 0.6, 0.6, 0.6, true)
  elseif v and v.problem then
    GameTooltip:AddLine("No gear data: " .. tostring(v.problem), 1, 0.4, 0.4, true)
  end
  GameTooltip:AddLine("Click: expand or collapse · Drag: move", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function buildTracker()
  tracker = CreateFrame("Frame", "PreppedTracker", UIParent, "BackdropTemplate")
  backdrop(tracker)
  tracker:SetSize(WIDTH, 28)
  tracker:SetMovable(true)
  tracker:SetClampedToScreen(true)
  placeAt(tracker, "trackerPos", TRACKER_DEFAULT)

  local head = CreateFrame("Button", nil, tracker)
  head:SetPoint("TOPLEFT", 6, -4)
  head:SetPoint("TOPRIGHT", -26, -4)
  head:SetHeight(20)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() if not ns.db.locked then tracker:StartMoving() end end)
  head:SetScript("OnDragStop", function() tracker:StopMovingOrSizing(); savePos(tracker, "trackerPos") end)
  head:SetScript("OnClick", function()
    ns.cdb.collapsed = not ns.cdb.collapsed
    UI.refreshTracker(Core.view)
  end)
  head:SetScript("OnEnter", headerTooltip)
  head:SetScript("OnLeave", GameTooltip_Hide)
  tracker.title = text(head, 13, 1, 0.82, 0)
  tracker.title:SetPoint("LEFT", 0, 0)
  tracker.title:SetPoint("RIGHT", 0, 0)

  local gear = CreateFrame("Button", nil, tracker)
  gear:SetSize(16, 16)
  gear:SetPoint("TOPRIGHT", -6, -6)
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  gear:SetScript("OnClick", function() UI.toggleOptions() end)
  gear:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine("Prepped options"); GameTooltip:Show()
  end)
  gear:SetScript("OnLeave", GameTooltip_Hide)

  tracker.lines, tracker.buttons = {}, {}
end

local function line(i)
  local l = tracker.lines[i]
  if not l then
    l = text(tracker, 12)
    l:SetWidth(WIDTH - 16)
    l:SetWordWrap(true) -- a long blocker line wraps instead of being cut off
    -- A hover area over the line: a line about an item shows that item's tooltip.
    local hit = CreateFrame("Frame", nil, tracker)
    hit:SetAllPoints(l)
    hit:SetScript("OnEnter", function(self)
      if not self.itemID then return end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetItemByID(self.itemID)
      GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", GameTooltip_Hide)
    -- Clicks and drags still reach the tracker underneath, so it moves from any line.
    if hit.SetPropagateMouseClicks then hit:SetPropagateMouseClicks(true) end
    l.hit = hit
    tracker.lines[i] = l
  end
  return l
end

local function choiceButton(i)
  local b = tracker.buttons[i]
  if not b then
    b = CreateFrame("Button", nil, tracker, "UIPanelButtonTemplate")
    b:SetHeight(18)
    b:SetScript("OnClick", function(self) Core.setSpec(self.spec) end)
    tracker.buttons[i] = b
  end
  return b
end

function UI.refreshTracker(view)
  if not tracker then return end
  if not ns.db.showTracker or not view then tracker:Hide(); return end
  tracker:SetScale(ns.db.scale or 1)
  -- Collapsing redraws without a recompute, so read the live setting, not the view's copy.
  view.state.collapsed = ns.cdb.collapsed
  local t = ns.Tracker.lines(view.state)
  tracker.title:SetText(t.header)
  for _, l in ipairs(tracker.lines) do l:Hide(); l.hit:Hide() end
  for _, b in ipairs(tracker.buttons) do b:Hide() end
  local y, bi = -26, 0
  for i, l in ipairs(t.lines) do
    local fs = line(i)
    local c = COLORS[l.kind] or COLORS.gear
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetText(l.text)
    fs.hit.itemID = l.itemID
    fs.hit:EnableMouse(l.itemID ~= nil) -- only item lines catch the mouse
    fs.hit:Show()
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 8, y)
    fs:Show()
    if l.buttons then
      local x = 8 + fs:GetStringWidth() + 6
      for _, choice in ipairs(l.buttons) do
        bi = bi + 1
        local b = choiceButton(bi)
        b.spec = choice.spec
        b:SetText(choice.label)
        b:SetWidth(math.max(44, b:GetFontString():GetStringWidth() + 16))
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, y + 2)
        b:Show()
        x = x + b:GetWidth() + 4
      end
      y = y - 4
    end
    y = y - math.max(LINE, (fs:GetStringHeight() or 0) + 3)
  end
  tracker:SetHeight(-y + 6)
  tracker:Show()
end

-- Buff bar: one secure button per missing buff, hidden in combat ---------------------------------------
local BUFF_DEFAULT = { "CENTER", UIParent, "CENTER", 0, 200 }
local SIZE, GAP = 40, 6
local holder, grip
local buffButtons = {}

local function buffButton(i)
  if buffButtons[i] then return buffButtons[i] end
  local b = CreateFrame("Button", "PreppedBuff" .. i, holder, "SecureActionButtonTemplate")
  b:SetSize(SIZE, SIZE)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "item")
  b:SetAttribute("unit", "player") -- scrolls buff your target otherwise
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b.count = text(b, 12)
  b.count:SetPoint("BOTTOMRIGHT", -2, 2)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetItemByID(self.id)
    if self.empty then GameTooltip:AddLine("(none in your bags)", 1, 0.4, 0.4) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  buffButtons[i] = b
  return b
end

function UI.refreshBuffs(view)
  if not holder then return end
  if InCombatLockdown() then return end -- redrawn on PLAYER_REGEN_ENABLED
  local list = {}
  if view and view.buffSlots and ns.db.buffsRaid and not UnitIsDeadOrGhost("player") then
    local stock = {}
    for _, s in ipairs(view.buffSlots) do if s.item then stock[s.item.id] = C_Item.GetItemCount(s.item.id) or 0 end end
    list = ns.Buffs.missing({ instance = view.instance, slots = view.buffSlots, stock = stock, inCombat = false,
      dungeons = ns.db.buffsDungeon })
  end
  for _, b in ipairs(buffButtons) do b:Hide() end
  if #list == 0 then holder:Hide(); return end
  for i, m in ipairs(list) do
    local b = buffButton(i)
    b.id, b.empty = m.item.id, m.bags == 0
    b:SetAttribute("item", (not b.empty) and ("item:" .. m.item.id) or nil)
    b.icon:SetTexture(C_Item.GetItemIconByID(m.item.id))
    b.icon:SetDesaturated(b.empty)
    b.count:SetText(b.empty and "(none)" or m.bags)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * (SIZE + GAP), 0)
    b:Show()
  end
  holder:SetWidth(#list * (SIZE + GAP) - GAP)
  grip.label:SetText("Prepped: buffs missing")
  holder:Show()
end

local function buildBuffBar()
  -- Never on screen in combat: a secure state driver works under combat lockdown.
  local gate = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
  gate:SetAllPoints(UIParent)
  RegisterStateDriver(gate, "visibility", "[combat] hide; show")
  holder = CreateFrame("Frame", "PreppedBuffs", gate)
  holder:SetSize(SIZE, SIZE)
  holder:SetMovable(true)
  holder:SetClampedToScreen(true)
  placeAt(holder, "buffPos", BUFF_DEFAULT)
  holder:Hide()
  grip = CreateFrame("Frame", nil, holder)
  grip:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, 2)
  grip:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", 0, 2)
  grip:SetHeight(14)
  grip.label = text(grip, 12, 1, 0.82, 0)
  grip.label:SetPoint("BOTTOM")
  grip:EnableMouse(true)
  grip:RegisterForDrag("LeftButton")
  grip:SetScript("OnDragStart", function() if not InCombatLockdown() and not ns.db.locked then holder:StartMoving() end end)
  grip:SetScript("OnDragStop", function() holder:StopMovingOrSizing(); savePos(holder, "buffPos") end)
end

-- Options window (its own frame: a page in the game's Settings tainted SimGear's action bars) ----------------
local options

local function cycle(list, current)
  for i, v in ipairs(list) do if v == current then return list[i % #list + 1] end end
  return list[1]
end

local function check(parent, label, get, set, y)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetPoint("TOPLEFT", 16, y)
  c:SetSize(24, 24)
  local fs = text(c, 12)
  fs:SetPoint("LEFT", c, "RIGHT", 4, 0)
  fs:SetText(label)
  c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  c.refresh = function() c:SetChecked(get()) end
  return c
end

local function button(parent, label, onClick, x, y, w)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 120, 22)
  b:SetPoint("TOPLEFT", x, y)
  b:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

local function heading(parent, label, y)
  local fs = text(parent, 13, 1, 0.82, 0)
  fs:SetPoint("TOPLEFT", 12, y)
  fs:SetText(label)
  return fs
end

local function buildOptions()
  options = CreateFrame("Frame", "PreppedOptions", UIParent, "BackdropTemplate")
  backdrop(options)
  options:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
  options:SetSize(420, 864)
  options:SetPoint("CENTER")
  options:SetFrameStrata("DIALOG")
  options:SetMovable(true)
  options:EnableMouse(true)
  options:RegisterForDrag("LeftButton")
  options:SetScript("OnDragStart", options.StartMoving)
  options:SetScript("OnDragStop", options.StopMovingOrSizing)
  options:SetClampedToScreen(true)
  tinsert(UISpecialFrames, "PreppedOptions") -- Escape closes it
  local close = CreateFrame("Button", nil, options, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  local title = text(options, 15, 0.2, 0.8, 1)
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText("Prepped " .. (C_AddOns.GetAddOnMetadata(ADDON, "Version") or ""))

  local widgets = {}
  local function add(w) widgets[#widgets + 1] = w; return w end
  local y = -36

  heading(options, "Character", y); y = y - 22
  local specBtn = add(button(options, "", function()
    local token = select(2, UnitClass("player"))
    local list = {}
    for _, s in ipairs(ns.Spec.specsOf(token)) do list[#list + 1] = s end
    list[#list + 1] = false -- back to detected
    local group = Core.talentGroup()
    local nextSpec = cycle(list, ns.cdb.groupSpec[group] or false)
    ns.cdb.groupSpec[group] = nextSpec or nil
    Core.settingsChanged()
  end, 16, y, 260))
  specBtn.refresh = function()
    local group = Core.talentGroup()
    local chosen = ns.cdb.groupSpec[group]
    local spec = Core.spec()
    specBtn:SetText("Talent group " .. group .. ": " .. (ns.Spec.NAME[spec] or spec or "?") .. (chosen and "" or " (detected)"))
  end
  y = y - 26
  local note = text(options, 11, 0.6, 0.6, 0.6)
  note:SetPoint("TOPLEFT", 18, y)
  note:SetText("Content target: Pre-raid (raids come once their loot data exists)")
  y = y - 24

  heading(options, "Obtainable (BiS leaves these out)", y); y = y - 22
  for _, f in ipairs({ { "reputation", "Exclude reputation items" }, { "profession", "Exclude profession bind-on-pickup items" },
    { "pvp", "Exclude PvP rank items" }, { "darkmoon", "Exclude Darkmoon Faire items" },
    { "unconfirmed", "Exclude unconfirmed consumables (Jujus)" } }) do
    add(check(options, f[2], function() return ns.cdb.filters[f[1]] == true end,
      function(on) ns.cdb.filters[f[1]] = on == true; Core.settingsChanged() end, y))
    y = y - 24
  end

  heading(options, "Score", y); y = y - 22
  local hoursLabel = text(options, 12)
  hoursLabel:SetPoint("TOPLEFT", 18, y - 4)
  hoursLabel:SetText("Raid night length (hours):")
  local hours = CreateFrame("EditBox", nil, options, "InputBoxTemplate")
  hours:SetSize(50, 20)
  hours:SetPoint("LEFT", hoursLabel, "RIGHT", 10, 0)
  hours:SetAutoFocus(false)
  hours:SetMaxLetters(4)
  local function applyHours(self)
    local n = tonumber((self:GetText() or ""):gsub(",", "."))
    if n and n >= 0.5 and n <= 12 then
      ns.cdb.raidHours = n
      Core.changed()
    end
    self:SetText(ns.cdb.raidHours) -- a bad entry goes back to the saved value
    self:ClearFocus()
  end
  hours:SetScript("OnEnterPressed", applyHours)
  hours:SetScript("OnEditFocusLost", applyHours)
  hours:SetScript("OnEscapePressed", function(self) self:SetText(ns.cdb.raidHours); self:ClearFocus() end)
  add({ refresh = function() if not hours:HasFocus() then hours:SetText(ns.cdb.raidHours) end end })
  y = y - 30

  heading(options, "Consumables (buffs of one stat don't stack)", y); y = y - 24
  -- One row per choice: flask, then each stat your buffs raise (an elixir and a scroll of one stat
  -- conflict), then food and weapon. A dropdown each (Baganator's API, so present on Forever); a
  -- click-to-cycle button stands in if this client has no dropdown template.
  local MAX_ROWS = 14
  local consRows = {}
  local function setPick(spec, key, value)
    ns.cdb.consumables[spec] = ns.cdb.consumables[spec] or {}
    ns.cdb.consumables[spec][key] = value
    Core.changed()
  end
  for i = 1, MAX_ROWS do
    local label = text(options, 12)
    label:SetPoint("TOPLEFT", 18, y - (i - 1) * 26 - 5)
    label:SetWidth(90)
    local ok, d = pcall(CreateFrame, "DropdownButton", nil, options, "WowStyle1DropdownTemplate")
    if not (ok and d and d.SetupMenu) then
      d = button(options, "", function(self)
        local v = Core.view
        if not (v and v.spec and self.key) then return end
        local list = { false }
        for _, e in ipairs(self.ranked or {}) do list[#list + 1] = e.id end
        list[#list + 1] = "none"
        local cur = ns.cdb.consumables[v.spec] and ns.cdb.consumables[v.spec][self.key] or false
        setPick(v.spec, self.key, cycle(list, cur) or nil)
      end, 0, 0, 260)
      d.cycling = true
    end
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", 112, y - (i - 1) * 26)
    d:SetWidth(260)
    consRows[i] = { label = label, d = d }
  end
  local LABEL = { flask = "Flask", food = "Food", weapon = "Weapon", Agility = "Agility", Strength = "Strength",
    AttackPower = "Attack power", MeleeCrit = "Crit", SpellCrit = "Spell crit", Armor = "Armor", Health = "Health",
    Stamina = "Stamina", SpellPower = "Spell power", ShadowPower = "Shadow power", NaturePower = "Nature power",
    HolyPower = "Holy power", FrostPower = "Frost power", FirePower = "Fire power", HealingPower = "Healing",
    Intellect = "Intellect", Spirit = "Spirit", Mp5 = "Mana regen" }
  -- The choices for the spec: { key, label, ranked entries }, flask first, food and weapon last.
  local function choices(spec, ws)
    local catalog = Core.consumablesFor(spec)
    local rule = { critStacks = ns.ConsumableRules.critStacks }
    local function pts(e) return ns.Score.value(e.stats, ws) end
    local byKey, statKeys = {}, {}
    local function put(key, e)
      if not byKey[key] then
        byKey[key] = {}
        if key ~= "flask" and key ~= "food" and key ~= "weapon" then statKeys[#statKeys + 1] = key end
      end
      table.insert(byKey[key], e)
    end
    for _, e in ipairs(catalog) do
      if pts(e) > 0 then
        if e.family == "buff" then
          for _, k in ipairs(ns.Consumables.claims(e, rule)) do put(k, e) end
        elseif e.family ~= "potion" then
          put(e.family, e)
        end
      end
    end
    table.sort(statKeys, function(a, b) return (LABEL[a] or a) < (LABEL[b] or b) end)
    local keys = { "flask" }
    for _, k in ipairs(statKeys) do keys[#keys + 1] = k end
    keys[#keys + 1] = "food"
    keys[#keys + 1] = "weapon"
    local out = {}
    for _, k in ipairs(keys) do
      if byKey[k] then
        table.sort(byKey[k], function(a, b) return pts(a) > pts(b) end)
        out[#out + 1] = { key = k, label = LABEL[k] or k, ranked = byKey[k] }
      end
    end
    return out, pts
  end
  add({ refresh = function()
    local v = Core.view
    local spec = v and v.spec
    local ws = v and v.set and v.set.ws
    local list, pts = {}, nil
    if spec and ws then list, pts = choices(spec, ws) end
    local picks = spec and ns.cdb.consumables[spec] or {}
    for i, row in ipairs(consRows) do
      local c, d = list[i], row.d
      if c then
        -- What fills this choice now, and whether a pick under another choice put it there.
        local filling
        for _, r in ipairs(v.consumableRows or {}) do
          for _, e in ipairs(c.ranked) do if r.item and r.item.id == e.id then filling = e end end
        end
        local pick = picks[c.key]
        local covered = false
        for key, value in pairs(picks) do
          if key ~= c.key and filling and value == filling.id then covered = true end
        end
        local best = "Best for you" .. (filling and (covered and (" (covered by " .. filling.name .. ")") or (" (" .. filling.name .. ")")) or "")
        row.label:SetText(c.label)
        row.label:Show()
        if d.cycling then
          local shown = best
          for _, e in ipairs(c.ranked) do if e.id == pick then shown = e.name end end
          if pick == "none" then shown = "None" end
          d.key, d.ranked = c.key, c.ranked
          d:SetText(shown)
        else
          d:SetupMenu(function(_, root)
            local function isPick(value) return (pick or false) == value end
            local function choose(value) setPick(spec, c.key, value or nil) end
            root:CreateRadio(best, isPick, choose, false)
            for _, e in ipairs(c.ranked) do root:CreateRadio(e.name, isPick, choose, e.id) end
            root:CreateRadio("None", isPick, choose, "none")
          end)
        end
        d:Show()
      else
        row.label:Hide()
        d:Hide()
      end
    end
  end })
  y = y - MAX_ROWS * 26 - 8

  heading(options, "Display", y); y = y - 22
  add(check(options, "Show tracker", function() return ns.db.showTracker end,
    function(on) ns.db.showTracker = on; UI.refreshTracker(Core.view) end, y)); y = y - 24
  add(check(options, "Buff reminder in raids", function() return ns.db.buffsRaid end,
    function(on) ns.db.buffsRaid = on; Core.changed() end, y))
  button(options, "Test", function() UI.buffTest() end, 260, y, 60)
  y = y - 24
  add(check(options, "Buff reminder in 5-player dungeons", function() return ns.db.buffsDungeon end,
    function(on) ns.db.buffsDungeon = on; Core.changed() end, y)); y = y - 24
  add(check(options, "Lock tracker and buff bar", function() return ns.db.locked end,
    function(on) ns.db.locked = on or nil end, y)); y = y - 26
  local scale = add(button(options, "", function()
    ns.db.scale = cycle({ 0.8, 0.9, 1, 1.1, 1.25, 1.5 }, ns.db.scale)
    UI.refreshTracker(Core.view)
  end, 16, y, 140))
  scale.refresh = function() scale:SetText("Tracker scale: " .. ns.db.scale) end
  button(options, "Reset positions", function() UI.resetPositions() end, 164, y, 140)
  y = y - 30

  heading(options, "About", y); y = y - 18
  local about = text(options, 11, 0.75, 0.75, 0.75)
  about:SetPoint("TOPLEFT", 16, y)
  about:SetWidth(390)
  about:SetWordWrap(true)
  options.about = about

  options.refresh = function()
    for _, w in ipairs(widgets) do if w.refresh then w.refresh() end end
    local v = Core.view
    local d = Core.data()
    options.about:SetText("Gear data and scoring: SimGear Forever" .. (d and d.generated and (" (weights " .. d.generated .. ")") or "")
      .. ", simmed on the MythicSim engine. Sources: cMaNGOS classic-db. "
      .. "Status: " .. ((v and v.state and v.state.badge) or "?")
      .. ". Issues: github.com (repo to come).")
  end
  options:SetScript("OnShow", options.refresh)
  options:Hide()
end

function UI.toggleOptions()
  if not options then buildOptions() end
  options:SetShown(not options:IsShown())
end

function UI.resetPositions()
  ns.db.trackerPos, ns.db.buffPos = nil, nil
  placeAt(tracker, "trackerPos", TRACKER_DEFAULT)
  if not InCombatLockdown() then placeAt(holder, "buffPos", BUFF_DEFAULT) end
end

function UI.buffTest()
  Core.buffTest = not Core.buffTest
  Core.print("buff reminder test " .. (Core.buffTest and "on: showing it as if you were in a raid" or "off"))
  Core.changed()
end

-- /pr, /prepped -------------------------------------------------------------------------------------------
local function slashTaken(cmd)
  for k, v in pairs(_G) do
    if type(k) == "string" and k:find("^SLASH_") and v == cmd and not k:find("^SLASH_PREPPED") then return k end
  end
end

local function debug()
  local v = Core.view
  local d, problem = Core.data()
  Core.print("class data: " .. (d and "loaded" or ("missing (" .. tostring(problem) .. ")")))
  if v then
    Core.print("spec " .. tostring(v.spec) .. " · talent group " .. Core.talentGroup() .. " · instance " .. tostring(v.instance))
    local r = v.readiness
    if r and r.pct then
      Core.print(string.format("readiness %.1f%% (gear %s, enchants %s, consumables %s)", r.pct * 100,
        r.gear and pct(r.gear) or "-", r.enchants and pct(r.enchants) or "-", r.consumables and pct(r.consumables) or "-"))
    end
    for inv, row in pairs(v.rows or {}) do
      Core.print(string.format("  %s: BiS %s (%d), you %d%%", Core.SLOT_NAME[inv], row.bis.item.name or row.bis.id, row.bis.id,
        math.floor(row.pct * 100 + 0.5)))
    end
  end
  if Core.lastError then Core.print("last error: " .. tostring(Core.lastError)) end
end

local function slash(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" then
    ns.db.showTracker = not ns.db.showTracker
    Core.print("tracker " .. (ns.db.showTracker and "shown" or "hidden (/prep shows it again)"))
    UI.refreshTracker(Core.view)
  elseif msg == "options" or msg == "o" then
    UI.toggleOptions()
  elseif msg == "buffs test" then
    UI.buffTest()
  elseif msg == "reset" then
    UI.resetPositions()
  elseif msg == "debug" then
    debug()
  elseif msg:match("^harvest") then
    local a, b = msg:match("^harvest%s+(%d+)%s+(%d+)")
    Core.harvest(tonumber(a), tonumber(b))
  elseif msg:match("^spec") then
    local arg = msg:match("^spec%s+(%S+)")
    local token = select(2, UnitClass("player"))
    local ok, value = ns.Spec.parseOverride(arg, token)
    if not ok then Core.print("/prep spec " .. ns.Spec.usage(token) .. "|auto"); return end
    ns.cdb.groupSpec[Core.talentGroup()] = value or nil
    Core.settingsChanged()
    Core.print("talent group " .. Core.talentGroup() .. ": " .. (value and (ns.Spec.NAME[value] or value) or "detected from talents"))
  else
    Core.print("/prep (show or hide the tracker) · /prep options · /prep spec <name>|auto · /prep buffs test · /prep reset · /prep debug · /prep harvest [from to]")
  end
end

local function registerSlash()
  local taken = slashTaken("/prep")
  SLASH_PREPPED1 = "/prepped"
  if taken then
    Core.print("/prep is already used by " .. taken .. ", so use /prepped.")
  else
    SLASH_PREPPED2 = "/prep"
  end
  SlashCmdList.PREPPED = slash
end

-- Addon compartment (minimap addon menu): left-click toggles the tracker, right-click opens options.
function Prepped_OnCompartmentClick(_, button)
  if button == "RightButton" then
    UI.toggleOptions()
  else
    ns.db.showTracker = not ns.db.showTracker
    UI.refreshTracker(Core.view)
  end
end

function Prepped_OnCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
  GameTooltip:AddLine("Prepped")
  GameTooltip:AddLine("Left-click: show or hide the tracker", 1, 1, 1)
  GameTooltip:AddLine("Right-click: options", 1, 1, 1)
  GameTooltip:Show()
end

function Prepped_OnCompartmentLeave() GameTooltip:Hide() end

function UI.onLoad()
  buildTracker()
  buildBuffBar()
  registerSlash()
  table.insert(Core.listeners, UI.refreshTracker)
  table.insert(Core.listeners, UI.refreshBuffs)
  table.insert(Core.listeners, function() if options and options:IsShown() then options.refresh() end end)
  Core.changed()
end
