local _, KC = ...
local Theme = KC.Theme
local Feed = KC.Feed
local call = KC.call

local UI = { expanded = {}, atBottom = true, newBelow = 0 }
KC.UI = UI

local DEFAULT_W, DEFAULT_H = 640, 400
local MIN_W, MIN_H = 420, 220
local HEADER = 34
local SIDE_W = 156
local FOOTER = 26
local PAD = 10
local TIME_W = 38
local INDENT = 16
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

--------------------------------------------------------------------------------
-- Drawing helpers (the same look as Krakenfriends)
--------------------------------------------------------------------------------

local function rgb(c) return c[1], c[2], c[3] end

local function Solid(parent, layer, color, alpha)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
    return t
end

local function Text(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 12, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.75)
    fs:SetTextColor(rgb(color or Theme.text))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Border(frame, color, alpha)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = Solid(frame, "BORDER", color, alpha)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT")
            t:SetPoint(side .. "RIGHT")
            t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side)
            t:SetPoint("BOTTOM" .. side)
            t:SetWidth(1)
        end
    end
end

local function Gradient(tex, orientation, c1, a1, c2, a2)
    tex:SetColorTexture(1, 1, 1, 1)
    if tex.SetGradient and CreateColor then
        tex:SetGradient(orientation, CreateColor(c1[1], c1[2], c1[3], a1), CreateColor(c2[1], c2[2], c2[3], a2))
    else
        tex:SetColorTexture(c2[1], c2[2], c2[3], a2)
    end
end

-- Rotated strokes: an "x" or a chevron without relying on font glyphs.
local function Strokes(parent, size, color, angles, spread)
    local strokes = {}
    for i, angle in ipairs(angles) do
        local s = parent:CreateTexture(nil, "ARTWORK")
        s:SetSize(size, 1.5)
        s:SetPoint("CENTER", spread and (i == 1 and -spread or spread) or 0, 0)
        s:SetColorTexture(rgb(color))
        s:SetRotation(math.rad(angle))
        strokes[i] = s
    end
    return strokes
end

-- A small chevron pointing right (closed) or down (open).
local function Chevron(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(10, 10)
    c.a = parent:CreateTexture(nil, "ARTWORK")
    c.b = parent:CreateTexture(nil, "ARTWORK")
    for _, s in ipairs({ c.a, c.b }) do
        s:SetSize(5, 1.5)
        s:SetColorTexture(rgb(Theme.dim))
    end
    function c:SetOpen(open)
        self.a:ClearAllPoints()
        self.b:ClearAllPoints()
        if open then
            self.a:SetPoint("CENTER", self, "CENTER", -1.6, 0)
            self.b:SetPoint("CENTER", self, "CENTER", 1.6, 0)
            self.a:SetRotation(math.rad(-45))
            self.b:SetRotation(math.rad(45))
        else
            self.a:SetPoint("CENTER", self, "CENTER", 0, 1.6)
            self.b:SetPoint("CENTER", self, "CENTER", 0, -1.6)
            self.a:SetRotation(math.rad(-45))
            self.b:SetRotation(math.rad(45))
        end
    end
    function c:SetColor(color)
        self.a:SetColorTexture(rgb(color))
        self.b:SetColorTexture(rgb(color))
    end
    c:SetOpen(false)
    return c
end

local function fontSize() return KC.db.settings.fontSize or 12 end

--------------------------------------------------------------------------------
-- Replying: opens the game's chat input set up for the stream.
--------------------------------------------------------------------------------

local SLASH = { party = "/p ", raid = "/ra ", instance = "/i ", guild = "/g ", officer = "/o ", say = "/s ", yell = "/y ", emote = "/e " }

local function whisper(name)
    local tell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
    if tell and pcall(tell, name, DEFAULT_CHAT_FRAME) then return end
    KC.OpenChat("/w " .. name .. " ")
end

local function bnetAccountName(tag)
    if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends) then return nil end
    local n = call(BNGetNumFriends) or 0
    for i = 1, n do
        local ok, info = pcall(C_BattleNet.GetFriendAccountInfo, i)
        info = ok and KC.clean(info)
        if type(info) == "table" and KC.clean(info.battleTag) == tag then return info.accountName end
    end
end

function UI:ReplyText(key)
    local s = KC:Stream(key)
    if key == "all" or not s then return "Click to chat" end
    if s.sec == "conv" then return "Reply to " .. s.label end
    if SLASH[key] then return "Write in " .. s.label end
    if s.sec == "channels" then return "Write in " .. s.label end
    return nil
end

function UI:Reply(key)
    local s = KC:Stream(key)
    if key == "all" or not s then return KC.OpenChat("") end
    if s.bn then
        local account = bnetAccountName(s.bn)
        if account then return KC.OpenBNetTell(account) end
        return KC:Print(s.label .. " isn't online on Battle.net.")
    end
    if s.who then return whisper(s.who) end
    if SLASH[key] then return KC.OpenChat(SLASH[key]) end
    if s.sec == "channels" then
        local index = s.chi
        if GetChannelName then
            local id = call(GetChannelName, s.label)
            if type(id) == "number" and id > 0 then index = id end
        end
        if index then return KC.OpenChat("/" .. index .. " ") end
    end
