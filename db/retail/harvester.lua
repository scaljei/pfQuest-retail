-- pfQuest-retail: NPC coordinate harvester
-- ============================================================
-- Supplements the nameplate/target/mouseover hooks in runtime_db
-- with additional passive harvest vectors, and imports coordinate
-- data from third-party SavedVariables (Wowhead Looter).
--
-- All vectors funnel through pfRetailRuntime.registerNPC so dedup,
-- zone mapping, wantedNames linking, and npcCache persistence are
-- handled in one place.
--
-- Harvest vectors:
--   1. wlUnit (Wowhead Looter SavedVariable)    — imported at login
--   2. COMBAT_LOG_EVENT_UNFILTERED / UNIT_DIED  — passive kill tracking
--   3. LOOT_OPENED                              — looting a creature
--   4. MERCHANT_SHOW / TRAINER_SHOW             — NPC service interaction
--   5. CHAT_MSG_MONSTER_SAY/YELL/EMOTE         — nearby NPC speech
--   6. QUEST_DETAIL / QUEST_PROGRESS /
--      QUEST_COMPLETE / QUEST_GREETING          — quest giver / finisher
-- ============================================================

-- ── Shared helpers ────────────────────────────────────────────────────────────

local function getPlayerPos()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local uiMapID = C_Map.GetBestMapForUnit("player")
  if not uiMapID then return nil end
  local pos = C_Map.GetPlayerMapPosition(uiMapID, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  return uiMapID, x * 100, y * 100
end

-- Parse npcID from a unit GUID.
-- GUID format: "Creature-0-REALM-MAP-INST-NPCID-UNIQUE"
local function npcIDFromGUID(guid)
  if not guid then return nil end
  local kind = string.match(guid, "^(%a+)-")
  if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
  local id = select(6, string.match(guid,
    "(%a+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)"))
  return tonumber(id)
end

local function registerFromUnit(unit)
  if not pfRetailRuntime or not pfRetailRuntime.registerNPC then return end
  if not UnitExists(unit) then return end
  if UnitIsPlayer(unit) then return end
  local guid = UnitGUID(unit)
  local npcID = npcIDFromGUID(guid)
  if not npcID or npcID <= 0 then return end
  local name = UnitName(unit)
  if not name or name == UNKNOWN then return end
  local uiMapID, x, y = getPlayerPos()
  if not uiMapID then return end
  pfRetailRuntime.registerNPC(npcID, name, uiMapID, x, y)
  if pfMap then pfMap.queue_update = GetTime() end
end

-- ── 1. Wowhead Looter import ──────────────────────────────────────────────────
-- wlUnit[npcID] = {
--   name = { [locale] = "Name" },
--   spec = { [dd] = { [level] = { loc = { [zone] = { [uiMapID] = {
--     n = count, [1] = {x=412, y=337, dl=uiMapID}, ...
--   }}}}}},
-- }
-- Coords are in 0-1000 scale; pfQuest uses 0-100, so divide by 10.
-- ─────────────────────────────────────────────────────────────────────────────
local function importWowheadLooter()
  if type(wlUnit) ~= "table" then return 0 end
  if not (pfRetailRuntime and pfRetailRuntime.registerNPC) then return 0 end

  local imported = 0

  for npcID, unitData in pairs(wlUnit) do
    npcID = tonumber(npcID)
    if npcID and npcID > 0 and type(unitData) == "table" then

      -- Extract name: prefer enUS, fall back to any locale
      local name = nil
      if type(unitData.name) == "table" then
        name = unitData.name["enUS"] or unitData.name[GetLocale()]
        if not name then
          for _, n in pairs(unitData.name) do name = n; break end
        end
      end
      if name and name ~= "" then
      -- Walk spec → level → loc → uiMapID → coord list
      if type(unitData.spec) == "table" then
        for _, specData in pairs(unitData.spec) do
          if type(specData) == "table" then
            for _, levelData in pairs(specData) do
              if type(levelData) == "table" and type(levelData.loc) == "table" then
                for _, zoneData in pairs(levelData.loc) do
                  if type(zoneData) == "table" then
                    for uiMapID, coordSet in pairs(zoneData) do
                      if type(uiMapID) == "number" and type(coordSet) == "table" then
                        local n = coordSet.n or 0
                        for i = 1, n do
                          local coord = coordSet[i]
                          if coord and coord.x and coord.y then
                            -- wlUnit coords are 0-1000; pfQuest uses 0-100
                            local x = coord.x / 10
                            local y = coord.y / 10
                            if x > 0 or y > 0 then
                              pfRetailRuntime.registerNPC(npcID, name, uiMapID, x, y)
                              imported = imported + 1
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end  -- if name
    end  -- npcID valid
  end  -- for pairs(wlUnit)

  if imported > 0 then
    pfQuest:Debug("|cffaabbffWowhead Looter|r: |cff33ff33" .. imported
      .. "|r coord(s) imported from wlUnit.")
    if pfMap then pfMap.queue_update = GetTime() end
  end

  return imported
end

-- ── 2. Combat log: UNIT_DIED ──────────────────────────────────────────────────
-- When a creature dies, the player is close to its spawn position.
-- COMBAT_LOG_EVENT_UNFILTERED fires with subevent="UNIT_DIED" and destGUID.
-- ─────────────────────────────────────────────────────────────────────────────
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatFrame:SetScript("OnEvent", function(self, event)
  local _, subevent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
  if subevent ~= "UNIT_DIED" and subevent ~= "UNIT_DESTROYED" then return end
  if not destGUID or not destName then return end
  local npcID = npcIDFromGUID(destGUID)
  if not npcID or npcID <= 0 then return end
  if not destName or destName == "" or destName == UNKNOWN then return end
  local uiMapID, x, y = getPlayerPos()
  if not uiMapID then return end
  if not pfRetailRuntime or not pfRetailRuntime.registerNPC then return end
  pfRetailRuntime.registerNPC(npcID, destName, uiMapID, x, y)
  if pfMap then pfMap.queue_update = GetTime() end
end)

-- ── 3. Loot: LOOT_OPENED ─────────────────────────────────────────────────────
-- When the player opens a loot window on a creature, it's at their position.
-- ─────────────────────────────────────────────────────────────────────────────
local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("LOOT_OPENED")
lootFrame:SetScript("OnEvent", function(self, event)
  -- GetLootSourceInfo returns GUID of the loot source
  if not GetLootSourceInfo then return end
  local guid = GetLootSourceInfo(1)
  if not guid then return end
  local npcID = npcIDFromGUID(guid)
  if not npcID or npcID <= 0 then return end
  -- Name from target if we still have it targeted
  local name = UnitName("target")
  if not name or name == UNKNOWN then
    -- Fall back to existing loc entry
    name = pfDB and pfDB["units"] and pfDB["units"]["loc"] and pfDB["units"]["loc"][npcID]
  end
  if not name then return end
  local uiMapID, x, y = getPlayerPos()
  if not uiMapID then return end
  if not pfRetailRuntime or not pfRetailRuntime.registerNPC then return end
  pfRetailRuntime.registerNPC(npcID, name, uiMapID, x, y)
  if pfMap then pfMap.queue_update = GetTime() end
end)

-- ── 4. NPC service: MERCHANT_SHOW / TRAINER_SHOW and other NPC interactions ──
-- All events where a specific unit token is the interacting NPC.
local serviceEvents = {
  MERCHANT_SHOW       = "npc",
  TRAINER_SHOW        = "npc",
  AUCTION_HOUSE_SHOW  = "auctioneer",
  BANKFRAME_OPENED    = "banker",
  TAXIMAP_OPENED      = "taxi",
  PET_STABLE_SHOW     = "stable",
  BATTLEFIELDS_SHOW   = "battlemaster",
  CONFIRM_BINDER      = "binder",
}
local serviceFrame = CreateFrame("Frame")
for event in pairs(serviceEvents) do
  serviceFrame:RegisterEvent(event)
end
serviceFrame:SetScript("OnEvent", function(self, event)
  local unit = serviceEvents[event]
  if unit then registerFromUnit(unit) end
end)

-- ── 5. Nearby NPC speech ──────────────────────────────────────────────────────
-- CHAT_MSG_MONSTER_* fires when a nearby NPC says/yells/emotes something.
-- Args: (text, senderName, _, _, _, _, _, _, _, _, _, guid)
-- Position is approximate (player position) but zone/map is correct.
-- ─────────────────────────────────────────────────────────────────────────────
local speechFrame = CreateFrame("Frame")
speechFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
speechFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
speechFrame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
speechFrame:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
speechFrame:SetScript("OnEvent", function(self, event, text, senderName, _, _, _, _, _, _, _, _, _, guid)
  if not guid or not senderName then return end
  local npcID = npcIDFromGUID(guid)
  if not npcID or npcID <= 0 then return end
  if senderName == "" or senderName == UNKNOWN then return end
  local uiMapID, x, y = getPlayerPos()
  if not uiMapID then return end
  if not pfRetailRuntime or not pfRetailRuntime.registerNPC then return end
  pfRetailRuntime.registerNPC(npcID, senderName, uiMapID, x, y)
  if pfMap then pfMap.queue_update = GetTime() end
end)

-- ── 6. Quest NPC: giver and finisher ─────────────────────────────────────────
-- QUEST_DETAIL fires when a quest offer dialog opens (NPC is "questnpc").
-- QUEST_PROGRESS fires when talking to the turn-in NPC mid-quest.
-- QUEST_COMPLETE fires when turning in a quest.
-- QUEST_GREETING fires when an NPC has multiple quests to offer.
-- UnitGUID("questnpc") gives the NPC's GUID at interaction time.
-- ─────────────────────────────────────────────────────────────────────────────
local questNPCFrame = CreateFrame("Frame")
questNPCFrame:RegisterEvent("QUEST_DETAIL")
questNPCFrame:RegisterEvent("QUEST_PROGRESS")
questNPCFrame:RegisterEvent("QUEST_COMPLETE")
questNPCFrame:RegisterEvent("QUEST_GREETING")
questNPCFrame:SetScript("OnEvent", function(self, event)
  registerFromUnit("questnpc")
end)

-- ── Login: import third-party SavedVars ───────────────────────────────────────
-- Deferred 2s so wlUnit is fully loaded and pfRetailRuntime is ready.
-- ─────────────────────────────────────────────────────────────────────────────
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self, event)
  self:UnregisterAllEvents()
  C_Timer.After(2, function()
    importWowheadLooter()
  end)
end)

-- Expose for /db commands
pfHarvester = {
  importWowheadLooter = importWowheadLooter,
}
