--[[
  CONTROLS (toggle, slider, dropdown, button, textbox, keybind, ...)

  Split out of src/core/ui/demon-theme.luau (original lines 8622-12105).
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
-- CONTROLS
-- =========================================================

-- One shared pointer pump for every draggable control. Each slider/color picker
-- used to register its own permanent UserInputService.InputChanged listener, so
-- every mouse movement ran N Lua closures for the whole session.
function Library:_ensureDragPump()
    if self._dragPumpInstalled then return end
    self._dragPumpInstalled = true
    Fn.track(UserInputService.InputChanged, function(input)
        local handler = self._activeDragHandler
        if handler then handler(input) end
    end, self)
    Fn.track(UserInputService.InputEnded, function(input)
        local handler = self._activeDragEnd
        if handler then handler(input) end
    end, self)
end

function Library:AddToggle(page, text, default, callback)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    if default ~= nil and type(default) ~= "boolean" then
        error("[DoD UI] AddToggle default must be a boolean.")
    end
    if callback ~= nil and type(callback) ~= "function" then
        error("[DoD UI] AddToggle callback must be a function.")
    end
    callback = callback or function() end
    local _isMobTgl = self._isMobile
    -- FIX: 52x28 switches on mobile looked disproportionate next to the
    -- 40px dropdowns and 42px buttons. 44x24 is the Apple/Google standard
    -- minimum touch target while matching the visual weight of the rest.
    local _swW = _isMobTgl and 44 or 36
    local _swH = _isMobTgl and 24 or 20
    local _knSz = _isMobTgl and 20 or 16
    local _knOnX = -(_knSz + 2)
    local _knOffX = 2
    local _knY = -(_knSz / 2)
    local _swRightX = -(_swW + 14)
    local _swY = -(_swH / 2)
    local _rowH = _isMobTgl and 44 or 36
    local _labPad = _swW + 68

    local holder = Instance.new("Frame", page)
    holder.Size = UDim2.new(1, 0, 0, _rowH)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    holder.Active = true
    Fn.bindPressAnimation(holder)
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local lab = Instance.new("TextLabel", holder)
    lab.Size = UDim2.new(1, -_labPad, 1, 0)
    lab.Position = UDim2.new(0, 12, 0, 0)
    lab.BackgroundTransparency = 1
    lab.Text = text
    lab.TextColor3 = self._Colors.Text
    lab.Font = Enum.Font.GothamBold
    lab.TextSize = _isMobTgl and 13 or 12
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.TextTruncate = Enum.TextTruncate.AtEnd

    local switchBg = Instance.new("Frame", holder)
    switchBg.Size = UDim2.fromOffset(_swW, _swH)
    switchBg.Position = UDim2.new(1, _swRightX, 0.5, _swY)
    switchBg.BackgroundColor3 = default and self._Colors.Accent or Color3.fromRGB(45, 45, 55)
    switchBg.BorderSizePixel = 0
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local switchStroke = Instance.new("UIStroke", switchBg)
    switchStroke.Color = default and self._Colors.Accent or self._Colors.Border
    switchStroke.Thickness = 1

    local knob = Instance.new("Frame", switchBg)
    knob.Size = UDim2.fromOffset(_knSz, _knSz)
    knob.Position = default and UDim2.new(1, _knOnX, 0.5, _knY) or UDim2.new(0, _knOffX, 0.5, _knY)
    knob.BackgroundColor3 = Fn.contrastForeground(default and self._Colors.Accent or Color3.fromRGB(45, 45, 55))
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default
    local settingsPanel
    local settingsContent
    local settingsLayout
    local refreshSettings

    local function updateVisual(animate)
        local tInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local targetBg = state and self._Colors.Accent or Color3.fromRGB(45, 45, 55)
        local targetStroke = state and self._Colors.Accent or self._Colors.Border
        local targetKnob = Fn.contrastForeground(targetBg)
        local onPos = UDim2.new(1, _knOnX, 0.5, _knY)
        local offPos = UDim2.new(0, _knOffX, 0.5, _knY)
        if animate then
            TweenService:Create(switchBg, tInfo, {BackgroundColor3 = targetBg}):Play()
            TweenService:Create(switchStroke, tInfo, {Color = targetStroke}):Play()
            TweenService:Create(knob, tInfo, {
                Position = state and onPos or offPos,
                BackgroundColor3 = targetKnob,
            }):Play()
        else
            switchBg.BackgroundColor3 = targetBg
            switchStroke.Color = targetStroke
            knob.Position = state and onPos or offPos
            knob.BackgroundColor3 = targetKnob
        end
    end

    local lastToggle = 0
    local function _doToggle()
        local now = os.clock()
        if now - lastToggle < 0.15 then return end
        lastToggle = now
        state = not state
        self:PlaySound(state and "ToggleOn" or "ToggleOff")
        updateVisual(true)
        if refreshSettings then refreshSettings(true) end
        callback(state)
        self:_triggerAutoSave()
    end
    holder.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
            and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        if settingsPanel and settingsPanel.Visible then
            local mp = inp.Position
            local pp, ps = settingsPanel.AbsolutePosition, settingsPanel.AbsoluteSize
            if mp.X >= pp.X and mp.X <= pp.X + ps.X and mp.Y >= pp.Y and mp.Y <= pp.Y + ps.Y then
                return
            end
        end
        local starBtn = holder:FindFirstChild("FavoriteStar")
        if starBtn and starBtn.Parent and starBtn.Visible then
            local mp = inp.Position
            local sp = starBtn.AbsolutePosition
            local ss = starBtn.AbsoluteSize
            if mp.X >= sp.X and mp.X <= sp.X + ss.X and mp.Y >= sp.Y and mp.Y <= sp.Y + ss.Y then
                return
            end
        end
        -- MOBILE: only toggle when the tap lands on the switch itself (plus
        -- ~10px slop for finger imprecision). Tapping the label row no longer
        -- flips the state -- that matches the request to stop accidental
        -- toggles when scrolling or aiming at the row by mistake.
        if self._isMobile then
            local mp = inp.Position
            local swp, sws = switchBg.AbsolutePosition, switchBg.AbsoluteSize
            local slop = 10
            if mp.X < swp.X - slop or mp.X > swp.X + sws.X + slop
                or mp.Y < swp.Y - slop or mp.Y > swp.Y + sws.Y + slop then
                return
            end
        end
        _doToggle()
    end)

    local _favId = self:_getConfigId("toggle", text)
    self:_registerConfigState(_favId,
        function() return state end,
        function(v, silent)
            if type(v) ~= "boolean" then return end
            if state == v then return end
            state = v
            updateVisual(false)
            if refreshSettings then refreshSettings(false) end
            if not silent then
                callback(state)
                self:_triggerAutoSave()
            end
        end
    )
    self:_attachFavorite(holder, _favId)

    holder.MouseEnter:Connect(function()
        self:PlaySound("Hover")
        if not state then
            TweenService:Create(switchBg, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}):Play()
        else
            TweenService:Create(switchBg, TweenInfo.new(0.15), {BackgroundColor3 = self._Colors.Accent:Lerp(Color3.new(1,1,1), 0.15)}):Play()
        end
    end)
    
    holder.MouseLeave:Connect(function()
        updateVisual(true)
    end)

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        lab.TextColor3 = self._Colors.Text
        updateVisual(false)
    end)
    self:_bindTooltip(holder, text)
    self:_registerSearchControl(holder, text)
    local _h = { __isHandle = true, __tag = "Toggle", Raw = holder }
    _h.Get = function(_) return state end
    _h.Set = function(_, v, silent)
        if type(v) ~= "boolean" then return end
        if state == v then return end
        state = v
        updateVisual(false)
        if refreshSettings then refreshSettings(false) end
        if not silent then callback(state); self:_triggerAutoSave() end
    end
    _h.CreateSettings = function(_, title, description)
        if settingsPanel then return _h.Settings end
        settingsPanel = Instance.new("Frame")
        settingsPanel.Name = "ToggleSettings"
        settingsPanel.Position = UDim2.new(0, 8, 0, _rowH + 7)
        settingsPanel.Size = UDim2.new(1, -16, 0, 42)
        settingsPanel.BackgroundColor3 = self._Colors.Bg2
        settingsPanel.BackgroundTransparency = 0.22
        settingsPanel.BorderSizePixel = 0
        settingsPanel.Visible = state
        settingsPanel.Parent = holder
        Instance.new("UICorner", settingsPanel).CornerRadius = UDim.new(0, 8)
        local panelStroke = Instance.new("UIStroke", settingsPanel)
        panelStroke.Color = self._Colors.Border
        panelStroke.Transparency = 0.55
        panelStroke.Thickness = 1

        local panelTitle = Instance.new("TextLabel", settingsPanel)
        panelTitle.Name = "SettingsTitle"
        panelTitle.Position = UDim2.fromOffset(10, 7)
        panelTitle.Size = UDim2.new(1, -20, 0, 15)
        panelTitle.BackgroundTransparency = 1
        panelTitle.Font = Enum.Font.GothamBold
        panelTitle.TextSize = 10
        panelTitle.TextColor3 = self._Colors.Accent
        panelTitle.TextXAlignment = Enum.TextXAlignment.Left
        panelTitle.Text = tostring(title or "CONFIGURAÇÕES"):upper()

        if type(description) == "string" and description ~= "" then
            panelTitle.Text = tostring(title or "CONFIGURAÇÕES"):upper() .. "  ·  " .. description
        end

        settingsContent = Instance.new("Frame", settingsPanel)
        settingsContent.Name = "SettingsContent"
        settingsContent.Position = UDim2.new(0, 10, 0, 29)
        settingsContent.Size = UDim2.new(1, -20, 0, 0)
        settingsContent.BackgroundTransparency = 1
        settingsContent.AutomaticSize = Enum.AutomaticSize.Y

        settingsLayout = Instance.new("UIListLayout", settingsContent)
        settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        settingsLayout.Padding = UDim.new(0, 7)

        local contentPadding = Instance.new("UIPadding", settingsContent)
        contentPadding.PaddingBottom = UDim.new(0, 9)

        local function resizePanel(animate)
            if not settingsPanel or not settingsPanel.Parent then return end
            local panelHeight = 29 + settingsLayout.AbsoluteContentSize.Y
            local targetPanel = UDim2.new(1, -16, 0, math.max(42, panelHeight))
            local targetHolder = UDim2.new(1, 0, 0, state and (_rowH + 7 + math.max(42, panelHeight) + 7) or _rowH)
            if animate and not SharedReduced.value then
                TweenService:Create(settingsPanel, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetPanel}):Play()
                TweenService:Create(holder, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetHolder}):Play()
            else
                settingsPanel.Size = targetPanel
                holder.Size = targetHolder
            end
        end

        refreshSettings = function(animate)
            if not settingsPanel then return end
            settingsPanel.Visible = state
            resizePanel(animate)
        end

        settingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if state then resizePanel(true) end
        end)

        self:_registerThemeRefresher(function()
            if settingsPanel and settingsPanel.Parent then
                settingsPanel.BackgroundColor3 = self._Colors.Bg2
                panelStroke.Color = self._Colors.Border
                panelTitle.TextColor3 = self._Colors.Accent
            end
        end)

        local api = {Library = self, Page = settingsContent}
        function api:CreateToggle(label, initial, callback)
            return self.Library:AddToggle(self.Page, label, initial == true, callback)
        end
        function api:CreateSlider(label, minimum, maximum, initial, callback, decimals)
            return self.Library:AddSlider(self.Page, label, tonumber(minimum) or 0, tonumber(maximum) or 100, tonumber(initial) or tonumber(minimum) or 0, tonumber(decimals) or 0, callback)
        end
        function api:CreateDropdown(label, options, initial, callback)
            local list = {}
            for _, option in ipairs(type(options) == "table" and options or {}) do list[#list + 1] = tostring(option) end
            if #list == 0 then list = {"None"} end
            local index = 1
            for i, option in ipairs(list) do if option == tostring(initial) then index = i break end end
            return self.Library:AddDropdown(self.Page, label, list, index, function(_, value)
                if callback then callback(value) end
            end)
        end
        function api:CreateButton(label, callback)
            return self.Library:AddButton(self.Page, label, callback)
        end
        function api:CreateInput(label, placeholder, initial, callback)
            return self.Library:AddTextbox(self.Page, label, tostring(placeholder or initial or ""), callback)
        end
        function api:CreateParagraph(titleText, bodyText)
            return self.Library:AddParagraph(self.Page, tostring(titleText or ""), tostring(bodyText or ""))
        end
        _h.Settings = api
        refreshSettings(false)
        return api
    end
    _h.AddSettings = _h.CreateSettings
    _h.SetValue = _h.Set
    _h.GetValue = _h.Get
    local _defaultToggleState = default
    _h.Reset = function(_)
        if state == _defaultToggleState then return end
        _h:Set(_defaultToggleState)
    end
    return _h
end

function Library:AddSlider(page, text, minVal, maxVal, default, decimals, callback)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    if type(minVal) ~= "number" or type(maxVal) ~= "number" then
        error("[DoD UI] AddSlider minVal/maxVal harus number.")
    end
    if maxVal <= minVal then
        error("[DoD UI] AddSlider maxVal harus lebih besar dari minVal.")
    end
    if minVal ~= minVal or maxVal ~= maxVal or minVal == math.huge or maxVal == math.huge
        or minVal == -math.huge or maxVal == -math.huge then
        error("[DoD UI] AddSlider bounds must be finite numbers.")
    end
    if maxVal - minVal == math.huge then
        error("[DoD UI] AddSlider range is too large.")
    end
    if decimals == nil then decimals = 1 end
    if type(decimals) ~= "number" or decimals < 0 or decimals > 6 or decimals % 1 ~= 0 then
        error("[DoD UI] AddSlider decimals must be an integer between 0 and 6.")
    end
    if callback ~= nil and type(callback) ~= "function" then
        error("[DoD UI] AddSlider callback must be a function.")
    end
    if type(default) ~= "number" then default = minVal end
    if default ~= default or default == math.huge or default == -math.huge then
        error("[DoD UI] AddSlider default must be finite.")
    end
    default = math.clamp(default, minVal, maxVal)
    callback = callback or function() end

    local holder = Instance.new("Frame", page)
    holder.Size = UDim2.new(1, 0, 0, 58)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local lab = Instance.new("TextLabel", holder)
    lab.Size = UDim2.new(1, -142, 0, 18)
    lab.Position = UDim2.new(0, 14, 0, 6)
    lab.BackgroundTransparency = 1
    lab.Text = text
    lab.TextColor3 = self._Colors.Text
    lab.Font = Enum.Font.GothamMedium
    lab.TextSize = 12
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.TextTruncate = Enum.TextTruncate.AtEnd

    local btnMinus = Instance.new("TextButton", holder)
    btnMinus.Name = "BtnMinus"
    btnMinus.Size = UDim2.fromOffset(24, 24)
    btnMinus.Position = UDim2.new(1, -114, 0, 3)
    btnMinus.BackgroundColor3 = self._Colors.Bg2
    btnMinus.BackgroundTransparency = 0.5
    btnMinus.TextColor3 = self._Colors.Text
    btnMinus.Font = Enum.Font.GothamBold
    btnMinus.TextSize = 14
    btnMinus.Text = "-"
    btnMinus.AutoButtonColor = false
    btnMinus.BorderSizePixel = 0
    Instance.new("UICorner", btnMinus).CornerRadius = UDim.new(0, 8)

    local btnMinusStroke = Instance.new("UIStroke", btnMinus)
    btnMinusStroke.Color = self._Colors.Border
    btnMinusStroke.Thickness = 1
    btnMinusStroke.Transparency = 0.6

    local valBox = Instance.new("TextBox", holder)
    valBox.Name = "ValueBox"
    valBox.Size = UDim2.new(0, 56, 0, 24)
    valBox.Position = UDim2.new(1, -84, 0, 3)
    valBox.BackgroundColor3 = self._Colors.Bg2
    valBox.BackgroundTransparency = 0.5
    valBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    valBox.TextStrokeTransparency = 1
    valBox.Font = Enum.Font.GothamBold
    valBox.TextSize = 12
    valBox.Text = tostring(default)
    valBox.TextXAlignment = Enum.TextXAlignment.Center
    valBox.ClearTextOnFocus = false
    valBox.BorderSizePixel = 0
    Instance.new("UICorner", valBox).CornerRadius = UDim.new(0, 8)

    local btnPlus = Instance.new("TextButton", holder)
    btnPlus.Name = "BtnPlus"
    btnPlus.Size = UDim2.fromOffset(24, 24)
    btnPlus.Position = UDim2.new(1, -18, 0, 3)
    btnPlus.BackgroundColor3 = self._Colors.Bg2
    btnPlus.BackgroundTransparency = 0.5
    btnPlus.TextColor3 = self._Colors.Text
    btnPlus.Font = Enum.Font.GothamBold
    btnPlus.TextSize = 14
    btnPlus.Text = "+"
    btnPlus.AutoButtonColor = false
    btnPlus.BorderSizePixel = 0
    Instance.new("UICorner", btnPlus).CornerRadius = UDim.new(0, 8)

    local btnPlusStroke = Instance.new("UIStroke", btnPlus)
    btnPlusStroke.Color = self._Colors.Border
    btnPlusStroke.Thickness = 1
    btnPlusStroke.Transparency = 0.6

    local valBoxPad = Instance.new("UIPadding", valBox)
    valBoxPad.PaddingLeft = UDim.new(0, 4)
    valBoxPad.PaddingRight = UDim.new(0, 4)

    local valBoxStroke = Instance.new("UIStroke", valBox)
    valBoxStroke.Color = self._Colors.Border
    valBoxStroke.Thickness = 1
    valBoxStroke.Transparency = 0.6

    btnMinus.MouseEnter:Connect(function()
        TweenService:Create(btnMinus, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
        TweenService:Create(btnMinusStroke, TweenInfo.new(0.15), {Transparency = 0.2, Color = self._Colors.Accent}):Play()
    end)
    btnMinus.MouseLeave:Connect(function()
        TweenService:Create(btnMinus, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(btnMinusStroke, TweenInfo.new(0.15), {Transparency = 0.6, Color = self._Colors.Border}):Play()
    end)
    
    btnPlus.MouseEnter:Connect(function()
        TweenService:Create(btnPlus, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
        TweenService:Create(btnPlusStroke, TweenInfo.new(0.15), {Transparency = 0.2, Color = self._Colors.Accent}):Play()
    end)
    btnPlus.MouseLeave:Connect(function()
        TweenService:Create(btnPlus, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(btnPlusStroke, TweenInfo.new(0.15), {Transparency = 0.6, Color = self._Colors.Border}):Play()
    end)

    local sliderBg = Instance.new("Frame", holder)
    sliderBg.Size = UDim2.new(1, -28, 0, 8)
    sliderBg.Position = UDim2.new(0, 14, 0, 36)
    sliderBg.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    sliderBg.BorderSizePixel = 0
    sliderBg.Active = true
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

    local sliderStroke = Instance.new("UIStroke", sliderBg)
    sliderStroke.Color = self._Colors.Border
    sliderStroke.Thickness = 1
    sliderStroke.Transparency = 0.5

    for i = 1, 3 do
        local tick = Instance.new("Frame", sliderBg)
        tick.Size = UDim2.new(0, 1, 0, 4)
        tick.Position = UDim2.new(i / 4, 0, 0.5, -2)
        tick.BackgroundColor3 = Color3.fromRGB(80, 80, 95)
        tick.BackgroundTransparency = 0.4
        tick.BorderSizePixel = 0
        tick.ZIndex = 1
    end

    local fillGlow = Instance.new("Frame", sliderBg)
    fillGlow.Size = UDim2.new((default - minVal) / (maxVal - minVal), 0, 1.6, -0.3)
    fillGlow.Position = UDim2.new(0, 0, 0.5, -6.4)
    fillGlow.BackgroundColor3 = self._Colors.Accent
    fillGlow.BackgroundTransparency = 0.7
    fillGlow.BorderSizePixel = 0
    fillGlow.ZIndex = 1
    Instance.new("UICorner", fillGlow).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", sliderBg)
    fill.Size = UDim2.new((default - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = self._Colors.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 2
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local fillGrad = Instance.new("UIGradient", fill)
    fillGrad.Color = ColorSequence.new(self._Colors.Accent, self._Colors.Accent2 or self._Colors.Accent)
    fillGrad.Rotation = 0

    local knobHalo = Instance.new("Frame", sliderBg)
    knobHalo.Name = "KnobHalo"
    knobHalo.AnchorPoint = Vector2.new(0.5, 0.5)
    knobHalo.Size = UDim2.fromOffset(24, 24)
    knobHalo.Position = UDim2.new((default - minVal) / (maxVal - minVal), 0, 0.5, 0)
    knobHalo.BackgroundColor3 = self._Colors.Accent
    knobHalo.BackgroundTransparency = 1
    knobHalo.BorderSizePixel = 0
    knobHalo.ZIndex = 2
    Instance.new("UICorner", knobHalo).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", sliderBg)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new((default - minVal) / (maxVal - minVal), -8, 0.5, -8)
    knob.BackgroundColor3 = Fn.contrastForeground(self._Colors.Accent)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local knobStroke = Instance.new("UIStroke", knob)
    knobStroke.Color = self._Colors.Accent
    knobStroke.Thickness = 2
    knobStroke.Transparency = 0.2

    local knobScale = Instance.new("UIScale", knob)
    knobScale.Scale = 1

    local knobHit = Instance.new("Frame", knob)
    knobHit.Name = "KnobHit"
    knobHit.AnchorPoint = Vector2.new(0.5, 0.5)
    knobHit.Position = UDim2.new(0.5, 0, 0.5, 0)
    knobHit.Size = UDim2.fromOffset(44, 44)
    knobHit.BackgroundTransparency = 1
    knobHit.Active = true
    knobHit.ZIndex = 4

    local val = default
    local drag = false
    local editing = false
    local originalText = ""

    local function formatValue(v)
        if decimals == 0 then
            return tostring(math.floor(v + 0.5))
        end
        return string.format("%." .. tostring(decimals) .. "f", v)
    end

    local function applyValue(newVal, animate)
        newVal = math.clamp(newVal, minVal, maxVal)
        local mult = 10 ^ decimals
        if math.abs(newVal) * mult < 2 ^ 52 then
            if newVal >= 0 then
                newVal = math.floor(newVal * mult + 0.5) / mult
            else
                newVal = math.ceil(newVal * mult - 0.5) / mult
            end
        end
        -- Rounding can push the value back past the limit (e.g. max 0.95 with
        -- 1 decimal rounds up to 1.0), so clamp again before storing it.
        newVal = math.clamp(newVal, minVal, maxVal)
        val = newVal
        local rel = math.clamp((newVal - minVal) / (maxVal - minVal), 0, 1)
        if animate then
            TweenService:Create(fill, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(rel, 0, 1, 0)}):Play()
            TweenService:Create(fillGlow, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(rel, 0, 1.6, -0.3)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(rel, -8, 0.5, -8)}):Play()
            TweenService:Create(knobHalo, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(rel, 0, 0.5, 0)}):Play()
        else
            fill.Size = UDim2.new(rel, 0, 1, 0)
            fillGlow.Size = UDim2.new(rel, 0, 1.6, -0.3)
            knob.Position = UDim2.new(rel, -8, 0.5, -8)
            knobHalo.Position = UDim2.new(rel, 0, 0.5, 0)
        end
        if not editing then
            valBox.Text = formatValue(newVal)
        end
    end

    local step = 1 / (10 ^ decimals)

    local function makeHold(dir)
        local active = false
        local thread = nil
        return {
            start = function()
                if active then return end
                active = true
                local prev = val
                applyValue(val + dir * step, true)
                if val ~= prev then
                    callback(val)
                    self:_triggerAutoSave()
                end
                thread = task.spawn(function()
                    task.wait(0.35)
                    -- Tie the repeat loop to the widget's lifetime: hiding the
                    -- window or destroying the library mid-press used to leave it
                    -- spinning at 20 Hz, driving the value to max on its own.
                    while active and holder.Parent and not self:_isDead() do
                        local prevV = val
                        applyValue(val + dir * step, false)
                        if val ~= prevV then
                            callback(val)
                            self:_triggerAutoSave()
                        end
                        task.wait(0.05)
                    end
                    active = false
                end)
            end,
            stop = function()
                if not active then return end
                active = false
                if thread then
                    pcall(task.cancel, thread)
                    thread = nil
                end
            end,
        }
    end

    local minusHold = makeHold(-1)
    local plusHold = makeHold(1)

    btnMinus.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            minusHold.start()
        end
    end)
    btnMinus.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            minusHold.stop()
        end
    end)

    btnPlus.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            plusHold.start()
        end
    end)
    btnPlus.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            plusHold.stop()
        end
    end)

    local function setFromPosition(position)
        local width = sliderBg.AbsoluteSize.X
        if width <= 0 then return end
        local rel = math.clamp((position.X - sliderBg.AbsolutePosition.X) / width, 0, 1)
        local newVal = minVal + (maxVal - minVal) * rel
        local previous = val
        applyValue(newVal, false)
        -- Dragging vertically or within one step used to re-fire the callback and
        -- an autosave at 60+ Hz with an identical value.
        if val == previous then return end
        callback(val)
        self:_triggerAutoSave()
    end

    valBox.Focused:Connect(function()
        editing = true
        originalText = valBox.Text
        TweenService:Create(valBoxStroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0}):Play()
        TweenService:Create(valBox, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
    end)

    valBox.MouseEnter:Connect(function()
        if not editing then
            TweenService:Create(valBox, TweenInfo.new(0.15), {BackgroundTransparency = 0.35}):Play()
            TweenService:Create(valBoxStroke, TweenInfo.new(0.15), {Transparency = 0.4}):Play()
        end
    end)
    valBox.MouseLeave:Connect(function()
        if not editing then
            TweenService:Create(valBox, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play()
            TweenService:Create(valBoxStroke, TweenInfo.new(0.15), {Transparency = 0.6}):Play()
        end
    end)

    valBox.FocusLost:Connect(function(enterPressed)
        editing = false
        TweenService:Create(valBoxStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.6}):Play()
        TweenService:Create(valBox, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play()
        if valBox.Text == originalText then
            valBox.Text = formatValue(val)
            return
        end
        local parsed = tonumber(valBox.Text)
        if parsed and parsed == parsed and parsed ~= math.huge and parsed ~= -math.huge then
            applyValue(parsed, true)
            callback(val)
            self:_triggerAutoSave()
        else
            valBox.Text = formatValue(val)
        end
    end)

    local dragInput = nil
    self:_ensureDragPump()

    local function endSliderDrag(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
            and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        if drag then
            TweenService:Create(knobScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
            TweenService:Create(knobStroke, TweenInfo.new(0.15), {Transparency = 0.2}):Play()
        end
        drag = false
        dragInput = nil
        if self._activeDragEnd == endSliderDrag then
            self._activeDragEnd = nil
            self._activeDragHandler = nil
        end
    end

    local function moveSliderDrag(inp)
        if not drag then return end
        -- Removed: dragInput identity check. dragInput holds the original
        -- InputBegan event; inp here is always InputChanged. They are never
        -- the same object, so the old check made every drag a no-op. The
        -- UserInputType filter below is enough device-mismatch protection.
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
            and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        setFromPosition(inp.Position)
    end

    local function beginSliderDrag(inp)
        drag = true
        dragInput = inp
        self._activeDragHandler = moveSliderDrag
        self._activeDragEnd = endSliderDrag
    end

    knobHit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            beginSliderDrag(inp)
            TweenService:Create(knobScale, TweenInfo.new(0.1), {Scale = 1.2}):Play()
            TweenService:Create(knobStroke, TweenInfo.new(0.1), {Transparency = 0}):Play()
        end
    end)

    sliderBg.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            beginSliderDrag(inp)
            TweenService:Create(knobScale, TweenInfo.new(0.1), {Scale = 1.2}):Play()
            setFromPosition(inp.Position)
        end
    end)

    local _favId = self:_getConfigId("slider", text)
    self:_registerConfigState(_favId,
        function() return val end,
        function(v, silent)
            if type(v) ~= "number" or v ~= v then return end
            applyValue(v, false)
            if not silent then
                callback(val)
                self:_triggerAutoSave()
            end
        end
    )
    self:_attachFavorite(holder, _favId)

    holder.MouseEnter:Connect(function()
        self:PlaySound("Hover")
        if not drag then
            TweenService:Create(knobScale, TweenInfo.new(0.15), {Scale = 1.1}):Play()
            TweenService:Create(knobHalo, TweenInfo.new(0.18), {BackgroundTransparency = 0.82}):Play()
        end
    end)
    holder.MouseLeave:Connect(function()
        if not drag then
            TweenService:Create(knobScale, TweenInfo.new(0.15), {Scale = 1}):Play()
            TweenService:Create(knobHalo, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
        end
    end)

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        lab.TextColor3 = self._Colors.Text
        valBox.TextColor3 = self._Colors.Text
        valBox.BackgroundColor3 = self._Colors.Bg2
        valBoxStroke.Color = self._Colors.Border
        btnMinus.BackgroundColor3 = self._Colors.Bg2
        btnMinus.TextColor3 = self._Colors.Text
        btnMinusStroke.Color = self._Colors.Border
        btnPlus.BackgroundColor3 = self._Colors.Bg2
        btnPlus.TextColor3 = self._Colors.Text
        btnPlusStroke.Color = self._Colors.Border
        fill.BackgroundColor3 = self._Colors.Accent
        fillGlow.BackgroundColor3 = self._Colors.Accent
        knob.BackgroundColor3 = Fn.contrastForeground(self._Colors.Accent)
        knobStroke.Color = self._Colors.Accent
        knobHalo.BackgroundColor3 = self._Colors.Accent
        sliderStroke.Color = self._Colors.Border
        fillGrad.Color = ColorSequence.new(self._Colors.Accent, self._Colors.Accent2 or self._Colors.Accent)
    end)
    self:_bindTooltip(lab, text .. " [" .. tostring(minVal) .. " - " .. tostring(maxVal) .. "] — click value to type")
    self:_registerSearchControl(holder, text .. " " .. tostring(minVal) .. " " .. tostring(maxVal))
    local _h = { __isHandle = true, __tag = "Slider", Raw = holder }
    _h.Get = function(_) return val end
    _h.Set = function(_, v, silent)
        if type(v) ~= "number" or v ~= v then return end
        v = math.clamp(v, minVal, maxVal)
        local _mult = 10 ^ decimals
        if math.abs(v) <= math.huge / _mult then
            if v >= 0 then v = math.floor(v * _mult + 0.5) / _mult
            else v = math.ceil(v * _mult - 0.5) / _mult end
        end
        if val == v then return end
        applyValue(v, not silent)
        if not silent then callback(val); self:_triggerAutoSave() end
    end
    _h.SetValue = _h.Set
    _h.GetValue = _h.Get
    local _defaultSliderVal = default
    _h.Reset = function(_)
        _h:Set(_defaultSliderVal)
    end
    return _h
end

function Library:AddDropdown(page, text, options, defaultIndex, callback)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    if type(options) ~= "table" or #options == 0 then
        error("[DoD UI] AddDropdown options harus array non-empty.")
    end
    if callback ~= nil and type(callback) ~= "function" then
        error("[DoD UI] AddDropdown callback must be a function.")
    end
    if type(defaultIndex) ~= "number" or defaultIndex % 1 ~= 0
        or defaultIndex < 1 or defaultIndex > #options then
        defaultIndex = 1
    end
    callback = callback or function() end

    local STATE = self._STATE
    local UI = self._UI

    local holder = Instance.new("Frame", page)
    holder.Size = UDim2.new(1, 0, 0, 40)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local holderStroke = Instance.new("UIStroke", holder)
    holderStroke.Color = self._Colors.Border
    holderStroke.Thickness = 1
    holderStroke.Transparency = 0.5

    local label = Instance.new("TextLabel", holder)
    label.Size = UDim2.new(0.42, -20, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = self._Colors.Text
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd

    local valueChip = Instance.new("TextButton", holder)
    valueChip.Size = UDim2.new(0.58, -54, 0, 30)
    valueChip.Position = UDim2.new(0.42, 4, 0.5, -15)
    valueChip.BackgroundColor3 = self._Colors.Bg2
    valueChip.BackgroundTransparency = 0.2
    valueChip.Text = ""
    valueChip.BorderSizePixel = 0
    valueChip.AutoButtonColor = false
    Fn.bindPressAnimation(valueChip)
    Instance.new("UICorner", valueChip).CornerRadius = UDim.new(0, 8)

    local chipStroke = Instance.new("UIStroke", valueChip)
    chipStroke.Color = self._Colors.Border
    chipStroke.Thickness = 1
    chipStroke.Transparency = 0.4

    valueChip.MouseEnter:Connect(function()
        self:PlaySound("Hover")
        TweenService:Create(chipStroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0.1}):Play()
        TweenService:Create(valueChip, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end)
    valueChip.MouseLeave:Connect(function()
        TweenService:Create(chipStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.4}):Play()
        TweenService:Create(valueChip, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
    end)

    local chipLabel = Instance.new("TextLabel", valueChip)
    chipLabel.Size = UDim2.new(1, -20, 1, 0)
    chipLabel.Position = UDim2.new(0, 12, 0, 0)
    chipLabel.BackgroundTransparency = 1
    chipLabel.Text = tostring(options[defaultIndex])
    chipLabel.TextColor3 = self._Colors.Text
    chipLabel.Font = Enum.Font.GothamBold
    chipLabel.TextSize = 11
    chipLabel.TextXAlignment = Enum.TextXAlignment.Left
    chipLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local navUp = Instance.new("TextButton", holder)
    navUp.Name = "NavUp"
    navUp.Size = UDim2.fromOffset(20, 30)
    navUp.Position = UDim2.new(1, -48, 0.5, -15)
    navUp.BackgroundColor3 = self._Colors.Bg2
    navUp.BackgroundTransparency = 0.2
    navUp.Text = ""
    navUp.BorderSizePixel = 0
    navUp.AutoButtonColor = false
    Instance.new("UICorner", navUp).CornerRadius = UDim.new(0, 8)
    Fn.bindPressAnimation(navUp)

    local navUpStroke = Instance.new("UIStroke", navUp)
    navUpStroke.Color = self._Colors.Border
    navUpStroke.Thickness = 1
    navUpStroke.Transparency = 0.4

    local navUpIcon = Instance.new("ImageLabel", navUp)
    navUpIcon.Size = UDim2.fromOffset(12, 12)
    navUpIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
    navUpIcon.BackgroundTransparency = 1
    navUpIcon.Image = GetIcon("chevrons-up")
    navUpIcon.ImageColor3 = self._Colors.TextDim

    local navDown = Instance.new("TextButton", holder)
    navDown.Name = "NavDown"
    navDown.Size = UDim2.fromOffset(20, 30)
    navDown.Position = UDim2.new(1, -24, 0.5, -15)
    navDown.BackgroundColor3 = self._Colors.Bg2
    navDown.BackgroundTransparency = 0.2
    navDown.Text = ""
    navDown.BorderSizePixel = 0
    navDown.AutoButtonColor = false
    Instance.new("UICorner", navDown).CornerRadius = UDim.new(0, 8)
    Fn.bindPressAnimation(navDown)

    local navDownStroke = Instance.new("UIStroke", navDown)
    navDownStroke.Color = self._Colors.Border
    navDownStroke.Thickness = 1
    navDownStroke.Transparency = 0.4

    local navDownIcon = Instance.new("ImageLabel", navDown)
    navDownIcon.Size = UDim2.fromOffset(12, 12)
    navDownIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
    navDownIcon.BackgroundTransparency = 1
    navDownIcon.Image = GetIcon("chevrons-down")
    navDownIcon.ImageColor3 = self._Colors.TextDim

    navUp.MouseEnter:Connect(function()
        TweenService:Create(navUpStroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0.1}):Play()
        TweenService:Create(navUpIcon, TweenInfo.new(0.15), {ImageColor3 = self._Colors.Accent}):Play()
    end)
    navUp.MouseLeave:Connect(function()
        TweenService:Create(navUpStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.4}):Play()
        TweenService:Create(navUpIcon, TweenInfo.new(0.15), {ImageColor3 = self._Colors.TextDim}):Play()
    end)
    navDown.MouseEnter:Connect(function()
        TweenService:Create(navDownStroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0.1}):Play()
        TweenService:Create(navDownIcon, TweenInfo.new(0.15), {ImageColor3 = self._Colors.Accent}):Play()
    end)
    navDown.MouseLeave:Connect(function()
        TweenService:Create(navDownStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.4}):Play()
        TweenService:Create(navDownIcon, TweenInfo.new(0.15), {ImageColor3 = self._Colors.TextDim}):Play()
    end)

    local _textSvc = game:GetService("TextService")
    local function _adaptDropdownLayout()
        local holderW = holder.AbsoluteSize.X
        if holderW <= 0 then return end
        local bounds = _textSvc:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(1000, 100))
        local rawLabelW = bounds.X + 4
        local maxLabelW = holderW * 0.55
        local labelW = math.clamp(rawLabelW, 40, maxLabelW)
        label.Size = UDim2.new(0, labelW, 1, 0)
        local navZone = 48
        local gap = 10
        local chipX = 14 + labelW + gap
        local chipW = holderW - chipX - navZone - 6
        if chipW < 80 then chipW = 80 end
        valueChip.Position = UDim2.new(0, chipX, 0.5, -15)
        valueChip.Size = UDim2.new(0, chipW, 0, 30)
    end
    holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(_adaptDropdownLayout)
    label:GetPropertyChangedSignal("AbsoluteSize"):Connect(_adaptDropdownLayout)
    task.defer(_adaptDropdownLayout)

    local currentIndex = defaultIndex
    local popup = Instance.new("Frame", UI.MainGui)
    popup.Name = "DropdownPopup"
    popup.BackgroundColor3 = self._Colors.Bg2
    popup.BorderSizePixel = 0
    popup.Visible = false
    popup.ZIndex = 200
    popup.ClipsDescendants = true
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 8)

    local popupStroke = Instance.new("UIStroke", popup)
    popupStroke.Color = self._Colors.Accent
    popupStroke.Thickness = 1
    popupStroke.Transparency = 0.3

    local popupSearch = Instance.new("Frame", popup)
    popupSearch.Size = UDim2.new(1, -10, 0, 24)
    popupSearch.Position = UDim2.new(0, 5, 0, 5)
    popupSearch.BackgroundColor3 = self._Colors.Card
    popupSearch.BackgroundTransparency = 0.5
    popupSearch.BorderSizePixel = 0
    popupSearch.ZIndex = 202
    Instance.new("UICorner", popupSearch).CornerRadius = UDim.new(0, 4)

    local searchIcon = Instance.new("ImageLabel", popupSearch)
    searchIcon.Name = "SearchIcon"
    searchIcon.Size = UDim2.fromOffset(14, 14)
    searchIcon.Position = UDim2.new(0, 8, 0.5, -7)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Image = GetIcon("search")
    searchIcon.ImageColor3 = self._Colors.TextDim
    searchIcon.ScaleType = Enum.ScaleType.Fit
    searchIcon.ZIndex = 203
    
    local searchBox = Instance.new("TextBox", popupSearch)
    searchBox.Size = UDim2.new(1, -36, 1, 0)
    searchBox.Position = UDim2.new(0, 28, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search options..."
    searchBox.PlaceholderColor3 = self._Colors.TextDim
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.TextStrokeTransparency = 1
    searchBox.Font = Enum.Font.GothamMedium
    searchBox.TextSize = 11
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false
    searchBox.ZIndex = 203

    local popupScroll = Instance.new("ScrollingFrame", popup)
    popupScroll.Size = UDim2.new(1, 0, 1, -34)
    popupScroll.Position = UDim2.new(0, 0, 0, 34)
    popupScroll.BackgroundTransparency = 1
    popupScroll.BorderSizePixel = 0
    popupScroll.ScrollBarThickness = 3
    popupScroll.ScrollBarImageColor3 = self._Colors.Accent
    popupScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    popupScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    popupScroll.ZIndex = 201
    self:_registerScrollFrame(popupScroll)

    local optionButtons = {}

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = string.lower(searchBox.Text)
        for _, btn in ipairs(optionButtons) do
            local lbl = btn:FindFirstChild("OptLabel")
            if lbl then
                local txt = string.lower(lbl.Text)
                btn.Visible = (q == "" or string.find(txt, q, 1, true) ~= nil)
            end
        end
    end)

    local popupList = Instance.new("UIListLayout", popupScroll)
    popupList.SortOrder = Enum.SortOrder.LayoutOrder
    popupList.Padding = UDim.new(0, 2)

    local popupPad = Instance.new("UIPadding", popupScroll)
    popupPad.PaddingTop = UDim.new(0, 5)
    popupPad.PaddingBottom = UDim.new(0, 5)
    popupPad.PaddingLeft = UDim.new(0, 5)
    popupPad.PaddingRight = UDim.new(0, 5)

    local optionsBuilt = false
    local function refreshOptions()
        if optionsBuilt then
            -- Rows already exist: refresh their state only. Rebuilding all of them
            -- on every open churned ~4 instances per option per click.
            for i, btn in ipairs(optionButtons) do
                local check = btn:FindFirstChild("Check")
                if check then check.Visible = (i == currentIndex) end
                if not btn.Visible then btn.Visible = true end
            end
            if searchBox.Text ~= "" then searchBox.Text = "" end
            return
        end
        optionsBuilt = true
        for _, b in ipairs(optionButtons) do b:Destroy() end
        table.clear(optionButtons)
        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton", popupScroll)
            optBtn.Size = UDim2.new(1, 0, 0, 30)
            optBtn.BackgroundColor3 = self._Colors.Card
            optBtn.BackgroundTransparency = 1
            optBtn.Text = ""
            optBtn.BorderSizePixel = 0
            optBtn.AutoButtonColor = false
            optBtn.ZIndex = 202
            Fn.bindPressAnimation(optBtn)
            Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 5)

            local optLabel = Instance.new("TextLabel", optBtn)
            optLabel.Name = "OptLabel"
            optLabel.Size = UDim2.new(1, -36, 1, 0)
            optLabel.Position = UDim2.new(0, 12, 0, 0)
            optLabel.BackgroundTransparency = 1
            optLabel.Text = tostring(opt)
            optLabel.TextColor3 = self._Colors.Text
            optLabel.Font = Enum.Font.GothamBold
            optLabel.TextSize = 12
            optLabel.TextXAlignment = Enum.TextXAlignment.Left

            local check = Instance.new("TextLabel", optBtn)
            check.Name = "Check"
            check.Size = UDim2.new(0, 24, 1, 0)
            check.Position = UDim2.new(1, -28, 0, 0)
            check.BackgroundTransparency = 1
            check.Text = "✓"
            check.TextColor3 = self._Colors.Accent
            check.Font = Enum.Font.GothamBlack
            check.TextSize = 14
            check.Visible = (i == currentIndex)

            optBtn.MouseEnter:Connect(function() optBtn.BackgroundTransparency = 0.4 end)
            optBtn.MouseLeave:Connect(function() optBtn.BackgroundTransparency = 1 end)
            optBtn.MouseButton1Click:Connect(function()
                currentIndex = i
                chipLabel.Text = tostring(options[i])
                popup.Visible = false
                callback(i, options[i])
                self:_triggerAutoSave()
            end)
            table.insert(optionButtons, optBtn)
        end
    end

    local function navTo(delta)
        local newIdx = currentIndex + delta
        if newIdx < 1 then newIdx = #options end
        if newIdx > #options then newIdx = 1 end
        currentIndex = newIdx
        chipLabel.Text = tostring(options[currentIndex])
        callback(currentIndex, options[currentIndex])
        self:_triggerAutoSave()
    end
    navUp.MouseButton1Click:Connect(function()
        self:PlaySound("Click")
        navTo(-1)
    end)
    navDown.MouseButton1Click:Connect(function()
        self:PlaySound("Click")
        navTo(1)
    end)

    local _favId = self:_getConfigId("dropdown", text)
    self:_registerConfigState(_favId,
        function() return currentIndex end,
        function(v, silent)
            -- Fractional indices used to pass this guard and render "nil".
            if type(v) ~= "number" or v % 1 ~= 0 or v < 1 or v > #options then return end
            if v == currentIndex then return end
            currentIndex = v
            chipLabel.Text = tostring(options[v])
            if not silent then
                callback(v, options[v])
                self:_triggerAutoSave()
            end
        end
    )
    self:_attachFavorite(holder, _favId, UDim2.new(1, -62, 0.5, -6))

    local keyNavConn = nil
    local highlightedIndex = 0
    local function setHighlight(idx)
        highlightedIndex = idx
        for i, btn in ipairs(optionButtons) do
            if i == idx then
                btn.BackgroundTransparency = 0.4
            else
                btn.BackgroundTransparency = 1
            end
        end
        if idx >= 1 and idx <= #optionButtons then
            popupScroll.CanvasPosition = Vector2.new(0, math.max(0, (idx - 1) * 32 - 60))
        end
    end
    local function stepHighlight(delta)
        local count = #optionButtons
        if count == 0 then return end
        local nextIndex = highlightedIndex + delta
        if nextIndex < 1 then nextIndex = count end
        if nextIndex > count then nextIndex = 1 end
        setHighlight(nextIndex)
    end
    popup:GetPropertyChangedSignal("Visible"):Connect(function()
        if popup.Visible then
            highlightedIndex = currentIndex
            setHighlight(highlightedIndex)
            if not keyNavConn then
                keyNavConn = Fn.track(UserInputService.InputBegan, function(input, gameProcessed)
                    if self:_isDead() then return end
                    if not popup.Visible then return end
                    if gameProcessed then return end
                    if UserInputService:GetFocusedTextBox() then return end
                    local key = input.KeyCode
                    if key == Enum.KeyCode.Down then
                        stepHighlight(1)
                    elseif key == Enum.KeyCode.Up then
                        stepHighlight(-1)
                    elseif key == Enum.KeyCode.Return then
                        if highlightedIndex >= 1 and highlightedIndex <= #options
                            and highlightedIndex ~= currentIndex then
                            currentIndex = highlightedIndex
                            chipLabel.Text = tostring(options[highlightedIndex])
                            popup.Visible = false
                            callback(highlightedIndex, options[highlightedIndex])
                            self:_triggerAutoSave()
                        end
                    elseif key == Enum.KeyCode.Escape then
                        popup.Visible = false
                    end
                end, self)
            end
        else
            if keyNavConn then
                pcall(function() Fn.untrack(keyNavConn, self) end)
                keyNavConn = nil
            end
        end
    end)

    local function updatePopupPosition()
        local camera = getCam()
        if not camera then return end
        local chipPos = valueChip.AbsolutePosition
        local chipSize = valueChip.AbsoluteSize
        local totalHeight = math.min(#options * 32 + 44, 260)
        local viewport = camera.ViewportSize
        local width = math.min(chipSize.X, math.max(1, viewport.X - 16))
        local x = math.clamp(chipPos.X, 8, math.max(8, viewport.X - width - 8))
        local y = chipPos.Y + chipSize.Y + 6
        if y + totalHeight > viewport.Y - 8 then
            y = chipPos.Y - totalHeight - 6
        end
        y = math.clamp(y, 8, math.max(8, viewport.Y - totalHeight - 8))
        popup.Size = UDim2.fromOffset(width, totalHeight)
        popup.Position = UDim2.fromOffset(x, y)
    end

    valueChip.MouseButton1Click:Connect(function()
        self:PlaySound("Dropdown")
        if popup.Visible then
            popup.Visible = false
        else
            for _, other in ipairs(STATE.activeDropdownPopups) do
                if other.popup ~= popup then other.close() end
            end
            refreshOptions()
            updatePopupPosition()
            popup.Visible = true
            local targetPos = popup.Position
            popup.Position = UDim2.new(targetPos.X.Scale, targetPos.X.Offset, targetPos.Y.Scale, targetPos.Y.Offset + 4)
            TweenService:Create(popup, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = targetPos,
            }):Play()
        end
    end)

    table.insert(STATE.activeDropdownPopups, {
        popup = popup,
        close = function() popup.Visible = false end,
    })

    Fn.track(UserInputService.InputBegan, function(inp)
        if not popup.Visible then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local mp = inp.Position
        local pp, ps = popup.AbsolutePosition, popup.AbsoluteSize
        local bp, bs = valueChip.AbsolutePosition, valueChip.AbsoluteSize
        local inPopup = mp.X >= pp.X and mp.X <= pp.X + ps.X and mp.Y >= pp.Y and mp.Y <= pp.Y + ps.Y
        local inBtn = mp.X >= bp.X and mp.X <= bp.X + bs.X and mp.Y >= bp.Y and mp.Y <= bp.Y + bs.Y
        if not inPopup and not inBtn then popup.Visible = false end
    end, self)

    -- Reposition on demand (open / resize) instead of a 10 Hz poll that ran for
    -- the whole session, even with the popup closed.
    popup:GetPropertyChangedSignal("Visible"):Connect(function()
        if popup.Visible then task.defer(updatePopupPosition) end
    end)

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        holderStroke.Color = self._Colors.Border
        label.TextColor3 = self._Colors.Text
        valueChip.BackgroundColor3 = self._Colors.Bg2
        chipStroke.Color = self._Colors.Border
        chipLabel.TextColor3 = self._Colors.Text
        navUp.BackgroundColor3 = self._Colors.Bg2
        navUpStroke.Color = self._Colors.Border
        navUpIcon.ImageColor3 = self._Colors.TextDim
        navDown.BackgroundColor3 = self._Colors.Bg2
        navDownStroke.Color = self._Colors.Border
        navDownIcon.ImageColor3 = self._Colors.TextDim
        popup.BackgroundColor3 = self._Colors.Bg2
        popupStroke.Color = self._Colors.Accent
        popupScroll.ScrollBarImageColor3 = self._Colors.Accent
        popupSearch.BackgroundColor3 = self._Colors.Card
        if searchIcon then searchIcon.ImageColor3 = self._Colors.TextDim end
        searchBox.TextColor3 = self._Colors.Text
        searchBox.PlaceholderColor3 = self._Colors.TextDim
        for _, btn in ipairs(optionButtons) do
            btn.BackgroundColor3 = self._Colors.Card
            local checkLbl = btn:FindFirstChild("Check")
            if checkLbl then checkLbl.TextColor3 = self._Colors.Accent end
            local optLbl = btn:FindFirstChild("OptLabel")
            if optLbl then optLbl.TextColor3 = self._Colors.Text end
        end
    end)

    local searchableOptions = {}
    for _, option in ipairs(options) do
        table.insert(searchableOptions, tostring(option))
    end
    self:_bindTooltip(label, text .. " (" .. #options .. " options)")
    self:_registerSearchControl(holder, text .. " " .. table.concat(searchableOptions, " "))
    local _h = { __isHandle = true, __tag = "Dropdown", Raw = holder }
    _h.Get = function(_) return currentIndex end
    _h.GetValue = function(_) return options[currentIndex] end
    _h.Set = function(_, idx, silent)
        if type(idx) ~= "number" or idx % 1 ~= 0 then return end
        if idx < 1 or idx > #options then return end
        if currentIndex == idx then return end
        currentIndex = idx
        chipLabel.Text = tostring(options[idx])
        if not silent then callback(idx, options[idx]); self:_triggerAutoSave() end
    end
    -- SetValue takes a value (what GetValue returns), not an index: aliasing it to
    -- Set made the canonical `h:SetValue(h:GetValue())` copy a silent no-op.
    _h.SetValue = function(_, value, silent)
        local idx = table.find(options, value)
        if idx then _h:Set(idx, silent) end
    end
    local _defaultDropdownIdx = defaultIndex
    _h.Reset = function(_)
        if currentIndex == _defaultDropdownIdx then return end
        _h:Set(_defaultDropdownIdx)
    end
    return _h
end

function Library:AddMultiDropdown(page, text, options, defaults, callback)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    if type(options) ~= "table" or #options == 0 then
        error("[DoD UI] AddMultiDropdown options must be a non-empty array.")
    end
    if callback ~= nil and type(callback) ~= "function" then
        error("[DoD UI] AddMultiDropdown callback must be a function.")
    end
    callback = callback or function() end
    local selected = {}
    if type(defaults) == "table" then
        for _, idx in ipairs(defaults) do
            if type(idx) == "number" and idx >= 1 and idx <= #options then
                selected[idx] = true
            end
        end
    end

    local STATE = self._STATE
    local holder = Instance.new("Frame", page)
    holder.Size = UDim2.new(1, 0, 0, 40)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local holderStroke = Instance.new("UIStroke", holder)
    holderStroke.Color = self._Colors.Border
    holderStroke.Thickness = 1
    holderStroke.Transparency = 0.5

    local label = Instance.new("TextLabel", holder)
    label.Size = UDim2.new(0.42, -20, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = self._Colors.Text
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd

    local valueChip = Instance.new("TextButton", holder)
    valueChip.Size = UDim2.new(0.58, -14, 0, 30)
    valueChip.Position = UDim2.new(0.42, 4, 0.5, -15)
    valueChip.BackgroundColor3 = self._Colors.Bg2
    valueChip.BackgroundTransparency = 0.2
    valueChip.Text = ""
    valueChip.BorderSizePixel = 0
    valueChip.AutoButtonColor = false
    Fn.bindPressAnimation(valueChip)
    Instance.new("UICorner", valueChip).CornerRadius = UDim.new(0, 8)

    local chipStroke = Instance.new("UIStroke", valueChip)
    chipStroke.Color = self._Colors.Border
    chipStroke.Thickness = 1
    chipStroke.Transparency = 0.4

    local chipLabel = Instance.new("TextLabel", valueChip)
    chipLabel.Size = UDim2.new(1, -20, 1, 0)
    chipLabel.Position = UDim2.new(0, 12, 0, 0)
    chipLabel.BackgroundTransparency = 1
    chipLabel.TextColor3 = self._Colors.Text
    chipLabel.Font = Enum.Font.GothamBold
    chipLabel.TextSize = 11
    chipLabel.TextXAlignment = Enum.TextXAlignment.Left
    chipLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local function getSelectedIndices()
        local out = {}
        for i = 1, #options do
            if selected[i] then table.insert(out, i) end
        end
        return out
    end

    local function getSelectedValues()
        local out = {}
        for i = 1, #options do
            if selected[i] then table.insert(out, options[i]) end
        end
        return out
    end

    local function updateChipLabel()
        local indices = getSelectedIndices()
        if #indices == 0 then
            chipLabel.Text = "None"
            chipLabel.TextColor3 = self._Colors.TextDim
        elseif #indices == 1 then
            chipLabel.Text = tostring(options[indices[1]])
            chipLabel.TextColor3 = self._Colors.Text
        else
            chipLabel.Text = tostring(#indices) .. " selected"
            chipLabel.TextColor3 = self._Colors.Text
        end
    end
    updateChipLabel()

    local _textSvc = game:GetService("TextService")
    local function _adaptMultiLayout()
        local holderW = holder.AbsoluteSize.X
        if holderW <= 0 then return end
        local bounds = _textSvc:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(1000, 100))
        local rawLabelW = bounds.X + 4
        local maxLabelW = holderW * 0.55
        local labelW = math.clamp(rawLabelW, 40, maxLabelW)
        label.Size = UDim2.new(0, labelW, 1, 0)
        local gap = 10
        local chipX = 14 + labelW + gap
        local chipW = holderW - chipX - 8
        if chipW < 80 then chipW = 80 end
        valueChip.Position = UDim2.new(0, chipX, 0.5, -15)
        valueChip.Size = UDim2.new(0, chipW, 0, 30)
    end
    holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(_adaptMultiLayout)
    label:GetPropertyChangedSignal("AbsoluteSize"):Connect(_adaptMultiLayout)
    task.defer(_adaptMultiLayout)

    local popup = Instance.new("Frame", self._UI.MainGui)
    popup.Name = "MultiDropdownPopup"
    popup.BackgroundColor3 = self._Colors.Bg2
    popup.BorderSizePixel = 0
    popup.Visible = false
    popup.ZIndex = 200
    popup.ClipsDescendants = true
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 8)

    local popupStroke = Instance.new("UIStroke", popup)
    popupStroke.Color = self._Colors.Accent
    popupStroke.Thickness = 1
    popupStroke.Transparency = 0.3

    local mdSearchFrame = Instance.new("Frame", popup)
    mdSearchFrame.Name = "SearchFrame"
    mdSearchFrame.Size = UDim2.new(1, -10, 0, 24)
    mdSearchFrame.Position = UDim2.new(0, 5, 0, 5)
    mdSearchFrame.BackgroundColor3 = self._Colors.Card
    mdSearchFrame.BackgroundTransparency = 0.5
    mdSearchFrame.BorderSizePixel = 0
    mdSearchFrame.ZIndex = 202
    Instance.new("UICorner", mdSearchFrame).CornerRadius = UDim.new(0, 4)

    local mdSearchIcon = Instance.new("ImageLabel", mdSearchFrame)
    mdSearchIcon.Name = "SearchIcon"
    mdSearchIcon.Size = UDim2.fromOffset(14, 14)
    mdSearchIcon.Position = UDim2.new(0, 8, 0.5, -7)
    mdSearchIcon.BackgroundTransparency = 1
    mdSearchIcon.Image = GetIcon("search")
    mdSearchIcon.ImageColor3 = self._Colors.TextDim
    mdSearchIcon.ScaleType = Enum.ScaleType.Fit
    mdSearchIcon.ZIndex = 203

    local mdSearchBox = Instance.new("TextBox", mdSearchFrame)
    mdSearchBox.Name = "SearchBox"
    mdSearchBox.Size = UDim2.new(1, -108, 1, 0)
    mdSearchBox.Position = UDim2.new(0, 28, 0, 0)
    mdSearchBox.BackgroundTransparency = 1
    mdSearchBox.Text = ""
    mdSearchBox.PlaceholderText = "Search..."
    mdSearchBox.PlaceholderColor3 = self._Colors.TextDim
    mdSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    mdSearchBox.TextStrokeTransparency = 1
    mdSearchBox.Font = Enum.Font.GothamMedium
    mdSearchBox.TextSize = 11
    mdSearchBox.TextXAlignment = Enum.TextXAlignment.Left
    mdSearchBox.ClearTextOnFocus = false
    mdSearchBox.ZIndex = 203

    local mdAllBtn = Instance.new("TextButton", mdSearchFrame)
    mdAllBtn.Name = "AllBtn"
    mdAllBtn.Size = UDim2.new(0, 32, 0, 20)
    mdAllBtn.Position = UDim2.new(1, -76, 0.5, -10)
    mdAllBtn.BackgroundColor3 = self._Colors.Accent
    mdAllBtn.BackgroundTransparency = 0.7
    mdAllBtn.Text = "All"
    mdAllBtn.TextColor3 = self._Colors.Accent
    mdAllBtn.Font = Enum.Font.GothamBold
    mdAllBtn.TextSize = 10
    mdAllBtn.AutoButtonColor = false
    mdAllBtn.ZIndex = 203
    Instance.new("UICorner", mdAllBtn).CornerRadius = UDim.new(0, 3)

    local mdNoneBtn = Instance.new("TextButton", mdSearchFrame)
    mdNoneBtn.Name = "NoneBtn"
    mdNoneBtn.Size = UDim2.new(0, 32, 0, 20)
    mdNoneBtn.Position = UDim2.new(1, -40, 0.5, -10)
    mdNoneBtn.BackgroundColor3 = self._Colors.Card
    mdNoneBtn.BackgroundTransparency = 0.3
    mdNoneBtn.Text = "None"
    mdNoneBtn.TextColor3 = self._Colors.TextDim
    mdNoneBtn.Font = Enum.Font.GothamBold
    mdNoneBtn.TextSize = 9
    mdNoneBtn.AutoButtonColor = false
    mdNoneBtn.ZIndex = 203
    Instance.new("UICorner", mdNoneBtn).CornerRadius = UDim.new(0, 3)

    local popupScroll = Instance.new("ScrollingFrame", popup)
    popupScroll.Size = UDim2.new(1, 0, 1, -34)
    popupScroll.Position = UDim2.new(0, 0, 0, 34)
    popupScroll.BackgroundTransparency = 1
    popupScroll.BorderSizePixel = 0
    popupScroll.ScrollBarThickness = 3
    popupScroll.ScrollBarImageColor3 = self._Colors.Accent
    popupScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    popupScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    popupScroll.ZIndex = 201
    self:_registerScrollFrame(popupScroll)

    local popupList = Instance.new("UIListLayout", popupScroll)
    popupList.SortOrder = Enum.SortOrder.LayoutOrder
    popupList.Padding = UDim.new(0, 2)

    local popupPad = Instance.new("UIPadding", popupScroll)
    popupPad.PaddingTop = UDim.new(0, 5)
    popupPad.PaddingBottom = UDim.new(0, 5)
    popupPad.PaddingLeft = UDim.new(0, 5)
    popupPad.PaddingRight = UDim.new(0, 5)

    local optionButtons = {}

    mdSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = string.lower(mdSearchBox.Text)
        for _, btn in ipairs(optionButtons) do
            local optLbl = btn:FindFirstChild("MultiLabel")
            if optLbl then
                local txt = string.lower(optLbl.Text)
                btn.Visible = (q == "" or string.find(txt, q, 1, true) ~= nil)
            end
        end
    end)

    local optionsBuilt = false
    local function refreshOptions()
        if mdSearchBox and mdSearchBox.Text ~= "" then mdSearchBox.Text = "" end
        if optionsBuilt then
            -- Built once, then only the checkbox state is re-synced. Every open
            -- used to destroy and recreate ~8 instances per option.
            for i, btn in ipairs(optionButtons) do
                local isSel = selected[i] == true
                local box = btn:FindFirstChild("CheckBox")
                if box then
                    box.BackgroundColor3 = isSel and self._Colors.Accent or self._Colors.Bg
                    local stroke = box:FindFirstChildOfClass("UIStroke")
                    if stroke then
                        stroke.Color = isSel and self._Colors.Accent or self._Colors.Border
                    end
                    local chk = box:FindFirstChild("CheckMark")
                    if chk then chk.Visible = isSel end
                end
                if not btn.Visible then btn.Visible = true end
            end
            return
        end
        optionsBuilt = true
        for _, b in ipairs(optionButtons) do b:Destroy() end
        table.clear(optionButtons)
        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton", popupScroll)
            optBtn.Size = UDim2.new(1, 0, 0, 30)
            optBtn.BackgroundColor3 = self._Colors.Card
            optBtn.BackgroundTransparency = 1
            optBtn.Text = ""
            optBtn.BorderSizePixel = 0
            optBtn.AutoButtonColor = false
            optBtn.ZIndex = 202
            Fn.bindPressAnimation(optBtn)
            Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 5)

            local box = Instance.new("Frame", optBtn)
            box.Name = "CheckBox"
            box.Size = UDim2.fromOffset(16, 16)
            box.Position = UDim2.new(0, 10, 0.5, -8)
            box.BackgroundColor3 = selected[i] and self._Colors.Accent or self._Colors.Bg
            box.BorderSizePixel = 0
            box.ZIndex = 203
            Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

            local boxStroke = Instance.new("UIStroke", box)
            boxStroke.Color = selected[i] and self._Colors.Accent or self._Colors.Border
            boxStroke.Thickness = 1

            local check = Instance.new("TextLabel", box)
            check.Name = "CheckMark"
            check.Size = UDim2.fromScale(1, 1)
            check.BackgroundTransparency = 1
            check.Text = "✓"
            check.TextColor3 = Fn.accentTextColor(self._Colors.Accent)
            check.Font = Enum.Font.GothamBlack
            check.TextSize = 11
            check.Visible = selected[i] and true or false
            check.ZIndex = 204

            local optLabel = Instance.new("TextLabel", optBtn)
            optLabel.Name = "MultiLabel"
            optLabel.Size = UDim2.new(1, -50, 1, 0)
            optLabel.Position = UDim2.new(0, 34, 0, 0)
            optLabel.BackgroundTransparency = 1
            optLabel.Text = tostring(opt)
            optLabel.TextColor3 = self._Colors.Text
            optLabel.Font = Enum.Font.GothamBold
            optLabel.TextSize = 12
            optLabel.TextXAlignment = Enum.TextXAlignment.Left
            optLabel.ZIndex = 203

            optBtn.MouseEnter:Connect(function() optBtn.BackgroundTransparency = 0.4 end)
            optBtn.MouseLeave:Connect(function() optBtn.BackgroundTransparency = 1 end)
            optBtn.MouseButton1Click:Connect(function()
                if selected[i] then
                    selected[i] = nil
                else
                    selected[i] = true
                end
                box.BackgroundColor3 = selected[i] and self._Colors.Accent or self._Colors.Bg
                boxStroke.Color = selected[i] and self._Colors.Accent or self._Colors.Border
                check.Visible = selected[i] and true or false
                updateChipLabel()
                callback(getSelectedIndices(), getSelectedValues())
                self:_triggerAutoSave()
            end)
            table.insert(optionButtons, optBtn)
        end
    end

    mdAllBtn.MouseButton1Click:Connect(function()
        for i = 1, #options do selected[i] = true end
        for i, btn in ipairs(optionButtons) do
            local box = btn:FindFirstChild("CheckBox")
            if box then
                box.BackgroundColor3 = self._Colors.Accent
                local stroke = box:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Color = self._Colors.Accent end
                local chk = box:FindFirstChild("CheckMark")
                if chk then chk.Visible = true end
            end
        end
        updateChipLabel()
        callback(getSelectedIndices(), getSelectedValues())
        self:_triggerAutoSave()
    end)

    mdNoneBtn.MouseButton1Click:Connect(function()
        table.clear(selected)
        for i, btn in ipairs(optionButtons) do
            local box = btn:FindFirstChild("CheckBox")
            if box then
                box.BackgroundColor3 = self._Colors.Bg
                local stroke = box:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Color = self._Colors.Border end
                local chk = box:FindFirstChild("CheckMark")
                if chk then chk.Visible = false end
            end
        end
        updateChipLabel()
        callback(getSelectedIndices(), getSelectedValues())
        self:_triggerAutoSave()
    end)

    local function updatePopupPosition()
        local camera = getCam()
        if not camera then return end
        local chipPos = valueChip.AbsolutePosition
        local chipSize = valueChip.AbsoluteSize
        local totalHeight = math.min(#options * 32 + 44, 260)
        local viewport = camera.ViewportSize
        local width = math.min(chipSize.X, math.max(1, viewport.X - 16))
        local x = math.clamp(chipPos.X, 8, math.max(8, viewport.X - width - 8))
        local y = chipPos.Y + chipSize.Y + 6
        if y + totalHeight > viewport.Y - 8 then
            y = chipPos.Y - totalHeight - 6
        end
        y = math.clamp(y, 8, math.max(8, viewport.Y - totalHeight - 8))
        popup.Size = UDim2.fromOffset(width, totalHeight)
        popup.Position = UDim2.fromOffset(x, y)
    end

    valueChip.MouseButton1Click:Connect(function()
        self:PlaySound("Dropdown")
        if popup.Visible then
            popup.Visible = false
        else
            for _, other in ipairs(STATE.activeDropdownPopups) do
                if other.popup ~= popup then other.close() end
            end
            refreshOptions()
            updatePopupPosition()
            popup.Visible = true
            local targetPos = popup.Position
            popup.Position = UDim2.new(targetPos.X.Scale, targetPos.X.Offset, targetPos.Y.Scale, targetPos.Y.Offset + 4)
            TweenService:Create(popup, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = targetPos,
            }):Play()
        end
    end)

    table.insert(STATE.activeDropdownPopups, {
        popup = popup,
        close = function() popup.Visible = false end,
    })

    Fn.track(UserInputService.InputBegan, function(inp)
        if not popup.Visible then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local mp = inp.Position
        local pp, ps = popup.AbsolutePosition, popup.AbsoluteSize
        local bp, bs = valueChip.AbsolutePosition, valueChip.AbsoluteSize
        local inPopup = mp.X >= pp.X and mp.X <= pp.X + ps.X and mp.Y >= pp.Y and mp.Y <= pp.Y + ps.Y
        local inBtn = mp.X >= bp.X and mp.X <= bp.X + bs.X and mp.Y >= bp.Y and mp.Y <= bp.Y + bs.Y
        if not inPopup and not inBtn then popup.Visible = false end
    end, self)

    -- Same as the single dropdown: no permanent 10 Hz poll.
    popup:GetPropertyChangedSignal("Visible"):Connect(function()
        if popup.Visible then task.defer(updatePopupPosition) end
    end)

    local _favId = self:_getConfigId("multi_dropdown", text)
    self:_registerConfigState(_favId,
        function() return getSelectedIndices() end,
        function(v, silent)
            if type(v) ~= "table" then return end
            table.clear(selected)
            for _, idx in ipairs(v) do
                if type(idx) == "number" and idx >= 1 and idx <= #options then
                    selected[idx] = true
                end
            end
            updateChipLabel()
            if not silent then
                callback(getSelectedIndices(), getSelectedValues())
                self:_triggerAutoSave()
            end
        end
    )
    self:_attachFavorite(holder, _favId)

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        holderStroke.Color = self._Colors.Border
        label.TextColor3 = self._Colors.Text
        valueChip.BackgroundColor3 = self._Colors.Bg2
        chipStroke.Color = self._Colors.Border
        updateChipLabel()
        popup.BackgroundColor3 = self._Colors.Bg2
        popupStroke.Color = self._Colors.Accent
        popupScroll.ScrollBarImageColor3 = self._Colors.Accent
        for _, btn in ipairs(optionButtons) do
            btn.BackgroundColor3 = self._Colors.Card
            local box = btn:FindFirstChild("CheckBox")
            if box then
                local chk = box:FindFirstChild("CheckMark")
                local isSel = chk and chk.Visible
                box.BackgroundColor3 = isSel and self._Colors.Accent or self._Colors.Bg
                local stroke = box:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Color = isSel and self._Colors.Accent or self._Colors.Border end
                if chk then chk.TextColor3 = Fn.accentTextColor(self._Colors.Accent) end
            end
            local optLbl = btn:FindFirstChild("MultiLabel")
            if optLbl then optLbl.TextColor3 = self._Colors.Text end
        end
    end)

    local searchableOptions = {}
    for _, option in ipairs(options) do
        table.insert(searchableOptions, tostring(option))
    end
    self:_bindTooltip(label, text .. " (" .. #options .. " options)")
    self:_registerSearchControl(holder, text .. " " .. table.concat(searchableOptions, " "))
    local _h = { __isHandle = true, __tag = "MultiDropdown", Raw = holder }
    _h.Get = function(_) return getSelectedIndices() end
    _h.GetValue = function(_) return getSelectedValues() end
    _h.Set = function(_, indices, silent)
        if type(indices) ~= "table" then return end
        table.clear(selected)
        for _, idx in ipairs(indices) do
            if type(idx) == "number" and idx >= 1 and idx <= #options then
                selected[idx] = true
            end
        end
        updateChipLabel()
        if not silent then callback(getSelectedIndices(), getSelectedValues()); self:_triggerAutoSave() end
    end
    -- SetValue accepts the values array that GetValue returns.
    _h.SetValue = function(_, values, silent)
        if type(values) ~= "table" then return end
        local indices = {}
        for _, value in ipairs(values) do
            local idx = table.find(options, value)
            if idx then table.insert(indices, idx) end
        end
        _h:Set(indices, silent)
    end
    local _defaultMultiIdx = {}
    if type(defaults) == "table" then
        for _, idx in ipairs(defaults) do table.insert(_defaultMultiIdx, idx) end
    end
    _h.Reset = function(_)
        _h:Set(_defaultMultiIdx)
    end
    return _h
end

function Library:AddConfigList(page, onLoad)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    local holder = Instance.new("Frame", page)
    holder.Name = "ConfigList"
    holder.Size = UDim2.new(1, 0, 0, 220)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local topBar = Instance.new("Frame", holder)
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.BackgroundTransparency = 1
    topBar.ZIndex = 2

    local title = Instance.new("TextLabel", topBar)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "SAVED CONFIGS"
    title.TextColor3 = self._Colors.Text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left

    local refreshBtn = Instance.new("TextButton", topBar)
    refreshBtn.Size = UDim2.fromOffset(24, 24)
    refreshBtn.Position = UDim2.new(1, -32, 0.5, -12)
    refreshBtn.BackgroundTransparency = 1
    refreshBtn.Text = ""
    refreshBtn.AutoButtonColor = false

    local refreshIcon = Instance.new("ImageLabel", refreshBtn)
    refreshIcon.Size = UDim2.fromScale(1, 1)
    refreshIcon.BackgroundTransparency = 1
    refreshIcon.Image = GetIcon("refresh-cw")
    refreshIcon.ImageColor3 = self._Colors.TextDim

    local copyBtn = Instance.new("TextButton", topBar)
    copyBtn.Size = UDim2.fromOffset(24, 24)
    copyBtn.Position = UDim2.new(1, -60, 0.5, -12)
    copyBtn.BackgroundTransparency = 1
    copyBtn.Text = ""
    copyBtn.AutoButtonColor = false

    local copyIcon = Instance.new("ImageLabel", copyBtn)
    copyIcon.Size = UDim2.fromScale(1, 1)
    copyIcon.BackgroundTransparency = 1
    copyIcon.Image = GetIcon("copy")
    copyIcon.ImageColor3 = self._Colors.TextDim

    local pasteBtn = Instance.new("TextButton", topBar)
    pasteBtn.Size = UDim2.fromOffset(24, 24)
    pasteBtn.Position = UDim2.new(1, -88, 0.5, -12)
    pasteBtn.BackgroundTransparency = 1
    pasteBtn.Text = ""
    pasteBtn.AutoButtonColor = false

    local pasteIcon = Instance.new("ImageLabel", pasteBtn)
    pasteIcon.Size = UDim2.fromScale(1, 1)
    pasteIcon.BackgroundTransparency = 1
    pasteIcon.Image = GetIcon("clipboard-paste")
    pasteIcon.ImageColor3 = self._Colors.TextDim
    
    copyBtn.MouseButton1Click:Connect(function()
        self:PlaySound("Click")
        local data = self:ExportConfig()
        local ok, json = pcall(function()
            return game:GetService("HttpService"):JSONEncode(data)
        end)
        if ok and json then
            if setclipboard then
                setclipboard(json)
                self:Notify("CONFIG", "Config copied to clipboard!", "success")
            else
                self:Notify("CONFIG", "Clipboard not supported", "error")
            end
        end
    end)
    
    pasteBtn.MouseButton1Click:Connect(function()
        self:PlaySound("Click")
        if getclipboard then
            local json = getclipboard()
            local ok, data = pcall(function()
                return game:GetService("HttpService"):JSONDecode(json)
            end)
            if ok and data then
                self:ImportConfig(data)
            else
                self:Notify("CONFIG", "Invalid JSON in clipboard", "error")
            end
        else
            self:Notify("CONFIG", "Clipboard not supported", "error")
        end
    end)

    local scroll = Instance.new("ScrollingFrame", holder)
    scroll.Size = UDim2.new(1, -16, 1, -38)
    scroll.Position = UDim2.new(0, 8, 0, 34)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = self._Colors.Accent
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex = 2

    local list = Instance.new("UIListLayout", scroll)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 4)

    local emptyLabel = Instance.new("TextLabel", scroll)
    emptyLabel.Size = UDim2.new(1, 0, 0, 30)
    emptyLabel.BackgroundTransparency = 1
    emptyLabel.Text = "No configs found."
    emptyLabel.TextColor3 = self._Colors.TextDim
    emptyLabel.Font = Enum.Font.GothamMedium
    emptyLabel.TextSize = 10
    emptyLabel.ZIndex = 2

    local function refreshList()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local configs = self:GetConfigs(true)
        emptyLabel.Visible = (#configs == 0)
        
        for i, cfg in ipairs(configs) do
            local row = Instance.new("TextButton", scroll)
            row.Size = UDim2.new(1, 0, 0, 36)
            row.BackgroundColor3 = self._Colors.Bg2
            row.BackgroundTransparency = 1
            row.Text = ""
            row.AutoButtonColor = false
            row.BorderSizePixel = 0
            row.ZIndex = 3
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

            local hoverStroke = Instance.new("UIStroke", row)
            hoverStroke.Color = self._Colors.Border
            hoverStroke.Transparency = 1
            hoverStroke.Thickness = 1

            local icon = Instance.new("ImageLabel", row)
            icon.Size = UDim2.fromOffset(14, 14)
            icon.Position = UDim2.new(0, 8, 0.5, -7)
            icon.BackgroundTransparency = 1
            icon.Image = GetIcon("file-clock")
            icon.ImageColor3 = self._Colors.Accent
            icon.ZIndex = 4

            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size = UDim2.new(1, -150, 0, 14)
            nameLbl.Position = UDim2.new(0, 28, 0, 4)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = cfg.name
            nameLbl.TextColor3 = self._Colors.Text
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 11
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nameLbl.ZIndex = 4

            local dateLbl = Instance.new("TextLabel", row)
            dateLbl.Name = "Date"
            dateLbl.Size = UDim2.new(1, -150, 0, 12)
            dateLbl.Position = UDim2.new(0, 28, 0, 18)
            dateLbl.BackgroundTransparency = 1
            if cfg.time and cfg.time > 0 then
                dateLbl.Text = os.date("%d %b %Y, %H:%M", cfg.time)
            else
                dateLbl.Text = "Unknown Date"
            end
            dateLbl.TextColor3 = self._Colors.TextDim
            dateLbl.Font = Enum.Font.GothamMedium
            dateLbl.TextSize = 9
            dateLbl.TextXAlignment = Enum.TextXAlignment.Left
            dateLbl.ZIndex = 4

            local loadBtn = Instance.new("TextButton", row)
            loadBtn.Name = "LoadBtn"
            loadBtn.Size = UDim2.fromOffset(48, 22)
            loadBtn.Position = UDim2.new(1, -108, 0.5, -11)
            loadBtn.BackgroundColor3 = self._Colors.Accent
            loadBtn.BackgroundTransparency = 0.8
            loadBtn.Text = "Load"
            loadBtn.TextColor3 = self._Colors.Accent
            loadBtn.Font = Enum.Font.GothamBold
            loadBtn.TextSize = 10
            loadBtn.AutoButtonColor = false
            loadBtn.ZIndex = 4
            Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 4)

            local delBtn = Instance.new("TextButton", row)
            delBtn.Size = UDim2.fromOffset(22, 22)
            delBtn.Position = UDim2.new(1, -54, 0.5, -11)
            delBtn.BackgroundColor3 = self._Colors.Red
            delBtn.BackgroundTransparency = 0.8
            delBtn.Text = ""
            delBtn.AutoButtonColor = false
            delBtn.ZIndex = 4
            Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 4)
            
            local delIcon = Instance.new("ImageLabel", delBtn)
            delIcon.Size = UDim2.fromOffset(12, 12)
            delIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
            delIcon.BackgroundTransparency = 1
            delIcon.Image = GetIcon("trash-2")
            delIcon.ImageColor3 = self._Colors.Red
            delIcon.ZIndex = 5

            row.MouseEnter:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.15), {BackgroundTransparency = 0.85}):Play()
                TweenService:Create(hoverStroke, TweenInfo.new(0.15), {Transparency = 0.7}):Play()
            end)
            row.MouseLeave:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
                TweenService:Create(hoverStroke, TweenInfo.new(0.15), {Transparency = 1}):Play()
            end)

            loadBtn.MouseEnter:Connect(function() TweenService:Create(loadBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play() end)
            loadBtn.MouseLeave:Connect(function() TweenService:Create(loadBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.8}):Play() end)
            loadBtn.MouseButton1Click:Connect(function()
                self:PlaySound("Click")
                -- Only fire onLoad when the load actually succeeded.
                if self:LoadConfig(cfg.name) then
                    if onLoad then onLoad(cfg.name) end
                end
            end)

            delBtn.MouseEnter:Connect(function() TweenService:Create(delBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play() end)
            delBtn.MouseLeave:Connect(function() TweenService:Create(delBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.8}):Play() end)
            delBtn.MouseButton1Click:Connect(function()
                self:PlaySound("Click")
                local deleted = false
                if cfg.file and type(delfile) == "function" then
                    deleted = pcall(delfile, cfg.file)
                end
                local g = (getgenv and getgenv()) or _G
                if g.__DoDConfigs then g.__DoDConfigs[cfg.name] = nil end
                if not deleted and cfg.file then
                    -- Do not silently pretend: the row will reappear otherwise.
                    self:Notify("CONFIG", "Delete failed: " .. tostring(cfg.name), "error")
                end
                refreshList()
            end)
        end
    end

    refreshBtn.MouseEnter:Connect(function()
        TweenService:Create(refreshIcon, TweenInfo.new(0.2), {Rotation = 180}):Play()
        refreshIcon.ImageColor3 = self._Colors.Text
    end)
    refreshBtn.MouseLeave:Connect(function()
        TweenService:Create(refreshIcon, TweenInfo.new(0.2), {Rotation = 0}):Play()
        refreshIcon.ImageColor3 = self._Colors.TextDim
    end)
    refreshBtn.MouseButton1Click:Connect(function()
        self:PlaySound("Click")
        refreshList()
    end)

    refreshList()

    local _h = { __isHandle = true, __tag = "ConfigList", Raw = holder }
    _h.Refresh = function(_) refreshList() end
    _h.SetVisible = function(_, v) holder.Visible = v and true or false end

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        title.TextColor3 = self._Colors.Text
        emptyLabel.TextColor3 = self._Colors.TextDim
        scroll.ScrollBarImageColor3 = self._Colors.Accent
        refreshIcon.ImageColor3 = self._Colors.TextDim
        copyIcon.ImageColor3 = self._Colors.TextDim
        pasteIcon.ImageColor3 = self._Colors.TextDim
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = self._Colors.Bg2
                local _childStroke = child:FindFirstChildOfClass("UIStroke")
                if _childStroke then _childStroke.Color = self._Colors.Border end
                local nameLbl = child:FindFirstChildOfClass("TextLabel")
                if nameLbl then nameLbl.TextColor3 = self._Colors.Text end
                local dateLbl = child:FindFirstChild("Date")
                if dateLbl then dateLbl.TextColor3 = self._Colors.TextDim end
                local icon = child:FindFirstChildOfClass("ImageLabel")
                if icon then icon.ImageColor3 = self._Colors.Accent end
                local loadB = child:FindFirstChild("LoadBtn")
                if loadB then
                    loadB.BackgroundColor3 = self._Colors.Accent
                    loadB.TextColor3 = self._Colors.Accent
                end
            end
        end
    end)

    return _h
