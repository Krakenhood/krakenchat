local _, KC = ...
local Theme = KC.Theme

--------------------------------------------------------------------------------
-- The settings window (/kc settings, the gear in the header, or right-click
-- the minimap button): tick boxes for the choices that are a matter of taste.
--------------------------------------------------------------------------------

local Options = {}
KC.Options = Options

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WIDTH = 330
local ROW = 24

local function settings() return KC.db.settings end

local function refreshAll()
    local UI = KC.UI
    if not UI.frame then return end
    UI:ApplyChat()
    UI:RenderSidebar()
    UI:RenderFeed()
end

-- Each entry: a tick box (get/set) or a header.
local ENTRIES = {
    { header = "Behaviour" },
    {
        label = "Open the chat when someone whispers you",
        get = function() return settings().openOnWhisper end,
        set = function(v) settings().openOnWhisper = v end,
    },
    {
        label = "Count new lines in Say, Yell and channels",
        get = function() return settings().quietCounts end,
        set = function(v)
            settings().quietCounts = v
            if not v then
                for _, s in pairs(KC.char.streams) do
                    local sec = KC:SectionOf(s)
                    if sec and sec.quiet then s.unread = 0 end
                end
                KC:Fire("UNREAD")
            end
        end,
    },
    {
        label = "Hide the game's own chat window",
        get = function() return settings().hideBlizzard end,
        set = function(v)
            settings().hideBlizzard = v
            KC.Blizzard:Apply()
        end,
    },
    { header = "Look" },
    {
        label = "Symbols instead of names in the sidebar",
        get = function() return settings().sidebar ~= "text" end,
        set = function(v)
            settings().sidebar = v and "symbols" or "text" -- square by default, like the game's icons
            refreshAll()
        end,
    },
    {
        label = "Round symbols",
        get = function() return settings().sidebar == "round" end,
        set = function(v)
            settings().sidebar = v and "round" or "symbols"
            refreshAll()
        end,
        enabled = function() return settings().sidebar ~= "text" end,
    },
    {
        label = "Timestamps",
        get = function() return settings().timestamps end,
        set = function(v)
            settings().timestamps = v
            KC:Fire("LAYOUT")
        end,
    },
    {
        label = "Minimap button",
        get = function() return not settings().minimap.hide end,
        set = function(v)
            settings().minimap.hide = not v
            KC:Fire("SETTINGS")
        end,
    },
    {
        stepper = true, label = "Text size",
        value = function() return tostring(settings().fontSize or 12) end,
        step = function(delta)
            settings().fontSize = math.max(10, math.min(18, (settings().fontSize or 12) + delta))
            KC:Fire("LAYOUT")
        end,
    },
    {
        -- shown as transparency (0% solid, + more see-through); stored as opacity
        stepper = true, label = "Background transparency",
        value = function() return math.floor((1 - (settings().bgAlpha or 1)) * 100 + 0.5) .. "%" end,
        step = function(delta)
            local a = math.floor((settings().bgAlpha or 1) * 10 + 0.5) - delta
            settings().bgAlpha = math.max(2, math.min(10, a)) / 10
            KC.UI:ApplyAlpha()
        end,
    },
}

local function makeCheck(parent, D)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(ROW)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(14, 14)
    b.box:SetPoint("LEFT", 0, 0)
    D.Solid(b.box, "BACKGROUND", { 0, 0, 0 }, 0.5):SetAllPoints()
    D.Border(b.box, Theme.accent, 0.7)
    b.tick = D.Strokes(b.box, 9, Theme.accent, { -45, 45 })
    -- a check mark: a short stroke and a long one
    b.tick[1]:ClearAllPoints()
    b.tick[1]:SetSize(5, 2)
    b.tick[1]:SetPoint("CENTER", b.box, "CENTER", -2.5, -1)
    b.tick[2]:ClearAllPoints()
    b.tick[2]:SetSize(9, 2)
    b.tick[2]:SetPoint("CENTER", b.box, "CENTER", 1.5, 0.5)
    b.label = D.Text(b, 12)
    b.label:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
    b.label:SetPoint("RIGHT", 0, 0)
    b:SetScript("OnClick", function(self)
        if self.entry.enabled and not self.entry.enabled() then return end
        self.entry.set(not self.entry.get())
        Options:Refresh()
    end)
    return b
