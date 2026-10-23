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
    Mark          = Color3.fromRGB(221, 221, 221),
    MarkInk       = Color3.fromRGB(21, 21, 21),
    -- index.html tokens
    FieldBg       = Color3.fromRGB(28, 28, 28),   -- .field background #1c1c1c
    FieldLine     = Color3.fromRGB(53, 53, 53),   -- .field border #353535
    Placeholder   = Color3.fromRGB(102, 102, 102),-- .field::placeholder #666
    SearchBg      = Color3.fromRGB(24, 24, 24),   -- .search background #181818
    SectionLabel  = Color3.fromRGB(119, 119, 119),-- .section-label #777
    Badge         = Color3.fromRGB(136, 136, 136),-- .badge #888
    BadgeLine     = Color3.fromRGB(56, 56, 56),   -- .badge border #383838
    Intro         = Color3.fromRGB(119, 119, 119),-- .intro #777
    Heading       = Color3.fromRGB(239, 239, 239),-- h1 color #efefef
    NoticeBg      = Color3.fromRGB(27, 27, 27),   -- .notice background #1b1b1b
    NoticeLine    = Color3.fromRGB(48, 48, 48),   -- .notice border #303030
    KeybindBg     = Color3.fromRGB(34, 34, 34),   -- .keybind background #222
    KeybindLine   = Color3.fromRGB(59, 59, 59),   -- .keybind border #3b3b3b
    KeybindText   = Color3.fromRGB(187, 187, 187),-- .keybind color #bbb
    ToggleOnAlt   = Color3.fromRGB(214, 214, 214),-- .toggle:checked #d6d6d6
    ToggleKnobAlt = Color3.fromRGB(146, 146, 146),-- .toggle::after #929292
    ToggleInkOn   = Color3.fromRGB(43, 43, 43),   -- checked knob #2b2b2b
    NavActive     = Color3.fromRGB(41, 41, 41),   -- nav button.active #292929
    NavHover      = Color3.fromRGB(35, 35, 35),   -- nav button:hover #232323
    NavRing       = Color3.fromRGB(54, 54, 54),   -- nav button.active inset ring #363636
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
    Footer        = Color3.fromRGB(20, 20, 20),   -- footer background #141414
    ShellBg       = Color3.fromRGB(25, 25, 25),   -- .panel-toggle background #191919
    ToastBorder   = Color3.fromRGB(60, 60, 60),
    ToastError    = Color3.fromRGB(121, 80, 80),
    ScrollBar     = Color3.fromRGB(58, 58, 58),
    FontHeader    = Enum.Font.GothamBold,
    FontBody      = Enum.Font.Gotham,
    FontMono      = Enum.Font.Code,
}

local WIN_W, WIN_H = 780, 520
local SIDEBAR_W    = 160
local HEADER_H     = 66
-- index.html: .row{min-height:58px} .toggle{width:35px;height:21px} ::after 15px
local ROW_MIN_H    = 58
local TOGGLE_W     = 35
local TOGGLE_H     = 21
local KNOB         = 15

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

