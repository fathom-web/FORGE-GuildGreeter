local _, ns = ...
local Greeter = ns.Greeter

-- Small feature layer: event status, safe user-triggered testing, welcome
-- whisper, activity log and defaults. This intentionally uses WoW chat APIs
-- only; it never tries to evade protected actions or chat restrictions.
Greeter.onlineCooldownOptions = { 1, 6, 12, 24, 48 }

local function Contains(items, value)
    for _, item in ipairs(items) do if item == value then return true end end
    return false
end

local function Trim(text)
    return type(text) == "string" and (text:match("^%s*(.-)%s*$") or "") or ""
end

local function LocalPlayer()
    if type(UnitName) == "function" then
        local name = UnitName("player")
        if type(name) == "string" and name ~= "" then return name end
    end
    return "Adventurer"
end

function Greeter:InitQuality()
    local db = self.db
    if not Contains(self.onlineCooldownOptions, db.onlineCooldownHours) then
        db.onlineCooldownHours = 24
    end
    if type(db.manualMode) ~= "boolean" then db.manualMode = false end
    if type(db.setupSeen) ~= "boolean" then db.setupSeen = false end
    if type(db.welcomeWhisperEnabled) ~= "boolean" then
        db.welcomeWhisperEnabled = false
    end
    if type(db.welcomeWhisperText) ~= "string" then
        db.welcomeWhisperText =
            "Welcome to {guild}, {player}! Join our Discord - ask an officer for an invite."
    end
    if type(db.activity) ~= "table" then db.activity = {} end
    while #db.activity > 10 do table.remove(db.activity) end
    if type(db.lastWhisper) ~= "table" then db.lastWhisper = {} end
    local now = self:Now()
    for key, stamp in pairs(db.lastWhisper) do
        if type(stamp) ~= "number" or stamp > now or now - stamp > 604800 then
            db.lastWhisper[key] = nil
        end
    end
    -- Transient state: we cannot confirm delivery just from the API call.
    self.chatBlocked = false
    self.lastAttempt = nil
end

function Greeter:LogAction(status, kind, player, message)
    if not self.db then return end
    local entry = {
        at = self:Now(), status = tostring(status),
        kind = tostring(kind or ""), player = tostring(player or ""),
        message = tostring(message or ""),
    }
    table.insert(self.db.activity, 1, entry)
    while #self.db.activity > 10 do table.remove(self.db.activity) end
    self.lastAttempt = entry
    if self.UpdateActivity then self:UpdateActivity() end
    if self.UpdateStatus then self:UpdateStatus() end
end

function Greeter:StatusText()
    if self.chatBlocked then
        return self:PendingCount() > 0 and "CHAT BLOCKED - SEND PENDING"
            or "CHAT BLOCKED - USE SEND TEST"
    end
    if self.db.paused then return "PAUSED" end
    if self.db.manualMode then return "MANUAL MODE" end
    if not self.ready then return "LOADING ROSTER" end
    local allowed, reason = self:CanAnnounce()
    if not allowed then return "INACTIVE: " .. tostring(reason) end
    return "ACTIVE"
end

function Greeter:TryChat(content, channel, recipient)
    if type(content) ~= "string" or content == "" or #content > 255 then
        return false, "Message too long or empty"
    end
    local sender
    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        sender = C_ChatInfo.SendChatMessage
    elseif type(SendChatMessage) == "function" then
        sender = SendChatMessage
    else
        return false, "Chat API unavailable"
    end
    -- A successful protected call means submission was attempted. There is
    -- no guarantee of server delivery. Blocked calls are not retried/spammed.
    local ok, result = pcall(sender, content, channel, nil, recipient)
    if not ok then return false, tostring(result) end
    if result == false then return false, "Chat API returned false" end
    return true
end

function Greeter:TryWelcomeWhisper(member)
    local db = self.db
    if not db.welcomeWhisperEnabled or db.channels.welcome == "LOCAL"
        or db.channels.welcome == "WHISPER" or member.online == false then return end
    local key = string.lower(member.name or "")
    if key == "" then return end
    local previous = db.lastWhisper[key]
    local now = self:Now()
    if type(previous) == "number" and now - previous < 86400 then return end
    local template = Trim(db.welcomeWhisperText)
    if template == "" then return end
    local text = self:Expand(template, member)
    local ok, reason = self:TryChat(text, "WHISPER", member.name)
    if ok then
        db.lastWhisper[key] = now
        self:LogAction("REQUESTED", "whisper", member.name, text)
    else
        self.chatBlocked = true
        self:LogAction("BLOCKED", "whisper", member.name, reason)
        self:Print("Welcome whisper was blocked: " .. reason)
    end
end

