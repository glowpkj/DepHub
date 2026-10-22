-- DepHub panel library (v2 — Rayfield-style frontend).
--
-- Drop-in replacement for the previous presentation layer. It exposes the
-- exact contract consumed by src/core/panel-host.lua:
--   PanelFactory.new(spec) -> panel
--   panel:CreateTab({Name, Glyph, Intro, Search}) -> tab
--   panel:AddToggle(tab, title, help, value, cb)
--   panel:AddSlider(tab, title, min, max, step, value, cb, format)
--   panel:AddInlineSlider(tab, title, min, max, step, value, cb, format)
--   panel:AddDropdown(tab, title, help, options, value, cb)
--   panel:AddAction(tab, title, help, buttonLabel, cb, primary)
--   panel:AddDisabledToggle(tab, title, help, value)
--   panel:AddNotice(tab, text, title)
--   panel:AddSection(tab, label)
--   panel:Notify(title, message, isError)
--   panel:SetStatus(text)
--
-- The ScreenGui is named "dephub" so src/core/ui-guard keeps it enabled.

local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")
local Players      = game:GetService("Players")
local UserInput    = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ---------------------------------------------------------------------------
-- Theme
-- ---------------------------------------------------------------------------
local Theme = {
    Bg            = Color3.fromRGB(21, 21, 21),
    Panel         = Color3.fromRGB(24, 24, 24),
    Sidebar       = Color3.fromRGB(19, 19, 19),
    Header        = Color3.fromRGB(24, 24, 24),
    Border        = Color3.fromRGB(43, 43, 43),
    BorderSoft    = Color3.fromRGB(34, 34, 34),
    TextBright    = Color3.fromRGB(239, 239, 239),
    Text          = Color3.fromRGB(206, 206, 206),
    TextDim       = Color3.fromRGB(128, 128, 128),
    TextQuiet     = Color3.fromRGB(110, 110, 110),
    Accent        = Color3.fromRGB(221, 221, 221),
    AccentInk     = Color3.fromRGB(24, 24, 24),
    NavActive     = Color3.fromRGB(30, 30, 30),
    NavHover      = Color3.fromRGB(26, 26, 26),
    Field         = Color3.fromRGB(17, 17, 17),
    FieldBorder   = Color3.fromRGB(51, 51, 51),
    FieldFocus    = Color3.fromRGB(119, 119, 119),
    ToggleOff     = Color3.fromRGB(48, 48, 48),
    ToggleOn      = Color3.fromRGB(221, 221, 221),
    ToggleKnob    = Color3.fromRGB(148, 148, 148),
    ToggleKnobOn  = Color3.fromRGB(24, 24, 24),
    RowHover      = Color3.fromRGB(28, 28, 28),
    Action        = Color3.fromRGB(29, 29, 29),
    ActionHover   = Color3.fromRGB(39, 39, 39),
    ActionBorder  = Color3.fromRGB(58, 58, 58),
    Primary       = Color3.fromRGB(221, 221, 221),
    PrimaryHover  = Color3.fromRGB(239, 239, 239),
    PrimaryInk    = Color3.fromRGB(24, 24, 24),
    Toast         = Color3.fromRGB(28, 28, 28),
    ToastBorder   = Color3.fromRGB(60, 60, 60),
    ToastError    = Color3.fromRGB(121, 80, 80),
    ScrollBar     = Color3.fromRGB(58, 58, 58),
    FontHeader    = Enum.Font.GothamBold,
    FontBody      = Enum.Font.Gotham,
    FontMono      = Enum.Font.Code,
}

local WIN_W, WIN_H = 620, 460
local SIDEBAR_W    = 160
local HEADER_H     = 48

-- ---------------------------------------------------------------------------
-- Instance helpers
-- ---------------------------------------------------------------------------
local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(inst, r)
    return new("UICorner", {CornerRadius = r or UDim.new(0, 6)}, inst)
end

local function stroke(inst, color, thickness)
    return new("UIStroke", {Color = color or Theme.Border, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst)
end

local function padding(inst, t, r, b, l)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft = UDim.new(0, l or 0),
    }, inst)
end

