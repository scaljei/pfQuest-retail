-- pfQuest-retail diagnostic logger v3
-- SavedVariable: pfQuest_diagnostic (loaded AFTER this file runs)
-- Use VARIABLES_LOADED to hook into the populated table

local _pendingLog = {}  -- collect logs before VARIABLES_LOADED
local _ready = false

local function ts() return string.format("[s %.1fs]", GetTime()) end

local function dlog(m)
    local e = ts() .. " " .. tostring(m)
    if _ready and pfQuest_diagnostic then
        table.insert(pfQuest_diagnostic.log, e)
        while #pfQuest_diagnostic.log > 500 do table.remove(pfQuest_diagnostic.log, 1) end
    else
        table.insert(_pendingLog, e)
    end
end

local function derr(m)
    local e = ts() .. " ERR: " .. tostring(m)
    dlog("ERR: " .. tostring(m))
    if _ready and pfQuest_diagnostic then
        table.insert(pfQuest_diagnostic.errors, e)
        while #pfQuest_diagnostic.errors > 200 do table.remove(pfQuest_diagnostic.errors, 1) end
    end
end

-- Hook error handler immediately
local _prevEH = geterrorhandler and geterrorhandler()
if seterrorhandler then
    seterrorhandler(function(msg)
        derr(tostring(msg))
        if _prevEH then return _prevEH(msg) end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "VARIABLES_LOADED" then
        -- NOW the SavedVariable is populated
        pfQuest_diagnostic = pfQuest_diagnostic or {}
        pfQuest_diagnostic.log = pfQuest_diagnostic.log or {}
        pfQuest_diagnostic.errors = pfQuest_diagnostic.errors or {}
        pfQuest_diagnostic.session = (pfQuest_diagnostic.session or 0) + 1
        _ready = true
        -- flush pending logs
        for _, e in ipairs(_pendingLog) do
            table.insert(pfQuest_diagnostic.log, e)
        end
        _pendingLog = {}
        -- Write session header at end of log (always visible)
        -- Auto-clear log on each new session so we always see fresh data
        pfQuest_diagnostic.log = {}
        pfQuest_diagnostic.errors = {}
        local sep = "=== SESSION " .. pfQuest_diagnostic.session .. " START =="
        table.insert(pfQuest_diagnostic.log, sep)
        -- Print to chat so user can confirm new version
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-retail|r diag ready (session " .. pfQuest_diagnostic.session .. ").")
        dlog("VARIABLES_LOADED - diagnostic ready (session " .. pfQuest_diagnostic.session .. ")")

    elseif event == "ADDON_LOADED" then
        local a = ...; if a and a:find("pfQuest") then dlog("ADDON_LOADED: " .. a) end

    elseif event == "PLAYER_LOGIN" then
        dlog("PLAYER_LOGIN")
        dlog("pfQuestMenu=" .. tostring(pfQuestMenu))
        dlog("pfDatabase=" .. tostring(pfDatabase))
        dlog("pfQuestConfig._initialized=" .. tostring(pfQuestConfig and pfQuestConfig._initialized))
        dlog("pfQuestConfig._progress=" .. tostring(pfQuestConfig and pfQuestConfig._progress))
        dlog("BackdropTemplateMixin=" .. tostring(BackdropTemplateMixin ~= nil))
        C_Timer.After(2, function()
            dlog("--- 2s ---")
            dlog("pfQuestMenu=" .. tostring(pfQuestMenu))
            local zcount = 0
            if pfQuest and pfQuest.retailZoneMap then
                for _ in pairs(pfQuest.retailZoneMap) do zcount = zcount + 1 end
            end
            dlog("retailZoneMap=" .. zcount)
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        dlog("PLAYER_ENTERING_WORLD")
    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        dlog("PLAYER_LOGOUT - saving diagnostic")
        -- SavedVariables auto-save happens after this event
    end
end)

SLASH_PFDIAG1 = "/pfdiag"
SlashCmdList["PFDIAG"] = function(input)
    local function p(s) DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc" .. s .. "|r") end
    local function r(s) DEFAULT_CHAT_FRAME:AddMessage("|cffff5555" .. s .. "|r") end

    if input == "clear" then
        pfQuest_diagnostic = { log={}, errors={}, session = pfQuest_diagnostic and pfQuest_diagnostic.session or 0 }
        _ready = true; p("Cleared"); return
    end
    if input == "menu" then
        p("pfQuestMenu=" .. tostring(pfQuestMenu))
        p("pfQuestIcon=" .. tostring(pfQuestIcon))
        if pfQuestMenu then
            p("shown=" .. tostring(pfQuestMenu:IsShown()))
            p("size=" .. pfQuestMenu:GetWidth() .. "x" .. pfQuestMenu:GetHeight())
            local ok, e = pcall(function()
                pfQuestMenu:SetFrameStrata("TOOLTIP"); pfQuestMenu:Show(); pfQuestMenu:Raise()
            end)
            p("Force show: " .. tostring(ok) .. " " .. tostring(e or ""))
        end; return
    end

    local d = pfQuest_diagnostic or { log={}, errors={} }
    p("=== pfQuest Diagnostic (session " .. tostring(d.session) .. ") ===")
    p("Errors: " .. #d.errors .. "  Log: " .. #d.log)
    p("--- Recent Errors ---")
    for i = math.max(1, #d.errors - 10), #d.errors do r(d.errors[i]) end
    if input == "log" or input == "" then
        p("--- Log (last 30) ---")
        for i = math.max(1, #d.log - 30), #d.log do
            DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa" .. d.log[i] .. "|r")
        end
    end
    if input == "debug" then
        p("--- Debug log entries ---")
        local count = 0
        for i = 1, #d.log do
            local e = d.log[i]
            if not e:find("ERR:") and (e:find("Zone") or e:find("Node") or e:find("Update") or e:find("Quest")) then
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88" .. e .. "|r")
                count = count + 1
                if count >= 40 then break end
            end
        end
        return
    end
    p("(WTF/Account/.../SavedVariables/pfQuest-retail.lua)")
    p("/pfdiag log | /pfdiag menu | /pfdiag debug | /pfdiag clear")
end

pfDiag = { log = dlog, err = derr }
dlog("diagnostic.lua loaded")
