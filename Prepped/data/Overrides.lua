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
