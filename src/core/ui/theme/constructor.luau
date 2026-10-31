--[[
  LIBRARY CONSTRUCTOR

  Split out of src/core/ui/demon-theme.luau (original lines 873-1217).
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
-- LIBRARY CONSTRUCTOR
-- =========================================================

function Library.new(opts)
    if opts == nil then opts = {}
    elseif type(opts) ~= "table" then
        error("[DoD UI] Library.new expects an options table.")
    end

    -- ANTI DOUBLE EXECUTION
    local _gv = (getgenv and getgenv()) or _G
    if _gv._DoD_ActiveInstances then
        for _, _old in ipairs(_gv._DoD_ActiveInstances) do
            pcall(function() _old:Destroy() end)
        end
        table.clear(_gv._DoD_ActiveInstances)
    else
        _gv._DoD_ActiveInstances = {}
    end
    local oldMain = findInGuiParents("DoD_UI_Main")
    if oldMain then oldMain:Destroy() end
    local oldNotif = findInGuiParents("DoD_UI_Notifications")
    if oldNotif then oldNotif:Destroy() end
    local oldTooltip = findInGuiParents("DoD_UI_Tooltip")
    if oldTooltip then oldTooltip:Destroy() end
    local oldBlur = Lighting:FindFirstChild("DoD_UI_Blur")
    if oldBlur then oldBlur:Destroy() end

    local self = setmetatable({}, Library)
    table.insert(_gv._DoD_ActiveInstances, self)

    self._initialized = false
    self._themeLoading = false
    self._themeSavePending = false

    self.Title       = opts.Title or "Demon of Darkness UI"
    self.Version     = opts.Version or "v1.2"
    self.Author      = opts.Author or "@DemonOfDarkness"
    self.ThemeName   = opts.Theme or "Demon of Darkness"
    -- SetTheme now reports unknown names instead of silently falling back to Dark,
    -- so an invalid opts.Theme is coerced to the default here instead.
    if type(self.ThemeName) ~= "string" or not D.Themes[self.ThemeName] then
        warn("[DoD UI] Unknown theme '" .. tostring(opts.Theme) .. "', using 'Demon of Darkness'")
        self.ThemeName = "Demon of Darkness"
    end
    self.TabPosition = opts.TabPosition or "Top"
    self.TabWidth    = opts.TabWidth or 130
    self.ToggleKey   = opts.ToggleKey or Enum.KeyCode.N
    self._TitleIconName = (type(opts.TitleIcon) == "string" and opts.TitleIcon ~= "")
        and opts.TitleIcon or "hexagon"
        
    self._Sounds = {}
    for name, data in pairs(GuiSound) do
        local s = Instance.new("Sound")
        s.Name = "DoD_Sound_" .. name
        s.SoundId = data.id
        s.PlaybackSpeed = data.pitch
        s.Volume = data.vol
        s.Parent = SoundService
        self._Sounds[name] = s
    end
    self._SoundsEnabled = opts.SoundsEnabled ~= false
    self._SoundVolume = opts.SoundVolume or 1
    self.CategoryAlign = opts.CategoryAlign or "Center"
    if self.CategoryAlign ~= "Center" and self.CategoryAlign ~= "Left" and self.CategoryAlign ~= "Right" then
        self.CategoryAlign = "Center"
    end
    if typeof(self.ToggleKey) ~= "EnumItem" or self.ToggleKey.EnumType ~= Enum.KeyCode then
        error("[DoD UI] ToggleKey must be an Enum.KeyCode.")
    end
    if type(self.TabWidth) ~= "number" or self.TabWidth <= 0
        or self.TabWidth ~= self.TabWidth or self.TabWidth == math.huge then
        error("[DoD UI] TabWidth must be a positive number.")
    end
    if opts.Size ~= nil and typeof(opts.Size) ~= "UDim2" then
        error("[DoD UI] Size must be a UDim2 value.")
    end
    if opts.Acrylic ~= nil and type(opts.Acrylic) ~= "boolean" then
        error("[DoD UI] Acrylic must be a boolean.")
    end
    self.WindowSize = opts.Size or UDim2.fromOffset(750, 500)
    self.WallpaperSource = opts.Wallpaper
    self.WallpaperTransparency = opts.WallpaperTransparency or 0
    -- Opt-in: this "derives" a palette from the URL string (it does not analyse
    -- the image) and then overrides whatever theme the user picked, so it must
    -- not happen by surprise.
    self.AutoTheme = opts.AutoTheme == true
    self.Acrylic = opts.Acrylic ~= false
    self._SmartThemeAutoFix = opts.SmartThemeAutoFix ~= false
    if opts.AcrylicBlur == nil then
        self.AcrylicBlurIntensity = 8
    else
        self.AcrylicBlurIntensity = opts.AcrylicBlur
    end
    if type(self.AcrylicBlurIntensity) ~= "number" or self.AcrylicBlurIntensity < 0
        or self.AcrylicBlurIntensity > 24 or self.AcrylicBlurIntensity ~= self.AcrylicBlurIntensity then
        error("[DoD UI] AcrylicBlur must be a number between 0 and 24.")
    end
    if self.TabPosition ~= "Top" and self.TabPosition ~= "Side" and self.TabPosition ~= "Bottom" then
        error('[DoD UI] TabPosition must be "Top", "Side", or "Bottom".')
    end

    if opts.AccentColor ~= nil and typeof(opts.AccentColor) ~= "Color3" then
        error("[DoD UI] AccentColor must be a Color3 value.")
    end
    if opts.VersionBadgeColor ~= nil and typeof(opts.VersionBadgeColor) ~= "Color3" then
        error("[DoD UI] VersionBadgeColor must be a Color3 value.")
    end
    if opts.SoundsEnabled ~= nil and type(opts.SoundsEnabled) ~= "boolean" then
        error("[DoD UI] SoundsEnabled must be a boolean.")
    end
    if opts.SoundVolume ~= nil and (type(opts.SoundVolume) ~= "number" or opts.SoundVolume < 0 or opts.SoundVolume > 1 or opts.SoundVolume ~= opts.SoundVolume) then
        error("[DoD UI] SoundVolume must be a number between 0 and 1.")
    end
    if opts.ReducedMotion ~= nil and type(opts.ReducedMotion) ~= "boolean" then
        error("[DoD UI] ReducedMotion must be a boolean.")
    end
    if opts.LayoutDensity ~= nil and opts.LayoutDensity ~= "Compact" and opts.LayoutDensity ~= "Normal" and opts.LayoutDensity ~= "Spacious" then
        error("[DoD UI] LayoutDensity must be 'Compact', 'Normal', or 'Spacious'.")
    end
    if opts.SectionTransparency ~= nil and (type(opts.SectionTransparency) ~= "number" or opts.SectionTransparency < 0 or opts.SectionTransparency > 1 or opts.SectionTransparency ~= opts.SectionTransparency) then
        error("[DoD UI] SectionTransparency must be a number between 0 and 1.")
    end
    if opts.NotificationPosition ~= nil and opts.NotificationPosition ~= "TopRight" and opts.NotificationPosition ~= "TopLeft" and opts.NotificationPosition ~= "BottomRight" and opts.NotificationPosition ~= "BottomLeft" then
        error("[DoD UI] NotificationPosition must be 'TopRight', 'TopLeft', 'BottomRight', or 'BottomLeft'.")
    end
    if opts.Tooltip ~= nil and type(opts.Tooltip) ~= "boolean" then
        error("[DoD UI] Tooltip must be a boolean.")
    end
    if opts.TooltipTransparency ~= nil and (type(opts.TooltipTransparency) ~= "number" or opts.TooltipTransparency < 0 or opts.TooltipTransparency > 1 or opts.TooltipTransparency ~= opts.TooltipTransparency) then
        error("[DoD UI] TooltipTransparency must be a number between 0 and 1.")
    end
    if opts.ThemeAutoLoad ~= nil and type(opts.ThemeAutoLoad) ~= "boolean" then
        error("[DoD UI] ThemeAutoLoad must be a boolean.")
    end

    self._UI = {}
    self._isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
    self._perfAuto = opts.AutoPerformance ~= false
    -- Provisional tier only (cheap, no sampling). _detectPerfTier() at the end of
    -- the constructor replaces it with a measured one; the duplicated scoring
    -- block that used to sit here was dead work.
    self._perfTier = self._isMobile and "Balanced" or "High"
    self._perfProfile = D.PerfProfiles[self._perfTier] or D.PerfProfiles.High
    self._CustomColorOverrides = {}
    self._NotifPosition = opts.NotificationPosition or "TopRight"
    self._Colors = table.clone(D.Colors)
    if opts.AccentColor then
        self._AccentOverride = opts.AccentColor
    end
    if opts.VersionBadgeColor then
        self._VersionBadgeOverride = opts.VersionBadgeColor
    end
    if opts.FocusOverlay ~= nil and type(opts.FocusOverlay) ~= "boolean" then
        error("[DoD UI] FocusOverlay must be a boolean.")
    end
    if opts.FocusOverlayType ~= nil and not table.find(D.FocusOverlayTypes, opts.FocusOverlayType) then
        error("[DoD UI] FocusOverlayType must be a supported overlay type.")
    end
    if opts.Weather ~= nil and type(opts.Weather) ~= "table" then
        error("[DoD UI] Weather must be a table.")
    end
    if opts.Weather then
        if opts.Weather.Enabled ~= nil and type(opts.Weather.Enabled) ~= "boolean" then
            error("[DoD UI] Weather.Enabled must be a boolean.")
        end
        if opts.Weather.Type ~= nil and not table.find(D.WeatherTypes, opts.Weather.Type) then
            error("[DoD UI] Weather.Type must be a supported weather type.")
        end
        local intensity = opts.Weather.Intensity
        if intensity ~= nil and (type(intensity) ~= "number" or intensity < 0
            or intensity > 100 or intensity ~= intensity) then
            error("[DoD UI] Weather.Intensity must be a number between 0 and 100.")
        end
    end
    self._STATE = {
        ContentPages        = {},
        CategoryTabs        = {},
        TabColumns          = {}, -- Stores LeftCol, RightCol for each tab
        TabTopContainers    = {}, -- Stores Top container for each tab
        SearchSections      = {},
        SearchBodies        = {},
        SearchTopLevel      = {},
        SearchQuery         = "",
        PageSectionCounts   = {},
        TabCategories       = {},
        ThemeRefreshers     = {},
        activeDropdownPopups = {},
        activeKeybindListeners = {},
        KeybindOverlayRows = {},
        activeNotifs        = {},
        NotifQueue          = {},
        NotifActive         = 0,
        NotifMax            = 3,
        SavedScrollPositions = {},
        GuiVisible          = true,
        AnimatingGui        = false,
        GuiTween            = nil,
        TrackedConns        = {},
        Destroyed           = false,
        ActiveCategory      = nil,
        ActiveTab           = nil,
        WeatherEnabled      = false,
        WeatherType         = (opts.Weather and opts.Weather.Type) or "Snow",
        WeatherIntensity    = (opts.Weather and opts.Weather.Intensity) or 65,
        -- Opt-in: a full-screen dim + a 12px BlurEffect on the whole viewport is
        -- the single most expensive thing this library can do, so it no longer
        -- switches itself on for every user. Enable it from Theme Customizer.
        FocusOverlayEnabled = opts.FocusOverlay == true,
        FocusOverlayType    = opts.FocusOverlayType or "Grid",
        notifParts          = {},
        SnowParticles       = {},
        SnowConnection      = nil,
        WeatherClock        = 0,
        AccordionExpanded   = {},
        ConfigRegistry      = {},
        ConfigCounter       = {},
        ConfigAutoSave      = nil,
        Favorites           = {},
        FavoritesOnly       = false,
        FavoriteHolders     = {},
        LayoutDensity       = opts.LayoutDensity or "Normal",
        ReducedMotion       = false,
        SectionTransparency = opts.SectionTransparency or 0.15,
        ScrollFrames        = {},
        TooltipEnabled      = opts.Tooltip ~= false and not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled),
        TooltipTransparency = opts.TooltipTransparency or 0.15,
        StandaloneTabs      = {},
        _closeCallbacks     = {},
    }

    self:_initNotifications()
    self:_initMainGui()
    self:_initCursorTrail()
    self:_initKeybindOverlay()
    self:_initTitleBar()
    self:_initTrafficLights()
    self:_initSidebar()
    self:_initSearchBar()
    self:_initContentArea()
    self:_applyNavigationLayout()
    self:_initFocusOverlay()
    self:_initMobileToggle()
    self:_initDrag()
    self:_initResize()
    self:_initTooltip()
    self:_bindToggleKey()

    if opts.ReducedMotion == true then
        self:SetReducedMotion(true)
    end
    self:SetTheme(self.ThemeName, true)
    if self.Acrylic then
        self:_updateAcrylicBlur()
    end
    if opts.Weather and opts.Weather.Enabled then
        self:SetWeather(true, self._STATE.WeatherType, self._STATE.WeatherIntensity)
    end

    local _navQueued = false
    Fn.track(self._UI.MainContainer:GetPropertyChangedSignal("AbsoluteSize"), function()
        if _navQueued then return end
        _navQueued = true
        task.defer(function()
            _navQueued = false
            if not self:_isDead() then
                self:_applyNavigationLayout()
            end
        end)
    end, self)

    -- Mouse state will be handled purely by RenderStepped based on hover

    if self.WallpaperSource then
        self:SetWallpaper(self.WallpaperSource, self.WallpaperTransparency)
    end

    local g = (getgenv and getgenv()) or _G
    if g.DoD_LastConfig then
        task.spawn(function()
            task.wait(0.1)
            self:LoadConfig(g.DoD_LastConfig, true)
        end)
    end

    local themeSetters = {
        "SetTheme", "SetAccentColor", "SetAcrylic", "SetAcrylicIntensity",
        "SetReducedMotion", "SetLayoutDensity", "SetSectionTransparency",
        "SetFocusOverlay", "SetWeather", "SetNotificationPosition",
        "SetTooltipEnabled", "SetTooltipTransparency",
        "SetSoundsEnabled", "SetSoundVolume", "SetWallpaper",
        "SetTitleIcon", "SetVersion", "SetVersionBadgeColor",
    }
    for _, mName in ipairs(themeSetters) do
        local orig = self[mName]
        if type(orig) == "function" then
            self[mName] = function(s, ...)
                local result = orig(s, ...)
                s:_triggerThemeSave()
                return result
            end
        end
    end

    self._initialized = true

    if opts.ThemeAutoLoad ~= false then
        -- Honour the last theme the user actually saved/loaded instead of always
        -- reloading "settings" (which made custom-named themes unreachable).
        local _themeGenv = (getgenv and getgenv()) or _G
        local _lastTheme = _themeGenv.DoD_LastTheme
        self:LoadThemeConfig(type(_lastTheme) == "string" and _lastTheme or "settings", true)
    end

    task.defer(function()
        for _ = 1, 100 do
            task.wait(0.05)
            if self:_isDead() then return end
            local p = self._pendingTabRestore
            if not p then return end
            if p.tab and self._STATE.ContentPages[p.tab] then
                self._pendingTabRestore = nil
                pcall(function() self:SwitchTab(p.tab) end)
                return
            end
        end
        self._pendingTabRestore = nil
    end)

    if self._savedPerfTier then
        self:SetPerformanceTier(self._savedPerfTier, true)
    elseif self._perfAuto then
        local _initTier = self:_detectPerfTier()
        self:SetPerformanceTier(_initTier, true)
    else
        -- AutoPerformance = false used to skip applying the profile entirely, so
        -- the UI claimed a tier while acrylic/blur/particles were still all on.
        self:SetPerformanceTier(self._perfTier, true)
    end
    self:_startPerfWatchdog()

    return self
end


return true
