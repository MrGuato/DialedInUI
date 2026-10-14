-- Turns a preset into an Edit Mode layout and saves it.
--
-- Every preset starts from a copy of one of Blizzard's own layouts (Modern,
-- Classic or Gamepad) and only changes what it lists. Anything a preset does
-- not mention stays exactly where Blizzard puts it. The result is saved as a
-- normal account layout named "DialedInUI", so it shows up in Edit Mode like any
-- layout you made yourself and can be tweaked there afterwards.
--
-- Nothing here touches Blizzard's frames directly. Layouts go through
-- C_EditMode and the UI is reloaded afterwards, which keeps the action bars
-- clean of addon taint.

local ADDON, ns = ...

local Layout = {}
ns.Layout = Layout

Layout.OWNED_NAME = "DialedInUI"

-- Edit Mode stores slider values in an encoded form. Most sliders store
-- (shown value - min) / step, size sliders for frames in pixels store
-- (shown value - min), and everything else is stored as is.
local function pct(min, step)
    return { kind = "pct", min = min, step = step }
end
local function diff(min)
    return { kind = "diff", min = min }
end
local function enum(name)
    return { kind = "enum", enum = name }
end
local RAW = { kind = "raw" }
local BOOL = { kind = "bool" }
local function composite(hundreds, ones)
    return { kind = "composite", hundreds = hundreds, ones = ones }
end

-- Ranges come from Blizzard's EditModeSettingDisplayInfo for the Forever client.
local CODEC = {
    ActionBar = {
        Orientation = enum("ActionBarOrientation"),
        NumRows = RAW,
        NumIcons = RAW,
        IconSize = pct(50, 10),
        IconPadding = RAW,
        VisibleSetting = enum("ActionBarVisibleSetting"),
        HideBarArt = BOOL,
        HideBarScrolling = BOOL,
        AlwaysShowButtons = BOOL,
    },
    CastBar = {
        BarSize = pct(100, 10),
        LockToPlayerFrame = BOOL,
        ShowCastTime = BOOL,
    },
    Minimap = {
        HeaderUnderneath = BOOL,
        RotateMinimap = BOOL,
        Size = pct(50, 10),
        IconScale = pct(50, 10),
    },
    UnitFrame = {
        CastBarUnderneath = BOOL,
        BuffsOnTop = BOOL,
        UseLargerFrame = BOOL,
        UseRaidStylePartyFrames = BOOL,
        ShowPartyFrameBackground = BOOL,
        UseHorizontalGroups = BOOL,
        DisplayBorder = BOOL,
        FrameWidth = diff(72),
        FrameHeight = diff(36),
        FrameSize = pct(100, 5),
        RaidGroupDisplayType = enum("RaidGroupDisplayType"),
        SortPlayersBy = enum("SortPlayersBy"),
        RowSize = RAW,
        Opacity = pct(50, 1),
        ViewRaidSize = enum("ViewRaidSize"),
        DebuffIconSize = pct(50, 10),
        BuffIconSize = pct(50, 10),
    },
    AuraFrame = {
        IconSize = pct(50, 10),
        IconPadding = RAW,
        IconLimitBuffFrame = RAW,
        IconLimitDebuffFrame = RAW,
        Opacity = pct(50, 1),
        VisibleSetting = enum("AuraFrameVisibleSetting"),
        ShowDispelType = BOOL,
    },
    ChatFrame = {
        Width = composite("WidthHundreds", "WidthTensAndOnes"),
        Height = composite("HeightHundreds", "HeightTensAndOnes"),
    },
    ObjectiveTracker = {
        Height = pct(400, 10),
        Opacity = pct(0, 1),
        TextSize = pct(12, 1),
    },
    MicroMenu = {
        Orientation = enum("MicroMenuOrientation"),
        Size = pct(70, 5),
    },
    Bags = {
        Orientation = enum("BagsOrientation"),
        Direction = enum("BagsDirection"),
        Size = pct(75, 5),
    },
    StatusTrackingBar = {
        Size = pct(50, 5),
    },
    DurabilityFrame = {
        Size = pct(75, 5),
    },
    CooldownViewer = {
        Orientation = enum("CooldownViewerOrientation"),
        IconLimit = RAW,
        IconSize = pct(50, 10),
        IconPadding = RAW,
        Opacity = pct(50, 1),
        VisibleSetting = enum("CooldownViewerVisibleSetting"),
        HideWhenInactive = BOOL,
    },
    PersonalResourceDisplay = {
        Size = pct(70, 10),
        Opacity = pct(50, 1),
        VisibleSetting = enum("PersonalResourceDisplayVisibleSetting"),
    },
    DamageMeter = {
        Visibility = enum("DamageMeterVisibility"),
        Style = enum("DamageMeterStyle"),
        Numbers = enum("DamageMeterNumbers"),
        FrameWidth = diff(200),
        FrameHeight = diff(120),
        BackgroundTransparency = pct(0, 1),
    },
    SwingTimer = {
        Visibility = enum("EditModeSwingTimerVisibility"),
        Width = diff(213),
        Height = diff(15),
        Opacity = pct(50, 1),
    },
    LossOfControl = {
        Size = pct(50, 10),
    },
    MainActionBarEndCap = {
        Hidden = BOOL,
    },
    GamepadMainActionBar = {
        Compact = BOOL,
        ShowEmptyBars = BOOL,
        ShowButtonPrompts = BOOL,
        ShowHighlight = BOOL,
        ShouldExpand = BOOL,
    },
}
Layout.CODEC = CODEC