local function tween(inst, time, props, style, dir)
    local t = TweenService:Create(inst,
        TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function safeParent()
    local ok = pcall(function() return CoreGui end)
    if ok and CoreGui then
        local probe = new("ScreenGui", {Name = "dephub_probe"})
        local s = pcall(function() probe.Parent = CoreGui end)
        probe:Destroy()
        if s then return CoreGui end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function makeDraggable(frame, handle)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInput.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                       startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Panel
-- ---------------------------------------------------------------------------
local Panel = {}
Panel.__index = Panel

function Panel.new(spec)
    spec = spec or {}
    local self = setmetatable({}, Panel)
    self.Tabs = {}
    self.ActiveTab = nil
    self.Toasts = {}

    local gui = new("ScreenGui", {
        Name = "dephub",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
    }, safeParent())
    self.Gui = gui

    local root = new("Frame", {
        Name = "Root",
        Size = UDim2.fromOffset(WIN_W, WIN_H),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        Visible = spec.StartOpen ~= false,
    }, gui)
    corner(root, UDim.new(0, 10))
    stroke(root, Theme.Border, 1)
    self.Root = root

    -- Header
    local header = new("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, HEADER_H),
        BackgroundColor3 = Theme.Header,
        BorderSizePixel = 0,
    }, root)
    corner(header, UDim.new(0, 10))
    new("Frame", { -- tapa o canto inferior arredondado do header
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Theme.Header,
        BorderSizePixel = 0,
    }, header)

    local badge = new("TextLabel", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.fromOffset(14, 10),
        BackgroundColor3 = Theme.Accent,
        Text = "d",
        TextColor3 = Theme.AccentInk,
        Font = Theme.FontHeader,
        TextSize = 18,
        BorderSizePixel = 0,
    }, header)
    corner(badge, UDim.new(0, 6))

    local title = new("TextLabel", {
        Size = UDim2.new(0, 200, 0, 16),
        Position = UDim2.fromOffset(52, 8),
        BackgroundTransparency = 1,
        Text = spec.Title or "DepHub",
        TextColor3 = Theme.TextBright,
        Font = Theme.FontHeader,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local gameName = new("TextLabel", {
        Size = UDim2.new(0, 300, 0, 14),
        Position = UDim2.fromOffset(52, 26),
        BackgroundTransparency = 1,
        Text = spec.GameName or "",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local closeBtn = new("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -38, 0, 10),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontHeader,
        TextSize = 18,
        AutoButtonColor = false,
    }, header)
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = Theme.TextBright end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = Theme.TextDim end)
    closeBtn.MouseButton1Click:Connect(function()
        root.Visible = false
        if self.FloatingButton then self.FloatingButton.Visible = true end
    end)

    makeDraggable(root, header)

    -- Sidebar
    local sidebar = new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR_W, 1, -HEADER_H),
        Position = UDim2.fromOffset(0, HEADER_H),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
    }, root)
    new("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.BorderSoft,
        BorderSizePixel = 0,
    }, sidebar)

    self.Sidebar = sidebar
    self.NavLayout = new("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, sidebar)
    padding(sidebar, 10, 10, 10, 10)

    -- Main content
    local main = new("Frame", {
        Name = "Main",
        Size = UDim2.new(1, -SIDEBAR_W, 1, -HEADER_H),
        Position = UDim2.fromOffset(SIDEBAR_W, HEADER_H),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    }, root)
    self.Main = main

    local scroll = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.ScrollBar,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, main)
    padding(scroll, 18, 18, 18, 18)
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroll)
    self.Scroll = scroll

    -- Status bar
    local status = new("TextLabel", {
        Name = "Status",
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 1, -28),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Text = "",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)
    padding(status, 0, 12, 0, 12)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.BorderSoft,
        BorderSizePixel = 0,
    }, status)
    self.StatusLabel = status

    -- Floating reopen button
    local floating = new("TextButton", {
        Name = "FloatingButton",
        Size = UDim2.fromOffset(38, 38),
        Position = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = Theme.Accent,
        Text = "d",
        TextColor3 = Theme.AccentInk,
        Font = Theme.FontHeader,
        TextSize = 20,
        BorderSizePixel = 0,
        Visible = false,
        AutoButtonColor = false,
    }, gui)
    corner(floating, UDim.new(0, 8))
    stroke(floating, Theme.Border, 1)
    floating.MouseButton1Click:Connect(function()
        root.Visible = true
        floating.Visible = false
    end)
    self.FloatingButton = floating

    -- RightShift toggle
    UserInput.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            root.Visible = not root.Visible
            floating.Visible = not root.Visible
        end
    end)

    -- Toast container
    local toastHolder = new("Frame", {
        Name = "Toasts",
        Size = UDim2.fromOffset(280, 400),
        Position = UDim2.new(1, -300, 1, -20),
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
    }, gui)
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, toastHolder)
    self.ToastHolder = toastHolder

    return self
end

