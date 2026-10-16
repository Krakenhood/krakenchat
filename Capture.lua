local _, KC = ...
local clean = KC.clean
local call = KC.call

--------------------------------------------------------------------------------
-- Streams: one list of messages per conversation, group chat, channel or kind
-- of game message. Everything the window shows is built from these.
--------------------------------------------------------------------------------

local DEDUPE_WINDOW = 600 -- seconds: a repeat within this time is counted, not shown again
local DEDUPE_LOOKBACK = 40

function KC:Stream(key)
    return self.char.streams[key]
end

-- Gets or makes a stream. `info` fills a new stream (label, section, ...).
function KC:EnsureStream(key, info)
    local s = self.char.streams[key]
    if not s then
        s = { key = key, msgs = {}, unread = 0, last = 0 }
        local fixed = KC.Fixed[key]
        for k, v in pairs(fixed or info or {}) do s[k] = v end
        self.char.streams[key] = s
        self:Fire("STREAMS")
    elseif info then
        -- a channel or a partner can change spelling or index; keep the latest
        for k, v in pairs(info) do
            if k ~= "sec" and v ~= nil then s[k] = v end
        end
    end
    return s
end

function KC:StreamCap(s)
    return s.cap or (s.sec == "conv" and KC.WhisperCap) or KC.ChannelCap
end

-- Does this stream fold into one line in "All messages"?
function KC:Folds(s)
    local o = self.db.settings.fold[s.key]
    if o ~= nil then return o end
    return s.fold and true or false
end

function KC:IsMuted(key)
    return self.db.settings.muted[key] and true or false
end

-- Is the stream on screen right now (so its new messages are read already)?
function KC:IsViewing(key)
    local UI = self.UI
    if not (UI and UI.frame and UI.frame:IsShown() and UI.atBottom ~= false) then return false end
    if self.db.settings.chatCollapsed then return false end
    return self.db.settings.view == key
end

function KC:MarkRead(key)
    local s = self.char.streams[key]
    if s and s.unread > 0 then
        s.unread = 0
        self:Fire("UNREAD")
    end
end

