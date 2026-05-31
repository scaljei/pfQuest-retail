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
