local addonName, TTA = ...

TTA = TTA or {}
_G[addonName] = TTA

TTA.version = "1.0.0"
TTA.author = "KTDS"

local DEBUG_MODE = false

function TTA:Debug(message)
    if DEBUG_MODE then
        print("TicTacAzeroth DEBUG: " .. tostring(message))
    end
end

local defaultConfig = {
    profile = {
        windowPosition = {
            point = "CENTER",
            x = 0,
            y = 0
        },
        soundEnabled = true,
        lastDifficulty = 1,
        showWinStats = true,
        autoAcceptInvites = false
    }
}

function TTA:InitializeDB()
    if not TicTacAzerothDB then
        TicTacAzerothDB = CopyTable(defaultConfig)
    end
    
    for key, value in pairs(defaultConfig.profile) do
        if TicTacAzerothDB.profile[key] == nil then
            TicTacAzerothDB.profile[key] = value
        end
    end
    
    self.db = TicTacAzerothDB
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            TTA:InitializeDB()
            TTA:InitializeSlashCommands()
        end
    elseif event == "PLAYER_LOGIN" then
        TTA:OnPlayerLogin()
    elseif event == "CHAT_MSG_ADDON" then
        TTA:OnAddonMessage(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        TTA:OnGroupRosterUpdate()
    end
end)

function TTA:OnPlayerLogin()
    C_ChatInfo.RegisterAddonMessagePrefix("TicTacAzeroth")
    
    if self.Settings then
        self.Settings:Initialize()
    end
    
    if self.Sounds then
        self.Sounds:Initialize()
    end
    
    if not self.UI then
        self:InitializeUI()
    end
    
    self:Print("TicTacAzeroth loaded! Type /tta to start playing.")
end

function TTA:InitializeSlashCommands()
    SLASH_TICTACAZEROTH1 = "/tta"
    SLASH_TICTACAZEROTH2 = "/tictacazeroth"
    
    SlashCmdList["TICTACAZEROTH"] = function(msg)
        local command, arg = msg:match("^(%S*)%s*(.-)$")
        command = command:lower()
        
        if command == "" or command == "show" then
            self:ShowMainWindow()
        elseif command == "accept" then
            self:AcceptGameInvite()
        elseif command == "decline" then
            self:DeclineGameInvite()
        elseif command == "config" then
            self:ShowConfigWindow()
        elseif command == "help" then
            self:ShowHelp()
        else
            print("|cffff0000TicTacAzeroth:|r Unknown command. Type |cffffffff/tta help|r for available commands.")
        end
    end
end

function TTA:ShowHelp()
    print("|cff00ff00TicTacAzeroth Commands:|r")
    print("|cffffffff/tta|r - Open the main game window")
    print("|cffffffff/tta accept|r - Accept a game invitation")
    print("|cffffffff/tta decline|r - Decline a game invitation")
    print("|cffffffff/tta config|r - Open configuration window")
    print("|cffffffff/tta help|r - Show this help")
end

function TTA:Print(msg)
    print("|cff00ff00TicTacAzeroth:|r " .. msg)
end

function TTA:Debug(msg)
    if self.db and self.db.profile.debugMode then
        print("|cffff9900TicTacAzeroth Debug:|r " .. msg)
    end
end

function TTA:InitializeUI()
    if self.UI and self.UI.Initialize then
        self.UI:Initialize()
    end
end

function TTA:ShowMainWindow()
    if InCombatLockdown() then
        self:Print("Cannot open TicTacAzeroth during combat!")
        return
    end
    
    if self.UI and self.UI.ShowMainWindow then
        self.UI:ShowMainWindow()
    else
        self:Print("UI not initialized yet. Please try again in a moment.")
    end
end

function TTA:ShowConfigWindow()
    self:Print("Configuration window coming soon!")
end

function TTA:AcceptGameInvite()
    if self.pendingInvite then
        local opponent = self.pendingInvite
        self.pendingInvite = nil
        
        self:SendMessage("GAME_ACCEPT", opponent)
        
        self:StartMultiplayerGame(opponent, false)
        
        TTA:Print("Accepted game invitation from " .. opponent)
    else
        self:Print("No pending game invitation.")
    end
