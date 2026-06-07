-- pfQuest-retail: runtime database population
-- Automatically populates pfDB with data gathered from the live game client:
--   - Active quest objectives (mob kill targets, item collection targets)
--   - Quest giver/ender NPCs from C_QuestLog
--   - Zone data from C_Map for the player's current content
--   - Unit positions from nearby NPC interactions
--
-- This means the addon works for your CURRENT quests without needing
-- pfQuest-retail-db installed. Data builds up as you play.

pfRetailRuntime = pfRetailRuntime or {}
pfRetailRuntime.populated = {}   -- track which questIDs we've already processed

-- ── Ensure pfDB tables exist ────────────────────────────────────────────────
local function ensureDB()
  pfDB["units"]   = pfDB["units"]   or { ["data"]={}, ["loc"]={} }
  pfDB["objects"] = pfDB["objects"] or { ["data"]={}, ["loc"]={} }
  pfDB["quests"]  = pfDB["quests"]  or { ["data"]={}, ["loc"]={} }
  pfDB["zones"]   = pfDB["zones"]   or { ["data"]={}, ["loc"]={} }
  pfDB["minimap"] = pfDB["minimap"] or {}
end

-- ── Zone registration ────────────────────────────────────────────────────────
local function registerZone(uiMapID)
  if not uiMapID then return nil end
  -- Ensure map tables exist (may not be initialized yet)
  pfQuest.retailZoneMap = type(pfQuest.retailZoneMap) == "table" and pfQuest.retailZoneMap or {}
  pfQuest.retailZoneMapReverse = type(pfQuest.retailZoneMapReverse) == "table" and pfQuest.retailZoneMapReverse or {}
  -- Already mapped via retailZoneMap?
  if pfQuest.retailZoneMap[uiMapID] then
    return pfQuest.retailZoneMap[uiMapID]
  end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMapID)
  if not info then return nil end
  -- Check if classic DB already has this zone by name — reuse its pfID.
  -- This prevents creating a duplicate pfID (e.g. 10000) for a zone that
  -- is already known as pfID 331 (Ashenvale) in the classic zones table.
  -- Without this, nodes get stored at pfID=10000 but GetCurrentMapID()
  -- returns pfID=331 via the name-lookup path, so UpdateNodes finds nothing.
  if pfDB["zones"] and pfDB["zones"]["loc"] then
    for existingPfID, zoneName in pairs(pfDB["zones"]["loc"]) do
      if zoneName == info.name then
        -- Classic zone already has this name; reuse its pfID
        pfQuest.retailZoneMap[uiMapID] = existingPfID
        pfQuest.retailZoneMapReverse[existingPfID] = uiMapID
        return existingPfID
      end
    end
  end
  -- No existing pfID found — allocate a new one in the retail range (>= 10000)
  local maxPfID = 10000
  for _, v in pairs(pfQuest.retailZoneMap) do
    if v >= maxPfID then maxPfID = v + 1 end
  end
  local pfID = maxPfID

  ensureDB()
  -- Register zone name (ensure loc table exists - database.lua may replace it)
  if not pfDB["zones"]["loc"] then pfDB["zones"]["loc"] = {} end
  pfDB["zones"]["loc"][pfID] = info.name
  pfDB["zones"]["data"][pfID] = { 99, 0, 0, 100, 100 }
  pfDB["minimap"][pfID] = { 4266.7, 2844.4 }

  -- Try to get real dimensions
  if C_Map.GetMapRects then
    local ok, tl, br = pcall(C_Map.GetMapRects, uiMapID)
    if ok and tl and br then
      local w = math.abs((br.x or 0)-(tl.x or 0))
      local h = math.abs((br.y or 0)-(tl.y or 0))
      if w > 100 then pfDB["minimap"][pfID] = { w, h }
      elseif w > 0 then pfDB["minimap"][pfID] = { w*62910, h*41942 } end
    end
  end

  -- Install into zone bridge (direct table update, avoid repeated log spam)
  if pfQuest.retailZoneMap then
    pfQuest.retailZoneMap[uiMapID] = pfID
  end
  if pfQuest.retailZoneMapReverse then
    pfQuest.retailZoneMapReverse[pfID] = uiMapID
  end
  -- Only call InstallRetailZoneBridge for batch updates, not single zones
  if pfMap and pfMap.GetCurrentMapID then
    pfMap.queue_update = GetTime()
  end

  return pfID
