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
    crafting = { label = "Crafting", tag = "Crafting", sec = "game", order = 5, cap = 150, fold = true },
    addons   = { label = "Addon messages", tag = "Addon", sec = "game", order = 6, cap = 150 },
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
    TRADESKILLS = { stream = "crafting", form = "plain" },
    ACHIEVEMENT = { stream = "achieve", form = "plain" },
    GUILD_ACHIEVEMENT = { stream = "achieve", form = "plain" },
    MONSTER_SAY = { stream = "npc", form = "talk" },
    MONSTER_YELL = { stream = "npc", form = "talk" },
    MONSTER_EMOTE = { stream = "npc", form = "plain", subst = true },
    MONSTER_WHISPER = { stream = "npc", form = "talk" },
    RAID_BOSS_EMOTE = { stream = "npc", form = "plain", subst = true },
    RAID_BOSS_WHISPER = { stream = "npc", form = "plain", subst = true },
}

--------------------------------------------------------------------------------
-- The look has two parts:
--   style:   "wow" (gold border, dark stone; the default) or "flat" (teal, the
--            first draft)
--   sidebar: "text" (streams by name), "symbols" (square icons) or "round"
-- /kc theme <n> sets both at once, for comparing.
--------------------------------------------------------------------------------

KC.Themes = {
    { name = "Names", note = "the first draft: teal, streams listed by name", style = "flat", sidebar = "text" },
    { name = "Symbols", note = "teal, a slim column of square symbols", style = "flat", sidebar = "symbols" },
    { name = "Round symbols", note = "teal, round symbols", style = "flat", sidebar = "round" },
    { name = "Azeroth", note = "WoW style (gold border, dark stone), streams by name", style = "wow", sidebar = "text" },
    { name = "Azeroth symbols", note = "WoW style with square symbols", style = "wow", sidebar = "symbols" },
}

-- Colours that replace KC.Theme for a theme with a `palette` (applied at load,
-- so switching between palettes asks for a /reload).
KC.Palettes = {
    wow = {
        bg      = { 0, 0, 0, 0 },           -- the backdrop draws the background
        input   = { 0.06, 0.05, 0.04, 0.95 },
        side    = { 0, 0, 0, 0.35 },
        panel   = { 0, 0, 0, 0.30 },
        hover   = { 1, 0.82, 0, 0.10 },
        line    = { 1, 0.82, 0, 0.22 },
        accent  = { 1, 0.82, 0 },            -- the game's gold
        accent2 = { 0.70, 0.08, 0.06 },      -- the red of its buttons
        text    = { 1, 1, 1 },
        dim     = { 0.78, 0.72, 0.60 },
        link    = { 1, 0.82, 0 },
    },
}

function KC:Look()
    local s = self.db.settings
    return {
        palette = s.style ~= "flat" and "wow" or nil,
        symbols = s.sidebar == "symbols" or s.sidebar == "round",
        round = s.sidebar == "round",
    }
end

--------------------------------------------------------------------------------
-- Symbols (themes 2 and 3): an icon per stream instead of its name. Each entry
-- lists candidates; the first one the client has wins, so a renamed file never
-- shows as a green square.
--------------------------------------------------------------------------------

local I = "Interface\\Icons\\"

KC.Symbols = {
    all      = { I .. "INV_Letter_15", I .. "INV_Letter_02" },
    party    = { I .. "INV_Misc_GroupNeedMore", I .. "Ability_Warrior_BattleShout" },
    raid     = { I .. "INV_Misc_Head_Dragon_01", I .. "INV_Misc_GroupNeedMore" },
    instance = { I .. "INV_Misc_Key_03", I .. "INV_Misc_Key_01" },
    guild    = { I .. "INV_Shirt_GuildTabard_01", I .. "INV_Misc_TabardPVP_01", I .. "INV_Banner_02" },
    officer  = { I .. "INV_Crown_01", I .. "INV_Helmet_25" },
    say      = { I .. "Spell_Holy_SpiritualGuidence", I .. "INV_Misc_Note_04" },
    yell     = { I .. "Ability_Warrior_BattleShout", I .. "Ability_Warrior_RallyingCry" },
    emote    = { I .. "Ability_Rogue_Disguise", I .. "Spell_Shadow_Charm" },
    npc      = { I .. "INV_Misc_Head_Orc_01", I .. "INV_Misc_Head_Human_01" },
    system   = { I .. "INV_Misc_Gear_01", I .. "Trade_Engineering" },
    loot     = { I .. "INV_Misc_Bag_08", I .. "INV_Misc_Coin_01" },
    progress = { I .. "Spell_Holy_SurgeOfLight", I .. "Spell_Holy_HolyBolt" },
    achieve  = { I .. "Achievement_General", I .. "INV_Misc_Token_ArgentCrusade" , I .. "INV_Jewelry_Talisman_07" },
    crafting = { I .. "Trade_BlackSmithing", I .. "Trade_Tailoring" },
    addons   = { I .. "INV_Gizmo_02", I .. "Trade_Engineering" },
    whisper  = { I .. "INV_Letter_02", I .. "INV_Letter_15" },
    bnet     = { "Interface\\FriendsFrame\\Battlenet-Battleneticon", I .. "INV_Letter_02" },
    channel  = { I .. "INV_Misc_Note_01", I .. "INV_Scroll_03" },
    unknown  = { I .. "INV_Misc_QuestionMark" },
}

-- Channels by their lower-case name without spaces.
KC.ChannelSymbols = {
    general          = { I .. "INV_Misc_Map_01", I .. "INV_Misc_Map02" },
    trade            = { I .. "INV_Misc_Coin_02", I .. "INV_Misc_Coin_01" },
    lookingforgroup  = { I .. "INV_Misc_GroupLooking", I .. "Spell_Holy_PrayerOfHealing02" },
    localdefense     = { I .. "INV_Shield_06", I .. "INV_Shield_04" },
    worlddefense     = { I .. "INV_Shield_06", I .. "INV_Shield_04" },
    guildrecruitment = { I .. "INV_Scroll_03", I .. "INV_Misc_Note_01" },
    newcomerchat     = { I .. "INV_Misc_Book_09", I .. "INV_Misc_Book_08" },
}
