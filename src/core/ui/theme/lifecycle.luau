--[[
  WINDOW TOGGLE / MINIMIZE / DESTROY

  Split out of src/core/ui/demon-theme.luau (original lines 12106-12975).
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
-- WINDOW TOGGLE / DESTROY
-- =========================================================

function Library:_themeSnapshot()
    local snap = {
        _version = self.Version,
        PerfAuto = self._perfAuto,
        PerfTier = self._perfTier,
        ThemeName = self.ThemeName,
        Acrylic = self.Acrylic,
        AcrylicBlurIntensity = self.AcrylicBlurIntensity,
        SoundsEnabled = self._SoundsEnabled,
        SoundVolume = self._SoundVolume,
        NotifPosition = self._NotifPosition,
        WallpaperSource = self.WallpaperSource or false,
        WallpaperTransparency = self.WallpaperTransparency,
        TitleIconName = self._TitleIconName,
        FocusOverlayEnabled = self._STATE.FocusOverlayEnabled,
        FocusOverlayType = self._STATE.FocusOverlayType,
        WeatherEnabled = self._STATE.WeatherEnabled,
        WeatherType = self._STATE.WeatherType,
        WeatherIntensity = self._STATE.WeatherIntensity,
        ReducedMotion = self._STATE.ReducedMotion,
        LayoutDensity = self._STATE.LayoutDensity,
        SectionTransparency = self._STATE.SectionTransparency,
        TooltipEnabled = self._STATE.TooltipEnabled,
        TooltipTransparency = self._STATE.TooltipTransparency,
        ActiveCategory = self._STATE.ActiveCategory,
        ActiveTab = self._STATE.ActiveTab,
        CursorTrailEnabled = self._cursorTrailEnabled or false,
        CursorTrailColor = self._cursorTrailColor and { self._cursorTrailColor.R, self._cursorTrailColor.G, self._cursorTrailColor.B } or nil,
        _timestamp = os.time(),
    }
    if self._AccentOverride then
        snap.AccentOverride = { self._AccentOverride.R, self._AccentOverride.G, self._AccentOverride.B }
    end
    if self._VersionBadgeOverride then
        snap.VersionBadgeOverride = { self._VersionBadgeOverride.R, self._VersionBadgeOverride.G, self._VersionBadgeOverride.B }
    end
    -- Custom palette overrides were never serialised, so they were silently
    -- dropped by every save/export.
    local custom = {}
    for key, color in pairs(self._CustomColorOverrides or {}) do
        if typeof(color) == "Color3" then
            custom[key] = { color.R, color.G, color.B }
        end
    end
    snap.CustomColorOverrides = custom
    return snap
end

function Library:_applyThemeSnapshot(data, silent)
    if type(data) ~= "table" then return false, "invalid snapshot" end
    if self:_isDead() then return false, "library destroyed" end
    local previousLoading = self._themeLoading
    self._themeLoading = true
    local ok, err = pcall(function()
        -- Clear overrides the snapshot does not carry, otherwise importing a
        -- partial/older theme leaves the previous session's accent and badge
        -- colour in place and the theme looks half-applied.
        if type(data.AccentOverride) ~= "table" then
            self._AccentOverride = nil
        end
        if type(data.VersionBadgeOverride) ~= "table" then
            self._VersionBadgeOverride = nil
        end
        self._CustomColorOverrides = {}
        if type(data.CustomColorOverrides) == "table" then
            for key, rgb in pairs(data.CustomColorOverrides) do
                if type(rgb) == "table" and #rgb >= 3 then
                    self._CustomColorOverrides[key] = Color3.new(rgb[1], rgb[2], rgb[3])
                end
            end
        end
        if type(data.PerfAuto) == "boolean" then
            self._perfAuto = data.PerfAuto
        end
        if type(data.PerfTier) == "string" and D.PerfProfiles[data.PerfTier] then
            self._savedPerfTier = data.PerfTier
            -- Applying it only in the constructor meant a runtime load reported
            -- success while the tier never changed.
            if self._initialized then
                self:SetPerformanceTier(data.PerfTier, true)
            end
        end
        if type(data.AccentOverride) == "table" and #data.AccentOverride >= 3 then
            self._AccentOverride = Color3.new(data.AccentOverride[1], data.AccentOverride[2], data.AccentOverride[3])
        end
        if type(data.VersionBadgeOverride) == "table" and #data.VersionBadgeOverride >= 3 then
            self._VersionBadgeOverride = Color3.new(data.VersionBadgeOverride[1], data.VersionBadgeOverride[2], data.VersionBadgeOverride[3])
        end
        if type(data.ThemeName) == "string" and D.Themes[data.ThemeName] then
            self:SetTheme(data.ThemeName, true)
        end
        if type(data.Acrylic) == "boolean" then
            self:SetAcrylic(data.Acrylic)
        end
        if type(data.AcrylicBlurIntensity) == "number" then
            self:SetAcrylicIntensity(data.AcrylicBlurIntensity)
        end
        if type(data.SoundsEnabled) == "boolean" then
            self:SetSoundsEnabled(data.SoundsEnabled)
        end
        if type(data.SoundVolume) == "number" then
            self:SetSoundVolume(data.SoundVolume)
        end
        if type(data.NotifPosition) == "string" then
            self:SetNotificationPosition(data.NotifPosition)
        end
        if type(data.FocusOverlayEnabled) == "boolean" then
            self:SetFocusOverlay(data.FocusOverlayEnabled, type(data.FocusOverlayType) == "string" and data.FocusOverlayType or nil)
        end
        if type(data.WeatherEnabled) == "boolean" then
            self:SetWeather(data.WeatherEnabled, type(data.WeatherType) == "string" and data.WeatherType or nil, type(data.WeatherIntensity) == "number" and data.WeatherIntensity or nil)
        end
        if type(data.ReducedMotion) == "boolean" then
            self:SetReducedMotion(data.ReducedMotion)
        end
        if type(data.LayoutDensity) == "string" then
            self:SetLayoutDensity(data.LayoutDensity)
        end
        if type(data.SectionTransparency) == "number" then
            self:SetSectionTransparency(data.SectionTransparency)
        end
        if type(data.TooltipEnabled) == "boolean" then
            self:SetTooltipEnabled(data.TooltipEnabled)
        end
        if type(data.TooltipTransparency) == "number" then
            self:SetTooltipTransparency(data.TooltipTransparency)
        end
        if type(data.CursorTrailEnabled) == "boolean" then
            self:SetCursorTrail(data.CursorTrailEnabled)
        end
        if type(data.CursorTrailColor) == "table" and #data.CursorTrailColor >= 3 then
            self:SetCursorTrailColor(Color3.new(data.CursorTrailColor[1], data.CursorTrailColor[2], data.CursorTrailColor[3]))
        end
        if type(data.ActiveTab) == "string" and data.ActiveTab ~= "" then
            self._pendingTabRestore = {
                category = type(data.ActiveCategory) == "string" and data.ActiveCategory or nil,
                tab = data.ActiveTab,
            }
        end
        if type(data.TitleIconName) == "string" and data.TitleIconName ~= "" then
            self:SetTitleIcon(data.TitleIconName)
            self._TitleIconName = data.TitleIconName
        end
        if type(data.WallpaperSource) == "string" and data.WallpaperSource ~= "" then
            self:SetWallpaper(data.WallpaperSource, tonumber(data.WallpaperTransparency) or 0)
            self.WallpaperSource = data.WallpaperSource
            self.WallpaperTransparency = tonumber(data.WallpaperTransparency) or 0
        elseif data.WallpaperSource == false and self.WallpaperSource then
            self:SetWallpaper(nil)
            self.WallpaperSource = nil
        end
        if type(data.WallpaperTransparency) == "number" then
            self.WallpaperTransparency = data.WallpaperTransparency
            if self._UI.Wallpaper and self._UI.Wallpaper.Visible then
                self._UI.Wallpaper.ImageTransparency = math.clamp(data.WallpaperTransparency, 0, 1)
            end
        end
    end)
    -- Restore the previous value instead of clearing it: a snapshot applied from
    -- inside another theme operation used to re-enable autosave mid-flight.
    self._themeLoading = previousLoading
    if not ok then
        if not silent then
            warn("[DoD UI] Theme apply failed: " .. tostring(err))
        end
        return false, err
    end
    return true
end

function Library:_triggerThemeSave()
    if not self._initialized then return end
    if self._themeLoading then return end
    if self._themeSavePending then return end
    self._themeSavePending = true
    task.delay(0.8, function()
        self._themeSavePending = false
        if not self:_isDead() then
            self:SaveThemeConfig("settings", true)
        end
    end)
end

function Library:ExportTheme()
    if self:_isDead() then return {} end
    return self:_themeSnapshot()
end

function Library:ImportTheme(data, silent)
    if self:_isDead() then return end
    if type(data) ~= "table" then
        if not silent then self:Notify("THEME", "Invalid theme data", "error") end
        return
    end
    local ok, err = self:_applyThemeSnapshot(data, silent)
    if not silent then
        if ok then
            self:Notify("THEME", "Theme applied", "success")
        else
            self:Notify("THEME", "Apply failed: " .. tostring(err), "error")
        end
    end
end

function Library:SaveThemeConfig(name, silent)
    if self:_isDead() then return false end
    local key = type(name) == "string" and name ~= "" and name or "settings"
    local g = (getgenv and getgenv()) or _G
    local snap = self:_themeSnapshot()
    local ok, json = pcall(function()
        return game:GetService("HttpService"):JSONEncode(snap)
    end)
    if not ok or type(json) ~= "string" then
        if not silent then self:Notify("THEME", "JSON encode failed", "error") end
        return false
    end
    -- Always mirror into memory as well: an executor that exposes writefile but
    -- not isfile/readfile used to write where the loader never looked.
    g.__DoDThemeConfigs = g.__DoDThemeConfigs or {}
    g.__DoDThemeConfigs[key] = json
    local path = "DoD_Theme_" .. key .. ".json"
    local fileOk = false
    pcall(function()
        if writefile and type(writefile) == "function" then
            writefile(path, json)
            fileOk = true
        end
    end)
    g.DoD_LastTheme = key
    if not silent then
        if fileOk then
            self:Notify("THEME", "Saved: " .. key, "success")
        else
            self:Notify("THEME", "Saved (memory only): " .. key, "warning")
        end
    end
    return true
end

function Library:LoadThemeConfig(name, silent)
    if self:_isDead() then return end
    local key = type(name) == "string" and name ~= "" and name or "settings"
    local path = "DoD_Theme_" .. key .. ".json"
    local json = nil
    pcall(function()
        if isfile and type(isfile) == "function" and readfile and type(readfile) == "function" then
            if isfile(path) then json = readfile(path) end
        end
    end)
    if not json then
        local g = (getgenv and getgenv()) or _G
        if g.__DoDThemeConfigs and g.__DoDThemeConfigs[key] then
            json = g.__DoDThemeConfigs[key]
        end
    end
    if type(json) ~= "string" then
        if not silent then self:Notify("THEME", "Not found: " .. key, "warning") end
        return
    end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(json)
    end)
    if not ok or type(data) ~= "table" then
        if not silent then self:Notify("THEME", "Decode failed", "error") end
        return
    end
    local appliedOk, applyErr = self:_applyThemeSnapshot(data, true)
    if not appliedOk then
        if not silent then
            self:Notify("THEME", "Load failed: " .. tostring(applyErr), "error")
        end
        return false
    end
    local g = (getgenv and getgenv()) or _G
    g.DoD_LastTheme = key
    if not silent then
        self:Notify("THEME", "Loaded: " .. key, "success")
    end
    return true
end

function Library:GetThemeConfigs()
    local seen, configs = {}, {}
    local g = (getgenv and getgenv()) or _G
    local function add(name)
        if type(name) ~= "string" or name == "" then return end
        if seen[name] then return end
        seen[name] = true
        table.insert(configs, name)
    end
    pcall(function()
        if listfiles and type(listfiles) == "function" then
            for _, file in ipairs(listfiles()) do
                local base = string.match(tostring(file), "[^\\/]+$") or tostring(file)
                local name = string.match(base, "^DoD_Theme_(.+)%.json$")
                if name then add(name) end
            end
        end
    end)
    -- Merge the in-memory store unconditionally; the old code only looked there
    -- when listfiles was missing entirely, so memory-only themes were invisible.
    if g.__DoDThemeConfigs then
        for name in pairs(g.__DoDThemeConfigs) do add(name) end
    end
    table.sort(configs)
    return configs
end

function Library:ResetThemeConfig(silent)
    if self:_isDead() then return end
    self._AccentOverride = nil
    self._VersionBadgeOverride = nil
    self._CustomColorOverrides = {}
    self:_applyThemeSnapshot({
        ThemeName = "Demon of Darkness",
        PerfAuto = true,
        Acrylic = true,
        AcrylicBlurIntensity = 8,
        SoundsEnabled = true,
        SoundVolume = 1,
        NotifPosition = "TopRight",
        FocusOverlayEnabled = false,
        FocusOverlayType = "Grid",
        WeatherEnabled = false,
        WeatherType = "Snow",
        WeatherIntensity = 65,
        ReducedMotion = false,
        LayoutDensity = "Normal",
        SectionTransparency = 0.15,
        TooltipEnabled = true,
        TooltipTransparency = 0.15,
        CursorTrailEnabled = false,
        TitleIconName = "hexagon",
        WallpaperSource = false,
        WallpaperTransparency = 0,
        CustomColorOverrides = {},
    }, true)
    -- Persist, otherwise the next launch reloads the old settings and the reset
    -- silently undoes itself.
    self:SaveThemeConfig("settings", true)
    if not silent then self:Notify("THEME", "Reset to defaults", "info") end
end

function Library:_isDead()
    local state = self._STATE
    if not state then return true end
    if state.Destroyed then return true end
    -- Treat a half-built instance (constructor threw after _STATE existed) as
    -- dead instead of letting every method index a missing _UI.
    return self._UI == nil
end

function Library:Minimize()
    if self:_isDead() then return end
    local STATE = self._STATE
    local UI = self._UI
    if not STATE.GuiVisible or STATE.AnimatingGui then return end
    STATE.AnimatingGui = true
    STATE.GuiVisible = false
    if UI.MobileToggle then UI.MobileToggle.Visible = false end
    for _, _entry in ipairs(STATE.activeDropdownPopups) do
        if _entry and _entry.close then pcall(_entry.close) end
    end
    
    self:PlaySound("ToggleOff")
    
    self._overGui = false
    if self._savedMouseIconEnabled ~= nil then
        UserInputService.MouseIconEnabled = self._savedMouseIconEnabled
    else
        UserInputService.MouseIconEnabled = true
    end
    if UI.CustomCursor then UI.CustomCursor.Visible = false end
    if self._savedMouseBehavior then
        UserInputService.MouseBehavior = self._savedMouseBehavior
    end
    
    -- OPTIMIZED: Removed the 40-particle burst and consolidated the
    -- 6 separate tween calls. This slides the window up smoothly with
    -- a subtle shrink, drastically reducing CPU overhead on mobile.
    STATE.SavedPos = UI.MainContainer.Position
    local slideDist = 150
    local targetPos = UDim2.new(STATE.SavedPos.X.Scale, STATE.SavedPos.X.Offset, STATE.SavedPos.Y.Scale, STATE.SavedPos.Y.Offset - slideDist)
    
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    
    TweenService:Create(UI.GuiBlur, TweenInfo.new(0.2), {Size = 0}):Play()
    
    local _tScale = self._adaptiveScaleTarget or 1
    local st = TweenService:Create(UI.MainScale, tweenInfo, {Scale = _tScale * 0.85})
    st:Play()
    
    TweenService:Create(UI.MainContainer, tweenInfo, {
        BackgroundTransparency = 1,
        Position = targetPos
    }):Play()
    if UI.AcrylicTexture then TweenService:Create(UI.AcrylicTexture, tweenInfo, {BackgroundTransparency = 1}):Play() end
    if UI.AcrylicSheen then TweenService:Create(UI.AcrylicSheen, tweenInfo, {BackgroundTransparency = 1}):Play() end
    if UI.FocusOverlay then TweenService:Create(UI.FocusOverlay, tweenInfo, {BackgroundTransparency = 1}):Play() end
    
    st.Completed:Connect(function(playbackState)
        if STATE.Destroyed then return end
        if playbackState == Enum.PlaybackState.Cancelled then
            STATE.AnimatingGui = false
            return
        end
        UI.MainContainer.Visible = false
        UI.ParticleBG.Visible = false
        UI.FocusOverlay.Visible = false
        STATE.GuiVisible = false
        STATE.AnimatingGui = false
        
        local btn = UI.MinimizeButton
        if btn then
            local _tw = self._minBtnBaseW or 180
            local _th = self._minBtnBaseH or 28
            local _ty = self._minBtnBaseY or 16
            btn.Visible = true
            btn.Size = UDim2.fromOffset(0, _th)
            btn.Position = UDim2.new(0.5, 0, 0, -(_th + 12))
            TweenService:Create(btn, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(_tw, _th),
                Position = UDim2.new(0.5, 0, 0, _ty)
            }):Play()
        end
    end)
