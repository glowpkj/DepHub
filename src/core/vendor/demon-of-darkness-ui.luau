--[[
                        _               _              
  _ __ __ _ _ __  _ __ | |_ ___ _______| |_ _   _  ___ 
 | '__/ _` | '_ \| '_ \| __/ _ \_  / _ \ __| | | |/ _ \
 | | | (_| | |_) | |_) | ||  __// /  __/ |_| |_| |  __/
 |_|  \__,_| .__/| .__/ \__\___/___\___|\__|\__, |\___|
           |_|   |_|                        |___/      

		   discord.gg/rapptezetyee
			t.me/HGithub


]]

-- Usage (chainable):
-- local UI = Library.CreateWindow({ Title = "..." })
-- local Tab = UI:CreateTab("Combat")
-- local Sec = Tab:CreateSection("Aimbot", "Settings", true, "Left", "target")
-- Sec:AddToggle("Enabled", false, function(v) end)
-- Sec:AddChipBar("Mode", {"LEGIT","RAGE","BLATANT"}, 1, function(i,v) end)
-- Classic style (still works): UI:AddToggle(Sec, "Enabled", false, cb)

local Library = {}
Library.__index = Library

-- Load Icons Library (Footagesus/Icons)
local IconsV2
local _iconsOk, _iconsErr = pcall(function()
    IconsV2 = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"))()
    IconsV2.SetIconsType("lucide")
end)
-- Surface the failure instead of silently degrading every icon to the fallback
-- set with no diagnostic.
if not _iconsOk or not IconsV2 then
    warn("[DoD UI] Icon pack unavailable (" .. tostring(_iconsErr) .. "), using built-in fallbacks")
    IconsV2 = nil
end

local _IconCache = {}
local _FallbackIcons = {
    ["search"] = "rbxassetid://7733765398",
    ["x"] = "rbxassetid://7734068321",
    ["check"] = "rbxassetid://7733954901",
    ["check-circle"] = "rbxassetid://7733954901",
    ["x-circle"] = "rbxassetid://7734068321",
    ["info"] = "rbxassetid://7734014847",
    ["alert-triangle"] = "rbxassetid://7734057721",
    ["star"] = "rbxassetid://7734060101",
    ["heart"] = "rbxassetid://7733994238",
    ["settings"] = "rbxassetid://7734065547",
    ["trash-2"] = "rbxassetid://7734086474",
    ["copy"] = "rbxassetid://7734038559",
    ["clipboard-paste"] = "rbxassetid://7734013510",
    ["refresh-cw"] = "rbxassetid://7734052500",
    ["chevron-down"] = "rbxassetid://7733998010",
    ["chevron-up"] = "rbxassetid://7733998010",
    ["chevrons-up"] = "rbxassetid://7734020531",
    ["chevrons-down"] = "rbxassetid://7734020531",
    ["arrow-up"] = "rbxassetid://7733988022",
    ["arrow-down"] = "rbxassetid://7733988022",
    ["keyboard"] = "rbxassetid://7734003090",
    ["command"] = "rbxassetid://7734007240",
    ["mouse-pointer-2"] = "rbxassetid://7734057332",
    ["panel-top"] = "rbxassetid://7734054207",
    ["move-diagonal"] = "rbxassetid://7734028058",
    ["loader"] = "rbxassetid://7734028058",
    ["hexagon"] = "rbxassetid://7734005169",
    ["shield"] = "rbxassetid://7734069485",
    ["user"] = "rbxassetid://7734082053",
    ["users"] = "rbxassetid://7734082113",
    ["wifi"] = "rbxassetid://7734083361",
    ["zap"] = "rbxassetid://7734088669",
    ["activity"] = "rbxassetid://7733951517",
    ["server"] = "rbxassetid://7734061229",
    ["message-circle"] = "rbxassetid://7734037126",
    ["file-clock"] = "rbxassetid://7733991600",
    ["id-card"] = "rbxassetid://7734003090",
    ["house"] = "rbxassetid://7734054207",
    ["monitor"] = "rbxassetid://7733951517",
    ["play"] = "rbxassetid://7734088669",
    ["file"] = "rbxassetid://7733991600",
    ["sword"] = "rbxassetid://7734069485",
    ["crosshair"] = "rbxassetid://7734057332",
    ["target"] = "rbxassetid://7734057332",
    ["mouse-pointer"] = "rbxassetid://7734057332",
    ["volume-2"] = "rbxassetid://7734037126",
    ["palette"] = "rbxassetid://7734060101",
    ["shield-check"] = "rbxassetid://7734069485",
    ["eye-off"] = "rbxassetid://7734068321",
    ["radar"] = "rbxassetid://7733951517",
    ["save"] = "rbxassetid://7734038559",
    ["code"] = "rbxassetid://7733991600",
    ["move"] = "rbxassetid://7734028058",
    ["cpu"] = "rbxassetid://7734005169",
}

local function GetIcon(name)
    name = tostring(name or "")
    local cached = _IconCache[name]
    if cached then return cached end
    if IconsV2 then
        local ok, icon = pcall(function() return IconsV2.GetIcon(name) end)
        if ok and icon then
            _IconCache[name] = icon
            return icon
        end
    end
    local fallback = _FallbackIcons[name] or _FallbackIcons[name:lower()] or "rbxassetid://6031075931"
    _IconCache[name] = fallback
    return fallback
end

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Stats              = game:GetService("Stats")
local UserInputService   = game:GetService("UserInputService")
local _ReducedMotion     = false
local _RealTweenService  = game:GetService("TweenService")
local TweenService = {
    Create = function(_, obj, info, props)
        if _ReducedMotion and info then
            -- Also drop RepeatCount/DelayTime: an infinitely repeating or delayed
            -- tween kept waiting forever and never fired Completed.
            info = TweenInfo.new(0, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0)
        end
        return _RealTweenService:Create(obj, info, props)
    end,
}
local CoreGui            = game:GetService("CoreGui")
local Lighting           = game:GetService("Lighting")
local SoundService       = game:GetService("SoundService")
local LocalPlayer        = Players.LocalPlayer

local function getCam() return workspace.CurrentCamera end

-- CoreGui is protected for some executors; fall back to gethui() (the standard
-- hidden-GUI API) and finally to PlayerGui instead of erroring out of the whole
-- constructor.
local function GetGuiParent()
    local ok, hidden = pcall(function()
        if gethui then return gethui() end
        if get_hidden_gui then return get_hidden_gui() end
        return nil
    end)
    if ok and hidden then return hidden end
    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and core then
        local probeOk = pcall(function() return core.Name end)
        if probeOk then return core end
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local GuiParent = GetGuiParent()

local function findInGuiParents(name)
    local found = GuiParent and GuiParent:FindFirstChild(name)
    if found then return found end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core and core ~= GuiParent then
        return core:FindFirstChild(name)
    end
    return nil
end

local GuiSound = {
    Click     = { id = "rbxassetid://6895079853", pitch = 1.10, vol = 0.45 },
    ToggleOn  = { id = "rbxassetid://6895079853", pitch = 1.40, vol = 0.50 },
    ToggleOff = { id = "rbxassetid://6895079853", pitch = 0.88, vol = 0.40 },
    TabSwitch = { id = "rbxassetid://6895079853", pitch = 1.25, vol = 0.40 },
    Dropdown  = { id = "rbxassetid://6895079853", pitch = 1.00, vol = 0.40 },
    Notify    = { id = "rbxassetid://4590662766", pitch = 1.35, vol = 0.55 },
    Hover     = { id = "rbxassetid://6895079853", pitch = 1.80, vol = 0.12 },
    Scroll    = { id = "rbxassetid://6895079853", pitch = 1.55, vol = 0.10 }
}

-- =========================================================
-- SHARED STATE / UTILITIES
-- =========================================================

local Fn = {}
local D  = {}

Fn.track = function(signal, callback, owner)
    if not owner or not owner._STATE or not owner._STATE.TrackedConns then
        error("[DoD UI] Tracked connections require a library owner.")
    end
    local conn = signal:Connect(callback)
    -- A tracked connection created by a deferred thread after Destroy() would be
    -- appended to a table that has already been drained and never disconnected.
    if owner._STATE.Destroyed or owner._STATE._destroying then
        pcall(function() conn:Disconnect() end)
        return conn
    end
    table.insert(owner._STATE.TrackedConns, conn)
    return conn
end

Fn.disconnectAll = function(owner)
    local connections = owner._STATE.TrackedConns
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
end

Fn.untrack = function(connection, owner)
    local connections = owner._STATE.TrackedConns
    local index = table.find(connections, connection)
    if index then table.remove(connections, index) end
    connection:Disconnect()
end

Fn.bindPressAnimation = function(guiObject)
    local scale = guiObject:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale", guiObject)
        scale.Scale = 1
    end
    local baseScale = scale.Scale
    local activeTween

    local function animate(factor)
        if activeTween then activeTween:Cancel() end
        activeTween = TweenService:Create(
            scale,
            TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Scale = baseScale * factor}
        )
        activeTween:Play()
    end

    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            animate(0.96)
        end
    end)
    guiObject.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            animate(1)
        end
    end)
    guiObject.MouseLeave:Connect(function()
        animate(1)
    end)
    return scale
end

Fn.accentTextColor = function(color)
    local function lin(c)
        if c <= 0.04045 then return c / 12.92 end
        return ((c + 0.055) / 1.055) ^ 2.4
    end
    local lum = 0.2126 * lin(color.R) + 0.7152 * lin(color.G) + 0.0722 * lin(color.B)
    return lum > 0.179 and Color3.fromRGB(20, 22, 28) or Color3.fromRGB(255, 255, 255)
end

