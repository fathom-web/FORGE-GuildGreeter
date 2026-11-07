# Changelog

## 0.2.0 — Smart GuildGreeter (development / in-game validation pending)

### Added
- Compact AFK DAD-style interface with Welcome, Online, Advanced and Activity views.
- Click-to-send `[TEST]` and local Preview for selected messages (never consumes the automatic rotation).
- Customizable online greeting cooldown; default 24 hours per member.
- Separate optional personal welcome whisper with editable template and 24-hour recipient cooldown.
- Live status (Active, Paused, Chat Blocked when observable) and a ten-entry local action history.
- Advanced Behavior / Messages settings pages, confirmation before settings reset, per-message restore.
- More conservative guild-roster handling to reduce false mass welcomes.
- Lua 5.1 mocked-client tests for chat rejection, safety limits, cooldowns, test clicks, whisper and restore logic.

### Retained
- Exactly five editable welcome messages, non-repeating shuffled rotation, saved across reloads.
- Separate online-greeting templates and independent enable switches.
- Guild Master-only default sender, anti-spam pacing and quiet hours.
- Novyx Forge branding and CurseForge-ready ZIP workflow.

### Important
- A successful chat API call means **requested**, not confirmed delivered.
- Automatic chat permission, guild event behavior and cross-client duplicate suppression must be tested in WoW Forever before releasing via CurseForge.

## 0.1.1
- Added a fifth customizable welcome message and persistent no-repeat rotation.

## 0.1.0
- Initial custom guild greeter with welcome/login detection, AFK Dad Mode UI, saved settings and minimap button.
