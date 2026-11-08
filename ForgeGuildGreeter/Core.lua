local addonName, ns = ...
local Greeter = {}
ns.Greeter = Greeter

Greeter.version = "0.4.2"
Greeter.brand = "NOVYX FORGE"
Greeter.channels = { "GUILD", "WHISPER", "OFFICER", "LOCAL" }
Greeter.cooldowns = { 5, 15, 30, 60, 120 }
Greeter.spacings = { 5, 10, 15, 30 }
Greeter.limits = { 1, 2, 3, 5, 8 }
Greeter.messageCount = 15
Greeter.defaults = {
    welcome = {
        "Welcome {player} to {guild}! Your repair bills are now our entertainment. FOR THE HORDE!",
        "A new adventurer appears! Welcome {player}! We have cookies. Probably.",
        "Welcome aboard, {player}! Bad pulls, terrible jokes and good times guaranteed.",
        "Everybody wave! {player} just joined {guild}. No refunds!",
        "Welcome {player}! Leave your dignity at the door. We lost ours several wipes ago.",
        "{player} just joined {guild}! Please sign the waiver before your first dungeon wipe.",
        "Hold the door! {player} is joining us. Somebody hide the guild bank.",
        "Welcome {player}! We promise nothing except questionable pulls and excellent company.",
        "New recruit: {player}! Your first quest is finding out who keeps pulling early.",
        "{guild} welcomes {player}! Warning: laughter may reduce your damage output.",
        "{player} has entered the guild. Group therapy now has one more participant.",
        "All hail {player}! The legendary loot is fictional, but the friendship is real.",
        "Welcome {player}! We are the reason your healer drinks between pulls.",
        "Fresh meat! Just kidding, {player}. We only sacrifice volunteers. Mostly.",
        "{player}, welcome to {guild}! Bring snacks, patience, and a spare repair bill.",
    },
    online = {
        "Look who's back! {player} has returned. Hide the good loot!",
        "{player} is online! The respawn timer on our chaos has ended.",
        "Welcome back, {player}! Your daily dose of questionable decisions awaits.",
        "Breaking news: {player} logged in. The guild's collective IQ remains unchanged.",
        "{player} is back! The mobs were beginning to feel safe.",
        "Attention, {guild}: {player} has logged in. This is not a drill.",
        "Welcome back, {player}! Your repair bill missed you.",
        "{player} just appeared online. Somewhere, a healer sighed.",
        "Look alive, guild! {player} is here and probably needs a summon.",
        "The legends were true: {player} has returned to Azeroth.",
        "{player} is online again! We were almost behaving ourselves.",
        "Welcome back, {player}! Your seat at the chaos table is still warm.",
        "Another day, another adventure. {player} has joined the party!",
        "It's {player}! Everybody pretend we know the tactics this time.",
        "{player} logged in! Time to turn perfectly good plans into glorious disasters.",
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
    if self.rosterPollingBlocked or not self:IsGuilded() then return end
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
    local validRows = 0
    for i = 1, count do
        local name, rank, _, level, class, _, _, _, online = GetGuildRosterInfo(i)
        if type(name) == "string" and name ~= "" then
            validRows = validRows + 1
            snapshot[SafeName(name)] = {
                name = name, rank = rank or "", class = class or "",
                level = level or "?", online = online and true or false,
            }
        end
    end
    -- WoW may deliver guild events while individual roster entries are nil.
    -- Never treat a partially populated response as a membership change.
    if validRows ~= count or not next(snapshot) then return nil end
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

-- Both message libraries have fifteen fixed editable slots, with separate
-- saved rotations that survive login/reload without duplicate adjacent texts.
-- Both message types use independent persisted shuffle bags. One full round
-- plays every editable slot exactly once, with no identical boundary message.
function Greeter:GetRotation(kind)
    if kind == "welcome" then return self.db.welcomeRotation end
    if kind == "online" then return self.db.onlineRotation end
    return nil
end

function Greeter:PickMessage(kind)
    local items = self.db.messages[kind]
    local rotation = self:GetRotation(kind)
    if not items or #items == 0 or not rotation then return nil end
    if #rotation.remaining == 0 then
        local bag = {}
        if self.db.randomMessages then
            for i = 1, #items do bag[i] = i end
            for i = #bag, 2, -1 do
                local j = math.random(i)
                bag[i], bag[j] = bag[j], bag[i]
            end
        else
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

function Greeter:PickWelcomeMessage()
    return self:PickMessage("welcome")
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
    local allowed, reason = self:CanAnnounce()
    if not allowed then
        if reason == "Guild Master only" and not self.rankWarningShown then
            self.rankWarningShown = true
            self:Print("Auto greetings are OFF on this character: GUILD MASTER ONLY is enabled. Type /fgreet enable to allow this character, or toggle it in Advanced.")
            self:LogAction("NOT SENDING", kind, member.name, "Guild Master Only is ON; /fgreet enable")
        end
        return
    end
    if #self.queue >= 20 then return end

    local key = kind .. ":" .. SafeName(member.name)
    local last = self.db.lastSent[key]
    local now = self:Now()
    local seconds = kind == "online" and self.db.onlineCooldownHours * 3600 or self.db.cooldownMinutes * 60
    if type(last) == "number" and now - last < seconds then return end
    if self.queuedKeys[key] or (self.manualKeys and self.manualKeys[key]) then return end
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

-- A message is composed only when its recipient is still relevant. Its
-- rotation is snapshotted so failed/blocked/local sends cannot burn a slot.
function Greeter:ProcessQueue()
    if #self.queue == 0 then return end
    if self:IsQuiet() then
        self.queue, self.queuedKeys = {}, {}
        return
    end
    if not self:CanAnnounce() then
        self.queue, self.queuedKeys = {}, {}
        return
    end
    local now = self:Now()
    local entry = self.queue[1]
    if not entry then return end
    if now - entry.enqueued > 180 then
        table.remove(self.queue, 1)
        self.queuedKeys[entry.key] = nil
        return
    end
    local current = self.roster[SafeName(entry.member.name)]
    if not current or (entry.kind == "online" and not current.online) then
        table.remove(self.queue, 1)
        self.queuedKeys[entry.key] = nil
        return
    end
    if self.db.manualMode or self.chatBlocked then
        table.remove(self.queue, 1)
        self.queuedKeys[entry.key] = nil
        self:HoldForManual(entry)
        return
    end
    -- Guild/officer/whisper chat types are permitted from normal addon
    -- callbacks. SAY/YELL/CHANNEL are not offered by this addon.
    -- In combat we defer conservatively rather than risk UI taint.
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return end
    if C_ChatInfo and type(C_ChatInfo.InChatMessagingLockdown) == "function" then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        if not ok or locked then return end
    end
    if now - self.lastBroadcast < self.db.spacingSeconds then return end
    local kept = {}
    for _, stamp in ipairs(self.sentTimes) do
        if now - stamp < 300 then kept[#kept + 1] = stamp end
    end
    self.sentTimes = kept
    if #kept >= self.db.maxPerFiveMinutes then return end

    table.remove(self.queue, 1)
    self.queuedKeys[entry.key] = nil
    local before = self:SnapshotRotation(entry.kind)
    local content = self:Compose(entry.kind, current)
    if not content then
        self:RestoreRotation(entry.kind, before)
        self:HoldForManual(entry)
        self:LogAction("BLOCKED", entry.kind, current.name, "Invalid/oversized greeting; edit template")
        return
    end
    if self.db.channels[entry.kind] == "LOCAL" then
        self:RestoreRotation(entry.kind, before)
        self:Send(entry.kind, current, content)
        return
    end
    if not self:Send(entry.kind, current, content) then
        self:RestoreRotation(entry.kind, before)
        self:HoldForManual(entry)
        return
    end
    self.lastBroadcast = now
    self.sentTimes[#self.sentTimes + 1] = now
    self.db.lastSent[entry.key] = now
    self.db.stats[entry.kind] = (self.db.stats[entry.kind] or 0) + 1
    self:RefreshUI()
end

-- Never infer a join from one roster snapshot: every new name must appear
-- in two complete snapshots separated by at least three seconds.
function Greeter:ProcessRoster()
    if not self:IsGuilded() then
        self.ready = false
        self.roster, self.seenNames, self.joinCandidates = {}, {}, {}
        self.queue, self.queuedKeys = {}, {}
        self.pendingManual, self.manualKeys = {}, {}
        return
    end
    local fresh = self:ReadRoster()
    if not fresh then return end
    local now = self:Now()
    if not self.ready then
        self.roster, self.seenNames, self.joinCandidates = fresh, {}, {}
        for key in pairs(fresh) do self.seenNames[key] = true end
        self.ready = true
        self:RefreshUI()
        return
    end

    local old = self.roster
    local oldCount, newCount, additions = 0, 0, 0
    for _ in pairs(old) do oldCount = oldCount + 1 end
    for key in pairs(fresh) do
        newCount = newCount + 1
        if not self.seenNames[key] then additions = additions + 1 end
    end
    -- Treat suspicious shrinks as incomplete cached roster reads, including
    -- small guilds where a single missing row would cause false joins.
    if oldCount >= 3 and newCount < math.floor(oldCount * 0.8 + 0.5) then return end
    if additions > 3 then
        -- On a large guild roster refill, learn names without welcoming a crowd.
        self.roster, self.joinCandidates = fresh, {}
        for key in pairs(fresh) do self.seenNames[key] = true end
        self:LogAction("SKIPPED", "roster", "Guild", "Bulk roster refill: no mass welcomes")
        self:RefreshUI()
        return
    end

    local possibleJoins = {}
    for key, member in pairs(fresh) do
        if not self.seenNames[key] then
            local candidate = self.joinCandidates[key]
            if not candidate then
                possibleJoins[key] = { since = now }
            elseif now - candidate.since >= 3 then
                self.seenNames[key] = true
                self:Queue("welcome", member)
            else
                possibleJoins[key] = candidate
            end
        elseif old[key] and member.online and not old[key].online then
            self:Queue("online", member)
        end
    end
    self.joinCandidates = possibleJoins
    self.roster = fresh
    if next(possibleJoins) then self.rosterCheckSoon = true end
    self:RefreshUI()
end

function Greeter:SaveMessage(kind, index, text)
    local items = self.db.messages[kind]
    if not items or type(index) ~= "number" or not items[index] then
        return false, "Choose a valid message."
    end
    text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if text == "" or #text > 220 then return false, "Use 1-220 characters." end
    for i, existing in ipairs(items) do
        if i ~= index and existing == text then
            return false, "All 15 " .. kind .. " messages must be different."
        end
    end
    items[index] = text
    self:RefreshUI()
    return true
end

function Greeter:AddMessage(kind)
    if kind ~= "welcome" and kind ~= "online" then
        return false, "Invalid message type."
    end
    return false, "Each greeting type has exactly 15 editable slots."
end

function Greeter:DeleteMessage(kind)
    if kind ~= "welcome" and kind ~= "online" then
        return false, "Invalid message type."
    end
    return false, "Edit one of the 15 fixed messages instead."
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
    -- Preserve existing user-edited messages in their original slot. Fill
    -- missing slots to fifteen; never overwrite custom 1-5 from v0.3.
    -- If a legacy build had >15 online messages, archive the extras.
    for _, kind in ipairs({ "welcome", "online" }) do
        local defaults = self.defaults[kind]
        local items = db.messages[kind]
        if type(items) ~= "table" then
            items = CopyArray(defaults)
            db.messages[kind] = items
        end
        local originalCount = #items
        if originalCount > self.messageCount then
            local archiveKey = kind == "welcome"
                and "archivedWelcomeMessages" or "archivedOnlineMessages"
            if type(db[archiveKey]) ~= "table" then db[archiveKey] = {} end
            for i = self.messageCount + 1, originalCount do
                db[archiveKey][#db[archiveKey] + 1] = items[i]
            end
            for i = originalCount, self.messageCount + 1, -1 do items[i] = nil end
        end
        for i = #items + 1, self.messageCount do
            items[i] = defaults[i]
        end
        for i = 1, self.messageCount do
            if type(items[i]) ~= "string" or items[i] == "" or #items[i] > 220 then
                items[i] = defaults[i]
            end
            -- Legacy duplicates cannot remain in a unique 15-message set.
            -- Preserve the first copy and substitute a distinct fallback.
            local distinct = false
            local candidateNumber = 1
            while not distinct do
                distinct = true
                for j = 1, i - 1 do
                    if items[i] == items[j] then
                        distinct = false
                        if candidateNumber == 1 then
                            items[i] = defaults[i]
                        else
                            items[i] = (kind == "welcome" and "Welcome " or "Welcome back ")
                                .. "{player}! " .. kind .. " greeting " .. candidateNumber .. "."
                        end
                        candidateNumber = candidateNumber + 1
                        break
                    end
                end
            end
        end
        local key = kind == "welcome" and "welcomeRotation" or "onlineRotation"
        local rotation = db[key]
        if type(rotation) ~= "table" then
            rotation = {}
            db[key] = rotation
        end
        if type(rotation.lastIndex) ~= "number" or rotation.lastIndex < 0
            or rotation.lastIndex > self.messageCount
            or rotation.lastIndex ~= math.floor(rotation.lastIndex) then
            rotation.lastIndex = 0
        end
        if type(rotation.remaining) ~= "table" then rotation.remaining = {} end
        local seen = {}
        local valid = #rotation.remaining <= self.messageCount
        for _, index in ipairs(rotation.remaining) do
            if type(index) ~= "number" or index < 1
                or index > self.messageCount or index ~= math.floor(index)
                or seen[index] then
                valid = false
                break
            end
            seen[index] = true
        end
        -- Resize begins a fresh fifteen-slot cycle while retaining the last
        -- choice, so even the upgrade cannot greet twice in a row.
        if originalCount ~= self.messageCount or not valid
            or (#rotation.remaining > 0 and rotation.remaining[1] == rotation.lastIndex) then
            rotation.remaining = {}
        end
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
    if self.InitQuality then self:InitQuality() end
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
    self.seenNames, self.joinCandidates = {}, {}
    self.pendingManual, self.manualKeys = {}, {}
    self.rosterCheckSoon, self.rosterCheckElapsed = false, 0
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
        elseif cmd == "enable" then
            -- Explicitly allow this character to broadcast even if it is
            -- not the Guild Master. Avoid running several broadcasters.
            db.leaderOnly = false
            Greeter.rankWarningShown = false
            Greeter:RefreshUI()
            Greeter:Print("This character can now send automatic greetings. Use only one active broadcaster per guild.")
        elseif cmd == "minimap" then
            db.minimapHidden = not db.minimapHidden
            Greeter:RefreshUI()
        elseif cmd == "check" then
            Greeter:RunSetupCheck()
        elseif cmd == "manual" then
            db.manualMode = not db.manualMode
            Greeter:RefreshUI()
            Greeter:Print("Manual mode " .. (db.manualMode and "ON" or "OFF") ..
                ". Pending greetings are sent with the SEND NEXT button.")
        elseif cmd == "status" then
            local ok, why = Greeter:CanAnnounce()
            Greeter:Print("Roster: " .. (Greeter.ready and "ready" or "loading") ..
                " | Sending: " .. (ok and "ENABLED" or "DISABLED: " .. tostring(why)) ..
                " | Mode: " .. (db.manualMode and "MANUAL" or "AUTO") ..
                " | Waiting: " .. #Greeter.queue .. " | Pending: " .. Greeter:PendingCount())
            if not ok and why == "Guild Master only" then
                Greeter:Print("Use /fgreet enable to enable this character; avoid installing multiple active broadcasters in the same guild.")
            end
        elseif cmd == "about" then
            Greeter:Print("By Novyx Forge - https://wow.novyxforge.com")
        elseif cmd == "help" then
            Greeter:Print("/fgreet, /fgreet enable, /fgreet check, /fgreet manual, /fgreet welcome, /fgreet online, /fgreet status")
        else
            Greeter:Toggle()
        end
    end

    if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    self.eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("GUILD_RANKS_UPDATE")
    self.eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
    self.eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    self.eventFrame:SetScript("OnEvent", function(_, event, addon, func)
        if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
            Greeter:HandleProtectedAction(event, addon, func)
        elseif event == "GUILD_ROSTER_UPDATE" then
            Greeter:ProcessRoster()
        else
            Greeter:RequestRoster()
        end
    end)
    self.eventFrame:SetScript("OnUpdate", function(_, elapsed)
        Greeter.tick = Greeter.tick + elapsed
        Greeter.rosterTick = Greeter.rosterTick + elapsed
        if Greeter.rosterCheckSoon then
            Greeter.rosterCheckElapsed = (Greeter.rosterCheckElapsed or 0) + elapsed
            if Greeter.rosterCheckElapsed >= 3 then
                Greeter.rosterCheckSoon = false
                Greeter.rosterCheckElapsed = 0
                Greeter:RequestRoster()
            end
        end
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
    if not db.setupSeen then
        self.frame:Show()
        self:Print("First setup: open ACTIVITY and click CHECK SETUP; then use SEND TEST.")
    end
    self:Print("Ready. /fgreet opens settings. /fgreet status checks auto-sending; /fgreet enable permits this character.")
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