end

function Library:AddKeybind(page, text, default, callback)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    local function _normSpec(spec)
        if spec == nil then return nil, {} end
        if typeof(spec) == "EnumItem" and spec.EnumType == Enum.KeyCode then
            return spec, {}
        end
        if spec == "LClick" or spec == "RClick" then
            return spec, {}
        end
        if type(spec) == "table" then
            local mods = spec.Modifiers or spec.mods or {}
            if type(mods) ~= "table" then mods = {} end
            local key = spec.Key or spec.key
            if key == nil then return nil, {} end
            return key, mods
        end
        return nil, {}
    end
    local _initKey, _initMods = _normSpec(default)
    if default ~= nil and not (
        (typeof(default) == "EnumItem" and default.EnumType == Enum.KeyCode)
        or default == "LClick" or default == "RClick"
        or (type(default) == "table" and (default.Key ~= nil or default.key ~= nil))
    ) then
        error("[DoD UI] AddKeybind default must be Enum.KeyCode, LClick, RClick, table, or nil.")
    end
    if callback ~= nil and type(callback) ~= "function" then
        error("[DoD UI] AddKeybind callback must be a function.")
    end
    local STATE = self._STATE
    local holder = Instance.new("Frame", page)
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local lab = Instance.new("TextLabel", holder)
    lab.Size = UDim2.new(1, -136, 1, 0)
    lab.Position = UDim2.new(0, 12, 0, 0)
    lab.BackgroundTransparency = 1
    lab.Text = text
    lab.TextColor3 = self._Colors.Text
    lab.Font = Enum.Font.GothamBold
    lab.TextSize = 13
    lab.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", holder)
    btn.Size = UDim2.new(0, 110, 0, 28)
    btn.Position = UDim2.new(1, -122, 0.5, -14)
    btn.BackgroundColor3 = self._Colors.Bg2
    btn.BackgroundTransparency = 0.2
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    Fn.bindPressAnimation(btn)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local btnGrad = Instance.new("UIGradient", btn)
    btnGrad.Color = ColorSequence.new(self._Colors.Bg2, self._Colors.Bg)
    btnGrad.Rotation = 90

    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = self._Colors.Border
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.5

    local btnIcon = Instance.new("ImageLabel", btn)
    btnIcon.Size = UDim2.fromOffset(14, 14)
    btnIcon.Position = UDim2.new(0, 10, 0.5, -7)
    btnIcon.BackgroundTransparency = 1
    btnIcon.Image = GetIcon("keyboard")
    btnIcon.ImageColor3 = self._Colors.TextDim

    local btnText = Instance.new("TextLabel", btn)
    btnText.Size = UDim2.new(1, -34, 1, 0)
    btnText.Position = UDim2.new(0, 28, 0, 0)
    btnText.BackgroundTransparency = 1
    btnText.Text = "NONE"
    btnText.TextColor3 = self._Colors.Text
    btnText.Font = Enum.Font.GothamBold
    btnText.TextSize = 11
    btnText.TextXAlignment = Enum.TextXAlignment.Left

    local listener
    local function _formatKeyName(k)
        if typeof(k) == "EnumItem" then
            return string.upper(k.Name)
        elseif k == nil then
            return "NONE"
        else
            return string.upper(tostring(k))
        end
    end
    local function setLabel(k, mods)
        mods = mods or {}
        local baseName = _formatKeyName(k)
        local keyName = baseName
        if #mods > 0 then
            keyName = table.concat(mods, "+") .. "+" .. baseName
        end
        btnText.Text = keyName
        btnIcon.ImageColor3 = (k ~= nil) and self._Colors.Accent or self._Colors.TextDim
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.5}):Play()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
        if listener then
            listener.key = k
            listener.mods = mods
            listener.keyName = keyName
            self:_refreshKeybindOverlay()
        end
    end
    setLabel(_initKey, _initMods)

    btn.MouseEnter:Connect(function()
        self:PlaySound("Hover")
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0.1}):Play()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
    end)

    btn.MouseLeave:Connect(function()
        if listener and listener.active then return end
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.5}):Play()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
    end)

    listener = {
        active = false,
        btn = btn,
        btnText = btnText,
        btnStroke = btnStroke,
        btnIcon = btnIcon,
        callback = callback or function() end,
        name = tostring(text),
        key = _initKey,
        mods = _initMods,
        keyName = btnText.Text,
        setKey = setLabel,
    }
    table.insert(STATE.activeKeybindListeners, listener)
    local _favId = self:_getConfigId("keybind", text)
    self:_registerConfigState(_favId,
        function() return listener.keyName end,
        function(v, silent)
            if type(v) ~= "string" then return end
            local _k, _mods = nil, {}
            local _upper = string.upper(v)
            if _upper == "LCLICK" then _k = "LClick"
            elseif _upper == "RCLICK" then _k = "RClick"
            elseif _upper ~= "NONE" and v ~= "" then
                local _ok, _e = pcall(function() return Enum.KeyCode[_upper] end)
                if _ok and _e then _k = _e
                else
                    if listener.btnText then listener.btnText.Text = v end
                    return
                end
            end
            listener.setKey(_k, _mods)
        end
    )
    self:_attachFavorite(holder, _favId)
    if not STATE._overlayAutoShown then
        STATE._overlayAutoShown = true
        -- MOBILE: keybind overlay toggle is a desktop-only affordance. On touch
        -- there is no keyboard to rebind, and the pill clutters the bottom-right
        -- of the screen. Desktop path is unchanged.
        if not self._isMobile then
            self._UI.KeybindOverlayToggle.Visible = true
        end
    end
    self:_refreshKeybindOverlay()

    if not self._isMobile then
        btn.MouseButton1Click:Connect(function()
            self:PlaySound("Click")
            if listener.active then
                listener.active = false
                self._keybindCapturing = false
                btnText.Text = listener.keyName
                TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.5}):Play()
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
                return
            end
            for _, l in ipairs(STATE.activeKeybindListeners) do 
                l.active = false
                if l.btnText then l.btnText.Text = l.keyName end
                if l.btnStroke then TweenService:Create(l.btnStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.5}):Play() end
            end
            listener.active = true
            self._keybindCapturing = true
            btnText.Text = "PRESS A KEY..."
            TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0}):Play()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
        end)
    end

    if not STATE._kbListenerInstalled then
        STATE._kbListenerInstalled = true
        local function getMods()
            local m = {}
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                table.insert(m, "Ctrl")
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
                table.insert(m, "Shift")
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
                table.insert(m, "Alt")
            end
            return m
        end
        local function modsMatch(stored, current)
            stored = stored or {}
            current = current or {}
            if #stored ~= #current then return false end
            for _, v in ipairs(stored) do
                if not table.find(current, v) then return false end
            end
            return true
        end
        Fn.track(UserInputService.InputBegan, function(inp, proc)
            if proc then return end
            for _, l in ipairs(STATE.activeKeybindListeners) do
                local mp = inp.Position
                local bp, bs = l.btn.AbsolutePosition, l.btn.AbsoluteSize
                local onClickBtn = mp.X >= bp.X and mp.X <= bp.X + bs.X
                    and mp.Y >= bp.Y and mp.Y <= bp.Y + bs.Y
                if l.active then
                    if not onClickBtn then
                        l.active = false
                        self._keybindCapturing = false
                        local capturedMods = getMods()
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            l.setKey(inp.KeyCode, capturedMods)
                            l.callback(inp.KeyCode, capturedMods)
                        elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            l.setKey("LClick", capturedMods)
                            l.callback(Enum.UserInputType.MouseButton1, capturedMods)
                        elseif inp.UserInputType == Enum.UserInputType.MouseButton2 then
                            l.setKey("RClick", capturedMods)
                            l.callback(Enum.UserInputType.MouseButton2, capturedMods)
                        elseif inp.UserInputType == Enum.UserInputType.Touch then
                            l.setKey("LClick", capturedMods)
                            l.callback(Enum.UserInputType.MouseButton1, capturedMods)
                        else
                            -- Gamepad / wheel / focus: not bindable. Restore the
                            -- label instead of leaving "PRESS A KEY..." stuck.
                            l.setKey(l.key, l.mods)
                        end
                    end
                elseif l.key ~= nil and not onClickBtn then
                    local currentMods = getMods()
                    local matched = false
                    local firedKey = nil
                    if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == l.key then
                        matched = true
                        firedKey = l.key
                    elseif inp.UserInputType == Enum.UserInputType.MouseButton1 and l.key == "LClick" then
                        matched = true
                        firedKey = Enum.UserInputType.MouseButton1
                    elseif inp.UserInputType == Enum.UserInputType.MouseButton2 and l.key == "RClick" then
                        matched = true
                        firedKey = Enum.UserInputType.MouseButton2
                    elseif inp.UserInputType == Enum.UserInputType.Touch and l.key == "LClick" then
                        matched = true
                        firedKey = Enum.UserInputType.MouseButton1
                    end
                    if matched and modsMatch(l.mods, currentMods) then
                        -- No autosave here: firing a bind does not change any
                        -- persisted value (it used to rewrite the config every
                        -- 0.6s whenever a movement key was held).
                        l.callback(firedKey, l.mods)
                    end
                end
            end
        end, self)
    end

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        lab.TextColor3 = self._Colors.Text
        btnGrad.Color = ColorSequence.new(self._Colors.Bg2, self._Colors.Bg)
        btnText.TextColor3 = self._Colors.Text
        if listener and listener.key ~= nil then
            btnIcon.ImageColor3 = self._Colors.Accent
        else
            btnIcon.ImageColor3 = self._Colors.TextDim
        end
    end)
    self:_bindTooltip(lab, text .. " — click to rebind")
    self:_registerSearchControl(holder, text)
    local _h = { __isHandle = true, __tag = "Keybind", Raw = holder }
    _h.Get = function(_) return listener.keyName end
    _h.GetValue = function(_) return { key = listener.key, mods = listener.mods } end
    _h.Set = function(_, key, mods, silent)
        if type(mods) ~= "table" then mods = {} end
        if key == nil then
            -- Unbinding used to be impossible, so "NONE" could never be reached
            -- through the API even though the UI can display it.
            listener.setKey(nil, {})
            if not silent then
                pcall(listener.callback, nil, {})
                self:_triggerAutoSave()
            end
            return
        end
        local k = key
        if type(key) == "string" and key ~= "LClick" and key ~= "RClick" then
            local ok, enum = pcall(function() return Enum.KeyCode[key] end)
            if ok and enum then
                k = enum
            else
                -- Storing the raw string left a bind that looked set but could
                -- never match an EnumItem, so it silently never fired.
                warn("[DoD UI] Keybind.Set: unknown key name '" .. tostring(key) .. "'")
                return
            end
        end
        listener.setKey(k, mods)
        if not silent then
            local _ok, _err = pcall(listener.callback, k, mods)
            if not _ok then warn("[DoD UI] Keybind set callback error: " .. tostring(_err)) end
            self:_triggerAutoSave()
        end
    end
    _h.SetValue = _h.Set
    _h.SetVisible = function(_, v) holder.Visible = v and true or false end
    return _h
