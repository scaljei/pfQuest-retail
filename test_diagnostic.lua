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
