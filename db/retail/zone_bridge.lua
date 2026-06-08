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

  -- Battle for Azeroth
  [876] = 10033,  -- Zuldazar
  [862] = 10034,  -- Nazmir
  [863] = 10035,  -- Vol'dun
  [895] = 10036,  -- Tiragarde Sound
  [896] = 10037,  -- Drustvar
  [942] = 10038,  -- Stormsong Valley
  [1462] = 10039, -- Uldum (BfA)
  [1463] = 10040, -- Vale of Eternal Blossoms (BfA)
  [1527] = 10041, -- Nazjatar
  [1530] = 10042, -- Mechagon Island

  -- Shadowlands
  [1525] = 10043, -- Oribos
  [1533] = 10044, -- Bastion
  [1536] = 10045, -- Maldraxxus
  [1565] = 10046, -- Ardenweald
  [1543] = 10047, -- Revendreth
  [1970] = 10048, -- The Maw
  [1960] = 10049, -- Zereth Mortis
  [1961] = 10050, -- Korthia

  -- Dragonflight
  [2022] = 10051, -- The Waking Shores
  [2023] = 10052, -- Ohn'ahran Plains
  [2024] = 10053, -- The Azure Span
  [2025] = 10054, -- Thaldraszus
  [2112] = 10055, -- Zaralek Cavern
  [2133] = 10056, -- Forbidden Reach
  [2200] = 10057, -- Emerald Dream

  -- The War Within (Khaz Algar) — interface 110105
  [2248] = 10058, -- Isle of Dorn
  [2214] = 10059, -- The Ringing Deeps
  [2215] = 10060, -- Hallowfall
  [2255] = 10061, -- Azj-Kahet
  [2241] = 10062, -- Khaz Algar (continent)
  [2256] = 10063, -- The City of Threads
  [2257] = 10064, -- Nerubian Empire
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
  local _zcount = 0
  for _ in pairs(RETAIL_ZONE_MAP) do _zcount = _zcount + 1 end
  pfQuest:Debug('pfQuest-retail-db: zone bridge installed, ' .. tostring(_zcount) .. ' zones registered')
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

-- ---------------------------------------------------------------------------
-- Retail minimap calibration data
-- These are the actual zone dimensions in yards used by the minimap system.
-- Populated on PLAYER_LOGIN from C_Map.GetMapRects() where available,
-- then stored in pfDB["minimap"] so UpdateMinimap() can scale pins correctly.
-- ---------------------------------------------------------------------------
local _calibFrame = CreateFrame("Frame")
_calibFrame:RegisterEvent("PLAYER_LOGIN")
_calibFrame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  pfDB["minimap"] = pfDB["minimap"] or {}

  for uiMapID, pfID in pairs(RETAIL_ZONE_MAP) do
    if not pfDB["minimap"][pfID] then
      -- C_Map.GetWorldPosFromMapPos / GetMapRects both exist in 11.x but
      -- GetMapRects(uiMapID) returns (topLeft, bottomRight) as Vector2DMixin.
      -- Use pcall to safely probe - some zone IDs have no rect data.
      if C_Map and C_Map.GetMapRects then
        local ok, topLeft, bottomRight = pcall(C_Map.GetMapRects, uiMapID)
        if ok and topLeft and bottomRight then
          -- In retail the rect is in map units (0-1). Convert to yards:
          -- typical zone is ~4266 yards wide. Scale by continent size.
          -- For minimap_zoom calibration we need actual yard dimensions.
          -- GetMapRects returns values already in yards for world maps.
          local width  = math.abs((bottomRight.x or 0) - (topLeft.x or 0))
          local height = math.abs((bottomRight.y or 0) - (topLeft.y or 0))
          if width > 100 and height > 100 then
            -- Plausible yard values (not 0-1 normalised)
            pfDB["minimap"][pfID] = { width, height }
          elseif width > 0 and width <= 1 then
            -- Normalised 0-1: scale to typical zone yard size
            pfDB["minimap"][pfID] = { width * 62910, height * 41942 }
          end
        end
      end
      -- Final fallback: use known good defaults if rect unavailable
      if not pfDB["minimap"][pfID] then
        pfDB["minimap"][pfID] = { 4266.7, 2844.4 }
      end
    end
  end
