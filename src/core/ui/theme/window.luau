--[[
  WINDOW CHROME (main GUI, title bar, category bar, search bar, content area)

  Split out of src/core/ui/demon-theme.luau (original lines 2489-5701).
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
-- MAIN GUI
-- =========================================================

-- Re-binds a viewport handler whenever the active camera is replaced (respawn,
-- first-person toggle, cinematic cut). The old code captured one Camera at
-- construction and stayed frozen on it for the rest of the session.
function Library:_bindViewportSignal(callback)
    local camConn
    local function attach()
        if camConn then pcall(function() camConn:Disconnect() end) end
        camConn = nil
        local cam = getCam()
        if cam then
            camConn = Fn.track(cam:GetPropertyChangedSignal("ViewportSize"), callback, self)
        end
    end
    attach()
    Fn.track(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
        if self:_isDead() then return end
        attach()
        pcall(callback)
    end, self)
end

function Library:_initMainGui()
    local UI = self._UI
    UI.MainGui = Instance.new("ScreenGui")
    UI.MainGui.Name = "DoD_UI_Main"
    UI.MainGui.Parent = GuiParent
    UI.MainGui.ResetOnSpawn = false
    UI.MainGui.IgnoreGuiInset = true
    UI.MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    UI.MainGui.DisplayOrder = 1000

    UI.CustomCursor = Instance.new("ImageLabel", UI.MainGui)
    UI.CustomCursor.Name = "CustomCursor"
    UI.CustomCursor.Size = UDim2.fromOffset(20, 20)
    UI.CustomCursor.AnchorPoint = Vector2.new(0, 0)
    UI.CustomCursor.BackgroundTransparency = 1
    UI.CustomCursor.Image = GetIcon("mouse-pointer-2")
    UI.CustomCursor.ImageColor3 = self._Colors.Accent
    UI.CustomCursor.ZIndex = 100000
    UI.CustomCursor.Visible = false

    -- Mouse ownership is scoped to the panel being OPEN, nothing more.
    --
    -- MouseBehavior belongs to the game's camera controller: it re-applies its own
    -- value every frame (LockCenter while aiming / first person, Default
    -- otherwise). Snapshotting it at open and writing it back at close was the
    -- "mouse travado" bug -- in any game that locks the cursor while playing, the
    -- restore re-locked the pointer to the screen centre and it could not be
    -- moved. It is never saved and never restored now.
    --
    -- MouseIconEnabled is ours only while the panel is open (to draw the custom
    -- cursor). On close the OS cursor is always handed back visible, so the panel
    -- can never leave the game without a pointer.
    self._overGui = false

    -- Take the mouse for the open panel: free it (Default) and hide the OS cursor
    -- so the custom one is the only pointer on screen.
    function Library:_captureMouse()
        self._overGui = false
        if self._isMobile then return end
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        UserInputService.MouseIconEnabled = false
    end

    -- Hand the mouse back to the game. MouseBehavior is left completely alone --
    -- the game's camera re-asserts it the moment we stop, which is exactly the
    -- behaviour we want. The cursor is always returned visible. Single restore
    -- path for Toggle close, Minimize and Destroy, so the three cannot drift.
    function Library:_restoreMouse()
        self._overGui = false
        if self._UI and self._UI.CustomCursor then self._UI.CustomCursor.Visible = false end
        UserInputService.MouseIconEnabled = true
    end

    local function pointIn(frame, mx, my)
        if not frame or not frame.Parent or not frame.Visible then return false end
        local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
        return mx >= pos.X and mx <= pos.X + size.X and my >= pos.Y and my <= pos.Y + size.Y
    end

    Fn.track(RunService.RenderStepped, function()
        if self._STATE.Destroyed then return end

        if self._isMobile then
            if UI.CustomCursor and UI.CustomCursor.Visible then
                UI.CustomCursor.Visible = false
            end
            if self._overGui then
                self._overGui = false
                UserInputService.MouseIconEnabled = true
            end
            return
        end

        local mouse = UserInputService:GetMouseLocation()
        local overGui = false

        -- Everything below is scoped to the panel being open. While it is
        -- minimized/closed the mouse is left entirely to the game: no
        -- MouseIconEnabled write, no MouseBehavior write, no cursor toggle.
        if self._STATE.GuiVisible then
            overGui = pointIn(UI.MainContainer, mouse.X, mouse.Y)
            if not overGui then
                overGui = pointIn(UI.KeybindOverlay, mouse.X, mouse.Y)
            end
            if not overGui and self._STATE.activeDropdownPopups then
                for _, entry in ipairs(self._STATE.activeDropdownPopups) do
                    if pointIn(entry.popup, mouse.X, mouse.Y) then
                        overGui = true
                        break
                    end
                end
            end

            -- Transition-only writes: the custom cursor follows the pointer over
            -- our UI, and the OS cursor is hidden only while it is over us.
            if overGui ~= self._overGui then
                self._overGui = overGui
                if UI.CustomCursor then
                    UI.CustomCursor.Visible = overGui
                end
                if UserInputService.MouseIconEnabled ~= (not overGui) then
                    UserInputService.MouseIconEnabled = not overGui
                end
            end

            -- Re-assert Default only if the game has re-locked the mouse *while our
            -- panel is open* (its camera script keeps running behind the overlay).
            -- Done as a guard, not a blind per-frame write, so we are not fighting
            -- the engine on the frames it already agrees with us.
            if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end

            if overGui and UI.CustomCursor then
                UI.CustomCursor.Position = UDim2.fromOffset(mouse.X, mouse.Y)
            end
        elseif self._overGui then
            -- Closed while the pointer was still tagged as over us: drop the flag
            -- and stop drawing the custom cursor. MouseIconEnabled is left alone --
            -- _restoreMouse already handed a visible cursor back to the game.
            self._overGui = false
            if UI.CustomCursor then UI.CustomCursor.Visible = false end
        end

        self:_updateCursorTrail(mouse)
    end, self)

    UI.FocusOverlay = Instance.new("Frame", UI.MainGui)
    UI.FocusOverlay.Name = "FocusOverlay"
    UI.FocusOverlay.Size = UDim2.fromScale(1, 1)
    UI.FocusOverlay.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    UI.FocusOverlay.BackgroundTransparency = 1
    UI.FocusOverlay.BorderSizePixel = 0
    UI.FocusOverlay.ZIndex = 0
    UI.FocusOverlay.Visible = false
    UI.FocusOverlay.Active = false

    UI.GridPattern = Instance.new("Frame", UI.FocusOverlay)
    UI.GridPattern.Size = UDim2.fromScale(1, 1)
    UI.GridPattern.BackgroundTransparency = 1
    UI.GridPattern.ZIndex = 0

    UI.ParticleBG = Instance.new("Frame", UI.MainGui)
    UI.ParticleBG.Name = "ParticleBG"
    UI.ParticleBG.Size = UDim2.fromScale(1, 1)
    UI.ParticleBG.BackgroundTransparency = 1
    UI.ParticleBG.BorderSizePixel = 0
    UI.ParticleBG.ZIndex = 5
    UI.ParticleBG.ClipsDescendants = true
    UI.ParticleBG.Visible = false
    
    local particles = {}
    for i = 1, 25 do
        local p = Instance.new("Frame", UI.ParticleBG)
        p.Size = UDim2.fromOffset(math.random(2, 4), math.random(2, 4))
        p.Position = UDim2.fromScale(math.random(), math.random())
        p.BackgroundColor3 = self._Colors.Accent
        p.BackgroundTransparency = math.random(30, 80) / 100
        p.BorderSizePixel = 0
        Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
        table.insert(particles, {
            obj = p,
            speedX = (math.random() - 0.5) * 0.005,
            speedY = -math.random(1, 3) / 1000
        })
    end
    
    Fn.track(UserInputService.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local mouse = UserInputService:GetMouseLocation()
            local frames = self._STATE.ScrollFrames
            local target = nil
            for i = #frames, 1, -1 do
                local sf = frames[i]
                if sf and sf.Parent and sf.Visible then
                    local pos, size = sf.AbsolutePosition, sf.AbsoluteSize
                    if mouse.X >= pos.X and mouse.X <= pos.X + size.X and
                       mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y then
                        local maxScroll = sf.AbsoluteCanvasSize.Y - sf.AbsoluteSize.Y
                        if maxScroll > 1 then
                            target = sf
                            break
                        end
                    end
                end
            end
            if target then
                local inPopup = false
                for _, entry in ipairs(self._STATE.activeDropdownPopups) do
                    local p = entry.popup
                    if p and p.Parent and p.Visible then
                        local pp, ps = p.AbsolutePosition, p.AbsoluteSize
                        if mouse.X >= pp.X and mouse.X <= pp.X + ps.X and
                           mouse.Y >= pp.Y and mouse.Y <= pp.Y + ps.Y then
                            inPopup = true
                            break
                        end
                    end
                end
                if not inPopup then
                    for _, entry in ipairs(self._STATE.activeDropdownPopups) do
                        if entry.popup and entry.popup.Visible then entry.close() end
                    end
                end
                local scrollAmount = 50
                local targetY = target.CanvasPosition.Y - (input.Position.Z * scrollAmount)
                local maxScroll = math.max(0, target.AbsoluteCanvasSize.Y - target.AbsoluteSize.Y)
                targetY = math.clamp(targetY, 0, maxScroll)
                TweenService:Create(target, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    CanvasPosition = Vector2.new(target.CanvasPosition.X, targetY)
                }):Play()
            end
        end
    end, self)

    local _particleAccum = 0
    self._particleBGConn = Fn.track(RunService.RenderStepped, function(dt)
        if not UI.ParticleBG.Visible then return end
        if SharedReduced.value then return end
        -- Decorative motion does not need render rate: 30 Hz is indistinguishable
        -- here and halves the property writes.
        _particleAccum = _particleAccum + dt
        if _particleAccum < 1 / 30 then return end
        local step = _particleAccum
        _particleAccum = 0
        for _, data in ipairs(particles) do
            local pos = data.obj.Position
            local nx = pos.X.Scale + data.speedX * step * 10
            local ny = pos.Y.Scale + data.speedY * step * 10
            if nx < 0 then nx = 1 elseif nx > 1 then nx = 0 end
            if ny < 0 then ny = 1 elseif ny > 1 then ny = 0 end
            data.obj.Position = UDim2.fromScale(nx, ny)
        end
    end, self)

    UI.SnowLayer = Instance.new("Frame", UI.MainGui)
    UI.SnowLayer.Name = "SnowLayer"
    UI.SnowLayer.Size = UDim2.fromScale(1, 1)
    UI.SnowLayer.BackgroundTransparency = 1
    UI.SnowLayer.BorderSizePixel = 0
    UI.SnowLayer.ZIndex = 4
    UI.SnowLayer.Visible = false

    local existingBlur = Lighting:FindFirstChild("DoD_UI_Blur")
    UI.GuiBlur = (existingBlur and existingBlur:IsA("BlurEffect")) and existingBlur or Instance.new("BlurEffect")
    UI.GuiBlur.Name = "DoD_UI_Blur"
    UI.GuiBlur.Size = 0
    UI.GuiBlur.Parent = Lighting

    local MC = Instance.new("Frame", UI.MainGui)
    UI.MainContainer = MC
    MC.Size = self.WindowSize
    MC.Position = UDim2.new(0.5, 0, 0.5, 0)
    MC.AnchorPoint = Vector2.new(0.5, 0.5)
    MC.BackgroundColor3 = self._Colors.Bg
    MC.BackgroundTransparency = self.Acrylic and 0.32 or 0.1
    MC.BorderSizePixel = 0
    MC.ClipsDescendants = true
    MC.ZIndex = 10
    Instance.new("UICorner", MC).CornerRadius = UDim.new(0, 14)

    UI.MainSizeConstraint = Instance.new("UISizeConstraint", MC)

    local function updateSizeLimit()
        local camera = getCam()
        if not camera then return end
        local viewport = camera.ViewportSize
        UI.MainSizeConstraint.MaxSize = Vector2.new(
            math.max(1, viewport.X * 0.96),
            math.max(1, viewport.Y * 0.92)
        )
        -- FIX: original 280x240 was so small that the entire content area
        -- collapsed to a sliver (only headers visible). 360x400 leaves enough
        -- room for title + tabs + search + at least 1-2 full sections. Mobile
        -- uses slightly smaller because the viewport itself is smaller.
        local _minW = self._isMobile and 300 or 360
        local _minH = self._isMobile and 340 or 400
        UI.MainSizeConstraint.MinSize = Vector2.new(
            math.min(_minW, UI.MainSizeConstraint.MaxSize.X),
            math.min(_minH, UI.MainSizeConstraint.MaxSize.Y)
        )
    end
    updateSizeLimit()
    self:_bindViewportSignal(updateSizeLimit)

    UI.Wallpaper = Instance.new("ImageLabel", MC)
    UI.Wallpaper.Name = "Wallpaper"
    UI.Wallpaper.Size = UDim2.fromScale(1, 1)
    UI.Wallpaper.Position = UDim2.fromScale(0, 0)
    UI.Wallpaper.AnchorPoint = Vector2.new(0, 0)
    UI.Wallpaper.BackgroundTransparency = 1
    UI.Wallpaper.ZIndex = 0
    UI.Wallpaper.Visible = false
    UI.Wallpaper.ScaleType = Enum.ScaleType.Crop
    -- UICorner sengaja dihapus karena MC udah nge-clip pake ClipsDescendants
    -- Jadi pas di-resize, gambar gak bakal aneh di sudutnya

    UI.AcrylicTexture = Instance.new("Frame", MC)
    UI.AcrylicTexture.Name = "AcrylicTexture"
    UI.AcrylicTexture.Size = UDim2.fromScale(1, 1)
    UI.AcrylicTexture.BackgroundColor3 = self._Colors.Accent2
    UI.AcrylicTexture.BackgroundTransparency = self.Acrylic and 0.94 or 1
    UI.AcrylicTexture.BorderSizePixel = 0
    UI.AcrylicTexture.Active = false
    UI.AcrylicTexture.Visible = self.Acrylic
    Instance.new("UICorner", UI.AcrylicTexture).CornerRadius = UDim.new(0, 14)

    UI.AcrylicGradient = Instance.new("UIGradient", UI.AcrylicTexture)
    UI.AcrylicGradient.Rotation = 35
    UI.AcrylicGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.48, self._Colors.Accent2),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    UI.AcrylicGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.45),
        NumberSequenceKeypoint.new(0.5, 0.8),
        NumberSequenceKeypoint.new(1, 0.5),
    })

    UI.AcrylicSheen = Instance.new("Frame", MC)
    UI.AcrylicSheen.Name = "AcrylicSheen"
    UI.AcrylicSheen.Size = UDim2.new(1, -2, 0, 1)
    UI.AcrylicSheen.Position = UDim2.new(0, 1, 0, 1)
    UI.AcrylicSheen.BackgroundColor3 = Color3.new(1, 1, 1)
    UI.AcrylicSheen.BackgroundTransparency = self.Acrylic and 0.72 or 1
    UI.AcrylicSheen.BorderSizePixel = 0
    UI.AcrylicSheen.Visible = self.Acrylic

    UI.MainScale = Instance.new("UIScale", MC)
    UI.MainScale.Scale = 1

    local function updateAdaptiveScale()
        if not UI.MainScale then return end
        if not UserInputService.TouchEnabled then
            UI.MainScale.Scale = 1
            self._adaptiveScaleTarget = 1
            return
        end
        local cam = getCam()
        if not cam then return end
        local viewport = cam.ViewportSize
        local baseW = (self.WindowSize and self.WindowSize.X.Offset) or 900
        local baseH = (self.WindowSize and self.WindowSize.Y.Offset) or 580
        if baseW <= 0 then baseW = 900 end
        if baseH <= 0 then baseH = 580 end
        local fitW = (viewport.X * 0.95) / baseW
        local fitH = (viewport.Y * 0.90) / baseH
        local fit = math.min(fitW, fitH)
        local _scale = math.clamp(fit, self._isMobile and 0.55 or 0.35, 1.4)
        UI.MainScale.Scale = _scale
        self._adaptiveScaleTarget = _scale
    end
    updateAdaptiveScale()
    self:_bindViewportSignal(updateAdaptiveScale)

    UI.MainStroke = Instance.new("UIStroke", MC)
    UI.MainStroke.Color = self._Colors.Border
    UI.MainStroke.Thickness = 1.5

    local resizeHandle = Instance.new("ImageLabel")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Parent = MC
    local _rszSize = self._isMobile and 44 or 26
    resizeHandle.Size = UDim2.fromOffset(_rszSize, _rszSize)
    resizeHandle.Position = UDim2.new(1, -(_rszSize + 4), 1, -(_rszSize + 4))
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.Image = GetIcon("move-diagonal")
    resizeHandle.ImageColor3 = self._Colors.TextDim
    resizeHandle.ZIndex = 100
    
    UI.ResizeHandle = resizeHandle

    local _mBtnCam = getCam()
    local _mBtnVpX = (_mBtnCam and _mBtnCam.ViewportSize.X) or 800
    local _mBtnVpY = (_mBtnCam and _mBtnCam.ViewportSize.Y) or 600
    local _mBtnMob = self._isMobile
    local _mBtnH = _mBtnMob and math.clamp(math.floor(_mBtnVpY * 0.055), 44, 56) or 28
    local _mBtnW = _mBtnMob and math.clamp(math.floor(_mBtnVpX * 0.5), 160, 260) or 180
    local _mIconSz = _mBtnMob and math.clamp(math.floor(_mBtnH * 0.42), 16, 22) or 14
    local _mFontSz = _mBtnMob and math.clamp(math.floor(_mBtnH * 0.30), 12, 16) or 11
    self._minBtnBaseW = _mBtnW
    self._minBtnBaseH = _mBtnH
    self._minBtnBaseY = _mBtnMob and 20 or 16

    local minBtn = Instance.new("TextButton")
    minBtn.Name = "MinimizeButton"
    minBtn.Parent = UI.MainGui
    minBtn.Size = UDim2.fromOffset(_mBtnW, _mBtnH)
    minBtn.Position = UDim2.new(0.5, 0, 0, -(_mBtnH + 12))
    minBtn.AnchorPoint = Vector2.new(0.5, 0)
    minBtn.BackgroundColor3 = self._Colors.Bg2
    minBtn.BackgroundTransparency = 0.12
    minBtn.AutoButtonColor = false
    minBtn.Text = ""
    minBtn.Visible = false
    minBtn.ZIndex = 500
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(1, 0)

    local minGrad = Instance.new("UIGradient", minBtn)
    minGrad.Rotation = 90
    minGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, self._Colors.Bg2),
        ColorSequenceKeypoint.new(1, self._Colors.Bg),
    })
    
    local minStroke = Instance.new("UIStroke", minBtn)
    minStroke.Color = self._Colors.Accent
    minStroke.Thickness = 1.5
    minStroke.Transparency = 0.4
    
    local minIcon = Instance.new("ImageLabel")
    minIcon.Size = UDim2.fromOffset(_mIconSz, _mIconSz)
    minIcon.Position = UDim2.new(0, 14, 0.5, -_mIconSz / 2)
    minIcon.BackgroundTransparency = 1
    minIcon.Image = GetIcon("panel-top")
    minIcon.ImageColor3 = self._Colors.Accent
    
    local mainTitle = self.Title:match("^(.-)%s*|") or self.Title
    
    local minText = Instance.new("TextLabel")
    minText.Size = UDim2.new(1, -(_mIconSz + 26), 1, 0)
    minText.Position = UDim2.new(0, 14 + _mIconSz + 8, 0, 0)
    minText.BackgroundTransparency = 1
    minText.Text = mainTitle
    minText.TextColor3 = self._Colors.Text
    minText.Font = Enum.Font.GothamBold
    minText.TextSize = _mFontSz
    minText.TextXAlignment = Enum.TextXAlignment.Left
    
    minIcon.Parent = minBtn
    minText.Parent = minBtn
    
    UI.MinimizeButton = minBtn
    UI.MinimizeButtonStroke = minStroke
    UI.MinimizeButtonIcon = minIcon
    
    Fn.bindPressAnimation(minBtn)
    
    minBtn.MouseEnter:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
        TweenService:Create(minStroke, TweenInfo.new(0.15), {Transparency = 0}):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
        TweenService:Create(minStroke, TweenInfo.new(0.15), {Transparency = 0.5}):Play()
    end)
    
    minBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    self:_registerThemeRefresher(function()
        minBtn.BackgroundColor3 = self._Colors.Bg2
        minStroke.Color = self._Colors.Accent
        minIcon.ImageColor3 = self._Colors.Accent
        minText.TextColor3 = self._Colors.Accent
    end)

    self:_bindViewportSignal(function()
        local vpCam = getCam()
        if not vpCam then return end
        local vp = vpCam.ViewportSize
        local mob = self._isMobile
        local h = mob and math.clamp(math.floor(vp.Y * 0.055), 44, 56) or 28
        local w = mob and math.clamp(math.floor(vp.X * 0.5), 160, 260) or 180
        local iconSz = mob and math.clamp(math.floor(h * 0.42), 16, 22) or 14
        local fontSz = mob and math.clamp(math.floor(h * 0.30), 12, 16) or 11
        self._minBtnBaseW = w
        self._minBtnBaseH = h
        self._minBtnBaseY = mob and 20 or 16
        minIcon.Size = UDim2.fromOffset(iconSz, iconSz)
        minIcon.Position = UDim2.new(0, 14, 0.5, -iconSz / 2)
        minText.Size = UDim2.new(1, -(iconSz + 26), 1, 0)
        minText.Position = UDim2.new(0, 14 + iconSz + 8, 0, 0)
        minText.TextSize = fontSz
        if minBtn.Visible then
            minBtn.Size = UDim2.fromOffset(w, h)
        end
    end)

    self._shadowLayers = {}

    -- Scroll sounds are wired where each ScrollingFrame is created (see
    -- _registerScrollFrame); the old 0.4s global scan ran for the whole session.
