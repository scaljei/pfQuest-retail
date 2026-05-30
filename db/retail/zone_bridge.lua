-- pfQuest retail zone bridge
-- Builds a live uiMapID <-> pfQuest zone ID mapping at runtime using C_Map,
-- so that pfMap:GetCurrentMapID() and pfMap:GetMapIDByName() work for all
-- retail zones even if the zone name in pfDB doesn't exactly match the
-- Blizzard localised name.

-- ── Static mapping: Blizzard uiMapID → pfQuest internal zone ID ─────────────
-- IDs 10000+ are retail zones added by the retail db converter.
local RETAIL_ZONE_MAP = {
  [210] = 10000,  -- Dalaran (Northrend)
  [217] = 10001,  -- Ulduar
  [629] = 10002,  -- The Jade Forest
  [862] = 10003,  -- Highmountain
  [863] = 10004,  -- Val\'sharah
  [882] = 10005,  -- Azsuna
  [896] = 10006,  -- Stormheim
  [942] = 10007,  -- Suramar
  [971] = 10008,  -- Broken Shore
  [1186] = 10009,  -- Argus
  [1360] = 10010,  -- Tiragarde Sound
  [1525] = 10011,  -- Oribos
  [1533] = 10012,  -- Bastion
  [1536] = 10013,  -- Maldraxxus
  [1543] = 10014,  -- Ardenweald
  [1550] = 10015,  -- Revendreth
  [1565] = 10016,  -- The Maw
  [1648] = 10017,  -- Korthia
  [1652] = 10018,  -- Zereth Mortis
  [1662] = 10019,  -- Torghast
  [1670] = 10020,  -- The Adamant Vaults
  [1671] = 10021,  -- The Upper Reaches
  [1672] = 10022,  -- Skoldus Hall
  [1673] = 10023,  -- Soulforges
  [1698] = 10024,  -- Coldheart Interstitia
  [1699] = 10025,  -- Mort\'regar
  [1700] = 10026,  -- The Necrotic Wake
  [1701] = 10027,  -- De Other Side
  [1702] = 10028,  -- Halls of Atonement
  [1703] = 10029,  -- Plaguefall
  [1707] = 10030,  -- Sanguine Depths
  [1708] = 10031,  -- Spires of Ascension
  [1912] = 10032,  -- Theater of Pain
  [1961] = 10033,  -- Sanctum of Domination
  [1970] = 10034,  -- Sepulcher of the First Ones
  [1971] = 10035,  -- Tazavesh the Veiled Market
  [2018] = 10036,  -- Karazhan
  [2022] = 10037,  -- The Waking Shores
  [2023] = 10038,  -- Ohn\'ahran Plains
  [2024] = 10039,  -- The Azure Span
  [2025] = 10040,  -- Thaldraszus
  [2027] = 10041,  -- Siege of Orgrimmar
  [2028] = 10042,  -- Antorus the Burning Throne
  [2031] = 10043,  -- Court of Stars
  [2042] = 10044,  -- Mists of Tirna Scithe
  [2070] = 10045,  -- Vault of the Incarnates
  [2085] = 10046,  -- The Forbidden Reach
  [2089] = 10047,  -- Zaralek Cavern
  [2090] = 10048,  -- The Emerald Dream
  [2092] = 10049,  -- Amirdrassil the Dream\'s Hope
  [2109] = 10050,  -- The Forbidden Reach (Instance)
  [2112] = 10051,  -- Aberrus the Shadowed Crucible
  [2118] = 10052,  -- Eon\'s Fringe
  [2133] = 10053,  -- Dawn of the Infinite
  [2151] = 10054,  -- Algeth\'ar Academy
  [2171] = 10055,  -- The Azure Vault
  [2174] = 10056,  -- Brackenhide Hollow
  [2184] = 10057,  -- Ruby Life Pools
  [2200] = 10058,  -- Uldaman Legacy of Tyr
  [2213] = 10059,  -- Neltharus
  [2214] = 10060,  -- The Nokhud Offensive
  [2215] = 10061,  -- Halls of Infusion
  [2216] = 10062,  -- Vault of the Incarnates (Entry)
  [2239] = 10063,  -- The Seat of the Aspects
  [2248] = 10064,  -- Khaz Algar
  [2255] = 10065,  -- Isle of Dorn
  [2256] = 10066,  -- The Ringing Deeps
  [2274] = 10067,  -- Hallowfall
  [2305] = 10068,  -- Azj-Kahet
  [2307] = 10069,  -- City of Threads
  [2321] = 10070,  -- Nerub-ar Palace
  [2339] = 10071,  -- Cinderbrew Meadery
  [2346] = 10072,  -- The Stonevault
  [2367] = 10073,  -- Priory of the Sacred Flame
  [2369] = 10074,  -- The Rookery
  [2371] = 10075,  -- Operation Floodgate
  [2372] = 10076,  -- Ara-Kara City of Echoes
  [2375] = 10077,  -- Darkflame Cleft
  [2381] = 10078,  -- The Dawnbreaker
  [2418] = 10079,  -- Undermine
  [2472] = 10080,  -- Liberation of Undermine
  [2477] = 10081,  -- K\'aresh
}

