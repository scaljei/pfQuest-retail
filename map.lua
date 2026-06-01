-- multi api compat
local compat = pfQuestCompat

-- fake the pfQuest minimap node names to Gatherer names,
-- if any minimap-breaking addon collector is found.
local nodename = "pfMiniMapPin"
local minimapbreakers = {
  ["ElvUI_MinimapButtons"] = true,
  ["MBB"] = true,
}

local compatnamefake = CreateFrame("Frame")
compatnamefake:RegisterEvent("PLAYER_ENTERING_WORLD")
compatnamefake:SetScript("OnEvent", function(self)
  -- only run once on login (retail: use self, not implicit self)
  self:UnregisterAllEvents()

  -- C_AddOns replaces GetNumAddOns/GetAddOnInfo in retail 11.x
  local numAddOns = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns())
                 or (GetNumAddOns and GetNumAddOns()) or 0
  local getInfo   = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo

  for i = 1, numAddOns do
    local name, _, _, loadable = getInfo(i)
    if loadable and minimapbreakers[name] then
      nodename = "GatherNoteCompatFake"
    end
  end
end)

-- checking for control key is very time expensive in 1.12
-- self loop puts it into one place and only updates it every .2 seconds
-- it also only updates the key if the mouse is over a relevant frame
local controlkey = CreateFrame("Frame", "pfQuestControlKey", UIParent)
controlkey:SetScript("OnUpdate", function(self)
  if ( self.throttle or .2) > GetTime() then return else self.throttle = GetTime() + .2 end
  -- pfMap may not be initialised yet on the very first tick; guard against nil
  if WorldMapFrame:IsShown() and MouseIsOver(WorldMapFrame)
    or (pfMap and pfMap.drawlayer and MouseIsOver(pfMap.drawlayer)) then
    controlkey.pressed = IsControlKeyDown()
  end
end)

local validmaps = setmetatable({},{__mode="kv"})
local rgbcache = setmetatable({},{__mode="kv"})
-- minimap_sizes: use a live accessor so retail zones added later by pfQuest-retail-db
-- are always visible. The local was captured before the db addon could inject entries.
local function get_minimap_sizes() return pfDB["minimap"] end

-- minimap_zoom[indoor][zoomLevel] = yards visible across minimap diameter
-- indoor: 0 = inside, 1 = outside
-- zoomLevel: 0-5 (matches minimapZoom CVar range)
-- In retail Minimap:GetZoom() was removed; zoom is read from GetCVar("minimapZoom")
local minimap_zoom_raw = {
  [0] = { [0] = 300,
          [1] = 240,
          [2] = 180,
          [3] = 120,
          [4] = 80,
          [5] = 50,
         },

  [1] = { [0] = 466 + 2/3,
          [1] = 400,
          [2] = 333 + 1/3,
          [3] = 266 + 2/6,
          [4] = 200,
          [5] = 133 + 1/3,
        },
}
-- Wrap with a metatable so out-of-range zoom values don't return nil
local minimap_zoom = setmetatable(minimap_zoom_raw, {
  __index = function(t, k)
    return minimap_zoom_raw[k] or minimap_zoom_raw[1]
  end
})
setmetatable(minimap_zoom_raw[0], {__index = function(t,k) return 300 end})
setmetatable(minimap_zoom_raw[1], {__index = function(t,k) return 466 end})

local unifiedcache = {}

-- used to store/cache combined meta data across nodes of
-- the same kind to avoid duplicating data for each pin
-- the objects here get directly attached to the pfMap nodes
local similar_nodes = {}

local function IsEmpty(tabl)
  for k,v in pairs(tabl) do
    return false
  end
  return true
end

local layers = {
  -- regular icons
  [pfQuestConfig.path.."\\img\\available"]          = 1,
  [pfQuestConfig.path.."\\img\\available_c"]        = 2,
  [pfQuestConfig.path.."\\img\\complete"]           = 3,
  [pfQuestConfig.path.."\\img\\complete_c"]         = 4,
  [pfQuestConfig.path.."\\img\\icon_vendor"]        = 5,
  [pfQuestConfig.path.."\\img\\fav"]                = 6,

  -- cluster textures
  [pfQuestConfig.path.."\\img\\cluster_item"]       = 9,
  [pfQuestConfig.path.."\\img\\cluster_mob"]        = 9,
  [pfQuestConfig.path.."\\img\\cluster_misc"]       = 9,
  [pfQuestConfig.path.."\\img\\cluster_mob_mono"]   = 9,
  [pfQuestConfig.path.."\\img\\cluster_item_mono"]  = 9,
  [pfQuestConfig.path.."\\img\\cluster_misc_mono"]  = 9,
}

local function GetLayerByTexture(tex)
  if layers[tex] then return layers[tex] else return 1 end
end

local function minimap_indoor()
  -- retail 11.x: IsIndoors() is the correct replacement for the CVar trick.
  -- Minimap:GetZoom() / SetZoom() were also removed in retail 10.0.
  if IsIndoors then
    return IsIndoors() and 0 or 1
  end
  -- Legacy path (classic/TBC/WotLK): detect via CVar trick.
  -- These CVars and Minimap:GetZoom() only exist on legacy clients.
  if not Minimap.GetZoom then return 1 end
  local tempzoom = 0
  local state = 1
  if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
    if GetCVar("minimapInsideZoom")+0 >= 3 then
      pfMap.drawlayer:SetZoom(pfMap.drawlayer:GetZoom() - 1)
      tempzoom = 1
    else
      pfMap.drawlayer:SetZoom(pfMap.drawlayer:GetZoom() + 1)
      tempzoom = -1
    end
  end
  if GetCVar("minimapInsideZoom")+0 == pfMap.drawlayer:GetZoom() then
    state = 0
  end
  pfMap.drawlayer:SetZoom(pfMap.drawlayer:GetZoom() + tempzoom)
  return state
end

local function str2rgb(text)
  if not text then return 1, 1, 1 end
  if pfQuest_colors[text] then return unpack(pfQuest_colors[text]) end
  if rgbcache[text] then return unpack(rgbcache[text]) end
  local counter = 1
  local l = string.len(text)
  for i = 1, l, 3 do
    counter = compat.mod(counter*8161, 4294967279) +
        (string.byte(text,i)*16776193) +
        ((string.byte(text,i+1) or (l-i+256))*8372226) +
        ((string.byte(text,i+2) or (l-i+256))*3932164)
  end
  local hash = compat.mod(compat.mod(counter, 4294967291),16777216)
  local r = (hash - (compat.mod(hash,65536))) / 65536
  local g = ((hash - r*65536) - ( compat.mod((hash - r*65536),256)) ) / 256
  local b = hash - r*65536 - g*256
  rgbcache[text] = { r / 255, g / 255, b / 255 }
  return unpack(rgbcache[text])
