# FORGE GuildGreeter

**Your guild. Your rules. Your madness.**

A customizable, lightweight World of Warcraft **Forever** guild welcome addon by [Novyx Forge](https://wow.novyxforge.com/). Built using the dark charcoal/gold native UI design language of **FORGE AFK — DAD MODE**.

**Version: 0.4.0** — development build; in-game verification is required before CurseForge publication.

## What it does

- **New guild members:** detect players appearing in the guild roster after the initial baseline, and announce a welcome.
- **Existing members who come online:** detect changes from offline to online and greet them once.
- **No login flood:** the guild members already visible when you log in are the baseline, not new arrivals. A new member must appear in two complete roster snapshots at least 3 seconds apart before triggering a welcome.
- **15 fully editable welcome messages:** all 15 are used once in their shuffled rotation before repeating. The next round never opens with the previous round's last message.
- **15 fully editable online greetings:** the online pool also contains exactly 15 distinct templates, with its own independently saved non-repeating shuffle rotation. All 30 templates can be edited or restored.
- **Template variables:** \`{player}\`, \`{full}\`, \`{guild}\`, \`{class}\`, \`{level}\`, \`{rank}\`.
- **Send channels per event:** Guild chat (default), whisper, officer chat, or **LOCAL** (only you see the text).
- **Optional Discord reminder:** edit the appended text. Disabled by default; your server invite link is not guessed or hardcoded.
- **Anti-spam:** default **24-hour cooldown for online greetings** (adjustable 1/6/12/24/48 hours), separate 5–120 minute welcome cooldown, 5–30 second spacing, and maximum 1–8 announcements per five minutes. Stale queue entries expire.
- **Quiet hours:** optional start/end hours using WoW's **server clock**, including midnight-crossing windows.
- **Guild Master only:** enabled by default to reduce duplicate automated greetings if several guildmates install the addon. You can disable this to allow other ranks, but multiple broadcasters may duplicate greetings.
- **Randomized or sequential texts.** Both categories use independent 15-message cycles without repeats. Changing the shuffle preference takes effect after the current cycle ends, preserving unused messages.
- **Saved settings, moveable panel, draggable minimap icon.** Right-click the minimap icon to pause/resume all announcements.
- **Safe preview and click-to-send test:** each selected message has Preview and Send Test. Send Test uses the selected channel, prefixes the message with [TEST], and never advances the welcome rotation or automated cooldowns. The recipient for test whispers is your own character.
- **Optional personal welcome whisper:** a separately editable template, off by default and limited to one request per new member every 24 hours.
- **Activity log:** last ten local previews, chat submission attempts, blocks and resets. Status shows ACTIVE, PAUSED, MANUAL MODE or CHAT BLOCKED (where API errors are detectable).
- **Manual fallback:** when the automatic chat API rejects a greeting, that event is held in a 20-item, session-only manual queue. Click **SEND NEXT** to attempt it explicitly. Alternatively enable **Manual Mode** in Advanced → Behavior to hold all new greetings for your confirmation. Events expire after 30 minutes and are checked against the live guild roster before sending.
- **No false consumption:** failed, oversized and LOCAL-preview messages do not consume a slot from either 15-message rotation or set the send cooldown.
- **First-run check:** on first installation the panel opens with a pointer to **Activity → CHECK SETUP**. Check guild membership, rank, roster readiness and chat API presence; verify real delivery with SEND TEST and a guildmate.
- **Restore defaults:** individual original messages can be restored. The Advanced → Behavior reset requires a second click within 15 seconds and preserves all customized greeting templates.
- **Roster burst protection:** ignores large incomplete roster drops and suppresses mass welcome floods after suspiciously large increases.
- No third-party libraries, tracking, accounts, or background servers.

## Interface

Dark charcoal background, gold typography and buttons, same visual conventions as **FORGE AFK — DAD MODE**.

| Tab | What you can customize |
| --- | --- |
| WELCOME | 15 fixed editable welcome messages, Previous/Next or +5 navigation, Save, Preview, Send Test, Restore, channel |
| ONLINE | 15 fixed editable online greetings, Previous/Next or +5 navigation, Save, Preview, Send Test, Restore, channel |
| ADVANCED → Behavior | Guild Master only, automatic/manual mode, randomized messages, cooldowns, quiet hours, pacing, rate limit, reset defaults with confirmation |
| ADVANCED → Messages | Discord reminder and optional personal welcome whisper with independent editable texts |
| ACTIVITY | Last ten actions, blocked/requested status, plus CHECK SETUP; the main panel shows WAITING/MANUAL queue counters and SEND NEXT |

Two main buttons across the top enable/disable welcome and online greetings independently. All edits are stored in WoW's SavedVariables.

## Installation — WoW Forever

The intended TOC interface is **16001**, following the known-working FORGE AFK addon. This repository includes both a normal and a Forever-style TOC name.

1. Obtain a maintainer test ZIP from the GitHub **Actions → Package GuildGreeter for CurseForge → Artifacts**, or install from source.
2. Put the **ForgeGuildGreeter** folder directly inside the WoW client's \`Interface/AddOns/\` folder.
3. Verify \`ForgeGuildGreeter.toc\`, \`ForgeGuildGreeter_Forever.toc\`, \`Core.lua\`, \`Quality.lua\`, \`UI.lua\` and \`Minimap.lua\` are in that directory.
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
| \`/fgreet check\` | Run first-use diagnostic checklist |
| \`/fgreet manual\` | Toggle explicit click-to-send mode |
| \`/fgreet help\` | Short command help |
| \`/fgreet about\` | Novyx Forge information |

## How detection works

The addon requests the guild roster and listens for \`GUILD_ROSTER_UPDATE\` events. When roster data first becomes available, it records a baseline and **does not** message any members. Later:

- A new roster entry confirmed on **two complete snapshots at least three seconds apart** causes one welcome (no immediate online greeting). Suspected bulk refills are silently rebaselined.
- An existing roster entry changing from offline to online causes an **online greeting**.
- Repeated events and short reconnects are suppressed by the cooldowns.
- Temporary incomplete roster snapshots are ignored, and suspicious large roster expansions are treated as silent rebaselines rather than mass joins.
- Only the **logged-in player** can perform this detection. The addon is not a 24/7 guild bot.

There is no server-to-server synchronization among installations. The default Guild Master-only mode helps ensure a single sender, but if more than one Guild Master character is online simultaneously, or users turn that rule off, double greetings can still occur.

## Important: client chat restrictions

The addon attempts messages through the standard WoW chat API. **Some versions of WoW block automated chat messages that are not initiated by a player click or keypress.** The addon does not bypass client restrictions. Therefore the real automatic guild-chat behavior must be verified in WoW Forever; if that server/client blocks it, the addon needs an approved/manual-send fallback.

**REQUESTED** in the Activity tab means the chat API accepted an attempted call; it is **not** evidence that the game server delivered the message. **CHAT BLOCKED** only appears for observable API failures; silently discarded messages cannot be detected. Use **Preview** (local) and **Send Test** (explicit click) to diagnose. Do not publish this as a confirmed auto-greeter before live testing.

## Developer checks

- Lua version: **5.1** is the target for mock tests.
- Run \`lua5.1 tests/smoke.lua\` at the repository root.
- The \`GuildGreeter Lua checks\` workflow checks Lua syntax and mocked behavior.
- The \`Package GuildGreeter for CurseForge\` workflow checks the folder structure and packages a single correct-root ZIP.

### In-game acceptance checklist

- [ ] Addon loads without Lua errors on the WoW Forever client.
- [ ] \`/fgreet\` opens the dark/gold panel and each tab works.
- [ ] Edit all 15 online and all 15 welcome templates; reload UI and confirm settings and shuffle rotations persist.
- [ ] Use Preview without guild chat, then Send Test in Guild/Whisper channels.
- [ ] Confirm automatic messages work without a click, and do not confuse REQUESTED with delivered.
- [ ] Enable welcome whispers with a second character and verify one whisper per day.
- [ ] Verify last-ten Activity log, observable CHAT BLOCKED state and recovery after a successful test.
- [ ] Reset one template, then reset advanced settings with two clicks; ensure custom texts survive.
- [ ] Verify template variable substitutions for all available variables.
- [ ] Log in as Guild Master and verify **no initial message flood**.
- [ ] Have one new player join while you are online; confirm exactly one welcome after two stable guild-roster updates.
- [ ] Simulate a partial roster load, a quick join-and-leave, and a bulk roster refresh: no false welcomes.
- [ ] Block chat APIs in test mode: ensure failed sends preserve rotation and enter the manual queue.
- [ ] Switch to Manual Mode: verify that new events queue, then use SEND NEXT from a real click.
- [ ] Run Activity → CHECK SETUP and verify status/queue counters.
- [ ] Have an existing member log off/on; verify exactly one login greeting.
- [ ] Check whether **automatic guild-chat sending is permitted** by this client/server.
- [ ] Test Guild, Whisper, Officer and Local channels.
- [ ] Confirm cooldown and rate limit with rapid repeated roster events.
- [ ] Confirm quiet hours, Guild Master mode and pause.
- [ ] Check drag/hide/restore minimap icon.
- [ ] Confirm two addons running on different clients do not spam the guild under the default configuration.
- [ ] Confirm no errors in combat or on /reload.

## Roadmap

V1 stays focused on **welcoming guildmates**. Both categories have exactly 15 fixed slots: edit or restore any text rather than adding/removing slots. Existing custom messages from earlier versions are preserved in their original positions; missing slots are populated with new default jokes. Extra messages beyond 15 from older experimental online builds are archived in SavedVariables, not erased. The two independent shuffle sequences are saved across reloads; upgraded five-message rotations restart as 15-message cycles without repeating the last welcome. Potential later ideas include per-player greetings or rank-specific messages after real-client validation.

## License

MIT — [LICENSE](LICENSE). 
