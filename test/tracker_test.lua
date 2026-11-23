local T = dofile("test/lib.lua")
local ns = T.load({}, "Tracker.lua")
local Tr = ns.Tracker

local function texts(view) local o = {} for i, l in ipairs(view.lines) do o[i] = l.text end return table.concat(o, " | ") end

-- Below 60: nothing but the activation note.
local v = Tr.lines({ level = 52 })
T.eq("below 60 header", v.header, "Prepped: activates at 60")
T.eq("below 60 no lines", #v.lines, 0)

-- At 60 the header carries the readiness % (rounded) and the data status badge.
v = Tr.lines({ level = 60, prep = 0.874, badge = "SimGear live" })
T.eq("header", v.header, "Prep 87% · SimGear live")
v = Tr.lines({ level = 60, prep = 0.875, badge = "Snapshot 19 Nov" })
T.eq("rounds half up", v.header, "Prep 88% · Snapshot 19 Nov")
v = Tr.lines({ level = 60, prep = nil, badge = "Estimated weights" })
T.eq("no score -> no number", v.header, "Prep: not scored · Estimated weights")

-- Blockers first, as Attune gives them, with chain progress; at most 3, then "+n more".
local ony = { text = "Blocked: Drakefire Amulet missing for Onyxia", done = 3, total = 16, next = "Marshal Windsor" }
local bank = { text = "Blocked: Drakefire Amulet is in your bank (carry it into Onyxia)" }
v = Tr.lines({ level = 60, prep = 0.5, blockers = { ony, bank } })
T.eq("blocker lines", texts(v), "Blocked: Drakefire Amulet missing for Onyxia (3/16, next: Marshal Windsor) | Blocked: Drakefire Amulet is in your bank (carry it into Onyxia)")
T.eq("blocker kind", v.lines[1].kind, "blocker")
local five = {}
for i = 1, 5 do five[i] = { text = "Blocked: raid " .. i } end
v = Tr.lines({ level = 60, prep = 0.5, blockers = five })
T.eq("capped at 3 + more", texts(v), "Blocked: raid 1 | Blocked: raid 2 | Blocked: raid 3 | +2 more")

-- Consumables short for raid night come next, as have/need; full, None and unknown slots are left out.
local cons = {
  { slot = "flask", item = { name = "Flask of the Titans" }, have = 2, need = 2 },
  { slot = "agility", item = { name = "Elixir of the Mongoose" }, have = 1, need = 3 },
  { slot = "food", item = nil, have = 0, need = 0 },                        -- None
  { slot = "strength", item = { name = "Juju Power" }, unknown = true, have = 0, need = 0 },
}
v = Tr.lines({ level = 60, prep = 0.5, blockers = { bank }, consumables = cons })
T.eq("blockers then consumables", texts(v), "Blocked: Drakefire Amulet is in your bank (carry it into Onyxia) | Elixir of the Mongoose 1/3")
T.eq("consumable kind", v.lines[2].kind, "consumable")

-- Gear to-dos last (Readiness steps, already biggest first), at most 8, each with its gain in %.
local todos = { { label = "Superior Agility on bracers", gain = 0.03 }, { label = "Hand of Justice", gain = 0.004 } }
v = Tr.lines({ level = 60, prep = 0.5, consumables = cons, todos = todos })
T.eq("consumables then gear", texts(v), "Elixir of the Mongoose 1/3 | Superior Agility on bracers (+3%) | Hand of Justice (+<1%)")
T.eq("gear kind", v.lines[2].kind, "gear")
local ten = {}
for i = 1, 10 do ten[i] = { label = "Item " .. i, gain = 0.01 } end
v = Tr.lines({ level = 60, prep = 0.5, todos = ten })
T.eq("gear capped at 8", #v.lines, 8)
T.eq("gear keeps order", v.lines[8].text, "Item 8 (+1%)")

-- In a raid: "Raid now" beside "Prep" in the header, and the tracker collapses to it.
v = Tr.lines({ level = 60, prep = 0.91, raidNow = 0.82, inRaid = true, badge = "SimGear live", consumables = cons, todos = todos })
T.eq("raid header", v.header, "Raid now 82% · Prep 91% · SimGear live")
T.eq("raid collapses", #v.lines, 0)
-- Collapsed by the player (and on first run): header only.
v = Tr.lines({ level = 60, prep = 0.5, collapsed = true, todos = todos })
T.eq("collapsed header", v.header, "Prep 50%")
T.eq("collapsed lines", #v.lines, 0)

-- Spec unclear: a one-line prompt with buttons comes first, and shows even while collapsed.
local choices = { { label = "Cat", spec = "FERAL_CAT" }, { label = "Bear", spec = "FERAL_BEAR" } }
v = Tr.lines({ level = 60, specChoices = choices, blockers = { bank }, collapsed = true })
T.eq("prompt first", v.lines[1] and v.lines[1].text, "Choose spec:")
T.eq("prompt kind", v.lines[1] and v.lines[1].kind, "choose")
T.eq("buttons", v.lines[1] and v.lines[1].buttons and (v.lines[1].buttons[1].label .. "/" .. v.lines[1].buttons[2].spec), "Cat/FERAL_BEAR")
T.eq("collapsed: only the prompt", #v.lines, 1)
v = Tr.lines({ level = 60, specChoices = choices, blockers = { bank } })
T.eq("expanded: prompt then blockers", texts(v), "Choose spec: | Blocked: Drakefire Amulet is in your bank (carry it into Onyxia)")

T.done()
