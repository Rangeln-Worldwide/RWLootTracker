RWLootTrackerGlobal = RWLootTrackerGlobal or {}

function RWLootTrackerGlobal.GetVersion()
    local toc_version = C_AddOns.GetAddOnMetadata("RWLootTracker", "Version")
    if toc_version then
        return toc_version
    else
        return "B.o.b.r"
    end
end

local defaults = {
    DebugMode = false,
    LogToChat = true,
    AddTableHeader = true,
    showMinimapButton = true,
    checkRaidLeader = false;
    guildName = "Rangeln Worldwide",
    trackedRaidDifficulties = {
        ["NHC"] = true,  -- 14
        ["HC"] = true,  -- 15
        ["MYTHIC"] = true,  -- 16
        ["MYTHIC_FLEX"] = true, -- 233
        ["LFR"] = false,  -- 17
    },
}

local function DebugPrint(msg)
    if LootTrackerConfig and LootTrackerConfig.DebugMode then
        print("RWLootTracker.lua: " .. msg)
    end
end


local function ApplyDefaults(targetTable, defaultTable)
    for k, v in pairs(defaultTable) do
        if type(v) == "table" then
            if type(targetTable[k]) ~= "table" then
                targetTable[k] = {}
            end
            ApplyDefaults(targetTable[k], v) 
        elseif targetTable[k] == nil then
            targetTable[k] = v
        end
    end
end

RWLootTrackerGlobal.lootTrackerFrame = nil        
RWLootTrackerGlobal.lootDatabasePanel = nil       
RWLootTrackerGlobal.settingsPanel = nil           
RWLootTrackerGlobal.tabButtons = {}               
RWLootTrackerGlobal.calendarFrame = nil           
RWLootTrackerGlobal.currentCalendarDate = date("*t") 
RWLootTrackerGlobal.lootDetailsFrame = nil        

-- Funktion zum Initialisieren des Bestätigungs-Popups einmalig
function RWLootTrackerGlobal.InitializeConfirmDialog()
    if RWLootTrackerGlobal.confirmDialog then return end
    DebugPrint("InitializeConfirmDialog: Dialog-Frame initialisiert.")
    local dialog = CreateFrame("Frame", "LootTrackerConfirmDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(350, 180)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("TOOLTIP") -- Höchste Sichtbarkeit
    dialog:SetFrameLevel(100) -- Hoher Level innerhalb der Strata
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:Hide() -- Initial ausblenden

    dialog.titleText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.titleText:SetPoint("TOP", dialog, "TOP", 0, -5)
    dialog.titleText:SetTextColor(1, 1, 1, 1)

    dialog.messageText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dialog.messageText:SetPoint("TOPLEFT", dialog, "TOPLEFT", 25, -60)
    dialog.messageText:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -25, -60)
    dialog.messageText:SetJustifyH("CENTER")
    dialog.messageText:SetJustifyV("TOP")
    dialog.messageText:SetTextColor(1, 0, 0, 1)
    dialog.messageText:SetMaxLines(5)

    dialog.confirmButton = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
    dialog.confirmButton:SetSize(80, 25)
    dialog.confirmButton:SetPoint("BOTTOM", dialog, "BOTTOM", -45, 25)
    dialog.confirmButton:SetText("Ja")

    dialog.cancelButton = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
    dialog.cancelButton:SetSize(80, 25)
    dialog.cancelButton:SetPoint("BOTTOM", dialog, "BOTTOM", 45, 25)
    dialog.cancelButton:SetText("Nein")
    

    RWLootTrackerGlobal.confirmDialog = dialog -- Globale Referenz speichern
end

function RWLootTrackerGlobal.ShowConfirmDialog(title, message, onConfirmCallback, onCancelCallback)
    DebugPrint("ShowConfirmDialog: Popup anzeigen für '" .. title .. "'")
    local dialog = RWLootTrackerGlobal.confirmDialog
    if not dialog then
        DebugPrint("ShowConfirmDialog: FEHLER: ConfirmDialog nicht initialisiert. Rufe InitializeConfirmDialog auf.")
        RWLootTrackerGlobal.InitializeConfirmDialog()
        dialog = RWLootTrackerGlobal.confirmDialog
        if not dialog then
            DebugPrint("ShowConfirmDialog: FEHLER: ConfirmDialog konnte auch nach Initialisierung nicht erstellt werden.")
            return
        end
    end

    dialog.titleText:SetText(title)
    dialog.messageText:SetText(message)

    dialog.confirmButton:SetScript("OnClick", function()
        DebugPrint("ConfirmDialog: Ja geklickt.")
        dialog:Hide() -- Popup ausblenden
        if onConfirmCallback then onConfirmCallback() end -- Aktion ausführen
    end)

    dialog.cancelButton:SetScript("OnClick", function()
        DebugPrint("ConfirmDialog: Nein geklickt.")
        dialog:Hide() -- Popup ausblenden
        if onCancelCallback then onCancelCallback() end -- Aktion ausführen
    end)

    dialog:Show()
    DebugPrint("ShowConfirmDialog: Popup Show() aufgerufen.")