end

--------------------------------------------------------------------------------
-- Links in messages
--------------------------------------------------------------------------------

local TOOLTIP_LINKS = { item = true, spell = true, quest = true, achievement = true, enchant = true, currency = true, talent = true, mount = true, battlepet = true }

local function onLinkClick(self, link, text, button)
    link = KC.clean(link)
    if type(link) ~= "string" then return end
    local kind, rest = link:match("^addon:KrakenChat:(%a+):(.*)$")
    if kind == "url" then
        UI:ShowCopy(rest, "Copy the link with Ctrl+C, then paste it in your browser.")
    elseif kind == "name" then
        whisper(rest)
    elseif kind == "stream" then
        UI:Reply(rest)
    elseif SetItemRef then
        pcall(SetItemRef, link, text, button, DEFAULT_CHAT_FRAME)
    end
end

UI.OnLinkClick = onLinkClick

local function onLinkEnter(self, link)
    link = KC.clean(link)
    local kind = type(link) == "string" and link:match("^(%a+):")
    if not (kind and TOOLTIP_LINKS[kind]) then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Show() else GameTooltip:Hide() end
end

local function onLinkLeave() GameTooltip:Hide() end

--------------------------------------------------------------------------------
-- Widget pools
--------------------------------------------------------------------------------

local factories = {}

function factories.msg(parent)
    local w = CreateFrame("Frame", nil, parent)
    w:EnableMouse(true)
    w.hl = Solid(w, "BACKGROUND", Theme.hover)
    w.hl:SetAllPoints()
    w.hl:Hide()
    w.guide = Solid(w, "BORDER", Theme.line, 0.12)
    w.guide:SetWidth(1)
    w.guide:SetPoint("TOPLEFT", 5, 0)
    w.guide:SetPoint("BOTTOMLEFT", 5, 0)
    w.time = Text(w, 10, Theme.dim)
    w.pre = Text(w, 12)
    w.body = Text(w, 12)
    w.body:SetWordWrap(true)
    if w.body.SetNonSpaceWrap then w.body:SetNonSpaceWrap(true) end
    w.body:SetJustifyV("TOP")
    if w.SetHyperlinksEnabled then w:SetHyperlinksEnabled(true) end
    w:SetScript("OnHyperlinkClick", onLinkClick)
    w:SetScript("OnHyperlinkEnter", onLinkEnter)
    w:SetScript("OnHyperlinkLeave", onLinkLeave)
    w:SetScript("OnEnter", function(self) self.hl:Show() end)
    w:SetScript("OnLeave", function(self) self.hl:Hide() end)
    w:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.entry then UI:MessageMenu(self, self.entry) end
    end)
    return w
end

function factories.fold(parent)
    local w = CreateFrame("Button", nil, parent)
    w:SetHeight(20)
    w.hl = Solid(w, "BACKGROUND", Theme.hover)
    w.hl:SetAllPoints()
    w.hl:Hide()
    w.bg = Solid(w, "BACKGROUND", Theme.panel)
    w.bg:SetAllPoints()
    w.chev = Chevron(w)
    w.chev:SetPoint("LEFT", 0, 0)
    w.text = Text(w, 11, Theme.dim)
    w.text:SetPoint("LEFT", INDENT, 0)
    w.text:SetPoint("RIGHT", -70, 0)
    w.span = Text(w, 10, Theme.dim, "RIGHT")
    w.span:SetPoint("RIGHT", -4, 0)
    w:SetScript("OnEnter", function(self) self.hl:Show(); self.text:SetTextColor(rgb(Theme.text)) end)
    w:SetScript("OnLeave", function(self) self.hl:Hide(); self.text:SetTextColor(rgb(Theme.dim)) end)
    w:SetScript("OnClick", function(self)
        UI.expanded[self.id] = not UI.expanded[self.id] or nil
        UI.anchorKey = "f" .. self.id -- keep the fold where it is on screen
        UI:RenderFeed()
    end)
    return w
end

function factories.day(parent)
    local w = CreateFrame("Frame", nil, parent)
    w:SetHeight(24)
    w.text = Text(w, 10, Theme.accent, "CENTER")
    w.text:SetPoint("CENTER", 0, -1)
    w.l = Solid(w, "ARTWORK", Theme.line)
    w.l:SetHeight(1)
    w.l:SetPoint("LEFT", 0, -1)
    w.l:SetPoint("RIGHT", w.text, "LEFT", -8, 0)
    w.r = Solid(w, "ARTWORK", Theme.line)
    w.r:SetHeight(1)
    w.r:SetPoint("LEFT", w.text, "RIGHT", 8, 0)
    w.r:SetPoint("RIGHT", 0, -1)
    return w
end

