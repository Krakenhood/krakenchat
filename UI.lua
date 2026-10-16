local _, KC = ...
local Theme = KC.Theme
local Feed = KC.Feed
local call = KC.call

local UI = { expanded = {}, atBottom = true, newBelow = 0 }
KC.UI = UI

local DEFAULT_W, DEFAULT_H = 520, 260
local MIN_W, MIN_H = 360, 140
local HEADER = 34
local SIDE_W = 156
local RAIL_W = 30 -- the sidebar folded in
local SYMBOL_W = 46 -- the sidebar as a column of symbols (/kc symbols)
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

-- Unread badges: red for whispers (meant for you), a calm dark gold for group
-- and guild chat, so a whisper stands out; for Say, Yell and channels only a
-- small grey number ("quiet").
local function paintBadge(bg, count, kind)
    if kind == "quiet" then
        bg:SetColorTexture(0, 0, 0, 0)
        count:SetTextColor(rgb(Theme.dim))
        return
    end
    local c = kind and Theme.accent2 or Theme.calm
    bg:SetColorTexture(c[1], c[2], c[3], 1)
    count:SetTextColor(rgb(kind and Theme.text or Theme.accent))
end

local function badgeKind(s)
    if s.sec == "conv" then return true end
    local sec = KC:SectionOf(s)
    return (sec and sec.quiet) and "quiet" or false
end
UI.PaintBadge = paintBadge

-- for the settings window
UI.Draw = { Solid = Solid, Text = Text, Border = Border, Strokes = Strokes, rgb = rgb }

-- The sidebar is folded into the rail only while the chat is out: with the
-- chat folded in, the stream list is all there is.
local function railed()
    local s = KC.db.settings
    return s.sideCollapsed and not s.chatCollapsed
end

local function sideWidth()
    if railed() then return RAIL_W end
    return KC:Look().symbols and SYMBOL_W or SIDE_W
end

--------------------------------------------------------------------------------
-- Symbols
--------------------------------------------------------------------------------

local fileCache = {}
local function resolveFile(path)
    -- our own files aren't in the game's file list; they're always there
    if not GetFileIDFromPath or path:find("^Interface\\AddOns\\") then return path end
    local id = fileCache[path]
    if id == nil then
        id = call(GetFileIDFromPath, path) or false
        fileCache[path] = id
    end
    return id
end

local function setFile(tex, candidates)
    for _, path in ipairs(candidates) do
        local file = resolveFile(path)
        if file then
            tex:SetTexture(file)
            -- game icons have a border to crop; our own icon doesn't
            if path:find("^Interface\\AddOns\\") then tex:SetTexCoord(0, 1, 0, 1) else tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
            return true
        end
    end
end

-- The symbol of a stream: a class icon for a whisper partner, the channel's own
-- symbol, or the stream's.
function UI.SetSymbol(tex, s)
    if s and s.sec == "conv" and s.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[s.class] then
        local c = CLASS_ICON_TCOORDS[s.class]
        tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
        tex:SetVertexColor(1, 1, 1)
        return
    end
    local list
    if not s then
        list = KC.Symbols.all
    elseif s.bn then
        list = KC.Symbols.bnet
    elseif s.sec == "conv" then
        list = KC.Symbols.whisper
    elseif s.sec == "channels" then
        list = KC.ChannelSymbol(s.label) or KC.Symbols.channel
    else
        list = KC.Symbols[s.key] or KC.Symbols.unknown
    end
    if not setFile(tex, list) then setFile(tex, KC.Symbols.unknown) end
    local tint = s and KC.SymbolTints[s.key]
    if tint then
        local info = ChatTypeInfo and ChatTypeInfo[tint.type]
        if info and info.r then tex:SetVertexColor(info.r, info.g, info.b) else tex:SetVertexColor(tint.r, tint.g, tint.b) end
    else
        tex:SetVertexColor(1, 1, 1)
    end
end

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
            c[self.id] = not c[self.id] -- false, not nil: a default must not come back
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
    w.badgeBg = Solid(w.badge, "ARTWORK", Theme.accent2)
    w.badgeBg:SetAllPoints()
    w.count = Text(w.badge, 9, Theme.text, "CENTER")
    w.count:SetPoint("CENTER", 0, 0)
    w.label = Text(w, 12)
    w.label:SetPoint("LEFT", 20, 0)
    w.label:SetPoint("RIGHT", w.badge, "LEFT", -4, 0)
    w:SetScript("OnEnter", function(self) self.hl:Show() end)
    w:SetScript("OnLeave", function(self) self.hl:Hide() end)
    w:SetScript("OnClick", factories.streamClick)
    return w
