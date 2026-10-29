--[[
  FOCUS OVERLAY + WEATHER ENGINE + MOBILE TOGGLE + DRAG LOGIC

  Split out of src/core/ui/demon-theme.luau (original lines 5702-6504).
  The body below is the original section, unchanged except for the shared
  reduced-motion flag (ctx.SharedReduced.value). The orchestrator loads this
  part with a shared context; it adds methods to the one Library table.
]]
local __CTX = ...
local SharedReduced = __CTX.SharedReduced
local Library = __CTX.Library
local D = __CTX.D
local Fn = __CTX.Fn
local GetIcon = __CTX.GetIcon
local getCam = __CTX.getCam
local GetGuiParent = __CTX.GetGuiParent
local findInGuiParents = __CTX.findInGuiParents
local GuiParent = __CTX.GuiParent
local TweenService = __CTX.TweenService
local GuiSound = __CTX.GuiSound
local Players = __CTX.Players
local RunService = __CTX.RunService
local MarketplaceService = __CTX.MarketplaceService
local Stats = __CTX.Stats
local UserInputService = __CTX.UserInputService
local CoreGui = __CTX.CoreGui
local Lighting = __CTX.Lighting
local SoundService = __CTX.SoundService
local LocalPlayer = __CTX.LocalPlayer
local IconsV2 = __CTX.IconsV2
local WEATHER_PRESETS = __CTX.WEATHER_PRESETS
local randomFloat = __CTX.randomFloat
local SubTabModule = __CTX.SubTabModule
local SUBTAB_DEFAULT_THEME = __CTX.SUBTAB_DEFAULT_THEME

-- =========================================================
-- FOCUS OVERLAY
-- =========================================================

function Library:_initFocusOverlay()
    self:_rebuildFocusPattern()
end

function Library:_patternCacheKey()
    local theme = D.Themes[self.ThemeName] or D.Themes.Dark
    local accent = theme.GridColor or theme.Accent or self._Colors.Accent
    local scale = (self._perfProfile and self._perfProfile.PatternScale) or 1
    return tostring(self._STATE.FocusOverlayType or "Grid") .. "|" .. tostring(accent) .. "|" .. tostring(scale)
end