-- Makes a frame draggable by a handle. When `sloppy` is true the drag only
-- begins after the pointer has moved a few pixels, so a handle that is also a
-- button (the floating reopen chip) still registers its click.
local function makeDraggable(frame, handle, sloppy)
    local dragging, dragStart, startPos = false, nil, nil
    local moved = false
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
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
            if sloppy and not moved then
                if math.abs(delta.X) < 5 and math.abs(delta.Y) < 5 then return end
                moved = true
            end
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                       startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    return function() return moved end
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
        Size = UDim2.fromOffset(34, 34),
        Position = UDim2.fromOffset(24, 16),
        BackgroundColor3 = Theme.Mark,
        Text = "D",
        TextColor3 = Theme.MarkInk,
        Font = Theme.FontHeader,
        TextSize = 27,
        BorderSizePixel = 0,
    }, header)
    corner(badge, UDim.new(0, 8))

    local title = new("TextLabel", {
        Size = UDim2.new(0, 200, 0, 18),
        Position = UDim2.fromOffset(69, 17),
        BackgroundTransparency = 1,
        Text = spec.Title or "DepHub",
        TextColor3 = Theme.TextBright,
        Font = Theme.FontHeader,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local gameName = new("TextLabel", {
        Size = UDim2.new(0, 300, 0, 14),
        Position = UDim2.fromOffset(69, 37),
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
        Size = UDim2.new(1, 0, 1, -39),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.ScrollBar,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, main)
    -- index.html main{padding:28px 30px 32px}
    padding(scroll, 28, 30, 28, 30)
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroll)
    self.Scroll = scroll

    -- index.html footer{min-height:39px;padding:12px 25px;background:#141414}
    local status = new("TextLabel", {
        Name = "Status",
        Size = UDim2.new(1, 0, 0, 39),
        Position = UDim2.new(0, 0, 1, -39),
        BackgroundColor3 = Theme.Footer,
        BorderSizePixel = 0,
        Text = "",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)
    padding(status, 0, 25, 0, 25)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.BorderSoft,
        BorderSizePixel = 0,
    }, status)
    self.StatusLabel = status

    -- index.html .panel-toggle: a floating chip with the mark and the name. It
    -- collapses its name (and rotates the mark -13deg) while the panel is open,
    -- and can be dragged around the screen.
    local floating = new("TextButton", {
        Name = "FloatingButton",
        Size = UDim2.fromOffset(140, 45),
        Position = UDim2.new(0, 24, 0, 22),
        BackgroundColor3 = Theme.ShellBg or Theme.Sidebar,
        Text = "",
        BorderSizePixel = 0,
        Visible = false,
        AutoButtonColor = false,
    }, gui)
    corner(floating, UDim.new(0, 10))
    stroke(floating, Theme.Border, 1)

    local toggleMark = new("TextLabel", {
        Name = "ToggleMark",
        Size = UDim2.fromOffset(27, 27),
        Position = UDim2.fromOffset(9, 9),
        BackgroundColor3 = Theme.Mark,
        Text = "d",
        TextColor3 = Theme.MarkInk,
        Font = Theme.FontHeader,
        TextSize = 20,
        BorderSizePixel = 0,
        Rotation = 0,
    }, floating)
    corner(toggleMark, UDim.new(0, 6))

    local toggleName = new("TextLabel", {
        Name = "ToggleName",
        Size = UDim2.fromOffset(90, 27),
        Position = UDim2.fromOffset(46, 9),
        BackgroundTransparency = 1,
        Text = "DepHub",
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, floating)

    -- .panel-toggle[aria-expanded=false] .toggle-name{max-width:0;opacity:0}
    local function setFloatingExpanded(expanded)
        toggleName.Visible = false
        floating.Size = UDim2.fromOffset(45, 45)
        tween(toggleMark, 0.35, {Rotation = expanded and 0 or -13}, Enum.EasingStyle.Quint)
    end
    setFloatingExpanded(false)

    floating.MouseButton1Click:Connect(function()
        root.Visible = true
        floating.Visible = false
    end)
    -- Dragging the chip moves it; a click that was a drag does not toggle.
    local wasDragged = makeDraggable(floating, floating, true)
    self.FloatingButton = floating

    -- Insert toggles the panel; the floating button reopens it when hidden.
    -- index.html drives .rectangle with opacity/translateY/scale on open+close.
    local function setPanelOpen(isOpen)
        root.Visible = true
        if isOpen then
            root.Position = UDim2.new(0.5, 0, 0.5, 18)
            root.Size = UDim2.fromOffset(math.floor(WIN_W * 0.96), math.floor(WIN_H * 0.96))
            tween(root, 0.35, {
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.fromOffset(WIN_W, WIN_H),
            }, Enum.EasingStyle.Back)
            floating.Visible = false
        else
            tween(root, 0.22, {Position = UDim2.new(0.5, 0, 0.5, 18)}, Enum.EasingStyle.Quad)
            task.delay(0.22, function()
                if not (self and root.Parent) then return end
                root.Visible = false
                floating.Visible = true
            end)
        end
    end
    self.SetPanelOpen = setPanelOpen

    UserInput.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            setPanelOpen(not root.Visible)
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
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Theme.Sidebar,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, self.Sidebar)
    corner(btn, UDim.new(0, 7))
    -- The active tab shows a 1px inset ring (box-shadow:inset 0 0 0 1px #363636).
    local btnStroke = stroke(btn, Theme.NavRing or Theme.BorderSoft, 1)
    btnStroke.Transparency = 1

    local glyph = new("TextLabel", {
        Size = UDim2.fromOffset(20, 42),
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
    tab.ButtonStroke = btnStroke
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
        -- nav button.active{box-shadow:inset 0 0 0 1px #363636}
        if t.ButtonStroke then
            t.ButtonStroke.Transparency = active and 0 or 1
        end
    end
    for _, child in ipairs(self.Scroll:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "UIPadding" and child.Name ~= "UIListLayout" then
            local visible = (child:GetAttribute("TabRef") == tab.Name)
            child.Visible = visible
            -- UIListLayout owns Position, so the appear animation is a fade
            -- rather than the CSS translateY (which a layout would override).
            if visible then
                child.BackgroundTransparency = math.min(1, (child.BackgroundTransparency or 0) + 0.85)
                tween(child, 0.28, {BackgroundTransparency = 0})
            end
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

-- Marks a control as searchable so Panel:AddSearch can filter it. The text the
-- search matches against is whatever the caller gives; the CSS equivalent is a
-- .searchable row whose textContent the browser's filter reads.
local function tagSearch(inst, text)
    inst:SetAttribute("Searchable", true)
    inst:SetAttribute("SearchText", tostring(text or ""))
end

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
        Size = UDim2.new(1, 0, 0, help and ROW_MIN_H or 46),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(row, UDim.new(0, 6))
    stroke(row, Theme.BorderSoft, 1)
    tagTab(row, tab)
    row.Visible = (self.ActiveTab == tab)
    tagSearch(row, tostring(title or "") .. " " .. tostring(help or ""))

    local titleLbl = new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 18),
        Position = UDim2.fromOffset(12, help and 10 or 14),
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
            Position = UDim2.fromOffset(12, 30),
            BackgroundTransparency = 1,
            Text = tostring(help),
            TextColor3 = Theme.TextQuiet,
            Font = Theme.FontBody,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
    end

    local track = new("Frame", {
        Size = UDim2.fromOffset(TOGGLE_W, TOGGLE_H),
        Position = UDim2.new(1, -47, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.ToggleOff,
        BorderSizePixel = 0,
    }, row)
    corner(track, UDim.new(1, 0))
    stroke(track, Theme.Border, 1)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(KNOB, KNOB),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Theme.ToggleKnobAlt,
        BorderSizePixel = 0,
    }, track)
    corner(knob, UDim.new(1, 0))

    -- index.html: knob travels 14px when checked (35 - 15 - 2*3 = 14).
    local KNOB_OFF  = UDim2.fromOffset(3, 3)
    local KNOB_ON   = UDim2.fromOffset(17, 3)
    local state = value == true
    local function render(animate)
        local target = state and KNOB_ON or KNOB_OFF
        local bg = state and Theme.ToggleOnAlt or Theme.ToggleOff
        local knobColor = state and Theme.ToggleInkOn or Theme.ToggleKnobAlt
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
    -- .disabled{opacity:.45}
    for _, child in ipairs(row:GetDescendants()) do
        if child:IsA("GuiObject") then
            child.BackgroundTransparency = math.min(1, (child.BackgroundTransparency or 0) + 0.55)
            if child:IsA("TextLabel") then
                child.TextTransparency = math.min(1, (child.TextTransparency or 0) + 0.55)
            end
            if child:IsA("UIStroke") then child.Transparency = math.min(1, (child.Transparency or 0) + 0.55) end
        end
    end
    overlay.MouseButton1Click:Connect(function() end)
    return row
end

-- index.html .checkbox: a plain 16x16 square, separate from the toggle.
function Panel:AddCheckbox(tab, title, help, value, callback)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, help and ROW_MIN_H or 46),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(row, UDim.new(0, 6))
    stroke(row, Theme.BorderSoft, 1)
    tagTab(row, tab)
    row.Visible = (self.ActiveTab == tab)
    tagSearch(row, tostring(title or "") .. " " .. tostring(help or ""))

    new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 18),
        Position = UDim2.fromOffset(12, help and 10 or 14),
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
            Position = UDim2.fromOffset(12, 30),
            BackgroundTransparency = 1,
            Text = tostring(help),
            TextColor3 = Theme.TextQuiet,
            Font = Theme.FontBody,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
    end

    local state = value == true
    local box = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, -28, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = state and Theme.Accent or Theme.FieldBg,
        BorderSizePixel = 0,
    }, row)
    corner(box, UDim.new(0, 3))
    local boxStroke = stroke(box, Theme.FieldLine, 1)

    local tick = new("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "x",
        TextColor3 = Theme.AccentInk,
        Font = Theme.FontHeader,
        TextSize = 11,
        Visible = state,
    }, box)

    local click = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
    }, row)
    click.MouseButton1Click:Connect(function()
        state = not state
        box.BackgroundColor3 = state and Theme.Accent or Theme.FieldBg
        boxStroke.Color = state and Theme.Accent or Theme.FieldLine
        tick.Visible = state
        if type(callback) == "function" then
            local ok, err = pcall(callback, state)
            if not ok then self:Notify("Erro", tostring(err), true) end
        end
    end)

    return row