end

function Library:AddButton(page, text, callback)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    if callback ~= nil and type(callback) ~= "function" then
        error("[DoD UI] AddButton callback must be a function.")
    end
    callback = callback or function() end
    local _isMobBtn = self._isMobile
    local _btnRowH = _isMobBtn and 56 or 42
    local _btnH = _isMobBtn and 44 or 32
    local _btnY = _isMobBtn and 6 or 5
    local _btnTxtMin = _isMobBtn and 12 or 9
    local _btnTxtMax = _isMobBtn and 15 or 12
    local holder = Instance.new("Frame", page)
    holder.Size = UDim2.new(1, 0, 0, _btnRowH)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local btn = Instance.new("TextButton", holder)
    btn.Size = UDim2.new(1, -24, 0, _btnH)
    btn.Position = UDim2.new(0, 12, 0, _btnY)
    btn.Text = text
    btn.BackgroundColor3 = self._Colors.Accent
    btn.BackgroundTransparency = 0.15
    btn.TextColor3 = Fn.accentTextColor(self._Colors.Accent)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = _btnTxtMax
    btn.TextScaled = true
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    local btnTextConstraint = Instance.new("UITextSizeConstraint", btn)
    btnTextConstraint.MinTextSize = _btnTxtMin
    btnTextConstraint.MaxTextSize = _btnTxtMax
    Fn.bindPressAnimation(btn)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local btnGrad = Instance.new("UIGradient", btn)
    btnGrad.Color = ColorSequence.new(self._Colors.Accent, self._Colors.Accent2 or self._Colors.Accent)
    btnGrad.Rotation = 90

    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = self._Colors.Accent
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.5

    btn.MouseEnter:Connect(function()
        self:PlaySound("Hover")
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Transparency = 0.1}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Transparency = 0.5}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        self:PlaySound("Click")
        callback()
    end)

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        btn.BackgroundColor3 = self._Colors.Accent
        btn.TextColor3 = Fn.accentTextColor(self._Colors.Accent)
        btnStroke.Color = self._Colors.Accent
        btnGrad.Color = ColorSequence.new(self._Colors.Accent, self._Colors.Accent2 or self._Colors.Accent)
    end)
    self:_bindTooltip(holder, text .. " (click)")
    self:_registerSearchControl(holder, text)
    local _h = { __isHandle = true, __tag = "Button", Raw = holder }
    _h.Click = function(_)
        local _ok, _err = pcall(callback)
        if not _ok then warn("[DoD UI] Button click error: " .. tostring(_err)) end
    end
    _h.SetVisible = function(_, v) holder.Visible = v and true or false end
    return _h