Fn.luminance = function(color)
    local function lin(c)
        if c <= 0.04045 then return c / 12.92 end
        return ((c + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * lin(color.R) + 0.7152 * lin(color.G) + 0.0722 * lin(color.B)
end

Fn.contrastRatio = function(a, b)
    local la = Fn.luminance(a)
    local lb = Fn.luminance(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

Fn.contrastForeground = function(bg)
    if typeof(bg) ~= "Color3" then return Color3.fromRGB(255, 255, 255) end
    return Fn.luminance(bg) > 0.179 and Color3.fromRGB(20, 22, 28) or Color3.fromRGB(255, 255, 255)
end

Fn.visibleAccent = function(accent, bg, minRatio)
    if not accent or not bg then return accent end
    minRatio = minRatio or 3
    if Fn.contrastRatio(accent, bg) >= minRatio then return accent end
    local h, s, v = accent:ToHSV()
    local candidates = {
        Color3.fromHSV(h, s * 0.85, math.min(1, v + 0.15)),
        Color3.fromHSV(h, s * 0.70, math.min(1, v + 0.30)),
        Color3.fromHSV(h, s * 0.50, math.min(1, v + 0.45)),
        Color3.fromHSV(h, s, math.max(0, v - 0.15)),
        Color3.fromHSV(h, s, math.max(0, v - 0.30)),
        Color3.fromHSV(h, s, math.max(0, v - 0.45)),
    }
    local best = accent
    local bestRatio = Fn.contrastRatio(accent, bg)
    for _, c in ipairs(candidates) do
        local r = Fn.contrastRatio(c, bg)
        if r >= minRatio then return c end
        if r > bestRatio then bestRatio = r; best = c end
    end
    return best
end

-- =========================================================
-- THEMES (20 presets)
-- =========================================================

D.Themes = {
    Dark = {
        Accent = Color3.fromRGB(180, 180, 195),
        Accent2 = Color3.fromRGB(100, 100, 120),
        FocusOverlayColor = Color3.fromRGB(2, 2, 5),
        Bg = Color3.fromRGB(8, 8, 12),
        Bg2 = Color3.fromRGB(14, 14, 20),
        Card = Color3.fromRGB(20, 20, 28),
        Sidebar = Color3.fromRGB(10, 10, 15),
        Border = Color3.fromRGB(40, 40, 50),
        Text = Color3.fromRGB(220, 220, 230),
        TextDim = Color3.fromRGB(140, 140, 155),
        OverlayTransparency = 0.38,
    },
    Indigo = {
        Accent = Color3.fromRGB(99, 102, 241),
        Accent2 = Color3.fromRGB(139, 92, 246),
        OverlayColor = Color3.fromRGB(10, 9, 27),
        OverlayTransparency = 0.44,
    },
    Red = {
        Accent = Color3.fromRGB(248, 113, 113),
        Accent2 = Color3.fromRGB(239, 68, 68),
        OverlayColor = Color3.fromRGB(25, 8, 10),
        OverlayTransparency = 0.42,
    },
    Green = {
        Accent = Color3.fromRGB(52, 211, 153),
        Accent2 = Color3.fromRGB(16, 185, 129),
        OverlayColor = Color3.fromRGB(5, 22, 18),
        OverlayTransparency = 0.42,
    },
    Purple = {
        Accent = Color3.fromRGB(168, 85, 247),
        Accent2 = Color3.fromRGB(192, 38, 211),
        OverlayColor = Color3.fromRGB(15, 8, 24),
        OverlayTransparency = 0.44,
    },
    Orange = {
        Accent = Color3.fromRGB(251, 146, 60),
        Accent2 = Color3.fromRGB(249, 115, 22),
        OverlayColor = Color3.fromRGB(26, 14, 7),
        OverlayTransparency = 0.42,
    },
    Christmas = {
        Accent = Color3.fromRGB(220, 40, 40),
        Accent2 = Color3.fromRGB(30, 150, 70),
        FocusOverlayColor = Color3.fromRGB(20, 40, 25),
        Bg = Color3.fromRGB(18, 22, 20),
        Bg2 = Color3.fromRGB(25, 32, 28),
        Card = Color3.fromRGB(35, 45, 40),
        Sidebar = Color3.fromRGB(15, 20, 18),
        Border = Color3.fromRGB(80, 50, 50),
        Text = Color3.fromRGB(245, 245, 240),
        TextDim = Color3.fromRGB(200, 170, 170),
        GridColor = Color3.fromRGB(30, 150, 70),
        GridAltColor = Color3.fromRGB(220, 40, 40),
        OverlayTransparency = 0.4,
    },
    Ocean = {
        Accent = Color3.fromRGB(45, 170, 205),
        Accent2 = Color3.fromRGB(32, 112, 175),
        OverlayColor = Color3.fromRGB(5, 18, 28),
        OverlayTransparency = 0.42,
    },
    Rose = {
        Accent = Color3.fromRGB(244, 114, 182),
        Accent2 = Color3.fromRGB(219, 39, 119),
        OverlayColor = Color3.fromRGB(27, 8, 20),
        OverlayTransparency = 0.42,
    },
    Forest = {
        Accent = Color3.fromRGB(132, 184, 96),
        Accent2 = Color3.fromRGB(65, 135, 82),
        OverlayColor = Color3.fromRGB(12, 22, 10),
        OverlayTransparency = 0.42,
    },
    Sunset = {
        Accent = Color3.fromRGB(247, 135, 83),
        Accent2 = Color3.fromRGB(221, 83, 92),
        OverlayColor = Color3.fromRGB(27, 11, 10),
        OverlayTransparency = 0.42,
    },
    Arctic = {
        Accent = Color3.fromRGB(125, 211, 252),
        Accent2 = Color3.fromRGB(147, 197, 253),
        OverlayColor = Color3.fromRGB(8, 19, 30),
        OverlayTransparency = 0.46,
    },
    Gold = {
        Accent = Color3.fromRGB(234, 179, 8),
        Accent2 = Color3.fromRGB(202, 138, 4),
        OverlayColor = Color3.fromRGB(27, 20, 5),
        OverlayTransparency = 0.42,
    },
    Midnight = {
        Accent = Color3.fromRGB(90, 150, 255),
        Accent2 = Color3.fromRGB(50, 200, 255),
        FocusOverlayColor = Color3.fromRGB(5, 10, 30),
        Bg = Color3.fromRGB(8, 10, 22),
        Bg2 = Color3.fromRGB(14, 18, 35),
        Card = Color3.fromRGB(20, 26, 48),
        Sidebar = Color3.fromRGB(6, 8, 18),
        Border = Color3.fromRGB(40, 55, 90),
    },
    Cyberpunk = {
        Accent = Color3.fromRGB(255, 20, 150),
        Accent2 = Color3.fromRGB(0, 240, 255),
        FocusOverlayColor = Color3.fromRGB(30, 5, 40),
        Bg = Color3.fromRGB(15, 5, 25),
        Bg2 = Color3.fromRGB(25, 10, 40),
        Card = Color3.fromRGB(35, 15, 55),
        Sidebar = Color3.fromRGB(12, 3, 20),
        Border = Color3.fromRGB(100, 30, 150),
    },
    Monochrome = {
        Accent = Color3.fromRGB(230, 230, 230),
        Accent2 = Color3.fromRGB(150, 150, 150),
        FocusOverlayColor = Color3.fromRGB(10, 10, 10),
        Bg = Color3.fromRGB(12, 12, 12),
        Bg2 = Color3.fromRGB(20, 20, 20),
        Card = Color3.fromRGB(30, 30, 30),
        Sidebar = Color3.fromRGB(8, 8, 8),
        Border = Color3.fromRGB(60, 60, 60),
    },
    Neon = {
        Accent = Color3.fromRGB(60, 255, 130),
        Accent2 = Color3.fromRGB(200, 255, 60),
        FocusOverlayColor = Color3.fromRGB(5, 30, 15),
        Bg = Color3.fromRGB(6, 15, 10),
        Bg2 = Color3.fromRGB(12, 25, 18),
        Card = Color3.fromRGB(20, 40, 28),
        Sidebar = Color3.fromRGB(4, 10, 6),
        Border = Color3.fromRGB(40, 100, 60),
    },
    BloodMoon = {
        Accent = Color3.fromRGB(200, 20, 40),
        Accent2 = Color3.fromRGB(255, 90, 20),
        FocusOverlayColor = Color3.fromRGB(40, 5, 10),
        Bg = Color3.fromRGB(15, 5, 8),
        Bg2 = Color3.fromRGB(25, 8, 12),
        Card = Color3.fromRGB(40, 12, 20),
        Sidebar = Color3.fromRGB(10, 3, 5),
        Border = Color3.fromRGB(80, 20, 30),
    },
    Ice = {
        Accent = Color3.fromRGB(180, 230, 255),
        Accent2 = Color3.fromRGB(100, 190, 255),
        FocusOverlayColor = Color3.fromRGB(10, 25, 45),
        Bg = Color3.fromRGB(12, 20, 30),
        Bg2 = Color3.fromRGB(20, 30, 45),
        Card = Color3.fromRGB(32, 48, 68),
        Sidebar = Color3.fromRGB(8, 15, 22),
        Border = Color3.fromRGB(60, 100, 140),
    },
    ["Demon of Darkness"] = {
        Accent = Color3.fromRGB(200, 20, 40),
        Accent2 = Color3.fromRGB(150, 24, 16),
        FocusOverlayColor = Color3.fromRGB(32, 3, 8),
        OverlayColor = Color3.fromRGB(24, 2, 6),
        OverlayTransparency = 0.34,
        Bg = Color3.fromRGB(5, 4, 6),
        Bg2 = Color3.fromRGB(13, 7, 9),
        Card = Color3.fromRGB(22, 10, 13),
        CardHover = Color3.fromRGB(34, 12, 17),
        Sidebar = Color3.fromRGB(8, 5, 7),
        Border = Color3.fromRGB(78, 18, 27),
        Text = Color3.fromRGB(244, 232, 234),
        TextDim = Color3.fromRGB(170, 133, 140),
    },
}

D.ThemeNames = {
    "Dark", "Indigo", "Red", "Green", "Purple", "Orange", "Christmas",
    "Ocean", "Rose", "Forest", "Sunset", "Arctic", "Gold", "Midnight", "Demon of Darkness",
    "Cyberpunk", "Monochrome", "Neon", "BloodMoon", "Ice",
}

D.Colors = {
    Accent    = Color3.fromRGB(180, 180, 195),
    Accent2   = Color3.fromRGB(100, 100, 120),
    Bg        = Color3.fromRGB(8, 8, 12),
    Bg2       = Color3.fromRGB(14, 14, 20),
    Card      = Color3.fromRGB(20, 20, 28),
    CardHover = Color3.fromRGB(30, 30, 40),
    Text      = Color3.fromRGB(220, 220, 230),
    TextDim   = Color3.fromRGB(140, 140, 155),
    Sidebar   = Color3.fromRGB(10, 10, 15),
    Border    = Color3.fromRGB(40, 40, 50),
    Green     = Color3.fromRGB(52, 211, 153),
    Red       = Color3.fromRGB(248, 113, 113),
}

D.FocusOverlayTypes = {
    "None", "Grid", "Dots", "Diagonal", "Crosshatch", "Radial",
    "Scanlines", "Bricks", "Concentric", "Stars", "Plus", "Zigzag",
    "Matrix", "Waves"
}
D.PerfProfiles = {
    Potato = {
        Acrylic = false, AcrylicBlurIntensity = 0,
        FocusOverlayEnabled = false, FocusOverlayType = "None",
        WeatherEnabled = false, WeatherIntensity = 0,
        ReducedMotion = true, LayoutDensity = "Compact",
        CursorTrail = false, ParticleBG = false, CustomCursor = false,
        SectionTransparency = 0.02,
        WeatherParticleCap = 0,
        PatternScale = 0.25,
    },
    Balanced = {
        Acrylic = true, AcrylicBlurIntensity = 4,
        FocusOverlayEnabled = true, FocusOverlayType = "Grid",
        WeatherEnabled = true, WeatherIntensity = 40,
        ReducedMotion = false, LayoutDensity = "Normal",
        CursorTrail = true, ParticleBG = true, CustomCursor = true,
        SectionTransparency = 0.15,
        WeatherParticleCap = 55,
        PatternScale = 0.6,
    },
    High = {
        Acrylic = true, AcrylicBlurIntensity = 8,
        FocusOverlayEnabled = true, FocusOverlayType = "Grid",
        WeatherEnabled = true, WeatherIntensity = 65,
        ReducedMotion = false, LayoutDensity = "Normal",
        CursorTrail = true, ParticleBG = true, CustomCursor = true,
        SectionTransparency = 0.15,
        WeatherParticleCap = 200,
        PatternScale = 1.0,
    },
}
D.WeatherTypes = {
    "Snow", "Rain", "Leaves", "Stars", "Bubbles",
    "Petals", "Embers", "Fireflies", "Mist", "Aurora",
}

-- =========================================================
-- WEATHER PRESETS
-- =========================================================

local WEATHER_PRESETS = {
    Snow = {
        count = 80, minSize = 1.5, maxSize = 4.5,
        color = Color3.fromRGB(255, 255, 255),
        transMin = 40, transMax = 60,
        speedMin = 10, speedMax = 18,
        driftMin = -5, driftMax = 5,
        shape = "Circle", sway = 0.012,
        rotationMin = -12, rotationMax = 12, zIndex = 1,
    },
    Rain = {
        count = 50, minSize = 2, maxSize = 3,
        color = Color3.fromRGB(150, 200, 255),
        transMin = 40, transMax = 70,
        speedMin = 80, speedMax = 120,
        driftMin = -2, driftMax = 2,
        shape = "Line", rotationMin = -8, rotationMax = 8, zIndex = 1,
    },
    Leaves = {
        count = 20, minSize = 6, maxSize = 12,
        colors = { Color3.fromRGB(205,112,52), Color3.fromRGB(185,75,42), Color3.fromRGB(222,165,65) },
        transMin = 20, transMax = 50,
        speedMin = 8, speedMax = 15,
        driftMin = -10, driftMax = 10,
        shape = "Leaf", sway = 0.035,
        rotationMin = -90, rotationMax = 90,
        rotationSpeedMin = -55, rotationSpeedMax = 55, zIndex = 1,
    },
    Stars = {
        count = 40, minSize = 2, maxSize = 4,
        color = Color3.fromRGB(255, 240, 150),
        transMin = 10, transMax = 40,
        speedMin = 0, speedMax = 0.5,
        driftMin = -0.5, driftMax = 0.5,
        shape = "Circle", zIndex = 1, twinkle = true,
    },
    Bubbles = {
        count = 25, minSize = 4, maxSize = 10,
        color = Color3.fromRGB(150, 220, 255),
        transMin = 30, transMax = 60,
        speedMin = -10, speedMax = -20,
        driftMin = -4, driftMax = 4,
        shape = "Circle", sway = 0.012, zIndex = 1,
    },
    Petals = {
        count = 36, minSize = 4, maxSize = 8,
        colors = { Color3.fromRGB(255,176,198), Color3.fromRGB(255,220,230), Color3.fromRGB(245,145,177) },
        transMin = 22, transMax = 48,
        speedMin = 7, speedMax = 16,
        driftMin = -12, driftMax = 12,
        shape = "Leaf", sway = 0.03,
        rotationMin = -180, rotationMax = 180,
        rotationSpeedMin = -70, rotationSpeedMax = 70, zIndex = 1,
    },
    Embers = {
        count = 42, minSize = 2, maxSize = 5,
        colors = { Color3.fromRGB(255,92,36), Color3.fromRGB(255,156,45), Color3.fromRGB(255,214,92) },
        transMin = 18, transMax = 48,
        speedMin = -28, speedMax = -10,
        driftMin = -9, driftMax = 9,
        shape = "Glow", sway = 0.012, twinkle = true,
        rotationSpeedMin = -25, rotationSpeedMax = 25, zIndex = 1,
    },
    Fireflies = {
        count = 24, minSize = 3, maxSize = 7,
        colors = { Color3.fromRGB(182,255,128), Color3.fromRGB(255,230,112), Color3.fromRGB(128,240,190) },
        transMin = 30, transMax = 65,
        speedMin = -3, speedMax = 3,
        driftMin = -5, driftMax = 5,
        shape = "Glow", sway = 0.02, twinkle = true, zIndex = 1,
    },
    Mist = {
        count = 8, minSize = 90, maxSize = 190,
        colors = { Color3.fromRGB(168,198,210), Color3.fromRGB(196,184,214), Color3.fromRGB(152,202,190) },
        transMin = 82, transMax = 92,
        speedMin = -1.5, speedMax = 1.5,
        driftMin = 1, driftMax = 4,
        shape = "Mist", sway = 0.025, zIndex = 1,
    },
    Aurora = {
        count = 5, minSize = 0.18, maxSize = 0.38,
        colors = { Color3.fromRGB(70,235,190), Color3.fromRGB(100,160,255), Color3.fromRGB(190,115,240) },
        transMin = 84, transMax = 92,
        speedMin = -1, speedMax = 1,
        driftMin = 1, driftMax = 3,
        shape = "Aurora", sway = 0.035,
        rotationMin = -8, rotationMax = 8, zIndex = 1,
    },
}

local function randomFloat(minV, maxV)
    if minV > maxV then minV, maxV = maxV, minV end
    return minV + (maxV - minV) * math.random()
end

-- =========================================================
-- SUB-TAB MODULE
-- =========================================================

local SubTabModule = {}
SubTabModule.__index = SubTabModule

local SUBTAB_DEFAULT_THEME = {
    PillBg       = Color3.fromRGB(34, 34, 44),
    LeftAccent   = Color3.fromRGB(160, 160, 185),
    TextActive   = Color3.fromRGB(255, 255, 255),
    TextInactive = Color3.fromRGB(130, 130, 145),
    FontActive   = Enum.Font.GothamBold,
    FontInactive = Enum.Font.GothamMedium,
}

function SubTabModule.new(config)
    local self = setmetatable({}, SubTabModule)
    self.Parent = config.Parent
    self.Owner = config.Owner
    self.Data = config.Data or {}
    self.OnChanged = config.OnChanged or function() end
    self.Theme = config.Theme or SUBTAB_DEFAULT_THEME
    self.CurrentMainCategory = nil
    self.ActiveSubIndices = {}
    self.Groups = {}
    self.TabWidth = config.TabWidth or 96
    self.TabHeight = config.TabHeight or 28
    self.Padding = config.Padding or 6
    self:_init()
    return self
end

function SubTabModule:_init()
    self.Wrapper = Instance.new("Frame", self.Parent)
    self.Wrapper.Name = "SubTabWrapper"
    self.Wrapper.Size = UDim2.new(1, 0, 1, 0)
    self.Wrapper.BackgroundTransparency = 1
    for mainCategory, subList in pairs(self.Data) do
        self:_createSubGroup(mainCategory, subList)
    end
end

function SubTabModule:_createSubGroup(mainCategory, subList)
    local group = Instance.new("CanvasGroup", self.Wrapper)
    group.Name = "SubGroup_" .. tostring(mainCategory)
    group.Size = UDim2.new(1, 0, 1, 0)
    group.BackgroundTransparency = 1
    group.GroupTransparency = 1
    group.Visible = false

    local indicator = Instance.new("Frame", group)
    indicator.Name = "SlidingIndicator"
    indicator.Size = UDim2.new(0, self.TabWidth, 0, self.TabHeight)
    indicator.Position = UDim2.new(0, 0, 0.5, -self.TabHeight / 2)
    indicator.BackgroundColor3 = self.Theme.PillBg
    indicator.BorderSizePixel = 0
    indicator.ZIndex = 1
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 6)

    local accentLine = Instance.new("Frame", indicator)
    accentLine.Name = "LeftAccentBar"
    accentLine.Size = UDim2.new(0, 3, 0, 12)
    accentLine.Position = UDim2.new(0, 6, 0.5, -6)
    accentLine.BackgroundColor3 = self.Theme.LeftAccent
    accentLine.BorderSizePixel = 0
    Instance.new("UICorner", accentLine).CornerRadius = UDim.new(1, 0)

    local subElements = {}
    self.ActiveSubIndices[mainCategory] = 1

    for i, subName in ipairs(subList) do
        local btn = Instance.new("TextButton", group)
        btn.Name = "SubBtn_" .. tostring(subName)
        btn.Size = UDim2.new(0, self.TabWidth, 0, self.TabHeight)
        btn.Position = UDim2.new(0, (i - 1) * (self.TabWidth + self.Padding), 0.5, -self.TabHeight / 2)
        btn.BackgroundTransparency = 1
        btn.Text = tostring(subName)
        btn.TextColor3 = (i == 1) and self.Theme.TextActive or self.Theme.TextInactive
        btn.Font = (i == 1) and self.Theme.FontActive or self.Theme.FontInactive
        btn.TextSize = 12
        btn.TextTruncate = Enum.TextTruncate.AtEnd
        btn.AutoButtonColor = false
        btn.ZIndex = 2
        subElements[i] = btn
        Fn.bindPressAnimation(btn)

        btn.MouseEnter:Connect(function()
            if self.Owner then self.Owner:PlaySound("Hover") end
            if self.ActiveSubIndices[mainCategory] ~= i then
                TweenService:Create(btn, TweenInfo.new(0.18), {
                    TextColor3 = self.Theme.TextActive or Color3.fromRGB(255, 255, 255)
                }):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if self.ActiveSubIndices[mainCategory] ~= i then
                TweenService:Create(btn, TweenInfo.new(0.18), {TextColor3 = self.Theme.TextInactive}):Play()
            end
        end)

        btn.MouseButton1Click:Connect(function()
            local currentActiveIdx = self.ActiveSubIndices[mainCategory]
            if currentActiveIdx == i then return end
            if self.Owner then self.Owner:PlaySound("TabSwitch") end
            local prevBtn = subElements[currentActiveIdx]
            self.ActiveSubIndices[mainCategory] = i
            local targetX = (i - 1) * (self.TabWidth + self.Padding)
            TweenService:Create(indicator, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, targetX, 0.5, -self.TabHeight / 2)
            }):Play()
            if prevBtn then
                TweenService:Create(prevBtn, TweenInfo.new(0.18), {TextColor3 = self.Theme.TextInactive}):Play()
                prevBtn.Font = self.Theme.FontInactive
            end
            TweenService:Create(btn, TweenInfo.new(0.18), {TextColor3 = self.Theme.TextActive}):Play()
            btn.Font = self.Theme.FontActive
            self.OnChanged(mainCategory, subName)
        end)
    end

    self.Groups[mainCategory] = {
        Group = group,
        Indicator = indicator,
        Buttons = subElements,
    }
end

function SubTabModule:SwitchCategory(newCategory)
    if self.CurrentMainCategory == newCategory then return end
    if not self.Groups[newCategory] then return end
    local oldCategory = self.CurrentMainCategory
    self.CurrentMainCategory = newCategory
    if oldCategory and self.Groups[oldCategory] then
        local oldGroup = self.Groups[oldCategory].Group
        self._switchToken = {}
        local token = self._switchToken
        TweenService:Create(oldGroup, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            GroupTransparency = 1
        }):Play()
        task.delay(0.15, function()
            -- Guard against A->B->A within 150ms hiding the group that is now active.
            if self._switchToken ~= token then return end
            if self.CurrentMainCategory ~= oldCategory then
                oldGroup.Visible = false
            end
        end)
    end
    local newGroupData = self.Groups[newCategory]
    local newGroup = newGroupData.Group
    newGroup.Visible = true
    newGroup.GroupTransparency = 1
    TweenService:Create(newGroup, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        GroupTransparency = 0
    }):Play()
    local activeSubIdx = self.ActiveSubIndices[newCategory] or 1
    local activeSubName = self.Data[newCategory] and self.Data[newCategory][activeSubIdx]
    if activeSubName then self.OnChanged(newCategory, activeSubName) end
end

function SubTabModule:SetActiveSub(category, subName)
    local group = self.Groups[category]
    if not group then return end
    for i, btn in ipairs(group.Buttons) do
        if btn.Text == tostring(subName) then
            local prev = self.ActiveSubIndices[category]
            if prev == i then return end
            self.ActiveSubIndices[category] = i
            if group.Buttons[prev] then
                TweenService:Create(group.Buttons[prev], TweenInfo.new(0.18), {
                    TextColor3 = self.Theme.TextInactive
                }):Play()
                group.Buttons[prev].Font = self.Theme.FontInactive
            end
            TweenService:Create(btn, TweenInfo.new(0.18), {
                TextColor3 = self.Theme.TextActive
            }):Play()
            btn.Font = self.Theme.FontActive
            TweenService:Create(group.Indicator, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, (i - 1) * (self.TabWidth + self.Padding), 0.5, -self.TabHeight / 2)
            }):Play()
            return
        end
    end
end

function SubTabModule:Resize(tabWidth, padding)
    if tabWidth <= 0 then return end
    self.TabWidth = tabWidth
    if padding then self.Padding = padding end
    for category, groupData in pairs(self.Groups) do
        groupData.Indicator.Size = UDim2.new(0, tabWidth, 0, self.TabHeight)
        for index, button in ipairs(groupData.Buttons) do
            button.Size = UDim2.new(0, tabWidth, 0, self.TabHeight)
            button.Position = UDim2.new(0, (index - 1) * (tabWidth + self.Padding), 0.5, -self.TabHeight / 2)
        end
        local activeIndex = self.ActiveSubIndices[category] or 1
        groupData.Indicator.Position = UDim2.new(
            0, (activeIndex - 1) * (tabWidth + self.Padding), 0.5, -self.TabHeight / 2
        )
    end
end

function SubTabModule:RefreshTheme(newTheme)
    if newTheme then self.Theme = newTheme end
    for cat, groupData in pairs(self.Groups) do
        groupData.Indicator.BackgroundColor3 = self.Theme.PillBg
        local accent = groupData.Indicator:FindFirstChild("LeftAccentBar")
        if accent then accent.BackgroundColor3 = self.Theme.LeftAccent end
        for i, btn in ipairs(groupData.Buttons) do
            if self.ActiveSubIndices[cat] == i then
                btn.TextColor3 = self.Theme.TextActive
                btn.Font = self.Theme.FontActive
            else
                btn.TextColor3 = self.Theme.TextInactive
                btn.Font = self.Theme.FontInactive
            end
        end
    end
end

function SubTabModule:Destroy()
    if self.Wrapper then
        self.Wrapper:Destroy()
        self.Wrapper = nil
    end
    table.clear(self.Groups)
    table.clear(self.ActiveSubIndices)
    self.CurrentMainCategory = nil
end

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
    self.ToggleKey   = opts.ToggleKey or Enum.KeyCode.RightShift
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
    _ReducedMotion = enabled and true or false
    self._STATE.ReducedMotion = _ReducedMotion
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

-- =========================================================
-- NOTIFICATIONS
-- =========================================================

function Library:_initNotifications()
    local gui = Instance.new("ScreenGui")
    gui.Name = "DoD_UI_Notifications"
    gui.Parent = GuiParent
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 2000
    self._UI.NotifGui = gui
end

function Library:SetNotificationPosition(pos)
    if self:_isDead() then return end
    self._NotifPosition = tostring(pos or "TopRight")
    self:_updateNotifPositions()
end

function Library:SetFavoritesOnly(enabled)
    if self:_isDead() then return end
    self._STATE.FavoritesOnly = enabled and true or false
    local icon = self._UI.FavoritesToggleIcon
    if icon then
        TweenService:Create(icon, TweenInfo.new(0.15), {
            ImageColor3 = self._STATE.FavoritesOnly and self._Colors.Accent or self._Colors.TextDim,
            ImageTransparency = self._STATE.FavoritesOnly and 0 or 0.4,
        }):Play()
    end
    if self._STATE.FavoritesOnly then
        local count = 0
        for _ in pairs(self._STATE.Favorites or {}) do count = count + 1 end
        if count == 0 then
            self:Notify("FAVORITES", "No favorites yet — right-click any control to add one", "info")
        end
    end
    self:_applySearchFilter()
