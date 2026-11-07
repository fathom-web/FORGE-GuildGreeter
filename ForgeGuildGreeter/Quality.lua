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
    if self.chatBlocked then return "CHAT BLOCKED" end
    if self.db.paused then return "PAUSED" end
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
    local ok, err = pcall(sender, content, channel, nil, recipient)
    if not ok then return false, tostring(err) end
    return true
end

function Greeter:TryWelcomeWhisper(member)
    local db = self.db
    if not db.welcomeWhisperEnabled or db.channels.welcome == "LOCAL" then return end
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
local originalSend = Greeter.Send
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
    db.randomMessages = true
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
    -- Reset options, never delete the user's five customized welcome texts.
    self:LogAction("RESET", "settings", LocalPlayer(), "Options restored; messages retained")
    self:RefreshUI()
end