end

function Library:_convertRichText(text)
    if type(text) ~= "string" then text = tostring(text or "") end
    -- Escape first: a literal "<" in user text used to be interpreted as a tag.
    local s = text
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
    s = s:gsub("%*%*(.-)%*%*", "<b>%1</b>")
    s = s:gsub("__(.-)__", "<i>%1</i>")
    s = s:gsub("`(.-)`", '<font name="RobotoMono">%1</font>')
    return s
end

function Library:AddLabel(page, text)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    local label = Instance.new("TextLabel", page)
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.RichText = true
    label.Text = self:_convertRichText(text)
    label.TextColor3 = self._Colors.Text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextWrapped = true

    self:_registerThemeRefresher(function()
        label.TextColor3 = self._Colors.Text
    end)
    self:_registerSearchControl(label, text)
    local _h = { __isHandle = true, __tag = "Label", Raw = label }
    _h.Get = function(_) return label.Text end
    _h.Set = function(_, t) label.Text = self:_convertRichText(tostring(t or "")) end
    _h.SetVisible = function(_, v) label.Visible = v and true or false end
    return _h
end

function Library:AddParagraph(page, title, desc)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    desc = desc or ""
    local holder = Instance.new("Frame", page)
    holder.Name = "Paragraph"
    holder.Size = UDim2.new(1, 0, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 7)

    local layout = Instance.new("UIListLayout", holder)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)

    local padding = Instance.new("UIPadding", holder)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.PaddingTop = UDim.new(0, 9)
    padding.PaddingBottom = UDim.new(0, 9)

    local titleLabel = Instance.new("TextLabel", holder)
    titleLabel.Name = "Title"
    titleLabel.LayoutOrder = 1
    titleLabel.Size = UDim2.new(1, 0, 0, 18)
    titleLabel.BackgroundTransparency = 1
    titleLabel.RichText = true
    titleLabel.Text = self:_convertRichText(title)
    titleLabel.TextColor3 = self._Colors.Text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local description = Instance.new("TextLabel", holder)
    description.Name = "Description"
    description.LayoutOrder = 2
    description.Size = UDim2.new(1, 0, 0, 0)
    description.AutomaticSize = Enum.AutomaticSize.Y
    description.BackgroundTransparency = 1
    description.RichText = true
    description.Text = self:_convertRichText(desc)
    description.TextColor3 = self._Colors.TextDim
    description.Font = Enum.Font.Gotham
    description.TextSize = 11
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.TextWrapped = true

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        titleLabel.TextColor3 = self._Colors.Text
        description.TextColor3 = self._Colors.TextDim
    end)
    self:_registerSearchControl(holder, tostring(title) .. " " .. tostring(desc))
    local _h = { __isHandle = true, __tag = "Paragraph", Raw = holder }
    _h.Set = function(_, t, d)
        if t ~= nil then titleLabel.Text = self:_convertRichText(tostring(t)) end
        if d ~= nil then description.Text = self:_convertRichText(tostring(d)) end
    end
    _h.SetVisible = function(_, v) holder.Visible = v and true or false end
    return _h
