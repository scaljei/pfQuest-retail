-- pfQuest-retail: MobInfo2 SavedVariable import
-- ============================================================
-- Supports two generations of MobInfo2:
--
-- LEGACY (kc8pnd/MobInfo2, v2.97 and earlier — Classic only):
--   SavedVariable: MobInfoDB
--   Key format:   "MobName:Level" → { ml="x1/y1/x2/y2/c/z", ... }
--   Coordinates:  0–100 percentages; z = classic zone ID = pfQuest pfID
--   Limitation:   keyed by name+level, requires reverse lookup via units.loc
--
-- MODERN (ileclerk CurseForge v11.0+, retail-compatible):
--   SavedVariable: MI2_MobDB (MobInfoDB deprecated/reset)
--   Key format:   npcID (integer) → { loc={ uiMapID, x, y, ... }, ... }
--   Coordinates:  0–1 fractions from C_Map.GetPlayerMapPosition (×100 = pfQuest)
--   Advantage:    direct npcID key, retail uiMapIDs, no name lookup needed
--
-- Both paths write into pfDB["units"]["data"][npcID]["coords"] and link
-- matched mobs to wantedNames quest objectives immediately.
-- ============================================================

-- ── Shared helper ─────────────────────────────────────────────────────────────
local function linkToQuest(npcID, name)
  if not (pfRetailRuntime and pfRetailRuntime.wantedNames and name) then return end
  local questID = pfRetailRuntime.wantedNames[string.lower(name)]
  if not (questID and pfDB["quests"]["data"][questID]) then return end
  local qdata = pfDB["quests"]["data"][questID]
  qdata["obj"] = qdata["obj"] or { ["U"] = {} }
  qdata["obj"]["U"] = qdata["obj"]["U"] or {}
  for _, uid in ipairs(qdata["obj"]["U"]) do
    if uid == npcID then return end  -- already linked
  end
  table.insert(qdata["obj"]["U"], npcID)
end

local function ensureUnit(npcID)
  if not pfDB["units"]["data"][npcID] then
    pfDB["units"]["data"][npcID] = { ["coords"]={}, ["fac"]="AH", ["lvl"]="??" }
  end
end

local function addCoord(npcID, x, y, pfZoneID)
  local data = pfDB["units"]["data"][npcID]
  for _, c in ipairs(data["coords"]) do
    if c[3] == pfZoneID and math.abs(c[1]-x) < 2 and math.abs(c[2]-y) < 2 then
      return false  -- duplicate
    end
  end
  table.insert(data["coords"], { x, y, pfZoneID, 0 })
  return true
end

-- ── Modern MobInfo2 import (ileclerk, retail-compatible) ──────────────────────
-- Key: npcID (integer) → { loc={ uiMapID=N, x=0.xx, y=0.xx } } or similar.
-- The exact structure isn't publicly documented but likely matches what
-- C_Map.GetPlayerMapPosition + UnitGUID produce. We probe several plausible
-- field layouts and fall back gracefully if the structure differs.
local function importModern()
  -- New DB name — ileclerk said MobInfoDB is "reset/no longer used"
  -- Common choices: MI2_MobDB, MobInfo2DB, MI2DB
  local candidates = { MI2_MobDB, MobInfo2DB, MI2DB }
  local db = nil
  for _, t in ipairs(candidates) do
    if type(t) == "table" then db = t; break end
  end
  if not db then return 0 end

  local imported = 0
  for key, entry in pairs(db) do
    local npcID = tonumber(key)
    if npcID and type(entry) == "table" then
      -- Probe common location field names
      local loc = entry.loc or entry.location or entry.pos
      if type(loc) == "table" then
        local uiMapID = loc.uiMapID or loc.mapID or loc.map
        local x = loc.x or loc.x1
        local y = loc.y or loc.y1
        if uiMapID and x and y then
          -- Convert retail uiMapID → pfID via zone bridge
          local pfZoneID = pfQuest.retailZoneMap and pfQuest.retailZoneMap[uiMapID]
          if pfZoneID then
            -- Convert [0,1] fractions to [0,100] percentages if needed
            if x <= 1 then x = x * 100 end
            if y <= 1 then y = y * 100 end
            ensureUnit(npcID)
            if addCoord(npcID, x, y, pfZoneID) then
              imported = imported + 1
              -- Also grab name from loc if present, for wantedNames linkage
              local name = loc.name or (pfDB["units"]["loc"] and pfDB["units"]["loc"][npcID])
              linkToQuest(npcID, name)
            end
          end
        end
      end
    end
  end
  return imported
end

-- ── Legacy MobInfo2 import (kc8pnd, Classic only) ─────────────────────────────
-- Key: "MobName:Level" → { ml="x1/y1/x2/y2/c/z" }
-- z = classic zone ID = pfQuest pfID (same numbering). Requires name→npcID lookup.
local function importLegacy()
  if type(MobInfoDB) ~= "table" then return 0 end

  -- Build name→npcID reverse index from pfDB["units"]["loc"]
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
          "^(%d+)/(%d+)/(%d+)/(%d+)/(%d+)/(%d+)$")
        x1,y1,x2,y2,z = tonumber(x1),tonumber(y1),tonumber(x2),tonumber(y2),tonumber(z)
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
    if modernCount > 0 then table.insert(parts, modernCount .. " from modern DB") end
    if legacyCount > 0 then table.insert(parts, legacyCount .. " from legacy DB") end
    pfQuest:Debug("|cffaabbffMobInfo2|r: |cff33ff33" .. total .. "|r NPC coords imported ("
      .. table.concat(parts, ", ") .. ")")
    if pfMap then pfMap.queue_update = GetTime() end
  end
end

-- Deferred 1s post-PLAYER_LOGIN: npcCache and scanQuestLog complete first
local mi2Frame = CreateFrame("Frame")
mi2Frame:RegisterEvent("PLAYER_LOGIN")
mi2Frame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  C_Timer.After(1, importMobInfo2)
end)

pfMobInfo2Import = importMobInfo2
