-- pfQuest-retail: MobInfo2 SavedVariable import
-- ============================================================
-- Supports two generations of MobInfo2:
--
-- MODERN (ileclerk CurseForge v11.0+, retail-compatible):
--   SavedVariable: MI2_DB
--   Structure:    MI2_DB.location[npcID][uiMapID] = {{x,y},{x,y},...}
--   Coordinates:  0–100 percentages (GetPlayerMapPosition×100) = pfQuest scale
--   Key:          npcID directly — no name lookup needed
--   Zone:         retail uiMapID → pfZoneID via pfQuest.retailZoneMap
--
-- LEGACY (kc8pnd/MobInfo2, v2.97, Classic only):
--   SavedVariable: MobInfoDB
--   Structure:    MobInfoDB["Name:Level"] = { ml="x1/y1/x2/y2/c/z" }
--   Coordinates:  0–100 percentages; z = classic zone ID = pfQuest pfID
--   Key:          name resolved via pfDB["units"]["loc"] reverse index
-- ============================================================

-- ── Shared helpers ────────────────────────────────────────────────────────────
local function linkToQuest(npcID, name)
  if not (pfRetailRuntime and pfRetailRuntime.wantedNames and name) then return end
  local questID = pfRetailRuntime.wantedNames[string.lower(name)]
  if not (questID and pfDB["quests"]["data"][questID]) then return end
  local qdata = pfDB["quests"]["data"][questID]
  qdata["obj"] = qdata["obj"] or { ["U"] = {} }
  qdata["obj"]["U"] = qdata["obj"]["U"] or {}
  for _, uid in ipairs(qdata["obj"]["U"]) do
    if uid == npcID then return end
  end
  table.insert(qdata["obj"]["U"], npcID)
end

local function ensureUnit(npcID)
  if not pfDB["units"]["data"][npcID] then
    pfDB["units"]["data"][npcID] = { ["coords"]={}, ["fac"]="AH", ["lvl"]="??" }
  end
end

local function addCoord(npcID, x, y, pfZoneID)
  local coords = pfDB["units"]["data"][npcID]["coords"]
  for _, c in ipairs(coords) do
    if c[3] == pfZoneID and math.abs(c[1]-x) < 2 and math.abs(c[2]-y) < 2 then
      return false  -- duplicate
    end
  end
  table.insert(coords, { x, y, pfZoneID, 0 })
  return true
end

-- ── Modern MI2_DB import (ileclerk v11.0+, retail) ───────────────────────────
-- MI2_DB.location[npcID] = {
--   zone  = { zoneID, uiMapID },       -- primary zone hint
--   [uiMapID] = { {x,y}, {x,y}, ... }  -- coord list per map, 0-100 scale
-- }
local function importModern()
  if type(MI2_DB) ~= "table" then return 0 end
  local locDB = MI2_DB.location
  if type(locDB) ~= "table" then return 0 end
  if not (pfQuest and pfQuest.retailZoneMap) then return 0 end

  -- Build a wanted-npcID set from classicNPCNames + wantedNames for O(1) lookup:
  -- wantedNames = { [lowername] = questID }
  -- classicNPCNames = { [lowername] = npcID }
  -- Intersection: names in both tables → we want those npcIDs from MI2
  local wantedIDs = {}  -- { [npcID] = { name=..., questID=... } }
  if pfRetailRuntime and pfRetailRuntime.wantedNames and pfQuest.classicNPCNames then
    for lname, questID in pairs(pfRetailRuntime.wantedNames) do
      local npcID = pfQuest.classicNPCNames[lname]
      if npcID then
        wantedIDs[npcID] = { name = lname, questID = questID }
      end
    end
  end

  local imported = 0
  for npcID, sourceData in pairs(locDB) do
    npcID = tonumber(npcID)
    if npcID and type(sourceData) == "table" then
      -- Iterate every uiMapID sub-table (skip the "zone" hint key)
      for mapID, coordList in pairs(sourceData) do
        if type(mapID) == "number" and type(coordList) == "table" then
          -- Resolve uiMapID → pfZoneID via the retail zone bridge
          local pfZoneID = pfQuest.retailZoneMap[mapID]
          if pfZoneID then
            ensureUnit(npcID)
            for _, coord in ipairs(coordList) do
              local x, y = coord[1], coord[2]
              if x and y and not (x == 0 and y == 0) then
                if addCoord(npcID, x, y, pfZoneID) then
                  imported = imported + 1
                  -- Try name from current session first, then wantedIDs index
                  local name = pfDB["units"]["loc"] and pfDB["units"]["loc"][npcID]
                  if not name and wantedIDs[npcID] then
                    name = wantedIDs[npcID].name
                    pfDB["units"]["loc"][npcID] = name  -- persist for future lookups
                  end
                  linkToQuest(npcID, name)
                end
              end
            end
          end
        end
      end
    end
  end
  return imported
