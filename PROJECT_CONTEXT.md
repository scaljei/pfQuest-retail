# pfQuest-retail — Project Context

## What this is
A port of the Classic WoW quest-helper addon **pfQuest** (by shagu) to retail WoW **The War Within 11.1.5** (interface 110105). The port makes the addon functional on a retail client while preserving the original architecture where possible.

## Repos
- **Main addon:** https://github.com/scaljei/pfQuest-retail.git (branch: `retail-11.1.5`)
- **DB addon:** https://github.com/scaljeri/pfQuest-retail-db (companion, expansion data)
- **GitHub username:** scaljei (one 'r') — note: DB addon repo uses `scaljeri` (with r)
- **GitHub token:** ghp_REDACTED_see_vault (expires 2026-06-29, refresh on/after 2026-06-22)

## WoW environment
- Lua 5.1 — no `goto`, no bitwise operators, no integer division `//`
- Interface 110105 = The War Within 11.1.5
- `luac5.1 -p file.lua` before every commit — mandatory

## File structure
```
pfQuest-retail/
├── tracker.lua          Floating quest tracker panel UI
├── quest.lua            Core event loop, UpdateQuestlog, queue processor
├── database.lua         SearchQuestID, SearchMobID, SearchQuests, QuestFilter, pfDatabase.Reload()
├── map.lua              Node rendering: UpdateNodes, UpdateMinimap, BuildNode, GetCurrentMapID
├── browser.lua          DB search UI, pfBrowser.ReloadDB()
├── journal.lua          Completed quest journal
├── slashcmd.lua         /db commands including /db dbinfo diagnostic
├── config.lua           Settings panel, classic_db toggle
├── diagnostic.lua       pfDiag.log/err/showWindow — copyable window infrastructure
├── compat/
│   ├── client.lua       WoW API shims, pfQuestCompat.*
│   └── pfUI.lua         pfUI compatibility layer
├── db/
│   ├── init.lua         pfDB table structure declaration
│   ├── quests.lua       Classic quest data (IDs 1-9665)
│   ├── units.lua        Classic NPC data (IDs 1-21010, 81544 entries, 10382 named in enUS)
│   ├── zones.lua        Classic zone data
│   ├── minimap.lua      Classic zone minimap dimensions (50 entries, must NOT be wiped)
│   └── retail/
│       ├── db_guard.lua         PLAYER_LOGIN: wipe classic DB, Reload(), deferred rescan
│       ├── runtime_db.lua       Dynamic zone/NPC/quest registration; wantedNames; npcCache
│       ├── att_integration.lua  ATT SavedVars + C_QuestLog.GetAllCompletedQuestIDs
│       ├── zone_bridge.lua      uiMapID→pfID mappings, InstallRetailZoneBridge
│       ├── mobinfo2_import.lua  MI2_DB coord import (coords only, no names)
│       └── harvester.lua        Passive NPC harvest (8 vectors) + Wowhead Looter import
└── init/
    ├── addon.xml        Load order (CRITICAL)
    └── data.xml         Classic DB file includes
```

## Load order (init/addon.xml) — CRITICAL
```
zone_bridge.lua → db_guard.lua → runtime_db.lua → att_integration.lua → mobinfo2_import.lua → harvester.lua
```
db_guard MUST fire before runtime_db. Reversing causes data to be wiped after population.

## DB architecture (retail mode)

### PLAYER_LOGIN sequence
1. **db_guard.lua**: saves active classic quest entries → wipes classic DB (quests/units/objects/items/refloot) → does NOT wipe `pfDB["minimap"]` (static dims) → `pfDatabase.Reload()` + `pfBrowser.ReloadDB()` → deferred `resetPopulated()` + `scanQuestLog()` + `linkCachedNPCs()`
2. **runtime_db.lua**: `registerZone()`, `scanQuestLog()`, `linkCachedNPCs()`, pre-seeds `units.data` from `pfQuest_npcCache`
3. **att_integration.lua**: ATT SavedVars at 1s, `GetAllCompletedQuestIDs` at 6s
4. **mobinfo2_import.lua**: MI2_DB coords at 1s (coords only; name bridge via `classicNPCNames` snapshot)
5. **harvester.lua**: Wowhead Looter `wlUnit` import at 2s

