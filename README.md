# KrakenChat

A chat window for **World of Warcraft: Forever** that doesn't suck. Everything said around you, sorted into streams you can open, fold, hide and search, instead of one long scroll where the whisper you were waiting for drowns between loot lines and trade spam.

- **Conversations**: every whisper partner (and Battle.net friend) gets their own conversation, with unread badges. Your replies and their AFK auto-replies land in the same place.
- **Streams in a sidebar**: Conversations, Group & Guild, Nearby, Channels and Game, each a section you can fold shut. Click a stream to see only that; "All messages" shows everything.
- **Folding**: in "All messages", runs of loot, gold, XP, reputation, system and NPC lines fold into one line ("5 lines: 3 loot & gold, 2 xp & reputation"). Click it to open it.
- **No repeats**: the same message from the same person in Say, Yell or a channel within 10 minutes is counted (`x3`) instead of shown again. Goodbye, trade spam.
- **Blocks**: lines from the same person within two minutes are grouped, with the name and time shown once.
- **Search**: type in the search box to filter the open stream by text or sender.
- **Hide or fold per stream**: right-click a stream to hide it from "All messages" (it's still there on its own), to switch folding on or off, or to close a conversation.
- **Clickable everything**: names whisper that person, item links show tooltips, web addresses open a copy box. Right-click a message to copy it.
- **History**: messages are kept per character and survive `/reload` and logging out.
- **Replying**: the bar at the bottom opens the game's own chat input, already set to that stream (`/w Name`, `/p`, `/g`, `/2`, ...).
- **Day lines**, timestamps, adjustable text size, a movable and resizable window, a minimap button with a dot for unread whispers, and a key binding.

## Install

Copy the `KrakenChat` folder into the game's `Interface\AddOns` folder, then type `/kc` in game, or click the minimap button. `/kc demo` fills the window with sample messages so you can see what it looks like.

## Commands

| Command | What it does |
| --- | --- |
| `/kc` | Open or close the window |
| `/kc time` | Timestamps on or off |
| `/kc font <10-18>` | Text size of the feed |
| `/kc minimap` | Show or hide the minimap button |
| `/kc demo` | Add or remove sample messages |
| `/kc resetwindow` | Move the window back to the middle of the screen |
| `/kc clear` | Erase this character's chat history (asks first) |

## How it works

- **Streams**: each kind of chat is a stream. Whispers get one stream per person, channels one per channel (all zones' "General" share one). Streams appear in the sidebar once something is said in them.
- **Unread**: conversations, group and guild streams count unread messages. Channels and game messages don't, they're too busy for a count to mean anything. A stream is read when it's open and scrolled to the bottom.
- **Reading back**: scroll up and the feed stays where you are; new messages are counted in a "new messages" bar that brings you back down. Shift + mouse wheel jumps to the end.
- **How much is kept**: up to 300 messages per conversation, 400 in Party, Raid and Guild, 250 per channel and fewer for game messages. A view shows the latest 300 messages.

## Good to know

- **The game's chat window stays.** KrakenChat reads the chat; it doesn't replace or hide the default window. Writing still goes through the game's own input box, which keeps slash commands, shift-click links and chat history working.
- **Secret messages.** In Forever (as in Midnight) the game can hand addons chat text as a "secret" value, for example inside instances during an encounter. KrakenChat shows those lines, but can't search, fold, link or save them.
- **Untested at scale.** Verified with a headless test suite (`tests/`, run `npm test` in that folder). Busy capitals with very active channels haven't been measured yet. Bug reports are welcome in the issue tracker.