end

function factories.streamClick(self, button)
    if button == "RightButton" then
        if self.key ~= "all" then UI:StreamMenu(self, self.key) end
    else
        UI:Select(self.key)
        if KC.db.settings.chatCollapsed then UI:ToggleChat() end
    end
end

-- A stream as a symbol, for /kc symbols. The name is in the tooltip.
function factories.icon(parent)
    local w = CreateFrame("Button", nil, parent)
    w:SetSize(SYMBOL_W, 34)
    w:RegisterForClicks("AnyUp")
    w.hl = Solid(w, "BACKGROUND", Theme.hover)
    w.hl:SetPoint("TOPLEFT", 4, -1)
    w.hl:SetPoint("BOTTOMRIGHT", -4, 1)
    w.hl:Hide()
    w.stripe = Solid(w, "ARTWORK", Theme.accent)
    w.stripe:SetPoint("LEFT", 0, 0)
    w.stripe:SetSize(2, 22)
    w.ring = Solid(w, "BORDER", Theme.accent, 0.9)
    w.ring:SetSize(30, 30)
    w.ring:SetPoint("CENTER", 1, 0)
    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(26, 26)
    w.icon:SetPoint("CENTER", 1, 0)
    -- round themes: a circle mask on the symbol and its ring
    w.mask = w:CreateMaskTexture()
    w.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    w.mask:SetAllPoints(w.icon)
    w.ringMask = w:CreateMaskTexture()
    w.ringMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    w.ringMask:SetAllPoints(w.ring)
    w.badge = CreateFrame("Frame", nil, w)
    w.badge:SetSize(16, 12)
    w.badge:SetPoint("TOPRIGHT", -3, -1)
    w.badge:SetFrameLevel(w:GetFrameLevel() + 3)
    w.badgeBg = Solid(w.badge, "OVERLAY", Theme.accent2)
    w.badgeBg:SetAllPoints()
    w.count = Text(w.badge, 8, Theme.text, "CENTER")
    w.count:SetPoint("CENTER", 0, 0)
    w:SetScript("OnEnter", function(self)
        self.hl:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.label or "", 1, 1, 1)
        if self.unread and self.unread > 0 then GameTooltip:AddLine(self.unread .. " unread", 0.55, 0.42, 0.95) end
        if self.muted then GameTooltip:AddLine("Hidden in All messages", 0.56, 0.6, 0.66) end
        GameTooltip:AddLine("Right-click for options", 0.56, 0.6, 0.66)
        GameTooltip:Show()
    end)
    w:SetScript("OnLeave", function(self)
        self.hl:Hide()
        GameTooltip:Hide()
    end)
    w:SetScript("OnClick", factories.streamClick)
    return w
end

function factories.sep(parent)
    local w = CreateFrame("Frame", nil, parent)
    w:SetSize(SYMBOL_W, 9)
    local line = Solid(w, "ARTWORK", Theme.line)
    line:SetHeight(1)
    line:SetPoint("LEFT", 10, 0)
    line:SetPoint("RIGHT", -8, 0)
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

-- "<" (fold in) or ">" (fold out), drawn with two strokes.
local function Arrow(parent)
    local a = { parent:CreateTexture(nil, "ARTWORK"), parent:CreateTexture(nil, "ARTWORK") }
    for _, s in ipairs(a) do
        s:SetSize(6, 1.5)
        s:SetColorTexture(rgb(Theme.dim))
    end
    function a.Point(dir)
        local sign = dir == "left" and 1 or -1
        a[1]:ClearAllPoints()
        a[2]:ClearAllPoints()
        a[1]:SetPoint("CENTER", parent, "CENTER", 0, 2)
        a[2]:SetPoint("CENTER", parent, "CENTER", 0, -2)
        a[1]:SetRotation(math.rad(45 * sign))
        a[2]:SetRotation(math.rad(-45 * sign))
    end
    function a.Color(color)
        for _, s in ipairs(a) do s:SetColorTexture(rgb(color)) end
    end
    return a
end