end

function Library:Confirm(title, text, onYes, onNo)
    if self:_isDead() then return end
    if not self._UI.MainContainer or not self._UI.MainContainer.Parent then return end
    -- Drop any stale modal first: the old guard returned while this cleanup was
    -- unreachable, so one interrupted Confirm locked the API forever.
    if self._ActiveConfirm then
        pcall(function() self._ActiveConfirm:Destroy() end)
        self._ActiveConfirm = nil
    end
    self._ConfirmAnimating = true

    local overlay = Instance.new("TextButton")
    overlay.Name = "DoD_ConfirmOverlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.ZIndex = 9500
    -- Parented to MainContainer (not the ScreenGui) so closing/minimising the
    -- window takes the modal with it instead of leaving a full-screen click trap.
    overlay.Parent = self._UI.MainContainer

    local _cCam = getCam()
    local _cVpX = (_cCam and _cCam.ViewportSize.X) or 800
    local _cVpY = (_cCam and _cCam.ViewportSize.Y) or 600
    local _cMob = self._isMobile
    local _cPanelW = math.min(340, _cVpX - 24)
    local _cPanelH = _cMob and math.min(200, _cVpY - 24) or 176
    local _cPad = 16
    local _cGap = 8
    local _cBtnW = _cMob and math.floor((_cPanelW - _cPad * 2 - _cGap) / 2) or 148
    local _cBtnH = _cMob and 44 or 34
    local panel = Instance.new("Frame", overlay)
    panel.Size = UDim2.fromOffset(_cPanelW, _cPanelH)
    panel.Position = UDim2.new(0.5, 0, 0.5, 30)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.BackgroundColor3 = self._Colors.Bg2
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 9501
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

    local panelStroke = Instance.new("UIStroke", panel)
    panelStroke.Color = self._Colors.Accent
    panelStroke.Thickness = 1
    panelStroke.Transparency = 0.2
    panelStroke.ZIndex = 9501

    local icon = Instance.new("ImageLabel", panel)
    icon.Size = UDim2.fromOffset(28, 28)
    icon.Position = UDim2.new(0, 16, 0, 16)
    icon.BackgroundTransparency = 1
    icon.Image = GetIcon("alert-triangle")
    icon.ImageColor3 = self._Colors.Accent
    icon.ImageTransparency = 1
    icon.ZIndex = 9502

    local titleLbl = Instance.new("TextLabel", panel)
    titleLbl.Size = UDim2.new(1, -58, 0, 22)
    titleLbl.Position = UDim2.new(0, 52, 0, 18)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = tostring(title or "Confirm")
    titleLbl.TextColor3 = self._Colors.Text
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTransparency = 1
    titleLbl.ZIndex = 9502

    local textLbl = Instance.new("TextLabel", panel)
    textLbl.Size = UDim2.new(1, -32, 0, 60)
    textLbl.Position = UDim2.new(0, 16, 0, 48)
    textLbl.BackgroundTransparency = 1
    textLbl.Text = tostring(text or "")
    textLbl.TextColor3 = self._Colors.TextDim
    textLbl.Font = Enum.Font.GothamMedium
    textLbl.TextSize = 11
    textLbl.TextWrapped = true
    textLbl.TextXAlignment = Enum.TextXAlignment.Left
    textLbl.TextYAlignment = Enum.TextYAlignment.Top
    textLbl.TextTransparency = 1
    textLbl.ZIndex = 9502

    local cancel = Instance.new("TextButton", panel)
    cancel.Size = UDim2.fromOffset(_cBtnW, _cBtnH)
    cancel.Position = UDim2.new(0, _cPad, 1, -(_cBtnH + _cPad))
    cancel.BackgroundColor3 = self._Colors.Card
    cancel.Text = "Cancel"
    cancel.TextColor3 = self._Colors.Text
    cancel.Font = Enum.Font.GothamBold
    cancel.TextSize = 12
    cancel.AutoButtonColor = false
    cancel.ZIndex = 9502
    Instance.new("UICorner", cancel).CornerRadius = UDim.new(0, 8)

    local cancelStroke = Instance.new("UIStroke", cancel)
    cancelStroke.Color = self._Colors.Border
    cancelStroke.Thickness = 1
    cancelStroke.ZIndex = 9502

    local confirm = Instance.new("TextButton", panel)
    confirm.Size = UDim2.fromOffset(_cBtnW, _cBtnH)
    confirm.Position = UDim2.new(1, -(_cBtnW + _cPad), 1, -(_cBtnH + _cPad))
    confirm.BackgroundColor3 = self._Colors.Accent
    confirm.Text = "Confirm"
    confirm.TextColor3 = Fn.accentTextColor(self._Colors.Accent)
    confirm.Font = Enum.Font.GothamBold
    confirm.TextSize = 12
    confirm.AutoButtonColor = false
    confirm.ZIndex = 9502
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 8)

    local confirmStroke = Instance.new("UIStroke", confirm)
    confirmStroke.Color = self._Colors.Accent
    confirmStroke.Thickness = 1
    confirmStroke.ZIndex = 9502

    Fn.bindPressAnimation(cancel)
    Fn.bindPressAnimation(confirm)

    local closed = false
    local function close(confirmed)
        if closed then return end
        closed = true
        self._ConfirmAnimating = false
        if self._ActiveConfirm == overlay then self._ActiveConfirm = nil end
        TweenService:Create(overlay, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        local info = TweenInfo.new(0.15)
        TweenService:Create(panel, info, {BackgroundTransparency = 1}):Play()
        TweenService:Create(titleLbl, info, {TextTransparency = 1}):Play()
        TweenService:Create(textLbl, info, {TextTransparency = 1}):Play()
        TweenService:Create(icon, info, {ImageTransparency = 1}):Play()
        TweenService:Create(cancel, info, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        TweenService:Create(confirm, info, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        task.delay(0.18, function()
            if overlay.Parent then overlay:Destroy() end
            if self._ActiveConfirm == overlay then self._ActiveConfirm = nil end
            self._ConfirmAnimating = false
            if self:_isDead() then return end
            if confirmed then
                if onYes then
                    local ok, err = pcall(onYes)
                    if not ok then warn("[DoD UI] Confirm onYes failed: " .. tostring(err)) end
                end
            else
                if onNo then
                    local ok, err = pcall(onNo)
                    if not ok then warn("[DoD UI] Confirm onNo failed: " .. tostring(err)) end
                end
            end
        end)
    end

    cancel.MouseButton1Click:Connect(function() close(false) end)
    confirm.MouseButton1Click:Connect(function() close(true) end)
    overlay.MouseButton1Click:Connect(function() close(false) end)

    self._ActiveConfirm = overlay

    TweenService:Create(overlay, TweenInfo.new(0.2), {BackgroundTransparency = 0.4}):Play()
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }):Play()
    TweenService:Create(titleLbl, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    TweenService:Create(textLbl, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    TweenService:Create(icon, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()

    return overlay
end

function Library:_updateNotifPositions()
    local pos = self._NotifPosition or "TopRight"
    for index, frame in ipairs(self._STATE.activeNotifs) do
        local targetY = 15 + ((index - 1) * 65)
        local targetX = UDim2.new(1, -282, 0, targetY)
        
        if pos == "TopLeft" then
            targetX = UDim2.new(0, 15, 0, targetY)
        elseif pos == "BottomLeft" then
            targetX = UDim2.new(0, 15, 1, -targetY - 56)
        elseif pos == "BottomRight" then
            targetX = UDim2.new(1, -282, 1, -targetY - 56)
        end
        
        TweenService:Create(
            frame,
            TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Position = targetX}
        ):Play()
    end
end

function Library:ExportConfig()
    if self:_isDead() then return {} end
    local out = { _version = self.Version, _theme = self.ThemeName, _controls = {}, _timestamp = os.time() }
    local failures = 0
    for id, entry in pairs(self._STATE.ConfigRegistry or {}) do
        local ok, val = pcall(entry.get)
        if ok and val ~= nil then
            out._controls[id] = val
        elseif not ok then
            -- Track failures instead of silently writing an incomplete config.
            failures = failures + 1
        end
    end
    self._lastExportFailures = failures
    out._favorites = {}
    for id, val in pairs(self._STATE.Favorites or {}) do
        if val then table.insert(out._favorites, id) end
    end
    return out
end

function Library:ImportConfig(config, silent)
    if self:_isDead() then return end
    if type(config) ~= "table" then return end
    if config._theme and D.Themes[config._theme] then
        self:SetTheme(config._theme, true)
    end
    if type(config._favorites) == "table" then
        table.clear(self._STATE.Favorites)
        for _, id in ipairs(config._favorites) do
            if type(id) == "string" then
                self._STATE.Favorites[id] = true
            end
        end
        for id in pairs(self._STATE.FavoriteStars or {}) do
            self:_updateFavoriteStar(id)
        end
        self:_applySearchFilter()
    end
    local applied, total = 0, 0
    for id, val in pairs(config._controls or {}) do
        total = total + 1
        local entry = self._STATE.ConfigRegistry and self._STATE.ConfigRegistry[id]
        if entry and entry.set then
            -- The setter's second argument means "do not fire the user callback".
            -- It used to be hard-coded true, so loading a config only repainted
            -- the widgets and never applied anything to the script that owns them.
            local ok = pcall(entry.set, val, silent == true)
            if ok then applied = applied + 1 end
        end
    end
    if not silent then
        self:Notify("CONFIG", "Imported " .. applied .. "/" .. total .. " settings", "success")
    end
end

function Library:GetConfigs(force)
    if self._configsCache and not force then
        return self._configsCache
    end
    local configs = {}
    local prefix = "DoD_UI_"
    local suffix = ".json"
    
    pcall(function()
        if listfiles and type(listfiles) == "function" then
            for _, file in ipairs(listfiles()) do
                local base = string.match(tostring(file), "[^\\/]+$") or tostring(file)
                if string.sub(base, 1, #prefix) == prefix and string.sub(base, -#suffix) == suffix then
                    local ok, content = pcall(readfile, file)
                    local timestamp = 0
                    if ok and content then
                        local ok2, data = pcall(function() return game:GetService("HttpService"):JSONDecode(content) end)
                        if ok2 and data and data._timestamp then
                            timestamp = data._timestamp
                        end
                    end
                    local name = string.match(base, "^" .. prefix .. "(.+)%.json$")
                        or string.sub(base, #prefix + 1, #base - #suffix)
                    table.insert(configs, { name = name, file = file, time = timestamp })
                end
            end
        end
        -- Always merge the in-memory store, so configs saved on executors without
        -- a filesystem still show up.
        local g = (getgenv and getgenv()) or _G
        if g.__DoDConfigs then
            local seen = {}
            for _, entry in ipairs(configs) do seen[entry.name] = true end
            for name, json in pairs(g.__DoDConfigs) do
                if not seen[name] then
                    local timestamp = 0
                    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(json) end)
                    if ok and data and data._timestamp then
                        timestamp = data._timestamp
                    end
                    table.insert(configs, { name = name, file = nil, time = timestamp })
                end
            end
        end
    end)

    table.sort(configs, function(a, b)
        return (a.time or 0) > (b.time or 0)
    end)

    self._configsCache = configs
    return configs
end

function Library:SaveConfig(name, silent)
    if self:_isDead() then return false end
    if type(name) ~= "string" or name == "" then return false end
    name = name:gsub("[^%w_%-]", "_")
    if name == "" then return false end
    
    local g = (getgenv and getgenv()) or _G

    local data = self:ExportConfig()
    local ok, json = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    if not ok or type(json) ~= "string" then
        if not silent then self:Notify("CONFIG", "JSON encode failed", "error") end
        return false
    end
    local path = "DoD_UI_" .. name .. ".json"
    -- Mirror to memory too, then report honestly whether the file write worked.
    g.__DoDConfigs = g.__DoDConfigs or {}
    g.__DoDConfigs[name] = json
    local fileOk = false
    pcall(function()
        if writefile and type(writefile) == "function" then
            writefile(path, json)
            fileOk = true
        end
    end)
    g.DoD_LastConfig = name
    self._configsCache = nil
    if not silent then
        if fileOk then
            self:Notify("CONFIG", "Saved: " .. name, "success")
        else
            self:Notify("CONFIG", "Saved (memory only): " .. name, "warning")
        end
    end
    return true
end

function Library:LoadConfig(name, silent)
    if self:_isDead() then return end
    if type(name) ~= "string" or name == "" then return end
    name = name:gsub("[^%w_%-]", "_")
    if name == "" then return end
    local path = "DoD_UI_" .. name .. ".json"
    local json = nil
    pcall(function()
        if isfile and type(isfile) == "function" and readfile and type(readfile) == "function" then
            if isfile(path) then json = readfile(path) end
        end
    end)
    if not json then
        local g = (getgenv and getgenv()) or _G
        if g.__DoDConfigs and g.__DoDConfigs[name] then
            json = g.__DoDConfigs[name]
        end
    end
    if type(json) ~= "string" then
        if not silent then self:Notify("CONFIG", "Not found: " .. name, "warning") end
        return false
    end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(json)
    end)
    if not ok or type(data) ~= "table" then
        if not silent then self:Notify("CONFIG", "Decode failed", "error") end
        return false
    end
    self:ImportConfig(data, silent)
    return true
end

function Library:EnableAutoSave(name)
    if self:_isDead() then return end
    if type(name) ~= "string" or name == "" then return end
    self._STATE.ConfigAutoSave = { name = name }
    self:SaveConfig(name, true)
end

function Library:DisableAutoSave()
    if self:_isDead() then return end
    self._STATE.ConfigAutoSave = nil
end

function Library:Notify(title, text, notifyType)
    local STATE = self._STATE
    if STATE.Destroyed then return end
    title = tostring(title or "")
    text = tostring(text or "")
    notifyType = tostring(notifyType or "info")
    
    if STATE.NotifActive >= STATE.NotifMax then
        local queue = STATE.NotifQueue
        table.insert(queue, { title = title, text = text, nType = notifyType })
        -- When the backlog is full, drop informational toasts before errors, so
        -- the messages that actually matter survive a burst.
        while #queue > 10 do
            local dropIndex = 1
            for i, entry in ipairs(queue) do
                if entry.nType ~= "error" and entry.nType ~= "warning" then
                    dropIndex = i
                    break
                end
            end
            table.remove(queue, dropIndex)
        end
        return
    end
    STATE.NotifActive = STATE.NotifActive + 1
    self:PlaySound("Notify")

    task.spawn(function()
        local ok, err = pcall(function()
        if STATE.Destroyed or not self._UI.NotifGui or not self._UI.NotifGui.Parent then
            return
        end
        local palette = self._Colors or {}
        local accent = palette.Accent or Color3.fromRGB(180, 180, 195)
        
        local iconId = GetIcon("info")
        local color = accent
        
        if notifyType == "success" then
            color = Color3.fromRGB(52, 211, 153)
            iconId = GetIcon("check-circle")
        elseif notifyType == "error" then
            color = Color3.fromRGB(248, 113, 113)
            iconId = GetIcon("x-circle")
        elseif notifyType == "warning" then
            color = Color3.fromRGB(251, 191, 36)
            iconId = GetIcon("alert-triangle")
        end

        local nPos = self._NotifPosition or "TopRight"
        local spawnPos = UDim2.new(1, -295, 0, -70)
        if nPos == "TopLeft" then spawnPos = UDim2.new(0, -295, 0, 15)
        elseif nPos == "BottomLeft" then spawnPos = UDim2.new(0, -295, 1, -71)
        elseif nPos == "BottomRight" then spawnPos = UDim2.new(1, -295, 1, -71)
        end

        local frame = Instance.new("Frame", self._UI.NotifGui)
        frame.Size = UDim2.new(0, 280, 0, 56)
        frame.Position = spawnPos
        frame.BackgroundColor3 = palette.Bg2 or Color3.fromRGB(14, 14, 20)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

        local frameStroke = Instance.new("UIStroke", frame)
        frameStroke.Color = color
        frameStroke.Thickness = 1
        frameStroke.Transparency = 0.4

        local icon = Instance.new("ImageLabel", frame)
        icon.Size = UDim2.fromOffset(16, 16)
        icon.Position = UDim2.new(0, 12, 0, 10)
        icon.BackgroundTransparency = 1
        icon.Image = iconId
        icon.ImageColor3 = color

        local titleLabel = Instance.new("TextLabel", frame)
        titleLabel.Size = UDim2.new(1, -40, 0, 20)
        titleLabel.Position = UDim2.new(0, 36, 0, 7)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        titleLabel.TextColor3 = palette.Text or Color3.fromRGB(220, 220, 230)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left

        local textLabel = Instance.new("TextLabel", frame)
        textLabel.Size = UDim2.new(1, -40, 0, 18)
        textLabel.Position = UDim2.new(0, 36, 0, 28)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = palette.TextDim or Color3.fromRGB(140, 140, 155)
        textLabel.Font = Enum.Font.GothamMedium
        textLabel.TextSize = 11
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.TextTruncate = Enum.TextTruncate.AtEnd

        local progressBar = Instance.new("Frame", frame)
        progressBar.Size = UDim2.new(1, -4, 0, 2)
        progressBar.Position = UDim2.new(0, 4, 1, -2)
        progressBar.BackgroundColor3 = color
        progressBar.BorderSizePixel = 0

        local accentBar = Instance.new("Frame", frame)
        accentBar.Name = "AccentBar"
        accentBar.Size = UDim2.new(0, 3, 1, -8)
        accentBar.Position = UDim2.new(0, 4, 0, 4)
        accentBar.BackgroundColor3 = color
        accentBar.BorderSizePixel = 0
        accentBar.ZIndex = 2
        Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

        STATE.notifParts[frame] = {
            stroke = frameStroke,
            accentBar = accentBar,
            progressBar = progressBar,
            titleLabel = titleLabel,
            textLabel = textLabel,
        }

        table.insert(STATE.activeNotifs, frame)
        self:_updateNotifPositions()
        TweenService:Create(frame, TweenInfo.new(0.25), {BackgroundTransparency = 0.1}):Play()

        TweenService:Create(
            progressBar,
            TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 0, 0, 2)}
        ):Play()

        task.wait(2.5)

        local index = table.find(STATE.activeNotifs, frame)
        if index then table.remove(STATE.activeNotifs, index) end
        if STATE.Destroyed or not frame.Parent then
            STATE.notifParts[frame] = nil
            if frame.Parent then frame:Destroy() end
            return
        end
        self:_updateNotifPositions()

        TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
        TweenService:Create(textLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
        TweenService:Create(icon, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
        TweenService:Create(frameStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()

        local exitX = UDim2.new(1, 15, 0, frame.Position.Y.Offset)
        if nPos == "TopLeft" or nPos == "BottomLeft" then
            exitX = UDim2.new(0, -300, 0, frame.Position.Y.Offset)
        end
        if nPos == "BottomLeft" or nPos == "BottomRight" then
            exitX = UDim2.new(exitX.X.Scale, exitX.X.Offset, 1, frame.Position.Y.Offset)
        end

        local out = TweenService:Create(
            frame,
            TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Position = exitX, BackgroundTransparency = 1}
        )
        out:Play()
        -- Fixed wait instead of Completed:Wait(): a cancelled tween would suspend
        -- this coroutine forever, pinning the library and one notification slot.
        task.wait(0.35)
        STATE.notifParts[frame] = nil
        if frame.Parent then frame:Destroy() end
        end)
        if not ok then
            warn("[DoD UI] Notify failed: " .. tostring(err))
        end
        -- Exactly one slot is released here, on every exit path.
        STATE.NotifActive = math.max(0, STATE.NotifActive - 1)
        if not STATE.Destroyed then
            local nxt = table.remove(STATE.NotifQueue, 1)
            if nxt then self:Notify(nxt.title, nxt.text, nxt.nType) end
        end
    end)
end

function Library:ShowLoading(label)
    if self:_isDead() then return end
    local UI = self._UI
    if not UI.LoadingFrame or not UI.LoadingFrame.Parent then
        local frame = Instance.new("Frame", UI.MainContainer)
        frame.Name = "LoadingFrame"
        frame.Size = UDim2.fromOffset(220, 42)
        frame.Position = UDim2.new(1, -16, 1, -16)
        frame.AnchorPoint = Vector2.new(1, 1)
        frame.BackgroundColor3 = self._Colors.Bg2
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.ZIndex = 500
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", frame)
        stroke.Color = self._Colors.Accent
        stroke.Thickness = 1
        stroke.Transparency = 0.3
        stroke.ZIndex = 500
        local spinner = Instance.new("ImageLabel", frame)
        spinner.Name = "Spinner"
        spinner.Size = UDim2.fromOffset(20, 20)
        spinner.Position = UDim2.new(0, 10, 0.5, -10)
        spinner.BackgroundTransparency = 1
        spinner.Image = GetIcon("loader")
        spinner.ImageColor3 = self._Colors.Accent
        spinner.ZIndex = 501
        local lbl = Instance.new("TextLabel", frame)
        lbl.Name = "LoadingLabel"
        lbl.Size = UDim2.new(1, -42, 1, -6)
        lbl.Position = UDim2.new(0, 36, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(label or "Loading...")
        lbl.TextColor3 = self._Colors.Text
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.ZIndex = 501
        local bar = Instance.new("Frame", frame)
        bar.Name = "ProgressBar"
        bar.Size = UDim2.new(0, 0, 0, 2)
        bar.Position = UDim2.new(0, 4, 1, -3)
        bar.BackgroundColor3 = self._Colors.Accent
        bar.BorderSizePixel = 0
        bar.ZIndex = 501
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
        UI.LoadingFrame = frame
        UI.LoadingSpinner = spinner
        UI.LoadingLabel = lbl
        UI.LoadingBar = bar
        local angle = 0
        if self._loadingSpinConn then
            pcall(function() self._loadingSpinConn:Disconnect() end)
            self._loadingSpinConn = nil
        end
        self._loadingSpinConn = Fn.track(RunService.RenderStepped, function(dt)
            if _ReducedMotion then return end
            if not spinner or not spinner.Parent then
                if self._loadingSpinConn then
                    Fn.untrack(self._loadingSpinConn, self)
                    self._loadingSpinConn = nil
                end
                return
            end
            angle = (angle + dt * 360) % 360
            spinner.Rotation = angle
        end, self)
    else
        UI.LoadingLabel.Text = tostring(label or "Loading...")
        if UI.LoadingBar then UI.LoadingBar.Size = UDim2.new(0, 0, 0, 2) end
    end
end

function Library:SetProgress(value)
    if self:_isDead() then return end
    local bar = self._UI.LoadingBar
    if not bar or not bar.Parent then return end
    local v = math.clamp(tonumber(value) or 0, 0, 1)
    bar.Size = UDim2.new(v, 0, 0, 2)
end

function Library:HideLoading()
    if self:_isDead() then return end
    -- Stop the spinner before the early-out, otherwise a frame that was already
    -- unparented leaves the RenderStepped rotation running forever.
    if self._loadingSpinConn then
        pcall(function() Fn.untrack(self._loadingSpinConn, self) end)
        self._loadingSpinConn = nil
    end
    local frame = self._UI.LoadingFrame
    if not frame or not frame.Parent then return end
    local out = TweenService:Create(frame, TweenInfo.new(0.2), {BackgroundTransparency = 1})
    out:Play()
    out.Completed:Connect(function()
        if frame and frame.Parent then frame:Destroy() end
    end)
    self._UI.LoadingFrame = nil
    self._UI.LoadingSpinner = nil
    self._UI.LoadingLabel = nil
    self._UI.LoadingBar = nil
end

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

    -- Remember the game's own cursor/camera state so closing the UI can hand it
    -- back instead of permanently unlocking the mouse.
    self._savedMouseIconEnabled = UserInputService.MouseIconEnabled
    self._savedMouseBehavior = UserInputService.MouseBehavior
    self._overGui = false

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
        else
            overGui = pointIn(UI.MinimizeButton, mouse.X, mouse.Y)
        end

        -- Transition-only writes: this used to touch UserInputService, the cursor
        -- label and MouseBehaviour on every single frame.
        if overGui ~= self._overGui then
            self._overGui = overGui
            if UI.CustomCursor then
                UI.CustomCursor.Visible = overGui
            end
            if UserInputService.MouseIconEnabled ~= (not overGui) then
                UserInputService.MouseIconEnabled = not overGui
            end
            -- NOTE: MouseBehaviour is intentionally NOT set here anymore. The old
            -- code restored _savedMouseBehavior whenever the pointer left the
            -- panel's bounds. If the game had LockCenter / LockCurrentPosition
            -- cached at construction time, the mouse would snap back to the
            -- center of the screen as soon as the cursor moved outside the panel,
            -- producing the "barely can move" feel. MouseBehaviour is now managed
            -- below (always Default while GUI is open) and restored only when the
            -- GUI closes (Toggle close path / Minimize / Destroy).
        end

        -- FIX: while the GUI is visible, keep the mouse unlocked no matter where
        -- the pointer is. This is the entire point of a free-mouse GUI overlay.
        if self._STATE.GuiVisible then
            if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
        end

        -- MOUSE FIX: force Default while GUI is visible, regardless of where
        -- the pointer is. Without this, the game snaps the cursor back to
        -- center the moment the pointer leaves the panel bounds.
        if self._STATE.GuiVisible and UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end

        if overGui and UI.CustomCursor then
            UI.CustomCursor.Position = UDim2.fromOffset(mouse.X, mouse.Y)
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
        if _ReducedMotion then return end
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

    -- Keeps the custom cursor authoritative, but only while the pointer is
    -- actually over our UI (the old version re-hid the OS cursor everywhere).
    Fn.track(UserInputService:GetPropertyChangedSignal("MouseIconEnabled"), function()
        if not self._STATE or self._STATE.Destroyed then return end
        if self._overGui and not self._isMobile and UserInputService.MouseIconEnabled then
            UserInputService.MouseIconEnabled = false
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
    if _ReducedMotion then return end
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
        if _ReducedMotion then return end

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

-- =========================================================
-- PUBLIC API: CREATE CATEGORY / TAB / SECTION
-- =========================================================

function Library:CreateCategory(categoryName, iconSpec)
    if self:_isDead() then return end
    if type(categoryName) ~= "string" or categoryName == "" then
        error("[DoD UI] CreateCategory requires a non-empty category name.")
    end
    if iconSpec ~= nil and type(iconSpec) ~= "string" then
        error("[DoD UI] CreateCategory iconSpec must be a string or nil.")
    end
    local UI = self._UI
    local STATE = self._STATE
    if STATE.CategoryButtons and STATE.CategoryButtons[categoryName] then
        error("[DoD UI] Category '" .. categoryName .. "' already exists.")
    end
    STATE.CategoryTabs[categoryName] = STATE.CategoryTabs[categoryName] or {}
    STATE.CategoryOrder = STATE.CategoryOrder or {}
    STATE.CategoryButtons = STATE.CategoryButtons or {}
    if not STATE.CategoryButtons[categoryName] then
        table.insert(STATE.CategoryOrder, categoryName)
    end

    if self.TabPosition == "Side" and UI.AccordionScroll then
        local group = Instance.new("Frame", UI.AccordionScroll)
        group.Name = "AccGroup_" .. categoryName
        group.LayoutOrder = #STATE.CategoryOrder
        group.Size = UDim2.new(1, 0, 0, 34)
        group.BackgroundTransparency = 1
        group.ClipsDescendants = true
        group.ZIndex = 5
        group.AutomaticSize = Enum.AutomaticSize.Y

        local groupLayout = Instance.new("UIListLayout", group)
        groupLayout.SortOrder = Enum.SortOrder.LayoutOrder
        groupLayout.Padding = UDim.new(0, 2)

        local header = Instance.new("TextButton", group)
        header.Name = "Header"
        header.LayoutOrder = 1
        header.Size = UDim2.new(1, 0, 0, 32)
        header.BackgroundColor3 = self._Colors.Card
        header.BackgroundTransparency = 0.75
        header.Text = ""
        header.AutoButtonColor = false
        header.ZIndex = 6
        Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

        local hStroke = Instance.new("UIStroke", header)
        hStroke.Color = self._Colors.Border
        hStroke.Thickness = 1
        hStroke.Transparency = 0.7

        local chevron = Instance.new("ImageLabel", header)
        chevron.Name = "Chevron"
        chevron.Size = UDim2.fromOffset(12, 12)
        chevron.Position = UDim2.new(0, 8, 0.5, -6)
        chevron.BackgroundTransparency = 1
        chevron.Image = GetIcon("chevron-down")
        chevron.ImageColor3 = self._Colors.TextDim
        chevron.ScaleType = Enum.ScaleType.Fit
        chevron.ZIndex = 7

        local iconImg = Instance.new("ImageLabel", header)
        iconImg.Size = UDim2.fromOffset(14, 14)
        iconImg.Position = UDim2.new(0, 26, 0.5, -7)
        iconImg.BackgroundTransparency = 1
        iconImg.ImageColor3 = self._Colors.TextDim
        iconImg.ScaleType = Enum.ScaleType.Fit
        iconImg.ZIndex = 7
        if iconSpec then
            if string.sub(iconSpec, 1, 6) == "asset:" then
                iconImg.Image = "rbxassetid://" .. string.sub(iconSpec, 7)
            else
                iconImg.Image = GetIcon(iconSpec)
            end
        end

        local label = Instance.new("TextLabel", header)
        label.Size = UDim2.new(1, -48, 1, 0)
        label.Position = UDim2.new(0, 46, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = string.upper(categoryName)
        label.TextColor3 = self._Colors.TextDim
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.ZIndex = 7

        local tabList = Instance.new("Frame", group)
        tabList.Name = "TabList"
        tabList.LayoutOrder = 2
        tabList.Size = UDim2.new(1, 0, 0, 0)
        tabList.BackgroundTransparency = 1
        tabList.ClipsDescendants = true
        tabList.Visible = false
        tabList.ZIndex = 5

        local tlLayout = Instance.new("UIListLayout", tabList)
        tlLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tlLayout.Padding = UDim.new(0, 3)

        local tlPad = Instance.new("UIPadding", tabList)
        tlPad.PaddingLeft = UDim.new(0, 20)
        tlPad.PaddingRight = UDim.new(0, 4)
        tlPad.PaddingTop = UDim.new(0, 4)
        tlPad.PaddingBottom = UDim.new(0, 6)

        STATE.CategoryButtons[categoryName] = {
            button = header,
            label = label,
            icon = iconImg,
            chevron = chevron,
            group = group,
            tabList = tabList,
            layout = tlLayout,
            stroke = hStroke,
            isAccordion = true,
        }

        header.MouseButton1Click:Connect(function()
            local current = STATE.AccordionExpanded[categoryName]
            local isActiveCat = (STATE.ActiveCategory == categoryName)
            
            if not current then
                local tabs = STATE.CategoryTabs[categoryName]
                local targetTab = nil
                if tabs and #tabs > 0 then
                    local savedIdx = STATE.ActiveSubIndices[categoryName]
                    targetTab = (savedIdx and tabs[savedIdx]) or tabs[1]
                end
                self:SetActiveCategory(categoryName, targetTab)
            elseif current and not isActiveCat then
                local tabs = STATE.CategoryTabs[categoryName]
                local targetTab = nil
                if tabs and #tabs > 0 then
                    local savedIdx = STATE.ActiveSubIndices[categoryName]
                    targetTab = (savedIdx and tabs[savedIdx]) or tabs[1]
                end
                self:SetActiveCategory(categoryName, targetTab)
            elseif current and isActiveCat then
                self:_setAccordionState(categoryName, false)
            end
        end)

        header.MouseEnter:Connect(function()
            self:PlaySound("Hover")
            TweenService:Create(hStroke, TweenInfo.new(0.15), {Transparency = 0.3, Color = self._Colors.Accent}):Play()
            TweenService:Create(header, TweenInfo.new(0.15), {BackgroundTransparency = 0.55}):Play()
        end)
        header.MouseLeave:Connect(function()
            local isActive = (self.TabPosition == "Side") and STATE.AccordionExpanded[categoryName] or (categoryName == STATE.ActiveCategory)
            TweenService:Create(hStroke, TweenInfo.new(0.15), {
                Transparency = isActive and 0.3 or 0.7,
                Color = isActive and self._Colors.Accent or self._Colors.Border,
            }):Play()
            TweenService:Create(header, TweenInfo.new(0.15), {BackgroundTransparency = isActive and 0.5 or 0.75}):Play()
        end)

        self:_registerThemeRefresher(function()
            if not header.Parent then return end
            header.BackgroundColor3 = self._Colors.Card
            local isActive = (self.TabPosition == "Side") and STATE.AccordionExpanded[categoryName] or (categoryName == STATE.ActiveCategory)
            hStroke.Color = isActive and self._Colors.Accent or self._Colors.Border
            label.TextColor3 = isActive and self._Colors.Text or self._Colors.TextDim
            iconImg.ImageColor3 = isActive and self._Colors.Accent or self._Colors.TextDim
            chevron.ImageColor3 = isActive and self._Colors.Accent or self._Colors.TextDim
        end)

        return header
    end

    local btn = Instance.new("TextButton", UI.CategoryBar)
    btn.Name = "CatBtn_" .. categoryName
    btn.Size = UDim2.new(0, 110, 0, 30)
    btn.BackgroundColor3 = self._Colors.Card
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    Fn.bindPressAnimation(btn)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local iconImg = Instance.new("ImageLabel", btn)
    iconImg.Size = UDim2.new(0, 16, 0, 16)
    iconImg.Position = UDim2.new(0, 14, 0.5, -8)
    iconImg.BackgroundTransparency = 1
    iconImg.ImageColor3 = Color3.new(1, 1, 1)
    iconImg.ImageTransparency = 0.45
    iconImg.ScaleType = Enum.ScaleType.Fit
    if iconSpec then
        if string.sub(iconSpec, 1, 6) == "asset:" then
            iconImg.Image = "rbxassetid://" .. string.sub(iconSpec, 7)
        else
            iconImg.Image = GetIcon(iconSpec)
        end
    end

    local label = Instance.new("TextLabel", btn)
    label.Size = UDim2.new(1, -42, 1, 0)
    label.Position = UDim2.new(0, 36, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = categoryName
    label.TextColor3 = self._Colors.TextDim
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd

    btn.MouseEnter:Connect(function()
        self:PlaySound("Hover")
    end)

    btn.MouseButton1Click:Connect(function()
        self:SetActiveCategory(categoryName)
    end)

    STATE.CategoryButtons[categoryName] = { button = btn, label = label, icon = iconImg }
    self:_registerThemeRefresher(function()
        if not btn.Parent then return end
        btn.BackgroundColor3 = self._Colors.Card
        -- Contrast-derived instead of hard-coded white: the active label was
        -- unreadable on light themes (Monochrome / Ice / Gold).
        label.TextColor3 = categoryName == STATE.ActiveCategory
            and Fn.contrastForeground(self._Colors.Sidebar) or self._Colors.TextDim
    end)

    self:_layoutCategoryButtons()
    return btn
end

function Library:_layoutCategoryButtons()
    local STATE = self._STATE
    local UI = self._UI
    if not STATE.CategoryButtons then return end
    if self.TabPosition == "Side" then
        if UI.BottomPill then UI.BottomPill.Visible = false end
        return
    end
    local names = {}
    for _, name in ipairs(STATE.CategoryOrder or {}) do
        if STATE.CategoryButtons[name] then table.insert(names, name) end
    end
    if #names == 0 then
        if self.TabPosition == "Bottom" then
            UI.CategoryBar.Size = UDim2.new(1, -20, 0, 48)
            UI.CategoryBar.Position = UDim2.new(0, 10, 1, -58)
        end
        return
    end

    local gap, padding = 8, 8
    local availableWidth = UI.MainContainer.AbsoluteSize.X - 20
    if self.TabPosition == "Top" then
        availableWidth = UI.CategoryBar.AbsoluteSize.X
    end
    if availableWidth <= 0 then return end

    gap = math.min(gap, math.floor(availableWidth / math.max(#names * 2, 1)))
    padding = math.min(padding, math.floor((availableWidth - gap * math.max(#names - 1, 0)) / (#names * 2)))
    local gapsWidth = math.max(#names - 1, 0) * gap
    local buttonWidth = math.min(self.TabWidth, math.floor((availableWidth - padding * 2 - gapsWidth) / #names))
    buttonWidth = math.max(buttonWidth, 1)
    local dockWidth = math.min(availableWidth, #names * buttonWidth + gapsWidth + padding * 2)
    
    if self.TabPosition == "Bottom" then
        UI.CategoryBar.Size = UDim2.new(1, -20, 0, 56)
        UI.CategoryBar.Position = UDim2.new(0, 10, 1, -66)
    end

    local startX = padding
    if self.CategoryAlign == "Center" or self.TabPosition == "Bottom" then
        startX = math.floor((availableWidth - dockWidth) / 2) + padding
    elseif self.CategoryAlign == "Right" then
        startX = availableWidth - dockWidth + padding
    end
    for i, name in ipairs(names) do
        local data = STATE.CategoryButtons[name]
        data.button.Size = UDim2.new(0, buttonWidth, 0, self.TabPosition == "Bottom" and 36 or 30)
        data.button.Position = UDim2.new(0, startX + (i - 1) * (buttonWidth + gap), 0.5, self.TabPosition == "Bottom" and -18 or -15)
        data.label.Visible = buttonWidth >= 72
        data.icon.Position = UDim2.new(0, buttonWidth >= 72 and 10 or (buttonWidth - 16) / 2, 0.5, -8)
        data.label.Size = UDim2.new(1, -38, 1, 0)
    end

    if self.TabPosition == "Bottom" and UI.BottomPill then
        local activeData = STATE.CategoryButtons[STATE.ActiveCategory]
        if activeData and activeData.button then
            UI.BottomPill.Size = UDim2.new(0, buttonWidth, 0, 36)
            UI.BottomPill.Position = UDim2.new(0, activeData.button.Position.X.Offset, 0.5, -18)
        end
    end
end

function Library:SetActiveCategory(categoryName, preferredTab)
    if self:_isDead() then return end
    local STATE = self._STATE
    if not STATE.CategoryButtons or not STATE.CategoryButtons[categoryName] then return end
    local targetData = STATE.CategoryButtons[categoryName]
    if targetData.isStandalone then
        if STATE.ActiveCategory == categoryName and STATE.ActiveTab then
            return
        end
        for name, data in pairs(STATE.CategoryButtons or {}) do
            local active = (name == categoryName)
            if data.isStandalone then
                if data.isAccordion then
                    if data.stroke then
                        TweenService:Create(data.stroke, TweenInfo.new(0.2), {
                            Transparency = active and 0.3 or 0.7,
                            Color = active and self._Colors.Accent or self._Colors.Border,
                        }):Play()
                    end
                    if data.button then
                        TweenService:Create(data.button, TweenInfo.new(0.2), {
                            BackgroundTransparency = active and 0.4 or 0.75,
                        }):Play()
                    end
                    if data.label then
                        data.label.TextColor3 = active and self._Colors.Text or self._Colors.TextDim
                        data.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
                    end
                    if data.icon then
                        data.icon.ImageColor3 = active and self._Colors.Accent or self._Colors.TextDim
                    end
                else
                    if data.button then
                        TweenService:Create(data.button, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {
                            BackgroundTransparency = active and 0.55 or 1,
                        }):Play()
                    end
                    if data.label then
                        TweenService:Create(data.label, TweenInfo.new(0.22), {
                            TextColor3 = active and Color3.fromRGB(255, 255, 255) or self._Colors.TextDim,
                        }):Play()
                        data.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
                    end
                    if data.icon then
                        TweenService:Create(data.icon, TweenInfo.new(0.22), {
                            ImageTransparency = active and 0 or 0.45,
                        }):Play()
                    end
                end
            elseif not data.isAccordion and data.button and data.label and data.icon then
                TweenService:Create(data.button, TweenInfo.new(0.22), {BackgroundTransparency = 1}):Play()
                TweenService:Create(data.label, TweenInfo.new(0.22), {TextColor3 = self._Colors.TextDim}):Play()
                data.label.Font = Enum.Font.GothamMedium
                TweenService:Create(data.icon, TweenInfo.new(0.22), {ImageTransparency = 0.45}):Play()
            end
        end
        STATE.ActiveCategory = categoryName
        STATE.ActiveSubIndices = STATE.ActiveSubIndices or {}
        local tabs = STATE.CategoryTabs[categoryName]
        if tabs and tabs[1] then
            STATE.ActiveTab = nil
            self:SwitchTab(tabs[1])
        end
        self:_applyNavigationLayout()
        return
    end
    local prevActive = STATE.ActiveCategory
    if prevActive and prevActive ~= categoryName then
        local prevData = STATE.CategoryButtons[prevActive]
        if prevData and prevData.isStandalone then
            if prevData.isAccordion then
                if prevData.stroke then
                    TweenService:Create(prevData.stroke, TweenInfo.new(0.2), {Transparency = 0.7, Color = self._Colors.Border}):Play()
                end
                if prevData.button then
                    TweenService:Create(prevData.button, TweenInfo.new(0.2), {BackgroundTransparency = 0.75}):Play()
                end
                if prevData.label then
                    prevData.label.TextColor3 = self._Colors.TextDim
                    prevData.label.Font = Enum.Font.GothamMedium
                end
                if prevData.icon then
                    prevData.icon.ImageColor3 = self._Colors.TextDim
                end
            else
                if prevData.button then
                    TweenService:Create(prevData.button, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                end
                if prevData.label then
                    TweenService:Create(prevData.label, TweenInfo.new(0.2), {TextColor3 = self._Colors.TextDim}):Play()
                    prevData.label.Font = Enum.Font.GothamMedium
                end
                if prevData.icon then
                    TweenService:Create(prevData.icon, TweenInfo.new(0.2), {ImageTransparency = 0.45}):Play()
                end
            end
        end
    end
    if STATE.ActiveCategory == categoryName and STATE.SubTabBar then
        if preferredTab and STATE.ContentPages[preferredTab] then
            self:SwitchTab(preferredTab)
        end
        return
    end
    STATE.ActiveCategory = categoryName
    STATE.ActiveSubIndices = STATE.ActiveSubIndices or {}

    if self.TabPosition ~= "Side" then
        for name, data in pairs(STATE.CategoryButtons or {}) do
            local active = (name == categoryName)
            TweenService:Create(data.button, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {
                BackgroundTransparency = active and 0.55 or 1,
            }):Play()
            TweenService:Create(data.label, TweenInfo.new(0.22), {
                TextColor3 = active and Color3.fromRGB(255, 255, 255) or self._Colors.TextDim,
            }):Play()
            data.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
            TweenService:Create(data.icon, TweenInfo.new(0.22), {
                ImageTransparency = active and 0 or 0.45,
            }):Play()
        end
    end

    local tabs = STATE.CategoryTabs[categoryName]
    if not (tabs and #tabs > 0) then return end

    local targetIdx, targetName
    if preferredTab and STATE.ContentPages[preferredTab] then
        for idx, name in ipairs(tabs) do
            if name == preferredTab then
                targetIdx, targetName = idx, name
                break
            end
        end
    end
    if not targetName then
        local savedIdx = STATE.ActiveSubIndices[categoryName]
        if savedIdx and tabs[savedIdx] then
            targetIdx, targetName = savedIdx, tabs[savedIdx]
        else
            targetIdx, targetName = 1, tabs[1]
        end
    end

    if self.TabPosition == "Side" then
        if not STATE.AccordionExpanded[categoryName] then
            self:_setAccordionState(categoryName, true)
        end
        
        for _, catData in pairs(STATE.CategoryButtons) do
            if catData.isAccordion and catData.tabList then
                for _, otherSub in ipairs(catData.tabList:GetChildren()) do
                    if otherSub:IsA("TextButton") then
                        otherSub.BackgroundTransparency = 1
                        local lbl = otherSub:FindFirstChild("SubLabel")
                        if lbl then
                            lbl.TextColor3 = self._Colors.TextDim
                            lbl.Font = Enum.Font.GothamMedium
                        end
                        local ind = otherSub:FindFirstChild("AccentDot")
                        if ind then ind.Visible = false end
                    end
                end
            end
        end
        
        if targetName then
            STATE.ActiveSubIndices[categoryName] = targetIdx
            local catData = STATE.CategoryButtons[categoryName]
            if catData and catData.tabList then
                for _, child in ipairs(catData.tabList:GetChildren()) do
                    if child:IsA("TextButton") and child:GetAttribute("TabName") == targetName then
                        child.BackgroundTransparency = 0.4
                        local lbl = child:FindFirstChild("SubLabel")
                        if lbl then
                            lbl.TextColor3 = self._Colors.Text
                            lbl.Font = Enum.Font.GothamBold
                        end
                        local ind = child:FindFirstChild("AccentDot")
                        if ind then ind.Visible = true end
                        break
                    end
                end
            end
            if STATE.ContentPages[targetName] then
                self:SwitchTab(targetName)
            end
        end
        self:_applyNavigationLayout()
        return
    end

    -- The tab strip is cached per category. It used to be destroyed and rebuilt
    -- from scratch on every category click, churning dozens of instances and
    -- connections each time.
    STATE.SubTabBars = STATE.SubTabBars or {}
    for name, bar in pairs(STATE.SubTabBars) do
        if name ~= categoryName and bar and bar.Wrapper then
            bar.Wrapper.Visible = false
        end
    end

    local cachedBar = STATE.SubTabBars[categoryName]
    if cachedBar and cachedBar.Wrapper and cachedBar.Wrapper.Parent then
        cachedBar.Wrapper.Visible = true
        STATE.SubTabBar = cachedBar
        self:_resizeSubTabs()
        if targetName then
            STATE.ActiveSubIndices[categoryName] = targetIdx
            cachedBar:SetActiveSub(categoryName, targetName)
            if STATE.ContentPages[targetName] then
                self:SwitchTab(targetName)
            end
        end
        self:_applyNavigationLayout()
        return
    end

    local suppress = false
    STATE.SubTabBar = SubTabModule.new({
        Parent = self._UI.Sidebar,
        Data = { [categoryName] = tabs },
        TabWidth = self.TabWidth, TabHeight = self._isMobile and 44 or 28, Padding = 6,
        Theme = {
            PillBg = self._Colors.Card, LeftAccent = self._Colors.Accent,
            TextActive = Fn.contrastForeground(self._Colors.Card), TextInactive = self._Colors.TextDim,
            FontActive = Enum.Font.GothamBold, FontInactive = Enum.Font.GothamMedium,
        },
        Owner = self,
        OnChanged = function(_, subName)
            if suppress then return end
            for idx, name in ipairs(tabs) do
                if name == subName then
                    STATE.ActiveSubIndices[categoryName] = idx
                    break
                end
            end
            if STATE.ContentPages[subName] then
                self:SwitchTab(subName)
            end
        end,
    })
    self:_resizeSubTabs()
    suppress = true
    STATE.SubTabBar:SwitchCategory(categoryName)
    suppress = false
    STATE.SubTabBars[categoryName] = STATE.SubTabBar

    if targetName then
        STATE.SubTabBar:SetActiveSub(categoryName, targetName)
        STATE.ActiveSubIndices[categoryName] = targetIdx
        if STATE.ContentPages[targetName] then
            self:SwitchTab(targetName)
        end
    end
    self:_applyNavigationLayout()
end

function Library:SetTabBadge(categoryName, tabName, text, color)
    warn("[DoD UI] SetTabBadge is deprecated - badges removed in this version.")
    return
end

function Library:CreateTab(categoryName, tabName)
    if self:_isDead() then return end
    if type(tabName) ~= "string" or tabName == "" then
        error("[DoD UI] CreateTab requires a non-empty tab name.")
    end
    local UI = self._UI
    local STATE = self._STATE
    if not STATE.CategoryButtons or not STATE.CategoryButtons[categoryName] then
        error("[DoD UI] Category '" .. tostring(categoryName) .. "' belum dibuat. Panggil :CreateCategory dulu.")
    end
    if STATE.ContentPages[tabName] then
        error("[DoD UI] Tab '" .. tabName .. "' already exists.")
    end
    STATE.TabCategories[tabName] = categoryName
    STATE.CategoryTabs[categoryName] = STATE.CategoryTabs[categoryName] or {}
    table.insert(STATE.CategoryTabs[categoryName], tabName)

    local page = Instance.new("ScrollingFrame", UI.ContentArea)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.Position = UDim2.new(0, 0, 0, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 0
    page.ScrollBarImageColor3 = self._Colors.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    page.VerticalScrollBarInset = Enum.ScrollBarInset.None
    page.HorizontalScrollBarInset = Enum.ScrollBarInset.None
    -- MOBILE: native bounce+inertia so finger scroll feels smooth.
    page.ElasticBehavior = self._isMobile and Enum.ElasticBehavior.WhenScrollable or Enum.ElasticBehavior.Never
    self:_registerScrollFrame(page)

    local pagePad = Instance.new("UIPadding", page)
    pagePad.PaddingTop = UDim.new(0, 6)
    pagePad.PaddingBottom = UDim.new(0, 12)
    pagePad.PaddingRight = UDim.new(0, 6)

    local pageList = Instance.new("UIListLayout", page)
    pageList.SortOrder = Enum.SortOrder.LayoutOrder
    pageList.Padding = UDim.new(0, self:_densityPadding(10))

    -- Top container (full width) for banners
    local topContainer = Instance.new("Frame", page)
    topContainer.Name = "TopContainer"
    topContainer.LayoutOrder = 1
    topContainer.Size = UDim2.new(1, 0, 0, 0)
    topContainer.AutomaticSize = Enum.AutomaticSize.Y
    topContainer.BackgroundTransparency = 1
    local topLayout = Instance.new("UIListLayout", topContainer)
    topLayout.SortOrder = Enum.SortOrder.LayoutOrder
    topLayout.Padding = UDim.new(0, 10)

    -- Dual Columns Container
    local columnsContainer = Instance.new("Frame", page)
    columnsContainer.Name = "ColumnsContainer"
    columnsContainer.LayoutOrder = 2
    columnsContainer.Size = UDim2.new(1, 0, 0, 0)
    columnsContainer.BackgroundTransparency = 1
    columnsContainer.ClipsDescendants = false

    -- Left Column
    local leftCol = Instance.new("Frame", columnsContainer)
    leftCol.Name = "LeftColumn"
    leftCol.Size = UDim2.new(0.5, -5, 0, 0)
    leftCol.Position = UDim2.new(0, 0, 0, 0)
    leftCol.AutomaticSize = Enum.AutomaticSize.Y
    leftCol.BackgroundTransparency = 1
    leftCol.ClipsDescendants = false
    local leftLayout = Instance.new("UIListLayout", leftCol)
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Padding = UDim.new(0, self:_densityPadding(10))

    -- Right Column
    local rightCol = Instance.new("Frame", columnsContainer)
    rightCol.Name = "RightColumn"
    rightCol.Size = UDim2.new(0.5, -5, 0, 0)
    rightCol.Position = UDim2.new(0.5, 5, 0, 0)
    rightCol.AutomaticSize = Enum.AutomaticSize.Y
    rightCol.BackgroundTransparency = 1
    rightCol.ClipsDescendants = false
    local rightLayout = Instance.new("UIListLayout", rightCol)
    rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rightLayout.Padding = UDim.new(0, self:_densityPadding(10))

    -- Auto-scale height for columns container
    local function updateColumnsSize()
        local leftSize = leftLayout.AbsoluteContentSize.Y
        local rightSize = rightLayout.AbsoluteContentSize.Y
        local maxH = math.max(leftSize, rightSize)
        columnsContainer.Size = UDim2.new(1, 0, 0, maxH)
    end
    leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateColumnsSize)
    rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateColumnsSize)

    -- Save references
    STATE.ContentPages[tabName] = page
    STATE.TabTopContainers[tabName] = topContainer
    STATE.TabColumns[tabName] = { Left = leftCol, Right = rightCol, Container = columnsContainer }

    self:_registerThemeRefresher(function()
        if page.Parent then
            page.ScrollBarImageColor3 = self._Colors.Accent
        end
    end)
    page:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if STATE.ActiveTab == tabName then
            STATE.SavedScrollPositions[tabName] = page.CanvasPosition
        end
    end)

    if self.TabPosition == "Side" then
        local catData = STATE.CategoryButtons[categoryName]
        if catData and catData.tabList and not catData.isStandalone then
            local tabCount = 0
            for _, c in ipairs(catData.tabList:GetChildren()) do
                if c:IsA("TextButton") then tabCount = tabCount + 1 end
            end
            local subBtn = Instance.new("TextButton", catData.tabList)
            subBtn.Name = "SubTab_" .. tabName
            subBtn.LayoutOrder = tabCount + 1
            subBtn.Size = UDim2.new(1, 0, 0, 26)
            subBtn.BackgroundColor3 = self._Colors.Card
            subBtn.BackgroundTransparency = 1
            subBtn.Text = ""
            subBtn.AutoButtonColor = false
            subBtn.ZIndex = 6
            subBtn:SetAttribute("TabName", tabName)
            Instance.new("UICorner", subBtn).CornerRadius = UDim.new(0, 6)

            local accentDot = Instance.new("Frame", subBtn)
            accentDot.Name = "AccentDot"
            accentDot.Size = UDim2.fromOffset(3, 12)
            accentDot.Position = UDim2.new(0, 2, 0.5, -6)
            accentDot.BackgroundColor3 = self._Colors.Accent
            accentDot.BorderSizePixel = 0
            accentDot.Visible = false
            accentDot.ZIndex = 7
            Instance.new("UICorner", accentDot).CornerRadius = UDim.new(1, 0)

            local subLabel = Instance.new("TextLabel", subBtn)
            subLabel.Name = "SubLabel"
            subLabel.Size = UDim2.new(1, -16, 1, 0)
            subLabel.Position = UDim2.new(0, 12, 0, 0)
            subLabel.BackgroundTransparency = 1
            subLabel.Text = tabName
            subLabel.TextColor3 = self._Colors.TextDim
            subLabel.Font = Enum.Font.GothamMedium
            subLabel.TextSize = 11
            subLabel.TextXAlignment = Enum.TextXAlignment.Left
            subLabel.TextTruncate = Enum.TextTruncate.AtEnd
            subLabel.ZIndex = 7

            subBtn.MouseEnter:Connect(function()
                self:PlaySound("Hover")
                if STATE.ActiveTab ~= tabName then
                    TweenService:Create(subBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.7}):Play()
                    TweenService:Create(subLabel, TweenInfo.new(0.15), {TextColor3 = self._Colors.Text}):Play()
                end
            end)
            subBtn.MouseLeave:Connect(function()
                if STATE.ActiveTab ~= tabName then
                    TweenService:Create(subBtn, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
                    TweenService:Create(subLabel, TweenInfo.new(0.15), {TextColor3 = self._Colors.TextDim}):Play()
                end
            end)

            subBtn.MouseButton1Click:Connect(function()
                self:SetActiveCategory(categoryName, tabName)
            end)

            self:_registerThemeRefresher(function()
                if not subBtn.Parent then return end
                subBtn.BackgroundColor3 = self._Colors.Card
                subLabel.TextColor3 = STATE.ActiveTab == tabName and self._Colors.Text or self._Colors.TextDim
                accentDot.BackgroundColor3 = self._Colors.Accent
            end)
        end
    end

    if self.TabPosition == "Side" and STATE.AccordionExpanded[categoryName] then
        self:_setAccordionState(categoryName, true)
    end

    if STATE.ActiveCategory == nil or STATE.ActiveCategory == categoryName then
        self:SetActiveCategory(categoryName)
    end
    return self:_wrapTab(page, tabName)
end

function Library:CreateStandaloneTab(tabName, iconSpec)
    if self:_isDead() then return end
    if type(tabName) ~= "string" or tabName == "" then
        error("[DoD UI] CreateStandaloneTab requires a non-empty tab name.")
    end
    if iconSpec ~= nil and type(iconSpec) ~= "string" then
        error("[DoD UI] CreateStandaloneTab iconSpec must be a string or nil.")
    end
    local STATE = self._STATE
    if STATE.ContentPages[tabName] then
        error("[DoD UI] Tab '" .. tabName .. "' already exists.")
    end
    if STATE.CategoryButtons and STATE.CategoryButtons[tabName] then
        error("[DoD UI] Category '" .. tabName .. "' already exists.")
    end
    self:CreateCategory(tabName, iconSpec)
    local catData = self._STATE.CategoryButtons[tabName]
    if catData then
        catData.isStandalone = true
        if catData.isAccordion then
            if catData.chevron then catData.chevron.Visible = false end
            if catData.icon then catData.icon.Position = UDim2.new(0, 10, 0.5, -7) end
            if catData.label then
                catData.label.Position = UDim2.new(0, 30, 0, 0)
                catData.label.Size = UDim2.new(1, -40, 1, 0)
            end
        end
    end
    self._STATE.StandaloneTabs[tabName] = true
    self:CreateTab(tabName, tabName)
    return self:_wrapTab(self._STATE.ContentPages[tabName], tabName)
end

function Library:SwitchTab(tabName)
    if self:_isDead() then return end
    local STATE = self._STATE
    local page = STATE.ContentPages[tabName]
    if not page then return end

    local ownerCat = STATE.TabCategories[tabName]
    if ownerCat and STATE.ActiveCategory ~= ownerCat then
        self:SetActiveCategory(ownerCat, tabName)
        return
    end

    if STATE.ActiveTab == tabName and page.Visible then
        return
    end

    self:PlaySound("TabSwitch")

    for _, p in pairs(STATE.ContentPages) do
        if p ~= page then p.Visible = false end
    end
    page.Visible = true
    STATE.ActiveTab = tabName

    local scale = page:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale", page)
    end
    scale.Scale = 0.94
    page.Position = UDim2.new(0, 25, 0, 0)
    page.BackgroundTransparency = 1

    TweenService:Create(scale,
        TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Scale = 1}
    ):Play()
    TweenService:Create(page,
        TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 0, 0, 0)}
    ):Play()

    local saved = STATE.SavedScrollPositions[tabName]
    if saved then
        task.defer(function()
            for _ = 1, 3 do
                task.wait(0.05)
                if page.Parent then page.CanvasPosition = saved end
            end
        end)
    end

    self:_applySearchFilter(tabName)
    if STATE.SubTabBar and ownerCat then
        pcall(function() STATE.SubTabBar:SetActiveSub(ownerCat, tabName) end)
    end
end

function Library:CreateSection(tabName, title, summary, defaultOpen, columnName, iconName)
    if self:_isDead() then return end
    if type(title) ~= "string" or title == "" then
        error("[DoD UI] CreateSection requires a non-empty title.")
    end
    if summary ~= nil and type(summary) ~= "string" then
        error("[DoD UI] CreateSection summary must be a string or nil.")
    end
    if columnName ~= nil and columnName ~= "Left" and columnName ~= "Right" then
        error("[DoD UI] CreateSection column must be 'Left' or 'Right'.")
    end
    columnName = columnName or "Left"
    local hasIcon = iconName ~= nil and iconName ~= ""
    local labelOffset = hasIcon and 42 or 16
    local labelWidth = hasIcon and -76 or -50

    local columns = self._STATE.TabColumns[tabName]
    if not columns then
        error("[DoD UI] Tab '" .. tostring(tabName) .. "' not found. Call :CreateTab first.")
    end
    local parentCol = columns[columnName]

    local sectionOrder = #parentCol:GetChildren() + 1
    local HEADER_HEIGHT = 50

    local section = Instance.new("Frame", parentCol)
    section.Name = (title:gsub("%W", "") or "") .. "Section"
    section.LayoutOrder = sectionOrder
    section.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
    section.BackgroundColor3 = self._Colors.Card
    section.BackgroundTransparency = self._STATE.SectionTransparency or 0.15
    section.BorderSizePixel = 0
    section.ClipsDescendants = true
    Instance.new("UICorner", section).CornerRadius = UDim.new(0, 12) -- Softer corners

    local cardStroke = Instance.new("UIStroke", section)
    cardStroke.Color = self._Colors.Border
    cardStroke.Thickness = 1
    cardStroke.Transparency = 0.4

    local header = Instance.new("TextButton", section)
    header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    Fn.bindPressAnimation(header)

    local sectionIcon
    if hasIcon then
        sectionIcon = Instance.new("ImageLabel", header)
        sectionIcon.Name = "SectionIcon"
        sectionIcon.Size = UDim2.fromOffset(18, 18)
        sectionIcon.Position = UDim2.new(0, 16, 0, 10)
        sectionIcon.BackgroundTransparency = 1
        sectionIcon.Image = GetIcon(iconName)
        sectionIcon.ImageColor3 = self._Colors.Accent
        sectionIcon.ScaleType = Enum.ScaleType.Fit
    end

    local titleLabel = Instance.new("TextLabel", header)
    titleLabel.Size = UDim2.new(1, labelWidth, 0, 18)
    titleLabel.Position = UDim2.new(0, labelOffset, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = self._Colors.Text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local summaryLabel = Instance.new("TextLabel", header)
    summaryLabel.Size = UDim2.new(1, labelWidth, 0, 14)
    summaryLabel.Position = UDim2.new(0, labelOffset, 0, 28)
    summaryLabel.BackgroundTransparency = 1
    summaryLabel.Text = summary or ""
    summaryLabel.TextColor3 = self._Colors.TextDim
    summaryLabel.Font = Enum.Font.GothamMedium
    summaryLabel.TextSize = 10
    summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
    summaryLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local indicator = Instance.new("ImageLabel", header)
    indicator.Name = "ExpandIndicator"
    indicator.Size = UDim2.fromOffset(16, 16)
    indicator.AnchorPoint = Vector2.new(0.5, 0.5)
    indicator.Position = UDim2.new(1, -26, 0.5, 0)
    indicator.BackgroundTransparency = 1
    indicator.Image = GetIcon(defaultOpen and "arrow-up" or "arrow-down")
    indicator.ImageColor3 = defaultOpen and self._Colors.Accent or self._Colors.TextDim
    indicator.ScaleType = Enum.ScaleType.Fit

    local hoverBar = Instance.new("Frame", section)
    hoverBar.Name = "HoverBar"
    hoverBar.AnchorPoint = Vector2.new(0, 0.5)
    hoverBar.Position = UDim2.new(0, 0, 0.5, 0)
    hoverBar.Size = UDim2.new(0, 3, 1, -32)
    hoverBar.BackgroundColor3 = self._Colors.Accent
    hoverBar.BackgroundTransparency = 1
    hoverBar.BorderSizePixel = 0
    hoverBar.ZIndex = 5
    Instance.new("UICorner", hoverBar).CornerRadius = UDim.new(1, 0)

    local separator = Instance.new("Frame", section)
    separator.Size = UDim2.new(1, -32, 0, 1)
    separator.Position = UDim2.new(0, 16, 0, HEADER_HEIGHT)
    separator.BackgroundColor3 = self._Colors.Border
    separator.BackgroundTransparency = 1
    separator.BorderSizePixel = 0

    local body = Instance.new("ScrollingFrame", section)
    body.Size = UDim2.new(1, 0, 0, 0)
    body.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.ClipsDescendants = true
    body.Visible = false
    body.ScrollBarThickness = 0
    body.ScrollingDirection = Enum.ScrollingDirection.Y
    body.ElasticBehavior = self._isMobile and Enum.ElasticBehavior.WhenScrollable or Enum.ElasticBehavior.Never
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.CanvasSize = UDim2.new(0, 0, 0, 0)
    body.VerticalScrollBarInset = Enum.ScrollBarInset.None
    body.HorizontalScrollBarInset = Enum.ScrollBarInset.None
    self:_registerScrollFrame(body)

    local bodyLayout = Instance.new("UIListLayout", body)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Padding = UDim.new(0, self:_densityPadding(8))

    local bodyPad = Instance.new("UIPadding", body)
    bodyPad.PaddingLeft = UDim.new(0, 12)
    bodyPad.PaddingRight = UDim.new(0, 20)
    bodyPad.PaddingTop = UDim.new(0, 10)
    bodyPad.PaddingBottom = UDim.new(0, 14)

    local scrollTrack = Instance.new("Frame", section)
    scrollTrack.Name = "ScrollTrack"
    scrollTrack.AnchorPoint = Vector2.new(0.5, 0)
    scrollTrack.Position = UDim2.new(1, -10, 0, HEADER_HEIGHT + 14)
    scrollTrack.Size = UDim2.fromOffset(3, 0)
    scrollTrack.BackgroundColor3 = self._Colors.Border
    scrollTrack.BackgroundTransparency = 0.75
    scrollTrack.BorderSizePixel = 0
    scrollTrack.ZIndex = 6
    scrollTrack.Visible = false
    Instance.new("UICorner", scrollTrack).CornerRadius = UDim.new(1, 0)

    local scrollThumb = Instance.new("Frame", scrollTrack)
    scrollThumb.Name = "ScrollThumb"
    scrollThumb.Size = UDim2.new(1, 0, 0.3, 0)
    scrollThumb.Position = UDim2.new(0, 0, 0, 0)
    scrollThumb.BackgroundColor3 = self._Colors.Accent
    scrollThumb.BorderSizePixel = 0
    scrollThumb.ZIndex = 7
    Instance.new("UICorner", scrollThumb).CornerRadius = UDim.new(1, 0)

    local scrollThumbGlow = Instance.new("Frame", scrollThumb)
    scrollThumbGlow.Name = "ThumbGlow"
    scrollThumbGlow.Size = UDim2.new(1, 8, 1, 0)
    scrollThumbGlow.Position = UDim2.new(0, -4, 0, 0)
    scrollThumbGlow.BackgroundColor3 = self._Colors.Accent
    scrollThumbGlow.BackgroundTransparency = 0.7
    scrollThumbGlow.BorderSizePixel = 0
    scrollThumbGlow.ZIndex = 6
    Instance.new("UICorner", scrollThumbGlow).CornerRadius = UDim.new(1, 0)

    local expanded = defaultOpen == true
    local currentTween
    local sectionData = {
        tabName = tabName,
        title = title,
        summary = summary or "",
        section = section,
        parentColumn = parentCol,
        controls = {},
        expanded = expanded,
        searching = false,
    }
    self._STATE.SearchSections[tabName] = self._STATE.SearchSections[tabName] or {}
    table.insert(self._STATE.SearchSections[tabName], sectionData)
    self._STATE.SearchBodies[body] = sectionData

    local function updateScrollIndicator()
        if not body or not body.Parent then return end
        if not expanded then
            scrollTrack.Visible = false
            return
        end
        local maxScroll = math.max(0, body.AbsoluteCanvasSize.Y - body.AbsoluteSize.Y)
        if maxScroll <= 2 then
            scrollTrack.Visible = false
            return
        end
        scrollTrack.Visible = true
        local bodyH = body.AbsoluteSize.Y
        if bodyH <= 0 then return end
        local trackH = math.max(28, bodyH - 20)
        scrollTrack.Size = UDim2.fromOffset(3, trackH)
        local canvasH = math.max(1, body.AbsoluteCanvasSize.Y)
        local ratio = math.clamp(body.CanvasPosition.Y / maxScroll, 0, 1)
        local thumbRatio = math.clamp(bodyH / canvasH, 0.12, 1)
        local thumbH = math.max(22, trackH * thumbRatio)
        scrollThumb.Size = UDim2.new(1, 0, 0, thumbH)
        local maxThumbY = math.max(0, trackH - thumbH)
        scrollThumb.Position = UDim2.new(0, 0, 0, ratio * maxThumbY)
    end

    local function updateHeight(animate)
        if not body or not body.Parent then return end
        local innerH = bodyLayout.AbsoluteContentSize.Y
        local contentH = (innerH > 0) and (innerH + 24) or 24
        local maxH = 450
        local contentArea = self._UI.ContentArea
        if contentArea and contentArea.AbsoluteSize.Y > 0 then
            maxH = math.min(450, math.max(240, contentArea.AbsoluteSize.Y - 40))
        end
        local cappedH = math.min(contentH, maxH)
        local targetH = expanded and (HEADER_HEIGHT + cappedH) or HEADER_HEIGHT
        if expanded then
            body.Size = UDim2.new(1, 0, 0, cappedH)
        end
        if currentTween then currentTween:Cancel() end
        if animate == false then
            section.Size = UDim2.new(1, 0, 0, targetH)
        else
            currentTween = TweenService:Create(section,
                TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {Size = UDim2.new(1, 0, 0, targetH)})
            currentTween:Play()
            if not expanded then
                local cap = currentTween
                cap.Completed:Connect(function()
                    if not expanded and body then body.Visible = false end
                    updateScrollIndicator()
                end)
            end
        end
        TweenService:Create(separator, TweenInfo.new(0.2), {
            BackgroundTransparency = expanded and 0.6 or 1
        }):Play()
        indicator.Image = GetIcon(expanded and "arrow-up" or "arrow-down")
        TweenService:Create(indicator,
            TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                ImageColor3 = expanded and self._Colors.Accent or self._Colors.TextDim,
            }):Play()
        updateScrollIndicator()
        task.defer(updateScrollIndicator)
    end

    local function toggle(forceState)
        if forceState ~= nil then expanded = forceState
        else expanded = not expanded end
        sectionData.expanded = expanded
        if expanded then
            body.Visible = true
            task.defer(function() updateHeight(true) end)
        else
            updateHeight(true)
        end
    end

    sectionData.setExpanded = function(isExpanded)
        expanded = isExpanded
        sectionData.expanded = expanded
        body.Visible = expanded
        if expanded then
            task.defer(function() updateHeight(false) end)
        else
            updateHeight(false)
        end
    end

    bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if expanded then updateHeight(true) end
    end)

    body:GetPropertyChangedSignal("CanvasPosition"):Connect(updateScrollIndicator)
    body:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateScrollIndicator)
    body:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScrollIndicator)

    -- No per-section listener on ContentArea.AbsoluteSize: every section used to
    -- register one, so a window resize produced N layout flushes per frame. The
    -- body's own AbsoluteContentSize signal already keeps the height correct.

    header.MouseEnter:Connect(function()
        local baseTrans = self._STATE.SectionTransparency or 0.15
        TweenService:Create(section, TweenInfo.new(0.18),
            {BackgroundColor3 = self._Colors.CardHover, BackgroundTransparency = math.max(0, baseTrans - 0.1)}):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.22),
            {Color = self._Colors.Accent, Transparency = 0.25}):Play()
        TweenService:Create(hoverBar, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.15}):Play()
        if sectionIcon then
            TweenService:Create(sectionIcon, TweenInfo.new(0.22),
                {ImageColor3 = self._Colors.Accent}):Play()
        end
    end)
    header.MouseLeave:Connect(function()
        local baseTrans = self._STATE.SectionTransparency or 0.15
        TweenService:Create(section, TweenInfo.new(0.18),
            {BackgroundColor3 = self._Colors.Card, BackgroundTransparency = baseTrans}):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.22),
            {Color = self._Colors.Border, Transparency = 0.4}):Play()
        TweenService:Create(hoverBar, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}):Play()
        if sectionIcon then
            TweenService:Create(sectionIcon, TweenInfo.new(0.22),
                {ImageColor3 = self._Colors.Accent}):Play()
        end
    end)

    local lastToggleTime = 0
    header.MouseButton1Up:Connect(function()
        local now = os.clock()
        if now - lastToggleTime < 0.18 then return end
        lastToggleTime = now
        toggle()
    end)

    if expanded then
        body.Visible = true
        task.spawn(function()
            task.wait(0.08)
            updateHeight(false)
        end)
    end

    self:_registerThemeRefresher(function()
        section.BackgroundColor3 = self._Colors.Card
        section.BackgroundTransparency = self._STATE.SectionTransparency or 0.15
        cardStroke.Color = self._Colors.Border
        titleLabel.TextColor3 = self._Colors.Text
        summaryLabel.TextColor3 = self._Colors.TextDim
        if sectionIcon then sectionIcon.ImageColor3 = self._Colors.Accent end
        indicator.Image = GetIcon(expanded and "arrow-up" or "arrow-down")
        indicator.ImageColor3 = expanded and self._Colors.Accent or self._Colors.TextDim
        separator.BackgroundColor3 = self._Colors.Border
        if hoverBar then
            hoverBar.BackgroundColor3 = self._Colors.Accent
        end
        if scrollTrack then
            scrollTrack.BackgroundColor3 = self._Colors.Border
        end
        if scrollThumb then
            scrollThumb.BackgroundColor3 = self._Colors.Accent
        end
        if scrollThumbGlow then
            scrollThumbGlow.BackgroundColor3 = self._Colors.Accent
        end
    end)

    self:_queueSearchFilter(tabName)
    return self:_wrapSection(body)
end

-- Helper for backwards compatibility
function Library:CreateColumnSection(tabName, title, summary, defaultOpen)
    if self:_isDead() then return end
    local body = self:_unwrap(self:CreateSection(tabName, title, summary, defaultOpen))
    local row = Instance.new("Frame", body)
    row.Name = "Columns"
    row.LayoutOrder = 1
    row.Size = UDim2.new(1, 0, 0, 0)
    row.BackgroundTransparency = 1
    row.AutomaticSize = Enum.AutomaticSize.Y

    local function createColumn(name, xPosition)
        local column = Instance.new("Frame", row)
        column.Name = name
        column.Size = UDim2.new(0.5, -6, 0, 0)
        column.Position = UDim2.new(xPosition, xPosition == 0 and 0 or 6, 0, 0)
        column.BackgroundTransparency = 1
        column.AutomaticSize = Enum.AutomaticSize.Y
        local layout = Instance.new("UIListLayout", column)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        local padding = Instance.new("UIPadding", column)
        padding.PaddingLeft = UDim.new(0, 4)
        padding.PaddingRight = UDim.new(0, 4)
        padding.PaddingTop = UDim.new(0, 1)
        padding.PaddingBottom = UDim.new(0, 1)
        return column
    end

    local leftColumn = createColumn("LeftColumn", 0)
    local rightColumn = createColumn("RightColumn", 0.5)
    return self:_wrapSection(leftColumn), self:_wrapSection(rightColumn)
end

function Library:CreateDashboardBanner(tabName)
    if self:_isDead() then return end
    local topContainer = self._STATE.TabTopContainers[tabName]
    if not topContainer then
        error("[DoD UI] Tab '" .. tostring(tabName) .. "' not found. Call :CreateTab first.")
    end

    local function GetGreeting()
        local h = tonumber(os.date("%H")) or 12
        if h >= 5 and h < 12 then return "Good Morning"
        elseif h >= 12 and h < 17 then return "Good Afternoon"
        elseif h >= 17 and h < 20 then return "Good Evening"
        else return "Good Night" end
    end

    local PlayerCard = Instance.new("Frame", topContainer)
    PlayerCard.Name = "PlayerGreetingCard"
    PlayerCard.LayoutOrder = #topContainer:GetChildren() + 1
    PlayerCard.Size = UDim2.new(1, 0, 0, 68)
    PlayerCard.BackgroundColor3 = self._Colors.Card
    PlayerCard.BorderSizePixel = 0
    Instance.new("UICorner", PlayerCard).CornerRadius = UDim.new(0, 12)
    local pcStroke = Instance.new("UIStroke", PlayerCard)
    pcStroke.Color = self._Colors.Border
    pcStroke.Thickness = 1

    local AvatarImg = Instance.new("ImageLabel", PlayerCard)
    AvatarImg.Size = UDim2.new(0, 46, 0, 46)
    AvatarImg.Position = UDim2.new(0, 12, 0.5, -23)
    AvatarImg.BackgroundTransparency = 1
    AvatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150&filters=circular"
    Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)
    local avStroke = Instance.new("UIStroke", AvatarImg)
    avStroke.Color = self._Colors.Border
    avStroke.Thickness = 1

    local GreetLabel = Instance.new("TextLabel", PlayerCard)
    GreetLabel.Size = UDim2.new(0.5, -70, 0, 14)
    GreetLabel.Position = UDim2.new(0, 68, 0, 14)
    GreetLabel.BackgroundTransparency = 1
    GreetLabel.Font = Enum.Font.GothamMedium
    GreetLabel.TextSize = 10.5
    GreetLabel.TextColor3 = self._Colors.TextDim
    GreetLabel.TextXAlignment = Enum.TextXAlignment.Left
    GreetLabel.Text = GetGreeting()

    local NameLabel = Instance.new("TextLabel", PlayerCard)
    NameLabel.Size = UDim2.new(0.5, -70, 0, 22)
    NameLabel.Position = UDim2.new(0, 68, 0, 30)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.TextSize = 16
    NameLabel.TextColor3 = self._Colors.Text
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Text = LocalPlayer.DisplayName or LocalPlayer.Name

    local ClockLabel = Instance.new("TextLabel", PlayerCard)
    ClockLabel.Size = UDim2.new(0.5, 0, 0, 24)
    ClockLabel.Position = UDim2.new(0.5, -16, 0, 11)
    ClockLabel.BackgroundTransparency = 1
    ClockLabel.Font = Enum.Font.GothamBold
    ClockLabel.TextSize = 20
    ClockLabel.TextColor3 = self._Colors.Text
    ClockLabel.TextXAlignment = Enum.TextXAlignment.Right
    ClockLabel.Text = os.date("%H:%M:%S")

    local DateLabel = Instance.new("TextLabel", PlayerCard)
    DateLabel.Size = UDim2.new(0.45, 0, 0, 14)
    DateLabel.Position = UDim2.new(0.55, -16, 0, 38)
    DateLabel.BackgroundTransparency = 1
    DateLabel.Font = Enum.Font.GothamMedium
    DateLabel.TextSize = 10.5
    DateLabel.TextColor3 = self._Colors.TextDim
    DateLabel.TextXAlignment = Enum.TextXAlignment.Right
    DateLabel.Text = os.date("%d / %m / %Y")

    local placeName = "Roblox Experience"
    local creatorName = "Roblox Studio"
    local resolvedGameIcon = ""
    -- The product lookup is an HTTP call: running it inline froze the whole UI
    -- build for 1-3 seconds. Resolve it from a spawned thread further below and
    -- patch the labels once it lands.
    if resolvedGameIcon == "" then
        local universeId = (game.GameId and tonumber(game.GameId) and tonumber(game.GameId) > 0) and game.GameId or nil
        if universeId then
            resolvedGameIcon = "rbxthumb://type=GameIcon&id=" .. tostring(universeId) .. "&w=150&h=150"
        else
            resolvedGameIcon = "rbxthumb://type=Asset&id=" .. tostring(game.PlaceId) .. "&w=150&h=150"
        end
    end

    local GameCard = Instance.new("Frame", topContainer)
    GameCard.Name = "GameServerCard"
    GameCard.LayoutOrder = #topContainer:GetChildren() + 1
    GameCard.Size = UDim2.new(1, 0, 0, 86)
    GameCard.BackgroundColor3 = self._Colors.Card
    GameCard.BorderSizePixel = 0
    Instance.new("UICorner", GameCard).CornerRadius = UDim.new(0, 14)
    local gcStroke = Instance.new("UIStroke", GameCard)
    gcStroke.Color = self._Colors.Border
    gcStroke.Thickness = 1

    local BannerImg = Instance.new("ImageLabel", GameCard)
    BannerImg.Name = "MapBanner"
    BannerImg.AnchorPoint = Vector2.new(1, 0)
    BannerImg.Position = UDim2.new(1, 0, 0, 0)
    BannerImg.Size = UDim2.new(0.65, 0, 1, 0)
    BannerImg.BackgroundTransparency = 1
    BannerImg.ScaleType = Enum.ScaleType.Crop
    BannerImg.Image = resolvedGameIcon
    BannerImg.ImageTransparency = 0.70
    BannerImg.ZIndex = 1
    Instance.new("UICorner", BannerImg).CornerRadius = UDim.new(0, 14)

    local bGrad = Instance.new("UIGradient", BannerImg)
    bGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.35, 0.82),
        NumberSequenceKeypoint.new(1, 0.35)
    })

    local GameThumb = Instance.new("ImageLabel", GameCard)
    GameThumb.Size = UDim2.new(0, 60, 0, 60)
    GameThumb.Position = UDim2.new(0, 12, 0.5, -30)
    GameThumb.BackgroundColor3 = self._Colors.Bg2
    GameThumb.BackgroundTransparency = 0.1
    GameThumb.ScaleType = Enum.ScaleType.Fit
    GameThumb.Image = resolvedGameIcon
    GameThumb.ZIndex = 3
    Instance.new("UICorner", GameThumb).CornerRadius = UDim.new(0, 14)
    local gtStroke = Instance.new("UIStroke", GameThumb)
    gtStroke.Color = self._Colors.Border
    gtStroke.Thickness = 1

    local GameTitleLbl = Instance.new("TextLabel", GameCard)
    GameTitleLbl.Size = UDim2.new(1, -90, 0, 18)
    GameTitleLbl.Position = UDim2.new(0, 84, 0, 12)
    GameTitleLbl.BackgroundTransparency = 1
    GameTitleLbl.Font = Enum.Font.GothamBold
    GameTitleLbl.TextSize = 14
    GameTitleLbl.TextColor3 = self._Colors.Text
    GameTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    GameTitleLbl.Text = placeName
    GameTitleLbl.ZIndex = 3

    local GameSubLbl = Instance.new("TextLabel", GameCard)
    GameSubLbl.Size = UDim2.new(1, -90, 0, 14)
    GameSubLbl.Position = UDim2.new(0, 84, 0, 32)
    GameSubLbl.BackgroundTransparency = 1
    GameSubLbl.Font = Enum.Font.Gotham
    GameSubLbl.TextSize = 9.5
    GameSubLbl.TextColor3 = self._Colors.TextDim
    GameSubLbl.TextXAlignment = Enum.TextXAlignment.Left
    GameSubLbl.Text = "by " .. ((creatorName and creatorName ~= "") and creatorName or "Roblox Creator")
    GameSubLbl.ZIndex = 3

    task.spawn(function()
        local ok = pcall(function()
            local info = MarketplaceService:GetProductInfo(game.PlaceId)
            if not info or self:_isDead() then return end
            if info.Name and info.Name ~= "" then
                placeName = info.Name
                if GameTitleLbl.Parent then GameTitleLbl.Text = placeName end
            end
            if info.Creator and info.Creator.Name and info.Creator.Name ~= "" then
                creatorName = info.Creator.Name
                if GameSubLbl.Parent then
                    GameSubLbl.Text = "by " .. creatorName
                end
            end
            if info.IconImageAssetId and tonumber(info.IconImageAssetId) and tonumber(info.IconImageAssetId) > 0 then
                local iconUrl = "rbxassetid://" .. tostring(info.IconImageAssetId)
                if BannerImg.Parent then BannerImg.Image = iconUrl end
                if GameThumb.Parent then GameThumb.Image = iconUrl end
            end
        end)
        if not ok then
            -- Network unavailable or throttled: placeholders stay, which is fine.
        end
    end)

    local PillsRow = Instance.new("Frame", GameCard)
    PillsRow.Size = UDim2.new(1, -90, 0, 22)
    PillsRow.Position = UDim2.new(0, 84, 0, 52)
    PillsRow.BackgroundTransparency = 1
    PillsRow.ZIndex = 3

    local prLayout = Instance.new("UIListLayout", PillsRow)
    prLayout.FillDirection = Enum.FillDirection.Horizontal
    prLayout.Padding = UDim.new(0, 6)

    local function MakePill(iconName, initialText, minW)
        local p = Instance.new("Frame", PillsRow)
        p.AutomaticSize = Enum.AutomaticSize.X
        p.Size = UDim2.new(0, minW or 70, 0, 22)
        p.BackgroundColor3 = self._Colors.Bg2
        p.BackgroundTransparency = 0.3
        Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)

        local ps = Instance.new("UIStroke", p)
        ps.Color = self._Colors.Border
        ps.Thickness = 1
        ps.Transparency = 0.6

        local gradient = Instance.new("UIGradient", p)
        gradient.Rotation = 90
        gradient.Color = ColorSequence.new(self._Colors.Bg2, self._Colors.Bg)

        local layout = Instance.new("UIListLayout", p)
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        layout.VerticalAlignment = Enum.VerticalAlignment.Center

        local pad = Instance.new("UIPadding", p)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 10)
        pad.PaddingTop = UDim.new(0, 2)
        pad.PaddingBottom = UDim.new(0, 2)

        local icon = Instance.new("ImageLabel", p)
        icon.LayoutOrder = 1
        icon.Size = UDim2.fromOffset(12, 12)
        icon.BackgroundTransparency = 1
        icon.Image = GetIcon(iconName)
        icon.ImageColor3 = self._Colors.Accent
        icon.ScaleType = Enum.ScaleType.Fit

        local t = Instance.new("TextLabel", p)
        t.LayoutOrder = 2
        t.AutomaticSize = Enum.AutomaticSize.X
        t.Size = UDim2.new(0, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.GothamBold
        t.TextSize = 9
        t.TextColor3 = self._Colors.Text
        t.Text = initialText
        t.TextXAlignment = Enum.TextXAlignment.Left

        return { Frame = p, Stroke = ps, Label = t, Icon = icon, Gradient = gradient }
    end

    local pillId = MakePill("id-card", "ID " .. tostring(game.PlaceId), 90)
    local pillPl = MakePill("users", tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers), 60)
    local pillPing = MakePill("wifi", "35 ms", 55)
    local pillFps = MakePill("zap", "60 FPS", 65)

    task.spawn(function()
        local frames = 0
        local timeElapsed = 0
        local fpsConn = RunService.RenderStepped:Connect(function(dt)
            -- Only sample while the banner is actually on screen (open window and
            -- visible tab); it used to run for the whole session.
            if not PlayerCard.Visible then return end
            if not self._STATE.GuiVisible then return end
            frames = frames + 1
            timeElapsed = timeElapsed + dt
            if timeElapsed >= 0.5 then
                local fps = math.floor(frames / timeElapsed + 0.5)
                pillFps.Label.Text = tostring(fps) .. " FPS"
                frames = 0
                timeElapsed = 0
            end
        end)

        while task.wait(0.25) do
            if not PlayerCard or not PlayerCard.Parent then
                fpsConn:Disconnect()
                break
            end
            if not PlayerCard.Visible or not self._STATE.GuiVisible then
                continue
            end
            ClockLabel.Text = os.date("%H:%M:%S")
            DateLabel.Text = os.date("%d / %m / %Y")
            GreetLabel.Text = GetGreeting()
            pillPl.Label.Text = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers)
            pcall(function()
                local p = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                pillPing.Label.Text = tostring(p) .. " ms"
            end)
        end
    end)

    self:_registerThemeRefresher(function()
        PlayerCard.BackgroundColor3 = self._Colors.Card
        pcStroke.Color = self._Colors.Border
        avStroke.Color = self._Colors.Border
        GreetLabel.TextColor3 = self._Colors.TextDim
        NameLabel.TextColor3 = self._Colors.Text
        ClockLabel.TextColor3 = self._Colors.Text
        DateLabel.TextColor3 = self._Colors.TextDim
        GameCard.BackgroundColor3 = self._Colors.Card
        gcStroke.Color = self._Colors.Border
        GameThumb.BackgroundColor3 = self._Colors.Bg2
        gtStroke.Color = self._Colors.Border
        GameTitleLbl.TextColor3 = self._Colors.Text
        GameSubLbl.TextColor3 = self._Colors.TextDim
        for _, pill in ipairs({pillId, pillPl, pillPing, pillFps}) do
            pill.Frame.BackgroundColor3 = self._Colors.Bg2
            pill.Stroke.Color = self._Colors.Border
            pill.Label.TextColor3 = self._Colors.Text
            if pill.Icon then
                pill.Icon.ImageColor3 = self._Colors.Accent
            end
            if pill.Gradient then
                pill.Gradient.Color = ColorSequence.new(self._Colors.Bg2, self._Colors.Bg)
            end
        end
    end)

    return GameCard
