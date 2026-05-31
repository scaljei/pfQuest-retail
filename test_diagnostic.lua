-- pfQuest-retail diagnostic tool
-- /pftest  - show all globals
-- /pftest2 - show config frame state  
-- /pftest5 - step through config.lua crash point

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00pfD:|r " .. tostring(s)) end
local function err(s) DEFAULT_CHAT_FRAME:AddMessage("|cffff0000pfERR:|r " .. tostring(s)) end

-- Register a test slash command at highest priority
SLASH_PFTEST1 = "/pftest"
SlashCmdList["PFTEST"] = function()
  msg("pfQuestConfig: " .. tostring(pfQuestConfig))
  msg("pfQuest_config: " .. tostring(pfQuest_config))
  msg("pfQuest: " .. tostring(pfQuest))
  msg("pfMap: " .. tostring(pfMap))
  msg("pfDB: " .. tostring(pfDB))
  msg("pfQuestCompat: " .. tostring(pfQuestCompat))
  msg("pfQuestConfig.path: " .. tostring(pfQuestConfig and pfQuestConfig.path))
  msg("pfQuestConfig._progress: " .. tostring(pfQuestConfig and pfQuestConfig._progress))
  msg("pfQuestConfig.CreateConfigEntries: " .. tostring(pfQuestConfig and type(pfQuestConfig.CreateConfigEntries)))
  msg("BackdropTemplateMixin: " .. tostring(BackdropTemplateMixin))
  msg("GetMouseFoci: " .. tostring(type(GetMouseFoci)))
end

SLASH_PFTEST21 = "/pftest2"
SlashCmdList["PFTEST2"] = function()
  msg("=== Config Frame ===")
  if not pfQuestConfig then err("pfQuestConfig is nil"); return end
  msg("shown: " .. tostring(pfQuestConfig:IsShown()))
  msg("size: " .. pfQuestConfig:GetWidth() .. "x" .. pfQuestConfig:GetHeight())
  msg("_progress: " .. tostring(pfQuestConfig._progress))
  msg("CreateConfigEntries: " .. type(pfQuestConfig.CreateConfigEntries or "nil"))
  local count = 0
  for _ in ipairs({pfQuestConfig:GetChildren()}) do count=count+1 end
  msg("children: " .. count)
  msg("minimap button shown: " .. tostring(pfQuestIcon and pfQuestIcon:IsShown()))
end

SLASH_PFTEST51 = "/pftest5"
SlashCmdList["PFTEST5"] = function()
  msg("=== Step test ===")
  -- Test 1: Can we create a FontString at all?
  local ok1, r1 = pcall(function()
    return pfQuestConfig:CreateFontString(nil, "OVERLAY")
  end)
  msg("FontString(nil,OVERLAY): " .. tostring(ok1) .. " -> " .. tostring(r1))

  -- Test 2: What does CreateBackdrop do?
  local ok2, r2 = pcall(function()
    pfUI.api.CreateBackdrop(pfQuestConfig, nil, true, 0.75)
  end)
  msg("CreateBackdrop: " .. tostring(ok2) .. " err=" .. tostring(r2))

  -- Test 3: Force define CreateConfigEntries if missing then call it
  if type(pfQuestConfig.CreateConfigEntries) ~= "function" then
    err("CreateConfigEntries missing - config.lua crashed before line 332")
    err("_progress=" .. tostring(pfQuestConfig._progress))
    
    -- Try to identify which SkinButton call crashes
    local ok3, r3 = pcall(pfUI.api.SkinButton, pfQuestConfig.close, 1, .5, .5)
    msg("SkinButton(close): " .. tostring(ok3) .. " " .. tostring(r3))
    local ok4, r4 = pcall(pfUI.api.SkinButton, pfQuestConfig.welcome)
    msg("SkinButton(welcome): " .. tostring(ok4) .. " " .. tostring(r4))
    local ok5, r5 = pcall(pfUI.api.SkinButton, pfQuestConfig.save)
    msg("SkinButton(save): " .. tostring(ok5) .. " " .. tostring(r5))
  else
    msg("CreateConfigEntries EXISTS - calling it now")
    local ok, r = pcall(pfQuestConfig.CreateConfigEntries, pfQuestConfig, pfQuest_defconfig)
    msg("CCE result: " .. tostring(ok) .. " " .. tostring(r))
    local count = 0
    for _ in ipairs({pfQuestConfig:GetChildren()}) do count=count+1 end
    msg("children after: " .. count)
  end
end

-- Auto-force init 3 seconds after login
local _init = CreateFrame("Frame")
_init:RegisterEvent("PLAYER_LOGIN")
_init:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  C_Timer.After(3, function()
    if pfQuestConfig and not pfQuestConfig._initialized then
      msg("Auto-forcing init...")
      local ok, e = pcall(function()
        pfQuestConfig:LoadConfig()
        pfQuestConfig:CreateConfigEntries(pfQuest_defconfig)
        pfQuestConfig._initialized = true
      end)
      if ok then
        local count = 0
        for _ in ipairs({pfQuestConfig:GetChildren()}) do count=count+1 end
        msg("Init OK, children=" .. count)
      else
        err("Init failed: " .. tostring(e))
      end
    end
  end)
end)