end

function Library:_initKeybindOverlay()
    local UI = self._UI
    local overlay = Instance.new("Frame", UI.MainGui)
    overlay.Name = "KeybindOverlay"
    overlay.Size = UDim2.fromOffset(290, 280)
    overlay.AnchorPoint = Vector2.new(1, 1)
    overlay.Position = UDim2.new(1, -18, 1, -58)
    overlay.BackgroundColor3 = self._Colors.Bg2
    overlay.BackgroundTransparency = 0.15
    overlay.BorderSizePixel = 0
    overlay.Visible = false
    overlay.ZIndex = 250
    overlay.ClipsDescendants = true
    Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 16)
    local stroke = Instance.new("UIStroke", overlay)
    stroke.Color = self._Colors.Border
    stroke.Thickness = 1
    stroke.Transparency = 0.6

    local heading = Instance.new("TextLabel", overlay)
    heading.Name = "Heading"
    heading.Size = UDim2.new(1, -80, 0, 20)
    heading.Position = UDim2.new(0, 16, 0, 14)
    heading.BackgroundTransparency = 1
    heading.Text = "KEYBINDS"
    heading.TextColor3 = self._Colors.Text
    heading.Font = Enum.Font.GothamBold
    heading.TextSize = 13
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.ZIndex = 251

    local subtitleBg = Instance.new("Frame", overlay)
    subtitleBg.Size = UDim2.new(0, 0, 0, 18)
    subtitleBg.AutomaticSize = Enum.AutomaticSize.X
    subtitleBg.AnchorPoint = Vector2.new(1, 0)
    subtitleBg.Position = UDim2.new(1, -56, 0, 15)
    subtitleBg.BackgroundColor3 = self._Colors.Bg
    subtitleBg.BackgroundTransparency = 0.4
    subtitleBg.BorderSizePixel = 0
    subtitleBg.ZIndex = 251
    Instance.new("UICorner", subtitleBg).CornerRadius = UDim.new(1, 0)

    local subPad = Instance.new("UIPadding", subtitleBg)
    subPad.PaddingLeft = UDim.new(0, 8)
    subPad.PaddingRight = UDim.new(0, 8)

    local subtitle = Instance.new("TextLabel", subtitleBg)
    subtitle.Size = UDim2.new(0, 0, 1, 0)
    subtitle.AutomaticSize = Enum.AutomaticSize.X
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "0 ACTIVE"
    subtitle.TextColor3 = self._Colors.TextDim
    subtitle.Font = Enum.Font.GothamBold
    subtitle.TextSize = 9
    subtitle.TextXAlignment = Enum.TextXAlignment.Center
    subtitle.TextYAlignment = Enum.TextYAlignment.Center
    subtitle.ZIndex = 252

    local closeButton = Instance.new("TextButton", overlay)
    closeButton.Name = "Close"
    closeButton.Size = UDim2.fromOffset(20, 20)
    closeButton.Position = UDim2.new(1, -28, 0, 16)
    closeButton.BackgroundColor3 = self._Colors.Card
    closeButton.BackgroundTransparency = 0.6
    closeButton.Text = ""
    closeButton.AutoButtonColor = false
    closeButton.ZIndex = 252
    Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 4)

    local closeIcon = Instance.new("ImageLabel", closeButton)
    closeIcon.Size = UDim2.fromOffset(10, 10)
    closeIcon.Position = UDim2.new(0.5, -5, 0.5, -5)
    closeIcon.BackgroundTransparency = 1
    closeIcon.Image = GetIcon("x")
    closeIcon.ImageColor3 = self._Colors.TextDim
    closeIcon.ZIndex = 253

    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
        TweenService:Create(closeIcon, TweenInfo.new(0.15), {ImageColor3 = self._Colors.Text}):Play()
    end)
    closeButton.MouseLeave:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.6}):Play()
        TweenService:Create(closeIcon, TweenInfo.new(0.15), {ImageColor3 = self._Colors.TextDim}):Play()
    end)

    local divider = Instance.new("Frame", overlay)
    divider.Name = "Divider"
    divider.Size = UDim2.new(1, -32, 0, 1)
    divider.Position = UDim2.new(0, 16, 0, 48)
    divider.BackgroundColor3 = self._Colors.Border
    divider.BackgroundTransparency = 0.8
    divider.BorderSizePixel = 0
    divider.ZIndex = 251

    local list = Instance.new("ScrollingFrame", overlay)
    list.Name = "KeybindList"
    list.Size = UDim2.new(1, -16, 1, -64)
    list.Position = UDim2.new(0, 8, 0, 54)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 2
    list.ScrollBarImageColor3 = self._Colors.Accent
    list.ScrollBarImageTransparency = 0.5
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.ZIndex = 251
    self:_registerScrollFrame(list)
    local layout = Instance.new("UIListLayout", list)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    local listPad = Instance.new("UIPadding", list)
    listPad.PaddingTop = UDim.new(0, 4)
    listPad.PaddingBottom = UDim.new(0, 8)

    local emptyMessage = Instance.new("Frame", list)
    emptyMessage.Name = "EmptyMessage"
    emptyMessage.LayoutOrder = 0
    emptyMessage.Size = UDim2.new(1, -8, 0, 100)
    emptyMessage.BackgroundTransparency = 1
    emptyMessage.ZIndex = 252

    local emptyIcon = Instance.new("ImageLabel", emptyMessage)
    emptyIcon.Size = UDim2.fromOffset(32, 32)
    emptyIcon.Position = UDim2.new(0.5, -16, 0, 16)
    emptyIcon.BackgroundTransparency = 1
    emptyIcon.Image = GetIcon("keyboard")
    emptyIcon.ImageColor3 = self._Colors.TextDim
    emptyIcon.ImageTransparency = 0.5
    emptyIcon.ZIndex = 252

    local emptyText = Instance.new("TextLabel", emptyMessage)
    emptyText.Size = UDim2.new(1, -16, 0, 14)
    emptyText.Position = UDim2.new(0, 8, 0, 56)
    emptyText.BackgroundTransparency = 1
    emptyText.Text = "No keybinds assigned"
    emptyText.TextColor3 = self._Colors.TextDim
    emptyText.Font = Enum.Font.GothamMedium
    emptyText.TextSize = 11
    emptyText.TextXAlignment = Enum.TextXAlignment.Center
    emptyText.ZIndex = 252

    local toggle = Instance.new("TextButton", UI.MainGui)
    toggle.Name = "KeybindOverlayToggle"
    toggle.Size = UDim2.fromOffset(110, 34)
    toggle.AnchorPoint = Vector2.new(1, 1)
    toggle.Position = UDim2.new(1, -18, 1, -18)
    toggle.BackgroundColor3 = self._Colors.Bg2
    toggle.BackgroundTransparency = 0.15
    toggle.BorderSizePixel = 0
    toggle.Text = ""
    toggle.AutoButtonColor = false
    toggle.ZIndex = 253
    toggle.Visible = false
    -- Extra safety net: never let the pill appear on touch devices, even if a
    -- future code path forgets the mobile guard.
    if self._isMobile then
        toggle.Active = false
    end
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

    local toggleStroke = Instance.new("UIStroke", toggle)
    toggleStroke.Color = self._Colors.Border
    toggleStroke.Thickness = 1
    toggleStroke.Transparency = 0.6

    local toggleIcon = Instance.new("ImageLabel", toggle)
    toggleIcon.Size = UDim2.fromOffset(14, 14)
    toggleIcon.Position = UDim2.new(0, 14, 0.5, -7)
    toggleIcon.BackgroundTransparency = 1
    toggleIcon.Image = GetIcon("keyboard")
    toggleIcon.ImageColor3 = self._Colors.Accent

    local toggleText = Instance.new("TextLabel", toggle)
    toggleText.Size = UDim2.new(1, -40, 1, 0)
    toggleText.Position = UDim2.new(0, 34, 0, 0)
    toggleText.BackgroundTransparency = 1
    toggleText.Text = "KEYBINDS"
    toggleText.TextColor3 = self._Colors.Text
    toggleText.Font = Enum.Font.GothamBold
    toggleText.TextSize = 10
    toggleText.TextXAlignment = Enum.TextXAlignment.Left

    Fn.bindPressAnimation(toggle)

    toggle.MouseEnter:Connect(function()
        TweenService:Create(toggle, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
        TweenService:Create(toggleStroke, TweenInfo.new(0.15), {Transparency = 0.2, Color = self._Colors.Accent}):Play()
    end)
    toggle.MouseLeave:Connect(function()
        TweenService:Create(toggle, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
        TweenService:Create(toggleStroke, TweenInfo.new(0.15), {Transparency = 0.6, Color = self._Colors.Border}):Play()
    end)

    local overlayAnimating = false
    local overlayTween
    local function setOverlayVisible(want, animate)
        if overlayTween then pcall(function() overlayTween:Cancel() end) end
        overlayAnimating = false
        if not animate then
            overlay.Visible = want
            overlay.Position = UDim2.new(1, -18, 1, -58)
            overlay.BackgroundTransparency = want and 0.15 or 1
            return
        end
        if want == overlay.Visible then return end
        if want then
            overlay.Visible = true
            overlay.Position = UDim2.new(1, -18, 1, -48)
            overlay.BackgroundTransparency = 1
            overlayTween = TweenService:Create(overlay, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(1, -18, 1, -58),
                BackgroundTransparency = 0.15
            })
            overlayTween:Play()
        else
            overlayTween = TweenService:Create(overlay, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(1, -18, 1, -48),
                BackgroundTransparency = 1
            })
            overlayTween:Play()
            overlayTween.Completed:Connect(function(playbackState)
                if playbackState == Enum.PlaybackState.Cancelled then return end
                overlay.Visible = false
            end)
        end
    end
    local function toggleOverlay()
        if self._isMobile then return end  -- desktop-only overlay
        if overlayAnimating then return end
        overlayAnimating = true
        setOverlayVisible(not overlay.Visible, true)
        task.delay(0.2, function() overlayAnimating = false end)
    end
    self._setKeybindOverlayVisible = setOverlayVisible

    toggle.MouseButton1Click:Connect(toggleOverlay)
    closeButton.MouseButton1Click:Connect(toggleOverlay)

    UI.KeybindOverlay = overlay
    UI.KeybindOverlayList = list
    UI.KeybindOverlayEmpty = emptyMessage
    UI.KeybindOverlayToggle = toggle
    UI.KeybindOverlayStroke = stroke
    UI.KeybindOverlayToggleStroke = toggleStroke
    UI.KeybindOverlayToggleIcon = toggleIcon
    UI.KeybindOverlayToggleText = toggleText
    UI.KeybindOverlaySubtitle = subtitle
    UI.KeybindOverlayCloseIcon = closeIcon
    UI.KeybindOverlayDivider = divider
    UI.KeybindOverlayEmptyIcon = emptyIcon
    UI.KeybindOverlayEmptyText = emptyText

    self:_registerThemeRefresher(function()
        overlay.BackgroundColor3 = self._Colors.Bg2
        stroke.Color = self._Colors.Border
        heading.TextColor3 = self._Colors.Text
        subtitle.TextColor3 = self._Colors.TextDim
        subtitleBg.BackgroundColor3 = self._Colors.Bg
        emptyText.TextColor3 = self._Colors.TextDim
        emptyIcon.ImageColor3 = self._Colors.TextDim
        closeIcon.ImageColor3 = self._Colors.TextDim
        closeButton.BackgroundColor3 = self._Colors.Card
        divider.BackgroundColor3 = self._Colors.Border
        list.ScrollBarImageColor3 = self._Colors.Accent
        toggle.BackgroundColor3 = self._Colors.Bg2
        toggleStroke.Color = self._Colors.Border
        toggleIcon.ImageColor3 = self._Colors.Accent
        toggleText.TextColor3 = self._Colors.Text
        for _, row in pairs(self._STATE.KeybindOverlayRows) do
            if row.frame then row.frame.BackgroundColor3 = self._Colors.Card end
            if row.name then row.name.TextColor3 = self._Colors.Text end
            if row.keyBg then
                row.keyBg.BackgroundColor3 = self._Colors.Bg
                row.keyBg.UIStroke.Color = self._Colors.Border
            end
            if row.key then row.key.TextColor3 = self._Colors.Accent end
            if row.icon then row.icon.ImageColor3 = self._Colors.Accent end
        end
    end)
