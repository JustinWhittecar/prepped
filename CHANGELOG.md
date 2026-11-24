# Changelog

All notable changes to Prepped. Versions follow the release tags (`v0.1.0-beta` → `## [0.1.0-beta]`).

## [Unreleased]

Planned as the first public beta, **0.1.0-beta**. It hasn't been released yet.

### Added
- Readiness score: gear, enchants and consumables against Pre-raid BiS, scored with SimGear Forever's
  scoring for your spec, plus a "Raid now" score from the buffs you have up inside a raid.
- Tracker with a to-do list sorted by gain: missing consumables, gear and enchant upgrades.
- Pre-raid BiS per slot with Obtainable filters (reputation, profession bind-on-pickup, PvP rank,
  Darkmoon Faire, unconfirmed consumables). Forever's server-only tier 0.5 items and set bonuses are
  included.
- Consumable plan sized to the raid night length, one buff per stat.
- Onyxia attunement blocker with quest-chain progress.
- Buff reminder bar in raids, optionally in 5-player dungeons.
- Stat weights per spec: SimGear's, the Raid Ready (MythicSim) preset, or Custom.
- Commands: `/prep`, `/prep options`, `/prep spec`, `/prep weights`, `/prep buffs test`,
  `/prep reset`, `/prep debug`.
- Release scaffolding: BigWigs packager config, CurseForge and Wago release workflow, weekly
  SimGear release watch, CI tests and a locale file (`Locales/enUS.lua`).
