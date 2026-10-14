-- A rough picture of a layout, worked out from the same data the layout is
-- built from. Sizes are approximate (frames grow with buffs, party size and
-- so on), so this is a sketch of where things go, not a screenshot.

local _, ns = ...

local Preview = {}
ns.Preview = Preview

local SCREEN_H = 768
local BUTTON = 45

local BAR_NUMBER = {
    MainBar = 1, Bar2 = 2, Bar3 = 3, RightBar1 = 4, RightBar2 = 5,
    ExtraBar1 = 6, ExtraBar2 = 7, ExtraBar3 = 8,
}

local function reverse(t)
    local r = {}
    for k, v in pairs(t or {}) do
        r[v] = k
    end
    return r
end

-- Stored Edit Mode value back to what Edit Mode shows.
local function decode(codec, stored)
    if stored == nil or not codec then
        return stored
    end
    if codec.kind == "pct" then
        return stored * codec.step + codec.min
    elseif codec.kind == "diff" then
        return stored + codec.min
    elseif codec.kind == "bool" then
        return stored == 1
    elseif codec.kind == "enum" then
        return reverse(Enum[codec.enum])[stored]
    end
    return stored
end

-- Shown values for one system, by setting name.
local function readSettings(sysName, info)
    local out = {}
    local names = reverse(Enum["EditMode" .. sysName .. "Setting"])
    local codecs = ns.Layout.CODEC[sysName] or {}
    for _, entry in ipairs(info.settings or {}) do
        local name = names[entry.setting]
        if name then
            out[name] = decode(codecs[name], entry.value)
        end
    end
    -- Chat stores width and height in two parts each.
    if out.WidthHundreds then
        out.Width = out.WidthHundreds * 100 + (out.WidthTensAndOnes or 0)
        out.Height = out.HeightHundreds * 100 + (out.HeightTensAndOnes or 0)
    end
    return out
end

local function barSize(s)
    local scale = (s.IconSize or 100) / 100
    local n = s.NumIcons or 12
    local rows = s.NumRows or 1
    local pad = s.IconPadding or 2
    local btn = BUTTON * scale
    local cols = math.ceil(n / rows)
    local w = cols * btn + (cols - 1) * pad
    local h = rows * btn + (rows - 1) * pad
    if s.Orientation == "Vertical" then
        return h, w
    end
    return w, h
end

