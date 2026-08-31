local game = game
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local env = type(getgenv) == "function" and getgenv() or _G

local Previous = env.__DEPHUB_TSB_FRONTEND
if type(Previous) == "table" and type(Previous.Destroy) == "function" then
    pcall(Previous.Destroy, Previous)
end

local oldGui = PlayerGui:FindFirstChild("dephubTSB")
if oldGui then
    pcall(oldGui.Destroy, oldGui)
end

local Backend = env.__DEPHUB and env.__DEPHUB.TSB or nil
if type(Backend) ~= "table" then
    return false
end

local UI = {
    Destroyed = false,
    Open = false,
    Connections = {},
    Controls = {}
}

local Colors = {
    Header = Color3.fromRGB(20, 22, 24),
    Body = Color3.fromRGB(16, 18, 20),
    Control = Color3.fromRGB(28, 31, 33),
    ControlHover = Color3.fromRGB(34, 38, 40),
    Border = Color3.fromRGB(48, 52, 55),
    Text = Color3.fromRGB(255, 255, 255),
    Accent = Color3.fromRGB(114, 236, 190),
    Off = Color3.fromRGB(58, 62, 65)
}

local Width = 238
local HeaderHeight = 36
local BodyHeight = 314
local RowHeight = 34

local function track(connection)
    UI.Connections[#UI.Connections + 1] = connection
    return connection
end

local function disconnectAll(list)
    for index = #list, 1, -1 do
        local connection = list[index]
        list[index] = nil
        if connection then
            pcall(connection.Disconnect, connection)
        end
    end
end

local function corner(object, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius)
    value.Parent = object
    return value
end

local function stroke(object)
    local value = Instance.new("UIStroke")
    value.Thickness = 1
    value.Color = Colors.Border
    value.Transparency = 0.15
    value.Parent = object
    return value
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "dephubTSB"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Root = Instance.new("Frame")
Root.Name = "Root"
Root.Size = UDim2.fromOffset(Width, HeaderHeight)
Root.Position = UDim2.new(0.5, -Width / 2, 0.32, 0)
Root.BackgroundTransparency = 1
Root.BorderSizePixel = 0
Root.Parent = Gui

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, HeaderHeight)
Header.BackgroundColor3 = Colors.Header
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Root
corner(Header, 7)
stroke(Header)

local Accent = Instance.new("Frame")
Accent.Name = "Accent"
Accent.Size = UDim2.fromOffset(3, 18)
Accent.Position = UDim2.new(0, 8, 0.5, -9)
Accent.BackgroundColor3 = Colors.Accent
Accent.BorderSizePixel = 0
Accent.Parent = Header
corner(Accent, 2)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -82, 1, 0)
Title.Position = UDim2.fromOffset(19, 0)
Title.BackgroundTransparency = 1
Title.Text = "DepHub TSB"
Title.TextColor3 = Colors.Text
Title.TextSize = 14
Title.Font = Enum.Font.GothamMedium
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "Open"
OpenButton.Size = UDim2.fromOffset(58, 24)
OpenButton.Position = UDim2.new(1, -64, 0.5, -12)
OpenButton.BackgroundColor3 = Colors.Control
OpenButton.BorderSizePixel = 0
OpenButton.AutoButtonColor = false
OpenButton.Text = "OPEN"
OpenButton.TextColor3 = Colors.Text
OpenButton.TextSize = 11
OpenButton.Font = Enum.Font.GothamMedium
OpenButton.Parent = Header
corner(OpenButton, 5)

local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Size = UDim2.new(1, 0, 0, 0)
Body.Position = UDim2.new(0, 0, 0, HeaderHeight + 4)
Body.BackgroundColor3 = Colors.Body
Body.BorderSizePixel = 0
Body.ClipsDescendants = true
Body.Visible = false
Body.Parent = Root
corner(Body, 7)
stroke(Body)

local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -12, 1, -12)
Content.Position = UDim2.fromOffset(6, 6)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 2
Content.ScrollBarImageColor3 = Colors.Accent
Content.CanvasSize = UDim2.fromOffset(0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Body

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 5)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Content

local function addSection(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = tostring(text)
    label.TextColor3 = Colors.Text
    label.TextSize = 12
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = Content
    return label
end

local function addToggle(text, default, callback)
    local state = default == true

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, RowHeight)
    row.BackgroundColor3 = Colors.Control
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.Parent = Content
    corner(row, 5)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -55, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = tostring(text)
    label.TextColor3 = Colors.Text
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local switch = Instance.new("Frame")
    switch.Size = UDim2.fromOffset(34, 18)
    switch.Position = UDim2.new(1, -44, 0.5, -9)
    switch.BorderSizePixel = 0
    switch.Parent = row
    corner(switch, 9)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(12, 12)
    dot.BackgroundColor3 = Colors.Text
    dot.BorderSizePixel = 0
    dot.Parent = switch
    corner(dot, 6)

    local function render(instant)
        local switchColor = state and Colors.Accent or Colors.Off
        local dotPosition = state and UDim2.new(1, -15, 0, 3) or UDim2.fromOffset(3, 3)

        if instant then
            switch.BackgroundColor3 = switchColor
            dot.Position = dotPosition
            return
        end

        TweenService:Create(switch, TweenInfo.new(0.11), {
            BackgroundColor3 = switchColor
        }):Play()

        TweenService:Create(dot, TweenInfo.new(0.11, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = dotPosition
        }):Play()
    end

    local control = {}

    function control:Set(value, fire)
        state = value == true
        render(false)
        if fire ~= false and type(callback) == "function" then
            task.spawn(callback, state)
        end
    end

    function control:Get()
        return state
    end

    track(row.MouseButton1Click:Connect(function()
        control:Set(not state)
    end))

    track(row.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.08), {
            BackgroundColor3 = Colors.ControlHover
        }):Play()
    end))

    track(row.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.08), {
            BackgroundColor3 = Colors.Control
        }):Play()
    end))

    render(true)
    UI.Controls[text] = control
    return control