end

-- ── Legacy MobInfoDB import (kc8pnd v2.97, Classic) ──────────────────────────
-- MobInfoDB["Name:Level"] = { ml="x1/y1/x2/y2/continent/pfZoneID" }
-- pfZoneID here is the classic zone ID which equals pfQuest's pfID directly.
local function importLegacy()
  if type(MobInfoDB) ~= "table" then return 0 end

  -- Build name → npcID reverse index from pfDB["units"]["loc"]
  local nameToID = {}
  for npcID, name in pairs(pfDB["units"]["loc"]) do
    if type(name) == "string" and name ~= "" then
      nameToID[name] = npcID
    end
  end

  local imported = 0
  for mobIndex, mobInfo in pairs(MobInfoDB) do
    if mobIndex ~= "DatabaseVersion:0" and type(mobInfo) == "table" and mobInfo.ml then
      local name = string.match(mobIndex, "^(.+):%d+$")
      local npcID = name and nameToID[name]
      if npcID then
        local x1,y1,x2,y2,c,z = string.match(mobInfo.ml,
          "^(%d+%.?%d*)/(%d+%.?%d*)/(%d+%.?%d*)/(%d+%.?%d*)/(%d+)/(%d+)$")
        x1,y1,x2,y2,z = tonumber(x1),tonumber(y1),tonumber(x2),tonumber(y2),tonumber(z)
        -- z is a classic zone pfID (1–9999)
        if z and z > 0 and z < 10000 and x1 and y1 then
          local x = (x1 + (x2 or x1)) / 2
          local y = (y1 + (y2 or y1)) / 2
          ensureUnit(npcID)
          if addCoord(npcID, x, y, z) then
            imported = imported + 1
            linkToQuest(npcID, name)
          end
        end
      end
    end
  end
  return imported
end

-- ── Main entry point ──────────────────────────────────────────────────────────
local function importMobInfo2()
  if not (pfDB and pfDB["units"] and pfDB["units"]["loc"]) then return end

  local modernCount = importModern()
  local legacyCount = importLegacy()
  local total = modernCount + legacyCount

  if total > 0 then
    local parts = {}
    if modernCount > 0 then table.insert(parts, modernCount .. " from MI2_DB (retail)") end
    if legacyCount > 0 then table.insert(parts, legacyCount .. " from MobInfoDB (legacy)") end
    pfQuest:Debug("|cffaabbffMobInfo2|r: |cff33ff33" .. total
      .. "|r NPC coord(s) imported (" .. table.concat(parts, ", ") .. ")")
    if pfMap then pfMap.queue_update = GetTime() end
  end
end

-- Deferred 1s after PLAYER_LOGIN: npcCache and scanQuestLog complete first,
-- meaning pfDB["units"]["loc"] and pfQuest.retailZoneMap are both populated.
local mi2Frame = CreateFrame("Frame")
mi2Frame:RegisterEvent("PLAYER_LOGIN")
mi2Frame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  C_Timer.After(1, importMobInfo2)
end)

pfMobInfo2Import = importMobInfo2
