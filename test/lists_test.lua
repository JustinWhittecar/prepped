local T = dofile("test/lib.lua")
local ns = T.load({}, "data/Lists.lua", "data/Excluded.lua")
local L = ns.Lists
print("lists: " .. L.source)

-- Known reputation rewards, one per way cMaNGOS records the requirement.
T.eq("quest needing reputation: Defender of the Timbermaw", L.reputation[21326] ~= nil, true)
T.eq("vendor behind a condition: Protector's Band (Silverwing Sentinels)", L.reputation[19515] ~= nil, true)
T.eq("vendor behind a condition: Legionnaire's Band (Warsong Outriders)", L.reputation[19513] ~= nil, true)
-- Known non-reputation items.
T.eq("Devilsaur Gauntlets are not a reputation item", L.reputation[15063], nil)
T.eq("Devilsaur Gauntlets are not profession-locked (bind on equip)", L.profession[15063], nil)
T.eq("Hand of Justice is not a reputation item", L.reputation[11815], nil)

-- Darkmoon Faire: card deck trinkets and ticket prizes.
T.eq("Darkmoon Card: Maelstrom", L.darkmoon[19289], true)
T.eq("Amulet of the Darkmoon (ticket prize)", L.darkmoon[19491], true)
T.eq("Hand of Justice is not a Darkmoon item", L.darkmoon[11815], nil)

-- Raid-only materials and quest items (generated): Pre-raid never picks these.
T.eq("Primal Batskin Bracers need Zul'Gurub bat leather", type(L.raidOnly[19687]), "string")
T.eq("Onyxia Scale Cloak needs a Scale of Onyxia", type(L.raidOnly[15138]), "string")
T.eq("Onyxia Tooth Pendant comes from the head quest", type(L.raidOnly[18404]), "string")
T.eq("Shadowskin Spaulders only need Runecloth (drops everywhere)", L.raidOnly[15822], nil)
T.eq("Fiery Plate Gauntlets only need common materials", L.raidOnly[12631], nil)
T.eq("Black Dragonscale Shoulders: no raid materials", L.raidOnly[15051], nil)
T.eq("Devilsaur Gauntlets: no raid materials", L.raidOnly[15063], nil)
-- Reputation only a raid gives: Zandalar Tribe (Zul'Gurub), Brood of Nozdormu (Temple of Ahn'Qiraj).
T.eq("Heathen's Brand (Zandalar Tribe)", type(L.raidOnly[19579]), "string")
T.eq("Defender of the Timbermaw: reputation, but not raid-only", L.raidOnly[21326], nil)

-- Hand-kept exclusions carry a reason.
for id, why in pairs(ns.Excluded) do
  if type(why) ~= "string" or why == "" then T.eq("reason for " .. id, why, "a reason") end
end
T.eq("Nefarian head ring excluded", type(ns.Excluded[19384]), "string")

T.done()