end

function Library:_refreshKeybindOverlay()
    local UI = self._UI
    local list = UI.KeybindOverlayList
    if not list then return end
    local count = #self._STATE.activeKeybindListeners
    UI.KeybindOverlayEmpty.Visible = count == 0
    if UI.KeybindOverlaySubtitle then
        if count == 0 then
            UI.KeybindOverlaySubtitle.Text = "0 ACTIVE"
        else
            UI.KeybindOverlaySubtitle.Text = tostring(count) .. " ACTIVE"
        end
    end
    for index, listener in ipairs(self._STATE.activeKeybindListeners) do
        local row = self._STATE.KeybindOverlayRows[listener]
        if not row or not row.frame.Parent then
            local frame = Instance.new("TextButton", list)
            frame.Name = "Keybind_" .. tostring(index)
            frame.LayoutOrder = index
            frame.Size = UDim2.new(1, -6, 0, 36)
            frame.BackgroundColor3 = self._Colors.Card
            frame.BackgroundTransparency = 1
            frame.Text = ""
            frame.AutoButtonColor = false
            frame.BorderSizePixel = 0
            frame.ZIndex = 252
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

            local icon = Instance.new("ImageLabel", frame)
            icon.Size = UDim2.fromOffset(14, 14)
            icon.Position = UDim2.new(0, 8, 0.5, -7)
            icon.BackgroundTransparency = 1
            icon.Image = GetIcon("command")
            icon.ImageColor3 = self._Colors.Accent
            icon.ZIndex = 253

            local name = Instance.new("TextLabel", frame)
            name.Name = "Action"
            name.Size = UDim2.new(1, -110, 1, 0)
            name.Position = UDim2.new(0, 30, 0, 0)
            name.BackgroundTransparency = 1
            name.TextColor3 = self._Colors.Text
            name.Font = Enum.Font.GothamMedium
            name.TextSize = 12
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextTruncate = Enum.TextTruncate.AtEnd
            name.ZIndex = 253

            -- Fluent Glass Keycap
            local keyBg = Instance.new("Frame", frame)
            keyBg.Name = "KeycapBg"
            keyBg.Size = UDim2.new(0, 0, 0, 24)
            keyBg.AutomaticSize = Enum.AutomaticSize.X
            keyBg.Position = UDim2.new(1, -8, 0.5, -12)
            keyBg.AnchorPoint = Vector2.new(1, 0)
            keyBg.BackgroundColor3 = self._Colors.Bg
            keyBg.BackgroundTransparency = 0.1
            keyBg.BorderSizePixel = 0
            keyBg.ZIndex = 253
            Instance.new("UICorner", keyBg).CornerRadius = UDim.new(0, 6)

            local keyPad = Instance.new("UIPadding", keyBg)
            keyPad.PaddingLeft = UDim.new(0, 8)
            keyPad.PaddingRight = UDim.new(0, 8)

            local keyStroke = Instance.new("UIStroke", keyBg)
            keyStroke.Color = self._Colors.Border
            keyStroke.Thickness = 1
            keyStroke.Transparency = 0.4

            local keyShadow = Instance.new("Frame", keyBg)
            keyShadow.Size = UDim2.new(1, 0, 0, 2)
            keyShadow.Position = UDim2.new(0, 0, 1, -2)
            keyShadow.BackgroundColor3 = Color3.new(0, 0, 0)
            keyShadow.BackgroundTransparency = 0.6
            keyShadow.BorderSizePixel = 0
            keyShadow.ZIndex = 252
            Instance.new("UICorner", keyShadow).CornerRadius = UDim.new(0, 2)

            local key = Instance.new("TextLabel", keyBg)
            key.Name = "Shortcut"
            key.Size = UDim2.new(0, 0, 1, 0)
            key.AutomaticSize = Enum.AutomaticSize.X
            key.BackgroundTransparency = 1
            key.TextColor3 = self._Colors.Accent
            key.Font = Enum.Font.GothamBold
            key.TextSize = 10
            key.TextXAlignment = Enum.TextXAlignment.Center
            key.ZIndex = 254

            frame.MouseEnter:Connect(function()
                TweenService:Create(frame, TweenInfo.new(0.15), {BackgroundTransparency = 0.85}):Play()
            end)
            frame.MouseLeave:Connect(function()
                TweenService:Create(frame, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
            end)

            row = {
                frame = frame,
                icon = icon,
                name = name,
                keyBg = keyBg,
                key = key,
            }
            self._STATE.KeybindOverlayRows[listener] = row
        end
        row.frame.LayoutOrder = index
        row.name.Text = listener.name
        row.key.Text = listener.keyName or "None"
    end
end

function Library:_initTooltip()
    local UI = self._UI
    -- MOBILE: tooltips need a hover state, and a finger has none. Tapping a
    -- control would flash a panel that covers the very control being pressed,
    -- so tooltips are hard-disabled on touch devices (the Theme Customizer
    -- toggle can no longer re-enable them there, it just reports the reason).
    if self._isMobile or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
        self._STATE.TooltipForceDisabled = true
        self._STATE.TooltipEnabled = false
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "DoD_UI_Tooltip"
    gui.Parent = GuiParent
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 9999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    UI.TooltipGui = gui

    local frame = Instance.new("Frame", gui)
    frame.Name = "Tooltip"
    frame.BackgroundColor3 = self._Colors.Bg2
    frame.BackgroundTransparency = self._STATE.TooltipTransparency or 0.15
    frame.BorderSizePixel = 0
    frame.Size = UDim2.fromOffset(120, 26)
    frame.Visible = false
    frame.ZIndex = 100
    frame.ClipsDescendants = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = self._Colors.Border
    stroke.Thickness = 1
    stroke.Transparency = 0.55

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextColor3 = self._Colors.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = ""
    label.ZIndex = 102

    local hint = Instance.new("TextLabel", frame)
    hint.Name = "Hint"
    hint.Size = UDim2.new(1, -16, 0, 11)
    hint.Position = UDim2.new(0, 8, 0, 22)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.GothamMedium
    hint.TextSize = 9
    hint.TextColor3 = self._Colors.TextDim
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextTruncate = Enum.TextTruncate.AtEnd
    hint.Text = ""
    hint.Visible = false
    hint.ZIndex = 102

    UI.TooltipFrame = frame
    UI.TooltipLabel = label
    UI.TooltipHint = hint
    UI.TooltipStroke = stroke

    self:_registerThemeRefresher(function()
        if not frame.Parent then return end
        frame.BackgroundColor3 = self._Colors.Bg2
        stroke.Color = self._Colors.Border
        label.TextColor3 = self._Colors.Text
        hint.TextColor3 = self._Colors.TextDim
    end)

    Fn.track(UserInputService.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            self:_updateTooltipPosition(input.Position)
        end
    end, self)
end

function Library:_updateTooltipPosition(mousePos, width, height)
    local frame = self._UI.TooltipFrame
    if not frame or not frame.Visible then return end
    local cam = getCam()
    if not cam then return end
    local vp = cam.ViewportSize
    -- Use the size we just assigned when the caller knows it: AbsoluteSize is
    -- only recomputed on the next render step, so flipping against it places
    -- wide tooltips half off-screen right after a resize.
    local fw = width or frame.AbsoluteSize.X
    local fh = height or frame.AbsoluteSize.Y
    if fw <= 0 then fw = 120 end
    if fh <= 0 then fh = 28 end
    local x = mousePos.X + 18
    local y = mousePos.Y + 22
    if x + fw > vp.X - 8 then x = mousePos.X - fw - 18 end
    if y + fh > vp.Y - 8 then y = mousePos.Y - fh - 14 end
    x = math.clamp(x, 8, math.max(8, vp.X - fw - 8))
    y = math.clamp(y, 8, math.max(8, vp.Y - fh - 8))
    frame.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end

function Library:_tooltipsAvailable()
    if not self._STATE then return false end
    if self._STATE.TooltipForceDisabled then return false end
    return self._STATE.TooltipEnabled == true
end

function Library:_resetTooltipText()
    local lbl = self._UI.TooltipLabel
    if lbl then lbl.Text = "" end
    local hint = self._UI.TooltipHint
    if hint then
        hint.Text = ""
        hint.Visible = false
    end
end

function Library:_hideTooltip(instant)
    local frame = self._UI.TooltipFrame
    if not frame then return end
    local stroke = self._UI.TooltipStroke
    self:_resetTooltipText()
    if instant then
        frame.Visible = false
        frame.BackgroundTransparency = 1
        if stroke then stroke.Transparency = 1 end
        return
    end
    TweenService:Create(frame, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
    if stroke then TweenService:Create(stroke, TweenInfo.new(0.1), {Transparency = 1}):Play() end
    task.delay(0.12, function()
        if frame and frame.Parent and frame.BackgroundTransparency >= 0.9 then
            frame.Visible = false
        end
    end)
end

function Library:SetTooltipEnabled(enabled)
    if self:_isDead() then return end
    if self._STATE.TooltipForceDisabled then
        self._STATE.TooltipEnabled = false
        self:_hideTooltip(true)
        if enabled then
            self:Notify("TOOLTIP", "Tooltip dimatikan di mobile", "info")
        end
        return
    end
    self._STATE.TooltipEnabled = enabled and true or false
    if self._STATE.TooltipEnabled then return end
    self:_hideTooltip(true)
end

function Library:SetTooltipTransparency(transparency)
    if self:_isDead() then return end
    local trans = math.clamp(tonumber(transparency) or 0.15, 0, 1)
    self._STATE.TooltipTransparency = trans
    local frame = self._UI.TooltipFrame
    if frame and frame.Visible then
        frame.BackgroundTransparency = trans
    end
end

function Library:_bindTooltip(element, text)
    if not text or text == "" then return end
    -- Mobile / touch: never wire hover handlers at all.
    if self._STATE.TooltipForceDisabled then return end
    local favoritable = false
    local cur = element
    while cur do
        if cur:GetAttribute("DoD_CtrlId") then
            favoritable = true
            break
        end
        cur = cur.Parent
    end
    local showThread
    local function cancelShow()
        if showThread then
            pcall(task.cancel, showThread)
            showThread = nil
        end
    end

    element.MouseEnter:Connect(function()
        if not self:_tooltipsAvailable() then return end
        if self._STATE.AnimatingGui then return end
        if self._keybindCapturing then return end
        cancelShow()
        -- Any pending "hide" from the control we just left is now stale.
        self._tooltipSerial = (self._tooltipSerial or 0) + 1
        local serial = self._tooltipSerial
        showThread = task.delay(0.3, function()
            showThread = nil
            if serial ~= self._tooltipSerial then return end
            if self:_isDead() then return end
            if not self:_tooltipsAvailable() then return end
            local frame = self._UI.TooltipFrame
            local lbl = self._UI.TooltipLabel
            local hint = self._UI.TooltipHint
            local stroke = self._UI.TooltipStroke
            if not (frame and lbl) then return end
            lbl.Text = tostring(text)
            local charCount = utf8.len(tostring(text)) or #tostring(text)
            local w = math.clamp(charCount * 6.5 + 24, 90, 300)
            local h
            if favoritable then
                w = math.max(w, 200)
                h = 40
                frame.Size = UDim2.fromOffset(w, h)
                lbl.Size = UDim2.new(1, -16, 0, 16)
                lbl.Position = UDim2.new(0, 8, 0, 5)
                if hint then
                    hint.Text = self._isMobile and "Long-press to favorite" or "Right-click to favorite"
                    hint.Visible = true
                end
            else
                h = 26
                frame.Size = UDim2.fromOffset(w, h)
                lbl.Size = UDim2.new(1, -16, 1, 0)
                lbl.Position = UDim2.new(0, 8, 0, 0)
                if hint then
                    hint.Visible = false
                    hint.Text = ""
                end
            end
            frame.Visible = true
            frame.BackgroundTransparency = 1
            if stroke then stroke.Transparency = 1 end
            local targetTrans = self._STATE.TooltipTransparency or 0.15
            TweenService:Create(frame, TweenInfo.new(0.15), {BackgroundTransparency = targetTrans}):Play()
            if stroke then
                TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.55}):Play()
            end
            self:_updateTooltipPosition(UserInputService:GetMouseLocation(), w, h)
        end)
    end)

    element.MouseLeave:Connect(function()
        cancelShow()
        self._tooltipSerial = (self._tooltipSerial or 0) + 1
        local serial = self._tooltipSerial
        task.delay(0.12, function()
            -- A new control got hovered inside the grace period: keep its tooltip.
            if serial ~= self._tooltipSerial then return end
            self:_hideTooltip(false)
        end)
    end)
end

function Library:_bindToggleKey()
    Fn.track(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if self._keybindCapturing then return end
        if input.KeyCode == self.ToggleKey then
            self:Toggle()
        end
    end, self)
    Fn.track(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed then return end
        -- Right-click favoriting is a desktop affordance; on touch it would fire
        -- on taps that belong to the control, and inside a TextBox it fires on
        -- the context-menu paste click.
        if self._isMobile then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
        if not self._STATE.GuiVisible then return end
        local mc = self._UI.MainContainer
        if not (mc and mc.Visible) then return end
        local mp = UserInputService:GetMouseLocation()
        local mcp, mcs = mc.AbsolutePosition, mc.AbsoluteSize
        if mp.X < mcp.X or mp.X > mcp.X + mcs.X or mp.Y < mcp.Y or mp.Y > mcp.Y + mcs.Y then
            return
        end
        local holders = self._STATE.FavoriteHolders
        if not holders or next(holders) == nil then return end
        for configId, holder in pairs(holders) do
            if holder and holder.Parent then
                local p, s = holder.AbsolutePosition, holder.AbsoluteSize
                if mp.X >= p.X and mp.X <= p.X + s.X and mp.Y >= p.Y and mp.Y <= p.Y + s.Y then
                    if self._STATE.Favorites[configId] then
                        self._STATE.Favorites[configId] = nil
                    else
                        self._STATE.Favorites[configId] = true
                    end
                    self:_updateFavoriteStar(configId)
                    self:_applySearchFilter()
                    self:_triggerAutoSave()
                    break
                end
            end
        end
    end, self)
    if self._isMobile then
        local tp0 = 0
        local tpos0 = Vector2.zero
        local thid = nil
        Fn.track(UserInputService.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            if not self._STATE.GuiVisible then return end
            local mc = self._UI.MainContainer
            if not (mc and mc.Visible) then return end
            tpos0 = Vector2.new(input.Position.X, input.Position.Y)
            local mcp, mcs = mc.AbsolutePosition, mc.AbsoluteSize
            if tpos0.X < mcp.X or tpos0.X > mcp.X + mcs.X or tpos0.Y < mcp.Y or tpos0.Y > mcp.Y + mcs.Y then
                thid = nil
                return
            end
            tp0 = os.clock()
            thid = nil
            local holders = self._STATE.FavoriteHolders
            if not holders or next(holders) == nil then return end
            for configId, holder in pairs(holders) do
                if holder and holder.Parent then
                    local p, s = holder.AbsolutePosition, holder.AbsoluteSize
                    if tpos0.X >= p.X and tpos0.X <= p.X + s.X and tpos0.Y >= p.Y and tpos0.Y <= p.Y + s.Y then
                        thid = configId
                        break
                    end
                end
            end
        end, self)
        Fn.track(UserInputService.InputEnded, function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            if not thid then return end
            local dur = os.clock() - tp0
            local endPos = Vector2.new(input.Position.X, input.Position.Y)
            local moved = (endPos - tpos0).Magnitude
            if dur >= 0.5 and moved < 14 then
                if self._STATE.Favorites[thid] then
                    self._STATE.Favorites[thid] = nil
                else
                    self._STATE.Favorites[thid] = true
                end
                self:_updateFavoriteStar(thid)
                self:_applySearchFilter()
                self:_triggerAutoSave()
            end
            thid = nil
        end, self)
    end
