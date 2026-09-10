local game = game
local task = task
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local math_floor = math.floor
local math_clamp = math.clamp

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return false end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local env = type(getgenv) == "function" and getgenv() or _G
local Backend = env.__DEPHUB and env.__DEPHUB.TSB or nil
if type(Backend) ~= "table" then return false end

local Previous = env.__DEPHUB_TSB_FRONTEND
if type(Previous) == "table" and type(Previous.Destroy) == "function" then
    pcall(Previous.Destroy, Previous)
end

local function getUiParent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end
    return PlayerGui
end

local UiParent = getUiParent()
for _, parent in ipairs({PlayerGui, UiParent}) do
    if parent then
        local oldGui = parent:FindFirstChild("dephubTSB")
        if oldGui then pcall(oldGui.Destroy, oldGui) end
    end
end

local UI = {
    Destroyed = false,
    Open = false,
    Connections = {},
    Controls = {}
}

local Colors = {
    Header = Color3.fromRGB(18, 20, 22),
    Body = Color3.fromRGB(14, 16, 18),
    Control = Color3.fromRGB(26, 29, 31),
    ControlHover = Color3.fromRGB(32, 36, 39),
    Sub = Color3.fromRGB(22, 25, 27),
    Border = Color3.fromRGB(47, 52, 55),
    Text = Color3.fromRGB(255, 255, 255),
    Accent = Color3.fromRGB(114, 236, 190),
    Off = Color3.fromRGB(58, 63, 66),
    Track = Color3.fromRGB(46, 51, 54)
}

local Width = 264
local HeaderHeight = 38
local BodyHeight = 486
local RowHeight = 35

local function track(connection)
    if connection then
        UI.Connections[#UI.Connections + 1] = connection
    end
    return connection
end

local function disconnectAll(list)
    if not list then return end
    for index = #list, 1, -1 do
        local connection = list[index]
        list[index] = nil
        if connection then pcall(connection.Disconnect, connection) end
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

local function safeBackendCall(callback, ...)
    if type(callback) ~= "function" then return true end
    local ok, result = pcall(callback, ...)
    return ok and result ~= false
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "dephubTSB"
Gui.Enabled = true
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 2147483647
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
Gui.IgnoreGuiInset = false
pcall(function() Gui.OnTopOfCoreBlur = true end)
Gui.Parent = UiParent

track(Gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if not UI.Destroyed and not Gui.Enabled then Gui.Enabled = true end
end))

track(Gui:GetPropertyChangedSignal("DisplayOrder"):Connect(function()
    if not UI.Destroyed and Gui.DisplayOrder ~= 2147483647 then
        Gui.DisplayOrder = 2147483647
    end
end))

local Root = Instance.new("Frame")
Root.Name = "Root"
Root.Size = UDim2.fromOffset(Width, HeaderHeight)
Root.Position = UDim2.new(0.5, -Width / 2, 0.24, 0)
Root.BackgroundTransparency = 1
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
Accent.Size = UDim2.fromOffset(3, 20)
Accent.Position = UDim2.new(0, 8, 0.5, -10)
Accent.BackgroundColor3 = Colors.Accent
Accent.BorderSizePixel = 0
Accent.Parent = Header
corner(Accent, 2)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -91, 1, 0)
Title.Position = UDim2.fromOffset(19, 0)
Title.BackgroundTransparency = 1
Title.Text = "DEPHUB TSB"
Title.TextColor3 = Colors.Text
Title.TextSize = 14
Title.Font = Enum.Font.GothamMedium
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(64, 25)
OpenButton.Position = UDim2.new(1, -70, 0.5, -12)
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
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.CanvasSize = UDim2.fromOffset(0, 0)
Content.Parent = Body

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Content

