local addonName, TTA = ...

TTA.Sounds = {}
local Sounds = TTA.Sounds

local SOUND_IDS = {
    -- Game Events
    GAME_START = 567,        -- Quest Complete sound
    MOVE_MADE = 1115,        -- UI Click sound
    
    -- Victory/Defeat
    VICTORY = 888,           -- Level Up sound
    DEFEAT = 846,            -- Death sound
    DRAW = 569,              -- Quest Failed sound
    
    -- Invitations
    INVITE_SENT = 3337,      -- Whisper sound
    INVITE_RECEIVED = 3337,  -- Whisper sound
    INVITE_ACCEPTED = 567,   -- Quest Complete sound
    INVITE_DECLINED = 846,   -- Decline/Error sound
    
    -- UI Events
    BUTTON_CLICK = 1115,     -- UI Click sound
    ERROR = 846,             -- Error sound
    SUCCESS = 567,           -- Success sound
    
    -- AI Events
    AI_THINKING = 1115,      -- Subtle click
    AI_MOVE = 1115,          -- UI Click sound
}

local soundSettings = {
    enabled = true,
    volume = 1.0,
    channel = "Master"
}

function Sounds:Initialize()
    if TicTacAzerothDB and TicTacAzerothDB.sounds then
        for key, value in pairs(TicTacAzerothDB.sounds) do
            if soundSettings[key] ~= nil then
                soundSettings[key] = value
            end
        end
    end
end

function Sounds:SaveSettings()
    if not TicTacAzerothDB then
        TicTacAzerothDB = {}
    end
    TicTacAzerothDB.sounds = soundSettings
end

function Sounds:PlaySound(soundName, volume)
    if not soundSettings.enabled then
        return
    end
    
    local soundId = SOUND_IDS[soundName]
    if not soundId then
        TTA:Debug("Unknown sound: " .. tostring(soundName))
        return
    end
    
    local actualVolume = volume or soundSettings.volume
    TTA:Debug("Playing sound: " .. soundName .. " (ID: " .. soundId .. ")")
    
    PlaySound(soundId, soundSettings.channel)
end

function Sounds:PlayGameStart()
    self:PlaySound("GAME_START")
end

function Sounds:PlayMoveMade()
    self:PlaySound("MOVE_MADE", 0.7)
end

function Sounds:PlayVictory()
    self:PlaySound("VICTORY")
end

function Sounds:PlayDefeat()
    self:PlaySound("DEFEAT")
end

function Sounds:PlayDraw()
    self:PlaySound("DRAW")
end

function Sounds:PlayInviteSent()
    self:PlaySound("INVITE_SENT")
end

function Sounds:PlayInviteReceived()
    self:PlaySound("INVITE_RECEIVED")
end

function Sounds:PlayInviteAccepted()
    self:PlaySound("INVITE_ACCEPTED")
end

function Sounds:PlayInviteDeclined()
    self:PlaySound("INVITE_DECLINED")
end

function Sounds:PlayError()
    self:PlaySound("ERROR")
end

function Sounds:PlaySuccess()
    self:PlaySound("SUCCESS")
end

function Sounds:PlayAIThinking()
    self:PlaySound("AI_THINKING", 0.5)
end

function Sounds:PlayAIMove()
    self:PlaySound("AI_MOVE", 0.8)
end

function Sounds:IsEnabled()
    return soundSettings.enabled
end

function Sounds:SetEnabled(enabled)
    soundSettings.enabled = enabled
    self:SaveSettings()
end

function Sounds:GetVolume()
    return soundSettings.volume
end

function Sounds:SetVolume(volume)
    soundSettings.volume = math.max(0, math.min(1, volume))
    self:SaveSettings()
end

function Sounds:GetChannel()
    return soundSettings.channel
end

function Sounds:SetChannel(channel)
    soundSettings.channel = channel
    self:SaveSettings()
end
