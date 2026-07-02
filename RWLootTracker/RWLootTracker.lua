RWLootTrackerGlobal = RWLootTrackerGlobal or {}

LootTrackerConfig = LootTrackerConfig or {}

-- Addon-Datenbank für Beute-Einträge
LootTrackerDB = LootTrackerDB or {}

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

    local rangelnIconImage = parentFrame:CreateTexture(nil, "OVERLAY")
    rangelnIconImage:SetTexture("Interface/AddOns/RWLootTracker/media/RangelnIcon.tga")
    rangelnIconImage:SetSize(192, 192) 
    rangelnIconImage:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -5, 0)

    local configChatFrame = CreateFrame("Frame", nil, parentFrame)
    configChatFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -15)
    configChatFrame:SetSize(300, 30)
    configChatFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 1)

    local generalLabel = configChatFrame:CreateFontString(nil, "OVERLAY")
    generalLabel:SetFontObject("GameFontHighlightLarge")
    generalLabel:SetPoint("TOPLEFT", configChatFrame, "TOPLEFT", 0, 5)
    generalLabel:SetText("Rangeln Worldwide Loot Tracker")
    generalLabel:SetTextColor(1, 1, 1, 1)
    generalLabel:SetDrawLayer("OVERLAY")

    local openCalendarButton = CreateFrame("Button", nil, configChatFrame, "GameMenuButtonTemplate")
    openCalendarButton:SetPoint("TOPLEFT", configChatFrame, "BOTTOMLEFT", 15, 0)
    openCalendarButton:SetSize(180, 30)
    openCalendarButton:SetText("Kalender öffnen")
    openCalendarButton:SetScript("OnClick", function()
        DebugPrint("Kalender öffnen button clicked.")
        if RWLootTrackerGlobal.CreateGUI and type(RWLootTrackerGlobal.CreateGUI) == "function" then
            RWLootTrackerGlobal.CreateGUI()
        else
            DebugPrint("RWLootTracker: GUI-Modul nicht geladen oder CreateGUI-Funktion nicht verfügbar. Bitte Addon neuladen.")
        end
        end)

    local logToChatCheckbox = CreateFrame("CheckButton", nil, openCalendarButton, "UICheckButtonTemplate")
    logToChatCheckbox:SetPoint("LEFT", openCalendarButton, "LEFT", 0, -40)
    logToChatCheckbox:SetFrameLevel(configChatFrame:GetFrameLevel() + 1)

    logToChatCheckbox.text = logToChatCheckbox:CreateFontString(nil, "OVERLAY")
    logToChatCheckbox.text:SetFontObject("GameFontNormal")
    logToChatCheckbox.text:SetPoint("LEFT", logToChatCheckbox, "RIGHT", 5, 0)
    logToChatCheckbox.text:SetText("Meldungen an Chat senden")
    logToChatCheckbox.text:SetTextColor(1, 1, 1, 1)
    logToChatCheckbox.text:SetDrawLayer("OVERLAY")

    logToChatCheckbox:SetChecked(LootTrackerConfig.LogToChat)

    logToChatCheckbox:SetScript("OnClick", function(self)
        LootTrackerConfig.LogToChat = self:GetChecked()
        DebugPrint("'Meldungen an Chat senden' auf " .. tostring(LootTrackerConfig.LogToChat) .. " gesetzt.")
    end)

    local debugModeCheckboxFrame = CreateFrame("Frame", nil, parentFrame)
    debugModeCheckboxFrame:SetPoint("TOPLEFT", logToChatCheckbox, "BOTTOMLEFT", 0, -10)
    debugModeCheckboxFrame:SetSize(300, 30)
    debugModeCheckboxFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 1)

    local debugModeCheckbox = CreateFrame("CheckButton", nil, debugModeCheckboxFrame, "UICheckButtonTemplate")
    debugModeCheckbox:SetPoint("LEFT", debugModeCheckboxFrame, "LEFT", 0, 0)
    debugModeCheckbox:SetFrameLevel(debugModeCheckboxFrame:GetFrameLevel() + 1)

    debugModeCheckbox.text = debugModeCheckbox:CreateFontString(nil, "OVERLAY")
    debugModeCheckbox.text:SetFontObject("GameFontNormal")
    debugModeCheckbox.text:SetPoint("LEFT", debugModeCheckbox, "RIGHT", 5, 0)
    debugModeCheckbox.text:SetText("Debug Mode")
    debugModeCheckbox.text:SetTextColor(1, 1, 1, 1)
    debugModeCheckbox.text:SetDrawLayer("OVERLAY")

    debugModeCheckbox:SetChecked(LootTrackerConfig.DebugMode)

    debugModeCheckbox:SetScript("OnClick", function(self)
        LootTrackerConfig.DebugMode = self:GetChecked()
        DebugPrint("'Debug Mode' auf " .. tostring(LootTrackerConfig.DebugMode) .. " gesetzt.")
    end)

    local addTableHeaderCheckboxFrame = CreateFrame("Frame", nil, parentFrame)
    addTableHeaderCheckboxFrame:SetPoint("TOPLEFT", debugModeCheckbox, "BOTTOMLEFT", 0, -10)
    addTableHeaderCheckboxFrame:SetSize(300, 30)
    addTableHeaderCheckboxFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 1)

    local addTableHeaderCheckbox = CreateFrame("CheckButton", nil, addTableHeaderCheckboxFrame, "UICheckButtonTemplate")
    addTableHeaderCheckbox:SetPoint("LEFT", addTableHeaderCheckboxFrame, "LEFT", 0, 0)
    addTableHeaderCheckbox:SetFrameLevel(addTableHeaderCheckboxFrame:GetFrameLevel() + 1)

    addTableHeaderCheckbox.text = addTableHeaderCheckbox:CreateFontString(nil, "OVERLAY")
    addTableHeaderCheckbox.text:SetFontObject("GameFontNormal")
    addTableHeaderCheckbox.text:SetPoint("LEFT", addTableHeaderCheckbox, "RIGHT", 5, 0)
    addTableHeaderCheckbox.text:SetText("Kopfzeile in Tabelle anzeigen")
    addTableHeaderCheckbox.text:SetTextColor(1, 1, 1, 1)
    addTableHeaderCheckbox.text:SetDrawLayer("OVERLAY")

    addTableHeaderCheckbox:SetChecked(LootTrackerConfig.AddTableHeader)

    addTableHeaderCheckbox:SetScript("OnClick", function(self)
        LootTrackerConfig.AddTableHeader = self:GetChecked()
        DebugPrint("'Add Table Header' auf " .. tostring(LootTrackerConfig.AddTableHeader) .. " gesetzt.")
    end)

    local checkRaidLeaderFrame = CreateFrame("Frame", nil, parentFrame)
    checkRaidLeaderFrame:SetPoint("TOPLEFT", addTableHeaderCheckbox, "BOTTOMLEFT", 0, -10)
    checkRaidLeaderFrame:SetSize(300, 30)

    local checkRaidLeaderCheckbox = CreateFrame("CheckButton", nil, checkRaidLeaderFrame, "UICheckButtonTemplate")
    checkRaidLeaderCheckbox:SetPoint("LEFT", checkRaidLeaderFrame, "LEFT", 0, 0)

    local checkRaidLeaderLabel = checkRaidLeaderCheckbox:CreateFontString(nil, "OVERLAY")
    checkRaidLeaderLabel:SetFontObject("GameFontNormal")
    checkRaidLeaderLabel:SetPoint("LEFT", checkRaidLeaderCheckbox, "RIGHT", 5, 0)
    checkRaidLeaderLabel:SetText("Raidleiter-Gilde prüfen")
    checkRaidLeaderLabel:SetTextColor(1, 1, 1, 1)

    checkRaidLeaderCheckbox:SetChecked(LootTrackerConfig.checkRaidLeader)

    -- Frame für die Gildennamen-Textbox
    local guildNameFrame = CreateFrame("Frame", nil, parentFrame)
    guildNameFrame:SetPoint("TOPLEFT", checkRaidLeaderCheckbox, "BOTTOMLEFT", 0, -10)
    guildNameFrame:SetSize(300, 30)

    -- Label für die Textbox
    local guildLabel = guildNameFrame:CreateFontString(nil, "OVERLAY")
    guildLabel:SetFontObject("GameFontNormal")
    guildLabel:SetPoint("TOPLEFT", guildNameFrame, "TOPLEFT", 38, 5)
    guildLabel:SetText("Gildenname des Raidleiters:")
    guildLabel:SetTextColor(1, 1, 1, 1)

    -- Textbox (EditBox) für den Gildennamen
    local guildNameEditBox = CreateFrame("EditBox", nil, guildNameFrame, "InputBoxTemplate")
    guildNameEditBox:SetSize(200, 20)
    guildNameEditBox:SetPoint("LEFT", guildLabel, "RIGHT", 10, 0)
    guildNameEditBox:SetTextInsets(5, 5, 5, 5)
    guildNameEditBox:SetAutoFocus(false)

    -- Setzen Sie den Text aus den gespeicherten Einstellungen
    guildNameEditBox:SetText(LootTrackerConfig.guildName)

    guildNameEditBox:SetScript("OnEnterPressed", function(self)
        LootTrackerConfig.guildName = self:GetText()
        self:SetTextColor(1, 1, 1)
        self:ClearFocus()
        self:HighlightText(0,0)
        self:ClearHighlightText()
    end)

    -- Wenn das Feld den Fokus verliert (z.B. durch Klick), auch speichern
    guildNameEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(LootTrackerConfig.guildName)
        self:ClearFocus()
        self:HighlightText(0,0)
        self:ClearHighlightText()
    end)

    guildNameEditBox:SetScript("OnEditFocusLost", function(self)
        self:SetText(LootTrackerConfig.guildName)
        self:ClearFocus()
        self:HighlightText(0,0)
        self:ClearHighlightText()
    end)

    guildNameEditBox:SetScript("OnTextChanged", function(self)
        local enteredText = self:GetText()
        if enteredText ~= LootTrackerConfig.guildName then
            self:SetTextColor(1, 0, 0)
        else
            if LootTrackerConfig.checkRaidLeader then
                self:SetTextColor(1, 1, 1)
            else
                self:SetTextColor(0.5, 0.5, 0.5)
            end
        end
    end)

    if not LootTrackerConfig.checkRaidLeader then
        guildNameEditBox:Disable()
        guildNameEditBox:SetTextColor(0.5, 0.5, 0.5)
    end
    
    checkRaidLeaderCheckbox:SetScript("OnClick", function(self)
        LootTrackerConfig.checkRaidLeader = self:GetChecked()
        if LootTrackerConfig.checkRaidLeader then
            guildNameEditBox:Enable()
            guildNameEditBox:SetTextColor(1, 1, 1)
        else
            guildNameEditBox:Disable()
            guildNameEditBox:SetTextColor(0.5, 0.5, 0.5)
        end
    end)

    local raidDifficultyConfig = CreateFrame("Frame", nil, parentFrame)
    raidDifficultyConfig:SetPoint("TOPLEFT", guildNameFrame, "BOTTOMLEFT", 0, -20)
    raidDifficultyConfig:SetSize(420, 130)
    raidDifficultyConfig:SetFrameLevel(parentFrame:GetFrameLevel() + 1)

    local raidDifficultyLabel = raidDifficultyConfig:CreateFontString(nil, "OVERLAY")
    raidDifficultyLabel:SetFontObject("GameFontNormalLarge")
    raidDifficultyLabel:SetPoint("TOPLEFT", raidDifficultyConfig, "TOPLEFT", 0, 5)
    raidDifficultyLabel:SetText("Beute erfassen in:")
    raidDifficultyLabel:SetTextColor(1, 1, 1, 1)
    raidDifficultyLabel:SetDrawLayer("OVERLAY")

    local raidDifficultiesCheckboxes = {
        { key = "LFR", text = "LFR" },
        { key = "NHC", text = "Normal Raid" },
        { key = "HC", text = "HC Raid" },
        { key = "MYTHIC", text = "Mythic Raid" },
        { key = "MYTHIC_FLEX", text = "Mythic Flex Raid" },
    }

    local col1X = 15
    local col2X = 215
    local startYCheckbox = 20
    local rowYStep = 30

    for i = 1, #raidDifficultiesCheckboxes do
        local data = raidDifficultiesCheckboxes[i]
        local cb = CreateFrame("CheckButton", nil, raidDifficultyConfig, "UICheckButtonTemplate")

        local x_pos, y_pos
        if (i - 1) % 2 == 0 then
            x_pos = col1X
        else
            x_pos = col2X
        end
        
        y_pos = - (startYCheckbox + floor((i-1)/2) * rowYStep)

        cb:SetPoint("TOPLEFT", raidDifficultyConfig, "TOPLEFT", x_pos, y_pos)
        cb:SetFrameLevel(raidDifficultyConfig:GetFrameLevel() + 2)

        cb.text = cb:CreateFontString(nil, "OVERLAY")
        cb.text:SetFontObject("GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        cb.text:SetText(data.text)
        cb.text:SetTextColor(1, 1, 1, 1)
        cb.text:SetDrawLayer("OVERLAY")

        cb:SetChecked(LootTrackerConfig.trackedRaidDifficulties[data.key])

        cb:SetScript("OnClick", function(self)
            LootTrackerConfig.trackedRaidDifficulties[data.key] = self:GetChecked()
            DebugPrint("Verfolgung für '" .. data.text .. "' auf " .. tostring(LootTrackerConfig.trackedRaidDifficulties[data.key]) .. " gesetzt.")
        end)

        local clearDatabaseButton = CreateFrame("Button", nil, raidDifficultyConfig, "GameMenuButtonTemplate")
        clearDatabaseButton:SetPoint("TOPLEFT", raidDifficultyConfig, "BOTTOMLEFT", 0, 0)
        clearDatabaseButton:SetSize(180, 30)
        clearDatabaseButton:SetText("Datenbank leeren")
        clearDatabaseButton:SetScript("OnClick", function()
            DebugPrint("Datenbank leeren button clicked.")
            -- Rufe die neue globale ShowConfirmDialog-Funktion auf
            RWLootTrackerGlobal.ShowConfirmDialog(
                "Datenbank leeren",
                "Wollen Sie Ihre Datenbank wirklich leeren? Alle Daten werden unwiderruflich gelöscht.",
                function()
                    DebugPrint("Datenbank wird geleert. (Bestätigt)")
                    LootTrackerDB = {} -- Leere die Datenbank
                    RWLootTrackerGlobal.InitializeCalendar() -- Kalender aktualisieren, um die leeren Daten anzuzeigen
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RWLootTracker]|r Die Beutedatenbank wurde erfolgreich geleert.")
                end,
                function()
                    DebugPrint("Datenbank leeren abgebrochen. (Abgelehnt)")
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RWLootTracker]|r Das Leeren der Beutedatenbank wurde abgebrochen.")
                end
            )
        end)
        
    end
end


RWLootTrackerGlobal.settingsPanel = CreateFrame("Frame", nil, UIParent)
RWLootTrackerGlobal.settingsPanel.name = "RW Loot Tracker"

local category = Settings.RegisterCanvasLayoutCategory(RWLootTrackerGlobal.settingsPanel, RWLootTrackerGlobal.settingsPanel.name)
Settings.RegisterAddOnCategory(category)

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


DebugPrint("Core-Modul RWLootTracker.lua geladen. " .. RWLootTrackerGlobal.GetVersion())
