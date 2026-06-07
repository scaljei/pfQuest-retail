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


  -- argument: dbinfo — live DB state snapshot for diagnosing data population issues
  if (arg1 == "dbinfo") then
    local function count(t)
      if type(t) ~= "table" then return 0 end
      local n = 0; for _ in pairs(t) do n = n + 1 end; return n
    end
    local function msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: " .. s) end
    local bar = "|cffaaaaaa----------------------------------------|r"

    msg(bar)
    msg("|cffffff00=== pfQuest DB State Snapshot ===|r")
    msg(bar)

    -- ── 1. pfDB table sizes ──────────────────────────────────────────────
    msg("|cffffff00pfDB table sizes:|r")
    local dbtables = { "quests", "units", "objects", "items", "zones", "refloot", "minimap", "meta", "areatrigger" }
    for _, name in ipairs(dbtables) do
      if pfDB[name] then
        if name == "minimap" or name == "areatrigger" then
          msg("  pfDB[" .. name .. "]: " .. count(pfDB[name]) .. " entries")
        else
          local dc = count(pfDB[name]["data"] or {})
          local lc = count(pfDB[name]["loc"] or {})
          msg("  pfDB[" .. name .. "].data=" .. dc .. "  .loc=" .. lc)
        end
      else
        msg("  pfDB[" .. name .. "]: |cffff3333NIL|r")
      end
    end

    -- ── 2. Upvalue identity check — are database.lua locals stale? ──────
    msg(bar)
    msg("|cffffff00Upvalue identity (database.lua):|r")
    if pfDatabase and pfDatabase.CheckUpvalues then
      pfDatabase:CheckUpvalues()
    else
      msg("  |cffaaaaaa(pfDatabase.CheckUpvalues not available — add to database.lua)|r")
      msg("  Workaround: pfDatabase.Reload() forces upvalue refresh")
    end

    -- ── 3. pfMap.nodes summary ───────────────────────────────────────────
    msg(bar)
    msg("|cffffff00pfMap.nodes summary:|r")
    if pfMap and pfMap.nodes then
      local totalNodes = 0
      for addon, zoneData in pairs(pfMap.nodes) do
        local addonNodes = 0
        for zoneID, coordData in pairs(zoneData) do
          for coords, titleData in pairs(coordData) do
            for _ in pairs(titleData) do addonNodes = addonNodes + 1 end
          end
        end
        totalNodes = totalNodes + addonNodes
        msg("  [" .. tostring(addon) .. "] " .. addonNodes .. " nodes across " .. count(zoneData) .. " zones")
      end
      msg("  Total: " .. totalNodes .. " nodes")
    else
      msg("  |cffff3333pfMap.nodes not available|r")
    end

    -- ── 4. Current zone and its nodes ────────────────────────────────────
    msg(bar)
    msg("|cffffff00Current zone:|r")
    local curMapID = pfMap and pfMap:GetCurrentMapID()
    local curZoneName = curMapID and pfDB["zones"]["loc"] and pfDB["zones"]["loc"][curMapID] or "?"
    msg("  pfID=" .. tostring(curMapID) .. "  name=" .. tostring(curZoneName))
    if curMapID and pfMap and pfMap.nodes then
      local zoneNodeCount = 0
      for addon, zoneData in pairs(pfMap.nodes) do
        if zoneData[curMapID] then
          for coords, titleData in pairs(zoneData[curMapID]) do
            for _ in pairs(titleData) do zoneNodeCount = zoneNodeCount + 1 end
          end
        end
      end
      msg("  Nodes in current zone: " .. zoneNodeCount)
    end

    -- ── 5. pfQuest_history ───────────────────────────────────────────────
    msg(bar)
    msg("|cffffff00pfQuest_history:|r")
    local histCount = count(pfQuest_history or {})
    msg("  " .. histCount .. " completed quest IDs stored")

    -- ── 6. retailZoneMap ─────────────────────────────────────────────────
    msg(bar)
    msg("|cffffff00retailZoneMap:|r")
    if pfQuest and pfQuest.retailZoneMap and type(pfQuest.retailZoneMap) == "table" then
      msg("  " .. count(pfQuest.retailZoneMap) .. " uiMapID→pfID mappings installed")
      -- show current zone's mapping
      if C_Map and C_Map.GetBestMapForUnit then
        local uid = C_Map.GetBestMapForUnit("player")
        local pfid = pfQuest.retailZoneMap[uid]
        msg("  Player uiMapID=" .. tostring(uid) .. " → pfID=" .. tostring(pfid))
      end
    elseif pfQuest and pfQuest.retailZoneMap == 0 then
      msg("  |cffff3333retailZoneMap=0 (zone bridge not installed — pfQuest-retail-db missing?)|r")
    else
      msg("  |cffff3333retailZoneMap not available|r")
    end

    -- ── 7. World map canvas check ─────────────────────────────────────────
    msg(bar)
    msg("|cffffff00World map canvas:|r")
    local canvas = WorldMapButton
      or (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
    if canvas then
      msg("  Found: " .. tostring(canvas:GetName() or "(unnamed)") ..
          "  size=" .. math.floor(canvas:GetWidth() or 0) .. "x" .. math.floor(canvas:GetHeight() or 0))
    else
      msg("  |cffff3333Canvas not found — WorldMapButton=nil, ScrollContainer.Child=nil|r")
      msg("  Nodes cannot be positioned on world map")
    end

    -- ── 8. pfDB.Reload status ─────────────────────────────────────────────
    msg(bar)
    msg("|cffffff00Classic DB loaded: |r" ..
      (pfQuestRetail_ClassicDBLoaded and "|cff33ff33YES|r" or "|cffaaaaaa NO (retail client — wiped at login)|r"))
    msg("|cffffff00pfDatabase.Reload exists: |r" ..
      (pfDatabase and pfDatabase.Reload and "|cff33ff33YES|r" or "|cffff3333NO|r"))

    msg(bar)
    msg("Run |cff33ffcc/db dbinfo|r again after zone change or quest update to refresh.")
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
