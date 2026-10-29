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
local SharedReduced = { value = false }
local _RealTweenService  = game:GetService("TweenService")
local TweenService = {
    Create = function(_, obj, info, props)
        if SharedReduced.value and info then
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
-- PART LOADER
-- =========================================================
-- The theme is split into ordered parts under src/core/ui/theme/. Each part
-- receives this shared context and adds methods to the one Library table.
-- Parts load with the same resolver the rest of the repo uses (the bundled
-- source table in a build, game:HttpGet in an executor), in the exact order
-- the sections appeared in the original file so every cross-reference
-- resolves when its part runs.
local THEME_PARTS = {
    "src/core/ui/theme/data.luau",
    "src/core/ui/theme/sub-tabs.luau",
    "src/core/ui/theme/constructor.luau",
    "src/core/ui/theme/theme-apply.luau",
    "src/core/ui/theme/notifications.luau",
    "src/core/ui/theme/window.luau",
    "src/core/ui/theme/extras.luau",
    "src/core/ui/theme/public-api.luau",
    "src/core/ui/theme/controls.luau",
    "src/core/ui/theme/lifecycle.luau",
}

local function resolvePartSource(relPath)
    local env = (type(getgenv) == "function" and getgenv()) or _G
    local resolver = (type(env.__dephubHttpGet) == "function" and env.__dephubHttpGet)
        or (type(env.__DEPHUB_HTTP_GET) == "function" and env.__DEPHUB_HTTP_GET)
        or (type(_G.__dephubHttpGet) == "function" and _G.__dephubHttpGet)
        or (type(_G.__DEPHUB_HTTP_GET) == "function" and _G.__DEPHUB_HTTP_GET)
    local base = (env.__DEPHUB and env.__DEPHUB.SourceBaseURL) or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
    local token = (env.__DEPHUB and env.__DEPHUB.SourceCacheBust) or ""
    local suffix = token ~= "" and ("?cb=" .. tostring(token)) or ""
    if resolver then
        local ok, source = pcall(resolver, base .. relPath .. suffix)
        if ok and type(source) == "string" and #source > 0 then return source end
    end
    local ok, source = pcall(function() return game:HttpGet(base .. relPath .. suffix) end)
    if ok and type(source) == "string" and #source > 0 then return source end
    return nil
end

local ctx = {
    Library = Library,
    D = D,
    Fn = Fn,
    GetIcon = GetIcon,
    getCam = getCam,
    GetGuiParent = GetGuiParent,
    findInGuiParents = findInGuiParents,
    GuiParent = GuiParent,
    TweenService = TweenService,
    GuiSound = GuiSound,
    Players = Players,
    RunService = RunService,
    MarketplaceService = MarketplaceService,
    Stats = Stats,
    UserInputService = UserInputService,
    CoreGui = CoreGui,
    Lighting = Lighting,
    SoundService = SoundService,
    LocalPlayer = LocalPlayer,
    IconsV2 = IconsV2,
    SharedReduced = SharedReduced,
}

local function loadThemeParts()
    -- Parts run in the same environment this chunk runs in (the executor's
    -- globals: game, Enum, Instance, ...). loadstring may hand back a chunk with
    -- a different env on some executors, so set it explicitly when the executor
    -- exposes setfenv/getfenv.
    local currentEnv = (type(getfenv) == "function") and getfenv(0) or nil
    for _, relPath in ipairs(THEME_PARTS) do
        local source = resolvePartSource(relPath)
        if type(source) ~= "string" or #source == 0 then
            error("[DoD UI] theme part unavailable: " .. tostring(relPath))
        end
        local chunk, compileError = loadstring(source)
        if not chunk then
            error("[DoD UI] theme part failed to compile: " .. tostring(relPath) .. ": " .. tostring(compileError))
        end
        if currentEnv and type(setfenv) == "function" then
            pcall(setfenv, chunk, currentEnv)
        end
        local ok, err = pcall(chunk, ctx)
        if not ok then
            error("[DoD UI] theme part failed: " .. tostring(relPath) .. ": " .. tostring(err))
        end
    end
end

loadThemeParts()

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

