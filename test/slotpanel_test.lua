local T = dofile("test/lib.lua")
local ns = T.load({}, "SlotPanel.lua")
local SP = ns.SlotPanel

local function item(name, sources, slot) return { name = name, sources = sources or {}, slot = slot } end
local function b(id, name, points, sources, slot) return { id = id, item = item(name, sources, slot), points = points } end
local function byInv(rows) local o = {} for _, r in ipairs(rows) do o[r.inv] = r end return o end

-- Paper-doll order, left column then right then weapons.
local panel = SP.build({ spec = "FERAL_CAT", state = { badge = "SimGear live" }, slotData = { bis = {}, worn = {}, total = 100 } })
local order = {}
for i, r in ipairs(panel.rows) do order[i] = r.inv end
T.eq("order", table.concat(order, ","), "1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17,18")
T.eq("labels", panel.rows[11].label .. "/" .. panel.rows[12].label, "Ring 1/Ring 2")
T.eq("badge kept", panel.badge, "SimGear live")

-- A slot: % of BiS from the points worn, the gain as a share of the whole readiness total.
local bis = { [1] = b(100, "Helm of Bis", 40, { { type = "boss", name = "Rend", zone = "Blackrock Spire" } }) }
local worn = { [1] = { id = 7, name = "Old Helm", points = 30 } }
local rows = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 200 } }).rows)
local head = rows[1]
T.near("head pct", head.pct, 0.75)
T.eq("head pct text", head.pctText, "75%")
T.near("head gain", head.gain, 10 / 200)
T.eq("head gain text", head.gainText, "+5%")
T.eq("head not bis", head.isBis, false)
T.eq("head bis name", head.bisName, "Helm of Bis")
T.eq("head source", head.source, "Boss: Rend (Blackrock Spire)")
T.eq("head worn name", head.wornName, "Old Helm")

-- Wearing the BiS: a star (colour never carries it alone), 100%, no gain line.
worn[1] = { id = 100, name = "Helm of Bis", points = 40 }
head = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 200 } }).rows)[1]
T.eq("bis star", head.isBis, true)
T.eq("bis name starred", head.bisText, "★ Helm of Bis")
T.eq("bis pct", head.pctText, "100%")
T.eq("bis no gain", head.gainText, "")
-- A worn item better than BiS (it can't be a target, say) caps at 100%, never a negative gain.
worn[1] = { id = 8, name = "Raid Helm", points = 55 }
head = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 200 } }).rows)[1]
T.eq("capped pct", head.pctText, "100%")
T.eq("capped gain", head.gainText, "")
-- A tiny gain still shows as a gain.
worn[1] = { id = 9, name = "Close Helm", points = 39.5 }
head = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 200 } }).rows)[1]
T.eq("tiny gain", head.gainText, "+<1%")

-- An item Prepped can't read: no number, ever.
worn[1] = { id = 9, unread = true }
head = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 200 } }).rows)[1]
T.eq("unread pct", head.pct, nil)
T.eq("unread text", head.pctText, "Not scored by Prepped")
T.eq("unread gain", head.gainText, "")
-- Empty slot: 0% and the whole BiS as the gain.
worn[1] = nil
head = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 200 } }).rows)[1]
T.eq("empty pct", head.pctText, "0%")
T.eq("empty gain", head.gainText, "+20%")
T.eq("empty worn", head.wornName, nil)
-- A slot with no target.
rows = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = {}, total = 200 } }).rows)
T.eq("no target text", rows[2].pctText, "No target")
T.eq("no target bis", rows[2].bisText, "No target for this slot")

-- A target worth nothing to the spec (an idol for the wrong form): no % to claim.
rows = byInv(SP.build({ state = {}, slotData = { bis = { [18] = b(400, "Idol", 0) }, worn = {}, total = 200 } }).rows)
T.eq("zero target pct", rows[18].pctText, "")
T.eq("zero target gain", rows[18].gainText, "")

-- Rings: a worn BiS ring counts in whichever slot it sits; the other BiS goes to the other slot.
bis = { [11] = b(201, "Ring A", 20), [12] = b(202, "Ring B", 10) }
worn = { [11] = { id = 50, name = "Ring X", points = 5 }, [12] = { id = 201, name = "Ring A", points = 20 } }
rows = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 100 } }).rows)
T.eq("ring 2 holds A", rows[12].bisName, "Ring A")
T.eq("ring 2 is bis", rows[12].isBis, true)
T.eq("ring 1 gets B", rows[11].bisName, "Ring B")
T.eq("ring 1 pct", rows[11].pctText, "50%")
T.eq("ring 1 gain", rows[11].gainText, "+5%")

