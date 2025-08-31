local addonName, TTA = ...

TTA.UI = {}
local UI = TTA.UI

local WINDOW_WIDTH = 400
local WINDOW_HEIGHT = 500
local BOARD_SIZE = 300
local CELL_SIZE = 90

function UI:Initialize()
    self:CreateMainWindow()
    self:CreateGameWindow()
end

function UI:CreateMainWindow()
    local frame = CreateFrame("Frame", "TicTacAzerothMainFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    self.mainFrame = frame
    
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -5)
    frame.title:SetText("TicTacAzeroth")
    
    local aiButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    aiButton:SetPoint("TOP", frame, "TOP", 0, -80)
    aiButton:SetSize(200, 40)
    aiButton:SetText("Play vs AI")
    aiButton:SetNormalFontObject("GameFontNormalLarge")
    aiButton:SetScript("OnClick", function()
        self:ShowDifficultySelection()
    end)
    
    local playerButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    playerButton:SetPoint("TOP", aiButton, "BOTTOM", 0, -20)
    playerButton:SetSize(200, 40)
    playerButton:SetText("Play vs Player")
    playerButton:SetNormalFontObject("GameFontNormalLarge")
    playerButton:SetScript("OnClick", function()
        self:ShowPlayerSelection()
    end)
    
    local closeButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
    closeButton:SetSize(100, 30)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    self.aiButton = aiButton
    self.playerButton = playerButton
    
    self:CreateDifficultyPanel(frame)
    
    self:CreatePlayerPanel(frame)
end

function UI:CreateDifficultyPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFontObject("GameFontHighlightLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -80)
    title:SetText("Select Difficulty")
    
    local easyButton = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    easyButton:SetPoint("TOP", title, "BOTTOM", 0, -30)
    easyButton:SetSize(150, 35)
    easyButton:SetText("Easy")
    easyButton:SetScript("OnClick", function()
        TTA.Game:StartAIGame(TTA.Game.AI_DIFFICULTY.EASY)
        parent:Hide()
    end)
    
    local mediumButton = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    mediumButton:SetPoint("TOP", easyButton, "BOTTOM", 0, -15)
    mediumButton:SetSize(150, 35)
    mediumButton:SetText("Medium")
    mediumButton:SetScript("OnClick", function()
        TTA.Game:StartAIGame(TTA.Game.AI_DIFFICULTY.MEDIUM)
        parent:Hide()
    end)
    
    local hardButton = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    hardButton:SetPoint("TOP", mediumButton, "BOTTOM", 0, -15)
    hardButton:SetSize(150, 35)
    hardButton:SetText("Hard")
    hardButton:SetScript("OnClick", function()
        TTA.Game:StartAIGame(TTA.Game.AI_DIFFICULTY.HARD)
        parent:Hide()
    end)
    
    local backButton = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    backButton:SetPoint("BOTTOM", panel, "BOTTOM", 0, 60)
    backButton:SetSize(100, 30)
    backButton:SetText("Back")
    backButton:SetScript("OnClick", function()
        self:ShowMainMenu()
    end)
    
    self.difficultyPanel = panel
end

function UI:CreatePlayerPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFontObject("GameFontHighlightLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -80)
    title:SetText("Invite Player")
    
    local instructions = panel:CreateFontString(nil, "OVERLAY")
    instructions:SetFontObject("GameFontNormal")
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -20)
    instructions:SetText("Enter the name of a player in your group:")
    
    local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    editBox:SetPoint("TOP", instructions, "BOTTOM", 0, -20)
    editBox:SetSize(200, 30)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(12)
    
    local inviteButton = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    inviteButton:SetPoint("TOP", editBox, "BOTTOM", 0, -20)
    inviteButton:SetSize(120, 35)
    inviteButton:SetText("Send Invite")
    inviteButton:SetScript("OnClick", function()
        local playerName = editBox:GetText():trim()
        if playerName ~= "" then
            local ourName = Ambiguate(UnitName("player"), "short")
            local targetName = Ambiguate(playerName, "short")
            if ourName == targetName then
                TTA:Print("You can't invite yourself to a game!")
                return
            end
            
            if TTA:IsPlayerInGroup(playerName) then
                local isBusy, reason = TTA:IsPlayerBusy(playerName)
                if isBusy then
                    if reason == "invited_by_us" then
                        TTA:Print("You have already invited '" .. playerName .. "'!")
                    elseif reason == "in_game_with_us" then
                        TTA:Print("You are already in a game with '" .. playerName .. "'!")
                    else
                        TTA:Print("Player '" .. playerName .. "' is currently busy!")
                    end
                    return
                end
                
                TTA:SendMessage("GAME_INVITE", playerName)
                TTA:Print("Game invitation sent to " .. playerName)
                
                if TTA.Sounds then
                    TTA.Sounds:PlayInviteSent()
                end
                
                if TTA.Game then
                    local gameId = math.random(1000000)
                    TTA.Game:StartWaitingForPlayer(playerName, gameId)
                end
                parent:Hide()
            else
                TTA:Print("Player '" .. playerName .. "' is not in your group!")
            end
        else
            TTA:Print("Please enter a player name.")
        end
    end)
    
    local backButton = CreateFrame("Button", nil, panel, "GameMenuButtonTemplate")
    backButton:SetPoint("BOTTOM", panel, "BOTTOM", 0, 60)
    backButton:SetSize(100, 30)
    backButton:SetText("Back")
    backButton:SetScript("OnClick", function()
        editBox:SetText("")
        self:ShowMainMenu()
    end)
    
    self.playerPanel = panel
    self.playerNameEditBox = editBox
end

function UI:CreateGameWindow()
    local frame = CreateFrame("Frame", "TicTacAzerothGameFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT + 50)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            TTA:HandleGameWindowClose()
        end)
    end
    
    frame:Hide()
    
    self.gameFrame = frame
    
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -5)
    frame.title:SetText("TicTacAzeroth")
    
    local gameInfo = frame:CreateFontString(nil, "OVERLAY")
    gameInfo:SetFontObject("GameFontNormal")
    gameInfo:SetPoint("TOP", frame, "TOP", 0, -50)
    gameInfo:SetText("Your turn!")
    self.gameInfo = gameInfo
    
    self:CreateGameBoard(frame)
    
    local newGameButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    newGameButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 20)
    newGameButton:SetSize(100, 30)
    newGameButton:SetText("New Game")
    newGameButton:SetScript("OnClick", function()
        frame:Hide()
        self:ShowMainWindow()
    end)
    
    local closeButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
    closeButton:SetSize(80, 30)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        TTA:HandleGameWindowClose()
    end)
