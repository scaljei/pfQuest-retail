local function strsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[#fields+1] = c end)
  return unpack(fields)
end

local channels = { "BATTLEGROUND", "RAID", "GUILD" }
local version, remote, major, minor, fix, displayed, available
local versioncheck = CreateFrame("Frame")
versioncheck:RegisterEvent("ADDON_LOADED")
versioncheck:RegisterEvent("CHAT_MSG_ADDON")
if not pcall(function() versioncheck:RegisterEvent("PARTY_MEMBERS_CHANGED") end) then
  versioncheck:RegisterEvent("GROUP_ROSTER_UPDATE")
end
versioncheck:RegisterEvent("PLAYER_ENTERING_WORLD")
versioncheck:SetScript("OnEvent", function(self, event)
  if event == "ADDON_LOADED" then
    if delta == "pfQuest" or delta == "pfQuest-tbc" or delta == "pfQuest-wotlk" then
      major, minor, fix = strsplit(".", tostring(((C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata)(delta, "Version")))
      major = tonumber(major) or 0
      minor = tonumber(minor) or 0
      fix = tonumber(fix) or 0

      version = major*10000 + minor*100 + fix
    end

    return
  elseif event == "CHAT_MSG_ADDON" and delta == "pfQuest" then
    local v, remoteversion = strsplit(":", arg2)
    local remoteversion = tonumber(remoteversion)
    if v == "VERSION" and remoteversion then
      remote = remote and max(remote, remoteversion) or remoteversion
      if remote > version then pfQuest_config.latest = remote end
    end
    return
  elseif event == "CHAT_MSG_ADDON" then
    return
  end

  -- abort here without local version
  if not version then return end

  -- send updates
  for _, chan in pairs(channels) do SendAddonMessage("pfQuest", "VERSION:" .. version, chan) end

  -- abort here on group member events
  if event == "PARTY_MEMBERS_CHANGED" then return end

  -- display available update
  if version and version > 0 and pfQuest_config.latest and pfQuest_config.latest > version and not displayed then
    DEFAULT_CHAT_FRAME:AddMessage(pfQuest_Loc["|cff33ffccpf|rQuest: New version available! Have a look at http://shagu.org !"])
    displayed = true
  end
end)
