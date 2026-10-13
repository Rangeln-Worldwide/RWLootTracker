-- Replaces the raw text viewer with a readable daily overview and explicit export.
-- Saved loot entries remain compatible; the comment is the first export column.
local addon = RWLootTrackerGlobal
local columns = {
    "Kommentar", "Zeit", "Boss", "Spieler", "GUID", "Klasse", "Spezialisierung",
    "Gegenstand", "Itemname", "ItemID", "Rollart", "Rollwert", "Rüstungstyp", "Slot",
}
local pageSize = 8

-- WoW closes frames in UISpecialFrames on Escape. One invisible frame keeps
-- our calendar, editor and export in one stack so only the front window closes.
local escapeFrame = CreateFrame("Frame", "RWLootTrackerEscapeFrame", UIParent)
escapeFrame:SetSize(1, 1)
escapeFrame:SetPoint("CENTER")
escapeFrame:EnableMouse(false)
escapeFrame:Hide()
UISpecialFrames[#UISpecialFrames + 1] = "RWLootTrackerEscapeFrame"

local function FrontWindow()
    if addon.entryEditor and addon.entryEditor:IsShown() then return addon.entryEditor end
    if addon.exportFrame and addon.exportFrame:IsShown() then return addon.exportFrame end
    if addon.lootTrackerFrame and addon.lootTrackerFrame:IsShown() then
        return addon.lootTrackerFrame
    end
end

local function UpdateEscapeFrame()
    if FrontWindow() then
        escapeFrame:Show()
    elseif escapeFrame:IsShown() then
        escapeFrame.quietHide = true
        escapeFrame:Hide()
        escapeFrame.quietHide = nil
    end
end

escapeFrame:SetScript("OnHide", function(self)
    if self.quietHide then return end
    local front = FrontWindow()
    if front then front:Hide() end
    UpdateEscapeFrame()
end)

local function Label(parent, font, point, relative, relativePoint, x, y, value)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint(point, relative, relativePoint, x, y)
    text:SetText(value)
    return text
end

local function ExportValue(value)
    return tostring(value or ""):gsub("[\t\r\n]", " ")
end

local function ExportDay(key)
    local lines = {}
    if LootTrackerConfig.AddTableHeader then
        lines[#lines + 1] = table.concat(columns, "\t")
    end
    for _, entry in ipairs(LootTrackerDB[key] or {}) do
        local data = {
            entry.comment, entry.time, entry.boss, entry.player, entry.playerGUID, entry.playerClass,
            entry.playerSpecialization, entry.item, entry.itemName, entry.itemID,
            entry.method, entry.rollValue, entry.armorType, entry.slot,
        }
        for i = 1, #columns do data[i] = ExportValue(data[i]) end
        lines[#lines + 1] = table.concat(data, "\t")
    end
    return table.concat(lines, "\n")
end

local function ShowExport(key)
    local f = addon.exportFrame
    if not f then
        f = CreateFrame("Frame", "RWLootTrackerExport", UIParent, "BasicFrameTemplateWithInset")
        f:Hide()
        f:HookScript("OnShow", UpdateEscapeFrame)
        f:HookScript("OnHide", UpdateEscapeFrame)
        f:SetSize(760, 410)
        f:SetPoint("CENTER")
        -- The main window also uses DIALOG. Keep the export and all its children
        -- on a higher stratum, including after the main window has been raised.
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(100)
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local background = f:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -25)
        background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -7, 7)
        background:SetColorTexture(0.035, 0.035, 0.045, 1)
        f.TitleText:SetText("Export für Google Sheets")
        f.heading = Label(f, "GameFontNormal", "TOPLEFT", f, "TOPLEFT", 16, -34,
            "Text markieren, Strg+C drücken und in Google Sheets einfügen.")
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -58)
        scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -35, 18)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject(ChatFontNormal)
        box:SetWidth(700)
        box:SetHeight(330)
        box:SetScript("OnTextChanged", function(self)
            local _, lineBreaks = self:GetText():gsub("\n", "\n")
            self:SetHeight(math.max(330, (lineBreaks + 1) * 44))
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            f:Hide()
        end)
        scroll:SetScrollChild(box)
        f.box = box
        addon.exportFrame = f
    end
    f.box:SetText(ExportDay(key))
    f:Show()
    f:Raise()
    f.box:SetFocus()
    f.box:HighlightText()
