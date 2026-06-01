-- pfQuest-retail diagnostic logger v4
-- /pfdiag         - show summary in chat
-- /pfdiag log     - show full log in scrollable window (copy-pasteable)
-- /pfdiag errors  - show only errors in window
-- /pfdiag clear   - clear log
-- /pfdiag menu    - test menu state

local _pendingLog = {}
local _ready = false

local function ts() return date("%H:%M:%S") end

local function dlog(m)
  local e = "[" .. ts() .. "] " .. tostring(m)
  if _ready and pfQuest_diagnostic then
    table.insert(pfQuest_diagnostic.log, e)
    while #pfQuest_diagnostic.log > 2000 do table.remove(pfQuest_diagnostic.log, 1) end
  else
    table.insert(_pendingLog, e)
  end
end

local function derr(m)
  local e = "[" .. ts() .. "] ERR: " .. tostring(m)
  if _ready and pfQuest_diagnostic then
    table.insert(pfQuest_diagnostic.errors, e)
    while #pfQuest_diagnostic.errors > 500 do table.remove(pfQuest_diagnostic.errors, 1) end
  end
  dlog("ERR: " .. tostring(m))
end

local _prevEH = geterrorhandler and geterrorhandler()
if seterrorhandler then
  seterrorhandler(function(msg)
    derr(tostring(msg))
    if _prevEH then return _prevEH(msg) end
  end)
end

-- ── Output window ─────────────────────────────────────────────────────────
local diagWin = nil

