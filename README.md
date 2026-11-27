# Prepped: Forever Raid Readiness (SimGear companion)

Prepped is a World of Warcraft: Forever addon (Interface 16001) that tells you how ready you are for
raid night as one number, and what to do next to raise it. It builds on
[SimGear Forever](https://www.curseforge.com/wow/addons/simgearforever)'s gear scores and item data.

Status: beta, English only. The content target is **Pre-raid**. Raid loot targets will follow once
loot data for them exists.

## What it does

- **One readiness score.** The tracker header shows `Prep NN%`: your gear, enchants and
  consumables against the same three at Pre-raid best-in-slot, scored for your spec. Consumables
  count from what's in your bags. Inside a raid it also shows `Raid now NN%`, the same score with
  consumables counted from the buffs you have up right now.
- **A to-do list, biggest gain first.** The tracker lists the missing consumables (`have/need` for
  the raid night) and up to eight gear and enchant upgrades, each with the readiness it would add
  (`+3%`).
- **Pre-raid BiS per slot**, picked with SimGear's own scoring. You can leave out reputation items,
  profession bind-on-pickup items, PvP rank items and Darkmoon Faire items. Raid loot, quest
  rewards that need a raid drop, AQ-war quests Forever doesn't have and consumables not yet confirmed
  on Forever (Jujus) are never picked. Forever's server-only tier 0.5 items, which SimGear can't see,
  are included, and so are their set bonuses.
- **Tier 0.5 hand-ins**, every class: a tier 0.5 piece names the quest that gives it, and its to-do
  lists the dungeon set pieces you still need to hand in. The hand-in items get a tooltip line so
  they don't get vendored.
- **A consumable plan** sized to your raid night length (3 hours by default). Buffs of the same stat
  don't stack, so you choose one per stat. Flask, food and weapon buffs are one choice each. You can
  switch consumables off in the options: the score is then gear and enchants only, with no
  consumable to-dos and no buff bar.
- **Attunement blockers**: a `Blocked:` line for Onyxia while you lack the Drakefire Amulet, with
  progress through the quest chain for your faction.
- **Buff reminders**: a bar of missing consumable buffs, hidden in combat. Show it never, in instances
  only (raids and 5-player dungeons, the default) or always.
- **Stat weights per spec**: SimGear's simmed weights by default, a preset, or your own.
- **Spec detection** from talents for each talent group, with a manual override.

## Install

1. Install **SimGear Forever** (CurseForge). Prepped reads its per-class data addons
   (`SimGearForever_<Class>`) and loads the one for your class when needed.
2. Install Prepped from CurseForge or Wago, or copy the `Prepped` folder from a release zip into
   `World of Warcraft/_forever_/Interface/AddOns/`.
3. Log in. The tracker appears and `/prep` toggles it. The minimap addon menu works too:
   left-click toggles the tracker and right-click opens the options.

The release zip also holds nine small data addons, `PreppedBackup_<Class>`: a snapshot of
SimGear's level-60 gear data for each class. Prepped loads yours only when SimGear's own data is
missing or not in the shape it expects, and the tracker badge then reads "Snapshot <date>" instead
of "SimGear live". Keep them installed; they cost nothing while SimGear works.

## Commands

| Command | What it does |
| --- | --- |
| `/prep` | Show or hide the tracker |
| `/prep options` | Open the options window (`/prep o` works too) |
| `/prep spec <name>` or `/prep spec auto` | Pick the spec for your current talent group, or go back to detecting it |
| `/prep weights` | Show the stat weights in use |
| `/prep weights <stat> <value>` | Set one weight in your Custom set and switch to it (`/prep weights simgear` switches back) |
| `/prep pick` | List your picks: slots where you chose your own target instead of Prepped's BiS |
| `/prep pick <slot> <item link>` or `/prep pick <slot> auto` | Make an item your target for a slot (say a cheaper BoE), or go back to Prepped's BiS. Slots: head neck shoulder back chest wrist hands waist legs feet ring1 ring2 trinket1 trinket2 mainhand offhand ranged. Right-clicking a row in the slot panel does the same from a menu |
| `/prep equip` | Put on the best gear in your bags for the spec Prepped is scoring (the Equip best button under the slot panel does the same). Bind-on-equip items stay in your bags; out of combat only |
| `/prep buffs never`, `instances` or `always` | When the buff reminder bar shows |
| `/prep reset` | Put the tracker and buff bar back where they started |
| `/prep debug` | Print what Prepped sees: data status, spec, the score parts, the BiS per slot |

If another addon already uses `/prep`, Prepped says so and you can use `/prepped` instead.

## How the score works

Everything is scored in SimGear's points for your spec: an item's stats times SimGear's stat weights,
using SimGear's own scoring code, including its hit cap handling. Your gear score is the points of
what you wear. Enchants and consumables are scored the same way, from the stats they give. Prepped adds up those three
parts and divides them by the same three at Pre-raid BiS: the best item SimGear scores for each slot
among what your filters allow, the best enchant for it, and a full consumable plan. 100% means
nothing on the list can raise your score further. Each to-do shows its own gain on the same scale.
When you choose other stat weights, they're scaled to SimGear's worth of one attack power and used in
place of SimGear's. Item effects SimGear doesn't value, such as some bear trinkets, get hand-set
values from `Prepped/data/Overrides.lua`.

## Credits and licences

Prepped is free software under the **GNU GPL, version 3 or later** (see `LICENSE`).

- **[SimGear Forever](https://www.curseforge.com/wow/addons/simgearforever)** by Flavius and
  contributors provides the item data, sources and gear scores Prepped reads at runtime. Its scoring
  code is copied unmodified into `Prepped/vendor/SimGear/` under the **MIT licence**. See the
  `LICENSE` and `README` files there. SimGear's item data is derived from cMaNGOS and is GPL-3.0-or-later.
- **MythicSim**: SimGear's stat weights and set bonus values come from MythicSim sims. The
  "Raid Ready (MythicSim)" weight preset and the hand-set effect values in `data/Overrides.lua` are
  calibrated to MythicSim's level-60 feral boards.
- **[cMaNGOS classic-db](https://github.com/cmangos/classic-db)** (GPL-3.0), commit `ec4f596146`:
  the reputation, profession and Darkmoon Faire lists (`data/Lists.lua`), the attunement quest chains
  and the excluded-item review.
- **ProfPlanner** community data: Forever consumable item IDs.
- **RankedBoost**'s WoW Forever consumables guide: consumable values and durations.

World of Warcraft is a trademark of Blizzard Entertainment. Prepped is not affiliated with Blizzard
or with the SimGear Forever authors.

## Translations

The interface is English only for now. `Prepped/Locales/enUS.lua` defines `ns.L`, which returns the
key itself for any string without a translation. It loads first in the `.toc`. Strings will move
there module by module once the UI settles: `print("tracker shown")` becomes
`print(L["tracker shown"])`, which still prints the same English until a locale file sets the key.
A new language goes in `Prepped/Locales/<locale>.lua`, listed after `enUS.lua`. It starts with
`if GetLocale() ~= "<locale>" then return end` and sets only the keys it translates.

## Maintainers

### Layout

`Prepped/` is the addon. `test/` holds the tests (`./run_tests.sh`, luajit) and `tools/` holds the
build and data scripts. `.pkgmeta` packages `Prepped/` and the `PreppedBackup_<Class>/` data addons
into one zip and leaves out tests, tools and repo files.

The tests need SimGear's class data installed. They read
`~/WoW/_forever_/Interface/AddOns/SimGearForever_<Class>/`, or the directory in `PREPPED_SIMGEAR_DIR`.
With `PREPPED_TEST_DATA=backup` they read Prepped's own snapshot (`PreppedBackup_<Class>/Data.lua`)
instead; CI does that, so it needs no CurseForge download key. Run them against the installed
SimGear before a release.

### One-time setup

1. Create the GitHub repo and push.
2. CurseForge project: `preppedforever`, ID 1829038 (in `Prepped/Prepped.toc`). Logo: `art/logo-400.png`.
3. Wago (optional, not set up yet): create the project, add a `## X-Wago-ID:` line to the .toc and
   the `WAGO_API_TOKEN` secret.
4. Add the repository secrets:
   - `CF_API_KEY`: a CurseForge upload API token (https://authors.curseforge.com/#/settings/api-tokens).
     The workflow passes it to the packager as `CF_API_TOKEN`, which replaces the deprecated
     `CF_API_KEY` variable name.
   - `WAGO_API_TOKEN` (only with Wago): a Wago Addons API token (Wago developer dashboard).
   - `CF_CORE_API_KEY` (optional): a CurseForge **Core** API key (https://console.curseforge.com),
     a different key from the upload token. Only the SimGear-watch workflow uses it; leave that
     workflow disabled until the key exists.

### Release steps

1. Move the `Unreleased` notes in `CHANGELOG.md` under a heading named exactly for the tag version,
   e.g. `## [0.1.0-beta] - 2026-12-01`. The release job fails without one.
2. Commit, then `git tag v0.1.0-beta && git push origin v0.1.0-beta`.
3. `.github/workflows/release.yml` checks that the secrets and toc IDs are present, runs the tests,
   then runs `BigWigsMods/packager@v2`. The packager builds the zip, uploads it to CurseForge and Wago
   and attaches it to a GitHub release. A tag containing `beta` or `alpha` uploads as that release
   type.

The `.toc` version is `@project-version@`, which the packager replaces with the tag. In a git
checkout loaded straight into the game, the options title shows the literal `@project-version@`.

To build locally without uploading, clone https://github.com/BigWigsMods/packager and run
`release.sh -d` from the repo root. The zip lands in `.release/`.

### Game versions for Forever (checked 2026-11-23)

The packager takes the game version from the `.toc`'s `## Interface:` line. It turns `16001` into
`1.60.1` and files it under the Forever game type, because any `16???` interface counts as Forever.
It then looks that version up on each site:

- **CurseForge**: game version type `88568` (Forever) in CurseForge's `/api/game/wow/versions`. If
  `1.60.1` isn't listed, it falls back to the nearest lower Forever version, then the highest.
- **Wago**: the `forever` patch list from `https://addons.wago.io/api/data/game`, with the same
  fallback, sent as `supported_forever_patches`.
- **WoWInterface** has no Forever game type, and the packager skips Forever there.

Forever support first shipped in packager v2.6.0 (commit `7391c8d`, "Add WoW Forever support
(#202)", 2026-09-17). The current release is v2.7.0 (2026-11-04), and the `v2` tag used here points
to it.

**What's confirmed:** CurseForge has a Forever game version `1.60.1`. The SimGear Forever page lists
its 0.16.0 file (21 Nov 2026) under game version "1.60.1", and other Forever addons on CurseForge
target Interface 16001. **Not confirmed:** whether Wago's `forever` list contains `1.60.1`. The
packager has code for it, but this was not checked against Wago's API. Check it on the first
release: the job log prints `WARNING: No Wago game version match` if it isn't listed.

Sources:
- Packager source, `release.sh` v2.7.0: `toc_to_type` (`16???` → forever), `upload_curseforge`
  (`forever) game_id=88568`), `upload_wago` (`supported_${wago_type}_patches`):
  https://github.com/BigWigsMods/packager/blob/v2.7.0/release.sh
- Packager README, multi-interface example including `16001` "Forever Beta":
  https://github.com/BigWigsMods/packager#readme
- SimGear Forever on CurseForge (project 1754471, file game version 1.60.1):
  https://www.curseforge.com/wow/addons/simgearforever
- Forever addons on CurseForge declaring Interface 16001, e.g.
  https://www.curseforge.com/wow/addons/keepward and
  https://www.curseforge.com/wow/addons/macro-manager-forever

### When SimGear releases

SimGear Forever publishes on CurseForge only (project 1754471). There's no public source repo or
GitHub releases page; bug reports go to its Discord. `.github/workflows/simgear-watch.yml` runs
weekly (and on demand). It reads the project's files through the CurseForge Core API
(`tools/simgear_cf.sh latest`, release-type files only) and opens one issue per version newer than
`tools/simgear-pin.txt`. The issue's checklist covers the update: diff `Prepped/vendor/SimGear/`,
rebuild the backup data addons, run the tests and the smoke run, bump the pin, and release.

The backup data addons are rebuilt with `luajit tools/build_backup.lua` (reads the installed
SimGear, pinned by `PIN` in the script; `--any-version` to override), then `luajit test/backup_test.lua`
checks that every spec's BiS from the backup matches the live data.

### Harvesting Forever items

Forever sends some items (the tier 0.5 upgrade sets, 2267xx) from the server only, so SimGear's
pipeline never sees them. Prepped asks the game about them itself. These commands are for
maintainers and aren't in the in-game help:

1. In game: `/prep harvest` scans the default range (226700-226900). `/prep harvest <from> <to>`
   scans a custom range of up to 20000 IDs. With a vendor's window open, `/prep harvest vendor`
   records its stock and prices.
2. `/reload` so the results are written to the account's `SavedVariables/Prepped.lua`.
3. From the repo root:
   `luajit tools/forever_items.lua "<WoW>/_forever_/WTF/Account/<ACCOUNT>/SavedVariables/Prepped.lua"`.
   This regenerates `Prepped/data/ForeverItems.lua` and `Prepped/data/VendorSources.lua`. Don't
   edit either file by hand.
4. Run `./run_tests.sh` and commit.

Other tools: `tools/build_lists.py` regenerates `data/Lists.lua` from cMaNGOS,
`tools/smoke.lua` loads the whole addon against stubbed WoW API calls, and `tools/simgear_crafted.lua`
lists SimGear's crafted items.
