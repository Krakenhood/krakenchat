local _, KC = ...

KC.Theme = {
    bg      = { 0.047, 0.055, 0.071, 0.94 },
    side    = { 1, 1, 1, 0.025 },
    panel   = { 1, 1, 1, 0.035 },
    hover   = { 1, 1, 1, 0.06 },
    line    = { 1, 1, 1, 0.08 },
    accent  = { 0.31, 0.82, 0.77 }, -- kraken teal
    accent2 = { 0.55, 0.42, 0.95 }, -- deep-sea violet
    text    = { 0.93, 0.94, 0.96 },
    dim     = { 0.56, 0.60, 0.66 },
    link    = { 0.31, 0.82, 0.77 },
}

--------------------------------------------------------------------------------
-- Sidebar sections. `personal` sections count unread messages; channels and
-- game messages are too busy for that to mean anything.
--------------------------------------------------------------------------------

KC.Sections = {
    { id = "conv", label = "Conversations", personal = true },
    { id = "group", label = "Group & Guild", personal = true },
    { id = "near", label = "Nearby" },
    { id = "channels", label = "Channels" },
    { id = "game", label = "Game" },
}

-- Streams that always have the same key. Whispers and channels get one stream
-- per person or channel, made on the fly (see Capture.lua).
-- tag: the short label in front of a message in "All messages".
-- fold: runs of these messages fold into one line in "All messages" by default.
-- dedupe: the same text from the same person within a few minutes is counted
-- (x3) instead of shown again.
-- cap: how many messages the stream keeps.
KC.Fixed = {
    party    = { label = "Party", tag = "Party", sec = "group", order = 1, cap = 400 },
    raid     = { label = "Raid", tag = "Raid", sec = "group", order = 2, cap = 400 },
    instance = { label = "Instance", tag = "Instance", sec = "group", order = 3, cap = 300 },
    guild    = { label = "Guild", tag = "Guild", sec = "group", order = 4, cap = 400 },
    officer  = { label = "Officer", tag = "Officer", sec = "group", order = 5, cap = 300 },
    say      = { label = "Say", tag = "Say", sec = "near", order = 1, cap = 250, dedupe = true },
    yell     = { label = "Yell", tag = "Yell", sec = "near", order = 2, cap = 200, dedupe = true },
    emote    = { label = "Emotes", tag = "Emote", sec = "near", order = 3, cap = 150 },
    npc      = { label = "NPCs", tag = "NPC", sec = "game", order = 1, cap = 150, fold = true },
    system   = { label = "System", tag = "System", sec = "game", order = 2, cap = 200, fold = true },
    loot     = { label = "Loot & gold", tag = "Loot", sec = "game", order = 3, cap = 200, fold = true },
    progress = { label = "XP & reputation", tag = "Progress", sec = "game", order = 4, cap = 150, fold = true },
    achieve  = { label = "Achievements", tag = "Achievement", sec = "game", order = 5, cap = 100 },
}

KC.WhisperCap = 300
KC.ChannelCap = 250

-- Short names for well-known channels.
KC.ChannelTags = {
    lookingforgroup = "LFG",
    localdefense = "Defense",
    worlddefense = "World Defense",
    guildrecruitment = "Recruit",
    newcomerchat = "Newcomer",
}

--------------------------------------------------------------------------------
-- Chat events. `type` is the CHAT_MSG_ suffix; the game's ChatTypeInfo[type]
-- gives the colour the player configured for it.
-- stream: a fixed stream key, or "whisper", "bnet", "channel" (one per partner
-- or channel).
-- form: how the line reads
--   talk:    Name: text
--   emote:   Name text
--   plain:   text (the game already wrote the whole sentence)
--   afk:     Name is away: text
-- out: the message is one we sent.
-- subst: the text has a %s where the speaker's name goes.
--------------------------------------------------------------------------------

KC.Events = {
    SAY = { stream = "say", form = "talk" },
    YELL = { stream = "yell", form = "talk" },
    EMOTE = { stream = "emote", form = "emote" },
    TEXT_EMOTE = { stream = "emote", form = "plain" },
    WHISPER = { stream = "whisper", form = "talk" },
    WHISPER_INFORM = { stream = "whisper", form = "talk", out = true },
    AFK = { stream = "whisper", form = "afk", color = "WHISPER" },
    DND = { stream = "whisper", form = "afk", color = "WHISPER" },
    BN_WHISPER = { stream = "bnet", form = "talk" },
    BN_WHISPER_INFORM = { stream = "bnet", form = "talk", out = true },
    PARTY = { stream = "party", form = "talk" },
    PARTY_LEADER = { stream = "party", form = "talk", leader = true },
    RAID = { stream = "raid", form = "talk" },
    RAID_LEADER = { stream = "raid", form = "talk", leader = true },
    RAID_WARNING = { stream = "raid", form = "talk", warning = true },
    INSTANCE_CHAT = { stream = "instance", form = "talk" },
    INSTANCE_CHAT_LEADER = { stream = "instance", form = "talk", leader = true },
    GUILD = { stream = "guild", form = "talk" },
    OFFICER = { stream = "officer", form = "talk" },
    CHANNEL = { stream = "channel", form = "talk" },
    SYSTEM = { stream = "system", form = "plain" },
    IGNORED = { stream = "system", form = "plain", color = "SYSTEM" },
    LOOT = { stream = "loot", form = "plain" },
    MONEY = { stream = "loot", form = "plain" },
    CURRENCY = { stream = "loot", form = "plain" },
    COMBAT_XP_GAIN = { stream = "progress", form = "plain" },
    COMBAT_FACTION_CHANGE = { stream = "progress", form = "plain" },
    COMBAT_HONOR_GAIN = { stream = "progress", form = "plain" },
    SKILL = { stream = "progress", form = "plain" },
    TRADESKILLS = { stream = "progress", form = "plain" },
    ACHIEVEMENT = { stream = "achieve", form = "plain" },
    GUILD_ACHIEVEMENT = { stream = "achieve", form = "plain" },
    MONSTER_SAY = { stream = "npc", form = "talk" },
    MONSTER_YELL = { stream = "npc", form = "talk" },
    MONSTER_EMOTE = { stream = "npc", form = "plain", subst = true },
    MONSTER_WHISPER = { stream = "npc", form = "talk" },
    RAID_BOSS_EMOTE = { stream = "npc", form = "plain", subst = true },
    RAID_BOSS_WHISPER = { stream = "npc", form = "plain", subst = true },
}