end

function Library:_registerScrollFrame(frame)
    if not frame then return end
    table.insert(self._STATE.ScrollFrames, frame)
    self:_attachScrollSound(frame)
    return frame
end

function Library:_attachScrollSound(frame)
    if not frame or not frame.Parent then return end
    if self._isMobile then return end
    if frame:GetAttribute("DoD_ScrollSound") then return end
    frame:SetAttribute("DoD_ScrollSound", true)
    local lastPlay = 0
    Fn.track(frame:GetPropertyChangedSignal("CanvasPosition"), function()
        if self:_isDead() then return end
        if not self._STATE.GuiVisible then return end
        if not self._SoundsEnabled then return end
        local now = os.clock()
        if now - lastPlay < 0.12 then return end
        lastPlay = now
        self:PlaySound("Scroll")
    end, self)
end

function Library:PlaySound(soundName)
    if self:_isDead() then return end
    if not self._SoundsEnabled then return end
    local s = self._Sounds and self._Sounds[soundName]
    if s then
        local baseVol = (GuiSound[soundName] and GuiSound[soundName].vol) or 1
        s.Volume = baseVol * (self._SoundVolume or 1)
        s:Play()
    end
end

function Library:SetSoundsEnabled(enabled)
    if self:_isDead() then return end
    self._SoundsEnabled = enabled and true or false