end

function TTA:DeclineGameInvite()
    if self.pendingInvite then
        local opponent = self.pendingInvite
        self.pendingInvite = nil
        
        -- Send decline message
        self:SendMessage("GAME_DECLINE", opponent)
        
        TTA:Print("Declined game invitation from " .. opponent)
    else
        self:Print("No pending game invitation.")
    end
end

function TTA:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= "TicTacAzeroth" then
        return
    end
    
    if sender == UnitName("player") then
        return
    end
    
    TTA:Debug("Received raw message: " .. message .. " from " .. sender)
    
    local parts = {strsplit("|", message)}
    if #parts < 3 then
        TTA:Debug("Invalid message format")
        return
    end
    
    local msgType = parts[1]
    local msgSender = parts[2]
    local msgTarget = parts[3]
    
    local ourName = Ambiguate(UnitName("player"), "short")
    if msgTarget ~= ourName then
        TTA:Debug("Message not for us (target: " .. msgTarget .. ", we are: " .. ourName .. ")")
        return
    end
    
    local senderName = Ambiguate(sender, "short")
    if msgSender ~= senderName then
        TTA:Debug("Sender mismatch - expected: " .. msgSender .. ", got: " .. senderName)
        return
    end
    
    TTA:Debug("Processing message: " .. msgType .. " from " .. msgSender)
    
    if msgType == "GAME_INVITE" then
        self:HandleGameInvite(msgSender)
    elseif msgType == "GAME_ACCEPT" then
        self:HandleGameAccept(msgSender)
    elseif msgType == "GAME_DECLINE" then
        self:HandleGameDecline(msgSender)
    elseif msgType:match("^MOVE:") then
        local position = tonumber(msgType:match("^MOVE:(%d+)$"))
        if position then
            self:HandleGameMove(position, msgSender)
        end
    elseif msgType:match("^GAME_END:") then
        local result = msgType:match("^GAME_END:(.+)$")
        if result then
            self:HandleGameEnd(result, msgSender)
        end
    elseif msgType == "RESTART_REQUEST" then
        self:HandleRestartRequest(msgSender)
    elseif msgType:match("^RESTART_ACCEPT") then
        local gameId = tonumber(msgType:match("^RESTART_ACCEPT:(%d+)$"))
        self:HandleRestartAccept(msgSender, gameId)
    elseif msgType == "RESTART_DECLINE" then
        self:HandleRestartDecline(msgSender)
    elseif msgType == "QUIT_GAME" then
        self:HandleQuitGame(msgSender)
    elseif msgType == "INVITE_CANCELLED" then
        self:HandleInviteCancelled(msgSender)
    end
end

function TTA:HandleGameInvite(sender)
    if InCombatLockdown() then
        TTA:Print("Auto-declined game invitation from " .. sender .. " (in combat).")
        self:SendMessage("GAME_DECLINE", sender)
        return
    end
    
    if self:IsPlayerCurrentlyBusy() then
        local reason = self:GetBusyReason()
        TTA:Print("Auto-declined game invitation from " .. sender .. " (" .. reason .. ").")
        self:SendMessage("GAME_DECLINE", sender)
        return
    end
    
    if self.Settings and self.Settings:Get("autoDeclineInvites") then
        TTA:Print("Auto-declined game invitation from " .. sender .. ".")
        self:SendMessage("GAME_DECLINE", sender)
        return
    end
    
    TTA:Print(sender .. " has invited you to play TicTacToe! Type /tta accept to join.")
    self.pendingInvite = sender
    
    if self.Sounds then
        self.Sounds:PlayInviteReceived()
    end
    
    if self.UI and self.UI.ShowGameInvite then
        self.UI:ShowGameInvite(sender)
    end
end

function TTA:HandleGameAccept(sender)
    TTA:Print(sender .. " accepted your game invitation!")
    
    if self.Sounds then
        self.Sounds:PlayInviteAccepted()
    end
    
    self:StartMultiplayerGame(sender, true)
end

