-- Upgrade arrows on bag icons: a green arrow on gear that would raise readiness for the spec Prepped
-- is scoring (the same test as the tooltip's arrow, ItemTooltip.isUpgrade). In Baganator as a corner
-- widget and an upgrade plugin (its Upgrades category); in the game's own bags on each item button.
local _, ns = ...
local Core, IT = ns.Core, ns.ItemTooltip
local ATLAS = "bags-greenarrow"

local function arrowTexture(parent, size)
  local tex = parent:CreateTexture(nil, "OVERLAY", nil, 7)
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ATLAS) then
    tex:SetAtlas(ATLAS)
  else
    tex:SetTexture("Interface\\PetBattles\\BattleBar-AbilityBadge-Strong")
  end
  tex:SetSize(size, size)
  return tex
end

local function upgrade(link)
  local ok, yes = pcall(IT.isUpgrade, link)
  return ok and yes or false
end

-- Baganator -------------------------------------------------------------------------------------------
local function baganator()
  local api = Baganator and Baganator.API
  if not (api and api.RegisterCornerWidget) then return false end
  api.RegisterCornerWidget("Prepped upgrade", "prepped", function(_, details)
    return details and details.itemLink and upgrade(details.itemLink) or false
  end, function(itemButton) return arrowTexture(itemButton, 14) end, { corner = "top_left", priority = 1 })
  if api.RegisterUpgradePlugin then api.RegisterUpgradePlugin("Prepped", "prepped", upgrade) end
  -- Worn gear, talents and settings move what counts as an upgrade.
  table.insert(Core.listeners, function()
    if api.RequestItemButtonsRefresh then api.RequestItemButtonsRefresh() end
  end)
  return true
end

-- The game's bags ---------------------------------------------------------------------------------------
local function mark(button)
  local bag = button.GetBagID and button:GetBagID()
  local slot = button.GetID and button:GetID()
  local link = bag and slot and C_Container.GetContainerItemLink(bag, slot)
  local show = link and upgrade(link) or false
  if show and not button.preppedArrow then
    button.preppedArrow = arrowTexture(button, 14)
    button.preppedArrow:SetPoint("TOPLEFT", 2, -2)
  end
  if button.preppedArrow then button.preppedArrow:SetShown(show) end
end

local function markFrame(frame)
  if not (frame and frame.IsShown and frame:IsShown() and frame.EnumerateValidItems) then return end
  for _, button in frame:EnumerateValidItems() do mark(button) end
end

local frames = {}
local function blizzard()
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do frames[#frames + 1] = _G["ContainerFrame" .. i] end
  frames[#frames + 1] = _G.ContainerFrameCombinedBags
  for _, f in ipairs(frames) do
    if f.UpdateItems then hooksecurefunc(f, "UpdateItems", markFrame) end
  end
  table.insert(Core.listeners, function() for _, f in ipairs(frames) do markFrame(f) end end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ok, err = pcall(function() if not baganator() then blizzard() end end)
  if not ok then Core.lastError = err end
end)
