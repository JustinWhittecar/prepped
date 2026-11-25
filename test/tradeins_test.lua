local T = dofile("test/lib.lua")
local ns = T.load({}, "data/TradeIns.lua", "TradeIns.lua")
local TI, data = ns.TradeIns, ns.TradeInData

-- The generated data: every class, both quests' hand-ins as the druid's Forever quests list them.
T.eq("druid head quest", TI.forSlot(data, "DRUID", "Alliance", "INVTYPE_HEAD").quest, "Saving the Best for Last")
T.eq("robe is chest", TI.forSlot(data, "DRUID", "Alliance", "INVTYPE_ROBE").quest, "Saving the Best for Last")
T.eq("horde turn-in", TI.forSlot(data, "DRUID", "Horde", "INVTYPE_HEAD").turnIn, "Mokvar")
T.eq("no quest for neck", TI.forSlot(data, "DRUID", "Alliance", "INVTYPE_NECK"), nil)
T.eq("paladin is alliance only", TI.forSlot(data, "PALADIN", "Horde", "INVTYPE_HEAD"), nil)
local shoulders = TI.forSlot(data, "DRUID", "Alliance", "INVTYPE_SHOULDER")
T.eq("shoulders: three hand-ins", #shoulders.needs, 3)
T.eq("shoulders turned in to Deliana", shoulders.turnIn, "Deliana")
for _, token in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
  local side = token == "SHAMAN" and "Horde" or "Alliance"
  local n = 0
  for _, loc in ipairs({ "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND" }) do
    if TI.forSlot(data, token, side, loc) then n = n + 1 end
  end
  T.eq(token .. ": all 8 slots", n, 8)
end

-- Source text: the quest, who takes it, the hand-ins and the gold.
local head = TI.forSlot(data, "DRUID", "Alliance", "INVTYPE_HEAD")
local wrist = TI.forSlot(data, "DRUID", "Alliance", "INVTYPE_WRIST")
T.eq("source text", TI.sourceText(head), "Quest: Saving the Best for Last (Deliana) · hand in Wildheart Cowl + Wildheart Vest")
T.eq("source with gold and count", TI.sourceText(wrist), "Quest: An Earnest Proposition (Deliana) · hand in 15 Winterspring Blood Sample + Wildheart Bracers + 20g")

-- Status: what you have of each hand-in, bags and bank.
local function counts(t) return function(id) return t[id] or 0 end end
local st = TI.status(shoulders, counts({ [16718] = 1 }))
T.eq("missing two", #st.missing, 2)
T.eq("not ready", st.ready, false)
T.eq("label lists what's missing", TI.label("Feralheart Epaulets", st), "Feralheart Epaulets: need Wildheart Boots, Wildheart Kilt")
local ready = TI.status(head, counts({ [16720] = 1, [16706] = 1 }), false, true)
T.eq("ready", ready.ready, true)
T.eq("ready label", TI.label("Feralheart Cap", ready), "Feralheart Cap: turn in Saving the Best for Last (Deliana)")
T.eq("head quest follows", head.after.quest, "Back to the Beginning")
local early = TI.status(head, counts({ [16720] = 1, [16706] = 1 }))
T.eq("not open yet", early.open, false)
T.eq("ready, chain not there yet", TI.label("Feralheart Cap", early),
  "Feralheart Cap: hand-ins ready, Saving the Best for Last opens after Back to the Beginning")
T.eq("no prerequisite: open", TI.status(wrist, counts({})).open, true)
local partial = TI.status(wrist, counts({ [21928] = 6, [16714] = 1 }))
T.eq("counted hand-in shows have/need", TI.label("Feralheart Bands", partial), "Feralheart Bands: need Winterspring Blood Sample 6/15")
local done = TI.status(head, counts({}), true)
T.eq("quest done: nothing missing", done.ready, true)
T.eq("quest done label", TI.label("Feralheart Cap", done), "Feralheart Cap: buy from Deliana (quest done)")

-- Which quests take an item: the tooltip's hand-in line.
local used = TI.usedFor(data, "DRUID", "Alliance", 16719)
T.eq("kilt goes to one quest", #used, 1)
T.eq("kilt's quest", used[1].quest, "Anthion's Parting Words")
T.eq("other class's piece: none", #TI.usedFor(data, "MAGE", "Alliance", 16719), 0)
T.eq("tooltip with targets", TI.tooltipLine(used[1], { "Feralheart Epaulets", "Feralheart Walkers" }),
  "Prepped: hand in at Anthion's Parting Words (Deliana) for Feralheart Epaulets, Feralheart Walkers")
T.eq("tooltip without targets", TI.tooltipLine(used[1], {}), "Prepped: tier 0.5 hand-in for Anthion's Parting Words (Deliana)")

T.done()