end

local fpsmod, step
local function NodeAnimate(self, zoom, alpha, fps)
  local cur_zoom = self:GetWidth()
  local cur_alpha = self:GetAlpha()
  local change = nil
  self:EnableMouse(true)
  fpsmod = math.min(2/fps, 2)
  step = fpsmod/10

  -- update size
  if math.abs(cur_zoom - zoom) < 3 then
    self:SetWidth(zoom)
    self:SetHeight(zoom)
  elseif cur_zoom < zoom then
    self:SetWidth(cur_zoom + fpsmod)
    self:SetHeight(cur_zoom + fpsmod)
    change = true
  elseif cur_zoom > zoom then
    self:SetWidth(cur_zoom - fpsmod)
    self:SetHeight(cur_zoom - fpsmod)
    change = true
  end

  -- update alpha
  if math.abs(cur_alpha - alpha) < step then
    self:SetAlpha(alpha)

    -- disable mouse on hidden
    if alpha < .1 then
      self:EnableMouse(nil)
    end
  elseif cur_alpha < alpha then
    self:SetAlpha(cur_alpha + step)
    change = true
  elseif cur_alpha > alpha then
    self:SetAlpha(cur_alpha - step)
    change = true
  end

  return change
end

-- put player position above everything on worldmap
for k, v in pairs({WorldMapFrame:GetChildren()}) do
  if v:IsObjectType("Model") and not v:GetName() then
    if string.find(string.lower(v:GetModel()), "interface\\minimap\\minimaparrow") then
      v:SetFrameLevel(255)
      break
    end
  end
end

pfMap = CreateFrame("Frame", "pfQuestMap", WorldFrame)
pfMap.str2rgb = str2rgb
pfMap.tooltips = {}
pfMap.nodes = {}
pfMap.pins = {}
pfMap.mpins = {}
pfMap.drawlayer = Minimap
pfMap.unifiedcache = unifiedcache

pfMap.minimap_indoor = minimap_indoor
pfMap.minimap_zoom = minimap_zoom
pfMap.minimap_sizes = get_minimap_sizes  -- function, not table; call to get live data

pfMap.tooltip = CreateFrame("Frame" , "pfMapTooltip", GameTooltip)
pfMap.tooltip:SetScript("OnShow", function(self)
  -- GetMouseFocus removed in retail 10.2; GetMouseFoci returns a list
  local focus = (GetMouseFoci and GetMouseFoci()) or (GetMouseFocus and GetMouseFocus())
  -- abort on pfQuest nodes
  if focus and focus.title then return end
  -- abort on quest timers
  if focus and focus.GetName and string.sub((focus:GetName() or ""),1,10) == "QuestTimer" then return end
  -- abort if tooltips are disabled
  if pfQuest_config.showtooltips == "0" then return end

  local name = _G["GameTooltipTextLeft1"] and _G["GameTooltipTextLeft1"]:GetText() or "__NONE__"
  local zone = pfMap:GetCurrentMapID()

  -- remove all colors from received tooltip text
  name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
  name = string.gsub(name, "|r", "")

  if pfMap.tooltips[name] and pfMap.tooltips[name] then
    for title, obj in pairs(pfMap.tooltips[name]) do
      if obj[zone] then
        pfMap:ShowTooltip(obj[zone], GameTooltip)
        GameTooltip:Show()
      end
    end
  end
end)

-- dummy function that can be used by extensions
-- to avoid drawing the minimap at some locations
function pfMap:HasMinimap()
  return true
end

function pfMap.tooltip:GetColor(min, max)
  local max = max or 1
  local min = min or max or 1

  local perc = min / max
  local r1, g1, b1, r2, g2, b2
  if perc <= 0.5 then
    perc = perc * 2
    r1, g1, b1 = 1, 0, 0
    r2, g2, b2 = 1, 1, 0
  else
    perc = perc * 2 - 1
    r1, g1, b1 = 1, 1, 0
    r2, g2, b2 = 0, 1, 0
  end
  r = r1 + (r2 - r1)*perc
  g = g1 + (g2 - g1)*perc
  b = b1 + (b2 - b1)*perc

  return r, g, b
end

function pfMap:HexDifficultyColor(level, force)
  if force and UnitLevel("player") < level then
    return "|cffff5555"
  else
    local c = pfQuestCompat.GetDifficultyColor(level)
    return string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
  end
end