-- A two-hander as BiS: the main hand row weighs both hands' worn points, the off hand row says why it's empty.
bis = { [16] = b(300, "Big Staff", 50, nil, "INVTYPE_2HWEAPON") }
worn = { [16] = { id = 60, name = "Mace", points = 20 }, [17] = { id = 61, name = "Lamp", points = 5 } }
rows = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 100 } }).rows)
T.eq("2h main pct", rows[16].pctText, "50%")
T.eq("2h main gain", rows[16].gainText, "+25%")
T.eq("2h off text", rows[17].bisText, "Two-hander: see main hand")
T.eq("2h off no pct", rows[17].pctText, "")
T.eq("2h off no gain", rows[17].gainText, "")

-- Sources: SimGear's records and Prepped's own { text } ones; the first two, then "+n more".
T.eq("quest src", SP.sourceText({ type = "quest", name = "Foo", zone = "Bar", level = 58 }), "Quest: Foo (Bar, Lv58)")
T.eq("drop chance", SP.sourceText({ type = "drop", name = "Mob", zone = "Strat", chance = 0.05 }), "Drop: Mob (Strat) 5.0%")
T.eq("crafted", SP.sourceText({ type = "crafted", name = "Leatherworking" }), "Crafted: Leatherworking")
T.eq("world", SP.sourceText({ type = "world", note = "World drop from level 50-60 NPCs" }), "World drop from level 50-60 NPCs")
T.eq("prepped text", SP.sourceText({ kind = "vendor", text = "Pix, Booty Bay · 100 Reals" }), "Pix, Booty Bay · 100 Reals")
T.eq("many", SP.sourcesText({ sources = { { text = "A" }, { text = "B" }, { text = "C" } } }), "A; B; +1 more")
T.eq("none", SP.sourcesText({ sources = {} }), "Source unknown")

-- No data at all: the badge says why and there are no rows to draw.
panel = SP.build({ state = { badge = "SimGear not installed" } })
T.eq("no data rows", #panel.rows, 0)
T.eq("no data badge", panel.badge, "SimGear not installed")

-- The selected slot's detail lines: worn, BiS, gain, source.
bis = { [1] = b(100, "Helm of Bis", 40, { { kind = "reputation", text = "Argent Dawn, Revered" } }) }
worn = { [1] = { id = 7, name = "Old Helm", points = 30 } }
head = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 200 } }).rows)[1]
local d = SP.detail(head)
local texts = {}
for i, l in ipairs(d) do texts[i] = l.text end
T.eq("detail", table.concat(texts, " | "),
  "Head | Worn: Old Helm (75% of BiS) | BiS: Helm of Bis | Upgrade: +5% readiness | Source: Argent Dawn, Revered")
worn[1] = { id = 100, name = "Helm of Bis", points = 40 }
head = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 200 } }).rows)[1]
texts = {}
for i, l in ipairs(SP.detail(head)) do texts[i] = l.text end
T.eq("detail bis", table.concat(texts, " | "), "Head | Worn: ★ Helm of Bis (BiS) | Source: Argent Dawn, Revered")
worn[1] = { id = 9, unread = true }
head = byInv(SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 200 } }).rows)[1]
texts = {}
for i, l in ipairs(SP.detail(head)) do texts[i] = l.text end
T.eq("detail unread", texts[2], "Worn: item 9 (Not scored by Prepped)")

-- Below 60, like the tracker: a note, no rows. No data: the badge's own explanation.
panel = SP.build({ state = { level = 52, badge = "SimGear live" }, slotData = { bis = {}, worn = {}, total = 1 } })
T.eq("below 60 rows", #panel.rows, 0)
T.eq("below 60 note", panel.note, "Prepped activates at 60")
panel = SP.build({ state = { level = 60, badge = "SimGear not installed" } })
T.eq("no data note", panel.note, "Install SimGear Forever: Prepped scores gear with its data.")

-- The slot shown before any hover: the one with the biggest gain, else the first.
bis = { [1] = b(100, "Helm", 40), [5] = b(101, "Chest", 60) }
worn = { [1] = { id = 7, points = 30 }, [5] = { id = 8, points = 20 } }
panel = SP.build({ state = {}, slotData = { bis = bis, worn = worn, total = 100 } })
T.eq("default biggest gain", SP.defaultSlot(panel.rows), 5)
T.eq("default first when none", SP.defaultSlot(SP.build({ state = {}, slotData = { bis = {}, worn = {}, total = 1 } }).rows), 1)
T.eq("default none without rows", SP.defaultSlot({}), nil)

-- Badge help: what each status means, for the hover.
T.eq("help live", SP.badgeHelp("SimGear live"), "Scores use SimGear Forever's data, read live.")
T.eq("help snapshot", SP.badgeHelp("Snapshot 19 Nov"), "SimGear isn't loaded: scores use Prepped's saved copy of its data (19 Nov).")
T.eq("help estimated", SP.badgeHelp("Estimated weights"),
  "SimGear's weights for this spec are placeholders, not sims: treat the score as rough.")

T.done()