end

function Library:AddTextbox(page, text, placeholder, callback, opts)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    opts = opts or {}
    if type(opts) ~= "table" then opts = {} end
    if callback ~= nil and type(callback) ~= "function" then
        error("[DoD UI] AddTextbox callback must be a function.")
    end
    callback = callback or function() end

    local holder = Instance.new("Frame", page)
    holder.Name = "Textbox"
    holder.Size = UDim2.new(1, 0, 0, 40)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 7)

    local label = Instance.new("TextLabel", holder)
    label.Size = UDim2.new(0.42, -14, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = tostring(text)
    label.TextColor3 = self._Colors.Text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd

    local input = Instance.new("TextBox", holder)
    input.Name = "Input"
    input.Size = UDim2.new(0.58, -18, 0, 30)
    input.Position = UDim2.new(0.42, 4, 0.5, -15)
    input.BackgroundColor3 = self._Colors.Bg2
    input.BackgroundTransparency = 0.2
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.ReturnKeyType = Enum.ReturnKeyType.Done
    input.Text = ""
    input.PlaceholderText = tostring(placeholder or "")
    input.PlaceholderColor3 = self._Colors.TextDim
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.TextStrokeTransparency = 1
    input.Font = Enum.Font.GothamMedium
    input.TextSize = 11
    input.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)
    if opts.readOnly then
        input.TextEditable = false
        input.BackgroundTransparency = 0.6
        input.TextColor3 = self._Colors.TextDim
        input.PlaceholderColor3 = self._Colors.TextDim
    end

    local inputStroke = Instance.new("UIStroke", input)
    inputStroke.Color = self._Colors.Border
    inputStroke.Thickness = 1
    inputStroke.Transparency = 0.5

    local inputPadding = Instance.new("UIPadding", input)
    inputPadding.PaddingLeft = UDim.new(0, 10)
    inputPadding.PaddingRight = UDim.new(0, 10)

    local _kbSavedPos = nil
    local lastSubmitted = ""
    input.Focused:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0.1}):Play()
        TweenService:Create(input, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
        if UserInputService.TouchEnabled and self._UI.MainContainer then
            if _kbSavedPos then return end
            _kbSavedPos = self._UI.MainContainer.Position
            local cam = getCam()
            if cam then
                local vp = cam.ViewportSize
                local absSize = self._UI.MainContainer.AbsoluteSize
                local shift = math.floor(vp.Y * 0.30)
                local maxShift = math.max(0, vp.Y * 0.5 - absSize.Y * 0.5 - 8)
                shift = math.min(shift, maxShift)
                local p = self._UI.MainContainer.Position
                -- Cancel the previous shift tween: two of them fighting over
                -- Position left the window parked at an offset.
                if self._kbTween then pcall(function() self._kbTween:Cancel() end) end
                self._kbTween = TweenService:Create(self._UI.MainContainer,
                    TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset - shift),
                    })
                self._kbTween:Play()
            end
        end
    end)
    input.FocusLost:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.5}):Play()
        TweenService:Create(input, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
        if _kbSavedPos and self._UI.MainContainer then
            if self._kbTween then pcall(function() self._kbTween:Cancel() end) end
            self._kbTween = TweenService:Create(self._UI.MainContainer,
                TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = _kbSavedPos,
                })
            self._kbTween:Play()
            _kbSavedPos = nil
        end
        -- A single FocusLost handler: the old pair ran the callback even when the
        -- text had not changed, and without pcall.
        if input.Text == lastSubmitted then return end
        lastSubmitted = input.Text
        local ok, err = pcall(callback, input.Text)
        if not ok then warn("[DoD UI] Textbox callback error: " .. tostring(err)) end
        self:_triggerAutoSave()
    end)

    local _favId = self:_getConfigId("textbox", text)
    self:_registerConfigState(_favId,
        function() return input.Text end,
        function(v, silent)
            if type(v) ~= "string" then return end
            if input.Text == v then return end
            input.Text = v
            lastSubmitted = v
            if not silent then
                callback(v)
                self:_triggerAutoSave()
            end
        end
    )
    self:_attachFavorite(holder, _favId)

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        label.TextColor3 = self._Colors.Text
        input.BackgroundColor3 = self._Colors.Bg2
        input.TextColor3 = self._Colors.Text
        input.PlaceholderColor3 = self._Colors.TextDim
    end)
    self:_bindTooltip(label, text .. " — press Enter or click outside to submit")
    self:_registerSearchControl(holder, tostring(text) .. " " .. tostring(placeholder or ""))
    local _h = { __isHandle = true, __tag = "Textbox", Raw = holder }
    _h.Get = function(_) return input.Text end
    _h.Set = function(_, v, silent)
        if type(v) ~= "string" then return end
        if input.Text == v then return end
        input.Text = v
        lastSubmitted = v
        if not silent then
            local _ok, _err = pcall(callback, v)
            if not _ok then warn("[DoD UI] Textbox set callback error: " .. tostring(_err)) end
            self:_triggerAutoSave()
        end
    end
    _h.SetValue = _h.Set
    _h.SetVisible = function(_, v) holder.Visible = v and true or false end
    return _h
