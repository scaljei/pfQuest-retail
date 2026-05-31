-- pfQuest browser - retail port
-- Minimal version to confirm loading
C_Timer.After(0, function()
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[diag] browser.lua started (minimal)|r")
  end
end)

pfBrowser_fav = pfBrowser_fav or {["units"]={}, ["objects"]={}, ["items"]={}, ["quests"]={}}

-- Create the browser frame
pfBrowser = CreateFrame("Frame", "pfQuestBrowser", UIParent,
  BackdropTemplateMixin and "BackdropTemplate" or nil)
pfBrowser:Hide()
pfBrowser:SetWidth(640)
pfBrowser:SetHeight(440)
pfBrowser:SetPoint("CENTER", 0, 0)
pfBrowser:SetFrameStrata("FULLSCREEN_DIALOG")
pfBrowser:SetMovable(true)
pfBrowser:EnableMouse(true)
pfBrowser:SetClampedToScreen(true)
pfUI.api.CreateBackdrop(pfBrowser, nil, true, 0.85)
pfBrowser:SetScript("OnMouseDown", function(self) self:StartMoving() end)
pfBrowser:SetScript("OnMouseUp",   function(self) self:StopMovingOrSizing() end)

-- Title
local title = pfBrowser:CreateFontString(nil, "OVERLAY")
title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
title:SetPoint("TOP", pfBrowser, "TOP", 0, -8)
title:SetText("|cff33ffccpf|rQuest")

-- Close button
local closeBtn = CreateFrame("Button", nil, pfBrowser,
  BackdropTemplateMixin and "BackdropTemplate" or nil)
closeBtn:EnableMouse(true)
closeBtn:SetWidth(20)
closeBtn:SetHeight(20)
closeBtn:SetPoint("TOPRIGHT", pfBrowser, "TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function(self) pfBrowser:Hide() end)
local closeTex = closeBtn:CreateTexture(nil, "OVERLAY")
closeTex:SetTexture(pfQuestConfig.path .. "\\img\\close")
closeTex:SetAllPoints()

-- Search input
pfBrowser.input = CreateFrame("EditBox", "pfQuestBrowserInput", pfBrowser)
pfBrowser.input:SetPoint("TOPLEFT", pfBrowser, "TOPLEFT", 10, -30)
pfBrowser.input:SetPoint("TOPRIGHT", pfBrowser, "TOPRIGHT", -10, -30)
pfBrowser.input:SetHeight(22)
pfBrowser.input:SetAutoFocus(false)
pfBrowser.input:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
pfBrowser.input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
pfBrowser.input:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)
pfBrowser.input:SetScript("OnTextChanged", function(self, userInput)
  if not userInput then return end
  pfBrowser:Search()
end)

-- Tabs (Units / Objects / Items / Quests)
pfBrowser.tabs = {}
local tabNames = {"units","objects","items","quests"}
local tabLabels = {
  pfQuest_Loc["Units"] or "Units",
  pfQuest_Loc["Objects"] or "Objects",
  pfQuest_Loc["Items"] or "Items",
  pfQuest_Loc["Quests"] or "Quests",
}
local tabW = 150

for i, tabKey in ipairs(tabNames) do
  local tab = CreateFrame("Button", nil, pfBrowser,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  tab:EnableMouse(true)
  tab:SetWidth(tabW)
  tab:SetHeight(24)
  tab:SetPoint("BOTTOMLEFT", pfBrowser, "BOTTOMLEFT", (i-1)*tabW + 4, 4)
  pfUI.api.CreateBackdrop(tab, nil, true, 0.6)
  local label = tab:CreateFontString(nil, "OVERLAY")
  label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
  label:SetAllPoints()
  label:SetText(tabLabels[i] .. " (0)")
  tab.label = label
  tab.btype = tabKey
  tab:SetScript("OnClick", function(self)
    pfBrowser.activeTab = self.btype
    pfBrowser:Search()
  end)
  pfBrowser.tabs[tabKey] = tab
  pfBrowser.tabs[tabKey].buttons = {}
end

pfBrowser.activeTab = "units"

-- Scroll frame for results
pfBrowser.scroll = CreateFrame("ScrollFrame", "pfQuestBrowserScroll", pfBrowser)
pfBrowser.scroll:SetPoint("TOPLEFT",  pfBrowser, "TOPLEFT",  5, -58)
pfBrowser.scroll:SetPoint("BOTTOMRIGHT", pfBrowser, "BOTTOMRIGHT", -5, 34)
pfBrowser.scrollChild = CreateFrame("Frame", nil, pfBrowser.scroll)
pfBrowser.scrollChild:SetWidth(pfBrowser.scroll:GetWidth())
pfBrowser.scrollChild:SetHeight(1)
pfBrowser.scroll:SetScrollChild(pfBrowser.scrollChild)

-- Search function
function pfBrowser:Search()
  local text = self.input and self.input:GetText() or ""
  local btype = self.activeTab or "units"
  local results = {}
  local limit = 50

  if #text >= 2 then
    local db = pfDB[btype] and pfDB[btype]["loc"]
    if db then
      for id, name in pairs(db) do
        -- loc can be a table {T=...} for quests or a string for units/objects
        local n = type(name) == "table" and name.T or name
        if n and string.find(string.lower(n), string.lower(text), 1, true) then
          table.insert(results, {id=id, name=n})
          if #results >= limit then break end
        end
      end
    end
  elseif text == "" then
    -- Show favorites
    if pfBrowser_fav[btype] then
      for id, name in pairs(pfBrowser_fav[btype]) do
        table.insert(results, {id=id, name=name})
      end
    end
  end

  -- Update tab label
  for _, tab in pairs(self.tabs) do
    local label = string.upper(tab.btype:sub(1,1)) .. tab.btype:sub(2)
    tab.label:SetText(label .. " (" .. (tab.btype == btype and #results or 0) .. ")")
  end

  -- Clear old buttons
  for _, btn in ipairs(self.scrollChild:GetChildren() or {}) do
    btn:Hide()
  end

  -- Create result buttons
  local yOff = 0
  for i, result in ipairs(results) do
    local btn = CreateFrame("Button", nil, self.scrollChild)
    btn:EnableMouse(true)
    btn:SetWidth(self.scrollChild:GetWidth())
    btn:SetHeight(20)
    btn:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -yOff)
    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    lbl:SetAllPoints()
    lbl:SetText("|cffcccccc[" .. result.id .. "]|r " .. result.name)
    btn.id = result.id
    btn.btype = btype
    btn:SetScript("OnClick", function(self)
      pfDatabase:SearchMobID(self.id)
      pfMap:UpdateNodes()
    end)
    yOff = yOff + 20
    btn:Show()
  end
  self.scrollChild:SetHeight(math.max(1, yOff))
end

C_Timer.After(0.5, function()
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[diag] pfBrowser created: " .. tostring(pfBrowser) .. "|r")
  end
end)
