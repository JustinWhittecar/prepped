# Changelog

All notable changes to Prepped. Versions follow the release tags (`v0.1.0-beta` → `## [0.1.0-beta]`).

## [Unreleased]

## [0.1.0-beta] - 2026-11-24

The first public beta.

### Added
- Readiness score: gear, enchants and consumables against Pre-raid BiS, scored with SimGear Forever's
  scoring for your spec, plus a "Raid now" score from the buffs you have up inside a raid.
- Tracker with a to-do list sorted by gain: missing consumables, gear and enchant upgrades.
- Pre-raid BiS per slot, with Forever's server-only tier 0.5 items and set bonuses. Never targets raid
  or world boss loot, the Abyssal Council, the other faction's gear, or quests that aren't on Forever.
- Obtainable filters: reputation, profession bind-on-pickup (Forever's own crafts included), PvP rank,
  Darkmoon Faire and unconfirmed consumables.
- Slot panel on the character sheet: each slot's worn item against BiS, with where to get it.
- Item tooltip line: % of BiS and readiness gain; hold Shift for your other spec.
- Loot alert in chat when a BiS item for one of your specs drops or comes up for roll.
- Consumable plan sized to the raid night length, one buff per stat.
- Onyxia attunement blocker with quest-chain progress.
- Buff reminder bar in raids, optionally in 5-player dungeons.
- Stat weights per spec from a dropdown: SimGear's, the Raid Ready (MythicSim) preset, or Custom,
  edited in its own panel.
- Works without SimGear's class data: a snapshot of it ships with Prepped and loads when needed.
- Commands: `/prep`, `/prep options`, `/prep spec`, `/prep weights`, `/prep buffs test`,
  `/prep reset`, `/prep debug`.
