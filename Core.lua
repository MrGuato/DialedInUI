-- DialedInUI: one-click layouts for Blizzard's own UI.
--
-- A layout is saved as a normal Edit Mode layout called "DialedInUI", so after
-- applying one you can open Edit Mode and keep adjusting it like any other.
-- Before the first change the addon writes down where you were (your active
-- layout, and any setting it is about to change), and Undo puts all of it
-- back.

local ADDON, ns = ...

local PREFIX = "|cff4fc3f7DialedInUI|r: "
local LOG_MAX = 200

local DEFAULTS = { gameSettings = true, debug = false }

local db, char

local function say(msg)
    print(PREFIX .. tostring(msg))
end
ns.Say = say

local function log(fmt, ...)
    if not (db and db.debug) then
        return
    end
    local ok, msg = pcall(string.format, fmt, ...)
    local list = db.log
    list[#list + 1] = date("%H:%M:%S ") .. (ok and msg or fmt)
    if #list > LOG_MAX then
        table.remove(list, 1)
    end
end
ns.Log = log

function ns.DB()
    return db
end

function ns.Reload()
    if C_UI and C_UI.Reload then
        C_UI.Reload()
    else
        ReloadUI()
    end
end

local function currentStyle()
    if InputUtil and InputUtil.GetCurrentInterfaceStyle then
        return InputUtil.GetCurrentInterfaceStyle()
    end
    return Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Mkb or 0
end

-- Whether a layout can be applied right now, and if not, why.
function ns.CanApply(preset)
    if InCombatLockdown() then
        return false, "Layouts can't be changed in combat."
    end
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
        return false, "Close Edit Mode first."
    end
    if not (C_EditMode and C_EditMode.SaveLayouts and C_EditMode.GetLayouts) then
        return false, "Edit Mode is not available."
    end
    if preset then
        local gamepad = Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Gamepad
        local onGamepad = gamepad ~= nil and currentStyle() == gamepad
        if preset.needsGamepad and not onGamepad then
            return false, "Turn on the gamepad UI first (Options, Controls, Gamepad)."
        elseif not preset.needsGamepad and onGamepad then
            return false, "This layout is for mouse and keyboard. Turn the gamepad UI off first."
        end
    end
    return true
end

-- Applies a preset. Returns true when the UI should be reloaded.
function ns.Apply(key, withSettings)
    local preset = ns.Presets.Get(key)
    if not preset then
        say("no layout called " .. tostring(key) .. ". Type /dialed list.")
        return false
    end
    local ok, why = ns.CanApply(preset)
    if not ok then
        say(why)
        return false
    end

    local layout, problems = ns.Layout.Build(preset)
    if not layout then
        say(problems[1])
        return false
    end
    for _, p in ipairs(problems) do
        log("%s: %s", key, p)
    end

    if not db.undo then
        local snapshot = ns.Layout.Snapshot()
        if ns.Layout.ActiveIsOwned() then
            snapshot = { preset = 1 }
        end
        db.undo = { layout = snapshot, at = time() }
    end
    if char.undoBars == nil and GetActionBarToggles then
        char.undoBars = { GetActionBarToggles() }
    end
    if withSettings then
        ns.Tweaks.Remember(preset, db.undo)
    end

    local index, err = ns.Layout.Save(layout)
    if not index then
        say(err)
        return false
    end
    log("%s saved as layout %d", key, index)

    ns.Tweaks.ApplyBars(preset)
    if withSettings then
        local changed, skipped = ns.Tweaks.Apply(preset)
        log("%s: %d setting(s) changed, skipped: %s", key, changed, table.concat(skipped, ", "))
    end

    db.applied = key
    db.notice = ("%s applied. Open Edit Mode to fine tune it, or type /dialed undo to go back."):format(preset.name)
    return true
end

-- Puts everything back the way it was before the first layout was applied.
function ns.Undo()
    local ok, why = ns.CanApply()
    if not ok then
        say(why)
        return false
    end
    if not db.undo then
        say("nothing to undo.")
        return false
    end
    ns.Layout.Restore(db.undo.layout)
    ns.Tweaks.Restore(db.undo, char)
    db.undo = nil
    db.applied = nil
    db.notice = "your previous layout and settings are back."
    return true
end

function ns.HasUndo()
    return db and db.undo ~= nil
end

function ns.Applied()
    return db and db.applied
end

-- Builds every preset against the running client and reports anything that
-- did not map, without saving anything.
local function check()
    local bad = 0
    for _, preset in ipairs(ns.Presets.list) do
        local layout, problems = ns.Layout.Build(preset)
        if not layout or #problems > 0 then
            bad = bad + 1
            say(preset.name .. ":")
            for _, p in ipairs(problems) do
                say("  " .. p)
            end
        end
    end
    if bad == 0 then
        say(("all %d layouts build cleanly on this client."):format(#ns.Presets.list))
    end
end

local function onSlash(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    rest = rest and rest:lower() or ""

    if cmd == "" or cmd == "show" then
        ns.Picker.Toggle()
    elseif cmd == "list" then
        for _, preset in ipairs(ns.Presets.list) do
            say(("%s  (%s) %s"):format(preset.name, preset.key, preset.bestFor))
        end
    elseif cmd == "apply" then
        local key, flag = rest:match("^(%S+)%s*(%S*)$")
        if ns.Apply(key, flag ~= "layoutonly") then
            ns.Reload()
        end
    elseif cmd == "undo" then
        if ns.Undo() then
            ns.Reload()
        end
    elseif cmd == "status" then
        local preset = db.applied and ns.Presets.Get(db.applied)
        say(preset and ("using " .. preset.name .. ".") or "no DialedInUI layout applied.")
        say(db.undo and "undo is available." or "nothing to undo.")
    elseif cmd == "check" then
        check()
    elseif cmd == "debug" then
        if rest == "on" or rest == "off" then
            db.debug = (rest == "on")
        end
        say("debug log is " .. (db.debug and "on" or "off") .. ".")
    else
        say("/dialed  open the layout picker")
        say("/dialed list  all layouts")
        say("/dialed apply <name>  apply one, add layoutonly to skip game settings")
        say("/dialed undo  go back to how things were")
        say("/dialed status, /dialed check, /dialed debug on|off")
    end
end

local function initDB()
    if type(DialedInUIDB) ~= "table" then
        DialedInUIDB = {}
    end
    db = DialedInUIDB
    db.version = 1
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end
    db.log = db.log or {}

    if type(DialedInUICharDB) ~= "table" then
        DialedInUICharDB = {}
    end
    char = DialedInUICharDB
end

-- Called by the addon compartment button next to the minimap.
function DialedInUI_OnAddonCompartmentClick()
    ns.Picker.Toggle()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then
            return
        end
        self:UnregisterEvent("ADDON_LOADED")
        initDB()
        self:RegisterEvent("PLAYER_LOGIN")
        SLASH_DIALEDINUI1 = "/dialed"
        SLASH_DIALEDINUI2 = "/dialedinui"
        SlashCmdList["DIALEDINUI"] = onSlash
    elseif event == "PLAYER_LOGIN" then
        if db.notice then
            say(db.notice)
            db.notice = nil
        elseif not db.welcomed then
            say("type /dialed to pick a layout.")
        end
        db.welcomed = true
    end
end)
