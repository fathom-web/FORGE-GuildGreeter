local _, ns = ...
local Greeter = ns.Greeter

-- Matches FORGE AFK - DAD MODE's native charcoal/gold visual language.
local C = {
    bg = { 0.075, 0.078, 0.082, 0.98 },
    button = { 0.15, 0.14, 0.13, 1 },
    hover = { 0.24, 0.19, 0.12, 1 },
    edge = { 0.43, 0.34, 0.22, 1 },
    gold = { 0.88, 0.71, 0.43 },
    muted = { 0.69, 0.68, 0.65 },
}

local function Backdrop(frame, color)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(unpack(color))
    frame:SetBackdropBorderColor(unpack(C.edge))
end

local function Label(parent, text, x, y, font, color)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    label:SetTextColor(unpack(color or C.muted))
    return label
end

local function Button(parent, text, x, y, width, height, handler)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetSize(width, height)
    Backdrop(b, C.button)
    local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", b, "CENTER", 0, 0)
    label:SetText(text)
    label:SetTextColor(0.96, 0.82, 0.59)
    b.label = label
    b:SetScript("OnEnter", function(frame)
        frame:SetBackdropColor(unpack(C.hover))
        frame:SetBackdropBorderColor(0.9, 0.68, 0.34, 1)
    end)
    b:SetScript("OnLeave", function(frame)
        frame:SetBackdropColor(unpack(C.button))
        frame:SetBackdropBorderColor(unpack(C.edge))
    end)
    b:SetScript("OnClick", handler)
    return b
end

local function Input(parent, x, y, width, maxLetters)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    e:SetSize(width, 34)
    Backdrop(e, C.button)
    e:SetAutoFocus(false)
    e:SetFontObject("GameFontHighlight")
    e:SetTextInsets(9, 9, 0, 0)
    e:SetMaxLetters(maxLetters)
    e:SetScript("OnEscapePressed", function(field) field:ClearFocus() end)
    return e
end