end

local function addInput(text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, RowHeight)
    row.BackgroundColor3 = Colors.Control
    row.BorderSizePixel = 0
    row.Parent = Content
    corner(row, 5)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.55, 0, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = tostring(text)
    label.TextColor3 = Colors.Text
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.34, 0, 0, 24)
    box.Position = UDim2.new(0.62, 0, 0.5, -12)
    box.BackgroundColor3 = Colors.Body
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Text = tostring(default)
    box.TextColor3 = Colors.Text
    box.TextSize = 11
    box.Font = Enum.Font.Gotham
    box.Parent = row
    corner(box, 4)

    track(box.FocusLost:Connect(function()
        local value = tonumber(box.Text)
        if value and type(callback) == "function" then
            local ok = callback(value)
            if ok == false then
                box.Text = tostring(default)
            end
        end
    end))

    UI.Controls[text] = box
    return box
end

addSection("Combat")

addToggle("Auto Block", Backend:GetToggle("AutoBlock"), function(value)
    Backend:SetAutoBlock(value)
end)

addToggle("M1 After Block", Backend:GetToggle("M1AfterBlock"), function(value)
    Backend:SetM1AfterBlock(value)
end)

addToggle("M1 Catch", Backend:GetToggle("M1Catch"), function(value)
    Backend:SetM1Catch(value)
end)

addSection("Ranges")

addInput("M1 Range", Backend:GetValue("NormalRange") or 30, function(value)
    return Backend:SetNormalRange(value)
end)

addInput("Dash Range", Backend:GetValue("SpecialRange") or 50, function(value)
    return Backend:SetSpecialRange(value)
end)

addInput("Skill Range", Backend:GetValue("SkillRange") or 50, function(value)
    return Backend:SetSkillRange(value)
end)

addInput("Skill Hold", Backend:GetValue("SkillHold") or 1.2, function(value)
    return Backend:SetSkillHold(value)
end)

local currentTween = nil

function UI:SetOpen(state)
    if self.Destroyed then return end
    state = state == true
    if self.Open == state then return end
    self.Open = state

    if currentTween then
        pcall(currentTween.Cancel, currentTween)
        currentTween = nil
    end

    if state then
        Body.Visible = true
        OpenButton.Text = "CLOSE"
        currentTween = TweenService:Create(Body, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, BodyHeight)
        })
        currentTween:Play()
        return
    end

    OpenButton.Text = "OPEN"
    currentTween = TweenService:Create(Body, TweenInfo.new(0.13, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Size = UDim2.new(1, 0, 0, 0)
    })

    local tween = currentTween
    tween:Play()

    task.spawn(function()
        tween.Completed:Wait()
        if not UI.Destroyed and not UI.Open and currentTween == tween then
            Body.Visible = false
        end
    end)
end

track(OpenButton.MouseButton1Click:Connect(function()
    UI:SetOpen(not UI.Open)
end))

track(OpenButton.MouseEnter:Connect(function()
    TweenService:Create(OpenButton, TweenInfo.new(0.08), {
        BackgroundColor3 = Colors.ControlHover
    }):Play()
end))

track(OpenButton.MouseLeave:Connect(function()
    TweenService:Create(OpenButton, TweenInfo.new(0.08), {
        BackgroundColor3 = Colors.Control
    }):Play()
end))

local dragging = false
local dragInput = nil
local dragStart = nil
local startPosition = nil

track(Header.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local point = input.Position
    local buttonPosition = OpenButton.AbsolutePosition
    local buttonSize = OpenButton.AbsoluteSize

    if point.X >= buttonPosition.X and point.X <= buttonPosition.X + buttonSize.X and point.Y >= buttonPosition.Y and point.Y <= buttonPosition.Y + buttonSize.Y then
        return
    end

    dragging = true
    dragStart = input.Position
    startPosition = Root.Position

    local changed
    changed = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
            if changed then
                changed:Disconnect()
                changed = nil
            end
        end
    end)
end))

track(Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not dragging or input ~= dragInput then return end
    local delta = input.Position - dragStart
    Root.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end))

function UI:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    if currentTween then
        pcall(currentTween.Cancel, currentTween)
        currentTween = nil
    end

    disconnectAll(self.Connections)
    self.Controls = {}

    if Gui then
        pcall(Gui.Destroy, Gui)
    end

    if env.__DEPHUB_TSB_FRONTEND == self then
        env.__DEPHUB_TSB_FRONTEND = nil
    end

    if env.__DEPHUB and env.__DEPHUB.TSBUI == self then
        env.__DEPHUB.TSBUI = nil
    end
end

env.__DEPHUB_TSB_FRONTEND = UI
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.TSBUI = UI

return UI