function KC:UnreadConversations()
    local n, list = 0, {}
    for key, s in pairs(self.char.streams) do
        if s.sec == "conv" and s.unread > 0 then
            n = n + s.unread
            list[#list + 1] = s
        end
    end
    table.sort(list, function(a, b) return a.last > b.last end)
    return n, list
end

--------------------------------------------------------------------------------
-- Who is who
--------------------------------------------------------------------------------

local classByName = {}

local function classOf(guid, name)
    local class
    if type(guid) == "string" and guid ~= "" and GetPlayerInfoByGUID then
        local _, token = call(GetPlayerInfoByGUID, guid)
        class = token
    end
    local norm = name and KC.NormName(name)
    if class and norm then classByName[norm] = class end
    return class or (norm and classByName[norm])
end
KC.ClassOf = classOf

local function isMe(name)
    local me = KC.me
    if not (me and type(name) == "string") then return false end
    local n = KC.NormName(name)
    return n == KC.NormName(me.name) or (me.realm ~= nil and n == KC.NormName(me.name .. "-" .. me.realm))
end
KC.IsMe = isMe

-- Battle.net whispers name the friend with a protected "|K...|k" string. The
-- BattleTag ("Thalia#1234") is plain text and stays the same across sessions.
local function bnetInfo(bnID)
    if not (C_BattleNet and C_BattleNet.GetAccountInfoByID and bnID) then return nil end
    local ok, info = pcall(C_BattleNet.GetAccountInfoByID, bnID)
    info = ok and clean(info) or nil
    if type(info) ~= "table" then return nil end
    local tag = clean(info.battleTag)
    if type(tag) ~= "string" or tag == "" then return nil end
    return tag
end

local function channelName(base, display)
    base = (type(base) == "string" and base ~= "" and base) or (type(display) == "string" and display:gsub("^%d+%.%s*", "")) or nil
    if not base then return nil end
    return (base:gsub("%s+%-%s+.*$", "")) -- "Trade - City" and "General - Elwynn Forest" become "Trade", "General"
end

--------------------------------------------------------------------------------
-- Capturing
--------------------------------------------------------------------------------

local function sameText(a, b)
    return type(a) == "string" and a == b
end

function KC:Add(s, msg)
    local list = s.msgs
    -- the same line again from the same person (trade spam, macros): count it
    if s.dedupe and not msg.secret and not msg.o then
        for i = #list, math.max(1, #list - DEDUPE_LOOKBACK), -1 do
            local m = list[i]
            if (msg.t - (m.l or m.t)) > DEDUPE_WINDOW then break end
            if not m.secret and m.a == msg.a and sameText(m.x, msg.x) then
                m.n = (m.n or 1) + 1
                m.l = msg.t
                s.last = msg.t
                self:Fire("MESSAGE", m, s, true)
                return m
            end
        end
    end

    msg.id = self.char.nextId
    self.char.nextId = msg.id + 1
    list[#list + 1] = msg
    local cap = self:StreamCap(s)
    while #list > cap do table.remove(list, 1) end
    s.last = msg.t

    local section = self:SectionOf(s)
    if section and section.personal and not msg.o and not self:IsViewing(s.key) and not self.demoing then
        s.unread = s.unread + 1
        self:Fire("UNREAD")
    end
    self:Fire("MESSAGE", msg, s, false)
    return msg
end

function KC:SectionOf(s)
    for _, sec in ipairs(KC.Sections) do
        if sec.id == s.sec then return sec end
    end
end

-- Turns one CHAT_MSG_ event into a message in its stream.
function KC:Capture(event, text, sender, _, channel, target, _, _, chanIndex, chanBase, _, _, guid, bnID)
    local ctype = event:sub(10) -- "CHAT_MSG_PARTY" -> "PARTY"
    local def = KC.Events[ctype]
    if not def or not self.char or not self.me then return end

    local secret = KC.IsSecret(text)
    sender, channel, target, chanIndex, chanBase, guid, bnID =
        clean(sender), clean(channel), clean(target), clean(chanIndex), clean(chanBase), clean(guid), clean(bnID)
    if not secret and type(text) ~= "string" then return end
    if type(sender) ~= "string" then sender = nil end
    if sender == "" then sender = nil end

    local msg = { t = KC.Now(), k = def.color or ctype, f = def.form }
    if secret then msg.secret = true end
    msg.x = text
    if def.leader then msg.ld = true end
    if def.warning then msg.w = true end
    if def.subst and not secret and sender and text:find("%s", 1, true) then
        msg.x = text:gsub("%%s", (sender:gsub("%%", "%%%%")), 1)
    end

    local s
    if def.stream == "whisper" then
        if not sender then return end
        s = self:EnsureStream("w:" .. KC.NormName(KC.LocalName(sender)), { sec = "conv", label = KC.ShortName(sender), who = sender, tag = "Whisper" })
        local class = classOf(guid, sender)
        if class then s.class = class end
        msg.o = def.out or nil
        msg.a = def.out and self.me.name or KC.ShortName(sender)
        msg.c = def.out and self.me.class or class
    elseif def.stream == "bnet" then
        local tag = bnetInfo(bnID)
        if not tag then return end
        local name = tag:match("^[^#]+") or tag
        s = self:EnsureStream("bn:" .. tag, { sec = "conv", label = name, bn = tag, tag = "Battle.net" })
        msg.o = def.out or nil
        msg.a = def.out and self.me.name or name
        msg.c = def.out and self.me.class or nil
    elseif def.stream == "channel" then
        local name = channelName(chanBase, channel)
        if not name then return end
        local key = "ch:" .. name:lower()
        s = self:EnsureStream(key, {
            sec = "channels", label = name, tag = KC.ChannelTags[name:lower():gsub("%s", "")] or name,
            chi = type(chanIndex) == "number" and chanIndex or nil, dedupe = true,
        })
        if type(chanIndex) == "number" then msg.ci = chanIndex end
        msg.a = sender and KC.ShortName(sender)
        msg.c = classOf(guid, sender)
        msg.o = isMe(sender) or nil
    else
        s = self:EnsureStream(def.stream)
        msg.a = sender and KC.ShortName(sender)
        if def.form ~= "plain" then
            msg.c = classOf(guid, sender)
            msg.o = isMe(sender) or nil
        end
    end
    return self:Add(s, msg)
end

for ctype in pairs(KC.Events) do
    KC:On("CHAT_MSG_" .. ctype, function(...) KC:Capture(...) end)
end

--------------------------------------------------------------------------------
-- History housekeeping
--------------------------------------------------------------------------------

-- Secret text can be shown but never written to disk, and demo lines are only
-- for looking at.
KC:Listen("LOGOUT", function()
    for _, s in pairs(KC.char.streams) do
        for i = #s.msgs, 1, -1 do
            if s.msgs[i].secret then table.remove(s.msgs, i) end
        end
    end
end)

function KC:ClearHistory()
    self.char.streams = {}
    self:Fire("STREAMS")
    self:Fire("UNREAD")
    self:Print("Chat history cleared.")
end

function KC:CloseStream(key)
    if not self.char.streams[key] then return end
    self.char.streams[key] = nil
    if self.db.settings.view == key then self.db.settings.view = "all" end
    self:Fire("STREAMS")
    self:Fire("UNREAD")
end

--------------------------------------------------------------------------------
-- Demo: sample messages to preview the window, removed again with /kc demo.
--------------------------------------------------------------------------------

local DEMO = {
    { "CHAT_MSG_SYSTEM", "Thalianne has come online." },
    { "CHAT_MSG_GUILD", "evening all! anyone up for Deadmines?", "Thalianne", "PRIEST" },
    { "CHAT_MSG_GUILD", "me! need 2 more", "Brontor", "WARRIOR" },
    { "CHAT_MSG_GUILD", "and a healer obviously", "Brontor", "WARRIOR" },
    { "CHAT_MSG_CHANNEL", "WTS |cff1eff00|Hitem:15210::::::::20:::::::::|h[Raider Shortsword]|h|r cheap, whisper me", "Goldfinger", "ROGUE", "Trade - City", 2 },
    { "CHAT_MSG_CHANNEL", "LF2M Wailing Caverns, need tank + heal", "Mistybrook", "DRUID", "LookingForGroup", 4 },
    { "CHAT_MSG_CHANNEL", "WTS |cff1eff00|Hitem:15210::::::::20:::::::::|h[Raider Shortsword]|h|r cheap, whisper me", "Goldfinger", "ROGUE", "Trade - City", 2 },
    { "CHAT_MSG_LOOT", "You receive loot: |cff9d9d9d|Hitem:2589::::::::20:::::::::|h[Linen Cloth]|h|rx2." },
    { "CHAT_MSG_MONEY", "You loot 1 Silver, 24 Copper" },
    { "CHAT_MSG_COMBAT_XP_GAIN", "Defias Bandit dies, you gain 145 experience." },
    { "CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:4306::::::::20:::::::::|h[Silk Cloth]|h|r." },
    { "CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Stormwind increased by 25." },
    { "CHAT_MSG_WHISPER", "hey, still need a healer for DM? I can come", "Elunara", "PRIEST" },
    { "CHAT_MSG_WHISPER_INFORM", "yes please! inviting you now", "Elunara", "PRIEST" },
    { "CHAT_MSG_WHISPER", "omw, check out https://forever.example/guide for the route", "Elunara", "PRIEST" },
    { "CHAT_MSG_PARTY_LEADER", "pull carefully please, I'm still drinking", "Thalianne", "PRIEST" },
    { "CHAT_MSG_PARTY", "ok", "Brontor", "WARRIOR" },
    { "CHAT_MSG_SAY", "Anyone know where the Defias hideout is?", "Pip", "MAGE" },
    { "CHAT_MSG_MONSTER_YELL", "Who dares disturb my work?", "Edwin VanCleef" },
}

function KC:ToggleDemo()
    local had = false
    for key, s in pairs(self.char.streams) do
        for i = #s.msgs, 1, -1 do
            if s.msgs[i].demo then table.remove(s.msgs, i); had = true end
        end
        if #s.msgs == 0 then self.char.streams[key] = nil end
    end
    if had then
        self:Fire("STREAMS")
        self:Fire("UNREAD")
        return self:Print("Sample messages removed.")
    end
    local now = KC.Now()
    self.demoing = true
    for i, d in ipairs(DEMO) do
        local event, text, who, class, chan, idx = d[1], d[2], d[3], d[4], d[5], d[6]
        if class then classByName[KC.NormName(who)] = class end
        local msg = self:Capture(event, text, who, nil, chan, nil, nil, nil, idx, chan)
        if msg and not msg.demo then
            msg.demo = true
            msg.t = now - (#DEMO - i) * 30
        elseif msg then
            msg.l = now - (#DEMO - i) * 30 -- a repeat of an earlier sample line
        end
    end
    self.demoing = nil
    self:Fire("STREAMS")
    self:Print("Sample messages added. Type |cff4fd1c5/kc demo|r again to remove them.")
    self.UI:Show()
end
