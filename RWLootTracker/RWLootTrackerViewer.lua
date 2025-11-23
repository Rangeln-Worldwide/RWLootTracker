
LootTrackerDetailsFrameName = "LootTrackerDetailsFrame"
LootTrackerFrameName = "LootTrackerFrame"

local function DebugPrint(msg)
    if LootTrackerConfig.DebugMode then
        print("RWLootTracker: " .. msg)
    end
end


local function UpdateLootDetailsText(editBox, selectedDate)
    DebugPrint("UpdateLootDetailsText: selectedDate erhalten: " .. tostring(selectedDate))
    if not editBox then DebugPrint("UpdateLootDetailsText: FEHLER: editBox ist NIL!") return end
    if not editBox:IsVisible() then DebugPrint("UpdateLootDetailsText: Warnung: editBox ist nicht sichtbar!") end
    if not editBox:GetParent():IsVisible() then DebugPrint("UpdateLootDetailsText: Warnung: Parent scrollBox ist nicht sichtbar!") end

    local scrollBox = editBox:GetParent()
    if scrollBox then

        editBox:SetPoint("TOPLEFT", scrollBox, "TOPLEFT")
        editBox:SetPoint("BOTTOMRIGHT", scrollBox, "BOTTOMRIGHT")
        editBox:SetWidth(scrollBox:GetWidth())
        editBox:SetHeight(scrollBox:GetHeight())
        DebugPrint(string.format("UpdateLootDetailsText: editBox Größe nach Anpassung: %.2fx%.2f", editBox:GetWidth(), editBox:GetHeight()))
    else
        DebugPrint("UpdateLootDetailsText: scrollBox ist NIL. Kann editBox nicht anpassen.")
    end
    DebugPrint(string.format("UpdateLootDetailsText: scrollBox Größe: %.2fx%.2f", scrollBox:GetWidth(), scrollBox:GetHeight()))


    local lines = {}
    local entriesToDisplay = LootTrackerDB[selectedDate] or {}

    DebugPrint("UpdateLootDetailsText: Anzahl der Einträge für " .. selectedDate .. ": " .. #entriesToDisplay)
    if #entriesToDisplay == 0 then
        DebugPrint("UpdateLootDetailsText: Keine Daten gefunden für " .. selectedDate .. ". LootTrackerDB[" .. selectedDate .. "] ist leer oder nil.")
    elseif LootTrackerConfig.AddTableHeader then
        table.insert(lines, "Zeit\tBoss\tSpieler\tGUID\tKlasse\tSpezialisierung\tGegenstand\tItemname\tItemID\tRollart\tRollwert\tRüstungstyp\tSlot")
    end

    for _, entry in ipairs(entriesToDisplay) do
        table.insert(lines, string.format('%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s',
            entry.time or "",
            entry.boss or "",
            entry.player or "",
            entry.playerGUID or "",
            entry.playerClass or "",
            entry.playerSpecialization or "",
            entry.item or "",
            entry.itemName or "",
            entry.itemID or "",
            entry.method or "",
            entry.rollValue or "",
            entry.armorType or "",
            entry.slot or ""
        ))
    end
    editBox:SetText(table.concat(lines, "\n"))
end


local function ShowLootDetailsFrame(selectedDate)
    DebugPrint("ShowLootDetailsFrame aufgerufen für Datum: " .. tostring(selectedDate))
    if not RWLootTrackerGlobal.lootDetailsFrame then
        local f = CreateFrame("Frame", LootTrackerDetailsFrameName, UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(600, 400)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("TOOLTIP") 
        f:SetFrameLevel(100) 
        f:SetClampedToScreen(true) 

        f.title = f:CreateFontString(nil, "OVERLAY")
        f.title:SetFontObject("GameFontHighlight")
        f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
        f.title:SetText("Beute für den " .. selectedDate)
        f.title:SetTextColor(1, 1, 1, 1)

        local scrollBox = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollBox:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -30)
        scrollBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -35, 15)
        scrollBox:SetFrameLevel(f:GetFrameLevel() + 1)
        
        local editBox = CreateFrame("EditBox", nil, scrollBox)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)

        editBox:SetPoint("TOPLEFT", scrollBox, "TOPLEFT")
        editBox:SetPoint("BOTTOMRIGHT", scrollBox, "BOTTOMRIGHT")
        editBox:SetMaxBytes(1000000)
        editBox:SetJustifyH("LEFT")
        editBox:SetJustifyV("TOP")
        scrollBox:SetScrollChild(editBox)
        f.editBox = editBox

        editBox:SetWidth(scrollBox:GetWidth())
        editBox:SetHeight(scrollBox:GetHeight())
        DebugPrint(string.format("ShowLootDetailsFrame: editBox Größe nach Initialisierung: %.2fx%.2f", editBox:GetWidth(), editBox:GetHeight()))

        editBox:SetTextColor(1, 1, 1, 1)
        editBox:SetScript("OnEscapePressed", function(self)
            self:GetParent():GetParent():Hide()
        end)

        RWLootTrackerGlobal.lootDetailsFrame = f
    end

    RWLootTrackerGlobal.lootDetailsFrame.title:SetText("Beute für den " .. selectedDate)
    UpdateLootDetailsText(RWLootTrackerGlobal.lootDetailsFrame.editBox, selectedDate)
    RWLootTrackerGlobal.lootDetailsFrame:Show()
