-- multi api compat
local compat = pfQuestCompat

SLASH_PFDB1, SLASH_PFDB2, SLASH_PFDB3, SLASH_PFDB4 = "/db", "/shagu", "/pfquest", "/pfdb"
SlashCmdList["PFDB"] = function(input, editbox)
  local params = {}
  local meta = { ["addon"] = "PFDB" }

  if (input == "" or input == nil) then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest (v" .. (pfQuestConfig.version or "?") .. "):")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff lock |cffcccccc - " .. pfQuest_Loc["Lock map tracker"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff tracker |cffcccccc - " .. pfQuest_Loc["Show map tracker"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff journal |cffcccccc - " .. pfQuest_Loc["Show quest journal"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff arrow |cffcccccc - " .. pfQuest_Loc["Show quest arrow"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff show |cffcccccc - " .. pfQuest_Loc["Show database interface"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff config |cffcccccc - " .. pfQuest_Loc["Show configuration interface"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff locale |cffcccccc - " .. pfQuest_Loc["Display addon locales"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff debug |cffcccccc - Toggle debug mode")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff scan |cffcccccc - " .. pfQuest_Loc["Scan the server for custom items"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff query |cffcccccc - " .. pfQuest_Loc["Query the server for completed quests"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff clean |cffcccccc - " .. pfQuest_Loc["Clean Map"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff reset |cffcccccc - " .. pfQuest_Loc["Reset Map"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff track <list> |cffcccccc - " .. pfQuest_Loc["Show available tracking lists"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff unit <name> |cffcccccc - " .. pfQuest_Loc["Search unit"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff object <name> |cffcccccc - " .. pfQuest_Loc["Search object"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff item <name> |cffcccccc - " .. pfQuest_Loc["Search loot"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff vendor <name> |cffcccccc - " .. pfQuest_Loc["Search item vendors"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff quest <name> |cffcccccc - " .. pfQuest_Loc["Show specific quest"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff quests |cffcccccc - " .. pfQuest_Loc["Show all quests on map"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/db|cffffffff meta <list> [min] [max] |cffcccccc - Search meta relations")
    return
  end

  local commandlist = { }
  local command

  for command in compat.gfind(input, "[^ ]+") do
    table.insert(commandlist, command)
  end

  local arg1, arg2 = commandlist[1], ""

  -- handle whitespace mob- and item names correctly
  for i in pairs(commandlist) do
    if (i ~= 1) then
      arg2 = arg2 .. commandlist[i]
      if (commandlist[i+1] ~= nil) then
        arg2 = arg2 .. " "
      end
    end
  end

  -- argument: debug
  if (arg1 == "debug") then
    pfQuest_config.debug = not pfQuest_config.debug
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Debug Mode: " .. ( pfQuest_config.debug and "|cff33ff33ON" or "|cffff3333OFF" ))
    pfQuest:Debug("Debug Mode Changed")
    return
  end

  -- argument: item
  if (arg1 == "item") then
    local maps = pfDatabase:SearchItem(arg2, meta, "LOWER")
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: vendor
  if (arg1 == "vendor") then
    local maps = pfDatabase:SearchVendor(arg2, meta, "LOWER")
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: unit
  if (arg1 == "unit") then
    local maps = pfDatabase:SearchMob(arg2, meta, "LOWER")
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: object
  if (arg1 == "object") then
    local maps = pfDatabase:SearchObject(arg2, meta, "LOWER")
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: quest
  if (arg1 == "quest") then
    local maps = pfDatabase:SearchQuest(arg2, meta, "LOWER")
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: att (force ATT/native quest completion sync)
  if arg1 == "att" or arg1 == "attquery" then
    if pfATTIntegration then
      pfATTIntegration:Sync(false)
      if pfATTIntegration:IsATTLoaded() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: AllTheThings detected — using ATT + native API sources.")
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: ATT not installed. Used C_QuestLog.GetAllCompletedQuestIDs only.")
      end
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: ATT integration module not loaded.")
    end
    return
  end

  -- argument: classicdb (report Classic DB status)
  if arg1 == "classicdb" then
    if pfQuestRetail_ClassicDBLoaded then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Classic DB is |cff33ff33LOADED|r. Disable via Settings > Load Classic Quest Database, then /reload.")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Classic DB is |cffaaaaaa UNLOADED|r (retail client). Enable in Settings + /reload.")
    end
    return
  end

  -- argument: mobinfo2 (import/status for MobInfo2 data)
  if arg1 == "mobinfo2" then
    local hasModern = type(MI2_DB) == "table" and type(MI2_DB.location) == "table"
    local hasLegacy = type(MobInfoDB) == "table"
    if not hasModern and not hasLegacy then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: MobInfo2 not found. Install MobInfo2 (CurseForge) and log some mobs first.")
    elseif pfMobInfo2Import then
      local before = 0
      if pfDB and pfDB["units"] and pfDB["units"]["data"] then
        for _ in pairs(pfDB["units"]["data"]) do before = before + 1 end
      end
      pfMobInfo2Import()
      local after = 0
      if pfDB and pfDB["units"] and pfDB["units"]["data"] then
        for _ in pairs(pfDB["units"]["data"]) do after = after + 1 end
      end
      DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff33ffccpf|cffffffffQuest: MobInfo2 import done — units.data %d → %d (+%d).",
        before, after, after - before))
    end
    return
  end

  -- argument: harvester (import from Wowhead Looter wlUnit SavedVariable)
  if arg1 == "harvester" then
    if type(wlUnit) ~= "table" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Wowhead Looter not found (wlUnit missing). Install it from CurseForge.")
      return
    end
    if pfHarvester and pfHarvester.importWowheadLooter then
      local before = 0
      if pfDB and pfDB["units"] and pfDB["units"]["data"] then
        for _ in pairs(pfDB["units"]["data"]) do before = before + 1 end
      end
      pfHarvester.importWowheadLooter()
      local after = 0
      if pfDB and pfDB["units"] and pfDB["units"]["data"] then
        for _ in pairs(pfDB["units"]["data"]) do after = after + 1 end
      end
      DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff33ffccpf|cffffffffQuest: Wowhead Looter import done — units.data %d → %d (+%d).",
        before, after, after - before))
    end
    return
  end

  -- argument: pindump (inspect live world map pin state for debugging)
  -- argument: nptrace (toggle nameplate event tracing to confirm NAME_PLATE_UNIT_ADDED fires)
  -- argument: guidcheck (show GUID and registration status of current target)
  -- argument: searchtest (directly call SearchQuestID for quest 28374 and show node result)
  if arg1 == "searchtest" then
    local qid = tonumber(arg2) or 28374
    local lines = { "=== SearchQuestID Test [" .. qid .. "] ===" }
    local function add(s) table.insert(lines, s) end
    -- Count nodes before
    local before = 0
    if pfMap and pfMap.nodes then
      for a,ad in pairs(pfMap.nodes) do for m,md in pairs(ad) do for c,_ in pairs(md) do before=before+1 end end end
    end
    add("nodes before: " .. before)
    -- Run SearchQuestID
    local meta = { ["addon"] = "PFQUEST" }
    local ok, err = pcall(pfDatabase.SearchQuestID, pfDatabase, qid, meta)
    add("SearchQuestID ok=" .. tostring(ok) .. (ok and "" or " err="..tostring(err)))
    -- Count nodes after
    local after = 0
    if pfMap and pfMap.nodes then
      for a,ad in pairs(pfMap.nodes) do for m,md in pairs(ad) do for c,cd in pairs(md) do
        after=after+1
        for title,_ in pairs(cd) do add("  node: addon="..a.." map="..m.." coords="..c.." title="..title) end
      end end end
    end
    add("nodes after: " .. after)
    if pfDiag and pfDiag.showWindow then pfDiag.showWindow(lines)
    else for _,l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(l) end end
    return
  end

  if arg1 == "guidcheck" then
    local lines = { "=== GUID / Registration Check ===" }
    local function add(s) table.insert(lines, s) end
    local found_unit = false
    for _, u in ipairs({ "target", "mouseover", "npc" }) do
      if not found_unit and UnitExists(u) then
        found_unit = true
        local guid = UnitGUID(u)
        local name = UnitName(u) or "?"
        local lname = string.lower(name)
        local kind = guid and string.match(guid, "^(%a+)-") or "?"
        -- Parse npcID
        local npcID = nil
        if guid then
          local a,b,c,d,e,f,g = string.match(guid, "(%a+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)")
          add("  raw guid='"..tostring(guid).."'")
          add("  match: a="..tostring(a).." b="..tostring(b).." c="..tostring(c).." d="..tostring(d).." e="..tostring(e).." f="..tostring(f).." g="..tostring(g))
          npcID = tonumber(f)
        end
        add("unit='"..u.."'  name='"..name.."'  kind="..kind.."  npcID="..tostring(npcID))
        -- Registration
        if npcID then
          local inData = pfDB and pfDB["units"] and pfDB["units"]["data"] and pfDB["units"]["data"][npcID]
          local inLoc  = pfDB and pfDB["units"] and pfDB["units"]["loc"]  and pfDB["units"]["loc"][npcID]
          add("  units.data: "..(inData and ("YES (coords="..#inData["coords"]..") lvl="..tostring(inData["lvl"])) or "NO"))
          if inData and inData["coords"] then
            for ci, coord in ipairs(inData["coords"]) do
              add("    coord["..ci.."]: x="..string.format("%.2f",coord[1] or 0).." y="..string.format("%.2f",coord[2] or 0).." pfZone="..tostring(coord[3]))
            end
          end
          add("  units.loc: "..(inLoc and ("YES ('"..inLoc.."')") or "NO"))
          -- wantedNames
          local wn = pfRetailRuntime and pfRetailRuntime.wantedNames
          local linkedQuest = wn and wn[lname]
          add("  wantedNames['"..lname.."']: "..(linkedQuest and ("questID="..tostring(linkedQuest)) or "NO"))
          if linkedQuest then
            local qdata = pfDB and pfDB["quests"] and pfDB["quests"]["data"] and pfDB["quests"]["data"][linkedQuest]
            if qdata then
              local objU = qdata["obj"] and qdata["obj"]["U"]
              if objU then
                local linked = false
                for _, uid in ipairs(objU) do
                  if uid then
                    add("  quest["..linkedQuest.."].obj.U: npcID="..tostring(uid)..(uid==npcID and " <-- THIS NPC" or ""))
                    if uid == npcID then linked = true end
                  end
                end
                if not linked then add("  WARNING: npcID "..tostring(npcID).." NOT in obj.U — link missing!") end
              else
                add("  quest["..tostring(linkedQuest).."].obj.U: NIL — link never formed!")
              end
            else
              add("  quest["..tostring(linkedQuest).."]: NOT in pfDB.quests.data")
            end
          end
        end
        -- Node check
        local nodeCount = 0
        if pfMap and pfMap.nodes then
          for addon, aData in pairs(pfMap.nodes) do
            for mapID, mData in pairs(aData) do
              for coords, nData in pairs(mData) do
                for title, _ in pairs(nData) do
                  if string.find(string.lower(title), lname, 1, true) then
                    nodeCount = nodeCount + 1
                    add("  node: addon="..addon.." mapID="..tostring(mapID).." coords="..coords.." title="..title)
                  end
                end
              end
            end
          end
        end
        if nodeCount == 0 then add("  nodes: NONE (not in pfMap.nodes)") end
        -- Zone
        local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local pfZoneID = uiMapID and pfQuest and pfQuest.retailZoneMap and pfQuest.retailZoneMap[uiMapID]
        add("  player uiMapID="..tostring(uiMapID).."  pfZoneID="..tostring(pfZoneID))
      end
    end
    if not found_unit then add("No valid unit found (target/mouseover/npc)") end
    if pfDiag and pfDiag.showWindow then pfDiag.showWindow(lines)
    else for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(l) end end
    return
  end

  if arg1 == "nptrace" then
    if not pfNPTrace then
      pfNPTrace = { count = 0, frame = CreateFrame("Frame") }
      pfNPTrace.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
      pfNPTrace.frame:SetScript("OnEvent", function(self, event, unitToken)
        pfNPTrace.count = pfNPTrace.count + 1
        local name = unitToken and UnitName(unitToken) or "?"
        local guid = unitToken and UnitGUID(unitToken) or "?"
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
          "|cff33ffccNPTrace|r [%d] %s  guid=%s", pfNPTrace.count, name, tostring(guid)))
      end)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Nameplate trace ON — move near NPCs.")
    else
      pfNPTrace.frame:UnregisterAllEvents()
      pfNPTrace = nil
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Nameplate trace OFF.")
    end
    return
  end

  if arg1 == "pindump" then
    local lines = { "=== Map Pin State ===" }
    local function add(s) table.insert(lines, s) end
    -- Canvas frame dimensions
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    local child = sc and sc.Child
    add("WorldMapFrame:       " .. (WorldMapFrame and WorldMapFrame:GetWidth().."x"..WorldMapFrame:GetHeight() or "NIL"))
    add("  screen pos TOPLEFT: " .. (WorldMapFrame and WorldMapFrame:GetLeft()..", "..WorldMapFrame:GetTop() or "NIL"))
    add("ScrollContainer:     " .. (sc and sc:GetWidth().."x"..sc:GetHeight() or "NIL"))
    add("  screen pos TOPLEFT: " .. (sc and sc:GetLeft()..", "..sc:GetTop() or "NIL"))
    add("ScrollContainer.Child: " .. (child and child:GetWidth().."x"..child:GetHeight() or "NIL"))
    add("  screen pos TOPLEFT: " .. (child and child:GetLeft()..", "..child:GetTop() or "NIL"))
    add("UIParent: " .. UIParent:GetWidth().."x"..UIParent:GetHeight())
    -- Walk all children of ScrollContainer looking for the map art frame
    if sc then
      if sc and child then
      local offsetX = (child:GetLeft() or 0) - (sc:GetLeft() or 0)
      local offsetY = (child:GetTop() or 0) - (sc:GetTop() or 0)
      add(string.format("Child offset in SC: %.1f, %.1f  (0,0 = fully panned to top-left)", offsetX, offsetY))
      add(string.format("Expected pin Y in SC viewport: %.1f%% * %.0f + %.1f = %.1fpx from SC top",
        32.11, child:GetHeight(), -offsetY, 32.11/100*child:GetHeight() - offsetY))
    end
    add("ScrollContainer children:")
      for i, f in ipairs({sc:GetChildren()}) do
        local n = f:GetName() or "(unnamed)"
        add(string.format("  [%d] %s  %dx%d  shown=%s  strata=%s  level=%d",
          i, n, f:GetWidth(), f:GetHeight(), tostring(f:IsShown()),
          tostring(f:GetFrameStrata()), f:GetFrameLevel()))
        if i >= 8 then add("  ..."); break end
      end
    end
    -- Pins
    local pinCount = pfMap.pins and #pfMap.pins or 0
    add("pfMap.pins count: " .. pinCount)
    for i = 1, math.min(pinCount, 10) do
      local p = pfMap.pins[i]
      if p then
        local shown = p:IsShown()
        local px, py = p:GetCenter()
        local fl = p:GetFrameLevel()
        local parent = p:GetParent() and p:GetParent():GetName() or "unnamed"
        add(string.format("  pin[%d]: shown=%s  center=%.0f,%.0f  level=%d  strata=%s  parent=%s  color=%s",
          i, tostring(shown), px or 0, py or 0, fl or 0, tostring(p:GetFrameStrata()), parent, tostring(p.color)))
      end
    end
    -- Node data
    local nodeCount = 0
    local curMap = pfMap:GetCurrentMapID()
    add("Current pfMapID: " .. tostring(curMap))
    if pfMap.nodes then
      for addon, aData in pairs(pfMap.nodes) do
        for mapID, mData in pairs(aData) do
          for coords, _ in pairs(mData) do
            nodeCount = nodeCount + 1
            if nodeCount <= 5 then
              add(string.format("  node: addon=%s  mapID=%d  coords=%s", addon, mapID, coords))
            end
          end
        end
      end
    end
    add("Total node entries: " .. nodeCount)
    if pfDiag and pfDiag.showWindow then pfDiag.showWindow(lines)
    else for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(l) end end
    return
  end

  if arg1 == "npccache" then
    if arg2 == "clear" then
      pfQuest_npcCache = nil
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: NPC cache cleared. Positions will rebuild from scratch on next login.")
    else
      local cc = (type(pfQuest_npcCache) == "table") and (pfQuest_npcCache.data and 0 or 0) or 0
      if type(pfQuest_npcCache) == "table" and pfQuest_npcCache.data then
        for _ in pairs(pfQuest_npcCache.data) do cc = cc + 1 end
      end
      local uc = 0
      if pfDB and pfDB["units"] and pfDB["units"]["data"] then
        for _ in pairs(pfDB["units"]["data"]) do uc = uc + 1 end
      end
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: NPC cache — " .. cc .. " saved, " .. uc .. " in session. Use /db npccache clear to reset.")
    end
    return
  end

  -- argument: queststatus (check single quest completion)
  if (arg1 == "queststatus") and arg2 then
    local qid = tonumber(arg2)
    if qid then
      local checkFn = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
      local done = checkFn and checkFn(qid)
      local inLog = C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(qid)
      local title = (pfDB["quests"]["loc"][qid] and pfDB["quests"]["loc"][qid].T)
                 or (type(pfDB["quests"]["loc"][qid]) == "string" and pfDB["quests"]["loc"][qid])
                 or ("Quest #" .. qid)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: " .. title)
      DEFAULT_CHAT_FRAME:AddMessage("  Completed: " .. (done and "|cff33ff33YES|r" or "|cffff3333NO|r"))
      DEFAULT_CHAT_FRAME:AddMessage("  In quest log: " .. (inLog and "|cff33ff33YES|r" or "|cffaaaaaa NO|r"))
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Usage: /db queststatus <questID>")
    end
    return
  end

  -- argument: quests
  if (arg1 == "quests") then
    pfDatabase:SearchQuests(meta)
    pfMap:UpdateNodes()
    -- open world map to show the results
    if OpenWorldMap then
      OpenWorldMap()
    elseif ToggleWorldMap and not WorldMapFrame:IsShown() then
      ToggleWorldMap()
    end
    return
  end

  -- argument: track
  if (arg1 == "track" or arg1 == "meta") then
    local list = commandlist[2]

    -- show available lists
    if not list or list == "" then
      local available = nil
      for list in pairs(pfDB["meta"]) do
        available = (available and available .. ", " or "") .. "\"|cff33ffcc"..list.."|r\""
      end

      DEFAULT_CHAT_FRAME:AddMessage(string.format(pfQuest_Loc["Available tracking targets are: %s. Or type \"|cff33ffcc/db track clean|r\" to untrack all."], available))
      return
    end

    -- clean all tracking results
    if commandlist[2] == "clean" then
      for list in pairs(pfDB["meta"]) do
        pfDatabase:TrackMeta(list, false)
      end

      return
    end

    -- load arguments into state
    local state = {
      min = commandlist[3],
      max = commandlist[4],
      faction = commandlist[3],
    }

    -- read skill for auto mines
    if (list == "mines" and commandlist[3] == "auto") then
      state.max = pfDatabase:GetPlayerSkill(186) or 0
      state.min = state.max - 100
    end

    -- read skill for auto herbs
    if (list == "herbs" and commandlist[3] == "auto") then
      state.max = pfDatabase:GetPlayerSkill(182) or 0
      state.min = state.max - 100
    end

    -- clean specific list
    if commandlist[3] == "clean" then
      state = nil
    end

    -- perform tracking
    local maps = pfDatabase:TrackMeta(list, state)
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- warn about deprecated arguments
  local deprecated = {
    ["chests"] = true, ["taxi"] = true, ["flights"] = true, ["rares"] = true, ["mines"] = true, ["herbs"] = true
  }

  if deprecated[arg1] then
    DEFAULT_CHAT_FRAME:AddMessage(string.format(pfQuest_Loc["|cffffcc00WARNING:|r The command \"|cff33ffcc/db %s|r\" is deprecated and will be removed soon. Please use the \"|cff33ffcc/db track %s|r\" instead to achieve the same functionality."], arg1, arg1))
  end

  -- argument: chests (deprecated)
  if (arg1 == "chests") then
    local state = true

    if commandlist[2] == "clean" then
      state = nil
    end

    local maps = pfDatabase:TrackMeta("chests", state)
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: taxi (deprecated)
  if (arg1 == "flights" or arg1 == "taxi") then
    local state = {
      faction = commandlist[2],
    }

    if commandlist[2] == "clean" then
      state = nil
    end

    local maps = pfDatabase:TrackMeta("flight", state)
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: rares (deprecated)
  if (arg1 == "rares") then
    local state = {
      min = commandlist[2],
      max = commandlist[3],
    }

    if commandlist[2] == "clean" then
      state = nil
    end

    local maps = pfDatabase:TrackMeta("rares", state)
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: mines (deprecated)
  if (arg1 == "mines") then
    local state = {
      min = commandlist[2],
      max = commandlist[3],
    }

    if (arg2 == "auto") then
      state.max = pfDatabase:GetPlayerSkill(186) or 0
      state.min = state.max - 100
    end

    if commandlist[2] == "clean" then
      state = nil
    end

    state = commandlist[2] == "clean" and nil or state
    local maps = pfDatabase:TrackMeta("mines", state)
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: herbs (deprecated)
  if (arg1 == "herbs") then
    local state = {
      min = commandlist[2],
      max = commandlist[3],
    }

    if (arg2 == "auto") then
      state.max = pfDatabase:GetPlayerSkill(182) or 0
      state.min = state.max - 100
    end

    if commandlist[2] == "clean" then
      state = nil
    end

    state = commandlist[2] == "clean" and nil or state
    local maps = pfDatabase:TrackMeta("herbs", state)
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))
    return
  end

  -- argument: clean
  if (arg1 == "clean") then
    pfMap:DeleteNode("PFDB")
    pfMap:UpdateNodes()
    return
  end

  -- argument: reset
  if (arg1 == "reset") then
    pfQuest:ResetAll()
    return
  end

  -- argument: show
  if (arg1 == "show") then
    if pfDiag then pfDiag.log("/db show: pfBrowser=" .. tostring(pfBrowser)) end
    if pfBrowser then
      local ok, err = pcall(function() pfBrowser:Show() end)
      if pfDiag then pfDiag.log("/db show result: " .. tostring(ok) .. " " .. tostring(err)) end
    end
    return
  end

  -- argument: tracker
  if (arg1 == "tracker") then
    if pfQuest.tracker then pfQuest.tracker:Show() end
    return
  end

  -- argument: lock
  if (arg1 == "lock") then
    pfQuest_config.lock = not pfQuest_config.lock
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest Tracker: " .. ( pfQuest_config.lock and "Locked" or "Unlocked" ))
    return
  end

  -- argument: journal
  if (arg1 == "journal") then
    if pfJournal then pfJournal:Show() end
    return
  end

  -- argument: arrow
  if (arg1 == "arrow") then
    if pfQuest_config["arrow"] == "1" then
      pfQuest_config["arrow"] = "0"
      pfQuest.route.arrow:Hide()
    else
      pfQuest_config["arrow"] = "1"
    end
    return
  end

  -- argument: show
  if (arg1 == "config") then
    if pfQuestConfig then pfQuestConfig:Show() end
    return
  end

  -- argument: locale
  if (arg1 == "locale") then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc" .. pfQuest_Loc["Locales"] .. "|r:" .. pfDatabase.dbstring)
    return
  end

  -- argument: scan
  if (arg1 == "scan") then
    pfDatabase:ScanServer()
    return
  end

    -- argument: query
  if (arg1 == "query") then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Starting quest completion scan...")
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa(This checks all quests in the database against your character's completion history)")
    pfDatabase:QueryServer()
    return
  end


  -- argument: dbinfo — live DB state snapshot in a copyable window
  if (arg1 == "dbinfo") then
    local function count(t)
      if type(t) ~= "table" then return 0 end
      local n = 0; for _ in pairs(t) do n = n + 1 end; return n
    end
    local lines = {}
    local function add(s) table.insert(lines, s) end
    local bar = "----------------------------------------"

    add("=== pfQuest DB State Snapshot (" .. date("%H:%M:%S") .. ") ===")
    add(bar)

    -- ── 1. pfDB table sizes ──────────────────────────────────────────────
    add("pfDB table sizes:")
    local dbtables = { "quests", "units", "objects", "items", "zones", "refloot", "minimap", "meta", "areatrigger" }
    for _, name in ipairs(dbtables) do
      if pfDB[name] then
        if name == "minimap" or name == "areatrigger" then
          add(string.format("  pfDB[%-12s]: %d entries", name, count(pfDB[name])))
        else
          local dc = count(pfDB[name]["data"] or {})
          local lc = count(pfDB[name]["loc"]  or {})
          add(string.format("  pfDB[%-12s]: data=%-6d  loc=%d", name, dc, lc))
        end
      else
        add("  pfDB[" .. name .. "]: NIL")
      end
    end

    -- ── 2. Upvalue identity (are database.lua locals stale?) ─────────────
    add(bar)
    add("Upvalue identity (database.lua locals vs live pfDB):")
    if pfDatabase and pfDatabase.GetUpvalueStatus then
      local status = pfDatabase:GetUpvalueStatus()
      for _, row in ipairs(status) do add("  " .. row) end
    else
      add("  (pfDatabase.GetUpvalueStatus not available)")
    end
    -- wantedNames index (objective mob names awaiting NPC interaction)
    if pfRetailRuntime and pfRetailRuntime.wantedNames then
      local wc = count(pfRetailRuntime.wantedNames)
      add("  wantedNames index: " .. wc .. " objective mob name(s) indexed"
        .. (wc > 0 and " (pins appear on first NPC sight)" or ""))
    end
    -- npcCache (cross-session NPC position persistence)
    if pfQuest_npcCache and type(pfQuest_npcCache) == "table" then
      local cc = count(pfQuest_npcCache.data or {})
      add("  npcCache (saved): " .. cc .. " NPC(s) from previous sessions"
        .. (cc > 0 and " — units.data pre-seeded at login" or ""))
    else
      add("  npcCache (saved): empty — will be written on logout")
    end
    -- MobInfo2 integration
    local mi2modern = type(MI2_DB) == "table" and type(MI2_DB.location) == "table"
    local mi2legacy = type(MobInfoDB) == "table"
    if mi2modern or mi2legacy then
      local parts = {}
      if mi2modern then
        local mc = 0; for _ in pairs(MI2_DB.location) do mc = mc + 1 end
        table.insert(parts, mc .. " NPCs in MI2_DB (retail)")
      end
      if mi2legacy then
        local lc = 0
        for k in pairs(MobInfoDB) do if k ~= "DatabaseVersion:0" then lc = lc + 1 end end
        if lc > 0 then table.insert(parts, lc .. " mobs in MobInfoDB (legacy)") end
      end
      add("  MobInfo2: " .. table.concat(parts, " + ") .. " — /db mobinfo2 to re-import")
    else
      add("  MobInfo2: not installed (optional — adds historic NPC coords)")
    end

    -- Wowhead Looter harvester
    if type(wlUnit) == "table" then
      local wlCount = 0
      for _ in pairs(wlUnit) do wlCount = wlCount + 1 end
      add("  Wowhead Looter: " .. wlCount .. " NPCs in wlUnit — /db harvester to re-import")
    else
      add("  Wowhead Looter: not installed (optional — adds NPC coords from your session history)")
    end

    -- ── 3. pfMap.nodes summary ────────────────────────────────────────────
    add(bar)
    add("pfMap.nodes (render queue):")
    if pfMap and pfMap.nodes then
      local totalNodes = 0
      for addon, zoneData in pairs(pfMap.nodes) do
        local addonNodes = 0
        for _, coordData in pairs(zoneData) do
          for _, titleData in pairs(coordData) do
            for _ in pairs(titleData) do addonNodes = addonNodes + 1 end
          end
        end
        totalNodes = totalNodes + addonNodes
        add(string.format("  [%-10s] %d nodes in %d zones", addon, addonNodes, count(zoneData)))
      end
      add("  Total: " .. totalNodes .. " nodes")
      if totalNodes == 0 then
        local ucount = count(pfDB["units"] and pfDB["units"]["data"] or {})
        local qcount = count(pfDB["quests"] and pfDB["quests"]["data"] or {})
        if qcount == 0 then
          add("  -> No quests in pfDB yet (runtime_db scan pending or failed)")
        elseif ucount == 0 then
          add("  -> " .. qcount .. " quests known but units.data=0")
          add("     Nodes appear once objective NPCs enter your view (nameplates),")
          add("     or when you target/mouse over them. Move toward quest area.")
          add("     After any NPC interaction, run /db dbinfo to see units grow.")
        else
          add("  -> " .. qcount .. " quests + " .. ucount .. " units registered")
          add("     No NPC-quest links yet. Links form as objective mob names match units.")
        end
      end
    else
      add("  pfMap.nodes not available")
    end

    -- ── 3b. Quest entry sample (first 5) ────────────────────────────────────
    add(bar)
    add("Quest DB sample (up to 5 entries):")
    local qsample = 0
    for qid, qdata in pairs(pfDB["quests"] and pfDB["quests"]["data"] or {}) do
      if qsample >= 5 then break end
      local loc = pfDB["quests"]["loc"] and pfDB["quests"]["loc"][qid]
      local title = (loc and loc["T"]) or "?"
      local parts = {}
      if qdata["start"] then
        table.insert(parts, "start:" .. (qdata["start"]["U"] and "U" or "") .. (qdata["start"]["O"] and "O" or ""))
      end
      if qdata["end"] then
        table.insert(parts, "end:" .. (qdata["end"]["U"] and "U" or "") .. (qdata["end"]["O"] and "O" or ""))
      end
      if qdata["obj"] then
        local ou = qdata["obj"]["U"] and ("#U=" .. #qdata["obj"]["U"]) or ""
        table.insert(parts, "obj:" .. ou)
      end
      local links = #parts > 0 and table.concat(parts, " ") or "no NPC links"
      add(string.format("  [%6d] lvl=%-4s %-30s %s", qid, tostring(qdata["lvl"] or "?"), title:sub(1,30), links))
      qsample = qsample + 1
    end
    if qsample == 0 then add("  (empty)") end

    -- ── 4. Current zone ───────────────────────────────────────────────────
    add(bar)
    add("Current zone:")
    local curMapID = pfMap and pfMap:GetCurrentMapID()
    local curZoneName = (curMapID and pfDB["zones"] and pfDB["zones"]["loc"] and pfDB["zones"]["loc"][curMapID]) or "?"
    add("  pfID=" .. tostring(curMapID) .. "  name=" .. tostring(curZoneName))
    if curMapID and pfMap and pfMap.nodes then
      local zoneNodeCount = 0
      for _, zoneData in pairs(pfMap.nodes) do
        if zoneData[curMapID] then
          for _, coordData in pairs(zoneData[curMapID]) do
            for _ in pairs(coordData) do zoneNodeCount = zoneNodeCount + 1 end
          end
        end
      end
      add("  Nodes in current zone: " .. zoneNodeCount)
    end

    -- ── 5. pfQuest_history ────────────────────────────────────────────────
    add(bar)
    add("pfQuest_history: " .. count(pfQuest_history or {}) .. " completed quest IDs")

    -- ── 6. retailZoneMap ──────────────────────────────────────────────────
    add(bar)
    add("retailZoneMap:")
    if pfQuest and type(pfQuest.retailZoneMap) == "table" then
      add("  " .. count(pfQuest.retailZoneMap) .. " uiMapID->pfID mappings installed")
      if C_Map and C_Map.GetBestMapForUnit then
        local uid  = C_Map.GetBestMapForUnit("player")
        local pfid = pfQuest.retailZoneMap[uid]
        add("  Player uiMapID=" .. tostring(uid) .. " -> pfID=" .. tostring(pfid))
      end
    elseif pfQuest and pfQuest.retailZoneMap == 0 then
      add("  retailZoneMap=0 (zone bridge not installed / pfQuest-retail-db missing)")
    else
      add("  retailZoneMap not available")
    end

    -- ── 7. World map canvas ────────────────────────────────────────────────
    add(bar)
    add("World map canvas:")
    local canvas = WorldMapButton
      or (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
    local mapOpen = WorldMapFrame and WorldMapFrame:IsShown()
    if canvas then
      local w = math.floor(canvas:GetWidth()  or 0)
      local h = math.floor(canvas:GetHeight() or 0)
      local sizeNote = (w == 0 and not mapOpen) and " (0x0 expected — map is closed)" or ""
      add(string.format("  Found: %s  size=%dx%d%s",
        tostring(canvas:GetName() or "(unnamed)"), w, h, sizeNote))
      if w == 0 and mapOpen then
        add("  WARNING: canvas has 0 width while map is open — pin positioning will fail")
      end
    else
      add("  NOT FOUND — WorldMapButton=nil, ScrollContainer.Child=nil")
      add("  World map pins cannot be positioned without a valid canvas")
      add("  Re-run /db dbinfo with the world map open to retest")
    end

    -- ── 8. minimap sizes for current zone ────────────────────────────────
    add(bar)
    add("Minimap dimensions for current zone:")
    if curMapID and pfDB["minimap"] then
      local mm = pfDB["minimap"][curMapID]
      if mm then
        add(string.format("  pfDB[minimap][%d] = { %.1f, %.1f }", curMapID, mm[1] or 0, mm[2] or 0))
      else
        add("  No entry for pfID=" .. tostring(curMapID) .. " (placeholder 4266.7x2844.4 will be used)")
      end
    else
      add("  pfDB.minimap not available")
    end

    -- ── 9. Classic DB / Reload status ────────────────────────────────────
    add(bar)
    add("Classic DB loaded: " .. (pfQuestRetail_ClassicDBLoaded and "YES" or "NO (wiped at login — retail client)"))
    add("pfDatabase.Reload:  " .. (pfDatabase and pfDatabase.Reload  and "available" or "MISSING"))
    add(bar)
    add("Run /db dbinfo again after zone change or quest update to refresh.")

    -- Show in copyable window via diagnostic infrastructure
    if pfDiag and pfDiag.showWindow then
      pfDiag.showWindow(lines)
    else
      -- fallback: print to chat if diagnostic window not available
      for _, line in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa" .. line .. "|r")
      end
    end
    return
  end

  -- argument: <text>
  if (type(arg1)=="string") then
    if pfBrowser then
      pfBrowser:Show()
      pfBrowser.input:SetText((string.gsub(string.format("%s %s",arg1,arg2),"^%s*(.-)%s*$", "%1")))
    end
    return
  end
end

C_Timer.After(0, function() if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[diag] slashcmd.lua loaded|r") end end)
