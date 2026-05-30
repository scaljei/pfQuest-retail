# pfQuest — Retail 11.1.5 Port

Full port of [pfQuest by Shagu](https://github.com/shagu/pfQuest) to **WoW retail 11.1.5** (Interface `110105`).

This branch (`retail-11.1.5`) is a complete, working retail port branched directly from the upstream `master`. Every Lua file has been updated.

---

## What was changed

### Lua language / runtime
| Old (TBC/WotLK Lua 5.0) | New (retail Lua 5.4) |
|---|---|
| `table.getn(t)` | `#t` |
| `getglobal("X")` | `_G["X"]` |
| `getfenv(0)` | `_G` (always the global table in 5.1+) |
| `math.mod(a,b)` | `a % b` |
| `strfind`, `strlower`, `strsub`, `strrev` | `string.find`, `string.lower`, `string.sub`, `string.reverse` |
| `string.gfind` | `string.gmatch` |
| `gsub(…)` bare global | `string.gsub(…)` |
| Implicit `this` in all `SetScript` callbacks | Explicit `self` (and `local btn = self or this` guards in `map.lua`) |
| `arg1` in `OnMouseWheel` callbacks | `delta` (passed as 2nd argument) |

### Map & minimap (`map.lua`)
| Old | New |
|---|---|
| `GetCurrentMapContinent()` + `GetCurrentMapZone()` | `C_Map.GetBestMapForUnit("player")` + `C_Map.GetMapInfo()` |
| `GetMapContinents()` / `GetMapZones(cid)` / `SetMapZoom()` | `C_Map.GetMapChildrenInfo()` + `OpenWorldMap()` |
| `SetMapToCurrentZone()` | No-op guard (C_Map tracks this automatically) |
| `GetPlayerMapPosition("player")` | `C_Map.GetPlayerMapPosition(uiMapID, "player")` → `Vector2DMixin:GetXY()` |
| `GetRealZoneText()` | `C_Map.GetMapInfo(C_Map.GetBestMapForUnit("player")).name` |
| `WorldMapButton` | `WorldMapFrame.ScrollContainer.Child` fallback chain |
| `WorldMapTooltip` | `GameTooltip` fallback |
| `ToggleWorldMap()` | `OpenWorldMap()` |
| `WorldMapQuestFrame_OnMouseUp` hook | `QUEST_LOG_SELECTION_CHANGED` event |
| `WorldMapBlobFrame` / `WorldMapFrame_ClearQuestPOIs` | Guard-checked, no-op on retail |
| `WorldMapPOIFrame.allowBlobTooltip` | Nil-checked before assignment |
| Minimap rotation marked `-- TODO` | Implemented with `math.sin/cos` |

### Quest log (`compat/client.lua`, `map.lua`, `quest.lua`, `database.lua`, `tracker.lua`)
| Old | New |
|---|---|
| `GetNumQuestLogEntries()` | `C_QuestLog.GetNumQuestLogEntries()` |
| `GetQuestLogTitle(id)` | `C_QuestLog.GetInfo(id)` + `C_QuestLog.IsComplete()` |
| `GetNumQuestLeaderBoards(id)` | `#C_QuestLog.GetQuestObjectives(questID)` |
| `GetQuestLogLeaderBoard(i, id)` | `C_QuestLog.GetQuestObjectives(questID)[i]` |
| `GetQuestLogSelection()` | `C_QuestLog.GetSelectedQuest()` |
| `GetDifficultyColor` / `GetQuestDifficultyColor` | Layered fallback |

### Addon API
| Old | New |
|---|---|
| `GetNumAddOns()` / `GetAddOnInfo(i)` | `C_AddOns.GetNumAddOns()` / `C_AddOns.GetAddOnInfo(i)` |
| `ChatFrameEditBox:Insert()` | `ChatEdit_GetActiveWindow():Insert()` |
| `QuestWatchFrame` | `ObjectiveTrackerFrame` fallback |

### Route system (`route.lua`)
- `GetPlayerMapPosition` replaced with `C_Map.GetPlayerMapPosition`
- `WorldMapButton` frame references replaced with dynamic canvas detection
- `WorldMapButton.routes` texture container migrated to the resolved canvas

---

## Installation

1. Place this entire folder as `pfQuest` inside:
   ```
   World of Warcraft/_retail_/Interface/AddOns/pfQuest/
   ```
2. Use **`pfQuest-retail.toc`** — rename it to `pfQuest.toc` if the game doesn't pick it up automatically, or load it via the interface version field.
3. Enable in the character select addon list.

> **Note:** The `db/` folder (quest/NPC/object database) ships with classic/TBC/WotLK zone data only. Retail zones will not have minimap pins until a matching database is built.

---

## Known limitations

- **Zone database:** `minimap_sizes` and zone coordinate data are for classic continents. Retail zones (Dragonflight / The War Within) need new entries.
- **World map canvas:** The retail world map scroll canvas differs per patch. The dynamic fallback chain (`WorldMapFrame.ScrollContainer.Child`) covers 11.x but may need a tweak on future patches.
- **pfUI dependency:** All `pfUI.api.*` calls have inline fallbacks so the addon loads without pfUI installed.

---

## Credits
Original addon: **Shagu** — https://github.com/shagu/pfQuest  
Retail port: API compatibility layer for WoW 11.1.5