function Library:_rebuildFocusPattern()
    local UI = self._UI
    if not UI.GridPattern then return end
    for _, child in ipairs(UI.GridPattern:GetChildren()) do
        child:Destroy()
    end
    self._lastPatternKey = self:_patternCacheKey()
    local patternType = self._STATE.FocusOverlayType or "Grid"
    if patternType == "None" then return end
    local _patScale = (self._perfProfile and self._perfProfile.PatternScale) or 1
    if _patScale <= 0 then return end

    local theme = D.Themes[self.ThemeName] or D.Themes.Dark
    local accent = theme.GridColor or theme.Accent or self._Colors.Accent
    local altAccent = theme.GridAltColor or accent

    local function pickColor(index)
        if theme.GridAltColor and index % 2 == 0 then return altAccent end
        return accent
    end

    if patternType == "Grid" then
        for index = 1, 18 do
            local line = Instance.new("Frame", UI.GridPattern)
            line.BackgroundColor3 = pickColor(index)
            line.BackgroundTransparency = 0.88
            line.BorderSizePixel = 0
            if index % 2 == 0 then
                line.Size = UDim2.new(1, 0, 0, 2)
                line.Position = UDim2.new(0, 0, index / 20, 0)
            else
                line.Size = UDim2.new(0, 2, 1, 0)
                line.Position = UDim2.new(index / 20, 0, 0, 0)
            end
        end
    elseif patternType == "Dots" then
        for xi = 1, 14 do
            for yi = 1, 9 do
                local dot = Instance.new("Frame", UI.GridPattern)
                dot.Size = UDim2.fromOffset(3, 3)
                dot.Position = UDim2.new(xi / 15, 0, yi / 10, 0)
                dot.BackgroundColor3 = pickColor(xi + yi)
                dot.BackgroundTransparency = 0.7
                dot.BorderSizePixel = 0
                Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
            end
        end
    elseif patternType == "Diagonal" then
        for index = 1, 14 do
            local line = Instance.new("Frame", UI.GridPattern)
            line.AnchorPoint = Vector2.new(0.5, 0.5)
            line.Size = UDim2.new(1.6, 0, 0, 2)
            line.Position = UDim2.new(0.5, 0, index / 15, 0)
            line.Rotation = 45
            line.BackgroundColor3 = pickColor(index)
            line.BackgroundTransparency = 0.9
            line.BorderSizePixel = 0
        end
    elseif patternType == "Crosshatch" then
        for index = 1, 10 do
            for _, rot in ipairs({45, -45}) do
                local line = Instance.new("Frame", UI.GridPattern)
                line.AnchorPoint = Vector2.new(0.5, 0.5)
                line.Size = UDim2.new(1.6, 0, 0, 2)
                line.Position = UDim2.new(0.5, 0, index / 11, 0)
                line.Rotation = rot
                line.BackgroundColor3 = pickColor(index)
                line.BackgroundTransparency = 0.9
                line.BorderSizePixel = 0
            end
        end
    elseif patternType == "Radial" then
        for index = 1, 12 do
            local angle = (index / 12) * math.pi
            local line = Instance.new("Frame", UI.GridPattern)
            line.AnchorPoint = Vector2.new(0.5, 0.5)
            line.Size = UDim2.new(1.4, 0, 0, 1)
            line.Position = UDim2.new(0.5, 0, 0.5, 0)
            line.Rotation = math.deg(angle)
            line.BackgroundColor3 = pickColor(index)
            line.BackgroundTransparency = 0.9
            line.BorderSizePixel = 0
        end
    elseif patternType == "Scanlines" then
        local count = 30
        for index = 1, count do
            local line = Instance.new("Frame", UI.GridPattern)
            line.Size = UDim2.new(1, 0, 0, 1)
            line.Position = UDim2.new(0, 0, index / count, 0)
            line.BackgroundColor3 = pickColor(index)
            line.BackgroundTransparency = 0.88
            line.BorderSizePixel = 0
        end
    elseif patternType == "Bricks" then
        local rows, cols = 10, 8
        local rowH = 1 / rows
        for r = 1, rows do
            local hLine = Instance.new("Frame", UI.GridPattern)
            hLine.Size = UDim2.new(1, 0, 0, 1)
            hLine.Position = UDim2.new(0, 0, r * rowH, 0)
            hLine.BackgroundColor3 = pickColor(r)
            hLine.BackgroundTransparency = 0.88
            hLine.BorderSizePixel = 0
            local isOdd = (r % 2 == 1)
            local limit = isOdd and cols or (cols - 1)
            local offset = isOdd and 0 or (0.5 / cols)
            for c = 1, limit do
                local vLine = Instance.new("Frame", UI.GridPattern)
                vLine.Size = UDim2.new(0, 1, rowH, 0)
                vLine.Position = UDim2.new((c / cols) + offset, 0, (r - 1) * rowH, 0)
                vLine.BackgroundColor3 = pickColor(r + c)
                vLine.BackgroundTransparency = 0.88
                vLine.BorderSizePixel = 0
            end
        end
    elseif patternType == "Concentric" then
        local rings = 10
        for index = 1, rings do
            local ring = Instance.new("Frame", UI.GridPattern)
            ring.AnchorPoint = Vector2.new(0.5, 0.5)
            ring.Position = UDim2.new(0.5, 0, 0.5, 0)
            local scale = index / rings
            ring.Size = UDim2.new(scale, 0, scale, 0)
            ring.BackgroundTransparency = 1
            ring.BorderSizePixel = 0
            local stroke = Instance.new("UIStroke", ring)
            stroke.Color = pickColor(index)
            stroke.Thickness = 1
            stroke.Transparency = 0.88
            Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
        end
    elseif patternType == "Stars" then
        for index = 1, 60 do
            local dot = Instance.new("Frame", UI.GridPattern)
            local sz = math.random(1, 3)
            dot.Size = UDim2.fromOffset(sz, sz)
            dot.Position = UDim2.new(math.random(), 0, math.random(), 0)
            dot.BackgroundColor3 = pickColor(index)
            dot.BackgroundTransparency = math.random(30, 70) / 100
            dot.BorderSizePixel = 0
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        end
    elseif patternType == "Plus" then
        for xi = 1, 8 do
            for yi = 1, 6 do
                local plus = Instance.new("TextLabel", UI.GridPattern)
                plus.Size = UDim2.fromOffset(14, 14)
                plus.Position = UDim2.new(xi / 9, 0, yi / 7, 0)
                plus.BackgroundTransparency = 1
                plus.Text = "+"
                plus.TextColor3 = pickColor(xi + yi)
                plus.TextTransparency = 0.7
                plus.Font = Enum.Font.GothamBold
                plus.TextSize = 16
            end
        end
    elseif patternType == "Zigzag" then
        local rows, segments = 10, 14
        for r = 1, rows do
            local y = r / (rows + 1)
            for s = 1, segments do
                local seg = Instance.new("Frame", UI.GridPattern)
                seg.AnchorPoint = Vector2.new(0.5, 0.5)
                seg.Size = UDim2.new(0.1, 0, 0, 1)
                local x = s / (segments + 1)
                local dir = (s % 2 == 0) and 40 or -40
                seg.Position = UDim2.new(x, 0, y, 0)
                seg.Rotation = dir
                seg.BackgroundColor3 = pickColor(r + s)
                seg.BackgroundTransparency = 0.88
                seg.BorderSizePixel = 0
            end
        end
    elseif patternType == "Matrix" then
        for index = 1, 20 do
            local col = Instance.new("Frame", UI.GridPattern)
            col.Size = UDim2.new(0, 1, 1, 0)
            col.Position = UDim2.new(index / 21, 0, 0, 0)
            col.BackgroundColor3 = pickColor(index)
            col.BorderSizePixel = 0
            local grad = Instance.new("UIGradient", col)
            grad.Rotation = 90
            grad.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0.85),
                NumberSequenceKeypoint.new(1, 1),
            })
        end
    elseif patternType == "Waves" then
        local waveCount = 4
        local points = 40
        for w = 1, waveCount do
            local baseY = w / (waveCount + 1)
            for p = 1, points do
                local seg = Instance.new("Frame", UI.GridPattern)
                seg.AnchorPoint = Vector2.new(0.5, 0.5)
                seg.Size = UDim2.new(0.04, 0, 0, 1)
                local x = p / (points + 1)
                local y = baseY + math.sin(x * math.pi * 6) * 0.04
                seg.Position = UDim2.new(x, 0, y, 0)
                seg.Rotation = math.cos(x * math.pi * 6) * 35
                seg.BackgroundColor3 = pickColor(w + p)
                seg.BackgroundTransparency = 0.88
                seg.BorderSizePixel = 0
            end
        end
    end
    if _patScale < 1 then
        local _kids = UI.GridPattern:GetChildren()
        local _total = #_kids
        local _keep = math.max(1, math.floor(_total * _patScale))
        -- Sample evenly across the whole child list instead of trimming the tail:
        -- keeping only the first N left the pattern lopsided (Concentric lost its
        -- outer rings, Grid clustered in one corner).
        local _stride = math.max(1, math.floor(_total / _keep))
        for _i = _total, 1, -1 do
            if ((_i - 1) % _stride) ~= 0 then
                _kids[_i]:Destroy()
            end
        end
    end