function pfMap:ShowTooltip(meta, tooltip)
  local catch = nil
  local catch_obj = nil
  local tooltip = tooltip or GameTooltip

  -- add quest data
  if meta["quest"] then
    -- scan all quest entries for matches
    local _numEntries = compat.GetNumQuestLogEntries()
    for qid=1, _numEntries do
      local qtitle, _, _, _, _, complete = compat.GetQuestLogTitle(qid)

      if meta["quest"] == qtitle then
        -- handle active quests
        local _objs = compat.GetQuestObjectives(qid)
        local objectives = #_objs
        catch = true

        local symbol = ( complete or objectives == 0 ) and "|cff555555[|cffffcc00?|cff555555]|r " or "|cff555555[|cffffcc00!|cff555555]|r "
        tooltip:AddLine(symbol .. meta["quest"], 1, 1, 0)

        if objectives then
          for i=1, objectives, 1 do
            local _o = _objs[i] or {}
            local text, type, finished = _o[1], _o[2], _o[3]

            if type == "monster" then
              -- kill
              local i, j, monsterName, objNum, objNeeded = string.find(text, pfUI.api.SanitizePattern(QUEST_MONSTERS_KILLED))
              if monsterName and meta["spawn"] == monsterName then
                catch_obj = true
                local r,g,b = pfMap.tooltip:GetColor(objNum, objNeeded)
                tooltip:AddLine("|cffaaaaaa- |r" .. monsterName .. ": " .. objNum .. "/" .. objNeeded, r, g, b)
              end
            elseif #meta["item"] > 0 and type == "item" and meta["droprate"] then
              -- loot
              local i, j, itemName, objNum, objNeeded = string.find(text, pfUI.api.SanitizePattern(QUEST_OBJECTS_FOUND))

              for mid, item in pairs(meta["item"]) do
                if item == itemName then
                  catch_obj = true
                  local r,g,b = pfMap.tooltip:GetColor(objNum, objNeeded)
                  local dr,dg,db = pfMap.tooltip:GetColor(tonumber(meta["droprate"]), 100)
                  local lootcolor = string.format("%02x%02x%02x", dr * 255,dg * 255, db * 255)
                  tooltip:AddLine("|cffaaaaaa- |r" .. itemName .. ": " .. objNum .. "/" .. objNeeded .. " |cff555555[|cff" .. lootcolor .. meta["droprate"] .. "%|cff555555]", r, g, b)
                end
              end
            elseif #meta["item"] > 0 and type == "item" and meta["sellcount"] then
              -- vendor
              local i, j, itemName, objNum, objNeeded = string.find(text, pfUI.api.SanitizePattern(QUEST_OBJECTS_FOUND))

              for mid, item in pairs(meta["item"]) do
                if item == itemName then
                  catch_obj = true
                  local r,g,b = pfMap.tooltip:GetColor(objNum, objNeeded)
                  local sellcount = tonumber(meta["sellcount"]) > 0 and " |cff555555[|cffcccccc" .. meta["sellcount"] .. "x" .. "|cff555555]" or ""
                  tooltip:AddLine("|cffaaaaaa- |r" .. pfQuest_Loc["Buy"] .. ": " .. itemName .. ": " .. objNum .. "/" .. objNeeded .. sellcount, r, g, b)
                end
              end
            end
          end
        end
      end
    end

    if not catch then
      tooltip:AddLine("|cff555555[|cffffcc00!|cff555555]|r " .. meta["quest"], 1, 1, .7)
    end

    if not catch_obj then
      -- handle inactive quests
      local catchFallback = nil

      if meta["item"] and meta["item"][1] and meta["droprate"] then
        for mid, item in pairs(meta["item"]) do
          catchFallback = true
          local dr, dg, db = pfMap.tooltip:GetColor(tonumber(meta["droprate"]), 100)
          local lootcolor = string.format("%02x%02x%02x", dr * 255, dg * 255, db * 255)
          tooltip:AddLine("|cffaaaaaa- |r" .. item .. " |cff555555[|cff" .. lootcolor .. meta["droprate"] .. "%|cff555555]", .7, .7, .7)
        end
      end

      if meta["item"] and meta["item"][1] and meta["sellcount"] then
        for mid, item in pairs(meta["item"]) do
          catchFallback = true
          local sellcount = tonumber(meta["sellcount"]) > 0 and " |cff555555[|cffcccccc" .. meta["sellcount"] .. "x" .. "|cff555555]" or ""
          tooltip:AddLine("|cffaaaaaa- |r" .. pfQuest_Loc["Buy"] .. ": " .. item .. sellcount, .7, .7, .7)
        end
      end

      if not catchFallback and meta["spawn"] and not meta["texture"] then
        catchFallback = true
        tooltip:AddLine("|cffaaaaaa- |r" .. (meta["spawntype"] and meta["spawntype"] == "Trigger" and pfQuest_Loc["Explore"] or meta["spawn"]), .7,.7,.7)
      end

      if not catchFallback and meta["texture"] and meta["qlvl"] then
        local texts = meta["questid"] and pfDB["quests"]["loc"][meta["questid"]] or nil

        if texts and texts["O"] and texts["O"] ~= "" then
          tooltip:AddLine(pfDatabase:FormatQuestText(texts["O"]),1,1,.9,true)
        end

        local qlvlstr = pfQuest_Loc["Level"] .. ": " .. pfMap:HexDifficultyColor(meta["qlvl"]) .. meta["qlvl"] .. "|r"
        local qminstr = meta["qmin"] and " / " .. pfQuest_Loc["Required"] .. ": " .. pfMap:HexDifficultyColor(meta["qmin"], true) .. meta["qmin"] .. "|r"  or ""
        tooltip:AddLine("|cffaaaaaa- |r" .. qlvlstr .. qminstr , .8,.8,.8)
      end
    end
  else
    -- handle non-quest objects
    if meta["item"][1] and meta["itemid"] and not meta["itemlink"] then
      local _, _, itemQuality = compat.GetItemInfo(meta["itemid"])
      if itemQuality then
        local itemColor = "|c" .. string.format("%02x%02x%02x%02x", 255,
            ITEM_QUALITY_COLORS[itemQuality].r * 255,
            ITEM_QUALITY_COLORS[itemQuality].g * 255,
            ITEM_QUALITY_COLORS[itemQuality].b * 255)

        meta["itemlink"] = itemColor .."|Hitem:".. meta["itemid"] ..":0:0:0|h[".. meta["item"][1] .."]|h|r"
      end
    end

    if meta["sellcount"] then
      local item = meta["itemlink"] or "[" .. meta["item"][1] .. "]"
      local sellcount = tonumber(meta["sellcount"]) > 0 and " |cff555555[|cffcccccc" .. meta["sellcount"] .. "x" .. "|cff555555]" or ""
      tooltip:AddLine(pfQuest_Loc["Vendor"] .. ": " .. item .. sellcount, 1,1,1)
    elseif meta["item"][1] then
      local item = meta["itemlink"] or "[" .. meta["item"][1] .. "]"
      local r,g,b = pfMap.tooltip:GetColor(tonumber(meta["droprate"]), 100)
      tooltip:AddLine("|cffffffff" .. pfQuest_Loc["Loot"] .. ": " .. item ..  " |cff555555[|r" .. meta["droprate"] .. "%|cff555555]", r,g,b)
    end
  end

  tooltip:Show()
end

function pfMap:GetMapNameByID(id)
  id = tonumber(id)
  return pfDB["zones"]["loc"][id] or nil
end

function pfMap:GetMapIDByName(search)
  if not pfDB["zones"]["loc"] then return nil end
  for id, name in pairs(pfDB["zones"]["loc"]) do
    if name == search then
      return id
    end
  end
end

function pfMap:ShowMapID(map)
  if map then
    -- retail 11.x: OpenWorldMap() replaces ToggleWorldMap()
    if OpenWorldMap then
      OpenWorldMap()
    elseif ToggleWorldMap then
      if not WorldMapFrame:IsShown() then ToggleWorldMap() end
    else
      WorldMapFrame:Show()
    end

    pfMap:SetMapByID(map)
    pfMap:UpdateNodes()
    return true
  end

  return nil
end

function pfMap:SetMapByID(id)
  local search = pfDB["zones"]["loc"][id]

  -- retail 11.x: use C_Map to find and open the zone
  if C_Map and C_Map.GetMapChildrenInfo then
    local allMaps = C_Map.GetMapChildrenInfo(946, nil, true) or {}
    for _, mapInfo in ipairs(allMaps) do
      if mapInfo.name == search then
        if OpenWorldMap then OpenWorldMap(mapInfo.mapID) end
        return
      end
    end
    return
  end
  -- legacy path
  if GetMapContinents then
    for cid, cname in pairs({GetMapContinents()}) do
      for mid, mname in pairs({GetMapZones(cid)}) do
        if mname == search then
          SetMapZoom(cid, mid)
          return
        end
      end
    end
  end
end

local customids = {
  ["AlteracValley"] = 2597,
}

