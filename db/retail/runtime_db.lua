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
-- wantedNames: maps lowercase mob name → questID, populated at quest scan time.
-- When registerNPC sees a name in this table it immediately links it as an objective
-- and triggers a map update, so pins appear the moment the NPC is first observed
-- rather than waiting for the next UpdateNodes poll cycle.
pfRetailRuntime.wantedNames = {}

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

  -- If this NPC name matches a quest objective, link it immediately so
  -- SearchQuestID's GetIDByName path finds it on the very next UpdateNodes call.
  local lname = string.lower(name)
  local questID = pfRetailRuntime.wantedNames[lname]
  if questID and pfDB["quests"]["data"][questID] then
    local qdata = pfDB["quests"]["data"][questID]
    qdata["obj"] = qdata["obj"] or { ["U"] = {} }
    qdata["obj"]["U"] = qdata["obj"]["U"] or {}
    -- Only add if not already present
    local already = false
    for _, uid in ipairs(qdata["obj"]["U"]) do
      if uid == npcID then already = true; break end
    end
    if not already then
      table.insert(qdata["obj"]["U"], npcID)
    end
  end
end

-- ── Quest registration ────────────────────────────────────────────────────────
-- registerQuestFromInfo: core registration using an already-fetched info struct.
-- C_QuestLog.GetInfo() takes a log INDEX not a questID, so callers must pass
-- the info object directly rather than expecting this function to look it up.
local function registerQuestFromInfo(info)
  if not info or info.isHeader or not info.questID then return end
  local questID = info.questID
  if pfRetailRuntime.populated[questID] then return end

  ensureDB()
  pfRetailRuntime.populated[questID] = true

  -- Register quest title and basic data
  pfDB["quests"]["loc"][questID] = pfDB["quests"]["loc"][questID]
    or { ["T"] = info.title or ("Quest " .. questID) }
  pfDB["quests"]["data"][questID] = pfDB["quests"]["data"][questID]
    or { ["lvl"] = tonumber(info.level) or 0 }

  -- Try to link objective NPCs by name-matching against registered units.
  -- Also index objective mob names into wantedNames so registerNPC can link
  -- them immediately when the NPC is first observed (target, nameplate, etc.)
  local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
  if objectives then
    for _, obj in ipairs(objectives) do
      if obj.type == "monster" and obj.text then
        -- Retail format: "0/5 Mob Name" (count prefix, no colon separator)
        -- Classic format: "Mob Name: 0/5" (name before colon)
        -- Try retail format first, fall back to classic.
        local mobName = string.match(obj.text, "^%d+/%d+%s+(.+)$")
                     or string.match(obj.text, "^([^:]+):")
        if mobName then
          mobName = string.match(mobName, "^%s*(.-)%s*$")  -- trim
          -- Skip pure action phrases (contain no capitalised proper noun pattern)
          -- by checking the name is non-empty; false positives don't hurt.
          -- Index name for fast future lookup by registerNPC
          pfRetailRuntime.wantedNames[string.lower(mobName)] = questID
          -- Also try to link immediately if already known
          for npcID, locName in pairs(pfDB["units"]["loc"]) do
            if locName == mobName then
              local qdata = pfDB["quests"]["data"][questID]
              qdata["obj"] = qdata["obj"] or { ["U"] = {} }
              qdata["obj"]["U"] = qdata["obj"]["U"] or {}
              table.insert(qdata["obj"]["U"], npcID)
              break
            end
          end
        end
      end
    end
  end
end

-- registerQuest: look up a questID in the current log and register it.
-- Iterates log entries to find the matching index (GetInfo takes an index).
local function registerQuest(questID)
  if not questID or pfRetailRuntime.populated[questID] then return end
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
  local n = C_QuestLog.GetNumQuestLogEntries()
  for i = 1, n do
    local info = C_QuestLog.GetInfo(i)
    if info and info.questID == questID then
      registerQuestFromInfo(info)
      return
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
      registerQuestFromInfo(info)  -- pass info directly; avoids redundant index lookup
    end
  end
