local Utils = {}

function Utils.new(window, theme)
    local self = {Window = window, Theme = theme}

    function self:Track(connection)
        if connection then window.Connections[#window.Connections + 1] = connection end
        return connection
    end

    function self:Corner(object, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = radius or UDim.new(0, 8)
        corner.Parent = object
        return corner
    end

    function self:Stroke(object, color, transparency, thickness)
        local stroke = Instance.new("UIStroke")
        stroke.Color = color or theme.Border
        stroke.Transparency = transparency or 0
        stroke.Thickness = thickness or 1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = object
        return stroke
    end

    function self:Text(parent, value, size, position, textSize, font, color, alignment)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.Size = size
        label.Position = position or UDim2.fromOffset(0, 0)
        label.Text = tostring(value or "")
        label.TextColor3 = color or theme.White
        label.TextSize = textSize or 14
        label.Font = font or Enum.Font.Gotham
        label.TextXAlignment = alignment or Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = parent
        return label
    end

    function self:Tween(key, object, duration, properties)
        local previous = window.Tweens[key]
        if previous then pcall(previous.Cancel, previous) end
        local tween = game:GetService("TweenService"):Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
        window.Tweens[key] = tween
        self:Track(tween.Completed:Connect(function()
            if window.Tweens[key] == tween then window.Tweens[key] = nil end
        end))
        tween:Play()
        return tween
    end

    function self:Viewport()
        local camera = workspace.CurrentCamera
        return camera and camera.ViewportSize or Vector2.new(1280, 720)
    end

    function self:FormatDuration(value)
        local seconds = math.max(0, math.floor(tonumber(value) or 0))
        local days = math.floor(seconds / 86400)
        local hours = math.floor((seconds % 86400) / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        local remaining = seconds % 60
        if days > 0 then return string.format("%dD %02dH %02dM %02dS", days, hours, minutes, remaining) end
        if hours > 0 then return string.format("%02dH %02dM %02dS", hours, minutes, remaining) end
        return string.format("%02dM %02dS", minutes, remaining)
    end

    return self
end

return Utils