end

local ShowEntryEditor

local function RefreshRows()
    local f = addon.lootTrackerFrame
    if not f then return end
    local entries = LootTrackerDB[f.selectedDate] or {}
    local pages = math.max(1, math.ceil(#entries / pageSize))
    f.page = math.min(math.max(f.page, 1), pages)
    f.dayHeading:SetText(f.selectedDate .. "  ·  " .. #entries .. " Einträge")
    f.pageText:SetText(f.page .. " / " .. pages)
    f.prevPage:SetEnabled(f.page > 1)
    f.nextPage:SetEnabled(f.page < pages)
    f.exportButton:SetEnabled(#entries > 0)
    f.emptyText:SetShown(#entries == 0)
    for i, row in ipairs(f.rows) do
        local entry = entries[(f.page - 1) * pageSize + i]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            row.top:SetText(((entry.time or ""):match("%d%d:%d%d") or "--:--")
                .. "  " .. (entry.player or "Unbekannt"))
            row.item:SetText(entry.itemName or entry.item or "Unbekannter Gegenstand")
            row.bottom:SetText(entry.comment or ((entry.boss or "Unbekannter Boss") .. " · "
                .. (entry.method or "Unbekannt") .. " " .. tostring(entry.rollValue or "")))
            if entry.originalWinner then
                row.bottom:SetTextColor(1, 0.72, 0.28)
            else
                row.bottom:SetTextColor(0.88, 0.88, 0.86)
            end
        end
    end
end

ShowEntryEditor = function(entry, dateKey)
    local f = addon.entryEditor
    if not f then
        f = CreateFrame("Frame", "RWLootTrackerEntryEditor", UIParent, "BasicFrameTemplateWithInset")
        f:Hide()
        f:HookScript("OnShow", UpdateEscapeFrame)
        f:HookScript("OnHide", UpdateEscapeFrame)
        f:SetSize(520, 520)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(200)
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.TitleText:SetText("Beute bearbeiten")
        local background = f:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -25)
        background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -7, 7)
        background:SetColorTexture(0.035, 0.035, 0.045, 1)
        f.itemLabel = Label(f, "GameFontNormalLarge", "TOPLEFT", f, "TOPLEFT", 18, -38, "")
        f.itemLabel:SetWidth(480)
        f.itemLabel:SetMaxLines(1)
        f.sourceLabel = Label(f, "GameFontHighlightSmall", "TOPLEFT", f, "TOPLEFT", 18, -69, "")
        f.sourceLabel:SetWidth(480)
        f.sourceLabel:SetMaxLines(2)
        Label(f, "GameFontNormal", "TOPLEFT", f, "TOPLEFT", 18, -101, "Empfänger suchen:")
        f.searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.searchBox:SetSize(245, 22)
        f.searchBox:SetPoint("TOPLEFT", f, "TOPLEFT", 145, -94)
        f.searchBox:SetAutoFocus(false)
        f.searchBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            f:Hide()
        end)
        f.options = {}
        f.rows = {}
        f.page = 1

        local function RefreshCandidates()
            if not f.entry then return end
            local rosterAvailable
            f.options, rosterAvailable = addon.GetEligibleRecipients(
                f.entry, f.dateKey, f.searchBox:GetText())
            f.sourceLabel:SetText(rosterAvailable and
                "Raidkader beim Drop (gespeichert)" or
                "Altdaten: Tagesgewinner; Suche erweitert auf die Historie")
            local pages = math.max(1, math.ceil(#f.options / 8))
            f.page = math.min(math.max(1, f.page), pages)
            f.pageLabel:SetText(f.page .. " / " .. pages)
            f.prev:SetEnabled(f.page > 1)
            f.next:SetEnabled(f.page < pages)
            f.manual:SetShown(not rosterAvailable)
            f.manual:SetEnabled(not rosterAvailable and f.searchBox:GetText():match("%S") ~= nil)
            for i, button in ipairs(f.rows) do
                local person = f.options[(f.page - 1) * 8 + i]
                button.person = person
                button:SetShown(person ~= nil)
                if person then
                    button:SetText(person[2] ..
                        (f.receiver and f.receiver[1] == person[1] and
                        f.receiver[2] == person[2] and "  (ausgewählt)" or ""))
                end
            end
        end
        f.refreshCandidates = RefreshCandidates
        f.searchBox:SetScript("OnTextChanged", function()
            f.page = 1
            RefreshCandidates()
        end)
        for i = 1, 8 do
            local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            button:SetSize(475, 27)
            button:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -127 - (i - 1) * 29)
            button:SetScript("OnClick", function(self)
                f.receiver = self.person
                f.selection:SetText("Ausgewählt: " .. self.person[2])
                RefreshCandidates()
            end)
            f.rows[i] = button
        end
        f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.prev:SetSize(27, 23)
        f.prev:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -365)
        f.prev:SetText("<")
        f.prev:SetScript("OnClick", function()
            f.page = f.page - 1
            RefreshCandidates()
        end)
        f.pageLabel = Label(f, "GameFontNormal", "LEFT", f.prev, "RIGHT", 10, 0, "")
        f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.next:SetSize(27, 23)
        f.next:SetPoint("LEFT", f.pageLabel, "RIGHT", 10, 0)
        f.next:SetText(">")
        f.next:SetScript("OnClick", function()
            f.page = f.page + 1
            RefreshCandidates()
        end)
        f.manual = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.manual:SetSize(215, 23)
        f.manual:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -365)
        f.manual:SetText("Suchnamen manuell übernehmen")
        f.manual:SetScript("OnClick", function()
            local name = f.searchBox:GetText():match("^%s*(.-)%s*$")
            if name == "" then return end
            f.receiver = {nil, name, "Unbekannt"}
            f.selection:SetText("Ausgewählt: " .. name .. " (GUID unbekannt)")
        end)
        f.selection = Label(f, "GameFontHighlight", "TOPLEFT", f, "TOPLEFT",
            18, -398, "Empfänger: unverändert")
        Label(f, "GameFontNormal", "TOPLEFT", f, "TOPLEFT", 18, -430, "Kommentar:")
        f.noteBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.noteBox:SetSize(385, 22)
        f.noteBox:SetPoint("TOPLEFT", f, "TOPLEFT", 105, -423)
        f.noteBox:SetAutoFocus(false)
        f.noteBox:SetMaxLetters(250)
        f.noteBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        f.noteBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            f:Hide()
        end)
        f.save = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
        f.save:SetSize(125, 28)
        f.save:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 18)
        f.save:SetText("Speichern")
        f.save:SetScript("OnClick", function()
            local record = f.entry
            local receiver = f.receiver
            if receiver and (receiver[1] ~= record.playerGUID or receiver[2] ~= record.player) then
                if addon.IsOriginalRecipient(record, receiver[1], receiver[2]) then
                    addon.RestoreOriginalWinner(record)
                else
                    record.originalWinner = record.originalWinner or {
                        record.player, record.playerGUID, record.playerClass, record.playerSpecialization,
                    }
                    record.player = receiver[2]
                    record.playerGUID = receiver[1] or ""
                    record.playerClass = receiver[3] or "Unbekannt"
                    record.playerSpecialization = "Unbekannt"
                end
            end
            local note = f.noteBox:GetText():match("^%s*(.-)%s*$")
            record.note = note ~= "" and note or nil
            local prefix = record.originalWinner and
                ("Weitergegeben von " .. record.originalWinner[1]) or nil
            record.comment = prefix and (prefix .. (record.note and " | " .. record.note or ""))
                or record.note
            f:Hide()
            RefreshRows()
        end)
        addon.entryEditor = f
    end
    if addon.exportFrame then addon.exportFrame:Hide() end
    f.entry = entry
    f.dateKey = dateKey
    f.receiver = nil
    f.page = 1
    f.itemLabel:SetText(entry.itemName or entry.item or "Unbekannter Gegenstand")
    f.selection:SetText("Empfänger: " .. (entry.player or "Unbekannt") .. " (unverändert)")
    f.searchBox:SetText("")
    f.noteBox:SetText(entry.note or (not entry.originalWinner and entry.comment) or "")
    f.refreshCandidates()
    f:Show()
    f:Raise()
