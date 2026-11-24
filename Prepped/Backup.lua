-- Backup copy: which class data Core uses. SimGear's, read live, when its shape fits; else the
-- snapshot Prepped ships (PreppedBackup_<Class>, built by tools/build_backup.lua), loaded only
-- then, since a second copy of the class data costs megabytes. Pure: the loaders are passed in.
local _, ns = ...
local Backup = {}
ns.Backup = Backup

-- class: "DRUID"; live, backup: functions returning a global shaped like SimGearForeverData, and
-- optionally why it couldn't be loaded; load: SimGear.load. Returns data or nil, problem. Data from
-- the backup carries snapshot (its build stamp) and liveProblem (why live wasn't used).
function Backup.choose(class, live, backup, load)
  local g, loadWhy = live()
  local d, why = load(g, class)
  if d then return d end
  local liveWhy = loadWhy or why
  local bg, bLoadWhy = backup()
  local b, bWhy = load(bg, class)
  if not b then return nil, liveWhy .. "; backup: " .. (bLoadWhy or bWhy) end
  local stamp = type(bg[class].snapshot) == "table" and bg[class].snapshot or {}
  b.snapshot, b.liveProblem = stamp, liveWhy
  return b
end

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- The data status badge for backup data: "Snapshot 23 Nov" from its build date (YYYY-MM-DD).
function Backup.badge(stamp)
  local _, m, d = tostring(stamp and stamp.built):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
  if not m then return "Snapshot" end
  return "Snapshot " .. tonumber(d) .. " " .. MONTHS[tonumber(m)]
end