end

-- index.html input[type=color]: a swatch that opens a palette of swatches.
-- Roblox has no native colour input, so the picker shows a grid of presets and
-- an RGB slider set, which covers the same ground as the browser control.
function Panel:AddColorPicker(tab, title, value, callback)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(row, UDim.new(0, 6))
    stroke(row, Theme.BorderSoft, 1)
    tagTab(row, tab)
    row.Visible = (self.ActiveTab == tab)
    tagSearch(row, tostring(title or ""))

    new("TextLabel", {
        Size = UDim2.new(1, -90, 0, 18),
        Position = UDim2.fromOffset(12, 14),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local current = value or Theme.Accent
    local swatch = new("TextButton", {
        Size = UDim2.fromOffset(30, 22),
        Position = UDim2.new(1, -42, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = current,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, row)
    corner(swatch, UDim.new(0, 4))
    stroke(swatch, Theme.FieldLine, 1)

    -- A preset grid stands in for the browser's colour wheel.
    local presets = {
        Color3.fromRGB(221, 221, 221), Color3.fromRGB(255, 255, 255),
        Color3.fromRGB(239, 68, 68),   Color3.fromRGB(249, 115, 22),
        Color3.fromRGB(234, 179, 8),   Color3.fromRGB(34, 197, 94),
        Color3.fromRGB(6, 182, 212),   Color3.fromRGB(59, 130, 246),
        Color3.fromRGB(168, 85, 247),  Color3.fromRGB(236, 72, 153),
    }

    local list = new("Frame", {
        Size = UDim2.fromOffset(200, 0),
        Position = UDim2.new(1, -212, 1, 4),
        BackgroundColor3 = Theme.Action,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 6,
    }, row)
    corner(list, UDim.new(0, 5))
    stroke(list, Theme.ActionBorder, 1)
    padding(list, 8, 8, 8, 8)
    new("UIGridLayout", {
        CellSize = UDim2.fromOffset(32, 32),
        CellPadding = UDim2.fromOffset(6, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, list)

    for index, colour in ipairs(presets) do
        local cell = new("TextButton", {
            Size = UDim2.fromOffset(32, 32),
            LayoutOrder = index,
            BackgroundColor3 = colour,
            Text = "",
            BorderSizePixel = 0,
            AutoButtonColor = false,
        }, list)
        corner(cell, UDim.new(0, 4))
        stroke(cell, Theme.ActionBorder, 1)
        cell.MouseButton1Click:Connect(function()
            current = colour
            swatch.BackgroundColor3 = colour
            list.Visible = false
            if type(callback) == "function" then
                local ok, err = pcall(callback, colour)
                if not ok then self:Notify("Erro", tostring(err), true) end
            end
        end)
    end
    list.Size = UDim2.fromOffset(200, math.ceil(#presets / 5) * 38 + 16)

    swatch.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)

    return row
end

-- index.html .keybind: a button that captures the next key pressed.
function Panel:AddKeybind(tab, title, defaultKey, callback)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(row, UDim.new(0, 6))
    stroke(row, Theme.BorderSoft, 1)
    tagTab(row, tab)
    row.Visible = (self.ActiveTab == tab)
    tagSearch(row, tostring(title or ""))

    new("TextLabel", {
        Size = UDim2.new(1, -110, 0, 18),
        Position = UDim2.fromOffset(12, 14),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local current = defaultKey or "Insert"
    local binding = false
    local btn = new("TextButton", {
        Size = UDim2.fromOffset(84, 28),
        Position = UDim2.new(1, -96, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.KeybindBg,
        Text = tostring(current),
        TextColor3 = Theme.KeybindText,
        Font = Theme.FontBody,
        TextSize = 11,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, row)
    corner(btn, UDim.new(0, 5))
    stroke(btn, Theme.KeybindLine, 1)

    btn.MouseButton1Click:Connect(function()
        binding = true
        btn.Text = "Pressione uma tecla"
    end)

    local conn
    conn = UserInput.InputBegan:Connect(function(input, processed)
        if not binding then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            binding = false
            btn.Text = tostring(current)
            return
        end
        local name = input.KeyCode.Name
        current = name
        btn.Text = name
        binding = false
        if type(callback) == "function" then
            local ok, err = pcall(callback, name)
            if not ok then self:Notify("Erro", tostring(err), true) end
        end
    end)

    return row, function() if conn then conn:Disconnect() end end
end

-- index.html input.field / .input-group: a labelled text field.
function Panel:AddField(tab, title, placeholder, value, callback)
    local group = new("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundTransparency = 1,
    }, self.Scroll)
    tagTab(group, tab)
    group.Visible = (self.ActiveTab == tab)
    tagSearch(group, tostring(title or ""))

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, group)

    local box = new("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        Position = UDim2.fromOffset(0, 22),
        BackgroundColor3 = Theme.FieldBg,
        BorderSizePixel = 0,
    }, group)
    corner(box, UDim.new(0, 6))
    local boxStroke = stroke(box, Theme.FieldLine, 1)

    local input = new("TextBox", {
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = tostring(value or ""),
        PlaceholderText = tostring(placeholder or ""),
        PlaceholderColor3 = Theme.Placeholder,
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, box)

    input.Focused:Connect(function() boxStroke.Color = Theme.FieldFocus end)
    input.FocusLost:Connect(function()
        boxStroke.Color = Theme.FieldLine
        if type(callback) == "function" then
            local ok, err = pcall(callback, input.Text)
            if not ok then self:Notify("Erro", tostring(err), true) end
        end
    end)

    return group, input
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
    tagSearch(row, tostring(title or "") .. " " .. tostring(help or ""))

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
    tagSearch(row, tostring(title or "") .. " " .. tostring(help or ""))

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
    tagSearch(row, tostring(title or "") .. " " .. tostring(help or ""))

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
-- Layout: heading, section, collapsible
-- ---------------------------------------------------------------------------

-- index.html .heading: <h1> + <p class="intro"> + <span class="badge">, on one
-- row with the badge pushed to the right.
function Panel:AddHeading(tab, title, intro, badge)
    local block = new("Frame", {
        Size = UDim2.new(1, 0, 0, intro and 52 or 34),
        BackgroundTransparency = 1,
    }, self.Scroll)
    tagTab(block, tab)
    block.Visible = (self.ActiveTab == tab)

    new("TextLabel", {
        Size = UDim2.new(1, -90, 0, 22),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = Theme.Heading,
        Font = Theme.FontHeader,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, block)

    if intro then
        new("TextLabel", {
            Size = UDim2.new(1, -90, 0, 14),
            Position = UDim2.fromOffset(0, 25),
            BackgroundTransparency = 1,
            Text = tostring(intro),
            TextColor3 = Theme.Intro,
            Font = Theme.FontBody,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, block)
    end

    if badge then
        local lbl = new("TextLabel", {
            Size = UDim2.fromOffset(60, 20),
            Position = UDim2.new(1, -60, 0, 0),
            BackgroundColor3 = Theme.Field,
            Text = string.upper(tostring(badge)),
            TextColor3 = Theme.Badge,
            Font = Theme.FontHeader,
            TextSize = 9,
            BorderSizePixel = 0,
        }, block)
        corner(lbl, UDim.new(0, 4))
        stroke(lbl, Theme.BadgeLine, 1)
    end

    return block
end

-- index.html .search: an input that filters every .searchable row in the tab.
-- Rows registered through AddToggle/AddSlider/AddDropdown/AddField/AddAction
-- carry a SearchText attribute and are shown/hidden as the query changes.
function Panel:AddSearch(tab, placeholder)
    local box = new("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Theme.SearchBg,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(box, UDim.new(0, 6))
    local boxStroke = stroke(box, Theme.FieldLine, 1)
    tagTab(box, tab)
    box.Visible = (self.ActiveTab == tab)

    local input = new("TextBox", {
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = tostring(placeholder or "Buscar..."),
        PlaceholderColor3 = Theme.Placeholder,
        TextColor3 = Theme.Text,
        Font = Theme.FontBody,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, box)

    -- .field:focus{border-color:#777;background:#202020}
    input.Focused:Connect(function() boxStroke.Color = Theme.FieldFocus end)
    input.FocusLost:Connect(function() boxStroke.Color = Theme.FieldLine end)

    local empty = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "Nenhum componente encontrado.",
        TextColor3 = Theme.TextQuiet,
        Font = Theme.FontBody,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
    }, self.Scroll)
    tagTab(empty, tab)
    empty.Visible = false

    input:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(input.Text)
        local shown = 0
        for _, child in ipairs(self.Scroll:GetChildren()) do
            if child:GetAttribute("TabRef") == tab.Name and child:GetAttribute("Searchable") then
                local text = string.lower(tostring(child:GetAttribute("SearchText") or ""))
                local match = query == "" or string.find(text, query, 1, true) ~= nil
                child.Visible = match and self.ActiveTab == tab
                if match then shown = shown + 1 end
            end
        end
        empty.Visible = (shown == 0) and self.ActiveTab == tab
    end)

    return box
end

-- index.html details/summary: a collapsible block that hides its children.
function Panel:AddDetails(tab, summary, expanded)
    local body = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Field,
        BorderSizePixel = 0,
    }, self.Scroll)
    corner(body, UDim.new(0, 6))
    stroke(body, Theme.BorderSoft, 1)
    tagTab(body, tab)
    body.Visible = (self.ActiveTab == tab)

    local open = expanded ~= false
    local header = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, body)

    local arrow = new("TextLabel", {
        Size = UDim2.fromOffset(16, 36),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = open and "v" or ">",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 11,
    }, header)

    new("TextLabel", {
        Size = UDim2.new(1, -44, 1, 0),
        Position = UDim2.fromOffset(32, 0),
        BackgroundTransparency = 1,
        Text = tostring(summary or ""),
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBody,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    -- Children are laid out below the header inside the same frame.
    local content = new("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -24, 0, 0),
        Position = UDim2.fromOffset(12, 40),
        BackgroundTransparency = 1,
        Visible = open,
    }, body)
    local layout = new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, content)

    -- Size the block to its content whenever the content changes.
    local function resize()
        local h = layout.AbsoluteContentSize.Y
        content.Size = UDim2.new(1, -24, 0, h)
        body.Size = UDim2.new(1, 0, 0, 40 + (open and h + 4 or 0))
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)

    header.MouseButton1Click:Connect(function()
        open = not open
        arrow.Text = open and "v" or ">"
        content.Visible = open
        resize()
    end)

    resize()
    return body, content
end

function Panel:AddButtonGroup(tab, buttons, onLayout)
    local group = new("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
    }, self.Scroll)
    tagTab(group, tab)
    group.Visible = (self.ActiveTab == tab)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, group)

    for index, spec in ipairs(buttons or {}) do
        local primary = spec.primary == true
        local bg = primary and Theme.Primary or Theme.Action
        local fg = primary and Theme.PrimaryInk or Theme.Text
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(spec.width or 110, 36),
            LayoutOrder = index,
            BackgroundColor3 = bg,
            Text = tostring(spec.label or "OK"),
            TextColor3 = fg,
            Font = Theme.FontBody,
            TextSize = 11,
            BorderSizePixel = 0,
            AutoButtonColor = false,
        }, group)
        corner(btn, UDim.new(0, 5))
        if not primary then stroke(btn, Theme.ActionBorder, 1) end
        local idle = bg
        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = primary and Theme.PrimaryHover or Theme.ActionHover end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = idle end)
        btn.MouseButton1Click:Connect(function()
            if type(spec.callback) == "function" then
                local ok, err = pcall(spec.callback)
                if not ok then self:Notify("Erro", tostring(err), true) end
            end
        end)
    end

    if type(onLayout) == "function" then onLayout(group) end
    return group
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