function factories.section(parent)
    local w = CreateFrame("Button", nil, parent)
    w:SetSize(SIDE_W, 24)
    w:RegisterForClicks("AnyUp")
    w.chev = Chevron(w)
    w.chev:SetPoint("LEFT", 8, -2)
    w.label = Text(w, 10, Theme.accent)
    w.label:SetPoint("LEFT", 20, -2)
    w.extra = Text(w, 10, Theme.dim, "RIGHT")
    w.extra:SetPoint("RIGHT", -8, -2)
    w:SetScript("OnEnter", function(self) self.label:SetTextColor(rgb(Theme.text)) end)
    w:SetScript("OnLeave", function(self) self.label:SetTextColor(rgb(Theme.accent)) end)
    w:SetScript("OnClick", function(self, button)
        local c = KC.db.settings.collapsed
        if self.id == "conv" and button == "RightButton" then
            KC.db.settings.sort = KC.db.settings.sort == "name" and "recent" or "name"
        else
            c[self.id] = not c[self.id] or nil
        end
        UI:RenderSidebar()
    end)
    return w
end

function factories.stream(parent)
    local w = CreateFrame("Button", nil, parent)
    w:SetSize(SIDE_W, 20)
    w:RegisterForClicks("AnyUp")
    w.hl = Solid(w, "BACKGROUND", Theme.hover)
    w.hl:SetAllPoints()
    w.hl:Hide()
    w.sel = Solid(w, "BACKGROUND", Theme.accent, 0.10)
    w.sel:SetAllPoints()
    w.stripe = Solid(w, "ARTWORK", Theme.accent)
    w.stripe:SetPoint("TOPLEFT")
    w.stripe:SetPoint("BOTTOMLEFT")
    w.stripe:SetWidth(2)
    w.badge = CreateFrame("Frame", nil, w)
    w.badge:SetSize(22, 14)
    w.badge:SetPoint("RIGHT", -8, 0)
    Solid(w.badge, "ARTWORK", Theme.accent2):SetAllPoints()
    w.count = Text(w.badge, 9, Theme.text, "CENTER")
    w.count:SetPoint("CENTER", 0, 0)
    w.label = Text(w, 12)
    w.label:SetPoint("LEFT", 20, 0)
    w.label:SetPoint("RIGHT", w.badge, "LEFT", -4, 0)
    w:SetScript("OnEnter", function(self) self.hl:Show() end)
    w:SetScript("OnLeave", function(self) self.hl:Hide() end)
    w:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.key ~= "all" then UI:StreamMenu(self, self.key) end
        else
            UI:Select(self.key)
        end
    end)
    return w
end

local pools = {}

