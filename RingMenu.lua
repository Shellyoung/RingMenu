-- Default Settings
RingMenu_defaultSettings = {
    startPageID = 13,
    numButtons = 12,
    radius = 100.0,
    angleOffset = 0.0,
    animationSpeedOpen = 4.0,
    animationSpeedClose = 3.0,
    backdropScale = 1.5,
    colorR = 0.0,
    colorG = 0.0,
    colorB = 0.0,
    colorAlpha = 0.5,
    autoClose = true,
    zoomButtonIcons = false,
}

function RingMenu_ResetDefaultSettings()
    RingMenu_settings = {}
    for k, v in pairs(RingMenu_defaultSettings) do
        RingMenu_settings[k] = v
    end
end

function RingMenu_LoadNewDefaultSettings()
    -- Only updates fields that are not present in the current settings dictionary.
    -- Used for initializing new settings with sensible initial values after a version update.
    for k, v in pairs(RingMenu_defaultSettings) do
        if RingMenu_settings[k] == nil then
            RingMenu_settings[k] = v
        end
    end
end

-- Settings (saved variables)
RingMenu_settings = {}

-- Runtime variables
RingMenu_currentSize = 0.0
RingMenu_targetSize = 0.0
RingMenu_currentX = -1.0
RingMenu_targetX = -1.0
RingMenu_currentY = -1.0
RingMenu_targetY = -1.0
RingMenu_isOpen = false

-- Slash Commands
SLASH_RINGMENU1 = "/ringmenu"

function SlashCmdList.RINGMENU(message)
	RingMenuSettingsFrame:Show()
end

-- Hooked ActionButton functions

local ActionButton_GetPagedID_Old
function RingMenuButton_GetPagedID(button)
	if button.isRingMenu then
		return RingMenu_settings.startPageID + button:GetID() - 1
	else
        return ActionButton_GetPagedID_Old(button)
    end
end

function RingMenuButton_OnClick()
    this:oldScriptOnClick()
    if IsShiftKeyDown() or CursorHasSpell() or CursorHasItem() then
        -- User is just changing button slots, keep RingMenu open
    elseif RingMenu_settings.autoClose then
        -- Clicked a button, close RingMenu
        RingMenu_Close()
    end
end

function RingMenuButton_OnEnter()
    -- Only show the tooltip if the ring menu is currently open
    -- Prevents flickering tooltips on fadeout animations
    if RingMenu_isOpen then
        this:oldScriptOnEnter()
    end
end

-- RingMenuFrame callbacks

function RingMenuFrame_OnLoad()
    RingMenu_ResetDefaultSettings()
    RingMenu_Close()
    this:RegisterEvent("VARIABLES_LOADED")
	RingMenuFrame:SetFrameLevel(7)
	
	--Create background frame
	local bg = CreateFrame("Frame", "RingMenuFrameBackground", RingMenuFrame)
	bg:SetFrameStrata("MEDIUM")
	bg:SetFrameLevel(7)
	bg:SetWidth(300)
	bg:SetHeight(300)
	bg:SetPoint("CENTER", RingMenuFrame, "CENTER")
	
	--Create background texture
	local tex = bg:CreateTexture("RingMenuShadow", "BACKGROUND")
	tex:SetTexture("Interface\\AddOns\\RingMenu\\RingMenuBackdrop")
	tex:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT")
	tex:SetPoint("TOPRIGHT", bg, "TOPRIGHT")
end

function RingMenuFrame_OnEvent(event)
    if event == "VARIABLES_LOADED" then
        RingMenu_LoadNewDefaultSettings()
        RingMenuFrame_ConfigureButtons()
        RingMenuSettings_SetupSettingsFrame()

        -- Hook global button callbacks
        ActionButton_GetPagedID_Old = ActionButton_GetPagedID
        ActionButton_GetPagedID = RingMenuButton_GetPagedID
    end
end

RingMenu_usedButtons = {}
function RingMenuFrame_ConfigureButtons()
    -- Hide all used buttons
    for _, button in ipairs(RingMenu_usedButtons) do
        button:Hide()
        button:Disable()
        button:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", -1000, -1000)
    end
    RingMenu_usedButtons = {}
    
    -- Create ring menu buttons
    for i = 1, RingMenu_settings.numButtons do
        local buttonName = "RingMenuButton" .. i
        local button = getglobal(buttonName) -- Try to reuse a button, if available
        if not button then -- No reusable button, create a new one
            button = CreateFrame("CheckButton", buttonName, RingMenuFrame, "BonusActionButtonTemplate")
            -- Hide Hotkey text
            local hotkey = getglobal(buttonName .. "HotKey")
            hotkey:Hide()
            -- Hook individual button callbacks
            button.oldScriptOnClick = button:GetScript("OnClick")
            button:SetScript("OnClick", RingMenuButton_OnClick)
            button.oldScriptOnEnter = button:GetScript("OnEnter")
            button:SetScript("OnEnter", RingMenuButton_OnEnter)
        end
        
        button:SetID(i)
        button:SetPoint("CENTER", RingMenuFrame, "CENTER", 0, 0)
		button:SetFrameStrata("MEDIUM") --ADDED
        button:SetFrameLevel(8) --CHANGED from 2
        button.isRingMenu = true
        button.isBonus = true
        button.buttonType = "RING_MENU"

        local icon = getglobal(buttonName .. "Icon")
        if cyCircled_RingMenu and RingMenu_settings.zoomButtonIcons then
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        else
            icon:SetTexCoord(0.0, 1.0, 0.0, 1.0)
        end

        table.insert(RingMenu_usedButtons, button)
        button:Enable()
        button:Show()
        
        this = button
        ActionButton_Update()
    end
    
    RingMenu_UpdateButtonPositions()