end


function RWLootTrackerGlobal.CreateSettingsPanelElements(parentFrame)
    ApplyDefaults(LootTrackerConfig, defaults)

    local logo = parentFrame:CreateTexture(nil, "OVERLAY")
    logo:SetTexture("Interface/AddOns/RWLootTracker/media/RangelnIcon.tga")
    logo:SetSize(192, 192)
    logo:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -5, -5)

    local title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 16, -15)
    title:SetText("Rangeln Worldwide Loot Tracker")

    local function AddSection(text, y)
        local heading = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 16, y)
        heading:SetText(text)
        local line = parentFrame:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.68, 0.53, 0.25, 0.45)
        line:SetHeight(1)
        line:SetPoint("LEFT", heading, "RIGHT", 12, 0)
        line:SetPoint("RIGHT", parentFrame, "RIGHT", -18, 0)
    end

    local function AddCheckbox(text, x, y, checked, onClick)
        local check = CreateFrame("CheckButton", nil, parentFrame, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
        check:SetChecked(checked)
        check.label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        check.label:SetText(text)
        check:SetScript("OnClick", function(self)
            onClick(not not self:GetChecked())
        end)
        return check
    end

    local openButton = CreateFrame("Button", nil, parentFrame, "GameMenuButtonTemplate")
    openButton:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 18, -49)
    openButton:SetSize(180, 28)
    openButton:SetText("Kalender öffnen")
    openButton:SetScript("OnClick", RWLootTrackerGlobal.OpenGUI)

    AddSection("Allgemein", -96)
    AddCheckbox("Minimap-Button anzeigen", 16, -119,
        LootTrackerConfig.showMinimapButton, function(enabled)
            LootTrackerConfig.showMinimapButton = enabled
            if RWLootTrackerGlobal.UpdateMinimapButton then
                RWLootTrackerGlobal.UpdateMinimapButton()
            end
        end)
    AddCheckbox("Meldungen an Chat senden", 16, -148,
        LootTrackerConfig.LogToChat, function(enabled)
            LootTrackerConfig.LogToChat = enabled
        end)
    AddCheckbox("Kopfzeile beim Sheets-Export", 16, -177,
        LootTrackerConfig.AddTableHeader, function(enabled)
            LootTrackerConfig.AddTableHeader = enabled
        end)

    AddSection("Raid-Schwierigkeiten", -216)
    local difficulties = {
        {"Normal Raid", "NHC", 16, -245},
        {"HC Raid", "HC", 226, -245},
        {"Mythic Raid", "MYTHIC", 16, -275},
        {"Mythic Flex Raid", "MYTHIC_FLEX", 226, -275},
        {"LFR", "LFR", 16, -305},
    }
    for _, entry in ipairs(difficulties) do
        local key = entry[2]
        AddCheckbox(entry[1], entry[3], entry[4],
            LootTrackerConfig.trackedRaidDifficulties[key], function(enabled)
                LootTrackerConfig.trackedRaidDifficulties[key] = enabled
            end)
    end

    AddSection("Raidleiter-Filter", -340)
    local guildNameEditBox
    local function SetGuildFieldEnabled(enabled)
        if not guildNameEditBox then return end
        if enabled then
            guildNameEditBox:Enable()
            guildNameEditBox:SetTextColor(1, 1, 1)
        else
            guildNameEditBox:Disable()
            guildNameEditBox:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    AddCheckbox("Raidleiter-Gilde prüfen", 16, -365,
        LootTrackerConfig.checkRaidLeader, function(enabled)
            LootTrackerConfig.checkRaidLeader = enabled
            SetGuildFieldEnabled(enabled)
        end)
    local guildLabel = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildLabel:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 52, -401)
    guildLabel:SetText("Gildenname des Raidleiters:")
    guildNameEditBox = CreateFrame("EditBox", nil, parentFrame, "InputBoxTemplate")
    guildNameEditBox:SetSize(200, 20)
    guildNameEditBox:SetPoint("LEFT", guildLabel, "RIGHT", 10, 0)
    guildNameEditBox:SetTextInsets(5, 5, 5, 5)
    guildNameEditBox:SetAutoFocus(false)
    guildNameEditBox:SetText(LootTrackerConfig.guildName)
    guildNameEditBox:SetScript("OnEnterPressed", function(self)
        LootTrackerConfig.guildName = self:GetText()
        self:ClearFocus()
    end)
    guildNameEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(LootTrackerConfig.guildName)
        self:ClearFocus()
    end)
    guildNameEditBox:SetScript("OnEditFocusLost", function(self)
        LootTrackerConfig.guildName = self:GetText()
        self:SetTextColor(1, 1, 1)
    end)
    guildNameEditBox:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= LootTrackerConfig.guildName then
            self:SetTextColor(1, 0, 0)
        elseif LootTrackerConfig.checkRaidLeader then
            self:SetTextColor(1, 1, 1)
        else
            self:SetTextColor(0.5, 0.5, 0.5)
        end
    end)
    SetGuildFieldEnabled(LootTrackerConfig.checkRaidLeader)

    AddSection("Wartung", -429)
    AddCheckbox("Debug Mode", 16, -453, LootTrackerConfig.DebugMode, function(enabled)
        LootTrackerConfig.DebugMode = enabled
    end)
    local clearButton = CreateFrame("Button", nil, parentFrame, "GameMenuButtonTemplate")
    clearButton:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 220, -450)
    clearButton:SetSize(180, 28)
    clearButton:SetText("Datenbank leeren")
    clearButton:SetScript("OnClick", function()
        RWLootTrackerGlobal.ShowConfirmDialog(
            "Datenbank leeren",
            "Wollen Sie Ihre Datenbank wirklich leeren? Alle Daten werden unwiderruflich gelöscht.",
            function()
                LootTrackerDB = {}
                RWLootTrackerGlobal.InitializeCalendar()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RWLootTracker]|r Die Beutedatenbank wurde erfolgreich geleert.")
            end,
            function()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RWLootTracker]|r Das Leeren der Beutedatenbank wurde abgebrochen.")
            end
        )
    end)
