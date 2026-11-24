-- Stat weight presets, in attack power units (1 AP = 1), by SimGear's stat names. Chosen per spec in
-- the options window; SimGear's own simmed weights stay the default.
--
-- Raid Ready (MythicSim): the weights the Raid Ready sheet settled on for Aliaira, Nov 2026, from
-- MythicSim's level-60 feral boards (cat re-fetched 19 Nov, bear threat 22 Nov). Raid Ready's stat
-- names: agi, str, sta, critPct -> MeleeCrit, hitPct -> MeleeHit, dodgePct -> Dodge, defrtng ->
-- Defense, armorbonus -> Armor, dps -> weapon DPS. Its expertise (cat 18.3, bear 77.15 per 1%) and
-- haste have no SimGear stat; expertise reaches the one item with it through data/Overrides.lua.
-- Raid Ready weighs bonus armor only; SimGear's items list all their armor, so here Armor applies to
-- all of it.
local _, ns = ...
local RAID_READY = "Raid Ready (MythicSim)"
ns.WeightPresets = {
  FERAL_CAT = {
    { id = "raidready", name = RAID_READY, weights = {
      AttackPower = 1, Agility = 2.75, Strength = 2.43, MeleeCrit = 30.1, MeleeHit = 18.9,
      MainHandDps = 9.09, TwoHandDps = 9.09 } },
  },
  FERAL_BEAR = {
    { id = "raidready", name = RAID_READY, weights = {
      AttackPower = 1, Agility = 3.42, Strength = 2.2, Stamina = 4.03, MeleeCrit = 21.81, MeleeHit = 33.73,
      Dodge = 33.18, Defense = 5.36, Armor = 0.71, MainHandDps = 14, TwoHandDps = 14 } },
  },
}