end


function RWLootTrackerGlobal.InitializeCalendar()
    if not RWLootTrackerGlobal.calendarFrame then
        DebugPrint("RWLootTrackerGlobal.InitializeCalendar: calendarFrame ist NIL. Kann Kalender nicht initialisieren.")
        return
    end

    local year = RWLootTrackerGlobal.currentCalendarDate.year
    local month = RWLootTrackerGlobal.currentCalendarDate.month

    RWLootTrackerGlobal.calendarFrame.monthYearText:SetText(date("%B %Y", time{year=year, month=month, day=1, hour=0, min=0, sec=0}))

    local function GetFirstWeekdayOfMonth(year, month)
        local t = time{year=year, month=month, day=1, hour=0, min=0, sec=0}
        local weekday = tonumber(date("%w", t))
        return (weekday == 0) and 7 or weekday
    end

    local firstWeekday = GetFirstWeekdayOfMonth(year, month)
    local daysInMonth = tonumber(date("%d", time{year=year, month=month, day=28, hour=0, min=0, sec=0} + 4 * 86400)) -- Trick für Tage im Monat. Konvertiere zu Zahl.

    local dayIndex = 1
    for i = 1, 42 do -- 6 Reihen * 7 Tage
        local dayButton = RWLootTrackerGlobal.calendarFrame.dayButtons[i]
        -- Debug-Ausgabe: Prüfen, ob dayButton existiert
        if not dayButton then
            DebugPrint("RWLootTrackerGlobal.InitializeCalendar: dayButton[" .. i .. "] ist NIL.")
            break -- Schleife abbrechen, um weitere Fehler zu vermeiden
        end

        -- Berechne das tatsächliche Datum für diesen Button-Slot
        local dateOffset = i - firstWeekday
        local timestampForDay = time{year=year, month=month, day=1, hour=0, min=0, sec=0} + dateOffset * 86400
        local displayDay = tonumber(date("%d", timestampForDay)) -- Sicherstellen, dass es eine Zahl ist
        local displayMonth = tonumber(date("%m", timestampForDay)) -- Sicherstellen, dass es eine Zahl ist
        local displayYear = tonumber(date("%Y", timestampForDay)) -- Sicherstellen, dass es eine Zahl ist
        local fullDisplayDate = string.format("%04d-%02d-%02d", displayYear, displayMonth, displayDay) -- Format mit führenden Nullen

        dayButton.dateString = fullDisplayDate -- Speichere das vollständige Datum als String

        -- Prüfe, ob der Tag zum aktuellen Monat gehört
        local isCurrentMonthDay = (displayMonth == month and displayYear == year)

        -- Setze die Tag-Nummer, wenn es ein gültiger Tag im Kalender ist
        dayButton.text:SetText(displayDay)

        -- Prüfe, ob Daten für diesen Tag vorhanden sind (egal ob im aktuellen Monat oder nicht)
        local hasData = LootTrackerDB[fullDisplayDate] and #LootTrackerDB[fullDisplayDate] > 0
        DebugPrint(string.format("Button %d (%s): isCurrentMonthDay=%s, hasData=%s", i, fullDisplayDate, tostring(isCurrentMonthDay), tostring(hasData)))

        if isCurrentMonthDay then
            dayButton:Enable() -- Tage im aktuellen Monat sind klickbar
            if hasData then
                -- Highlighted (wie Screenshot 2)
                dayButton.bg:SetColorTexture(0.5, 0.1, 0.1, 0.9) -- Rötlicher Hintergrund
                dayButton.border:SetColorTexture(0.8, 0.2, 0.2, 1) -- Roter Rahmen
                dayButton.text:SetTextColor(1, 1, 0, 1) -- Gelber Text
            else
                -- Ausgegraut (wie Screenshot 1)
                dayButton.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5) -- Dunklerer, transparenterer Hintergrund
                dayButton.border:SetColorTexture(0.4, 0.4, 0.4, 0.8) -- Grauer Rahmen
                dayButton.text:SetTextColor(0.8, 0.8, 0.8, 1) -- Grauer Text
            end
        else
            -- Tage außerhalb des aktuellen Monats (Vormonat / Folgemonat)
            dayButton.text:SetText(displayDay) -- Zeige die Tageszahl auch für andere Monate
            dayButton.bg:SetColorTexture(0.1, 0.1, 0.1, 0.3) -- Sehr dunkler, transparenter Hintergrund
            dayButton.border:SetColorTexture(0.3, 0.3, 0.3, 0.5) -- Dunkelgrauer Rahmen
            dayButton.text:SetTextColor(0.5, 0.5, 0.5, 0.6) -- Noch grauer und transparenter für Text
            dayButton:Disable() -- Tage außerhalb des Monats sind nicht klickbar
        end
    end
