--[[
    Intro.lua - Animacao de entrada do DepHub

    Porte fiel de INTRO.html: o shell monograma (62x62) chega, materializa o
    nome ("DepHub"), expande ate as dimensoes do painel (780x520) e revela o
    conteudo. Mesmas fases, mesmos tempos e mesmos tokens do mockup.

    Uso:
        local Intro = loadModule("src/ui/Intro.lua")
        Intro:Play({ OnComplete = function() end, OnReveal = function() end })

    Fases (CSS -> ms):
        arrive      chega                       0
        named       shell 174x62, nome revela   950
        expanding   shell 780x520               2050
        revealed    painel visivel              3050
        done        stage sai                   3550

    Tokens lidos de INTRO.html: shell #191919 / borda #3a3a3a / radius 15,
    mark 34x34 radius 9 gradiente #ededed->#b5b5b5 com o glifo "D" em #171717
    rotacionado -13deg, nome 18px letter-spacing -.55 #e6e6e6, linha divisoria
    em top:65px.
]]

local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Intro = {}
Intro.__index = Intro

-- ---------------------------------------------------------------------------
-- Tokens (INTRO.html)
-- ---------------------------------------------------------------------------
local Theme = {
    Bg            = Color3.fromRGB(0x15, 0x15, 0x15),
    ShellBg       = Color3.fromRGB(0x19, 0x19, 0x19),
    ShellBgTop    = Color3.fromRGB(0x25, 0x25, 0x25),
    ShellBorder   = Color3.fromRGB(0x3a, 0x3a, 0x3a),
    ShellBorderEx = Color3.fromRGB(0x32, 0x32, 0x32),
    ShellBorderNm = Color3.fromRGB(0x48, 0x48, 0x48),
    MarkTop       = Color3.fromRGB(0xed, 0xed, 0xed),
    MarkBot       = Color3.fromRGB(0xb5, 0xb5, 0xb5),
    MarkInk       = Color3.fromRGB(0x17, 0x17, 0x17),
    Name          = Color3.fromRGB(0xe6, 0xe6, 0xe6),
    Line          = Color3.fromRGB(0x2b, 0x2b, 0x2b),
    Guide         = Color3.fromRGB(0xff, 0xff, 0xff),
    Font          = Enum.Font.GothamBold,
    FontReg       = Enum.Font.Gotham,
}

-- Geometria declarada pelo mockup.
local SHELL        = 62            -- width/height iniciais
local SHELL_NAMED  = 174           -- largura depois do nome
local SHELL_RADIUS = 15
local MARK         = 34
local MARK_RADIUS  = 9
local MARK_PAD     = 27            -- font-size do "D"
local NAME_WIDTH   = 86            -- width revelada
local NAME_SIZE    = 18
local PANEL_W      = 780
local PANEL_H      = 520
local LINE_TOP     = 65

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(inst, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius or 7)}, inst)
end

