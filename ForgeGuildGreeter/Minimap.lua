local _, ns = ...
local Greeter = ns.Greeter

local function Place(button, angle)
    if not Minimap then return end
    local theta = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(theta) * 79, math.sin(theta) * 79)
end

local function MouseAngle()
    if not Minimap or not GetCursorPosition then return nil end
    local x, y = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not x or not y or not cx or not cy or not scale or scale == 0 then return nil end
    local dx, dy = cx / scale - x, cy / scale - y
    if type(math.atan2) == "function" then
        return math.deg(math.atan2(dy, dx)) % 360
    end
    local angle = math.deg(math.atan(dy / (dx == 0 and 0.00001 or dx)))
    if dx < 0 then angle = angle + 180 end
    return angle % 360
end

function Greeter:UpdateMinimap()
    if not self.minimapButton then return end
    if self.db.minimapHidden then self.minimapButton:Hide()
    else self.minimapButton:Show(); Place(self.minimapButton, self.db.minimapAngle) end
end

function Greeter:CreateMinimapButton()
    if not Minimap then
        self:Print("Minimap unavailable. Use /fgreet to open the panel.")
        return
    end
    if self.minimapButton then self.minimapButton:Hide() end
    local b = CreateFrame("Button", "ForgeGuildGreeterMinimap", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
    icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", b, "TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetScript("OnClick", function(_, click)
        if click == "RightButton" then
            Greeter.db.paused = not Greeter.db.paused
            if Greeter.db.paused then
                Greeter.queue, Greeter.queuedKeys = {}, {}
            end
            Greeter:RefreshUI()
            Greeter:Print(Greeter.db.paused and "Greetings PAUSED." or "Greetings RESUMED.")
        else
            Greeter:Toggle()
        end
    end)
    b:SetScript("OnEnter", function(frame)
        if not GameTooltip then return end
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:AddLine("FORGE GUILDGREETER", 1, 0.78, 0.45)
        GameTooltip:AddLine("Left-click: Open greeting settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Pause/resume all greetings", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move around the minimap", 0.72, 0.72, 0.72)
        GameTooltip:AddLine(Greeter.db.paused and "Status: PAUSED" or "Status: ACTIVE",
            0.87, 0.77, 0.53)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    b:SetScript("OnDragStart", function(frame)
        frame:SetScript("OnUpdate", function(target)
            local angle = MouseAngle()
            if angle then
                Greeter.db.minimapAngle = math.floor(angle)
                Place(target, angle)
            end
        end)
        if GameTooltip then GameTooltip:Hide() end
    end)
    b:SetScript("OnDragStop", function(frame)
        frame:SetScript("OnUpdate", nil)
    end)
    self.minimapButton = b
    self:UpdateMinimap()
end
