--[[
    Intro.lua — Animação de entrada do DepHub
    Uso:
        local Intro = loadstring(game:HttpGet("URL/Intro.lua"))()
        Intro:Play({ OnComplete = function() end })
    Fases: named (950ms) -> expanding (2050ms) -> revealed (3050ms) -> done (3550ms)
]]

local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Intro = {}
Intro.__index = Intro

local Theme = {
    Background = Color3.fromRGB(0x15, 0x15, 0x15),
    Panel      = Color3.fromRGB(0x18, 0x18, 0x18),
    Border     = Color3.fromRGB(0x2b, 0x2b, 0x2b),
    TextBright = Color3.fromRGB(0xef, 0xef, 0xef),
    TextDim    = Color3.fromRGB(0x80, 0x80, 0x80),
    Font       = Enum.Font.GothamBold,
    FontReg    = Enum.Font.Gotham,
}

local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(inst, r) return new("UICorner", { CornerRadius = r or UDim.new(0, 7) }, inst) end
local function stroke(inst, c, t) return new("UIStroke", { Color = c or Theme.Border, Thickness = t or 1 }, inst) end

local function safeParent()
    local ok = pcall(function() return CoreGui end)
    if ok and CoreGui then
        local probe = new("ScreenGui", { Name = "DepHubIntroProbe" })
        local s = pcall(function() probe.Parent = CoreGui end)
        probe:Destroy()
        if s then return CoreGui end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function tween(inst, time, props, style, dir)
    local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function prefersReducedMotion()
    -- Roblox não expõe prefers-reduced-motion; usamos uma flag opcional
    return false
end

function Intro:Play(opts)
    opts = opts or {}
    local reduced = prefersReducedMotion()
    local T = function(ms) return reduced and (ms / 4) or ms end

    local gui = new("ScreenGui", {
        Name = "DepHubIntro",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, safeParent())

    local overlay = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
    }, gui)

    -- "d" central que expande
    local mark = new("TextLabel", {
        Size = UDim2.fromOffset(60, 60),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "d",
        TextColor3 = Theme.TextBright,
        Font = Theme.Font,
        TextSize = 48,
        TextTransparency = 1,
    }, overlay)

    -- "DepHub" que aparece abaixo
    local name = new("TextLabel", {
        Size = UDim2.new(0, 300, 0, 40),
        Position = UDim2.new(0.5, 0, 0.5, 60),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "DepHub",
        TextColor3 = Theme.TextBright,
        Font = Theme.Font,
        TextSize = 34,
        TextTransparency = 1,
    }, overlay)

    local subtitle = new("TextLabel", {
        Size = UDim2.new(0, 300, 0, 20),
        Position = UDim2.new(0.5, 0, 0.5, 95),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = "LIBRARY / 01",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontReg,
        TextSize = 11,
        TextTransparency = 1,
    }, overlay)

    local function finish()
        tween(overlay, 0.4, { BackgroundTransparency = 1 })
        tween(mark, 0.4, { TextTransparency = 1 })
        tween(name, 0.4, { TextTransparency = 1 })
        tween(subtitle, 0.4, { TextTransparency = 1 })
        task.delay(0.5, function()
            gui:Destroy()
            if opts.OnComplete then task.spawn(opts.OnComplete) end
        end)
    end

    -- Fase 1: "d" aparece (named)
    task.delay(T(950) / 1000, function()
        tween(mark, 0.3, { TextTransparency = 0 })
    end)

    -- Fase 2: logo expande (expanding)
    task.delay(T(2050) / 1000, function()
        tween(mark, 0.4, { TextSize = 64 }, Enum.EasingStyle.Back)
    end)

    -- Fase 3: nome revelado (revealed)
    task.delay(T(3050) / 1000, function()
        tween(name, 0.35, { TextTransparency = 0 })
        tween(subtitle, 0.35, { TextTransparency = 0 })
    end)

    -- Fase 4: done
    task.delay(T(3550) / 1000, finish)

    self.Gui = gui
    return self
end

function Intro:Skip()
    if self.Gui then self.Gui:Destroy() end
end

return Intro