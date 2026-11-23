"""Builds Prepped/data/Lists.lua: the items Prepped's reputation and profession filters exclude.

SimGear doesn't mark either, so they come from cMaNGOS classic-db (GPL), pinned to the commit
SimGear's own sources use.
  reputation: items that need a reputation standing, recorded three ways in cMaNGOS: on the item
              (RequiredReputationFaction), on the vendor's listing (npc_vendor or npc_vendor_template
              condition_id -> conditions type 5, "minimum reputation rank", alone or inside an AND/OR),
              and on quests (RequiredMinRepFaction: the quest's rewards).
              Crafted items from reputation recipes are NOT included: most bind on equip and can
              be bought.
  darkmoon:   rewards of quests given or turned in at Darkmoon Faire NPCs (creature SubName
              "Darkmoon Faire ...": card decks, ticket prizes) and items those NPCs sell.
  raidOnly:   [item] = why, for items that need something only a raid gives: crafted items with a
              reagent that drops (or is skinned) only on a raid map, and rewards of quests that need
              such an item, are started by one, or follow such a quest. Raid-only = looted on a raid
              map and not looted elsewhere, sold, given as a quest reward or found in a container.
              Also reputation rewards of factions only raids give (RAID_FACTIONS).
  profession: items SimGear lists as crafted that bind on pickup (bonding = 1) or need a
              profession skill to use (RequiredSkill, e.g. engineering goggles).

Usage (repo root): python3 -I tools/build_lists.py <ClassicDB .sql.gz> <crafted file>
  crafted file: output of `luajit tools/simgear_crafted.lua` (item ID, then its reagent IDs)
"""
import gzip, re, sys

COMMIT = "ec4f596146"

def tuples(sql_line):
    """Yields each row of a MySQL extended INSERT as a list of strings/None."""
    i, n = sql_line.index("VALUES") + 6, len(sql_line)
    while i < n:
        if sql_line[i] != "(":
            i += 1
            continue
        i += 1
        row, cur, inq = [], [], False
        while i < n:
            ch = sql_line[i]
            if inq:
                if ch == "\\":
                    cur.append(sql_line[i + 1]); i += 2; continue
                if ch == "'":
                    inq = False
                else:
                    cur.append(ch)
            elif ch == "'":
                inq = True
            elif ch == ",":
                row.append("".join(cur)); cur = []
            elif ch == ")":
                row.append("".join(cur)); i += 1
                break
            else:
                cur.append(ch)
            i += 1
        yield row

def columns(lines, table):
    cols, inside = [], False
    for line in lines:
        if line.startswith("CREATE TABLE `%s`" % table):
            inside = True; continue
        if inside:
            m = re.match(r"\s+`(\w+)`", line)
            if m: cols.append(m.group(1))
            elif line.startswith(")"): return cols

RAID_MAPS = {249: "Onyxia's Lair", 409: "Molten Core", 469: "Blackwing Lair", 309: "Zul'Gurub",
             509: "Ruins of Ahn'Qiraj", 531: "Temple of Ahn'Qiraj", 533: "Naxxramas"}

# Reputation earned only in a raid: its rewards are raid-only whatever the reputation filter says.
RAID_FACTIONS = {270: "Zandalar Tribe reputation (Zul'Gurub)", 910: "Brood of Nozdormu reputation (Temple of Ahn'Qiraj)"}

def rows(lines, table):
    cols = {c: k for k, c in enumerate(columns(lines, table))}
    return cols, [r for l in lines if l.startswith("INSERT INTO `%s`" % table) for r in tuples(l)]