function TTA:HandleGameDecline(sender)
    TTA:Print(sender .. " declined your game invitation.")
    
    if self.Sounds then
        self.Sounds:PlayInviteDeclined()
    end
    
    if self.Game and self.Game.gameMode == "player" and
       self.Game.gameState == self.Game.GAME_STATE.WAITING_FOR_PLAYER and
       self.Game.opponentName == sender then
        
        self.Game:ResetGame()
        
        if self.UI and self.UI.gameFrame then
            self.UI.gameFrame:Hide()
            self.UI:ShowMainWindow()
        end
    end
end

function TTA:HandleGameMove(position, sender)
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName == sender then
        self.Game:HandleOpponentMove(position)
    end
end

function TTA:HandleGameEnd(result, sender)
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName == sender then
        local message
        if result == "WON" then
            message = "You won!"
        elseif result == "LOST" then 
            message = "You lost!"
        else
            message = "It's a draw!"
        end
        
        TTA:Print("Game ended: " .. message)
        
        self.Game.gameState = self.Game.GAME_STATE.FINISHED
        
        if self.UI then
            self.UI:UpdateGameInfo()
            self.UI:ShowGameResult(message)
        end
    end
end

function TTA:HandleRestartRequest(sender)
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName == sender then
        TTA:Print(sender .. " wants to play another round!")
        
        if self.UI then
            self.UI:ShowRestartRequest(sender)
        end
    end
end

function TTA:HandleRestartAccept(sender, gameId)
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName == sender then
        TTA:Print("Starting new round with " .. sender)
        
        self:StartNewMultiplayerRound(sender, gameId)
    end
end

function TTA:HandleRestartDecline(sender)
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName == sender then
        TTA:Print(sender .. " has declined to play another round.")
        
        if self.UI then
            StaticPopup_Hide("TICTACAZEROTH_PLAYER_RESULT")
            StaticPopup_Hide("TICTACAZEROTH_AI_RESULT")
            StaticPopup_Hide("TICTACAZEROTH_RESTART_REQUEST")
        end
        
        self:ReturnToMainMenu()
    end
end

function TTA:HandleQuitGame(sender)
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName == sender then
        TTA:Print(sender .. " has left the game.")
        
        if self.UI then
            StaticPopup_Hide("TICTACAZEROTH_PLAYER_RESULT")
            StaticPopup_Hide("TICTACAZEROTH_AI_RESULT")
            StaticPopup_Hide("TICTACAZEROTH_RESTART_REQUEST")
        end
        
        self:ReturnToMainMenu()
    end
end

function TTA:HandleInviteCancelled(sender)
    if self.pendingInvite == sender then
        TTA:Print(sender .. " has cancelled the game invitation.")
        
        self.pendingInvite = nil
        
        if self.UI then
            StaticPopup_Hide("TICTACAZEROTH_GAME_INVITE")
        end
    end
end

function TTA:SendMessage(message, targetPlayer)
    if targetPlayer == UnitName("player") then
        return
    end
    
    local senderName = Ambiguate(UnitName("player"), "short")
    local targetName = Ambiguate(targetPlayer, "short")
    
    local fullMessage = message .. "|" .. senderName .. "|" .. targetName
    TTA:Debug("Sending message: " .. fullMessage)
    C_ChatInfo.SendAddonMessage("TicTacAzeroth", fullMessage, "PARTY")
end

function TTA:StartMultiplayerGame(opponentName, isInviter)
    if self.Game then
        self.Game:StartSimplePlayerGame(opponentName, isInviter)
    end
end

function TTA:OnGroupRosterUpdate()
    if self.pendingInvite and not self:IsPlayerInGroup(self.pendingInvite) then
        self.pendingInvite = nil
    end
end

function TTA:IsPlayerInGroup(playerName)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name and name == playerName then
                return true
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local name = UnitName("party" .. i)
            if name and name == playerName then
                return true
            end
        end
    end
    return false
end

function TTA:IsPlayerBusy(playerName)
    if self.pendingInvite == playerName then
        return true, "invited_by_us"
    end
    
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName == playerName then
        if self.Game.gameState == self.Game.GAME_STATE.PLAYING then
            return true, "in_game_with_us"
        elseif self.Game.gameState == self.Game.GAME_STATE.WAITING_FOR_PLAYER then
            return true, "invited_by_us"
        end
    end

    return false, nil
