-- Hand-kept sources for items SimGear has but gives no source, so Prepped's BiS can target them
-- (Bis.pick skips sourceless items: they may be unreleased loot). Checked in game by the author;
-- vendor stock captured with /prep harvest vendor goes in data/VendorSources.lua instead.
local _, ns = ...
local PIX = "Pix Xizzix, Booty Bay · "
ns.ExtraSources = {
  [272396] = { kind = "vendor", text = PIX .. "100 Tarnished Undermine Reals" }, -- Shifter's Belt
  [272408] = { kind = "vendor", text = PIX .. "75 Tarnished Undermine Reals" },  -- Cutthroat's Signet
  [272437] = { kind = "vendor", text = PIX .. "125 Tarnished Undermine Reals" }, -- Adaptive Combat Assistant
  [272415] = { kind = "vendor", text = PIX .. "75 Tarnished Undermine Reals" },  -- Stalwart Cloak
}
