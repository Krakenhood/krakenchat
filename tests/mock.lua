-- Minimal WoW API mock for headless testing of KrakenChat (runs on fengari / Lua 5.3)
unpack = table.unpack
ERRORS = {}
CHAT = {}
CAPTURE = nil -- when a table, SetText calls append here

local function noop() end

-- clock ------------------------------------------------------------------
NOW = 1790000000
GT = 1000.0
function time(t) if t then return os.time(t) end return math.floor(NOW) end
function GetTime() return GT end
function GetServerTime() return math.floor(NOW) end
function date(fmt, t) return os.date(fmt, math.floor(t or NOW)) end

-- timers -------------------------------------------------------------------
TIMERS = {}
C_Timer = {
    After = function(sec, fn) TIMERS[#TIMERS + 1] = { at = GT + sec, fn = fn } end,
    NewTicker = function(sec, fn) return { Cancel = noop } end,
}
function Advance(sec)
    NOW = NOW + sec
    GT = GT + sec
    local due = {}
    for i = #TIMERS, 1, -1 do
        if TIMERS[i].at <= GT then due[#due + 1] = TIMERS[i]; table.remove(TIMERS, i) end
    end
    for i = #due, 1, -1 do due[i].fn() end
end

-- secrets -------------------------------------------------------------------
SECRET = setmetatable({}, { __tostring = function() error("touched a secret") end,
    __eq = function() error("compared a secret") end, __concat = function() error("concat secret") end,
    __len = function() error("measured a secret") end, __index = function() error("indexed a secret") end })
function issecretvalue(v) return rawequal(v, SECRET) end

-- frames ---------------------------------------------------------------------
local eventFrames = {}
local Object = {}
Object.__index = function(t, k)
    local m = Object[k]
    if m then return m end
    if type(k) == "string" and k:match("^%u") then return noop end
    return nil
end
local function new(kind, parent)
    local o = setmetatable({ _kind = kind, _parent = parent, _shown = true, _w = 0, _h = 0, _scripts = {}, _events = {} }, Object)
    return o
end
function Object:SetSize(w, h) rawset(self, "_w", w); rawset(self, "_h", h) end
function Object:SetWidth(w) rawset(self, "_w", w) end
function Object:SetHeight(h) rawset(self, "_h", h) end
function Object:GetWidth() return self._w end
function Object:GetHeight() return self._h end
function Object:Show() local was = self._shown; rawset(self, "_shown", true); local s = self._scripts.OnShow; if s and not was then s(self) end end
function Object:Hide() local was = self._shown; rawset(self, "_shown", false); local s = self._scripts.OnHide; if s and was then s(self) end end
function Object:SetShown(v) if v then self:Show() else self:Hide() end end
function Object:IsShown() return self._shown end
function Object:IsVisible() return self._shown end
function Object:SetScript(name, fn) self._scripts[name] = fn end
function Object:GetScript(name) return self._scripts[name] end
function Object:HookScript(name, fn) self._scripts[name] = fn end
function Object:RegisterEvent(e)
    if not KNOWN_EVENTS[e] then error("unknown event " .. e) end
    self._events[e] = true
    eventFrames[self] = true
end
function Object:UnregisterEvent(e) self._events[e] = nil end
function Object:CreateTexture() return new("Texture", self) end
function Object:CreateMaskTexture() return new("MaskTexture", self) end
function Object:CreateFontString() local fs = new("FontString", self); rawset(fs, "_text", ""); return fs end
function Object:GetParent() return self._parent end
function Object:SetParent(p) rawset(self, "_parent", p) end
function Object:SetText(t)
    if issecretvalue(t) then rawset(self, "_text", "<secret>"); rawset(self, "_secret", true); return end
    rawset(self, "_text", t); rawset(self, "_secret", false)
    if CAPTURE and t and t ~= "" then CAPTURE[#CAPTURE + 1] = t end
end
function Object:GetText() return self._text end
function Object:GetStringHeight() if self._secret then return SECRET end return 14 end
function Object:GetStringWidth() return 50 end
function Object:GetVerticalScroll() return self._scroll or 0 end
function Object:SetVerticalScroll(v) rawset(self, "_scroll", v) end
function Object:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Object:GetCenter() return 100, 100 end
function Object:GetEffectiveScale() return 1 end
function Object:GetFrameLevel() return 1 end
function Object:SetFont() return true end
function Object:SetTexture(f) rawset(self, "_file", f) end

function CreateFrame(kind, name, parent)
    local f = new(kind or "Frame", parent)
    if kind ~= "Frame" or name then rawset(f, "_shown", true) end
    if name then _G[name] = f end
    return f
end
function FireEvent(e, ...)
    for f in pairs(eventFrames) do
        if f._events[e] and f._scripts.OnEvent then f._scripts.OnEvent(f, e, ...) end
    end
end
function Click(btn, which)
    local s = btn._scripts.OnClick
    if s then s(btn, which or "LeftButton") end
end

UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap"); Minimap:SetSize(140, 140)
GameTooltip = CreateFrame("Frame", "GameTooltip")
DEFAULT_CHAT_FRAME = CreateFrame("Frame")
function DEFAULT_CHAT_FRAME:AddMessage(msg)
    msg = tostring(msg):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    CHAT[#CHAT + 1] = msg
    print("  [chat] " .. msg)
end
UISpecialFrames = {}
SlashCmdList = {}
StaticPopupDialogs = {}
POPUPS = {}
function StaticPopup_Show(which) POPUPS[#POPUPS + 1] = { which = which }; return true end
function geterrorhandler() return function(err) ERRORS[#ERRORS + 1] = err; print("  !! ERROR: " .. tostring(err)) end end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function GetCursorPosition() return 0, 0 end
function IsShiftKeyDown() return false end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function Ambiguate(name) return (name:gsub("%-Forever$", "")) end
RAID_CLASS_COLORS = {
    MAGE = { r = 0.25, g = 0.78, b = 0.92 }, PRIEST = { r = 1, g = 1, b = 1 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    ROGUE = { r = 1, g = 0.96, b = 0.41 }, DRUID = { r = 1, g = 0.49, b = 0.04 },
}
LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", PRIEST = "Priest", WARRIOR = "Warrior" }
YES, NO = "Yes", "No"
ChatTypeInfo = {
    SAY = { r = 1, g = 1, b = 1 }, PARTY = { r = 0.67, g = 0.67, b = 1 }, GUILD = { r = 0.25, g = 1, b = 0.25 },
    WHISPER = { r = 1, g = 0.5, b = 1 }, CHANNEL = { r = 1, g = 0.75, b = 0.75 }, CHANNEL2 = { r = 1, g = 0.8, b = 0.6 },
    SYSTEM = { r = 1, g = 1, b = 0 }, LOOT = { r = 0, g = 0.67, b = 0 },
}

-- players ----------------------------------------------------------------------
PLAYERS = {} -- guid -> class token
function GetPlayerInfoByGUID(guid) local c = PLAYERS[guid]; if c then return LOCALIZED_CLASS_NAMES_MALE[c], c end end
function UnitFullName(u) if u == "player" then return "Krakenhood", "Forever" end end
function UnitClass(u) if u == "player" then return "Mage", "MAGE", 8 end end
BNET = {} -- bnID -> battleTag
C_BattleNet = {
    GetAccountInfoByID = function(id) return BNET[id] and { battleTag = BNET[id], accountName = "|Kq" .. id .. "|k" } end,
    GetFriendAccountInfo = function(i) local n = 0 for id, tag in pairs(BNET) do n = n + 1 if n == i then return { battleTag = tag, accountName = "|Kq" .. id .. "|k" } end end end,
}
function BNGetNumFriends() local n = 0 for _ in pairs(BNET) do n = n + 1 end return n end

-- chat input -------------------------------------------------------------------
OPENED = {}
function ChatFrame_OpenChat(text) OPENED[#OPENED + 1] = { open = text } end
function ChatFrame_SendTell(name) OPENED[#OPENED + 1] = { tell = name } end
function ChatFrame_SendBNetTell(name) OPENED[#OPENED + 1] = { bn = name } end
function GetChannelName(name) if name == "Trade" then return 2 end return 0 end
LINKS = {}
function SetItemRef(link) LINKS[#LINKS + 1] = link end

NUM_CHAT_WINDOWS = 3
for i = 1, 3 do
    local cf = CreateFrame("Frame", "ChatFrame" .. i, UIParent)
    CreateFrame("Button", "ChatFrame" .. i .. "Tab", UIParent)
end
ChatFrame1EditBox = CreateFrame("EditBox", "ChatFrame1EditBox", ChatFrame1)
GeneralDockManager = CreateFrame("Frame", "GeneralDockManager", UIParent)
function hooksecurefunc(t, name, fn)
    if type(t) == "string" then t, name, fn = _G, t, name end
    local orig = t[name]
    t[name] = function(...) local r = orig(...); fn(...); return r end
end
function ChatEdit_DeactivateChat(box) end
function ChatEdit_ActivateChat(box) end
function ChatFrame_DeactivateForTest(box) ChatEdit_DeactivateChat(box) end

C_AddOns = { GetAddOnMetadata = function() return "0.1.0-test" end }

KNOWN_EVENTS = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_LOGOUT = true }
for e in ([[SAY YELL EMOTE TEXT_EMOTE WHISPER WHISPER_INFORM AFK DND BN_WHISPER BN_WHISPER_INFORM PARTY PARTY_LEADER
RAID RAID_LEADER RAID_WARNING INSTANCE_CHAT INSTANCE_CHAT_LEADER GUILD OFFICER CHANNEL SYSTEM IGNORED LOOT MONEY CURRENCY
COMBAT_XP_GAIN COMBAT_FACTION_CHANGE COMBAT_HONOR_GAIN SKILL TRADESKILLS ACHIEVEMENT GUILD_ACHIEVEMENT MONSTER_SAY
MONSTER_YELL MONSTER_EMOTE MONSTER_WHISPER RAID_BOSS_EMOTE RAID_BOSS_WHISPER]]):gmatch("%S+") do KNOWN_EVENTS["CHAT_MSG_" .. e] = true end

-- CHAT_MSG_* arguments: text, sender, language, channel, target, flags, zoneID, channelIndex, channelBase, languageID, lineID, guid, bnID
function Say(kind, text, sender, guid, extra)
    extra = extra or {}
    FireEvent("CHAT_MSG_" .. kind, text, sender, "Common", extra.channel or "", "", "", 0, extra.index or 0, extra.base or "", 7, 1, guid or "", extra.bn or 0)
end