-- ── Reverse map: pfQuest ID → uiMapID ───────────────────────────────────────
local PF_TO_UI = {}
for uiMapID, pfID in pairs(RETAIL_ZONE_MAP) do
  PF_TO_UI[pfID] = uiMapID
end

-- ── Register with pfMap ──────────────────────────────────────────────────────
-- Override GetCurrentMapID to check retail zones first
local _pfMap_GetCurrentMapID_orig = pfMap.GetCurrentMapID
pfMap.GetCurrentMapID = function(self)
  -- Try C_Map first (retail path)
  if C_Map and C_Map.GetBestMapForUnit then
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if uiMapID then
      -- Direct lookup in our static map
      local pfID = RETAIL_ZONE_MAP[uiMapID]
      if pfID then return pfID end
      -- Walk up the map hierarchy to find a matching parent zone
      local info = C_Map.GetMapInfo(uiMapID)
      while info and info.parentMapID and info.parentMapID > 0 do
        pfID = RETAIL_ZONE_MAP[info.parentMapID]
        if pfID then return pfID end
        info = C_Map.GetMapInfo(info.parentMapID)
      end
    end
  end
  -- Fall back to original (classic/TBC/WotLK path)
  return _pfMap_GetCurrentMapID_orig(self)
end

-- ── Override GetMapIDByName to also match retail zone names ─────────────────
local _pfMap_GetMapIDByName_orig = pfMap.GetMapIDByName
pfMap.GetMapIDByName = function(self, name)
  if not name then return _pfMap_GetMapIDByName_orig(self, name) end
  -- Check retail zone names first
  for pfID, zoneName in pairs(pfDB["zones"]["data-retail"] and {} or {}) do end
  for uiMapID, pfID in pairs(RETAIL_ZONE_MAP) do
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMapID)
    if info and info.name == name then return pfID end
    -- Also check our static name table
    if pfDB["zones"]["loc"][pfID] == name then return pfID end
  end
  return _pfMap_GetMapIDByName_orig(self, name)
end

-- ── Runtime discovery: register any zones C_Map knows but we don't ──────────
-- Runs once on PLAYER_LOGIN, walks all map children and fills gaps.
local _bridgeFrame = CreateFrame("Frame")
_bridgeFrame:RegisterEvent("PLAYER_LOGIN")
_bridgeFrame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if not (C_Map and C_Map.GetMapChildrenInfo) then return end

  -- Walk the entire map tree from the Azeroth root (946)
  local function walkMaps(parentID)
    local children = C_Map.GetMapChildrenInfo(parentID, nil, true) or {}
    for _, info in ipairs(children) do
      if not RETAIL_ZONE_MAP[info.mapID] then
        -- Check if we can match by name to an existing pfQuest zone
        local pfID = pfMap:GetMapIDByName(info.name)
        if pfID then
          RETAIL_ZONE_MAP[info.mapID] = pfID
          PF_TO_UI[pfID] = info.mapID
        end
      end
      walkMaps(info.mapID)
    end
  end

  -- Only walk retail expansion roots (avoid scanning 10000 classic zones)
  local retail_roots = { 946, 1550, 1525, 2022, 2023, 2024, 2025, 2248, 2255, 2256, 2274, 2305 }
  for _, root in ipairs(retail_roots) do
    walkMaps(root)
  end
end)

-- ── Expose the map for use by other modules ──────────────────────────────────
pfQuest = pfQuest or {}
pfQuest.retailZoneMap = RETAIL_ZONE_MAP
pfQuest.retailZoneMapReverse = PF_TO_UI
