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

    local tabs = {}
    local tabIDs = { "welcome", "online", "settings", "about" }
    local tabNames = { "WELCOME", "ONLINE", "SETTINGS", "ABOUT" }
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

    Button(editor, "SAVE MESSAGE", 0, -109, 149, 38, function()
        if Greeter:CommitDraft() then Greeter:Print("Message saved.") end
    end)
    Button(editor, "ADD NEW", 161, -109, 149, 38, function()
        if not Greeter:CommitDraft() then return end
        local kind = Greeter:CurrentKind()
        local starter = kind == "welcome" and "Welcome {player} to {guild}!" or "Welcome back, {player}!"
        local ok, index = Greeter:AddMessage(kind, starter)
        if not ok then Greeter:Print(index); return end
        Greeter.ui.index[kind] = index
        Greeter:LoadSelectedMessage()
        Greeter:UpdatePanel()
    end)
    Button(editor, "DELETE", 322, -109, 150, 38, function()
        local kind = Greeter:CurrentKind()
        local ok, err = Greeter:DeleteMessage(kind, Greeter.ui.index[kind])
        if not ok then Greeter:Print(err); return end
        Greeter.ui.index[kind] = math.max(1, math.min(Greeter.ui.index[kind], #Greeter.db.messages[kind]))
        Greeter:LoadSelectedMessage()
        Greeter:UpdatePanel()
    end)

    local channelBtn = Button(editor, "", 0, -163, 472, 37, function()
        local kind = Greeter:CurrentKind()
        Greeter.db.channels[kind] = Cycle(Greeter.channels, Greeter.db.channels[kind])
        Greeter:RefreshUI()
    end)
    Label(editor, "LIVE PREVIEW  -  NOT SENT TO GUILD CHAT", 0, -220, "GameFontNormalSmall", C.gold)
    local previewText = Label(editor, "", 0, -246, "GameFontHighlightSmall")
    previewText:SetWidth(466)
    previewText:SetJustifyH("LEFT")
    previewText:SetWordWrap(true)

    Label(p, "VARIABLES: {player} {full} {guild} {class} {level} {rank}", 20, -559)
    local footer = Label(p, "NOVYX FORGE  |  /fgreet  |  v" .. self.version ..
        "  |  R-click minimap: pause", 20, -588)
    footer:SetTextColor(0.55, 0.55, 0.52)

    local settings = CreateFrame("Frame", nil, p)
    settings:SetSize(472, 335)
    settings:SetPoint("TOPLEFT", p, "TOPLEFT", 19, -239)
    local leaderBtn = Button(settings, "", 0, 0, 230, 42, function()
        Greeter.db.leaderOnly = not Greeter.db.leaderOnly; Greeter:RefreshUI()
    end)
    local randomBtn = Button(settings, "", 242, 0, 230, 42, function()
        Greeter.db.randomMessages = not Greeter.db.randomMessages; Greeter:RefreshUI()
    end)
    local discordBtn = Button(settings, "", 0, -54, 230, 42, function()
        Greeter.db.discordEnabled = not Greeter.db.discordEnabled; Greeter:RefreshUI()
    end)
    local quietBtn = Button(settings, "", 242, -54, 230, 42, function()
        Greeter.db.quietEnabled = not Greeter.db.quietEnabled; Greeter:RefreshUI()
    end)
    local cdBtn = Button(settings, "", 0, -108, 230, 42, function()
        Greeter.db.cooldownMinutes = Cycle(Greeter.cooldowns, Greeter.db.cooldownMinutes)
        Greeter:RefreshUI()
    end)
    local gapBtn = Button(settings, "", 242, -108, 230, 42, function()
        Greeter.db.spacingSeconds = Cycle(Greeter.spacings, Greeter.db.spacingSeconds)
        Greeter:RefreshUI()
    end)
    local limitBtn = Button(settings, "", 0, -162, 230, 42, function()
        Greeter.db.maxPerFiveMinutes = Cycle(Greeter.limits, Greeter.db.maxPerFiveMinutes)
        Greeter:RefreshUI()
    end)
    local startBtn = Button(settings, "", 242, -162, 110, 42, function()
        Greeter.db.quietStart = (Greeter.db.quietStart + 1) % 24
        Greeter:RefreshUI()
    end)
    local endBtn = Button(settings, "", 362, -162, 110, 42, function()
        Greeter.db.quietEnd = (Greeter.db.quietEnd + 1) % 24
        Greeter:RefreshUI()
    end)
    Label(settings, "DISCORD REMINDER (APPENDED TO WELCOME IF ENABLED)", 0, -219,
        "GameFontNormalSmall", C.gold)
    local discordEdit = Input(settings, 0, -241, 472, 100)
    discordEdit:SetText(self.db.discordText)
    local function SaveDiscord()
        Greeter.db.discordText = (discordEdit:GetText() or ""):match("^%s*(.-)%s*$")
        Greeter:RefreshUI()
        discordEdit:ClearFocus()
        Greeter:Print("Discord text saved.")
    end
    discordEdit:SetScript("OnEnterPressed", SaveDiscord)
    Button(settings, "SAVE DISCORD MESSAGE", 0, -286, 472, 38, SaveDiscord)

    local about = CreateFrame("Frame", nil, p)
    about:SetSize(472, 320)
    about:SetPoint("TOPLEFT", p, "TOPLEFT", 19, -239)
    Label(about, "GUILD GREETINGS, WITHOUT THE GUILD SPAM.", 0, 0,
        "GameFontNormal", C.gold)
    local lines = {
        "Welcomes freshly joined guild members.",
        "Greets members when they switch from offline to online.",
        "Never greets the entire roster when you log in.",
        "Only Guild Master broadcasts by default.",
        "Separate channels and custom templates for both types.",
        "Quiet hours use the server's in-game clock.",
        "Local channel is a safe way to preview without chatting.",
        "No cloud, no tracking, no external addon dependencies.",
        "",
        "Commands: /fgreet  /fgreet status  /fgreet help",
        "Website: wow.novyxforge.com",
    }
    for i, line in ipairs(lines) do
        Label(about, line, 0, -28 - (i - 1) * 26)
    end

    self.ui = {
        tab = "welcome",
        index = { welcome = 1, online = 1 },
        editor = editor, settings = settings, about = about,
        welcomeToggle = welcomeToggle, onlineToggle = onlineToggle,
        tabs = tabs, statusLabel = statusLabel, indexLabel = indexLabel,
        messageEdit = messageEdit, channelBtn = channelBtn,
        previewText = previewText, leaderBtn = leaderBtn, randomBtn = randomBtn,
        discordBtn = discordBtn, quietBtn = quietBtn, cdBtn = cdBtn,
        gapBtn = gapBtn, limitBtn = limitBtn, startBtn = startBtn, endBtn = endBtn,
        discordEdit = discordEdit,
    }
    self.frame = p
    self:LoadSelectedMessage()
    self:UpdatePanel()
    p:Hide()
end

function Greeter:UpdatePanel()
    local u = self.ui
    if not u or not self.db then return end
    u.welcomeToggle.label:SetText("NEW MEMBERS\n" ..
        (self.db.enabled.welcome and "ENABLED" or "DISABLED"))
    u.onlineToggle.label:SetText("ONLINE GREETINGS\n" ..
        (self.db.enabled.online and "ENABLED" or "DISABLED"))
    local can, reason = self:CanAnnounce()
    u.statusLabel:SetText(self.ready and (can and "GUILD ROSTER READY  -  ACTIVE"
        or "GUILD ROSTER READY  -  " .. tostring(reason))
        or "WAITING FOR GUILD ROSTER...")
    local kind = self:CurrentKind()
    local isEditor = u.tab == "welcome" or u.tab == "online"
    if isEditor then u.editor:Show() else u.editor:Hide() end
    if u.tab == "settings" then u.settings:Show() else u.settings:Hide() end
    if u.tab == "about" then u.about:Show() else u.about:Hide() end
    for tab, button in pairs(u.tabs) do
        if tab == u.tab then
            button:SetBackdropBorderColor(0.9, 0.68, 0.34, 1)
        else
            button:SetBackdropBorderColor(unpack(C.edge))
        end
    end
    if isEditor then
        u.indexLabel:SetText(string.upper(kind) .. " MESSAGE  " ..
            u.index[kind] .. " / " .. #self.db.messages[kind])
        u.channelBtn.label:SetText("SEND VIA: " .. self.db.channels[kind] ..
            "  (CLICK TO CHANGE)")
        self:UpdatePreview()
    end
    u.leaderBtn.label:SetText("GUILD MASTER ONLY: " ..
        (self.db.leaderOnly and "ON" or "OFF"))
    u.randomBtn.label:SetText("RANDOM MESSAGES: " ..
        (self.db.randomMessages and "ON" or "OFF"))
    u.discordBtn.label:SetText("DISCORD REMINDER: " ..
        (self.db.discordEnabled and "ON" or "OFF"))
    u.quietBtn.label:SetText("QUIET HOURS: " ..
        (self.db.quietEnabled and "ON" or "OFF"))
    u.cdBtn.label:SetText("PLAYER COOLDOWN: " .. self.db.cooldownMinutes .. "m")
    u.gapBtn.label:SetText("CHAT SPACING: " .. self.db.spacingSeconds .. "s")
    u.limitBtn.label:SetText("MAX / 5 MINUTES: " .. self.db.maxPerFiveMinutes)
    u.startBtn.label:SetText("FROM " .. string.format("%02d:00", self.db.quietStart))
    u.endBtn.label:SetText("TO " .. string.format("%02d:00", self.db.quietEnd))
end