end

function Library:AddColorPicker(page, text, defaultColor3, callback)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    if typeof(defaultColor3) ~= "Color3" then
        error("[DoD UI] AddColorPicker expects defaultColor3 to be a Color3 value.")
    end
    if callback ~= nil and type(callback) ~= "function" then
        error("[DoD UI] AddColorPicker callback must be a function.")
    end
    callback = callback or function() end

    local holder = Instance.new("Frame", page)
    holder.Name = "ColorPicker"
    holder.Size = UDim2.new(1, 0, 0, 40)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 7)

    local label = Instance.new("TextLabel", holder)
    label.Size = UDim2.new(1, -72, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = tostring(text)
    label.TextColor3 = self._Colors.Text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd

    local preview = Instance.new("TextButton", holder)
    preview.Name = "Preview"
    preview.Size = UDim2.new(0, 42, 0, 24)
    preview.Position = UDim2.new(1, -54, 0.5, -12)
    preview.BackgroundColor3 = defaultColor3
    preview.Text = ""
    preview.AutoButtonColor = false
    preview.BorderSizePixel = 0
    Fn.bindPressAnimation(preview)
    Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 6)

    local previewStroke = Instance.new("UIStroke", preview)
    previewStroke.Color = self._Colors.Border
    previewStroke.Thickness = 1

    local hue, saturation, value = defaultColor3:ToHSV()
    local currentColor = defaultColor3
    local _cpCam = getCam()
    local _cpW = self._isMobile and math.min(280, ((_cpCam and _cpCam.ViewportSize.X) or 320) - 24) or 230
    local _cpH = self._isMobile and math.min(240, ((_cpCam and _cpCam.ViewportSize.Y) or 600) - 24) or 176
    local popup = Instance.new("Frame", self._UI.MainGui)
    popup.Name = "ColorPickerPopup"
    _cpH = math.clamp(_cpH or 176, 190, 310)
    popup.Size = UDim2.fromOffset(_cpW, _cpH)
    popup.BackgroundColor3 = self._Colors.Bg2
    popup.BorderSizePixel = 0
    popup.Visible = false
    popup.ZIndex = 210
    popup.ClipsDescendants = true
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 9)

    local popupStroke = Instance.new("UIStroke", popup)
    popupStroke.Color = self._Colors.Border
    popupStroke.Thickness = 1

    local saturationValue = Instance.new("Frame", popup)
    saturationValue.Name = "SaturationValue"
    saturationValue.Position = UDim2.new(0, 10, 0, 10)
    saturationValue.Size = UDim2.new(1, -52, 1, -86)
    saturationValue.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
    saturationValue.BorderSizePixel = 0
    saturationValue.Active = true
    saturationValue.ZIndex = 211
    Instance.new("UICorner", saturationValue).CornerRadius = UDim.new(0, 5)

    local saturationGradient = Instance.new("UIGradient", saturationValue)
    saturationGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
    saturationGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })

    local valueOverlay = Instance.new("Frame", saturationValue)
    valueOverlay.Size = UDim2.new(1, 0, 1, 0)
    valueOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
    valueOverlay.BackgroundTransparency = 1
    valueOverlay.BorderSizePixel = 0
    valueOverlay.ZIndex = 212
    Instance.new("UICorner", valueOverlay).CornerRadius = UDim.new(0, 5)

    local valueGradient = Instance.new("UIGradient", valueOverlay)
    valueGradient.Rotation = 90
    valueGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })

    local selector = Instance.new("Frame", saturationValue)
    selector.Name = "Selector"
    selector.AnchorPoint = Vector2.new(0.5, 0.5)
    selector.Size = UDim2.new(0, 10, 0, 10)
    selector.BackgroundTransparency = 1
    selector.BorderSizePixel = 0
    selector.ZIndex = 213
    Instance.new("UICorner", selector).CornerRadius = UDim.new(1, 0)
    local selectorStroke = Instance.new("UIStroke", selector)
    selectorStroke.Color = Color3.new(1, 1, 1)
    selectorStroke.Thickness = 2

    local hueBar = Instance.new("TextButton", popup)
    hueBar.Name = "Hue"
    hueBar.Position = UDim2.new(1, -30, 0, 10)
    hueBar.Size = UDim2.new(0, 18, 1, -86)
    hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
    hueBar.BorderSizePixel = 0
    hueBar.Text = ""
    hueBar.AutoButtonColor = false
    hueBar.Active = true
    hueBar.ZIndex = 211
    Instance.new("UICorner", hueBar).CornerRadius = UDim.new(0, 5)

    local hueGradient = Instance.new("UIGradient", hueBar)
    hueGradient.Rotation = 90
    hueGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
    })

    local alpha = 1

    local alphaBar = Instance.new("TextButton", popup)
    alphaBar.Name = "Alpha"
    alphaBar.Position = UDim2.new(0, 10, 1, -70)
    alphaBar.Size = UDim2.new(1, -52, 0, 12)
    alphaBar.BackgroundColor3 = currentColor
    alphaBar.BorderSizePixel = 0
    alphaBar.Text = ""
    alphaBar.AutoButtonColor = false
    alphaBar.Active = true
    alphaBar.ZIndex = 211
    Instance.new("UICorner", alphaBar).CornerRadius = UDim.new(0, 3)

    local alphaGradient = Instance.new("UIGradient", alphaBar)
    alphaGradient.Rotation = 0
    alphaGradient.Color = ColorSequence.new(currentColor)
    alphaGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.95),
        NumberSequenceKeypoint.new(1, 0),
    })

    local alphaSelector = Instance.new("Frame", alphaBar)
    alphaSelector.Name = "AlphaSelector"
    alphaSelector.AnchorPoint = Vector2.new(0.5, 0.5)
    alphaSelector.Size = UDim2.fromOffset(6, 18)
    alphaSelector.Position = UDim2.new(1, 0, 0.5, 0)
    alphaSelector.BackgroundTransparency = 1
    alphaSelector.BorderSizePixel = 0
    alphaSelector.ZIndex = 213
    Instance.new("UICorner", alphaSelector).CornerRadius = UDim.new(1, 0)
    local alphaSelectorStroke = Instance.new("UIStroke", alphaSelector)
    alphaSelectorStroke.Color = Color3.new(1, 1, 1)
    alphaSelectorStroke.Thickness = 2

    local currentPreview = Instance.new("Frame", popup)
    currentPreview.Name = "CurrentColor"
    currentPreview.Position = UDim2.new(0, 10, 1, -28)
    currentPreview.Size = UDim2.new(0.55, -12, 0, 18)
    currentPreview.BackgroundColor3 = currentColor
    currentPreview.BorderSizePixel = 0
    currentPreview.ZIndex = 211
    Instance.new("UICorner", currentPreview).CornerRadius = UDim.new(0, 5)

    local hexBox = Instance.new("TextBox", popup)
    hexBox.Name = "HexInput"
    hexBox.Position = UDim2.new(0.55, 2, 1, -28)
    hexBox.Size = UDim2.new(0.45, -12, 0, 18)
    hexBox.BackgroundColor3 = self._Colors.Bg
    hexBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    hexBox.TextStrokeTransparency = 1
    hexBox.Font = Enum.Font.RobotoMono
    hexBox.TextSize = 10
    hexBox.PlaceholderText = "#FFFFFF"
    hexBox.Text = "#FFFFFF"
    hexBox.ClearTextOnFocus = false
    hexBox.TextXAlignment = Enum.TextXAlignment.Center
    hexBox.BorderSizePixel = 0
    hexBox.ZIndex = 211
    Instance.new("UICorner", hexBox).CornerRadius = UDim.new(0, 4)

    local hexStroke = Instance.new("UIStroke", hexBox)
    hexStroke.Color = self._Colors.Border
    hexStroke.Thickness = 1
    hexStroke.ZIndex = 211

    local dragMode

    local function updateColor(notify)
        currentColor = Color3.fromHSV(hue, saturation, value)
        saturationValue.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        selector.Position = UDim2.new(saturation, 0, 1 - value, 0)
        selectorStroke.Color = Fn.contrastForeground(currentColor)
        preview.BackgroundColor3 = currentColor
        preview.BackgroundTransparency = 1 - math.max(alpha, 0.15)
        currentPreview.BackgroundColor3 = currentColor
        currentPreview.BackgroundTransparency = 1 - math.max(alpha, 0.15)
        if alphaBar then
            alphaBar.BackgroundColor3 = currentColor
            alphaGradient.Color = ColorSequence.new(currentColor)
            alphaSelector.Position = UDim2.new(alpha, 0, 0.5, 0)
        end
        
        if hexBox then
            hexBox.Text = string.format("#%02X%02X%02X", 
                math.floor(currentColor.R * 255 + 0.5), 
                math.floor(currentColor.G * 255 + 0.5), 
                math.floor(currentColor.B * 255 + 0.5)
            )
        end

        if notify then
            -- Throttle the user callback during a drag; the final value is
            -- delivered on release. It used to fire 60+ times per second.
            local now = os.clock()
            if now - (self._cpLastNotify or 0) >= 0.05 then
                self._cpLastNotify = now
                callback(currentColor, alpha)
            end
        end
    end

    updateColor(false)

    hexBox.Focused:Connect(function()
        TweenService:Create(hexStroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0}):Play()
    end)
    
    hexBox.FocusLost:Connect(function()
        TweenService:Create(hexStroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.5}):Play()
        local hex = hexBox.Text:gsub("#", "")
        if #hex == 6 then
            local r = tonumber("0x" .. hex:sub(1, 2))
            local g = tonumber("0x" .. hex:sub(3, 4))
            local b = tonumber("0x" .. hex:sub(5, 6))
            if r and g and b then
                hue, saturation, value = Color3.new(r/255, g/255, b/255):ToHSV()
                updateColor(true)
                return
            end
        end
        updateColor(false)
    end)

    local _favId = self:_getConfigId("colorpicker", text)
    self:_registerConfigState(_favId,
        function() return { currentColor.R, currentColor.G, currentColor.B, alpha } end,
        function(v, silent)
            if type(v) ~= "table" or type(v[1]) ~= "number" or type(v[2]) ~= "number" or type(v[3]) ~= "number" then return end
            local newColor = Color3.new(v[1], v[2], v[3])
            local newAlpha = type(v[4]) == "number" and math.clamp(v[4], 0, 1) or 1
            hue, saturation, value = newColor:ToHSV()
            alpha = newAlpha
            updateColor(false)
            if not silent then
                callback(currentColor, alpha)
                self:_triggerAutoSave()
            end
        end
    )
    self:_attachFavorite(holder, _favId)

    local function pickFromPosition(mode, position)
        if mode == "SV" then
            local size = saturationValue.AbsoluteSize
            if size.X <= 0 or size.Y <= 0 then return end
            saturation = math.clamp((position.X - saturationValue.AbsolutePosition.X) / size.X, 0, 1)
            value = 1 - math.clamp((position.Y - saturationValue.AbsolutePosition.Y) / size.Y, 0, 1)
        elseif mode == "Hue" then
            local size = hueBar.AbsoluteSize
            if size.Y <= 0 then return end
            hue = 1 - math.clamp((position.Y - hueBar.AbsolutePosition.Y) / size.Y, 0, 1)
        elseif mode == "Alpha" then
            local size = alphaBar.AbsoluteSize
            if size.X <= 0 then return end
            alpha = math.clamp((position.X - alphaBar.AbsolutePosition.X) / size.X, 0, 1)
        end
        updateColor(true)
    end

    local dragInput = nil
    self:_ensureDragPump()
    local function endColorDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragMode = nil
        dragInput = nil
        if self._activeDragEnd == endColorDrag then
            self._activeDragEnd = nil
            self._activeDragHandler = nil
        end
        callback(currentColor, alpha)
        -- Persist once, on release, instead of re-arming the autosave every frame.
        self:_triggerAutoSave()
    end
    local function moveColorDrag(input)
        if not dragMode then return end
        -- Same identity-check bug as the slider; input events are always new
        -- objects so comparing them to the InputBegan reference is useless.
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        pickFromPosition(dragMode, input.Position)
    end
    local function beginColorDrag(input, mode)
        dragMode = mode
        dragInput = input
        self._activeDragHandler = moveColorDrag
        self._activeDragEnd = endColorDrag
    end

    saturationValue.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            beginColorDrag(input, "SV")
            pickFromPosition("SV", input.Position)
        end
    end)
    hueBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            beginColorDrag(input, "Hue")
            pickFromPosition("Hue", input.Position)
        end
    end)
    alphaBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            beginColorDrag(input, "Alpha")
            pickFromPosition("Alpha", input.Position)
        end
    end)

    preview.MouseButton1Click:Connect(function()
        if popup.Visible then
            popup.Visible = false
            return
        end
        for _, other in ipairs(self._STATE.activeDropdownPopups) do
            if other.popup ~= popup then other.close() end
        end

        local camera = getCam()
        if not camera then return end
        local viewport = camera.ViewportSize
        local popupWidth, popupHeight = popup.AbsoluteSize.X, popup.AbsoluteSize.Y
        local x = math.clamp(preview.AbsolutePosition.X, 8, math.max(8, viewport.X - popupWidth - 8))
        local y = preview.AbsolutePosition.Y + preview.AbsoluteSize.Y + 6
        if y + popupHeight > viewport.Y - 8 then
            y = preview.AbsolutePosition.Y - popupHeight - 6
        end
        popup.Position = UDim2.fromOffset(x, math.max(8, y))
        popup.Visible = true
    end)

    Fn.track(UserInputService.InputBegan, function(input)
        if not popup.Visible
            or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then
            return
        end
        local position = input.Position
        local popupPosition, popupSize = popup.AbsolutePosition, popup.AbsoluteSize
        local inside = position.X >= popupPosition.X and position.X <= popupPosition.X + popupSize.X
            and position.Y >= popupPosition.Y and position.Y <= popupPosition.Y + popupSize.Y
        local previewPosition, previewSize = preview.AbsolutePosition, preview.AbsoluteSize
        local onPreview = position.X >= previewPosition.X and position.X <= previewPosition.X + previewSize.X
            and position.Y >= previewPosition.Y and position.Y <= previewPosition.Y + previewSize.Y
        if not inside and not onPreview then popup.Visible = false end
    end, self)

    table.insert(self._STATE.activeDropdownPopups, {
        popup = popup,
        close = function()
            popup.Visible = false
            dragMode = nil
        end,
    })

    -- Position on demand instead of polling at 10 Hz for the picker's lifetime.
    -- The popup closes as soon as the pointer leaves it, so it cannot be dragged
    -- around while open.
    popup:GetPropertyChangedSignal("Visible"):Connect(function()
        if not popup.Visible then return end
        task.defer(function()
            if not popup.Visible then return end
            local camera = getCam()
            if not camera then return end
            local viewport = camera.ViewportSize
            local pw, ph = popup.AbsoluteSize.X, popup.AbsoluteSize.Y
            local x = math.clamp(preview.AbsolutePosition.X, 8, math.max(8, viewport.X - pw - 8))
            local y = preview.AbsolutePosition.Y + preview.AbsoluteSize.Y + 6
            if y + ph > viewport.Y - 8 then
                y = preview.AbsolutePosition.Y - ph - 6
            end
            popup.Position = UDim2.fromOffset(x, math.max(8, y))
        end)
    end)

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        label.TextColor3 = self._Colors.Text
        previewStroke.Color = self._Colors.Border
        popup.BackgroundColor3 = self._Colors.Bg2
        popupStroke.Color = self._Colors.Border
        hexBox.BackgroundColor3 = self._Colors.Bg
        hexBox.TextColor3 = self._Colors.Text
        hexStroke.Color = self._Colors.Border
    end)

    self:_bindTooltip(label, text .. " — click preview to open")
    self:_registerSearchControl(holder, text)
    local _h = { __isHandle = true, __tag = "ColorPicker", Raw = holder }
    _h.Get = function(_) return currentColor, alpha end
    _h.Set = function(_, c, a, silent)
        if typeof(c) ~= "Color3" then return end
        hue, saturation, value = c:ToHSV()
        if type(a) == "number" then alpha = math.clamp(a, 0, 1) end
        updateColor(not silent)
    end
    _h.SetValue = _h.Set
    _h.SetVisible = function(_, v) holder.Visible = v and true or false end
    local _defaultCPAlpha = alpha
    local _defaultCPColor = defaultColor3
    _h.Reset = function(_)
        _h:Set(_defaultCPColor, _defaultCPAlpha)
    end
    return _h