local function settingEnum(sysName)
    return Enum["EditMode" .. sysName .. "Setting"]
end

local function indexEnum(sysName)
    return Enum["EditMode" .. sysName .. "SystemIndices"]
end

-- Value as Edit Mode stores it, or nil and a reason.
function Layout.Encode(codec, value)
    local kind = codec.kind
    if kind == "bool" then
        return value and 1 or 0
    elseif kind == "raw" then
        return value
    elseif kind == "pct" then
        local stored = (value - codec.min) / codec.step
        if stored ~= math.floor(stored) then
            return nil, ("%s is not on a %d step from %d"):format(tostring(value), codec.step, codec.min)
        end
        return stored
    elseif kind == "diff" then
        return value - codec.min
    elseif kind == "enum" then
        if type(value) == "number" then
            return value
        end
        local e = Enum[codec.enum]
        local stored = e and e[value]
        if stored == nil then
            return nil, ("unknown value %s for %s"):format(tostring(value), codec.enum)
        end
        return stored
    end
    return nil, "unknown codec"
end

local function numPresets()
    local meta = Enum.EditModePresetLayoutsMeta
    if meta and meta.NumValues then
        return meta.NumValues
    end
    local mgr = rawget(_G, "EditModePresetLayoutManager")
    if mgr and mgr.presetLayoutInfo then
        return #mgr.presetLayoutInfo
    end
    return 3
end

local function basePreset(name)
    local mgr = rawget(_G, "EditModePresetLayoutManager")
    if not (mgr and mgr.GetCopyOfPresetLayouts) then
        return nil
    end
    local wanted = Enum.EditModePresetLayouts[name]
    for _, layout in ipairs(mgr:GetCopyOfPresetLayouts()) do
        if layout.layoutIndex == wanted then
            return layout
        end
    end
    return nil
end

local function findSystem(systems, sys, index)
    for _, info in ipairs(systems) do
        if info.system == sys and info.systemIndex == index then
            return info
        end
    end
    return nil
end

local function setSetting(info, setting, value)
    for _, entry in ipairs(info.settings) do
        if entry.setting == setting then
            entry.value = value
            return true
        end
    end
    return false
end