end

function Library:SetVersion(text)
    if self:_isDead() then return end
    self.Version = tostring(text or "")
    if self._UI.TitleVersionBadge then
        self._UI.TitleVersionBadge.Text = self.Version
    end
end

function Library:SetVersionBadgeColor(color)
    if self:_isDead() then return end
    if typeof(color) ~= "Color3" then
        error("[DoD UI] SetVersionBadgeColor expects a Color3 value.")
    end
    self._VersionBadgeOverride = color
    -- Was a full SetTheme() rebuild (every refresher + a config write) for one
    -- BackgroundColor3.
    local badge = self._UI.TitleVersionBadge
    if badge then
        badge.BackgroundColor3 = color
        badge.TextColor3 = Fn.contrastForeground(color)
    end
end

function Library:SetToggleKey(key)
    if self:_isDead() then return end
    if typeof(key) ~= "EnumItem" or key.EnumType ~= Enum.KeyCode then
        error("[DoD UI] SetToggleKey expects an Enum.KeyCode.")
    end
    self.ToggleKey = key
    if self._UI.TitleToggleHint then
        self._UI.TitleToggleHint.Text = key.Name
    end
    self:Notify("KEYBIND", "Toggle GUI: " .. key.Name)
end

function Library:_generateAutoTheme(imageStr)
    if not self.AutoTheme then return end
    if not imageStr then return end
    
    local hash = 0
    for i = 1, #imageStr do
        hash = (hash + (string.byte(imageStr, i) * i)) % 360
    end
    local h1 = hash / 360
    local h2 = (hash + 45) / 360
    if h2 > 1 then h2 = h2 - 1 end

    D.Themes["Auto"] = {
        Accent = Color3.fromHSV(h1, 0.7, 0.9),
        Accent2 = Color3.fromHSV(h2, 0.8, 0.8),
        Bg = Color3.fromHSV(h1, 0.4, 0.08),
        Bg2 = Color3.fromHSV(h1, 0.4, 0.12),
        Card = Color3.fromHSV(h1, 0.35, 0.18),
        Sidebar = Color3.fromHSV(h1, 0.4, 0.06),
        Border = Color3.fromHSV(h1, 0.4, 0.3),
        Text = Color3.fromHSV(h1, 0.05, 0.95),
        TextDim = Color3.fromHSV(h1, 0.15, 0.65),
        FocusOverlayColor = Color3.fromHSV(h1, 0.5, 0.05),
        OverlayTransparency = 0.4
    }
    self._autoThemeApplied = true
    self:SetTheme("Auto", true)
end

function Library:_wallpaperCachePath(url)
    local hash = 0
    for i = 1, #url do
        hash = (hash * 31 + string.byte(url, i)) % 2147483647
    end
    return "DoD_Wallpaper_" .. tostring(hash) .. ".url"
end

function Library:_getCachedWallpaper(url)
    if type(url) ~= "string" then return nil end
    self._wallpaperCache = self._wallpaperCache or {}
    if self._wallpaperCache[url] then return self._wallpaperCache[url] end
    local cacheFile = self:_wallpaperCachePath(url)
    local cached = nil
    pcall(function()
        if isfile and type(isfile) == "function" and readfile and type(readfile) == "function" then
            if isfile(cacheFile) then
                cached = readfile(cacheFile)
            end
        end
    end)
    if cached then self._wallpaperCache[url] = cached end
    return cached
end

function Library:_setWallpaperCache(url, result)
    if type(url) ~= "string" or type(result) ~= "string" then return end
    self._wallpaperCache = self._wallpaperCache or {}
    self._wallpaperCache[url] = result
    local cacheFile = self:_wallpaperCachePath(url)
    pcall(function()
        if writefile and type(writefile) == "function" then
            writefile(cacheFile, result)
        end
    end)
end

function Library:ClearWallpaperCache()
    if self:_isDead() then return end
    local removed = 0
    pcall(function()
        if listfiles and type(listfiles) == "function" and delfile and type(delfile) == "function" then
            for _, f in ipairs(listfiles()) do
                local base = string.match(tostring(f), "[^\\/]+$") or tostring(f)
                if string.find(base, "DoD_Wallpaper_", 1, true) then
                    pcall(delfile, f)
                    removed = removed + 1
                end
            end
        end
    end)
    self:Notify("WALLPAPER", "Cleared " .. removed .. " cached entries", "success")
end

function Library:SetWallpaper(assetId, transparency)
    if self:_isDead() then return end
    local UI = self._UI
    if not UI.Wallpaper then return end
    if assetId == nil or assetId == "" then
        UI.Wallpaper.Visible = false
        -- Also drop the texture reference and the palette it generated, otherwise
        -- "remove wallpaper" left both applied.
        pcall(function() UI.Wallpaper.Image = "" end)
        if self._autoThemeApplied then
            self._autoThemeApplied = false
            pcall(function() self:SetTheme("Demon of Darkness", true) end)
        end
        self.WallpaperSource = nil
        return
    end
    
    local img = tostring(assetId)
    
    local trans = math.clamp(transparency or 0, 0, 1)

    if string.sub(img, 1, 4) == "http" then
        if string.sub(img, 1, 8) ~= "https://" then
            self:Notify("WALLPAPER", "Only https:// URLs allowed", "error")
            return
        end
        if not (getcustomasset and writefile and type(writefile) == "function") then
            self:Notify("WALLPAPER", "Executor tidak support getcustomasset/writefile", "error")
            return
        end
        
        -- Reuse the cached asset for this URL instead of re-downloading a
        -- multi-megabyte image every time it is selected.
        local cachedAsset = self:_getCachedWallpaper(img)
        if type(cachedAsset) == "string" and cachedAsset ~= "" then
            UI.Wallpaper.Image = cachedAsset
            UI.Wallpaper.ImageTransparency = trans
            UI.Wallpaper.Visible = true
            self:Notify("WALLPAPER", "Wallpaper restored from cache", "info")
            return
        end

        self:Notify("WALLPAPER", "Downloading...", "info")
        if self.ShowLoading then self:ShowLoading("Downloading wallpaper...") end
        
        task.spawn(function()
            local timedOut = false
            local watchdog = task.delay(10, function()
                if timedOut then return end
                timedOut = true
                if self.HideLoading then self:HideLoading() end
                if self:_isDead() then return end
                self:Notify("WALLPAPER", "Download timeout (>10s) — server slow or unreachable", "error")
            end)
            local success, content = pcall(function()
                return game:HttpGet(img, true)
            end)
            if watchdog then pcall(task.cancel, watchdog) end
            if timedOut or self:_isDead() then return end
            
            if not success or type(content) ~= "string" or #content == 0 then
                if self.HideLoading then self:HideLoading() end
                self:Notify("WALLPAPER", "Download gagal — Cek URL GitHub (mungkin 404/private)", "error")
                return
            end
            
            local ext = ".jpg"
            local lowerImg = string.lower(img)
            if string.find(lowerImg, ".gif") then ext = ".gif"
            elseif string.find(lowerImg, ".png") then ext = ".png"
            elseif string.find(lowerImg, ".webp") then ext = ".webp"
            end
            -- Deterministic, hash-based filename: the old random name leaked a new
            -- multi-MB file into the executor folder on every single download.
            local baseName = self:_wallpaperCachePath(img):gsub("%.url$", "")
            local fileName = baseName .. ext
            
            -- 🧹 Auto-cleanup: Delete old wallpaper files so it only keeps 1.
            if listfiles and delfile then
                pcall(function()
                    for _, f in ipairs(listfiles()) do
                        local base = string.match(tostring(f), "[^\\/]+$") or tostring(f)
                        if string.find(base, "DoD_Wallpaper_", 1, true) 
                           and base ~= fileName 
                           and base ~= (baseName .. ".url") then
                            delfile(f)
                        end
                    end
                end)
            end

            local writeOk = pcall(function()
                writefile(fileName, content)
            end)
            
            if not writeOk then
                if self.HideLoading then self:HideLoading() end
                self:Notify("WALLPAPER", "Gagal simpan file ke executor", "error")
                return
            end
            
            local assetOk, assetContent = pcall(getcustomasset, fileName)
            if self.HideLoading then self:HideLoading() end
            if self:_isDead() then return end
            
            if not assetOk or type(assetContent) ~= "string" then
                self:Notify("WALLPAPER", "Gagal load file lokal ke Roblox", "error")
                return
            end
            pcall(function() self:_setWallpaperCache(img, assetContent) end)
            
            local setOk = pcall(function()
                UI.Wallpaper.Image = assetContent
                UI.Wallpaper.ImageTransparency = trans
                UI.Wallpaper.Visible = true
            end)
            
            if setOk then
                self:Notify("WALLPAPER", "Wallpaper applied", "success")
                self:_generateAutoTheme(img)
            else
                self:Notify("WALLPAPER", "Gagal apply gambar ke UI", "error")
            end
        end)
        return
    elseif string.sub(img, 1, 13) == "rbxassetid://" or string.sub(img, 1, 9) == "rbxasset:" then
        UI.Wallpaper.Image = img
    elseif img:match("^%d+$") then
        UI.Wallpaper.Image = "rbxassetid://" .. img
    else
        -- A path or a stray string used to become the broken
        -- "rbxassetid://some/path.png" with no feedback.
        self:Notify("WALLPAPER", "Invalid wallpaper id/URL: " .. tostring(img), "error")
        return
    end
    
    UI.Wallpaper.ImageTransparency = trans
    UI.Wallpaper.Visible = true
    self:_generateAutoTheme(img)
end

function Library:SetCursorIcon(assetId)
    if self:_isDead() then return end
    local raw = tostring(assetId or "")
    if raw == "" then return end
    local img
    if tonumber(raw) then
        img = "rbxassetid://" .. raw
    elseif raw:match("^rbxasset") then
        img = raw
    elseif raw:match("^https?://") then
        img = raw
    else
        -- Accept icon names too (consistent with SetTitleIcon); a bare name used
        -- to become the broken "rbxassetid://shield".
        img = GetIcon(raw)
    end
    if self._UI.CustomCursor then
        self._UI.CustomCursor.Image = img
    end
end

function Library:SetCursorTrail(enabled)
    if self:_isDead() then return end
    if type(enabled) ~= "boolean" then
        error("[DoD UI] SetCursorTrail expects a boolean value.")
    end
    self._cursorTrailEnabled = enabled
    if enabled then
        -- The perf profile used to latch this block on and never release it, so
        -- the public setter (and the Theme Customizer toggle) did nothing.
        -- An explicit user request always wins over the automatic tier.
        self._perfCursorBlocked = false
        self._cursorTrailPrevPos = UserInputService:GetMouseLocation()
        self._cursorTrailSpawnDist = 0
    else
        for _, dot in ipairs(self._cursorTrailPool or {}) do
            dot.active = false
            if dot.img then dot.img.Visible = false end
        end
    end
end

function Library:SetCursorTrailColor(color)
    if self:_isDead() then return end
    if typeof(color) ~= "Color3" then
        error("[DoD UI] SetCursorTrailColor expects a Color3 value.")
    end
    self._cursorTrailColor = color
    for _, dot in ipairs(self._cursorTrailPool or {}) do
        if dot.img then dot.img.ImageColor3 = color end
    end
end

function Library:_initCursorTrail()
    if self._cursorTrailPool then return end
    local UI = self._UI
    if not UI.MainGui then return end
    if self._cursorTrailEnabled == nil then self._cursorTrailEnabled = false end
    if self._cursorTrailColor == nil then self._cursorTrailColor = Color3.fromRGB(0, 255, 255) end
    self._cursorTrailPool = {}
    self._cursorTrailTexture = "rbxassetid://5029929719"
    self._cursorTrailSpawnDist = 0
    self._cursorTrailPrevPos = Vector2.zero
    for i = 1, 28 do
        local img = Instance.new("ImageLabel", UI.MainGui)
        img.Name = "CursorTrail_" .. tostring(i)
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Size = UDim2.fromOffset(32, 32)
        img.BackgroundTransparency = 1
        img.Image = self._cursorTrailTexture
        img.ImageColor3 = self._cursorTrailColor
        img.ImageTransparency = 1
        img.Visible = false
        img.ZIndex = 99999
        img.ScaleType = Enum.ScaleType.Fit
        img.Active = false
        table.insert(self._cursorTrailPool, {
            img = img,
            active = false,
            spawnedAt = 0,
            life = 0.5,
            baseSize = 32,
            x = 0,
            y = 0,
            offsetX = 0,
            offsetY = 0,
            spin = 0,
            pulsePhase = 0,
        })
    end
end

function Library:_spawnCursorTrailDot(pos, now)
    if not self._cursorTrailPool then return end
    local dot = nil
    for _, d in ipairs(self._cursorTrailPool) do
        if not d.active then dot = d; break end
    end
    if not dot then
        local oldest = math.huge
        for _, d in ipairs(self._cursorTrailPool) do
            if d.spawnedAt < oldest then
                oldest = d.spawnedAt
                dot = d
            end
        end
    end
    if not dot then return end
    dot.active = true
    dot.spawnedAt = now
    dot.x = pos.X
    dot.y = pos.Y
    dot.pulsePhase = math.random() * math.pi * 2
    dot.spin = (math.random() - 0.5) * 1.6
    dot.baseSize = math.random(22, 42)
    dot.offsetX = (math.random() - 0.5) * 18
    dot.offsetY = (math.random() - 0.5) * 18
    dot.life = 0.42 + math.random() * 0.28
    dot.img.Visible = true
    dot.img.ImageColor3 = self._cursorTrailColor
    dot.img.ImageTransparency = 0.15
    dot.img.Size = UDim2.fromOffset(dot.baseSize, dot.baseSize)
    dot.img.Position = UDim2.fromOffset(pos.X + dot.offsetX, pos.Y + dot.offsetY)
    dot.img.Rotation = 0
end

function Library:_updateCursorTrail(mouse)
    if not self._cursorTrailEnabled then return end
    if self._perfCursorBlocked then return end
    if not self._cursorTrailPool then return end
    if self._isMobile then return end
    if not self._UI.CustomCursor or not self._UI.CustomCursor.Visible then
        for _, _dot in ipairs(self._cursorTrailPool) do
            if _dot.active then
                _dot.active = false
                if _dot.img then _dot.img.Visible = false end
            end
        end
        return
    end
    local now = os.clock()
    local pos = Vector2.new(mouse.X, mouse.Y)
    local moved = (pos - self._cursorTrailPrevPos).Magnitude
    self._cursorTrailPrevPos = pos
    if moved > 2.5 and moved < 200 then
        self._cursorTrailSpawnDist = self._cursorTrailSpawnDist + moved
        local threshold = 7
        local spawned = 0
        while self._cursorTrailSpawnDist >= threshold and spawned < 4 do
            self._cursorTrailSpawnDist = self._cursorTrailSpawnDist - threshold
            self:_spawnCursorTrailDot(pos, now)
            spawned = spawned + 1
        end
    else
        self._cursorTrailSpawnDist = 0
    end
    if SharedReduced.value then return end
    local baseR = self._cursorTrailColor.R
    local baseG = self._cursorTrailColor.G
    local baseB = self._cursorTrailColor.B
    for _, dot in ipairs(self._cursorTrailPool) do
        if dot.active then
            local age = now - dot.spawnedAt
            if age >= dot.life then
                dot.active = false
                dot.img.Visible = false
            else
                local t = age / dot.life
                local alpha = 1 - t
                local pulse = math.sin(now * 5 + dot.pulsePhase) * 0.35 + 0.65
                local boost = 1 + pulse * 0.35
                dot.img.ImageColor3 = Color3.new(
                    math.min(baseR * boost, 1),
                    math.min(baseG * boost, 1),
                    math.min(baseB * boost, 1)
                )
                local sz = dot.baseSize * (0.4 + alpha * 0.6)
                dot.img.ImageTransparency = 0.1 + t * 0.85
                dot.img.Size = UDim2.fromOffset(sz, sz)
                dot.img.Position = UDim2.fromOffset(
                    dot.x + dot.offsetX * (1 - t),
                    dot.y + dot.offsetY * (1 - t)
                )
                dot.img.Rotation = dot.spin * t * 180
            end
        end
    end