function UI:SaveGeometry()
    local f = self.frame
    local point, _, relPoint, x, y = f:GetPoint()
    local win = KC.db.settings.window
    win.point, win.relPoint, win.x, win.y = point, relPoint, x, y
    -- folded to the stream list, the window is narrow; keep the chat's width for later
    if not KC.db.settings.chatCollapsed then win.w = math.floor(f:GetWidth() + 0.5) end
    win.h = math.floor(f:GetHeight() + 0.5)
end

-- Keeps the window inside the screen, with room below or above it for the
-- chat input. A saved size from a bigger screen (or a bad drag) can't stick.
function UI:FitToScreen()
    local f = self.frame
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if not (f and sw and sh and sw > 0 and sh > 0) then return end
    local win = KC.db.settings.window
    if win.w and win.w > sw - 20 then win.w = math.min(DEFAULT_W, sw - 20) end
    if win.h and win.h > sh - 60 then win.h = math.min(DEFAULT_H, sh - 60) end
    local w = math.min(f:GetWidth(), sw - 20)
    local h = math.min(f:GetHeight(), sh - 60)
    if w ~= f:GetWidth() or h ~= f:GetHeight() then f:SetSize(w, h) end
end

function UI:ResetPosition()
    if not self.frame then return end
    KC.db.settings.window = {}
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER")
    KC.db.settings.chatCollapsed = false
    self.frame:SetSize(DEFAULT_W, DEFAULT_H)
    self:ApplyChat()
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
    self:FitToScreen()
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
        UI:FitToScreen()
        UI:SaveGeometry()
        KC:Fire("GEOMETRY") -- the chat input follows (above the window near the bottom edge)
    end)
    f:SetScript("OnShow", function()
        KC.db.settings.shown = true
        UI:Refresh()
    end)
    f:SetScript("OnHide", function()
        KC.db.settings.shown = false
        if UI.menu then UI.menu:Hide() end
    end)
    f:SetScript("OnSizeChanged", function()
        UI:Request("feed")
        KC:Fire("GEOMETRY")
    end)

    if KC:Look().palette == "wow" then
        self.backdrop, self.band = self:CreateWoWFrame(f)
    else
        self.flatBg = self:CreateFlatFrame(f)
    end

    -- header, sidebar, chat
    self:CreateContent(f)
end

-- Krakenfriends' look: deep panel, faint teal glow at the top, teal-to-violet rim.
function UI:CreateFlatFrame(f)
    local bg = Solid(f, "BACKGROUND", Theme.bg)
    bg:SetAllPoints()
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
    return bg
end

-- The game's own look: dark stone inside a gold dialog border, the title in
-- the fantasy font, a dark band behind the header.
local WOW_EDGES = { "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", "Interface\\DialogFrame\\UI-DialogBox-Border" }
local WOW_BACKS = { "Interface\\FrameGeneral\\UI-Background-Rock", "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" }

local function firstFile(list)
    for _, path in ipairs(list) do
        if not GetFileIDFromPath or call(GetFileIDFromPath, path) then return path end
    end
    return list[#list]
end

function UI:CreateWoWFrame(f)
    local frame = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetPoint("TOPLEFT", -7, 7)
    frame:SetPoint("BOTTOMRIGHT", 7, -7)
    frame:SetFrameLevel(math.max(0, f:GetFrameLevel()))
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = firstFile(WOW_BACKS), tile = true, tileSize = 256,
            edgeFile = firstFile(WOW_EDGES), edgeSize = 32,
            insets = { left = 9, right = 9, top = 9, bottom = 9 },
        })
        frame:SetBackdropColor(0.55, 0.55, 0.55, 1)
    end
    local band = Solid(f, "BACKGROUND", { 0, 0, 0 }, 0.45)
    band:SetPoint("TOPLEFT", 2, -2)
    band:SetPoint("TOPRIGHT", -2, -2)
    band:SetHeight(HEADER - 2)
    return frame, band
end

-- The background's opacity (settings: Background). The border and the text
-- stay solid.
function UI:ApplyAlpha()
    if not self.frame then return end
    local a = KC.db.settings.bgAlpha or 1
    if self.backdrop and self.backdrop.SetBackdropColor then self.backdrop:SetBackdropColor(0.55, 0.55, 0.55, a) end
    if self.band then self.band:SetAlpha(a) end
    if self.flatBg then self.flatBg:SetAlpha(a) end
    if self.sideBg then self.sideBg:SetAlpha(a) end
end

