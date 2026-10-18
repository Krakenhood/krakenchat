local _, KC = ...
local Theme = KC.Theme

--------------------------------------------------------------------------------
-- The view editor: tick the streams a view shows. Opened with right-click on
-- a view ("Edit view...") or on a stream ("Show together with...", which makes
-- a new view starting with that stream).
--------------------------------------------------------------------------------

local Editor = {}
KC.ViewEditor = Editor

local WIDTH = 440
local COLS = 3
local ROW = 22

-- Every stream a view could show, by section: the fixed ones even before
-- anything was said in them (a raid you haven't joined yet), plus the
-- channels and conversations there are. Conversations come last.
local ORDER = { "group", "near", "channels", "game", "conv" }

local function candidates()
    local bySec = {}
    for key, def in pairs(KC.Fixed) do
        bySec[def.sec] = bySec[def.sec] or {}
        table.insert(bySec[def.sec], { key = key, label = def.label, order = def.order or 99 })
    end
    for key, s in pairs(KC.char.streams) do
        if not KC.Fixed[key] and s.sec then
            bySec[s.sec] = bySec[s.sec] or {}
            table.insert(bySec[s.sec], { key = key, label = s.label or key, order = s.chi or 50 })
        end
    end
    local out = {}
    for _, sec in ipairs(ORDER) do
        local list = bySec[sec]
        if list then
            table.sort(list, function(a, b)
                if a.order ~= b.order then return a.order < b.order end
                return a.label:lower() < b.label:lower()
            end)
            local label
            for _, s in ipairs(KC.Sections) do if s.id == sec then label = s.label end end
            out[#out + 1] = { label = label or sec, list = list }
        end
    end
    return out
end
Editor.Candidates = candidates

function Editor:View()
    local _, saved = KC:ViewKeys(self.key)
    return saved
end

-- Ticks and unticks, keeping the streams in the editor's order.
function Editor:Toggle(key)
    local v = self:View()
    if not v then return end
    local on = {}
    for _, k in ipairs(v.keys) do on[k] = true end
    on[key] = not on[key] or nil
    local keys = {}
    for _, sec in ipairs(candidates()) do
        for _, c in ipairs(sec.list) do
            if on[c.key] then keys[#keys + 1] = c.key end
        end
    end
    v.keys = keys
    self:Refresh()
    local UI = KC.UI
    if KC.db.settings.view == self.key then UI:RenderFeed() end
    UI:RenderSidebar()
end

function Editor:Create()
    if self.frame then return end
    local UI = KC.UI
    local D = UI.Draw
    local f = CreateFrame("Frame", "KrakenChatViewEditor", UIParent)
    f:Hide()
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetPoint("CENTER", 0, 60)
    f:SetScript("OnHide", function() Editor:Closed() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "KrakenChatViewEditor") end
    self.frame = f

    if KC:Look().palette == "wow" then UI:CreateWoWFrame(f) else UI:CreateFlatFrame(f) end

    local wow = KC:Look().palette == "wow"
    local title = D.Text(f, 15, wow and Theme.accent or nil)
    title:SetPoint("TOPLEFT", 12, -10)
    if wow then KC.SetFont(title, 15, "", "title") end
    title:SetText("Edit view")

    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -8)
    D.Strokes(close, 11, Theme.dim, { 45, -45 })
    close:SetScript("OnClick", function() f:Hide() end)

    -- the view's name; empty means it's named after its streams
    local name = CreateFrame("EditBox", nil, f)
    name:SetSize(WIDTH - 32, 22)
    name:SetPoint("TOPLEFT", 16, -42)
    name:SetAutoFocus(false)
    KC.SetFont(name, 12)
    name:SetTextColor(D.rgb(Theme.text))
    name:SetTextInsets(8, 8, 0, 0)
    name:SetMaxLetters(40)
    D.Solid(name, "BACKGROUND", { 0, 0, 0 }, 0.4):SetAllPoints()
    D.Border(name, Theme.accent, 0.5)
    name.placeholder = D.Text(name, 12, Theme.dim)
    name.placeholder:SetPoint("LEFT", 8, 0)
    name.placeholder:SetText("Name (empty: named after its streams)")
    name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    name:SetScript("OnTextChanged", function(self, user)
        local text = strtrim(self:GetText() or "")
        self.placeholder:SetShown(text == "")
        if not user then return end
        local v = Editor:View()
        if v then
            v.name = text ~= "" and text or nil
            KC.UI:RenderSidebar()
            KC.UI:RefreshHeader()
        end
    end)
    self.name = name

    -- the view's symbol: a row of presets, the chosen one in a gold frame
    local label = D.Text(f, 10, Theme.accent)
    label:SetPoint("TOPLEFT", 16, -74)
    label:SetText("SYMBOL")
    self.icons = {}
    local x = 0
    for _, choice in ipairs(KC.ViewIcons) do
        local path = choice.path
        if UI.HasFile(path) then
            local b = CreateFrame("Button", nil, f)
            b:SetSize(26, 26)
            b:SetPoint("TOPLEFT", 16 + x, -90)
            b.ring = D.Solid(b, "BACKGROUND", Theme.accent, 0.95)
            b.ring:SetAllPoints()
            b.tex = b:CreateTexture(nil, "ARTWORK")
            b.tex:SetPoint("TOPLEFT", 2, -2)
            b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
            UI.SetSymbol(b.tex, { view = true, icon = path, gold = choice.gold })
            b.path, b.gold = path, choice.gold
            b:SetScript("OnClick", function(self) Editor:SetIcon(self.path, self.gold) end)
            self.icons[#self.icons + 1] = b
            x = x + 30
        end
    end

    self.headers, self.boxes = {}, {}
end

-- Lays out the sections and tick boxes for the view being edited.
function Editor:Refresh()
    local f, v = self.frame, self:View()
    if not (f and v) then return end
    local D = KC.UI.Draw
    for _, h in ipairs(self.headers) do h:Hide() end
    for _, b in ipairs(self.boxes) do b:Hide() end
    local on = {}
    for _, k in ipairs(v.keys) do on[k] = true end

    -- no symbol of its own: the view shows the default scroll, so that's framed
    local icon, gold = v.icon or KC.Symbols.view[1], v.icon and v.gold or false
    for _, b in ipairs(self.icons) do
        b.ring:SetShown(b.path == icon and (b.gold and true or false) == (gold and true or false))
    end

    local y, hi, bi = 124, 0, 0
    local colW = (WIDTH - 32) / COLS
    for _, sec in ipairs(candidates()) do
        hi = hi + 1
        local h = self.headers[hi]
        if not h then
            h = D.Text(f, 10, Theme.accent)
            self.headers[hi] = h
        end
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 16, -(y + 6))
        h:SetText(sec.label:upper())
        h:Show()
        y = y + 22
        for i, c in ipairs(sec.list) do
            bi = bi + 1
            local b = self.boxes[bi]
            if not b then
                b = KC.Options.CheckBox(f)
                b:SetScript("OnClick", function(self) Editor:Toggle(self.key) end)
                self.boxes[bi] = b
            end
            local col = (i - 1) % COLS
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 16 + col * colW, -y)
            b:SetWidth(colW - 6)
            b:SetHeight(ROW)
            b.key = c.key
            b.label:SetText(c.label)
            b:SetChecked(on[c.key])
            b:Show()
            if col == COLS - 1 or i == #sec.list then y = y + ROW end
        end
        y = y + 4
    end
    f:SetSize(WIDTH, y + 16)
end

function Editor:SetIcon(path, gold)
    local v = self:View()
    if not v then return end
    v.icon, v.gold = path, gold or nil
    self:Refresh()
    KC.UI:RenderSidebar()
end

function Editor:Open(viewKey)
    self:Create()
    self.key = viewKey
    local v = self:View()
    if not v then return end
    self.name:SetText(v.name or "")
    self:Refresh()
    self.frame:Show()
end

-- A new view, opened in the chat so every tick shows right away: empty (the
-- "+" in the header) or starting with a stream ("Show together with...").
function Editor:NewWith(streamKey)
    local settings = KC.db.settings
    local id = settings.nextViewId or 2
    settings.nextViewId = id + 1
    table.insert(settings.views, { id = id, keys = { streamKey } }) -- { nil } is an empty list
    self.isNew = "v:" .. id
    KC.UI:Select("v:" .. id)
    self:Open("v:" .. id)
end

-- A new view left with fewer than two streams isn't a view: it goes again.
function Editor:Closed()
    local key = self.isNew
    self.isNew = nil
    if not key or key ~= self.key then return end
    local v = self:View()
    if v and #v.keys < 2 then
        local only = v.keys[1]
        KC.UI:DeleteView(key)
        if only and KC:Stream(only) then KC.UI:Select(only) end
    end
end