end

function Library:AddTitleButton(iconName, tooltip, callback)
    if self:_isDead() then return end
    local UI = self._UI
    if not UI.TitleCustomIcons then return end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(24, 24)
    btn.BackgroundColor3 = self._Colors.Card
    btn.BackgroundTransparency = 0.8
    btn.Text = ""
    btn.Parent = UI.TitleCustomIcons
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = self._Colors.Border
    stroke.Thickness = 1
    stroke.Transparency = 0.8

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.fromOffset(14, 14)
    icon.Position = UDim2.new(0.5, -7, 0.5, -7)
    icon.BackgroundTransparency = 1
    icon.Image = GetIcon(iconName)
    icon.ImageColor3 = self._Colors.TextDim
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = btn

    Fn.bindPressAnimation(btn)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.3, Color = self._Colors.Accent}):Play()
        TweenService:Create(icon, TweenInfo.new(0.15), {ImageColor3 = self._Colors.Accent}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.8}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.8, Color = self._Colors.Border}):Play()
        TweenService:Create(icon, TweenInfo.new(0.15), {ImageColor3 = self._Colors.TextDim}):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        self:PlaySound("Click")
        if callback then callback() end
    end)

    if tooltip and tooltip ~= "" then
        self:_bindTooltip(btn, tooltip)
    end

    self:_registerThemeRefresher(function()
        btn.BackgroundColor3 = self._Colors.Card
        stroke.Color = self._Colors.Border
        icon.ImageColor3 = self._Colors.TextDim
    end)

    return btn
end

function Library:SetTitleIcon(iconName)
    if self:_isDead() then return end
    if type(iconName) ~= "string" or iconName == "" then
        error("[DoD UI] SetTitleIcon expects a non-empty icon name string.")
    end
    self._TitleIconName = iconName
    
    local finalImage = iconName
    local lower = string.lower(iconName)
    
    if tonumber(iconName) then
        finalImage = "rbxassetid://" .. iconName
    elseif string.sub(lower, 1, 4) == "http" or string.sub(lower, 1, 11) == "rbxassetid:" or string.sub(lower, 1, 11) == "rbxasset://" then
        -- 11, not 10: the literal "rbxassetid:" is 11 characters, so the old
        -- 10-char comparison could never be true and asset ids were ignored.
        finalImage = iconName
    else
        finalImage = GetIcon(iconName)
    end
    
    if self._UI.TitleLogoIcon then
        self._UI.TitleLogoIcon.Image = finalImage
    end
end

-- Removed _initProfileCard

function Library:CreateKeybindOverlay()
    if self:_isDead() then return end
    self:_refreshKeybindOverlay()
    -- Desktop-only toggle; mobile skips showing it but still returns the
    -- overlay instance so callers that expect a return value do not crash.
    if not self._isMobile then
        self._UI.KeybindOverlayToggle.Visible = true
    end
    return self._UI.KeybindOverlay
end

function Library:SetKeybindOverlayVisible(visible)
    if self:_isDead() then return end
    if type(visible) ~= "boolean" then
        error("[DoD UI] SetKeybindOverlayVisible expects a boolean value.")
    end
    -- Keybind overlay does not exist on touch: honour the call silently instead
    -- of flickering a panel that has no reason to be there.
    if self._isMobile then return end
    -- Route through the animated setter so a click-tween in flight cannot hide
    -- the overlay right after the caller asked for it to be shown.
    if self._setKeybindOverlayVisible then
        self._setKeybindOverlayVisible(visible, false)
    elseif self._UI.KeybindOverlay then
        self._UI.KeybindOverlay.Visible = visible
    end
end

-- =========================================================
-- TITLE BAR
-- =========================================================