### Runtime NPC harvest vectors (harvester.lua + runtime_db.lua)
| Event | Unit token | Notes |
|-------|-----------|-------|
| `NAME_PLATE_UNIT_ADDED` + OnUpdate poll | nameplateN | C_NamePlate.GetNamePlates() every 1s |
| `PLAYER_TARGET_CHANGED` | target | |
| `UPDATE_MOUSEOVER_UNIT` | mouseover | was broken — was using wrong unit token |
| `GOSSIP_SHOW` | npc | |
| `COMBAT_LOG/UNIT_DIED` | destGUID | player position approximation |
| `LOOT_OPENED` | GetLootSourceInfo | |
| `MERCHANT_SHOW/TRAINER_SHOW` | npc | |
| `AUCTION_HOUSE_SHOW` | auctioneer | |
| `BANKFRAME_OPENED` | banker | |
| `TAXIMAP_OPENED` | taxi | |
| `PET_STABLE_SHOW` | stable | |
| `BATTLEFIELDS_SHOW` | battlemaster | |
| `CONFIRM_BINDER` | binder | |
| `CHAT_MSG_MONSTER_SAY/YELL/EMOTE/WHISPER` | GUID in arg12 | |
| `QUEST_DETAIL/PROGRESS/COMPLETE/GREETING` | questnpc | |
| `wlUnit` SavedVariable | — | Wowhead Looter, optional, 2s deferred |

`registerNPC(npcID, name, uiMapID, x, y, level)` — all paths funnel here.

### wantedNames index
Built by `scanQuestLog` from `C_QuestLog.GetQuestObjectives(questID)`.
- Retail text format: `"0/N Mob Name verb"` — strip count prefix, then trailing verbs:
  `slain, killed, defeated, destroyed, checked, collected, gathered, looted, freed, rescued, spoken to, escorted, found`
- Also strips trailing plural `s` and indexes both forms
- `linkCachedNPCs()` back-links already-cached NPCs against fresh `wantedNames` after each `scanQuestLog`

### npcCache (pfQuest_npcCache SavedVariable)
Persists all harvested NPC coords across sessions. Pre-seeds `units.data` at login.

### classicNPCNames snapshot
Built by db_guard before wipe: `{ [lowercase_name] = npcID }` — 10382 entries (enUS locale).
Used by mobinfo2_import to bridge MI2 npcID→name for classic-era NPCs.

## Node display chain
```
UpdateQuestlog → queue → SearchQuestID(questID, meta{qlogid=N})
  → quests[id]["obj"]["U"] → SearchMobID(npcID) → AddNode()
  → pfMap.nodes[addon][pfZoneID][coords][title]
  → UpdateNodes() / UpdateMinimap() → Button frames on canvas
```

## Map rendering

### World map
- Canvas: `WorldMapFrame.ScrollContainer.Child` (1002×668px)
- Pin parent: Child frame; anchored `CENTER, Child, TOPLEFT, x, -y`
- Position: `x = x%/100 * Child:GetWidth()`, `y = y%/100 * Child:GetHeight()`
- Child scrolls inside ScrollContainer — pins move with content correctly
- Pin frame level: 112 + layer

### Minimap
- Parent: `Minimap` frame (= `pfMap.drawlayer`)
- **Strata: `MEDIUM`** (inherited BACKGROUND was buried under TWW minimap overlays)
- **Frame level: 200 + layer** (was 4+layer, buried under minimap art)
- **Color: normalized to max channel** (`r/max, g/max, b/max`) — prevents dark/grey pins from str2rgb hash
- Dimensions from `pfDB["minimap"][pfZoneID]` — classic zones have real dims; retail zones use placeholder until `registerZone` calls `C_Map.GetMapRects()`

