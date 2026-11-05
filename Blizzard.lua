local _, KC = ...

--------------------------------------------------------------------------------
-- Hiding the game's chat windows (on by default, /kc blizzard switches it).
--
-- The chat frames, their tabs and the chat buttons go into a hidden frame; the
-- game keeps running them, it just doesn't draw them. The chat input
-- (ChatFrame1EditBox) stays: it moves under the KrakenChat window, so Enter,
-- slash commands and shift-click links work as always.
--
-- Messages that only ever go to the chat window (addon prints, /played, error
-- notes from other addons) are copied into the "Addon messages" stream, so
-- nothing disappears with the window.
--------------------------------------------------------------------------------

local Blizz = {}
KC.Blizzard = Blizz

local hidden = CreateFrame("Frame")
hidden:Hide()

local BUTTONS = {
    "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton",
    "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "FriendsMicroButton",
}

local saved = {} -- frame -> its parent before we moved it
local editPoints -- the chat input's anchors before we moved it

local function frames()
    local list = {}
    local n = NUM_CHAT_WINDOWS or 10
    for i = 1, n do
        for _, suffix in ipairs({ "", "Tab", "ButtonFrame" }) do
            local f = _G["ChatFrame" .. i .. suffix]
            if f then list[#list + 1] = f end
        end
    end
    for _, name in ipairs(BUTTONS) do
        if _G[name] then list[#list + 1] = _G[name] end
    end
    return list
end

local function editBox()
    return ChatFrame1EditBox
end

--------------------------------------------------------------------------------
-- The chat input: in KrakenChat's look, and only there while you type.
--------------------------------------------------------------------------------

local skin -- our textures on the chat input
local dimmed = {} -- the game's own textures we made invisible

local function styleEditBox(box)
    local Theme = KC.Theme
    for _, region in ipairs({ box:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and not (skin and skin[region]) then
            dimmed[region] = region:GetAlpha()
            region:SetAlpha(0)
        end
    end
    if not skin then
        skin = {}
        local function tex(layer, c, a)
            local t = box:CreateTexture(nil, layer)
            t:SetColorTexture(c[1], c[2], c[3], a)
            skin[t] = true
            return t
        end
        local fill = Theme.input or Theme.bg
        local bg = tex("BACKGROUND", fill, fill[4])
        bg:SetPoint("TOPLEFT", 0, -2)
        bg:SetPoint("BOTTOMRIGHT", 0, 2)
        local edge = tex("BORDER", Theme.accent, 0.6)
        edge:SetPoint("TOPLEFT", bg, "TOPLEFT")
        edge:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT")
        edge:SetWidth(2)
        local line = tex("BORDER", Theme.accent, 0.35)
        line:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT")
        line:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT")
        line:SetHeight(1)
    end
    for t in pairs(skin) do t:Show() end
end

local function unstyleEditBox()
    for region, alpha in pairs(dimmed) do region:SetAlpha(alpha) end
    wipe(dimmed)
    if skin then for t in pairs(skin) do t:Hide() end end
end

-- Takes the input out of sight once you're done typing (the game keeps it on
-- screen otherwise). Faded out, not hidden: hiding or showing it runs the
-- game's chat code, and run from here that code notes the active chat input
-- with KrakenChat's taint. The game then refuses protected actions that read
-- it, such as copying a shared map pin's /way command to the clipboard. The
-- game makes it visible again itself when you press Enter.
local function tuckAway(box)
    if not Blizz.active or box ~= editBox() then return end
    if box.HasFocus and box:HasFocus() then return end
    box:SetAlpha(0)
end

-- After the game's own function, without changing what it does.
local function after(name, fn)
    if not hooksecurefunc then return end
    if ChatFrameUtil and ChatFrameUtil[name] then
        hooksecurefunc(ChatFrameUtil, name, fn)
    elseif _G["ChatEdit_" .. name] then
        hooksecurefunc("ChatEdit_" .. name, fn)
    end
end

-- Puts the chat input under the KrakenChat window, at least wide enough to type in.
function Blizz:PlaceEditBox()
    local box, win = editBox(), KC.UI.frame
    if not (self.active and box and win) then return end
    box:ClearAllPoints()
    local bottom = win:GetBottom()
    if bottom and bottom < 36 then
        -- no room below the window: the input goes above it, never off the screen
        box:SetPoint("BOTTOMLEFT", win, "TOPLEFT", 0, 4)
    else
        box:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, -2)
    end
    box:SetWidth(math.max(360, win:GetWidth()))
end

function Blizz:Hide()
    if self.active then return end
    self.active = true
    -- the input first: hidden along with its chat window, the game would note
    -- a new active chat input from here (see tuckAway)
    local box = editBox()
    if box then
        if not editPoints then
            editPoints = {}
            for i = 1, (box.GetNumPoints and box:GetNumPoints() or 0) do editPoints[i] = { box:GetPoint(i) } end
            editPoints.parent = box:GetParent()
        end
        pcall(box.SetParent, box, UIParent)
        if not self.hooked and box.HookScript then
            self.hooked = true
            -- the game re-anchors the input now and then; put it back when it opens
            box:HookScript("OnShow", function() Blizz:PlaceEditBox() end)
            box:HookScript("OnEditFocusLost", function(b)
                if (b:GetText() or "") == "" then tuckAway(b) end
            end)
            after("DeactivateChat", tuckAway)
            -- the game shows it when you press Enter; we only put it in place
            after("ActivateChat", function(b)
                if b == editBox() then Blizz:PlaceEditBox() end
            end)
        end
        styleEditBox(box)
        self:PlaceEditBox()
        tuckAway(box)
    end
    for _, f in ipairs(frames()) do
        if saved[f] == nil then
            saved[f] = f:GetParent() or false
            pcall(f.SetParent, f, hidden)
        end
    end
end

function Blizz:Restore()
    if not self.active then return end
    self.active = false
    for f, parent in pairs(saved) do
        if parent then pcall(f.SetParent, f, parent) end
    end
    wipe(saved)
    local box = editBox()
    if box and editPoints then
        unstyleEditBox()
        box:SetAlpha(1)
        pcall(box.SetParent, box, editPoints.parent or ChatFrame1)
        box:ClearAllPoints()
        for _, p in ipairs(editPoints) do box:SetPoint(unpack(p)) end
        editPoints = nil
    end
end

function Blizz:Apply()
    if KC.db.settings.hideBlizzard then self:Hide() else self:Restore() end
end

--------------------------------------------------------------------------------
-- Printed messages. Chat events reach the window with their chat type id as
-- the fifth argument; a plain print has none.
--------------------------------------------------------------------------------

local function onAddMessage(_, text, r, g, b, id)
    if not (Blizz.active and KC.ready) or id ~= nil then return end
    if KC.IsSecret(text) or type(text) ~= "string" or text == "" then return end
    local s = KC:EnsureStream("addons")
    KC:Add(s, { t = KC.Now(), k = "SYSTEM", f = "plain", x = text })
end

KC:Listen("LOGIN", function()
    if DEFAULT_CHAT_FRAME and hooksecurefunc then
        hooksecurefunc(DEFAULT_CHAT_FRAME, "AddMessage", onAddMessage)
    end
    KC.UI:Create()
    Blizz:Apply()
end)

KC:Listen("GEOMETRY", function() Blizz:PlaceEditBox() end)