local function addSection(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = string.upper(text)
    label.TextColor3 = Colors.Text
    label.TextTransparency = 0.18
    label.TextSize = 11
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = Content
    return label
end

local function makeToggle(parent, text, default, callback, sub)
    local state = default == true

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, RowHeight)
    row.BackgroundColor3 = sub and Colors.Sub or Colors.Control
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.Parent = parent
    corner(row, 5)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -55, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
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
        local targetColor = state and Colors.Accent or Colors.Off
        local targetPosition = state and UDim2.new(1, -15, 0, 3) or UDim2.fromOffset(3, 3)

        if instant then
            switch.BackgroundColor3 = targetColor
            dot.Position = targetPosition
            return
        end

        TweenService:Create(switch, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            BackgroundColor3 = targetColor
        }):Play()
        TweenService:Create(dot, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = targetPosition
        }):Play()
    end

    local control = {}

    function control:Set(value, fire)
        local wanted = value == true
        if wanted == state then return true end

        local previous = state
        state = wanted

        if fire ~= false and not safeBackendCall(callback, state) then
            state = previous
            render(false)
            return false
        end

        render(false)
        if type(self.OnChanged) == "function" then
            self.OnChanged(state)
        end
        return true
    end

    function control:Get()
        return state
    end

    track(row.MouseButton1Click:Connect(function()
        control:Set(not state, true)
    end))

    track(row.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.08), {
            BackgroundColor3 = sub and Colors.Control or Colors.ControlHover
        }):Play()
    end))

    track(row.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.08), {
            BackgroundColor3 = sub and Colors.Sub or Colors.Control
        }):Play()
    end))

    render(true)
    UI.Controls[text] = control
    return control, row
end

local function roundStep(value, step)
    return math_floor(value / step + 0.5) * step
end

local function addSlider(parent, text, minimum, maximum, step, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = Colors.Sub
    row.BorderSizePixel = 0
    row.Parent = parent
    corner(row, 5)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -62, 0, 22)
    label.Position = UDim2.fromOffset(10, 3)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.Text
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.fromOffset(48, 22)
    valueLabel.Position = UDim2.new(1, -56, 0, 3)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Colors.Text
    valueLabel.TextSize = 11
    valueLabel.Font = Enum.Font.GothamMedium
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = row

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.Position = UDim2.fromOffset(10, 35)
    bar.BackgroundColor3 = Colors.Track
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.Parent = row
    corner(bar, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Colors.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 3)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12, 12)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Colors.Text
    knob.BorderSizePixel = 0
    knob.Parent = bar
    corner(knob, 6)

    local value = math_clamp(tonumber(default) or minimum, minimum, maximum)
    local dragging = false

    local function formatValue(current)
        if step < 1 then
            return string.format("%.1f", current)
        end
        return tostring(math_floor(current + 0.5))
    end

    local function render()
        local alpha = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = formatValue(value)
    end

    local function setValue(newValue, fire)
        newValue = tonumber(newValue)
        if not newValue then return false end

        local previous = value
        value = math_clamp(roundStep(newValue, step), minimum, maximum)

        if fire ~= false and not safeBackendCall(callback, value) then
            value = previous
            render()
            return false
        end

        render()
        return true
    end

    local function setFromX(x)
        local width = bar.AbsoluteSize.X
        if width <= 0 then return end
        local alpha = math_clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
        setValue(minimum + (maximum - minimum) * alpha, true)
    end

    track(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            setFromX(input.Position.X)
        end
    end))

    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    local control = {}
    function control:Set(newValue, fire)
        return setValue(newValue, fire)
    end
    function control:Get()
        return value
    end

    render()
    UI.Controls[text] = control
    return control, row
end

local function addFeature(text, default, callback)
    local group = Instance.new("Frame")
    group.Size = UDim2.new(1, 0, 0, 0)
    group.AutomaticSize = Enum.AutomaticSize.Y
    group.BackgroundTransparency = 1
    group.Parent = Content

    local groupLayout = Instance.new("UIListLayout")
    groupLayout.Padding = UDim.new(0, 5)
    groupLayout.SortOrder = Enum.SortOrder.LayoutOrder
    groupLayout.Parent = group

    local control = makeToggle(group, text, default, callback, false)

    local settings = Instance.new("Frame")
    settings.Size = UDim2.new(1, 0, 0, 0)
    settings.BackgroundTransparency = 1
    settings.ClipsDescendants = true
    settings.Parent = group

    local inner = Instance.new("Frame")
    inner.Size = UDim2.new(1, -8, 0, 0)
    inner.Position = UDim2.fromOffset(8, 0)
    inner.AutomaticSize = Enum.AutomaticSize.Y
    inner.BackgroundTransparency = 1
    inner.Parent = settings

    local innerLayout = Instance.new("UIListLayout")
    innerLayout.Padding = UDim.new(0, 5)
    innerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    innerLayout.Parent = inner

    local currentTween = nil

    local function targetHeight()
        return innerLayout.AbsoluteContentSize.Y
    end

    local function animate(open, instant)
        if currentTween then
            pcall(currentTween.Cancel, currentTween)
            currentTween = nil
        end

        local target = open and targetHeight() or 0
        if instant then
            settings.Size = UDim2.new(1, 0, 0, target)
            return
        end

        currentTween = TweenService:Create(
            settings,
            TweenInfo.new(0.18, Enum.EasingStyle.Quart, open and Enum.EasingDirection.Out or Enum.EasingDirection.In),
            {Size = UDim2.new(1, 0, 0, target)}
        )
        currentTween:Play()
    end

    control.OnChanged = function(open)
        task.defer(function()
            if not UI.Destroyed then animate(open, false) end
        end)
    end

    track(innerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if control:Get() then
            settings.Size = UDim2.new(1, 0, 0, targetHeight())
        end
    end))

    task.defer(function()
        if not UI.Destroyed then animate(control:Get(), true) end
    end)

    return control, inner