local function acquire(kind, parent)
    local pool = pools[kind]
    if not pool then
        pool = { free = {}, used = {} }
        pools[kind] = pool
    end
    local w = table.remove(pool.free) or factories[kind](parent)
    pool.used[#pool.used + 1] = w
    if w.hl then w.hl:Hide() end
    w:ClearAllPoints()
    w:Show()
    return w
end

local function release(kinds)
    for _, kind in ipairs(kinds) do
        local pool = pools[kind]
        if pool then
            for i = #pool.used, 1, -1 do
                local w = pool.used[i]
                w:Hide()
                pool.free[#pool.free + 1] = w
                pool.used[i] = nil
            end
        end
    end
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

function UI:SaveGeometry()
    local f = self.frame
    local point, _, relPoint, x, y = f:GetPoint()
    local win = KC.db.settings.window
    win.point, win.relPoint, win.x, win.y = point, relPoint, x, y
    win.w, win.h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
end

function UI:ResetPosition()
    if not self.frame then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER")
    self.frame:SetSize(DEFAULT_W, DEFAULT_H)
    self:SaveGeometry()
    self:Show()
end

function UI:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "KrakenChatFrame", UIParent)
    f:Hide() -- before the OnHide script, which remembers that the window was closed
    self.frame = f
    local win = KC.db.settings.window
    f:SetSize(win.w or DEFAULT_W, win.h or DEFAULT_H)
    if win.point then
        f:SetPoint(win.point, UIParent, win.relPoint or win.point, win.x or 0, win.y or 0)
    else
        f:SetPoint("BOTTOMLEFT", 40, 140)
    end
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H) elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H) end
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        UI:SaveGeometry()
    end)
    f:SetScript("OnShow", function()
        KC.db.settings.shown = true
        UI:Refresh()
    end)
    f:SetScript("OnHide", function()
        KC.db.settings.shown = false
        if UI.menu then UI.menu:Hide() end
    end)
    f:SetScript("OnSizeChanged", function() UI:Request("feed") end)

    -- backdrop: deep panel, faint teal glow at the top, teal-to-violet rim
    Solid(f, "BACKGROUND", Theme.bg):SetAllPoints()
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("TOPRIGHT", -1, -1)
    glow:SetHeight(60)
    Gradient(glow, "VERTICAL", Theme.accent, 0, Theme.accent, 0.07)
    Border(f, Theme.line, 0.10)
    local rim = f:CreateTexture(nil, "ARTWORK")
    rim:SetPoint("TOPLEFT", 1, -1)
    rim:SetPoint("TOPRIGHT", -1, -1)
    rim:SetHeight(2)
    Gradient(rim, "HORIZONTAL", Theme.accent, 1, Theme.accent2, 1)

    -- header: title, search, close
    local title = Text(f, 13)
    title:SetPoint("TOPLEFT", 12, -11)
    title:SetText("|cff4fd1c5Kraken|rchat")

    self.viewTitle = Text(f, 11, Theme.dim)
    self.viewTitle:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -8)
    local x = Strokes(close, 11, Theme.dim, { 45, -45 })
    close:SetScript("OnEnter", function() for _, s in ipairs(x) do s:SetColorTexture(1, 1, 1, 1) end end)
    close:SetScript("OnLeave", function() for _, s in ipairs(x) do s:SetColorTexture(Theme.dim[1], Theme.dim[2], Theme.dim[3], 1) end end)
    close:SetScript("OnClick", function() f:Hide() end)

    self:CreateSearch(f, close)

    local headLine = Solid(f, "ARTWORK", Theme.line)
    headLine:SetHeight(1)
    headLine:SetPoint("TOPLEFT", 1, -HEADER)
    headLine:SetPoint("TOPRIGHT", -1, -HEADER)

    -- sidebar
    local sideBg = Solid(f, "BACKGROUND", Theme.side)
    sideBg:SetPoint("TOPLEFT", 1, -HEADER - 1)
    sideBg:SetPoint("BOTTOMLEFT", 1, 1)
    sideBg:SetWidth(SIDE_W)
    local sideLine = Solid(f, "ARTWORK", Theme.line)
    sideLine:SetWidth(1)
    sideLine:SetPoint("TOPLEFT", SIDE_W + 1, -HEADER - 1)
    sideLine:SetPoint("BOTTOMLEFT", SIDE_W + 1, 1)

    local side = CreateFrame("ScrollFrame", nil, f)
    side:SetPoint("TOPLEFT", 1, -HEADER - 1)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDE_W)
    local sideChild = CreateFrame("Frame", nil, side)
    sideChild:SetSize(SIDE_W, 1)
    side:SetScrollChild(sideChild)
    side:EnableMouseWheel(true)
    side:SetScript("OnMouseWheel", function(sf, delta)
        local max = math.max(0, sideChild:GetHeight() - sf:GetHeight())
        sf:SetVerticalScroll(math.min(max, math.max(0, sf:GetVerticalScroll() - delta * 40)))
    end)
    self.side, self.sideChild = side, sideChild

    -- feed
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", SIDE_W + PAD + 1, -HEADER - 6)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 6, FOOTER + 6)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local step = IsShiftKeyDown and IsShiftKeyDown() and 100000 or 3 * (fontSize() + 4)
        UI:Scroll(-delta * step)
    end)
    self.scroll, self.child = scroll, child

    self.track = Solid(f, "ARTWORK", Theme.line, 0.06)
    self.track:SetWidth(2)
    self.track:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
    self.track:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
    self.thumb = Solid(f, "OVERLAY", Theme.accent, 0.55)
    self.thumb:SetWidth(2)

    self.empty = Text(f, 12, Theme.dim, "CENTER")
    self.empty:SetPoint("CENTER", scroll, "CENTER")
    self.empty:SetWidth(260)
    self.empty:SetWordWrap(true)

    -- "N new messages": shown while you read further up
    local pill = CreateFrame("Button", nil, f)
    pill:SetSize(130, 20)
    pill:SetPoint("BOTTOM", scroll, "BOTTOM", 0, 4)
    pill:SetFrameLevel(scroll:GetFrameLevel() + 10)
    Solid(pill, "BACKGROUND", Theme.accent2, 0.9):SetAllPoints()
    pill.text = Text(pill, 11, Theme.text, "CENTER")
    pill.text:SetPoint("CENTER", 0, 0)
    pill:SetScript("OnClick", function() UI:ScrollToBottom() end)
    pill:Hide()
    self.pill = pill

    -- footer: reply
    local footer = CreateFrame("Button", nil, f)
    footer:SetPoint("BOTTOMLEFT", SIDE_W + PAD + 1, 6)
    footer:SetPoint("BOTTOMRIGHT", -PAD - 12, 6)
    footer:SetHeight(FOOTER - 6)
    footer.bg = Solid(footer, "BACKGROUND", Theme.panel)
    footer.bg:SetAllPoints()
    footer.edge = Solid(footer, "ARTWORK", Theme.accent, 0.5)
    footer.edge:SetPoint("TOPLEFT")
    footer.edge:SetPoint("BOTTOMLEFT")
    footer.edge:SetWidth(2)
    footer.text = Text(footer, 11, Theme.dim)
    footer.text:SetPoint("LEFT", 10, 0)
    footer.hint = Text(footer, 10, Theme.dim, "RIGHT")
    footer.hint:SetPoint("RIGHT", -8, 0)
    footer:SetScript("OnEnter", function(self) self.text:SetTextColor(rgb(Theme.text)) end)
    footer:SetScript("OnLeave", function(self) self.text:SetTextColor(rgb(Theme.dim)) end)
    footer:SetScript("OnClick", function() UI:Reply(KC.db.settings.view) end)
    self.footer = footer

    -- resize grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    for i, len in ipairs({ 10, 6 }) do
        local s = grip:CreateTexture(nil, "ARTWORK")
        s:SetSize(len, 1.5)
        s:SetPoint("BOTTOMRIGHT", -2 - (i - 1) * 2, 2 + (i - 1) * 2 + len / 3)
        s:SetColorTexture(rgb(Theme.dim))
        s:SetRotation(math.rad(45))
    end
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        UI:SaveGeometry()
        UI:RenderFeed()
    end)
