-- pfQuest-retail diagnostic logger
-- Writes a diagnostic report to SavedVariables: pfQuest_diagnostic
-- View with: /pfdiag  or check pfQuest_diagnostic in SavedVariables file

pfQuest_diagnostic = pfQuest_diagnostic or {}

local diag = pfQuest_diagnostic
diag.log = diag.log or {}
diag.errors = diag.errors or {}

local startTime = GetTime()

local function ts()
  return string.format("[%.1fs]", GetTime() - startTime)
end

local function dlog(msg)
  table.insert(diag.log, ts() .. " " .. tostring(msg))
  -- Keep last 200 entries
  while #diag.log > 200 do table.remove(diag.log, 1) end
end

local function derr(msg)
  table.insert(diag.errors, ts() .. " ERROR: " .. tostring(msg))
  dlog("ERROR: " .. tostring(msg))
end

-- Hook pcall-based error catcher for all SetScript handlers
local origSErr = seterrorhandler
if seterrorhandler then
  seterrorhandler(function(err)
    derr(tostring(err))
  end)
end

-- Capture all Lua errors via geterrorhandler
local prevHandler = geterrorhandler and geterrorhandler()
if seterrorhandler then
  seterrorhandler(function(err)
    derr(tostring(err))
    if prevHandler then prevHandler(err) end
  end)
end

-- Log key initialization events
local diagFrame = CreateFrame("Frame")
diagFrame:RegisterEvent("ADDON_LOADED")
diagFrame:RegisterEvent("PLAYER_LOGIN")
diagFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
diagFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

diagFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local addon = ...
    if addon and string.find(addon, "pfQuest") then
      dlog("ADDON_LOADED: " .. addon)
    end
  elseif event == "PLAYER_LOGIN" then
    dlog("PLAYER_LOGIN fired")
    dlog("pfQuestConfig: " .. tostring(pfQuestConfig))
    dlog("pfQuestConfig.path: " .. tostring(pfQuestConfig and pfQuestConfig.path))
    dlog("pfQuestConfig._initialized: " .. tostring(pfQuestConfig and pfQuestConfig._initialized))
    dlog("pfQuestMenu: " .. tostring(pfQuestMenu))
    dlog("pfQuest_config keys: " .. tostring(pfQuest_config and next(pfQuest_config)))
    dlog("BackdropTemplateMixin: " .. tostring(BackdropTemplateMixin ~= nil))
    dlog("retailZoneMap size: " .. tostring(pfQuest and pfQuest.retailZoneMap and (function() local n=0; for _ in pairs(pfQuest.retailZoneMap) do n=n+1 end; return n end)()))
  elseif event == "PLAYER_ENTERING_WORLD" then
    dlog("PLAYER_ENTERING_WORLD")
    -- Test CreateMenu by calling it with pcall
    C_Timer.After(1, function()
      dlog("--- Post-load state (1s) ---")
      dlog("pfQuestMenu: " .. tostring(pfQuestMenu))
      dlog("pfQuestConfig._initialized: " .. tostring(pfQuestConfig and pfQuestConfig._initialized))
      dlog("pfQuestConfig._progress: " .. tostring(pfQuestConfig and pfQuestConfig._progress))
      -- Test SetColorTexture exists
      local testf = CreateFrame("Frame", nil, UIParent)
      local testt = testf:CreateTexture()
      local ok, err = pcall(function() testt:SetColorTexture(1,0,0,1) end)
      dlog("SetColorTexture works: " .. tostring(ok) .. " " .. tostring(err))
      -- Test SetJustifyV
      local testfs = testf:CreateFontString(nil, "OVERLAY")
      local ok2, err2 = pcall(function() testfs:SetJustifyV("BOTTOM") end)
      dlog("SetJustifyV works: " .. tostring(ok2) .. " " .. tostring(err2))
      testf:Hide()
    end)
  end
end)

-- Slash command to dump diagnostic
SLASH_PFDIAG1 = "/pfdiag"
SlashCmdList["PFDIAG"] = function(input)
  if input == "clear" then
    pfQuest_diagnostic = { log = {}, errors = {} }
    diag = pfQuest_diagnostic
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfDiag:|r Cleared")
    return
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest Diagnostic Report|r")
  DEFAULT_CHAT_FRAME:AddMessage("Errors: " .. #diag.errors .. "  Log entries: " .. #diag.log)

  if input == "errors" or input == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900--- Recent Errors ---|r")
    local start = math.max(1, #diag.errors - 10)
    for i = start, #diag.errors do
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555" .. diag.errors[i] .. "|r")
    end
  end

  if input == "log" or input == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa--- Recent Log (last 20) ---|r")
    local start = math.max(1, #diag.log - 20)
    for i = start, #diag.log do
      DEFAULT_CHAT_FRAME:AddMessage("|cffcccccc" .. diag.log[i] .. "|r")
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa(Saved to pfQuest_diagnostic in SavedVariables)|r")
end

-- Make logger available globally
pfDiag = { log = dlog, err = derr }

-- Also wrap the original error handler to capture all Lua errors
local _origEH = geterrorhandler and geterrorhandler()
if seterrorhandler then
  seterrorhandler(function(msg)
    derr(tostring(msg))
    if _origEH then return _origEH(msg) end
  end)
end

dlog("diagnostic.lua loaded")