end

function Library:SetSoundVolume(volume)
    if self:_isDead() then return end
    local v = tonumber(volume) or 1
    self._SoundVolume = math.clamp(v, 0, 1)
end

function Library:Toggle()
    if self:_isDead() then return end
    local STATE = self._STATE
    local UI = self._UI
    if STATE.AnimatingGui then
        -- Record the intent instead of dropping the press: double-tapping the
        -- hotkey used to leave the window in the state the *first* press started.
        STATE.ToggleQueued = not STATE.GuiVisible
        return
    end
    STATE.AnimatingGui = true
    if STATE.GuiTween then STATE.GuiTween:Cancel() end

    local function settleAnimation()
        STATE.AnimatingGui = false
        STATE.GuiTween = nil
        local queued = STATE.ToggleQueued
        if queued ~= nil then
            STATE.ToggleQueued = nil
            if queued ~= STATE.GuiVisible then
                task.defer(function()
                    if not self:_isDead() then self:Toggle() end
                end)
            end
        end
    end

    local blurTarget = self.Acrylic and self.AcrylicBlurIntensity or 0
    if STATE.FocusOverlayEnabled then blurTarget = math.max(blurTarget, 12) end
    if self._perfTier == "Potato" then
        blurTarget = math.min(blurTarget, 3)
    end
    local mainBgTrans = self.Acrylic and 0.32 or 0.1

    if STATE.GuiVisible then
        -- CLOSE ANIMATION (Smooth Slide Down + Fade Out)
        self:PlaySound("ToggleOff")
        for _, _entry in ipairs(STATE.activeDropdownPopups) do
            if _entry and _entry.close then pcall(_entry.close) end
        end
        STATE.GuiVisible = false
        self._overGui = false
        -- Hand the OS cursor back the way the game had it, not always "visible".
        if self._savedMouseIconEnabled ~= nil then
            UserInputService.MouseIconEnabled = self._savedMouseIconEnabled
        else
            UserInputService.MouseIconEnabled = true
        end
        if UI.CustomCursor then UI.CustomCursor.Visible = false end
        if self._savedMouseBehavior then
            UserInputService.MouseBehavior = self._savedMouseBehavior
        end
        
        STATE.SavedPos = UI.MainContainer.Position
        local targetPos = UDim2.new(STATE.SavedPos.X.Scale, STATE.SavedPos.X.Offset, STATE.SavedPos.Y.Scale, STATE.SavedPos.Y.Offset + 30)
        
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        
        TweenService:Create(UI.GuiBlur, tweenInfo, {Size = 0}):Play()
        TweenService:Create(UI.MainContainer, tweenInfo, {BackgroundTransparency = 1, Position = targetPos}):Play()
        if UI.AcrylicTexture then TweenService:Create(UI.AcrylicTexture, tweenInfo, {BackgroundTransparency = 1}):Play() end
        if UI.AcrylicSheen then TweenService:Create(UI.AcrylicSheen, tweenInfo, {BackgroundTransparency = 1}):Play() end
        TweenService:Create(UI.FocusOverlay, tweenInfo, {BackgroundTransparency = 1}):Play()
        
        local _tScale = self._adaptiveScaleTarget or 1
        STATE.GuiTween = TweenService:Create(UI.MainScale, tweenInfo, {Scale = _tScale * 0.96})
        STATE.GuiTween:Play()
        
        STATE.GuiTween.Completed:Connect(function(playbackState)
            if STATE.Destroyed then return end
            if playbackState == Enum.PlaybackState.Cancelled then
                settleAnimation()
                return
            end
            UI.MainContainer.Visible = false
            UI.ParticleBG.Visible = false
            UI.FocusOverlay.Visible = false
            STATE.GuiVisible = false
            settleAnimation()
        end)
    else
        -- OPEN ANIMATION (Smooth Slide Up + Fade In)
        self:PlaySound("ToggleOn")
        -- Capture the current game mouse behavior right before we start
        -- forcing Default. Doing this at open time (not at construction)
        -- keeps the value fresh if the game locked the mouse mid-session
        -- (combat, aiming, cutscene, etc). Close path restores this value.
        self._savedMouseBehavior = UserInputService.MouseBehavior
        if not self._isMobile and UI.CustomCursor then 
            UI.CustomCursor.Visible = true 
        end

        local fromPill = UI.MinimizeButton and UI.MinimizeButton.Visible
        UI.MainContainer.Visible = true
        local _wantParticles = (self._perfProfile and self._perfProfile.ParticleBG) ~= false
        if _wantParticles then
            task.delay(0.08, function()
                if STATE.GuiVisible and not STATE.Destroyed and UI.ParticleBG then
                    UI.ParticleBG.Visible = true
                end
            end)
        end
        STATE.GuiVisible = true
        if UI.MinimizeButton then
            UI.MinimizeButton.Visible = false
        end
        
        local basePos = STATE.SavedPos or UI.MainContainer.Position
        local startPos = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale, basePos.Y.Offset + 30)
        
        local _tScale = self._adaptiveScaleTarget or 1
        if fromPill then
            UI.MainContainer.Position = UDim2.new(0.5, 0, 0, 30)
            UI.MainScale.Scale = _tScale * 0.4
        else
            UI.MainContainer.Position = startPos
            UI.MainScale.Scale = _tScale * 0.96
        end
        UI.MainContainer.BackgroundTransparency = 1
        if UI.AcrylicTexture then UI.AcrylicTexture.BackgroundTransparency = 1 end
        if UI.AcrylicSheen then UI.AcrylicSheen.BackgroundTransparency = 1 end
        UI.GuiBlur.Size = 0
        
        local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        
        if STATE.FocusOverlayEnabled and self._perfTier ~= "Potato" then
            task.delay(0.25, function()
                if not STATE.Destroyed and STATE.GuiVisible and UI.FocusOverlay then
                    UI.FocusOverlay.Visible = true
                    UI.FocusOverlay.BackgroundTransparency = 1
                    TweenService:Create(UI.FocusOverlay, tweenInfo, {
                        BackgroundTransparency = (D.Themes[self.ThemeName] or {}).OverlayTransparency or 0.45
                    }):Play()
                end
            end)
        end
        
        TweenService:Create(UI.GuiBlur, tweenInfo, {Size = blurTarget}):Play()
        TweenService:Create(UI.MainContainer, tweenInfo, {BackgroundTransparency = mainBgTrans, Position = basePos}):Play()
        if UI.AcrylicTexture then TweenService:Create(UI.AcrylicTexture, tweenInfo, {BackgroundTransparency = self.Acrylic and 0.94 or 1}):Play() end
        if UI.AcrylicSheen then TweenService:Create(UI.AcrylicSheen, tweenInfo, {BackgroundTransparency = self.Acrylic and 0.72 or 1}):Play() end
        
        STATE.GuiTween = TweenService:Create(UI.MainScale, tweenInfo, {Scale = _tScale})
        STATE.GuiTween:Play()
        
        STATE.GuiTween.Completed:Connect(function(playbackState)
            if STATE.Destroyed then return end
            if playbackState == Enum.PlaybackState.Cancelled then
                settleAnimation()
                return
            end
            settleAnimation()
        end)
    end
