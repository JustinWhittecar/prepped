-- Slot panel on the character sheet: each slot's worn item against the spec's BiS, and the
-- selected slot in detail. Hovering a paper-doll slot (or a row) selects it. Draws what
-- SlotPanel.build returns; no scoring here.
local _, ns = ...
local SlotPanelUI = {}
ns.SlotPanelUI = SlotPanelUI
local Core, UI, SP = ns.Core, ns.UI, ns.SlotPanel

local FONT = "Fonts\\FRIZQT__.TTF"
local WIDTH, ROW_H, PAD = 340, 18, 8
local DETAIL_LINES = 6
-- The game font may lack ★, so it's drawn as the raid-target star, which every client has.
local STAR_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t"
-- The strip colour repeats what the % and ★ already say (colour never carries it alone).
local GOLD, PURPLE, BLUE, GREY = { 1, 0.78, 0.1 }, { 0.70, 0.36, 1 }, { 0.15, 0.55, 1 }, { 0.45, 0.45, 0.45 }
local DETAIL_COLOR = { title = { 1, 0.82, 0 }, worn = { 1, 1, 1 }, bis = { 1, 1, 1 }, gain = { 0.4, 1, 0.4 },
  source = { 0.8, 0.8, 0.8 } }

-- Paper-doll slot buttons; each one's GetID() is its inventory slot.
local BUTTONS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
  "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged" }

local panel, selected, built

local function text(parent, size, r, g, b)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 12, "")
  fs:SetTextColor(r or 1, g or 1, b or 1)
  fs:SetJustifyH("LEFT")
  return fs
end

-- Your pick shows as a lock (the font may lack ⚑ too).
local PICK_ICON = "|TInterface\\Buttons\\LockButton-Locked-Up:14:14|t"
local function star(s) return (s:gsub("★", STAR_ICON):gsub("⚑", PICK_ICON)) end

local function tier(r)
  if r.isBis then return GOLD end
  if not r.pct then return GREY end
  if r.pct >= 0.85 then return PURPLE end
  if r.pct >= 0.5 then return BLUE end
  return GREY
end

local function itemName(id, fallback)
  local name = id and C_Item.GetItemNameByID(id)
  if id and not name and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
  return name or fallback
end

local function showDetail()
  if not (panel and built) then return end
  local r
  for _, row in ipairs(built.rows) do if row.inv == selected then r = row end end
  for _, fs in ipairs(panel.detail) do fs:Hide() end
  local y = panel.detailTop
  if not r then return end
  -- Names the game knows (a random-suffix roll, an item SimGear lacks) beat "item 1234".
  local shown = {}
  for k, v in pairs(r) do shown[k] = v end
  shown.wornName = itemName(r.wornID, r.wornName)
  for i, l in ipairs(SP.detail(shown)) do
    local fs = panel.detail[i]
    if not fs then break end
    local c = DETAIL_COLOR[l.kind] or DETAIL_COLOR.worn
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetText(star(l.text))
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:Show()
    y = y - math.max(ROW_H, (fs:GetStringHeight() or 0) + 4)
  end
  panel.equip:ClearAllPoints()
  panel.equip:SetPoint("TOPLEFT", PAD, y - 4)
  panel.equip:Show()
  y = y - 4 - panel.equip:GetHeight()
  panel:SetHeight(-y + PAD)
end

local function selectSlot(inv)
  if not inv or inv == selected then return end
  selected = inv
  for _, row in ipairs(panel and panel.rows or {}) do
    if row.inv == inv then row.sel:Show() else row.sel:Hide() end
  end
  showDetail()
end
SlotPanelUI.select = selectSlot