def raid_only_items(lines):
    """[item] = raid name, for items looted on a raid map and nowhere else."""
    cc, crs = rows(lines, "creature")
    cmaps = {}
    for r in crs: cmaps.setdefault(int(r[cc["id"]]), set()).add(int(r[cc["map"]]))
    gc, grs = rows(lines, "gameobject")
    gmaps = {}
    for r in grs: gmaps.setdefault(int(r[gc["id"]]), set()).add(int(r[gc["map"]]))
    refs = {}
    rc, rrs = rows(lines, "reference_loot_template")
    for r in rrs: refs.setdefault(int(r[rc["entry"]]), []).append((int(r[rc["item"]]), int(r[rc["mincountOrRef"]])))
    def items_of(table):
        lc, lrs = rows(lines, table)
        by = {}
        for r in lrs: by.setdefault(int(r[lc["entry"]]), []).append((int(r[lc["item"]]), int(r[lc["mincountOrRef"]])))
        return by
    def expand(entries, depth=0):
        for item, mc in entries:
            if mc < 0 and depth < 5: yield from expand(refs.get(-mc, []), depth + 1)
            elif mc >= 0: yield item
    in_raid, elsewhere = {}, set()
    def note(entries, maps):
        for item in expand(entries):
            for m in maps:
                if m in RAID_MAPS: in_raid.setdefault(item, RAID_MAPS[m])
                else: elsewhere.add(item)
    tc, trs = rows(lines, "creature_template")
    cloot, sloot = items_of("creature_loot_template"), items_of("skinning_loot_template")
    for r in trs:
        maps = cmaps.get(int(r[tc["Entry"]]), set())
        note(cloot.get(int(r[tc["LootId"]]), []), maps)
        note(sloot.get(int(r[tc["SkinningLootId"]]), []), maps)
    gtc, gtrs = rows(lines, "gameobject_template")
    gloot = items_of("gameobject_loot_template")
    for r in gtrs:
        if int(r[gtc["type"]]) in (3, 25):  # chest, fishing hole
            note(gloot.get(int(r[gtc["data1"]]), []), gmaps.get(int(r[gtc["entry"]]), set()))
    for entries in items_of("item_loot_template").values():
        elsewhere.update(expand(entries))
    for table in ("npc_vendor", "npc_vendor_template"):
        vc, vrs = rows(lines, table)
        elsewhere.update(int(r[vc["item"]]) for r in vrs)
    qc, qrs = rows(lines, "quest_template")
    for r in qrs:
        for c in ["RewChoiceItemId%d" % k for k in range(1, 7)] + ["RewItemId%d" % k for k in range(1, 5)]:
            elsewhere.add(int(r[qc[c]]))
    return {i: m for i, m in in_raid.items() if i not in elsewhere}

def raid_gated_rewards(lines, qcol, raid_only, rnames):
    """[item] = why, for rewards of quests that need, start from, or follow a raid-only item."""
    ic, irs = rows(lines, "item_template")
    started_by = {int(r[ic["startquest"]]): int(r[ic["entry"]]) for r in irs if int(r[ic["startquest"]]) > 0}
    _, qrs = rows(lines, "quest_template")
    gated, prev, rewards = {}, {}, {}
    for r in qrs:
        q = int(r[qcol["entry"]])
        prev[q] = abs(int(r[qcol["PrevQuestId"]]))
        rewards[q] = [int(r[qcol[c]]) for c in ["RewChoiceItemId%d" % k for k in range(1, 7)] + ["RewItemId%d" % k for k in range(1, 5)]]
        for k in range(1, 5):
            it = int(r[qcol["ReqItemId%d" % k]])
            if it in raid_only: gated[q] = "quest needs %s (%s only)" % (rnames[it], raid_only[it])
        st = started_by.get(q)
        if st in raid_only: gated[q] = "quest starts from %s (%s only)" % (rnames[st], raid_only[st])
    changed = True
    while changed:
        changed = False
        for q, p in prev.items():
            if p in gated and q not in gated: gated[q] = gated[p]; changed = True
    out = {}
    for q, why in gated.items():
        for item in rewards.get(q, []):
            if item > 0: out.setdefault(item, why)
    return out