end

function Library:BindToClose(callback)
    if self:_isDead() then return end
    if type(callback) ~= "function" then return end
    table.insert(self._STATE._closeCallbacks, callback)
    -- Actually bind to the engine: the old version only stored the callback, so
    -- "save my config on exit" handlers never ran when the player left.
    if not self._engineCloseBound then
        self._engineCloseBound = true
        pcall(function()
            game:BindToClose(function()
                if self:_isDead() then return end
                for _, cb in ipairs(self._STATE._closeCallbacks or {}) do
                    pcall(cb)
                end
            end)
        end)
    end
    return callback
end

function Library:ShowContextMenu(position, options)
    if self:_isDead() then return end
    if type(options) ~= "table" or #options == 0 then return end
    
    if self._activeContextMenu and self._activeContextMenu.Parent then
        self._activeContextMenu:Destroy()
    end
    
    local menu = Instance.new("Frame", self._UI.MainGui)
    menu.Name = "ContextMenu"
    menu.Size = UDim2.fromOffset(200, #options * 30 + 8)
    menu.BackgroundColor3 = self._Colors.Bg2
    menu.BackgroundTransparency = 0.05
    menu.BorderSizePixel = 0
    menu.ZIndex = 9600
    menu.ClipsDescendants = true
    Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 8)
    
    local mStroke = Instance.new("UIStroke", menu)
    mStroke.Color = self._Colors.Accent
    mStroke.Thickness = 1
    mStroke.Transparency = 0.3
    
    local cam = getCam()
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    local px = math.clamp(position.X, 8, math.max(8, vp.X - 208))
    local py = math.clamp(position.Y, 8, math.max(8, vp.Y - menu.Size.Y.Offset - 8))
    menu.Position = UDim2.fromOffset(px, py)
    
    local layout = Instance.new("UIListLayout", menu)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 1)
    
    local pad = Instance.new("UIPadding", menu)
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    
    for i, rawOpt in ipairs(options) do
        -- Normalise entries: a bare string used to raise "attempt to index
        -- string" mid-build, leaving a half-constructed menu on screen forever.
        local opt = rawOpt
        if type(opt) == "string" then
            opt = { label = opt }
        elseif type(opt) ~= "table" then
            warn("[DoD UI] ShowContextMenu: skipping invalid option #" .. tostring(i))
            opt = { label = tostring(opt) }
        end
        local btn = Instance.new("TextButton", menu)
        btn.LayoutOrder = i
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.BackgroundColor3 = self._Colors.Card
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.ZIndex = 9601
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        
        local lbl = Instance.new("TextLabel", btn)
        lbl.Size = UDim2.new(1, -12, 1, 0)
        lbl.Position = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(opt.label or "")
        lbl.TextColor3 = self._Colors.Text
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 9602
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.6}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            if self._activeContextMenu == menu then
                self._activeContextMenu = nil
            end
            menu:Destroy()
            if opt.callback then
                local _ok, _err = pcall(opt.callback)
                if not _ok then warn("[DoD UI] ContextMenu callback error: " .. tostring(_err)) end
            end
        end)
    end
    
    local dismissConn
    dismissConn = UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            local mp = inp.Position
            local mpos, msz = menu.AbsolutePosition, menu.AbsoluteSize
            if mp.X < mpos.X or mp.X > mpos.X + msz.X or mp.Y < mpos.Y or mp.Y > mpos.Y + msz.Y then
                menu:Destroy()
                if dismissConn then pcall(function() dismissConn:Disconnect() end) end
            end
        end
    end)
    
    menu.Destroying:Connect(function()
        if dismissConn then pcall(function() dismissConn:Disconnect() end) end
    end)
    
    self._activeContextMenu = menu
    return menu