-- ---------------------------------------------------------------------------
-- pfMap:GetCurrentMapID()
-- Retail 11.x replacement for GetCurrentMapContinent() + GetCurrentMapZone().
-- Returns the pfDB internal zone id for the player's current zone.
-- ---------------------------------------------------------------------------
function pfMap:GetCurrentMapID()
  if C_Map and C_Map.GetBestMapForUnit then
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if uiMapID then
      local mapInfo = C_Map.GetMapInfo(uiMapID)
      if mapInfo then
        return pfMap:GetMapIDByName(mapInfo.name)
      end
    end
    return nil
  end
  -- legacy fallback
  if GetCurrentMapContinent and GetCurrentMapZone then
    return pfMap:GetMapID(GetCurrentMapContinent(), GetCurrentMapZone())
  end
end

local map_zone_cache = {}
function pfMap:GetMapID(cid, mid)
  -- retail: no continent/zone API; delegate
  if not (GetCurrentMapContinent and GetCurrentMapZone) then
    return pfMap:GetCurrentMapID()
  end

  cid = cid or GetCurrentMapContinent()
  mid = mid or GetCurrentMapZone()

  if not map_zone_cache[cid] then
    map_zone_cache[cid] = { GetMapZones(cid) }
  end

  local list = map_zone_cache[cid]
  local name = list[mid]
  local id   = pfMap:GetMapIDByName(name)
  id = id or customids[GetMapInfo and GetMapInfo()]

  return id
end

function pfMap:AddNode(meta)
  if not meta then return end
  if not meta["zone"] then return end
  if not meta["title"] then return end

  meta["description"] = pfDatabase:BuildQuestDescription(meta)

  local addon = meta["addon"] or "PFDB"
  local map = meta["zone"]
  local coords = meta["x"] .. "|" .. meta["y"]
  local title = meta["title"]
  local layer = GetLayerByTexture(meta["texture"])
  local spawn = meta["spawn"]
  local item = meta["item"]

  -- Debug log node additions (throttled: max 5 per addon to avoid log spam)
  if pfQuest_config and pfQuest_config.debug then
    pfMap._nodeLogCount = pfMap._nodeLogCount or {}
    pfMap._nodeLogCount[addon] = (pfMap._nodeLogCount[addon] or 0) + 1
    if pfMap._nodeLogCount[addon] <= 5 then
      local zoneName = (pfDB["zones"]["loc"] and pfDB["zones"]["loc"][map]) or "?"
      pfQuest:Debug("|cff55ff55+Node|r " .. tostring(addon) .. " |cffaaaaaa" .. tostring(title) .. " @ zone=" .. tostring(map) .. "/" .. zoneName .. " (" .. tostring(meta["x"]) .. "," .. tostring(meta["y"]) .. ")|r")
    elseif pfMap._nodeLogCount[addon] == 6 then
      pfQuest:Debug("|cff55ff55+Node|r " .. tostring(addon) .. " |cffaaaaaa(further nodes suppressed...)|r")
    end
  end

  local sindex = string.format("%s:%s:%s:%s:%s:%s",
    (addon or ""), (map or ""), (coords or ""), (title or ""), (layer or ""), (spawn or ""), (item or ""))

  -- use prioritized clusters
  if layer >= 9 and meta["priority"] then
    layer = layer + (10 - min(meta["priority"], 10))
  end

  if not pfMap.nodes[addon] then pfMap.nodes[addon] = {} end
  if not pfMap.nodes[addon][map] then pfMap.nodes[addon][map] = {} end
  if not pfMap.nodes[addon][map][coords] then pfMap.nodes[addon][map][coords] = {} end

  -- skip early on existing nodes
  if pfMap.nodes[addon][map][coords][title] then
    if item and #pfMap.nodes[addon][map][coords][title].item > 0 then
      -- check if item already exists
      for id, name in pairs(pfMap.nodes[addon][map][coords][title].item) do
        if name == item then return end
      end

      -- add new item and exit
      table.insert(pfMap.nodes[addon][map][coords][title].item, item)
      return
    end

    if pfMap.nodes[addon][map][coords][title] and pfMap.nodes[addon][map][coords][title].layer and layer and
     pfMap.nodes[addon][map][coords][title].layer >= layer then
      -- identical node already exists, exit here
      return
    end
  end

  -- create new combined data node from given meta data
  if not similar_nodes[sindex] then
    similar_nodes[sindex] = {}
    for key, val in pairs(meta) do similar_nodes[sindex][key] = val end
    similar_nodes[sindex].item = { [1] = item }
  end

  -- set current node to combined node
  pfMap.nodes[addon][map][coords][title] = similar_nodes[sindex]

  -- add node to unified cluster cache
  if not meta["cluster"] and not meta["texture"] then
    local node_index = meta.item or meta.spawn or UNKNOWN
    local x, y = tonumber(meta.x), tonumber(meta.y)

    -- create prerequisite table structure
    unifiedcache[title] = unifiedcache[title] or {}
    unifiedcache[title][map] = unifiedcache[title][map] or {}

    if not unifiedcache[title][map][node_index] then
      -- create new unified node from given meta data
      local unified_meta = {}
      for key, val in pairs(meta) do unified_meta[key] = val end

      -- save node to unified cache
      unifiedcache[title][map][node_index] = { meta = unified_meta, coords = {} }
    end

    -- append new coords to unified cache unified cache
    table.insert(unifiedcache[title][map][node_index].coords, { x, y })
  end

  -- add to gametooltips
  if spawn and title then
    pfMap.tooltips[spawn] = pfMap.tooltips[spawn] or {}
    pfMap.tooltips[spawn][title] = pfMap.tooltips[spawn][title] or {}
    pfMap.tooltips[spawn][title][map] = pfMap.tooltips[spawn][title][map] or similar_nodes[sindex]
  end

  pfMap.queue_update = GetTime()
end

function pfMap:GetNodes(addon, title)
  local nodes = {}

  if title and pfMap.nodes[addon] then
    for map, foo in pairs(pfMap.nodes[addon]) do
      for coords, node in pairs(pfMap.nodes[addon][map]) do
        if pfMap.nodes[addon][map][coords][title] then
          table.insert(nodes, pfMap.nodes[addon][map][coords][title])
        end
      end
    end
  end

  return nodes
end