-- kind, label, width, height for a system, or nil to leave it out.
local function describe(sysName, indexName, s, preset)
    local cvars = preset.cvars or {}
    if sysName == "ActionBar" and (indexName == "StanceBar" or indexName == "PetActionBar") then
        -- Class bars: drawn with a typical button count so overlaps show up.
        local t = {}
        for k, v in pairs(s) do
            t[k] = v
        end
        t.NumIcons = indexName == "StanceBar" and 4 or 10
        local w, h = barSize(t)
        return "minor", nil, w, h
    elseif sysName == "TotemActionBar" then
        return "minor", nil, 150, 36
    elseif sysName == "ActionBar" then
        local number = BAR_NUMBER[indexName]
        if not number or s.VisibleSetting == "Hidden" then
            return nil
        end
        if number > 1 and not preset.showAllBars then
            local wanted = false
            for _, b in ipairs(preset.bars or {}) do
                if b == number then
                    wanted = true
                end
            end
            if not wanted then
                return nil
            end
        end
        local w, h = barSize(s)
        return "bars", nil, w, h
    elseif sysName == "GamepadMainActionBar" then
        return "bars", "Gamepad bar", 400, 130
    elseif sysName == "UnitFrame" then
        local size = (s.FrameSize or 100) / 100
        if indexName == "Player" or indexName == "Target" then
            return "unit", indexName, 232 * size, 100 * size
        elseif indexName == "Focus" then
            if s.UseLargerFrame then
                return "unit", "Focus", 232 * size, 100 * size
            end
            return "unit", "Focus", 180 * size, 75 * size
        elseif indexName == "Party" then
            if s.UseRaidStylePartyFrames then
                local cw, ch = s.FrameWidth or 98, s.FrameHeight or 44
                if s.UseHorizontalGroups then
                    return "group", "Party", cw * 5, ch
                end
                return "group", "Party", cw, ch * 5
            end
            return "group", "Party", 130, 4 * 62
        end
        return nil
    elseif sysName == "CastBar" then
        local size = (s.BarSize or 100) / 100
        return "cast", "Cast", 208 * size, 16 * size
    elseif sysName == "Minimap" then
        -- Measured in game: the zone name bar stays about 205 wide whatever
        -- the size, and the coordinates sit under the map.
        local size = (s.Size or 100) / 100
        return "map", "Map", math.max(205, 214 * size), 150 + 150 * size
    elseif sysName == "AuraFrame" then
        local icon = 30 * (s.IconSize or 100) / 100 + 5
        if indexName == "BuffFrame" then
            return "info", "Buffs", icon * 8, icon
        elseif indexName == "DebuffFrame" then
            return "info", nil, icon * 5, icon
        end
        return nil
    elseif sysName == "ChatFrame" then
        return "chat", "Chat", s.Width or 430, s.Height or 170
    elseif sysName == "ObjectiveTracker" then
        return "info", "Quests", 250, math.min(s.Height or 800, 600) * 0.55
    elseif sysName == "MicroMenu" then
        local size = (s.Size or 100) / 100
        return "info", nil, 283 * size, 36 * size
    elseif sysName == "Bags" then
        local size = (s.Size or 100) / 100
        return "info", nil, 300 * size, 48 * size
    elseif sysName == "StatusTrackingBar" then
        if indexName ~= "StatusTrackingBar1" then
            return nil
        end
        local size = (s.Size or 100) / 100
        return "info", nil, 1150 * size, 10
    elseif sysName == "CooldownViewer" then
        if cvars.cooldownViewerEnabled ~= "1" or s.VisibleSetting == "Hidden" then
            return nil
        end
        local icon = BUTTON * (s.IconSize or 100) / 100
        local pad = s.IconPadding or 2
        if indexName == "Essential" or indexName == "Utility" then
            local n = math.min(s.IconLimit or 8, indexName == "Essential" and 8 or 6)
            return "cooldown", nil, n * icon + (n - 1) * pad, icon
        elseif indexName == "BuffIcon" then
            return "cooldown", nil, 4 * icon + 3 * pad, icon
        end
        return nil
    elseif sysName == "DamageMeter" then
        if s.Visibility == "Hidden" then
            return nil
        end
        if cvars.damageMeterEnabled ~= "1" then
            return nil
        end
        return "meter", "Meter", s.FrameWidth or 400, s.FrameHeight or 140
    elseif sysName == "PersonalResourceDisplay" then
        if cvars.nameplateShowSelf ~= "1" or s.VisibleSetting == "Hidden" then
            return nil
        end
        local size = (s.Size or 100) / 100
        return "cooldown", nil, 200 * size, 34 * size
    end
    return nil
end

local H_FACTOR = { LEFT = 0, CENTER = 0.5, RIGHT = 1 }
local V_FACTOR = { BOTTOM = 0, CENTER = 0.5, TOP = 1 }

local function split(point)
    if point == "CENTER" then
        return "CENTER", "CENTER"
    end
    local v = point:match("^(TOP)") or point:match("^(BOTTOM)") or "CENTER"
    local h = point:match("(LEFT)$") or point:match("(RIGHT)$") or "CENTER"
    return h, v
end

-- Lower left corner of a frame anchored to the screen.
local function place(anchor, w, h, screenW)
    local fh, fv = split(anchor.point)
    local rh, rv = split(anchor.relativePoint)
    local ax = H_FACTOR[rh] * screenW + anchor.offsetX
    local ay = V_FACTOR[rv] * SCREEN_H + anchor.offsetY
    return ax - H_FACTOR[fh] * w, ay - V_FACTOR[fv] * h
end

-- Approximate spots for frames Blizzard positions itself (the Forever
-- action bar band and the frames stacked on it).
local function defaultSpot(sysName, indexName, w, h, rects, screenW)
    local mid = screenW / 2
    if sysName == "MicroMenu" then
        return mid + 116.5 - w / 2, 6
    elseif sysName == "ActionBar" and indexName == "MainBar" then
        local micro = rects.MicroMenu
        local right = micro and micro.x or (mid - 33)
        return right - 4.5 - w, 2
    elseif sysName == "Bags" then
        local micro = rects.MicroMenu
        local left = micro and (micro.x + micro.w) or (mid + 267)
        return left + 7, 2
    elseif sysName == "StatusTrackingBar" then
        local main = rects.MainBar
        if main then
            return main.x, main.y + main.h + 4
        end
        return mid - w / 2, 0
    elseif sysName == "ActionBar" and (indexName == "Bar2" or indexName == "Bar3") then
        local main = rects.MainBar
        local xp = rects.StatusTrackingBar1
        if not main then
            return nil
        end
        local y = (xp and (xp.y + xp.h) or (main.y + main.h)) + 4
        return main.x + (indexName == "Bar2" and 22 or 606), y
    elseif sysName == "ActionBar" and (indexName == "RightBar1" or indexName == "RightBar2") then
        -- Blizzard shrinks the side bars to fit between the minimap and the
        -- bottom bars, so they are drawn no taller than that gap.
        local x = screenW - 5 - w
        if indexName == "RightBar2" then
            x = x - w - 5
        end
        return x, SCREEN_H / 2 - 77 - h / 2
    elseif sysName == "ActionBar" and (indexName == "StanceBar" or indexName == "PetActionBar") then
        local bar2 = rects.Bar2 or rects.MainBar
        if not bar2 then
            return nil
        end
        return bar2.x + 8, bar2.y + bar2.h + 4
    elseif sysName == "CastBar" then
        local top = 0
        -- Blizzard stacks the default cast bar above the pet and stance bars
        -- as well as the action bars.
        for _, key in ipairs({ "MainBar", "StatusTrackingBar1", "Bar2", "Bar3", "GamepadMainActionBar",
            "PetActionBar", "StanceBar" }) do
            local r = rects[key]
            if r then
                top = math.max(top, r.y + r.h)
            end
        end
        return mid - w / 2, top + 40
    elseif sysName == "UnitFrame" and indexName == "Party" then
        return 12, SCREEN_H - 150 - h
    end
    return nil