-- ---------------------------------------------------------------------------
-- Tabs
-- ---------------------------------------------------------------------------
function Panel:CreateTab(spec)
    spec = spec or {}
    local tab = {Name = spec.Name or "Tab", Glyph = spec.Glyph or "", Spec = spec, Buttons = {}}

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Sidebar,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, self.Sidebar)
    corner(btn, UDim.new(0, 6))

    local glyph = new("TextLabel", {
        Size = UDim2.fromOffset(20, 34),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = spec.Glyph or "",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 15,
    }, btn)

    local label = new("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.fromOffset(36, 0),
        BackgroundTransparency = 1,
        Text = spec.Name or "",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, btn)

    tab.Button = btn
    tab.GlyphLabel = glyph
    tab.NameLabel = label

    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then
            btn.BackgroundColor3 = Theme.NavHover
            label.TextColor3 = Theme.Text
            glyph.TextColor3 = Theme.Text
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.ActiveTab ~= tab then
            btn.BackgroundColor3 = Theme.Sidebar
            label.TextColor3 = Theme.TextDim
            glyph.TextColor3 = Theme.TextDim
        end
    end)
    btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

    self.Tabs[#self.Tabs + 1] = tab
    if not self.ActiveTab then self:SelectTab(tab) end
    return tab
end

function Panel:SelectTab(tab)
    if self.ActiveTab == tab then return end
    self.ActiveTab = tab
    for _, t in ipairs(self.Tabs) do
        local active = (t == tab)
        t.Button.BackgroundColor3 = active and Theme.NavActive or Theme.Sidebar
        t.NameLabel.TextColor3 = active and Theme.TextBright or Theme.TextDim
        t.GlyphLabel.TextColor3 = active and Theme.TextBright or Theme.TextDim
    end
    for _, child in ipairs(self.Scroll:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "UIPadding" and child.Name ~= "UIListLayout" then
            child.Visible = (child:GetAttribute("TabRef") == tab.Name)
        end
    end
    if tab.Spec.Intro then
        self:SetStatus(tab.Spec.Intro)
    end
end

-- ---------------------------------------------------------------------------
-- Controls
-- ---------------------------------------------------------------------------
local function tagTab(inst, tab) inst:SetAttribute("TabRef", tab.Name) end

function Panel:AddSection(tab, label)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = string.upper(tostring(label or "")),
        TextColor3 = Theme.TextQuiet,
        Font = Theme.FontHeader,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, self.Scroll)
    tagTab(lbl, tab)
    lbl.Visible = (self.ActiveTab == tab)
    return lbl
end

function Panel:AddToggle(tab, title, help, value, callback)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, help and 52 or 40),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(row, UDim.new(0, 6))
    stroke(row, Theme.BorderSoft, 1)
    tagTab(row, tab)
    row.Visible = (self.ActiveTab == tab)

    local titleLbl = new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 18),
        Position = UDim2.fromOffset(12, help and 8 or 11),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    if help then
        new("TextLabel", {
            Size = UDim2.new(1, -70, 0, 14),
            Position = UDim2.fromOffset(12, 26),
            BackgroundTransparency = 1,
            Text = tostring(help),
            TextColor3 = Theme.TextQuiet,
            Font = Theme.FontBody,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
    end

    local track = new("Frame", {
        Size = UDim2.fromOffset(34, 20),
        Position = UDim2.new(1, -46, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.ToggleOff,
        BorderSizePixel = 0,
    }, row)
    corner(track, UDim.new(1, 0))
    stroke(track, Theme.Border, 1)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Theme.ToggleKnob,
        BorderSizePixel = 0,
    }, track)
    corner(knob, UDim.new(1, 0))

    local state = value == true
    local function render(animate)
        local target = state and UDim2.fromOffset(17, 3) or UDim2.fromOffset(3, 3)
        local bg = state and Theme.ToggleOn or Theme.ToggleOff
        local knobColor = state and Theme.ToggleKnobOn or Theme.ToggleKnob
        if animate then
            tween(knob, 0.12, {Position = target})
            tween(track, 0.12, {BackgroundColor3 = bg})
            tween(knob, 0.12, {BackgroundColor3 = knobColor})
        else
            knob.Position = target
            track.BackgroundColor3 = bg
            knob.BackgroundColor3 = knobColor
        end
    end
    render(false)

    local click = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
    }, row)
    click.MouseButton1Click:Connect(function()
        state = not state
        render(true)
        if type(callback) == "function" then
            local ok, err = pcall(callback, state)
            if not ok then self:Notify("Erro", tostring(err), true) end
        end
    end)

    return row
