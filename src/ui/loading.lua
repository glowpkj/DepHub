local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Loading = {}
Loading.__index = Loading

local function tween(instance, duration, style, direction, properties, repeatCount, reverses)
    local info = TweenInfo.new(duration, style, direction, repeatCount or 0, reverses == true)
    local animation = TweenService:Create(instance, info, properties)
    animation:Play()
    return animation
end

function Loading.new(options)
    options = options or {}

    local self = setmetatable({}, Loading)
    self.Destroyed = false
    self.Completed = false
    self.CurrentProgress = 0
    self.Gui = nil
    self.ProgressFill = nil
    self.StatusLabel = nil
    self.TitleLabel = nil
    self.Logo = nil

    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return self
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = options.Name or "DepHubCinematicLoading"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = options.DisplayOrder or 10000
    screenGui.Parent = playerGui
    self.Gui = screenGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    self.MainFrame = mainFrame

    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = options.AspectRatio or 1.45
    aspect.AspectType = Enum.AspectType.ScaleWithParentSize
    aspect.DominantAxis = Enum.DominantAxis.Width
    aspect.Parent = mainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = mainFrame

    local logo = Instance.new("ImageLabel")
    logo.Name = "Logo"
    logo.Size = UDim2.fromOffset(options.LogoSize or 110, options.LogoSize or 110)
    logo.Position = UDim2.new(0.5, 0, 0.42, 0)
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.BackgroundTransparency = 1
    logo.Image = options.LogoId or "rbxassetid://79507712997362"
    logo.ScaleType = Enum.ScaleType.Fit
    logo.ImageTransparency = 0
    logo.Parent = mainFrame
    self.Logo = logo

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 24)
    title.Position = UDim2.new(0.5, 0, 0.66, 0)
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.BackgroundTransparency = 1
    title.Text = options.Title or "DEPHUB"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = mainFrame
    self.TitleLabel = title

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -40, 0, 22)
    status.Position = UDim2.new(0.5, 0, 0.75, 0)
    status.AnchorPoint = Vector2.new(0.5, 0.5)
    status.BackgroundTransparency = 1
    status.Text = options.Status or "Inicializando..."
    status.TextColor3 = Color3.fromRGB(150, 150, 150)
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextWrapped = true
    status.Parent = mainFrame
    self.StatusLabel = status

    local progressContainer = Instance.new("Frame")
    progressContainer.Name = "ProgressContainer"
    progressContainer.Size = UDim2.new(1, 0, 0, 7)
    progressContainer.Position = UDim2.new(0, 0, 1, -7)
    progressContainer.BackgroundTransparency = 1
    progressContainer.BorderSizePixel = 0
    progressContainer.ClipsDescendants = true
    progressContainer.Parent = mainFrame

    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 20)
    progressCorner.Parent = progressContainer

    local fill = Instance.new("Frame")
    fill.Name = "ProgressFill"
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    fill.BorderSizePixel = 0
    fill.Parent = progressContainer
    self.ProgressFill = fill

    tween(mainFrame, options.OpenDuration or 0.45, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, {
        Size = UDim2.new(options.Width or 0.38, 0, options.Height or 0.42, 0)
    })

    self.FloatTween = tween(logo, 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, {
        Position = UDim2.new(0.5, 0, 0.38, 0)
    }, -1, true)

    self.RotateTween = tween(logo, 2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, {
        Rotation = 12
    }, -1, true)

    return self
end

function Loading:SetProgress(progress, status)
    if self.Destroyed then
        return
    end

    self.CurrentProgress = math.clamp(tonumber(progress) or 0, 0, 1)

    if self.StatusLabel and status then
        self.StatusLabel.Text = tostring(status)
    end

    if self.ProgressFill then
        tween(self.ProgressFill, 0.18, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, {
            Size = UDim2.new(self.CurrentProgress, 0, 1, 0)
        })
    end
end

function Loading:SetStatus(status)
    if self.Destroyed or not self.StatusLabel then
        return
    end
    self.StatusLabel.Text = tostring(status or "")
end

function Loading:Complete(status)
    if self.Destroyed or self.Completed then
        return
    end

    self.Completed = true
    self:SetProgress(1, status or "Concluído")

    if self.FloatTween then
        self.FloatTween:Cancel()
    end

    if self.RotateTween then
        self.RotateTween:Cancel()
    end

    task.wait(0.18)

    tween(self.Logo, 0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, {
        ImageTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        Rotation = 0
    })

    if self.StatusLabel then
        tween(self.StatusLabel, 0.16, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, {
            TextTransparency = 1
        })
    end

    if self.TitleLabel then
        tween(self.TitleLabel, 0.16, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, {
            TextTransparency = 1
        })
    end

    if self.ProgressFill then
        tween(self.ProgressFill, 0.16, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, {
            BackgroundTransparency = 1
        })
    end

    local collapse = tween(self.MainFrame, 0.36, Enum.EasingStyle.Cubic, Enum.EasingDirection.In, {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1
    })

    collapse.Completed:Wait()

    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end

    self.Destroyed = true
end

function Loading:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true

    if self.FloatTween then
        self.FloatTween:Cancel()
    end

    if self.RotateTween then
        self.RotateTween:Cancel()
    end

    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end
end

return Loading
