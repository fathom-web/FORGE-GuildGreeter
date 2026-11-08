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
assert(loadfile("ForgeGuildGreeter/Quality.lua"))("ForgeGuildGreeter", ns)
assert(loadfile("ForgeGuildGreeter/UI.lua"))("ForgeGuildGreeter", ns)
assert(loadfile("ForgeGuildGreeter/Minimap.lua"))("ForgeGuildGreeter", ns)
local addon = assert(ns.Greeter)
assert(addon.version == "0.3.0")
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
now = now + 3
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
now = now + 3
addon:ProcessRoster()
addon:ProcessQueue()
assert(#outgoing == 2, "Local channel must not send actual guild chat")
assert(addon.db.stats.welcome == 1, "LOCAL preview should not consume welcome rotation")

-- PAUSE must suppress all greetings.
addon.minimapButton.scripts.OnClick(addon.minimapButton, "RightButton")
assert(addon.db.paused == true)
now = now + 10
guild[#guild + 1] = { name = "PausedUser", rank = "Raider", online = true }
addon:ProcessRoster()
now = now + 3
addon:ProcessRoster()
assert(#addon.queue == 0, "Pause must block queues")
addon.minimapButton.scripts.OnClick(addon.minimapButton, "RightButton")
assert(addon.db.paused == false)

-- Non-leader must not broadcast unless explicitly allowed.
rankIndex = 1
now = now + 10
guild[#guild + 1] = { name = "LeaderTest", rank = "Raider", online = true }
addon:ProcessRoster()
now = now + 3
addon:ProcessRoster()
assert(#addon.queue == 0)
addon.db.leaderOnly = false
addon.db.channels.welcome = "WHISPER"
addon.db.maxPerFiveMinutes = 8
now = now + 10
guild[#guild + 1] = { name = "WhisperTest", rank = "Raider", online = true }
addon:ProcessRoster()
now = now + 3
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
now = now + 3
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
now = now + 3
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
assert(#addon.queue == 0, "Unconfirmed joins must never be queued")
table.remove(guild, #guild)
addon:ProcessRoster()
addon:ProcessQueue()
assert(#outgoing == 3, "Do not welcome a member who already left")

-- Pause clears pending greetings immediately (not just at next queue tick).
now = now + 10
guild[#guild + 1] = { name = "Pending", rank = "Raider", online = true }
addon:ProcessRoster()
now = now + 3
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

-- v0.2 quality: activity is local, bounded, and delivery is not assumed.
assert(addon.db.onlineCooldownHours == 24)
assert(#addon.db.activity <= 10)
assert(addon:StatusText() == "ACTIVE" or addon:StatusText():find("INACTIVE"))

-- Preview never sends chat or consumes the welcome rotation.
local outBefore = #outgoing
local pending = #addon.db.welcomeRotation.remaining
local previousIndex = addon.db.welcomeRotation.lastIndex
addon:PreviewSelected("welcome", "Hi {player}, welcome to {guild}!")
assert(#outgoing == outBefore and #addon.db.welcomeRotation.remaining == pending)
assert(addon.db.welcomeRotation.lastIndex == previousIndex)
assert(addon.db.activity[1].status == "PREVIEW")

-- Send Test uses an explicit button action; it is not an automatic event.
assert(addon:SendTest("welcome", "Hi {player}!"))
assert(#outgoing == outBefore + 1)
assert(outgoing[#outgoing].message:find("[TEST]", 1, true))
assert(addon.db.activity[1].status == "TEST REQUESTED")

-- A blocked API is observable; no fake "delivered" state.
local sender = C_ChatInfo.SendChatMessage
C_ChatInfo.SendChatMessage = function() error("protected chat operation") end
assert(not addon:SendTest("welcome", "Hello!"))
assert(addon:StatusText():find("CHAT BLOCKED", 1, true))
assert(addon.db.activity[1].status == "BLOCKED")
C_ChatInfo.SendChatMessage = function() return false end
assert(not addon:SendTest("welcome", "Hello!"))
assert(addon:StatusText():find("CHAT BLOCKED", 1, true))
C_ChatInfo.SendChatMessage = sender
assert(addon:SendTest("welcome", "Hello!"))
assert(addon:StatusText() == "ACTIVE")

-- Personal whisper is optional and limited to one request/player/day.
local guest = {name = "WhisperGuest", class = "Paladin", level = 17, rank = "Member"}
addon.db.channels.welcome = "GUILD"
addon.db.welcomeWhisperEnabled = true
local initial = #outgoing
assert(addon:Send("welcome", guest, "Welcome!"))
assert(#outgoing == initial + 2)
assert(outgoing[#outgoing].channel == "WHISPER")
assert(outgoing[#outgoing].target == "WhisperGuest")
assert(addon:Send("welcome", guest, "Welcome again!"))
assert(#outgoing == initial + 3, "Whisper cooldown must suppress duplicate")
addon.db.welcomeWhisperEnabled = false
assert(#addon.db.activity == 10, "Last-ten activity history must be capped")

-- Different cooldown policies for welcome and online messages.
now = now + 50
addon.db.lastSent["online:hourguest"] = now - 3600
addon.db.onlineCooldownHours = 24
addon:Queue("online", {name = "HourGuest", online = true})
assert(#addon.queue == 0, "Online greeting should be limited to once per 24h")
addon.db.onlineCooldownHours = 1
addon:Queue("online", {name = "HourGuest", online = true})
assert(#addon.queue == 1, "Shorter custom online cooldown should work")
addon.queue, addon.queuedKeys = {}, {}

-- Edited messages and settings can be restored independently.
assert(addon:RestoreTemplate("welcome", 1))
assert(addon.db.messages.welcome[1] == addon.defaults.welcome[1])
assert(addon:RestoreTemplate("online", 1))
assert(addon.db.messages.online[1] == addon.defaults.online[1])
local originalFive = {}
for i = 1, 5 do originalFive[i] = addon.db.messages.welcome[i] end
addon.db.onlineCooldownHours = 1
addon.db.enabled.welcome = false
addon.ui.resetButton.scripts.OnClick()
assert(not addon.db.enabled.welcome, "First reset click must only ask for confirmation")
addon.ui.resetButton.scripts.OnClick()
assert(addon.db.enabled.welcome and addon.db.onlineCooldownHours == 24)
for i = 1, 5 do
    assert(addon.db.messages.welcome[i] == originalFive[i],
        "Options reset should never delete customized greetings")
end


-- First-run setup is a real button; never assumes that server delivery works.
assert(addon.ui.setupButton and addon.ui.setupButton.scripts.OnClick)
addon.db.setupSeen = false
addon.ui.setupButton.scripts.OnClick()
assert(addon.db.setupSeen)
assert(addon.ui.sendNextButton and addon.ui.manualBtn)
assert(addon.ui.queueLabel.text:find("MANUAL", 1, true))

-- Partial roster rows must be ignored, even if the reported count is intact.
local originalInfo = GetGuildRosterInfo
local knownBefore = #addon.queue
GetGuildRosterInfo = function(i)
    if i == 2 then return nil end
    return originalInfo(i)
end
addon:ProcessRoster()
assert(#addon.queue == knownBefore)
GetGuildRosterInfo = originalInfo

-- Each new guild member needs two complete, time-separated observations.
now = now + 400
guild[#guild + 1] = {
    name = "VerifiedJoin", rank = "Raider", online = true, class = "Druid", level = 22
}
addon:ProcessRoster()
assert(#addon.queue == 0, "First roster snapshot cannot announce a guild join")
now = now + 3
addon:ProcessRoster()
assert(#addon.queue == 1 and addon.queue[1].kind == "welcome")
addon.queue, addon.queuedKeys = {}, {}

-- A failed automatic send must leave the shuffle bag and cooldown unchanged,
-- and it must be recoverable via a real UI-click fallback.
now = now + 30
guild[#guild + 1] = {
    name = "FailedJoin", rank = "Raider", online = true, class = "Hunter", level = 21
}
addon:ProcessRoster()
assert(#addon.queue == 0)
now = now + 3
addon:ProcessRoster()
assert(#addon.queue == 1)
addon.db.channels.welcome = "GUILD"
addon.db.manualMode = false
addon.db.maxPerFiveMinutes = 8
local lastIndex = addon.db.welcomeRotation.lastIndex
local remaining = #addon.db.welcomeRotation.remaining
local outgoingBeforeFail = #outgoing
local savedSender = C_ChatInfo.SendChatMessage
C_ChatInfo.SendChatMessage = function() error("chat protected") end
addon:ProcessQueue()
assert(#outgoing == outgoingBeforeFail)
assert(#addon.queue == 0 and addon:PendingCount() == 1)
assert(addon.db.welcomeRotation.lastIndex == lastIndex)
assert(#addon.db.welcomeRotation.remaining == remaining)
assert(not addon.db.lastSent["welcome:failedjoin"])
assert(addon.ui.sendNextButton.enabled)
assert(addon.ui.queueLabel.text:find("MANUAL: 1", 1, true))

C_ChatInfo.SendChatMessage = savedSender
addon.ui.sendNextButton.scripts.OnClick()
assert(addon:PendingCount() == 0)
assert(#outgoing == outgoingBeforeFail + 1)
assert(addon.db.lastSent["welcome:failedjoin"])
assert(not addon.chatBlocked)

-- Manual-only mode must queue, not send automatically; click sends one event.
now = now + 20
addon.db.manualMode = true
guild[#guild + 1] = {
    name = "ManualJoin", rank = "Raider", online = true, class = "Mage", level = 50
}
addon:ProcessRoster()
now = now + 3
addon:ProcessRoster()
assert(#addon.queue == 1)
local beforeManual = #outgoing
addon:ProcessQueue()
assert(#outgoing == beforeManual and addon:PendingCount() == 1)
addon.ui.sendNextButton.scripts.OnClick()
assert(#outgoing == beforeManual + 1 and addon:PendingCount() == 0)
addon.db.manualMode = false

-- A silent LOCAL preview should not advance the five-message cycle.
now = now + 20
addon.db.channels.welcome = "LOCAL"
guild[#guild + 1] = {
    name = "PreviewOnly", rank = "Raider", online = false, class = "Rogue", level = 12
}
addon:ProcessRoster()
now = now + 3
addon:ProcessRoster()
local beforeLocal = addon:SnapshotRotation("welcome")
local sentBeforeLocal = #outgoing
addon:ProcessQueue()
assert(#outgoing == sentBeforeLocal)
assert(addon.db.welcomeRotation.lastIndex == beforeLocal.lastIndex)
assert(#addon.db.welcomeRotation.remaining == #beforeLocal.remaining)
assert(not addon.db.lastSent["welcome:previewonly"])

-- Sudden mass additions must be rebaselined instead of welcomed.
addon.db.channels.welcome = "GUILD"
now = now + 10
for i = 1, 4 do
    guild[#guild + 1] = {
        name = "MassJoin" .. i, rank = "Raider", online = true
    }
end
addon:ProcessRoster()
now = now + 3
addon:ProcessRoster()
assert(#addon.queue == 0, "Guild roster refill must not flood chat")
assert(addon:PendingCount() == 0)

print("FORGE GuildGreeter v0.3: mock checks passed.")

