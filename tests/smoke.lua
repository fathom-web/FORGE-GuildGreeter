-- Mocked WoW Forever 16001 client. Run from repository root with Lua 5.1.
unpack = unpack or table.unpack
local now = 1000000
local hour = 12
local rankIndex = 0
local guild = {
    { name = "Dadbod", rank = "Guild Master", online = true, level = 60, class = "Warrior" },
    { name = "Morg", rank = "Raider", online = false, level = 48, class = "Mage" },
}
local outgoing, printed = {}, {}
local requestCount = 0

function time() return now end
function GetGameTime() return hour, 0 end
function IsInGuild() return true end
function GetGuildInfo() return "Novus Ordo Mundi", "Guild Master", rankIndex end
function GuildRoster() requestCount = requestCount + 1 end
function GetNumGuildMembers() return #guild, 0 end
function GetGuildRosterInfo(i)
    local p = guild[i]
    if not p then return nil end
    return p.name, p.rank, 1, p.level, p.class, "Orgrimmar", "", "",
        p.online, "", "WARRIOR"
end
function GetCursorPosition() return 630, 530 end
C_ChatInfo = {
    SendChatMessage = function(message, channel, _, target)
        outgoing[#outgoing + 1] = { message = message, channel = channel, target = target }
    end,
}
DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, text) printed[#printed + 1] = text end
}
SlashCmdList = {}

local Widget = {}
Widget.__index = function(self, key)
    return rawget(Widget, key) or function() end
end
function Widget:SetScript(name, handler)
    local scripts = rawget(self, "scripts") or {}
    rawset(self, "scripts", scripts)
    scripts[name] = handler
end
function Widget:RegisterEvent(name)
    local events = rawget(self, "events") or {}
    rawset(self, "events", events)
    events[name] = true
end
function Widget:UnregisterEvent(name)
    local events = rawget(self, "events")
    if events then events[name] = nil end
end
function Widget:UnregisterAllEvents()
    self.events = {}
end
function Widget:CreateTexture() return setmetatable({}, Widget) end
function Widget:CreateFontString() return setmetatable({}, Widget) end
function Widget:SetText(value)
    self.text = value
    local scripts = rawget(self, "scripts")
    if scripts and scripts.OnTextChanged then
        scripts.OnTextChanged(self)
    end
end
function Widget:GetText() return self.text or "" end
function Widget:Show() self.visible = true end
function Widget:Hide() self.visible = false end
function Widget:IsShown() return self.visible == true end
function Widget:GetCenter() return 500, 500 end
function Widget:GetEffectiveScale() return 1 end
function Widget:SetBackdropBorderColor(...) self.border = { ... } end
function CreateFrame(_, name, parent)
    return setmetatable({ name = name, parent = parent }, Widget)
end
UIParent = setmetatable({}, Widget)
Minimap = setmetatable({}, Widget)
GameTooltip = setmetatable({}, Widget)