end

-- ── Back-link already-registered NPCs against wantedNames ───────────────────
-- loadNPCCache() runs before scanQuestLog(), so cached NPCs are registered
-- before wantedNames is populated. Call this once after scanQuestLog() to link
-- any cached NPC whose name matches a quest objective.
local function linkCachedNPCs()
  if not next(pfRetailRuntime.wantedNames) then return end
  local linked = 0
  for npcID, name in pairs(pfDB["units"]["loc"]) do
    if name then
      local lname = string.lower(name)
      local questID = pfRetailRuntime.wantedNames[lname]
      if questID and pfDB["quests"]["data"][questID] then
        local qdata = pfDB["quests"]["data"][questID]
        qdata["obj"] = qdata["obj"] or { ["U"] = {} }
        qdata["obj"]["U"] = qdata["obj"]["U"] or {}
        local already = false
        for _, uid in ipairs(qdata["obj"]["U"]) do
          if uid == npcID then already = true; break end
        end
        if not already then
          table.insert(qdata["obj"]["U"], npcID)
          linked = linked + 1
        end
      end
    end
  end
  if linked > 0 then
    pfQuest:Debug("|cff33ff33" .. linked .. "|r cached NPC(s) linked to quest objectives.")
    if pfMap then pfMap.queue_update = GetTime() end
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
          pfDB["quests"]["data"][questID] = pfDB["quests"]["data"][questID] or { ["lvl"]=0 }
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
runtimeFrame:RegisterEvent("PLAYER_LOGOUT")
runtimeFrame:RegisterEvent("QUEST_LOG_UPDATE")
runtimeFrame:RegisterEvent("QUEST_ACCEPTED")
runtimeFrame:RegisterEvent("GOSSIP_SHOW")
runtimeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
runtimeFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

-- ── NPC cache persistence ─────────────────────────────────────────────────────
-- pfQuest_npcCache (SavedVariablesPerCharacter) stores NPC positions seen in
-- previous sessions so units.data is non-empty at login without any interaction.
-- Format: { data = {[npcID]={coords=...,fac=...,lvl=...}}, loc = {[npcID]=name} }

local function loadNPCCache()
  if type(pfQuest_npcCache) ~= "table" then return end
  ensureDB()
  local loaded = 0
  if type(pfQuest_npcCache.data) == "table" then
    for npcID, entry in pairs(pfQuest_npcCache.data) do
      if not pfDB["units"]["data"][npcID] then
        pfDB["units"]["data"][npcID] = entry
        loaded = loaded + 1
      end
    end
  end
  if type(pfQuest_npcCache.loc) == "table" then
    for npcID, name in pairs(pfQuest_npcCache.loc) do
      pfDB["units"]["loc"][npcID] = pfDB["units"]["loc"][npcID] or name
    end
  end
  if loaded > 0 then
    pfQuest:Debug("|cff33ff33" .. loaded .. "|r NPCs loaded from session cache.")
  end
end

local function saveNPCCache()
  ensureDB()
  -- Only persist retail NPCs (no classic IDs — those get wiped by db_guard anyway)
  -- Keep the cache bounded: max 2000 entries to avoid SavedVars bloat
  local MAX_CACHE = 2000
  local newData, newLoc, count = {}, {}, 0
  for npcID, entry in pairs(pfDB["units"]["data"]) do
    if count >= MAX_CACHE then break end
    -- Only cache entries that have at least one coord in a retail zone (pfID >= 10000)
    -- OR that were preserved classic-quest NPCs (low IDs with real coord data)
    if entry and entry["coords"] and #entry["coords"] > 0 then
      newData[npcID] = entry
      newLoc[npcID]  = pfDB["units"]["loc"][npcID]
      count = count + 1
    end
  end
  pfQuest_npcCache = { data = newData, loc = newLoc }
end

runtimeFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    -- Load NPC positions from previous sessions before anything else runs,
    -- so units.data is non-empty when scanQuestLog links objectives.
    -- This must run AFTER db_guard (which fires first at PLAYER_LOGIN and wipes
    -- units.data) — but since we're in runtime_db's own PLAYER_LOGIN handler,
    -- load order in addon.xml guarantees db_guard has already run.
    loadNPCCache()
    -- Register the player's current zone immediately
    if C_Map and C_Map.GetBestMapForUnit then
      local uid = C_Map.GetBestMapForUnit("player")
      if uid then registerZone(uid) end
    end
    -- Scan quest log on login
    scanQuestLog()
    -- Back-link any cached NPCs whose names match quest objectives.
    -- Must run after scanQuestLog() which populates wantedNames.
    linkCachedNPCs()
    -- Pre-fetch zone dimensions for all quest-related zones (#6).
    -- C_QuestLog.GetQuestUiMapID returns the uiMapID for a quest's zone — call it
    -- for every active quest so registerZone stores real GetMapRects data instead
    -- of the 4266x2844 placeholder. Deferred 2s so the game is fully loaded.
    C_Timer.After(2, function()
      if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
      local n = C_QuestLog.GetNumQuestLogEntries()
      for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
          -- GetQuestUiMapID returns the primary zone uiMapID for the quest
          local uid = C_QuestLog.GetQuestUiMapID and C_QuestLog.GetQuestUiMapID(info.questID)
          if uid and uid > 0 then
            registerZone(uid)
          end
        end
      end
    end)

  elseif event == "PLAYER_LOGOUT" then
    saveNPCCache()

  elseif event == "QUEST_LOG_UPDATE" then
    scanQuestLog()
    linkCachedNPCs()
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

-- ── Nameplate hook: capture visible NPCs without requiring explicit targeting ─
-- NAME_PLATE_UNIT_ADDED fires whenever a nameplate enters the player's view.
-- This lets us register nearby NPC positions passively as the player moves around,
-- building up units.data much faster than explicit target/mouseover alone.
-- Guards: player units and invalid GUIDs are skipped; only creatures are stored.
local nameplateFrame = CreateFrame("Frame")
nameplateFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
nameplateFrame:SetScript("OnEvent", function(self, event, unitToken)
  if not unitToken then return end
  -- Skip player characters
  if UnitIsPlayer(unitToken) then return end

  local guid = UnitGUID(unitToken)
  if not guid then return end
  -- Extract NPC ID from GUID: "Creature-0-REALM-MAP-INST-NPCID-UNIQUE"
  local _, _, _, _, _, id = string.match(guid, "(%a+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)")
  id = tonumber(id)
  if not id or id <= 0 then return end

  local name = UnitName(unitToken)
  if not name then return end

  if not (C_Map and C_Map.GetBestMapForUnit) then return end
  local uiMapID = C_Map.GetBestMapForUnit("player")
  if not uiMapID then return end
  local pos = C_Map.GetPlayerMapPosition(uiMapID, "player")
  if not pos then return end
  local x, y = pos:GetXY()
  -- Nameplate position is approximate (player position), but still useful for
  -- establishing which zone the NPC is in. x/y will be close enough for a pin.
  registerNPC(id, name, uiMapID, x * 100, y * 100)

  -- If this NPC matches a quest objective, trigger a node update
  if pfMap then pfMap.queue_update = GetTime() end
end)

-- Make registration functions public so other modules can call them
pfRetailRuntime.registerZone    = registerZone
pfRetailRuntime.registerNPC     = registerNPC
pfRetailRuntime.registerQuest   = registerQuest
pfRetailRuntime.scanQuestLog    = scanQuestLog
pfRetailRuntime.linkCachedNPCs  = linkCachedNPCs

-- resetPopulated: clear the dedup cache so scanQuestLog re-registers all quests.
-- Called by db_guard after wiping pfDB, otherwise the deferred rescan is a no-op
-- because every questID is already marked as populated from the pre-wipe scan.
pfRetailRuntime.resetPopulated = function()
  pfRetailRuntime.populated = {}
  pfRetailRuntime.wantedNames = {}
end
