-- Hand-kept: items Prepped never picks as a Pre-raid target, whatever the filters.
-- [item] = why. Two kinds:
--   raid kill: a quest reward that needs a raid drop or a raid boss's head.
--   not on Forever: AQ-war Silithus quests that SimGear found only in cMaNGOS, not in Forever's
--   own client (SimGear source origin "cmangos", not "client"). Forever has no Ahn'Qiraj.
-- Seeded 2026-11-23 from cMaNGOS classic-db ec4f596146 and SimGear 0.16.0, then reviewed by hand:
-- quests that only need common trade goods also dropped in raids (Runecloth, Star Ruby...) are left out.
local _, ns = ...
ns.Excluded = {
  -- raid kill
  [18398] = "MC: Hydraxian quest needs Molten Core drops", -- Tidal Loop
  [18399] = "MC: Hydraxian quest needs Molten Core drops", -- Ocean's Breeze
  [18403] = "Onyxia: head quest", -- Dragonslayer's Signet
  [18404] = "Onyxia: head quest", -- Onyxia Tooth Pendant
  [18406] = "Onyxia: head quest", -- Onyxia Blood Talisman
  [19019] = "MC: Thunderfury needs Molten Core drops", -- Thunderfury, Blessed Blade of the Windseeker
  [19366] = "BWL: Nefarian head quest", -- Master Dragonslayer's Orb
  [19383] = "BWL: Nefarian head quest", -- Master Dragonslayer's Medallion
  [19384] = "BWL: Nefarian head quest", -- Master Dragonslayer's Ring
  [21200] = "AQ40: signet chain", -- Signet Ring of the Bronze Dragonflight
  [21205] = "AQ40: signet chain", -- Signet Ring of the Bronze Dragonflight
  [21210] = "AQ40: signet chain", -- Signet Ring of the Bronze Dragonflight
  [22347] = "AQ20: The Perfect Poison", -- Fahrad's Reloading Repeater
  [22348] = "AQ20: The Perfect Poison", -- Doomulus Prime
  [22377] = "AQ20: The Perfect Poison", -- The Thunderwood Poker
  [22378] = "AQ20: The Perfect Poison", -- Ravenholdt Slicer
  [22379] = "AQ20: The Perfect Poison", -- Shivsprocket's Shiv
  [22380] = "AQ20: The Perfect Poison", -- Simone's Cultivating Hammer
  [22589] = "Naxxramas: Atiesh", -- Atiesh, Greatstaff of the Guardian
  [22630] = "Naxxramas: Atiesh", -- Atiesh, Greatstaff of the Guardian
  [22631] = "Naxxramas: Atiesh", -- Atiesh, Greatstaff of the Guardian
  [22632] = "Naxxramas: Atiesh", -- Atiesh, Greatstaff of the Guardian
  -- not on Forever
  [20699] = "not on Forever: Armaments of War (Silithus)", -- Cenarion Reservist's Legplates
  [20700] = "not on Forever: Armaments of War (Silithus)", -- Cenarion Reservist's Legplates
  [20701] = "not on Forever: Armaments of War (Silithus)", -- Cenarion Reservist's Legguards
  [20702] = "not on Forever: Armaments of War (Silithus)", -- Cenarion Reservist's Legguards
  [20703] = "not on Forever: Armaments of War (Silithus)", -- Cenarion Reservist's Leggings
  [20704] = "not on Forever: Armaments of War (Silithus)", -- Cenarion Reservist's Leggings
  [20705] = "not on Forever: Armaments of War (Silithus)", -- Cenarion Reservist's Pants
  [20707] = "not on Forever: Armaments of War (Silithus)", -- Cenarion Reservist's Pants
  [20710] = "not on Forever: Armaments of War (Silithus)", -- Crystal Encrusted Greaves
  [20711] = "not on Forever: Armaments of War (Silithus)", -- Crystal Lined Greaves
  [20712] = "not on Forever: Armaments of War (Silithus)", -- Wastewalker's Gauntlets
  [20713] = "not on Forever: Armaments of War (Silithus)", -- Desertstalkers's Gauntlets
  [20714] = "not on Forever: Armaments of War (Silithus)", -- Sandstorm Boots
  [20715] = "not on Forever: Armaments of War (Silithus)", -- Dunestalker's Boots
  [20716] = "not on Forever: Armaments of War (Silithus)", -- Sandworm Skin Gloves
  [20717] = "not on Forever: Armaments of War (Silithus)", -- Desert Bloom Gloves
  [21178] = "not on Forever: Volunteer's Battlegear (Silithus)", -- Gloves of Earthen Power
  [21179] = "not on Forever: Volunteer's Battlegear (Silithus)", -- Band of Earthen Wrath
  [21180] = "not on Forever: Champion's Battlegear (Silithus)", -- Earthstrike
  [21181] = "not on Forever: Veteran's Battlegear (Silithus)", -- Grace of Earth
  [21182] = "not on Forever: Veteran's Battlegear (Silithus)", -- Band of Earthen Might
  [21183] = "not on Forever: Veteran's Battlegear (Silithus)", -- Earthpower Vest
  [21184] = "not on Forever: Stalwart's Battlegear (Silithus)", -- Deeprock Bracers
  [21185] = "not on Forever: Stalwart's Battlegear (Silithus)", -- Earthcalm Orb
  [21186] = "not on Forever: Stalwart's Battlegear (Silithus)", -- Rockfury Bracers
  [21187] = "not on Forever: Volunteer's Battlegear (Silithus)", -- Earthweave Cloak
  [21188] = "not on Forever: Champion's Battlegear (Silithus)", -- Fist of Cenarius
  [21189] = "not on Forever: Stalwart's Battlegear (Silithus)", -- Might of Cenarius
  [21190] = "not on Forever: Champion's Battlegear (Silithus)", -- Wrath of Cenarius
  [21520] = "not on Forever: Treasure of the Timeless One (Silithus)", -- Ravencrest's Legacy
  [21521] = "not on Forever: Treasure of the Timeless One (Silithus)", -- Runesword of the Red
  [21522] = "not on Forever: Treasure of the Timeless One (Silithus)", -- Shadowsong's Sorrow
  [21523] = "not on Forever: Treasure of the Timeless One (Silithus)", -- Fang of Korialstrasz
  [22725] = "not on Forever: A Humble Offering (Silithus)", -- Band of Cenarius
}