end

-- ── NPC registration ─────────────────────────────────────────────────────────
local function registerNPC(npcID, name, uiMapID, x, y)
  if not npcID or npcID <= 0 then return end
  ensureDB()

  -- Register name
  pfDB["units"]["loc"][npcID] = pfDB["units"]["loc"][npcID] or name

  -- Get or create zone
  local pfZoneID = registerZone(uiMapID)
  if not pfZoneID then return end

  -- Add coord if not already present
  local data = pfDB["units"]["data"][npcID]
  if not data then
    pfDB["units"]["data"][npcID] = { ["coords"]={}, ["fac"]="AH", ["lvl"]="??" }
    data = pfDB["units"]["data"][npcID]
  end

  -- Check for duplicate
  local px, py = math.floor(x*100+0.5)/100, math.floor(y*100+0.5)/100
  for _, c in ipairs(data["coords"]) do
    if math.abs(c[1]-px) < 1 and math.abs(c[2]-py) < 1 and c[3] == pfZoneID then return end
  end
  table.insert(data["coords"], { px, py, pfZoneID, 0 })
end

-- ── Quest registration ────────────────────────────────────────────────────────
local function registerQuest(questID)
  if not questID or pfRetailRuntime.populated[questID] then return end
  if not (C_QuestLog and C_QuestLog.GetInfo) then return end

  local info = C_QuestLog.GetInfo(questID)
  if not info or info.isHeader then return end

  ensureDB()
  pfRetailRuntime.populated[questID] = true

  -- Register quest title
  pfDB["quests"]["loc"][questID] = pfDB["quests"]["loc"][questID]
    or { ["T"] = info.title }
  pfDB["quests"]["data"][questID] = pfDB["quests"]["data"][questID]
    or { ["lvl"] = "??" }

  -- Get quest details for objective NPCs
  local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
  if objectives then
    for _, obj in ipairs(objectives) do
      if obj.type == "monster" and obj.text then
        -- Extract mob name from objective text ("Kill X: 0/6" -> "X")
        local mobName = string.match(obj.text, "^([^:]+):")
        if mobName then
          mobName = string.gsub(mobName, "^%s+", "")
          mobName = string.gsub(mobName, "%s+$", "")
          -- Try to find this NPC in the existing db by name
          for npcID, locName in pairs(pfDB["units"]["loc"]) do
            if locName == mobName then
              -- Link quest to this NPC
              local qdata = pfDB["quests"]["data"][questID]
              qdata["obj"] = qdata["obj"] or {}
              table.insert(qdata["obj"], npcID)
              break
            end
          end
        end
      end
    end
  end
end

-- ── Scan all current quests ───────────────────────────────────────────────────
local function scanQuestLog()
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
  local n = C_QuestLog.GetNumQuestLogEntries()
  for i = 1, n do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader and info.questID then
      registerQuest(info.questID)
    end
  end
end

-- ── Intercept NPC interactions to capture coordinates ──────────────────────
local function onNPCInteraction()
  local unit = "npc"
  if not UnitExists(unit) then unit = "target" end
  if not UnitExists(unit) then return end
  if UnitIsPlayer(unit) then return end

  local npcID = UnitGUID(unit)
  if not npcID then return end
  -- GUID format: "Creature-0-REALM-MAP-INSTANCE-NPCID-UNIQUE"
  local _, _, _, _, _, id = string.match(npcID, "(%a+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)")
  id = tonumber(id)
  if not id or id <= 0 then return end

  local name = UnitName(unit)
  if not name then return end

  -- Get position
  if not (C_Map and C_Map.GetBestMapForUnit) then return end
  local uiMapID = C_Map.GetBestMapForUnit("player")
  if not uiMapID then return end
  local pos = C_Map.GetPlayerMapPosition(uiMapID, "player")
  if not pos then return end
  local x, y = pos:GetXY()
  x, y = x * 100, y * 100

  registerNPC(id, name, uiMapID, x, y)
