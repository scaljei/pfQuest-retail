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
  -- Clear the large static tables entirely
  -- zones and init structure are kept — needed for zone name resolution
  pfDB["items"]          = { ["data"] = {}, ["loc"] = {} }
  pfDB["units"]          = { ["data"] = {}, ["loc"] = {} }
  pfDB["objects"]        = { ["data"] = {}, ["loc"] = {} }
  pfDB["refloot"]        = { ["data"] = {}, ["loc"] = {} }
  pfDB["quests"]         = { ["data"] = {}, ["loc"] = {} }
  pfDB["quests-itemreq"] = { ["data"] = {}, ["loc"] = {} }
  pfDB["minimap"]        = {}
  pfDB["areatrigger"]    = {}
  -- meta kept: small (24KB) and needed for SearchObjectSkill structure checks
  collectgarbage("collect")
  DEFAULT_CHAT_FRAME:AddMessage(
    "|cff33ffccpf|cffffffffQuest: Classic DB unloaded (retail client). " ..
    "Quest data will be populated from live client + ATT integration.")
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

  if isRetailClient() then
    pfQuestRetail_ClassicDBLoaded = false
    wipeClassicDB()
  else
    pfQuestRetail_ClassicDBLoaded = true
  end
end)