local function Cycle(list, value)
    for i, item in ipairs(list) do
        if item == value then return list[(i % #list) + 1] end
    end
    return list[1]
end

function Greeter:CurrentKind()
    if self.ui.tab == "online" then return "online" end
    return "welcome"
end

function Greeter:LoadSelectedMessage()
    local kind = self:CurrentKind()
    local list = self.db.messages[kind]
    local index = math.max(1, math.min(#list, self.ui.index[kind]))
    self.ui.index[kind] = index
    self.ui.messageEdit:SetText(list[index] or "")
    self.ui.messageEdit:ClearFocus()
    self:UpdatePreview()
end

function Greeter:CommitDraft()
    local kind = self:CurrentKind()
    local ok, err = self:SaveMessage(kind, self.ui.index[kind], self.ui.messageEdit:GetText())
    if not ok then self:Print(err) end
    return ok
end

function Greeter:ChangeMessage(direction)
    if not self:CommitDraft() then return end
    local kind = self:CurrentKind()
    local total = #self.db.messages[kind]
    self.ui.index[kind] = ((self.ui.index[kind] + direction - 1) % total) + 1
    self:LoadSelectedMessage()
    self:UpdatePanel()
end

function Greeter:ChangeTab(tab)
    if self.ui.tab == tab then return end
    if (self.ui.tab == "welcome" or self.ui.tab == "online")
        and not self:CommitDraft() then return end
    self.ui.tab = tab
    if tab == "welcome" or tab == "online" then self:LoadSelectedMessage() end
    self:UpdatePanel()
end

function Greeter:UpdatePreview()
    if not self.ui or not self.ui.previewText then return end
    local kind = self:CurrentKind()
    local member = { name = "Thrall", class = "Shaman", level = 60, rank = "Raider" }
    local draft = self.ui.messageEdit:GetText() or ""
    local result = self:Expand(draft, member)
    if kind == "welcome" and self.db.discordEnabled and self.db.discordText ~= "" then
        result = result .. " " .. self:Expand(self.db.discordText, member)
    end
    self.ui.previewText:SetText(result)
    if #result > 255 then self.ui.previewText:SetTextColor(1, 0.35, 0.35)
    else self.ui.previewText:SetTextColor(0.76, 0.88, 0.75) end
end

function Greeter:CreateUI()
    if self.frame then self.frame:Hide() end
    local p = CreateFrame("Frame", "ForgeGuildGreeterPanel", UIParent, "BackdropTemplate")
    p:SetSize(510, 615)
    p:SetFrameStrata("DIALOG")
    p:SetClampedToScreen(true)
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetPoint("CENTER", UIParent, "CENTER", self.db.x or 0, self.db.y or 0)
    Backdrop(p, C.bg)
    p:SetBackdropBorderColor(0.86, 0.65, 0.35, 1)
    p:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    p:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local x, y = frame:GetCenter()
        local px, py = UIParent:GetCenter()
        if x and y and px and py then
            Greeter.db.x = math.floor(x - px + 0.5)
            Greeter.db.y = math.floor(y - py + 0.5)
        end
    end)

    Label(p, "FORGE GUILDGREETER", 20, -18, "GameFontNormalLarge", C.gold)
    Label(p, "Your guild. Your rules. Your madness.", 21, -43)
    local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() p:Hide() end)
    local divider = p:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.6, 0.43, 0.24, 0.75)
    divider:SetPoint("TOPLEFT", p, "TOPLEFT", 19, -74)
    divider:SetSize(472, 1)

    local welcomeToggle = Button(p, "", 19, -88, 230, 65, function()
        Greeter.db.enabled.welcome = not Greeter.db.enabled.welcome
        Greeter:RefreshUI()
    end)
    local onlineToggle = Button(p, "", 260, -88, 231, 65, function()
        Greeter.db.enabled.online = not Greeter.db.enabled.online
        Greeter:RefreshUI()
    end)
    local statusLabel = Label(p, "", 20, -166, "GameFontHighlightSmall", C.gold)
    statusLabel:SetWidth(470)
    statusLabel:SetWordWrap(false)

    local tabs = {}
    local tabIDs = { "welcome", "online", "settings", "about" }
    local tabNames = { "WELCOME", "ONLINE", "ADVANCED", "ACTIVITY" }
    for i, tab in ipairs(tabIDs) do
        tabs[tab] = Button(p, tabNames[i], 19 + (i - 1) * 120, -191, 111, 34,
            function() Greeter:ChangeTab(tab) end)
    end

    local editor = CreateFrame("Frame", nil, p)
    editor:SetSize(472, 330)
    editor:SetPoint("TOPLEFT", p, "TOPLEFT", 19, -238)
    local indexLabel = Label(editor, "MESSAGE 1 / 4", 0, 0, "GameFontNormal", C.gold)
    Button(editor, "<", 361, 4, 50, 30, function() Greeter:ChangeMessage(-1) end)
    Button(editor, ">", 421, 4, 50, 30, function() Greeter:ChangeMessage(1) end)
    Label(editor, "Edit your message (up to 220 characters):", 0, -40)
    local messageEdit = Input(editor, 0, -62, 472, 220)
    messageEdit:SetScript("OnEnterPressed", function(field)
        Greeter:CommitDraft()
        field:ClearFocus()
    end)
    messageEdit:SetScript("OnTextChanged", function()
        Greeter:UpdatePreview()
    end)

    Button(editor, "SAVE", 0, -109, 149, 38, function()
        if Greeter:CommitDraft() then Greeter:Print("Message saved.") end
    end)
    Button(editor, "PREVIEW", 161, -109, 149, 38, function()
        Greeter:PreviewSelected(Greeter:CurrentKind(), Greeter.ui.messageEdit:GetText())
    end)
    Button(editor, "SEND TEST", 322, -109, 150, 38, function()
        local kind = Greeter:CurrentKind()
        if Greeter:CommitDraft() then
            Greeter:SendTest(kind, Greeter.ui.messageEdit:GetText())
        end
    end)

    local addButton = Button(editor, "ADD NEW", 242, -163, 110, 37, function()
        local kind = Greeter:CurrentKind()
        if kind == "welcome" then
            local ok, err = Greeter:RestoreTemplate(kind, Greeter.ui.index[kind])
            if not ok then Greeter:Print(err); return end
            Greeter:LoadSelectedMessage()
            Greeter:Print("Original welcome message restored.")
            return
        end
        if not Greeter:CommitDraft() then return end
        local ok, index = Greeter:AddMessage(kind, "Welcome back, {player}!")
        if not ok then Greeter:Print(index); return end
        Greeter.ui.index[kind] = index
        Greeter:LoadSelectedMessage()
        Greeter:UpdatePanel()
    end)
    local deleteButton = Button(editor, "DELETE", 362, -163, 110, 37, function()
        local kind = Greeter:CurrentKind()
        local ok, err = Greeter:DeleteMessage(kind, Greeter.ui.index[kind])
        if not ok then Greeter:Print(err); return end
        Greeter.ui.index[kind] = math.max(1, math.min(Greeter.ui.index[kind], #Greeter.db.messages[kind]))
        Greeter:LoadSelectedMessage()
        Greeter:UpdatePanel()
    end)
    local channelBtn = Button(editor, "", 0, -163, 232, 37, function()
        local kind = Greeter:CurrentKind()
        Greeter.db.channels[kind] = Cycle(Greeter.channels, Greeter.db.channels[kind])
        Greeter:RefreshUI()
    end)
    local uniqueHint = Label(editor, "5 UNIQUE WELCOMES  -  NO REPEATS UNTIL ALL FIVE PLAY",
        0, -201, "GameFontHighlightSmall", C.gold)
    local restoreOnlineBtn = Button(editor, "RESTORE ORIGINAL", 306, -199, 166, 33, function()
        local kind = Greeter:CurrentKind()
        if kind ~= "online" then return end
        local ok, err = Greeter:RestoreTemplate(kind, Greeter.ui.index[kind])
        if not ok then Greeter:Print(err); return end
        Greeter:LoadSelectedMessage()
        Greeter:Print("Original online greeting restored.")
    end)
    Label(editor, "PREVIEW / VARS: {player} {guild} {class} {level} {rank}", 0, -243,
        "GameFontNormalSmall", C.gold)
    local previewText = Label(editor, "", 0, -268, "GameFontHighlightSmall")
    previewText:SetWidth(466)
    previewText:SetJustifyH("LEFT")
    previewText:SetWordWrap(true)

    local queueLabel = Label(p, "", 20, -560, "GameFontHighlightSmall", C.gold)
    local sendNextButton = Button(p, "SEND NEXT", 309, -546, 182, 32, function()
        Greeter:SendNextPending()
    end)
    local footer = Label(p, "NOVYX FORGE  |  /fgreet  |  v" .. self.version ..
        "  |  R-click minimap: pause", 20, -588)
    footer:SetTextColor(0.55, 0.55, 0.52)

    -- Advanced tools are behind one tab, split into just two small pages.
    local settings = CreateFrame("Frame", nil, p)
    settings:SetSize(472, 330)
    settings:SetPoint("TOPLEFT", p, "TOPLEFT", 19, -238)
    local subTab = "safety"
    local policyPage = CreateFrame("Frame", nil, settings)
    policyPage:SetSize(472, 285)
    policyPage:SetPoint("TOPLEFT", settings, "TOPLEFT", 0, -44)
    local messagePage = CreateFrame("Frame", nil, settings)
    messagePage:SetSize(472, 285)
    messagePage:SetPoint("TOPLEFT", settings, "TOPLEFT", 0, -44)
    local behaviorTab = Button(settings, "BEHAVIOR", 0, 0, 230, 36, function()
        Greeter.ui.subTab = "safety"; Greeter:UpdatePanel()
    end)
    local messageTab = Button(settings, "MESSAGES", 242, 0, 230, 36, function()
        Greeter.ui.subTab = "messages"; Greeter:UpdatePanel()
    end)
    local leaderBtn = Button(policyPage, "", 0, 0, 230, 42, function()
        Greeter.db.leaderOnly = not Greeter.db.leaderOnly; Greeter:RefreshUI()
    end)
    local randomBtn = Button(policyPage, "", 242, 0, 230, 42, function()
        Greeter.db.randomMessages = not Greeter.db.randomMessages
        Greeter.db.welcomeRotation.remaining = {}
        Greeter:RefreshUI()
    end)
    local quietBtn = Button(policyPage, "", 0, -54, 230, 42, function()
        Greeter.db.quietEnabled = not Greeter.db.quietEnabled; Greeter:RefreshUI()
    end)
    local onlineCdBtn = Button(policyPage, "", 242, -54, 230, 42, function()
        Greeter.db.onlineCooldownHours =
            Cycle(Greeter.onlineCooldownOptions, Greeter.db.onlineCooldownHours)
        Greeter:RefreshUI()
    end)
    local cdBtn = Button(policyPage, "", 0, -108, 230, 42, function()
        Greeter.db.cooldownMinutes = Cycle(Greeter.cooldowns, Greeter.db.cooldownMinutes)
        Greeter:RefreshUI()
    end)
    local gapBtn = Button(policyPage, "", 242, -108, 230, 42, function()
        Greeter.db.spacingSeconds = Cycle(Greeter.spacings, Greeter.db.spacingSeconds)
        Greeter:RefreshUI()
    end)
    local limitBtn = Button(policyPage, "", 0, -162, 230, 42, function()
        Greeter.db.maxPerFiveMinutes = Cycle(Greeter.limits, Greeter.db.maxPerFiveMinutes)
        Greeter:RefreshUI()
    end)
    local startBtn = Button(policyPage, "", 242, -162, 110, 42, function()
        Greeter.db.quietStart = (Greeter.db.quietStart + 1) % 24
        Greeter:RefreshUI()
    end)
    local endBtn = Button(policyPage, "", 362, -162, 110, 42, function()
        Greeter.db.quietEnd = (Greeter.db.quietEnd + 1) % 24
        Greeter:RefreshUI()
    end)
    local manualBtn = Button(policyPage, "", 0, -214, 230, 35, function()
        Greeter.db.manualMode = not Greeter.db.manualMode
        Greeter:RefreshUI()
    end)
    Label(policyPage, "Manual mode queues greetings.", 248, -223,
        "GameFontHighlightSmall", C.muted)
    local resetButton = Button(policyPage, "RESTORE DEFAULT SETTINGS", 0, -257, 472, 37, function()
        local u = Greeter.ui
        local now = Greeter:Now()
        if not u.confirmReset or now > u.confirmReset then
            u.confirmReset = now + 15
            Greeter:Print("Click CONFIRM RESET within 15 seconds. Your texts will be kept.")
        else
            u.confirmReset = nil
            Greeter:ResetOptions()
            u.discordEdit:SetText(Greeter.db.discordText)
            u.whisperEdit:SetText(Greeter.db.welcomeWhisperText)
        end
        Greeter:UpdatePanel()
    end)

    local discordBtn = Button(messagePage, "", 0, 0, 230, 42, function()
        Greeter.db.discordEnabled = not Greeter.db.discordEnabled; Greeter:RefreshUI()
    end)
    local whisperBtn = Button(messagePage, "", 242, 0, 230, 42, function()
        Greeter.db.welcomeWhisperEnabled = not Greeter.db.welcomeWhisperEnabled
        Greeter:RefreshUI()
    end)
    Label(messagePage, "DISCORD REMINDER (APPENDED TO PUBLIC WELCOME)", 0, -56,
        "GameFontNormalSmall", C.gold)
    local discordEdit = Input(messagePage, 0, -76, 472, 100)
    discordEdit:SetText(self.db.discordText)
    local function SaveDiscord()
        Greeter.db.discordText = (discordEdit:GetText() or ""):match("^%s*(.-)%s*$")
        Greeter:RefreshUI()
        discordEdit:ClearFocus()
        Greeter:Print("Discord reminder saved.")
    end
    discordEdit:SetScript("OnEnterPressed", SaveDiscord)
    Button(messagePage, "SAVE DISCORD REMINDER", 0, -117, 472, 33, SaveDiscord)
    Label(messagePage, "PERSONAL WELCOME WHISPER (NEW MEMBERS ONLY)", 0, -161,
        "GameFontNormalSmall", C.gold)
    local whisperEdit = Input(messagePage, 0, -181, 472, 220)
    whisperEdit:SetText(self.db.welcomeWhisperText)
    local function SaveWhisper()
        local value = (whisperEdit:GetText() or ""):match("^%s*(.-)%s*$")
        if value == "" then Greeter:Print("Whisper message cannot be blank."); return end
        Greeter.db.welcomeWhisperText = value
        Greeter:RefreshUI()
        whisperEdit:ClearFocus()
        Greeter:Print("Personal welcome whisper saved.")
    end
    whisperEdit:SetScript("OnEnterPressed", SaveWhisper)
    Button(messagePage, "SAVE WELCOME WHISPER", 0, -222, 472, 33, SaveWhisper)
    Label(messagePage, "Whisper is optional, off by default and limited to one per player/day.",
        0, -271, "GameFontHighlightSmall", C.muted)

    -- Activity stays intentionally tiny: last 10 local events and send attempts.
    local about = CreateFrame("Frame", nil, p)
    about:SetSize(472, 330)
    about:SetPoint("TOPLEFT", p, "TOPLEFT", 19, -238)
    Label(about, "RECENT ACTIVITY  -  MOST RECENT FIRST", 0, 0,
        "GameFontNormal", C.gold)
    local setupButton = Button(about, "CHECK SETUP", 328, -2, 144, 28, function()
        Greeter:RunSetupCheck()
    end)
    Label(about, "REQUESTED = chat API called; not proof of delivery.", 0, -23,
        "GameFontHighlightSmall", C.muted)
    local activityRows = {}
    for i = 1, 10 do
        activityRows[i] = Label(about, "", 0, -50 - (i - 1) * 26,
            "GameFontHighlightSmall", C.muted)
        activityRows[i]:SetWidth(464)
        activityRows[i]:SetWordWrap(false)
    end
    Label(about, "NOVYX FORGE  |  wow.novyxforge.com  |  Auto-send requires in-game test",
        0, -318, "GameFontHighlightSmall", C.gold)

    self.ui = {
        tab = "welcome", subTab = "safety", confirmReset = nil,
        index = { welcome = 1, online = 1 },
        editor = editor, settings = settings, about = about,
        policyPage = policyPage, messagePage = messagePage,
        behaviorTab = behaviorTab, messageTab = messageTab,
        welcomeToggle = welcomeToggle, onlineToggle = onlineToggle,
        tabs = tabs, statusLabel = statusLabel, indexLabel = indexLabel,
        messageEdit = messageEdit, channelBtn = channelBtn,
        addButton = addButton, deleteButton = deleteButton,
        uniqueHint = uniqueHint, queueLabel = queueLabel, sendNextButton = sendNextButton,
        restoreOnlineBtn = restoreOnlineBtn,
        previewText = previewText,
        leaderBtn = leaderBtn, randomBtn = randomBtn, quietBtn = quietBtn,
        manualBtn = manualBtn, setupButton = setupButton,
        onlineCdBtn = onlineCdBtn, cdBtn = cdBtn, gapBtn = gapBtn,
        limitBtn = limitBtn, startBtn = startBtn, endBtn = endBtn,
        resetButton = resetButton, discordBtn = discordBtn,
        whisperBtn = whisperBtn, discordEdit = discordEdit,
        whisperEdit = whisperEdit, activityRows = activityRows,
    }
    self.frame = p
    self:LoadSelectedMessage()
    self:UpdatePanel()
    p:Hide()
end

function Greeter:UpdateStatus()
    local u = self.ui
    if not u or not u.statusLabel or not self.db then return end
    local line = "STATUS: " .. self:StatusText()
    local recent = self.db.activity and self.db.activity[1]
    if recent then
        local player = recent.player or ""
        if #player > 18 then player = player:sub(1, 18) end
        line = line .. "  |  LAST: " .. recent.status .. " " .. player
    end
    u.statusLabel:SetText(line)
end

function Greeter:UpdateActivity()
    local u = self.ui
    if not u or not u.activityRows or not self.db then return end
    for i, label in ipairs(u.activityRows) do
        local entry = self.db.activity[i]
        if entry then
            local clock = type(date) == "function" and date("%H:%M", entry.at) or "--:--"
            local description = entry.player .. " - " .. entry.message
            if #description > 48 then description = description:sub(1, 45) .. "..." end
            label:SetText(clock .. "  " .. entry.status .. "  " .. description)
        else
            label:SetText(i == 1 and "No activity yet. Waiting for your first guild event." or "")
        end
    end
end

function Greeter:UpdatePanel()
    local u = self.ui
    if not u or not self.db then return end
    u.welcomeToggle.label:SetText("NEW MEMBERS\n" ..
        (self.db.enabled.welcome and "ENABLED" or "DISABLED"))
    u.onlineToggle.label:SetText("ONLINE GREETINGS\n" ..
        (self.db.enabled.online and "ENABLED" or "DISABLED"))
    self:UpdateStatus()
    local kind = self:CurrentKind()
    local isEditor = u.tab == "welcome" or u.tab == "online"
    if isEditor then u.editor:Show() else u.editor:Hide() end
    local auto = #self.queue
    local manual = self:PendingCount()
    u.queueLabel:SetText("WAITING: " .. auto .. "  |  MANUAL: " .. manual)
    u.sendNextButton:SetEnabled(manual > 0 and not self.db.paused)
    u.sendNextButton:SetAlpha(manual > 0 and not self.db.paused and 1 or 0.4)
    u.sendNextButton.label:SetText(manual > 0 and "SEND NEXT (" .. manual .. ")"
        or "NO PENDING")
    if u.tab == "settings" then u.settings:Show() else u.settings:Hide() end
    if u.tab == "about" then u.about:Show() else u.about:Hide() end
    for tab, button in pairs(u.tabs) do
        if tab == u.tab then button:SetBackdropBorderColor(0.9, 0.68, 0.34, 1)
        else button:SetBackdropBorderColor(unpack(C.edge)) end
    end
    u.addButton:SetEnabled(isEditor)
    u.deleteButton:SetEnabled(isEditor and kind ~= "welcome")
    u.addButton:SetAlpha(isEditor and 1 or 0.4)
    u.deleteButton:SetAlpha(kind == "welcome" and 0.4 or 1)
    u.addButton.label:SetText(kind == "welcome" and "RESTORE" or "ADD")
    u.deleteButton.label:SetText(kind == "welcome" and "5 SLOTS" or "DELETE")
    u.uniqueHint:SetShown(isEditor and kind == "welcome")
    u.restoreOnlineBtn:SetShown(isEditor and kind == "online")
    if isEditor then
        u.indexLabel:SetText(string.upper(kind) .. " MESSAGE  " ..
            u.index[kind] .. " / " .. #self.db.messages[kind])
        u.channelBtn.label:SetText("SEND VIA: " .. self.db.channels[kind])
        self:UpdatePreview()
    end

    if u.subTab == "messages" then
        u.messagePage:Show(); u.policyPage:Hide()
    else
        u.policyPage:Show(); u.messagePage:Hide()
    end
    u.behaviorTab:SetBackdropBorderColor(u.subTab == "safety"
        and 0.9 or 0.43, u.subTab == "safety" and 0.68 or 0.34,
        u.subTab == "safety" and 0.34 or 0.22, 1)
    u.messageTab:SetBackdropBorderColor(u.subTab == "messages"
        and 0.9 or 0.43, u.subTab == "messages" and 0.68 or 0.34,
        u.subTab == "messages" and 0.34 or 0.22, 1)

    u.leaderBtn.label:SetText("GUILD MASTER ONLY: " ..
        (self.db.leaderOnly and "ON" or "OFF"))
    u.randomBtn.label:SetText("SHUFFLED WELCOMES: " ..
        (self.db.randomMessages and "ON" or "OFF"))
    u.manualBtn.label:SetText("MANUAL MODE: " ..
        (self.db.manualMode and "ON" or "OFF"))
    u.quietBtn.label:SetText("QUIET HOURS: " ..
        (self.db.quietEnabled and "ON" or "OFF"))
    u.onlineCdBtn.label:SetText("ONLINE COOLDOWN: " ..
        self.db.onlineCooldownHours .. "h")
    u.cdBtn.label:SetText("WELCOME COOLDOWN: " .. self.db.cooldownMinutes .. "m")
    u.gapBtn.label:SetText("CHAT SPACING: " .. self.db.spacingSeconds .. "s")
    u.limitBtn.label:SetText("MAX / 5 MINUTES: " .. self.db.maxPerFiveMinutes)
    u.startBtn.label:SetText("FROM " .. string.format("%02d:00", self.db.quietStart))
    u.endBtn.label:SetText("TO " .. string.format("%02d:00", self.db.quietEnd))
    u.discordBtn.label:SetText("DISCORD REMINDER: " ..
        (self.db.discordEnabled and "ON" or "OFF"))
    u.whisperBtn.label:SetText("WELCOME WHISPER: " ..
        (self.db.welcomeWhisperEnabled and "ON" or "OFF"))
    u.resetButton.label:SetText(u.confirmReset and self:Now() <= u.confirmReset
        and "CONFIRM RESET?  (KEEPS YOUR MESSAGES)"
        or "RESTORE DEFAULT SETTINGS")

    self:UpdateActivity()
end