-- The header (title, search, close), the sidebar and the chat.
function UI:CreateContent(f)
    local wow = KC:Look().palette == "wow"
    local title = Text(f, wow and 16 or 13, wow and Theme.accent or nil)
    title:SetPoint("TOPLEFT", 12, wow and -9 or -11)
    if wow then
        if not pcall(title.SetFont, title, "Fonts\\MORPHEUS.TTF", 17, "") then title:SetFont(FONT, 15, "") end
        title:SetText("KrakenChat")
    else
        title:SetText("|cff4fd1c5Kraken|rchat")
    end
    self.title = title

    self.viewTitle = Text(f, 11, Theme.dim)
    self.viewTitle:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -8)
    local x = Strokes(close, 11, Theme.dim, { 45, -45 })
    close:SetScript("OnEnter", function() for _, s in ipairs(x) do s:SetColorTexture(1, 1, 1, 1) end end)
    close:SetScript("OnLeave", function() for _, s in ipairs(x) do s:SetColorTexture(Theme.dim[1], Theme.dim[2], Theme.dim[3], 1) end end)
    close:SetScript("OnClick", function() f:Hide() end)

    -- fold the chat in: the window narrows to the stream list
    local chatToggle = CreateFrame("Button", nil, f)
    chatToggle:SetSize(18, 18)
    chatToggle:SetPoint("RIGHT", close, "LEFT", -4, 0)
    chatToggle.arrow = Arrow(chatToggle)
    chatToggle:SetScript("OnEnter", function(self)
        self.arrow.Color(Theme.text)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(KC.db.settings.chatCollapsed and "Show the chat" or "Fold the chat in (streams only)", 1, 1, 1)
        GameTooltip:Show()
    end)
    chatToggle:SetScript("OnLeave", function(self)
        self.arrow.Color(Theme.dim)
        GameTooltip:Hide()
    end)
    chatToggle:SetScript("OnClick", function() UI:ToggleChat() end)
    self.chatToggle = chatToggle

    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(18, 18)
    gear:SetPoint("RIGHT", chatToggle, "LEFT", -2, 0)
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetSize(14, 14)
    gear.icon:SetPoint("CENTER")
    gear.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear.icon:SetVertexColor(rgb(Theme.dim))
    gear:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(rgb(Theme.text))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(rgb(Theme.dim))
        GameTooltip:Hide()
    end)
    gear:SetScript("OnClick", function() KC.Options:Toggle() end)
    self.gear = gear

    self:CreateSearch(f, gear, title)

    local headLine = Solid(f, "ARTWORK", Theme.line)
    headLine:SetHeight(1)
    headLine:SetPoint("TOPLEFT", 1, -HEADER)
    headLine:SetPoint("TOPRIGHT", -1, -HEADER)

    -- sidebar
    local sideBg = Solid(f, "BACKGROUND", Theme.side)
    sideBg:SetPoint("TOPLEFT", 1, -HEADER - 1)
    sideBg:SetPoint("BOTTOMLEFT", 1, 1)
    local sideLine = Solid(f, "ARTWORK", Theme.line)
    sideLine:SetWidth(1)
    self.sideBg, self.sideLine = sideBg, sideLine

    local side = CreateFrame("ScrollFrame", nil, f)
    side:SetPoint("TOPLEFT", 1, -HEADER - 1)
    side:SetPoint("BOTTOMLEFT", 1, 28)
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
    self:CreateRail(f)

    -- feed
    local scroll = CreateFrame("ScrollFrame", nil, f)
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
    self.grip = grip
    -- Our own resizing: the game's StartSizing snaps the corner to the cursor,
    -- which sits a few pixels inside the corner, so every click grew the window.
    -- Here the size only changes by how far the mouse moves; the top-left
    -- corner stays put and the window never grows past the screen.
    grip:SetScript("OnMouseDown", function() UI:BeginResize() end)
    grip:SetScript("OnMouseUp", function() UI:EndResize() end)
    grip:SetScript("OnHide", function() UI:EndResize() end)

    self:ApplyChat()
    self:ApplyAlpha()
end

--------------------------------------------------------------------------------
-- Folding the sidebar in: a slim rail with the unread count, so the chat gets
-- the whole width. The window remembers it.
--------------------------------------------------------------------------------