local function stroke(inst, colour, thickness)
    return new("UIStroke", {
        Color = colour or Theme.ShellBorder,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, inst)
end

-- The gradient the mark and shell use (linear-gradient(145deg, a, b)). Roblox
-- only offers a gradient over an axis, so the 145deg direction is approximated
-- with a diagonal axis and the two stops the mockup names.
local function gradient(inst, top, bottom, rotation)
    return new("UIGradient", {
        Color = ColorSequence.new(top, bottom),
        Rotation = rotation or 145,
    }, inst)
end

local function safeParent()
    local ok = pcall(function() return CoreGui end)
    if ok and CoreGui then
        local probe = new("ScreenGui", {Name = "DepHubIntroProbe"})
        local parented = pcall(function() probe.Parent = CoreGui end)
        probe:Destroy()
        if parented then return CoreGui end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function tween(inst, seconds, props, style, direction)
    local info = TweenInfo.new(
        seconds,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

-- cubic-bezier(.22,1,.36,1) etc. are CSS curves; Roblox's closest built-ins are
-- Quint/Back. The mockup's brand reveal uses (.22,1,.36,1) (a strong ease-out)
-- and the shell expansion (.65,0,.2,1) (an ease-in-out). These map well onto
-- Quint Out and Quint InOut respectively.
local EASE_OUT   = Enum.EasingStyle.Quint
local EASE_INOUT = Enum.EasingStyle.Quint

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------
function Intro:Play(opts)
    opts = opts or {}
    self.Destroyed = false
    self.Timers = {}
    self.Tweens = {}

    local function later(seconds, fn)
        self.Timers[#self.Timers + 1] = task.delay(seconds, function()
            if self.Destroyed then return end
            local ok, err = pcall(fn)
            if not ok then warn("[DepHub Intro] " .. tostring(err)) end
        end)
    end

    local function remember(t)
        if t then self.Tweens[#self.Tweens + 1] = t end
        return t
    end

    local gui = new("ScreenGui", {
        Name = "DepHubIntro",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 200,
    }, safeParent())
    self.Gui = gui

    -- #intro-stage{position:fixed;inset:0;display:grid;place-items:center}
    local stage = new("Frame", {
        Name = "Stage",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, gui)
    self.Stage = stage

    -- #intro-stage::before - the ambient radial glow.
    local ambient = new("Frame", {
        Name = "Ambient",
        Size = UDim2.fromOffset(math.min(650, 0.9 * PANEL_W), 460),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(0xff, 0xff, 0xff),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, stage)
    corner(ambient, 460)
    new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.955),
            NumberSequenceKeypoint.new(0.30, 0.985),
            NumberSequenceKeypoint.new(0.68, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, ambient)

    -- #intro-shell{width:62px;height:62px;border-radius:15px;background:#191919}
    local shell = new("Frame", {
        Name = "Shell",
        Size = UDim2.fromOffset(SHELL, SHELL),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.ShellBg,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, stage)
    corner(shell, SHELL_RADIUS)
    local shellStroke = stroke(shell, Theme.ShellBorder, 1)
    local shellGradient = gradient(shell, Theme.ShellBgTop, Theme.ShellBg, 145)
    self.Shell = shell
    self.ShellStroke = shellStroke

    -- .intro-sheen - the diagonal light sweep across the shell.
    local sheen = new("Frame", {
        Name = "Sheen",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0xff, 0xff, 0xff),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, shell)
    corner(sheen, SHELL_RADIUS)
    new("UIGradient", {
        Rotation = 110,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1),
            NumberSequenceKeypoint.new(0.32, 1),
            NumberSequenceKeypoint.new(0.48, 0.98),
            NumberSequenceKeypoint.new(0.64, 1),
            NumberSequenceKeypoint.new(1.00, 1),
        }),
    }, sheen)

    -- .intro-line{top:65px} - the divider that appears during the expansion.
    local line = new("Frame", {
        Name = "Line",
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.fromOffset(0, LINE_TOP),
        BackgroundColor3 = Theme.Line,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, shell)
    self.Line = line

    -- .intro-brand{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%)}
    local brand = new("Frame", {
        Name = "Brand",
        Size = UDim2.fromOffset(SHELL_NAMED, 40),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, shell)
    new("UIListLayout", {
        Name = "Flow",
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 0),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = brand,
    })
    self.Brand = brand

    -- .intro-mark{width:34px;height:34px;border-radius:9px;
    --            background:linear-gradient(145deg,#ededed,#b5b5b5);transform:rotate(-13deg)}
    local markHolder = new("Frame", {
        Name = "MarkHolder",
        Size = UDim2.fromOffset(MARK, MARK),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Rotation = -13,
    }, brand)
    local mark = new("Frame", {
        Name = "Mark",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.MarkTop,
        BorderSizePixel = 0,
    }, markHolder)
    corner(mark, MARK_RADIUS)
    gradient(mark, Theme.MarkTop, Theme.MarkBot, 145)
    -- The mockup draws an SVG monogram; the same shape is drawn as text, the
    -- way the panel header does it.
    local markGlyph = new("TextLabel", {
        Name = "Glyph",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "D",
        TextColor3 = Theme.MarkInk,
        Font = Theme.Font,
        TextSize = MARK_PAD,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 2,
    }, mark)
    self.MarkHolder = markHolder
    self.Mark = mark
    self.MarkGlyph = markGlyph

    -- .intro-mark::after - the glint that sweeps once the shell warms up.
    local glint = new("Frame", {
        Name = "Glint",
        Size = UDim2.fromScale(2.4, 2.4),
        Position = UDim2.fromScale(-0.7, -0.7),
        BackgroundColor3 = Color3.fromRGB(0xff, 0xff, 0xff),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Rotation = 12,
        ZIndex = 3,
    }, mark)
    new("UIGradient", {
        Rotation = 110,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1),
            NumberSequenceKeypoint.new(0.40, 1),
            NumberSequenceKeypoint.new(0.50, 0.9),
            NumberSequenceKeypoint.new(0.60, 1),
            NumberSequenceKeypoint.new(1.00, 1),
        }),
    }, glint)
    self.Glint = glint

    -- .intro-name{font-size:18px;letter-spacing:-.55px;color:#e6e6e6;width:0}
    local name = new("TextLabel", {
        Name = "Name",
        Size = UDim2.fromOffset(0, 40),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Text = "DepHub",
        TextColor3 = Theme.Name,
        Font = Theme.Font,
        TextSize = NAME_SIZE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTransparency = 1,
        TextTruncate = Enum.TextTruncate.Clip,
    }, brand)
    new("UISizeConstraint", {
        Name = "Reveal",
        MinSize = Vector2.new(0, 0),
        MaxSize = Vector2.new(0, math.huge),
    }, name)
    self.Name = name
    self.NameConstraint = name:FindFirstChild("Reveal")

    -- The brand sits centred by default and slides to the header position on
    -- expansion, exactly like the mockup's .intro-brand keyframes.
    local nameMargin = new("UIPadding", {PaddingLeft = UDim.new(0, 0)}, name)

    -- Start state: everything hidden, matching the CSS opacity:0 defaults.
    self:Reset()

    -- -----------------------------------------------------------------------
    -- Phase timeline (from INTRO.html runIntro)
    -- -----------------------------------------------------------------------
    local phases = {
        arrive    = 0,
        named     = 950,
        expanding = 2050,
        revealed  = 3050,
        done      = 3550,
    }

    -- 0ms: arrive. #intro-shell.arrive -> logo-arrival, and the mark turns.
    -- A Frame has no independent scale pivot in Roblox, so the arrival pop is
    -- expressed as the fade-in the mockup also runs (opacity 0 -> 1); the shell
    -- keeps its 62px size so the later phases measure cleanly.
    shell.BackgroundTransparency = 1
    shell.Size = UDim2.fromOffset(SHELL, SHELL)
    markHolder.Rotation = -13
    remember(tween(shell, 0.60, {BackgroundTransparency = 0}, EASE_OUT))
    remember(tween(markHolder, 0.70, {Rotation = 0}, Enum.EasingStyle.Back))

    -- 950ms: named. Shell widens to 174, the name unrolls, the mark glints.
    later(phases.named / 1000, function()
        remember(tween(shell, 0.65, {Size = UDim2.fromOffset(SHELL_NAMED, SHELL)}, EASE_OUT))
        shellStroke.Color = Theme.ShellBorderNm
        -- .intro-name{width:0 -> 86; opacity 0 -> 1; blur(4px) -> 0}
        self.NameConstraint.MaxSize = Vector2.new(0, math.huge)
        local widthTween = TweenService:Create(self.Name,
            TweenInfo.new(0.65, EASE_OUT, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(NAME_WIDTH, 40)})
        widthTween:Play()
        remember(widthTween)
        nameMargin.PaddingLeft = UDim.new(0, 11)
        remember(tween(self.Name, 0.50, {TextTransparency = 0}, EASE_OUT))
        -- The name is clipped while it has no width, which is the CSS
        -- overflow:hidden behaviour.
        self:_sweep(self.Glint, 0.9, 0.7)
        self:_sweep(sheen, 1.1, 0.0)
    end)

    -- 2050ms: expanding. The shell becomes the panel rectangle.
    later(phases.expanding / 1000, function()
        remember(tween(shell, 0.95,
            {Size = UDim2.fromOffset(PANEL_W, PANEL_H)},
            EASE_INOUT))
        shellStroke.Color = Theme.ShellBorderEx
        remember(tween(shell, 0.80, {BackgroundTransparency = 1}, EASE_INOUT))
        -- Linear-gradient stops to the flat panel background.
        if shellGradient then shellGradient.Enabled = false end
        -- .intro-brand{left:24px;top:13px;transform:none}
        local brandTween = TweenService:Create(self.Brand,
            TweenInfo.new(0.95, EASE_INOUT, Enum.EasingDirection.Out), {
                Position = UDim2.fromOffset(24, 13),
                AnchorPoint = Vector2.new(0, 0),
                Size = UDim2.fromOffset(SHELL_NAMED, 40),
            })
        brandTween:Play()
        remember(brandTween)
        -- The mark shrinks from the 34px intro mark toward the header mark; the
        -- mockup keeps 34px, so only the radius and shadow settle.
        markHolder.Rotation = 0
        corner(mark, MARK_RADIUS)
        -- .intro-line{opacity:0 -> 1; scaleX .1 -> 1}
        local lineTween = TweenService:Create(self.Line,
            TweenInfo.new(0.70, EASE_INOUT, Enum.EasingDirection.Out), {
                BackgroundTransparency = 0,
            })
        lineTween:Play()
        remember(lineTween)
        self:_fadeAmbient(0.6)
    end)

    -- 3050ms: revealed. Hand the stage over; the panel is already mounted.
    later(phases.revealed / 1000, function()
        if opts.OnReveal then pcall(opts.OnReveal) end
        local stageTween = TweenService:Create(stage,
            TweenInfo.new(0.30, EASE_OUT, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1})
        stageTween:Play()
        -- The shell's own background must not cover the panel below it.
        remember(tween(shell, 0.30, {BackgroundTransparency = 1}, EASE_OUT))
        if shellStroke then shellStroke.Transparency = 1 end
        self:_fadeAmbient(0.35, true)
    end)

    -- 3550ms: done. Remove the intro entirely.
    later(phases.done / 1000, function()
        if self.Destroyed then return end
        local fade = tween(gui, 0.30, {Enabled = false}, EASE_OUT)
        remember(fade)
        task.delay(0.32, function()
            if not self.Destroyed then self:Destroy() end
            if opts.OnComplete then task.spawn(opts.OnComplete) end
        end)
    end)

    return self
end

-- Internal: run a one-shot light sweep across an element.
function Intro:_sweep(inst, seconds, delay)
    if not inst then return end
    local function run()
        if self.Destroyed then return end
        inst.Position = UDim2.fromScale(-1.2, inst.Position.Y.Scale)
        tween(inst, seconds, {Position = UDim2.fromScale(1.2, inst.Position.Y.Scale)}, EASE_INOUT)
    end
    if delay and delay > 0 then
        self.Timers[#self.Timers + 1] = task.delay(delay, run)
    else
        run()
    end
end

-- Internal: the ambient radial glow pulses in and out during the boot.
function Intro:_fadeAmbient(seconds, out)
    local ambient = self.Stage and self.Stage:FindFirstChild("Ambient")
    if not ambient then return end
    if out then
        tween(ambient, seconds, {BackgroundTransparency = 1}, EASE_OUT)
    else
        tween(ambient, seconds, {BackgroundTransparency = 0.94}, EASE_OUT)
    end
end

-- Reset the intro to the pre-arrival state (used by Play and by a replay).
function Intro:Reset()
    if self.Shell then
        self.Shell.Size = UDim2.fromOffset(SHELL, SHELL)
        self.Shell.Position = UDim2.fromScale(0.5, 0.5)
        self.Shell.AnchorPoint = Vector2.new(0.5, 0.5)
        self.Shell.BackgroundColor3 = Theme.ShellBg
    end
    if self.ShellStroke then
        self.ShellStroke.Color = Theme.ShellBorder
        self.ShellStroke.Transparency = 0
    end
    if self.Brand then
        self.Brand.Position = UDim2.fromScale(0.5, 0.5)
        self.Brand.AnchorPoint = Vector2.new(0.5, 0.5)
    end
    if self.MarkHolder then self.MarkHolder.Rotation = -13 end
    if self.MarkGlyph then self.MarkGlyph.TextTransparency = 0 end
    if self.Name then
        self.Name.Size = UDim2.fromOffset(0, 40)
        self.Name.TextTransparency = 1
    end
    if self.NameConstraint then self.NameConstraint.MaxSize = Vector2.new(0, math.huge) end
    if self.Line then self.Line.BackgroundTransparency = 1 end
    if self.Glint then self.Glint.BackgroundTransparency = 1 end
end

-- Skip to the end (e.g. the panel was opened during the intro).
function Intro:Skip()
    self:Destroy()
end

function Intro:Destroy()
    self.Destroyed = true
    for _, timer in ipairs(self.Timers or {}) do
        if timer then pcall(task.cancel, timer) end
    end
    self.Timers = {}
    for _, t in ipairs(self.Tweens or {}) do
        if t then pcall(function() t:Cancel() end) end
    end
    self.Tweens = {}
    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end
end

return Intro
