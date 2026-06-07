-- pfQuest-retail: Classic DB guard
-- ============================================================
-- The static DB (quests.lua, units.lua, objects.lua, items.lua,
-- refloot.lua, minimap.lua, areatrigger.lua, meta.lua) contains
-- Classic/TBC data (quest IDs 1-9665, NPC IDs 1-21010) that is
-- irrelevant for retail characters playing The War Within.
--
-- WoW's TOC/XML system has no conditionals, so both versions load
-- the same files. This script runs AFTER the static DB is loaded
-- and wipes the Classic tables when running on a retail client,
-- freeing ~12MB of memory and preventing the misleading "0 completed
-- out of 4433" quest scan result.
--
-- Retail is detected by interface version >= 100000 (Shadowlands+).
-- The config option pfQuest_config["classic_db"] = "1" overrides
-- this and keeps Classic data even on retail (for players who run
-- old content or have a mixed account).
-- ============================================================

local function isRetailClient()
  local _, _, _, iface = GetBuildInfo()
  return iface and iface >= 100000
end

local function wipeClassicDB()
  -- Preserve classic DB entries for quests currently in the player's log.
  -- If the player is on a classic quest (ID < 10000), its NPC start/end/obj
  -- links from the static DB are the only source of that data.
  local preserveQuests  = {}
  local preserveUnits   = {}
  local preserveObjects = {}

  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
    local n = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, n do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID and info.questID < 10000 then
        local qid = info.questID
        -- Preserve quest data and loc
        if pfDB["quests"]["data"][qid] then
          preserveQuests[qid] = { data = pfDB["quests"]["data"][qid],
                                  loc  = pfDB["quests"]["loc"][qid] }
          -- Preserve all referenced unit IDs
          local qd = pfDB["quests"]["data"][qid]
          for _, section in ipairs({ "start", "end", "obj" }) do
            if qd[section] and qd[section]["U"] then
              for _, uid in ipairs(qd[section]["U"]) do
                if pfDB["units"]["data"][uid] then
                  preserveUnits[uid] = { data = pfDB["units"]["data"][uid],
                                         loc  = pfDB["units"]["loc"][uid] }
                end
              end
            end
            if qd[section] and qd[section]["O"] then
              for _, oid in ipairs(qd[section]["O"]) do
                if pfDB["objects"]["data"][oid] then
                  preserveObjects[oid] = { data = pfDB["objects"]["data"][oid],
                                           loc  = pfDB["objects"]["loc"][oid] }
                end
              end
            end
          end
        end
      end
    end
  end

  local preserved = 0
  for _ in pairs(preserveQuests) do preserved = preserved + 1 end

  -- Clear the large static tables
  pfDB["items"]          = { ["data"] = {}, ["loc"] = {} }
  pfDB["units"]          = { ["data"] = {}, ["loc"] = {} }
  pfDB["objects"]        = { ["data"] = {}, ["loc"] = {} }
  pfDB["refloot"]        = { ["data"] = {}, ["loc"] = {} }
  pfDB["quests"]         = { ["data"] = {}, ["loc"] = {} }
  pfDB["quests-itemreq"] = { ["data"] = {}, ["loc"] = {} }
  pfDB["minimap"]        = {}
  pfDB["areatrigger"]    = {}
  -- meta kept: needed for SearchObjectSkill

  -- Restore preserved active-quest entries
  for qid, entry in pairs(preserveQuests) do
    pfDB["quests"]["data"][qid] = entry.data
    if entry.loc then pfDB["quests"]["loc"][qid] = entry.loc end
  end
  for uid, entry in pairs(preserveUnits) do
    pfDB["units"]["data"][uid] = entry.data
    if entry.loc then pfDB["units"]["loc"][uid] = entry.loc end
  end
  for oid, entry in pairs(preserveObjects) do
    pfDB["objects"]["data"][oid] = entry.data
    if entry.loc then pfDB["objects"]["loc"][oid] = entry.loc end
  end

  collectgarbage("collect")
  DEFAULT_CHAT_FRAME:AddMessage(
    "|cff33ffccpf|cffffffffQuest: Classic DB unloaded (" .. preserved ..
    " active quest(s) preserved). Retail quest data from live client.")
end

-- Pre-populate zone names from the zone bridge so UpdateNodes never shows '?'
local function preCacheZoneNames()
  if not (C_Map and C_Map.GetMapInfo) then return end
  if not pfDB["zones"] then pfDB["zones"] = {} end
  if not pfDB["zones"]["loc"] then pfDB["zones"]["loc"] = {} end
  -- Iterate the installed zone bridge (installed by zone_bridge.lua)
  local bridge = pfQuest and pfQuest.retailZoneMap
  if not bridge or type(bridge) ~= "table" or bridge == 0 then return end
  for uiMapID, pfID in pairs(bridge) do
    if not pfDB["zones"]["loc"][pfID] then
      local info = C_Map.GetMapInfo(uiMapID)
      if info and info.name then
        pfDB["zones"]["loc"][pfID] = info.name
      end
    end
  end
end

-- Run after all DB files have loaded but before addon logic starts.
-- PLAYER_LOGIN fires after SavedVariables are available.
local guard = CreateFrame("Frame")
guard:RegisterEvent("PLAYER_LOGIN")
guard:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()

  -- Honour explicit override: keep Classic DB if user opted in
  if pfQuest_config and pfQuest_config["classic_db"] == "1" then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff33ffccpf|cffffffffQuest: Classic DB kept (classic_db config override).")
    pfQuestRetail_ClassicDBLoaded = true
    return
  end

  -- Initialize retailZoneMap/Reverse before anything uses them
  pfQuest = pfQuest or {}
  if type(pfQuest.retailZoneMap) ~= "table" then
    pfQuest.retailZoneMap = {}
  end
  if type(pfQuest.retailZoneMapReverse) ~= "table" then
    pfQuest.retailZoneMapReverse = {}
  end

  if isRetailClient() then
    pfQuestRetail_ClassicDBLoaded = false
    wipeClassicDB()
    -- Re-point database.lua local upvalues to the new empty tables
    -- so searches iterate the live tables, not the old pre-wipe ones
    if pfDatabase and pfDatabase.Reload then
      pfDatabase.Reload()
    end
    -- Also refresh browser.lua upvalues if available
    if pfBrowser and pfBrowser.ReloadDB then
      pfBrowser.ReloadDB()
    end
    -- Safety net: re-scan quest log after all PLAYER_LOGIN handlers have run.
    -- runtime_db registers its PLAYER_LOGIN before db_guard (earlier in addon.xml),
    -- but with the corrected load order db_guard fires first. This deferred rescan
    -- ensures quest data is populated even if load order changes again.
    C_Timer.After(0, function()
      if pfRetailRuntime and pfRetailRuntime.scanQuestLog then
        pfRetailRuntime.scanQuestLog()
      end
      if pfMap then pfMap.queue_update = GetTime() end
    end)
  else
    pfQuestRetail_ClassicDBLoaded = true
  end

  -- Pre-cache zone names regardless of client type
  C_Timer.After(1, preCacheZoneNames)
end)
