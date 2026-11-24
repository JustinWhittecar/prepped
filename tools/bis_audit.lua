-- BiS audit: every class and spec's BiS with no filters on, and why any pick might be wrong from
-- its sources (tools/audit_lib.lua): rare drops, world or open-world drops, quests only in cMaNGOS,
-- community reports only, Prepped's own sources. Also names the filter that would already remove it.
--   luajit tools/bis_audit.lua            all classes, flagged items first
--   luajit tools/bis_audit.lua --all      also list the items with nothing flagged
-- Runs each class in its own process through tools/smoke.lua's stubs (one class's data at a time).
local CLASSES = { "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior" }

if arg[1] == "--class" then
  -- Child: load Prepped for one class silently, then print one tab-separated line per BiS pick.
  local A = dofile("tools/audit_lib.lua")
  local realPrint = print
  print = function() end
  arg = { [0] = "tools/smoke.lua", arg[2], "-" }
  local ok, err = pcall(dofile, "tools/smoke.lua")
  print = realPrint
  if not ok then io.stderr:write(arg[1] .. ": " .. tostring(err) .. "\n") os.exit(1) end
  local ns = _G.PREPPED_NS
  local Core = ns.Core
  for k in pairs(ns.cdb.filters) do ns.cdb.filters[k] = false end
  ns.cdb.weights = {}
  Core.changed(true)
  local d = Core.data()
  local token = select(2, UnitClass("player"))
  for _, spec in ipairs(ns.Spec.specsOf(token)) do
    local r = Core.bisReport(spec)
    for inv, b in pairs(r and r.slots or {}) do
      local item = d.items[b.id] or {}
      local tags = {}
      if d.repTagged and d.repTagged[b.id] then tags[#tags + 1] = "reputation" end
      if d.profTagged and d.profTagged[b.id] then tags[#tags + 1] = "profession BoP" end
      if item.pvp or item.pvpRank then tags[#tags + 1] = "PvP" end
      if ns.Lists.darkmoon and ns.Lists.darkmoon[b.id] then tags[#tags + 1] = "Darkmoon" end
      local srcs = {}
      for _, s in ipairs(type(item.sources) == "table" and item.sources or {}) do srcs[#srcs + 1] = A.sourceText(s) end
      realPrint(table.concat({ b.id, token, spec, Core.SLOT_NAME[inv] or inv, item.name or b.name or "?",
        table.concat(A.flags(item), "; "), table.concat(tags, ", "), table.concat(srcs, " | ") }, "\t"))
    end
  end
  os.exit(0)
end

-- Parent: run each class, merge the picks by item.
local showAll = arg[1] == "--all"
local items, order = {}, {}
for _, class in ipairs(CLASSES) do
  local p = assert(io.popen("luajit tools/bis_audit.lua --class " .. class))
  for line in p:lines() do
    local id, token, spec, slot, name, flags, tags, srcs = line:match("^(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
    if id then
      local it = items[id]
      if not it then
        it = { id = id, name = name, slot = slot, flags = flags, tags = tags, srcs = srcs, specs = {} }
        items[id] = it
        order[#order + 1] = it
      end
      local key = spec
      local seen = false
      for _, s in ipairs(it.specs) do if s == key then seen = true end end
      if not seen then it.specs[#it.specs + 1] = key end
    end
  end
  p:close()
end
table.sort(order, function(a, b) if a.slot ~= b.slot then return a.slot < b.slot end return a.name < b.name end)

local function show(it)
  print(string.format("%s (%s) · %s · %s", it.name, it.id, it.slot, table.concat(it.specs, ", ")))
  if it.flags ~= "" then print("    look: " .. it.flags) end
  if it.tags ~= "" then print("    a filter removes it: " .. it.tags) end
  print("    sources: " .. (it.srcs ~= "" and it.srcs or "none"))
end

local flagged, filtered, plain = {}, {}, {}
for _, it in ipairs(order) do
  if it.flags ~= "" and it.tags == "" then flagged[#flagged + 1] = it
  elseif it.tags ~= "" then filtered[#filtered + 1] = it
  else plain[#plain + 1] = it end
end
print(string.format("BiS audit, no filters, %d classes: %d items picked; %d to look at, %d a filter removes, %d ordinary",
  #CLASSES, #order, #flagged, #filtered, #plain))
print("\n== To look at (flagged, no filter covers them)")
for _, it in ipairs(flagged) do show(it) end
print("\n== A filter removes these (flags shown if any)")
for _, it in ipairs(filtered) do show(it) end
if showAll then
  print("\n== Ordinary")
  for _, it in ipairs(plain) do show(it) end
end
