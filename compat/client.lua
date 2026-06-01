-- pfQuest compat/client.lua
-- Retail 11.1.5 port — replaces all TBC/WotLK API calls with their modern equivalents.
-- Original by Shagu; retail adaptation adds C_Map, C_QuestLog, C_AddOns layers.

-- GetBuildInfo() 4th return is the full interface string e.g. "110105" in retail.
local _, _, _, clientStr = GetBuildInfo()
local client = tonumber(clientStr) or 110105

pfQuestCompat = {}
pfQuestCompat.client = client

-- math.mod was removed; expose via % wrapper
pfQuestCompat.mod = function(a, b) return a % b end

-- string.gmatch replaces string.gfind (Lua 5.0 only)
pfQuestCompat.gfind = string.gmatch

-- Item suffix: retail uses a 13-field link format
pfQuestCompat.itemsuffix = ":0:0:0:0:0:0:0:0:0:0:0:0:0"

-- Minimap rotation CVar is still present in retail
pfQuestCompat.rotateMinimap = GetCVar("rotateMinimap") ~= "0" and true or nil

-- ---------------------------------------------------------------------------
-- Quest log helpers
-- C_QuestLog fully replaces the old global functions in retail 11.x.
-- We normalise to the 6-return signature that the rest of pfQuest expects:
--   title, level, tag, header, collapsed, complete
-- ---------------------------------------------------------------------------
pfQuestCompat.GetQuestLogTitle = function(id)
  if C_QuestLog and C_QuestLog.GetInfo then
    local info = C_QuestLog.GetInfo(id)
    if not info then return nil end
    local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) and 1 or nil
    return info.title, info.level, nil, info.isHeader, info.isCollapsed, complete
  end
  -- legacy fallback (should never be reached on retail)
  if GetQuestLogTitle then
    local title, level, tag, group, header, collapsed, complete, daily = GetQuestLogTitle(id)
    return title, level, tag, header, collapsed, complete
  end
end

-- ---------------------------------------------------------------------------
-- Number of quest log entries
-- ---------------------------------------------------------------------------
pfQuestCompat.GetNumQuestLogEntries = function()
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
    return C_QuestLog.GetNumQuestLogEntries()
  end
  return GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
end