end

function UI:CreateSearch(f, close)
    local box = CreateFrame("EditBox", nil, f)
    box:SetSize(170, 20)
    box:SetPoint("RIGHT", close, "LEFT", -10, 0)
    box:SetAutoFocus(false)
    box:SetFont(FONT, 11, "")
    box:SetTextColor(rgb(Theme.text))
    box:SetTextInsets(8, 20, 0, 0)
    box:SetMaxLetters(60)
    Solid(box, "BACKGROUND", Theme.panel):SetAllPoints()
    local edge = Solid(box, "ARTWORK", Theme.accent, 0.6)
    edge:SetPoint("BOTTOMLEFT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetHeight(1)
    box.placeholder = Text(box, 11, Theme.dim)
    box.placeholder:SetPoint("LEFT", 8, 0)
    box.placeholder:SetText("Search")

    local clear = CreateFrame("Button", nil, box)
    clear:SetSize(16, 16)
    clear:SetPoint("RIGHT", -2, 0)
    Strokes(clear, 8, Theme.dim, { 45, -45 })
    clear:SetScript("OnClick", function()
        box:SetText("")
        box:ClearFocus()
    end)
    clear:Hide()

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function() box.placeholder:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) box.placeholder:SetShown((self:GetText() or "") == "") end)
    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        clear:SetShown(text ~= "")
        if text ~= "" then box.placeholder:Hide() end
        UI.query = text
        UI.atBottom = true
        UI:Request("feed")
    end)
    self.search = box
end

--------------------------------------------------------------------------------
-- Scrolling
--------------------------------------------------------------------------------

function UI:Scroll(delta)
    local sf, child = self.scroll, self.child
    if sf.UpdateScrollChildRect then sf:UpdateScrollChildRect() end
    local height = sf:GetHeight()
    local max = math.max(0, child:GetHeight() - height)
    local v = math.min(max, math.max(0, sf:GetVerticalScroll() + delta))
    sf:SetVerticalScroll(v)
    self.atBottom = v >= max - 2
    if self.atBottom then
        self.newBelow = 0
        KC:MarkRead(KC.db.settings.view)
    end
    self:UpdatePill()
    if max <= 0 then
        self.thumb:Hide()
        self.track:Hide()
        return
    end
    self.thumb:Show()
    self.track:Show()
    local th = math.max(24, height * height / child:GetHeight())
    self.thumb:SetHeight(th)
    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 6, -(height - th) * (v / max))
end

function UI:ScrollToBottom()
    self:Scroll(1e9)
end

function UI:UpdatePill()
    if self.newBelow > 0 and not self.atBottom then
        self.pill.text:SetText(self.newBelow == 1 and "1 new message" or (self.newBelow .. " new messages"))
        self.pill:Show()
    else
        self.pill:Hide()
    end
end

--------------------------------------------------------------------------------
-- Feed
--------------------------------------------------------------------------------

local function itemKey(item)
    if item.type == "msg" then return "m" .. item.e.m.id end
    if item.type == "fold" then return "f" .. item.id end
    return "d" .. date("%Y%m%d", item.t)
end

-- Lays out one message row and returns its height.
local function layoutMsg(w, item, width, all)
    local m, s = item.e.m, item.e.s
    local size = fontSize()
    local x = item.indent and INDENT or 0
    local timestamps = KC.db.settings.timestamps
    local top = item.cont and 1 or 4
    w.entry = item.e
    w.guide:SetShown(item.indent and true or false)

    w.time:SetFont(FONT, size - 2, "")
    w.time:ClearAllPoints()
    w.time:SetPoint("TOPLEFT", x, -top - 1)
    w.time:SetText((timestamps and not item.cont) and date("%H:%M", m.t) or "")
    local bodyX = x + (timestamps and TIME_W or 0)

    w.body:SetFont(FONT, size, "")
    w.pre:SetFont(FONT, size, "")
    w.body:ClearAllPoints()
    w.pre:ClearAllPoints()
    if m.secret then
        -- secret text can be shown but not read: it goes into the font string as is
        local r, g, b = Feed.Color(m)
        w.pre:SetText((all and s.tag and ("[" .. s.tag .. "] ") or "") .. (m.a and (m.a .. ":") or ""))
        w.pre:SetTextColor(r, g, b)
        w.pre:SetPoint("TOPLEFT", bodyX, -top)
        w.pre:Show()
        local preW = KC.clean(w.pre:GetStringWidth()) or 0
        w.body:SetPoint("TOPLEFT", bodyX + preW + 4, -top)
        w.body:SetWidth(math.max(40, width - bodyX - preW - 4))
        w.body:SetTextColor(r, g, b)
        pcall(w.body.SetText, w.body, m.x)
    else
        w.pre:Hide()
        w.body:SetPoint("TOPLEFT", bodyX, -top)
        w.body:SetWidth(math.max(40, width - bodyX))
        w.body:SetTextColor(rgb(Theme.text))
        w.body:SetText(Feed:Line(m, s, all))
    end
    local h = KC.clean(w.body:GetStringHeight()) or size
    if type(h) ~= "number" or h < size then h = size end
    h = math.floor(h + 0.5) + top + 2
    w:SetHeight(h)
    return h
