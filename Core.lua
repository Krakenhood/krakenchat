local ADDON, KC = ...
KrakenChat = KC -- global handle, handy for /dump KrakenChat.db.settings

local floor = math.floor

KC.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "1.1.0"

--------------------------------------------------------------------------------
-- Secret-value safety
--
-- Forever runs the Midnight "secret values" system: some reads come back as
-- opaque values that throw on arithmetic, comparison, concatenation and even
-- ==. Chat text can be one of them (inside instances during an encounter).
-- The only safe test is issecretvalue(), so every value we read from the game
-- goes through clean() before we look at it, and API calls go through call().
--------------------------------------------------------------------------------

local issecretvalue = issecretvalue

function KC.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function clean(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
KC.clean = clean

function KC.call(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok then return nil end
    return clean(a), clean(b), clean(c), clean(d), clean(e), clean(f)
end

function KC.Now()
    local t = GetServerTime and GetServerTime()
    if type(t) ~= "number" then t = time() end
    return floor(t)
end

-- Character names come in several spellings: Forever's two-word names arrive as
-- "Naendor Delorentis" in a message, while other APIs give "Naendor-Delorentis".
-- Compare them with the spaces, hyphens and capitals taken out.
function KC.NormName(s)
    return (tostring(s or ""):lower():gsub("[%s%-]+", ""))
end

-- "Name-Realm" -> "Name" when the realm is our own (or Ambiguate isn't there).
function KC.ShortName(name)
    if type(name) ~= "string" or name == "" then return name end
    if Ambiguate then
        local short = KC.call(Ambiguate, name, "short")
        if type(short) == "string" and short ~= "" then return short end
    end
    return (name:gsub("%-[^%-]+$", ""))
end

-- The name without our own realm: "Elunara-Forever" -> "Elunara" for a player
-- on our realm, while someone from another realm keeps theirs. Used for keys,
-- so a person always lands in the same conversation.
function KC.LocalName(name)
    if type(name) ~= "string" then return name end
    local realm = KC.me and KC.me.realm
    if realm and realm ~= "" then
        local suffix = "-" .. realm
        if name:sub(-#suffix):lower() == suffix:lower() then name = name:sub(1, -#suffix - 1) end
    end
    return name
end

-- Removes colour codes, textures and hyperlink wrappers, keeping the visible text.
function KC.Plain(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "?")
    return s
end

function KC.Colorize(text, r, g, b)
    return ("|cff%02x%02x%02x%s|r"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), text)
end

function KC.ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
end

--------------------------------------------------------------------------------
-- Fonts. A single font file only has the letters it was made for: the
-- game's own FRIZQT__.TTF has no Cyrillic, Korean or Chinese, so a Russian
-- message set in it shows as boxes. The game's chat uses font families that
-- switch to a matching file for each alphabet; KC.SetFont makes the same kind
-- of family for every size we use.
--------------------------------------------------------------------------------

KC.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local ALPHABET_LIST = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }

-- The file the game itself uses for each alphabet, read from its own font
-- family, so it's the file this client really has. Guessed names only when
-- the game can't say.
local GUESS = {
    roman = KC.FONT,
    russian = "Fonts\\FRIZQT___CYR.TTF",
    korean = "Fonts\\2002.TTF",
    simplifiedchinese = "Fonts\\ARKai_T.ttf",
    traditionalchinese = "Fonts\\blei00d.TTF",
}
local gameFiles

local function readGameFiles()
    local files, from = {}, {}
    for _, alphabet in ipairs(ALPHABET_LIST) do
        for _, name in ipairs({ "ChatFontNormal", "GameFontHighlight", "GameFontNormal", "SystemFont_Shadow_Med1" }) do
            local base = _G[name]
            if not files[alphabet] and type(base) == "table" and base.GetFontObjectForAlphabet then
                local ok, obj = pcall(base.GetFontObjectForAlphabet, base, alphabet)
                local file = ok and obj and obj.GetFont and obj:GetFont()
                if type(file) == "string" and file ~= "" then files[alphabet], from[alphabet] = file, name end
            end
        end
        if not files[alphabet] then files[alphabet], from[alphabet] = GUESS[alphabet], "guess" end
    end
    return files, from
end

local function filesFor(kind)
    gameFiles = gameFiles or { readGameFiles() }
    local files = {}
    for k, v in pairs(gameFiles[1]) do files[k] = v end
    files.roman = KC.FONT
    if kind == "title" then
        files.roman = "Fonts\\MORPHEUS.TTF"
        files.russian = "Fonts\\MORPHEUS_CYR.TTF"
    end
    return files
end

local families = {}

local function family(kind, size, flags)
    local key = kind .. size .. flags
    local font = families[key]
    if font ~= nil then return font end
    font = false
    if CreateFontFamily then
        local files, members = filesFor(kind), {}
        for _, alphabet in ipairs(ALPHABET_LIST) do
            members[#members + 1] = { alphabet = alphabet, file = files[alphabet], height = size, flags = flags }
        end
        local ok, f = pcall(CreateFontFamily, "KrakenChatFont_" .. key:gsub("%W", ""), members)
        if ok and f then font = f end
    end
    families[key] = font
    return font
end

-- Without font families of our own: the game's text object closest in size,
-- which has every alphabet (the size is near, the outline is lost).
local GAME_SIZES = {
    { 10, "GameFontHighlightSmall" }, { 12, "GameFontHighlight" }, { 14, "GameFontHighlightMedium" }, { 16, "GameFontHighlightLarge" },
}
local function nearestGameFont(size)
    local best, bestD
    for _, g in ipairs(GAME_SIZES) do
        local d = math.abs(g[1] - size)
        if _G[g[2]] and (not bestD or d < bestD) then best, bestD = _G[g[2]], d end
    end
    return best
end

-- `kind` "normal" (the default) or "title" (the fantasy font). True when the
-- font was set (a title may fail on a client without the fantasy font).
function KC.SetFont(fs, size, flags, kind)
    kind, flags = kind or "normal", flags or ""
    local font = family(kind, size, flags)
    if font and pcall(fs.SetFontObject, fs, font) then return true end
    if kind == "title" then return pcall(fs.SetFont, fs, "Fonts\\MORPHEUS.TTF", size, flags) end
    font = nearestGameFont(size)
    if font and pcall(fs.SetFontObject, fs, font) then return true end
    fs:SetFont(KC.FONT, size, flags)
    return true
end

-- What /kc fonts prints: which file each alphabet gets, and where it came from.
function KC.FontReport()
    local files, from = readGameFiles()
    local lines = { ("font families: %s"):format(CreateFontFamily and "yes" or "no (the game's own text objects instead)") }
    for _, alphabet in ipairs(ALPHABET_LIST) do
        lines[#lines + 1] = ("%s: %s (%s)"):format(alphabet, tostring(files[alphabet]), from[alphabet])
    end
    return lines
end

--------------------------------------------------------------------------------
-- Chat output
--------------------------------------------------------------------------------

local PREFIX = "|cff4fd1c5Kraken|rchat:"

function KC:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. " " .. tostring(msg))
end

function KC:Printf(fmt, ...)
    self:Print(fmt:format(...))
end

--------------------------------------------------------------------------------
-- Events and internal messages
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local events, listeners, reported = {}, {}, {}
KC.missingEvents = {}

function KC:ReportError(err)
    err = tostring(clean(err) or "?")
    if reported[err] then return end
    reported[err] = true
    local handler = geterrorhandler and geterrorhandler()
    if handler then pcall(handler, err) end
end

local function dispatch(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then KC:ReportError(err) end
end

-- RegisterEvent on an event this client doesn't have raises, which would abort
-- the rest of the file, so every registration is protected.
function KC:On(event, fn)
    if not events[event] then
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
            table.insert(self.missingEvents, event)
            return false
        end
        events[event] = {}
    end
    table.insert(events[event], fn)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = events[event]
    if not list then return end
    for i = 1, #list do dispatch(list[i], event, ...) end
end)

function KC:Listen(msg, fn)
    listeners[msg] = listeners[msg] or {}
    table.insert(listeners[msg], fn)
end

function KC:Fire(msg, ...)
    local list = listeners[msg]
    if not list then return end
    for i = 1, #list do dispatch(list[i], ...) end
end

--------------------------------------------------------------------------------
-- SavedVariables
--
-- KrakenChatDB (account): settings and window layout.
-- KrakenChatCharDB (character): the message history, one list per stream.
--------------------------------------------------------------------------------

local function fill(t, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then t[k] = {} end
            fill(t[k], v)
        elseif t[k] == nil then
            t[k] = v
        end
    end
    return t
end
KC.fill = fill

local DEFAULTS = {
    settings = {
        shown = true,          -- the window is open at login
        timestamps = true,
        fontSize = 12,
        sort = "recent",       -- conversations: "recent" or "name"
        view = "all",          -- the stream shown in the feed
        collapsed = { near = true, channels = true, game = true }, -- sidebar sections folded shut: the busy ones
        sideCollapsed = nil,   -- true: the whole sidebar is folded into a slim rail
        chatCollapsed = true,  -- the chat is folded in, the window shows only the stream list
        hideBlizzard = true,   -- the game's own chat windows are hidden
        style = "wow",         -- the WoW style; the teal "flat" look is parked
        sidebar = "text",      -- "text", "symbols" or "round"
        openOnWhisper = true,  -- a whisper unfolds the chat while it's folded in
        openOnGroup = false,   -- ...and so do party, raid and instance lines
        popWhenFolded = true,  -- pop up when the chat is folded in
        popWhenClosed = true,  -- pop up when the window is closed
        popReturn = true,      -- go back after a few seconds unless you use it
        quietCounts = true,    -- small grey unread counts for Say, Yell, Emotes and channels
        muted = {},            -- stream key -> true: left out of "All messages" (false: shown)
        views = {},            -- saved views: { id, name?, keys = { stream keys } }, shown under "Views"
        combo = {},            -- the streams combined with Ctrl+click right now (view "combo")
        fold = {},             -- stream key -> true/false: overrides the default folding in "All messages"
        minimap = { angle = 225, hide = false },
        window = {},
    },
}

local CHAR_DEFAULTS = { streams = {}, nextId = 1 }

-- The ready-made view: your group and guild, what's said around you and the
-- game's own lines (all but crafting); no channels, no whispers. Added once at the start, and again
-- with /kc groupview. Returns its key.
local GROUP_VIEW = {
    "party", "raid", "instance", "guild", "say", "yell", "emote",
    "npc", "system", "loot", "progress", "achieve", "addons",
}

function KC:AddGroupView()
    local settings = self.db.settings
    local id = settings.nextViewId or 1
    settings.nextViewId = id + 1
    local keys = {}
    for _, k in ipairs(GROUP_VIEW) do keys[#keys + 1] = k end
    table.insert(settings.views, 1, { id = id, name = "Group & nearby", keys = keys, icon = KC.GroupViewIcon, gold = true })
    return "v:" .. id
end

-- The saved view that shows your group: "Group & nearby" if it's there.
function KC:GroupViewKey()
    for _, v in ipairs(self.db.settings.views) do
        for _, k in ipairs(v.keys) do
            if k == "party" or k == "raid" or k == "instance" then return "v:" .. v.id end
        end
    end
end

function KC:LoadDB()
    -- nothing saved yet: a fresh install, which gets the welcome (sidebar choice)
    self.firstRun = type(KrakenChatDB) ~= "table" or type(KrakenChatDB.settings) ~= "table"
    if type(KrakenChatDB) ~= "table" then KrakenChatDB = {} end
    if type(KrakenChatCharDB) ~= "table" then KrakenChatCharDB = {} end
    -- 0.1 kept a theme number; it becomes a style and a sidebar
    local old = type(KrakenChatDB.settings) == "table" and KrakenChatDB.settings
    if old and old.theme and not old.style then
        local t = KC.Themes[old.theme] or KC.Themes[1]
        old.style, old.sidebar, old.theme = t.style, t.sidebar, nil
    end
    self.db = fill(KrakenChatDB, DEFAULTS)
    -- the teal look is parked for now: everyone gets the WoW style
    self.db.settings.style = "wow"
    -- one ready-made view, once: deleting it is final
    local settings = self.db.settings
    if not settings.viewsSeeded then
        settings.viewsSeeded = true
        self:AddGroupView()
    end
    -- made before views had symbols: the ready-made one gets its gold group
    for _, v in ipairs(settings.views) do
        if v.name == "Group & nearby" and not v.icon then v.icon, v.gold = KC.GroupViewIcon, true end
    end
    self.char = fill(KrakenChatCharDB, CHAR_DEFAULTS)
    for key, s in pairs(self.char.streams) do
        if type(s.msgs) ~= "table" then s.msgs = {} end
        s.unread = s.unread or 0
        -- fixed streams take their label, cap and folding from the current code
        for k, v in pairs(KC.Fixed[key] or {}) do s[k] = v end
    end
    -- a WoW-style theme swaps the colours before any frame is made
    local palette = KC.Palettes[KC:Look().palette or ""]
    if palette then
        for k, v in pairs(palette) do KC.Theme[k] = v end
    end
    self.palette = KC:Look().palette
end

--------------------------------------------------------------------------------
-- Opening the game's own chat input (replying, whispering). We never send chat
-- ourselves: the game's edit box handles slash commands, links and history,
-- and stays free of addon taint for anything it sends.
--------------------------------------------------------------------------------

function KC.OpenChat(text)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if open then pcall(open, text or "", DEFAULT_CHAT_FRAME) end
end

function KC.OpenBNetTell(accountName)
    local tell = (ChatFrameUtil and ChatFrameUtil.SendBNetTell) or ChatFrame_SendBNetTell
    if tell and accountName then
        pcall(tell, accountName)
    end
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

if StaticPopupDialogs then
    StaticPopupDialogs.KRAKENCHAT_RELOAD = {
        text = "This theme has a different frame and colours.\n\nReload the interface now to see it?",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function() ReloadUI() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs.KRAKENCHAT_CLEAR = {
        text = "Clear the whole chat history of this character?\n\nThis cannot be undone.",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function() KC:ClearHistory() end,
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
    }
end

local HELP = {
    "|cff4fd1c5/kc|r: open or close the chat window",
    "|cff4fd1c5/kc time|r: timestamps on or off",
    "|cff4fd1c5/kc font <10-18>|r: text size of the feed",
    "|cff4fd1c5/kc side|r: fold the stream list in or out",
    "|cff4fd1c5/kc compact|r: fold the chat in, keeping only the stream list",
    "|cff4fd1c5/kc symbols|r: sidebar as symbols or names (|cff4fd1c5/kc symbols round|r for round ones)",
    "|cff4fd1c5/kc settings|r: open the settings window",
    "|cff4fd1c5/kc welcome|r: the first-start choice between symbols and names",
    "|cff4fd1c5/kc groupview|r: bring back the \"Group & nearby\" view",
    "|cff4fd1c5/kc whisperopen|r: whether a whisper unfolds the folded-in chat",
    "|cff4fd1c5/kc blizzard|r: hide or show the game's own chat window",
    "|cff4fd1c5/kc minimap|r: show or hide the minimap button",
    "|cff4fd1c5/kc demo|r: add or remove sample messages to preview the window",
    "|cff4fd1c5/kc resetwindow|r: window back to the bottom left at its default size",
    "|cff4fd1c5/kc clear|r: erase this character's chat history",
    "|cff4fd1c5/kc cpu|r: how much time each addon takes (recent average and worst frame)",
    "|cff4fd1c5/kc fonts|r: which font file each alphabet (Latin, Cyrillic, Korean, Chinese) gets",
}

-- The game's own profiler, which its addon list only shows an average of:
-- every loaded addon, busiest first.
function KC:PrintCPU()
    local P, M, A = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric, C_AddOns
    if not (P and P.GetAddOnMetric and M and A) then
        self:Print("This game client has no addon profiler.")
        return
    end
    local list = {}
    for i = 1, A.GetNumAddOns() do
        local name = A.GetAddOnInfo(i)
        if name and A.IsAddOnLoaded(i) then
            local ok1, recent = pcall(P.GetAddOnMetric, name, M.RecentAverageTime)
            local ok2, peak = pcall(P.GetAddOnMetric, name, M.PeakTime)
            list[#list + 1] = { name = name, recent = ok1 and tonumber(recent) or 0, peak = ok2 and tonumber(peak) or 0 }
        end
    end
    table.sort(list, function(a, b)
        if a.recent ~= b.recent then return a.recent > b.recent end
        return a.peak > b.peak
    end)
    self:Print("CPU per addon, in ms per frame: recent average, worst frame since login")
    for _, e in ipairs(list) do
        self:Printf("  %s: %.3f, worst %.1f", e.name, e.recent, e.peak)
    end
end

function KC:Slash(input)
    local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    local settings = self.db.settings
    if cmd == "" or cmd == "show" then
        self.UI:Toggle()
    elseif cmd == "time" or cmd == "timestamps" then
        settings.timestamps = not settings.timestamps
        self:Fire("LAYOUT")
        self:Print("Timestamps " .. (settings.timestamps and "on." or "off."))
    elseif cmd == "font" then
        local n = tonumber(rest)
        if not n or n < 10 or n > 18 then return self:Print("Font size: a number from 10 to 18, e.g. /kc font 13") end
        settings.fontSize = floor(n)
        self:Fire("LAYOUT")
        self:Print("Font size " .. settings.fontSize .. ".")
    elseif cmd == "side" then
        self.UI:Create()
        self.UI:ToggleSide()
    elseif cmd == "compact" then
        self.UI:Create()
        if not self.UI.frame:IsShown() then self.UI:Show() end
        self.UI:ToggleChat()
    elseif cmd == "symbols" or cmd == "symbol" or cmd == "text" then
        self.UI:Create()
        local sidebar = (cmd == "text" and "text") or (rest == "round" and "round") or (settings.sidebar == "text" and "symbols" or "text")
        self.UI:SetLook(settings.style, sidebar)
        self:Print(sidebar == "text" and "Sidebar: names." or "Sidebar: symbols (names are in the tooltips).")
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        self.Options:Toggle()
    elseif cmd == "welcome" then
        self.Welcome:Show()
    elseif cmd == "cpu" then
        self:PrintCPU()
    elseif cmd == "fonts" then
        self:Print("fonts:")
        for _, line in ipairs(KC.FontReport()) do self:Print("  " .. line) end
    elseif cmd == "groupview" then
        self.UI:Create()
        if not self.UI.frame:IsShown() then self.UI:Show() end
        self.UI:Select(self:AddGroupView())
        self:Print('"Group & nearby" is back under Views.')
    elseif cmd == "whisperopen" then
        settings.openOnWhisper = not settings.openOnWhisper
        self:Print("A whisper " .. (settings.openOnWhisper and "unfolds the chat." or "no longer unfolds the chat."))
    elseif cmd == "blizzard" then
        settings.hideBlizzard = not settings.hideBlizzard
        self.Blizzard:Apply()
        self:Print("The game's chat window is " .. (settings.hideBlizzard and "hidden." or "shown again."))
    elseif cmd == "minimap" then
        settings.minimap.hide = not settings.minimap.hide
        self:Fire("SETTINGS")
        self:Print("Minimap button " .. (settings.minimap.hide and "hidden." or "shown."))
    elseif cmd == "demo" then
        self:ToggleDemo()
    elseif cmd == "resetwindow" or cmd == "reset" then
        self.UI:Create()
        self.UI:ResetPosition()
    elseif cmd == "clear" then
        if StaticPopup_Show then StaticPopup_Show("KRAKENCHAT_CLEAR") end
    else
        self:Print("commands:")
        for _, line in ipairs(HELP) do DEFAULT_CHAT_FRAME:AddMessage("   " .. line) end
    end
end

SLASH_KRAKENCHAT1 = "/kc"
SLASH_KRAKENCHAT2 = "/krakenchat"
SlashCmdList.KRAKENCHAT = function(input) KC:Slash(input) end

-- Key binding (Bindings.xml)
BINDING_HEADER_KRAKENCHAT = "KrakenChat"
BINDING_NAME_KRAKENCHAT_TOGGLE = "Open or close the chat window"
function KrakenChat_Toggle() KC.UI:Toggle() end

--------------------------------------------------------------------------------
-- Bootstrap
--------------------------------------------------------------------------------

KC:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    KC:LoadDB()
end)

KC:On("PLAYER_LOGIN", function()
    local name, realm = KC.call(UnitFullName, "player")
    KC.me = { name = name or "?", realm = realm, class = select(2, KC.call(UnitClass, "player")) }
    KC.ready = true
    KC:Fire("LOGIN")
end)

KC:On("PLAYER_LOGOUT", function()
    if not KC.char then return end
    KC:Fire("LOGOUT")
end)