-- Applies one preset entry: { system, index, anchor, settings }.
local function applyEntry(systems, entry, problems)
    local sysName, indexName, at, set = entry[1], entry[2], entry[3], entry[4]
    local label = sysName .. (indexName and ("." .. indexName) or "")

    local sys = Enum.EditModeSystem[sysName]
    if sys == nil then
        problems[#problems + 1] = label .. ": no such system"
        return
    end
    local index
    if indexName then
        local indices = indexEnum(sysName)
        index = indices and indices[indexName]
        if index == nil then
            problems[#problems + 1] = label .. ": no such index"
            return
        end
    end
    local info = findSystem(systems, sys, index)
    if not info then
        problems[#problems + 1] = label .. ": not in the base layout"
        return
    end

    if at then
        info.anchorInfo = {
            point = at.point,
            relativeTo = "UIParent",
            relativePoint = at.relativePoint,
            offsetX = at.x,
            offsetY = at.y,
        }
        info.anchorInfo2 = nil
        info.isInDefaultPosition = false
    end

    if set then
        local codecs = CODEC[sysName] or {}
        local settings = settingEnum(sysName) or {}
        for name, value in pairs(set) do
            local codec = codecs[name]
            if not codec then
                problems[#problems + 1] = label .. "." .. name .. ": no codec"
            elseif codec.kind == "composite" then
                local h, o = settings[codec.hundreds], settings[codec.ones]
                local ok1 = h and setSetting(info, h, math.floor(value / 100))
                local ok2 = o and setSetting(info, o, value % 100)
                if not (ok1 and ok2) then
                    problems[#problems + 1] = label .. "." .. name .. ": not in the base layout"
                end
            else
                local setting = settings[name]
                local stored, why = Layout.Encode(codec, value)
                if setting == nil then
                    problems[#problems + 1] = label .. "." .. name .. ": no such setting"
                elseif stored == nil then
                    problems[#problems + 1] = label .. "." .. name .. ": " .. why
                elseif not setSetting(info, setting, stored) then
                    problems[#problems + 1] = label .. "." .. name .. ": not in the base layout"
                end
            end
        end
    end
end

-- Returns the finished layout and a list of anything that could not be applied.
function Layout.Build(preset)
    local base = basePreset(preset.base)
    if not base then
        return nil, { "Blizzard's " .. tostring(preset.base) .. " layout is not available" }
    end
    local layout = {
        layoutName = Layout.OWNED_NAME,
        layoutType = Enum.EditModeLayoutType.Account,
        interfaceStyle = base.interfaceStyle,
        systems = base.systems,
    }
    local problems = {}
    for _, entry in ipairs(preset.place) do
        applyEntry(layout.systems, entry, problems)
    end
    return layout, problems
end

-- Saved layouts only, in the order Edit Mode keeps them, plus the index of
-- the first saved layout in the combined list Edit Mode uses for activeLayout.
local function readSaved()
    local data = C_EditMode.GetLayouts()
    local saved = {}
    for _, layout in ipairs(data.layouts or {}) do
        if layout.layoutType ~= Enum.EditModeLayoutType.Preset then
            saved[#saved + 1] = layout
        end
    end
    return saved, data.activeLayout
end

-- Where the player is now, in a form that survives other layouts moving.
function Layout.Snapshot()
    local saved, active = readSaved()
    local presets = numPresets()
    if not active or active <= presets then
        return { preset = active or 1 }
    end
    local layout = saved[active - presets]
    if not layout then
        return { preset = 1 }
    end
    return { name = layout.layoutName, layoutType = layout.layoutType }
end

function Layout.ActiveIsOwned()
    local saved, active = readSaved()
    local layout = active and saved[active - numPresets()]
    return layout ~= nil and layout.layoutType == Enum.EditModeLayoutType.Account
        and layout.layoutName == Layout.OWNED_NAME
end

-- Saves the layout into the DialedInUI slot and makes it active.
function Layout.Save(layout)
    local saved = readSaved()
    local account = Enum.EditModeLayoutType.Account

    local pos
    for i, existing in ipairs(saved) do
        if existing.layoutType == account and existing.layoutName == Layout.OWNED_NAME then
            pos = i
            break
        end
    end

    if pos then
        saved[pos] = layout
    else
        local accounts, lastAccount = 0, 0
        for i, existing in ipairs(saved) do
            if existing.layoutType == account then
                accounts = accounts + 1
                lastAccount = i
            end
        end
        local max = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType or 5
        if accounts >= max then
            return nil, ("Edit Mode already has %d account layouts. Delete one in Edit Mode, then try again."):format(max)
        end
        pos = lastAccount + 1
        table.insert(saved, pos, layout)
    end

    local index = numPresets() + pos
    C_EditMode.SaveLayouts({ layouts = saved, activeLayout = index })
    C_EditMode.SetActiveLayout(index)
    return index
end

-- Removes the DialedInUI layout and switches back to what the snapshot recorded.
function Layout.Restore(snapshot)
    local saved = readSaved()
    local account = Enum.EditModeLayoutType.Account
    for i = #saved, 1, -1 do
        if saved[i].layoutType == account and saved[i].layoutName == Layout.OWNED_NAME then
            table.remove(saved, i)
        end
    end

    local index
    if snapshot and snapshot.preset then
        index = snapshot.preset
    elseif snapshot then
        for i, layout in ipairs(saved) do
            if layout.layoutName == snapshot.name and layout.layoutType == snapshot.layoutType then
                index = numPresets() + i
                break
            end
        end
    end
    index = index or 1

    C_EditMode.SaveLayouts({ layouts = saved, activeLayout = index })
    C_EditMode.SetActiveLayout(index)
    return index
end
