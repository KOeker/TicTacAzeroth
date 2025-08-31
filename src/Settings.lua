local addonName, TTA = ...

TTA.Settings = {}
local Settings = TTA.Settings

local defaultConfig = {
    autoDeclineInvites = false,
}

local TicTacAzerothPanelMixin = {}

function TicTacAzerothPanelMixin:SetupPanel()
    self.cancel = function() self:Cancel() end
    self.okay = function() if self.shownSettings then self:Save() end end
    self.shownSettings = false
    self.OnCommit = self.okay
    self.OnDefault = function() end
    self.OnRefresh = function() end

    if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
        local category = _G.Settings.RegisterCanvasLayoutCategory(self, self.name)
        category.ID = self.name
        _G.Settings.RegisterAddOnCategory(category)
    else
        if InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(self, self.name)
        end
    end
end

function TicTacAzerothPanelMixin:OnShow()
    self:ShowSettings()
    self.shownSettings = true
end

function TicTacAzerothPanelMixin:Cancel()
    -- Cancel changes
end

function TicTacAzerothPanelMixin:Save()
    -- Save changes
end

function TicTacAzerothPanelMixin:ShowSettings()
    -- Override in subclass
end

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

function SettingsPanel:new(parent, name)
    local obj = {}
    obj.parent = parent
    obj.name = name or "TicTacAzeroth"
    obj.rows = {}
    obj.currentY = -20
    obj.rowHeight = 35
    obj.scrollChild = parent
    
    setmetatable(obj, self)
    return obj
end

function SettingsPanel:createOptionRowWithLabel(labelText)
    local row = CreateFrame("Frame", nil, self.scrollChild or self)
    row:SetSize(600, self.rowHeight)
    row:SetPoint("TOPLEFT", self.scrollChild or self, "TOPLEFT", 20, self.currentY)
    
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetText(labelText)
    label:SetWidth(400)
    label:SetJustifyH("LEFT")
    
    row:Show()
    table.insert(self.rows, row)
    self.currentY = self.currentY - (self.rowHeight + 10)
    
    return row
end

function SettingsPanel:addCheckboxToLastRow(onClick, checked)
    local row = self.rows[#self.rows]
    if not row then return end
    
    local checkbox = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    checkbox:SetChecked(checked)
    checkbox:SetScript("OnClick", onClick)
    
    return checkbox
end

function Settings:Initialize()
    if not TicTacAzerothDB then
        TicTacAzerothDB = {}
    end
    
    for key, value in pairs(defaultConfig) do
        if TicTacAzerothDB[key] == nil then
            TicTacAzerothDB[key] = value
        end
    end
end

function Settings:CreatePanels()
    self:CreateSettingsPanel()
end

function Settings:CreateSettingsPanel()
    local mainPanel = CreateFrame("Frame", "TicTacAzerothConfigFrame")
    mainPanel:SetSize(650, 500)
    Mixin(mainPanel, TicTacAzerothPanelMixin)
    mainPanel.name = "TicTacAzeroth"
    mainPanel:SetupPanel()
    
    function mainPanel:ShowSettings()
        -- Main settings display
    end
    
    local settingsPanel = SettingsPanel:new(mainPanel, "TicTacAzeroth")
    
    settingsPanel:createOptionRowWithLabel("Auto-decline game invitations")
    settingsPanel:addCheckboxToLastRow(function(self)
        local checked = self:GetChecked()
        TicTacAzerothDB.autoDeclineInvites = checked
        
        if checked then
            TTA:Print("Auto-decline invitations: Enabled")
        else
            TTA:Print("Auto-decline invitations: Disabled")
        end
    end, TicTacAzerothDB.autoDeclineInvites or false)
    
    return mainPanel
end

function Settings:Get(key)
    return TicTacAzerothDB[key]
end

function Settings:Set(key, value)
    TicTacAzerothDB[key] = value
end

local function loadSettings(_, _, addonName)
    if addonName ~= "TicTacAzeroth" then
        return
    end
    
    TTA.Settings:CreatePanels()
    
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", loadSettings)