local function badgeTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(built and built.badge or "Prepped")
  GameTooltip:AddLine(SP.badgeHelp(built and built.badge), 1, 1, 1, true)
  GameTooltip:AddLine("Click: About", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function rowTooltip(self)
  selectSlot(self.inv)
  local r = self.data
  if not (r and r.bisID) then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetItemByID(r.bisID)
  GameTooltip:AddLine((r.pinned and "Your pick" or "Prepped's BiS") .. " for " .. r.label:lower()
    .. ". Right-click: choose your own. Shift-click: link it.", 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function build()
  panel = CreateFrame("Frame", "PreppedSlotPanel", UIParent, "BackdropTemplate")
  panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  panel:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
  panel:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.9)
  panel:SetWidth(WIDTH)
  panel:SetFrameStrata("HIGH")
  panel:SetClampedToScreen(true)
  panel:Hide()
  -- Drag to move; the spot is kept relative to the character frame (/prep reset puts it back).
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function(self) if not ns.db.locked then self:StartMoving() end end)
  panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local l, t = self:GetLeft(), self:GetTop()
    if l and t and CharacterFrame:GetRight() then
      ns.db.slotPanelOffset = { l - CharacterFrame:GetRight(), t - CharacterFrame:GetTop() }
    end
    SlotPanelUI.dock()
  end)

  panel.title = text(panel, 13, 1, 0.82, 0)
  panel.title:SetPoint("TOPLEFT", PAD, -PAD)

  local badge = CreateFrame("Button", nil, panel)
  badge:SetHeight(16)
  badge:SetPoint("TOPRIGHT", -PAD, -PAD + 2)
  badge.text = text(badge, 12, 0.6, 0.85, 1)
  badge.text:SetPoint("RIGHT")
  badge:SetScript("OnEnter", badgeTooltip)
  badge:SetScript("OnLeave", GameTooltip_Hide)
  badge:SetScript("OnClick", function()
    if not (PreppedOptions and PreppedOptions:IsShown()) then UI.toggleOptions() end
  end)
  panel.badge = badge

  panel.legend = text(panel, 12, 0.7, 0.7, 0.7)
  panel.legend:SetPoint("TOPLEFT", PAD, -PAD - 20)
  panel.legend:SetText(star("★ wearing BiS · ⚑ your pick · % of BiS · readiness gain"))

  panel.note = text(panel, 12, 0.8, 0.8, 0.8)
  panel.note:SetPoint("TOPLEFT", PAD, -PAD - 42)
  panel.note:SetWidth(WIDTH - 2 * PAD)
  panel.note:SetWordWrap(true)

  panel.rows = {}
  local top = -PAD - 40
  for i, inv in ipairs(SP.ORDER) do
    local row = CreateFrame("Button", nil, panel)
    row.inv = inv
    row:SetSize(WIDTH - 2 * PAD, ROW_H - 1)
    row:SetPoint("TOPLEFT", PAD, top - (i - 1) * ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.04)
    row.sel = row:CreateTexture(nil, "BORDER")
    row.sel:SetAllPoints()
    row.sel:SetColorTexture(0.2, 0.6, 1, 0.25)
    row.sel:Hide()
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(4)
    row.label = text(row, 12, 0.85, 0.85, 0.85)
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetWidth(72)
    row.label:SetText(SP.LABEL[inv])
    row.right = text(row, 12)
    row.right:SetPoint("RIGHT", -2, 0)
    row.right:SetJustifyH("RIGHT")
    row.name = text(row, 12)
    row.name:SetPoint("LEFT", 82, 0)
    row.name:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
    row.name:SetWordWrap(false) -- a long name is cut, the numbers never are
    row:SetScript("OnEnter", rowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
      if button == "RightButton" then SlotPanelUI.pickMenu(self, self.inv); return end
      if IsShiftKeyDown() and self.data and self.data.bisID then
        local _, link = C_Item.GetItemInfo(self.data.bisID)
        if link then ChatEdit_InsertLink(link) end
      end
    end)
    panel.rows[i] = row
  end
  panel.detailTop = top - #SP.ORDER * ROW_H - 6

  -- Equip best: the best outfit from your bags for the spec shown (Equip.lua).
  local equip = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  equip:SetSize(110, 22)
  equip:SetText("Equip best")
  equip:SetScript("OnClick", function() ns.Equip.best() end)
  equip:SetScript("OnEnter", function(self)
    local spec = Core.view and Core.view.spec
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Equip best")
    GameTooltip:AddLine("Puts on the best gear in your bags for " .. (spec and (ns.Spec.NAME[spec] or spec) or "this spec")
      .. ", scored as the rest of this panel is. Bind-on-equip items stay in your bags. Out of combat only. Also /prep equip.",
      1, 1, 1, true)
    GameTooltip:Show()
  end)
  equip:SetScript("OnLeave", GameTooltip_Hide)
  equip:Hide()
  panel.equip = equip

  panel.detail = {}
  for i = 1, DETAIL_LINES do
    local fs = text(panel, 12)
    fs:SetWidth(WIDTH - 2 * PAD)
    fs:SetWordWrap(true) -- sources run long
    panel.detail[i] = fs
  end
end

-- Your pick for a slot: Prepped's BiS, or one of the best items the filters allow (with its share
-- of the BiS's points). An item outside the list can be picked with /prep pick <slot> <item link>.
function SlotPanelUI.pickMenu(owner, inv)
  local spec = Core.view and Core.view.spec
  if not spec then return end
  local list, autoID = Core.pickChoices(spec, inv, 15)
  if not list then return end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then
    Core.print("no menu on this client: use /prep pick " .. ns.UI.slotKey(inv) .. " <item link>|auto")
    return
  end
  local current = Core.pickFor(spec, inv)
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(SP.LABEL[inv] .. ": your pick")
    local function choose(id) return function() Core.setPick(spec, inv, id) end end
    local autoName = autoID and itemName(autoID, "item " .. autoID) or "none"
    root:CreateRadio("Prepped's BiS (" .. autoName .. ")", function() return current == nil end, choose(nil))
    local listed = false
    for _, c in ipairs(list) do
      if c.id ~= autoID then
        local share = c.share and string.format(" (%d%%)", math.floor(c.share * 100 + 0.5)) or ""
        root:CreateRadio(itemName(c.id, c.name) .. share, function() return current == c.id end, choose(c.id))
      end
      if c.id == current then listed = true end
    end
    if current and not listed then
      root:CreateRadio(itemName(current, "item " .. current) .. " (typed)", function() return true end, choose(current))
    end
    root:CreateDivider()
    root:CreateTitle("Others: /prep pick " .. ns.UI.slotKey(inv) .. " <item link>")
  end)
