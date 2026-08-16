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

local function makeToggle(parent, title, callback)
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
    local enabled = false

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
        if not value then
            input.Text = tostring(currentValue)
            return
        end
        value = math_floor(value + 0.5)
        if value < 1 then value = 1 end
        if value > 500 then value = 500 end
        local ok, result = pcall(callback, value)
        if ok and result ~= false then
            currentValue = value
            input.Text = tostring(value)
        else
            input.Text = tostring(currentValue)
        end
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
    frame.Size = UDim2.fromOffset(300, 390)
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

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 1, -40)
    list.Position = UDim2.fromOffset(0, 40)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Parent = list

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = list

    local function toggle(name)
        return function(enabled)
            if not self.State or type(self.State.SetToggle) ~= "function" then return false end
            return self.State:SetToggle(name, enabled)
        end
    end

    makeToggle(list, "Player ESP", toggle("PlayerESP"))
    makeToggle(list, "Fruit ESP", toggle("FruitESP"))
    makeToggle(list, "Unbreakable All", toggle("UnbreakableAll"))
    makeValueInput(list, "Dash Length", state.Values and state.Values.DashLength or 1, function(value)
        if not self.State or type(self.State.SetDashLength) ~= "function" then return false end
        return self.State:SetDashLength(value)
    end)
    makeToggle(list, "Dash Customizer", toggle("DashCustomizer"))
    makeToggle(list, "Flashstep No Cooldown", toggle("FlashstepNoCooldown"))
    makeToggle(list, "Water Walking", toggle("WaterWalking"))

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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    self.Connections[#self.Connections + 1] = toggleButton.MouseButton1Click:Connect(function()
        self:SetVisible(not self.Visible)
    end)

    self.Connections[#self.Connections + 1] = close.MouseButton1Click:Connect(function()
        self:SetVisible(false)
    end)

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