end

function addon.InitializeCalendar()
    local calendar = addon.calendarFrame
    if not calendar then return end
    local current = addon.currentCalendarDate
    local first = time({year = current.year, month = current.month, day = 1, hour = 12})
    calendar.heading:SetText(date("%B %Y", first))
    local mondayOffset = (tonumber(date("%w", first)) + 6) % 7
    for i, button in ipairs(calendar.days) do
        local stamp = first + (i - 1 - mondayOffset) * 86400
        local key = date("%Y-%m-%d", stamp)
        local inMonth = tonumber(date("%m", stamp)) == current.month
            and tonumber(date("%Y", stamp)) == current.year
        local hasLoot = LootTrackerDB[key] and #LootTrackerDB[key] > 0
        button.key = key
        button.text:SetText(date("%d", stamp))
        button:SetEnabled(inMonth)
        if not inMonth then
            button.bg:SetColorTexture(0.08, 0.075, 0.07, 0.6)
            button.text:SetTextColor(0.46, 0.43, 0.39)
        elseif addon.lootTrackerFrame.selectedDate == key then
            button.bg:SetColorTexture(0.43, 0.31, 0.12, 0.95)
            button.text:SetTextColor(1, 1, 1)
        elseif hasLoot then
            button.bg:SetColorTexture(0.29, 0.15, 0.09, 0.92)
            button.text:SetTextColor(1, 0.85, 0.5)
        else
            button.bg:SetColorTexture(0.17, 0.16, 0.15, 0.86)
            button.text:SetTextColor(0.86, 0.85, 0.82)
        end
    end
    RefreshRows()
