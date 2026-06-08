-- This file can be used to manually overwrite or add contents to the db
-- which weren't detected by the extractor. Make sure to write proper comments
-- and include as much information as possible, as this should be only the
-- intermediate solution and fixing the extractor instead is the desired goal.
--
-- IMPORTANT: Overwrites run at file-load time, before PLAYER_LOGIN.
-- db_guard wipes pfDB["quests"] at PLAYER_LOGIN, which destroys any overwrites
-- written directly into the static tables. For overwrites to survive:
--   - Classic-quest overwrites are preserved by db_guard IF the quest is in
--     the player's active log (see db_guard.lua preserveQuests logic).
--   - For all other cases, re-apply overwrites after PLAYER_LOGIN via the
--     hook below, which fires after db_guard and runtime_db have run.

local function applyOverwrites()
  -- [[ Quest: Great Bear Spirit ]]
  -- Unit: Great Bear Spirit (11956)
  -- Type: Talk/Gossip Menu Requirement
  -- Quests 5929/5930 require talking to this spirit NPC as an objective,
  -- but the extractor missed the link. Applied here so the NPC shows as a
  -- quest objective pin when the player has these quests active.
  if pfDB["quests"]["data"][5929] then
    pfDB["quests"]["data"][5929]["obj"] = pfDB["quests"]["data"][5929]["obj"] or {}
    pfDB["quests"]["data"][5929]["obj"]["U"] = { 11956 }
  end
  if pfDB["quests"]["data"][5930] then
    pfDB["quests"]["data"][5930]["obj"] = pfDB["quests"]["data"][5930]["obj"] or {}
    pfDB["quests"]["data"][5930]["obj"]["U"] = { 11956 }
  end
end

-- Apply at load time (captures classic DB overwrites before db_guard wipe)
applyOverwrites()

-- Re-apply after PLAYER_LOGIN so overwrites survive the db_guard wipe.
-- C_Timer.After(0) fires after all PLAYER_LOGIN handlers, so db_guard and
-- runtime_db have both completed by the time this runs.
local _owFrame = CreateFrame("Frame")
_owFrame:RegisterEvent("PLAYER_LOGIN")
_owFrame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  C_Timer.After(0, applyOverwrites)
end)
