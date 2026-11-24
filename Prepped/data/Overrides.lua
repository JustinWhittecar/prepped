-- Item effects SimGear doesn't value, for the specs it has no simmed value for (bear has none).
-- Used only where SimGear gives no effect for the item and spec: its own simmed values win.
--   ap     attack power equivalent per spec, turned into points by that spec's AttackPower weight
--   stats  extra stats for every spec (an on-use effect as its average); drop: listed stats that don't count
-- Values from Raid Ready, calibrated to MythicSim's trinket boards (cat 20 Nov, bear 22 Nov 2026):
-- sim DPS gain / DPS per AP, minus what the item's plain stats already score.
local _, ns = ...
ns.EffectOverrides = {
  [11815] = { ap = { FERAL_CAT = 14, FERAL_BEAR = 24 } }, -- Hand of Justice: extra-attack proc
  [22321] = { ap = { FERAL_CAT = 34, FERAL_BEAR = 77 } }, -- Heart of Wyrmthalak: fire proc (bear: threat)
  -- Adaptive Combat Assistant: +1.1% expertise, a stat SimGear doesn't have. Raid Ready's MythicSim
  -- weights put 1% expertise at 77.15 AP for bear and 18.3 AP for cat.
  [272437] = { ap = { FERAL_CAT = 20.1, FERAL_BEAR = 84.9 } },
  -- Blackhand's Breadth: SimGear lists no stats; the item's +1% crit, plus its on-use +5% crit for
  -- 20 s every 5 min as its 0.33% average.
  [13965] = { stats = { MeleeCrit = 1.33 } },
  -- Vigilance Charm: on-use +20% dodge for 20 s or 3 dodges, every 6 min, counted as ~0.5% dodge.
  [18370] = { stats = { Dodge = 0.5 } },
}