end

function Library:CreateThemeCustomizer(tabName)
    if self:_isDead() then return end
    local section = self:CreateSection(
        tabName,
        "Theme Customizer",
        "Adjust appearance and effects live",
        true
    )
    local _perfDefault = 1
    if self._perfAuto == false then
        _perfDefault = (self._perfTier == "Potato" and 2) or (self._perfTier == "Balanced" and 3) or 4
    end
    self._perfDropdown = self:AddDropdown(section, "Performance Mode", { "Auto", "Potato", "Balanced", "High" },
        _perfDefault,
        function(_, val)
            if val == "Auto" then
                self._perfAuto = true
                local _t = self:_detectPerfTier()
                self:SetPerformanceTier(_t, true)
                self:Notify("PERFORMANCE", "Auto mode active", "info")
            else
                self._perfAuto = false
                self:SetPerformanceTier(val, false)
            end
        end
    )
    local themeIndex = table.find(D.ThemeNames, self.ThemeName) or 1
    self:AddDropdown(section, "Theme", D.ThemeNames, themeIndex, function(_, themeName)
        self._AccentOverride = nil
        self:SetTheme(themeName)
    end)
    
    local iconOptions = {
        "hexagon", "shield", "sword", "ghost", "skull", "crown", "star", 
        "zap", "flame", "diamond", "gem", "target", "crosshair", "eye", 
        "settings", "wrench", "cog", "command", "activity", "cpu", 
        "database", "terminal", "box", "package", "layers", "gamepad-2",
        "bot", "user", "users", "infinity", "orbit", "atom", "sparkles"
    }
    local currentIcon = self._TitleIconName or "hexagon"
    local iconIndex = table.find(iconOptions, currentIcon) or 1
    
    self:AddDropdown(section, "Title Icon", iconOptions, iconIndex, function(_, val)
        self:SetTitleIcon(val)
        self._TitleIconName = val
    end)
    
    self:AddTextbox(section, "Custom Title Icon", "Lucide Name / ID / URL", function(txt)
        if txt and txt ~= "" then
            self:SetTitleIcon(txt)
            self._TitleIconName = txt
        end
    end)
    self:AddColorPicker(section, "Accent color", self._Colors.Accent, function(color)
        self:SetAccentColor(color)
    end)
    self:AddDropdown(section, "Focus overlay pattern", D.FocusOverlayTypes,
        math.max(1, table.find(D.FocusOverlayTypes, self._STATE.FocusOverlayType) or 2),
        function(_, overlayType)
            self:SetFocusOverlay(self._STATE.FocusOverlayEnabled, overlayType)
        end
    )
    self:AddToggle(section, "Focus overlay", self._STATE.FocusOverlayEnabled, function(enabled)
        self:SetFocusOverlay(enabled, self._STATE.FocusOverlayType)
    end)
    self:AddToggle(section, "Acrylic blur", self.Acrylic, function(enabled)
        self:SetAcrylic(enabled)
    end)
    self:AddSlider(section, "Blur intensity", 0, 24, self.AcrylicBlurIntensity, 0, function(value)
        self:SetAcrylicIntensity(value)
    end)
    local wallpaperBaseUrl = "https://raw.githubusercontent.com/rapzxcwxcorparation/DemonOfDarknessUI/refs/heads/main/wallpaperdod/"
    local wallpaperOptions = {
        "None",
        "chika-fujiwara-3840x2160-16148.jpg",
        "h1-key-lovechapter-3840x2160-25940.jpg",
        "itachi-uchiha-3840x2160-25721.jpg",
        "kawaii-cat-girl-3840x2160-26545.png",
        "miles-morales-3840x2160-25975.jpg",
        "thumb-1920-1394067.png",
        "daemons.wtf.png",
        "miside-mita-dark-3840x2160-21051.jpg",
        "wp15319350-4k-anime-girl-eyes-wallpapers.jpg"
    }

    local currentWallpaperIndex = 1
    local wpName = tostring(self.WallpaperSource or "")
    for i, name in ipairs(wallpaperOptions) do
        if wpName:find(name, 1, true) or (self._UI.Wallpaper and self._UI.Wallpaper.Image and string.find(tostring(self._UI.Wallpaper.Image), name, 1, true)) then
            currentWallpaperIndex = i
            break
        end
    end

    local _pendingWallpaper = self.WallpaperSource

    self:AddDropdown(section, "Wallpaper Image", wallpaperOptions, currentWallpaperIndex, function(idx, val)
        if val == "None" then
            _pendingWallpaper = nil
            self:SetWallpaper(nil)
            self.WallpaperSource = nil
        else
            local fullUrl = wallpaperBaseUrl .. val
            _pendingWallpaper = fullUrl
            self:SetWallpaper(fullUrl, self.WallpaperTransparency or 0)
            self.WallpaperSource = fullUrl
        end
    end)

    self:AddButton(section, "Re-apply Wallpaper", function()
        if _pendingWallpaper then
            self:SetWallpaper(_pendingWallpaper, self.WallpaperTransparency or 0)
        else
            self:Notify("WALLPAPER", "Pilih wallpaper dulu di dropdown", "info")
        end
    end)

    self:AddButton(section, "Remove Wallpaper", function()
        self:SetWallpaper(nil)
        self.WallpaperSource = nil
        _pendingWallpaper = nil
        self:Notify("WALLPAPER", "Wallpaper dihapus", "info")
    end)
    
    self:AddTextbox(section, "Custom Image URL", "https://raw.github.../image.png", function(txt)
        if txt and txt ~= "" then
            _pendingWallpaper = txt
            self:SetWallpaper(txt, self.WallpaperTransparency or 0)
            self.WallpaperSource = txt
        end
    end)

    self:AddSlider(section, "Wallpaper Transparency", 0, 1, self.WallpaperTransparency or 0, 2, function(value)
        self.WallpaperTransparency = value
        if self._UI.Wallpaper and self._UI.Wallpaper.Visible then
            self._UI.Wallpaper.ImageTransparency = math.clamp(value, 0, 1)
        end
    end)

    self:AddDropdown(section, "Weather effect", D.WeatherTypes,
        table.find(D.WeatherTypes, self._STATE.WeatherType) or 1,
        function(_, weatherType)
            if self._STATE.WeatherEnabled then
                self:SetWeather(true, weatherType, self._STATE.WeatherIntensity)
            else
                self._STATE.WeatherType = weatherType
            end
        end
    )
    local weatherIntensity = math.clamp(tonumber(self._STATE.WeatherIntensity) or 65, 0, 100)
    self:AddSlider(section, "Weather intensity", 0, 100, weatherIntensity, 0, function(value)
        self:SetWeather(self._STATE.WeatherEnabled, self._STATE.WeatherType, value)
    end)
    self:AddToggle(section, "Weather effects", self._STATE.WeatherEnabled, function(enabled)
        self:SetWeather(enabled, self._STATE.WeatherType, self._STATE.WeatherIntensity)
    end)
    self:AddToggle(section, "UI Sounds", self._SoundsEnabled, function(enabled)
        self:SetSoundsEnabled(enabled)
    end)
    self:AddSlider(section, "Sound Volume", 0, 1, self._SoundVolume or 1, 2, function(value)
        self:SetSoundVolume(value)
    end)
    self:AddToggle(section, "Reduced Motion", self._STATE.ReducedMotion or false, function(enabled)
        self:SetReducedMotion(enabled)
    end)
    self:AddToggle(section, "Cursor Trail", self._cursorTrailEnabled or false, function(enabled)
        self:SetCursorTrail(enabled)
    end)
    self:AddColorPicker(section, "Cursor Trail Color", self._cursorTrailColor or Color3.fromRGB(0, 255, 255), function(color)
        self:SetCursorTrailColor(color)
    end)
    local _densityIdx = 2
    local _curDensity = self._STATE.LayoutDensity or "Normal"
    if _curDensity == "Compact" then _densityIdx = 1
    elseif _curDensity == "Spacious" then _densityIdx = 3 end
    self:AddDropdown(section, "Layout Density", { "Compact", "Normal", "Spacious" }, _densityIdx, function(idx, val)
        self:SetLayoutDensity(val)
    end)
    self:AddSlider(section, "Section Transparency", 0, 1, self._STATE.SectionTransparency or 0.15, 2, function(value)
        self:SetSectionTransparency(value)
    end)
    local notifPositionLabels = { "Top Right", "Top Left", "Bottom Right", "Bottom Left" }
    local notifPositionKeys = { "TopRight", "TopLeft", "BottomRight", "BottomLeft" }
    local notifCurrentKey = self._NotifPosition or "TopRight"
    local notifCurrentIdx = 1
    for i, key in ipairs(notifPositionKeys) do
        if key == notifCurrentKey then notifCurrentIdx = i; break end
    end
    self:AddDropdown(section, "Notification Position", notifPositionLabels, notifCurrentIdx, function(idx, _)
        self:SetNotificationPosition(notifPositionKeys[idx])
    end)
    self:AddToggle(section, "Tooltip", self._STATE.TooltipEnabled ~= false, function(enabled)
        self:SetTooltipEnabled(enabled)
    end)
    self:AddSlider(section, "Tooltip Background Transparency", 0, 1, self._STATE.TooltipTransparency or 0.15, 2, function(value)
        self:SetTooltipTransparency(value)
    end)
    self:AddButton(section, "Clear Wallpaper Cache", function()
        self:ClearWallpaperCache()
    end)
    self:AddButton(section, "Save Theme Settings", function()
        self:SaveThemeConfig("settings")
    end)
    self:AddButton(section, "Reset Theme to Default", function()
        self:Confirm("Reset Theme", "Reset all theme customization to defaults?", function()
            self:ResetThemeConfig()
        end)
    end)
    return section
