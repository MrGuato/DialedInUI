-- The layouts.
--
-- Each preset names one of Blizzard's layouts as its base and lists only what
-- it changes. An entry is { system, index, position, settings }:
--   position  where the frame goes, relative to the screen, or nil to leave it
--   settings  Edit Mode settings in the units Edit Mode shows (percent,
--             pixels, on/off), converted when the layout is built
--
-- Positions are in UI units. With the default UI scale the screen is 768
-- units tall and 1366 wide at 16:9, and every layout here is laid out to fit
-- that without overlaps. A smaller UI scale shrinks everything towards the
-- same anchor points.
--
-- cvars are game options, listed in the picker before applying. bars lists
-- the extra action bars a layout turns on. Bars are never turned off.

local ADDON, ns = ...

local Presets = {}
ns.Presets = Presets

local function at(point, x, y, relativePoint)
    return { point = point, relativePoint = relativePoint or point, x = x, y = y }
end

local VERTICAL = "Vertical"

-- The minimap cluster as measured in game: the zone name bar on top stays
-- about 205 wide at any size, and with the coordinates underneath the whole
-- thing is about 150 + 150 x size tall. Buffs go to its left, with room for
-- two rows before the debuffs, and the quest tracker goes below it.
local function mapWidth(size)
    return math.max(205, math.floor(214 * size / 100 + 0.5))
end
local function mapHeight(size)
    return math.floor(150 + 150 * size / 100 + 0.5)
