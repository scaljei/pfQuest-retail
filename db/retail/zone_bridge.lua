-- pfQuest-retail: zone bridge
-- Hooks pfMap:GetCurrentMapID() and pfMap:GetMapIDByName() to resolve
-- Blizzard uiMapIDs (retail C_Map) to pfQuest internal zone IDs.
-- When pfQuest-retail-db is installed, it calls InstallRetailZoneBridge()
-- with a full zone table. Otherwise a minimal built-in table is used.

-- ── Built-in minimal table (classic zones that overlap with retail content) ──
local BUILTIN_ZONES = {
  [22] = 10000,  -- The Barrens
  [37] = 10001,  -- Dustwallow Marsh
  [78] = 10002,  -- Feralas
  [84] = 10003,  -- Eversong Woods
  [85] = 10004,  -- Ghostlands
  [88] = 10005,  -- Azshara
  [210] = 10006,  -- Dalaran
  [626] = 10007,  -- Azsuna
  [627] = 10008,  -- Val'sharah
  [628] = 10009,  -- Highmountain
  [629] = 10010,  -- Stormheim
  [630] = 10011,  -- Suramar
  [631] = 10012,  -- The Broken Shore
  [634] = 10013,  -- Vault of the Wardens
  [636] = 10014,  -- Black Rook Hold
  [641] = 10015,  -- Darkheart Thicket
  [642] = 10016,  -- The Arcway
  [643] = 10017,  -- Cathedral of Eternal Night
  [649] = 10018,  -- Neltharion's Lair
  [650] = 10019,  -- The Seat of the Triumvirate
  [651] = 10020,  -- Halls of Valor
  [652] = 10021,  -- Court of Stars
  [653] = 10022,  -- The Nighthold
  [657] = 10023,  -- The Emerald Nightmare
  [659] = 10024,  -- Trial of Valor
  [680] = 10025,  -- Antorus the Burning Throne
  [684] = 10026,  -- Tomb of Sargeras
  [688] = 10027,  -- Krokuun
  [697] = 10028,  -- Antoran Wastes
  [717] = 10029,  -- Mac'Aree
  [747] = 10030,  -- The Broken Shore
  [750] = 10031,  -- Broken Isles
  [775] = 10032,  -- The Fel Hammer
}

-- ── Active zone table (replaced by db addon if installed) ───────────────
local RETAIL_ZONE_MAP = {}
for k, v in pairs(BUILTIN_ZONES) do RETAIL_ZONE_MAP[k] = v end

-- ── pfMap integration API ────────────────────────────────────────────────
-- Called by pfQuest-retail-db loader once its data is ready
function pfMap:InstallRetailZoneBridge(zoneTable)
  for uid, pfid in pairs(zoneTable) do
    RETAIL_ZONE_MAP[uid] = pfid
  end
  pfQuest:Debug('pfQuest-retail-db: zone bridge installed, ' ..
    tostring(#(function() local n=0 for _ in pairs(RETAIL_ZONE_MAP) do n=n+1 end return n end)()) ..
    ' zones registered')
end

-- ── Hook pfMap:GetCurrentMapID() ─────────────────────────────────────────
local _orig_GetCurrentMapID = pfMap.GetCurrentMapID
pfMap.GetCurrentMapID = function(self)
  if C_Map and C_Map.GetBestMapForUnit then
    local uiMapID = C_Map.GetBestMapForUnit('player')
    if uiMapID then
      local pfID = RETAIL_ZONE_MAP[uiMapID]
      if pfID then return pfID end
      -- Walk up the hierarchy
      local info = C_Map.GetMapInfo(uiMapID)
      while info and info.parentMapID and info.parentMapID > 0 do
        pfID = RETAIL_ZONE_MAP[info.parentMapID]
        if pfID then return pfID end
        info = C_Map.GetMapInfo(info.parentMapID)
      end
    end
  end
  return _orig_GetCurrentMapID(self)
end

-- ── Hook pfMap:GetMapIDByName() ──────────────────────────────────────────
local _orig_GetMapIDByName = pfMap.GetMapIDByName
pfMap.GetMapIDByName = function(self, name)
  if name then
    for pfID, _ in pairs(RETAIL_ZONE_MAP) do
      if pfDB['zones']['loc'][pfID] == name then return pfID end
    end
    if C_Map and C_Map.GetMapInfo then
      for uiMapID, pfID in pairs(RETAIL_ZONE_MAP) do
        local info = C_Map.GetMapInfo(uiMapID)
        if info and info.name == name then return pfID end
      end
    end
  end
  return _orig_GetMapIDByName(self, name)
end

-- ── Runtime discovery on login ───────────────────────────────────────────
-- Walks C_Map hierarchy to auto-register zones not in either table.
local _bridgeFrame = CreateFrame('Frame')
_bridgeFrame:RegisterEvent('PLAYER_LOGIN')
_bridgeFrame:SetScript('OnEvent', function(self)
  self:UnregisterAllEvents()
  if not (C_Map and C_Map.GetMapChildrenInfo) then return end
  local function walk(parentID)
    for _, info in ipairs(C_Map.GetMapChildrenInfo(parentID, nil, true) or {}) do
      if not RETAIL_ZONE_MAP[info.mapID] then
        local pfID = _orig_GetMapIDByName(pfMap, info.name)
        if pfID then RETAIL_ZONE_MAP[info.mapID] = pfID end
      end
    end
  end
  -- Scan key zone roots only
  for _, root in ipairs({946,1525,2022,2248}) do walk(root) end
end)

-- Expose for pfQuest-retail-db
pfQuest = pfQuest or {}
pfQuest.OnRetailDBLoaded = pfQuest.OnRetailDBLoaded or function(self)
  -- Called when pfQuest-retail-db finishes loading
  -- pfRetailDB.uiMapToPF is already populated at this point
  if pfRetailDB and pfRetailDB.uiMapToPF then
    pfMap:InstallRetailZoneBridge(pfRetailDB.uiMapToPF)
  end
  pfMap.queue_update = GetTime()
end
