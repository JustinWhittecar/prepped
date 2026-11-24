-- Tiny test helpers. Each test file: local T = dofile("test/lib.lua"); ... ; T.done()
local T = { failed = 0, passed = 0 }

-- Loads an addon file the way WoW does: with (addonName, ns) as its varargs.
function T.load(ns, ...)
  for _, file in ipairs({ ... }) do
    local chunk = assert(loadfile("Prepped/" .. file))
    chunk("Prepped", ns)
  end
  return ns
end

local function report(ok, name, msg)
  if ok then
    T.passed = T.passed + 1
  else
    T.failed = T.failed + 1
    print("FAIL " .. name .. ": " .. msg)
  end
end

function T.eq(name, got, want)
  report(got == want, name, "got " .. tostring(got) .. ", want " .. tostring(want))
end

function T.near(name, got, want, tol)
  tol = tol or 1e-3
  report(type(got) == "number" and math.abs(got - want) <= tol, name, "got " .. tostring(got) .. ", want " .. tostring(want))
end

-- Runs an installed SimGear class data addon the way WoW does and returns the global it fills.
-- Fails closed: a missing install is an error, never a skipped test.
T.SIMGEAR_DIR = os.getenv("PREPPED_SIMGEAR_DIR")
  or (os.getenv("HOME") .. "/WoW/_forever_/Interface/AddOns")
-- PREPPED_TEST_DATA=backup: read Prepped's own snapshot (PreppedBackup_<Class>/Data.lua, from this repo)
-- in place of SimGear's addon, for CI without a CurseForge download. Never a silent fallback: unset,
-- the tests need SimGear and fail without it.
T.DATA = os.getenv("PREPPED_TEST_DATA") or "simgear"
assert(T.DATA == "simgear" or T.DATA == "backup", "PREPPED_TEST_DATA must be simgear or backup, got " .. T.DATA)
local backupSeen = {}
function T.simgearGlobal(class) -- class as in the folder name, e.g. "Druid"
  if T.DATA == "backup" then
    local path = "PreppedBackup_" .. class .. "/Data.lua"
    _G.PreppedBackupData = nil
    assert(loadfile(path), "backup not found at " .. path)("PreppedBackup_" .. class, {})
    local token = class:upper()
    local g = assert(_G.PreppedBackupData and _G.PreppedBackupData[token], path .. " has no " .. token)
    if not backupSeen[class] then
      backupSeen[class] = true
      io.stderr:write("test data: " .. path .. " (Prepped's snapshot, not live SimGear)\n")
    end
    return { [token] = g }
  end
  local dir = T.SIMGEAR_DIR .. "/SimGearForever_" .. class .. "/"
  local toc = assert(io.open(dir .. "SimGearForever_" .. class .. ".toc"), "SimGear not found at " .. dir)
  local ns = {}
  _G.SimGearForeverData = nil
  for line in toc:lines() do
    if not line:match("^#") and line:match("%.lua%s*$") then
      local file = line:gsub("\\", "/"):gsub("%s+$", "")
      assert(loadfile(dir .. file))("SimGearForever_" .. class, ns)
    end
  end
  toc:close()
  return _G.SimGearForeverData
end

function T.done()
  print(string.format("%s: %d passed, %d failed", arg and arg[0] or "?", T.passed, T.failed))
  if T.failed > 0 then os.exit(1) end
end

return T
