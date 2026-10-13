-- Compact raid roster snapshots: one per distinct lineup and day, referenced
-- by loot entries instead of copied into every drop.
local addon = RWLootTrackerGlobal

function addon.IsOriginalRecipient(entry, guid, name)
    local original = entry.originalWinner
    if not original then return false end
    if guid and guid ~= "" and original[2] and original[2] ~= "" then
        return guid == original[2]
    end
    return name == original[1]
end

function addon.RestoreOriginalWinner(entry)
    local original = entry.originalWinner
    if not original then return end
    entry.player = original[1]
    entry.playerGUID = original[2]
    entry.playerClass = original[3]
    entry.originalWinner = nil
    entry.comment = entry.note
end

-- Fix transfers returned to their initial winner by version 0.6.0.
-- Run only after the saved database has been loaded.
function addon.NormalizeTransferredEntries()
    for day, entries in pairs(LootTrackerDB) do
        if type(day) == "string" and day:match("^%d%d%d%d%-%d%d%-%d%d$")
            and type(entries) == "table" then
            for _, entry in ipairs(entries) do
                if addon.IsOriginalRecipient(entry, entry.playerGUID, entry.player) then
                    addon.RestoreOriginalWinner(entry)
                end
            end
        end
    end
end

function addon.CaptureRaidRoster(dateKey)
    if not IsInRaid() then return nil end
    local members = {}
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        local guid = UnitGUID(unit)
        local name, _, _, _, class = GetRaidRosterInfo(i)
        if guid and name then
            members[#members + 1] = {guid, name, class}
        end
    end
    if #members == 0 then return nil end
    table.sort(members, function(a, b) return a[1] < b[1] end)

    LootTrackerDB._rosters = LootTrackerDB._rosters or {}
    local snapshots = LootTrackerDB._rosters[dateKey] or {}
    LootTrackerDB._rosters[dateKey] = snapshots
    for id, previous in ipairs(snapshots) do
        if #previous == #members then
            local same = true
            for i = 1, #members do
                if previous[i][1] ~= members[i][1] then
                    same = false
                    break
                end
            end
            if same then return id end
        end
    end
    snapshots[#snapshots + 1] = members
    return #snapshots
end

local function Matches(name, search)
    return search == "" or (name and name:lower():find(search, 1, true))
end

function addon.GetEligibleRecipients(entry, dateKey, search)
    search = (search or ""):lower()
    local snapshots = LootTrackerDB._rosters and LootTrackerDB._rosters[dateKey]
    local roster = snapshots and entry.rosterID and snapshots[entry.rosterID]
    local candidates = {}
    if roster then
        for _, member in ipairs(roster) do
            if Matches(member[2], search) then
                candidates[#candidates + 1] = member
            end
        end
    else
        -- Old records cannot reconstruct their historical raid. Prefer winners
        -- on the same day; an explicit search can also find known players from
        -- other days. A manual name remains possible for unknown recipients.
        local seen = {}
        local function Add(record)
            local guid, name = record.playerGUID, record.player
            local key = guid and guid ~= "" and guid ~= "Unbekannt" and guid or name
            if key and name and not seen[key] and Matches(name, search) then
                seen[key] = true
                candidates[#candidates + 1] = {guid, name, record.playerClass}
            end
        end
        for _, record in ipairs(LootTrackerDB[dateKey] or {}) do
            Add(record)
            if record.originalWinner then
                Add({
                    player = record.originalWinner[1],
                    playerGUID = record.originalWinner[2],
                    playerClass = record.originalWinner[3],
                })
            end
        end
        if search ~= "" then
            for day, records in pairs(LootTrackerDB) do
                if day ~= dateKey and type(day) == "string" and day:match("^%d%d%d%d%-%d%d%-%d%d$")
                    and type(records) == "table" then
                    for _, record in ipairs(records) do Add(record) end
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a[2]:lower() < b[2]:lower() end)
    return candidates, roster ~= nil
end
