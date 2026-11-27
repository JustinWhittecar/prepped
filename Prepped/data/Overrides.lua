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
  -- The feral idols. SimGear lists no stats or sims for idols, so both scored 0 and the first in its
  -- list won for both forms. No sim prices them: these are Prepped's estimates, sized as cheaper
  -- core abilities (Claw and Rake -2 energy; Maul and Swipe -2 rage), each only in its own form.
  [22397] = { ap = { FERAL_CAT = 20 } }, -- Idol of Ferocity
  [23198] = { ap = { FERAL_BEAR = 30 } }, -- Idol of Brutality
  -- Restoration's idols, as healing power: Prepped's estimates, assuming a 1,000-point Regrowth and
  -- Swiftmend and about 0.4 healing per second per point of healing power. Idol of Synthesis (Pix
  -- Xizzix): ~2 heal-over-time effects take ~2 s off each Swiftmend's cooldown, ~10 more healing
  -- per second. Idol of Rejuvenation (Mor Grayhoof): 5% more Regrowth every ~10 s, ~5.
  [22398] = { specStats = { RESTORATION = { HealingPower = 12 } } }, -- Idol of Rejuvenation
  [272429] = { specStats = { RESTORATION = { HealingPower = 25 } } }, -- Idol of Synthesis
}

-- Forever's tier 0.5 sets are the classic sets under new IDs, keeping the classic 2-piece (+8 all
-- resistances) and 4-piece (a proc) word for word, so they borrow SimGear's sims of the classic
-- set's same bonuses: { [Forever set] = { [pieces] = { set = SimGear set, n = pieces } } }. Texts
-- compared 2026-11-23 (harvested tooltips vs SimGear's extras); only bonuses SimGear sims get a value.
local function classic(id) return { [2] = { set = id, n = 2 }, [4] = { set = id, n = 4 } } end
ns.SetBonusSameAs = {
  [1667] = classic(513), -- Feralheart Raiment
  [1669] = classic(515), -- Beastmaster Armor
  [1671] = classic(517), -- Sorcerer's Regalia
  [1673] = classic(516), -- Soulforge Armor
  [1675] = classic(514), -- Vestments of the Virtuous
  [1676] = classic(512), -- Darkmantle Armor
  [1679] = classic(519), -- The Five Thunders
  [1681] = classic(518), -- Deathmist Raiment
  [1778] = classic(511), -- Battlegear of Heroism
}

-- Set bonus sims Prepped doesn't trust, valued by hand instead: { [SimGear set] = { [pieces] = { ap =
-- { [spec] = attack power equivalent } } } }, turned into points by the spec's AttackPower weight.
ns.SetBonusOverrides = {
  -- Stormshroud Armor 3-piece (3% chance on melee hit to restore 18 energy): SimGear sims it at ~44
  -- points for cat (~200 AP), the same as wowsims; Raid Ready's estimate (2026-11-20) is 80-100 AP,
  -- below the ~140 AP where three Stormshroud pieces pay. Unverified in game, so the estimate stands.
  [142] = { [3] = { ap = { FERAL_CAT = 90 } } },
}

-- Unique-equipped groups: at most one item of each in BiS. { [item] = group }.
-- "Unique-Equipped: Undermine Trinkets (1)" on all four Pix Xizzix trinkets (seen in game, Raid Ready mocks).
ns.UniqueEquipped = {
  [272437] = "Undermine Trinkets", -- Adaptive Combat Assistant
  [272438] = "Undermine Trinkets", -- Weakness Analyzer
  [272439] = "Undermine Trinkets", -- Serenity Field
  [272440] = "Undermine Trinkets", -- Defender's Grip Stabilizer
}
