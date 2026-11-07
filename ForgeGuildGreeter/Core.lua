local addonName, ns = ...
local Greeter = {}
ns.Greeter = Greeter

Greeter.version = "0.1.1"
Greeter.brand = "NOVYX FORGE"
Greeter.channels = { "GUILD", "WHISPER", "OFFICER", "LOCAL" }
Greeter.cooldowns = { 5, 15, 30, 60, 120 }
Greeter.spacings = { 5, 10, 15, 30 }
Greeter.limits = { 1, 2, 3, 5, 8 }
Greeter.defaults = {
    welcome = {
        "Welcome {player} to {guild}! Your repair bills are now our entertainment. FOR THE HORDE!",
        "A new adventurer appears! Welcome {player}! We have cookies. Probably.",
        "Welcome aboard, {player}! Bad pulls, terrible jokes and good times guaranteed.",
        "Everybody wave! {player} just joined {guild}. No refunds!",
        "Welcome {player}! Leave your dignity at the door. We lost ours several wipes ago.",
    },
    online = {
        "Look who's back! {player} has returned. Hide the good loot!",
        "{player} is online! The respawn timer on our chaos has ended.",
        "Welcome back, {player}! Your daily dose of questionable decisions awaits.",
        "Breaking news: {player} logged in. The guild's collective IQ remains unchanged.",
    },
}
Greeter.quietHours = { start = 23, finish = 8 }

local function CopyArray(source)
    local copy = {}
    for i, value in ipairs(source) do copy[i] = value end
    return copy
end

local function Clamp(n, minimum, maximum, fallback)
    if type(n) ~= "number" then return fallback end
    n = math.floor(n)
    return math.max(minimum, math.min(maximum, n))
end