function Library:_initTitleBar()
    local UI = self._UI
    UI.TitleBar = Instance.new("Frame", UI.MainContainer)
    UI.TitleBar.Size = UDim2.new(1, 0, 0, 42)
    UI.TitleBar.BackgroundColor3 = self._Colors.Bg2
    UI.TitleBar.BorderSizePixel = 0
    Instance.new("UICorner", UI.TitleBar).CornerRadius = UDim.new(0, 14)

    UI.TitleGradient = Instance.new("UIGradient", UI.TitleBar)
    UI.TitleGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, self._Colors.Accent),
        ColorSequenceKeypoint.new(1, self._Colors.Accent2),
    })
    UI.TitleGradient.Rotation = 90
    UI.TitleGradient.Transparency = NumberSequence.new(0.85)

    -- Modern Glass Logo
    local logoBadge = Instance.new("Frame", UI.TitleBar)
    logoBadge.Name = "TitleLogoBadge"
    logoBadge.Size = UDim2.fromOffset(24, 24)
    logoBadge.Position = UDim2.new(0, 12, 0.5, -12)
    logoBadge.BackgroundColor3 = Color3.new(1, 1, 1)
    logoBadge.BackgroundTransparency = 0.88
    logoBadge.BorderSizePixel = 0
    Instance.new("UICorner", logoBadge).CornerRadius = UDim.new(0, 8)

    local logoStroke = Instance.new("UIStroke", logoBadge)
    logoStroke.Color = Color3.new(1, 1, 1)
    logoStroke.Thickness = 1
    logoStroke.Transparency = 0.85

    local logoIcon = Instance.new("ImageLabel", logoBadge)
    logoIcon.Name = "Icon"
    logoIcon.Size = UDim2.fromOffset(14, 14)
    logoIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    logoIcon.BackgroundTransparency = 1
    local iconName = self._TitleIconName
    local lowerIcon = string.lower(iconName)
    if tonumber(iconName) then
        logoIcon.Image = "rbxassetid://" .. iconName
    elseif string.sub(lowerIcon, 1, 4) == "http" or string.sub(lowerIcon, 1, 11) == "rbxassetid:" or string.sub(lowerIcon, 1, 11) == "rbxasset://" then
        logoIcon.Image = iconName
    else
        logoIcon.Image = GetIcon(iconName)
    end
    logoIcon.ImageColor3 = self._Colors.Accent
    logoIcon.ScaleType = Enum.ScaleType.Fit

    local logoScale = Instance.new("UIScale", logoBadge)
    logoScale.Scale = 1

    logoBadge.MouseEnter:Connect(function()
        TweenService:Create(logoScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.08}):Play()
        TweenService:Create(logoStroke, TweenInfo.new(0.15), {Transparency = 0}):Play()
    end)
    logoBadge.MouseLeave:Connect(function()
        TweenService:Create(logoScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
        TweenService:Create(logoStroke, TweenInfo.new(0.15), {Transparency = 0.85}):Play()
    end)

    UI.TitleLogoBadge = logoBadge
    UI.TitleLogoStroke = logoStroke
    UI.TitleLogoIcon = logoIcon

    local mainTitle, subTitle = self.Title:match("^(.-)%s*|%s*(.+)$")
    if not mainTitle then
        mainTitle = self.Title
        subTitle = ""
    end

    UI.TitleLabel = Instance.new("TextLabel", UI.TitleBar)
    UI.TitleLabel.Size = UDim2.new(0, 200, 1, 0)
    UI.TitleLabel.Position = UDim2.new(0, 46, 0, 0)
    UI.TitleLabel.BackgroundTransparency = 1
    UI.TitleLabel.Text = mainTitle
    UI.TitleLabel.TextColor3 = self._Colors.Text
    UI.TitleLabel.Font = Enum.Font.GothamBlack
    UI.TitleLabel.TextSize = 14
    UI.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    UI.TitleLabel.TextYAlignment = Enum.TextYAlignment.Center

    UI.TitleSubtitle = Instance.new("TextLabel", UI.TitleBar)
    UI.TitleSubtitle.Size = UDim2.new(0, 200, 1, 0)
    UI.TitleSubtitle.Position = UDim2.new(0, 46, 0, 0)
    UI.TitleSubtitle.BackgroundTransparency = 1
    UI.TitleSubtitle.Text = subTitle
    UI.TitleSubtitle.TextColor3 = self._Colors.TextDim
    UI.TitleSubtitle.Font = Enum.Font.GothamMedium
    UI.TitleSubtitle.TextSize = 12
    UI.TitleSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    UI.TitleSubtitle.TextYAlignment = Enum.TextYAlignment.Center

    -- Glass Pill Version
    UI.TitleVersionBadge = Instance.new("TextLabel", UI.TitleBar)
    UI.TitleVersionBadge.Size = UDim2.new(0, 0, 0, 18)
    UI.TitleVersionBadge.AutomaticSize = Enum.AutomaticSize.X
    UI.TitleVersionBadge.Position = UDim2.new(0, 170, 0.5, -9)
    UI.TitleVersionBadge.BackgroundColor3 = self._Colors.Accent
    UI.TitleVersionBadge.BackgroundTransparency = 0.85
    UI.TitleVersionBadge.Text = self.Version
    UI.TitleVersionBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
    UI.TitleVersionBadge.Font = Enum.Font.GothamBold
    UI.TitleVersionBadge.TextSize = 10
    UI.TitleVersionBadge.BorderSizePixel = 0
    Instance.new("UICorner", UI.TitleVersionBadge).CornerRadius = UDim.new(1, 0)

    local vPad = Instance.new("UIPadding", UI.TitleVersionBadge)
    vPad.PaddingLeft = UDim.new(0, 8)
    vPad.PaddingRight = UDim.new(0, 8)

    UI.TitleDiscord = Instance.new("TextLabel", UI.TitleBar)
    UI.TitleDiscord.Size = UDim2.new(0, 0, 1, 0)
    UI.TitleDiscord.AutomaticSize = Enum.AutomaticSize.X
    UI.TitleDiscord.Position = UDim2.new(1, -230, 0, 0)
    UI.TitleDiscord.BackgroundTransparency = 1
    UI.TitleDiscord.Text = "<i>" .. self.Author .. "</i>"
    UI.TitleDiscord.RichText = true
    UI.TitleDiscord.TextColor3 = self._Colors.TextDim
    UI.TitleDiscord.Font = Enum.Font.GothamBold
    UI.TitleDiscord.TextSize = 12
    UI.TitleDiscord.TextXAlignment = Enum.TextXAlignment.Right

    -- Custom Title Elements Container (Right side)
    local customContainer = Instance.new("Frame", UI.TitleBar)
    customContainer.Name = "TitleCustomIcons"
    customContainer.Size = UDim2.new(0, 0, 0, 24)
    customContainer.AutomaticSize = Enum.AutomaticSize.X
    customContainer.AnchorPoint = Vector2.new(1, 0.5)
    customContainer.Position = UDim2.new(1, -200, 0.5, 0)
    customContainer.BackgroundTransparency = 1
    customContainer.ZIndex = 10

    local customLayout = Instance.new("UIListLayout", customContainer)
    customLayout.FillDirection = Enum.FillDirection.Horizontal
    customLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    customLayout.Padding = UDim.new(0, 6)

    UI.TitleCustomIcons = customContainer

    -- Keybind Hint Box
    local hintBg = Instance.new("TextButton", UI.TitleBar)
    hintBg.Name = "TitleToggleHintBg"
    hintBg.Size = UDim2.new(0, 0, 0, 20)
    hintBg.AutomaticSize = Enum.AutomaticSize.X
    hintBg.Position = UDim2.new(1, -300, 0.5, -10)
    hintBg.BackgroundColor3 = self._Colors.Bg
    hintBg.BackgroundTransparency = 0.5
    hintBg.BorderSizePixel = 0
    hintBg.Text = ""
    hintBg.AutoButtonColor = false
    Instance.new("UICorner", hintBg).CornerRadius = UDim.new(0, 4)

    local hintStroke = Instance.new("UIStroke", hintBg)
    hintStroke.Color = self._Colors.Border
    hintStroke.Transparency = 0.5
    hintStroke.Thickness = 1

    local hintPad = Instance.new("UIPadding", hintBg)
    hintPad.PaddingLeft = UDim.new(0, 6)
    hintPad.PaddingRight = UDim.new(0, 6)

    UI.TitleToggleHint = Instance.new("TextLabel", hintBg)
    UI.TitleToggleHint.AutomaticSize = Enum.AutomaticSize.X
    UI.TitleToggleHint.Size = UDim2.new(0, 0, 1, 0)
    UI.TitleToggleHint.BackgroundTransparency = 1
    UI.TitleToggleHint.Text = self.ToggleKey.Name
    UI.TitleToggleHint.TextColor3 = self._Colors.TextDim
    UI.TitleToggleHint.Font = Enum.Font.GothamMedium
    UI.TitleToggleHint.TextSize = 10
    UI.TitleToggleHint.TextXAlignment = Enum.TextXAlignment.Center
    UI.TitleToggleHint.TextYAlignment = Enum.TextYAlignment.Center
    
    UI.TitleToggleHintBg = hintBg

    if self._isMobile then hintBg.Visible = false end
    hintBg.MouseEnter:Connect(function()
        TweenService:Create(hintBg, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
        TweenService:Create(hintStroke, TweenInfo.new(0.15), {Transparency = 0.2, Color = self._Colors.Accent}):Play()
    end)
    hintBg.MouseLeave:Connect(function()
        TweenService:Create(hintBg, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(hintStroke, TweenInfo.new(0.15), {Transparency = 0.5, Color = self._Colors.Border}):Play()
    end)

    local isListening = false
    local _hintConn = nil
    local function _endHintListen()
        isListening = false
        if _hintConn then
            pcall(function() _hintConn:Disconnect() end)
            _hintConn = nil
        end
    end
    hintBg.MouseButton1Click:Connect(function()
        if isListening then
            _endHintListen()
            UI.TitleToggleHint.Text = self.ToggleKey.Name
            UI.TitleToggleHint.TextColor3 = self._Colors.TextDim
            return
        end
        isListening = true
        UI.TitleToggleHint.Text = "PRESS KEY..."
        UI.TitleToggleHint.TextColor3 = self._Colors.Accent
        _hintConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                self:SetToggleKey(input.KeyCode)
                UI.TitleToggleHint.TextColor3 = self._Colors.TextDim
                _endHintListen()
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
                UI.TitleToggleHint.Text = self.ToggleKey.Name
                UI.TitleToggleHint.TextColor3 = self._Colors.TextDim
                _endHintListen()
            end
        end)
    end)

    self:_registerThemeRefresher(function()
        if UI.CustomCursor then
            UI.CustomCursor.ImageColor3 = self._Colors.Accent
        end
        if UI.TitleToggleHint then
            UI.TitleToggleHint.TextColor3 = self._Colors.TextDim
        end
        if hintStroke then
            hintStroke.Color = self._Colors.Border
        end
        if hintBg then
            hintBg.BackgroundColor3 = self._Colors.Bg
        end
        if UI.TitleSubtitle then
            UI.TitleSubtitle.TextColor3 = self._Colors.TextDim
        end
        if logoIcon then
            logoIcon.ImageColor3 = self._Colors.Accent
        end
    end)

    local function updateTitleLayout()
        local width = UI.MainContainer.AbsoluteSize.X
        if width <= 0 then width = 640 end
        
        local tlWidth = 76
        UI.TitleDiscord.Visible = width >= 560
        local authorW = 0
        if UI.TitleDiscord.Visible then
            authorW = UI.TitleDiscord.AbsoluteSize.X
            if authorW <= 0 then authorW = 50 end
            UI.TitleDiscord.Position = UDim2.new(1, -tlWidth - authorW - 12, 0, 0)
        end

        local hintW = UI.TitleToggleHintBg.AbsoluteSize.X
        if self._isMobile then hintW = 0 elseif hintW <= 0 then hintW = 40 end
        local hintOffset = tlWidth + (authorW > 0 and authorW + 28 or 0)
        UI.TitleToggleHintBg.Position = UDim2.new(1, -hintOffset - hintW, 0.5, -10)

        local customW = UI.TitleCustomIcons.AbsoluteSize.X
        if customW <= 0 then customW = 0 end
        local customOffset = hintOffset + hintW + (customW > 0 and 16 or 0)
        UI.TitleCustomIcons.Position = UDim2.new(1, -customOffset - customW, 0.5, 0)

        local maxTitleWidth = math.clamp(width - 420, 80, 300)
        
        local mainTextW = UI.TitleLabel.TextBounds.X
        if mainTextW <= 0 then
            mainTextW = #UI.TitleLabel.Text * 7.5
        end
        mainTextW = math.min(mainTextW, maxTitleWidth)
        UI.TitleLabel.Size = UDim2.new(0, mainTextW, 1, 0)
        
        local subTextW = 0
        if UI.TitleSubtitle.Text ~= "" then
            subTextW = UI.TitleSubtitle.TextBounds.X
            if subTextW <= 0 then subTextW = #UI.TitleSubtitle.Text * 6 end
            local maxSubWidth = math.max(10, maxTitleWidth - mainTextW - 8)
            subTextW = math.min(subTextW, maxSubWidth)
            UI.TitleSubtitle.Size = UDim2.new(0, subTextW, 1, 0)
            UI.TitleSubtitle.Position = UDim2.new(0, 46 + mainTextW + 8, 0, 0)
            UI.TitleSubtitle.Visible = true
        else
            UI.TitleSubtitle.Visible = false
        end

        local badgeW = UI.TitleVersionBadge.AbsoluteSize.X
        if badgeW <= 0 then badgeW = 40 end
        local badgeStart = 46 + mainTextW + (subTextW > 0 and subTextW + 12 or 10)
        local badgeEnd = badgeStart + badgeW

        local hintStart = width - hintOffset - hintW
        local canShowBadge = width >= 420 and (badgeEnd + 16) < hintStart

        UI.TitleVersionBadge.Visible = canShowBadge
        UI.TitleVersionBadge.Position = UDim2.new(0, badgeStart, 0.5, -9)
    end
    updateTitleLayout()
    task.defer(updateTitleLayout)
    task.delay(0.15, updateTitleLayout)
    Fn.track(UI.MainContainer:GetPropertyChangedSignal("AbsoluteSize"), updateTitleLayout, self)
    Fn.track(UI.TitleVersionBadge:GetPropertyChangedSignal("AbsoluteSize"), updateTitleLayout, self)
    Fn.track(UI.TitleToggleHintBg:GetPropertyChangedSignal("AbsoluteSize"), updateTitleLayout, self)
end

function Library:_initTrafficLights()
    local UI = self._UI
    local container = Instance.new("Frame", UI.TitleBar)
    container.Name = "TrafficLights"
    local _isMobTL = self._isMobile
    local _tlDot = _isMobTL and 20 or 14
    local _tlSpace = _isMobTL and 26 or 18
    local _tlTotal = _tlDot + _tlSpace * 2
    container.Size = UDim2.fromOffset(_tlTotal, _tlDot)
    container.Position = UDim2.new(1, -(_tlTotal + 14), 0.5, -(_tlDot / 2))
    container.BackgroundTransparency = 1

    local baseColors = {
        Color3.fromRGB(255, 95, 86),
        Color3.fromRGB(255, 189, 46),
        Color3.fromRGB(39, 201, 63),
    }
    local hoverColors = {
        Color3.fromRGB(255, 130, 122),
        Color3.fromRGB(255, 205, 90),
        Color3.fromRGB(60, 220, 80),
    }
    UI.TrafficDots = {}
    local isMobile = _isMobTL
    local dotSize = _tlDot
    local dotSpacing = _tlSpace
    for i = 1, 3 do
        local dot = Instance.new("TextButton", container)
        dot.Size = UDim2.new(0, dotSize, 0, dotSize)
        dot.Position = UDim2.new(0, (i - 1) * dotSpacing, 0, 0)
        dot.BackgroundColor3 = baseColors[i]
        dot.Text = ""
        dot.BorderSizePixel = 0
        dot.AutoButtonColor = false
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        Fn.bindPressAnimation(dot)
        dot.MouseEnter:Connect(function() dot.BackgroundColor3 = hoverColors[i] end)
        dot.MouseLeave:Connect(function() dot.BackgroundColor3 = baseColors[i] end)
        table.insert(UI.TrafficDots, dot)
    end

    UI.TrafficDots[1].MouseButton1Click:Connect(function()
        self:Destroy()
    end)

    self._hudState    = "NORMAL"
    self._hudNormalSize = self.WindowSize
    self._hudNormalPos  = UDim2.new(0.5, 0, 0.5, 0)

    local hudTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local function hideChildren(visible)
        local layoutOwned = {}
        if UI.BottomPill then layoutOwned[UI.BottomPill] = true end
        if UI.SideProfileMini then layoutOwned[UI.SideProfileMini] = true end
        if UI.AccordionScroll then layoutOwned[UI.AccordionScroll] = true end
        if UI.SearchBar then layoutOwned[UI.SearchBar] = true end
        for _, child in ipairs(UI.MainContainer:GetChildren()) do
            -- Layout-owned widgets are managed by _applyNavigationLayout; blindly
            -- restoring them painted the bottom pill / profile card over the
            -- category bar after maximize -> restore.
            if child:IsA("GuiObject") and child ~= UI.TitleBar and not layoutOwned[child] then
                if child == UI.AcrylicTexture or child == UI.AcrylicSheen then
                    child.Visible = visible and self.Acrylic
                else
                    child.Visible = visible
                end
            end
        end
        if UI.ParticleBG then
            UI.ParticleBG.Visible = visible and self._STATE.GuiVisible
        end
        if UI.SnowLayer then
            UI.SnowLayer.Visible = visible and self._STATE.GuiVisible and self._STATE.WeatherEnabled
        end
        if UI.MobileToggle then
            UI.MobileToggle.Visible = visible and UserInputService.TouchEnabled
        end
        if UI.KeybindOverlay then
            UI.KeybindOverlay.Visible = visible and not self._isMobile
                and self._keybindOverlayWasVisible == true
        end
        if UI.KeybindOverlayToggle then
            UI.KeybindOverlayToggle.Visible = visible and not self._isMobile
                and #self._STATE.activeKeybindListeners > 0
        end
        if self._STATE.ContentPages then
            for name, page in pairs(self._STATE.ContentPages) do
                if page then
                    page.Visible = visible and (name == self._STATE.ActiveTab)
                end
            end
        end
    end

    local function applyHudState(target)
        if self._hudState == target then return end
        -- Resolve the camera before committing state, otherwise a missing camera
        -- left _hudState = MAXIMIZED while the window was never resized.
        local camera
        if target == "MAXIMIZED" then
            camera = getCam()
            if not camera then return end
        end
        local prev = self._hudState
        self._hudState = target

        if prev == "NORMAL" then
            self._hudNormalSize = UI.MainContainer.Size
            self._hudNormalPos  = UI.MainContainer.Position
        end

        if target == "MINIMIZED" then
            hideChildren(false)
            if UI.FocusOverlay then
                self._focusOverlayWasVisible = UI.FocusOverlay.Visible
                UI.FocusOverlay.Visible = false
            end
            if UI.KeybindOverlay then
                self._keybindOverlayWasVisible = UI.KeybindOverlay.Visible
                UI.KeybindOverlay.Visible = false
            end
            local curr = UI.MainContainer.Size
            TweenService:Create(UI.MainContainer, hudTweenInfo, {
                Size = UDim2.new(curr.X.Scale, curr.X.Offset, 0, 42),
            }):Play()
        elseif target == "MAXIMIZED" then
            local vp = camera.ViewportSize
            TweenService:Create(UI.MainContainer, hudTweenInfo, {
                Size = UDim2.new(0, math.max(1, vp.X - 40), 0, math.max(1, vp.Y - 40)),
                Position = UDim2.new(0.5, 0, 0.5, 0),
            }):Play()
        else -- NORMAL
            local tw = TweenService:Create(UI.MainContainer, hudTweenInfo, {
                Size = self._hudNormalSize,
                Position = self._hudNormalPos,
            })
            tw.Completed:Connect(function(playbackState)
                if playbackState == Enum.PlaybackState.Cancelled then return end
                if self._hudState ~= "NORMAL" then return end
                hideChildren(true)
                self:_applyNavigationLayout()
                if self._STATE.FocusOverlayEnabled and self._STATE.GuiVisible and UI.FocusOverlay then
                    UI.FocusOverlay.Visible = true
                end
                if UI.KeybindOverlay and self._keybindOverlayWasVisible and not self._isMobile then
                    UI.KeybindOverlay.Visible = true
                    self._keybindOverlayWasVisible = false
                end
            end)
            tw:Play()
        end
    end

    UI.TrafficDots[2].MouseButton1Click:Connect(function()
        self:Minimize()
    end)

    UI.TrafficDots[3].MouseButton1Click:Connect(function()
        if self._hudState == "MAXIMIZED" then
            applyHudState("NORMAL")
        else
            applyHudState("MAXIMIZED")
        end
    end)
end

-- =========================================================
-- CATEGORY BAR + SUB-TAB HOST
-- =========================================================

function Library:_initSidebar()
    local UI = self._UI

    UI.CategoryBar = Instance.new("Frame", UI.MainContainer)
    UI.CategoryBar.Size = UDim2.new(1, -20, 0, 46)
    UI.CategoryBar.Position = UDim2.new(0, 10, 0, 42)
    UI.CategoryBar.BackgroundColor3 = self._Colors.Sidebar
    UI.CategoryBar.BackgroundTransparency = 0.35
    UI.CategoryBar.BorderSizePixel = 0
    UI.CategoryBar.ClipsDescendants = true
    Instance.new("UICorner", UI.CategoryBar).CornerRadius = UDim.new(0, 14)
    UI.CategoryBarStroke = Instance.new("UIStroke", UI.CategoryBar)
    UI.CategoryBarStroke.Color = self._Colors.Border
    UI.CategoryBarStroke.Thickness = 1
    UI.CategoryBarStroke.Transparency = 1

    UI.Sidebar = Instance.new("Frame", UI.MainContainer)
    UI.Sidebar.Size = UDim2.new(1, -20, 0, 30)
    UI.Sidebar.Position = UDim2.new(0, 10, 0, 94)
    UI.Sidebar.BackgroundColor3 = self._Colors.Sidebar
    UI.Sidebar.BackgroundTransparency = 1
    UI.Sidebar.BorderSizePixel = 0
    UI.Sidebar.ClipsDescendants = true
    Instance.new("UICorner", UI.Sidebar).CornerRadius = UDim.new(0, 10)

    UI.TabBarDivider = Instance.new("Frame", UI.MainContainer)
    UI.TabBarDivider.Size = UDim2.new(1, -20, 0, 1)
    UI.TabBarDivider.Position = UDim2.new(0, 10, 0, 124)
    UI.TabBarDivider.BackgroundColor3 = self._Colors.Border
    UI.TabBarDivider.BackgroundTransparency = 0.5
    UI.TabBarDivider.BorderSizePixel = 0

    local accordionScroll = Instance.new("ScrollingFrame", UI.CategoryBar)
    accordionScroll.Name = "AccordionScroll"
    accordionScroll.Position = UDim2.new(0, 6, 0, 56)
    accordionScroll.Size = UDim2.new(1, -12, 1, -114)
    accordionScroll.BackgroundTransparency = 1
    accordionScroll.BorderSizePixel = 0
    accordionScroll.ScrollBarThickness = 2
    accordionScroll.ScrollBarImageColor3 = self._Colors.Accent
    accordionScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    accordionScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    accordionScroll.Visible = false
    accordionScroll.ZIndex = 5

    local asLayout = Instance.new("UIListLayout", accordionScroll)
    asLayout.SortOrder = Enum.SortOrder.LayoutOrder
    asLayout.Padding = UDim.new(0, 4)

    local asPad = Instance.new("UIPadding", accordionScroll)
    asPad.PaddingTop = UDim.new(0, 4)
    asPad.PaddingBottom = UDim.new(0, 8)
    asPad.PaddingLeft = UDim.new(0, 4)
    asPad.PaddingRight = UDim.new(0, 4)

    UI.AccordionScroll = accordionScroll
    self:_attachScrollSound(accordionScroll)

    local miniProfile = Instance.new("Frame", UI.CategoryBar)
    miniProfile.Name = "SideProfileMini"
    miniProfile.Size = UDim2.new(1, -16, 0, 36)
    miniProfile.Position = UDim2.new(0, 8, 1, -44)
    miniProfile.BackgroundColor3 = self._Colors.Card
    miniProfile.BackgroundTransparency = 0.5
    miniProfile.BorderSizePixel = 0
    miniProfile.Visible = false
    miniProfile.ZIndex = 10
    Instance.new("UICorner", miniProfile).CornerRadius = UDim.new(0, 8)

    local spStroke = Instance.new("UIStroke", miniProfile)
    spStroke.Color = self._Colors.Border
    spStroke.Thickness = 1
    spStroke.Transparency = 0.5

    local spAvatar = Instance.new("ImageLabel", miniProfile)
    spAvatar.Name = "Avatar"
    spAvatar.Size = UDim2.fromOffset(22, 22)
    spAvatar.Position = UDim2.new(0, 8, 0.5, -11)
    spAvatar.BackgroundColor3 = self._Colors.Bg2
    spAvatar.BorderSizePixel = 0
    spAvatar.ZIndex = 11
    spAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150&filters=circular"
    Instance.new("UICorner", spAvatar).CornerRadius = UDim.new(1, 0)

    local spName = Instance.new("TextLabel", miniProfile)
    spName.Name = "Name"
    spName.Size = UDim2.new(1, -44, 1, 0)
    spName.Position = UDim2.new(0, 36, 0, 0)
    spName.BackgroundTransparency = 1
    spName.Text = LocalPlayer.Name
    spName.TextColor3 = self._Colors.Text
    spName.Font = Enum.Font.GothamBold
    spName.TextSize = 12
    spName.TextXAlignment = Enum.TextXAlignment.Left
    spName.TextTruncate = Enum.TextTruncate.AtEnd
    spName.ZIndex = 11

    UI.SideProfileMini = miniProfile
    UI.SideProfileAvatar = spAvatar
    UI.SideProfileName = spName
    UI.SideProfileStroke = spStroke

    UI.BottomPill = Instance.new("Frame", UI.CategoryBar)
    UI.BottomPill.Name = "BottomPill"
    UI.BottomPill.Size = UDim2.new(0, 110, 0, 36)
    UI.BottomPill.Position = UDim2.new(0, 0, 0.5, -18)
    UI.BottomPill.BackgroundColor3 = self._Colors.Card
    UI.BottomPill.BackgroundTransparency = 0.4
    UI.BottomPill.BorderSizePixel = 0
    UI.BottomPill.ZIndex = 0
    UI.BottomPill.Visible = false
    Instance.new("UICorner", UI.BottomPill).CornerRadius = UDim.new(1, 0)
    UI.BottomPillStroke = Instance.new("UIStroke", UI.BottomPill)
    UI.BottomPillStroke.Color = self._Colors.Accent
    UI.BottomPillStroke.Thickness = 1.2
    UI.BottomPillStroke.Transparency = 0.3

    self:_registerThemeRefresher(function()
        if not miniProfile.Parent then return end
        miniProfile.BackgroundColor3 = self._Colors.Card
        spStroke.Color = self._Colors.Border
        spName.TextColor3 = self._Colors.Text
        spAvatar.BackgroundColor3 = self._Colors.Bg2
        if accordionScroll and accordionScroll.Parent then
            accordionScroll.ScrollBarImageColor3 = self._Colors.Accent
        end
        if UI.BottomPill and UI.BottomPill.Parent then
            UI.BottomPill.BackgroundColor3 = self._Colors.Card
            if UI.BottomPillStroke then UI.BottomPillStroke.Color = self._Colors.Accent end
        end
    end)
end

function Library:_applyNavigationLayout()
    local UI = self._UI
    if not (UI.CategoryBar and UI.Sidebar and UI.TabBarDivider) then return end
    UI.Sidebar.Visible = true
    UI.TabBarDivider.Visible = true
    local position = self.TabPosition
    local mainSize = UI.MainContainer.AbsoluteSize
    local mainW = mainSize.X
    local mainH = mainSize.Y
    local sideWidth = math.min(self.TabWidth + 20, math.max(120, mainW * 0.36))
    local hasSearch  = UI.SearchBar ~= nil
    local hasContent = UI.ContentArea ~= nil

    local BOTTOM_PADDING = 15

    if position == "Side" then
        if hasSearch and UI.SearchBar.Parent ~= UI.CategoryBar then
            UI.SearchBar.Parent = UI.CategoryBar
        end
        UI.CategoryBar.Size = UDim2.new(0, sideWidth, 1, -62)
        UI.CategoryBar.Position = UDim2.new(0, 10, 0, 50)
        UI.CategoryBar.BackgroundColor3 = self._Colors.Sidebar
        UI.CategoryBar.BackgroundTransparency = 0.35
        UI.CategoryBarStroke.Transparency = 0
        UI.CategoryBarStroke.Color = self._Colors.Border

        if hasSearch then
            UI.SearchBar.Size = UDim2.new(1, -16, 0, 32)
            UI.SearchBar.Position = UDim2.new(0, 8, 0, 8)
            if UI.SearchInput then
                UI.SearchInput.Size = UDim2.new(1, -82, 1, 0)
                UI.SearchInput.Position = UDim2.new(0, 36, 0, 0)
                UI.SearchInput.PlaceholderText = (sideWidth - 16) >= 130 and "Search..." or ""
            end
            if UI.SearchIcon then UI.SearchIcon.ZIndex = 2 end
            if UI.FavoritesToggle then
                UI.FavoritesToggle.Position = UDim2.new(1, -42, 0.5, -8)
                UI.FavoritesToggle.ZIndex = 4
            end
            local clearBtn = UI.SearchBar:FindFirstChild("ClearBtn")
            if clearBtn then
                clearBtn.Position = UDim2.new(1, -22, 0.5, -8)
                clearBtn.ZIndex = 4
            end
        end

        UI.Sidebar.Visible = false
        UI.TabBarDivider.Visible = false
        if UI.AccordionScroll then UI.AccordionScroll.Visible = true end
        if UI.SideProfileMini then UI.SideProfileMini.Visible = true end

        if hasContent then
            UI.ContentArea.Size = UDim2.new(1, -(sideWidth + 30), 1, -62)
            UI.ContentArea.Position = UDim2.new(0, sideWidth + 20, 0, 50)
        end
        if UI.BottomPill then UI.BottomPill.Visible = false end

    elseif position == "Bottom" then
        if hasSearch and UI.SearchBar.Parent ~= UI.MainContainer then
            UI.SearchBar.Parent = UI.MainContainer
        end
        UI.Sidebar.Visible = true
        UI.TabBarDivider.Visible = true
        if UI.AccordionScroll then UI.AccordionScroll.Visible = false end
        if UI.SideProfileMini then UI.SideProfileMini.Visible = false end
        if UI.BottomPill then UI.BottomPill.Visible = true end

        UI.CategoryBar.Size = UDim2.new(1, -20, 0, 56)
        UI.CategoryBar.Position = UDim2.new(0, 10, 1, -66)
        UI.CategoryBar.BackgroundColor3 = self._Colors.Card
        UI.CategoryBar.BackgroundTransparency = 0.05
        UI.CategoryBarStroke.Transparency = 0.2

        UI.Sidebar.Size = UDim2.new(1, -20, 0, 30)
        UI.Sidebar.Position = UDim2.new(0, 10, 0, 48)
        UI.TabBarDivider.Size = UDim2.new(1, -20, 0, 1)
        UI.TabBarDivider.Position = UDim2.new(0, 10, 0, 80)

        if hasSearch then
            UI.SearchBar.Size = UDim2.new(1, -30, 0, 28)
            UI.SearchBar.Position = UDim2.new(0, 15, 0, 86)
            if UI.SearchInput then UI.SearchInput.Size = UDim2.new(1, -100, 1, 0) end
            if UI.FavoritesToggle then UI.FavoritesToggle.Position = UDim2.new(1, -48, 0.5, -8) end
        end
        if hasContent then
            local contentTop = 119
            local bottomReserve = 56 + 10 + 10
            local contentH = math.max(120, mainH - contentTop - bottomReserve)
            UI.ContentArea.Size = UDim2.new(1, -30, 0, contentH)
            UI.ContentArea.Position = UDim2.new(0, 15, 0, contentTop)
        end

    else -- Top
        if UI.AccordionScroll then UI.AccordionScroll.Visible = false end
        if UI.SideProfileMini then UI.SideProfileMini.Visible = false end
        UI.CategoryBar.Size = UDim2.new(1, -20, 0, 46)
        UI.CategoryBar.Position = UDim2.new(0, 10, 0, 42)
        UI.CategoryBar.BackgroundColor3 = self._Colors.Sidebar
        UI.CategoryBar.BackgroundTransparency = 0.35
        UI.CategoryBarStroke.Transparency = 1

        UI.Sidebar.Size = UDim2.new(1, -20, 0, 30)
        UI.Sidebar.Position = UDim2.new(0, 10, 0, 94)
        UI.TabBarDivider.Size = UDim2.new(1, -20, 0, 1)
        UI.TabBarDivider.Position = UDim2.new(0, 10, 0, 124)

        if hasSearch then
            UI.SearchBar.Size = UDim2.new(1, -30, 0, 28)
            UI.SearchBar.Position = UDim2.new(0, 15, 0, 129)
            if UI.SearchInput then UI.SearchInput.Size = UDim2.new(1, -100, 1, 0) end
            if UI.FavoritesToggle then UI.FavoritesToggle.Position = UDim2.new(1, -48, 0.5, -8) end
        end
        if hasContent then
            local contentTop = 162
            local contentH = math.max(150, mainH - contentTop - BOTTOM_PADDING)
            UI.ContentArea.Size = UDim2.new(1, -30, 0, contentH)
            UI.ContentArea.Position = UDim2.new(0, 15, 0, contentTop)
        end
        if UI.BottomPill then UI.BottomPill.Visible = false end
    end

    self:_layoutCategoryButtons()
    self:_resizeSubTabs()

    local activeIsStandalone = false
    local activeCatName = self._STATE.ActiveCategory
    if activeCatName and self._STATE.CategoryButtons and self._STATE.CategoryButtons[activeCatName] then
        activeIsStandalone = self._STATE.CategoryButtons[activeCatName].isStandalone == true
    end
    if activeIsStandalone and position ~= "Side" then
        UI.Sidebar.Visible = false
        UI.TabBarDivider.Visible = false
        if hasSearch then
            local searchY = (position == "Top") and 94 or 86
            UI.SearchBar.Size = UDim2.new(1, -30, 0, 28)
            UI.SearchBar.Position = UDim2.new(0, 15, 0, searchY)
        end
        if hasContent then
            local contentTop = hasSearch and ((position == "Top") and 127 or 119) or ((position == "Top") and 94 or 86)
            local bottomReserve = (position == "Bottom") and 76 or BOTTOM_PADDING
            local contentH = math.max(120, mainH - contentTop - bottomReserve)
            UI.ContentArea.Size = UDim2.new(1, -30, 0, contentH)
            UI.ContentArea.Position = UDim2.new(0, 15, 0, contentTop)
        end
    end
end

function Library:_setAccordionState(categoryName, expanded)
    if self:_isDead() then return end
    local STATE = self._STATE
    local data = STATE.CategoryButtons and STATE.CategoryButtons[categoryName]
    if not data or not data.isAccordion then return end
    local wasExpanded = STATE.AccordionExpanded[categoryName] == true
    STATE.AccordionExpanded[categoryName] = expanded
    if expanded then
        data.tabList.Visible = true
        if not wasExpanded then
            data.tabList.Size = UDim2.new(1, 0, 0, 0)
        end
        task.defer(function()
            local targetH = data.layout.AbsoluteContentSize.Y + 4
            TweenService:Create(data.tabList, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, targetH)
            }):Play()
        end)
    else
        local tw = TweenService:Create(data.tabList, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, 0)
        })
        tw.Completed:Connect(function()
            if not STATE.AccordionExpanded[categoryName] then
                data.tabList.Visible = false
            end
        end)
        tw:Play()
    end
    if data.chevron then
        data.chevron.Image = GetIcon(expanded and "chevron-up" or "chevron-down")
    end
    if data.button and data.stroke then
        TweenService:Create(data.stroke, TweenInfo.new(0.18), {
            Transparency = expanded and 0.3 or 0.7,
            Color = expanded and self._Colors.Accent or self._Colors.Border,
        }):Play()
        TweenService:Create(data.button, TweenInfo.new(0.18), {
            BackgroundTransparency = expanded and 0.5 or 0.75,
        }):Play()
        if data.label then
            data.label.TextColor3 = expanded and self._Colors.Text or self._Colors.TextDim
            data.label.Font = expanded and Enum.Font.GothamBold or Enum.Font.GothamMedium
        end
        if data.icon then
            data.icon.ImageColor3 = expanded and self._Colors.Accent or self._Colors.TextDim
        end
        if data.chevron then
            data.chevron.ImageColor3 = expanded and self._Colors.Accent or self._Colors.TextDim
        end
    end
