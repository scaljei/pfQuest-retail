-- pfQuest-retail: MobInfo2 SavedVariable import
-- ============================================================
-- If MobInfo2 is installed, its SavedVariable "MobInfoDB" contains mob
-- location data gathered by the user over multiple sessions. This module
-- reads that data at login and cross-references it with pfDB["units"]["loc"]
-- to pre-populate pfDB["units"]["data"] with NPC coordinates.
--
-- MobInfoDB key format : "MobName:Level"  → { ml="x1/y1/x2/y2/c/z", ... }
-- ml coordinates       : x1,y1,x2,y2 are 0–100 percentages (same as pfQuest)
--                        c = classic continent ID (not used; z is enough)
--                        z = classic zone ID = pfQuest pfID (direct match)
--
-- Because MobInfo2 keys by name+level (not NPC ID), we reverse-index
-- pfDB["units"]["loc"] (npcID→name) to resolve name → npcID.
-- ============================================================

local function importMobInfo2()
  if type(MobInfoDB) ~= "table" then return end
  if not (pfDB and pfDB["units"] and pfDB["units"]["loc"]) then return end

  -- Build name→npcID reverse index
  local nameToID = {}
  for npcID, name in pairs(pfDB["units"]["loc"]) do
    if type(name) == "string" and name ~= "" then
      nameToID[name] = npcID
    end
  end

  local imported, skipped = 0, 0

  for mobIndex, mobInfo in pairs(MobInfoDB) do
    if mobIndex ~= "DatabaseVersion:0" and type(mobInfo) == "table" and mobInfo.ml then
      -- Parse "Name:Level" — name may contain colons, level is the last segment
      local name = string.match(mobIndex, "^(.+):%d+$")
      local npcID = name and nameToID[name]

      if npcID then
        -- Parse "x1/y1/x2/y2/c/z"
        local x1,y1,x2,y2,c,z = string.match(mobInfo.ml,
          "^(%d+)/(%d+)/(%d+)/(%d+)/(%d+)/(%d+)$")
        x1,y1,x2,y2,z = tonumber(x1),tonumber(y1),tonumber(x2),tonumber(y2),tonumber(z)

        -- z must be a valid classic pfID (1–9999)
        if z and z > 0 and z < 10000 and x1 and y1 then
          local x = (x1 + (x2 or x1)) / 2
          local y = (y1 + (y2 or y1)) / 2

          -- Ensure pfDB entry exists
          if not pfDB["units"]["data"][npcID] then
            pfDB["units"]["data"][npcID] = { ["coords"]={}, ["fac"]="AH", ["lvl"]="??" }
          end

          -- Check for duplicate (within 2-unit tolerance)
          local data = pfDB["units"]["data"][npcID]
          local exists = false
          for _, coord in ipairs(data["coords"]) do
            if coord[3] == z and math.abs(coord[1]-x) < 2 and math.abs(coord[2]-y) < 2 then
              exists = true; break
            end
          end

          if not exists then
            table.insert(data["coords"], { x, y, z, 0 })
            imported = imported + 1

            -- If this mob is a wanted quest objective, link it immediately
            if pfRetailRuntime and pfRetailRuntime.wantedNames then
              local questID = pfRetailRuntime.wantedNames[string.lower(name)]
              if questID and pfDB["quests"]["data"][questID] then
                local qdata = pfDB["quests"]["data"][questID]
                qdata["obj"] = qdata["obj"] or { ["U"] = {} }
                qdata["obj"]["U"] = qdata["obj"]["U"] or {}
                local linked = false
                for _, uid in ipairs(qdata["obj"]["U"]) do
                  if uid == npcID then linked = true; break end
                end
                if not linked then table.insert(qdata["obj"]["U"], npcID) end
              end
            end
          end
        else
          skipped = skipped + 1
        end
      end
    end
  end

  if imported > 0 then
    pfQuest:Debug(string.format(
      "|cffaabbffMobInfo2|r: |cff33ff33%d|r NPC coords imported"
      .. (skipped > 0 and (" (%d skipped — no pfID or no npcID)"):format(skipped) or ""),
      imported))
    if pfMap then pfMap.queue_update = GetTime() end
  end
end

-- Deferred 1s after PLAYER_LOGIN so npcCache and scanQuestLog have already
-- run, meaning pfDB["units"]["loc"] and wantedNames are fully populated.
local mi2Frame = CreateFrame("Frame")
mi2Frame:RegisterEvent("PLAYER_LOGIN")
mi2Frame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  C_Timer.After(1, importMobInfo2)
end)

-- Expose for /db commands and manual triggering
pfMobInfo2Import = importMobInfo2
