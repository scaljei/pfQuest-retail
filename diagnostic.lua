-- pfQuest-retail diagnostic logger v2
-- Saves to SavedVariable: pfQuest_diagnostic (in WTF/Account/SERVER/CHAR/SavedVariables/)
-- Commands: /pfdiag, /pfdiag log, /pfdiag errors, /pfdiag clear, /pfdiag menu

pfQuest_diagnostic = pfQuest_diagnostic or { log={}, errors={}, session=0 }
pfQuest_diagnostic.session = (pfQuest_diagnostic.session or 0) + 1
pfQuest_diagnostic.log = pfQuest_diagnostic.log or {}
pfQuest_diagnostic.errors = pfQuest_diagnostic.errors or {}

local diag = pfQuest_diagnostic
local sessionID = diag.session
local startTime = GetTime()

local function ts() return string.format("[s%d %.1fs]", sessionID, GetTime()-startTime) end
local function dlog(m) local e=ts().." "..tostring(m); table.insert(diag.log,e); while #diag.log>500 do table.remove(diag.log,1) end end
local function derr(m) local e=ts().." ERR: "..tostring(m); table.insert(diag.errors,e); dlog("ERR: "..tostring(m)); while #diag.errors>200 do table.remove(diag.errors,1) end end

-- Hook error handler
local _prevEH = geterrorhandler and geterrorhandler()
if seterrorhandler then
  seterrorhandler(function(msg)
    derr(tostring(msg))
    if _prevEH then return _prevEH(msg) end
  end)
end

-- Event logging
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, ...)
  if event=="ADDON_LOADED" then
    local a=...; if a and a:find("pfQuest") then dlog("ADDON_LOADED: "..a) end
  elseif event=="PLAYER_LOGIN" then
    dlog("PLAYER_LOGIN")
    dlog("pfQuestMenu="..tostring(pfQuestMenu))
    dlog("pfDatabase="..tostring(pfDatabase))
    dlog("pfQuestConfig._initialized="..tostring(pfQuestConfig and pfQuestConfig._initialized))
    dlog("pfQuestConfig._progress="..tostring(pfQuestConfig and pfQuestConfig._progress))
    dlog("BackdropTemplateMixin="..tostring(BackdropTemplateMixin~=nil))
    -- Test APIs
    local t=CreateFrame("Frame",nil,UIParent)
    local tx=t:CreateTexture(nil,"OVERLAY")
    local ok,e=pcall(function() tx:SetColorTexture(1,0,0,1) end)
    dlog("SetColorTexture: "..tostring(ok).." "..(e or ""))
    local fs=t:CreateFontString(nil,"OVERLAY")
    ok,e=pcall(function() fs:SetJustifyV("BOTTOM") end)
    dlog("SetJustifyV(BOTTOM): "..tostring(ok).." "..(e or ""))
    ok,e=pcall(function() fs:SetJustifyV("MIDDLE") end)
    dlog("SetJustifyV(MIDDLE): "..tostring(ok).." "..(e or ""))
    t:Hide()
    C_Timer.After(2, function()
      dlog("--- 2s post-login ---")
      dlog("pfQuestMenu="..tostring(pfQuestMenu))
      dlog("pfQuestConfig.CreateConfigEntries="..type(pfQuestConfig and pfQuestConfig.CreateConfigEntries or "nil"))
      local zcount=0; if pfQuest and pfQuest.retailZoneMap then for _ in pairs(pfQuest.retailZoneMap) do zcount=zcount+1 end end
      dlog("retailZoneMap="..zcount)
    end)
  elseif event=="PLAYER_ENTERING_WORLD" then
    dlog("PLAYER_ENTERING_WORLD")
  end
end)

-- Slash command
SLASH_PFDIAG1="/pfdiag"
SlashCmdList["PFDIAG"]=function(input)
  local function p(s) DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc"..s.."|r") end
  if input=="clear" then
    pfQuest_diagnostic={log={},errors={},session=sessionID}
    diag=pfQuest_diagnostic
    p("Diagnostic cleared"); return
  end
  if input=="menu" then
    p("pfQuestMenu: "..tostring(pfQuestMenu))
    p("pfQuestIcon: "..tostring(pfQuestIcon))
    p("pfDatabase: "..tostring(pfDatabase))
    p("pfQuestConfig._progress: "..tostring(pfQuestConfig and pfQuestConfig._progress))
    if pfQuestMenu then
      p("pfQuestMenu shown: "..tostring(pfQuestMenu:IsShown()))
      p("pfQuestMenu size: "..pfQuestMenu:GetWidth().."x"..pfQuestMenu:GetHeight())
    end
    -- Try to open manually
    p("--- Forcing menu show ---")
    local ok,e=pcall(function()
      if pfQuestMenu then pfQuestMenu:Show() end
    end)
    p("Show result: "..tostring(ok).." "..(e or ""))
    return
  end
  p("=== pfQuest Diagnostic (session "..sessionID..") ===")
  p("Errors: "..#diag.errors.."  Log: "..#diag.log)
  p("--- Recent Errors ---")
  for i=math.max(1,#diag.errors-8),#diag.errors do
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555"..diag.errors[i].."|r")
  end
  if input=="log" then
    p("--- Log (last 30) ---")
    for i=math.max(1,#diag.log-30),#diag.log do
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa"..diag.log[i].."|r")
    end
  end
  p("(Saved in WTF SavedVariables as pfQuest_diagnostic)")
  p("Commands: /pfdiag log  /pfdiag menu  /pfdiag clear")
end

pfDiag={log=dlog,err=derr}
dlog("diagnostic.lua loaded (session "..sessionID..")")
