local game = game
local type = type
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local math_floor = math.floor

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local UI = {}
UI.__index = UI

local function safeDestroy(instance)
    if instance then pcall(instance.Destroy, instance) end
end

local function corner(parent, radius)
    local object = Instance.new("UICorner")
    object.CornerRadius = UDim.new(0, radius)
    object.Parent = parent
    return object
end

local function stroke(parent, transparency)
    local object = Instance.new("UIStroke")
    object.Color = Color3.fromRGB(65, 65, 65)
    object.Transparency = transparency or 0
    object.Thickness = 1
    object.Parent = parent
    return object
end

local function makeButton(parent, text)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamMedium
    button.Text = text
    button.TextColor3 = Color3.fromRGB(235, 235, 235)
    button.TextSize = 12
    button.Parent = parent
    corner(button, 8)
    return button
end

local function makeLabel(parent, text, height)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 0, height or 26)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = Color3.fromRGB(170, 170, 170)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function makeToggle(parent, title, callback, initial)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -24, 0, 42)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    row.BorderSizePixel = 0
    row.Parent = parent
    corner(row, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -74, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.Text = title
    label.TextColor3 = Color3.fromRGB(225, 225, 225)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local button = makeButton(row, "OFF")
    button.Size = UDim2.fromOffset(48, 26)
    button.Position = UDim2.new(1, -60, 0.5, 0)
    button.AnchorPoint = Vector2.new(0, 0.5)
    local enabled = initial == true

    local function render()
        button.Text = enabled and "ON" or "OFF"
        button.BackgroundColor3 = enabled and Color3.fromRGB(35, 110, 70) or Color3.fromRGB(28, 28, 28)
    end

    button.MouseButton1Click:Connect(function()
        local nextState = not enabled
        local ok, result = pcall(callback, nextState)
        if ok and result ~= false then enabled = nextState end
        render()
    end)

    render()
    return row
end

local function makeValueInput(parent, title, initialValue, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -24, 0, 42)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    row.BorderSizePixel = 0
    row.Parent = parent
    corner(row, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -104, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.Text = title
    label.TextColor3 = Color3.fromRGB(225, 225, 225)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local input = Instance.new("TextBox")
    input.Size = UDim2.fromOffset(76, 26)
    input.Position = UDim2.new(1, -88, 0.5, 0)
    input.AnchorPoint = Vector2.new(0, 0.5)
    input.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.Font = Enum.Font.GothamMedium
    input.Text = tostring(initialValue)
    input.TextColor3 = Color3.fromRGB(235, 235, 235)
    input.TextSize = 12
    input.Parent = row
    corner(input, 8)

    local currentValue = math_floor(tonumber(initialValue) or 1)

    input.FocusLost:Connect(function()
        local value = tonumber(input.Text)
        if not value then input.Text = tostring(currentValue); return end
        value = math_floor(value + 0.5)
        if value < 1 then value = 1 end
        if value > 100 then value = 100 end
        local ok, result = pcall(callback, value)
        if ok and result ~= false then currentValue = value; input.Text = tostring(value) else input.Text = tostring(currentValue) end
    end)

    return row
end

function UI.new(state)
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end

    local oldGui = playerGui:FindFirstChild("DepHubBloxFruitsUI")
    if oldGui then oldGui:Destroy() end

    local self = setmetatable({}, UI)
    self.State = state
    self.Destroyed = false
    self.Visible = false
    self.Connections = {}
    self.Tab = "Main"

    local gui = Instance.new("ScreenGui")
    gui.Name = "DepHubBloxFruitsUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 9999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui
    self.Gui = gui

    local toggleButton = makeButton(gui, "DEPHUB")
    toggleButton.Size = UDim2.fromOffset(82, 30)
    toggleButton.Position = UDim2.fromOffset(18, 90)
    toggleButton.TextSize = 11
    self.ToggleButton = toggleButton

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(330, 500)
    frame.Position = UDim2.fromOffset(18, 128)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = gui
    corner(frame, 12)
    stroke(frame, 0.15)
    self.Frame = frame

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame
    corner(titleBar, 12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -56, 1, 0)
    title.Position = UDim2.fromOffset(14, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Blox Fruits"
    title.TextColor3 = Color3.fromRGB(245, 245, 245)
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local close = makeButton(titleBar, "X")
    close.Size = UDim2.fromOffset(28, 26)
    close.Position = UDim2.new(1, -40, 0.5, 0)
    close.AnchorPoint = Vector2.new(0, 0.5)
    close.TextSize = 11

    local tabs = Instance.new("Frame")
    tabs.Size = UDim2.new(1, -16, 0, 34)
    tabs.Position = UDim2.fromOffset(8, 44)
    tabs.BackgroundTransparency = 1
    tabs.Parent = frame

    local mainTab = makeButton(tabs, "MAIN")
    mainTab.Size = UDim2.new(0.5, -4, 1, 0)
    mainTab.Position = UDim2.fromOffset(0, 0)
    local cloneTab = makeButton(tabs, "VISUAL CLONER")
    cloneTab.Size = UDim2.new(0.5, -4, 1, 0)
    cloneTab.Position = UDim2.new(0.5, 4, 0, 0)

    local function styleTabs()
        mainTab.BackgroundColor3 = self.Tab == "Main" and Color3.fromRGB(45, 45, 45) or Color3.fromRGB(24, 24, 24)
        cloneTab.BackgroundColor3 = self.Tab == "Visual" and Color3.fromRGB(45, 45, 45) or Color3.fromRGB(24, 24, 24)
    end

    local mainFrame = Instance.new("ScrollingFrame")
    mainFrame.Size = UDim2.new(1, 0, 1, -86)
    mainFrame.Position = UDim2.fromOffset(0, 86)
    mainFrame.BackgroundTransparency = 1
    mainFrame.BorderSizePixel = 0
    mainFrame.ScrollBarThickness = 3
    mainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    mainFrame.CanvasSize = UDim2.fromOffset(0, 0)
    mainFrame.Parent = frame

    local mainLayout = Instance.new("UIListLayout")
    mainLayout.Padding = UDim.new(0, 8)
    mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    mainLayout.Parent = mainFrame
    local mainPadding = Instance.new("UIPadding")
    mainPadding.PaddingTop = UDim.new(0, 10)
    mainPadding.PaddingBottom = UDim.new(0, 10)
    mainPadding.Parent = mainFrame

    local visualFrame = Instance.new("ScrollingFrame")
    visualFrame.Size = UDim2.new(1, 0, 1, -86)
    visualFrame.Position = UDim2.fromOffset(0, 86)
    visualFrame.BackgroundTransparency = 1
    visualFrame.BorderSizePixel = 0
    visualFrame.ScrollBarThickness = 3
    visualFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    visualFrame.CanvasSize = UDim2.fromOffset(0, 0)
    visualFrame.Visible = false
    visualFrame.Parent = frame

    local visualLayout = Instance.new("UIListLayout")
    visualLayout.Padding = UDim.new(0, 8)
    visualLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    visualLayout.Parent = visualFrame
    local visualPadding = Instance.new("UIPadding")
    visualPadding.PaddingTop = UDim.new(0, 10)
    visualPadding.PaddingBottom = UDim.new(0, 10)
    visualPadding.Parent = visualFrame

    local function toggle(name)
        return function(enabled)
            if not self.State or type(self.State.SetToggle) ~= "function" then return false end
            return self.State:SetToggle(name, enabled)
        end
    end

    makeToggle(mainFrame, "Player ESP", toggle("PlayerESP"), state:GetToggle("PlayerESP"))
    makeToggle(mainFrame, "Fruit ESP", toggle("FruitESP"), state:GetToggle("FruitESP"))
    makeToggle(mainFrame, "Unbreakable All", toggle("UnbreakableAll"), state:GetToggle("UnbreakableAll"))
    makeValueInput(mainFrame, "Dash Length", state.Values and state.Values.DashLength or 1, function(value)
        if not self.State or type(self.State.SetDashLength) ~= "function" then return false end
        return self.State:SetDashLength(value)
    end)
    makeToggle(mainFrame, "Dash Customizer", toggle("DashCustomizer"), state:GetToggle("DashCustomizer"))
    makeToggle(mainFrame, "Flashstep No Cooldown", toggle("FlashstepNoCooldown"), state:GetToggle("FlashstepNoCooldown"))
    makeToggle(mainFrame, "Water Walking", toggle("WaterWalking"), state:GetToggle("WaterWalking"))
    makeToggle(mainFrame, "Silent Aim", toggle("SilentAim"), state:GetToggle("SilentAim"))
    makeToggle(mainFrame, "Visual Cloner", toggle("VisualCloner"), state:GetToggle("VisualCloner"))
    makeToggle(mainFrame, "Auto Join Team", toggle("AutoJoinTeam"), state:GetToggle("AutoJoinTeam"))

    makeLabel(mainFrame, "PREFERRED TEAM", 24)
    local teamRow = Instance.new("Frame")
    teamRow.Size = UDim2.new(1, -24, 0, 42)
    teamRow.BackgroundTransparency = 1
    teamRow.Parent = mainFrame
    local pirates = makeButton(teamRow, "PIRATES")
    pirates.Size = UDim2.new(0.5, -4, 1, 0)
    local marines = makeButton(teamRow, "MARINES")
    marines.Size = UDim2.new(0.5, -4, 1, 0)
    marines.Position = UDim2.new(0.5, 4, 0, 0)

    local function renderTeam()
        local selected = state:GetPreferredTeam()
        pirates.BackgroundColor3 = selected == "Pirates" and Color3.fromRGB(45, 45, 45) or Color3.fromRGB(28, 28, 28)
        marines.BackgroundColor3 = selected == "Marines" and Color3.fromRGB(45, 45, 45) or Color3.fromRGB(28, 28, 28)
    end
    pirates.MouseButton1Click:Connect(function()
        if state:SetPreferredTeam("Pirates") then renderTeam() end
    end)
    marines.MouseButton1Click:Connect(function()
        if state:SetPreferredTeam("Marines") then renderTeam() end
    end)
    renderTeam()

    makeLabel(visualFrame, "LOCAL VISUALS", 24)
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -24, 0, 40)
    info.BackgroundTransparency = 1
    info.Text = "Clones são apenas visuais no seu cliente."
    info.TextColor3 = Color3.fromRGB(145, 145, 145)
    info.TextWrapped = true
    info.Font = Enum.Font.Gotham
    info.TextSize = 11
    info.Parent = visualFrame

    local refresh = makeButton(visualFrame, "ATUALIZAR LISTA")
    refresh.Size = UDim2.new(1, -24, 0, 36)
    local clear = makeButton(visualFrame, "LIMPAR CLONES")
    clear.Size = UDim2.new(1, -24, 0, 36)

    local listHolder = Instance.new("Frame")
    listHolder.Size = UDim2.new(1, -24, 0, 0)
    listHolder.AutomaticSize = Enum.AutomaticSize.Y
    listHolder.BackgroundTransparency = 1
    listHolder.Parent = visualFrame
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = listHolder

    local function rebuild(options)
        for _, child in ipairs(listHolder:GetChildren()) do
            if not child:IsA("UIListLayout") then child:Destroy() end
        end
        for _, option in ipairs(options or {}) do
            local button = makeButton(listHolder, option.Name .. "  |  " .. option.Player)
            button.Size = UDim2.new(1, 0, 0, 38)
            button.MouseButton1Click:Connect(function()
                local feature = state.Features and state.Features.VisualCloner
                if feature then feature:CloneOption(option.Id) end
            end)
        end
    end

    local cloner = state.Features and state.Features.VisualCloner
    if cloner then
        cloner:SetRefreshCallback(rebuild)
        refresh.MouseButton1Click:Connect(function() cloner:_scan() end)
        clear.MouseButton1Click:Connect(function() cloner:ClearClones() end)
    end

    mainTab.MouseButton1Click:Connect(function()
        self.Tab = "Main"
        mainFrame.Visible = true
        visualFrame.Visible = false
        styleTabs()
    end)
    cloneTab.MouseButton1Click:Connect(function()
        self.Tab = "Visual"
        mainFrame.Visible = false
        visualFrame.Visible = true
        styleTabs()
    end)
    styleTabs()

    local dragging = false
    local dragStart
    local frameStart

    self.Connections[#self.Connections + 1] = titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = frame.Position
        end
    end)
    self.Connections[#self.Connections + 1] = UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
    end)
    self.Connections[#self.Connections + 1] = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    self.Connections[#self.Connections + 1] = toggleButton.MouseButton1Click:Connect(function() self:SetVisible(not self.Visible) end)
    self.Connections[#self.Connections + 1] = close.MouseButton1Click:Connect(function() self:SetVisible(false) end)

    return self
end

function UI:SetVisible(value)
    if self.Destroyed or not self.Frame then return end
    self.Visible = value == true
    self.Frame.Visible = self.Visible
end

function UI:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Visible = false
    for index = #self.Connections, 1, -1 do
        local connection = self.Connections[index]
        self.Connections[index] = nil
        if connection then pcall(connection.Disconnect, connection) end
    end
    safeDestroy(self.Gui)
    self.Gui = nil
    self.Frame = nil
    self.ToggleButton = nil
end

return UI