end

function RingMenuFrame_OnUpdate(elapsed)
    if RingMenu_currentSize ~= RingMenu_targetSize then
        -- Snap to target size if within epsilon
        if math.abs(RingMenu_currentSize - RingMenu_targetSize) < 0.001 then
            RingMenu_currentSize = RingMenu_targetSize
        end

        -- Animate
        local animationSpeed = 0.0
        if RingMenu_isOpen then
            animationSpeed = RingMenu_settings.animationSpeedOpen
        else
            animationSpeed = RingMenu_settings.animationSpeedClose
        end
        local alpha = math.pow(0.001, elapsed * animationSpeed * 0.6)

        RingMenu_currentSize = RingMenu_Lerp(RingMenu_targetSize, RingMenu_currentSize, alpha)
        RingMenu_currentX = RingMenu_Lerp(RingMenu_targetX, RingMenu_currentX, alpha)
        RingMenu_currentY = RingMenu_Lerp(RingMenu_targetY, RingMenu_currentY, alpha)

        -- Update appearance
        RingMenu_UpdateButtonPositions()
    end

    -- Hide frame when the closing animation has finished
    if (not RingMenu_isOpen) and RingMenu_currentSize == RingMenu_targetSize then
        RingMenuFrame:Hide()
    end
end

-- RingMenu methods

function RingMenu_Lerp(a, b, alpha)
    return a * (1 - alpha) + b * alpha
end

function RingMenu_UpdateButtonPositions()
    -- Button positions
    local radius = RingMenu_settings.radius * RingMenu_currentSize
    local angleOffsetRadians = RingMenu_settings.angleOffset / 180.0 * math.pi
    for i = 1, RingMenu_settings.numButtons do
        local button = getglobal("RingMenuButton" .. i)
        local angle = angleOffsetRadians + 2.0 * math.pi * (i - 1) / RingMenu_settings.numButtons
        local buttonX = radius * math.sin(angle)
        local buttonY = radius * math.cos(angle)
        button:SetPoint("CENTER", RingMenuFrame, "CENTER", buttonX, buttonY)
		button:SetScale(RingMenu_currentSize)
        button:SetAlpha(RingMenu_currentSize)
    end

    -- Background shadow
    local backdropAlpha = RingMenu_currentSize * RingMenu_settings.colorAlpha
    RingMenuShadow:SetVertexColor(RingMenu_settings.colorR, RingMenu_settings.colorG, RingMenu_settings.colorB, backdropAlpha)

    -- Ring size
    local size = radius * 2 * RingMenu_settings.backdropScale * RingMenu_currentSize
    RingMenuFrameBackground:SetWidth(size)
    RingMenuFrameBackground:SetHeight(size)

    -- Ring position
    --RingMenuFrame:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", RingMenu_currentX, RingMenu_currentY)
    RingMenuFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0) --CHANGED
end

function RingMenu_Toggle()
    if RingMenu_isOpen then
        RingMenu_Close()
    else
        RingMenu_Open()
    end
end

function RingMenu_GetMousePosition()
    local mouseX, mouseY = GetCursorPosition()
    local uiScale = RingMenuFrame:GetParent():GetEffectiveScale()
    mouseX = mouseX / uiScale
    mouseY = mouseY / uiScale
    return mouseX, mouseY
end

function RingMenu_Close()
    local mouseX, mouseY = RingMenu_GetMousePosition()
    RingMenu_targetSize = 0.0
    RingMenu_targetX = mouseX
    RingMenu_targetY = mouseY
    RingMenu_isOpen = false
end

function RingMenu_Open()
    local mouseX, mouseY =  RingMenu_GetMousePosition()
    
    RingMenu_targetSize = 1.0
    RingMenu_targetX = mouseX
    RingMenu_targetY = mouseY
	
    if RingMenu_currentSize == 0.0 then
        RingMenu_currentX = RingMenu_targetX
        RingMenu_currentY = RingMenu_targetY
    end
	
    RingMenu_isOpen = true
    RingMenuFrame:Show()
end
