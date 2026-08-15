local Controller = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local function clampToggle(toggle)
    local parent = toggle.Parent
    if not parent or not parent:IsA("GuiObject") then
        return
    end

    local parentSize = parent.AbsoluteSize
    local size = toggle.AbsoluteSize
    local margin = 10
    local x = toggle.AbsolutePosition.X - parent.AbsolutePosition.X
    local y = toggle.AbsolutePosition.Y - parent.AbsolutePosition.Y

    x = math.clamp(x, margin, math.max(margin, parentSize.X - size.X - margin))
    y = math.clamp(y, margin, math.max(margin, parentSize.Y - size.Y - margin))

    toggle.Position = UDim2.fromOffset(x, y)
end

local function createToggleController(window)
    if window.__DEPHUBToggleController then
        return
    end

    local original = window.ScreenGui and window.ScreenGui:FindFirstChild("DepHubToggle", true)
    if not original or not original:IsA("GuiObject") then
        return
    end

    original.Visible = false

    local toggle = Instance.new("TextButton")
    toggle.Name = "DepHubToggleControl"
    toggle.Size = UDim2.fromOffset(50, 50)
    toggle.Position = UDim2.fromOffset(18, 68)
    toggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Text = ""
    toggle.ZIndex = 2000
    toggle.Active = true
    toggle.Parent = window.ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = toggle

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(35, 35, 35)
    stroke.Transparency = 0.15
    stroke.Parent = toggle

    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.fromOffset(26, 26)
    logo.Position = UDim2.fromScale(0.5, 0.5)
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.BackgroundTransparency = 1
    logo.Image = window.LogoId
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Parent = toggle

    local pressed = false
    local dragging = false
    local moved = false
    local dragStart
    local startPosition
    local debounce = false

    local function setPosition(inputPosition)
        if not dragStart or not startPosition then
            return
        end

        local parent = toggle.Parent
        if not parent or not parent:IsA("GuiObject") then
            return
        end

        local delta = inputPosition - dragStart
        local size = toggle.AbsoluteSize
        local parentSize = parent.AbsoluteSize
        local x = startPosition.X.Offset + delta.X
        local y = startPosition.Y.Offset + delta.Y

        x = math.clamp(x, 10, math.max(10, parentSize.X - size.X - 10))
        y = math.clamp(y, 10, math.max(10, parentSize.Y - size.Y - 10))

        toggle.Position = UDim2.fromOffset(x, y)
    end

    toggle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        pressed = true
        dragging = false
        moved = false
        dragStart = input.Position
        startPosition = UDim2.fromOffset(toggle.Position.X.Offset, toggle.Position.Y.Offset)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not pressed then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        if not dragging and delta.Magnitude >= 6 then
            dragging = true
            moved = true
        end

        if dragging then
            setPosition(input.Position)
        end
    end)

    toggle.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if not pressed then
            return
        end

        pressed = false
        dragging = false

        if not moved and not debounce and not window.Destroyed then
            debounce = true
            window:SetOpen(not window.IsHidden)
            task.delay(0.35, function()
                debounce = false
            end)
        end
    end)

    toggle.MouseEnter:Connect(function()
        if not pressed then
            toggle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        end
    end)

    toggle.MouseLeave:Connect(function()
        if not pressed then
            toggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        end
    end)

    toggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            toggle.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
        end
    end)

    toggle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            toggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        end
    end)

    clampToggle(toggle)

    local camera = workspace.CurrentCamera
    local viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        clampToggle(toggle)
    end)

    toggle.AncestryChanged:Connect(function(_, parent)
        if not parent and viewportConnection then
            viewportConnection:Disconnect()
        end
    end)

    window.ToggleButton = toggle
    window.__DEPHUBToggleController = true
    window.__DEPHUBToggleConnection = viewportConnection
end

