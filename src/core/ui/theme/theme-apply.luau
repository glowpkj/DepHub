--[[
  THEME APPLY (perf tier, density, acrylic, reduced motion)

  Split out of src/core/ui/demon-theme.luau (original lines 1218-1778).
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
-- THEME APPLY
-- =========================================================

function Library:_applyThemeColors(themeName)
    local theme = D.Themes[themeName] or D.Themes.Dark
    local base = D.Themes.Dark
    self._Colors.Accent = theme.Accent or base.Accent
    self._Colors.Accent2 = theme.Accent2 or base.Accent2
    if self._AccentOverride then
        self._Colors.Accent = self._AccentOverride
        self._Colors.Accent2 = self._AccentOverride:Lerp(Color3.new(1, 1, 1), 0.25)
    end
    self._Colors.Bg = theme.Bg or base.Bg
    self._Colors.Bg2 = theme.Bg2 or base.Bg2
    self._Colors.Card = theme.Card or base.Card
    self._Colors.CardHover = theme.CardHover or theme.Card or base.CardHover or base.Card
    self._Colors.Sidebar = theme.Sidebar or base.Sidebar
    self._Colors.Border = theme.Border or base.Border
    self._Colors.Text = theme.Text or (theme.Bg and Fn.accentTextColor(theme.Bg)) or base.Text
    self._Colors.TextDim = theme.TextDim or base.TextDim
    
    for key, color in pairs(self._CustomColorOverrides) do
        if self._Colors[key] then
            self._Colors[key] = color
        end
    end

    self._themeAutoAdjusted = false
    if self._SmartThemeAutoFix ~= false then
        local origAccent = self._Colors.Accent
        if Fn.contrastRatio(self._Colors.Accent, self._Colors.Bg) < 3 then
            self._Colors.Accent = Fn.visibleAccent(self._Colors.Accent, self._Colors.Bg, 3)
            self._themeAutoAdjusted = true
        end
        if Fn.contrastRatio(self._Colors.Accent, self._Colors.Card) < 2 then
            self._Colors.Accent = Fn.visibleAccent(self._Colors.Accent, self._Colors.Card, 2)
            self._themeAutoAdjusted = true
        end
        if Fn.contrastRatio(self._Colors.Text, self._Colors.Bg) < 3 then
            self._Colors.Text = Fn.contrastForeground(self._Colors.Bg)
            self._themeAutoAdjusted = true
        end
        if Fn.contrastRatio(self._Colors.Border, self._Colors.Card) < 1.4 then
            self._Colors.Border = self._Colors.Border:Lerp(Fn.contrastForeground(self._Colors.Card), 0.3)
            self._themeAutoAdjusted = true
        end
        if self._themeAutoAdjusted and self._Colors.Accent ~= origAccent then
            self._Colors.Accent2 = self._Colors.Accent:Lerp(Color3.new(1, 1, 1), 0.25)
        end
    end
    return theme
end

function Library:_detectPerfTier()
    local score = 5
    if self._isMobile then score = score - 3
    elseif UserInputService.TouchEnabled then score = score - 1 end
    local cam = getCam()
    if cam then
        local px = cam.ViewportSize.X * cam.ViewportSize.Y
        if px < 500000 then score = score - 2
        elseif px < 1000000 then score = score - 1
        elseif px > 2000000 then score = score + 1 end
    end
    pcall(function()
        local q = UserSettings():GetService("UserGameSettings").SavedQualityLevel
        if q <= Enum.SavedQualitySetting.QualityLevel1 then score = score - 2
        elseif q <= Enum.SavedQualitySetting.QualityLevel4 then score = score - 1
        elseif q >= Enum.SavedQualitySetting.QualityLevel8 then score = score + 1 end
    end)
    local initial = (score <= 1 and "Potato") or (score <= 3 and "Balanced") or "High"
    self._perfDetectGen = (self._perfDetectGen or 0) + 1
    local myGen = self._perfDetectGen
    task.spawn(function()
        local samples = {}
        local conn
        conn = RunService.RenderStepped:Connect(function(dt)
            if #samples < 120 then table.insert(samples, dt) end
        end)
        task.wait(1.2)
        if conn then conn:Disconnect() end
        if myGen ~= self._perfDetectGen then return end
        if self._perfAuto == false then return end
        if #samples < 15 then return end
        if self:_isDead() then return end
        local total = 0
        for _, d in ipairs(samples) do total = total + d end
        local fps = #samples / math.max(total, 0.001)
        if fps < 25 then score = score - 3
        elseif fps < 40 then score = score - 1
        elseif fps > 55 then score = score + 1 end
        local tier = (score <= 1 and "Potato") or (score <= 3 and "Balanced") or "High"
        if myGen ~= self._perfDetectGen then return end
        if self._perfAuto == false then return end
        if tier ~= self._perfTier then
            self:SetPerformanceTier(tier, true)
        end
    end)
    self._perfTier = initial
    return initial
end

function Library:SetPerformanceTier(tier, silent)
    if self:_isDead() then return end
    local p = D.PerfProfiles[tier]
    if not p then return end
    local _prevLoading = self._themeLoading
    self._themeLoading = true
    local ok, err = pcall(function()
        self._perfTier = tier
        self._perfProfile = p
        self._perfCursorBlocked = not p.CursorTrail
        self:SetAcrylic(p.Acrylic, p.AcrylicBlurIntensity)
        self:SetSectionTransparency(p.SectionTransparency)
        self:SetLayoutDensity(p.LayoutDensity)
        self:SetReducedMotion(p.ReducedMotion)
        if self._STATE.FocusOverlayEnabled then
            if p.FocusOverlayEnabled then
                self:_updateFocusOverlay()
            elseif self._UI.FocusOverlay then
                self._UI.FocusOverlay.Visible = false
            end
        end
        if self._STATE.WeatherEnabled then
            if p.WeatherEnabled then
                -- Never write the clamped value back into the user's setting.
                self:SetWeather(true, self._STATE.WeatherType, nil)
            else
                self:_stopWeather()
            end
        end
        if not p.CursorTrail then
            for _, dot in ipairs(self._cursorTrailPool or {}) do
                dot.active = false
                if dot.img then dot.img.Visible = false end
            end
        end
        if self._UI.ParticleBG then
            self._UI.ParticleBG.Visible = p.ParticleBG and self._STATE.GuiVisible
        end
        if self._UI.CustomCursor then
            self._UI.CustomCursor.Visible = p.CustomCursor and not self._isMobile and self._STATE.GuiVisible
        end
    end)
    self._themeLoading = _prevLoading
    if not ok then
        warn("[DoD UI] SetPerformanceTier failed: " .. tostring(err))
        return
    end
    if self._initialized and not _prevLoading then
        self:_triggerThemeSave()
    end
    pcall(function()
        if self._perfDropdown and self._perfDropdown.Set then
            local idx = 1
            if self._perfAuto == false then
                if tier == "Potato" then idx = 2
                elseif tier == "Balanced" then idx = 3
                else idx = 4 end
            end
            self._perfDropdown:Set(idx, true)
        end
    end)
    if not silent then
        self:Notify("PERFORMANCE", "Mode: " .. tier, "info")
    end
end

function Library:_startPerfWatchdog()
    task.spawn(function()
        task.wait(3)
        local goodStreak = 0
        local badStreak = 0
        while not self:_isDead() do
            -- Back off on the lowest tier: the sampler is itself a per-frame cost
            -- and there is nothing below Potato to fall back to.
            task.wait(self._perfTier == "Potato" and 12 or 4)
            if self:_isDead() then return end
            if self._perfAuto == true then
                local samples = {}
                local conn
                conn = RunService.RenderStepped:Connect(function(dt)
                    if #samples < 90 then table.insert(samples, dt) end
                end)
                task.wait(0.6)
                if conn then conn:Disconnect() end
                if #samples >= 10 then
                    local total = 0
                    for _, d in ipairs(samples) do total = total + d end
                    local fps = #samples / math.max(total, 0.001)
                    if fps < 30 then
                        badStreak = badStreak + 1
                        goodStreak = 0
                    elseif fps > 58 then
                        goodStreak = goodStreak + 1
                        badStreak = 0
                    else
                        goodStreak = 0
                        badStreak = 0
                    end
                    -- Two consecutive bad windows before stepping down, so a
                    -- single hitch (tab build, teleport, server lag spike) can no
                    -- longer pin the UI at Potato for the whole session.
                    if badStreak >= 2 then
                        badStreak = 0
                        if self._perfTier == "High" then
                            self:SetPerformanceTier("Balanced", false)
                        elseif self._perfTier == "Balanced" then
                            self:SetPerformanceTier("Potato", false)
                        end
                    elseif goodStreak >= 3 then
                        goodStreak = 0
                        if self._perfTier == "Potato" then
                            self:SetPerformanceTier("Balanced", true)
                        elseif self._perfTier == "Balanced" then
                            self:SetPerformanceTier("High", true)
                        end
                    end
                end
            end
        end
    end)
end

function Library:SetCustomColors(colorTable)
    if self:_isDead() then return end
    if type(colorTable) ~= "table" then return end
    for k, v in pairs(colorTable) do
        if typeof(v) == "Color3" then
            self._CustomColorOverrides[k] = v
        end
    end
    self:SetTheme(self.ThemeName, true)
end

function Library:SetTheme(themeName, silent)
    if self:_isDead() then return end
    local actualName
    if type(themeName) == "string" and D.Themes[themeName] then
        actualName = themeName
    else
        -- Report instead of silently resetting the user's theme to Dark and
        -- adopting "Dark" as the current name.
        warn("[DoD UI] Unknown theme '" .. tostring(themeName) .. "', keeping " .. tostring(self.ThemeName))
        return
    end
    -- An explicit theme change wins over a one-off accent override; otherwise the
    -- accent stuck forever and flattened two-tone palettes after the first tweak.
    if self._applyingAccent ~= true then
        self._AccentOverride = nil
    end
    local theme = self:_applyThemeColors(actualName)
    self.ThemeName = actualName

    local UI = self._UI
    local ok, err = pcall(function()
        if UI.MainContainer then
            UI.MainContainer.BackgroundColor3 = self._Colors.Bg
            UI.MainContainer.BackgroundTransparency = self.Acrylic and 0.32 or 0.1
        end
        if UI.AcrylicTexture then UI.AcrylicTexture.BackgroundColor3 = self._Colors.Accent2 end
        if UI.AcrylicGradient then
            UI.AcrylicGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.48, self._Colors.Accent2),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
            })
        end
        if UI.TitleBar then UI.TitleBar.BackgroundColor3 = self._Colors.Bg2 end
        if UI.CategoryBar then
            UI.CategoryBar.BackgroundColor3 = self.TabPosition == "Bottom" and self._Colors.Card or self._Colors.Sidebar
        end
        if UI.CategoryBarStroke then UI.CategoryBarStroke.Color = self._Colors.Border end
        if UI.Sidebar then UI.Sidebar.BackgroundColor3 = self._Colors.Sidebar end
        if UI.TabBarDivider then UI.TabBarDivider.BackgroundColor3 = self._Colors.Border end
        if UI.TitleLabel then UI.TitleLabel.TextColor3 = self._Colors.Text end
        if UI.TitleDiscord then UI.TitleDiscord.TextColor3 = self._Colors.TextDim end
        if UI.ResizeHandle then
            UI.ResizeHandle.ImageColor3 = self._Colors.TextDim
        end
        if UI.TitleLogoBadge then
            UI.TitleLogoBadge.BackgroundColor3 = self._Colors.Accent
            if UI.TitleLogoGradient then
                UI.TitleLogoGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, self._Colors.Accent),
                    ColorSequenceKeypoint.new(1, self._Colors.Accent2),
                })
            end
            if UI.TitleLogoStroke then UI.TitleLogoStroke.Color = self._Colors.Accent end
            if UI.TitleLogoIcon then UI.TitleLogoIcon.ImageColor3 = Fn.accentTextColor(self._Colors.Accent) end
        end
        if UI.TitleVersionBadge then
            local badgeColor = self._VersionBadgeOverride or self._Colors.Accent
            UI.TitleVersionBadge.BackgroundColor3 = badgeColor
            UI.TitleVersionBadge.TextColor3 = Fn.contrastForeground(badgeColor)
        end
        if UI.MainStroke then UI.MainStroke.Color = self._Colors.Border end
        if UI.TitleGradient then
            UI.TitleGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, self._Colors.Accent),
                ColorSequenceKeypoint.new(1, self._Colors.Accent2),
            })
        end
        if UI.SearchBar then UI.SearchBar.BackgroundColor3 = self._Colors.Card end
        if UI.SearchBarStroke then UI.SearchBarStroke.Color = self._Colors.Border end
        if UI.SearchInput then
            UI.SearchInput.TextColor3 = self._Colors.Text
            UI.SearchInput.PlaceholderColor3 = self._Colors.TextDim
        end
        if UI.SearchIcon then UI.SearchIcon.ImageColor3 = self._Colors.TextDim end
        if UI.FavoritesToggleIcon then
            UI.FavoritesToggleIcon.ImageColor3 = self._STATE.FavoritesOnly and self._Colors.Accent or self._Colors.TextDim
        end
        if UI.MobileToggle then
            UI.MobileToggle.BackgroundColor3 = self._Colors.Card
            UI.MobileToggle.TextColor3 = self._Colors.Text
        end
        if UI.MobileToggleStroke then UI.MobileToggleStroke.Color = self._Colors.Accent end
        if UI.KeybindOverlay then
            UI.KeybindOverlay.BackgroundColor3 = self._Colors.Bg2
        end
        if UI.KeybindOverlayStroke then UI.KeybindOverlayStroke.Color = self._Colors.Border end
        if UI.KeybindOverlayList then UI.KeybindOverlayList.ScrollBarImageColor3 = self._Colors.Accent end
        if UI.KeybindOverlayToggle then
            UI.KeybindOverlayToggle.BackgroundColor3 = self._Colors.Card
        end
        if UI.KeybindOverlayToggleStroke then UI.KeybindOverlayToggleStroke.Color = self._Colors.Accent end
        if UI.KeybindOverlayToggleIcon then UI.KeybindOverlayToggleIcon.ImageColor3 = self._Colors.Accent end
        if UI.KeybindOverlayToggleText then UI.KeybindOverlayToggleText.TextColor3 = self._Colors.Accent end
    end)
    if not ok then
        warn("[DoD UI] Theme UI refresh failed: " .. tostring(err))
    end

    for index, fn in ipairs(self._STATE.ThemeRefreshers) do
        local refreshed, refreshError = pcall(fn)
        if not refreshed then
            warn("[DoD UI] Theme refresher " .. index .. " failed: " .. tostring(refreshError))
        end
    end

    for frame, parts in pairs(self._STATE.notifParts) do
        if frame and frame.Parent then
            frame.BackgroundColor3 = self._Colors.Bg2
            if parts.stroke and parts.stroke.Parent then parts.stroke.Color = self._Colors.Accent end
            if parts.accentBar and parts.accentBar.Parent then parts.accentBar.BackgroundColor3 = self._Colors.Accent end
            if parts.progressBar and parts.progressBar.Parent then parts.progressBar.BackgroundColor3 = self._Colors.Accent end
            if parts.titleLabel and parts.titleLabel.Parent then parts.titleLabel.TextColor3 = self._Colors.Text end
            if parts.textLabel and parts.textLabel.Parent then parts.textLabel.TextColor3 = self._Colors.TextDim end
        end
    end

    if self._STATE.SubTabBar then
        self._STATE.SubTabBar:RefreshTheme({
            PillBg       = self._Colors.Card,
            LeftAccent   = self._Colors.Accent,
            TextActive   = Fn.contrastForeground(self._Colors.Card),
            TextInactive = self._Colors.TextDim,
            FontActive   = Enum.Font.GothamBold,
            FontInactive = Enum.Font.GothamMedium,
        })
    end

    if self._UI.FocusOverlay then
        self:_updateFocusOverlay(theme)
    end

    if not silent then
        if self._themeAutoAdjusted then
            self:Notify("THEME", "Applied: " .. actualName .. " (auto-adjusted)", "info")
        else
            self:Notify("THEME", "Applied: " .. actualName)
        end
    end
