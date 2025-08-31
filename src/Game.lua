local addonName, TTA = ...

TTA.Game = {}
local Game = TTA.Game

local EMPTY = 0
local PLAYER_X = 1
local PLAYER_O = 2

local GAME_STATE = {
    MENU = 0,
    PLAYING = 1,
    FINISHED = 2,
    WAITING_FOR_PLAYER = 3
}

local AI_DIFFICULTY = {
    EASY = 1,
    MEDIUM = 2,
    HARD = 3
}

function Game:Initialize()
    self:ResetGame()
end

function Game:ResetGame()
    self.board = {0, 0, 0, 0, 0, 0, 0, 0, 0}
    self.currentPlayer = PLAYER_X
    self.gameState = GAME_STATE.MENU
    self.gameMode = nil
    self.aiDifficulty = AI_DIFFICULTY.MEDIUM
    self.winner = nil
    self.isPlayerTurn = true
    self.opponentName = nil
    self.gameId = nil
    self.playerSymbol = nil
end

function Game:StartAIGame(difficulty)
    self:ResetGame()
    self.gameMode = "ai"
    self.aiDifficulty = difficulty or AI_DIFFICULTY.MEDIUM
    self.gameState = GAME_STATE.PLAYING
    self.isPlayerTurn = true
    
    TTA:Print("Starting game against AI (Difficulty: " .. self:GetDifficultyName(difficulty) .. ")")
    
    if TTA.Sounds then
        TTA.Sounds:PlayGameStart()
    end
    
    if TTA.UI then
        TTA.UI:UpdateGameBoard()
        TTA.UI:ShowGameWindow()
    end
end

function Game:StartSimplePlayerGame(opponentName, isInviter)
    self:ResetGame()
    self.gameMode = "player"
    self.gameState = GAME_STATE.PLAYING
    self.opponentName = opponentName
    
    self.isPlayerTurn = isInviter
    self.playerSymbol = isInviter and PLAYER_X or PLAYER_O
    
    local turnInfo = self.isPlayerTurn and "You start (X)!" or "Opponent starts (O). Wait for their move."
    TTA:Print("Starting game against " .. opponentName .. " - " .. turnInfo)
    
    if TTA.UI then
        TTA.UI:UpdateGameBoard()
        TTA.UI:ShowGameWindow()
        TTA.UI:UpdateGameInfo()
    end
end

function Game:StartWaitingForPlayer(opponentName, gameId)
    self:ResetGame()
    self.gameMode = "player"
    self.gameState = GAME_STATE.WAITING_FOR_PLAYER
    self.opponentName = opponentName
    self.gameId = gameId
    
    TTA:Print("Waiting for " .. opponentName .. " to accept invitation...")
    
    if TTA.UI then
        TTA.UI:ShowGameWindow()
        TTA.UI:UpdateGameBoard()
        TTA.UI:UpdateGameInfo()
    end
end

function Game:StartPlayerGame(opponentName, gameId)
    if self.gameState ~= GAME_STATE.WAITING_FOR_PLAYER then
        self:ResetGame()
        self.gameMode = "player"
        self.opponentName = opponentName
        self.gameId = gameId or self:GenerateGameId()
    end
    
    self.gameState = GAME_STATE.PLAYING
    
    local hash = self.gameId or math.random(1000000)

    local playerName = UnitName("player")
    local opponentName = self.opponentName
    
    local isInviter = playerName < opponentName
    local inviterStarts = (hash % 2) == 0
    
    local playerStartsFirst = (isInviter and inviterStarts) or (not isInviter and not inviterStarts)
    
    self.isPlayerTurn = playerStartsFirst
    self.playerSymbol = playerStartsFirst and PLAYER_X or PLAYER_O
    
    local turnInfo = self.isPlayerTurn and "You start (X)!" or "Opponent starts (O). Wait for their move."
    TTA:Print("Starting game against " .. opponentName .. " - " .. turnInfo)
    
    if TTA.Sounds then
        TTA.Sounds:PlayGameStart()
    end
    
    TTA:Debug("StartPlayerGame - State: " .. self.gameState .. ", PlayerTurn: " .. tostring(self.isPlayerTurn) .. ", Symbol: " .. tostring(self.playerSymbol))
    
    if TTA.UI then
        TTA.UI:UpdateGameBoard()
        TTA.UI:ShowGameWindow()
        TTA.UI:UpdateGameInfo()
        TTA:Debug("UI updated in StartPlayerGame")
    else
        TTA:Debug("TTA.UI not available")
    end
