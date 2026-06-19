-- pfQuest-retail Debug Panel
-- Floating draggable panel with buttons for all /db debug commands.
-- Toggle with:  /db debug panel
-- Auto-hidden unless pfQuest_config.debugPanel is set.

local PANEL_W  = 220
local PANEL_H  = 380   -- grows automatically with button count
local BTN_H    = 20
local BTN_PAD  = 4
local HEADER_H = 28

-- ── button definitions ────────────────────────────────────────────────────
-- { label, slash_arg, tooltip }
local BUTTONS = {
  { "DB Info",       "dbinfo",      "Live DB state snapshot" },
  { "Obj Dump",      "objdump",     "Raw GetQuestObjectives for active quests" },
  { "Wanted Names",  "wantednames", "Dump wantedNames objective index" },
  { "GUID Check",    "guidcheck",   "GUID / registration check on current target" },
  { "Pin Dump",      "pindump",     "Inspect world map pin state" },
  { "NP Trace",      "nptrace",     "Toggle nameplate event trace" },
  { "NPC Cache",     "npccache",    "Show NPC cache size (/db npccache clear to wipe)" },
  { "Harvester",     "harvester",   "Re-import Wowhead Looter wlUnit data" },
  { "MobInfo2",      "mobinfo2",    "Re-import MobInfo2 NPC coord data" },
  { "ATT Sync",      "att",         "Force ATT / native quest completion sync" },
  { "Classic DB",    "classicdb",   "Report classic DB load status" },
  { "pfDiag Log",    "pfdiag",      "Open pfDiag session log window" },
  { "pfDiag Errors", "pfdiag errors", "Show only errors from session log" },
  { "Scan",          "scan",        "Scan server for custom items" },
  { "Search Test",   "searchtest",  "SearchQuestID smoke-test (last active quest)" },
  { "Item Dump",     "itemdump",    "Inspect type=item objective state and drop sources" },
  { "Loot Dump",     "lootdump",    "Inspect currently open loot window slots (run while looting)" },
  { "Item Cache",    "itemcache",   "Show item drop cache state ('itemcache save' before /reload)" },
}

-- ── helpers ───────────────────────────────────────────────────────────────
local function runCmd(arg)
  -- /pfdiag variants are a different slash command
  if arg:sub(1,7) == "pfdiag" then
    local sub = arg:sub(8):match("^%s*(.-)%s*$") or ""
    if pfDiag and pfDiag.showWindow then
      -- delegate to the pfDiag slash handler directly
      SlashCmdList["PFDIAG"](sub)
    end
  else
    SlashCmdList["PFDB"](arg)
  end
end

-- ── panel creation ────────────────────────────────────────────────────────
local panel = nil

local function buildPanel()
  if panel then return end

  local totalH = HEADER_H + (#BUTTONS * (BTN_H + BTN_PAD)) + BTN_PAD + 30

  panel = CreateFrame("Frame", "pfQuestDebugPanel", UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  panel:SetSize(PANEL_W, totalH)
  panel:SetPoint("CENTER", UIParent, "CENTER", 400, 0)
  panel:SetFrameStrata("HIGH")
  panel:SetFrameLevel(100)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  panel:Hide()

  if panel.SetBackdrop then
    panel:SetBackdrop({
      bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 24,
      insets = { left=8, right=8, top=8, bottom=8 },
    })
  end

  -- drag
  panel:SetScript("OnMouseDown", function(self, btn)
    if btn == "LeftButton" then self:StartMoving() end
  end)
  panel:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

  -- Title bar
  local title = panel:CreateFontString(nil, "OVERLAY")
  title:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
  title:SetPoint("TOPLEFT", 12, -8)
  title:SetText("|cff33ffccpfQuest|r Debug")

  -- Close button
  local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  closeBtn:SetSize(20, 20)
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  closeBtn:SetScript("OnClick", function() panel:Hide() end)

  -- Buttons
  local y = -(HEADER_H)
  for i, def in ipairs(BUTTONS) do
    local lbl, arg, tip = def[1], def[2], def[3]

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(PANEL_W - 24, BTN_H)
    btn:SetPoint("TOPLEFT", 12, y)
    btn:SetText(lbl)

    -- shrink font to fit
    local fs = btn:GetFontString()
    if fs then fs:SetFont(STANDARD_TEXT_FONT, 10, "") end

    btn:SetScript("OnClick", function() runCmd(arg) end)

    -- tooltip
    btn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("|cff33ffcc/db " .. arg .. "|r", 1, 1, 1)
      GameTooltip:AddLine(tip, 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    y = y - (BTN_H + BTN_PAD)
  end

  -- resize to actual content
  panel:SetHeight(-y + 10)
end

-- ── public API ────────────────────────────────────────────────────────────
pfDebugPanel = {}

function pfDebugPanel.Toggle()
  buildPanel()
  if panel:IsShown() then
    panel:Hide()
  else
    panel:Show()
  end
end

function pfDebugPanel.Show()
  buildPanel()
  panel:Show()
end

function pfDebugPanel.Hide()
  if panel then panel:Hide() end
end

-- ── hook into /db debug ───────────────────────────────────────────────────
-- We wrap SlashCmdList["PFDB"] after it's defined so that
-- "/db debug panel" toggles the panel instead of just toggling debug mode.
C_Timer.After(0, function()
  local original = SlashCmdList["PFDB"]
  if not original then return end
  SlashCmdList["PFDB"] = function(input, editbox)
    local first = input and input:match("^(%S+)") or ""
    local rest  = input and input:match("^%S+%s+(.+)$") or ""
    if first == "debug" and (rest == "panel" or rest == "p") then
      pfDebugPanel.Toggle()
      return
    end
    original(input, editbox)
  end
end)

C_Timer.After(0, function()
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[diag] debugpanel.lua loaded — /db debug panel to open|r")
  end
end)