end

function Library:SetAccentColor(color)
    if self:_isDead() then return end
    if typeof(color) ~= "Color3" then
        error("[DoD UI] SetAccentColor expects a Color3 value.")
    end
    self._AccentOverride = color
    -- Flag the internal re-apply so SetTheme does not clear the override we just
    -- set, while a normal theme change still resets it.
    self._applyingAccent = true
    self:SetTheme(self.ThemeName, true)
    self._applyingAccent = false
end

function Library:SetAcrylic(enabled, blurIntensity)
    if self:_isDead() then return end
    if type(enabled) ~= "boolean" then
        error("[DoD UI] SetAcrylic expects a boolean enabled value.")
    end
    if blurIntensity ~= nil then self:SetAcrylicIntensity(blurIntensity) end
    self.Acrylic = enabled

    local UI = self._UI
    if UI.MainContainer then
        UI.MainContainer.BackgroundTransparency = enabled and 0.32 or 0.1
    end
    if UI.AcrylicTexture then
        UI.AcrylicTexture.Visible = enabled
        UI.AcrylicTexture.BackgroundTransparency = enabled and 0.94 or 1
    end
    if UI.AcrylicSheen then
        UI.AcrylicSheen.Visible = enabled
        UI.AcrylicSheen.BackgroundTransparency = enabled and 0.72 or 1
    end
    self:_updateAcrylicBlur()
