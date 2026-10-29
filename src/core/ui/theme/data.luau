--[[
  THEMES + WEATHER PRESETS (D.* tables, WEATHER_PRESETS, randomFloat)

  Split out of src/core/ui/demon-theme.luau (original lines 304-641).
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
local SubTabModule = __CTX.SubTabModule
local SUBTAB_DEFAULT_THEME = __CTX.SUBTAB_DEFAULT_THEME

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


__CTX.WEATHER_PRESETS = WEATHER_PRESETS
__CTX.randomFloat = randomFloat
return true
