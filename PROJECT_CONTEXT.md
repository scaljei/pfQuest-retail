# pfQuest-retail — Project Context

## What this is
A port of the Classic WoW quest-helper addon **pfQuest** (by shagu) to retail WoW **The War Within 11.1.5** (interface 110105). The port makes the addon functional on a retail client while preserving the original architecture where possible.

## Repos
- **Main addon:** https://github.com/scaljei/pfQuest-retail.git (branch: `retail-11.1.5`)
- **DB addon:** https://github.com/scaljeri/pfQuest-retail-db (companion, expansion data)
- **PBSBuilder:** https://github.com/scaljei/PBSBuilder.git (branch: `main`) — visual script editor for PBS addon
- **GitHub username:** scaljei (one 'r')
- **GitHub token:** ghp_REDACTED_see_vault (expires 2026-06-29)

## WoW environment
- Lua 5.1 (WoW retail uses Lua 5.1 — no `goto`, no bitwise operators, no integer division)
- Interface 110105 = The War Within (pfQuest-retail) / 110200 = TWW 11.2.0 (PBSBuilder)
- Retail enforces strict API contracts: `SetAlpha` range [0,1], protected frame restrictions, `INT32_MAX` limit on quest IDs passed to `C_QuestLog` APIs

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
│   ├── client.lua       WoW API shims, pfQuestCompat.QuestWatchFrame
│   └── pfUI.lua         pfUI compatibility layer
├── db/
│   ├── init.lua         pfDB table structure declaration
│   ├── quests.lua       Classic quest data (IDs 1-9665)
│   ├── units.lua        Classic NPC data (IDs 1-21010)
│   ├── zones.lua        Classic zone data (always loaded, never wiped)
│   └── retail/
│       ├── db_guard.lua         PLAYER_LOGIN: wipe classic DB, Reload(), deferred rescan
│       ├── runtime_db.lua       Dynamic registration of zones/NPCs/quests from live client
│       ├── att_integration.lua  ATT SavedVars + C_QuestLog.GetAllCompletedQuestIDs
│       └── zone_bridge.lua      uiMapID→pfID mappings, InstallRetailZoneBridge
└── init/
    ├── addon.xml        Load order (CRITICAL — db_guard BEFORE runtime_db)
    └── data.xml         Classic DB file includes