-- Keep the original dedicated guild-chat handler, but audit delivery attempts.
function Greeter:Send(kind, member, content)
    local channel = self.db.channels[kind] or "LOCAL"
    if channel == "LOCAL" then
        self:LogAction("LOCAL", kind, member.name, content)
        self:Print("[PREVIEW " .. string.upper(kind) .. "] " .. content)
        return true
    end
    local ok, why = self:TryChat(content, channel,
        channel == "WHISPER" and member.name or nil)
    if not ok then
        self.chatBlocked = true
        self:LogAction("BLOCKED", kind, member.name, why)
        self:Print("Chat could not be sent: " .. why .. ". Use SEND TEST or LOCAL.")
        return false
    end
    self.chatBlocked = false
    self:LogAction("REQUESTED", kind, member.name, content)
    if kind == "welcome" then self:TryWelcomeWhisper(member) end
    return true
end

function Greeter:PreviewSelected(kind, text)
    local fake = { name = LocalPlayer(), class = "Adventurer", level = "?",
                   rank = "Guild Member" }
    local message = self:Expand(text, fake)
    if kind == "welcome" and self.db.discordEnabled
        and Trim(self.db.discordText) ~= "" then
        message = message .. " " .. self:Expand(self.db.discordText, fake)
    end
    self:LogAction("PREVIEW", kind, fake.name, message)
    self:Print("[PREVIEW] " .. message)
    return message
end

function Greeter:SendTest(kind, text)
    -- This is called only from a deliberate user click in the UI. Do not
    -- consume automatic rotations, per-player cooldowns or the activity limit.
    local player = LocalPlayer()
    local member = { name = player, class = "Adventurer", level = "?",
                     rank = "Guild Member" }
    local message = self:Expand(text, member)
    if kind == "welcome" and self.db.discordEnabled
        and Trim(self.db.discordText) ~= "" then
        message = message .. " " .. self:Expand(self.db.discordText, member)
    end
    if self.db.channels[kind] == "LOCAL" then
        self:LogAction("TEST LOCAL", kind, player, message)
        self:Print("[TEST PREVIEW] " .. message)
        return true
    end
    local channel = self.db.channels[kind]
    local content = "[TEST] " .. message
    local ok, reason = self:TryChat(content, channel,
        channel == "WHISPER" and player or nil)
    if not ok then
        self.chatBlocked = true
        self:LogAction("BLOCKED", "test " .. kind, player, reason)
        self:Print("Test message blocked: " .. reason)
        return false
    end
    self.chatBlocked = false
    self:LogAction("TEST REQUESTED", kind, player, content)
    self:Print("Test submitted to " .. channel ..
        " (delivery still needs in-game verification).")
    return true
end

function Greeter:RestoreTemplate(kind, index)
    local default = self.defaults[kind] and self.defaults[kind][index]
    if type(default) ~= "string" then
        return false, "No original text for this message slot."
    end
    return self:SaveMessage(kind, index, default)
end

function Greeter:ResetOptions()
    local db = self.db
    db.enabled.welcome = true
    db.enabled.online = true
    db.leaderOnly = true
    db.paused = false
    db.manualMode = false
    db.randomMessages = true
    -- Retain both in-progress 15-message bags; resetting settings does not
    -- consume or reshuffle already scheduled greetings.
    db.discordEnabled = false
    db.welcomeWhisperEnabled = false
    db.quietEnabled = false
    db.quietStart = 23
    db.quietEnd = 8
    db.cooldownMinutes = 30
    db.onlineCooldownHours = 24
    db.spacingSeconds = 10
    db.maxPerFiveMinutes = 3
    db.channels.welcome = "GUILD"
    db.channels.online = "GUILD"
    db.discordText = "Join our Discord! Ask an officer for an invite."
    db.welcomeWhisperText =
        "Welcome to {guild}, {player}! Join our Discord - ask an officer for an invite."
    self.queue, self.queuedKeys = {}, {}
    self.pendingManual, self.manualKeys = {}, {}
    self.chatBlocked = false
    -- Reset options, never delete the user's five customized welcome texts.
    self:LogAction("RESET", "settings", LocalPlayer(), "Options restored; messages retained")
    self:RefreshUI()
end


-- Snapshot the welcome shuffle bag before attempting to send. A failed API
-- call must not silently spend one of the five customizable welcome messages.
function Greeter:SnapshotRotation(kind)
    local rotation = self:GetRotation(kind)
    if not rotation then return nil end
    local snapshot = { lastIndex = rotation.lastIndex, remaining = {} }
    for i, value in ipairs(rotation.remaining) do
        snapshot.remaining[i] = value
    end
    return snapshot
end

function Greeter:RestoreRotation(kind, snapshot)
    local rotation = self:GetRotation(kind)
    if not rotation or not snapshot then return end
    rotation.lastIndex = snapshot.lastIndex
    rotation.remaining = {}
    for i, value in ipairs(snapshot.remaining) do
        rotation.remaining[i] = value
    end
