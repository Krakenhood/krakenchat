local _, KC = ...

--------------------------------------------------------------------------------
-- The feed: picks the messages a view shows and turns them into display items.
--
--   day   a date line between days ("Today", "Yesterday", "Mon 14 Oct")
--   msg   one message; `cont` when it continues the line above (same person,
--         same stream, within two minutes: the name and time are left out);
--         `indent` when it sits inside an opened fold
--   fold  a run of loot, XP, system or NPC lines in "All messages", shown as
--         one line that opens on click
--
-- Kept free of frames so it can be tested on its own.
--------------------------------------------------------------------------------

local Feed = {}
KC.Feed = Feed

Feed.CAP = 300           -- messages in one view; older ones are a scroll in their own stream away
local CONT_GAP = 120     -- seconds between two lines that still read as one block

local plainCache = setmetatable({}, { __mode = "k" })

local function searchText(m)
    local p = plainCache[m]
    if not p then
        p = (KC.Plain(m.x) .. "\n" .. (m.a or "")):lower()
        plainCache[m] = p
    end
    return p
end

local function matches(m, q)
    if not q then return true end
    if m.secret then return false end
    return searchText(m):find(q, 1, true) ~= nil
end

-- The messages of a view ("all" or a stream key), oldest first, at most CAP.
-- Each entry is { m = message, s = stream }.
function Feed:Collect(view, query)
    local q = type(query) == "string" and strtrim(query):lower() or ""
    if q == "" then q = nil end
    local streams = {}
    if view == "all" then
        for key, s in pairs(KC.char.streams) do
            if not KC:IsMuted(key) then streams[#streams + 1] = s end
        end
    elseif KC.char.streams[view] then
        streams[1] = KC.char.streams[view]
    end

    local out = {}
    for _, s in ipairs(streams) do
        local n, list = 0, s.msgs
        for i = #list, 1, -1 do
            local m = list[i]
            if matches(m, q) then
                out[#out + 1] = { m = m, s = s }
                n = n + 1
                if n >= self.CAP then break end
            end
        end
    end
    table.sort(out, function(a, b) return a.m.id < b.m.id end)
    local extra = #out - self.CAP
    if extra > 0 then
        local trimmed = {}
        for i = extra + 1, #out do trimmed[#trimmed + 1] = out[i] end
        out = trimmed
    end
    return out
end

local function continues(prev, e)
    if not prev or prev.indent then return false end
    local a, b = prev.e, e
    return a.s == b.s and b.m.a ~= nil and a.m.a == b.m.a and b.m.f ~= "plain" and a.m.f ~= "plain"
        and not b.m.w and not b.m.secret and (b.m.t - a.m.t) <= CONT_GAP
end

-- folding: fold runs of game messages (only in "All messages" without a search).
-- expanded: fold id -> true for the folds that are open.
function Feed:Build(entries, folding, expanded)
    expanded = expanded or {}
    local raw, lastDay, fold = {}, nil, nil
    for _, e in ipairs(entries) do
        local day = date("%Y%m%d", e.m.t)
        if day ~= lastDay then
            raw[#raw + 1] = { type = "day", t = e.m.t }
            lastDay, fold = day, nil
        end
        if folding and KC:Folds(e.s) then
            if fold then
                fold.list[#fold.list + 1] = e
                fold.last = e.m.t
            else
                fold = { type = "fold", id = e.m.id, list = { e }, first = e.m.t, last = e.m.t }
                raw[#raw + 1] = fold
            end
        else
            fold = nil
            raw[#raw + 1] = { type = "msg", e = e }
        end
    end

    -- a fold of one line is just that line; an open fold lists its lines under it
    local items, prev = {}, nil
    for _, item in ipairs(raw) do
        if item.type == "fold" and #item.list == 1 then
            item = { type = "msg", e = item.list[1] }
        end
        if item.type == "msg" then
            item.cont = continues(prev, item.e)
            items[#items + 1] = item
            prev = item
        elseif item.type == "fold" then
            item.open = expanded[item.id] and true or false
            items[#items + 1] = item
            prev = nil
            if item.open then
                for _, e in ipairs(item.list) do
                    items[#items + 1] = { type = "msg", e = e, indent = true }
                end
            end
        else
            items[#items + 1] = item
            prev = nil
        end
    end
    return items
end

-- "4 loot, 2 XP & reputation, 1 system"
function Feed:FoldSummary(fold)
    local counts, order = {}, {}
    for _, e in ipairs(fold.list) do
        local label = (e.s.label or e.s.key):lower()
        if not counts[label] then order[#order + 1] = label end
        counts[label] = (counts[label] or 0) + 1
    end
    local parts = {}
    for _, label in ipairs(order) do parts[#parts + 1] = counts[label] .. " " .. label end
    return table.concat(parts, ", ")
end

function Feed:DayLabel(t)
    local now = KC.Now()
    local day = date("%Y%m%d", t)
    if day == date("%Y%m%d", now) then return "Today" end
    if day == date("%Y%m%d", now - 86400) then return "Yesterday" end
    return date("%a %d %b", t)
end

--------------------------------------------------------------------------------
-- Message text
--------------------------------------------------------------------------------

local URL_PATTERNS = {
    "https?://[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+",
    "www%.[%w%-]+%.[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+",
    "discord%.gg/[%w%-]+",
}

local function linkURL(url)
    local tail = url:match("[%.,;:!%?%)]+$") or "" -- trailing punctuation belongs to the sentence
    if tail ~= "" then url = url:sub(1, #url - #tail) end
    return ("|cff4fd1c5|Haddon:KrakenChat:url:%s|h[%s]|h|r%s"):format(url, url, tail)
end

-- Makes web addresses clickable, leaving existing links (items, quests, ...) alone.
function Feed.LinkURLs(text)
    if type(text) ~= "string" or not (text:find("://", 1, true) or text:find("www.", 1, true) or text:find("discord.gg", 1, true)) then
        return text
    end
    local out, pos = {}, 1
    while pos <= #text do
        local ls = text:find("|H", pos, true)
        local chunk = text:sub(pos, (ls or (#text + 1)) - 1)
        for _, pattern in ipairs(URL_PATTERNS) do
            chunk = chunk:gsub(pattern, function(u)
                if u:find("|H", 1, true) then return u end
                return "\001" .. u .. "\002"
            end)
        end
        out[#out + 1] = chunk:gsub("\001([^\002]*)\002", linkURL)
        if not ls then break end
        local _, close = text:find("|h.-|h", ls + 2) -- the end of "|Hdata|h[text]|h"
        close = close or #text
        out[#out + 1] = text:sub(ls, close)
        pos = close + 1
    end
    return table.concat(out)
end

-- A clickable name. `target` is what a click replies to: "name:<character>",
-- or "stream:<key>" in conversations (Battle.net friends have no character name).
local function nameLink(target, class, label)
    local r, g, b = KC.ClassColor(class)
    label = KC.Colorize(label, r or 0.93, g or 0.94, b or 0.96)
    return ("|Haddon:KrakenChat:%s|h%s|h"):format(target, label)
end
Feed.NameLink = nameLink

local function hex(r, g, b)
    return ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- The colour the player set for this kind of chat.
function Feed.Color(m)
    local info = ChatTypeInfo and ChatTypeInfo[m.ci and ("CHANNEL" .. m.ci) or m.k]
    if not (info and info.r) and m.ci and ChatTypeInfo then info = ChatTypeInfo.CHANNEL end
    if info and info.r then return info.r, info.g, info.b end
    return 0.93, 0.94, 0.96
end

-- The text of one line (without the time). `all`: shown in "All messages", so
-- the stream's tag goes in front.
function Feed:Line(m, s, all)
    local r, g, b = Feed.Color(m)
    local color = "|cff" .. hex(r, g, b)
    local parts = {}
    if all and s.tag and not (s.fold and m.f == "plain") then
        parts[#parts + 1] = color .. "[" .. s.tag .. "]|r "
    end
    if m.w then parts[#parts + 1] = "|cffff4646[Warning]|r " end

    local text = Feed.LinkURLs(m.x)
    if (m.n or 1) > 1 then text = text .. ("  |cff8a8f98x%d|r"):format(m.n) end

    local who = m.a
    local target = s.sec == "conv" and ("stream:" .. s.key) or ("name:" .. tostring(who))
    if m.f == "plain" or not who then
        parts[#parts + 1] = color .. text .. "|r"
    elseif m.f == "emote" then
        parts[#parts + 1] = nameLink(target, m.c, who) .. color .. " " .. text .. "|r"
    elseif m.f == "afk" then
        parts[#parts + 1] = nameLink(target, m.c, who) .. color .. " is away: " .. text .. "|r"
    else
        local label, class = who, m.c
        if s.sec == "conv" and m.o and all then label, class = "To " .. s.label, s.class end
        local lead = m.ld and "|cff8a8f98 (lead)|r" or ""
        parts[#parts + 1] = nameLink(target, class, label) .. lead .. color .. ": " .. text .. "|r"
    end
    return table.concat(parts)
end

-- Plain words for copying.
function Feed:CopyText(m, s)
    local who = m.a and (m.f == "plain" and "" or (m.a .. (m.f == "emote" and " " or ": "))) or ""
    return date("%H:%M", m.t) .. " [" .. (s.label or s.key) .. "] " .. who .. KC.Plain(m.x)
end