```

## Load order (init/addon.xml) — critical
```
zone_bridge.lua → db_guard.lua → runtime_db.lua → att_integration.lua
```
db_guard MUST load before runtime_db so its PLAYER_LOGIN fires first (wipe + Reload), then runtime_db fires second (populates fresh tables). Reversing this causes data to be wiped after population.

## The DB architecture (retail mode)

### At file load time
- Classic DB files load (quests.lua 4433 entries, units.lua 81544 entries, etc.)
- `database.lua` calls `pfDatabase.Reload()` capturing upvalues pointing to classic tables
- `browser.lua` captures same tables as module-level locals

### At PLAYER_LOGIN (in order)
1. **db_guard.lua** fires first:
   - Reads C_QuestLog to find classic quest IDs (< 10000) currently in player's log
   - Saves their DB entries (preserving NPC start/end/obj links for active classic quests)
   - Wipes all classic tables: `pfDB["quests"] = {data={}, loc={}}` etc.
   - Restores the saved active-quest entries
   - Calls `pfDatabase.Reload()` → upvalues now point to new empty tables
   - Calls `pfBrowser.ReloadDB()` → browser upvalues refreshed
   - `C_Timer.After(0)`: calls `resetPopulated()` then `scanQuestLog()` (deferred rescan)
   - `C_Timer.After(1)`: pre-caches zone names from zone bridge
   - Initializes `pfQuest.retailZoneMap = {}` and `pfQuest.retailZoneMapReverse = {}`

2. **runtime_db.lua** fires second:
   - `registerZone(uiMapID)`: maps retail uiMapID to pfID, reusing classic pfID if zone name matches
   - `scanQuestLog()`: calls `registerQuestFromInfo(info)` for each log entry

3. **att_integration.lua** fires third:
   - Reads ATT SavedVars (ATTCharacterData, AllTheThingsAD)
   - `C_Timer.After(6)`: calls `C_QuestLog.GetAllCompletedQuestIDs()` for pfQuest_history

### Runtime (ongoing)
- `PLAYER_TARGET_CHANGED` / `UPDATE_MOUSEOVER_UNIT` → `registerNPC(id, name, uiMapID, x, y)` → `units.data` grows
- `QUEST_ACCEPTED` → `onQuestAccepted(questID)` → links the accepting NPC as quest starter
- `QUEST_LOG_UPDATE` → `scanQuestLog()` → registers any new quests
- `ZONE_CHANGED*` → `registerZone(uiMapID)` → zone bridge grows

## How nodes appear on the map

The node display chain for an **active quest** (in player's log):
1. `UpdateQuestlog` → detects quest in log → adds to queue
2. Queue processor → `SearchQuestID(questID, meta{qlogid=N})`
3. `SearchQuestID` reads `pfDB["quests"]["data"][questID]`:
   - If `["start"]["U"]` has NPC IDs → `SearchMobID()` → `AddNode()` ✓
   - If `["obj"]["U"]` has NPC IDs → `SearchMobID()` → `AddNode()` ✓
   - **OR** with `qlogid`: `GetQuestObjectives()` → mob name → `GetIDByName()` → `SearchMobID()` ✓
4. `SearchMobID` reads `pfDB["units"]["data"][npcID]["coords"]` for positions
5. `AddNode()` → `pfMap.nodes[addon][zoneID][coords][title]` populated
6. `UpdateNodes()` → creates Button frames on world map canvas → pins visible

**Critical dependency:** `units.data` must be non-empty for nodes to appear. It grows through NPC interaction (targeting, mousing over). The `GetIDByName` path makes this automatic — as soon as a player targets a mob whose name matches a quest objective, the node appears on the next `UpdateNodes` cycle.

## Key retail API differences from Classic
| Classic | Retail 11.1.5 |
|---------|---------------|
| `this` implicit global in callbacks | Explicit `self` parameter required |
| `SetTexture(r,g,b,a)` | `SetColorTexture(r,g,b,a)` |
| `SetAlpha` accepts any number | Strict [0.0, 1.0] range |
| `GetCurrentMapID()` / continent APIs | `C_Map.GetBestMapForUnit("player")` |
| `GetQuestsCompleted()` returns table | `C_QuestLog.GetAllCompletedQuestIDs()` returns array |
| `GetQuestsCompleted(outTable)` | Same but pass table as arg |
| `C_QuestLog.GetInfo(index)` | Takes log INDEX not questID |
| `QuestWatchFrame` exists | Removed; `ObjectiveTrackerFrame` is protected |
| Quest IDs fit INT32 | Some TWW quest IDs exceed 2,147,483,647 |

## ⚠️ Mouse-input frame trap — known footgun
**Never use `SetAllPoints(UIParent)` on a frame that has `EnableMouse(true)` or any mouse script.**
A full-screen mouse-enabled frame blocks right-click camera drag for the entire game session.
Always scope mouse-catching frames to a specific parent window, or use `WorldFrame` as parent
with `EnableMouse(false)` (no scripts). This was the root cause of PBSBuilder issue #1.

## Diagnostic tools

### pfQuest-retail: /pfdiag
Slash command opens a copyable scrollable window. Sub-commands:
- `/pfdiag`        — recent log + error summary
- `/pfdiag log`    — full timestamped session log
- `/pfdiag errors` — errors only
- `/pfdiag clear`  — clear log
- `/pfdiag menu`   — menu/frame state snapshot
Public API: `pfDiag.log(msg)` / `pfDiag.err(msg)` — call from any file.
`diagnostic.lua` is the **first file loaded** (top of `addon.xml`) so it is always available.

### pfQuest-retail: /db dbinfo
Run in-game to open a copyable snapshot window. Key sections:
- **pfDB table sizes**: `quests.data=47` means 47 active quests registered
- **Upvalue identity**: `FRESH` = good, `STALE` = db_guard wiped after upvalues captured (call `pfDatabase.Reload()`)
- **pfMap.nodes**: total node count; if 0, see explanation line
- **Quest sample**: first 5 quest entries with NPC link status
- **retailZoneMap**: zone bridge entry count; `0` means pfQuest-retail-db missing
- **Canvas size**: `0x0 expected — map is closed` is normal; real dimensions show when map open

### pfQuest-retail: /db att / /db classicdb
- `/db att` — forces ATT quest completion sync and reports sources used
- `/db classicdb` — reports whether classic DB was loaded or wiped

### PBSBuilder: /pbsbd
Slash command opens a copyable scrollable window. Sub-commands:
- `/pbsbd`         — recent log + error summary
- `/pbsbd log`     — full timestamped session log
- `/pbsbd errors`  — errors only
- `/pbsbd clear`   — clear log
Public API: `PBSBuilderDebug.log(msg)` / `PBSBuilderDebug.err(msg)`.
`DebugLog.lua` is the **first file loaded** in PBSBuilder.toc so it is always available.

### Debug window pattern (shared)
Both addons use the same pattern:
- `CreateFrame("EditBox")` with `SetMultiLine(true)`, `SetAutoFocus(false)`, inside a `ScrollFrame`
- `EnableMouseWheel(true)` + explicit `OnMouseWheel` handler on the scroll frame
- Ctrl+A / Ctrl+C to select and copy all log text
- Global error handler hooked via `seterrorhandler` to capture all Lua errors automatically

## Open GitHub issues (pfQuest-retail)
- **#1** DB interface search returns no results — **FIXED** (upvalue reload after db_guard wipe)
- **#2** Quest tracker no quest givers on map — **PARTIAL** (pipeline correct, needs NPC interaction to populate units.data)
- **#3** Minimap button not clickable — **OPEN** (not yet investigated)
- **#4** Quest nodes don't appear on map — **PARTIAL** (pipeline sound, depends on units.data; minimap placeholder dimensions still wrong for retail zones)
- **#5** DB not updating — **FIXED** (load order, resetPopulated, registerZone pfID collision, GetInfo index fix)

## Open GitHub issues (PBSBuilder)
- **#1** globalCatcher frame blocks camera right-click drag — **FIXED** (removed SetAllPoints/UIParent frame; use WorldFrame with EnableMouse(false) instead)

## Known remaining issues (not yet filed)
- **Minimap zone dimensions**: placeholder `4266.7×2844.4` used for all retail zones (pfID ≥ 10000). `runtime_db.registerZone()` calls `C_Map.GetMapRects()` and stores result in `pfDB["minimap"]` — but only for zones visited with active quests. Pins will be mispositioned until correct dimensions are stored.
- **Quest giver NPCs for pre-existing quests**: quests accepted before this session have no start NPC data unless the player re-accepts or the classic DB had the entry. No retail API returns the giver NPC ID for a questID.
- **Browser search**: upvalues refreshed but actual search results depend on `units.data` being populated.