end

local function MoveMonth(amount)
    local current = addon.currentCalendarDate
    local stamp = time({year = current.year, month = current.month + amount, day = 1, hour = 12})
    current.year = tonumber(date("%Y", stamp))
    current.month = tonumber(date("%m", stamp))
    addon.InitializeCalendar()
end

function addon.CreateGUI()
    if addon.lootTrackerFrame then
        addon.lootTrackerFrame:Show()
        addon.InitializeCalendar()
        return
    end
    local f = CreateFrame("Frame", "RWLootTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
    f:Hide()
    f:HookScript("OnShow", UpdateEscapeFrame)
    f:HookScript("OnHide", function()
        if addon.entryEditor then addon.entryEditor:Hide() end
        if addon.exportFrame then addon.exportFrame:Hide() end
        UpdateEscapeFrame()
    end)
    f:SetSize(800, 555)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.TitleText:SetText("Rangeln Worldwide Loot Tracker " .. addon.GetVersion())
    local current = addon.currentCalendarDate
    f.selectedDate = date("%Y-%m-%d", time({
        year = current.year, month = current.month, day = current.day, hour = 12,
    }))
    f.page = 1
    f.rows = {}
    addon.lootTrackerFrame = f

    local cal = CreateFrame("Frame", nil, f)
    cal:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -42)
    cal:SetSize(405, 450)
    addon.calendarFrame = cal
    local bg = cal:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.045, 0.04, 0.035, 0.88)
    cal.heading = Label(cal, "GameFontNormalLarge", "TOP", cal, "TOP", 0, -18, "")
    for _, direction in ipairs({-1, 1}) do
        local arrow = CreateFrame("Button", nil, cal, "UIPanelButtonTemplate")
        arrow:SetSize(30, 24)
        arrow:SetPoint(direction == -1 and "TOPLEFT" or "TOPRIGHT",
            cal, direction == -1 and "TOPLEFT" or "TOPRIGHT",
            direction == -1 and 15 or -15, -15)
        arrow:SetText(direction == -1 and "<" or ">")
        arrow:SetScript("OnClick", function() MoveMonth(direction) end)
    end
    local weekday = {"Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"}
    cal.days = {}
    for col = 0, 6 do
        Label(cal, "GameFontNormalSmall", "TOPLEFT", cal, "TOPLEFT",
            22 + col * 55, -63, weekday[col + 1])
    end
    for i = 1, 42 do
        local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
        local button = CreateFrame("Button", nil, cal)
        button:SetSize(48, 46)
        button:SetPoint("TOPLEFT", cal, "TOPLEFT", 12 + col * 55, -88 - row * 57)
        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints()
        button.text = Label(button, "GameFontNormal", "CENTER", button, "CENTER", 0, 0, "")
        button:SetScript("OnClick", function(self)
            f.selectedDate = self.key
            f.page = 1
            addon.InitializeCalendar()
        end)
        cal.days[i] = button
    end

    local panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", cal, "TOPRIGHT", 12, 0)
    panel:SetSize(345, 450)
    local shade = panel:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0.055, 0.05, 0.045, 0.92)
    f.dayHeading = Label(panel, "GameFontNormalLarge", "TOPLEFT", panel, "TOPLEFT", 12, -14, "")
    f.emptyText = Label(panel, "GameFontHighlight", "CENTER", panel, "CENTER", 0, 0,
        "Keine Beute an diesem Tag")
    for i = 1, pageSize do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(325, 48)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -46 - (i - 1) * 49)
        local color = row:CreateTexture(nil, "BACKGROUND")
        color:SetAllPoints()
        color:SetColorTexture(0.18, 0.16, 0.14, i % 2 == 0 and 0.56 or 0.78)
        row.top = Label(row, "GameFontNormalSmall", "TOPLEFT", row, "TOPLEFT", 5, -3, "")
        row.item = Label(row, "GameFontHighlight", "TOPLEFT", row, "TOPLEFT", 5, -17, "")
        row.item:SetWidth(310)
        row.item:SetJustifyH("LEFT")
        row.item:SetMaxLines(1)
        row.bottom = Label(row, "GameFontHighlightSmall", "TOPLEFT", row, "TOPLEFT", 5, -34, "")
        row.bottom:SetWidth(310)
        row.bottom:SetJustifyH("LEFT")
        row.bottom:SetMaxLines(1)
        row:SetScript("OnEnter", function(self)
            if self.entry and self.entry.item then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.entry.item)
                if self.entry.comment then
                    GameTooltip:AddLine(self.entry.comment, 1, 0.82, 0.35, true)
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            if self.entry then ShowEntryEditor(self.entry, f.selectedDate) end
        end)
        f.rows[i] = row
    end
    f.prevPage = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.prevPage:SetSize(28, 24)
    f.prevPage:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, -30)
    f.prevPage:SetText("<")
    f.prevPage:SetScript("OnClick", function() f.page = f.page - 1; RefreshRows() end)
    f.pageText = Label(f, "GameFontNormal", "LEFT", f.prevPage, "RIGHT", 10, 0, "")
    f.nextPage = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.nextPage:SetSize(28, 24)
    f.nextPage:SetPoint("LEFT", f.pageText, "RIGHT", 10, 0)
    f.nextPage:SetText(">")
    f.nextPage:SetScript("OnClick", function() f.page = f.page + 1; RefreshRows() end)
    f.exportButton = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
    f.exportButton:SetSize(170, 27)
    f.exportButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 17)
    f.exportButton:SetText("Für Sheets exportieren")
    f.exportButton:SetScript("OnClick", function() ShowExport(f.selectedDate) end)
    Label(f, "GameFontHighlightSmall", "BOTTOMLEFT", f, "BOTTOMLEFT", 18, 21,
        "Eintrag anklicken: Kommentar / Weitergabe")
    addon.InitializeCalendar()
    f:Show()
end