end

function Panel:AddDisabledToggle(tab, title, help, value)
    local row = self:AddToggle(tab, title, help, value, nil)
    local overlay = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        Active = false,
    }, row)
    overlay.MouseButton1Click:Connect(function() end)
    return row
end

function Panel:AddSlider(tab, title, min, max, step, value, callback, format)
    min = tonumber(min) or 0
    max = tonumber(max) or 100
    step = tonumber(step) or 1
    if step <= 0 then step = 1 end
    value = tonumber(value) or min

    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(row, UDim.new(0, 6))
    stroke(row, Theme.BorderSoft, 1)
    tagTab(row, tab)
    row.Visible = (self.ActiveTab == tab)

    local titleLbl = new("TextLabel", {
        Size = UDim2.new(1, -80, 0, 18),
        Position = UDim2.fromOffset(12, 8),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local fmt = format
    if type(fmt) ~= "function" then fmt = function(v) return tostring(v) end end

    local out = new("TextLabel", {
        Size = UDim2.new(0, 70, 0, 18),
        Position = UDim2.new(1, -82, 0, 8),
        BackgroundTransparency = 1,
        Text = fmt(value),
        TextColor3 = Theme.TextDim,
        Font = Theme.FontMono,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    local track = new("Frame", {
        Size = UDim2.new(1, -24, 0, 5),
        Position = UDim2.new(0, 12, 0, 34),
        BackgroundColor3 = Theme.BorderSoft,
        BorderSizePixel = 0,
    }, row)
    corner(track, UDim.new(1, 0))

    local fill = new("Frame", {
        Size = UDim2.new((value - min) / math.max(max - min, 1e-6), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, UDim.new(1, 0))

    local knob = new("Frame", {
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new((value - min) / math.max(max - min, 1e-6), 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, track)
    corner(knob, UDim.new(1, 0))

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 20),
        Position = UDim2.new(0, 0, 0.5, -10),
        BackgroundTransparency = 1,
        Text = "",
    }, row)

    local dragging = false
    local function setFromX(px)
        local abs = track.AbsolutePosition.X
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local ratio = math.clamp((px - abs) / w, 0, 1)
        local raw = min + ratio * (max - min)
        local snapped = math.floor((raw - min) / step + 0.5) * step + min
        snapped = math.clamp(snapped, min, max)
        value = snapped
        local r2 = (value - min) / math.max(max - min, 1e-6)
        fill.Size = UDim2.new(r2, 0, 1, 0)
        knob.Position = UDim2.new(r2, 0, 0.5, 0)
        out.Text = fmt(value)
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    UserInput.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)
    UserInput.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if type(callback) == "function" then
                local ok, err = pcall(callback, value)
                if not ok then self:Notify("Erro", tostring(err), true) end
            end
        end
    end)

    return row
end

function Panel:AddInlineSlider(tab, title, min, max, step, value, callback, format)
    return self:AddSlider(tab, title, min, max, step, value, callback, format)
end

function Panel:AddDropdown(tab, title, help, options, value, callback)
    options = options or {}
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, help and 56 or 42),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(row, UDim.new(0, 6))
    stroke(row, Theme.BorderSoft, 1)
    tagTab(row, tab)
    row.Visible = (self.ActiveTab == tab)

    new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 18),
        Position = UDim2.fromOffset(12, help and 8 or 12),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    if help then
        new("TextLabel", {
            Size = UDim2.new(1, -24, 0, 14),
            Position = UDim2.fromOffset(12, 26),
            BackgroundTransparency = 1,
            Text = tostring(help),
            TextColor3 = Theme.TextQuiet,
            Font = Theme.FontBody,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
    end

    local current = value
    local trigger = new("TextButton", {
        Size = UDim2.new(0, 130, 0, 24),
        Position = UDim2.new(1, -142, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.Action,
        Text = tostring(current or "—"),
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 11,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, row)
    corner(trigger, UDim.new(0, 5))
    stroke(trigger, Theme.ActionBorder, 1)

    local list = new("Frame", {
        Size = UDim2.fromOffset(130, 0),
        Position = UDim2.new(1, -142, 1, 4),
        BackgroundColor3 = Theme.Action,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 5,
    }, row)
    corner(list, UDim.new(0, 5))
    stroke(list, Theme.ActionBorder, 1)
    local listLayout = new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, list)
    padding(list, 4, 4, 4, 4)

    local open = false
    local function rebuild()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for _, opt in ipairs(options) do
            local ob = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundColor3 = (opt == current) and Theme.NavActive or Theme.Action,
                Text = tostring(opt),
                TextColor3 = (opt == current) and Theme.TextBright or Theme.Text,
                Font = Theme.FontBody,
                TextSize = 11,
                BorderSizePixel = 0,
                AutoButtonColor = false,
            }, list)
            corner(ob, UDim.new(0, 4))
            ob.MouseButton1Click:Connect(function()
                current = opt
                trigger.Text = tostring(opt)
                open = false
                list.Visible = false
                if type(callback) == "function" then
                    local ok, err = pcall(callback, opt)
                    if not ok then self:Notify("Erro", tostring(err), true) end
                end
            end)
        end
        list.Size = UDim2.fromOffset(130, math.max(#options * 24 + 8, 24))
    end
    rebuild()

    trigger.MouseButton1Click:Connect(function()
        open = not open
        list.Visible = open
    end)

    return row
end

function Panel:AddAction(tab, title, help, buttonLabel, callback, primary)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, help and 56 or 42),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(row, UDim.new(0, 6))
    stroke(row, Theme.BorderSoft, 1)
    tagTab(row, tab)
    row.Visible = (self.ActiveTab == tab)

    new("TextLabel", {
        Size = UDim2.new(1, -140, 0, 18),
        Position = UDim2.fromOffset(12, help and 8 or 12),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    if help then
        new("TextLabel", {
            Size = UDim2.new(1, -140, 0, 14),
            Position = UDim2.fromOffset(12, 26),
            BackgroundTransparency = 1,
            Text = tostring(help),
            TextColor3 = Theme.TextQuiet,
            Font = Theme.FontBody,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
    end

    local bg = primary and Theme.Primary or Theme.Action
    local fg = primary and Theme.PrimaryInk or Theme.Text
    local hover = primary and Theme.PrimaryHover or Theme.ActionHover

    local btn = new("TextButton", {
        Size = UDim2.new(0, 110, 0, 26),
        Position = UDim2.new(1, -122, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = bg,
        Text = tostring(buttonLabel or title or "Executar"),
        TextColor3 = fg,
        Font = Theme.FontBody,
        TextSize = 11,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, row)
    corner(btn, UDim.new(0, 5))
    if not primary then stroke(btn, Theme.ActionBorder, 1) end

    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = hover end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = bg end)
    btn.MouseButton1Click:Connect(function()
        if type(callback) == "function" then
            local ok, err = pcall(callback)
            if not ok then self:Notify("Erro", tostring(err), true) end
        end
    end)

    return row
end

function Panel:AddNotice(tab, text, title)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(row, UDim.new(0, 6))
    stroke(row, Theme.BorderSoft, 1)
    tagTab(row, tab)
    row.Visible = (self.ActiveTab == tab)

    local body = tostring(text or "")
    if title then body = tostring(title) .. "\n" .. body end

    new("TextLabel", {
        Size = UDim2.new(1, -24, 1, -16),
        Position = UDim2.fromOffset(12, 8),
        BackgroundTransparency = 1,
        Text = body,
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, row)

    return row
end

-- ---------------------------------------------------------------------------
-- Notify / Status
-- ---------------------------------------------------------------------------
function Panel:Notify(title, message, isError)
    local toast = new("Frame", {
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Theme.Toast,
        BorderSizePixel = 0,
        BackgroundTransparency = 0.05,
    }, self.ToastHolder)
    corner(toast, UDim.new(0, 6))
    stroke(toast, isError and Theme.ToastError or Theme.ToastBorder, 1)

    new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 16),
        Position = UDim2.fromOffset(10, 8),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = isError and Color3.fromRGB(255, 140, 140) or Theme.TextBright,
        Font = Theme.FontHeader,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, toast)

    new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 24),
        Position = UDim2.fromOffset(10, 26),
        BackgroundTransparency = 1,
        Text = tostring(message or ""),
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 10,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, toast)

    task.delay(4, function()
        if toast.Parent then
            tween(toast, 0.3, {BackgroundTransparency = 1})
            task.delay(0.3, function() toast:Destroy() end)
        end
    end)

    return toast
end

function Panel:SetStatus(text)
    if self.StatusLabel then
        self.StatusLabel.Text = tostring(text or "")
    end
end

-- ---------------------------------------------------------------------------
-- Factory
-- ---------------------------------------------------------------------------
local Factory = {}
Factory.__index = Factory

function Factory.new(spec)
    return Panel.new(spec)
end

return Factory