end

function Game:MakeMove(position)
    if self.gameState ~= GAME_STATE.PLAYING then
        return false
    end
    
    if self.board[position] ~= EMPTY then
        return false
    end
    
    if not self.isPlayerTurn then
        if self.gameMode == "player" then
            TTA:Print("It's not your turn!")
        else
            TTA:Print("Wait for AI to make its move!")
        end
        return false
    end
    
    local symbol
    if self.gameMode == "player" then
        symbol = self.playerSymbol
    else
        symbol = PLAYER_X
    end
    
    self.board[position] = symbol
    
    if TTA.Sounds then
        TTA.Sounds:PlayMoveMade()
    end
    
    local winner = self:CheckWinner()
    local isGameEnd = winner or self:IsBoardFull()
    
    if self.gameMode == "player" then
        TTA:SendMessage("MOVE:" .. position, self.opponentName)
        
        if isGameEnd then
            local opponentMessage
            if not winner and self:IsBoardFull() then -- Draw
                opponentMessage = "GAME_END:DRAW"
            elseif winner == symbol then
                opponentMessage = "GAME_END:LOST"
            else
                opponentMessage = "GAME_END:WON"
            end
            TTA:SendMessage(opponentMessage, self.opponentName)
        else
            self.isPlayerTurn = false
        end
    end
    
    if winner then
        self:EndGame(winner)
    elseif self:IsBoardFull() then
        self:EndGame(0)
    else
        if self.gameMode == "ai" then
            self.isPlayerTurn = false
            C_Timer.After(0.5, function()
                self:MakeAIMove()
            end)
        end
    end
    
    if TTA.UI then
        TTA.UI:UpdateGameBoard()
    end
    
    return true
end

function Game:HandleOpponentMove(position)
    if self.gameState ~= GAME_STATE.PLAYING then
        return
    end
    
    if self.board[position] ~= EMPTY then
        return
    end
    
    if self.isPlayerTurn then
        TTA:Print("Received move but it's still your turn - ignoring")
        return
    end
    
    local opponentSymbol = (self.playerSymbol == PLAYER_X) and PLAYER_O or PLAYER_X
    self.board[position] = opponentSymbol
    
    if TTA.Sounds then
        TTA.Sounds:PlayMoveMade()
    end
    
    self.isPlayerTurn = true
    
    if TTA.UI then
        TTA.UI:UpdateGameBoard()
        TTA.UI:UpdateGameInfo()
    end
end

function Game:MakeAIMove()
    if self.gameState ~= GAME_STATE.PLAYING or self.isPlayerTurn then
        return
    end
    
    local move = self:GetAIMove()
    if move then
        self.board[move] = PLAYER_O
        
        if TTA.Sounds then
            TTA.Sounds:PlayAIMove()
        end
        
        local winner = self:CheckWinner()
        if winner then
            self:EndGame(winner)
        elseif self:IsBoardFull() then
            self:EndGame(0)
        else
            self.isPlayerTurn = true
        end
        
        if TTA.UI then
            TTA.UI:UpdateGameBoard()
        end
    end
end

