-- pfQuest-retail: AllTheThings integration
-- ============================================================
-- If AllTheThings (ATT) is installed, this module reads its
-- completed quest IDs into pfQuest_history on login, so quest
-- givers for already-completed quests are suppressed on the map.
--
-- ATT tracks completions via two APIs:
--   C_QuestLog.GetAllCompletedQuestIDs() — retail 8.0+ indexed array
--   GetQuestsCompleted(tbl)              — legacy, fills tbl in-place
--
-- We also call these APIs directly (regardless of ATT) because they
-- are the correct retail mechanism. ATT's SavedVariables are an
-- additional source for cross-session persistence before the server
-- sends fresh data.
-- ============================================================

local function applyCompletedIDs(ids, source, level, now)
  pfQuest_history = pfQuest_history or {}
  local found = 0
  if type(ids) == "table" then
    -- Indexed array form: {questID, questID, ...}
    if ids[1] then
      for _, questID in ipairs(ids) do
        if not pfQuest_history[questID] then found = found + 1 end
        pfQuest_history[questID] = pfQuest_history[questID] or { now, level }
      end
    else
      -- Hash form: {[questID]=true, ...}
      for questID in pairs(ids) do
        if not pfQuest_history[questID] then found = found + 1 end
        pfQuest_history[questID] = pfQuest_history[questID] or { now, level }
      end
    end
  end
  return found
end

-- ── Source 1: C_QuestLog.GetAllCompletedQuestIDs (retail native) ─────────────
-- Returns an indexed array of every questID the character has ever completed.
-- Synchronous once the player is logged in. This is what ATT primarily uses.
local function queryViaGetAllCompleted(level, now)
  if not (C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs) then return 0 end
  local ids = C_QuestLog.GetAllCompletedQuestIDs()
  if not ids or #ids == 0 then return 0 end
  return applyCompletedIDs(ids, "C_QuestLog.GetAllCompletedQuestIDs", level, now)
end

-- ── Source 2: GetQuestsCompleted (legacy table-fill calling convention) ───────
-- Note: in retail this is called as GetQuestsCompleted(outTable) — the results
-- are written INTO the table passed as argument, not returned. ATT uses this
-- as its fallback when GetAllCompletedQuestIDs is absent (classic clients).
local function queryViaGetQuestsCompleted(level, now)
  if not GetQuestsCompleted then return 0 end
  local out = {}
  -- Try the output-table convention first (retail/live)
  local ok = pcall(GetQuestsCompleted, out)
  if ok and next(out) then
    return applyCompletedIDs(out, "GetQuestsCompleted(table)", level, now)
  end
  -- Fall back to return-value convention (some private server builds)
  local ret = GetQuestsCompleted()
  if type(ret) == "table" and next(ret) then
    return applyCompletedIDs(ret, "GetQuestsCompleted() return", level, now)
  end
  return 0
end

-- ── Source 3: ATT SavedVariables (cross-session, available immediately) ───────
-- ATT stores completed quests in ATTCharacterData[guid].Quests = {[questID]=true}
-- This is available before the server sends fresh data, so it's the fastest
-- source on login. It may be slightly stale (last session) but that's fine —
-- C_QuestLog.GetAllCompletedQuestIDs will overwrite with fresh data shortly.
local function queryViaATT(level, now)
  if not ATTCharacterData then return 0, false end
  local guid = UnitGUID and UnitGUID("player")
  if not guid then return 0, false end

  local charData = ATTCharacterData[guid]
  if not charData then
    -- ATT may store by realm+name instead — try to find the right key
    local name = UnitName("player")
    local realm = GetRealmName and GetRealmName() or ""
    local altKey = name .. "-" .. realm
    charData = ATTCharacterData[altKey]
  end

  if not charData or not charData.Quests then return 0, false end

  local found = applyCompletedIDs(charData.Quests, "ATT SavedVariables", level, now)
  return found, true
end