end

local function addAction(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, RowHeight)
    button.BackgroundColor3 = Colors.Control
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = text
    button.TextColor3 = Colors.Text
    button.TextSize = 11
    button.Font = Enum.Font.GothamMedium
    button.Parent = parent
    corner(button, 5)

    track(button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.08), {BackgroundColor3 = Colors.ControlHover}):Play()
    end))

    track(button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.08), {BackgroundColor3 = Colors.Control}):Play()
    end))

    track(button.MouseButton1Click:Connect(function()
        safeBackendCall(callback)
    end))

    return button
end

local function addStatusCard(parent)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 164)
    card.BackgroundColor3 = Colors.Sub
    card.BorderSizePixel = 0
    card.Parent = parent
    corner(card, 5)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 22)
    title.Position = UDim2.fromOffset(10, 5)
    title.BackgroundTransparency = 1
    title.Text = "LIVE STATUS"
    title.TextColor3 = Colors.Text
    title.TextSize = 11
    title.Font = Enum.Font.GothamMedium
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -20, 1, -32)
    body.Position = UDim2.fromOffset(10, 27)
    body.BackgroundTransparency = 1
    body.Text = "runtime: idle"
    body.TextColor3 = Colors.Text
    body.TextTransparency = 0.08
    body.TextSize = 10
    body.Font = Enum.Font.Code
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextWrapped = true
    body.Parent = card

    return body
end

addSection("Combat")

local autoBlock, autoBlockSettings = addFeature("Auto Block", Backend:GetToggle("AutoBlock"), function(value)
    return Backend:SetAutoBlock(value)
end)

makeToggle(autoBlockSettings, "M1 After Block", Backend:GetToggle("M1AfterBlock"), function(value)
    return Backend:SetM1AfterBlock(value)
end, true)

makeToggle(autoBlockSettings, "M1 Catch", Backend:GetToggle("M1Catch"), function(value)
    return Backend:SetM1Catch(value)
end, true)

makeToggle(autoBlockSettings, "Show Hitbox", Backend:GetToggle("ShowDetectionBox"), function(value)
    return Backend:SetShowDetectionBox(value)
end, true)

addSlider(autoBlockSettings, "Hitbox Size", 2, 40, 1, Backend:GetValue("DetectionBoxSize") or 12, function(value)
    return Backend:SetDetectionBoxSize(value)
end)

addSlider(autoBlockSettings, "M1 Range", 2, 30, 1, Backend:GetValue("NormalRange") or 12, function(value)
    return Backend:SetNormalRange(value)
end)

addSlider(autoBlockSettings, "Scan Hz", 10, 60, 5, Backend:GetValue("ScanHz") or 30, function(value)
    return Backend:SetScanHz(value)
end)

local dashBlock, dashSettings = addFeature("Dash Block", Backend:GetToggle("DashBlock"), function(value)
    return Backend:SetDashBlock(value)
end)

addSlider(dashSettings, "Dash Range", 5, 80, 1, Backend:GetValue("SpecialRange") or 50, function(value)
    return Backend:SetSpecialRange(value)
end)

local skillBlock, skillSettings = addFeature("Skill Block", Backend:GetToggle("SkillBlock"), function(value)
    return Backend:SetSkillBlock(value)
end)

addSlider(skillSettings, "Skill Range", 5, 80, 1, Backend:GetValue("SkillRange") or 50, function(value)
    return Backend:SetSkillRange(value)
end)

addSlider(skillSettings, "Skill Hold", 0.1, 2, 0.1, Backend:GetValue("SkillHold") or 1.2, function(value)
    return Backend:SetSkillHold(value)
end)