end

function Library:SetAcrylicIntensity(intensity)
    if self:_isDead() then return end
    if type(intensity) ~= "number" or intensity < 0 or intensity > 24
        or intensity ~= intensity then
        error("[DoD UI] Acrylic intensity must be a number between 0 and 24.")
    end
    self.AcrylicBlurIntensity = intensity
    self:_updateAcrylicBlur()
end

function Library:SetReducedMotion(enabled)
    if self:_isDead() then return end
    SharedReduced.value = enabled and true or false
    self._STATE.ReducedMotion = SharedReduced.value
end

function Library:_densityPadding(base)
    local mode = self._STATE.LayoutDensity or "Normal"
    if mode == "Compact" then return math.max(2, math.floor(base / 2)) end
    if mode == "Spacious" then return base + 4 end
    return base
end

function Library:SetLayoutDensity(density)
    if self:_isDead() then return end
    local mode = tostring(density or "Normal")
    if mode ~= "Compact" and mode ~= "Spacious" then mode = "Normal" end
    self._STATE.LayoutDensity = mode
    local function applyPadding(layout, base)
        if layout then
            layout.Padding = UDim.new(0, self:_densityPadding(base))
        end
    end
    for body, _ in pairs(self._STATE.SearchBodies) do
        if body and body.Parent then
            applyPadding(body:FindFirstChildOfClass("UIListLayout"), 8)
        end
    end
    for name, page in pairs(self._STATE.ContentPages) do
        if page and page.Parent then
            applyPadding(page:FindFirstChildOfClass("UIListLayout"), 10)
            local cols = self._STATE.TabColumns[name]
            if cols then
                if cols.Left then applyPadding(cols.Left:FindFirstChildOfClass("UIListLayout"), 10) end
                if cols.Right then applyPadding(cols.Right:FindFirstChildOfClass("UIListLayout"), 10) end
            end
        end
    end