local function HasValue(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

local function SafeName(value)
    if type(value) ~= "string" then return nil end
    return string.lower(value)
end

local function ShortName(name)
    return type(name) == "string" and (name:match("^([^-]+)") or name) or "Adventurer"
end

function Greeter:Print(value)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd5af67FORGE GuildGreeter|r  " .. tostring(value))
    end
end

function Greeter:Now()
    return type(time) == "function" and time() or 0
end

function Greeter:IsGuilded()
    if type(IsInGuild) == "function" then return IsInGuild() end
    if type(GetGuildInfo) == "function" then return GetGuildInfo("player") ~= nil end
    return false
end

function Greeter:GuildName()
    if type(GetGuildInfo) == "function" then
        local name = GetGuildInfo("player")
        if type(name) == "string" and name ~= "" then return name end
    end
    return "the guild"
end

function Greeter:CanAnnounce()
    if not self:IsGuilded() then return false, "not in a guild" end
    if self.db.paused then return false, "paused" end
    if not self.db.leaderOnly then return true end
    if type(GetGuildInfo) ~= "function" then return false, "cannot verify guild rank" end
    local _, _, rankIndex = GetGuildInfo("player")
    if rankIndex ~= 0 then return false, "Guild Master only" end
    return true
end

function Greeter:IsQuiet()
    if not self.db.quietEnabled then return false end
    if type(GetGameTime) ~= "function" then return false end
    local hour = GetGameTime()
    if type(hour) ~= "number" then return false end
    local first, last = self.db.quietStart, self.db.quietEnd
    if first == last then return false end
    if first < last then return hour >= first and hour < last end
    return hour >= first or hour < last
end

function Greeter:RequestRoster()
    if not self:IsGuilded() then return end
    if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
        C_GuildInfo.GuildRoster()
    elseif type(GuildRoster) == "function" then
        GuildRoster()
    end
end

function Greeter:ReadRoster()
    if type(GetNumGuildMembers) ~= "function"
        or type(GetGuildRosterInfo) ~= "function" then return nil end
    local count = GetNumGuildMembers()
    if type(count) ~= "number" or count < 1 then return nil end
    local snapshot = {}
    for i = 1, count do
        local name, rank, _, level, class, _, _, _, online = GetGuildRosterInfo(i)
        if type(name) == "string" and name ~= "" then
            snapshot[SafeName(name)] = {
                name = name, rank = rank or "", class = class or "",
                level = level or "?", online = online and true or false,
            }
        end
    end
    if not next(snapshot) then return nil end
    return snapshot
end

function Greeter:Expand(template, member)
    local vars = {
        player = ShortName(member.name),
        full = member.name,
        guild = self:GuildName(),
        class = tostring(member.class),
        level = tostring(member.level),
        rank = tostring(member.rank),
    }
    return (template:gsub("{([%w_]+)}", function(key)
        return vars[key] or "{" .. key .. "}"
    end))
end

-- Welcome messages have five fixed editable slots. Their shuffled-bag state
-- is saved, so reloading the game does not restart the cycle or repeat a slot.
function Greeter:PickWelcomeMessage()
    local items = self.db.messages.welcome
    local rotation = self.db.welcomeRotation
    if not rotation then
        rotation = { remaining = {}, lastIndex = 0 }
        self.db.welcomeRotation = rotation
    end
    if #rotation.remaining == 0 then
        local bag = {}
        if self.db.randomMessages then
            for i = 1, #items do bag[i] = i end
            for i = #bag, 2, -1 do
                local j = math.random(i)
                bag[i], bag[j] = bag[j], bag[i]
            end
        else
            -- Preserve the previous choice when switching rotation modes.
            local start = (rotation.lastIndex % #items) + 1
            for i = 1, #items do
                bag[i] = ((start + i - 2) % #items) + 1
            end
        end
        if #bag > 1 and bag[1] == rotation.lastIndex then
            bag[1], bag[2] = bag[2], bag[1]
        end
        rotation.remaining = bag
    end
    local index = table.remove(rotation.remaining, 1)
    rotation.lastIndex = index
    return items[index]
end

function Greeter:PickMessage(kind)
    local items = self.db.messages[kind]
    if not items or #items == 0 then return nil end
    if kind == "welcome" then
        return self:PickWelcomeMessage()
    end
    local index
    if self.db.randomMessages and #items > 1 then
        index = math.random(#items)
        if index == self.lastPicked[kind] then
            index = (index % #items) + 1
        end
    else
        index = ((self.lastPicked[kind] or 0) % #items) + 1
    end
    self.lastPicked[kind] = index
    return items[index]
end

function Greeter:Compose(kind, member)
    local template = self:PickMessage(kind)
    if not template then return nil end
    local message = self:Expand(template, member)
    if kind == "welcome" and self.db.discordEnabled
        and self.db.discordText ~= "" then
        message = message .. " " .. self:Expand(self.db.discordText, member)
    end
    if #message > 255 then
        self:Print("Message is over 255 bytes. Shorten the template or Discord text.")
        return nil
    end
    return message
end

function Greeter:Queue(kind, member)
    if not self.db.enabled[kind] then return end
    if self:IsQuiet() then return end
    local allowed = self:CanAnnounce()
    if not allowed then return end
    if #self.queue >= 20 then return end

    local key = kind .. ":" .. SafeName(member.name)
    local last = self.db.lastSent[key]
    local now = self:Now()
    if type(last) == "number" and now - last < self.db.cooldownMinutes * 60 then return end
    if self.queuedKeys[key] then return end
    self.queue[#self.queue + 1] = {
        kind = kind, member = member, key = key, enqueued = now,
    }
    self.queuedKeys[key] = true
end

function Greeter:Send(kind, member, content)
    local channel = self.db.channels[kind]
    if channel == "LOCAL" then
        self:Print("[PREVIEW " .. string.upper(kind) .. "] " .. content)
        return true
    end
    if not (C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function")
        and type(SendChatMessage) ~= "function" then
        self:Print("Chat API unavailable. Message not sent.")
        return false
    end
    local recipient = channel == "WHISPER" and member.name or nil
    local sender = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    -- Some Forever/Blizzard clients may block unattended chat actions.
    -- Protected chat failures are logged, never bypassed.
    local ok, err = pcall(sender, content, channel, nil, recipient)
    if not ok then
        self:Print("Chat blocked or failed: " .. tostring(err))
        return false
    end
    return true
end

function Greeter:ProcessQueue()
    if #self.queue == 0 then return end
    local now = self:Now()
    if self:IsQuiet() then
        self.queue, self.queuedKeys = {}, {}
        return
    end
    local permitted = self:CanAnnounce()
    if not permitted then
        self.queue, self.queuedKeys = {}, {}
        return
    end
    if now - self.lastBroadcast < self.db.spacingSeconds then return end

    local kept = {}
    for _, stamp in ipairs(self.sentTimes) do
        if now - stamp < 300 then kept[#kept + 1] = stamp end
    end
    self.sentTimes = kept
    if #kept >= self.db.maxPerFiveMinutes then return end

    local entry = table.remove(self.queue, 1)
    self.queuedKeys[entry.key] = nil
    if now - entry.enqueued > 180 then return end
    local current = self.roster[SafeName(entry.member.name)]
    if not current or (entry.kind == "online" and not current.online) then return end
    local message = self:Compose(entry.kind, current)
    if not message then return end
    if self:Send(entry.kind, entry.member, message) then
        self.lastBroadcast = now
        self.sentTimes[#self.sentTimes + 1] = now
        self.db.lastSent[entry.key] = now
        self.db.stats[entry.kind] = (self.db.stats[entry.kind] or 0) + 1
        self:RefreshUI()
    end
end

function Greeter:ProcessRoster()
    if not self:IsGuilded() then
        self.ready = false
        self.roster = {}
        self.queue, self.queuedKeys = {}, {}
        return
    end
    local fresh = self:ReadRoster()
    if not fresh then return end
    if not self.ready then
        -- Baseline first: never greet every player already online on login.
        self.roster = fresh
        self.ready = true
        self:RefreshUI()
        return
    end

    local old = self.roster
    local oldCount, newCount = 0, 0
    for _ in pairs(old) do oldCount = oldCount + 1 end
    for _ in pairs(fresh) do newCount = newCount + 1 end
    -- Discard partial roster snapshots to avoid false joins on next update.
    if oldCount >= 5 and newCount < math.floor(oldCount / 2) then return end

    for key, member in pairs(fresh) do
        local previous = old[key]
        if not previous then
            self:Queue("welcome", member)
            -- A new guild member never also gets an immediate login greeting.
        elseif member.online and not previous.online then
            self:Queue("online", member)
        end
    end
    self.roster = fresh
end

function Greeter:SaveMessage(kind, index, text)
    local items = self.db.messages[kind]
    if not items or type(index) ~= "number" or not items[index] then
        return false, "Choose a valid message."
    end
    text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if text == "" or #text > 220 then return false, "Use 1-220 characters." end
    if kind == "welcome" then
        for i, existing in ipairs(items) do
            if i ~= index and existing == text then
                return false, "All five welcome messages must be different."
            end
        end
    end
    items[index] = text
    self:RefreshUI()
    return true
end

function Greeter:AddMessage(kind, text)
    local items = self.db.messages[kind]
    if not items then return false, "Invalid message type." end
    if kind == "welcome" then return false, "Welcome messages use exactly five editable slots." end
    if #items >= 50 then return false, "Maximum 50 messages per type." end
    text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if text == "" or #text > 220 then return false, "Use 1-220 characters." end
    items[#items + 1] = text
    self:RefreshUI()
    return true, #items
end

function Greeter:DeleteMessage(kind, index)
    local items = self.db.messages[kind]
    if not items or not items[index] then return false, "Invalid message." end
    if kind == "welcome" then return false, "Edit one of the five fixed welcome messages instead." end
    if #items == 1 then return false, "Keep at least one message." end
    table.remove(items, index)
    self:RefreshUI()
    return true
end

function Greeter:RefreshUI()
    if self.UpdatePanel then self:UpdatePanel() end
    if self.UpdateMinimap then self:UpdateMinimap() end
end

function Greeter:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide()
    else self.frame:Show(); self:RefreshUI() end
end

function Greeter:Initialize()
    if type(ForgeGuildGreeterDB) ~= "table" then ForgeGuildGreeterDB = {} end
    local db = ForgeGuildGreeterDB
    self.db = db
    if type(db.enabled) ~= "table" then db.enabled = {} end
    if type(db.enabled.welcome) ~= "boolean" then db.enabled.welcome = true end
    if type(db.enabled.online) ~= "boolean" then db.enabled.online = true end
    if type(db.messages) ~= "table" then db.messages = {} end
    for kind, defaults in pairs(self.defaults) do
        if type(db.messages[kind]) ~= "table" or #db.messages[kind] == 0 then
            db.messages[kind] = CopyArray(defaults)
        end
    end
    -- Upgrade older installations without overwriting edited welcome slots.
    -- Any extras from experimental builds are archived in SavedVariables.
    local welcomes = db.messages.welcome
    if #welcomes > 5 then
        if type(db.archivedWelcomeMessages) ~= "table" then
            db.archivedWelcomeMessages = {}
        end
        for i = 6, #welcomes do
            db.archivedWelcomeMessages[#db.archivedWelcomeMessages + 1] = welcomes[i]
        end
        for i = #welcomes, 6, -1 do welcomes[i] = nil end
    end
    for i = #welcomes + 1, 5 do
        welcomes[i] = self.defaults.welcome[i]
    end
    -- A user can still edit each message after migration; use distinct
    -- defaults when legacy data contains duplicate strings.
    for i = 1, 5 do
        if type(welcomes[i]) ~= "string" or welcomes[i] == "" or #welcomes[i] > 220 then
            welcomes[i] = self.defaults.welcome[i]
        end
        for j = 1, i - 1 do
            if welcomes[i] == welcomes[j] then
                welcomes[i] = self.defaults.welcome[i]
                local suffix = 2
                while true do
                    local unique = true
                    for k = 1, i - 1 do
                        if welcomes[i] == welcomes[k] then unique = false; break end
                    end
                    if unique then break end
                    welcomes[i] = "Welcome {player}! Greetings from {guild}. Message " .. tostring(suffix) .. "."
                    suffix = suffix + 1
                end
            end
        end
    end
    if type(db.welcomeRotation) ~= "table" then db.welcomeRotation = {} end
    local rotation = db.welcomeRotation
    if type(rotation.lastIndex) ~= "number" or rotation.lastIndex < 0
        or rotation.lastIndex > 5 or rotation.lastIndex ~= math.floor(rotation.lastIndex) then
        rotation.lastIndex = 0
    end
    if type(rotation.remaining) ~= "table" then rotation.remaining = {} end
    local seen = {}
    local valid = #rotation.remaining <= 5
    for _, index in ipairs(rotation.remaining) do
        if type(index) ~= "number" or index < 1 or index > 5
            or index ~= math.floor(index) or seen[index] then
            valid = false
            break
        end
        seen[index] = true
    end
    if not valid or (#rotation.remaining > 0 and rotation.remaining[1] == rotation.lastIndex) then
        rotation.remaining = {}
    end
    if type(db.channels) ~= "table" then db.channels = {} end
    for _, kind in ipairs({ "welcome", "online" }) do
        if not HasValue(self.channels, db.channels[kind]) then
            db.channels[kind] = "GUILD"
        end
    end
    if type(db.leaderOnly) ~= "boolean" then db.leaderOnly = true end
    if type(db.paused) ~= "boolean" then db.paused = false end
    if type(db.randomMessages) ~= "boolean" then db.randomMessages = true end
    if type(db.discordEnabled) ~= "boolean" then db.discordEnabled = false end
    if type(db.discordText) ~= "string" then db.discordText = "Join our Discord! Ask an officer for an invite." end
    if type(db.quietEnabled) ~= "boolean" then db.quietEnabled = false end
    db.quietStart = Clamp(db.quietStart, 0, 23, 23)
    db.quietEnd = Clamp(db.quietEnd, 0, 23, 8)
    db.cooldownMinutes = HasValue(self.cooldowns, db.cooldownMinutes) and db.cooldownMinutes or 30
    db.spacingSeconds = HasValue(self.spacings, db.spacingSeconds) and db.spacingSeconds or 10
    db.maxPerFiveMinutes = HasValue(self.limits, db.maxPerFiveMinutes) and db.maxPerFiveMinutes or 3
    if type(db.minimapHidden) ~= "boolean" then db.minimapHidden = false end
    db.minimapAngle = Clamp(db.minimapAngle, 0, 359, 225)
    if type(db.lastSent) ~= "table" then db.lastSent = {} end
    if type(db.stats) ~= "table" then db.stats = { welcome = 0, online = 0 } end
    local now = self:Now()
    for key, stamp in pairs(db.lastSent) do
        if type(stamp) ~= "number" or stamp > now or now - stamp > 604800 then
            db.lastSent[key] = nil
        end
    end

    self.queue, self.queuedKeys, self.sentTimes = {}, {}, {}
    self.roster, self.lastPicked, self.ready = {}, {}, false
    self.lastBroadcast = now - db.spacingSeconds
    self.tick, self.rosterTick = 0, 0

    self:CreateUI()
    self:CreateMinimapButton()

    SLASH_FORGEGUILDGREETER1 = "/fgreet"
    SLASH_FORGEGUILDGREETER2 = "/guildgreeter"
    SlashCmdList.FORGEGUILDGREETER = function(input)
        local cmd = string.lower((input or ""):match("^%s*(.-)%s*$"))
        if cmd == "welcome" or cmd == "online" then
            db.enabled[cmd] = not db.enabled[cmd]
            Greeter:RefreshUI()
            Greeter:Print(cmd .. " greetings: " .. (db.enabled[cmd] and "ON" or "OFF"))
        elseif cmd == "minimap" then
            db.minimapHidden = not db.minimapHidden
            Greeter:RefreshUI()
        elseif cmd == "status" then
            local ok, why = Greeter:CanAnnounce()
            Greeter:Print("Roster: " .. (Greeter.ready and "ready" or "loading") ..
                " | Broadcast: " .. (ok and "allowed" or why))
        elseif cmd == "about" then
            Greeter:Print("By Novyx Forge - https://wow.novyxforge.com")
        elseif cmd == "help" then
            Greeter:Print("/fgreet, /fgreet welcome, /fgreet online, /fgreet minimap, /fgreet status")
        else
            Greeter:Toggle()
        end
    end

    if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    self.eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("GUILD_RANKS_UPDATE")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "GUILD_ROSTER_UPDATE" then
            Greeter:ProcessRoster()
        else
            Greeter:RequestRoster()
        end
    end)
    self.eventFrame:SetScript("OnUpdate", function(_, elapsed)
        Greeter.tick = Greeter.tick + elapsed
        Greeter.rosterTick = Greeter.rosterTick + elapsed
        if Greeter.rosterTick >= 30 then
            Greeter.rosterTick = 0
            Greeter:RequestRoster()
        end
        if Greeter.tick >= 1 then
            Greeter.tick = 0
            Greeter:ProcessQueue()
        end
    end)
    self:RequestRoster()
    self:Print("Ready. /fgreet opens settings. Only the Guild Master broadcasts by default.")
    self:RefreshUI()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, loadedName)
    if loadedName == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        Greeter:Initialize()
    end
end)