end

function Library:_resizeSubTabs()
    if self.TabPosition == "Side" then return end
    local subTabBar = self._STATE.SubTabBar
    local category = self._STATE.ActiveCategory
    if not subTabBar or not category then return end
    local tabs = self._STATE.CategoryTabs[category] or {}
    local tabCount = #tabs
    if tabCount == 0 then return end
    local availableWidth = self._UI.Sidebar.AbsoluteSize.X
    if availableWidth <= 0 then return end
    local gap = math.min(subTabBar.Padding, availableWidth / math.max(tabCount * 2 - 1, 1))
    local tabWidth = math.min(self.TabWidth, (availableWidth - gap * (tabCount - 1)) / tabCount)
    local minW = 64
    if (minW * tabCount + gap * (tabCount - 1)) <= availableWidth then
        tabWidth = math.max(tabWidth, minW)
    end
    subTabBar:Resize(tabWidth, gap)
end

-- =========================================================
-- SEARCH BAR
-- =========================================================

function Library:_initSearchBar()
    local UI = self._UI
    UI.SearchBar = Instance.new("Frame", UI.MainContainer)
    UI.SearchBar.Size = UDim2.new(1, -30, 0, 28)
    UI.SearchBar.Position = UDim2.new(0, 15, 0, 129)
    UI.SearchBar.BackgroundColor3 = self._Colors.Card
    UI.SearchBar.BackgroundTransparency = 0.15
    UI.SearchBar.BorderSizePixel = 0
    Instance.new("UICorner", UI.SearchBar).CornerRadius = UDim.new(1, 0)

    UI.SearchBarStroke = Instance.new("UIStroke", UI.SearchBar)
    UI.SearchBarStroke.Color = self._Colors.Border
    UI.SearchBarStroke.Thickness = 1.1
    UI.SearchBarStroke.Transparency = 0.25

    UI.SearchIcon = Instance.new("ImageLabel", UI.SearchBar)
    UI.SearchIcon.Size = UDim2.new(0, 14, 0, 14)
    UI.SearchIcon.Position = UDim2.new(0, 14, 0.5, -7)
    UI.SearchIcon.BackgroundTransparency = 1
    UI.SearchIcon.Image = GetIcon("search")
    UI.SearchIcon.ImageColor3 = self._Colors.TextDim
    UI.SearchIcon.ZIndex = 2

    UI.SearchInput = Instance.new("TextBox", UI.SearchBar)
    UI.SearchInput.Size = UDim2.new(1, -100, 1, 0)
    UI.SearchInput.Position = UDim2.new(0, 36, 0, 0)
    UI.SearchInput.BackgroundTransparency = 1
    UI.SearchInput.Text = ""
    UI.SearchInput.PlaceholderText = "Search settings..."
    UI.SearchInput.PlaceholderColor3 = self._Colors.TextDim
    UI.SearchInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    UI.SearchInput.TextStrokeTransparency = 1
    UI.SearchInput.Font = Enum.Font.GothamMedium
    UI.SearchInput.TextSize = 12
    UI.SearchInput.TextXAlignment = Enum.TextXAlignment.Left
    UI.SearchInput.ClearTextOnFocus = false
    UI.SearchInput.ReturnKeyType = Enum.ReturnKeyType.Search
    UI.SearchInput.ZIndex = 1

    local starBtn = Instance.new("TextButton", UI.SearchBar)
    starBtn.Name = "FavoritesToggle"
    starBtn.Size = UDim2.fromOffset(16, 16)
    starBtn.Position = UDim2.new(1, -48, 0.5, -8)
    starBtn.BackgroundTransparency = 1
    starBtn.Text = ""
    starBtn.AutoButtonColor = false
    starBtn.ZIndex = 4
    local starIcon = Instance.new("ImageLabel", starBtn)
    starIcon.Size = UDim2.fromScale(1, 1)
    starIcon.BackgroundTransparency = 1
    starIcon.Image = GetIcon("star")
    starIcon.ImageColor3 = self._Colors.TextDim
    starIcon.ImageTransparency = 0.4
    starBtn.MouseButton1Click:Connect(function()
        self:SetFavoritesOnly(not self._STATE.FavoritesOnly)
    end)
    UI.FavoritesToggle = starBtn
    UI.FavoritesToggleIcon = starIcon

    local clearBtn = Instance.new("TextButton", UI.SearchBar)
    clearBtn.Name = "ClearBtn"
    clearBtn.Size = UDim2.fromOffset(16, 16)
    clearBtn.Position = UDim2.new(1, -26, 0.5, -8)
    clearBtn.BackgroundTransparency = 1
    clearBtn.Text = ""
    clearBtn.AutoButtonColor = false
    clearBtn.Visible = false
    clearBtn.ZIndex = 4
    
    local clearIcon = Instance.new("ImageLabel", clearBtn)
    clearIcon.Size = UDim2.fromScale(1, 1)
    clearIcon.BackgroundTransparency = 1
    clearIcon.Image = GetIcon("x")
    clearIcon.ImageColor3 = self._Colors.TextDim

    clearBtn.MouseButton1Click:Connect(function()
        UI.SearchInput.Text = ""
    end)

    UI.SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
        self._STATE.SearchQuery = UI.SearchInput.Text
        clearBtn.Visible = #UI.SearchInput.Text > 0
        
        if self._searchDebounce then
            pcall(task.cancel, self._searchDebounce)
            self._searchDebounce = nil
        end
        self._searchDebounce = task.delay(0.15, function()
            self._searchDebounce = nil
            if self:_isDead() then return end
            local query = string.lower(self._STATE.SearchQuery or ""):match("^%s*(.-)%s*$")
            local currentTab = self._STATE.ActiveTab
            if #query >= 2 and currentTab and not self._autoJumping then
                local hasMatch = self:_countTabMatches(currentTab, query) > 0
                if not hasMatch then
                    -- Deterministic order: pairs() used to jump to an arbitrary
                    -- matching tab, and an error inside SwitchTab could strand
                    -- _autoJumping = true for the rest of the session.
                    local order = {}
                    for _, cat in ipairs(self._STATE.CategoryOrder or {}) do
                        for _, tn in ipairs(self._STATE.CategoryTabs[cat] or {}) do
                            order[#order + 1] = tn
                        end
                    end
                    if #order == 0 then
                        for tn in pairs(self._STATE.ContentPages) do
                            order[#order + 1] = tn
                        end
                        table.sort(order)
                    end
                    for _, tn in ipairs(order) do
                        if tn ~= currentTab and self._STATE.ContentPages[tn]
                            and self:_countTabMatches(tn, query) > 0 then
                            self._autoJumping = true
                            pcall(self.SwitchTab, self, tn)
                            self._autoJumping = false
                            return
                        end
                    end
                end
            end
            self:_applySearchFilter()
        end)
    end)

    local _searchSavedPos = nil
    UI.SearchInput.Focused:Connect(function()
        TweenService:Create(UI.SearchBarStroke, TweenInfo.new(0.22), {
            Color = self._Colors.Accent, Transparency = 0.1
        }):Play()
        if UserInputService.TouchEnabled and UI.MainContainer then
            _searchSavedPos = UI.MainContainer.Position
            local cam = getCam()
            if cam then
                local vp = cam.ViewportSize
                local absSize = UI.MainContainer.AbsoluteSize
                local shift = math.floor(vp.Y * 0.25)
                local maxShift = math.max(0, vp.Y * 0.5 - absSize.Y * 0.5 - 8)
                shift = math.min(shift, maxShift)
                local p = UI.MainContainer.Position
                TweenService:Create(UI.MainContainer, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset - shift),
                }):Play()
            end
        end
    end)
    UI.SearchInput.FocusLost:Connect(function()
        TweenService:Create(UI.SearchBarStroke, TweenInfo.new(0.22), {
            Color = self._Colors.Border, Transparency = 0.25
        }):Play()
        if _searchSavedPos and UI.MainContainer then
            TweenService:Create(UI.MainContainer, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = _searchSavedPos,
            }):Play()
            _searchSavedPos = nil
        end
    end)