-- ---------------------------------------------------------------------------
-- Quest objective boards
-- Returns a list of {text, type, finished} tables matching old leaderboard API.
-- ---------------------------------------------------------------------------
pfQuestCompat.GetQuestObjectives = function(qlogid)
  if C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
    local info = C_QuestLog.GetInfo(qlogid)
    if not info then return {} end
    local objs = C_QuestLog.GetQuestObjectives(info.questID) or {}
    -- normalise to {text, type, finished}
    local result = {}
    for _, o in ipairs(objs) do
      result[#result+1] = { o.text, o.type, o.finished }
    end
    return result
  end
  -- legacy fallback
  if GetNumQuestLeaderBoards then
    local result = {}
    local n = GetNumQuestLeaderBoards(qlogid) or 0
    for i = 1, n do
      local text, t, done = GetQuestLogLeaderBoard(i, qlogid)
      result[#result+1] = { text, t, done }
    end
    return result
  end
  return {}
end

-- Convenience: number of objectives for a quest log index
pfQuestCompat.GetNumQuestLeaderBoards = function(qlogid)
  return #pfQuestCompat.GetQuestObjectives(qlogid)
end

-- ---------------------------------------------------------------------------
-- Difficulty colouring
-- ---------------------------------------------------------------------------
pfQuestCompat.GetDifficultyColor = GetQuestDifficultyColor
  or (C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer)
  or GetDifficultyColor
  or function() return { r=1, g=1, b=1 } end

-- ---------------------------------------------------------------------------
-- Watch frame: ObjectiveTrackerFrame in retail
-- ---------------------------------------------------------------------------
pfQuestCompat.QuestWatchFrame = QuestWatchFrame or ObjectiveTrackerFrame or WatchFrame

-- ---------------------------------------------------------------------------
-- Quest log UI frame names (renamed in WotLK; mostly absent in retail)
-- ---------------------------------------------------------------------------
pfQuestCompat.QuestLogQuestTitle      = QuestLogQuestTitle      or QuestInfoTitleHeader
pfQuestCompat.QuestLogObjectivesText  = QuestLogObjectivesText  or QuestInfoObjectivesText
pfQuestCompat.QuestLogQuestDescription= QuestLogQuestDescription or QuestInfoDescriptionText
pfQuestCompat.QuestLogDescriptionTitle= QuestLogDescriptionTitle or QuestInfoDescriptionHeader

-- ---------------------------------------------------------------------------
-- Chat edit box insert
-- ChatFrameEditBox was removed; use ChatEdit_GetActiveWindow() in retail.
-- ---------------------------------------------------------------------------
pfQuestCompat.InsertQuestLink = function(questid, name)
  local questid  = questid or 0
  local fallback = name or UNKNOWN
  local level    = pfDB["quests"]["data"][questid] and pfDB["quests"]["data"][questid]["lvl"] or 0
  local qname    = pfDB["quests"]["loc"][questid]  and pfDB["quests"]["loc"][questid]["T"]   or fallback
  local dc       = pfQuestCompat.GetDifficultyColor(level)
  local hex      = string.format("|cff%02x%02x%02x", (dc.r or 1)*255, (dc.g or 1)*255, (dc.b or 1)*255)

  local editbox = (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
               or (ChatFrameEditBox and ChatFrameEditBox:IsShown() and ChatFrameEditBox)
  if editbox then
    editbox:Show()
    if pfQuest_config["questlinks"] == "1" then
      editbox:Insert(hex .. "|Hquest:" .. questid .. ":" .. level .. "|h[" .. qname .. "]|h|r")
    else
      editbox:Insert("[" .. qname .. "]")
    end
  end
end

-- ---------------------------------------------------------------------------
-- Minimap arrow / player facing
-- In retail the compass ring / arrow model is no longer a bare unnamed child.
-- GetPlayerFacing() is still present and works correctly in retail.
-- ---------------------------------------------------------------------------
pfQuestCompat.GetPlayerFacing = GetPlayerFacing or function()
  if pfQuestCompat.rotateMinimap and MiniMapCompassRing and MiniMapCompassRing.GetFacing then
    return (MiniMapCompassRing:GetFacing() * -1)
  end
  return 0
end

-- Elevate the minimap arrow frame above pfQuest pins.
-- Deferred to PLAYER_LOGIN so all frames are guaranteed to exist.
local function ElevateMinimapArrow()
  -- retail: named frames come first
  local arrow = _G["MinimapArrow"] or _G["PlayerArrowEffectFrame"]
  if arrow and arrow.SetFrameLevel then
    arrow:SetFrameLevel(8)
    return
  end
  -- legacy scan for unnamed Model child
  for _, v in ipairs({Minimap:GetChildren()}) do
    if v.IsObjectType and v:IsObjectType("Model") and not v:GetName() then
      local mdl = v:GetModel() or ""
      if string.find(mdl:lower(), "interface\\minimap\\minimaparrow") then
        v:SetFrameLevel(8)
        return
      end
    end
  end
end

local _arrowFrame = CreateFrame("Frame")
_arrowFrame:RegisterEvent("PLAYER_LOGIN")
_arrowFrame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  ElevateMinimapArrow()
end)

-- ---------------------------------------------------------------------------
-- pfUI colour helper shim
-- pfUI.api.rgbhex may not be available without the real pfUI. Provide a
-- lightweight version so InsertQuestLink and other callers work standalone.
-- ---------------------------------------------------------------------------
if not (pfUI and pfUI.api and pfUI.api.rgbhex) then
  pfUI = pfUI or { api = {} }
  pfUI.api = pfUI.api or {}
  pfUI.api.rgbhex = pfUI.api.rgbhex or function(r, g, b, a)
    if type(r) == "table" then
      local t = r
      r, g, b, a = t.r or t[1], t.g or t[2], t.b or t[3], t.a or t[4] or 1
    end
    a = a or 1
    return string.format("|c%02x%02x%02x%02x", a*255, (r or 1)*255, (g or 1)*255, (b or 1)*255)
  end
end

-- ---------------------------------------------------------------------------
-- Quest watch API
-- IsQuestWatched/AddQuestWatch/RemoveQuestWatch moved to C_QuestLog in retail.
-- These shims accept a qlogid (log index) and convert to questID internally.
-- ---------------------------------------------------------------------------
local function _qlogidToQuestID(qlogid)
  if C_QuestLog and C_QuestLog.GetInfo then
    local info = C_QuestLog.GetInfo(qlogid)
    return info and info.questID
  end
end

pfQuestCompat.IsQuestWatched = function(qlogid)
  if C_QuestLog and C_QuestLog.IsQuestWatched then
    local questID = _qlogidToQuestID(qlogid)
    return questID and C_QuestLog.IsQuestWatched(questID) or false
  end
  return IsQuestWatched and IsQuestWatched(qlogid) or false
end

pfQuestCompat.AddQuestWatch = function(qlogid)
  if C_QuestLog and C_QuestLog.AddQuestWatch then
    local questID = _qlogidToQuestID(qlogid)
    if questID then C_QuestLog.AddQuestWatch(questID) end
    return
  end
  if AddQuestWatch then AddQuestWatch(qlogid) end
end

pfQuestCompat.RemoveQuestWatch = function(qlogid)
  if C_QuestLog and C_QuestLog.RemoveQuestWatch then
    local questID = _qlogidToQuestID(qlogid)
    if questID then C_QuestLog.RemoveQuestWatch(questID) end
    return
  end
  if RemoveQuestWatch then RemoveQuestWatch(qlogid) end
end

-- ---------------------------------------------------------------------------
-- GetItemInfo retail shim
-- In retail 11.x GetItemInfo() was replaced by C_Item.GetItemInfo() which
-- returns a table: { itemName, itemLink, itemQuality, itemLevel, ... }
-- We provide a compat wrapper that always returns the old positional values.
-- ---------------------------------------------------------------------------
pfQuestCompat.GetItemInfo = function(itemID)
  if not itemID then return nil end
  if C_Item and C_Item.GetItemInfo then
    local info = C_Item.GetItemInfo(itemID)
    if not info then return nil end
    return info.itemName,    -- 1: name
           info.itemLink,    -- 2: link
           info.itemQuality, -- 3: quality
           info.itemLevel,   -- 4: level
           info.itemMinLevel,-- 5: minLevel
           info.itemType,    -- 6: type
           info.itemSubType, -- 7: subType
           info.itemStackCount, -- 8: stackCount
           info.itemEquipLoc,   -- 9: equipLoc
           info.itemTexture,    -- 10: texture
           info.sellPrice,      -- 11: sellPrice
           info.classID,        -- 12: classID
           info.subclassID,     -- 13: subclassID
           info.bindType,       -- 14: bindType
           info.expacID,        -- 15: expacID
           info.setID,          -- 16: setID
           info.isCraftingReagent -- 17: isCraftingReagent
  end
  -- legacy fallback
  return GetItemInfo and GetItemInfo(itemID)
end

-- Note: The bit library (bit.band, bit.bor, etc.) is a WoW global present on
-- ALL clients including retail 11.x. WoW uses Lua 5.1 internally on all versions
-- so native Lua 5.3+ bitwise operators (&, |, ~) are NOT valid syntax here.
-- No shim needed - bit.band etc. work as-is.

C_Timer.After(0, function() if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[diag] client.lua loaded|r") end end)
