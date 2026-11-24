-- Forever items SimGear can't see: its pipeline asks the game only about IDs in the client's own
-- item table, and Forever sends some items (the tier 0.5 upgrade sets, 2267xx) from the server
-- only. Prepped asks the game about them itself (/prep harvest) and keeps what comes back raw:
-- name, slot, levels, the "Classes:" line and GetItemStats' stats. This module is pure.
local _, ns = ...
local ForeverItems = {}
ns.ForeverItems = ForeverItems

-- The classes on a tooltip's "Classes: A, B" line, as tokens ({DRUID = true}); nil without one.
-- tokens: localized class name -> class token.
function ForeverItems.classesFrom(lines, tokens)
  for _, line in ipairs(lines or {}) do
    local list = type(line) == "string" and line:match("^Classes: (.+)$")
    if list then
      local out = {}
      for name in list:gmatch("[^,]+") do
        local token = tokens[(name:gsub("^%s+", ""):gsub("%s+$", ""))]
        if token then out[token] = true end
      end
      return out
    end
  end
  return nil
end

-- A harvested record. info: name, quality, itemLevel, minLevel, equipLoc (GetItemInfo's fields);
-- raw: GetItemStats' table; classes: classesFrom's result or nil (any class).
function ForeverItems.record(info, raw, classes)
  return { name = info.name, quality = info.quality, ilvl = info.itemLevel, req = info.minLevel,
    slot = info.equipLoc, classes = classes, raw = raw or {} }
end

-- SimGear-shaped items ({name, slot, stats, req, ilvl, quality}) for one class: the records it can
-- use that equip somewhere and that SimGear doesn't already have. Only class-restricted records
-- count, since without SimGear's armor rules Prepped can't tell who wears an unrestricted one.
-- Each gets one source (kind "forever", text = the record's source note if any): it was found in game.
-- normalize: raw stats -> SimGear stats (Stats.normalize plus weapon DPS in the game).
function ForeverItems.forClass(records, token, have, normalize)
  local out = {}
  for id, r in pairs(records or {}) do
    if not have[id] and r.classes and r.classes[token] and r.slot and r.slot ~= "" then
      out[id] = { name = r.name, slot = r.slot, stats = normalize(r.raw, r.slot), req = r.req, ilvl = r.ilvl,
        quality = r.quality, sources = { { kind = "forever", text = r.source } }, forever = true }
    end
  end
  return out
end
