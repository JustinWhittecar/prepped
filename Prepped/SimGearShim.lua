-- Stand-ins the copied SimGear files (vendor/SimGear) expect in their namespace.
-- Loaded before them. Prepped doesn't use SimGear's interface strings, so they pass through.
local _, ns = ...
ns.N = ns.N or function(s) return s end -- marks a string for translation
ns.L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