end

function Library:Destroy()
    local STATE = self._STATE
    if not STATE or STATE.Destroyed or STATE._destroying then return end
    STATE._destroying = true
    local _ok, _err = pcall(function()
    STATE.GuiVisible = false

    -- Flush debounced writes first: `Destroyed` is only set after this pcall, so
    -- the public save methods still function here. Without this the last 0.6-0.8s
    -- of user changes were silently dropped on close.
    pcall(function()
        local auto = STATE.ConfigAutoSave
        if auto and auto.name then self:SaveConfig(auto.name, true) end
        if self._initialized then self:SaveThemeConfig("settings", true) end
    end)

    self._overGui = false
    if self._savedMouseIconEnabled ~= nil then
        UserInputService.MouseIconEnabled = self._savedMouseIconEnabled
    else
        UserInputService.MouseIconEnabled = true
    end
    if self._savedMouseBehavior then
        UserInputService.MouseBehavior = self._savedMouseBehavior
    end

    STATE.WeatherEnabled = false
    if STATE.GuiTween then
        pcall(function() STATE.GuiTween:Cancel() end)
        STATE.GuiTween = nil
    end
    STATE.AnimatingGui = false
    if self._loadingSpinConn then
        pcall(function() Fn.untrack(self._loadingSpinConn, self) end)
        self._loadingSpinConn = nil
    end

    pcall(function() self:_hideTooltip(true) end)
    pcall(function() self:_stopWeather() end)
    for _, entry in ipairs(STATE.activeDropdownPopups or {}) do
        if entry and entry.close then pcall(entry.close) end
    end
    if self._activeContextMenu then
        pcall(function() self._activeContextMenu:Destroy() end)
        self._activeContextMenu = nil
    end
    if self._ActiveConfirm then
        pcall(function() self._ActiveConfirm:Destroy() end)
        self._ActiveConfirm = nil
    end
    self._ConfirmAnimating = false

    for _, frame in ipairs(STATE.activeNotifs) do
        if frame and frame.Parent then frame:Destroy() end
        STATE.notifParts[frame] = nil
    end
    table.clear(STATE.activeNotifs)
    table.clear(STATE.NotifQueue)
    table.clear(STATE.notifParts)
    STATE.NotifActive = 0

    pcall(function() if self._UI.GuiBlur then self._UI.GuiBlur:Destroy() end end)
    pcall(function() if self._UI.MainGui then self._UI.MainGui:Destroy() end end)
    pcall(function() if self._UI.NotifGui then self._UI.NotifGui:Destroy() end end)
    pcall(function() if self._UI.TooltipGui then self._UI.TooltipGui:Destroy() end end)

    for _, _snd in pairs(self._Sounds or {}) do pcall(function() _snd:Stop(); _snd:Destroy() end) end
    self._Sounds = {}

    Fn.disconnectAll(self)
    self._particleBGConn = nil
    self._loadingSpinConn = nil
    self._favTweens = nil
    self._cursorTrailPool = nil
    self._UI = {}

    table.clear(STATE.ThemeRefreshers)
    table.clear(STATE.activeKeybindListeners)
    table.clear(STATE.KeybindOverlayRows)
    table.clear(STATE.activeDropdownPopups)
    table.clear(STATE.SearchSections)
    table.clear(STATE.SearchBodies)
    table.clear(STATE.SearchTopLevel)
    table.clear(STATE.ConfigRegistry)
    table.clear(STATE.ScrollFrames)
    table.clear(STATE.FavoriteHolders)
    if STATE.FavoriteStars then table.clear(STATE.FavoriteStars) end
    if STATE.ConfigCounter then table.clear(STATE.ConfigCounter) end
    if STATE.SubTabBars then table.clear(STATE.SubTabBars) end
    table.clear(STATE.SavedScrollPositions)

    -- Module-level flags outlive the instance: leaving them set made the *next*
    -- library instance start with every tween at zero duration.
    SharedReduced.value = false
    STATE.ReducedMotion = false

    for _, cb in ipairs(STATE._closeCallbacks or {}) do
        local cbOk, cbErr = pcall(cb)
        if not cbOk then warn("[DoD UI] BindToClose callback error: " .. tostring(cbErr)) end
    end
    table.clear(STATE._closeCallbacks or {})
    end)
    STATE._destroying = false
    STATE.Destroyed = true
    if not _ok then warn("[DoD UI] Destroy error: " .. tostring(_err)) end
end


return true