local function createDiagWindow()
  if diagWin then diagWin:Show() return end

  diagWin = CreateFrame("Frame", "pfDiagWindow", UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  diagWin:SetSize(700, 500)
  diagWin:SetPoint("CENTER")
  diagWin:SetFrameStrata("DIALOG")
  diagWin:SetMovable(true)
  diagWin:EnableMouse(true)
  diagWin:SetClampedToScreen(true)
  if diagWin.SetBackdrop then
    diagWin:SetBackdrop({
      bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
      tile=true, tileSize=32, edgeSize=32,
      insets={left=11,right=12,top=12,bottom=11}
    })
  end
  diagWin:SetScript("OnMouseDown", function(self) self:StartMoving() end)
  diagWin:SetScript("OnMouseUp",   function(self) self:StopMovingOrSizing() end)

  -- Title
  local title = diagWin:CreateFontString(nil, "OVERLAY")
  title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
  title:SetPoint("TOP", 0, -8)
  title:SetText("|cff33ffccpfQuest|r Diagnostic Log")

  -- Close button
  local closeBtn = CreateFrame("Button", nil, diagWin, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -5, -5)
  closeBtn:SetScript("OnClick", function() diagWin:Hide() end)

  -- Copy hint
  local hint = diagWin:CreateFontString(nil, "OVERLAY")
  hint:SetFont(STANDARD_TEXT_FONT, 10, "")
  hint:SetPoint("BOTTOMLEFT", 15, 15)
  hint:SetTextColor(0.6, 0.6, 0.6)
  hint:SetText("Ctrl+A, Ctrl+C to copy all text below")

  -- EditBox (scrollable, copyable)
  local scrollFrame = CreateFrame("ScrollFrame", "pfDiagScroll", diagWin,
    "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 15, -30)
  scrollFrame:SetPoint("BOTTOMRIGHT", -35, 35)

  local editBox = CreateFrame("EditBox", "pfDiagEditBox", scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:EnableMouse(true)
  editBox:SetFont(STANDARD_TEXT_FONT, 11, "")
  editBox:SetWidth(650)
  editBox:SetHeight(1)  -- grows with content
  editBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    diagWin:Hide()
  end)
  scrollFrame:SetScrollChild(editBox)

  diagWin.editBox = editBox
  diagWin.scrollFrame = scrollFrame
end

local function showDiagWindow(lines)
  createDiagWindow()
  local text = table.concat(lines, "\n")
  diagWin.editBox:SetText(text)
  diagWin.editBox:SetCursorPosition(0)
  diagWin.editBox:SetWidth(650)
  diagWin:Show()
end

-- ── Events ────────────────────────────────────────────────────────────────
local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(self, event, ...)
  if event == "VARIABLES_LOADED" then
    pfQuest_diagnostic = pfQuest_diagnostic or {}
    pfQuest_diagnostic.session = (pfQuest_diagnostic.session or 0) + 1
    pfQuest_diagnostic.log    = {}
    pfQuest_diagnostic.errors = {}
    _ready = true
    for _, e in ipairs(_pendingLog) do
      table.insert(pfQuest_diagnostic.log, e)
    end
    _pendingLog = {}
    dlog("=== SESSION " .. pfQuest_diagnostic.session .. " START ===")
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff33ffccpfQuest-retail|r diag ready (session " ..
      pfQuest_diagnostic.session .. "). |cffffff00/pfdiag|r for output window.")

  elseif event == "ADDON_LOADED" then
    local a = ...; if a and a:find("pfQuest") then dlog("ADDON_LOADED: "..a) end

  elseif event == "PLAYER_LOGIN" then
    dlog("PLAYER_LOGIN pfQuestMenu="..tostring(pfQuestMenu)
      .." pfDatabase="..tostring(pfDatabase)
      .." pfBrowser="..tostring(pfBrowser)
      .." initialized="..tostring(pfQuestConfig and pfQuestConfig._initialized))
    C_Timer.After(2, function()
      dlog("2s: pfQuestMenu="..tostring(pfQuestMenu)
        .." pfBrowser="..tostring(pfBrowser))
      local z=0
      if pfQuest and pfQuest.retailZoneMap then
        for _ in pairs(pfQuest.retailZoneMap) do z=z+1 end
      end
      dlog("2s: retailZoneMap="..z)
    end)

  elseif event == "PLAYER_ENTERING_WORLD" then
    dlog("PLAYER_ENTERING_WORLD")
  elseif event == "PLAYER_LOGOUT" then
    dlog("PLAYER_LOGOUT")
  end
end)

-- ── Slash command ─────────────────────────────────────────────────────────
SLASH_PFDIAG1 = "/pfdiag"
SlashCmdList["PFDIAG"] = function(input)
  local d = pfQuest_diagnostic or { log={}, errors={} }

  if input == "clear" then
    pfQuest_diagnostic = { log={}, errors={}, session = d.session }
    d = pfQuest_diagnostic; _ready = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfDiag:|r Cleared")
    return
  end

  if input == "menu" then
    local lines = {
      "pfQuestMenu: " .. tostring(pfQuestMenu),
      "pfBrowser:   " .. tostring(pfBrowser),
      "pfQuestIcon: " .. tostring(pfQuestIcon),
      "pfDatabase:  " .. tostring(pfDatabase),
    }
    if pfQuestMenu then
      table.insert(lines, "menu shown: " .. tostring(pfQuestMenu:IsShown()))
    end
    showDiagWindow(lines)
    return
  end

  if input == "errors" then
    local lines = {"=== ERRORS (last 100) ==="}
    for i = math.max(1, #d.errors-99), #d.errors do
      table.insert(lines, d.errors[i])
    end
    showDiagWindow(lines)
    return
  end

  -- default: show full log in window
  local lines = {
    "=== pfQuest-retail Diagnostic (session " .. tostring(d.session) .. ") ===",
    "Errors: " .. #d.errors .. "   Log entries: " .. #d.log,
    "",
    "=== RECENT ERRORS ===",
  }
  for i = math.max(1, #d.errors-19), #d.errors do
    table.insert(lines, d.errors[i])
  end
  if input == "log" then
    table.insert(lines, "")
    table.insert(lines, "=== FULL LOG ===")
    for i = 1, #d.log do table.insert(lines, d.log[i]) end
  else
    table.insert(lines, "")
    table.insert(lines, "=== RECENT LOG (last 50) ===")
    for i = math.max(1, #d.log-49), #d.log do
      table.insert(lines, d.log[i])
    end
    table.insert(lines, "")
    table.insert(lines, "Use /pfdiag log for full log | /pfdiag errors | /pfdiag clear")
  end
  showDiagWindow(lines)
end

pfDiag = { log = dlog, err = derr }
dlog("diagnostic.lua loaded")