addSection("Diagnostics")

local debugFeature, debugSettings = addFeature("Debug", Backend:GetToggle("Debug"), function(value)
    return Backend:SetDebug(value)
end)

local DebugText = addStatusCard(debugSettings)
addAction(debugSettings, "RESET COMBAT STATE", function()
    return Backend:ResetCombatState()
end)

local debugElapsed = 0
track(RunService.Heartbeat:Connect(function(dt)
    if UI.Destroyed or not debugFeature:Get() then return end

    debugElapsed = debugElapsed + dt
    if debugElapsed < 0.25 then return end
    debugElapsed = 0

    local info = Backend:GetDebugInfo()
    if type(info) ~= "table" then
        DebugText.Text = "backend unavailable"
        return
    end

    DebugText.Text = table.concat({
        "runtime: " .. tostring(info.Runtime),
        "character: " .. tostring(info.Character) .. " | remote: " .. tostring(info.Remote),
        "live: " .. tostring(info.Live) .. " | tracked: " .. tostring(info.TrackedPlayers),
        "block: " .. tostring(info.BlockActive) .. " | source: " .. tostring(info.BlockSource),
        "blocks: " .. tostring(info.Blocks) .. " | releases: " .. tostring(info.Releases),
        "animations: " .. tostring(info.AnimationEvents) .. " | m1 events: " .. tostring(info.M1Events),
        "scan: " .. tostring(info.ScanHz) .. "hz | skill ids: " .. tostring(info.KnownSkillAnimations),
        "last: " .. tostring(info.LastReason) .. " | player: " .. tostring(info.LastPlayer),
        "id: " .. tostring(info.LastAnimation) .. " | dist: " .. string.format("%.1f", tonumber(info.LastDistance) or 0),
        "error: " .. tostring(info.LastError)
    }, "\n")
end))

local currentTween = nil

function UI:SetOpen(state)
    if self.Destroyed then return false end
    state = state == true
    if self.Open == state then return true end

    self.Open = state
    if currentTween then
        pcall(currentTween.Cancel, currentTween)
        currentTween = nil
    end

    if state then
        Body.Visible = true
        OpenButton.Text = "CLOSE"
        currentTween = TweenService:Create(
            Body,
            TweenInfo.new(0.17, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Size = UDim2.new(1, 0, 0, BodyHeight)}
        )
        currentTween:Play()
    else
        OpenButton.Text = "OPEN"
        local tween = TweenService:Create(
            Body,
            TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Size = UDim2.new(1, 0, 0, 0)}
        )
        currentTween = tween
        tween:Play()
        task.spawn(function()
            tween.Completed:Wait()
            if not UI.Destroyed and not UI.Open and currentTween == tween then
                Body.Visible = false
            end
        end)
    end

    return true
end

track(OpenButton.MouseButton1Click:Connect(function()
    UI:SetOpen(not UI.Open)
end))

local dragging = false
local dragInput = nil
local dragStart = nil
local startAbsolute = nil

local function clampPosition(x, y)
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local visibleX = 72
    local visibleY = HeaderHeight

    local minX = -Width + visibleX
    local maxX = viewport.X - visibleX
    local minY = 0
    local maxY = viewport.Y - visibleY

    return math_clamp(x, minX, maxX), math_clamp(y, minY, maxY)
end

track(Header.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local point = input.Position
    local buttonPosition = OpenButton.AbsolutePosition
    local buttonSize = OpenButton.AbsoluteSize
    if point.X >= buttonPosition.X and point.X <= buttonPosition.X + buttonSize.X
        and point.Y >= buttonPosition.Y and point.Y <= buttonPosition.Y + buttonSize.Y then
        return
    end

    dragging = true
    dragStart = input.Position
    startAbsolute = Root.AbsolutePosition

    local changed
    changed = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
            if changed then changed:Disconnect() end
        end
    end)
end))

track(Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not dragging or input ~= dragInput or not dragStart or not startAbsolute then return end

    local delta = input.Position - dragStart
    local x, y = clampPosition(startAbsolute.X + delta.X, startAbsolute.Y + delta.Y)
    Root.Position = UDim2.fromOffset(x, y)
end))

function UI:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    if currentTween then pcall(currentTween.Cancel, currentTween) end
    disconnectAll(self.Connections)
    self.Controls = {}

    if Gui then pcall(Gui.Destroy, Gui) end

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