function UI:CreateRail(f)
    local toggle = CreateFrame("Button", nil, f)
    toggle:SetSize(24, 24)
    toggle:SetPoint("BOTTOMLEFT", 4, 3)
    toggle.arrow = Arrow(toggle)
    toggle:SetScript("OnEnter", function(self)
        self.arrow.Color(Theme.text)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(KC.db.settings.sideCollapsed and "Show the streams" or "Fold the streams in", 1, 1, 1)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function(self)
        self.arrow.Color(Theme.dim)
        GameTooltip:Hide()
    end)
    toggle:SetScript("OnClick", function() UI:ToggleSide() end)
    self.sideToggle = toggle


    -- while folded in: unread messages, click to fold out
    local badge = CreateFrame("Button", nil, f)
    badge:SetSize(22, 16)
    badge:SetPoint("TOPLEFT", 4, -HEADER - 10)
    badge.bg = Solid(badge, "ARTWORK", Theme.accent2)
    badge.bg:SetAllPoints()
    badge.count = Text(badge, 9, Theme.text, "CENTER")
    badge.count:SetPoint("CENTER", 0, 0)
    badge:SetScript("OnClick", function() UI:ToggleSide() end)
    badge:Hide()
    self.railBadge = badge
end

function UI:ApplySide()
    local collapsed = railed()
    local w = sideWidth()
    self.sideBg:SetWidth(w)
    self.side:SetWidth(w)
    self.sideChild:SetWidth(w)
    self.sideLine:ClearAllPoints()
    self.sideLine:SetPoint("TOPLEFT", w + 1, -HEADER - 1)
    self.sideLine:SetPoint("BOTTOMLEFT", w + 1, 1)
    self.side:SetShown(not collapsed)
    self.scroll:SetPoint("TOPLEFT", w + PAD + 1, -HEADER - 6)
    self.footer:SetPoint("BOTTOMLEFT", w + PAD + 1, 6)
    self.sideToggle.arrow.Point(collapsed and "right" or "left")
    self.sideToggle:SetShown(not KC.db.settings.chatCollapsed)
    self:UpdateRail()
end

--------------------------------------------------------------------------------
-- Folding the chat in: the window narrows to just the stream list with its
-- unread badges, like a buddy list. Clicking a stream opens the chat on it.
--------------------------------------------------------------------------------

local CHAT_PARTS = { "scroll", "track", "thumb", "empty", "footer" }

function UI:ApplyChat()
    local f, folded = self.frame, KC.db.settings.chatCollapsed and true or false
    local win = KC.db.settings.window
    local narrow = sideWidth() + 2
    for _, key in ipairs(CHAT_PARTS) do self[key]:SetShown(not folded) end
    if folded then
        -- the chat comes back at the bottom (ToggleChat), so nothing is "new below"
        self.newBelow = 0
        self.pill:Hide()
        if self.search:IsShown() then
            self.search:SetText("")
            self.search:Hide()
        end
        if f.SetResizeBounds then f:SetResizeBounds(narrow, MIN_H, narrow, 2000) end
        f:SetWidth(narrow)
    else
        if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H) end
        f:SetWidth(math.max(MIN_W, win.w or DEFAULT_W))
    end
    self:FitToScreen()
    self.chatToggle.arrow.Point(folded and "right" or "left")
    -- folded with symbols, the window is only a column wide: no room for the title
    self.title:SetShown(not (folded and KC:Look().symbols))
    self:ApplySide()
    self:RefreshHeader()
end

function UI:ToggleChat()
    local settings = KC.db.settings
    if not settings.chatCollapsed then self:SaveGeometry() end -- the width to come back to
    settings.chatCollapsed = not settings.chatCollapsed
    self:ApplyChat()
    self:SaveGeometry()
    if not settings.chatCollapsed then
        self.atBottom = true
        KC:MarkRead(settings.view)
    end
    self:RenderSidebar()
    self:RenderFeed()
end

function UI:UpdateRail()
    if not self.railBadge then return end
    local unread, whispers = 0, false
    if KC.db.settings.sideCollapsed then
        for _, s in pairs(KC.char.streams) do
            local sec = KC:SectionOf(s)
            if sec and sec.personal then unread = unread + s.unread end
            if s.sec == "conv" and s.unread > 0 then whispers = true end
        end
    end
    self.railBadge.count:SetText(unread > 99 and "99+" or tostring(unread))
    self.railBadge:SetShown(unread > 0)
    paintBadge(self.railBadge.bg, self.railBadge.count, whispers)