end

function Library:AddSeparator(page, height)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    local h = tonumber(height) or 16
    local container = Instance.new("Frame", page)
    container.Name = "Separator"
    container.Size = UDim2.new(1, 0, 0, h)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    local line = Instance.new("Frame", container)
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 0.5, -0.5)
    line.BackgroundColor3 = self._Colors.Border
    line.BackgroundTransparency = 0.5
    line.BorderSizePixel = 0
    self:_registerThemeRefresher(function()
        line.BackgroundColor3 = self._Colors.Border
    end)
    -- Return the same handle shape as every other Add* so SetVisible/Raw work.
    local _h = { __isHandle = true, __tag = "Separator", Raw = container }
    _h.SetVisible = function(_, visible) container.Visible = visible and true or false end
    return _h
end

function Library:AddChipBar(page, text, options, defaultIndex, callback)
    if self:_isDead() then return end
    page = self:_unwrap(page)
    if type(options) ~= "table" or #options == 0 then
        error("[DoD UI] AddChipBar options must be a non-empty array.")
    end
    if callback ~= nil and type(callback) ~= "function" then
        error("[DoD UI] AddChipBar callback must be a function.")
    end
    callback = callback or function() end
    if type(defaultIndex) ~= "number" or defaultIndex % 1 ~= 0
        or defaultIndex < 1 or defaultIndex > #options then
        defaultIndex = 1
    end

    local hasLabel = text ~= nil and text ~= ""
    local _chipH = self._isMobile and 44 or 28
    local yOffset = hasLabel and 26 or 8
    local holderHeight = yOffset + _chipH + (hasLabel and 12 or 8)

    local holder = Instance.new("Frame", page)
    holder.Name = "ChipBar"
    holder.Size = UDim2.new(1, 0, 0, holderHeight)
    holder.BackgroundColor3 = self._Colors.Card
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    if hasLabel then
        local label = Instance.new("TextLabel", holder)
        label.Name = "Label"
        label.Size = UDim2.new(1, -32, 0, 16)
        label.Position = UDim2.new(0, 12, 0, 6)
        label.BackgroundTransparency = 1
        label.Text = tostring(text)
        label.TextColor3 = self._Colors.Text
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local arrowSize = self._isMobile and 40 or 20
    local arrowGap = self._isMobile and 6 or 4

    local leftArrow = Instance.new("TextButton", holder)
    leftArrow.Name = "ArrowLeft"
    leftArrow.Size = UDim2.fromOffset(arrowSize, _chipH)
    leftArrow.Position = UDim2.new(0, 6, 0, yOffset)
    leftArrow.BackgroundColor3 = self._Colors.Bg2
    leftArrow.BackgroundTransparency = 0.3
    leftArrow.Text = ""
    leftArrow.AutoButtonColor = false
    leftArrow.BorderSizePixel = 0
    leftArrow.Visible = false
    leftArrow.ZIndex = 5
    Instance.new("UICorner", leftArrow).CornerRadius = UDim.new(0, 6)

    local leftStroke = Instance.new("UIStroke", leftArrow)
    leftStroke.Color = self._Colors.Border
    leftStroke.Thickness = 1
    leftStroke.Transparency = 0.5

    local leftIcon = Instance.new("ImageLabel", leftArrow)
    leftIcon.Size = UDim2.fromOffset(12, 12)
    leftIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
    leftIcon.BackgroundTransparency = 1
    leftIcon.Image = GetIcon("chevron-down")
    leftIcon.Rotation = 90
    leftIcon.ImageColor3 = self._Colors.TextDim

    local rightArrow = Instance.new("TextButton", holder)
    rightArrow.Name = "ArrowRight"
    rightArrow.Size = UDim2.fromOffset(arrowSize, _chipH)
    rightArrow.AnchorPoint = Vector2.new(1, 0)
    rightArrow.Position = UDim2.new(1, -6, 0, yOffset)
    rightArrow.BackgroundColor3 = self._Colors.Bg2
    rightArrow.BackgroundTransparency = 0.3
    rightArrow.Text = ""
    rightArrow.AutoButtonColor = false
    rightArrow.BorderSizePixel = 0
    rightArrow.Visible = false
    rightArrow.ZIndex = 5
    Instance.new("UICorner", rightArrow).CornerRadius = UDim.new(0, 6)

    local rightStroke = Instance.new("UIStroke", rightArrow)
    rightStroke.Color = self._Colors.Border
    rightStroke.Thickness = 1
    rightStroke.Transparency = 0.5

    local rightIcon = Instance.new("ImageLabel", rightArrow)
    rightIcon.Size = UDim2.fromOffset(12, 12)
    rightIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
    rightIcon.BackgroundTransparency = 1
    rightIcon.Image = GetIcon("chevron-down")
    rightIcon.Rotation = -90
    rightIcon.ImageColor3 = self._Colors.TextDim

    local scroller = Instance.new("ScrollingFrame", holder)
    scroller.Name = "ChipScroller"
    scroller.Size = UDim2.new(1, -16, 0, _chipH)
    scroller.Position = UDim2.new(0, 8, 0, yOffset)
    scroller.BackgroundTransparency = 1
    scroller.BorderSizePixel = 0
    scroller.ScrollBarThickness = 0
    scroller.ScrollingDirection = Enum.ScrollingDirection.X
    scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroller.ElasticBehavior = self._isMobile and Enum.ElasticBehavior.WhenScrollable or Enum.ElasticBehavior.Never
    scroller.VerticalScrollBarInset = Enum.ScrollBarInset.None
    scroller.HorizontalScrollBarInset = Enum.ScrollBarInset.None
    self:_registerScrollFrame(scroller)

    local layout = Instance.new("UIListLayout", scroller)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 6)

    local currentIndex = defaultIndex
    local chips = {}

    local function updateChips()
        for i, chip in ipairs(chips) do
            local isActive = (i == currentIndex)
            TweenService:Create(chip, TweenInfo.new(0.15), {
                BackgroundColor3 = isActive and self._Colors.Accent or self._Colors.Bg2,
                BackgroundTransparency = isActive and 0 or 0.4,
            }):Play()
            local lbl = chip:FindFirstChild("ChipLabel")
            if lbl then
                TweenService:Create(lbl, TweenInfo.new(0.15), {
                    TextColor3 = isActive and Fn.accentTextColor(self._Colors.Accent) or self._Colors.Text,
                }):Play()
            end
            local stroke = chip:FindFirstChildOfClass("UIStroke")
            if stroke then
                TweenService:Create(stroke, TweenInfo.new(0.15), {
                    Transparency = isActive and 0 or 0.5,
                    Color = isActive and self._Colors.Accent or self._Colors.Border,
                }):Play()
            end
        end
    end

    local TextService = game:GetService("TextService")
    local _chipPadX = 14
    local _chipFont = Enum.Font.GothamBold
    local _chipTextSize = 11
    local _gap = 6
    local _totalW = 0

    for i, opt in ipairs(options) do
        local _str = tostring(opt)
        local _bounds = TextService:GetTextSize(_str, _chipTextSize, _chipFont, Vector2.new(4000, 100))
        local _w = math.ceil(_bounds.X) + (_chipPadX * 2)
        _totalW = _totalW + _w + (i > 1 and _gap or 0)

        local chip = Instance.new("TextButton", scroller)
        chip.Name = "Chip_" .. tostring(i)
        chip.LayoutOrder = i
        chip.Size = UDim2.fromOffset(_w, _chipH)
        chip.BackgroundColor3 = self._Colors.Bg2
        chip.BackgroundTransparency = 0.4
        chip.Text = ""
        chip.AutoButtonColor = false
        chip.BorderSizePixel = 0
        Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 6)

        local chipStroke = Instance.new("UIStroke", chip)
        chipStroke.Color = self._Colors.Border
        chipStroke.Thickness = 1
        chipStroke.Transparency = 0.5

        local chipLabel = Instance.new("TextLabel", chip)
        chipLabel.Name = "ChipLabel"
        chipLabel.Size = UDim2.new(1, -(_chipPadX * 2), 1, 0)
        chipLabel.Position = UDim2.new(0, _chipPadX, 0, 0)
        chipLabel.BackgroundTransparency = 1
        chipLabel.Text = _str
        chipLabel.TextColor3 = self._Colors.Text
        chipLabel.Font = _chipFont
        chipLabel.TextSize = _chipTextSize
        chipLabel.TextXAlignment = Enum.TextXAlignment.Center

        Fn.bindPressAnimation(chip)

        chip.MouseButton1Click:Connect(function()
            if currentIndex == i then return end
            currentIndex = i
            self:PlaySound("Click")
            updateChips()
            callback(i, options[i])
            self:_triggerAutoSave()
        end)

        chip.MouseEnter:Connect(function()
            self:PlaySound("Hover")
            if currentIndex ~= i then
                TweenService:Create(chip, TweenInfo.new(0.12), {BackgroundTransparency = 0.2}):Play()
            end
        end)
        chip.MouseLeave:Connect(function()
            if currentIndex ~= i then
                TweenService:Create(chip, TweenInfo.new(0.12), {BackgroundTransparency = 0.4}):Play()
            end
        end)

        chips[i] = chip
    end

    updateChips()

    scroller.CanvasSize = UDim2.fromOffset(_totalW, 0)

    local _lastArrowsState = nil
    local function updateArrows()
        local parentW = holder.AbsoluteSize.X
        if parentW <= 0 then return end
        local availableFull = parentW - 16
        local needsArrows = _totalW > availableFull + 2
        if _lastArrowsState == needsArrows then return end
        _lastArrowsState = needsArrows
        leftArrow.Visible = needsArrows
        rightArrow.Visible = needsArrows
        if needsArrows then
            local arrowW = arrowSize + arrowGap
            scroller.Size = UDim2.new(1, -(arrowW * 2 + 4), 0, _chipH)
            scroller.Position = UDim2.new(0, arrowW + 2, 0, yOffset)
        else
            scroller.Size = UDim2.new(1, -16, 0, _chipH)
            scroller.Position = UDim2.new(0, 8, 0, yOffset)
        end
    end

    holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateArrows)
    task.defer(updateArrows)
    task.delay(0.1, updateArrows)

    local function scrollBy(dx)
        local maxScroll = math.max(0, scroller.AbsoluteCanvasSize.X - scroller.AbsoluteSize.X)
        local targetX = math.clamp(scroller.CanvasPosition.X + dx, 0, maxScroll)
        TweenService:Create(scroller, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            CanvasPosition = Vector2.new(targetX, 0),
        }):Play()
    end

    leftArrow.MouseButton1Click:Connect(function()
        self:PlaySound("Click")
        scrollBy(-scroller.AbsoluteSize.X * 0.7)
    end)
    rightArrow.MouseButton1Click:Connect(function()
        self:PlaySound("Click")
        scrollBy(scroller.AbsoluteSize.X * 0.7)
    end)

    leftArrow.MouseEnter:Connect(function()
        TweenService:Create(leftStroke, TweenInfo.new(0.12), {Transparency = 0.1, Color = self._Colors.Accent}):Play()
    end)
    leftArrow.MouseLeave:Connect(function()
        TweenService:Create(leftStroke, TweenInfo.new(0.12), {Transparency = 0.5, Color = self._Colors.Border}):Play()
    end)
    rightArrow.MouseEnter:Connect(function()
        TweenService:Create(rightStroke, TweenInfo.new(0.12), {Transparency = 0.1, Color = self._Colors.Accent}):Play()
    end)
    rightArrow.MouseLeave:Connect(function()
        TweenService:Create(rightStroke, TweenInfo.new(0.12), {Transparency = 0.5, Color = self._Colors.Border}):Play()
    end)

    local _favId = self:_getConfigId("chipbar", text or "ChipBar")
    self:_registerConfigState(_favId,
        function() return currentIndex end,
        function(v, silent)
            if type(v) ~= "number" or v < 1 or v > #options then return end
            if v == currentIndex then return end
            currentIndex = v
            updateChips()
            if not silent then
                callback(v, options[v])
                self:_triggerAutoSave()
            end
        end
    )
    self:_attachFavorite(holder, _favId)

    self:_registerThemeRefresher(function()
        holder.BackgroundColor3 = self._Colors.Card
        leftArrow.BackgroundColor3 = self._Colors.Bg2
        rightArrow.BackgroundColor3 = self._Colors.Bg2
        leftStroke.Color = self._Colors.Border
        rightStroke.Color = self._Colors.Border
        leftIcon.ImageColor3 = self._Colors.TextDim
        rightIcon.ImageColor3 = self._Colors.TextDim
        updateChips()
    end)

    if hasLabel then
        self:_bindTooltip(holder, text)
    end

    local searchText = tostring(text or "") .. " " .. table.concat(options, " ")
    self:_registerSearchControl(holder, searchText)
    local _h = { __isHandle = true, __tag = "ChipBar", Raw = holder }
    _h.Get = function(_) return currentIndex end
    _h.GetValue = function(_) return options[currentIndex] end
    _h.Set = function(_, idx, silent)
        if type(idx) ~= "number" or idx % 1 ~= 0 then return end
        if idx < 1 or idx > #options then return end
        if currentIndex == idx then return end
        currentIndex = idx
        updateChips()
        if not silent then callback(idx, options[idx]); self:_triggerAutoSave() end
    end
    _h.SetValue = function(_, value, silent)
        local idx = table.find(options, value)
        if idx then _h:Set(idx, silent) end
    end
    -- Every other control exposes SetVisible; generic code that loops over handles
    -- used to break on the chip bar.
    _h.SetVisible = function(_, visible) holder.Visible = visible and true or false end
    return _h
end


return true