local ns = {}
assert(loadfile("ForgeGuildGreeter/Core.lua"))("ForgeGuildGreeter", ns)
assert(loadfile("ForgeGuildGreeter/UI.lua"))("ForgeGuildGreeter", ns)
assert(loadfile("ForgeGuildGreeter/Minimap.lua"))("ForgeGuildGreeter", ns)
local addon = assert(ns.Greeter)
assert(addon.version == "0.1.1")
addon:Initialize()
assert(requestCount >= 1)
assert(addon.frame and addon.minimapButton)
assert(addon.db.leaderOnly == true)
assert(addon.db.enabled.welcome and addon.db.enabled.online)
assert(addon.db.channels.welcome == "GUILD")
assert(addon.db.cooldownMinutes == 30)
assert(addon.ui.tab == "welcome")
assert(#addon.db.messages.welcome == 5, "Exactly five welcome templates expected")

-- Shuffled welcome bag must use each of the five distinct messages before
-- repeating, including across bag boundaries. All five remain editable.
local previous = nil
for round = 1, 4 do
    local seen = {}
    for i = 1, 5 do
        local message = addon:PickMessage("welcome")
        assert(message and not seen[message], "Duplicate welcome in the same five-message round")
        assert(message ~= previous, "Consecutive welcome messages must always differ")
        seen[message] = true
        previous = message
    end
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    assert(count == 5, "Every welcome must be used exactly once per round")
end

-- Simulating a UI reload: the persisted remaining bag must not reset.
local lastBeforeReload = addon:PickMessage("welcome")
local pendingBeforeReload = #addon.db.welcomeRotation.remaining
addon.lastPicked = {}
assert(#addon.db.welcomeRotation.remaining == pendingBeforeReload)
local nextWelcome = addon:PickMessage("welcome")
assert(nextWelcome ~= lastBeforeReload)
assert(#addon.db.welcomeRotation.remaining == pendingBeforeReload - 1)


-- Initial roster may already contain dozens online: zero greeting messages.
addon:ProcessRoster()
assert(addon.ready)
assert(#outgoing == 0, "Initial roster must never trigger greetings")
addon:ProcessRoster()
assert(#addon.queue == 0, "No change must not enqueue")

-- Online transition: one announcement only.
guild[2].online = true
addon:ProcessRoster()
assert(#addon.queue == 1 and addon.queue[1].kind == "online")
addon:ProcessRoster()
assert(#addon.queue == 1, "Duplicate roster update must not duplicate messages")
addon:ProcessQueue()
assert(#outgoing == 1)
assert(outgoing[1].channel == "GUILD")
assert(outgoing[1].message:find("Morg", 1, true))
assert(#addon.queue == 0)

-- New online guildmate is welcome, not separately logged in.
now = now + 10
guild[#guild + 1] = { name = "Thrall", rank = "Raider", online = true, level = 60, class = "Shaman" }
addon:ProcessRoster()
assert(#addon.queue == 1 and addon.queue[1].kind == "welcome")
addon:ProcessQueue()
assert(#outgoing == 2)
assert(outgoing[2].channel == "GUILD")
assert(outgoing[2].message:find("Thrall", 1, true))
assert(outgoing[2].message:find("Novus Ordo Mundi", 1, true) or
    outgoing[2].message:find("Thrall", 1, true))

-- Repeated login within cooldown should be suppressed.
now = now + 10
guild[2].online = false
addon:ProcessRoster()
guild[2].online = true
addon:ProcessRoster()
assert(#addon.queue == 0, "Repeated login during cooldown should be ignored")

-- Editable template library, add, delete, variables and preview.
assert(addon:SaveMessage("welcome", 1, "Greetings {player} of {guild}!"))
assert(not addon:SaveMessage("welcome", 2, "Greetings {player} of {guild}!"),
    "Duplicate welcome templates must be rejected")
assert(not addon:AddMessage("welcome", "Sixth welcome should be rejected"))
assert(not addon:DeleteMessage("welcome", 1))
local ok, idx = addon:AddMessage("online", "We see {class} {player}, level {level}.")
assert(ok and idx == 5)
assert(addon:Expand(addon.db.messages.online[idx],
    { name = "Thrall-Realm", rank = "Raider", class = "Shaman", level = 60 })
    == "We see Shaman Thrall, level 60.")
assert(addon:DeleteMessage("online", idx))
assert(#addon.db.messages.welcome == 5)
assert(not addon:SaveMessage("online", 1, ""))
assert(not addon:DeleteMessage("welcome", 100))

-- Settings are editable; preview uses no guild chat.
addon:ChangeTab("online")
assert(addon.ui.tab == "online")
addon:ChangeTab("settings")
assert(addon.ui.tab == "settings")
addon:ChangeTab("about")
assert(addon.ui.tab == "about")
addon:ChangeTab("welcome")
assert(addon.ui.tab == "welcome")
addon.db.channels.welcome = "LOCAL"
now = now + 10
guild[#guild + 1] = { name = "Tester", rank = "Raider", online = false, level = 12, class = "Druid" }
addon:ProcessRoster()
addon:ProcessQueue()
assert(#outgoing == 2, "Local channel must not send actual guild chat")
assert(addon.db.stats.welcome == 2)

-- PAUSE must suppress all greetings.
addon.minimapButton.scripts.OnClick(addon.minimapButton, "RightButton")
assert(addon.db.paused == true)
now = now + 10
guild[#guild + 1] = { name = "PausedUser", rank = "Raider", online = true }
addon:ProcessRoster()
assert(#addon.queue == 0, "Pause must block queues")
addon.minimapButton.scripts.OnClick(addon.minimapButton, "RightButton")
assert(addon.db.paused == false)

-- Non-leader must not broadcast unless explicitly allowed.
rankIndex = 1
now = now + 10
guild[#guild + 1] = { name = "LeaderTest", rank = "Raider", online = true }
addon:ProcessRoster()
assert(#addon.queue == 0)
addon.db.leaderOnly = false
addon.db.channels.welcome = "WHISPER"
addon.db.maxPerFiveMinutes = 8
now = now + 10
guild[#guild + 1] = { name = "WhisperTest", rank = "Raider", online = true }
addon:ProcessRoster()
addon:ProcessQueue()
assert(#outgoing == 3)
assert(outgoing[3].channel == "WHISPER" and outgoing[3].target == "WhisperTest")

-- Quiet hours use server time and suppress new queue entries.
addon.db.quietEnabled = true
addon.db.quietStart = 23
addon.db.quietEnd = 8
hour = 23
now = now + 10
guild[#guild + 1] = { name = "NightOwl", rank = "Raider", online = true }
addon:ProcessRoster()
assert(#addon.queue == 0)
hour = 9
assert(not addon:IsQuiet())
hour = 3
assert(addon:IsQuiet())
addon.db.quietEnabled = false

-- Messages over 255 bytes must not be broadcast.
addon.db.discordEnabled = true
addon.db.discordText = string.rep("a", 240)
now = now + 10
guild[#guild + 1] = { name = "LongMessage", rank = "Raider", online = true }
addon:ProcessRoster()
assert(#addon.queue == 1)
addon:ProcessQueue()
assert(#outgoing == 3 and #addon.queue == 0)
addon.db.discordEnabled = false

-- Pending messages are discarded if a member leaves before dispatch.
addon.db.discordEnabled = false
addon.db.channels.welcome = "GUILD"
now = now + 10
guild[#guild + 1] = { name = "HitAndRun", rank = "Raider", online = true }
addon:ProcessRoster()
assert(#addon.queue == 1)
table.remove(guild, #guild)
addon:ProcessRoster()
addon:ProcessQueue()
assert(#outgoing == 3, "Do not welcome a member who already left")

-- Pause clears pending greetings immediately (not just at next queue tick).
now = now + 10
guild[#guild + 1] = { name = "Pending", rank = "Raider", online = true }
addon:ProcessRoster()
assert(#addon.queue == 1)
addon.minimapButton.scripts.OnClick(addon.minimapButton, "RightButton")
assert(#addon.queue == 0 and addon.db.paused)
addon.minimapButton.scripts.OnClick(addon.minimapButton, "RightButton")
assert(not addon.db.paused)

-- The slash command and minimap control exist and retain position.
assert(type(SlashCmdList.FORGEGUILDGREETER) == "function")
SlashCmdList.FORGEGUILDGREETER("status")
SlashCmdList.FORGEGUILDGREETER("welcome")
assert(not addon.db.enabled.welcome)
SlashCmdList.FORGEGUILDGREETER("welcome")
assert(addon.db.enabled.welcome)
addon.minimapButton.scripts.OnDragStart(addon.minimapButton)
addon.minimapButton.scripts.OnUpdate(addon.minimapButton)
addon.minimapButton.scripts.OnDragStop(addon.minimapButton)
assert(type(addon.db.minimapAngle) == "number")

print("FORGE GuildGreeter: roster, greeting, spam, editable UI, rank, whisper, pause and quiet-hours smoke tests passed.")