-- ── Source 4: ATT account-wide quests ────────────────────────────────────────
-- ATT also tracks account-wide one-time quests across all characters.
-- AllTheThingsAD.OneTimeQuests = {[questID]=characterGUID}
local function queryViaATTAccountWide(level, now)
  if not AllTheThingsAD then return 0, false end
  local otq = AllTheThingsAD.OneTimeQuests
  if not otq then return 0, false end
  local found = applyCompletedIDs(otq, "ATT AccountWide", level, now)
  return found, true
end

-- ── Public API ────────────────────────────────────────────────────────────────
pfATTIntegration = pfATTIntegration or {}

function pfATTIntegration:Sync(silent)
  local level = UnitLevel("player") or 0
  local now = time()
  local total = 0
  local sources = {}

  -- Source 1: Native retail API (most authoritative)
  local n1 = queryViaGetAllCompleted(level, now)
  if n1 > 0 then total = total + n1; table.insert(sources, n1 .. " via GetAllCompletedQuestIDs") end

  -- Source 2: Legacy GetQuestsCompleted (covers clients without GetAllCompleted)
  if n1 == 0 then
    local n2 = queryViaGetQuestsCompleted(level, now)
    if n2 > 0 then total = total + n2; table.insert(sources, n2 .. " via GetQuestsCompleted") end
  end

  -- Source 3: ATT character data (instant, may be slightly stale)
  local n3, hasATT = queryViaATT(level, now)
  if n3 > 0 then total = total + n3; table.insert(sources, n3 .. " via ATT char data") end

  -- Source 4: ATT account-wide
  local n4, hasATTAW = queryViaATTAccountWide(level, now)
  if n4 > 0 then total = total + n4; table.insert(sources, n4 .. " via ATT account-wide") end

  if not silent then
    if total > 0 then
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ffccpf|cffffffffQuest: |cff33ff33" .. total ..
        "|r completed quests loaded (" .. table.concat(sources, ", ") .. ").")
    elseif not hasATT then
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ffccpf|cffffffffQuest: No ATT data found — " ..
        "install AllTheThings for better quest completion tracking.")
    else
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ffccpf|cffffffffQuest: ATT found but 0 new quests marked.")
    end
  end

  return total
end

function pfATTIntegration:IsATTLoaded()
  return AllTheThingsDB ~= nil or ATTCharacterData ~= nil
end

-- ── Auto-sync on login ────────────────────────────────────────────────────────
-- Runs at PLAYER_LOGIN after SavedVariables (including ATT's) are available.
-- Two passes:
--   Pass 1 (2s): ATT SavedVars (instant, cross-session)
--   Pass 2 (6s): C_QuestLog.GetAllCompletedQuestIDs (fresh from server)
local attFrame = CreateFrame("Frame")
attFrame:RegisterEvent("PLAYER_LOGIN")
attFrame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()

  -- Pass 1: read ATT SavedVars immediately (available at PLAYER_LOGIN)
  C_Timer.After(1, function()
    local n3, hasATT = queryViaATT(UnitLevel("player") or 0, time())
    local n4 = queryViaATTAccountWide(UnitLevel("player") or 0, time())
    local total = n3 + n4
    if total > 0 then
      pfQuest:Debug("|cff33ff33" .. total .. "|r quests from ATT SavedVars.")
    end
  end)

  -- Pass 2: fresh data from server after game fully loads
  C_Timer.After(6, function()
    local level = UnitLevel("player") or 0
    local now = time()
    local n1 = queryViaGetAllCompleted(level, now)
    if n1 == 0 then
      n1 = queryViaGetQuestsCompleted(level, now)
    end
    if n1 > 0 then
      pfQuest:Debug("|cff33ff33" .. n1 .. "|r quests from C_QuestLog (server).")
    end
  end)
end)

-- ── Hook into /db query command ───────────────────────────────────────────────
-- Replace pfDatabase:QueryServer with one that uses the new sources.
-- We keep the original as a fallback.
local _origQueryServer = pfDatabase and pfDatabase.QueryServer
function pfDatabase:QueryServer()
  local total = pfATTIntegration:Sync(false)
  if total == 0 and _origQueryServer then
    -- Nothing found via ATT/native APIs — run the legacy scanner
    _origQueryServer(self)
  end
end