end

-- A row with - and + around a value (text size, opacity).
local function makeStepper(parent, D, e)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW)
    row.entry = e
    row.label = D.Text(row, 12)
    row.label:SetPoint("LEFT", 22, 0)
    row.label:SetText(e.label)
    local function step(delta)
        local b = CreateFrame("Button", nil, row)
        b:SetSize(18, 18)
        D.Solid(b, "BACKGROUND", { 0, 0, 0 }, 0.5):SetAllPoints()
        D.Border(b, Theme.accent, 0.5)
        local t = D.Text(b, 13, Theme.accent, "CENTER")
        t:SetPoint("CENTER", 0, 1)
        t:SetText(delta > 0 and "+" or "-")
        b:SetScript("OnClick", function()
            e.step(delta)
            Options:Refresh()
        end)
        return b
    end
    -- - value +, lined up on the right edge whatever the label's length
    row.plus = step(1)
    row.plus:SetPoint("RIGHT", 0, 0)
    row.value = D.Text(row, 12, nil, "CENTER")
    row.value:SetPoint("RIGHT", row.plus, "LEFT", -2, 0)
    row.value:SetWidth(40)
    row.minus = step(-1)
    row.minus:SetPoint("RIGHT", row.value, "LEFT", -2, 0)
    return row
end

function Options:Create()
    if self.frame then return end
    local UI = KC.UI
    local D = UI.Draw
    local f = CreateFrame("Frame", "KrakenChatOptionsFrame", UIParent)
    f:Hide()
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetPoint("CENTER", 0, 80)
    if UISpecialFrames then table.insert(UISpecialFrames, "KrakenChatOptionsFrame") end
    self.frame = f

    if KC:Look().palette == "wow" then UI:CreateWoWFrame(f) else UI:CreateFlatFrame(f) end

    local wow = KC:Look().palette == "wow"
    local title = D.Text(f, wow and 15 or 13, wow and Theme.accent or nil)
    title:SetPoint("TOPLEFT", 12, -10)
    if wow then pcall(title.SetFont, title, "Fonts\\MORPHEUS.TTF", 15, "") end
    title:SetText("Settings")

    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -8)
    D.Strokes(close, 11, Theme.dim, { 45, -45 })
    close:SetScript("OnClick", function() f:Hide() end)

    self.rows = {}
    local y = 44
    for _, e in ipairs(ENTRIES) do
        local w
        if e.header then
            w = CreateFrame("Frame", nil, f)
            w:SetHeight(22)
            w.label = D.Text(w, 10, Theme.accent)
            w.label:SetPoint("BOTTOMLEFT", 0, 4)
            w.label:SetText(e.header:upper())
            local line = D.Solid(w, "ARTWORK", Theme.line)
            line:SetHeight(1)
            line:SetPoint("LEFT", w.label, "RIGHT", 8, 0)
            line:SetPoint("RIGHT", 0, 0)
        elseif e.stepper then
            w = makeStepper(f, D, e)
            self.steppers = self.steppers or {}
            self.steppers[#self.steppers + 1] = w
        else
            w = makeCheck(f, D)
            w.entry = e
            w.label:SetText(e.label)
            self.rows[#self.rows + 1] = w
        end
        w:SetPoint("TOPLEFT", 16, -y)
        w:SetPoint("RIGHT", f, "RIGHT", -16, 0)
        y = y + (e.header and 22 or ROW)
    end
    f:SetSize(WIDTH, y + 16)
end

function Options:Refresh()
    if not self.frame then return end
    for _, row in ipairs(self.rows) do
        local e = row.entry
        local on = e.get() and true or false
        for _, s in ipairs(row.tick) do s:SetShown(on) end
        local enabled = not e.enabled or e.enabled()
        row.label:SetTextColor(KC.UI.Draw.rgb(enabled and Theme.text or Theme.dim))
        row:SetAlpha(enabled and 1 or 0.5)
    end
    for _, row in ipairs(self.steppers or {}) do row.value:SetText(row.entry.value()) end
end

function Options:Toggle()
    self:Create()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Refresh()
        self.frame:Show()
    end
end