## Key retail API differences
| Classic | Retail TWW |
|---------|-----------|
| `this` in callbacks | explicit `self` |
| `SetTexture(r,g,b,a)` | `SetColorTexture(r,g,b,a)` |
| `GetCurrentMapID()` | `C_Map.GetBestMapForUnit("player")` |
| `GetMouseFocus()` | `GetMouseFoci()[1]` (removed in TWW) |
| `GetQuestsCompleted()` | `C_QuestLog.GetAllCompletedQuestIDs()` |
| `C_QuestLog.GetInfo(questID)` | takes log INDEX not questID |
| `QuestWatchFrame` | removed; `ObjectiveTrackerFrame` is protected |
| Quest IDs fit INT32 | some TWW IDs exceed 2,147,483,647 |
| `GetQuestObjectives` text: `"Name: 0/N"` | `"0/N Name verb"` |

## Lua 5.1 gotchas
- `guid and string.match(guid, pat)` in multi-assign: **truncates to 1 return value**. Assign captures directly: `local a,b,c,d,e,f,g = string.match(guid, pat)`
- No `goto`/`continue` — use `if/else` or wrapper functions
- No bitwise operators — use `bit.band()` etc.

## Diagnostic commands
| Command | Purpose |
|---------|---------|
| `/db dbinfo` | Full DB state snapshot (copyable window) |
| `/db guidcheck` | Target NPC: GUID parse, registration, wantedNames, quest link, nodes |
| `/db searchtest [questID]` | Directly invoke SearchQuestID with/without qlogid, show nodes produced |
| `/db wantednames` | Dump all wantedNames entries |
| `/db objdump` | Raw GetQuestObjectives for all active quests |
| `/db nptrace` | Toggle nameplate event fire confirmation |
| `/db pindump` | World map pin state (canvas size, pin positions, strata) |
| `/db harvester` | Re-import Wowhead Looter wlUnit |
| `/db mobinfo2` | Re-import MI2_DB |
| `/db npccache` | Manage NPC position cache |
| `/db att` | Force ATT sync |
| `/db classicdb` | Classic DB load status |

## GitHub issues status
| # | Title | Status |
|---|-------|--------|
| 1 | DB interface no results | **FIXED** |
| 2 | No quest givers on map | **PARTIAL** — QUEST_DETAIL/COMPLETE harvester covers new; no API for pre-existing |
| 3 | Minimap button not clickable | **OPEN** — undiagnosed |
| 4 | Quest nodes don't appear | **CLOSED** — working for type=monster; type=item/object are known limitations |
| 5 | DB not updating | **FIXED** |
| 7 | Nodes only after targeting NPC | **CLOSED** — merged into #4 |
| 9 | QuestFilter crash string vs number | **FIXED+CLOSED** |
| 10 | browser.lua GetMouseFocus nil | **FIXED+CLOSED** |

## Known remaining limitations (untracked)
- **type=item objectives**: quest tracks item count not mob kills; need retail loot source DB (mob→item mapping) to show pins
- **type=object objectives**: need GameObject GUID harvesting (`pfDB["objects"]` population)
- **Retail zone minimap dims**: placeholder `4266.7×2844.4` until zone is visited with quests active and `C_Map.GetMapRects()` returns real dims
- **Quest givers for pre-existing quests**: no retail API returns giver NPC ID for a questID without re-accepting

## Commit workflow
```bash
cd /home/claude/pfQuest-retail-full
git config user.email "claude@anthropic.com" && git config user.name "Claude"
# edit files
luac5.1 -p changed_file.lua && echo "OK"
git add file.lua
git commit -m "fix: description"
git push https://ghp_REDACTED_see_vault@github.com/scaljei/pfQuest-retail.git retail-11.1.5
```