end

function UI:RenderFeed()
    if not (self.frame and self.frame:IsShown()) then
        self.dirty = true
        return
    end
    self.dirty = false
    local view = KC.db.settings.view
    if view ~= "all" and not KC:Stream(view) then
        view = "all"
        KC.db.settings.view = view
    end
    local all = view == "all"
    local query = (self.query and self.query ~= "") and self.query or nil

    -- remember what is at the top of the screen, to keep it there
    local anchorKey, anchorOffset = self.anchorKey, 0
    self.anchorKey = nil
    local scrollY = self.scroll:GetVerticalScroll()
    if self.layout then
        for _, row in ipairs(self.layout) do
            if anchorKey then
                if row.key == anchorKey then anchorOffset = row.y - scrollY; break end
            elseif row.y + row.h > scrollY then
                anchorKey, anchorOffset = row.key, row.y - scrollY
                break
            end
        end
    end
    local stick = self.atBottom ~= false

    release({ "msg", "fold", "day" })
    local entries = Feed:Collect(view, query)
    local items = Feed:Build(entries, all and not query, self.expanded)
    local width = math.max(100, self.frame:GetWidth() - SIDE_W - PAD * 2 - 8)
    self.child:SetWidth(width)

    local y, layout = 0, {}
    for _, item in ipairs(items) do
        local w = acquire(item.type, self.child)
        w:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
        w:SetWidth(width)
        local h
        if item.type == "msg" then
            h = layoutMsg(w, item, width, all)
        elseif item.type == "fold" then
            w.id = item.id
            w.chev:SetOpen(item.open)
            local n = #item.list
            w.text:SetText(("%d lines: %s"):format(n, Feed:FoldSummary(item)))
            local a, b = date("%H:%M", item.first), date("%H:%M", item.last)
            w.span:SetText(a == b and a or (a .. "-" .. b))
            h = 20
            w:SetHeight(h)
            h = h + 2
        else
            w.text:SetText(Feed:DayLabel(item.t):upper())
            h = 24
        end
        layout[#layout + 1] = { key = itemKey(item), y = y, h = h }
        y = y + h
    end
    self.layout = layout
    self.child:SetHeight(math.max(1, y + 4))

    if #items == 0 then
        if query then
            self.empty:SetText("Nothing matches \"" .. query .. "\".")
        elseif all then
            self.empty:SetText("No messages yet. Everything said around you shows up here.\n\nType /kc demo to see sample messages.")
        else
            self.empty:SetText("No messages here yet.")
        end
        self.empty:Show()
    else
        self.empty:Hide()
    end

    if stick then
        self:ScrollToBottom()
    else
        local target
        for _, row in ipairs(layout) do
            if row.key == anchorKey then target = row.y - anchorOffset; break end
        end
        self.scroll:SetVerticalScroll(0)
        self:Scroll(target or scrollY)
    end
    self:RefreshHeader()
end

function UI:RefreshHeader()
    local view = KC.db.settings.view
    local s = KC:Stream(view)
    local name = view == "all" and "All messages" or (s and s.label) or ""
    if KC:IsMuted(view) then name = name .. " (hidden in All messages)" end
    self.viewTitle:SetText(name)
    local reply = self:ReplyText(view)
    self.footer:SetShown(reply ~= nil)
    if reply then
        self.footer.text:SetText(reply)
        self.footer.hint:SetText("opens the chat input")
    end
end

--------------------------------------------------------------------------------
-- Sidebar
--------------------------------------------------------------------------------

local function sortStreams(sec, list)
    if sec == "conv" then
        if KC.db.settings.sort == "name" then
            table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
        else
            table.sort(list, function(a, b) return a.last > b.last end)
        end
    elseif sec == "channels" then
        table.sort(list, function(a, b)
            if (a.chi or 99) ~= (b.chi or 99) then return (a.chi or 99) < (b.chi or 99) end
            return a.label < b.label
        end)
    else
        table.sort(list, function(a, b) return (a.order or 99) < (b.order or 99) end)
    end
end

local function fillStream(w, key, label, s)
    local settings = KC.db.settings
    local selected = settings.view == key
    w.key = key
    w.sel:SetShown(selected)
    w.stripe:SetShown(selected)
    local muted = key ~= "all" and KC:IsMuted(key)
    local r, g, b = rgb(Theme.text)
    if s and s.class then
        local cr, cg, cb = KC.ClassColor(s.class)
        if cr then r, g, b = cr, cg, cb end
    end
    if muted then r, g, b = Theme.dim[1] * 0.8, Theme.dim[2] * 0.8, Theme.dim[3] * 0.8 end
    w.label:SetText(label)
    w.label:SetTextColor(r, g, b)
    local unread = s and s.unread or 0
    w.badge:SetShown(unread > 0)
    w.count:SetText(unread > 99 and "99+" or tostring(unread))
end

function UI:RenderSidebar()
    if not (self.frame and self.frame:IsShown()) then
        self.dirty = true
        return
    end
    release({ "section", "stream" })
    local child = self.sideChild
    local y = 6

    local w = acquire("stream", child)
    w:SetPoint("TOPLEFT", 0, -y)
    fillStream(w, "all", "All messages", nil)
    w.label:SetPoint("LEFT", 12, 0)
    y = y + 22

    local bySection = {}
    for _, s in pairs(KC.char.streams) do
        if s.sec and #s.msgs > 0 then
            bySection[s.sec] = bySection[s.sec] or {}
            table.insert(bySection[s.sec], s)
        end
    end

    local collapsed = KC.db.settings.collapsed
    for _, sec in ipairs(KC.Sections) do
        local list = bySection[sec.id]
        if list then
            sortStreams(sec.id, list)
            local h = acquire("section", child)
            h:SetPoint("TOPLEFT", 0, -y)
            h.id = sec.id
            h.label:SetText(sec.label:upper())
            h.chev:SetOpen(not collapsed[sec.id])
            local unread = 0
            for _, s in ipairs(list) do unread = unread + s.unread end
            if collapsed[sec.id] and unread > 0 then
                h.extra:SetText(KC.Colorize(tostring(unread), rgb(Theme.accent2)))
            elseif sec.id == "conv" then
                h.extra:SetText(KC.db.settings.sort == "name" and "a-z" or "recent")
            else
                h.extra:SetText("")
            end
            y = y + 24
            if not collapsed[sec.id] then
                for _, s in ipairs(list) do
                    local row = acquire("stream", child)
                    row:SetPoint("TOPLEFT", 0, -y)
                    row.label:SetPoint("LEFT", 20, 0)
                    fillStream(row, s.key, s.label, s)
                    y = y + 20
                end
            end
        end
    end
    child:SetHeight(y + 6)
end

function UI:Select(key)
    KC.db.settings.view = key
    self.atBottom = true
    self.newBelow = 0
    KC:MarkRead(key)
    self:RenderSidebar()
    self:RenderFeed()
end

--------------------------------------------------------------------------------
-- Menus (right-click)
--------------------------------------------------------------------------------

function UI:ShowMenu(anchor, entries)
    if not self.menu then
        local m = CreateFrame("Frame", nil, self.frame)
        m:SetFrameStrata("DIALOG")
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        Solid(m, "BACKGROUND", { 0.035, 0.04, 0.055, 0.98 }):SetAllPoints()
        Border(m, Theme.line, 0.14)
        m.buttons = {}
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("DIALOG")
        catcher:SetFrameLevel(1)
        catcher:RegisterForClicks("AnyUp")
        catcher:SetScript("OnClick", function() m:Hide() end)
        catcher:Hide()
        m:SetScript("OnShow", function() catcher:Show() end)
        m:SetScript("OnHide", function() catcher:Hide() end)
        m:SetFrameLevel(catcher:GetFrameLevel() + 5)
        m:Hide()
        self.menu = m
    end
    local m = self.menu
    for _, b in ipairs(m.buttons) do b:Hide() end
    local y = 6
    for i, e in ipairs(entries) do
        local b = m.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, m)
            b:SetHeight(20)
            b.hl = Solid(b, "BACKGROUND", Theme.hover)
            b.hl:SetAllPoints()
            b.hl:Hide()
            b.text = Text(b, 12)
            b.text:SetPoint("LEFT", 12, 0)
            b.text:SetPoint("RIGHT", -8, 0)
            b:SetScript("OnEnter", function(btn) if btn.func then btn.hl:Show() end end)
            b:SetScript("OnLeave", function(btn) btn.hl:Hide() end)
            b:SetScript("OnClick", function(btn)
                if not btn.func then return end
                m:Hide()
                btn.func()
            end)
            m.buttons[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 1, -y)
        b:SetPoint("TOPRIGHT", -1, -y)
        b.func = e.func
        if e.header then
            b.text:SetFont(FONT, 10, "")
            b.text:SetTextColor(rgb(Theme.accent))
            b.text:SetText(e.header:upper())
        else
            b.text:SetFont(FONT, 12, "")
            b.text:SetTextColor(rgb(e.danger and { 1, 0.45, 0.45 } or Theme.text))
            b.text:SetText(e.text)
        end
        b:Show()
        y = y + 20
    end
    m:SetSize(210, y + 6)
    m:ClearAllPoints()
    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    m:Show()
    self.menuEntries = entries -- for tests