end

function Greeter:HoldForManual(entry)
    if not self.pendingManual or not entry then return false end
    if self.manualKeys[entry.key] then return false end
    if #self.pendingManual >= 20 then
        self:LogAction("SKIPPED", entry.kind, entry.member.name,
            "Manual queue full (20); greeting not stored")
        return false
    end
    self.pendingManual[#self.pendingManual + 1] = {
        kind = entry.kind, key = entry.key,
        member = { name = entry.member.name },
        enqueued = entry.enqueued,
    }
    self.manualKeys[entry.key] = true
    self:RefreshUI()
    return true
end

function Greeter:PendingCount()
    return self.pendingManual and #self.pendingManual or 0
end

function Greeter:DiscardFirstPending()
    if not self.pendingManual or #self.pendingManual == 0 then return nil end
    local entry = table.remove(self.pendingManual, 1)
    self.manualKeys[entry.key] = nil
    return entry
end

function Greeter:SendNextPending()
    -- Only called from an actual click on the "SEND NEXT" WoW UI button or
    -- another deliberate user invocation. Never called from OnUpdate.
    if self:PendingCount() == 0 then
        self:Print("No pending greetings.")
        return false
    end
    if not self:CanAnnounce() or self:IsQuiet() then
        self:Print("Greeting is paused, inactive or within quiet hours.")
        return false
    end
    local now = self:Now()
    local entry = self.pendingManual[1]
    if now - entry.enqueued > 1800 then
        self:DiscardFirstPending()
        self:Print("Pending greeting expired after 30 minutes.")
        self:RefreshUI()
        return false
    end
    local member = self.roster[string.lower(entry.member.name)]
    if not member or (entry.kind == "online" and not member.online) then
        self:DiscardFirstPending()
        self:Print("Member is no longer eligible; pending greeting discarded.")
        self:RefreshUI()
        return false
    end
    local cooldown = entry.kind == "online"
        and self.db.onlineCooldownHours * 3600 or self.db.cooldownMinutes * 60
    local last = self.db.lastSent[entry.key]
    if type(last) == "number" and now - last < cooldown then
        self:DiscardFirstPending()
        self:Print("Greeting already sent within cooldown; discarded duplicate.")
        self:RefreshUI()
        return false
    end
    if now - self.lastBroadcast < self.db.spacingSeconds then
        self:Print("Chat spacing is active. Try sending again shortly.")
        return false
    end
    local stamps = {}
    for _, stamp in ipairs(self.sentTimes) do
        if now - stamp < 300 then stamps[#stamps + 1] = stamp end
    end
    self.sentTimes = stamps
    if #stamps >= self.db.maxPerFiveMinutes then
        self:Print("Rate limit reached. Try again after the five-minute window.")
        return false
    end
    local before = self:SnapshotRotation(entry.kind)
    local message = self:Compose(entry.kind, member)
    if not message then
        self:RestoreRotation(entry.kind, before)
        self:LogAction("BLOCKED", entry.kind, member.name,
            "Invalid greeting. Edit template before retry.")
        return false
    end
    if self.db.channels[entry.kind] == "LOCAL" then
        self:RestoreRotation(entry.kind, before)
        self:Send(entry.kind, member, message)
        self:DiscardFirstPending()
        self:RefreshUI()
        return true
    end
    if not self:Send(entry.kind, member, message) then
        self:RestoreRotation(entry.kind, before)
        self:Print("Pending greeting remains queued. Try a manual click again.")
        return false
    end
    self:DiscardFirstPending()
    self.lastBroadcast = now
    self.sentTimes[#self.sentTimes + 1] = now
    self.db.lastSent[entry.key] = now
    self.db.stats[entry.kind] = (self.db.stats[entry.kind] or 0) + 1
    self:RefreshUI()
    return true
end

function Greeter:RunSetupCheck()
    self.db.setupSeen = true
    local ok, why = self:CanAnnounce()
    self:Print("Setup check - guild: " .. self:GuildName() ..
        " | roster: " .. (self.ready and "ready" or "loading"))
    self:Print("Broadcast eligibility: " ..
        (ok and "allowed" or tostring(why)))
    local hasChat = (C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function")
        or type(SendChatMessage) == "function"
    self:Print("Chat API: " .. (hasChat and "present" or "not available") ..
        " | mode: " .. (self.db.manualMode and "manual" or "automatic"))
    self:Print("Welcome: " .. (self.db.enabled.welcome and "ON" or "OFF") ..
        " | online: " .. (self.db.enabled.online and "ON" or "OFF") ..
        " | pending: " .. self:PendingCount())
    self:Print("Next: use PREVIEW, then SEND TEST. Real automatic delivery must be checked with a guildmate.")
    self:RefreshUI()
    return ok and self.ready and hasChat and true or false
end