end

function UI:CreateGameBoard(parent)
    local exactBoardSize = (CELL_SIZE * 3) + 4
    
    local boardFrame = CreateFrame("Frame", nil, parent)
    boardFrame:SetSize(exactBoardSize, exactBoardSize)
    boardFrame:SetPoint("CENTER", parent, "CENTER", 0, -10)
    
    for i = 1, 2 do
        local vLine = boardFrame:CreateTexture(nil, "ARTWORK")
        vLine:SetSize(2, CELL_SIZE * 3)
        vLine:SetPoint("TOPLEFT", boardFrame, "TOPLEFT", i * CELL_SIZE - 1, 0)
        vLine:SetColorTexture(1, 1, 1, 0.8)
        
        local hLine = boardFrame:CreateTexture(nil, "ARTWORK")
        hLine:SetSize(CELL_SIZE * 3, 2)  -- Width of 3 cells
        hLine:SetPoint("TOPLEFT", boardFrame, "TOPLEFT", 0, -(i * CELL_SIZE - 1))
        hLine:SetColorTexture(1, 1, 1, 0.8)
    end
    
    self.cells = {}
    for i = 1, 9 do
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3
        
        local cell = CreateFrame("Button", nil, boardFrame)
        cell:SetSize(CELL_SIZE, CELL_SIZE)
        cell:SetPoint("TOPLEFT", boardFrame, "TOPLEFT", col * CELL_SIZE, -row * CELL_SIZE)
        
        local cellBg = cell:CreateTexture(nil, "BACKGROUND")
        cellBg:SetAllPoints()
        cellBg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
        
        local cellText = cell:CreateFontString(nil, "OVERLAY")
        cellText:SetFontObject("GameFontHighlightHuge")
        cellText:SetPoint("CENTER")
        cellText:SetText("")
        
        cell:SetScript("OnEnter", function()
            if TTA.Game.board[i] == TTA.Game.EMPTY and 
               TTA.Game.gameState == TTA.Game.GAME_STATE.PLAYING and 
               TTA.Game.isPlayerTurn then
                cellBg:SetColorTexture(0.3, 0.3, 0.3, 0.7)
            end
        end)
        
        cell:SetScript("OnLeave", function()
            cellBg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
        end)
        
        cell:SetScript("OnClick", function()
            if TTA.Game:MakeMove(i) then
                -- Move was successful, update will be handled by game logic
            end
        end)
        
        cell.text = cellText
        cell.bg = cellBg
        self.cells[i] = cell
    end
    
    self.boardFrame = boardFrame
end

function UI:ShowMainWindow()
    if not self.mainFrame then
        self:Initialize()
    end
    
    self:ShowMainMenu()
    self.mainFrame:Show()
end

function UI:ShowMainMenu()
    if self.difficultyPanel then
        self.difficultyPanel:Hide()
    end
    if self.playerPanel then
        self.playerPanel:Hide()
    end
    
    self.aiButton:Show()
    self.playerButton:Show()