end

RWLootTrackerGlobal.settingsPanel = CreateFrame("Frame", nil, UIParent)
RWLootTrackerGlobal.settingsPanel.name = "RW Loot Tracker"

local category = Settings.RegisterCanvasLayoutCategory(RWLootTrackerGlobal.settingsPanel, RWLootTrackerGlobal.settingsPanel.name)
Settings.RegisterAddOnCategory(category)

function RWLootTrackerGlobal.OpenSettings()
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[RWLootTracker]|r Optionen können nach dem Kampf geöffnet werden.")
        return
    end
    Settings.OpenToCategory(category:GetID())
end

RWLootTrackerGlobal.settingsPanel:SetScript("OnShow", function(self)
    if not self.elementsCreated then
            DebugPrint("settingsPanel OnShow aufgerufen. Erstelle GUI-Elemente...")
            RWLootTrackerGlobal.CreateSettingsPanelElements(self)
            self.elementsCreated = true
    end
end)


function RWLootTrackerGlobal.OpenGUI()
    if RWLootTrackerGlobal.CreateGUI and type(RWLootTrackerGlobal.CreateGUI) == "function" then
        RWLootTrackerGlobal.CreateGUI()
    else
        print("RWLootTracker: GUI-Modul nicht geladen.")
    end
end


SLASH_RWLOOTTRACKER1 = "/rwloottracker"
SLASH_RWLOOTTRACKER2 = "/rwl"

SlashCmdList["RWLOOTTRACKER"] = function(msg)
    RWLootTrackerGlobal.OpenGUI()
end


function RWL_CompartmentClickAction()
    RWLootTrackerGlobal.OpenGUI()
end

-- SavedVariables stehen nach ADDON_LOADED zuverlässig bereit. Insbesondere der
-- Minimap-Button darf vorher nicht mit einem vorläufigen Default registriert werden.
local loadingFrame = CreateFrame("Frame")
loadingFrame:RegisterEvent("ADDON_LOADED")
loadingFrame:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= "RWLootTracker" then return end
    self:UnregisterEvent("ADDON_LOADED")
    LootTrackerConfig = LootTrackerConfig or {}
    LootTrackerDB = LootTrackerDB or {}
    ApplyDefaults(LootTrackerConfig, defaults)
    if RWLootTrackerGlobal.NormalizeTransferredEntries then
        RWLootTrackerGlobal.NormalizeTransferredEntries()
    end
    if RWLootTrackerGlobal.InitializeMinimapButton then
        RWLootTrackerGlobal.InitializeMinimapButton()
    end
end)


DebugPrint("Core-Modul RWLootTracker.lua geladen. " .. RWLootTrackerGlobal.GetVersion())