function pfMap:DeleteNode(addon, title)
  -- Reset node log count for self addon so next update logs fresh
  if pfMap._nodeLogCount and addon then
    pfMap._nodeLogCount[addon] = nil
  end
  -- Debug log node deletions
  if pfQuest_config and pfQuest_config.debug then
    pfQuest:Debug("|cffff5555-Node|r " .. tostring(addon) .. " |cffaaaaaa" .. tostring(title or "ALL") .. "|r")
  end
  -- remove tooltips
  if not addon then
    pfMap.tooltips = {}
  else
    for mk, mv in pairs(pfMap.tooltips) do
      for tk, tv in pairs(mv) do
        if ( title and tk == title ) or ( not title and tv.addon == addon ) then
          pfMap.tooltips[mk][tk] = nil
        end
      end
    end
  end

  -- remove nodes
  if not addon then
    pfMap.nodes = {}
  elseif not title then
    pfMap.nodes[addon] = {}
  elseif pfMap.nodes[addon] then
    for map, foo in pairs(pfMap.nodes[addon]) do
      for coords, node in pairs(pfMap.nodes[addon][map]) do
        if pfMap.nodes[addon][map][coords][title] then
          pfMap.nodes[addon][map][coords][title] = nil
          if IsEmpty(pfMap.nodes[addon][map][coords]) then
            pfMap.nodes[addon][map][coords] = nil
          end
        end
      end
    end
  end

  pfMap.queue_update = GetTime()
end

function pfMap:NodeClick(self)
  -- retail: OnClick passes (self, button); legacy used implicit "self"
  local btn = self or self
  if IsShiftKeyDown() then
    if btn.questid and btn.texture and btn.layer < 5 then
      -- mark questnode as done
      pfQuest_history[btn.questid] = { time(), UnitLevel("player") }
    end

    if btn.node and btn.title and btn.node[btn.title] then
      -- delete node from map
      pfMap:DeleteNode(btn.node[btn.title].addon, btn.title)
    end

    pfQuest.updateQuestGivers = true
  elseif btn.texture and pfQuest.route and
   (( pfQuest_config["routecluster"] == "1" and btn.layer >= 9 ) or
    ( pfQuest_config["routeender"] == "1" and btn.layer == 4) or
    ( pfQuest_config["routestarter"] == "1" and btn.layer == 1) or
    ( pfQuest_config["routestarter"] == "1" and btn.layer == 2))
  then
    -- set as arrow target priority
    pfQuest.route.SetTarget((not pfQuest.route.IsTarget(btn) and btn))
    pfMap.queue_update = GetTime()
  else
    -- switch color
    pfQuest_colors[btn.color] = { str2rgb(btn.color .. GetTime()) }
    pfMap.queue_update = GetTime()
  end
end

