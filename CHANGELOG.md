# Changelog

All notable changes to Prepped. Versions follow the release tags (`v0.1.0-beta` → `## [0.1.0-beta]`).

## [Unreleased]

## [0.3.0-beta] - 2026-11-25

A three-way buff reminder bar, back in 5-player dungeons, and tier 0.5 to-dos in quest-chain order.

### Changed
- The buff reminder bar has three settings: Never show, In instances only (the default) or Always
  show (anywhere out of combat). They replace the "Buff reminder in raids" check and its Test button,
  which also switched the tracker to the in-raid "Raid now" score. `/prep buffs never|instances|always`
  replaces `/prep buffs test`.
- The buff reminder bar works in 5-player dungeons again, without the flask.
- Tier 0.5 to-dos come in quest-chain order: the next quest's piece first, even when a later
  quest's piece (the head, say) would gain more. Other to-dos keep their places.

## [0.2.0-beta] - 2026-11-25

Fixes and polish from an in-game walkthrough, plus tier 0.5 hand-ins for every class.

### Added
- Your picks: choose your own target for any gear slot (a cheaper BoE in place of an expensive one,
  say). Right-click a row in the slot panel for the best options, or `/prep pick <slot> <item link>`.
  Readiness, to-dos and set bonuses then count your pick; the slot panel marks it with a lock and
  still names Prepped's BiS. Kept per character and spec.
- Tier 0.5 hand-ins, every class. A tier 0.5 BiS piece now says which quest gives it and what it
  takes; its to-do names the dungeon set pieces (and samples) you still need, says when everything
  is ready to turn in, or that the chain hasn't reached that quest yet. Hand-in items (Wildheart
  Kilt, Lightforge Breastplate...) get a tooltip line naming the quest and the BiS pieces they lead to,
  so they don't get vendored.

### Changed
- A slot's enchant to-do now always comes after that slot's BiS item, since the enchant goes on the
  new item.
- Options: the Consumables section has an on/off switch. Off, consumables leave the score, the
  tracker and the buff bar, and the section's settings hide. The raid night length moved into it.
- The "Exclude unconfirmed consumables (Jujus)" option is gone: Jujus stay out until they're
  confirmed on Forever.
- Options window: a cleaner header (icon, name, version), the stat weights dropdown matches the
  consumable dropdowns, the raid buff reminder moved into the Consumables section, the content
  target note is gone, and the window's height follows its contents. A Restore defaults button
  puts every option back (your slot picks and Custom weight values are kept).
- Item tooltips show where to get items whose source Prepped supplies and SimGear doesn't: Pix
  Xizzix's Undermine Reals stock, tier 0.5 quests and reputation vendors.
- The spec line in the options is a dropdown like the others; "Detect from talents" names what your
  talents point to.
- The loot alert also speaks up for tier 0.5 hand-ins: a Wildheart Kilt dropping says which of your
  BiS pieces it leads to and the quest (not when you already hold one).

### Removed
- Buff reminders in 5-player dungeons. Prepped is for raids.
- Leftovers from Raid Ready, Prepped's private predecessor: docking beside its panel and the one-time
  import of its spec choices.

### Fixed
- Tier 0.5 pieces showed no usable source in the slot panel.
- The profession filter missed gear that isn't crafted but needs a profession to use, such as the
  Glimmering Mithril Insignia (a quest reward that needs Blacksmithing 225).
- Raid loot could be picked as Pre-raid BiS: SimGear's stand-in items include a few raid drops
  (Onyxia's Eskhandar's Collar, Ring of Binding and Shard of the Scale; Sapphiron Drape). Items whose
  only source is a raid are never targets now.

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
