-- Interface strings: English, and the fallback for every other client locale.
-- ns.L[key] returns the key itself when no translation is set, so code can write
-- L["Tracker shown"] today and the text stays English until someone adds a line below.
-- Called as L(key) it does the same: the copied SimGear files (vendor/SimGear) use both forms,
-- and SimGearShim.lua keeps this table instead of making its own.
--
-- Another locale goes in its own file after this one in the .toc (Locales\deDE.lua), starting
-- with: if GetLocale() ~= "deDE" then return end, and then setting only the keys it translates.
local _, ns = ...

local L = setmetatable({}, {
  __index = function(_, key) return key end,
  __call = function(self, key) return self[key] end,
})
ns.L = L

-- Strings move here as the tracker, options and chat lines settle. None have yet.