end

function UI:StreamMenu(anchor, key)
    local s = KC:Stream(key)
    if not s then return end
    local settings = KC.db.settings
    local muted, folds = KC:IsMuted(key), KC:Folds(s)
    local entries = {
        { header = s.label },
        { text = muted and "Show in All messages" or "Hide in All messages", func = function()
            settings.muted[key] = not muted or nil
            UI:RenderSidebar()
            UI:RenderFeed()
        end },
        { text = folds and "Don't fold in All messages" or "Fold in All messages", func = function()
            settings.fold[key] = not folds
            UI:RenderFeed()
        end },
    }
    if self:ReplyText(key) then
        entries[#entries + 1] = { text = s.sec == "conv" and "Whisper" or "Write here", func = function() UI:Reply(key) end }
    end
    entries[#entries + 1] = { text = s.sec == "conv" and "Close conversation" or "Clear history", danger = true, func = function()
        KC:CloseStream(key)
    end }
    self:ShowMenu(anchor, entries)
end

function UI:MessageMenu(anchor, entry)
    local m, s = entry.m, entry.s
    local entries = { { header = m.a or s.label } }
    if not m.secret then
        entries[#entries + 1] = { text = "Copy text", func = function() UI:ShowCopy(Feed:CopyText(m, s)) end }
    end
    if m.a and not m.o and m.f ~= "plain" and s.key ~= "npc" then
        entries[#entries + 1] = { text = "Whisper " .. m.a, func = function()
            if s.sec == "conv" then UI:Reply(s.key) else whisper(m.a) end
        end }
    end
    if KC.db.settings.view == "all" then
        entries[#entries + 1] = { text = "Open " .. s.label, func = function() UI:Select(s.key) end }
    end
    self:ShowMenu(anchor, entries)
end

--------------------------------------------------------------------------------
-- Copy box
--------------------------------------------------------------------------------

function UI:ShowCopy(text, hint)
    if not self.copy then
        local c = CreateFrame("Frame", "KrakenChatCopyFrame", UIParent)
        c:SetSize(420, 96)
        c:SetPoint("CENTER", 0, 120)
        c:SetFrameStrata("DIALOG")
        c:EnableMouse(true)
        Solid(c, "BACKGROUND", Theme.bg):SetAllPoints()
        Border(c, Theme.line, 0.14)
        local rim = c:CreateTexture(nil, "ARTWORK")
        rim:SetPoint("TOPLEFT", 1, -1)
        rim:SetPoint("TOPRIGHT", -1, -1)
        rim:SetHeight(2)
        Gradient(rim, "HORIZONTAL", Theme.accent, 1, Theme.accent2, 1)
        c.hint = Text(c, 11, Theme.dim)
        c.hint:SetPoint("TOPLEFT", 12, -12)
        c.hint:SetPoint("TOPRIGHT", -30, -12)
        local close = CreateFrame("Button", nil, c)
        close:SetSize(18, 18)
        close:SetPoint("TOPRIGHT", -6, -8)
        Strokes(close, 11, Theme.dim, { 45, -45 })
        close:SetScript("OnClick", function() c:Hide() end)
        local box = CreateFrame("EditBox", nil, c)
        box:SetPoint("TOPLEFT", 12, -34)
        box:SetPoint("BOTTOMRIGHT", -12, 12)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFont(FONT, 12, "")
        box:SetTextColor(rgb(Theme.text))
        Solid(box, "BACKGROUND", Theme.panel):SetAllPoints()
        box:SetTextInsets(6, 6, 4, 4)
        box:SetScript("OnEscapePressed", function() c:Hide() end)
        box:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(c.value or ""); self:HighlightText() end -- read-only
        end)
        c.box = box
        if UISpecialFrames then table.insert(UISpecialFrames, "KrakenChatCopyFrame") end
        self.copy = c
    end
    local c = self.copy
    c.value = text or ""
    c.hint:SetText(hint or "Press Ctrl+C to copy.")
    c:Show()
    c.box:SetText(c.value)
    c.box:SetFocus()
    c.box:HighlightText()
end

--------------------------------------------------------------------------------
-- Refreshing
--------------------------------------------------------------------------------

local pending = {}

-- Coalesces bursts (a busy trade channel, a loot shower) into one redraw.
function UI:Request(what)
    if not (self.frame and self.frame:IsShown()) then
        self.dirty = true
        return
    end
    if pending[what] then return end
    pending[what] = true
    C_Timer.After(0.1, function()
        pending[what] = nil
        if what == "feed" then UI:RenderFeed() else UI:RenderSidebar() end
    end)
end

function UI:Refresh()
    if not self.frame then return end
    self:RenderSidebar()
    self:RenderFeed()
end

function UI:Show()
    self:Create()
    if self.frame:IsShown() then self:Refresh() else self.frame:Show() end
end

function UI:Toggle()
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
end

local function inView(s)
    local view = KC.db.settings.view
    return view == s.key or (view == "all" and not KC:IsMuted(s.key))
end

KC:Listen("MESSAGE", function(_, s, isRepeat)
    if not inView(s) then
        UI:Request("side")
        return
    end
    if not isRepeat and UI.atBottom == false then
        UI.newBelow = UI.newBelow + 1
        if UI.frame then UI:UpdatePill() end
    end
    UI:Request("feed")
end)
KC:Listen("STREAMS", function() UI:Request("side"); UI:Request("feed") end)
KC:Listen("UNREAD", function() UI:Request("side") end)
KC:Listen("LAYOUT", function() UI:Request("feed") end)

KC:Listen("LOGIN", function()
    UI.query = ""
    if KC.db.settings.shown then UI:Show() end
end)
