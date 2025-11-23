-- Dies ist die Listener-Datei, die sich um die Beute-Events kütert.


local function DebugPrint(msg)
    if LootTrackerConfig and LootTrackerConfig.DebugMode then
        print("RWLootTracker: " .. msg)
    end
end

local function GetRaidLeaderGuild()
    DebugPrint("Checking Raid Group")
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name and UnitIsGroupLeader(name) then
            DebugPrint(string.format("Found group leader: %s", name))
            local guildName = GetGuildInfo(name)
            
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
    local instanceName, instanceMapID, difficultyName, maxPlayers, isDynamic, instanceID, instanceGroupSize = GetInstanceInfo()
    
    if inInstance then
        if instanceType == "raid" then
            local instanceDifficulty = nil
            if difficultyName == 14 then
                instanceDifficulty = "NHC"
            elseif difficultyName == 15 then
                instanceDifficulty = "HC"
            elseif difficultyName == 16 then
                instanceDifficulty = "MYTHIC"
            elseif difficultyName == 17 then
                instanceDifficulty = "LFR"
            else
                instanceDifficulty = "unknown"
            end
            
            if LootTrackerConfig.trackedRaidDifficulties[instanceDifficulty] then
                DebugPrint(string.format("Instanz verfolgen: %s (%s, %s) %s", instanceName, difficultyName, instanceType, instanceDifficulty))
                return true
            else
                DebugPrint(string.format("Instanz NICHT verfolgen: %s (%s). Schwierigkeitsgrad nicht aktiviert.", instanceName, difficultyName))
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
            local itemName = item:GetItemName()
            local itemID = select(1, GetItemInfoInstant(dropInfo.itemHyperlink))
            local encounterInfo = C_LootHistory.GetInfoForEncounter(encounterID)
            local bossName = encounterInfo and encounterInfo.encounterName or "Unbekannt"

            local rollTypeName = "Unbekannt"
            local rollValue = 0
            if dropInfo.rollInfos then
                for _, roll in ipairs(dropInfo.rollInfos) do
                    if roll.isWinner then
                        local rollType = roll.state
                        rollValue = roll.roll
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
                            rollTypeName = "Unbekannt" -- Fallback für unerwartete Rollzustände
                        end
                        break -- Wir haben den Gewinner gefunden, Schleife beenden
                    end
                end
            end

            local _, _, _, _, _, itemType, itemSubClass, _, itemEquipLoc = GetItemInfo(dropInfo.itemHyperlink)

            local armorType = ""
            if itemType == "Armor" then
                armorType = itemSubClass or "Unbekannt"
            elseif itemType == "Weapon" then
                armorType = "Waffe"
            else
                armorType = itemType or "Sonstiges"
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

            -- Zusätzliche Informationen aus dropInfo.winner und erweiterte Logik für Klasse/Spezialisierung
            local playerGUID = dropInfo.winner.playerGUID or "Unbekannt"
            local playerClass = "Unbekannt"
            local playerSpecialization = dropInfo.winner.specialization or "Unbekannt"

            -- Versuche, die Klasse über GetPlayerInfoByGUID zu ermitteln und zu lokalisieren
            if playerGUID ~= "Unbekannt" then
                -- Der erste Rückgabewert von GetPlayerInfoByGUID ist die lokalisierte Klasse.
                local locClassString, _, _, _, _, _, _ = GetPlayerInfoByGUID(playerGUID)
                if locClassString then
                    playerClass = locClassString
                end
            end


            -- Sicherstellen, dass LootTrackerDB existiert, bevor darauf zugegriffen wird
            LootTrackerDB = LootTrackerDB or {}
            LootTrackerDB[dateOnly] = LootTrackerDB[dateOnly] or {}

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
                armorType = armorType,
                slot = itemSlot,
                dateOnly = dateOnly
            })

            if LootTrackerConfig.LogToChat then
                print("RWLootTracker: Gewinner erkannt: " .. dropInfo.winner.playerName .. " (" .. playerClass .. ", " .. playerSpecialization .. ", GUID: " .. playerGUID .. "), " .. itemName .. " (Roll: " .. rollTypeName .. ", Wert: " .. rollValue .. ")")
            end
        else
            DebugPrint("... no Winner yet")
        end
    end
end)

DebugPrint("Listener-Modul geladen. " .. RWLootTrackerGlobal.GetVersion())
