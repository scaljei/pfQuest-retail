-- Diagnostic: runs at file scope, prints immediately
local function pf_diag(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000pfDiag:|r " .. tostring(msg))
  end
end

-- Test 1: slash command registration
SLASH_PFTEST1 = "/pftest"
SlashCmdList["PFTEST"] = function(input)
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00pfQuest-retail ALIVE|r")
  DEFAULT_CHAT_FRAME:AddMessage("pfQuestConfig: " .. tostring(pfQuestConfig))
  DEFAULT_CHAT_FRAME:AddMessage("pfQuest_config: " .. tostring(pfQuest_config))
  DEFAULT_CHAT_FRAME:AddMessage("pfQuest: " .. tostring(pfQuest))
  DEFAULT_CHAT_FRAME:AddMessage("pfMap: " .. tostring(pfMap))
  DEFAULT_CHAT_FRAME:AddMessage("pfDB: " .. tostring(pfDB))
  DEFAULT_CHAT_FRAME:AddMessage("pfQuestCompat: " .. tostring(pfQuestCompat))
  DEFAULT_CHAT_FRAME:AddMessage("pfQuestConfig.path: " .. tostring(pfQuestConfig and pfQuestConfig.path))
  if pfQuest_config then
    DEFAULT_CHAT_FRAME:AddMessage("pfQuest_config keys: " .. tostring(next(pfQuest_config)))
  end
end

-- Enhanced test showing config state
SLASH_PFTEST21 = "/pftest2"
SlashCmdList["PFTEST2"] = function()
  DEFAULT_CHAT_FRAME:AddMessage("=== Config State ===")
  DEFAULT_CHAT_FRAME:AddMessage("pfQuestConfig shown: " .. tostring(pfQuestConfig and pfQuestConfig:IsShown()))
  DEFAULT_CHAT_FRAME:AddMessage("pfQuestConfig size: " .. tostring(pfQuestConfig and pfQuestConfig:GetWidth()) .. "x" .. tostring(pfQuestConfig and pfQuestConfig:GetHeight()))
  DEFAULT_CHAT_FRAME:AddMessage("pfQuestConfig children: " .. tostring(pfQuestConfig and select(2, pfQuestConfig:GetChildren())))
  local count = 0
  if pfQuestConfig then
    for _, child in ipairs({pfQuestConfig:GetChildren()}) do
      count = count + 1
      if count <= 5 then
        DEFAULT_CHAT_FRAME:AddMessage("  child " .. count .. ": " .. tostring(child:GetObjectType()) .. " shown=" .. tostring(child:IsShown()) .. " h=" .. tostring(child:GetHeight()))
      end
    end
  end
  DEFAULT_CHAT_FRAME:AddMessage("Total children: " .. count)
  DEFAULT_CHAT_FRAME:AddMessage("minimap button: " .. tostring(pfQuestIcon and pfQuestIcon:IsShown()))
end

SLASH_PFTEST31 = "/pftest3"
SlashCmdList["PFTEST3"] = function()
  DEFAULT_CHAT_FRAME:AddMessage("=== Init State ===")
  DEFAULT_CHAT_FRAME:AddMessage("pfQuestConfig._initialized: " .. tostring(pfQuestConfig and pfQuestConfig._initialized))
  DEFAULT_CHAT_FRAME:AddMessage("pfQuest._addonInitialized: " .. tostring(pfQuest and pfQuest._addonInitialized))
  DEFAULT_CHAT_FRAME:AddMessage("pfQuest_defconfig type: " .. tostring(type(pfQuest_defconfig)))
  DEFAULT_CHAT_FRAME:AddMessage("pfQuest_defconfig len: " .. tostring(pfQuest_defconfig and #pfQuest_defconfig))
  DEFAULT_CHAT_FRAME:AddMessage("pfUI.api.emulated: " .. tostring(pfUI and pfUI.api and pfUI.api.emulated))
  -- Force run CreateConfigEntries right now
  DEFAULT_CHAT_FRAME:AddMessage("--- Forcing CreateConfigEntries ---")
  local ok, err = pcall(function()
    pfQuestConfig:CreateConfigEntries(pfQuest_defconfig)
  end)
  DEFAULT_CHAT_FRAME:AddMessage("pcall result: " .. tostring(ok) .. " err: " .. tostring(err))
  local count = 0
  for _ in ipairs({pfQuestConfig:GetChildren()}) do count = count + 1 end
  DEFAULT_CHAT_FRAME:AddMessage("Children after force: " .. count)
end

-- Force init on PLAYER_LOGIN regardless of other handlers
local _forceInit = CreateFrame("Frame")
_forceInit:RegisterEvent("PLAYER_LOGIN")
_forceInit:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  C_Timer.After(2, function()  -- wait 2 seconds for everything to settle
    if pfQuestConfig and not pfQuestConfig._initialized then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555pfDiag: PLAYER_LOGIN fired but _initialized=false, forcing now|r")
      local ok, err = pcall(function()
        pfQuestConfig:LoadConfig()
        pfQuestConfig:CreateConfigEntries(pfQuest_defconfig)
        pfQuestConfig._initialized = true
      end)
      if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000pfDiag ERROR: " .. tostring(err) .. "|r")
      else
        local count = 0
        for _ in ipairs({pfQuestConfig:GetChildren()}) do count = count + 1 end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00pfDiag: CreateConfigEntries OK, children=" .. count .. "|r")
      end
    end
  end)
end)

SLASH_PFTEST41 = "/pftest4"
SlashCmdList["PFTEST4"] = function()
  DEFAULT_CHAT_FRAME:AddMessage("=== Line-by-line config.lua test ===")
  local tests = {
    {"CreateFontString", function()
      local fs = pfQuestConfig:CreateFontString(nil, "LOW")
      DEFAULT_CHAT_FRAME:AddMessage("  FontString: " .. tostring(fs))
    end},
    {"CreateConfigEntries exists", function()
      DEFAULT_CHAT_FRAME:AddMessage("  CCE type: " .. tostring(type(pfQuestConfig.CreateConfigEntries)))
    end},
    {"pfQuest_defconfig len", function()
      DEFAULT_CHAT_FRAME:AddMessage("  defconfig: " .. tostring(#pfQuest_defconfig))
    end},
    {"Force CCE", function()
      pfQuestConfig:CreateConfigEntries(pfQuest_defconfig)
      local count = 0
      for _ in ipairs({pfQuestConfig:GetChildren()}) do count=count+1 end
      DEFAULT_CHAT_FRAME:AddMessage("  children after CCE: " .. count)
    end},
  }
  for _, t in ipairs(tests) do
    local ok, err = pcall(t[2])
    if not ok then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FAIL " .. t[1] .. ": " .. tostring(err) .. "|r")
    end
  end
end
