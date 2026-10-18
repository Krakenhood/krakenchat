local _, KC = ...
local Theme = KC.Theme
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

--------------------------------------------------------------------------------
-- Minimap button. A violet dot shows unread whispers.
--------------------------------------------------------------------------------

local button

local function updatePosition()
    local angle = math.rad(KC.db.settings.minimap.angle or 225)
    local radius = Minimap:GetWidth() / 2 + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function updateState()
    if not button then return end
    button:SetShown(not KC.db.settings.minimap.hide)
    local unread = KC:UnreadConversations()
    button.pip:SetShown(unread > 0)
    button.pip.count:SetText(unread > 9 and "9+" or tostring(unread))
end

local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff4fd1c5Kraken|rchat")
    local unread, list = KC:UnreadConversations()
    if unread > 0 then
        for i, s in ipairs(list) do
            if i > 6 then break end
            local r, g, b = KC.ClassColor(s.class)
            GameTooltip:AddDoubleLine(s.label, s.unread .. " new", r or 1, g or 1, b or 1, 0.55, 0.42, 0.95)
        end
    else
        GameTooltip:AddLine("No unread whispers.", 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: open or close   Right-click: settings   Drag: move", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function createButton()
    button = CreateFrame("Button", "KrakenChatMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture(KC.IconFileBare)
    -- round like the other minimap buttons
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- unread whispers: a round red badge with the count, like the sidebar's
    local pip = CreateFrame("Frame", nil, button)
    pip:SetSize(15, 15)
    pip:SetPoint("BOTTOMRIGHT", -2, 3)
    pip:SetFrameLevel(button:GetFrameLevel() + 2)
    pip.ring = pip:CreateTexture(nil, "ARTWORK", nil, 1)
    pip.ring:SetAllPoints()
    pip.ring:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    pip.dot = pip:CreateTexture(nil, "ARTWORK", nil, 2)
    pip.dot:SetPoint("TOPLEFT", 1.5, -1.5)
    pip.dot:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
    pip.dot:SetColorTexture(Theme.accent2[1], Theme.accent2[2], Theme.accent2[3], 1)
    for _, t in ipairs({ pip.ring, pip.dot }) do
        local m = pip:CreateMaskTexture()
        m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(t)
        t:AddMaskTexture(m)
    end
    pip.count = pip:CreateFontString(nil, "OVERLAY")
    KC.SetFont(pip.count, 9)
    pip.count:SetPoint("CENTER", 0, 0)
    pip.count:SetTextColor(1, 1, 1)
    button.pip = pip

    button:SetScript("OnClick", function(_, which)
        if which == "RightButton" then KC.Options:Toggle() else KC.UI:Toggle() end
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            KC.db.settings.minimap.angle = math.deg(atan2(py / scale - my, px / scale - mx))
            updatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    updatePosition()
    updateState()
end

-- Retail's addon compartment (the button under the minimap) calls this
-- global, named in the .toc.
function KrakenChat_OnAddonCompartmentClick()
    KC.UI:Toggle()
end

KC:Listen("LOGIN", createButton)
KC:Listen("SETTINGS", updateState)
KC:Listen("UNREAD", updateState)