end

function UI:ShowDifficultySelection()
    self.aiButton:Hide()
    self.playerButton:Hide()
    self.difficultyPanel:Show()
end

function UI:ShowPlayerSelection()
    self.aiButton:Hide()
    self.playerButton:Hide()
    self.playerPanel:Show()
end

function UI:ShowGameWindow()
    if not self.gameFrame then
        self:Initialize()
    end
    
    if self.mainFrame and self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    end
    
    self.gameFrame:Show()
    self:UpdateGameInfo()
end

function UI:UpdateGameBoard()
    if not self.cells then
        return
    end
    
    for i = 1, 9 do
        local symbol = TTA.Game.board[i]
        local text = TTA.Game:GetSymbolText(symbol)
        self.cells[i].text:SetText(text)
        
        if symbol == TTA.Game.PLAYER_X then
            self.cells[i].text:SetTextColor(0, 1, 0)
        elseif symbol == TTA.Game.PLAYER_O then
            self.cells[i].text:SetTextColor(1, 0, 0)
        else
            self.cells[i].text:SetTextColor(1, 1, 1)
        end
    end
    
    self:UpdateGameInfo()
end

function UI:UpdateGameInfo()
    if not self.gameInfo then
        return
    end
    
    local text = ""
    
    if TTA.Game.gameState == TTA.Game.GAME_STATE.WAITING_FOR_PLAYER then
        text = "Waiting for " .. (TTA.Game.opponentName or "player") .. " to accept invitation..."
    elseif TTA.Game.gameState == TTA.Game.GAME_STATE.PLAYING then
        if TTA.Game.gameMode == "ai" then
            text = TTA.Game.isPlayerTurn and "Your turn!" or "AI is thinking..."
        elseif TTA.Game.gameMode == "player" then
            if TTA.Game.isPlayerTurn then
                text = "Your turn! (" .. (TTA.Game.playerSymbol == 1 and "X" or "O") .. ")"
            else
                text = (TTA.Game.opponentName or "Opponent") .. " is thinking... (" .. (TTA.Game.playerSymbol == 1 and "O" or "X") .. ")"
            end
        end
    elseif TTA.Game.gameState == TTA.Game.GAME_STATE.FINISHED then
        text = "Game Over"
    end
    
    self.gameInfo:SetText(text)
end

function UI:ShowGameResult(message)
    if TTA.Game.gameMode == "ai" then
        StaticPopup_Show("TICTACAZEROTH_AI_RESULT", message)
    elseif TTA.Game.gameMode == "player" then
        StaticPopup_Show("TICTACAZEROTH_PLAYER_RESULT", message)
    end
end

StaticPopupDialogs["TICTACAZEROTH_AI_RESULT"] = {
    text = "Game Result: %s",
    button1 = "Restart",
    button2 = "Quit",
    OnAccept = function()
        if TTA.Game and TTA.Game.aiDifficulty then
            TTA.Game:StartAIGame(TTA.Game.aiDifficulty)
        end
    end,
    OnCancel = function()
        if TTA.UI and TTA.UI.gameFrame then
            TTA.UI.gameFrame:Hide()
            TTA.UI:ShowMainWindow()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["TICTACAZEROTH_PLAYER_RESULT"] = {
    text = "Game Result: %s",
    button1 = "Restart",
    button2 = "Quit",
    OnAccept = function()
        TTA:SendRestartRequest()
        TTA:Print("Restart request sent. Waiting for " .. (TTA.Game.opponentName or "opponent") .. " to accept...")
    end,
    OnCancel = function()
        TTA:SendQuitGame()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["TICTACAZEROTH_RESTART_REQUEST"] = {
    text = "%s wants to play another round!",
    button1 = "Accept",
    button2 = "Decline",
    OnAccept = function()
        TTA:SendRestartAccept()
    end,
    OnCancel = function()
        TTA:SendRestartDecline()
    end,
    timeout = 30,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["TICTACAZEROTH_GAME_INVITE"] = {
    text = "%s has invited you to play TicTacToe! Type /tta accept to join or /tta decline to refuse.",
    button1 = "Accept",
    button2 = "Decline",
    OnAccept = function()
        TTA:AcceptGameInvite()
    end,
    OnCancel = function()
        TTA:DeclineGameInvite()
    end,
    timeout = 30,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function UI:ShowGameInvite(senderName)
    StaticPopup_Show("TICTACAZEROTH_GAME_INVITE", senderName)
end

function UI:ShowRestartRequest(senderName)
    StaticPopup_Hide("TICTACAZEROTH_PLAYER_RESULT")
    StaticPopup_Hide("TICTACAZEROTH_AI_RESULT")
    
    StaticPopup_Show("TICTACAZEROTH_RESTART_REQUEST", senderName)
end
