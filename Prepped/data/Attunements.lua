-- Raid attunements: the item that lets you in, and the quest chain that gives it, per faction.
-- Hand-kept. Quest IDs and order from cMaNGOS classic-db ec4f596146 (PrevQuestId chains ending in
-- the quest that rewards the item). Not yet checked against Forever's own quest IDs.
-- A raid that needs no attunement has no entry (Barrow Deeps, Hyjal Summit).
local _, ns = ...
ns.Attunements = {
  ONYXIA = {
    raid = "Onyxia",
    item = 16309, itemName = "Drakefire Amulet",
    chains = {
      Alliance = {
        { 4182, "Dragonkin Menace" }, { 4183, "The True Masters" }, { 4184, "The True Masters" },
        { 4185, "The True Masters" }, { 4186, "The True Masters" }, { 4223, "The True Masters" },
        { 4224, "The True Masters" }, { 4241, "Marshal Windsor" }, { 4242, "Abandoned Hope" },
        { 4264, "A Crumpled Up Note" }, { 4282, "A Shred of Hope" }, { 4322, "Jail Break!" },
        { 6402, "Stormwind Rendezvous" }, { 6403, "The Great Masquerade" }, { 6501, "The Dragon's Eye" },
        { 6502, "Drakefire Amulet" },
      },
      Horde = {
        { 4903, "Warlord's Command" }, { 4941, "Eitrigg's Wisdom" }, { 4974, "For The Horde!" },
        { 6566, "What the Wind Carries" }, { 6567, "The Champion of the Horde" },
        { 6568, "The Testament of Rexxar" }, { 6569, "Oculus Illusions" }, { 6570, "Emberstrife" },
        -- The three Tests of Skulls can be done in any order; all three come before Axtroz.
        { 6582, "The Test of Skulls, Scryer" }, { 6583, "The Test of Skulls, Somnus" },
        { 6584, "The Test of Skulls, Chronalis" }, { 6585, "The Test of Skulls, Axtroz" },
        { 6601, "Ascension..." }, { 6602, "Blood of the Black Dragon Champion" },
      },
    },
  },
}
