-- Runs DialedInUI under plain Lua 5.1 against a stubbed game API.
--
-- The Edit Mode data is not stubbed: the harness loads Blizzard's own preset
-- layouts, enums and slider definitions from a checkout of the Forever UI
-- source, so every preset is checked against the real thing.
--
--   lua5.1 tests/harness.lua <addon dir> <wow-ui-source dir, forever branch> [rects.lua out]

local dir, src, rectsOut = arg[1], arg[2], arg[3]
assert(dir and src, "usage: harness.lua <addon dir> <wow-ui-source dir> [rects out]")
local A = src .. "/Interface/AddOns/"

local out = {}
local realprint = print
print = function(...)
    local t = {}
    for i = 1, select("#", ...) do
        t[#t + 1] = tostring((select(i, ...)))
    end
    out[#out + 1] = table.concat(t, " ")
end
local function lastSaid()
    return out[#out] or ""
end

---------------------------------------------------------------------------
-- Enums and constants from Blizzard's API documentation
---------------------------------------------------------------------------
Enum, Constants = {}, {}
-- The documentation file reads a few enums while it is being built, before
-- they are registered. Hand out empty tables until the real ones arrive.
setmetatable(Enum, { __index = function(t, k)
    local e = {}
    rawset(t, k, e)
    return e
end })
APIDocumentation = {
    AddDocumentationTable = function(_, doc)
        for _, t in ipairs(doc.Tables or {}) do
            if t.Type == "Enumeration" then
                local e = {}
                for _, f in ipairs(t.Fields) do
                    e[f.Name] = f.EnumValue
                end
                Enum[t.Name] = e
                Enum[t.Name .. "Meta"] = { NumValues = #t.Fields }
            elseif t.Type == "Constants" then
                local c = {}
                for _, v in ipairs(t.Values) do
                    c[v.Name] = tonumber(v.Value) or v.Value
                end
                Constants[t.Name] = c
            end
        end
    end,
}
assert(loadfile(A .. "Blizzard_APIDocumentationGenerated/EditModeManagerConstantsDocumentation.lua"))()
setmetatable(Enum, nil)
Enum.InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 }
assert(Constants.EditModeConsts.EditModeMaxLayoutsPerType == 5)

---------------------------------------------------------------------------
-- Small parts of Blizzard's shared Lua the data files expect
---------------------------------------------------------------------------
function CopyTable(t)
    local c = {}
    for k, v in pairs(t) do
        c[k] = type(v) == "table" and CopyTable(v) or v
    end
    return c
end
function Clamp(v, lo, hi)
    return math.min(math.max(v, lo), hi)
end
function FormatPercentage(v)
    return tostring(v * 100) .. "%"
end
TableUtil = {
    GetHighestNumericalValueInTable = function(t)
        local h
        for _, v in pairs(t) do
            if type(v) == "number" and (not h or v > h) then
                h = v
            end
        end
        return h
    end,
}
C_AddOns = { EnableAddOn = function() end }

---------------------------------------------------------------------------
-- Edit Mode store
---------------------------------------------------------------------------
local store = { layouts = {}, active = 1 }
local calls = { save = 0, setActive = {} }
C_EditMode = {
    GetEditModeDefaultLayout = function() return Enum.EditModePresetLayouts.Modern end,
    GetLayouts = function()
        return { layouts = CopyTable(store.layouts), activeLayout = store.active }
    end,
    SaveLayouts = function(info)
        calls.save = calls.save + 1
        local kept = {}
        for _, l in ipairs(info.layouts) do
            assert(l.layoutType ~= Enum.EditModeLayoutType.Preset, "presets must not be saved")
            assert(type(l.layoutName) == "string" and #l.layoutName > 0)
            kept[#kept + 1] = CopyTable(l)
        end
        store.layouts = kept
        store.active = info.activeLayout
    end,
    SetActiveLayout = function(i)
        calls.setActive[#calls.setActive + 1] = i
        store.active = i
    end,
}

for _, f in ipairs({
    "Blizzard_EditMode/Camelot/EditModePresetLayoutConstants.lua",
    "Blizzard_EditMode/Mainline/EditModePresetLayouts.lua",
    "Blizzard_EditMode/Shared/EditModePresetLayoutSystemUtils.lua",
    "Blizzard_EditMode/Shared/EditModePresetLayoutsManager.lua",
    "Blizzard_EditMode/Shared/EditModeSettingDisplayInfo.lua",
}) do
    assert(loadfile(A .. f))()
end
assert(#EditModePresetLayoutManager:GetCopyOfPresetLayouts() == 3)

---------------------------------------------------------------------------
-- Game API stubs
---------------------------------------------------------------------------
local clock, wall = 1000, 1700000000
function GetTime() return clock end
function time() return wall end
function date() return "00:00:00 " end

local inCombat = false
function InCombatLockdown() return inCombat end

local style = Enum.InputDeviceInterfaceType.Mkb
InputUtil = { GetCurrentInterfaceStyle = function() return style end }

local editModeOpen = false
EditModeManagerFrame = { IsEditModeActive = function() return editModeOpen end }

local toggles = { true, false, false, false, false, false, false }
function GetActionBarToggles() return unpack(toggles, 1, 7) end
function SetActionBarToggles(...)
    for i = 1, 7 do
        toggles[i] = (select(i, ...)) and true or false
    end
end
C_GameRules = { IsMultiActionBarVisibilityForced = function() return false end }

local cvars = {
    statusText = "0", statusTextDisplay = "NONE", showTargetOfTarget = "0",
    cameraDistanceMaxZoomFactor = "1.9", countdownForCooldowns = "0", cooldownViewerEnabled = "0",
    damageMeterEnabled = "0", nameplateShowSelf = "0", combinedBags = "1", autoLootDefault = "0",
    enableMouseoverCast = "0", raidFramesDisplayClassColor = "0", raidFramesDisplayPowerBars = "0",
    raidFramesHealthText = "none", nameplateShowEnemies = "1", doNotFlashLowHealthWarning = "0",
}
local original = CopyTable(cvars)
C_CVar = {
    GetCVar = function(n) return cvars[n] end,
    SetCVar = function(n, v)
        assert(cvars[n] ~= nil, "unknown cvar " .. n)
        cvars[n] = tostring(v)
        return true
    end,
}

local reloads = 0
C_UI = { Reload = function() reloads = reloads + 1 end }

-- Frames: enough for the picker window.
local frames = {}
local function newFrame(ftype, name)
    local f = { _type = ftype, _scripts = {}, _events = {}, _shown = true, _text = "", _enabled = true }
    local methods = {
        RegisterEvent = function(self, e) self._events[e] = true end,
        UnregisterEvent = function(self, e) self._events[e] = nil end,
        SetScript = function(self, k, fn) self._scripts[k] = fn end,
        Show = function(self)
            local was = self._shown
            self._shown = true
            if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
        end,
        Hide = function(self)
            local was = self._shown
            self._shown = false
            if was and self._scripts.OnHide then self._scripts.OnHide(self) end
        end,
        IsShown = function(self) return self._shown end,
        SetText = function(self, t) self._text = t end,
        GetText = function(self) return self._text end,
        SetEnabled = function(self, e) self._enabled = e end,
        IsEnabled = function(self) return self._enabled end,
        SetChecked = function(self, c) self._checked = c end,
        GetChecked = function(self) return self._checked end,
        SetSize = function(self, w, h) self._w, self._h = w, h end,
        CreateTexture = function() return newFrame("Texture") end,
        CreateFontString = function() return newFrame("FontString") end,
        SetColorTexture = function(self, r, g, b, a) self._color = { r, g, b, a } end,
    }
    setmetatable(f, { __index = function(_, k) return methods[k] or function() end end })
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end
function CreateFrame(ftype, name) return newFrame(ftype, name) end
UIParent = newFrame("Frame")
UISpecialFrames = {}
SlashCmdList = {}
local function fire(event, ...)
    for i = 1, #frames do
        local f = frames[i]
        if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

---------------------------------------------------------------------------
-- Load the addon
---------------------------------------------------------------------------
local ns = {}
local files = {}
for line in io.lines(dir .. "/DialedInUI.toc") do
    if line:match("%.lua$") then files[#files + 1] = line end
end
for _, f in ipairs(files) do
    assert(loadfile(dir .. "/" .. f))("DialedInUI", ns)
end
fire("ADDON_LOADED", "DialedInUI")
fire("PLAYER_LOGIN")
assert(lastSaid():find("/dialed", 1, true))
local slash = assert(SlashCmdList.DIALEDINUI)
local db = DialedInUIDB

---------------------------------------------------------------------------
-- 1. Every preset builds cleanly against Blizzard's data
---------------------------------------------------------------------------
assert(#ns.Presets.list == 10, "expected 10 presets")
local seen = {}
for _, preset in ipairs(ns.Presets.list) do
    assert(not seen[preset.key], "duplicate key " .. preset.key)
    seen[preset.key] = true
    local layout, problems = ns.Layout.Build(preset)
    assert(layout, preset.key .. ": " .. tostring(problems and problems[1]))
    assert(#problems == 0, preset.key .. ": " .. table.concat(problems, "; "))
    assert(layout.layoutName == "DialedInUI" and layout.layoutType == Enum.EditModeLayoutType.Account)
    for name in pairs(preset.cvars) do
        assert(cvars[name] ~= nil, preset.key .. ": cvar not covered by the test: " .. name)
    end
end

---------------------------------------------------------------------------
-- 2. Stored values decode back to exactly what the preset asked for,
--    using Blizzard's own slider definitions.
---------------------------------------------------------------------------
local checked = 0
local displayMap = EditModeSettingDisplayInfoManager.displayInfoMap
for _, preset in ipairs(ns.Presets.list) do
    local layout = ns.Layout.Build(preset)
    for _, entry in ipairs(preset.place) do
        local sysName, indexName, at, set = entry[1], entry[2], entry[3], entry[4]
        local sys = Enum.EditModeSystem[sysName]
        local index = indexName and Enum["EditMode" .. sysName .. "SystemIndices"][indexName]
        local info
        for _, s in ipairs(layout.systems) do
            if s.system == sys and s.systemIndex == index then info = s end
        end
        assert(info)
        if at then
            assert(info.isInDefaultPosition == false and info.anchorInfo.relativeTo == "UIParent")
            assert(info.anchorInfo.offsetX == at.x and info.anchorInfo.offsetY == at.y)
        end
        local stored = {}
        for _, s in ipairs(info.settings) do stored[s.setting] = s.value end
        local settingEnum = Enum["EditMode" .. sysName .. "Setting"]
        for name, want in pairs(set or {}) do
            local codec = ns.Layout.CODEC[sysName][name]
            local where = preset.key .. " " .. sysName .. "." .. tostring(indexName) .. "." .. name
            if codec.kind == "composite" then
                local value = stored[settingEnum[codec.hundreds]] * 100 + stored[settingEnum[codec.ones]]
                assert(value == want, where)
                local d = displayMap[sys][Enum.EditModeChatFrameDisplayOnlySetting[name]]
                assert(want >= d.minValue and want <= d.maxValue, where .. " out of range")
            else
                local d = displayMap[sys] and displayMap[sys][settingEnum[name]]
                assert(d, where .. ": Blizzard has no display info for this setting")
                local v = stored[settingEnum[name]]
                if codec.kind == "pct" or codec.kind == "diff" or codec.kind == "raw" then
                    local shown = d:ConvertValueForDisplay(v)
                    assert(shown == want, ("%s: stored %s shows as %s, wanted %s"):format(where, tostring(v), tostring(shown), tostring(want)))
                elseif codec.kind == "bool" then
                    assert(d.type == Enum.EditModeSettingDisplayType.Checkbox, where .. " is not a checkbox")
                    assert(v == (want and 1 or 0), where)
                elseif codec.kind == "enum" then
                    assert(d.type == Enum.EditModeSettingDisplayType.Dropdown, where .. " is not a dropdown")
                    assert(v == Enum[codec.enum][want], where)
                    local found = false
                    for _, o in ipairs(d.options or {}) do
                        if o.value == v then found = true end
                    end
                    assert(found or not d.options, where .. ": not one of Blizzard's options")
                end
            end
            checked = checked + 1
        end
    end
end
assert(checked > 200, "checked only " .. checked)

---------------------------------------------------------------------------
-- 3. Apply, apply another, undo
---------------------------------------------------------------------------
local A_TYPE = Enum.EditModeLayoutType.Account
local C_TYPE = Enum.EditModeLayoutType.Character
local mine = CopyTable(EditModePresetLayoutManager:GetCopyOfPresetLayouts()[1])
mine.layoutType, mine.layoutName, mine.layoutIndex = A_TYPE, "My Layout", nil
store.layouts = { mine }
store.active = 4

assert(ns.Apply("center", true))
assert(#store.layouts == 2 and store.layouts[2].layoutName == "DialedInUI" and store.active == 5)
assert(calls.setActive[#calls.setActive] == 5)
assert(cvars.statusTextDisplay == "BOTH" and cvars.cooldownViewerEnabled == "1" and cvars.cameraDistanceMaxZoomFactor == "2")
assert(toggles[1] and toggles[2] and not toggles[3], "bars 2-3 on, 4 off")
assert(db.undo.layout.name == "My Layout" and db.undo.cvars.statusTextDisplay == "NONE")
assert(db.applied == "center" and db.notice:find("Center Stage", 1, true))

-- A second preset replaces the DialedInUI layout in place and keeps the original undo point.
assert(ns.Apply("healer", true))
assert(#store.layouts == 2 and store.layouts[2].layoutName == "DialedInUI" and store.active == 5)
assert(db.undo.layout.name == "My Layout")
assert(db.undo.cvars.statusTextDisplay == "NONE", "first remembered value must survive")
assert(db.undo.cvars.enableMouseoverCast == "0" and cvars.enableMouseoverCast == "1")

-- Undo removes the layout and puts settings and bars back.
slash("undo")
assert(reloads == 1)
assert(#store.layouts == 1 and store.layouts[1].layoutName == "My Layout" and store.active == 4)
for k, v in pairs(original) do
    assert(cvars[k] == v, "cvar not restored: " .. k)
end
assert(toggles[1] and not toggles[2] and not toggles[3] and not toggles[4])
assert(db.undo == nil and db.applied == nil and DialedInUICharDB.undoBars == nil)
slash("undo"); assert(lastSaid():find("nothing to undo", 1, true))

-- Layout only: no cvars change, but the layout still applies and undo still works.
assert(ns.Apply("clean", false))
assert(cvars.statusTextDisplay == "NONE" and store.layouts[2].layoutName == "DialedInUI")
assert(ns.Undo())
assert(store.active == 4 and #store.layouts == 1)

-- From a Blizzard preset, undo returns to that preset.
store.active = 2
assert(ns.Apply("pvp", true)); assert(store.active == 5)
assert(ns.Undo()); assert(store.active == 2 and #store.layouts == 1)

---------------------------------------------------------------------------
-- 4. Character layouts stay behind account layouts
---------------------------------------------------------------------------
local charLayout = CopyTable(mine)
charLayout.layoutType, charLayout.layoutName = C_TYPE, "Alt Layout"
store.layouts = { CopyTable(mine), charLayout }
store.active = 5
assert(ns.Apply("laptop", true))
assert(store.layouts[2].layoutName == "DialedInUI" and store.layouts[3].layoutName == "Alt Layout" and store.active == 5)
assert(ns.Undo())
assert(#store.layouts == 2 and store.layouts[2].layoutName == "Alt Layout" and store.active == 5)

---------------------------------------------------------------------------
-- 5. Things that must refuse
---------------------------------------------------------------------------
local before = calls.save
store.layouts = {}
for i = 1, 5 do
    local l = CopyTable(mine); l.layoutName = "Full " .. i; store.layouts[i] = l
end
store.active = 1
assert(not ns.Apply("center", true) and lastSaid():find("5 account layouts", 1, true))
assert(calls.save == before, "must not save when full")
store.layouts = { CopyTable(mine) }; store.active = 4
db.undo = nil; DialedInUICharDB.undoBars = nil

inCombat = true
assert(not ns.Apply("center", true) and lastSaid():find("combat", 1, true))
inCombat = false
editModeOpen = true
assert(not ns.Apply("center", true) and lastSaid():find("Edit Mode", 1, true))
editModeOpen = false
assert(not ns.Apply("controller", true) and lastSaid():find("gamepad", 1, true))
style = Enum.InputDeviceInterfaceType.Gamepad
assert(not ns.Apply("center", true) and lastSaid():find("mouse and keyboard", 1, true))
assert(ns.Apply("controller", true))
assert(store.layouts[2].interfaceStyle == Enum.InputDeviceInterfaceType.Gamepad)
assert(ns.Undo())
style = Enum.InputDeviceInterfaceType.Mkb
assert(not ns.Apply("nope", true) and lastSaid():find("no layout called", 1, true))

---------------------------------------------------------------------------
-- 6. Picker window
---------------------------------------------------------------------------
slash("")
assert(DialedInUIFrame and DialedInUIFrame:IsShown())
local buttons, apply, undo = {}, nil, nil
for _, f in ipairs(frames) do
    if f._type == "Button" and rawget(f, "key") then buttons[#buttons + 1] = f end
    if f._type == "Button" and f._text == "Apply" then apply = f end
    if f._type == "Button" and f._text == "Undo" then undo = f end
end
assert(#buttons == 10 and apply and undo)
for _, b in ipairs(buttons) do
    b._scripts.OnClick(b)
    assert(ns.Picker.Selected() == b.key)
end
buttons[1]._scripts.OnClick(buttons[1])
local r0 = reloads
apply._scripts.OnClick(apply)
assert(apply._text ~= "Apply" and reloads == r0, "first click only arms")
clock = clock + 10; DialedInUIFrame._scripts.OnUpdate(DialedInUIFrame)
assert(apply._text == "Apply", "confirm times out")
apply._scripts.OnClick(apply); apply._scripts.OnClick(apply)
assert(reloads == r0 + 1 and db.applied == "center")
undo._scripts.OnClick(undo); undo._scripts.OnClick(undo)
assert(reloads == r0 + 2 and db.applied == nil)
DialedInUIFrame:Hide()

slash("list"); slash("status"); slash("check"); assert(lastSaid():find("build cleanly", 1, true))
slash("debug on"); assert(ns.Apply("mirror", true)); assert(#db.log > 0); assert(ns.Undo()); slash("debug off")
slash("help")

---------------------------------------------------------------------------
-- 7. Preview geometry: on screen, and report overlaps between key frames
---------------------------------------------------------------------------
local KEY = { unit = true, group = true, cast = true, chat = true, map = true, bars = true, meter = true, cooldown = true, minor = true }
local overlaps, reach = {}, {}
local dump = { "return {" }
-- 16:9, 16:10 and a 14 inch MacBook, all at the default UI scale.
local WIDTHS = { 1366, 1229, 1182 }
-- An optional fourth argument picks which width goes into the rects file.
local dumpWidth = tonumber(arg[4]) or 1366
local function check(preset, width, writeDump)
    local layout = ns.Layout.Build(preset)
    local saved = preset.screen
    preset.screen = saved or width
    local rects, W, H = ns.Preview.Rects(preset, layout)
    preset.screen = saved
    assert(#rects > 5, preset.key .. ": preview is nearly empty")
    if writeDump then
        dump[#dump + 1] = ("{ key=%q, name=%q, w=%d, h=%d, rects={"):format(preset.key, preset.name, W, H)
    end
    for _, r in ipairs(rects) do
        local onScreen = r.x >= -2 and r.y >= -2 and r.x + r.w <= W + 2 and r.y + r.h <= H + 2
        local msg = ("%s at %d: %s %s off screen (%d,%d %dx%d)"):format(preset.key, W, r.kind, tostring(r.label), r.x, r.y, r.w, r.h)
        if W >= 1366 then
            assert(onScreen, msg)
        elseif not onScreen then
            overlaps[#overlaps + 1] = msg
        end
        if writeDump then
            dump[#dump + 1] = ("  {x=%.1f,y=%.1f,w=%.1f,h=%.1f,kind=%q,label=%q},"):format(r.x, r.y, r.w, r.h, r.kind, r.label or "")
        end
    end
    if writeDump then
        dump[#dump + 1] = "}},"
    end
    for i = 1, #rects do
        for j = i + 1, #rects do
            local a, b = rects[i], rects[j]
            local mapPair = (a.kind == "map" and b.kind == "info") or (a.kind == "info" and b.kind == "map")
            -- The quest tracker and buffs are drawn at a typical size, not their
            -- largest, but even that size should stay clear of real frames.
            local grows = function(r) return r.label == "Quests" or r.label == "Buffs" end
            local growPair = (grows(a) and (KEY[b.kind] or grows(b))) or (grows(b) and KEY[a.kind])
            if mapPair or growPair or (KEY[a.kind] and KEY[b.kind] and not (a.kind == "minor" and b.kind == "minor")) then
                local ox = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
                local oy = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
                if ox > 1 and oy > 1 then
                    local msg = ("%s at %d: %s %s overlaps %s %s by %dx%d"):format(preset.key, W,
                        a.kind, a.label or "", b.kind, b.label or "", ox, oy)
                    -- A quest tracker that grows into a frame on a narrow screen is
                    -- reported, not failed: Blizzard's own layouts do the same and
                    -- the README says so. Laptop exists for narrow screens, so it
                    -- has to stay clear everywhere.
                    if growPair and not mapPair and W < 1366 and preset.key ~= "laptop" then
                        reach[#reach + 1] = msg
                    else
                        overlaps[#overlaps + 1] = msg
                    end
                end
            end
        end
    end
end
for _, preset in ipairs(ns.Presets.list) do
    for _, width in ipairs(preset.screen and { preset.screen } or WIDTHS) do
        check(preset, width, preset.screen ~= nil or width == dumpWidth)
    end
end
-- Again with every action bar turned on, as for a player who already uses all
-- eight: the spare rows a layout parks at the top must not land on anything.
for _, preset in ipairs(ns.Presets.list) do
    preset.showAllBars = true
    for _, width in ipairs(preset.screen and { preset.screen } or WIDTHS) do
        check(preset, width, false)
    end
    preset.showAllBars = nil
end
dump[#dump + 1] = "}"
if rectsOut then
    local f = assert(io.open(rectsOut, "w"))
    f:write(table.concat(dump, "\n"))
    f:close()
end

for _, l in ipairs(out) do realprint(l) end
for _, o in ipairs(reach) do realprint("TRACKER REACH " .. o) end
for _, o in ipairs(overlaps) do realprint("OVERLAP " .. o) end
assert(#overlaps == 0, #overlaps .. " frames overlap")
realprint(("checked %d settings against Blizzard's definitions"):format(checked))
realprint("DIALEDINUI HARNESS OK")
