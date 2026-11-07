# FORGE GuildGreeter

**Your guild. Your rules. Your madness.**

A customizable, lightweight World of Warcraft **Forever** guild welcome addon by [Novyx Forge](https://wow.novyxforge.com/). Built using the dark charcoal/gold native UI design language of **FORGE AFK — DAD MODE**.

**Version: 0.1.0** — development build; in-game verification is required before CurseForge publication.

## What it does

- **New guild members:** detect players appearing in the guild roster after the initial baseline, and announce a welcome.
- **Existing members who come online:** detect changes from offline to online and greet them once.
- **No login flood:** the guild members already visible when you log in are the baseline, not new arrivals.
- **Two independent greeting libraries:** edit, add, remove or cycle through up to **50 custom messages per event**. Four humorous examples of each are included.
- **Template variables:** \`{player}\`, \`{full}\`, \`{guild}\`, \`{class}\`, \`{level}\`, \`{rank}\`.
- **Send channels per event:** Guild chat (default), whisper, officer chat, or **LOCAL** (only you see the text).
- **Optional Discord reminder:** edit the appended text. Disabled by default; your server invite link is not guessed or hardcoded.
- **Anti-spam:** configurable per-player/event cooldown (5–120 minutes), spacing between announcements (5–30 seconds), and outgoing limit (1–8 every five minutes). Stale queue entries expire.
- **Quiet hours:** optional start/end hours using WoW's **server clock**, including midnight-crossing windows.
- **Guild Master only:** enabled by default to reduce duplicate automated greetings if several guildmates install the addon. You can disable this to allow other ranks, but multiple broadcasters may duplicate greetings.
- **Randomized or sequential texts.** Consecutive repeats of the same randomly selected template are avoided.
- **Saved settings, moveable panel, draggable minimap icon.** Right-click the minimap icon to pause/resume all announcements.
- No third-party libraries, tracking, accounts, or background servers.

## Interface

Dark charcoal background, gold typography and buttons, same visual conventions as **FORGE AFK — DAD MODE**.

| Tab | What you can customize |
| --- | --- |
| WELCOME | Welcome messages, channel, add/remove/save, live preview |
| ONLINE | Return greetings, channel, add/remove/save, live preview |
| SETTINGS | Guild Master only, randomized text, Discord reminders, quiet hours, cooldown, chat pacing, maximum messages, quiet window, Discord text |
| ABOUT | Behavior, limitations, commands, Novyx Forge link |

Two main buttons across the top enable/disable welcome and online greetings independently. All edits are stored in WoW's SavedVariables.

## Installation — WoW Forever

The intended TOC interface is **16001**, following the known-working FORGE AFK addon. This repository includes both a normal and a Forever-style TOC name.

1. Obtain a maintainer test ZIP from the GitHub **Actions → Package GuildGreeter for CurseForge → Artifacts**, or install from source.
2. Put the **ForgeGuildGreeter** folder directly inside the WoW client's \`Interface/AddOns/\` folder.
3. Verify \`ForgeGuildGreeter.toc\`, \`ForgeGuildGreeter_Forever.toc\`, \`Core.lua\`, \`UI.lua\` and \`Minimap.lua\` are in that directory.
4. Restart WoW; enable **FORGE GuildGreeter** in the AddOns list.
5. Log in as guild master. Type \`/fgreet\` to open the configuration panel.

**Public addon distribution and updates are intended exclusively through CurseForge.** GitHub Actions artifacts are intended for maintainer testing, not as a separate public addon release channel.

## Commands

| Command | Function |
| --- | --- |
| \`/fgreet\` | Show/hide addon panel |
| \`/guildgreeter\` | Alternate panel command |
| \`/fgreet welcome\` | Toggle new-member welcomes |
| \`/fgreet online\` | Toggle member-online greetings |
| \`/fgreet minimap\` | Show/hide minimap icon |
| \`/fgreet status\` | Guild roster / broadcast status |
| \`/fgreet help\` | Short command help |
| \`/fgreet about\` | Novyx Forge information |

## How detection works

The addon requests the guild roster and listens for \`GUILD_ROSTER_UPDATE\` events. When roster data first becomes available, it records a baseline and **does not** message any members. Later:

- A new roster entry causes a **single welcome** (no immediate extra online greeting).
- An existing roster entry changing from offline to online causes an **online greeting**.
- Repeated events and short reconnects are suppressed by the cooldowns.
- Temporary very small roster snapshots are ignored to reduce false join detections.
- Only the **logged-in player** can perform this detection. The addon is not a 24/7 guild bot.

There is no server-to-server synchronization among installations. The default Guild Master-only mode helps ensure a single sender, but if more than one Guild Master character is online simultaneously, or users turn that rule off, double greetings can still occur.

## Important: client chat restrictions

The addon attempts messages through the standard WoW chat API. **Some versions of WoW block automated chat messages that are not initiated by a player click or keypress.** The addon does not bypass client restrictions. Therefore the real automatic guild-chat behavior must be verified in WoW Forever; if that server/client blocks it, the addon needs an approved/manual-send fallback.

Similarly, a successful API call in a headless test cannot guarantee the game server delivered the chat. Do not publish this as a confirmed auto-greeter before live testing.

## Developer checks

- Lua version: **5.1** is the target for mock tests.
- Run \`lua5.1 tests/smoke.lua\` at the repository root.
- The \`GuildGreeter Lua checks\` workflow checks Lua syntax and mocked behavior.
- The \`Package GuildGreeter for CurseForge\` workflow checks the folder structure and packages a single correct-root ZIP.

### In-game acceptance checklist

- [ ] Addon loads without Lua errors on the WoW Forever client.
- [ ] \`/fgreet\` opens the dark/gold panel and each tab works.
- [ ] Edit/add/delete templates, reload UI and confirm settings persist.
- [ ] Verify template variable substitutions for all available variables.
- [ ] Log in as Guild Master and verify **no initial message flood**.
- [ ] Have one new player join while you are online; verify exactly one welcome.
- [ ] Have an existing member log off/on; verify exactly one login greeting.
- [ ] Check whether **automatic guild-chat sending is permitted** by this client/server.
- [ ] Test Guild, Whisper, Officer and Local channels.
- [ ] Confirm cooldown and rate limit with rapid repeated roster events.
- [ ] Confirm quiet hours, Guild Master mode and pause.
- [ ] Check drag/hide/restore minimap icon.
- [ ] Confirm two addons running on different clients do not spam the guild under the default configuration.
- [ ] Confirm no errors in combat or on /reload.

## Roadmap

V1 is deliberately focused on **welcoming guildmates**. Potential follow-ups include per-player greetings, rank-specific templates, shared master election and localization after client behavior has been verified.

## License

MIT — [LICENSE](LICENSE). 