end

function UI:ToggleSide()
    local settings = KC.db.settings
    settings.sideCollapsed = not settings.sideCollapsed or nil
    self:ApplySide()
    self:RenderSidebar()
    self:RenderFeed()
end

-- A magnifier in the header; the search box only shows while you search.
function UI:BeginResize()
    local f = self.frame
    local left, top = f:GetLeft(), f:GetTop()
    if not (left and top) then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    local scale = f:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local start = { x = cx / scale, y = cy / scale, w = f:GetWidth(), h = f:GetHeight(), left = left, top = top }
    self.resizing = start
    self.grip:SetScript("OnUpdate", function()
        local mx, my = GetCursorPosition()
        UI:ResizeTo(start.w + (mx / scale - start.x), start.h - (my / scale - start.y))
    end)
end

-- Sets the size within the limits: the window's minimum, the screen, and in
-- the folded-in view a fixed width.
function UI:ResizeTo(w, h)
    local f, s = self.frame, self.resizing
    local folded = KC.db.settings.chatCollapsed
    local minW = folded and (sideWidth() + 2) or MIN_W
    local maxW = folded and minW or math.max(minW, (UIParent:GetWidth() or 2000) - (s and s.left or 0))
    local maxH = math.max(MIN_H, (s and s.top) or (UIParent:GetHeight() or 2000))
    f:SetSize(math.max(minW, math.min(maxW, w)), math.max(MIN_H, math.min(maxH, h)))
end

function UI:EndResize()
    if not self.resizing then return end
    self.resizing = nil
    self.grip:SetScript("OnUpdate", nil)
    self:FitToScreen()
    self:SaveGeometry()
    self:RenderFeed()
end

function UI:CreateSearch(f, anchor, title)
    local glass = CreateFrame("Button", nil, f)
    glass:SetSize(18, 18)
    glass:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    glass.icon = glass:CreateTexture(nil, "ARTWORK")
    glass.icon:SetSize(13, 13)
    glass.icon:SetPoint("CENTER")
    glass.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    glass.icon:SetVertexColor(rgb(Theme.dim))
    glass:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(rgb(Theme.text))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Search", 1, 1, 1)
        GameTooltip:Show()
    end)
    glass:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(rgb(Theme.dim))
        GameTooltip:Hide()
    end)
    self.glass = glass

    local box = CreateFrame("EditBox", nil, f)
    box:SetHeight(20)
    box:SetPoint("RIGHT", glass, "LEFT", -4, 0)
    box:SetPoint("LEFT", title, "RIGHT", 10, 0)
    box:Hide()
    glass:SetScript("OnClick", function()
        if box:IsShown() and (box:GetText() or "") == "" then
            box:Hide()
        else
            box:Show()
            box:SetFocus()
        end
        UI:RefreshHeader()
    end)
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

    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function() box.placeholder:Hide() end)
    box:SetScript("OnEditFocusLost", function(self)
        -- an empty search folds back into the magnifier
        if (self:GetText() or "") == "" then
            self:Hide()
            UI:RefreshHeader()
        else
            box.placeholder:Hide()
        end
    end)
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
    -- only over an open chat: never over the folded-in stream list
    if self.newBelow > 0 and not self.atBottom and not KC.db.settings.chatCollapsed then
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
        w.body:SetText(Feed:Line(m, s, all, item.cont))
    end
    local h = KC.clean(w.body:GetStringHeight()) or size
    if type(h) ~= "number" or h < size then h = size end
    h = math.floor(h + 0.5) + top + 2
    w:SetHeight(h)
    return h
end

function UI:RenderFeed()
    if not (self.frame and self.frame:IsShown()) or KC.db.settings.chatCollapsed then
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
    local width = math.max(100, self.frame:GetWidth() - sideWidth() - PAD * 2 - 8)
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
    -- with names in the sidebar the open stream is plain to see; with symbols
    -- its name goes in the header (unless the search box is there)
    local folded = KC.db.settings.chatCollapsed
    self.viewTitle:SetShown(not folded and KC:Look().symbols and not self.search:IsShown())
    self.glass:SetShown(not folded)
    self.gear:SetShown(not folded)
    local reply = self:ReplyText(view)
    self.footer:SetShown(reply ~= nil and not folded)
    if reply then self.footer.text:SetText(reply) end
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
    if unread > 0 then paintBadge(w.badgeBg, w.count, badgeKind(s)) end