end)

-- Pre-populate zone bridge on PLAYER_LOGIN from C_Map
-- This catches any zones not covered by pfQuest-retail-db
local _loginBridge = CreateFrame("Frame")
_loginBridge:RegisterEvent("PLAYER_LOGIN")
_loginBridge:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if not (C_Map and C_Map.GetBestMapForUnit) then return end

  local function tryRegisterZone(uiMapID)
    if RETAIL_ZONE_MAP[uiMapID] then return end  -- already known
    -- Assign next available pfID
    local maxPF = 10000
    for _, v in pairs(RETAIL_ZONE_MAP) do if v >= maxPF then maxPF = v + 1 end end
    local info = C_Map.GetMapInfo(uiMapID)
    if not info then return end
    RETAIL_ZONE_MAP[uiMapID] = maxPF
    if pfQuest and pfQuest.retailZoneMapReverse then pfQuest.retailZoneMapReverse[maxPF] = uiMapID end
    pfDB["zones"] = pfDB["zones"] or {["data"]={}, ["loc"]={}}
    pfDB["zones"]["loc"] = pfDB["zones"]["loc"] or {}
    pfDB["zones"]["loc"][maxPF] = info.name
    pfDB["zones"]["data"][maxPF] = { 99, 0, 0, 100, 100 }
    pfDB["minimap"] = pfDB["minimap"] or {}
    pfDB["minimap"][maxPF] = { 4266.7, 2844.4 }
  end

  -- Register current zone immediately
  local uid = C_Map.GetBestMapForUnit("player")
  if uid then tryRegisterZone(uid) end

  -- Also register parent zones
  if uid then
    local info = C_Map.GetMapInfo(uid)
    while info and info.parentMapID and info.parentMapID > 0 do
      tryRegisterZone(info.parentMapID)
      info = C_Map.GetMapInfo(info.parentMapID)
    end
  end
end)

-- Also register on ZONE_CHANGED_NEW_AREA before the main map OnEvent runs
local _zoneBridgeFrame = CreateFrame("Frame")
_zoneBridgeFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
_zoneBridgeFrame:RegisterEvent("ZONE_CHANGED")
_zoneBridgeFrame:SetScript("OnEvent", function(self, event)
  if not (C_Map and C_Map.GetBestMapForUnit) then return end
  local uid = C_Map.GetBestMapForUnit("player")
  if uid and not RETAIL_ZONE_MAP[uid] then
    -- Auto-register unknown zone
    local maxPF = 10000
    for _, v in pairs(RETAIL_ZONE_MAP) do if v >= maxPF then maxPF = v + 1 end end
    local info = C_Map.GetMapInfo(uid)
    if info then
      RETAIL_ZONE_MAP[uid] = maxPF
      if pfQuest and pfQuest.retailZoneMapReverse then pfQuest.retailZoneMapReverse[maxPF] = uid end
      pfDB["zones"] = pfDB["zones"] or {["data"]={},["loc"]={}}
      pfDB["zones"]["loc"] = pfDB["zones"]["loc"] or {}
      pfDB["zones"]["loc"][maxPF] = info.name
      pfDB["zones"]["data"][maxPF] = { 99, 0, 0, 100, 100 }
      pfDB["minimap"] = pfDB["minimap"] or {}
      pfDB["minimap"][maxPF] = { 4266.7, 2844.4 }
      if pfDiag then pfDiag.log("AutoZone: " .. info.name .. " uiMapID=" .. uid .. " pfID=" .. maxPF) end
    end
  end
end)

local _PLAYER_LOGIN_BRIDGE = true  -- marker
