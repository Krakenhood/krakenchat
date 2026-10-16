# KrakenChat

A chat window for **World of Warcraft: Forever** that doesn't suck. Everything said around you, sorted into streams you can open, fold, hide and search, instead of one long scroll where the whisper you were waiting for drowns between loot lines and trade spam.

- **Conversations**: every whisper partner (and Battle.net friend) gets their own conversation, with unread badges. Your replies and their AFK auto-replies land in the same place.
- **Streams in a sidebar**: Conversations, Group & Guild, Nearby, Channels and Game, each a section you can fold shut. Click a stream to see only that; "All messages" shows everything.
- **Folding**: in "All messages", runs of loot, gold, XP, reputation, system and NPC lines fold into one line ("5 lines: 3 loot & gold, 2 xp & reputation"). Click it to open it.
- **No repeats**: the same message from the same person in Say, Yell or a channel within 10 minutes is counted (`x3`) instead of shown again. Goodbye, trade spam.
- **Blocks**: lines from the same person within two minutes are grouped, with the name and time shown once.
- **Search**: click the magnifier in the header and type to filter the open stream by text or sender. An empty search folds back into the magnifier.
- **Fold the chat in**: the arrow next to the close button folds the chat away, and the window narrows to just the stream list with its unread badges, like a buddy list. Click a stream (or the arrow again) and the chat opens on it at its old width. A whisper brings the chat back by itself, unfolded on that conversation, even if you closed the window (`/kc whisperopen` or the settings switch that off).
- **Fold the sidebar in**: the arrow at the bottom left folds the stream list into a slim rail, so the chat gets the whole width. Unread messages still show as a badge on the rail; click it to fold back out. The window remembers the choice.
- **Hide or fold per stream**: right-click a stream to hide it from "All messages" (it's still there on its own), to switch folding on or off, or to close a conversation.
- **Clickable everything**: names whisper that person, item links show tooltips, web addresses open a copy box. Right-click a message to copy it.
- **History**: messages are kept per character and survive `/reload` and logging out.
- **Replying**: the bar at the bottom opens the game's own chat input, already set to that stream (`/w Name`, `/p`, `/g`, `/2`, ...).
- **Replaces the game's chat window**: the game's chat windows, tabs and chat buttons are hidden while KrakenChat runs (`/kc blizzard` brings them back). The chat input moves under the KrakenChat window, and lines other addons print go into "Addon messages".
- **WoW style**: a gold border around dark stone and the title in the game's fantasy font. A flat teal look is there as an alternative (`/kc style teal`, or in the settings).
- **Settings window**: the gear in the header, right-click on the minimap button or `/kc settings`. Tick boxes for opening the chat on a whisper, hiding the game's chat window, symbols, round symbols, timestamps, the minimap button and the teal style, plus the text size.
- **Names or symbols**: the button at the bottom of the sidebar (or `/kc symbols`) shows the streams as a slim column of symbols instead of names: coins for Trade, a map for General, class icons for whisper partners. Names are in the tooltips. `/kc symbols round` makes them round. `/kc theme 1` to `5` sets style and sidebar together, for comparing.
- **Day lines**, timestamps, adjustable text size, a movable and resizable window, a minimap button with a dot for unread whispers, and a key binding.

## Install

Copy the `KrakenChat` folder into the game's `Interface\AddOns` folder, then type `/kc` in game, or click the minimap button. `/kc demo` fills the window with sample messages so you can see what it looks like.

## Commands

| Command | What it does |
| --- | --- |
| `/kc` | Open or close the window |
| `/kc time` | Timestamps on or off |
| `/kc font <10-18>` | Text size of the feed |
| `/kc compact` | Fold the chat in, keeping only the stream list |
| `/kc side` | Fold the stream list in or out |
| `/kc symbols` | Sidebar as symbols or names (`/kc symbols round` for round symbols) |
| `/kc settings` | Open the settings window |
| `/kc style teal` | The alternative teal look (`/kc style wow` for the standard one) |
| `/kc theme <1-5>` | Both at once: 1 teal names, 2 teal symbols, 3 teal round, 4 WoW names, 5 WoW symbols |
| `/kc whisperopen` | Whether a whisper unfolds the folded-in chat |
| `/kc blizzard` | Hide or show the game's own chat window |
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

- **Writing goes through the game's own chat input.** That keeps slash commands, shift-click links and chat history working; it sits under the KrakenChat window while the game's chat window is hidden.
- **Secret messages.** In Forever (as in Midnight) the game can hand addons chat text as a "secret" value, for example inside instances during an encounter. KrakenChat shows those lines, but can't search, fold, link or save them.
- **Untested at scale.** Verified with a headless test suite (`tests/`, run `npm test` in that folder). Busy capitals with very active channels haven't been measured yet. Bug reports are welcome in the issue tracker.