end

-- Hauptfunktion zum Erstellen der GUI
function RWLootTrackerGlobal.CreateGUI()
    if RWLootTrackerGlobal.lootTrackerFrame then
        RWLootTrackerGlobal.lootTrackerFrame:Show()
        RWLootTrackerGlobal.InitializeCalendar() -- Kalender immer aktualisieren, wenn das GUI gezeigt wird.
        return
    end

    local f = CreateFrame("Frame", LootTrackerFrameName, UIParent, "BasicFrameTemplateWithInset")
    DebugPrint("RWLootTrackerGlobal.CreateGUI: lootTrackerFrame (f) nach CreateFrame: " .. tostring(f))
    if not f then
        DebugPrint("FEHLER: lootTrackerFrame (f) ist NIL nach CreateFrame!")
        return -- Beende die Funktion, wenn Frame-Erstellung fehlschlägt
    end

    f:SetSize(700, 600) -- Hauptfenster-Höhe und -Breite angepasst
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(2)
    f:SetClampedToScreen(true)
    f.CloseButton:SetScript("OnClick", function(self)
    f:Hide()
    end)

    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFontObject("GameFontHighlight")
    f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 15, 0)
    f.title:SetText("Rangeln Worldwide Loot Tracker " .. RWLootTrackerGlobal.GetVersion())
    f.title:SetTextColor(1, 1, 1, 1)

    -- Panels für die Tab-Inhalte
    RWLootTrackerGlobal.lootDatabasePanel = CreateFrame("Frame", nil, f)
    DebugPrint("RWLootTrackerGlobal.CreateGUI: lootDatabasePanel nach CreateFrame: " .. tostring(RWLootTrackerGlobal.lootDatabasePanel))
    if not RWLootTrackerGlobal.lootDatabasePanel then
        DebugPrint("FEHLER: lootDatabasePanel ist NIL nach CreateFrame!")
        return -- Beende die Funktion, wenn Frame-Erstellung fehlschlägt
    end
    RWLootTrackerGlobal.lootDatabasePanel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -30) -- Unter den Tabs
    RWLootTrackerGlobal.lootDatabasePanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 15) -- Bis zum unteren Rand
    RWLootTrackerGlobal.lootDatabasePanel:SetFrameLevel(f:GetFrameLevel() + 1)
    -- Hintergrund für lootDatabasePanel
    local lootDatabasePanelBg = RWLootTrackerGlobal.lootDatabasePanel:CreateTexture(nil, "BACKGROUND")
    lootDatabasePanelBg:SetAllPoints(true)
    lootDatabasePanelBg:SetColorTexture(0.1, 0.1, 0.15, 0.7) -- Dezentes Dunkelblau-Grau
    lootDatabasePanelBg:SetDrawLayer("BACKGROUND")

    RWLootTrackerGlobal.lootDatabasePanel:Show() -- Sicherstellen, dass das Panel sichtbar ist


    -- === Elemente für "Beute Datenbank" Tab (RWLootTrackerGlobal.lootDatabasePanel) - Jetzt mit Kalender ===
    -- WICHTIG: Erstelle calendarFrame nur, wenn lootDatabasePanel existiert
    if RWLootTrackerGlobal.lootDatabasePanel then
        -- Erstelle ein einfaches Frame
        RWLootTrackerGlobal.calendarFrame = CreateFrame("Frame", "LootTrackerCalendarFrame", RWLootTrackerGlobal.lootDatabasePanel)
        DebugPrint("calendarFrame nach CreateFrame (mit Parent, OHNE Template): " .. tostring(RWLootTrackerGlobal.calendarFrame))
        
        if not RWLootTrackerGlobal.calendarFrame then
            DebugPrint("FEHLER: calendarFrame ist NIL nach CreateFrame in RWLootTrackerGlobal.CreateGUI, obwohl lootDatabasePanel existiert!")
            return -- Beende die Funktion, wenn Frame-Erstellung fehlschlägt
        end

        -- Kalender-Hintergrund soll vertikal das lootDatabasePanel ausfüllen und feste Breite haben.
        -- Berücksichtigt den 'inset' des manuellen Rahmens, um visuelle Überlappungen zu vermeiden.
        local calendarFrameInset = 4

        RWLootTrackerGlobal.calendarFrame:SetPoint("TOPLEFT", RWLootTrackerGlobal.lootDatabasePanel, "TOPLEFT", 0, -calendarFrameInset) -- Y-Offset nach oben für den oberen Rand
        RWLootTrackerGlobal.calendarFrame:SetPoint("BOTTOMLEFT", RWLootTrackerGlobal.lootDatabasePanel, "BOTTOMLEFT", 0, calendarFrameInset) -- Y-Offset nach unten für den unteren Rand
        RWLootTrackerGlobal.calendarFrame:SetWidth(450) -- Feste Breite für den Kalender
        
        -- SetFrameLevel auf Basis des Parent, aber sicherstellen, dass es über dem Panel-Hintergrund ist.
        RWLootTrackerGlobal.calendarFrame:SetFrameLevel(RWLootTrackerGlobal.lootDatabasePanel:GetFrameLevel() + 2)
        
        -- MANUELLES BACKDROP IM STIL VON LEATRIX
        local bg = RWLootTrackerGlobal.calendarFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.7) -- Dunkler Hintergrund
        bg:SetDrawLayer("BACKGROUND", 0)

        local borderTex = "Interface/Tooltips/UI-Tooltip-Border"
        local borderSize = 16
        local inset = 4

        -- Rahmentexturen mit ARTWORK-Ebene
        local topBorder = RWLootTrackerGlobal.calendarFrame:CreateTexture(nil, "ARTWORK")
        topBorder:SetTexture(borderTex)
        topBorder:SetPoint("TOPLEFT", RWLootTrackerGlobal.calendarFrame, "TOPLEFT", -inset, inset)
        topBorder:SetPoint("TOPRIGHT", RWLootTrackerGlobal.calendarFrame, "TOPRIGHT", inset, inset)
        topBorder:SetHeight(borderSize)
        topBorder:SetTexCoord(0.125, 0.875, 0.125, 0.875)
        topBorder:SetDrawLayer("ARTWORK", 0)

        local bottomBorder = RWLootTrackerGlobal.calendarFrame:CreateTexture(nil, "ARTWORK")
        bottomBorder:SetTexture(borderTex)
        bottomBorder:SetPoint("BOTTOMLEFT", RWLootTrackerGlobal.calendarFrame, "BOTTOMLEFT", -inset, -inset)
        bottomBorder:SetPoint("BOTTOMRIGHT", RWLootTrackerGlobal.calendarFrame, "BOTTOMRIGHT", inset, -inset)
        bottomBorder:SetHeight(borderSize)
        bottomBorder:SetTexCoord(0.125, 0.875, 0.125, 0.875)
        bottomBorder:SetDrawLayer("ARTWORK", 0)

        local leftBorder = RWLootTrackerGlobal.calendarFrame:CreateTexture(nil, "ARTWORK")
        leftBorder:SetTexture(borderTex)
        leftBorder:SetPoint("TOPLEFT", RWLootTrackerGlobal.calendarFrame, "TOPLEFT", -inset, inset)
        leftBorder:SetPoint("BOTTOMLEFT", RWLootTrackerGlobal.calendarFrame, "BOTTOMLEFT", -inset, -inset)
        leftBorder:SetWidth(borderSize)
        leftBorder:SetTexCoord(0.125, 0.875, 0.125, 0.875)
        leftBorder:SetDrawLayer("ARTWORK", 0)

        local rightBorder = RWLootTrackerGlobal.calendarFrame:CreateTexture(nil, "ARTWORK")
        rightBorder:SetTexture(borderTex)
        rightBorder:SetPoint("TOPRIGHT", RWLootTrackerGlobal.calendarFrame, "TOPRIGHT", inset, inset)
        rightBorder:SetPoint("BOTTOMRIGHT", RWLootTrackerGlobal.calendarFrame, "BOTTOMRIGHT", inset, -inset)
        rightBorder:SetWidth(borderSize)
        rightBorder:SetTexCoord(0.125, 0.875, 0.125, 0.875)
        rightBorder:SetDrawLayer("ARTWORK", 0)
        
        DebugPrint("Manuelles Backdrop für calendarFrame erstellt.")


        -- Kalender-Header (Monat und Jahr)
        RWLootTrackerGlobal.calendarFrame.monthYearText = RWLootTrackerGlobal.calendarFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        RWLootTrackerGlobal.calendarFrame.monthYearText:SetPoint("TOP", RWLootTrackerGlobal.calendarFrame, "TOP", 0, -30) -- Weiter nach unten verschoben für Header-Bereich
        RWLootTrackerGlobal.calendarFrame.monthYearText:SetText("Monat Jahr")
        RWLootTrackerGlobal.calendarFrame.monthYearText:SetTextColor(1, 1, 1, 1)
        RWLootTrackerGlobal.calendarFrame.monthYearText:SetDrawLayer("OVERLAY")


        -- Navigationspfeile
        RWLootTrackerGlobal.calendarFrame.prevMonthButton = CreateFrame("Button", nil, RWLootTrackerGlobal.calendarFrame, "UIPanelButtonTemplate")
        RWLootTrackerGlobal.calendarFrame.prevMonthButton:SetSize(20, 20)
        RWLootTrackerGlobal.calendarFrame.prevMonthButton:SetPoint("RIGHT", RWLootTrackerGlobal.calendarFrame.monthYearText, "LEFT", -10, 0)
        RWLootTrackerGlobal.calendarFrame.prevMonthButton:SetText("<")
        RWLootTrackerGlobal.calendarFrame.prevMonthButton:SetScript("OnClick", function()
            RWLootTrackerGlobal.currentCalendarDate.month = RWLootTrackerGlobal.currentCalendarDate.month - 1
            if RWLootTrackerGlobal.currentCalendarDate.month < 1 then
                RWLootTrackerGlobal.currentCalendarDate.month = 12
                RWLootTrackerGlobal.currentCalendarDate.year = RWLootTrackerGlobal.currentCalendarDate.year - 1
            end
            RWLootTrackerGlobal.InitializeCalendar()
        end)

        RWLootTrackerGlobal.calendarFrame.nextMonthButton = CreateFrame("Button", nil, RWLootTrackerGlobal.calendarFrame, "UIPanelButtonTemplate")
        RWLootTrackerGlobal.calendarFrame.nextMonthButton:SetSize(20, 20)
        RWLootTrackerGlobal.calendarFrame.nextMonthButton:SetPoint("LEFT", RWLootTrackerGlobal.calendarFrame.monthYearText, "RIGHT", 10, 0)
        RWLootTrackerGlobal.calendarFrame.nextMonthButton:SetText(">")
        RWLootTrackerGlobal.calendarFrame.nextMonthButton:SetScript("OnClick", function()
            RWLootTrackerGlobal.currentCalendarDate.month = RWLootTrackerGlobal.currentCalendarDate.month + 1
            if RWLootTrackerGlobal.currentCalendarDate.month > 12 then
                RWLootTrackerGlobal.currentCalendarDate.month = 1
                RWLootTrackerGlobal.currentCalendarDate.year = RWLootTrackerGlobal.currentCalendarDate.year + 1
            end
            RWLootTrackerGlobal.InitializeCalendar()
        end)


        -- Wochentags-Labels
        local dayNames = {"Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"}
        RWLootTrackerGlobal.calendarFrame.dayLabels = {}
        local columnWidth = 60
        local initialXOffset = 15

        for i = 1, 7 do
            local label = RWLootTrackerGlobal.calendarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetWidth(columnWidth)
            label:SetJustifyH("CENTER")
            label:SetPoint("TOPLEFT", RWLootTrackerGlobal.calendarFrame, "TOPLEFT", initialXOffset + (i-1) * columnWidth, -70)
            label:SetText(dayNames[i])
            label:SetTextColor(1, 1, 0, 1)
            label:SetDrawLayer("OVERLAY")
            RWLootTrackerGlobal.calendarFrame.dayLabels[i] = label
        end

        -- Kalender-Tage-Buttons (Grid)
        RWLootTrackerGlobal.calendarFrame.dayButtons = {}
        local buttonSize = 50
        local buttonSpacing = columnWidth
        local startY = -110
        local buttonPaddingInColumn = (columnWidth - buttonSize) / 2

        for row = 0, 5 do -- 6 Reihen
            for col = 0, 6 do -- 7 Spalten
                local button = CreateFrame("Button", nil, RWLootTrackerGlobal.calendarFrame)
                button:SetSize(buttonSize, buttonSize)
                button:SetPoint("TOPLEFT", RWLootTrackerGlobal.calendarFrame, "TOPLEFT", initialXOffset + col * buttonSpacing + buttonPaddingInColumn, startY + row * -buttonSpacing)
                button:SetFrameLevel(RWLootTrackerGlobal.calendarFrame:GetFrameLevel() + 2)
                
                -- Hintergrund für den Button
                button.bg = button:CreateTexture(nil, "BACKGROUND")
                button.bg:SetAllPoints(true)
                button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                button.bg:SetDrawLayer("BACKGROUND", 1)

                -- Rahmen für den Button
                button.border = button:CreateTexture(nil, "ARTWORK")
                button.border:SetTexture("Interface/Common/Common-Border")
                button.border:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
                button.border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
                button.border:SetBlendMode("BLEND")
                button.border:SetColorTexture(0.5, 0.5, 0.5, 1)
                button.border:SetDrawLayer("ARTWORK", 0)

                -- Text (Tag-Nummer)
                button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                button.text:SetPoint("CENTER")
                button.text:SetText("")
                button.text:SetTextColor(1, 1, 1, 1)
                button.text:SetDrawLayer("OVERLAY")

                button:SetScript("OnClick", function(self)
                    if self.dateString then
                        ShowLootDetailsFrame(self.dateString)
                    end
                end)
                table.insert(RWLootTrackerGlobal.calendarFrame.dayButtons, button)
            end
        end
        
        local rangelnLabel = RWLootTrackerGlobal.lootDatabasePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge2")
        rangelnLabel:SetPoint("TOPRIGHT", RWLootTrackerGlobal.lootDatabasePanel, "TOPRIGHT", -10, -20)
        rangelnLabel:SetText("Rangeln Worldwide")
        rangelnLabel:SetTextColor(1, 1, 1, 1)
        rangelnLabel:SetWidth(190)
        
        local lootTrackerLabel = RWLootTrackerGlobal.lootDatabasePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        lootTrackerLabel:SetPoint("TOPRIGHT", RWLootTrackerGlobal.lootDatabasePanel, "TOPRIGHT", -10, -80)
        lootTrackerLabel:SetText("Loot Tracker")
        lootTrackerLabel:SetTextColor(1, 1, 1, 1)
        lootTrackerLabel:SetWidth(190)
        
        local logoTexture = RWLootTrackerGlobal.lootDatabasePanel:CreateTexture(nil, "ARTWORK")
        logoTexture:SetTexture("Interface/AddOns/RWLootTracker/media/rwl_lass_rangeln.png")
        logoTexture:SetSize(200, 200)
        logoTexture:SetPoint("TOPRIGHT", RWLootTrackerGlobal.lootDatabasePanel, "TOPRIGHT", -10, -200)
        
    else
        DebugPrint("lootDatabasePanel ist NIL, Kalender wird nicht erstellt.")
    end

    RWLootTrackerGlobal.lootTrackerFrame = f -- Speichere die Referenz zum Haupt-Frame
    f:Show()
    -- Sicherstellen, dass der Kalender initial gefüllt wird, wenn das GUI zum ersten Mal erstellt wird.
    -- Dies sollte nur aufgerufen werden, wenn calendarFrame tatsächlich erstellt wurde.
    if RWLootTrackerGlobal.calendarFrame then
        RWLootTrackerGlobal.InitializeCalendar()
    end

    -- Initialisiere das Bestätigungs-Popup beim Erstellen der GUI
    RWLootTrackerGlobal.InitializeConfirmDialog()
end

DebugPrint("Viewer-Modul geladen.")