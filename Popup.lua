local _, KC = ...
local Theme = KC.Theme

--------------------------------------------------------------------------------
-- Pop-up: a whisper (or, if wanted, a party or raid line) opens a folded-in or
-- closed chat on that conversation. With "go back", it returns after a few
-- seconds unless you point at it, click or type: a thin gold line along the
-- bottom runs out meanwhile, then the window slides back to the stream list or
-- fades out. The lines it showed stay unread, so their badges remain.
--------------------------------------------------------------------------------

local Popup = {}
KC.Popup = Popup

Popup.DURATION = 5   -- seconds before going back
Popup.ANIM = 0.3     -- the slide or fade

local timer = CreateFrame("Frame")
timer:Hide()
Popup.timer = timer

local function isGroup(key)
    return key == "party" or key == "raid" or key == "instance"
end

-- Does this new line open the chat? Returns true if it did.
function Popup:Consider(m, s, isRepeat)
    local settings = KC.db.settings
    local UI = KC.UI
    local group = isGroup(s.key)
    local wanted = (s.sec == "conv" and settings.openOnWhisper) or (group and settings.openOnGroup and not m.sys)
    if not wanted or m.o or isRepeat or KC.demoing then return false end

    local closed = not (UI.frame and UI.frame:IsShown())
    local folded = settings.chatCollapsed
    if closed then
        if not settings.popWhenClosed then return false end
    elseif folded then
        if not settings.popWhenFolded then return false end
    else
        return false -- already open: the badge does the rest
    end

    -- what to go back to (a second pop-up during the first keeps the first's)
    local back = self.active and self.active.back or { closed = closed, folded = folded }
    local target = group and KC:GroupViewKey() or s.key
    local keys = KC:ViewKeys(target) or { target }
    local unread = self.active and self.active.unread or {}
    for _, k in ipairs(keys) do
        local st = KC:Stream(k)
        if st then unread[k] = math.max(unread[k] or 0, st.unread) end
    end

    UI:Show()
    UI.frame:SetAlpha(1)
    UI:Select(target)
    if settings.chatCollapsed then UI:ToggleChat() end

    if settings.popReturn then
        self:Start(back, unread)
    else
        self:Stop()
    end
    return true
end

function Popup:Line()
    local UI = KC.UI
    if not self.line then
        self.line = UI.frame:CreateTexture(nil, "OVERLAY")
        self.line:SetHeight(2)
        self.line:SetPoint("BOTTOMLEFT", UI.frame, "BOTTOMLEFT", 3, 3)
        self.line:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.9)
    end
    return self.line
end

-- You're using it: it stays.
local function interacting()
    local UI = KC.UI
    if UI.frame:IsMouseOver() then return true end
    local box = ChatFrame1EditBox
    if box and box.HasFocus and box:HasFocus() then return true end
    if UI.search and UI.search.HasFocus and UI.search:HasFocus() then return true end
    return false
end

function Popup:Start(back, unread)
    self.active = { back = back, unread = unread, t = 0 }
    self:Line():Show()
    timer:SetScript("OnUpdate", function(_, elapsed) Popup:Tick(elapsed) end)
    timer:Show()
end

function Popup:Stop()
    self.active = nil
    if self.line then self.line:Hide() end
    timer:SetScript("OnUpdate", nil)
    timer:Hide()
end

function Popup:Tick(elapsed)
    local a = self.active
    if not a then return self:Stop() end
    local UI = KC.UI
    if not a.going then
        if interacting() or not UI.frame:IsShown() or KC.db.settings.chatCollapsed then return self:Stop() end
        a.t = a.t + elapsed
        local left = math.max(0, 1 - a.t / self.DURATION)
        self:Line():SetWidth(math.max(1, (UI.frame:GetWidth() - 6) * left))
        if a.t >= self.DURATION then
            a.going, a.t = true, 0
            a.width = UI.frame:GetWidth()
            self:Line():Hide()
        end
        return
    end
    -- the way back: fade out (closed before) or slide to the stream list (folded before)
    a.t = a.t + elapsed
    local p = math.min(1, a.t / self.ANIM)
    if a.back.closed then
        UI.frame:SetAlpha(1 - p)
    else
        UI.frame:SetWidth(a.width - (a.width - UI.FoldedWidth()) * p)
    end
    if p >= 1 then self:Finish() end
end

function Popup:Finish()
    local a = self.active
    self:Stop()
    if not a then return end
    local UI = KC.UI
    local settings = KC.db.settings
    if not a.back.closed then UI.frame:SetWidth(a.width) end -- ToggleChat saves the real width first
    if a.back.folded and not settings.chatCollapsed then UI:ToggleChat() end
    if a.back.closed then
        UI.frame:Hide()
        UI.frame:SetAlpha(1)
    end
    -- you didn't look: the lines stay unread
    for key, n in pairs(a.unread) do
        local s = KC:Stream(key)
        if s and n > s.unread then s.unread = n end
    end
    KC:Fire("UNREAD")
end