def main(dump, crafted_file):
    with gzip.open(dump, "rt", encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    icol = {c: k for k, c in enumerate(columns(lines, "item_template"))}
    qcol = {c: k for k, c in enumerate(columns(lines, "quest_template"))}
    names, rep_vendor, bop, rep_quest = {}, {}, set(), {}
    for line in lines:
        if line.startswith("INSERT INTO `item_template`"):
            for r in tuples(line):
                entry = int(r[icol["entry"]])
                names[entry] = r[icol["name"]]
                if int(r[icol["RequiredReputationFaction"]]) > 0:
                    rep_vendor[entry] = int(r[icol["RequiredReputationFaction"]])
                if int(r[icol["bonding"]]) == 1 or int(r[icol["RequiredSkill"]]) > 0:
                    bop.add(entry)
        elif line.startswith("INSERT INTO `quest_template`"):
            for r in tuples(line):
                faction = int(r[qcol["RequiredMinRepFaction"]])
                if faction > 0:
                    for c in ["RewChoiceItemId%d" % k for k in range(1, 7)] + ["RewItemId%d" % k for k in range(1, 5)]:
                        item = int(r[qcol[c]])
                        if item > 0: rep_quest[item] = faction
    # Vendor listings behind a reputation condition.
    ccol = {c: k for k, c in enumerate(columns(lines, "conditions"))}
    conds = {}
    for line in lines:
        if line.startswith("INSERT INTO `conditions`"):
            for r in tuples(line):
                conds[int(r[ccol["condition_entry"]])] = [int(r[ccol[c]]) for c in ("type", "value1", "value2", "value3", "value4")]
    def rep_faction(cid, depth=0):
        c = conds.get(cid)
        if not c or depth > 8: return 0
        if c[0] == 5: return c[1]
        if c[0] in (-1, -2):  # AND / OR of other conditions
            for sub in c[1:]:
                f = rep_faction(sub, depth + 1)
                if f: return f
        return 0
    rep_listing = {}
    for table in ("npc_vendor", "npc_vendor_template"):
        vcol = {c: k for k, c in enumerate(columns(lines, table))}
        for line in lines:
            if line.startswith("INSERT INTO `%s`" % table):
                for r in tuples(line):
                    f = rep_faction(int(r[vcol["condition_id"]]))
                    if f: rep_listing[int(r[vcol["item"]])] = f
    # Darkmoon Faire: NPCs by subtitle, then their quests' rewards and their wares.
    tcol = {c: k for k, c in enumerate(columns(lines, "creature_template"))}
    faire = set()
    for line in lines:
        if line.startswith("INSERT INTO `creature_template`"):
            for r in tuples(line):
                if "Darkmoon Faire" in (r[tcol["SubName"]] or ""): faire.add(int(r[tcol["Entry"]]))
    faire_quests = set()
    for table in ("creature_questrelation", "creature_involvedrelation"):
        rcol = {c: k for k, c in enumerate(columns(lines, table))}
        for line in lines:
            if line.startswith("INSERT INTO `%s`" % table):
                for r in tuples(line):
                    if int(r[rcol["id"]]) in faire: faire_quests.add(int(r[rcol["quest"]]))
    darkmoon = set()
    nv_cols = {c: k for k, c in enumerate(columns(lines, "npc_vendor"))}
    for line in lines:
        if line.startswith("INSERT INTO `quest_template`"):
            for r in tuples(line):
                if int(r[qcol["entry"]]) in faire_quests:
                    for c in ["RewChoiceItemId%d" % k for k in range(1, 7)] + ["RewItemId%d" % k for k in range(1, 5)]:
                        if int(r[qcol[c]]) > 0: darkmoon.add(int(r[qcol[c]]))
        elif line.startswith("INSERT INTO `npc_vendor`"):
            vcol = nv_cols
            for r in tuples(line):
                if int(r[vcol["entry"]]) in faire: darkmoon.add(int(r[vcol["item"]]))
    reagents = {}
    for line in open(crafted_file):
        ids = [int(x) for x in line.split()]
        if ids: reagents[ids[0]] = ids[1:]
    crafted = set(reagents)
    raid_only = raid_only_items(lines)
    raid_need = {}
    for item, regs in reagents.items():
        for r in regs:
            if r in raid_only: raid_need[item] = "crafted from %s (%s only)" % (names.get(r, r), raid_only[r])
    rnames = {r: names.get(r, str(r)) for r in raid_only}
    for item, why in raid_gated_rewards(lines, qcol, raid_only, rnames).items():
        raid_need.setdefault(item, why)
    reputation = dict(rep_quest); reputation.update(rep_listing); reputation.update(rep_vendor)
    profession = sorted(crafted & bop)
    out = ["-- Generated by tools/build_lists.py from cMaNGOS classic-db %s (GPL-3.0). Do not hand-edit." % COMMIT,
           "-- reputation: [item] = faction ID; darkmoon: Darkmoon Faire rewards and wares; profession: crafted items that bind on pickup or need a skill to use.",
           "local _, ns = ...", "ns.Lists = {", '  source = "cMaNGOS classic-db %s",' % COMMIT, "  reputation = {"]
    for item in sorted(reputation):
        out.append("    [%d] = %d, -- %s" % (item, reputation[item], names.get(item, "?").replace("\n", " ")))
    for item, faction in reputation.items():
        if faction in RAID_FACTIONS: raid_need.setdefault(item, RAID_FACTIONS[faction])
    out += ["  },", "  raidOnly = {"]
    for item in sorted(raid_need):
        out.append('    [%d] = "%s", -- %s' % (item, raid_need[item].replace('"', "'"), names.get(item, "?")))
    out += ["  },", "  darkmoon = {"]
    for item in sorted(darkmoon):
        out.append("    [%d] = true, -- %s" % (item, names.get(item, "?")))
    out += ["  },", "  profession = {"]
    for item in profession:
        out.append("    [%d] = true, -- %s" % (item, names.get(item, "?")))
    out += ["  },", "}", ""]
    open("Prepped/data/Lists.lua", "w").write("\n".join(out))
    print("raid-only items %d, items needing them %d" % (len(raid_only), len(raid_need)))
    print("darkmoon NPCs %d, quests %d, items %d" % (len(faire), len(faire_quests), len(darkmoon)))
    print("item rows %d, reputation %d (item %d, vendor listing %d, quest %d), crafted %d, profession %d"
          % (len(names), len(reputation), len(rep_vendor), len(rep_listing), len(rep_quest), len(crafted), len(profession)))

main(sys.argv[1], sys.argv[2])
