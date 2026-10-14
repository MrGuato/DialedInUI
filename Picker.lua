-- The layout picker window: a list of layouts on the left, a sketch of the
-- selected one on the right, and Apply / Undo underneath.

local ADDON, ns = ...

local Picker = {}
ns.Picker = Picker

local WIDTH, HEIGHT = 680, 520
local LIST_W = 180
local PREVIEW_W, PREVIEW_H = 448, 252
local CONFIRM_SECONDS = 4

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local frame, preview, nameText, bestText, aboutText, changesText, statusText
local applyButton, undoButton, settingsCheck
local listButtons = {}
local rectPool, labelPool = {}, {}
local selected
local armed -- "apply" or "undo" while waiting for the second click
local armedAt = 0

local function disarm()
    armed = nil
    if applyButton then
        applyButton:SetText("Apply")
        undoButton:SetText("Undo")
    end
end

local function texture(i)
    local t = rectPool[i]
    if not t then
        t = preview:CreateTexture(nil, "ARTWORK")
        rectPool[i] = t
    end
    return t
end

local function label(i)
    local f = labelPool[i]
    if not f then
        f = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        labelPool[i] = f
    end
    return f
end

local function drawPreview(preset)
    for _, t in ipairs(rectPool) do
        t:Hide()
    end
    for _, f in ipairs(labelPool) do
        f:Hide()
    end
    local layout = ns.Layout.Build(preset)
    if not layout then
        return
    end
    local rects, screenW, screenH = ns.Preview.Rects(preset, layout)
    local scale = math.min(PREVIEW_W / screenW, PREVIEW_H / screenH)
    local offX = (PREVIEW_W - screenW * scale) / 2
    local offY = (PREVIEW_H - screenH * scale) / 2

    local screen = texture(1)
    screen:SetColorTexture(0.10, 0.11, 0.13, 1)
    screen:ClearAllPoints()
    screen:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", offX, offY)
    screen:SetSize(screenW * scale, screenH * scale)
    screen:Show()

    local labels = 0
    for i, r in ipairs(rects) do
        local t = texture(i + 1)
        local c = ns.Preview.COLORS[r.kind] or ns.Preview.COLORS.info
        t:SetColorTexture(c[1], c[2], c[3], 0.85)
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", offX + r.x * scale, offY + r.y * scale)
        t:SetSize(math.max(r.w * scale, 1), math.max(r.h * scale, 1))
        t:Show()
        if r.label and r.w * scale > 28 and r.h * scale > 9 then
            labels = labels + 1
            local f = label(labels)
            f:SetText(r.label)
            f:ClearAllPoints()
            f:SetPoint("CENTER", t, "CENTER")
            f:Show()
        end
    end
end

local function refreshButtons()
    local preset = selected and ns.Presets.Get(selected)
    local canApply = preset and ns.CanApply(preset)
    applyButton:SetEnabled(canApply and true or false)
    undoButton:SetEnabled(ns.HasUndo())

    local applied = ns.Applied()
    local current = applied and ns.Presets.Get(applied)
    if current then
        statusText:SetText("Using: " .. current.name)
    elseif ns.HasUndo() then
        statusText:SetText("")
    else
        statusText:SetText("Using your own layout")
    end
end

local function choose(key)
    selected = key
    disarm()
    local preset = ns.Presets.Get(key)
    for _, b in ipairs(listButtons) do
        if b.key == key then
            b:LockHighlight()
        else
            b:UnlockHighlight()
        end
    end
    nameText:SetText(preset.name)
    bestText:SetText(preset.bestFor)
    aboutText:SetText(preset.about)

    local lines = ns.Tweaks.Describe(preset)
    if #lines > 0 then
        changesText:SetText("Game settings: " .. table.concat(lines, ", ") .. ".")
    else
        changesText:SetText("")
    end
    local ok, why = ns.CanApply(preset)
    if not ok then
        changesText:SetText("|cffff8040" .. why .. "|r\n" .. changesText:GetText())
    end
    drawPreview(preset)
    refreshButtons()
end

local function onApply()
    if not selected then
        return
    end
    if armed ~= "apply" then
        disarm()
        armed = "apply"
        armedAt = GetTime()
        applyButton:SetText("Click to confirm")
        return
    end
    disarm()
    if ns.Apply(selected, settingsCheck:GetChecked()) then
        ns.Reload()
    end
end

local function onUndo()
    if armed ~= "undo" then
        disarm()
        armed = "undo"
        armedAt = GetTime()
        undoButton:SetText("Confirm")
        return
    end
    disarm()
    if ns.Undo() then
        ns.Reload()
    end
end

local function build()
    frame = CreateFrame("Frame", "DialedInUIFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", 0, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0, 0, 0, 0.94)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("DialedInUI")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)
    subtitle:SetText("One-click layouts for Blizzard's own UI")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    for i, preset in ipairs(ns.Presets.list) do
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(LIST_W - 10, 26)
        b:SetPoint("TOPLEFT", 12, -44 - (i - 1) * 30)
        b:SetText(preset.name)
        b.key = preset.key
        b:SetScript("OnClick", function()
            choose(preset.key)
        end)
        listButtons[#listButtons + 1] = b
    end

    preview = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    preview:SetSize(PREVIEW_W, PREVIEW_H)
    preview:SetPoint("TOPLEFT", LIST_W + 18, -44)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPRIGHT", preview, "BOTTOMRIGHT", 0, -2)
    hint:SetText("Sketch, sizes are approximate")

    nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -18)

    bestText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bestText:SetPoint("LEFT", nameText, "RIGHT", 10, -1)

    aboutText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    aboutText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -8)
    aboutText:SetWidth(PREVIEW_W)
    aboutText:SetJustifyH("LEFT")
    aboutText:SetJustifyV("TOP")

    changesText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    changesText:SetPoint("TOPLEFT", aboutText, "BOTTOMLEFT", 0, -8)
    changesText:SetWidth(PREVIEW_W)
    changesText:SetJustifyH("LEFT")
    changesText:SetJustifyV("TOP")

    settingsCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    settingsCheck:SetSize(24, 24)
    settingsCheck:SetPoint("BOTTOMLEFT", LIST_W + 14, 12)
    settingsCheck:SetChecked(ns.DB().gameSettings)
    settingsCheck:SetScript("OnClick", function(self)
        ns.DB().gameSettings = self:GetChecked() and true or false
    end)
    local checkLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    checkLabel:SetPoint("LEFT", settingsCheck, "RIGHT", 2, 0)
    checkLabel:SetText("Also change game settings")

    applyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyButton:SetSize(130, 24)
    applyButton:SetPoint("BOTTOMRIGHT", -14, 14)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", onApply)

    undoButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    undoButton:SetSize(90, 24)
    undoButton:SetPoint("RIGHT", applyButton, "LEFT", -8, 0)
    undoButton:SetText("Undo")
    undoButton:SetScript("OnClick", onUndo)

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", 14, 20)

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMRIGHT", applyButton, "TOPRIGHT", 0, 6)
    note:SetText("Applying reloads your UI.")

    frame:SetScript("OnUpdate", function()
        if armed and GetTime() - armedAt > CONFIRM_SECONDS then
            disarm()
        end
    end)
    frame:SetScript("OnHide", disarm)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "DialedInUIFrame")
    end
end

function Picker.Show()
    if not frame then
        build()
    end
    frame:Show()
    choose(selected or ns.Applied() or ns.Presets.list[1].key)
end

function Picker.Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        Picker.Show()
    end
end

function Picker.Selected()
    return selected
end
