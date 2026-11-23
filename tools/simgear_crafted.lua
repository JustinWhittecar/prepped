-- Prints every item SimGear lists as crafted, across all classes: one line per item,
-- the item ID followed by its reagent item IDs.
-- Usage (repo root): luajit tools/simgear_crafted.lua [AddOns dir]
package.path = "./?.lua;" .. package.path
local T = dofile("test/lib.lua")
if arg[1] then T.SIMGEAR_DIR = arg[1] end
local seen = {}
for _, cls in ipairs({ "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior" }) do
  for id, it in pairs(T.simgearGlobal(cls)[cls:upper()].items.items) do
    for _, s in ipairs(it.sources or {}) do
      if s.type == "crafted" and not seen[id] then
        seen[id] = true
        local line = { id }
        for _, r in ipairs(s.reagents or {}) do line[#line + 1] = r[1] end
        print(table.concat(line, " "))
      end
    end
  end
end
