-- Why a BiS item might be a wrong pick, from its sources alone (tools/bis_audit.lua). Pure.
-- Sources are SimGear's ({type, origin, name, zone, instance, chance}) or Prepped's own ({kind, text}).
local A = {}

local RARE = 0.02 -- every known chance under 2%

local function pct(c)
  local p = c * 100
  return (p < 1 and string.format("%.1f", p) or string.format("%.0f", p)):gsub("%.0$", "") .. "%"
end

-- One source in a line: "boss Baron Rivendare (Stratholme) 11.1% [cmangos]".
function A.sourceText(s)
  if s.kind then return s.kind .. ": " .. tostring(s.text) end
  local out = (s.type or "?") .. (s.name and (" " .. s.name) or "")
  if s.zone then out = out .. " (" .. s.zone .. ")" end
  if s.chance then out = out .. " " .. string.format("%.1f%%", s.chance * 100) end
  if s.origin then out = out .. " [" .. s.origin .. "]" end
  return out
end

-- Reasons to look twice: { "rare: best chance 0.2%", ... }, empty when the sources look ordinary.
function A.flags(item)
  local srcs = type(item.sources) == "table" and item.sources or {}
  local out = {}
  if #srcs == 0 then return { "no source" } end
  local all = function(test) for _, s in ipairs(srcs) do if not test(s) then return false end end return true end
  -- Prepped's own sources (the tier 0.5 harvest, Pix Xizzix's stock, reputation) were found in game.
  if all(function(s) return s.kind end) then return out end
  -- Rare: only drops, chests or world drops, every one with a chance under RARE.
  local looted = all(function(s) return (s.type == "drop" or s.type == "boss" or s.type == "chest" or s.type == "world") and s.chance end)
  if looted then
    local best = 0
    for _, s in ipairs(srcs) do best = math.max(best, s.chance) end
    if best < RARE then out[#out + 1] = "rare: best chance " .. pct(best) end
  end
  if all(function(s) return s.type == "world" end) then out[#out + 1] = "world drop only" end
  if all(function(s) return s.type == "drop" and not s.instance end) then out[#out + 1] = "open-world mob only" end
  if all(function(s) return s.type == "quest" and s.origin == "cmangos" end) then
    out[#out + 1] = "quest only in cMaNGOS (not in Forever's client)"
  end
  if all(function(s) return s.origin == "seen" or s.origin == "lead" end) then out[#out + 1] = "community reports only" end
  return out
end

return A