end

function Library:SetSectionTransparency(transparency)
    if self:_isDead() then return end
    local trans = math.clamp(tonumber(transparency) or 0.15, 0, 1)
    self._STATE.SectionTransparency = trans
    -- Direct assignment, and it now also applies to the control rows: the setting
    -- used to tween every section on every slider tick while barely changing
    -- anything visible.
    local rowTrans = math.clamp(trans + 0.1, 0, 1)
    for _, sections in pairs(self._STATE.SearchSections) do
        for _, sec in ipairs(sections) do
            if sec.section and sec.section.Parent then
                sec.section.BackgroundTransparency = trans
                for _, control in ipairs(sec.controls or {}) do
                    local inst = control.instance
                    if inst and inst.Parent and inst:IsA("GuiObject") then
                        inst.BackgroundTransparency = rowTrans
                    end
                end
            end
        end
    end
end

function Library:_registerThemeRefresher(fn)
    table.insert(self._STATE.ThemeRefreshers, fn)
end

function Library:_unwrap(target)
    if target == nil then return nil end
    if typeof(target) == "Instance" then return target end
    if type(target) == "table" and target.__isHandle then return target.Raw end
    return target
end

function Library:_wrapSection(rawBody)
    if not rawBody then return nil end
    local lib = self
    local h = { __isHandle = true, Raw = rawBody, __tag = "Section" }
    h.AddToggle = function(_, ...) return lib:AddToggle(rawBody, ...) end
    h.AddSlider = function(_, ...) return lib:AddSlider(rawBody, ...) end
    h.AddDropdown = function(_, ...) return lib:AddDropdown(rawBody, ...) end
    h.AddMultiDropdown = function(_, ...) return lib:AddMultiDropdown(rawBody, ...) end
    h.AddKeybind = function(_, ...) return lib:AddKeybind(rawBody, ...) end
    h.AddButton = function(_, ...) return lib:AddButton(rawBody, ...) end
    h.AddLabel = function(_, ...) return lib:AddLabel(rawBody, ...) end
    h.AddParagraph = function(_, ...) return lib:AddParagraph(rawBody, ...) end
    h.AddTextbox = function(_, ...) return lib:AddTextbox(rawBody, ...) end
    h.AddColorPicker = function(_, ...) return lib:AddColorPicker(rawBody, ...) end
    h.AddConfigList = function(_, ...) return lib:AddConfigList(rawBody, ...) end
    h.AddSeparator = function(_, ...) return lib:AddSeparator(rawBody, ...) end
    h.AddChipBar = function(_, ...) return lib:AddChipBar(rawBody, ...) end
    return h