end

function Library:_updateFocusOverlay(theme)
    local UI = self._UI
    theme = theme or D.Themes[self.ThemeName] or D.Themes.Dark
    if not UI.FocusOverlay then return end

    local _focusAllowed = self._STATE.FocusOverlayEnabled
        and self._perfTier ~= "Potato"
        and self._STATE.GuiVisible
    UI.FocusOverlay.BackgroundColor3 = theme.FocusOverlayColor or theme.OverlayColor or self._Colors.Bg
    UI.FocusOverlay.BackgroundTransparency = _focusAllowed
        and (theme.OverlayTransparency or 0.45) or 1
    UI.FocusOverlay.Visible = _focusAllowed

    if self._lastPatternKey ~= self:_patternCacheKey() then
        if self._patternRebuildDebounce then
            pcall(task.cancel, self._patternRebuildDebounce)
        end
        self._patternRebuildDebounce = task.delay(0.15, function()
            self._patternRebuildDebounce = nil
            if self:_isDead() then return end
            if self._lastPatternKey ~= self:_patternCacheKey() then
                self:_rebuildFocusPattern()
            end
        end)
    end
end

function Library:SetFocusOverlay(enabled, patternType)
    if self:_isDead() then return end
    if type(enabled) ~= "boolean" then
        error("[DoD UI] SetFocusOverlay expects a boolean enabled value.")
    end
    if patternType ~= nil and not table.find(D.FocusOverlayTypes, patternType) then
        error("[DoD UI] SetFocusOverlay received an unsupported pattern type.")
    end
    self._STATE.FocusOverlayEnabled = enabled
    if patternType ~= nil then
        self._STATE.FocusOverlayType = patternType
        if enabled then
            self:_rebuildFocusPattern()
        end
    end
    self:_updateFocusOverlay()
    self:_updateAcrylicBlur()
