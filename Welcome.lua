local _, KC = ...
local Theme = KC.Theme

--------------------------------------------------------------------------------
-- Welcome: on the very first start, pick how the sidebar looks, with a small
-- preview of each: symbols (slim, names on hover) or names. /kc welcome shows
-- it again any time.
--------------------------------------------------------------------------------

local Welcome = {}
KC.Welcome = Welcome

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WIDTH, HEIGHT = 470, 300
local CARD_W, CARD_H = 205, 180

-- A few sample lines, the same in both previews.
local SAMPLE = {
    { "Thalianne", "pull carefully", { 0.67, 0.67, 1 } },
    { "Pip", "anyone near?", { 1, 1, 1 } },
    { "Elunara", "omw!", { 1, 0.5, 1 } },
    { "Brontor", "inv pls", { 0.67, 0.67, 1 } },
}

-- The streams shown in the previews: All messages, Party, Say, Trade.
local STREAMS = {
    { label = "All messages", s = nil },
    { label = "Party", s = { key = "party" } },
    { label = "Say", s = { key = "say" } },
    { label = "Trade", s = { sec = "channels", label = "Trade" } },
}

local function sampleLines(card, D, left)
    for i, line in ipairs(SAMPLE) do
        local fs = D.Text(card, 10)
        fs:SetPoint("TOPLEFT", left, -12 - (i - 1) * 18)
        fs:SetPoint("RIGHT", card, "RIGHT", -6, 0)
        local c = line[3]
        fs:SetText(KC.Colorize(line[1], 1, 1, 1) .. KC.Colorize(": " .. line[2], c[1], c[2], c[3]))
    end
end

local function makeCard(parent, D, kind)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(CARD_W, CARD_H)
    D.Solid(card, "BACKGROUND", { 0, 0, 0 }, 0.45):SetAllPoints()
    card.edge = D.Solid(card, "BORDER", Theme.accent, 0.25)
    card.edge:SetPoint("TOPLEFT", -1, 1)
    card.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    card.hl = D.Solid(card, "ARTWORK", Theme.hover)
    card.hl:SetAllPoints()
    card.hl:Hide()

    -- the sidebar of the preview
    local sideW = kind == "symbols" and 34 or 86
    local side = D.Solid(card, "BACKGROUND", { 1, 1, 1 }, 0.04)
    side:SetPoint("TOPLEFT")
    side:SetPoint("BOTTOMLEFT", 0, 40)
    side:SetWidth(sideW)
    for i, st in ipairs(STREAMS) do
        if kind == "symbols" then
            local icon = card:CreateTexture(nil, "ARTWORK")
            icon:SetSize(22, 22)
            icon:SetPoint("TOPLEFT", 6, -8 - (i - 1) * 28)
            KC.UI.SetSymbol(icon, st.s)
        else
            local fs = D.Text(card, 10, i == 1 and Theme.text or Theme.text)
            fs:SetPoint("TOPLEFT", 8, -12 - (i - 1) * 22)
            fs:SetText(st.label)
        end
    end
    sampleLines(card, D, sideW + 8)

    card.title = D.Text(card, 13, Theme.accent, "CENTER")
    card.title:SetPoint("BOTTOM", 0, 22)
    card.title:SetText(kind == "symbols" and "Symbols" or "Names")
    card.sub = D.Text(card, 10, Theme.dim, "CENTER")
    card.sub:SetPoint("BOTTOM", 0, 8)
    card.sub:SetText(kind == "symbols" and "slim, names on hover" or "every stream spelled out")

    card:SetScript("OnEnter", function(self)
        self.hl:Show()
        self.edge:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.9)
    end)
    card:SetScript("OnLeave", function(self)
        self.hl:Hide()
        self.edge:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.25)
    end)
    card:SetScript("OnClick", function() Welcome:Choose(kind) end)
    return card
end

function Welcome:Create()
    if self.frame then return end
    local UI = KC.UI
    local D = UI.Draw
    local f = CreateFrame("Frame", "KrakenChatWelcome", UIParent)
    f:Hide()
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if UISpecialFrames then table.insert(UISpecialFrames, "KrakenChatWelcome") end
    self.frame = f

    if KC:Look().palette == "wow" then UI:CreateWoWFrame(f) else UI:CreateFlatFrame(f) end

    local title = D.Text(f, 16, Theme.accent)
    title:SetPoint("TOPLEFT", 14, -9)
    if not pcall(title.SetFont, title, "Fonts\\MORPHEUS.TTF", 17, "") then title:SetFont(FONT, 15, "") end
    title:SetText("Welcome to KrakenChat")

    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -8)
    D.Strokes(close, 11, Theme.dim, { 45, -45 })
    close:SetScript("OnClick", function() f:Hide() end)

    local ask = D.Text(f, 12, Theme.text, "CENTER")
    ask:SetPoint("TOP", 0, -46)
    ask:SetText("How should your streams look in the sidebar?")

    self.symbols = makeCard(f, D, "symbols")
    self.symbols:SetPoint("TOPLEFT", 20, -72)
    self.names = makeCard(f, D, "text")
    self.names:SetPoint("TOPRIGHT", -20, -72)

    local note = D.Text(f, 10, Theme.dim, "CENTER")
    note:SetPoint("BOTTOM", 0, 14)
    note:SetText("You can switch any time in the settings (the gear in the header).")
end

function Welcome:Show()
    self:Create()
    self.frame:Show()
end

function Welcome:Choose(kind)
    local settings = KC.db.settings
    settings.sidebar = kind == "symbols" and "symbols" or "text"
    local UI = KC.UI
    UI:Create()
    UI:ApplyChat()
    UI:RenderSidebar()
    UI:RenderFeed()
    self.frame:Hide()
    KC:Print(kind == "symbols" and "Symbols it is: point at one to see its name."
        or "Names it is.")
end

KC:Listen("LOGIN", function()
    if KC.firstRun then Welcome:Show() end
end)