end

-- Order matters: the band is worked out from the micro menu outwards, so the
-- micro menu comes first, then the main bar, the XP bar on top of it, the
-- bars above that, and finally the cast bar above everything.
local function rank(item)
    local sys = item.sysName
    if sys == "MicroMenu" then
        return 1
    elseif sys == "Bags" then
        return 2
    elseif sys == "GamepadMainActionBar" then
        return 3
    elseif sys == "ActionBar" and item.indexName == "MainBar" then
        return 4
    elseif sys == "StatusTrackingBar" then
        return 5
    elseif sys == "ActionBar" then
        return 6 + (BAR_NUMBER[item.indexName] or 20) / 100
    elseif sys == "CastBar" then
        return 7
    end
    return 9
end

-- Returns a list of { x, y, w, h, kind, label } in UI units, plus the
-- screen width used. y grows upwards from the bottom of the screen.
function Preview.Rects(preset, layout)
    local screenW = preset.screen or 1366
    local items = {}
    local sysNames = reverse(Enum.EditModeSystem)
    for _, info in ipairs(layout.systems) do
        local sysName = sysNames[info.system]
        local indexName = info.systemIndex and reverse(Enum["EditMode" .. sysName .. "SystemIndices"])[info.systemIndex]
        items[#items + 1] = { info = info, sysName = sysName, indexName = indexName }
    end
    for i, item in ipairs(items) do
        item.rank = rank(item) + i / 10000
    end
    table.sort(items, function(a, b)
        return a.rank < b.rank
    end)

    local rects, byKey = {}, {}
    for _, item in ipairs(items) do
        local s = readSettings(item.sysName, item.info)
        local kind, label, w, h = describe(item.sysName, item.indexName, s, preset)
        if kind and item.info.isInDefaultPosition and (item.indexName == "RightBar1" or item.indexName == "RightBar2") then
            local fit = 400 / h
            if fit < 1 then
                w, h = w * fit, h * fit
            end
        end
        if kind then
            local x, y
            local anchor = item.info.anchorInfo
            if item.info.isInDefaultPosition and anchor.relativeTo ~= "UIParent" then
                x, y = defaultSpot(item.sysName, item.indexName, w, h, byKey, screenW)
            elseif item.info.isInDefaultPosition and (item.sysName == "ActionBar" or item.sysName == "CastBar"
                or item.sysName == "StatusTrackingBar") then
                x, y = defaultSpot(item.sysName, item.indexName, w, h, byKey, screenW)
            else
                x, y = place(anchor, w, h, screenW)
            end
            if x then
                local r = { x = x, y = y, w = w, h = h, kind = kind, label = label }
                rects[#rects + 1] = r
                byKey[item.indexName or item.sysName] = r
            end
        end
    end
    return rects, screenW, SCREEN_H
end

Preview.COLORS = {
    bars = { 0.55, 0.57, 0.62 },
    unit = { 0.95, 0.74, 0.25 },
    group = { 0.36, 0.78, 0.42 },
    chat = { 0.36, 0.58, 0.95 },
    map = { 0.30, 0.78, 0.78 },
    cooldown = { 0.68, 0.46, 0.95 },
    meter = { 0.95, 0.50, 0.30 },
    cast = { 1.00, 0.86, 0.45 },
    info = { 0.45, 0.45, 0.48 },
    minor = { 0.40, 0.42, 0.47 },
}