end

-- ── Intercept quest acceptance to link quest giver NPCs ─────────────────────
local function onQuestAccepted(questID)
  if not questID then return end

  -- Try to get the NPC we just accepted from
  local unit = "npc"
  if not UnitExists(unit) then unit = "target" end
  if UnitExists(unit) and not UnitIsPlayer(unit) then
    local npcGUID = UnitGUID(unit)
    if npcGUID then
      local _, _, _, _, _, id = string.match(npcGUID, "(%a+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)")
      id = tonumber(id)
      if id and id > 0 then
        local uiMapID = C_Map.GetBestMapForUnit("player")
        local pos = uiMapID and C_Map.GetPlayerMapPosition(uiMapID, "player")
        if pos then
          local x, y = pos:GetXY()
          registerNPC(id, UnitName(unit), uiMapID, x*100, y*100)
          -- Link as quest starter
          ensureDB()
          pfDB["quests"]["data"][questID] = pfDB["quests"]["data"][questID] or { ["lvl"]="??" }
          pfDB["quests"]["data"][questID]["start"] = pfDB["quests"]["data"][questID]["start"] or {}
          pfDB["quests"]["data"][questID]["start"]["U"] = { id }
        end
      end
    end
  end
  registerQuest(questID)
  -- Trigger map update
  if pfMap then
    pfMap.queue_update = GetTime()
  end
end

-- ── Event frame ──────────────────────────────────────────────────────────────
local runtimeFrame = CreateFrame("Frame")
runtimeFrame:RegisterEvent("PLAYER_LOGIN")
runtimeFrame:RegisterEvent("QUEST_LOG_UPDATE")
runtimeFrame:RegisterEvent("QUEST_ACCEPTED")
runtimeFrame:RegisterEvent("GOSSIP_SHOW")
runtimeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
runtimeFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

runtimeFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    -- Register the player's current zone immediately
    if C_Map and C_Map.GetBestMapForUnit then
      local uid = C_Map.GetBestMapForUnit("player")
      if uid then registerZone(uid) end
    end
    -- Scan quest log on login
    scanQuestLog()

  elseif event == "QUEST_LOG_UPDATE" then
    scanQuestLog()
    if pfMap then pfMap.queue_update = GetTime() end

  elseif event == "QUEST_ACCEPTED" then
    local questID = ...
    onQuestAccepted(questID)

  elseif event == "GOSSIP_SHOW" or event == "PLAYER_TARGET_CHANGED"
      or event == "UPDATE_MOUSEOVER_UNIT" then
    onNPCInteraction()
  end
end)

-- ── Zone change: register the new zone immediately ───────────────────────────
local zoneChangeFrame = CreateFrame("Frame")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneChangeFrame:RegisterEvent("ZONE_CHANGED")
zoneChangeFrame:SetScript("OnEvent", function(self, event)
  if C_Map and C_Map.GetBestMapForUnit then
    local uid = C_Map.GetBestMapForUnit("player")
    if uid then
      registerZone(uid)
      if pfMap then pfMap.queue_update = GetTime() end
    end
  end
end)

-- Make registration functions public so other modules can call them
pfRetailRuntime.registerZone  = registerZone
pfRetailRuntime.registerNPC   = registerNPC
pfRetailRuntime.registerQuest = registerQuest
pfRetailRuntime.scanQuestLog  = scanQuestLog

-- resetPopulated: clear the dedup cache so scanQuestLog re-registers all quests.
-- Called by db_guard after wiping pfDB, otherwise the deferred rescan is a no-op
-- because every questID is already marked as populated from the pre-wipe scan.
pfRetailRuntime.resetPopulated = function()
  pfRetailRuntime.populated = {}
end