function Game:GetAIMove()
    if self.aiDifficulty == AI_DIFFICULTY.EASY then
        return self:GetRandomMove()
    elseif self.aiDifficulty == AI_DIFFICULTY.MEDIUM then
        if math.random() < 0.7 then
            return self:GetSmartMove()
        else
            return self:GetRandomMove()
        end
    else
        return self:GetSmartMove()
    end
end

function Game:GetRandomMove()
    local availableMoves = {}
    for i = 1, 9 do
        if self.board[i] == EMPTY then
            table.insert(availableMoves, i)
        end
    end
    
    if #availableMoves > 0 then
        return availableMoves[math.random(#availableMoves)]
    end
    return nil
end

function Game:GetSmartMove()
    for i = 1, 9 do
        if self.board[i] == EMPTY then
            self.board[i] = PLAYER_O
            if self:CheckWinner() == PLAYER_O then
                self.board[i] = EMPTY
                return i
            end
            self.board[i] = EMPTY
        end
    end
    
    for i = 1, 9 do
        if self.board[i] == EMPTY then
            self.board[i] = PLAYER_X
            if self:CheckWinner() == PLAYER_X then
                self.board[i] = EMPTY
                return i
            end
            self.board[i] = EMPTY
        end
    end
    
    if self.board[5] == EMPTY then
        return 5
    end
    
    local corners = {1, 3, 7, 9}
    for _, corner in ipairs(corners) do
        if self.board[corner] == EMPTY then
            return corner
        end
    end
    
    return self:GetRandomMove()
end

function Game:CheckWinner()
    local winPatterns = {
        {1, 2, 3}, {4, 5, 6}, {7, 8, 9},
        {1, 4, 7}, {2, 5, 8}, {3, 6, 9},
        {1, 5, 9}, {3, 5, 7}
    }
    
    for _, pattern in ipairs(winPatterns) do
        local a, b, c = pattern[1], pattern[2], pattern[3]
        if self.board[a] ~= EMPTY and 
           self.board[a] == self.board[b] and 
           self.board[b] == self.board[c] then
            return self.board[a]
        end
    end
    
    return nil
end

function Game:IsBoardFull()
    for i = 1, 9 do
        if self.board[i] == EMPTY then
            return false
        end
    end
    return true
end

function Game:EndGame(winner)
    self.gameState = GAME_STATE.FINISHED
    self.winner = winner
    
    local message
    if winner == 0 then
        message = "It's a draw!"
        if TTA.Sounds then
            TTA.Sounds:PlayDraw()
        end
    elseif self.gameMode == "ai" then
        if winner == PLAYER_X then
            message = "You won!"
            if TTA.Sounds then
                TTA.Sounds:PlayVictory()
            end
        else
            message = "AI won!"
            if TTA.Sounds then
                TTA.Sounds:PlayDefeat()
            end
        end
    else
        if winner == self.playerSymbol then
            message = "You won!"
            if TTA.Sounds then
                TTA.Sounds:PlayVictory()
            end
        else
            message = self.opponentName .. " won!"
            if TTA.Sounds then
                TTA.Sounds:PlayDefeat()
            end
        end
    end
    
    TTA:Print(message)
    
    if TTA.UI then
        TTA.UI:ShowGameResult(message)
    end
end

function Game:GetDifficultyName(difficulty)
    if difficulty == AI_DIFFICULTY.EASY then
        return "Easy"
    elseif difficulty == AI_DIFFICULTY.MEDIUM then
        return "Medium"
    else
        return "Hard"
    end
end

function Game:GetSymbolText(symbol)
    if symbol == PLAYER_X then
        return "X"
    elseif symbol == PLAYER_O then
        return "O"
    else
        return ""
    end
end

function Game:GenerateGameId()
    return tostring(GetTime()) .. "_" .. UnitName("player")
end

Game.EMPTY = EMPTY
Game.PLAYER_X = PLAYER_X
Game.PLAYER_O = PLAYER_O
Game.GAME_STATE = GAME_STATE
Game.AI_DIFFICULTY = AI_DIFFICULTY
