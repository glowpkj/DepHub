local game = game
local pcall = pcall
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local UI = {}
UI.__index = UI

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
    local mainFrame = Instance.new("ScrollingFrame")
    mainFrame.Size = UDim2.new(1, 0, 1, -50)
    mainFrame.Position = UDim2.fromOffset(0, 50)
    mainFrame.BackgroundTransparency = 1
    mainFrame.BorderSizePixel = 0
    mainFrame.ScrollBarThickness = 3
    mainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    mainFrame.Parent = frame
    local mainLayout = Instance.new("UIListLayout")
    mainLayout.Padding = UDim.new(0, 8)
    mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    mainLayout.Parent = mainFrame
    local mainPadding = Instance.new("UIPadding")
    mainPadding.PaddingTop = UDim.new(0, 10)
    mainPadding.PaddingBottom = UDim.new(0, 10)
    mainPadding.Parent = mainFrame
    local function toggle(name)
        return function(enabled)
            return self.State and self.State.SetToggle and self.State:SetToggle(name, enabled) or false
        end
    end
    makeToggle(mainFrame, "Player ESP", toggle("PlayerESP"), state:GetToggle("PlayerESP"))
    makeToggle(mainFrame, "Fruit ESP", toggle("FruitESP"), state:GetToggle("FruitESP"))
    makeToggle(mainFrame, "Unbreakable All", toggle("UnbreakableAll"), state:GetToggle("UnbreakableAll"))
    makeToggle(mainFrame, "Dash Customizer", toggle("DashCustomizer"), state:GetToggle("DashCustomizer"))
    makeToggle(mainFrame, "Flashstep No Cooldown", toggle("FlashstepNoCooldown"), state:GetToggle("FlashstepNoCooldown"))
    makeToggle(mainFrame, "Water Walking", toggle("WaterWalking"), state:GetToggle("WaterWalking"))
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
    pirates.MouseButton1Click:Connect(function() if state:SetPreferredTeam("Pirates") then renderTeam() end end)
    marines.MouseButton1Click:Connect(function() if state:SetPreferredTeam("Marines") then renderTeam() end end)
    renderTeam()
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
    if self.Gui then pcall(self.Gui.Destroy, self.Gui) end
    self.Gui = nil
    self.Frame = nil
    self.ToggleButton = nil
    self.State = nil
end

return UI
