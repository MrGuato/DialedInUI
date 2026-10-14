-- Game settings a preset can change: a handful of CVars from the options
-- menu, plus turning on the extra action bars a layout uses.
--
-- Every value is recorded before it is changed so Undo can put it back.
-- Action bars are only ever turned on, never off. If you had a bar enabled
-- that a preset does not use, it stays enabled.

local ADDON, ns = ...

local Tweaks = {}
ns.Tweaks = Tweaks

-- What each setting is called in the picker. Order is the order shown.
local LABELS = {
    { "statusText", nil },
    { "statusTextDisplay", "Health and mana numbers" },
    { "showTargetOfTarget", "Target of target" },
    { "cameraDistanceMaxZoomFactor", "Max camera distance" },
    { "countdownForCooldowns", "Cooldown numbers on buttons" },
    { "cooldownViewerEnabled", "Cooldown Manager" },
    { "damageMeterEnabled", "Damage meter" },
    { "nameplateShowSelf", "Personal resource display" },
    { "combinedBags", "Combined bags" },
    { "autoLootDefault", "Auto loot" },
    { "enableMouseoverCast", "Mouseover casting" },
    { "raidFramesDisplayClassColor", "Class colors on raid frames" },
    { "raidFramesDisplayPowerBars", "Power bars on raid frames" },
    { "raidFramesHealthText", "Raid frame health text" },
    { "nameplateShowEnemies", "Enemy nameplates" },
    { "doNotFlashLowHealthWarning", "Low health screen flash" },
}

local VALUE_TEXT = {
    statusTextDisplay = { NUMERIC = "numbers", PERCENT = "percent", BOTH = "both", NONE = "off" },
    raidFramesHealthText = { none = "off", health = "health", losthealth = "health lost", perc = "percent" },
    cameraDistanceMaxZoomFactor = {},
    -- This one is worded the other way round in the game.
    doNotFlashLowHealthWarning = { ["1"] = "off", ["0"] = "on" },
}

local BAR_NAMES = { [2] = "Bar 2", [3] = "Bar 3", [4] = "Bar 4", [5] = "Bar 5", [6] = "Bar 6", [7] = "Bar 7", [8] = "Bar 8" }

local function getCVar(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    return GetCVar(name)
end

local function setCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        return C_CVar.SetCVar(name, value)
    end
    return SetCVar(name, value)
end

-- Lines describing what a preset changes, for the picker.
function Tweaks.Describe(preset)
    local lines = {}
    local cvars = preset.cvars or {}
    for _, pair in ipairs(LABELS) do
        local name, label = pair[1], pair[2]
        local value = cvars[name]
        if label and value ~= nil then
            local text
            local map = VALUE_TEXT[name]
            if map then
                text = map[value]
                if name == "cameraDistanceMaxZoomFactor" then
                    text = "max"
                end
            end
            if not text then
                text = (value == "1") and "on" or (value == "0") and "off" or value
            end
            lines[#lines + 1] = label .. ": " .. text
        end
    end
    if preset.bars and #preset.bars > 0 then
        local names = {}
        for _, n in ipairs(preset.bars) do
            names[#names + 1] = BAR_NAMES[n] or ("Bar " .. n)
        end
        lines[#lines + 1] = "Turns on " .. table.concat(names, ", ")
    end
    return lines
end

-- Remembers current values for anything this preset touches that is not
-- already remembered, so applying several presets in a row still undoes
-- back to how things were before the first one.
function Tweaks.Remember(preset, undo)
    undo.cvars = undo.cvars or {}
    for name in pairs(preset.cvars or {}) do
        if undo.cvars[name] == nil then
            local current = getCVar(name)
            if current ~= nil then
                undo.cvars[name] = current
            end
        end
    end
end

-- Returns how many settings were changed and the names that were skipped.
function Tweaks.Apply(preset)
    local changed, skipped = 0, {}
    for name, value in pairs(preset.cvars or {}) do
        if getCVar(name) == nil then
            skipped[#skipped + 1] = name
        elseif getCVar(name) ~= value then
            setCVar(name, value)
            changed = changed + 1
        end
    end
    return changed, skipped
end

function Tweaks.ApplyBars(preset)
    if not (preset.bars and GetActionBarToggles and SetActionBarToggles) then
        return 0
    end
    if C_GameRules and C_GameRules.IsMultiActionBarVisibilityForced and C_GameRules.IsMultiActionBarVisibilityForced() then
        return 0
    end
    local toggles = { GetActionBarToggles() }
    local turnedOn = 0
    for _, bar in ipairs(preset.bars) do
        -- The toggles start at Bar 2.
        local slot = bar - 1
        if slot >= 1 and slot <= 7 and not toggles[slot] then
            toggles[slot] = true
            turnedOn = turnedOn + 1
        end
    end
    if turnedOn > 0 then
        for i = 1, 7 do
            toggles[i] = toggles[i] and true or false
        end
        SetActionBarToggles(unpack(toggles, 1, 7))
    end
    return turnedOn
end

-- Bars are saved per character, so they come back on the character that
-- applied the layout. Other characters keep whatever bars they had.
function Tweaks.Restore(undo, char)
    for name, value in pairs(undo and undo.cvars or {}) do
        if getCVar(name) ~= nil and getCVar(name) ~= value then
            setCVar(name, value)
        end
    end
    local bars = char and char.undoBars
    if bars and SetActionBarToggles then
        local flags = {}
        for i = 1, 7 do
            flags[i] = bars[i] and true or false
        end
        SetActionBarToggles(unpack(flags, 1, 7))
        char.undoBars = nil
    end
end