end

function Library:CreateQuickDashboard(tabName, columnName)
    if self:_isDead() then return end
    columnName = columnName or "Right"

    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer

    local QuickBox = self:_unwrap(self:CreateSection(tabName, "QUICK INSTANCE CONTROL", "Manage your session and community", true, columnName, "refresh-cw"))

    local function CreateActionRow(title, desc, iconName, callback)
        local holder = Instance.new("TextButton", QuickBox)
        holder.Size = UDim2.new(1, 0, 0, 54)
        holder.BackgroundColor3 = self._Colors.Card
        holder.BackgroundTransparency = 0.3
        holder.Text = ""
        holder.AutoButtonColor = false
        holder.BorderSizePixel = 0
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", holder)
        stroke.Color = self._Colors.Border
        stroke.Thickness = 1
        stroke.Transparency = 0.5

        local iconBg = Instance.new("Frame", holder)
        iconBg.Size = UDim2.fromOffset(34, 34)
        iconBg.Position = UDim2.new(0, 10, 0.5, -17)
        iconBg.BackgroundColor3 = self._Colors.Bg2
        iconBg.BorderSizePixel = 0
        Instance.new("UICorner", iconBg).CornerRadius = UDim.new(0, 6)

        local icon = Instance.new("ImageLabel", iconBg)
        icon.Size = UDim2.fromOffset(18, 18)
        icon.Position = UDim2.new(0.5, -9, 0.5, -9)
        icon.BackgroundTransparency = 1
        icon.Image = GetIcon(iconName)
        icon.ImageColor3 = self._Colors.Accent

        local titleLbl = Instance.new("TextLabel", holder)
        titleLbl.Size = UDim2.new(1, -70, 0, 18)
        titleLbl.Position = UDim2.new(0, 54, 0, 10)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = title
        titleLbl.TextColor3 = self._Colors.Text
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 13
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local descLbl = Instance.new("TextLabel", holder)
        descLbl.Size = UDim2.new(1, -70, 0, 14)
        descLbl.Position = UDim2.new(0, 54, 0, 28)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = desc
        descLbl.TextColor3 = self._Colors.TextDim
        descLbl.Font = Enum.Font.GothamMedium
        descLbl.TextSize = 10
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.TextTruncate = Enum.TextTruncate.AtEnd

        holder.MouseEnter:Connect(function()
            self:PlaySound("Hover")
            TweenService:Create(stroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0.1}):Play()
            TweenService:Create(holder, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
        end)
        holder.MouseLeave:Connect(function()
            TweenService:Create(stroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.5}):Play()
            TweenService:Create(holder, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
        end)
        holder.MouseButton1Click:Connect(function()
            self:PlaySound("Click")
            callback()
        end)
        
        self:_registerThemeRefresher(function()
            holder.BackgroundColor3 = self._Colors.Card
            stroke.Color = self._Colors.Border
            iconBg.BackgroundColor3 = self._Colors.Bg2
            icon.ImageColor3 = self._Colors.Accent
            titleLbl.TextColor3 = self._Colors.Text
            descLbl.TextColor3 = self._Colors.TextDim
        end)
        self:_registerSearchControl(holder, title .. " " .. desc)
        return holder
    end

    CreateActionRow("Reconnect Instance", "Rejoin the current server", "refresh-cw", function()
        -- Rejoin the *same* server (JobId) instead of teleporting into a random
        -- one, and guard against double-clicks creating two teleports.
        if self._teleporting then return end
        self._teleporting = true
        self:Notify("TELEPORT", "Reconnecting to server...", "info")
        task.spawn(function()
            task.wait(0.8)
            local ok = pcall(function()
                if game.JobId and game.JobId ~= "" then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                else
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
            if not ok then
                self._teleporting = false
                self:Notify("TELEPORT", "Reconnect failed — try again", "error")
            end
        end)
    end)

    CreateActionRow("Server Hop", "Move to a different public server", "server", function()
        if self._teleporting then return end
        self._teleporting = true
        self:Notify("SERVER HOP", "Searching for another server...", "info")
        task.spawn(function()
            local success = pcall(function()
                local url = string.format(
                    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
                    game.PlaceId)
                local response = HttpService:JSONDecode(game:HttpGet(url))
                local picked = nil
                if response and type(response.data) == "table" then
                    -- Skip the server we are already on; prefer populated-but-not-full.
                    for _, server in ipairs(response.data) do
                        if server.id ~= game.JobId then
                            picked = server
                            if (server.playing or 0) > 0 then break end
                        end
                    end
                end
                if picked then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, picked.id, LocalPlayer)
                else
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
            if not success then
                self._teleporting = false
                self:Notify("ERROR", "Server hop failed, rejoining instead...", "error")
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            end
        end)
    end)

    CreateActionRow("Discord Community", "Copy encrypted access link to clipboard", "message-circle", function()
        local discordLink = "https://discord.gg/rapptezetyee"
        if setclipboard then
            setclipboard(discordLink)
            self:Notify("DISCORD", "Link copied to clipboard!", "success")
        else
            self:Notify("DISCORD", "Executor doesn't support clipboard", "error")
        end
    end)
    return self:_wrapSection(QuickBox)
end

function Library:CreatePerformanceDashboard(tabName, columnName)
    if self:_isDead() then return end
    columnName = columnName or "Left"

    local PerfBox = self:_unwrap(self:CreateSection(tabName, "SYSTEM PERFORMANCE", "Realtime hardware and network stats", true, columnName, "activity"))

    -- 1. Container for Metrics (Grid Layout)
    local metricsContainer = Instance.new("Frame", PerfBox)
    metricsContainer.Size = UDim2.new(1, 0, 0, 120)
    metricsContainer.BackgroundTransparency = 1
    metricsContainer.LayoutOrder = 1

    local grid = Instance.new("UIGridLayout", metricsContainer)
    grid.CellSize = UDim2.new(0.5, -4, 0.5, -4)
    grid.CellPadding = UDim2.new(0, 8, 0, 8)
    grid.SortOrder = Enum.SortOrder.LayoutOrder

    -- Helper: MakeMetric Card
    local function MakeMetric(label, defaultVal, sub, order)
        local card = Instance.new("Frame", metricsContainer)
        card.LayoutOrder = order
        card.BackgroundColor3 = self._Colors.Bg2
        card.BackgroundTransparency = 0.2
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", card)
        stroke.Color = self._Colors.Border
        stroke.Thickness = 1
        stroke.Transparency = 0.5

        local lbl = Instance.new("TextLabel", card)
        lbl.Size = UDim2.new(1, -16, 0, 14)
        lbl.Position = UDim2.new(0, 8, 0, 8)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 9
        lbl.TextColor3 = self._Colors.TextDim
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.upper(label)

        local valLbl = Instance.new("TextLabel", card)
        valLbl.Size = UDim2.new(1, -16, 0, 22)
        valLbl.Position = UDim2.new(0, 8, 0, 22)
        valLbl.BackgroundTransparency = 1
        valLbl.Font = Enum.Font.GothamBlack
        valLbl.TextSize = 18
        valLbl.TextColor3 = self._Colors.Accent
        valLbl.TextXAlignment = Enum.TextXAlignment.Left
        valLbl.Text = defaultVal

        local subLbl = Instance.new("TextLabel", card)
        subLbl.Size = UDim2.new(1, -16, 0, 12)
        subLbl.Position = UDim2.new(0, 8, 0, 44)
        subLbl.BackgroundTransparency = 1
        subLbl.Font = Enum.Font.GothamMedium
        subLbl.TextSize = 9
        subLbl.TextColor3 = self._Colors.TextDim
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.Text = sub

        self:_registerThemeRefresher(function()
            card.BackgroundColor3 = self._Colors.Bg2
            stroke.Color = self._Colors.Border
            lbl.TextColor3 = self._Colors.TextDim
            valLbl.TextColor3 = self._Colors.Accent
            subLbl.TextColor3 = self._Colors.TextDim
        end)

        return valLbl
    end

    local fpsM = MakeMetric("FRAMERATE", "60.0", "FPS", 1)
    local pingM = MakeMetric("LATENCY", "35 ms", "OPTIMAL", 2)
    local plM = MakeMetric("PLAYERS", tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers), "ONLINE", 3)
    local sessM = MakeMetric("SESSION", "00:00", "ACTIVE", 4)

    -- 2. Graph (Framebuffer Activity)
    local WaveBox = Instance.new("Frame", PerfBox)
    WaveBox.Size = UDim2.new(1, 0, 0, 72)
    WaveBox.BackgroundColor3 = self._Colors.Bg2
    WaveBox.BackgroundTransparency = 0.2
    WaveBox.BorderSizePixel = 0
    WaveBox.LayoutOrder = 2
    Instance.new("UICorner", WaveBox).CornerRadius = UDim.new(0, 8)

    local wStroke = Instance.new("UIStroke", WaveBox)
    wStroke.Color = self._Colors.Border
    wStroke.Thickness = 1
    wStroke.Transparency = 0.5

    local wTitle = Instance.new("TextLabel", WaveBox)
    wTitle.Size = UDim2.new(0.5, -10, 0, 14)
    wTitle.Position = UDim2.new(0, 12, 0, 8)
    wTitle.BackgroundTransparency = 1
    wTitle.Font = Enum.Font.GothamBold
    wTitle.TextSize = 9
    wTitle.TextColor3 = self._Colors.TextDim
    wTitle.TextXAlignment = Enum.TextXAlignment.Left
    wTitle.Text = "FRAMEBUFFER ACTIVITY"

    local wSub = Instance.new("TextLabel", WaveBox)
    wSub.Size = UDim2.new(0.5, -10, 0, 14)
    wSub.Position = UDim2.new(0.5, 0, 0, 8)
    wSub.BackgroundTransparency = 1
    wSub.Font = Enum.Font.GothamBold
    wSub.TextSize = 9
    wSub.TextColor3 = self._Colors.Accent
    wSub.TextXAlignment = Enum.TextXAlignment.Right
    wSub.Text = "REALTIME | 60 FPS"

    local barBox = Instance.new("Frame", WaveBox)
    barBox.Size = UDim2.new(1, -24, 0, 32)
    barBox.Position = UDim2.new(0, 12, 0, 28)
    barBox.BackgroundTransparency = 1
    barBox.ClipsDescendants = true

    local bLayout = Instance.new("UIListLayout", barBox)
    bLayout.FillDirection = Enum.FillDirection.Horizontal
    bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    bLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    bLayout.Padding = UDim.new(0, 3)

    local graphBars = {}
    for i = 1, 20 do
        local b = Instance.new("Frame", barBox)
        b.Size = UDim2.new(0, 4, 0.6, 0)
        b.BackgroundColor3 = self._Colors.Accent
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        table.insert(graphBars, b)
    end

    local fpsHistory = {}
    for i = 1, 20 do
        fpsHistory[i] = 60
    end

    self:_registerThemeRefresher(function()
        WaveBox.BackgroundColor3 = self._Colors.Bg2
        wStroke.Color = self._Colors.Border
        wTitle.TextColor3 = self._Colors.TextDim
        wSub.TextColor3 = self._Colors.Accent
        for _, b in ipairs(graphBars) do
            b.BackgroundColor3 = self._Colors.Accent
        end
    end)

    -- 3. Live Logic
    local currentFPS = 60
    local frameCount = 0
    local lastCheck = os.clock()
    local startTime = os.clock()
    local maxObservedFPS = 60

    Fn.track(RunService.RenderStepped, function()
        if not WaveBox.Parent then return end
        -- Idle when the dashboard is not on screen: this used to run for the whole
        -- session on every rendered frame.
        if not WaveBox.Visible or not self._STATE.GuiVisible then
            lastCheck = os.clock()
            frameCount = 0
            return
        end
        frameCount = frameCount + 1
        local now = os.clock()
        local elapsed = now - lastCheck
        if elapsed >= 0.2 then
            currentFPS = math.clamp(math.floor((frameCount / elapsed) + 0.5), 1, 360)
            fpsM.Text = string.format("%.1f", currentFPS)
            wSub.Text = "REALTIME | " .. tostring(currentFPS) .. " FPS"
            frameCount = 0
            lastCheck = now

            if currentFPS > maxObservedFPS then
                maxObservedFPS = math.max(60, currentFPS)
            end

            table.remove(fpsHistory, 1)
            table.insert(fpsHistory, currentFPS)

            -- Direct sizing instead of 24 fresh tweens every 0.2s.
            for i, bar in ipairs(graphBars) do
                local sample = fpsHistory[i] or 60
                local targetHeight = math.clamp(sample / maxObservedFPS, 0.1, 0.95)
                bar.Size = UDim2.new(0, 4, targetHeight, 0)
            end
        end
    end, self)

    task.spawn(function()
        while task.wait(0.5) do
            if not WaveBox.Parent then break end
            if not WaveBox.Visible or not self._STATE.GuiVisible then continue end
            local elapsed = math.floor(os.clock() - startTime)
            sessM.Text = string.format("%02d:%02d", math.floor(elapsed / 60), elapsed % 60)
            plM.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)
            pcall(function()
                local p = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                pingM.Text = tostring(p) .. " ms"
            end)
        end
    end)

    return self:_wrapSection(PerfBox)
end

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
        callback(state)
        self:_triggerAutoSave()
    end
    holder.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
            and inp.UserInputType ~= Enum.UserInputType.Touch then return end
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
        if not silent then callback(state); self:_triggerAutoSave() end
    end
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
    _ReducedMotion = false
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

-- =========================================================
-- MODULE EXPORT (UPDATED FOR MAXIMUM COMPATIBILITY)
-- =========================================================

local export = {
    new = function(...) return Library.new(...) end,
    CreateWindow = function(...) return Library.new(...) end,
    Themes = D.ThemeNames,
    WeatherTypes = D.WeatherTypes,
    FocusOverlayTypes = D.FocusOverlayTypes,
}

setmetatable(export, {
    __call = function(_, ...)
        return Library.new(...)
    end
})

return export