function pfMap:NodeEnter(self)
  local btn = self or self

  -- Disable blob tooltips where still applicable (WotLK / early retail)
  if compat.client >= 30300 and WorldMapPOIFrame and WorldMapPOIFrame.allowBlobTooltip ~= nil then
    WorldMapPOIFrame.allowBlobTooltip = false
  end

  -- retail 11.x: WorldMapButton and WorldMapTooltip are removed.
  -- Detect the map canvas dynamically and fall back to GameTooltip.
  local mapCanvas = WorldMapButton
    or (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
  local tooltip = (mapCanvas and btn:GetParent() == mapCanvas)
    and (WorldMapTooltip or GameTooltip) or GameTooltip

  tooltip:SetOwner(btn, "ANCHOR_LEFT")
  btn.spawn = btn.spawn or UNKNOWN
  tooltip:SetText(btn.spawn..(pfQuest_config.showids == "1" and " |cffcccccc("..btn.spawnid..")|r" or ""), .3, 1, .8)
  tooltip:AddDoubleLine(pfQuest_Loc["Level"] .. ":", (btn.level or UNKNOWN), .8,.8,.8, 1,1,1)
  tooltip:AddDoubleLine(pfQuest_Loc["Type"] .. ":", (btn.spawntype or UNKNOWN), .8,.8,.8, 1,1,1)
  tooltip:AddDoubleLine(pfQuest_Loc["Respawn"] .. ":", (btn.respawn or UNKNOWN), .8,.8,.8, 1,1,1)

  for title, meta in pairs(btn.node) do
    pfMap:ShowTooltip(meta, tooltip)
  end

  -- add tooltip help if setting is enabled
  if pfQuest_config["tooltiphelp"] == "1" then
    local text = pfQuest_Loc["Use <Shift>-Click To Remove Nodes"]

    if btn.cluster then
      text = pfQuest_Loc["Hold <Ctrl> To Hide Cluster"]
    elseif tooltip == GameTooltip then
      text = pfQuest_Loc["Hold <Ctrl> To Hide Minimap Nodes"]
    elseif not btn.texture then
      text = pfQuest_Loc["Click Node To Change Color"]
    elseif btn.questid and btn.texture and btn.layer < 5 then
      text = pfQuest_Loc["Use <Shift>-Click To Mark Quest As Done"]
    end

    tooltip:AddLine(text, .6, .6, .6)
    tooltip:Show()
  end

  pfMap.highlight = pfQuest_config["mouseover"] == "1" and btn.title
end

function pfMap:NodeLeave(self)
  local btn = self or self

  if compat.client >= 30300 and WorldMapPOIFrame and WorldMapPOIFrame.allowBlobTooltip ~= nil then
    WorldMapPOIFrame.allowBlobTooltip = true
  end

  local mapCanvas = WorldMapButton
    or (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
  local tooltip = (mapCanvas and btn:GetParent() == mapCanvas)
    and (WorldMapTooltip or GameTooltip) or GameTooltip

  tooltip:Hide()
  pfMap.highlight = nil
end

function pfMap:BuildNode(name, parent)
  local f = CreateFrame("Button", name, parent)

  -- retail 11.x: WorldMapButton removed; detect map canvas dynamically
  local mapCanvas = WorldMapButton
    or (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
  if parent == mapCanvas then
    f.defalpha = tonumber(pfQuest_config["worldmaptransp"]) or 1
    f.defsize  = 14
  else
    f.defalpha = tonumber(pfQuest_config["minimaptransp"]) or 1
    f.defsize  = 14
    f.minimap  = true
  end

  f:SetWidth(f.defsize)
  f:SetHeight(f.defsize)

  f.Animate = NodeAnimate
  f:SetScript("OnEnter", function(self) pfMap:NodeEnter(self) end)
  f:SetScript("OnLeave", function(self) pfMap:NodeLeave(self) end)

  f.tex = f:CreateTexture(nil, "BACKGROUND")
  f.tex:SetAllPoints(f)

  f.pic = f:CreateTexture(nil, "ARTWORK")
  f.pic:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  f.pic:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

  f.hl = f:CreateTexture(nil, "BORDER")
  f.hl:SetTexture(pfQuestConfig.path.."\\img\\track")
  f.hl:SetPoint("TOPLEFT", f, "TOPLEFT", -5, 5)
  f.hl:SetWidth(12)
  f.hl:SetHeight(12)
  return f
end

pfMap.highlightdb = {}
function pfMap:UpdateNode(frame, node, color, obj, distance)
  -- clear node to title association table
  if pfMap.highlightdb[frame] then
    for k,v in pairs(pfMap.highlightdb[frame]) do
      pfMap.highlightdb[frame][k] = nil
    end
  else
    pfMap.highlightdb[frame] = {}
  end

  -- reset layer
  frame.layer = 0

  for title, tab in pairs(node) do
    pfMap.highlightdb[frame][title] = true

    tab.layer = GetLayerByTexture(tab.texture)

    -- use prioritized clusters
    if tab.cluster and tab.priority then
      tab.layer = tab.layer + (10 - min(tab.priority , 10))
    end

    if tab.spawn and ( tab.layer > frame.layer or not frame.spawn ) then
      frame.updateTexture = (frame.texture ~= tab.texture)
      frame.updateVertex = (frame.vertex ~= tab.vertex )
      frame.updateColor = (frame.color ~= tab.color)
      frame.updateLayer = (frame.layer ~= tab.layer)

      -- set title and texture to the entry with highest layer
      -- and add core information
      frame.layer       = tab.layer
      frame.spawn       = tab.spawn
      frame.spawnid     = tab.spawnid
      frame.spawntype   = tab.spawntype
      frame.respawn     = tab.respawn
      frame.level       = tab.level
      frame.questid     = tab.questid
      frame.texture     = tab.texture
      frame.vertex      = tab.vertex
      frame.title       = title
      frame.func        = tab.func
      frame.cluster     = tab.cluster
      frame.description = tab.description
      frame.priority    = tab.priority
      frame.quest       = tab.quest
      frame.qlvl        = tab.qlvl
      frame.itemreq     = tab.itemreq
      frame.arrow       = tab.arrow
      frame.icon        = tab.icon
      frame.fade_range  = tab.fade_range

      if pfQuest_config["spawncolors"] == "1" then
        frame.color = tab.spawn or tab.title
      else
        frame.color = tab.title
      end
    end
  end

  if ( frame.updateTexture or frame.updateVertex or not frame.tex:GetTexture() ) and frame.texture then
    frame.tex:SetTexture(frame.texture)
    frame.tex:SetVertexColor(1,1,1)
    frame.pic:Hide()

    if frame.updateVertex and frame.vertex then
      local r, g, b = unpack(frame.vertex)
      if r > 0 or g > 0 or b > 0 then
        frame.tex:SetVertexColor(r, g, b, 1)
      end
    end
  end

  if ( frame.updateColor or frame.updateTexture or not frame.tex:GetTexture() ) and not frame.texture then
    local r, g, b = str2rgb(frame.color)

    if (frame.title and pfQuest.icons[frame.title]) or frame.icon then
      local texture = (frame.title and pfQuest.icons[frame.title]) or frame.icon
      frame.pic:SetTexture(texture)
      frame.pic:Show()

      if obj == "minimap" then
        local halfsize = pfMap.drawlayer:GetWidth()/2
        local fade_range = frame.fade_range or 8
        local fade_in = halfsize/100*(fade_range-4)
        local fade_out = halfsize/100*(fade_range+4)
        local alpha = ((distance or fade_out) - fade_in) / (fade_out - fade_in)
        alpha = math.max(alpha, 0)
        alpha = math.min(alpha, 1)
        frame.pic:SetAlpha(alpha)
      end
    else
      frame.pic:Hide()
    end

    if obj == "minimap" and pfQuest_config["cutoutminimap"] == "1" then
      frame.tex:SetTexture(pfQuestConfig.path.."\\img\\nodecut")
      frame.tex:SetVertexColor(r,g,b,1)
    elseif obj ~= "minimap" and pfQuest_config["cutoutworldmap"] == "1" then
      frame.tex:SetTexture(pfQuestConfig.path.."\\img\\nodecut")
      frame.tex:SetVertexColor(r,g,b,1)
    else
      frame.tex:SetTexture(pfQuestConfig.path.."\\img\\node")
      frame.tex:SetVertexColor(r,g,b,1)
    end
  end

  if frame.updateLayer then
    frame:SetFrameLevel((obj == "minimap" and 4 or 112) + frame.layer)
  end

  if frame.updateTexture or frame.updateVertex or frame.updateColor or frame.updateLayer then
    frame:SetScript("OnClick", frame.func or function(self, btn) pfMap:NodeClick(self, btn) end)
  end

  local highlight = frame.texture and pfMap.highlightdb[frame][pfMap.highlight] and true or nil
  local target = frame.texture and pfQuest.route and pfQuest.route.IsTarget(frame) or nil

  -- set default sizes for different node types
  frame.defsize = (frame.cluster or frame.layer == 4) and 18 or 14

  -- make the current route target visible
  if target then frame.hl:Show() else frame.hl:Hide() end

  -- reset frame size except for highlights
  if not highlight then
    frame:SetWidth(frame.defsize)
    frame:SetHeight(frame.defsize)
  end

  frame.node = node
end

function pfMap:UpdateNodes()
  local _mapID = pfMap:GetCurrentMapID()
  local _zoneName = (_mapID and pfDB["zones"]["loc"] and pfDB["zones"]["loc"][_mapID]) or "unknown"
  pfQuest:Debug("Update Nodes |cffaaaaaa[zone=" .. tostring(_mapID) .. " " .. _zoneName .. "]|r")

  local color = pfQuest_config["spawncolors"] == "1" and "spawn" or "title"

  -- retail 11.x: use the DISPLAYED map zone, not just the player's current zone.
  -- WorldMapFrame:GetMapID() returns the uiMapID of the map being viewed.
  -- Fall back to player zone if map isn't open or API unavailable.
  local map
  if WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:IsShown() then
    local displayedUID = WorldMapFrame:GetMapID()
    if displayedUID then
      -- Convert displayed uiMapID -> pfQuest zone ID via bridge
      map = pfQuest.retailZoneMap and pfQuest.retailZoneMap[displayedUID]
      -- If not in retail map, try classic path via zone name
      if not map and C_Map then
        local info = C_Map.GetMapInfo(displayedUID)
        if info then map = pfMap:GetMapIDByName(info.name) end
      end
    end
  end
  -- Fallback: player's current zone
  map = map or pfMap:GetCurrentMapID()
  local i = 1

  -- reset tracker
  pfQuest.tracker.Reset()

  -- reset route
  pfQuest.route:Reset()

  -- refresh all nodes
  for addon, _ in pairs(pfMap.nodes) do
    if pfMap.nodes[addon][map] then
      for coords, node in pairs(pfMap.nodes[addon][map]) do
        if not pfMap.pins[i] then
          -- retail 11.x: resolve map canvas at call time
          local _mapCanvas = WorldMapButton
            or (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
            or WorldMapFrame
          pfMap.pins[i] = pfMap:BuildNode("pfMapPin" .. i, _mapCanvas)
        end

        pfMap:UpdateNode(pfMap.pins[i], node, color)

        -- set position
        local _, _, x, y = string.find(coords, "(.*)|(.*)")

        -- write points to the route plan
        if ( pfQuest_config["routecluster"] == "1" and pfMap.pins[i].layer >= 9 ) or
          ( pfQuest_config["routeender"] == "1" and pfMap.pins[i].layer == 4) or
          ( pfQuest_config["routestarter"] == "1" and pfMap.pins[i].layer == 1 and pfMap.pins[i].texture) or
          ( pfQuest_config["routestarter"] == "1" and pfMap.pins[i].layer == 2) or
          pfMap.pins[i].arrow == true
        then
          pfQuest.route:AddPoint({ x, y, pfMap.pins[i] })
        end

        -- hide cluster nodes if set
        if pfQuest_config["showcluster"] == "0" and pfMap.pins[i].cluster then
          pfMap.pins[i]:Hide()
        -- hide individual quest spawns
        elseif pfQuest_config["showspawn"] == "0" and addon == "PFQUEST" and not pfMap.pins[i].texture then
          pfMap.pins[i]:Hide()
        else
          -- populate quest list on map
          for title, node in pairs(pfMap.pins[i].node) do
            pfQuest.tracker.ButtonAdd(title, node)
          end

          local _mapCanvas = WorldMapButton
            or (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
            or WorldMapFrame
          x = x / 100 * _mapCanvas:GetWidth()
          y = y / 100 * _mapCanvas:GetHeight()

          pfMap.pins[i]:ClearAllPoints()
          pfMap.pins[i]:SetPoint("CENTER", _mapCanvas, "TOPLEFT", x, -y)

          pfMap.pins[i]:Show()
        end

        i = i + 1
      end
    end
  end

  -- hide remaining pins
  for j=i, #pfMap.pins do
    if pfMap.pins[j] then pfMap.pins[j]:Hide() end
  end
end

local coord_cache = {}
local _mmState = {}  -- replaces implicit "self" storage
function pfMap:UpdateMinimap()
  -- check for disabled minimap nodes
  if pfQuest_config["minimapnodes"] == "0" then
    return
  end

  -- hide all minimap nodes while shift is pressed
  if controlkey.pressed and MouseIsOver(pfMap.drawlayer) then
    _mmState.xPlayer = nil

    for id, pin in pairs(pfMap.mpins) do
      pin:Hide()
    end

    return
  end

  -- hide nodes / skip in instances where position is unavailable
  local xPlayer, yPlayer
  if C_Map and C_Map.GetPlayerMapPosition then
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if uiMapID then
      local pos = C_Map.GetPlayerMapPosition(uiMapID, "player")
      if pos then xPlayer, yPlayer = pos:GetXY() end
    end
  elseif GetPlayerMapPosition then
    xPlayer, yPlayer = GetPlayerMapPosition("player")
  end

  if not xPlayer or (xPlayer == 0 and yPlayer == 0) then
    for _, pin in pairs(pfMap.mpins) do pin:Hide() end
    return
  end

  -- retail 11.x: Minimap:GetZoom() removed; read from CVar instead
  local mZoom = (Minimap.GetZoom and Minimap:GetZoom())
             or (tonumber(GetCVar("minimapZoom")) or 0)
  xPlayer, yPlayer = xPlayer * 100, yPlayer * 100

  -- force refresh every second even without changed values, otherwise skip
  if _mmState.xPlayer == xPlayer and _mmState.yPlayer == yPlayer and _mmState.mZoom == mZoom then
    if (_mmState.tick or 1) > GetTime() then return else _mmState.tick = GetTime() + 1 end
  end

  _mmState.xPlayer, _mmState.yPlayer, _mmState.mZoom = xPlayer, yPlayer, mZoom
  local color = pfQuest_config["spawncolors"] == "1" and "spawn" or "title"
  local minimap_sizes = get_minimap_sizes()

  -- Use GetCurrentMapID (which goes through the zone bridge) rather than
  -- GetMapIDByName, so retail zones resolve correctly via the uiMapID table.
  local mapID = pfMap:GetCurrentMapID()
  local mapZoom = minimap_zoom[minimap_indoor()][mZoom]

  -- For retail zones the placeholder size is 4266.7 x 2844.4.
  -- If no entry exists at all, use the retail default so pins still appear.
  local _sizes = minimap_sizes[mapID] or (mapID and mapID >= 10000 and { 4266.7, 2844.4 })
  local mapWidth  = _sizes and _sizes[1] or 0
  local mapHeight = _sizes and _sizes[2] or 0

  local xScale = mapZoom / mapWidth
  local yScale = mapZoom / mapHeight

  local xDraw = pfMap.drawlayer:GetWidth() / xScale / 100
  local yDraw = pfMap.drawlayer:GetHeight() / yScale / 100

  local i = 1

  -- refresh all nodes
  for addon, data in pairs(pfMap.nodes) do
    -- hide minimap nodes in continent view
    if data[mapID] and (minimap_sizes[mapID] or (mapID and mapID >= 10000)) and pfMap:HasMinimap(mapID) then
      for coords, node in pairs(data[mapID]) do
        local x, y
        if coord_cache[coords] then
          x, y = coord_cache[coords][1], coord_cache[coords][2]
        else
          local _, _, strx, stry = string.find(coords, "(.*)|(.*)")
          x, y = strx + 0, stry + 0
          coord_cache[coords] = { x, y }
        end

        local xPos = ( x - xPlayer) * xDraw
        local yPos = ( y - yPlayer) * yDraw

        if pfQuestCompat.rotateMinimap then
          local _facing = pfQuestCompat.GetPlayerFacing()
          local sinF, cosF = math.sin(_facing), math.cos(_facing)
          local dx, dy = xPos, -yPos
          xPos = (dx * cosF) + (dy * sinF)
          yPos = -((-dx * sinF) + (dy * cosF))
        end

        local display = nil
        local distance = sqrt(xPos * xPos + yPos * yPos)

        if pfUI and pfUI.minimap then
          display = (math.abs(xPos) + 8 < pfMap.drawlayer:GetWidth()/2 and math.abs(yPos) + 8 < pfMap.drawlayer:GetHeight()/2) and true or nil
        else
          display = (distance + 8 < pfMap.drawlayer:GetWidth()/2) and true or nil
        end

        if display then
          if not pfMap.mpins[i] then
            pfMap.mpins[i] = pfMap:BuildNode(nodename .. i, pfMap.drawlayer)
          end

          pfMap:UpdateNode(pfMap.mpins[i], node, color, "minimap", distance)

          pfMap.mpins[i].hl:Hide()

          if pfQuest_config["showclustermini"] == "0" and pfMap.mpins[i].cluster then
            pfMap.mpins[i]:Hide()
          elseif pfQuest_config["showspawnmini"] == "0" and addon == "PFQUEST" and not pfMap.mpins[i].texture then
            pfMap.mpins[i]:Hide()
          else
            pfMap.mpins[i]:ClearAllPoints()
            pfMap.mpins[i]:SetPoint("CENTER", pfMap.drawlayer, "CENTER", xPos, -yPos)
            pfMap.mpins[i]:Show()
          end

          i = i + 1
        end
      end
    end
  end

  -- hide remaining pins
  for j=i, #pfMap.mpins do
    if pfMap.mpins[j] then pfMap.mpins[j]:Hide() end
  end
end

local zone, last_zone
pfMap:RegisterEvent("ZONE_CHANGED")
pfMap:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- MINIMAP_ZONE_CHANGED removed in retail; MINIMAP_UPDATE_ZOOM is the replacement
if not pcall(function() pfMap:RegisterEvent("MINIMAP_ZONE_CHANGED") end) then
  pfMap:RegisterEvent("MINIMAP_UPDATE_ZOOM")
end
-- WORLD_MAP_UPDATE removed in retail; use MAP_OPENED + ZONE_CHANGED
if not pcall(function() pfMap:RegisterEvent("MAP_OPENED") end) then end
if not pcall(function() pfMap:RegisterEvent("MAP_CLOSED") end) then end
pfMap:SetScript("OnEvent", function(self, event)
  -- retail: track zone by C_Map uiMapID; legacy by GetCurrentMapZone()
  if C_Map and C_Map.GetBestMapForUnit then
    zone = C_Map.GetBestMapForUnit("player")
  elseif GetCurrentMapZone then
    zone = GetCurrentMapZone()
  end

  if event == "ZONE_CHANGED" or event == "MINIMAP_ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
    -- Trigger UpdateNodes for the new zone via queue_update
    pfMap.queue_update = GetTime()
    -- Log zone change with name and ID
    local pfZoneID = pfMap:GetCurrentMapID()
    local zoneName = (pfZoneID and pfDB["zones"]["loc"] and pfDB["zones"]["loc"][pfZoneID]) or GetRealZoneText() or "?"
    pfQuest:Debug("|cff33ffccZone|r " .. event .. " |cffaaaaaa[uiMapID=" .. tostring(zone) .. " pfID=" .. tostring(pfZoneID) .. " " .. zoneName .. "]|r")
    if not WorldMapFrame:IsShown() then
      -- SetMapToCurrentZone removed in retail; C_Map handles self automatically
      if SetMapToCurrentZone then SetMapToCurrentZone() end
    end
  end

  if (event == "WORLD_MAP_UPDATE" or event == "MAP_OPENED" or event == "MAP_CLOSED") and last_zone ~= zone then
    pfMap:UpdateNodes()
    last_zone = zone
  end
end)

local hlstate, shiftstate, transition, hidecluster, fps, resetmap
local _mapThrottle = 0
pfMap:SetScript("OnUpdate", function(self)
  -- handle highlights and animations
  if pfMap.queue_update or transition or pfMap.highlight ~= hlstate or shiftstate ~= hidecluster then
    hlstate, shiftstate, transition = pfMap.highlight, hidecluster, nil
    fps = math.max(.2, GetFramerate() / 30)

    for frame, data in pairs(pfMap.highlightdb) do
      local highlight = pfMap.highlightdb[frame][pfMap.highlight] and true or nil

      if hidecluster and frame.cluster then
        -- hide clusters
        transition = frame:Animate(frame.defsize, 0, fps) or transition
      elseif highlight then
        -- zoom node
        transition = frame:Animate((frame.texture and frame.defsize + 4 or frame.defsize), 1, fps) or transition
      elseif not highlight and pfMap.highlight then
        -- fade node
        transition = frame:Animate(frame.defsize, tonumber(pfQuest_config["nodefade"]) or 0.3, fps) or transition
      elseif frame.texture or frame.cluster then
        -- defaults for textured nodes
        transition = frame:Animate(frame.defsize, 1, fps) or transition
      else
        -- defaults
        transition = frame:Animate(frame.defsize, frame.defalpha, fps) or transition
      end
    end
  end

  -- limit all map updates to once per .05 seconds
  if _mapThrottle > GetTime() then return else _mapThrottle = GetTime() + .05 end

  -- process node updates if required
  if pfMap.queue_update and pfMap.queue_update + .25 < GetTime() then
    pfMap.queue_update = nil
    pfMap:UpdateNodes()
  end

  -- reset map to current zone once map is closed
  if WorldMapFrame:IsShown() then
    resetmap = true
  elseif resetmap == true then
    if SetMapToCurrentZone then SetMapToCurrentZone() end
    resetmap = nil
  end

  -- refresh minimap
  pfMap:UpdateMinimap()

  -- update hidecluster detection
  if controlkey.pressed then
    hidecluster = MouseIsOver(WorldMapFrame)
  else
    hidecluster = nil
  end
end)

-- ---------------------------------------------------------------------------
-- Retail 11.x quest highlight hook
-- WorldMapQuestFrame_OnMouseUp / WorldMapBlobFrame no longer exist.
-- Use the QUEST_LOG_SELECTION_CHANGED event and C_QuestLog instead.
-- WotLK (3.3.5) hook is retained for that client version.
-- ---------------------------------------------------------------------------
if compat.client >= 110000 then
  local _qlsFrame = CreateFrame("Frame")
  if not pcall(function() _qlsFrame:RegisterEvent("QUEST_LOG_SELECTION_CHANGED") end) then
    -- QUEST_LOG_SELECTION_CHANGED removed; use QUEST_LOG_UPDATE instead
    _qlsFrame:RegisterEvent("QUEST_LOG_UPDATE")
  end
  _qlsFrame:SetScript("OnEvent", function(self, event)
    local questID = C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
    if not questID then return end
    local info  = C_QuestLog.GetInfo and C_QuestLog.GetInfo(questID)
    local title = info and info.title
    if title then
      pfMap.highlight = title
      pfMap.queue_update = GetTime()
    end
  end)

elseif compat.client >= 30300 then
  local previousTitle = nil
  local pfHookWorldMapQuestFrame_OnMouseUp = WorldMapQuestFrame_OnMouseUp
  WorldMapQuestFrame_OnMouseUp = function(self)
    pfHookWorldMapQuestFrame_OnMouseUp(self)
    if WorldMapBlobFrame then WorldMapBlobFrame:Hide() end
    if WorldMapFrame_ClearQuestPOIs then WorldMapFrame_ClearQuestPOIs() end
    if not IsShiftKeyDown() then
      pfMap.highlight = nil
      local questLogIndex = (GetQuestLogSelection and GetQuestLogSelection()) or 0
      local title = GetQuestLogTitle and GetQuestLogTitle(questLogIndex)
      if title then
        if previousTitle == title then
          pfMap.highlight = nil
          previousTitle = nil
        else
          pfMap.highlight = title
          previousTitle = title
          pfMap.queue_update = GetTime()
        end
      end
    end
  end
end
