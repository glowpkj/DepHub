local Controller = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

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
    if not toggle then
        return
    end

    if toggle:FindFirstChild("DepHubToggleInput") then
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

    local dragging = false
    local pressed = false
    local dragStart = nil
    local startPosition = nil
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
        dragging = false

        if not moved and not debounce and window and not window.Destroyed then
            debounce = true
            window:SetOpen(not window.IsHidden)
            task.delay(0.28, function()
                debounce = false
            end)
        end
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

    input.MouseEnter:Connect(function()
        input.BackgroundTransparency = 1
    end)

    clampToggle(toggle)

    local viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
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

        local viewport = camera.ViewportSize
        local width = viewport.X
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

        if not window.IsHidden then
            main.Size = UDim2.new(widthScale, 0, heightScale, 0)
        else
            main.Size = UDim2.new(widthScale, 0, heightScale, 0)
        end
    end

    update()

    local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
    window.__DEPHUBResponsiveConnection = connection
end

local function enhanceDashboard(window)
    if window.__DEPHUBDashboardEnhanced or not window.DashboardStats then
        return
    end

    window.__DEPHUBDashboardEnhanced = true

    local stats = window.DashboardStats
    if stats.Status then
        stats.Status:SetTitle("VERSÃO")
    end

    if stats.Version then
        stats.Version:SetTitle("FPS")
        local card = stats.Version.Card
        for _, child in card:GetChildren() do
            if child:IsA("TextLabel") and child ~= nil then
                if child.Text == "--" then
                    child.TextColor3 = Color3.fromRGB(80, 200, 120)
                    window.__DEPHUBFPSLabel = child
                    break
                end
            end
        end
    end

    if stats.Ping then
        local card = stats.Ping.Card
        for _, child in card:GetChildren() do
            if child:IsA("TextLabel") and child.Text == "--" then
                window.__DEPHUBPingLabel = child
                break
            end
        end
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

        task.spawn(function()
            local ok, image = pcall(function()
                local content = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                return content
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

    enhanceResponsive(window)
    enhanceToggle(window)
    enhanceDashboard(window)

    return window
end

return Controller
