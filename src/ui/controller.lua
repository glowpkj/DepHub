local Controller = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local function findToggle(window)
    if window.ToggleButton and window.ToggleButton:IsA("GuiObject") then
        return window.ToggleButton
    end

    if window.ScreenGui then
        local found = window.ScreenGui:FindFirstChild("ToggleButton", true)
        if found and found:IsA("GuiObject") then
            return found
        end
    end

    return nil
end

local function clampToggle(toggle)
    local parent = toggle.Parent
    if not parent or not parent:IsA("GuiObject") then
        return
    end

    local parentSize = parent.AbsoluteSize
    local size = toggle.AbsoluteSize
    local margin = 8
    local x = toggle.AbsolutePosition.X - parent.AbsolutePosition.X
    local y = toggle.AbsolutePosition.Y - parent.AbsolutePosition.Y

    x = math.clamp(x, margin, math.max(margin, parentSize.X - size.X - margin))
    y = math.clamp(y, margin, math.max(margin, parentSize.Y - size.Y - margin))

    toggle.Position = UDim2.fromOffset(x, y)
end

local function enhanceToggle(window)
    local toggle = findToggle(window)
    if not toggle or toggle:FindFirstChild("DepHubToggleInput") then
        return
    end

    toggle.Active = true

    local input = Instance.new("TextButton")
    input.Name = "DepHubToggleInput"
    input.Size = UDim2.fromScale(1, 1)
    input.Position = UDim2.fromScale(0, 0)
    input.BackgroundTransparency = 1
    input.BorderSizePixel = 0
    input.Text = ""
    input.AutoButtonColor = false
    input.ZIndex = math.max(toggle.ZIndex + 10, 10000)
    input.Parent = toggle

    local pressed = false
    local dragging = false
    local dragStart
    local startPosition
    local moved = false
    local debounce = false

    local function setPosition(inputPosition)
        if not dragStart or not startPosition then
            return
        end

        local delta = inputPosition - dragStart
        local parent = toggle.Parent
        if not parent or not parent:IsA("GuiObject") then
            return
        end

        local parentSize = parent.AbsoluteSize
        local size = toggle.AbsoluteSize
        local x = startPosition.X.Offset + delta.X
        local y = startPosition.Y.Offset + delta.Y

        x = math.clamp(x, 8, math.max(8, parentSize.X - size.X - 8))
        y = math.clamp(y, 8, math.max(8, parentSize.Y - size.Y - 8))

        toggle.Position = UDim2.fromOffset(x, y)
    end

    input.InputBegan:Connect(function(io)
        if io.UserInputType ~= Enum.UserInputType.MouseButton1 and io.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        pressed = true
        dragging = false
        moved = false
        dragStart = io.Position

        local parent = toggle.Parent
        if parent and parent:IsA("GuiObject") then
            startPosition = UDim2.fromOffset(
                toggle.AbsolutePosition.X - parent.AbsolutePosition.X,
                toggle.AbsolutePosition.Y - parent.AbsolutePosition.Y
            )
            toggle.Position = startPosition
        end
    end)

    input.InputEnded:Connect(function(io)
        if io.UserInputType ~= Enum.UserInputType.MouseButton1 and io.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if not pressed then
            return
        end

        pressed = false

        if not moved and not debounce and window and not window.Destroyed then
            debounce = true
            window:SetOpen(not window.IsHidden)
            task.delay(0.32, function()
                debounce = false
            end)
        end

        dragging = false
    end)

    UserInputService.InputChanged:Connect(function(io)
        if not pressed then
            return
        end

        if io.UserInputType ~= Enum.UserInputType.MouseMovement and io.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = io.Position - dragStart
        if not dragging and delta.Magnitude >= 6 then
            dragging = true
            moved = true
        end

        if dragging then
            setPosition(io.Position)
        end
    end)

    clampToggle(toggle)

    local camera = workspace.CurrentCamera
    local viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        clampToggle(toggle)
    end)

    input.AncestryChanged:Connect(function(_, parent)
        if not parent then
            viewportConnection:Disconnect()
        end
    end)
end

local function enhanceResponsive(window)
    local main = window.Window
    if not main then
        return
    end

    for _, child in main:GetChildren() do
        if child:IsA("UISizeConstraint") then
            child.MinSize = Vector2.new(320, 240)
            child.MaxSize = Vector2.new(1500, 1000)
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
            widthScale = 0.94
            heightScale = 0.76
        elseif width <= 1000 then
            widthScale = 0.86
            heightScale = 0.76
        else
            widthScale = 0.72
            heightScale = 0.74
        end

        main.Size = UDim2.new(widthScale, 0, heightScale, 0)
    end

    update()
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

    if not window.__DEPHUBOriginalSetReleases and type(window.SetReleases) == "function" then
        window.__DEPHUBOriginalSetReleases = window.SetReleases
        window.SetReleases = function(self, changelog)
            self.__DEPHUBOriginalSetReleases(self, changelog)

            local latestVersion = changelog and changelog[1] and changelog[1].Version
            if self.DashboardStats and self.DashboardStats.Status and latestVersion then
                self.DashboardStats.Status:SetValue(latestVersion)
            end

            if self.DashboardStats and self.DashboardStats.Version and self.__DEPHUBLastFPS ~= nil then
                self.DashboardStats.Version:SetValue(tostring(self.__DEPHUBLastFPS))
            end
        end
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
            if self.Destroyed or self.__DEPHUBTransitioning then
                return
            end

            local targetOpen = shouldOpen == true
            if self.IsHidden == not targetOpen then
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

    if not window.__DEPHUBOriginalCreateTab and type(window.CreateTab) == "function" then
        window.__DEPHUBOriginalCreateTab = window.CreateTab
        window.CreateTab = function(self, ...)
            local tab = self.__DEPHUBOriginalCreateTab(self, ...)
            task.defer(function()
                enhanceDashboard(self)
            end)
            return tab
        end
    end

    if not window.__DEPHUBOriginalCreateDashboard and type(window.CreateDashboard) == "function" then
        window.__DEPHUBOriginalCreateDashboard = window.CreateDashboard
        window.CreateDashboard = function(self, ...)
            local tab = self.__DEPHUBOriginalCreateDashboard(self, ...)
            enhanceDashboard(self)
            return tab
        end
    end

    enhanceResponsive(window)
    enhanceToggle(window)
    enhanceDashboard(window)

    return window
end

return Controller
