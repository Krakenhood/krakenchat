# Krakenchat changelog

## 1.1.6

*   Fixed: long messages could still overlap the next line. Lines are now stacked by the game itself, directly below where the text above them ends, so they can no longer overlap.

## 1.1.5

*   Fixed: long messages could still overlap the next line. The chat now keeps checking the line heights while it's open and corrects the layout as soon as the game reports the right height.

## 1.1.4

*   Fixed: the first-start choice between symbols and names could be closed by the same Escape that skips the intro cinematic, and then never came back. It now asks at every login until you pick one.
*   Fixed: sharing a map pin showed an "action blocked" error and didn't copy the /way command to the clipboard.

## 1.1.3

*   Fixed: long messages could overlap the next line right after the chat window opened or changed size.

## 1.1.2

*   Fixed: Korean and Chinese text could still show as boxes on some clients. Krakenchat now uses the same font files as the game itself.
*   New: /kc fonts shows which font each alphabet uses, to help track down any remaining boxes.

## 1.1.1

*   Fixed: Russian, Korean and Chinese text (names, guild tags, messages, the chat box) showed as empty boxes instead of letters.

## 1.1.0

**New: Views, several streams in one feed**

*   The **+** in the header makes a new view: tick the streams it shows, give it a name and a symbol.
*   Ready-made view **Group & nearby**: Party, Raid, Instance, Guild, Say, Yell, Emotes and the game's own lines (NPCs, System, Loot & gold, XP & reputation, Achievements, Addon messages). No channels, crafting or whispers. Deleted by accident? /kc groupview brings it back.
*   Right-click a stream → "Show together with..." starts a view with it. Right-click a view → "Edit view..." or "Delete view".
*   Ctrl+click streams to combine them on the fly, right-click → "Save as view" to keep it.
*   A row of symbols to choose from for each view, among them the group symbol in gold.
*   A view's badge counts only its most urgent kind: one party line among forty Trade posts shows a red 1.

**New: Auto-open chat**

*   A whisper opens the chat even when it's folded in or closed, on that conversation.
*   Optional: party and raid messages do the same, opening on "Group & nearby" (off by default).
*   After 5 seconds it goes back by itself: a thin gold line counts down, then it slides back to the stream list or fades out. The message stays unread. Point at it, click or type and it stays open.
*   All of it can be switched in the settings under "Auto-open chat".

**New: First start**

*   A welcome window asks once whether the sidebar shows symbols or names, with a preview of each. /kc welcome shows it again.

**New: /kc cpu**

*   Lists how much CPU time each of your addons takes, busiest first: recent average and worst frame since login.

**Fixes**

*   Hovering a symbol in the sidebar now shows its name.
*   The view editor marks the current symbol, including the default scroll on a new view.

## 1.0.0

*   First version.
*   Streams in a sidebar: Conversations, Group & Guild, Nearby, Channels and Game. "All messages" shows everything.
*   Every whisper partner and Battle.net friend gets their own conversation, including your replies and AFK auto-replies.
*   Unread badges: red for whispers and your group, dark gold for guild, a quiet grey count for Say, Yell and channels.
*   Runs of loot, gold, XP, crafting and NPC lines fold into one line in "All messages".
*   Repeated posts within 10 minutes are counted (x3) instead of shown again.
*   Lines from the same person within two minutes are grouped.
*   Group news (joins, leaves, loot method, resets, dice rolls) shows in Party, Raid or Instance, in every language.
*   Fold the chat in to a buddy-list-like stream list, or fold the sidebar into a slim rail.
*   Hide or fold any stream in "All messages" with a right-click.
*   Search, clickable names with the game's player menu, item tooltips, copyable web addresses and lines.
*   History per character, kept across /reload and logging out.
*   Replaces the game's chat window; the chat input sits under Krakenchat while you type. /kc blizzard brings the old one back.
*   WoW style: gold border, dark stone, fantasy-font title. Streams by name or as symbols (square or round).
*   Settings window, minimap button with unread badge, key binding, /kc demo for a showcase.