end

function TTA:SetPlayerBusy(playerName, reason)
    -- This could be expanded to track global busy states
end

function TTA:IsPlayerCurrentlyBusy()
    if self.pendingInvite then
        return true
    end
    
    if self.Game then
        if self.Game.gameMode == "ai" and self.Game.gameState == self.Game.GAME_STATE.PLAYING then
            return true
        elseif self.Game.gameMode == "player" then
            if self.Game.gameState == self.Game.GAME_STATE.PLAYING then
                return true
            elseif self.Game.gameState == self.Game.GAME_STATE.WAITING_FOR_PLAYER then
                return true
            end
        end
    end
    
    return false
end

function TTA:GetBusyReason()
    if self.pendingInvite then
        return "already have pending invitation"
    end
    
    if self.Game then
        if self.Game.gameMode == "ai" and self.Game.gameState == self.Game.GAME_STATE.PLAYING then
            return "playing against AI"
        elseif self.Game.gameMode == "player" then
            if self.Game.gameState == self.Game.GAME_STATE.PLAYING then
                return "already in game with " .. (self.Game.opponentName or "another player")
            elseif self.Game.gameState == self.Game.GAME_STATE.WAITING_FOR_PLAYER then
                return "waiting for " .. (self.Game.opponentName or "player") .. " to accept invitation"
            end
        end
    end
    
    return "busy"
end

function TTA:ReturnToMainMenu()
    if self.UI then
        if self.UI.gameFrame then
            self.UI.gameFrame:Hide()
        end
        self.UI:ShowMainWindow()
    end
    
    if self.Game then
        self.Game:ResetGame()
    end
end

function TTA:StartNewMultiplayerRound(opponentName, gameId)
    if self.Game then
        self.Game:ResetGame()
        local newGameId = gameId or math.random(1000000)
        self.Game:StartPlayerGame(opponentName, newGameId)
    end
    
    if self.UI then
        self.UI:UpdateGameBoard()
        self.UI:UpdateGameInfo()
    end
end

function TTA:SendRestartRequest()
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName then
        self:SendMessage("RESTART_REQUEST", self.Game.opponentName)
    end
end

function TTA:SendRestartAccept()
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName then
        local newGameId = math.random(1000000)
        self:SendMessage("RESTART_ACCEPT:" .. newGameId, self.Game.opponentName)
        self:StartNewMultiplayerRound(self.Game.opponentName, newGameId)
    end
end

function TTA:SendRestartDecline()
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName then
        self:SendMessage("RESTART_DECLINE", self.Game.opponentName)
        self:ReturnToMainMenu()
    end
end

function TTA:SendQuitGame()
    if self.Game and self.Game.gameMode == "player" and self.Game.opponentName then
        self:SendMessage("QUIT_GAME", self.Game.opponentName)
        self:ReturnToMainMenu()
    end
end

function TTA:HandleGameWindowClose()
    if not self.Game then
        if self.UI and self.UI.gameFrame then
            self.UI.gameFrame:Hide()
        end
        return
    end
    
    local gameState = self.Game.gameState
    local gameMode = self.Game.gameMode
    
    if gameMode == "player" then
        if gameState == self.Game.GAME_STATE.WAITING_FOR_PLAYER then
            TTA:Print("Game invitation cancelled.")
            
            if self.Game.opponentName then
                self:SendMessage("INVITE_CANCELLED", self.Game.opponentName)
            end
            
            self.Game:ResetGame()
            if self.UI and self.UI.gameFrame then
                self.UI.gameFrame:Hide()
            end
            
        elseif gameState == self.Game.GAME_STATE.PLAYING then
            TTA:Print("Left the game.")
            
            if self.Game.opponentName then
                self:SendMessage("QUIT_GAME", self.Game.opponentName)
            end
            
            self:ReturnToMainMenu()
            
        else
            if self.UI and self.UI.gameFrame then
                self.UI.gameFrame:Hide()
            end
        end
    else
        if self.UI and self.UI.gameFrame then
            self.UI.gameFrame:Hide()
        end
    end
end