end

function Library:_wrapTab(rawPage, tabName)
    if not rawPage then return nil end
    local lib = self
    local h = { __isHandle = true, Raw = rawPage, __tag = "Tab", Name = tabName }
    h.CreateSection = function(_, title, summary, defaultOpen, columnName, iconName)
        return lib:CreateSection(tabName, title, summary, defaultOpen, columnName, iconName)
    end
    h.CreateDashboardBanner = function(_, ...) return lib:CreateDashboardBanner(tabName, ...) end
    h.CreateThemeCustomizer = function(_, ...) return lib:CreateThemeCustomizer(tabName, ...) end
    h.CreateQuickDashboard = function(_, columnName) return lib:CreateQuickDashboard(tabName, columnName) end
    h.CreatePerformanceDashboard = function(_, columnName) return lib:CreatePerformanceDashboard(tabName, columnName) end
    return h
end

function Library:_getConfigId(controlType, label)
    if type(label) ~= "string" then label = tostring(label or "") end
    local key = tostring(controlType) .. ":" .. label
    local counter = self._STATE.ConfigCounter
    counter[key] = (counter[key] or 0) + 1
    local n = counter[key]
    if n > 1 then return key .. "#" .. n end
    return key
end

function Library:_registerConfigState(id, getter, setter)
    if self:_isDead() then return id end
    self._STATE.ConfigRegistry[id] = { get = getter, set = setter }
    return id
end

function Library:_triggerAutoSave()
    if self:_isDead() then return end
    local auto = self._STATE.ConfigAutoSave
    if not auto or not auto.name then return end
    if self._autoSavePending then return end
    self._autoSavePending = true
    task.delay(0.6, function()
        self._autoSavePending = false
        if not self:_isDead() then
            self:SaveConfig(auto.name, true)
        end
    end)
end


return true
