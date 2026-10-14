-- Luacheck settings for a World of Warcraft addon.
std = "lua51"
max_line_length = 140
self = false

-- Values the game client provides.
read_globals = {
    "CreateFrame", "UIParent", "UISpecialFrames", "EditModeManagerFrame",
    "InCombatLockdown", "GetTime", "ReloadUI", "GetCVar", "SetCVar",
    "GetActionBarToggles", "SetActionBarToggles",
    "C_CVar", "C_EditMode", "C_GameRules", "C_UI",
    "Constants", "Enum", "InputUtil",
    "date", "time",
}
-- Values the addon defines for the client to read.
globals = {
    "DialedInUIDB", "DialedInUICharDB", "DialedInUI_OnAddonCompartmentClick",
    "SlashCmdList", "SLASH_DIALEDINUI1", "SLASH_DIALEDINUI2",
}
-- Each layout entry and description reads better on one line than wrapped.
files["Presets.lua"] = { max_line_length = false }
files["tests/harness.lua"] = { ignore = { "." } }