end

function Library:_updateAcrylicBlur()
    local blur = self._UI.GuiBlur
    if not blur then return end
    local state = self._STATE
    local blurSize = 0
    if state.GuiVisible then
        if self.Acrylic then blurSize = self.AcrylicBlurIntensity end
        if state.FocusOverlayEnabled and self._perfTier ~= "Potato" then
            blurSize = math.max(blurSize, 12)
        end
    end
    if self._perfTier == "Potato" then
        blurSize = math.min(blurSize, 3)
    end
    blur.Size = blurSize
end

-- =========================================================
-- WEATHER ENGINE
-- =========================================================

function Library:SetWeather(enabled, weatherType, intensity)
    if self:_isDead() then return end
    if type(enabled) ~= "boolean" then
        error("[DoD UI] SetWeather expects a boolean enabled value.")
    end
    if weatherType ~= nil and not table.find(D.WeatherTypes, weatherType) then
        error("[DoD UI] SetWeather received an unsupported weather type.")
    end
    if intensity ~= nil and (type(intensity) ~= "number" or intensity < 0
        or intensity > 100 or intensity ~= intensity) then
        error("[DoD UI] Weather intensity must be a number between 0 and 100.")
    end
    local wasEnabled = self._STATE.WeatherEnabled
    local typeChanged = weatherType and weatherType ~= self._STATE.WeatherType
    self._STATE.WeatherEnabled = enabled
    if weatherType then self._STATE.WeatherType = weatherType end
    if intensity then self._STATE.WeatherIntensity = intensity end

    if enabled then
        -- Rebuild when the active profile's particle budget changed too: a tier
        -- downgrade used to keep animating the old (larger) pool forever.
        local wantCap = (self._perfProfile and self._perfProfile.WeatherParticleCap) or -1
        if not wasEnabled or typeChanged or not self._STATE.SnowConnection
            or self._weatherCapUsed ~= wantCap then
            self:_createWeather(self._STATE.WeatherType)
        end
    else
        self:_stopWeather()
    end
end

function Library:_stopWeather()
    local STATE = self._STATE
    if STATE.SnowConnection then
        Fn.untrack(STATE.SnowConnection, self)
        STATE.SnowConnection = nil
    end
    for _, particle in ipairs(STATE.SnowParticles) do
        if particle.frame then particle.frame:Destroy() end
    end
    table.clear(STATE.SnowParticles)
    if self._UI and self._UI.SnowLayer then
        self._UI.SnowLayer.Visible = false
    end
end