end

function SlotPanelUI.refresh(view)
  if not (panel and panel:IsShown()) then return end
  view = view or Core.view
  if not view then return end
  built = SP.build(view)
  local name = view.spec and ns.Spec.NAME[view.spec] or view.spec
  panel.title:SetText("Prepped" .. (name and (" · " .. name) or ""))
  panel.badge.text:SetText(built.badge or "")
  panel.badge:SetWidth(math.max(20, panel.badge.text:GetStringWidth() or 0))
  local has = #built.rows > 0
  panel.legend:SetShown(has)
  panel.note:SetText(built.note or "")
  panel.note:SetShown(not has)
  local byInv = {}
  for _, r in ipairs(built.rows) do byInv[r.inv] = r end
  for _, row in ipairs(panel.rows) do
    local r = byInv[row.inv]
    row.data = r
    row:SetShown(r ~= nil)
    if r then
      local c = tier(r)
      row.strip:SetColorTexture(c[1], c[2], c[3], 1)
      row.name:SetText(star(r.bisText))
      row.name:SetTextColor(r.bisID and 1 or 0.6, r.bisID and 1 or 0.6, r.bisID and 1 or 0.6)
      row.right:SetText(r.pctText .. (r.gainText ~= "" and ("  |cff66ff66" .. r.gainText .. "|r") or ""))
    end
  end
  if not has then
    for _, fs in ipairs(panel.detail) do fs:Hide() end
    panel.equip:Hide()
    panel:SetHeight(PAD + 42 + math.max(ROW_H, (panel.note:GetStringHeight() or 0)) + PAD)
    return
  end
  -- Keep the slot last hovered; a new character sheet opens on the biggest gain.
  if not (selected and byInv[selected]) then selected = nil; selectSlot(SP.defaultSlot(built.rows)) end
  for _, row in ipairs(panel.rows) do
    if row.inv == selected then row.sel:Show() else row.sel:Hide() end
  end
  showDetail()
end

-- How far other frames (a UI skin's side tabs, flyouts) stick out past the character frame's right edge.
local function rightOverhang()
  local right, top, bottom = CharacterFrame:GetRight(), CharacterFrame:GetTop(), CharacterFrame:GetBottom()
  if not (right and top and bottom) then return 0 end
  local over = 0
  local function check(f, depth)
    if f == panel or not f.IsShown or not f:IsShown() then return end
    local r, t, b = f:GetRight(), f:GetTop(), f:GetBottom()
    if r and t and b and r > right + 1 and r < right + 120 and t > bottom and b < top then over = math.max(over, r - right) end
    if depth < 2 then for _, c in ipairs({ f:GetChildren() }) do check(c, depth + 1) end end
  end
  for _, c in ipairs({ CharacterFrame:GetChildren() }) do check(c, 1) end
  return over
end

-- Beside the character frame (or where you dragged it, relative to the frame).
function SlotPanelUI.dock()
  if not panel then build() end
  panel:ClearAllPoints()
  local o = ns.db.slotPanelOffset
  if o then
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", o[1], o[2])
  else
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 4 + rightOverhang(), 0)
  end
  panel:Show()
  SlotPanelUI.refresh(Core.view)
end

local function hookSlots()
  for _, name in ipairs(BUTTONS) do
    local b = _G["Character" .. name .. "Slot"]
    if b and b.HookScript then
      -- HookScript runs after Blizzard's handler and SimGear's, replacing neither.
      b:HookScript("OnEnter", function(self) if panel and panel:IsShown() then selectSlot(self:GetID()) end end)
    end
  end
end

local function onLogin()
  if not CharacterFrame then return end
  -- Only on the paper doll tab, not reputation or currency.
  local host = _G.PaperDollFrame or CharacterFrame
  host:HookScript("OnShow", function()
    SlotPanelUI.dock()
    -- Again once other addons (skins) have placed their frames.
    C_Timer.After(0.1, function() if host:IsShown() then SlotPanelUI.dock() end end)
  end)
  host:HookScript("OnHide", function() if panel then panel:Hide() end end)
  hookSlots()
  table.insert(Core.listeners, SlotPanelUI.refresh)
  -- /prep reset also puts the panel back beside the character frame.
  local reset = UI.resetPositions
  UI.resetPositions = function(...)
    reset(...)
    ns.db.slotPanelOffset = nil
    if panel and panel:IsShown() then SlotPanelUI.dock() end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", onLogin)