local function enhanceResponsive(window)
    local main = window.Window
    if not main then
        return
    end

    for _, child in main:GetChildren() do
        if child:IsA("UISizeConstraint") then
            child.MinSize = Vector2.new(320, 240)
            child.MaxSize = Vector2.new(1400, 900)
        end
    end

    local camera = workspace.CurrentCamera
    local function update()
        if not main.Parent then
            return
        end

        local width = camera.ViewportSize.X
        local widthScale
        local heightScale

        if width <= 600 then
            widthScale = 0.88
            heightScale = 0.62
        elseif width <= 1000 then
            widthScale = 0.78
            heightScale = 0.66
        else
            widthScale = 0.62
            heightScale = 0.68
        end

        main.Size = UDim2.new(widthScale, 0, heightScale, 0)
    end

    update()

    if window.__DEPHUBResponsiveConnection then
        window.__DEPHUBResponsiveConnection:Disconnect()
    end

    window.__DEPHUBResponsiveConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
end

local function findStatLabels(stat)
    local titleLabel
    local valueLabel
    if not stat or not stat.Card then
        return nil, nil
    end

    for _, child in stat.Card:GetChildren() do
        if child:IsA("TextLabel") then
            if not titleLabel then
                titleLabel = child
            else
                valueLabel = child
                break
            end
        end
    end

    return titleLabel, valueLabel
end

local function addStatHelpers(stat)
    if not stat or stat.__DEPHUBEnhanced then
        return
    end

    local titleLabel, valueLabel = findStatLabels(stat)
    stat.__DEPHUBEnhanced = true
    stat.__DEPHUBTitleLabel = titleLabel
    stat.__DEPHUBValueLabel = valueLabel

    function stat:SetColor(color)
        if self.__DEPHUBValueLabel and color then
            self.__DEPHUBValueLabel.TextColor3 = color
        end
    end

    function stat:SetTitle(newTitle)
        if self.__DEPHUBTitleLabel then
            self.__DEPHUBTitleLabel.Text = tostring(newTitle or "")
        end
    end
end

local function enhanceDashboard(window)
    if window.__DEPHUBDashboardEnhanced or not window.DashboardStats then
        return
    end

    window.__DEPHUBDashboardEnhanced = true

    local stats = window.DashboardStats
    addStatHelpers(stats.Player)
    addStatHelpers(stats.Status)
    addStatHelpers(stats.Version)
    addStatHelpers(stats.Ping)

    if stats.Status then
        stats.Status:SetTitle("VERSÃO")
    end

    if stats.Version then
        stats.Version:SetTitle("FPS")
    end

    local playerCard = stats.Player and stats.Player.Card
    if playerCard and not playerCard:FindFirstChild("DepHubAvatar") then
        local avatar = Instance.new("ImageLabel")
        avatar.Name = "DepHubAvatar"
        avatar.Size = UDim2.fromOffset(42, 42)
        avatar.Position = UDim2.new(1, -50, 0.5, 0)
        avatar.AnchorPoint = Vector2.new(0, 0.5)
        avatar.BackgroundTransparency = 1
        avatar.ScaleType = Enum.ScaleType.Fit
        avatar.Parent = playerCard

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = avatar

        if stats.Player.__DEPHUBValueLabel then
            stats.Player.__DEPHUBValueLabel.Size = UDim2.new(1, -65, 0, 28)
        end

        task.spawn(function()
            local ok, image = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and image and avatar.Parent then
                avatar.Image = image
            end
        end)
    end
end

function Controller.Enhance(window)
    if not window or window.Destroyed then
        return window
    end

    if not window.__DEPHUBOriginalSetOpen then
        window.__DEPHUBOriginalSetOpen = window.SetOpen
        window.__DEPHUBTransitioning = false
        window.SetOpen = function(self, shouldOpen)
            if self.Destroyed or self.__DEPHUBTransitioning or not self.Window then
                return
            end

            local targetOpen = shouldOpen == true
            if self.IsHidden == targetOpen then
                return
            end

            self.__DEPHUBTransitioning = true
            self.__DEPHUBOriginalSetOpen(self, targetOpen)

            task.delay(targetOpen and 0.38 or 0.28, function()
                if not self.Destroyed then
                    self.__DEPHUBTransitioning = false
                end
            end)
        end
    end

    createToggleController(window)
    enhanceResponsive(window)
    enhanceDashboard(window)

    return window
end

return Controller