function Library:_createWeather(weatherType)
    self:_stopWeather()
    if not self._STATE.WeatherEnabled then return end

    local preset = WEATHER_PRESETS[weatherType]
    if not preset then return end

    local UI = self._UI
    local STATE = self._STATE

    UI.SnowLayer.Visible = STATE.GuiVisible
    local mobileScale = self._isMobile and 0.5 or 1
    local maxCount = math.max(1, math.floor(preset.count * 100 / 65 * mobileScale + 0.5))
    local _cap = (self._perfProfile and self._perfProfile.WeatherParticleCap)
    if _cap and _cap > 0 then
        maxCount = math.min(maxCount, _cap)
    end
    self._weatherCapUsed = _cap or -1
    if maxCount <= 0 then
        UI.SnowLayer.Visible = false
        STATE.WeatherEnabled = false
        return
    end
    local colors = preset.colors or { preset.color or Color3.new(1, 1, 1) }

    for index = 1, maxCount do
        local size = randomFloat(preset.minSize, preset.maxSize)
        local frame = Instance.new("Frame", UI.SnowLayer)
        local baseTransparency = randomFloat(preset.transMin, preset.transMax) / 100
        local color = colors[math.random(1, #colors)]

        if preset.shape == "Aurora" then
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Size = UDim2.new(size, 0, randomFloat(0.65, 1.1), 0)
            frame.Position = UDim2.fromScale(math.random(), randomFloat(0.35, 0.65))
            frame.BackgroundTransparency = baseTransparency
        elseif preset.shape == "Mist" then
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Size = UDim2.fromOffset(size * 2.2, randomFloat(24, 54))
            frame.Position = UDim2.fromScale(math.random(), randomFloat(0.2, 0.9))
            frame.BackgroundTransparency = baseTransparency
        elseif preset.shape == "Line" then
            frame.Size = UDim2.fromOffset(size, size * 4)
            frame.BackgroundTransparency = baseTransparency
        elseif preset.shape == "Leaf" then
            frame.Size = UDim2.fromOffset(size * 1.5, size * 0.75)
            frame.BackgroundTransparency = baseTransparency
        else
            frame.Size = UDim2.fromOffset(size, size)
            frame.BackgroundTransparency = baseTransparency
        end

        if preset.shape ~= "Aurora" and preset.shape ~= "Mist" then
            frame.Position = UDim2.fromScale(math.random(), math.random())
        end
        frame.BackgroundColor3 = color
        frame.BorderSizePixel = 0
        frame.ZIndex = preset.zIndex + (math.random() < 0.35 and 1 or 0)

        if preset.shape == "Circle" or preset.shape == "Leaf" or preset.shape == "Glow" then
            Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
        end

        local gradient
        if preset.shape == "Mist" or preset.shape == "Aurora" then
            gradient = Instance.new("UIGradient", frame)
            gradient.Color = ColorSequence.new(color, colors[math.random(1, #colors)])
            gradient.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.25, 0.35),
                NumberSequenceKeypoint.new(0.75, 0.35),
                NumberSequenceKeypoint.new(1, 1),
            })
            gradient.Rotation = preset.shape == "Aurora" and 90 or 0
        elseif preset.shape == "Glow" or weatherType == "Bubbles" then
            local stroke = Instance.new("UIStroke", frame)
            stroke.Color = color
            stroke.Thickness = 1
            stroke.Transparency = 0.35
        end

        local depth = randomFloat(0.65, 1.2)
        local baseSizeX = frame.Size.X
        local baseSizeY = frame.Size.Y
        local shape = preset.shape
        local breathAmp = 0
        local breathFreq = 0
        if shape == "Aurora" then
            breathAmp = 0.18
            breathFreq = randomFloat(0.15, 0.35)
        elseif shape == "Mist" then
            breathAmp = 0.08
            breathFreq = randomFloat(0.1, 0.25)
        elseif shape == "Glow" then
            breathAmp = 0.22
            breathFreq = randomFloat(0.6, 1.2)
        end
        table.insert(STATE.SnowParticles, {
            frame = frame,
            x = frame.Position.X.Scale,
            y = frame.Position.Y.Scale,
            speed = randomFloat(preset.speedMin, preset.speedMax) / 100 * depth,
            drift = randomFloat(preset.driftMin, preset.driftMax) / 100 * depth,
            sway = (preset.sway or 0) * depth,
            phase = math.random() * math.pi * 2,
            frequency = randomFloat(0.7, 1.8),
            sway2Amp = (preset.sway or 0) * depth * randomFloat(0.35, 0.7),
            sway2Phase = math.random() * math.pi * 2,
            sway2Freq = randomFloat(1.6, 2.8),
            rotation = randomFloat(preset.rotationMin or 0, preset.rotationMax or 0),
            rotationSpeed = randomFloat(preset.rotationSpeedMin or 0, preset.rotationSpeedMax or 0),
            baseTransparency = baseTransparency,
            twinkle = preset.twinkle or false,
            twinkleSpeed = randomFloat(1.5, 4),
            twinklePhase = math.random() * math.pi * 2,
            color = color,
            gradient = gradient,
            index = index,
            depth = depth,
            windFactor = randomFloat(0.3, 1.0),
            baseSizeX = baseSizeX,
            baseSizeY = baseSizeY,
            breathAmp = breathAmp,
            breathFreq = breathFreq,
            breathPhase = math.random() * math.pi * 2,
            fadeAlpha = 1,
        })
    end

    STATE.WeatherClock = 0
    STATE.SnowConnection = Fn.track(RunService.RenderStepped, function(dt)
        if not STATE.WeatherEnabled then
            self:_stopWeather()
            return
        end
        if UI.SnowLayer.Visible ~= STATE.GuiVisible then
            UI.SnowLayer.Visible = STATE.GuiVisible
        end
        if not STATE.GuiVisible then return end
        -- Reduced motion freezes the field instead of animating it; the old loop
        -- ignored the setting entirely.
        if SharedReduced.value then return end

        STATE.WeatherClock = STATE.WeatherClock + dt
        local T = STATE.WeatherClock
        -- The tier's cap must not be written back into the user's intensity (that
        -- ratcheted it down permanently); it only limits the effective value here.
        local profileIntensity = (self._perfProfile and self._perfProfile.WeatherIntensity) or 100
        local currentIntensity = math.clamp(math.min(tonumber(STATE.WeatherIntensity) or 65, profileIntensity), 0, 100)
        local activeCount = math.floor(#STATE.SnowParticles * currentIntensity / 100 + 0.5)
        local speedScale = 0.45 + currentIntensity / 100 * 0.9

        local windX = math.sin(T * 0.32) * 0.008 + math.sin(T * 0.77) * 0.005
        local windY = math.sin(T * 0.21) * 0.002

        for _, particle in ipairs(STATE.SnowParticles) do
            local frame = particle.frame
            local active = particle.index <= activeCount
            local wantVisible = active and (particle.fadeAlpha or 1) > 0.01
            if frame.Visible ~= wantVisible then frame.Visible = wantVisible end
            if active then
                particle.y = particle.y + (particle.speed * speedScale + windY) * dt
                particle.x = particle.x + (particle.drift * speedScale + windX * particle.windFactor) * dt

                local wrapped = false
                if particle.speed > 0 then
                    if particle.y > 1.08 then particle.y = -0.08; wrapped = true end
                else
                    if particle.y < -0.08 then particle.y = 1.08; wrapped = true end
                end
                if particle.x > 1.08 then particle.x = -0.08; wrapped = true end
                if particle.x < -0.08 then particle.x = 1.08; wrapped = true end
                if wrapped then particle.fadeAlpha = 0 end

                local edgeDist = math.min(
                    math.clamp(particle.y, 0, 1),
                    math.clamp(1 - particle.y, 0, 1),
                    math.clamp(particle.x, 0, 1),
                    math.clamp(1 - particle.x, 0, 1)
                )
                local targetFade = edgeDist < 0.08 and (edgeDist / 0.08) or 1
                particle.fadeAlpha = particle.fadeAlpha + (targetFade - particle.fadeAlpha) * math.min(1, dt * 2.5)

                local baseTrans = particle.baseTransparency
                if particle.twinkle then
                    local raw = math.sin(T * particle.twinkleSpeed + particle.twinklePhase)
                    local pulse = raw * raw
                    baseTrans = baseTrans + (1 - pulse) * 0.32
                end
                local depthFade = math.clamp(0.45 + particle.depth * 0.55, 0, 1)
                baseTrans = baseTrans + (1 - depthFade) * 0.12
                local finalTrans = math.clamp(baseTrans + (1 - particle.fadeAlpha) * (1 - baseTrans), 0, 1)
                if particle.lastTrans ~= finalTrans then
                    frame.BackgroundTransparency = finalTrans
                    particle.lastTrans = finalTrans
                end

                local swayA = math.sin(T * particle.frequency + particle.phase) * particle.sway
                local swayB = math.sin(T * particle.sway2Freq + particle.sway2Phase) * particle.sway2Amp
                local px, py = particle.x + swayA + swayB, particle.y
                if particle.lastX ~= px or particle.lastY ~= py then
                    frame.Position = UDim2.fromScale(px, py)
                    particle.lastX, particle.lastY = px, py
                end

                if particle.rotationSpeed ~= 0 then
                    particle.rotation = particle.rotation + particle.rotationSpeed * dt
                    if particle.lastRot ~= particle.rotation then
                        frame.Rotation = particle.rotation
                        particle.lastRot = particle.rotation
                    end
                end

                if particle.breathAmp and particle.breathAmp > 0 then
                    local breath = 1 + math.sin(T * particle.breathFreq + particle.breathPhase) * particle.breathAmp
                    frame.Size = UDim2.new(
                        particle.baseSizeX.Scale * breath, particle.baseSizeX.Offset * breath,
                        particle.baseSizeY.Scale * breath, particle.baseSizeY.Offset * breath
                    )
                end

                if particle.gradient and weatherType == "Aurora" then
                    particle.gradient.Rotation = 78 + math.sin(T * 0.28 + particle.phase) * 22 + math.cos(T * 0.17 + particle.sway2Phase) * 8
                end
            end
        end
    end, self)
end

-- =========================================================
-- MOBILE TOGGLE
-- =========================================================

function Library:_initMobileToggle()
    local UI = self._UI
    local isTouch = UserInputService.TouchEnabled

    UI.MobileToggle = Instance.new("TextButton", UI.MainGui)
    UI.MobileToggle.Name = "MobileToggle"
    UI.MobileToggle.Size = UDim2.fromOffset(160, 32)
    UI.MobileToggle.AnchorPoint = Vector2.new(0.5, 0)
    UI.MobileToggle.Position = UDim2.new(0.5, 0, 0, 36)
    UI.MobileToggle.BackgroundColor3 = self._Colors.Bg2
    UI.MobileToggle.BackgroundTransparency = 0.08
    UI.MobileToggle.Text = ""
    UI.MobileToggle.AutoButtonColor = false
    UI.MobileToggle.BorderSizePixel = 0
    UI.MobileToggle.Visible = isTouch and self._STATE.GuiVisible
    UI.MobileToggle.ZIndex = 1001
    Instance.new("UICorner", UI.MobileToggle).CornerRadius = UDim.new(1, 0)

    UI.MobileToggleStroke = Instance.new("UIStroke", UI.MobileToggle)
    UI.MobileToggleStroke.Color = self._Colors.Accent
    UI.MobileToggleStroke.Thickness = 1.5
    UI.MobileToggleStroke.Transparency = 0.4

    local mtGrad = Instance.new("UIGradient", UI.MobileToggle)
    mtGrad.Rotation = 90
    mtGrad.Color = ColorSequence.new(self._Colors.Bg2, self._Colors.Bg)

    local mtIcon = Instance.new("ImageLabel", UI.MobileToggle)
    mtIcon.Size = UDim2.fromOffset(14, 14)
    mtIcon.Position = UDim2.new(0, 14, 0.5, -7)
    mtIcon.BackgroundTransparency = 1
    mtIcon.Image = GetIcon("panel-top")
    mtIcon.ImageColor3 = self._Colors.Accent

    local mtLabel = Instance.new("TextLabel", UI.MobileToggle)
    mtLabel.Size = UDim2.new(1, -40, 1, 0)
    mtLabel.Position = UDim2.new(0, 36, 0, 0)
    mtLabel.BackgroundTransparency = 1
    mtLabel.Text = (self.Title:match("^(.-)%s*|") or self.Title)
    mtLabel.TextColor3 = self._Colors.Text
    mtLabel.Font = Enum.Font.GothamBold
    mtLabel.TextSize = 11
    mtLabel.TextXAlignment = Enum.TextXAlignment.Left
    mtLabel.TextTruncate = Enum.TextTruncate.AtEnd

    Fn.bindPressAnimation(UI.MobileToggle)
    UI.MobileToggle.MouseButton1Click:Connect(function()
        self:Minimize()
    end)

    self:_registerThemeRefresher(function()
        if not UI.MobileToggle.Parent then return end
        UI.MobileToggle.BackgroundColor3 = self._Colors.Bg2
        if UI.MobileToggleStroke then UI.MobileToggleStroke.Color = self._Colors.Accent end
        mtIcon.ImageColor3 = self._Colors.Accent
        mtLabel.TextColor3 = self._Colors.Text
        mtGrad.Color = ColorSequence.new(self._Colors.Bg2, self._Colors.Bg)
    end)

    local oldToggle = self.Toggle
    self.Toggle = function(lib, ...)
        oldToggle(lib, ...)
        if UI.MobileToggle then
            UI.MobileToggle.Visible = UserInputService.TouchEnabled and self._STATE.GuiVisible
        end
    end
end

-- =========================================================
-- DRAG LOGIC
-- =========================================================

function Library:_initResize()
    local UI = self._UI
    if not UI.ResizeHandle or not UI.MainContainer then return end
    
    local resizing = false
    local startSize
    local startInput = Vector2.zero
    local currentInput = Vector2.zero
    
    UI.ResizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            -- AbsoluteSize is post-UIScale, Size is pre-scale. Feeding the scaled
            -- value back into Size made the window snap to ~55% of itself on the
            -- first drag frame on any device with an adaptive scale != 1.
            local s = (UI.MainScale and UI.MainScale.Scale) or 1
            if s <= 0 then s = 1 end
            local logicalX = UI.MainContainer.Size.X.Offset
            local logicalY = UI.MainContainer.Size.Y.Offset
            if logicalX <= 0 then logicalX = UI.MainContainer.AbsoluteSize.X / s end
            if logicalY <= 0 then logicalY = UI.MainContainer.AbsoluteSize.Y / s end
            startSize = Vector2.new(logicalX, logicalY)
            startInput = Vector2.new(input.Position.X, input.Position.Y)
            currentInput = startInput
        end
    end)

    Fn.track(UserInputService.InputChanged, function(input)
        if not resizing then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            currentInput = Vector2.new(input.Position.X, input.Position.Y)
        end
    end, self)
    
    Fn.track(RunService.RenderStepped, function()
        if not resizing then return end
        local cam = getCam()
        if not cam then return end
        local mc = UI.MainContainer
        local s = (UI.MainScale and UI.MainScale.Scale) or 1
        if s <= 0 then s = 1 end
        local delta = Vector2.new(currentInput.X - startInput.X, currentInput.Y - startInput.Y)
        local vp = cam.ViewportSize
        local maxW = math.max(120, vp.X * 0.95)
        local maxH = math.max(120, vp.Y * 0.95)
        -- Derive the floor from the ceiling instead of clamping to the same value,
        -- which used to turn the handle into a "jump to 95%" button on small
        -- viewports (minW == maxW).
        -- FIX: was 280x240 with 0.6 proportional fallback, which on tiny
        -- viewports produced unusably small windows. Use the same explicit
        -- minimum as the UISizeConstraint with a 0.9 proportional fallback
        -- (only kicks in if the viewport itself is smaller than the min).
        local _baseMinW = self._isMobile and 300 or 360
        local _baseMinH = self._isMobile and 340 or 400
        local minW = math.min(_baseMinW, maxW * 0.9)
        local minH = math.min(_baseMinH, maxH * 0.9)
        local newX = math.clamp(startSize.X + delta.X / s, minW, maxW)
        local newY = math.clamp(startSize.Y + delta.Y / s, minH, maxH)

        mc.Size = UDim2.fromOffset(newX, newY)

        -- Growing from a bottom/right anchored position used to push the window
        -- (and its resize handle) off-screen with no way back.
        local absPos = mc.AbsolutePosition
        local absSize = mc.AbsoluteSize
        if absSize.X > 0 and absSize.Y > 0 then
            local cx = absPos.X + absSize.X / 2
            local cy = absPos.Y + absSize.Y / 2
            local halfW = absSize.X / 2
            local halfH = absSize.Y / 2
            local wantX = math.clamp(cx, halfW + 4, math.max(halfW + 4, vp.X - halfW - 4))
            local wantY = math.clamp(cy, halfH + 4, math.max(halfH + 4, vp.Y - halfH - 4))
            if wantX ~= cx or wantY ~= cy then
                local p = mc.Position
                mc.Position = UDim2.new(p.X.Scale, p.X.Offset + (wantX - cx), p.Y.Scale, p.Y.Offset + (wantY - cy))
            end
        end
    end, self)
    
    Fn.track(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if resizing then
                resizing = false
                local mobileToggle = UI.MobileToggle
                if mobileToggle then
                    mobileToggle.Visible = UserInputService.TouchEnabled and self._STATE.GuiVisible
                end
            end
        end
    end, self)
end

function Library:_initDrag()
    local UI = self._UI
    local dragging = false
    local dragStartPos = UDim2.new()
    local dragStartInput = Vector2.zero
    local currentInput = Vector2.zero

    UI.TitleBar.Active = true
    UI.TitleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStartPos = UI.MainContainer.Position
            dragStartInput = Vector2.new(inp.Position.X, inp.Position.Y)
            currentInput = dragStartInput
        end
    end)

    Fn.track(UserInputService.InputChanged, function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            currentInput = Vector2.new(inp.Position.X, inp.Position.Y)
        end
    end, self)

    Fn.track(RunService.RenderStepped, function()
        if not dragging then return end
        local camera = getCam()
        if not camera then return end
        local vp = camera.ViewportSize
        local sz = UI.MainContainer.AbsoluteSize
        local deltaX = currentInput.X - dragStartInput.X
        local deltaY = currentInput.Y - dragStartInput.Y
        local baseAbsX = dragStartPos.X.Scale * vp.X + dragStartPos.X.Offset
        local baseAbsY = dragStartPos.Y.Scale * vp.Y + dragStartPos.Y.Offset
        local targetAbsX = baseAbsX + deltaX
        local targetAbsY = baseAbsY + deltaY
        local halfW = sz.X * 0.5
        local halfH = sz.Y * 0.5
        targetAbsX = math.clamp(targetAbsX, halfW + 8, vp.X - halfW - 8)
        targetAbsY = math.clamp(targetAbsY, halfH + 8, vp.Y - halfH - 8)
        UI.MainContainer.Position = UDim2.new(
            dragStartPos.X.Scale,
            targetAbsX - dragStartPos.X.Scale * vp.X,
            dragStartPos.Y.Scale,
            targetAbsY - dragStartPos.Y.Scale * vp.Y
        )
    end, self)

    Fn.track(UserInputService.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end, self)
end


return true
