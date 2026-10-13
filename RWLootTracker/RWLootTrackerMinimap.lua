local addon = RWLootTrackerGlobal
local broker = LibStub("LibDataBroker-1.1")
local icons = LibStub("LibDBIcon-1.0")
local name = "RWLootTracker"
local button
local watchedParent
local pendingCollectorRefresh = false

local function KeepLibraryIconAboveCollector(button)
    -- LibDBIcon creates and owns this texture. EllesmereUI raises all direct
    -- children of a flyout button after clicks, including its black backdrop.
    -- Keep the existing library texture one frame deeper than that backdrop.
    local icon = button.icon
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints(button)
    holder:EnableMouse(false)
    local layer = CreateFrame("Frame", nil, holder)
    layer:SetAllPoints(holder)
    layer:EnableMouse(false)
    layer.dataObject = button.dataObject
    local updateCoord = icon.UpdateCoord
    icon.UpdateCoord = function(self)
        layer.isMouseDown = button.isMouseDown
        return updateCoord(self)
    end
    icon:SetParent(layer)
end

local function RefreshCollector()
    -- EllesmereUI offers a rebuild for buttons toggled while its flyout is open.
    if not InCombatLockdown() and type(_G._EMM_FullRebuildMinimap) == "function" then
        _G._EMM_FullRebuildMinimap()
    end
end

local function WatchCollectorParent()
    local parent = button and button:GetParent()
    if not parent or parent == Minimap or parent == watchedParent then return end
    watchedParent = parent
    parent:HookScript("OnHide", function(self)
        if pendingCollectorRefresh and button and button:GetParent() == self then
            pendingCollectorRefresh = false
            if LootTrackerConfig.showMinimapButton then
                icons:Show(name)
            else
                icons:Hide(name)
            end
            C_Timer.After(0, RefreshCollector)
        end
    end)
end

function addon.InitializeMinimapButton()
    if button then return end
    local config = LootTrackerConfig
    if type(config.minimap) ~= "table" then config.minimap = {} end
    local db = config.minimap
    -- Preserve the angle from the old hand-built button once, then let
    -- LibDBIcon keep the position in its own SavedVariables table.
    db.minimapPos = tonumber(db.minimapPos) or tonumber(config.minimapAngle) or 225
    config.minimapAngle = nil
    db.hide = config.showMinimapButton == false

    local launcher = broker:NewDataObject(name, {
        type = "launcher",
        label = "Rangeln Worldwide Loot Tracker",
        icon = "Interface\\AddOns\\RWLootTracker\\media\\RangelnIcon.tga",
        OnClick = function(_, mouseButton)
            if mouseButton == "RightButton" then
                addon.OpenSettings()
            else
                addon.OpenGUI()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Rangeln Worldwide Loot Tracker")
            tooltip:AddLine("Linksklick: Kalender öffnen", 1, 1, 1)
            tooltip:AddLine("Rechtsklick: Optionen öffnen", 1, 1, 1)
            if button and button:GetParent() == Minimap then
                local point, relative, relativePoint = button:GetPoint(1)
                if point == "CENTER" and relative == Minimap and relativePoint == "CENTER" then
                    tooltip:AddLine("Ziehen: Button verschieben", 1, 1, 1)
                end
            end
        end,
    })
    if not icons:IsRegistered(name) then
        icons:Register(name, launcher, db)
    else
        icons:Refresh(name, db)
    end
    button = icons:GetMinimapButton(name)
    addon.minimapButton = button
    KeepLibraryIconAboveCollector(button)
    -- LibDBIcon applies db.hide at PLAYER_LOGIN; hide immediately as well so
    -- collectors scanning after ADDON_LOADED never see a temporary button.
    if db.hide then icons:Hide(name) end

    -- The library handles dragging on the minimap. A collector owns the
    -- position of a reparented button, so do not start a drag inside it.
    local startDrag = button:GetScript("OnDragStart")
    local stopDrag = button:GetScript("OnDragStop")
    if startDrag and stopDrag then
        local dragging = false
        button:SetScript("OnDragStart", function(self, ...)
            local point, relative, relativePoint = self:GetPoint(1)
            if self:GetParent() ~= Minimap or point ~= "CENTER"
                or relative ~= Minimap or relativePoint ~= "CENTER" then return end
            dragging = true
            startDrag(self, ...)
        end)
        button:SetScript("OnDragStop", function(self, ...)
            if not dragging then return end
            dragging = false
            stopDrag(self, ...)
        end)
    end
end

function addon.UpdateMinimapButton()
    if not button then return end
    LootTrackerConfig.minimap.hide = LootTrackerConfig.showMinimapButton == false
    if LootTrackerConfig.minimap.hide then
        icons:Hide(name)
    else
        icons:Show(name)
    end
    WatchCollectorParent()
    pendingCollectorRefresh = button:GetParent() ~= Minimap
        and button:GetParent():IsShown() or false
    if not pendingCollectorRefresh then RefreshCollector() end
end
