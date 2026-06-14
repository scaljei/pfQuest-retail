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

  -- argument: mi2dump (inspect MI2_DB structure to find name fields)
  if arg1 == "mi2dump" then
    local lines = { "=== MI2 Link Diagnostic ===" }
    local function add(s) table.insert(lines, s) end

    -- 1. classicNPCNames snapshot
    local cnn = pfQuest and pfQuest.classicNPCNames
    if cnn then
      local c = 0; for _ in pairs(cnn) do c = c + 1 end
      add("classicNPCNames: " .. c .. " entries")
    else
      add("classicNPCNames: NIL (db_guard snapshot not built)")
    end

    -- 2. wantedNames
    local wn = pfRetailRuntime and pfRetailRuntime.wantedNames
    if wn then
      local c = 0; for _ in pairs(wn) do c = c + 1 end
      add("wantedNames: " .. c .. " entries")
      -- Show all wanted names and whether classicNPCNames resolves them
      for name, questID in pairs(wn) do
        local npcID = cnn and cnn[name]
        add(string.format("  '%s' (q%d) -> npcID=%s", name, questID, tostring(npcID)))
      end
    else
      add("wantedNames: NIL")
    end

    -- 3. retailZoneMap coverage for MI2 coords
    local rzm = pfQuest and pfQuest.retailZoneMap
    local rzmCount = 0
    if rzm then for _ in pairs(rzm) do rzmCount = rzmCount + 1 end end
    add("retailZoneMap: " .. rzmCount .. " uiMapID->pfID mappings")

    -- 4. How many MI2 coords are in mapped zones
    if type(MI2_DB) == "table" and type(MI2_DB.location) == "table" and rzm then
      local total, mapped = 0, 0
      for _, sourceData in pairs(MI2_DB.location) do
        if type(sourceData) == "table" then
          for mapID, coordList in pairs(sourceData) do
            if type(mapID) == "number" and type(coordList) == "table" then
              total = total + 1
              if rzm[mapID] then mapped = mapped + 1 end
            end
          end
        end
      end
      add(string.format("MI2 zone coverage: %d/%d coord-sets in mapped zones", mapped, total))
    end

    if pfDiag and pfDiag.showWindow then
      pfDiag.showWindow(lines)
    else
      for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(l) end
    end
    return
  end

  -- argument: objdump (dump raw GetQuestObjectives data for all active quests)
  if arg1 == "objdump" then
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: C_QuestLog not available.")
      return
    end
    local lines = { "=== Quest Objective Dump ===" }
    local n = C_QuestLog.GetNumQuestLogEntries()
    local shown = 0
    for i = 1, n do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID and shown < 10 then
        local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(info.questID)
        if objs and #objs > 0 then
          table.insert(lines, string.format("[%d] %s", info.questID, info.title or "?"))
          for _, obj in ipairs(objs) do
            table.insert(lines, string.format("  type=%s  text=%s  finished=%s",
              tostring(obj.type), tostring(obj.text), tostring(obj.finished)))
          end
          shown = shown + 1
        end
      end
    end
    if shown == 0 then
      table.insert(lines, "No quests with objectives found.")
    end
    if pfDiag and pfDiag.showWindow then
      pfDiag.showWindow(lines)
    else
      for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(l) end
    end
    return
  end

  -- argument: npccache (manage NPC position cache)
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