end
local function buffsBeside(list, mapSize, buffSize, debuffSize)
    local x = -(mapWidth(mapSize) + 10)
    list[#list + 1] = { "AuraFrame", "BuffFrame", at("TOPRIGHT", x, -8), buffSize and { IconSize = buffSize } or nil }
    list[#list + 1] = { "AuraFrame", "DebuffFrame", at("TOPRIGHT", x, -110), debuffSize and { IconSize = debuffSize } or nil }
end
local function trackerBelow(list, mapSize, x, set)
    list[#list + 1] = { "ObjectiveTracker", nil, at("TOPRIGHT", x, -(mapHeight(mapSize) + 10)), set }
end

-- Bars a layout does not use get a row near the top middle, out of the way,
-- in case you already had them turned on. Pass "Hidden" to hide them, and a
-- top offset to start the rows lower. Side bars are vertical by default, so
-- every row is set to horizontal.
local SPARE_X = -120
local function spareBars(list, names, size, visible, top)
    local step = math.floor(45 * size / 100 + 0.5) + 4
    for i, name in ipairs(names) do
        local set = { IconSize = size, Orientation = "Horizontal" }
        if visible then
            set.VisibleSetting = visible
        end
        list[#list + 1] = { "ActionBar", name, at("TOP", SPARE_X, (top or -4) - (i - 1) * step), set }
    end
end

local function hideEndCaps(list)
    list[#list + 1] = { "MainActionBarEndCap", "EndCapLeft", nil, { Hidden = true } }
    list[#list + 1] = { "MainActionBarEndCap", "EndCapRight", nil, { Hidden = true } }
end

local function hideCooldownViewer(list, names)
    for _, name in ipairs(names or { "Essential", "Utility", "BuffIcon", "BuffBar" }) do
        list[#list + 1] = { "CooldownViewer", name, nil, { VisibleSetting = "Hidden" } }
    end
end

local function swing(list, offY, mainY, visible)
    local set = { Visibility = visible or "Always" }
    list[#list + 1] = { "SwingTimer", "OffHand", at("BOTTOM", 0, offY), set }
    list[#list + 1] = { "SwingTimer", "MainHand", at("BOTTOM", 0, mainY), set }
    list[#list + 1] = { "SwingTimer", "Ranged", at("BOTTOM", 0, offY), set }
end

local function hideSwing(list)
    for _, name in ipairs({ "MainHand", "OffHand", "Ranged" }) do
        list[#list + 1] = { "SwingTimer", name, nil, { Visibility = "Hidden" } }
    end
end

local list = {}
Presets.list = list

---------------------------------------------------------------------------
-- 1. Center Stage
---------------------------------------------------------------------------
do
    local place = {
        { "StatusTrackingBar", "StatusTrackingBar1", at("BOTTOM", 0, 0), { Size = 50 } },
        { "StatusTrackingBar", "StatusTrackingBar2", at("BOTTOM", 0, 12), { Size = 50 } },
        { "ActionBar", "MainBar", at("BOTTOM", 0, 26), { IconSize = 80, HideBarArt = true, HideBarScrolling = true } },
        { "ActionBar", "Bar2", at("BOTTOM", 0, 64), { IconSize = 80 } },
        { "ActionBar", "Bar3", at("BOTTOM", 0, 102), { IconSize = 80 } },
        { "ActionBar", "PetActionBar", at("BOTTOMRIGHT", -4, 142, "BOTTOM"), { IconSize = 50 } },
        { "ActionBar", "StanceBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "ActionBar", "PossessActionBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "TotemActionBar", nil, at("BOTTOMLEFT", 4, 142, "BOTTOM") },
        { "CastBar", nil, at("BOTTOM", 0, 218), { BarSize = 120, ShowCastTime = true } },
        { "CooldownViewer", "Utility", at("BOTTOM", 0, 244), { IconSize = 80, IconLimit = 7 } },
        { "CooldownViewer", "Essential", at("BOTTOM", 0, 286), { IconLimit = 8 } },
        { "CooldownViewer", "BuffIcon", at("BOTTOM", 0, 337), { IconSize = 80 } },
        { "UnitFrame", "Player", at("BOTTOMRIGHT", -195, 232, "BOTTOM") },
        { "UnitFrame", "Target", at("BOTTOMLEFT", 195, 232, "BOTTOM") },
        { "UnitFrame", "Focus", at("BOTTOMRIGHT", -195, 344, "BOTTOM") },
        { "UnitFrame", "Party", at("TOPRIGHT", -460, 80, "CENTER"), { UseRaidStylePartyFrames = true, SortPlayersBy = "Role" } },
        { "UnitFrame", "Raid", at("TOPLEFT", 8, -50), { RaidGroupDisplayType = "CombineGroupsHorizontal", RowSize = 5, FrameWidth = 80, FrameHeight = 36 } },
        { "UnitFrame", "Boss", at("RIGHT", -90, 40) },
        { "PersonalResourceDisplay", nil, nil, { VisibleSetting = "Hidden" } },
        { "ChatFrame", nil, at("BOTTOMLEFT", 8, 26), { Width = 330, Height = 160 } },
        { "MicroMenu", nil, at("BOTTOMRIGHT", -8, 8), { Size = 80 } },
        { "Bags", nil, at("BOTTOMRIGHT", -8, 40), { Size = 80 } },
        { "DamageMeter", nil, at("BOTTOMRIGHT", -8, 82), { Visibility = "InGroup", Style = "Thin", FrameWidth = 240, FrameHeight = 130 } },
        { "HudTooltip", nil, at("BOTTOMRIGHT", -8, 218) },
        { "ExtraAbilities", nil, at("BOTTOM", 0, 380) },
        { "EncounterBar", nil, at("TOP", 0, -160) },
    }
    buffsBeside(place, 100, 90, nil)
    trackerBelow(place, 100, -5, { Height = 400 })
    hideEndCaps(place)
    hideCooldownViewer(place, { "BuffBar" })
    swing(place, 182, 200)
    spareBars(place, { "RightBar1", "RightBar2", "ExtraBar1", "ExtraBar2", "ExtraBar3" }, 70)

    list[#list + 1] = {
        key = "center",
        name = "Center Stage",
        bestFor = "Dungeons and raids, DPS and tanks",
        about = "Everything you watch in a fight sits in one column under your character: player and target on either side, the Cooldown Manager and cast bar between them, three bars stacked at the bottom without the stone band. Chat, bags and the meter go to the corners.",
        base = "Modern",
        bars = { 2, 3 },
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "BOTH",
            showTargetOfTarget = "1",
            cameraDistanceMaxZoomFactor = "2",
            countdownForCooldowns = "1",
            cooldownViewerEnabled = "1",
            damageMeterEnabled = "1",
            raidFramesDisplayClassColor = "1",
        },
    }
end

---------------------------------------------------------------------------
-- 2. Classic 2004
---------------------------------------------------------------------------
do
    local place = {
        { "ChatFrame", nil, at("BOTTOMLEFT", 32, 160), { Width = 430, Height = 120 } },
        -- The 2004 side bars: one column each on the right edge. Placed by hand
        -- so they sit under the taller Forever minimap at any screen height.
        { "ActionBar", "RightBar1", at("RIGHT", -5, -100), { Orientation = VERTICAL, IconSize = 60 } },
        { "ActionBar", "RightBar2", at("RIGHT", -37, -100), { Orientation = VERTICAL, IconSize = 60 } },
        { "DamageMeter", nil, nil, { Visibility = "Hidden" } },
        { "PersonalResourceDisplay", nil, nil, { VisibleSetting = "Hidden" } },
    }
    buffsBeside(place, 100, nil, nil)
    trackerBelow(place, 100, -110, nil)
    hideCooldownViewer(place)
    hideSwing(place)
    spareBars(place, { "ExtraBar1", "ExtraBar2", "ExtraBar3" }, 80, "Hidden")

    list[#list + 1] = {
        key = "classic",
        name = "Classic 2004",
        bestFor = "Classic veterans and nostalgia",
        about = "Blizzard's Classic layout with the rough edges fixed: player and target in the top left, the stone action bar band with its gryphons, and the minimap, quest log and two side bars on the right. Chat moves up so it no longer covers the stance bar, and modern extras like the Cooldown Manager and damage meter stay hidden.",
        base = "Classic",
        bars = { 2, 3, 4, 5 },
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "NUMERIC",
            showTargetOfTarget = "1",
            combinedBags = "0",
        },
    }
end

---------------------------------------------------------------------------
-- 3. Clean Slate
---------------------------------------------------------------------------
do
    local place = {
        { "StatusTrackingBar", "StatusTrackingBar1", at("BOTTOM", 0, 0), { Size = 50 } },
        { "StatusTrackingBar", "StatusTrackingBar2", at("BOTTOM", 0, 12), { Size = 50 } },
        { "ActionBar", "MainBar", at("BOTTOM", 0, 26), { IconSize = 80, HideBarArt = true, HideBarScrolling = true, AlwaysShowButtons = false } },
        { "ActionBar", "Bar2", at("BOTTOM", 0, 64), { IconSize = 80, VisibleSetting = "InCombat", AlwaysShowButtons = false } },
        { "ActionBar", "Bar3", at("BOTTOM", 0, 102), { IconSize = 80, VisibleSetting = "InCombat", AlwaysShowButtons = false } },
        { "ActionBar", "PetActionBar", at("BOTTOMRIGHT", -4, 142, "BOTTOM"), { IconSize = 50 } },
        { "ActionBar", "StanceBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "ActionBar", "PossessActionBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "TotemActionBar", nil, at("BOTTOMLEFT", 4, 142, "BOTTOM") },
        { "CastBar", nil, at("BOTTOM", 0, 216), { ShowCastTime = true } },
        { "CooldownViewer", "Essential", at("BOTTOM", 0, 240), { IconSize = 80, IconLimit = 8, VisibleSetting = "InCombat", HideWhenInactive = true } },
        { "CooldownViewer", "BuffIcon", at("BOTTOM", 0, 282), { IconSize = 70, VisibleSetting = "InCombat" } },
        { "UnitFrame", "Player", at("BOTTOMRIGHT", -190, 230, "BOTTOM") },
        { "UnitFrame", "Target", at("BOTTOMLEFT", 190, 230, "BOTTOM") },
        { "UnitFrame", "Focus", at("BOTTOMRIGHT", -190, 342, "BOTTOM") },
        { "PersonalResourceDisplay", nil, at("CENTER", 0, -40), { VisibleSetting = "InCombat" } },
        { "UnitFrame", "Party", at("TOPRIGHT", -450, 40, "CENTER"), { UseRaidStylePartyFrames = true, FrameWidth = 80, FrameHeight = 36, Opacity = 70 } },
        { "UnitFrame", "Raid", at("TOPLEFT", 8, -50), { RaidGroupDisplayType = "CombineGroupsHorizontal", RowSize = 5, FrameWidth = 72, FrameHeight = 36, Opacity = 70 } },
        { "UnitFrame", "Boss", at("RIGHT", -80, 40) },
        { "Minimap", nil, nil, { Size = 80 } },
        { "ActionBar", "RightBar1", at("TOP", SPARE_X, -4), { Orientation = "Horizontal", IconSize = 70, VisibleSetting = "OutOfCombat" } },
        { "ChatFrame", nil, at("BOTTOMLEFT", 8, 26), { Width = 330, Height = 120 } },
        { "MicroMenu", nil, at("BOTTOMRIGHT", -6, 6), { Size = 70 } },
        { "Bags", nil, at("BOTTOMRIGHT", -6, 34), { Size = 75 } },
        { "DamageMeter", nil, at("BOTTOMRIGHT", -6, 74), { Visibility = "InGroup", Style = "Thin", BackgroundTransparency = 50, FrameWidth = 240, FrameHeight = 120 } },
        { "HudTooltip", nil, at("BOTTOMRIGHT", -6, 200) },
        { "ExtraAbilities", nil, at("BOTTOM", 0, 380) },
        { "EncounterBar", nil, at("TOP", 0, -160) },
    }
    buffsBeside(place, 80, 80, 80)
    trackerBelow(place, 80, -5, { Height = 400, TextSize = 12 })
    hideEndCaps(place)
    hideCooldownViewer(place, { "Utility", "BuffBar" })
    swing(place, 180, 198, "InCombat")
    spareBars(place, { "RightBar2", "ExtraBar1", "ExtraBar2", "ExtraBar3" }, 70, "Hidden")

    list[#list + 1] = {
        key = "clean",
        name = "Clean Slate",
        bestFor = "Exploring, leveling, screenshots",
        about = "As little on screen as possible. One small bar is always there, the other two only show in combat, Bar 4 sits along the top and only shows out of combat, and the cooldown icons and resource bar only appear when you fight. The middle of the screen stays clear.",
        base = "Modern",
        bars = { 2, 3, 4 },
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "PERCENT",
            cameraDistanceMaxZoomFactor = "2",
            countdownForCooldowns = "1",
            cooldownViewerEnabled = "1",
            nameplateShowSelf = "1",
            doNotFlashLowHealthWarning = "1",
        },
    }
end

---------------------------------------------------------------------------
-- 4. Healer Focus
---------------------------------------------------------------------------
do
    local place = {
        { "StatusTrackingBar", "StatusTrackingBar1", at("BOTTOM", 0, 0), { Size = 50 } },
        { "StatusTrackingBar", "StatusTrackingBar2", at("BOTTOM", 0, 12), { Size = 50 } },
        { "ActionBar", "MainBar", at("BOTTOM", 0, 26), { IconSize = 80, HideBarArt = true, HideBarScrolling = true } },
        { "ActionBar", "Bar2", at("BOTTOM", 0, 64), { IconSize = 80 } },
        { "ActionBar", "Bar3", at("BOTTOM", 0, 102), { IconSize = 80 } },
        { "ActionBar", "PetActionBar", at("BOTTOMRIGHT", -4, 142, "BOTTOM"), { IconSize = 50 } },
        { "ActionBar", "StanceBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "ActionBar", "PossessActionBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "TotemActionBar", nil, at("BOTTOMLEFT", 4, 142, "BOTTOM") },
        { "CastBar", nil, at("BOTTOM", 0, 180), { BarSize = 110, ShowCastTime = true } },
        { "UnitFrame", "Party", at("BOTTOM", 0, 204), { UseRaidStylePartyFrames = true, UseHorizontalGroups = true, FrameWidth = 76, FrameHeight = 52, SortPlayersBy = "Role" } },
        { "UnitFrame", "Raid", at("BOTTOM", 0, 204), { RaidGroupDisplayType = "CombineGroupsHorizontal", RowSize = 5, FrameWidth = 76, FrameHeight = 40, SortPlayersBy = "Role", DebuffIconSize = 120 } },
        { "CooldownViewer", "Utility", at("BOTTOMRIGHT", -200, 204, "BOTTOM"), { IconSize = 80, IconLimit = 6 } },
        { "CooldownViewer", "Essential", at("BOTTOMLEFT", 200, 204, "BOTTOM"), { IconSize = 80, IconLimit = 6 } },
        { "CooldownViewer", "BuffIcon", at("BOTTOMLEFT", 200, 246, "BOTTOM"), { IconSize = 70 } },
        { "UnitFrame", "Player", at("BOTTOMRIGHT", -195, 280, "BOTTOM") },
        { "UnitFrame", "Target", at("BOTTOMLEFT", 195, 280, "BOTTOM") },
        { "UnitFrame", "Focus", at("BOTTOMLEFT", 195, 392, "BOTTOM") },
        { "UnitFrame", "Boss", at("RIGHT", -90, 40) },
        { "PersonalResourceDisplay", nil, nil, { VisibleSetting = "Hidden" } },
        { "ChatFrame", nil, at("BOTTOMLEFT", 8, 26), { Width = 330, Height = 150 } },
        { "MicroMenu", nil, at("BOTTOMRIGHT", -8, 8), { Size = 80 } },
        { "Bags", nil, at("BOTTOMRIGHT", -8, 40), { Size = 80 } },
        { "DamageMeter", nil, at("BOTTOMRIGHT", -8, 82), { Visibility = "InGroup", Style = "Thin", Numbers = "Compact", FrameWidth = 240, FrameHeight = 120 } },
        { "HudTooltip", nil, at("BOTTOMRIGHT", -8, 218) },
        { "ExtraAbilities", nil, at("BOTTOMLEFT", 235, 90, "BOTTOM") },
        { "EncounterBar", nil, at("TOP", 0, -160) },
    }
    buffsBeside(place, 100, 90, nil)
    trackerBelow(place, 100, -5, { Height = 400 })
    hideEndCaps(place)
    hideCooldownViewer(place, { "BuffBar" })
    hideSwing(place)
    spareBars(place, { "RightBar1", "RightBar2", "ExtraBar1", "ExtraBar2", "ExtraBar3" }, 70)

    list[#list + 1] = {
        key = "healer",
        name = "Healer Focus",
        bestFor = "Healers in dungeons and raids",
        about = "Party and raid frames move to the lower middle of the screen, between your character and your bars, so health bars sit where your eyes already are. Player and target move up and out to the sides. Turns on mouseover casting and raid frame class colors.",
        base = "Modern",
        bars = { 2, 3 },
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "PERCENT",
            showTargetOfTarget = "1",
            cameraDistanceMaxZoomFactor = "2",
            countdownForCooldowns = "1",
            cooldownViewerEnabled = "1",
            damageMeterEnabled = "1",
            enableMouseoverCast = "1",
            raidFramesDisplayClassColor = "1",
            raidFramesDisplayPowerBars = "1",
            raidFramesHealthText = "losthealth",
        },
    }
end

---------------------------------------------------------------------------
-- 5. Mirror Panels
---------------------------------------------------------------------------
do
    local place = {
        { "StatusTrackingBar", "StatusTrackingBar1", at("BOTTOM", 0, 0), { Size = 50 } },
        { "StatusTrackingBar", "StatusTrackingBar2", at("BOTTOM", 0, 12), { Size = 50 } },
        { "ActionBar", "MainBar", at("BOTTOM", 0, 26), { IconSize = 80, HideBarArt = true, HideBarScrolling = true } },
        { "ActionBar", "Bar2", at("BOTTOM", 0, 64), { IconSize = 80 } },
        { "ActionBar", "Bar3", at("BOTTOM", 0, 102), { IconSize = 80 } },
        { "ChatFrame", nil, at("BOTTOMLEFT", 8, 26), { Width = 330, Height = 130 } },
        { "DamageMeter", nil, at("BOTTOMRIGHT", -8, 26), { Visibility = "Always", Style = "Bordered", FrameWidth = 330, FrameHeight = 130 } },
        { "ActionBar", "RightBar1", at("BOTTOMLEFT", 8, 186), { Orientation = "Horizontal", IconSize = 70 } },
        { "ActionBar", "RightBar2", at("BOTTOMRIGHT", -8, 186), { Orientation = "Horizontal", IconSize = 70 } },
        { "MicroMenu", nil, at("TOPLEFT", 8, -4), { Size = 80 } },
        { "Bags", nil, at("TOPLEFT", 242, -4), { Size = 80 } },
        { "ActionBar", "PetActionBar", at("BOTTOMRIGHT", -4, 142, "BOTTOM"), { IconSize = 50 } },
        { "ActionBar", "StanceBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "ActionBar", "PossessActionBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "TotemActionBar", nil, at("BOTTOMLEFT", 4, 142, "BOTTOM") },
        { "CooldownViewer", "Essential", at("BOTTOM", 0, 178), { IconSize = 80, IconLimit = 8 } },
        { "CooldownViewer", "Utility", at("BOTTOM", 0, 220), { IconSize = 70, IconLimit = 8 } },
        { "CooldownViewer", "BuffIcon", at("BOTTOM", 0, 258), { IconSize = 70 } },
        { "UnitFrame", "Player", at("BOTTOMRIGHT", -192, 230, "BOTTOM"), { CastBarUnderneath = true } },
        { "UnitFrame", "Target", at("BOTTOMLEFT", 192, 230, "BOTTOM") },
        { "UnitFrame", "Focus", at("BOTTOMLEFT", 192, 342, "BOTTOM") },
        { "CastBar", nil, at("BOTTOM", 0, 330), { LockToPlayerFrame = true } },
        { "UnitFrame", "Party", at("BOTTOMLEFT", 8, 230), { UseRaidStylePartyFrames = true } },
        { "UnitFrame", "Raid", at("TOPLEFT", 8, -110), { RaidGroupDisplayType = "CombineGroupsHorizontal", RowSize = 5, FrameWidth = 80, FrameHeight = 36 } },
        { "UnitFrame", "Boss", at("RIGHT", -60, 40) },
        { "PersonalResourceDisplay", nil, nil, { VisibleSetting = "Hidden" } },
        { "HudTooltip", nil, at("BOTTOMRIGHT", -8, 225) },
        { "ExtraAbilities", nil, at("BOTTOM", 0, 380) },
        { "EncounterBar", nil, at("TOP", 0, -160) },
    }
    buffsBeside(place, 100, 90, nil)
    trackerBelow(place, 100, -5, { Height = 400, Opacity = 20 })
    hideEndCaps(place)
    hideCooldownViewer(place, { "BuffBar" })
    swing(place, 290, 308)
    -- The micro menu and bags run along the top left here, so spare bars start
    -- lower to clear them on narrow screens.
    spareBars(place, { "ExtraBar1", "ExtraBar2", "ExtraBar3" }, 70, nil, -44)

    list[#list + 1] = {
        key = "mirror",
        name = "Mirror Panels",
        bestFor = "Former ElvUI users, raiders",
        about = "Chat in the bottom left and the damage meter in the bottom right as matching panels, each with a bar on top. Three bars stack in the middle, with player and target just above them and the cast bar under your player frame. The micro menu and bags move to the top left.",
        base = "Modern",
        bars = { 2, 3, 4, 5 },
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "BOTH",
            showTargetOfTarget = "1",
            cameraDistanceMaxZoomFactor = "2",
            countdownForCooldowns = "1",
            cooldownViewerEnabled = "1",
            damageMeterEnabled = "1",
            combinedBags = "1",
            raidFramesDisplayClassColor = "1",
        },
    }
end

---------------------------------------------------------------------------
-- 6. Controller
---------------------------------------------------------------------------
do
    local place = {
        { "GamepadMainActionBar", nil, nil, { ShowButtonPrompts = true } },
        { "UnitFrame", "Player", at("BOTTOMRIGHT", -160, 295, "BOTTOM"), { FrameSize = 110 } },
        { "UnitFrame", "Target", at("BOTTOMLEFT", 160, 295, "BOTTOM"), { FrameSize = 110 } },
        { "UnitFrame", "Focus", at("BOTTOM", 0, 390) },
        { "TotemActionBar", nil, at("BOTTOMRIGHT", -210, 250, "BOTTOM") },
        { "UnitFrame", "Party", at("BOTTOMRIGHT", -471, 236, "BOTTOM"), { UseRaidStylePartyFrames = true, FrameWidth = 100, FrameHeight = 50 } },
        { "UnitFrame", "Raid", at("TOPLEFT", 8, -140), { RaidGroupDisplayType = "CombineGroupsHorizontal", RowSize = 5, FrameWidth = 72, FrameHeight = 36 } },
        { "CooldownViewer", "Essential", at("BOTTOM", 0, 305), { IconSize = 80, IconLimit = 8 } },
        { "CooldownViewer", "BuffIcon", at("BOTTOM", 0, 347), { IconSize = 70 } },
        { "DamageMeter", nil, at("BOTTOMRIGHT", -8, 60), { Visibility = "InGroup", Style = "Thin", FrameWidth = 260, FrameHeight = 130 } },
        { "PersonalResourceDisplay", nil, nil, { VisibleSetting = "Hidden" } },
        { "ChatFrame", nil, at("BOTTOMLEFT", 8, 90), { Width = 370, Height = 120 } },
        { "Minimap", nil, nil, { Size = 120 } },
        { "SwingTimer", "MainHand", nil, { Visibility = "InCombat" } },
        { "SwingTimer", "OffHand", nil, { Visibility = "InCombat" } },
        { "SwingTimer", "Ranged", nil, { Visibility = "InCombat" } },
    }
    buffsBeside(place, 120, 110, 110)
    trackerBelow(place, 120, -5, { Height = 400, TextSize = 15 })
    hideCooldownViewer(place, { "Utility", "BuffBar" })

    list[#list + 1] = {
        key = "controller",
        name = "Controller",
        bestFor = "Gamepad, couch and Steam Deck",
        about = "Blizzard's gamepad layout, made easier to read from the couch: bigger player and target frames, button prompts on, party frames pulled toward the middle, and the damage meter moved away from the top left where the button legend lives. Needs the gamepad UI turned on first.",
        base = "Gamepad",
        needsGamepad = true,
        bars = {},
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "BOTH",
            showTargetOfTarget = "1",
            cameraDistanceMaxZoomFactor = "2",
            countdownForCooldowns = "1",
            cooldownViewerEnabled = "1",
        },
    }
end

---------------------------------------------------------------------------
-- 7. Ultrawide
---------------------------------------------------------------------------
do
    local place = {
        { "StatusTrackingBar", "StatusTrackingBar1", at("BOTTOM", 0, 0), { Size = 60 } },
        { "StatusTrackingBar", "StatusTrackingBar2", at("BOTTOM", 0, 12), { Size = 60 } },
        { "ActionBar", "MainBar", at("BOTTOM", 0, 26), { IconSize = 80, HideBarArt = true, HideBarScrolling = true } },
        { "ActionBar", "Bar2", at("BOTTOM", 0, 64), { IconSize = 80 } },
        { "ActionBar", "Bar3", at("BOTTOM", 0, 102), { IconSize = 80 } },
        { "ActionBar", "PetActionBar", at("BOTTOMLEFT", 235, 26, "BOTTOM"), { NumRows = 2, IconSize = 70 } },
        { "ActionBar", "StanceBar", at("BOTTOMLEFT", 235, 99, "BOTTOM"), { IconSize = 70 } },
        { "ActionBar", "PossessActionBar", at("BOTTOMLEFT", 235, 99, "BOTTOM"), { IconSize = 70 } },
        { "TotemActionBar", nil, at("BOTTOMLEFT", 235, 99, "BOTTOM") },
        { "CastBar", nil, at("BOTTOM", 0, 186), { BarSize = 120, ShowCastTime = true } },
        { "CooldownViewer", "Utility", at("BOTTOM", 0, 212), { IconSize = 80, IconLimit = 7 } },
        { "CooldownViewer", "Essential", at("BOTTOM", 0, 254), { IconLimit = 8 } },
        { "CooldownViewer", "BuffIcon", at("BOTTOM", 0, 305), { IconSize = 80 } },
        { "UnitFrame", "Player", at("BOTTOMRIGHT", -200, 240, "BOTTOM") },
        { "UnitFrame", "Target", at("BOTTOMLEFT", 200, 240, "BOTTOM") },
        { "UnitFrame", "Focus", at("BOTTOMLEFT", 200, 352, "BOTTOM") },
        { "ActionBar", "RightBar1", at("LEFT", 520, 10, "CENTER"), { Orientation = VERTICAL, NumRows = 2, IconSize = 80 } },
        { "ActionBar", "RightBar2", at("RIGHT", -520, 10, "CENTER"), { Orientation = VERTICAL, NumRows = 2, IconSize = 80 } },
        { "DamageMeter", nil, at("BOTTOMLEFT", 420, 26, "BOTTOM"), { Visibility = "InGroup", Style = "Thin", FrameWidth = 260, FrameHeight = 130 } },
        { "UnitFrame", "Party", at("TOPRIGHT", -640, 80, "CENTER"), { UseRaidStylePartyFrames = true, SortPlayersBy = "Role" } },
        { "UnitFrame", "Raid", at("TOPRIGHT", -480, 280, "CENTER"), { RaidGroupDisplayType = "CombineGroupsHorizontal", RowSize = 5, FrameWidth = 80, FrameHeight = 36 } },
        { "UnitFrame", "Boss", at("RIGHT", 680, 80, "CENTER") },
        { "PersonalResourceDisplay", nil, nil, { VisibleSetting = "Hidden" } },
        { "ChatFrame", nil, at("BOTTOMLEFT", 8, 8), { Width = 420, Height = 180 } },
        { "MicroMenu", nil, at("BOTTOMRIGHT", -8, 8), { Size = 85 } },
        { "Bags", nil, at("BOTTOMRIGHT", -8, 42), { Size = 85 } },
        { "HudTooltip", nil, at("BOTTOMRIGHT", -8, 80) },
        { "ExtraAbilities", nil, at("BOTTOM", 0, 352) },
        { "EncounterBar", nil, at("TOP", 0, -160) },
    }
    buffsBeside(place, 100, 90, nil)
    trackerBelow(place, 100, -30, { Height = 400 })
    hideEndCaps(place)
    hideCooldownViewer(place, { "BuffBar" })
    swing(place, 146, 164)
    spareBars(place, { "ExtraBar1", "ExtraBar2", "ExtraBar3" }, 70)

    list[#list + 1] = {
        key = "ultrawide",
        name = "Ultrawide",
        bestFor = "21:9 and 32:9 monitors",
        about = "The Center Stage fight column, anchored to the middle so it never stretches across a wide screen. Side bars, boss frames and the damage meter are pulled in close to the middle where you can see them without turning your head. Chat and bags stay in the far corners.",
        base = "Modern",
        screen = 1792,
        bars = { 2, 3, 4, 5 },
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "BOTH",
            showTargetOfTarget = "1",
            cameraDistanceMaxZoomFactor = "2",
            countdownForCooldowns = "1",
            cooldownViewerEnabled = "1",
            damageMeterEnabled = "1",
            raidFramesDisplayClassColor = "1",
        },
    }
end

---------------------------------------------------------------------------
-- 8. Questing
---------------------------------------------------------------------------
do
    local place = {
        { "Minimap", nil, nil, { Size = 130 } },
        { "ChatFrame", nil, at("BOTTOMLEFT", 32, 160), { Width = 450, Height = 170 } },
        { "DamageMeter", nil, at("BOTTOMRIGHT", -8, 130), { Visibility = "InGroup", Style = "Thin", FrameWidth = 240, FrameHeight = 130 } },
        { "PersonalResourceDisplay", nil, nil, { VisibleSetting = "Hidden" } },
    }
    buffsBeside(place, 130, nil, nil)
    trackerBelow(place, 130, -110, { Height = 500, Opacity = 30, TextSize = 14 })
    hideCooldownViewer(place, { "Utility", "BuffBar" })
    for _, name in ipairs({ "MainHand", "OffHand", "Ranged" }) do
        place[#place + 1] = { "SwingTimer", name, nil, { Visibility = "InCombat" } }
    end
    -- Bars 4 and 5, if you already use them, become rows below the player and
    -- target frames, clear of the bigger minimap.
    spareBars(place, { "RightBar1", "RightBar2" }, 70, nil, -110)
    spareBars(place, { "ExtraBar1", "ExtraBar2", "ExtraBar3" }, 70, "Hidden")

    list[#list + 1] = {
        key = "questing",
        name = "Questing",
        bestFor = "Leveling your first character",
        about = "Keeps the middle of the screen clear for the world: player and target in the top left and the Forever action bar band at the bottom, with the things you read while leveling made bigger. A larger minimap, a taller quest tracker with bigger text, and a roomier chat for quest text and loot.",
        base = "Classic",
        bars = { 2, 3 },
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "NUMERIC",
            cameraDistanceMaxZoomFactor = "2",
            countdownForCooldowns = "1",
            autoLootDefault = "1",
            combinedBags = "1",
        },
    }
end

---------------------------------------------------------------------------
-- 9. Battleground
---------------------------------------------------------------------------
do
    local place = {
        { "StatusTrackingBar", "StatusTrackingBar1", at("BOTTOM", 0, 0), { Size = 50 } },
        { "StatusTrackingBar", "StatusTrackingBar2", at("BOTTOM", 0, 12), { Size = 50 } },
        { "ActionBar", "MainBar", at("BOTTOM", 0, 26), { IconSize = 80, HideBarArt = true, HideBarScrolling = true } },
        { "ActionBar", "Bar2", at("BOTTOM", 0, 64), { IconSize = 80 } },
        { "ActionBar", "Bar3", at("BOTTOM", 0, 102), { IconSize = 80 } },
        { "ActionBar", "PetActionBar", at("BOTTOMRIGHT", -4, 142, "BOTTOM"), { IconSize = 50 } },
        { "ActionBar", "StanceBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "ActionBar", "PossessActionBar", at("BOTTOMLEFT", 4, 142, "BOTTOM"), { IconSize = 60 } },
        { "TotemActionBar", nil, at("BOTTOMLEFT", 4, 142, "BOTTOM") },
        { "CooldownViewer", "Utility", at("BOTTOM", 0, 214), { IconSize = 80, IconLimit = 7 } },
        { "CastBar", nil, at("BOTTOM", 0, 256), { BarSize = 120, ShowCastTime = true } },
        { "CooldownViewer", "Essential", at("BOTTOM", 0, 282), { IconSize = 90, IconLimit = 6 } },
        { "CooldownViewer", "BuffIcon", at("BOTTOM", 0, 329), { IconSize = 80 } },
        { "UnitFrame", "Player", at("BOTTOMRIGHT", -150, 282, "BOTTOM") },
        { "UnitFrame", "Target", at("BOTTOMLEFT", 150, 282, "BOTTOM"), { BuffsOnTop = true } },
        { "UnitFrame", "Focus", at("BOTTOM", 0, 372) },
        { "UnitFrame", "Party", at("RIGHT", -400, 0, "CENTER"), { UseRaidStylePartyFrames = true, FrameWidth = 110, FrameHeight = 48, SortPlayersBy = "Role" } },
        { "UnitFrame", "Raid", at("TOPLEFT", 8, -110), { RaidGroupDisplayType = "CombineGroupsHorizontal", RowSize = 5, FrameWidth = 72, FrameHeight = 36 } },
        { "UnitFrame", "Boss", at("RIGHT", -90, 40) },
        { "LossOfControl", nil, at("CENTER", 0, 90), { Size = 120 } },
        { "PersonalResourceDisplay", nil, nil, { VisibleSetting = "Hidden" } },
        { "Minimap", nil, nil, { Size = 110 } },
        { "ChatFrame", nil, at("BOTTOMLEFT", 8, 26), { Width = 330, Height = 140 } },
        { "MicroMenu", nil, at("BOTTOMRIGHT", -8, 8), { Size = 75 } },
        { "Bags", nil, at("BOTTOMRIGHT", -8, 38), { Size = 75 } },
        { "DamageMeter", nil, at("BOTTOMRIGHT", -8, 78), { Visibility = "InGroup", Style = "Thin", FrameWidth = 240, FrameHeight = 130 } },
        { "HudTooltip", nil, at("BOTTOMRIGHT", -8, 214) },
        { "ExtraAbilities", nil, at("BOTTOMLEFT", 240, 160, "BOTTOM") },
        { "EncounterBar", nil, at("TOP", 0, -160) },
    }
    buffsBeside(place, 110, nil, 120)
    trackerBelow(place, 110, -5, { Height = 400, Opacity = 0 })
    hideEndCaps(place)
    hideCooldownViewer(place, { "BuffBar" })
    swing(place, 180, 198, "InCombat")
    spareBars(place, { "RightBar1", "RightBar2", "ExtraBar1", "ExtraBar2", "ExtraBar3" }, 70)

    list[#list + 1] = {
        key = "pvp",
        name = "Battleground",
        bestFor = "Battlegrounds and world PvP",
        about = "A tight cluster in the middle so you never look away from the fight: player and target close together, the focus frame centered above them, your party at the same distance to the left, and a bigger loss of control alert. Turns on enemy nameplates.",
        base = "Modern",
        bars = { 2, 3 },
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "PERCENT",
            showTargetOfTarget = "1",
            cameraDistanceMaxZoomFactor = "2",
            countdownForCooldowns = "1",
            cooldownViewerEnabled = "1",
            nameplateShowEnemies = "1",
        },
    }
end

---------------------------------------------------------------------------
-- 10. Laptop
---------------------------------------------------------------------------
do
    local place = {
        { "StatusTrackingBar", "StatusTrackingBar1", at("BOTTOM", 0, 0), { Size = 50 } },
        { "StatusTrackingBar", "StatusTrackingBar2", at("BOTTOM", 0, 12), { Size = 50 } },
        { "ActionBar", "MainBar", at("BOTTOM", 0, 24), { IconSize = 80, HideBarArt = true, HideBarScrolling = true } },
        { "ActionBar", "Bar2", at("BOTTOM", 0, 62), { IconSize = 80 } },
        { "ActionBar", "Bar3", at("RIGHT", -5, 0), { Orientation = VERTICAL, NumRows = 2, IconSize = 70 } },
        { "ActionBar", "PetActionBar", at("BOTTOMRIGHT", -4, 102, "BOTTOM"), { IconSize = 50 } },
        { "ActionBar", "StanceBar", at("BOTTOMLEFT", 4, 102, "BOTTOM"), { IconSize = 60 } },
        { "ActionBar", "PossessActionBar", at("BOTTOMLEFT", 4, 102, "BOTTOM"), { IconSize = 60 } },
        { "TotemActionBar", nil, at("BOTTOMLEFT", 4, 102, "BOTTOM") },
        { "CastBar", nil, at("BOTTOM", 0, 142) },
        { "CooldownViewer", "Essential", at("BOTTOM", 0, 196), { IconSize = 80, IconLimit = 8 } },
        { "CooldownViewer", "BuffIcon", at("BOTTOM", 0, 238), { IconSize = 70 } },
        { "UnitFrame", "Player", at("BOTTOMRIGHT", -190, 162, "BOTTOM") },
        { "UnitFrame", "Target", at("BOTTOMLEFT", 190, 162, "BOTTOM") },
        { "UnitFrame", "Focus", at("BOTTOMRIGHT", -190, 274, "BOTTOM") },
        { "UnitFrame", "Party", at("TOPLEFT", 8, 120, "LEFT"), { UseRaidStylePartyFrames = true, FrameWidth = 72, FrameHeight = 36 } },
        { "UnitFrame", "Raid", at("TOPLEFT", 8, -60), { RaidGroupDisplayType = "CombineGroupsHorizontal", RowSize = 5, FrameWidth = 72, FrameHeight = 36 } },
        { "UnitFrame", "Boss", at("RIGHT", -80, 40) },
        { "PersonalResourceDisplay", nil, nil, { VisibleSetting = "Hidden" } },
        { "Minimap", nil, nil, { Size = 80 } },
        { "ActionBar", "RightBar1", at("RIGHT", -74, 0), { Orientation = VERTICAL, NumRows = 2, IconSize = 70 } },
        { "ChatFrame", nil, at("BOTTOMLEFT", 6, 6), { Width = 290, Height = 120 } },
        { "MicroMenu", nil, at("BOTTOMRIGHT", -4, 4), { Size = 70 } },
        { "Bags", nil, at("BOTTOMRIGHT", -4, 32), { Size = 75 } },
        { "DamageMeter", nil, at("BOTTOMRIGHT", -4, 72), { Visibility = "InGroup", Style = "Thin", FrameWidth = 200, FrameHeight = 120 } },
        { "HudTooltip", nil, at("BOTTOMRIGHT", -4, 198) },
        { "ExtraAbilities", nil, at("BOTTOM", 0, 276) },
        { "EncounterBar", nil, at("TOP", 0, -150) },
    }
    buffsBeside(place, 80, 70, 70)
    trackerBelow(place, 80, -145, { Height = 400, TextSize = 12 })
    hideEndCaps(place)
    hideCooldownViewer(place, { "Utility", "BuffBar" })
    swing(place, 160, 178, "InCombat")
    spareBars(place, { "RightBar2", "ExtraBar1", "ExtraBar2", "ExtraBar3" }, 70, "Hidden")

    list[#list + 1] = {
        key = "laptop",
        name = "Laptop",
        bestFor = "MacBooks, laptops and small screens",
        about = "Everything a little smaller so nothing overlaps on a 13 or 14 inch screen: two bars at the bottom, bars 3 and 4 as a compact block on the right edge, a smaller minimap and chat, and compact party frames on the left. On a Steam Deck use Controller instead.",
        base = "Modern",
        bars = { 2, 3, 4 },
        place = place,
        cvars = {
            statusText = "1",
            statusTextDisplay = "PERCENT",
            cameraDistanceMaxZoomFactor = "2",
            countdownForCooldowns = "1",
            cooldownViewerEnabled = "1",
            combinedBags = "1",
        },
    }
end

Presets.byKey = {}
for _, preset in ipairs(list) do
    Presets.byKey[preset.key] = preset
end

function Presets.Get(key)
    return Presets.byKey[key]
end