end

function UI:RenderSidebar()
    if not (self.frame and self.frame:IsShown()) then
        self.dirty = true
        return
    end
    self:UpdateRail()
    release({ "section", "stream", "icon", "sep" })
    if KC:Look().symbols then return self:RenderSymbols() end
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
                h.extra:SetText(KC.Colorize(tostring(unread), rgb((sec.id == "conv" and { 1, 0.3, 0.25 }) or (sec.quiet and Theme.dim) or Theme.accent)))
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

local function fillIcon(w, key, label, s)
    local selected = KC.db.settings.view == key
    w.key, w.label = key, label
    w.unread = s and s.unread or 0
    w.muted = key ~= "all" and KC:IsMuted(key)
    w.stripe:SetShown(selected)
    w.ring:SetShown(selected)
    UI.SetSymbol(w.icon, s)
    local round = KC:Look().round and true or false
    if w.round ~= round then
        w.round = round
        if round then
            w.icon:AddMaskTexture(w.mask)
            w.ring:AddMaskTexture(w.ringMask)
        else
            w.icon:RemoveMaskTexture(w.mask)
            w.ring:RemoveMaskTexture(w.ringMask)
        end
    end
    if w.icon.SetDesaturated then w.icon:SetDesaturated(w.muted) end
    w.icon:SetAlpha(w.muted and 0.45 or 1)
    w.badge:SetShown(w.unread > 0)
    w.count:SetText(w.unread > 99 and "99" or tostring(w.unread))
    if w.unread > 0 then paintBadge(w.badgeBg, w.count, badgeKind(s)) end
end

-- The sidebar as one column of symbols, sections apart by a thin line.
function UI:RenderSymbols()
    local child = self.sideChild
    local y = 6
    local w = acquire("icon", child)
    w:SetPoint("TOPLEFT", 0, -y)
    fillIcon(w, "all", "All messages", nil)
    y = y + 34

    local bySection = {}
    for _, s in pairs(KC.char.streams) do
        if s.sec and #s.msgs > 0 then
            bySection[s.sec] = bySection[s.sec] or {}
            table.insert(bySection[s.sec], s)
        end
    end
    for _, sec in ipairs(KC.Sections) do
        local list = bySection[sec.id]
        if list then
            sortStreams(sec.id, list)
            local line = acquire("sep", child)
            line:SetPoint("TOPLEFT", 0, -y)
            y = y + 9
            for _, s in ipairs(list) do
                local row = acquire("icon", child)
                row:SetPoint("TOPLEFT", 0, -y)
                fillIcon(row, s.key, s.label, s)
                y = y + 34
            end
        end
    end
    child:SetHeight(y + 6)
end

-- Switching the look opens the chat, so it shows in full.
function UI:SetLook(style, sidebar)
    local settings = KC.db.settings
    if settings.chatCollapsed then self:SaveGeometry() end
    settings.style, settings.sidebar = style, sidebar
    settings.chatCollapsed = false
    if not self.frame:IsShown() then self.frame:Show() end
    self:ApplyChat()
    self:SaveGeometry()
    self:RenderSidebar()
    self:RenderFeed()
    -- a different frame and colours are built at load
    if KC:Look().palette ~= KC.palette and StaticPopup_Show then StaticPopup_Show("KRAKENCHAT_RELOAD") end
end

function UI:Select(key)
    KC.db.settings.view = key
    -- the open stream is never hidden in a folded section
    local s = KC:Stream(key)
    if s and s.sec then KC.db.settings.collapsed[s.sec] = false end
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
            settings.muted[key] = not muted
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
        local who = (s.sec == "conv" and s.who) or m.p
        local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
        if who and invite then
            entries[#entries + 1] = { text = "Invite to group", func = function() pcall(invite, who) end }
        end
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

KC:Listen("MESSAGE", function(m, s, isRepeat)
    -- a whisper brings the chat back, closed or folded in, open on its conversation
    local settings = KC.db.settings
    if s.sec == "conv" and not m.o and not isRepeat and settings.openOnWhisper and not KC.demoing then
        local closed = not (UI.frame and UI.frame:IsShown())
        if closed or settings.chatCollapsed then
            UI:Show()
            UI:Select(s.key)
            if settings.chatCollapsed then UI:ToggleChat() end
            return
        end
    end
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