end

function Library:_queueSearchFilter(tabName)
    if self:_isDead() then return end
    tabName = tabName or self._STATE.ActiveTab
    if not tabName then return end
    self._pendingSearchTabs = self._pendingSearchTabs or {}
    self._pendingSearchTabs[tabName] = true
    if self._searchFilterQueued then return end
    self._searchFilterQueued = true
    task.defer(function()
        self._searchFilterQueued = false
        local pending = self._pendingSearchTabs
        self._pendingSearchTabs = {}
        if self:_isDead() then return end
        for tn, _ in pairs(pending) do
            self:_applySearchFilter(tn)
        end
    end)
end

function Library:_countTabMatches(tabName, query)
    if not tabName or not query or query == "" then return 0 end
    local count = 0
    for _, sectionData in ipairs(self._STATE.SearchSections[tabName] or {}) do
        if sectionData.titleLower == nil then
            sectionData.titleLower = string.lower(sectionData.title or "")
        end
        if sectionData.summaryLower == nil then
            sectionData.summaryLower = string.lower(sectionData.summary or "")
        end
        local sectionMatch = string.find(sectionData.titleLower, query, 1, true)
            or string.find(sectionData.summaryLower, query, 1, true)
        if sectionMatch then
            count = count + 1
        else
            for _, control in ipairs(sectionData.controls) do
                if control.searchLower == nil then
                    control.searchLower = string.lower(control.searchText or "")
                end
                if string.find(control.searchLower, query, 1, true) then
                    count = count + 1
                    break
                end
            end
        end
    end
    local pool = self._STATE.SearchTopLevel and self._STATE.SearchTopLevel[tabName]
    if pool then
        for _, ctrl in ipairs(pool) do
            if ctrl.searchLower == nil then
                ctrl.searchLower = string.lower(ctrl.searchText or "")
            end
            if string.find(ctrl.searchLower, query, 1, true) then
                count = count + 1
            end
        end
    end
    return count
end

function Library:_applySearchFilter(tabName)
    local STATE = self._STATE
    tabName = tabName or STATE.ActiveTab
    if not tabName then return end

    local query = string.lower(STATE.SearchQuery or ""):match("^%s*(.-)%s*$")
    local searching = query ~= ""
    local favoritesOnly = STATE.FavoritesOnly == true
    local isFiltering = searching or favoritesOnly
    local totalMatches = 0

    for _, sectionData in ipairs(STATE.SearchSections[tabName] or {}) do
        if isFiltering and not sectionData.searching then
            sectionData.expandedBeforeSearch = sectionData.expanded
        end

        local sectionMatches = false
        if searching then
            if sectionData.titleLower == nil then
                sectionData.titleLower = string.lower(sectionData.title or "")
            end
            if sectionData.summaryLower == nil then
                sectionData.summaryLower = string.lower(sectionData.summary or "")
            end
            sectionMatches = string.find(sectionData.titleLower, query, 1, true) ~= nil
                or string.find(sectionData.summaryLower, query, 1, true) ~= nil
        end
        local anyControlMatches = false

        for _, control in ipairs(sectionData.controls) do
            if control.searchLower == nil then
                control.searchLower = string.lower(control.searchText or "")
            end
            local textMatch = not searching
                or sectionMatches
                or string.find(control.searchLower, query, 1, true) ~= nil
            local ctrlId = control.ctrlId
            local favMatch = not favoritesOnly or (ctrlId ~= nil and STATE.Favorites[ctrlId] ~= nil)
            local matches = textMatch and favMatch
            if matches then
                -- Only reparent on a state transition. Reparenting every control
                -- on every keystroke invalidated the whole tab's layout.
                if control.hidden then
                    control.hidden = false
                    if control.instance.Parent == nil and control.parent and control.parent.Parent then
                        control.instance.Parent = control.parent
                    end
                end
                anyControlMatches = true
            elseif not control.hidden then
                control.hidden = true
                control.instance.Parent = nil
            end
        end

        local sectionVisible
        if not isFiltering then
            sectionVisible = true
        elseif favoritesOnly and not searching then
            sectionVisible = anyControlMatches
        elseif searching and not favoritesOnly then
            sectionVisible = sectionMatches or anyControlMatches
        else
            sectionVisible = anyControlMatches
        end

        sectionData.section.Visible = sectionVisible
        local wantSectionHidden = isFiltering and not sectionVisible
        if wantSectionHidden and not sectionData.hidden then
            sectionData.hidden = true
            sectionData.section.Parent = nil
        elseif not wantSectionHidden and sectionData.hidden then
            sectionData.hidden = false
            if sectionData.section.Parent == nil
                and sectionData.parentColumn and sectionData.parentColumn.Parent then
                sectionData.section.Parent = sectionData.parentColumn
            end
        end
        if isFiltering and sectionVisible then totalMatches = totalMatches + 1 end

        if isFiltering then
            if sectionData.expanded ~= sectionVisible then
                sectionData.setExpanded(sectionVisible, false)
            end
        elseif sectionData.searching then
            if sectionData.expandedBeforeSearch ~= nil then
                sectionData.setExpanded(sectionData.expandedBeforeSearch, false)
                sectionData.expandedBeforeSearch = nil
            end
        end
        sectionData.searching = isFiltering
    end

    local pool = STATE.SearchTopLevel and STATE.SearchTopLevel[tabName]
    if pool then
        for _, ctrl in ipairs(pool) do
            if ctrl.searchLower == nil then
                ctrl.searchLower = string.lower(ctrl.searchText or "")
            end
            local textMatch = not searching
                or string.find(ctrl.searchLower, query, 1, true) ~= nil
            local ctrlId = ctrl.ctrlId
            local favMatch = not favoritesOnly or (ctrlId ~= nil and STATE.Favorites[ctrlId] ~= nil)
            local matches = textMatch and favMatch
            if matches then
                if ctrl.hidden then
                    ctrl.hidden = false
                    if ctrl.instance.Parent == nil and ctrl.parent and ctrl.parent.Parent then
                        ctrl.instance.Parent = ctrl.parent
                    end
                end
                if isFiltering then totalMatches = totalMatches + 1 end
            elseif not ctrl.hidden then
                ctrl.hidden = true
                ctrl.instance.Parent = nil
            end
        end
    end

    local page = STATE.ContentPages[tabName]
    if page then
        local emptyState = page:FindFirstChild("SearchEmptyState")
        local showEmpty = isFiltering and totalMatches == 0
        if showEmpty then
            local msg, iconName
            if searching and favoritesOnly then
                msg = "No favorites match '" .. query .. "'"
                iconName = "search"
            elseif searching then
                msg = "No results found for '" .. query .. "'"
                iconName = "search"
            else
                msg = "No favorites yet — right-click any control to favorite it"
                iconName = "star"
            end
            if not emptyState then
                emptyState = Instance.new("Frame", page)
                emptyState.Name = "SearchEmptyState"
                emptyState.Size = UDim2.new(1, 0, 0, 100)
                emptyState.BackgroundTransparency = 1
                emptyState.LayoutOrder = 999
                local eIcon = Instance.new("ImageLabel", emptyState)
                eIcon.Name = "EmptyIcon"
                eIcon.Size = UDim2.fromOffset(32, 32)
                eIcon.Position = UDim2.new(0.5, -16, 0, 10)
                eIcon.BackgroundTransparency = 1
                eIcon.ImageColor3 = self._Colors.TextDim
                local eText = Instance.new("TextLabel", emptyState)
                eText.Name = "EmptyText"
                eText.Size = UDim2.new(1, -32, 0, 40)
                eText.Position = UDim2.new(0, 16, 0, 50)
                eText.BackgroundTransparency = 1
                eText.TextColor3 = self._Colors.TextDim
                eText.Font = Enum.Font.GothamMedium
                eText.TextSize = 11
                eText.TextWrapped = true
                eText.TextXAlignment = Enum.TextXAlignment.Center
            end
            local eIcon = emptyState:FindFirstChild("EmptyIcon")
            if eIcon then
                eIcon.Image = GetIcon(iconName)
                eIcon.ImageColor3 = self._Colors.TextDim
            end
            local eText = emptyState:FindFirstChild("EmptyText")
            if eText then
                eText.Text = msg
                eText.TextColor3 = self._Colors.TextDim
            end
            emptyState.Visible = true
            emptyState.Size = UDim2.new(1, 0, 0, 100)
        elseif emptyState then
            emptyState.Visible = false
            emptyState.Size = UDim2.new(0, 0, 0, 0)
        end
    end
end

function Library:_registerSearchControl(instance, searchText)
    local parent = instance.Parent
    local sectionData
    while parent do
        sectionData = self._STATE.SearchBodies[parent]
        if sectionData then break end
        parent = parent.Parent
    end

    if not sectionData then
        local tabName
        local p = instance.Parent
        while p do
            for name, page in pairs(self._STATE.ContentPages) do
                if page == p then tabName = name; break end
            end
            if tabName then break end
            p = p.Parent
        end
        if tabName then
            self._STATE.SearchTopLevel = self._STATE.SearchTopLevel or {}
            self._STATE.SearchTopLevel[tabName] = self._STATE.SearchTopLevel[tabName] or {}
            local text = tostring(searchText or "")
            table.insert(self._STATE.SearchTopLevel[tabName], {
                instance = instance,
                searchText = text,
                searchLower = string.lower(text),
                ctrlId = instance:GetAttribute("DoD_CtrlId"),
                parent = instance.Parent,
            })
            self:_queueSearchFilter(tabName)
        end
        return instance
    end

    local text = tostring(searchText or "")
    table.insert(sectionData.controls, {
        instance = instance,
        searchText = text,
        searchLower = string.lower(text),
        ctrlId = instance:GetAttribute("DoD_CtrlId"),
        parent = instance.Parent,
    })
    self:_queueSearchFilter(sectionData.tabName)
    return instance
end

function Library:_updateFavoriteStar(configId)
    local star = self._STATE.FavoriteStars and self._STATE.FavoriteStars[configId]
    if not star or not star.Parent then return end
    local isFav = self._STATE.Favorites[configId] == true
    local hovering = star:GetAttribute("DoD_Hover") == true
    local mobile = self._isMobile
    -- MOBILE: the star is only a "this row is favorited" badge. It used to be
    -- drawn at 50% opacity on *every* control, which littered the whole menu and
    -- (because an ImageButton always sinks input) stole taps from the +/toggle
    -- widgets sitting under it. Favoriting on mobile is done by long-press.
    -- DESKTOP: hidden unless favorited or the row is hovered, so an invisible
    -- star can never intercept a click meant for the control itself.
    local visible = isFav or (not mobile and hovering)
    star.Visible = visible
    if not visible then
        star:SetAttribute("DoD_Hover", false)
        return
    end
    local transparency
    if mobile then
        transparency = 0.12
    elseif isFav then
        transparency = hovering and 0 or 0.15
    else
        transparency = 0.25
    end
    self._favTweens = self._favTweens or {}
    local prev = self._favTweens[star]
    if prev then pcall(function() prev:Cancel() end) end
    local tw = TweenService:Create(star, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        ImageColor3 = isFav and self._Colors.Accent or self._Colors.TextDim,
        ImageTransparency = transparency,
    })
    self._favTweens[star] = tw
    tw:Play()
end

function Library:_attachFavorite(holder, configId, starPos)
    if not holder or not configId then return end
    if holder:GetAttribute("DoD_CtrlId") then return end
    holder:SetAttribute("DoD_CtrlId", configId)
    self._STATE.FavoriteHolders[configId] = holder
    self._STATE.FavoriteStars = self._STATE.FavoriteStars or {}

    local star = Instance.new("ImageButton", holder)
    star.Name = "FavoriteStar"
    if self._isMobile then
        -- Small corner badge, clear of the +/toggle widgets on the right edge.
        star.Size = UDim2.fromOffset(14, 14)
        star.Position = starPos or UDim2.new(1, -20, 0, 1)
    else
        star.Size = UDim2.fromOffset(11, 11)
        star.Position = starPos or UDim2.new(1, -14, 0, 2)
    end
    star.BackgroundTransparency = 1
    star.BorderSizePixel = 0
    star.AutoButtonColor = false
    star.Image = GetIcon("star")
    star.ImageColor3 = self._STATE.Favorites[configId] and self._Colors.Accent or self._Colors.TextDim
    star.ImageTransparency = 0.15
    star.ZIndex = 10
    star.Visible = self._STATE.Favorites[configId] == true
    self._STATE.FavoriteStars[configId] = star

    holder.MouseEnter:Connect(function()
        if not star.Parent then return end
        star:SetAttribute("DoD_Hover", true)
        self:_updateFavoriteStar(configId)
    end)
    holder.MouseLeave:Connect(function()
        -- The star is a child of the holder, so sliding onto it fires
        -- holder.MouseLeave first and would hide the star from under the cursor.
        -- Re-check on the next frame and keep the hover state when the pointer
        -- actually landed on the star.
        task.defer(function()
            if not star.Parent then return end
            local mp = UserInputService:GetMouseLocation()
            local sp, ss = star.AbsolutePosition, star.AbsoluteSize
            local onStar = star.Visible
                and mp.X >= sp.X and mp.X <= sp.X + ss.X
                and mp.Y >= sp.Y and mp.Y <= sp.Y + ss.Y
            if onStar then return end
            star:SetAttribute("DoD_Hover", false)
            self:_updateFavoriteStar(configId)
        end)
    end)
    star.MouseEnter:Connect(function()
        star:SetAttribute("DoD_Hover", true)
        self:_updateFavoriteStar(configId)
    end)
    star.MouseLeave:Connect(function()
        task.defer(function()
            if not star.Parent then return end
            local mp = UserInputService:GetMouseLocation()
            local hp, hs = holder.AbsolutePosition, holder.AbsoluteSize
            local onHolder = mp.X >= hp.X and mp.X <= hp.X + hs.X
                and mp.Y >= hp.Y and mp.Y <= hp.Y + hs.Y
            if onHolder then return end
            star:SetAttribute("DoD_Hover", false)
            self:_updateFavoriteStar(configId)
        end)
    end)

    star.MouseButton1Click:Connect(function()
        if self:_isDead() then return end
        if self._STATE.Favorites[configId] then
            self._STATE.Favorites[configId] = nil
        else
            self._STATE.Favorites[configId] = true
        end
        self:_updateFavoriteStar(configId)
        self:_applySearchFilter()
        self:_triggerAutoSave()
    end)

    self:_registerThemeRefresher(function()
        if star and star.Parent then
            self:_updateFavoriteStar(configId)
        end
    end)
end

-- =========================================================
-- CONTENT AREA (TRUE 2-COLUMN LAYOUT)
-- =========================================================

function Library:_initContentArea()
    local UI = self._UI
    UI.ContentArea = Instance.new("Frame", UI.MainContainer)
    UI.ContentArea.Size = UDim2.new(1, -30, 1, -177)
    UI.ContentArea.Position = UDim2.new(0, 15, 0, 162)
    UI.ContentArea.BackgroundTransparency = 1
    UI.ContentArea.ClipsDescendants = false
    UI.ContentArea.ZIndex = 3
end


return true
