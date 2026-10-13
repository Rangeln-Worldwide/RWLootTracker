-- Dies ist die Listener-Datei, die sich um die Beute-Events kümmert.

local function DebugPrint(msg)
    if LootTrackerConfig and LootTrackerConfig.DebugMode then
        print("RWLootTracker: " .. msg)
    end
end

local function GetRaidLeaderGuild()
    DebugPrint("Checking Raid Group")
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        local unit = "raid" .. i
        if name and UnitIsGroupLeader(unit) then
            DebugPrint(string.format("Found group leader: %s", name))
            local guildName = GetGuildInfo(unit)
            
            if guildName then
                DebugPrint(string.format("Found Guild name: %s", guildName))
                return guildName
            end
        end
    end
    return nil
end

local function IsRaidLeaderInGuild()
    local guildName = GetRaidLeaderGuild()
    if guildName and guildName == LootTrackerConfig.guildName then
        DebugPrint("Der Raidleiter ist Mitglied von '" .. LootTrackerConfig.guildName .. "'.")
        return true
    else
        DebugPrint("Der Raidleiter ist NICHT Mitglied von '" .. LootTrackerConfig.guildName .. "'.")
        return false
    end
end

local function ShouldTrackInstance()
    local inInstance, instanceType = IsInInstance()
    local instanceName, _, difficultyID = GetInstanceInfo()
    
    if inInstance then
        if instanceType == "raid" then
            local instanceDifficulty = nil
            if difficultyID == 14 then
                instanceDifficulty = "NHC"
            elseif difficultyID == 15 then
                instanceDifficulty = "HC"
            elseif difficultyID == 16 then
                instanceDifficulty = "MYTHIC"
            elseif difficultyID == 17 then
                instanceDifficulty = "LFR"
            elseif difficultyID == 233 then
                instanceDifficulty = "MYTHIC_FLEX"
            else
                instanceDifficulty = "unknown"
            end
            
            if LootTrackerConfig.trackedRaidDifficulties[instanceDifficulty] then
                DebugPrint(string.format("Instanz verfolgen: %s (%s, %s) %s", instanceName, difficultyID, instanceType, instanceDifficulty))
                return true
            else
                DebugPrint(string.format("Instanz NICHT verfolgen: %s (%s). Schwierigkeitsgrad nicht aktiviert.", instanceName, difficultyID))
                return false
            end
        else
            DebugPrint(string.format("Instanz nicht verfolgen: %s (%s)", instanceName, instanceType))
            return false
        end
    else
        DebugPrint(string.format("Nicht in einer Instanz"))
        return false
    end
end


local listenerFrame = CreateFrame("Frame")
listenerFrame:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")

listenerFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "LOOT_HISTORY_UPDATE_DROP" then
        local encounterID, lootListID = ...
        DebugPrint("Loot Event...")

        local dropInfo = C_LootHistory.GetSortedInfoForDrop(encounterID, lootListID)
        if not dropInfo or not dropInfo.itemHyperlink then return end

        if dropInfo.winner then
            DebugPrint("Prüfe Schwierigkeitsgrad...")
            if not ShouldTrackInstance() then return end
            DebugPrint("Schwierigkeitsgrad gültig, verarbeite Loot...")

            if LootTrackerConfig.checkRaidLeader then
                DebugPrint("Prüfe Raidleader")
                if not IsRaidLeaderInGuild() then return end
            end
            DebugPrint("Prüfung bestanden, verarbeite Loot")
            local item = Item:CreateFromItemLink(dropInfo.itemHyperlink)
            -- Item data may not be cached yet. The hyperlink already carries
            -- the localized display name, so recording can still finish now.
            local itemName = item:GetItemName()
                or dropInfo.itemHyperlink:match("|h%[(.-)%]|h")
                or dropInfo.itemHyperlink
            local itemID, _, _, itemEquipLoc =
                C_Item.GetItemInfoInstant(dropInfo.itemHyperlink)
            local encounterInfo = C_LootHistory.GetInfoForEncounter(encounterID)
            local bossName = encounterInfo and encounterInfo.encounterName or "Unbekannt"

            local rollTypeName = "Unbekannt"
            local rollValue = 0
            if dropInfo.rollInfos then
                for _, roll in ipairs(dropInfo.rollInfos) do
                    if roll.isWinner then
                        local rollType = roll.state
                        rollValue = roll.roll or 0
                        if rollType == Enum.EncounterLootDropRollState.NeedMainSpec then
                            rollTypeName = "Need (Main Spec)"
                        elseif rollType == Enum.EncounterLootDropRollState.NeedOffSpec then
                            rollTypeName = "Need (Off Spec)"
                        elseif rollType == Enum.EncounterLootDropRollState.Greed then
                            rollTypeName = "Greed"
                        elseif rollType == Enum.EncounterLootDropRollState.Transmog then
                            rollTypeName = "Transmog"
                        elseif rollType == Enum.EncounterLootDropRollState.Pass then
                            rollTypeName = "Pass"
                        else
                            rollTypeName = "Unbekannt" 
                        end
                        break 
                    end
                end
            end

            local itemSlot = ""
            if itemEquipLoc and _G[itemEquipLoc] then
                itemSlot = _G[itemEquipLoc]
            elseif itemEquipLoc then
                itemSlot = itemEquipLoc
            else
                itemSlot = "Nicht ausrüstbar"
            end

            local fullTime = date("%Y-%m-%d %H:%M:%S")
            local dateOnly = date("%Y-%m-%d")

            local playerGUID = dropInfo.winner.playerGUID or "Unbekannt"
            local playerClass = "Unbekannt"
            local playerSpecialization = dropInfo.winner.specialization or "Unbekannt"

            if playerGUID ~= "Unbekannt" then
                local locClassString, _, _, _, _, _, _ = GetPlayerInfoByGUID(playerGUID)
                if locClassString then
                    playerClass = locClassString
                end
            end


            LootTrackerDB = LootTrackerDB or {}
            LootTrackerDB[dateOnly] = LootTrackerDB[dateOnly] or {}
            local rosterID = RWLootTrackerGlobal.CaptureRaidRoster(dateOnly)

            table.insert(LootTrackerDB[dateOnly], {
                time = fullTime,
                player = dropInfo.winner.playerName,
                playerGUID = playerGUID,
                playerClass = playerClass,
                playerSpecialization = playerSpecialization,
                item = dropInfo.itemHyperlink,
                itemID = itemID,
                itemName = itemName,
                method = rollTypeName,
                rollValue = rollValue,
                boss = bossName,
                slot = itemSlot,
                dateOnly = dateOnly,
                rosterID = rosterID
            })

            if RWLootTrackerGlobal.calendarFrame then
                RWLootTrackerGlobal.InitializeCalendar()
            end

            if LootTrackerConfig.LogToChat then
                print("RWLootTracker: Gewinner erkannt: " .. (dropInfo.winner.playerName or "Unbekannt") .. " (" .. playerClass .. ", " .. playerSpecialization .. ", GUID: " .. playerGUID .. "), " .. itemName .. " (Roll: " .. rollTypeName .. ", Wert: " .. rollValue .. ")")
            end
        else
            DebugPrint("... no Winner yet")
        end
    end
end)

DebugPrint("Listener-Modul geladen. " .. RWLootTrackerGlobal.GetVersion())
