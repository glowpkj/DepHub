-- DepHub panel library.
--
-- Faithful Luau port of the authored interface mockup (proposta-02.html +
-- dephub.css). It rebuilds the same monochrome window with Roblox GUI
-- instances: the fixed 840x560 shell, the draggable header with the brand mark,
-- the current-game caption, the three macOS-style window buttons, the 160px
-- section nav, per-page headings, the search field, and the full control set
-- (field, toggle, checkbox, range, input group, choice trigger, colour trigger,
-- action, keybind, notice, collapsible, button group), plus the toast and the
-- confirmation dialog.
--
-- The library is pure presentation: callers hand it a spec and receive
-- callbacks. src/core/panel-host.lua binds those callbacks to a backend.
--
-- The ScreenGui is named with "dephub" so src/core/ui-guard keeps it enabled,
-- on top and parented to gethui().
--
-- Modules load as plain chunks (no require), so the theme tokens below are
-- inlined; src/frontend/theme.lua mirrors the same values as the reference.

-- ---------------------------------------------------------------------------
-- Theme (kept in lockstep with src/frontend/theme.lua)
-- ---------------------------------------------------------------------------
local Theme = {}
local function rgb(r, g, b) return {r = r, g = g, b = b} end

Theme.Accent = rgb(188, 188, 188)
Theme.Bg = rgb(9, 9, 9)
Theme.Surface = rgb(16, 16, 16)
Theme.Line = rgb(37, 37, 37)
Theme.Text = rgb(222, 222, 222)
Theme.Muted = rgb(154, 154, 154)
Theme.Quiet = rgb(119, 119, 119)

Theme.Left = 24
Theme.BrandTop = 20
Theme.Header = 100
Theme.Footer = 40
Theme.MinWidth = 840
Theme.MinHeight = 560
Theme.WindowRadius = 12
Theme.WindowBorder = rgb(44, 44, 44)

Theme.MarkBg = rgb(209, 209, 209)
Theme.MarkInk = rgb(23, 23, 23)
Theme.MarkSize = 30
Theme.MarkRadius = 7
Theme.BrandHeight = 30

Theme.GameTop = 64
Theme.GameGap = 7
Theme.GameIndicator = 4
Theme.GameIndicatorColor = rgb(153, 153, 153)
Theme.GameNameColor = rgb(160, 160, 160)
Theme.GameNameFont = 11

Theme.WindowButtonsRight = 16
Theme.WindowButtonsTop = 13
Theme.WindowButtonW = 30
Theme.WindowButtonH = 44
Theme.WindowDot = 13
Theme.CloseDot = rgb(255, 96, 88)
Theme.MinDot = rgb(254, 188, 46)
Theme.MaxDot = rgb(40, 200, 64)

Theme.NavWidth = 160
Theme.NavBorder = rgb(28, 28, 28)
Theme.NavPadV = 20
Theme.NavPadH = 10
Theme.NavGap = 7
Theme.NavItemMinH = 44
Theme.NavItemPadV = 11
Theme.NavItemPadH = 10
Theme.NavItemRadius = 6
Theme.NavItemGap = 9
Theme.NavIdle = rgb(146, 146, 146)
Theme.NavActiveBg = rgb(26, 26, 26)
Theme.NavActiveText = rgb(227, 227, 227)
Theme.NavHoverBg = rgb(22, 22, 22)
Theme.NavHoverText = rgb(221, 221, 221)
Theme.NavGlyphColor = rgb(138, 138, 138)
Theme.NavGlyphWidth = 20
Theme.NavGlyphFont = 17
Theme.NavFont = 12
Theme.NavBg = rgb(9, 9, 9)

Theme.MainBg = rgb(12, 12, 12)
Theme.MainPadTop = 25
Theme.MainPadX = 26
Theme.MainPadBottom = 30
Theme.ScrollBar = rgb(58, 58, 58)

Theme.H1Size = 21
Theme.IntroSize = 11
Theme.IntroColor = rgb(150, 150, 150)
Theme.HeadingGap = 22

Theme.SectionLabel = rgb(153, 153, 153)
Theme.SectionLabelSize = 9
Theme.SectionLabelMarginTop = 25
Theme.SectionLabelMarginBottom = 11

Theme.FieldBg = rgb(17, 17, 17)
Theme.FieldBorder = rgb(51, 51, 51)
Theme.FieldText = rgb(221, 221, 221)
Theme.FieldPlaceholder = rgb(129, 129, 129)
Theme.FieldFocusBg = rgb(22, 22, 22)
Theme.FieldFocusBorder = rgb(119, 119, 119)
Theme.FieldRadius = 6
Theme.FieldPadV = 11
Theme.FieldPadH = 12
Theme.FieldMinH = 42
Theme.FieldFont = 12
Theme.SearchBg = rgb(15, 15, 15)
Theme.SearchBorder = rgb(41, 41, 41)

Theme.RowBg = rgb(17, 17, 17)
Theme.RowHoverBg = rgb(22, 22, 22)
Theme.RowGap = 14
Theme.RowMinH = 61
Theme.RowPad = 14
Theme.RowRadius = 6
Theme.RowMarginBottom = 4
Theme.RowLabel = rgb(206, 206, 206)
Theme.RowLabelFont = 12
Theme.HelpColor = rgb(146, 146, 146)
Theme.HelpFont = 10
Theme.HelpMarginTop = 6

Theme.ToggleW = 34
Theme.ToggleH = 21
Theme.ToggleRadius = 20
Theme.ToggleBg = rgb(48, 48, 48)
Theme.ToggleBorder = rgb(68, 68, 68)
Theme.ToggleKnob = rgb(148, 148, 148)
Theme.ToggleKnobSize = 13
Theme.ToggleKnobInset = 3
Theme.ToggleKnobOn = rgb(34, 34, 34)
Theme.ToggleShift = 13
Theme.CheckboxSize = 17

Theme.RangeBg = rgb(17, 17, 17)
Theme.RangePadTop = 15
Theme.RangePadX = 14
Theme.RangePadBottom = 4
Theme.RangeRadius = 6
Theme.RangeLabel = rgb(204, 204, 204)
Theme.RangeOutput = rgb(170, 170, 170)
Theme.RangeOutputSize = 11
Theme.RangeTrackHeight = 5
Theme.RangeTrackMarginTop = 22
Theme.RangeTrackMarginBottom = 18

Theme.GroupBg = rgb(17, 17, 17)
Theme.GroupPad = 14
Theme.GroupRadius = 6
Theme.GroupLabel = rgb(176, 176, 176)
Theme.GroupLabelSize = 11
Theme.GroupLabelMargin = 9
Theme.GroupFieldBg = rgb(12, 12, 12)

Theme.NoticeBg = rgb(17, 17, 17)
Theme.NoticePad = 14
Theme.NoticeRadius = 6
Theme.NoticeColor = rgb(153, 153, 153)
Theme.NoticeSize = 11
Theme.NoticeStrong = rgb(204, 204, 204)
Theme.NoticeMarginY = 21

Theme.ActionBg = rgb(29, 29, 29)
Theme.ActionText = rgb(204, 204, 204)
Theme.ActionBorder = rgb(58, 58, 58)
Theme.ActionHoverBg = rgb(39, 39, 39)
Theme.ActionHoverBorder = rgb(90, 90, 90)
Theme.ActionRadius = 6
Theme.ActionMinH = 38
Theme.ActionPadV = 9
Theme.ActionPadH = 12
Theme.ActionFont = 11
Theme.PrimaryBg = rgb(204, 204, 204)
Theme.PrimaryText = rgb(22, 22, 22)
Theme.PrimaryHoverBg = rgb(224, 224, 224)
Theme.ButtonGroupGap = 8
Theme.ButtonGroupMarginY = 15
Theme.ButtonGroupMinW = 90

Theme.DetailsBg = rgb(16, 16, 16)
Theme.DetailsBorder = rgb(44, 44, 44)
Theme.DetailsRadius = 6
Theme.DetailsPad = 14
Theme.DetailsMarginTop = 20
Theme.SummaryColor = rgb(184, 184, 184)
Theme.SummaryMinH = 24

Theme.TriggerBg = rgb(27, 27, 27)
Theme.TriggerBorder = rgb(59, 59, 59)
Theme.TriggerText = rgb(197, 197, 197)
Theme.TriggerHoverBg = rgb(36, 36, 36)
Theme.TriggerHoverBorder = rgb(85, 85, 85)
Theme.TriggerMinH = 38
Theme.TriggerRadius = 6
Theme.TriggerFont = 11
Theme.SwatchSize = 16
Theme.SwatchRadius = 4
Theme.ColorCodeFont = 10

Theme.MenuBg = rgb(23, 23, 23)
Theme.MenuBorder = rgb(59, 59, 59)
Theme.MenuRadius = 8
Theme.MenuPad = 5
Theme.MenuMinW = 155
Theme.MenuMaxH = 220
Theme.MenuItemMinH = 37
Theme.MenuItemPadV = 10
Theme.MenuItemPadH = 11
Theme.MenuItemColor = rgb(170, 170, 170)
Theme.MenuItemSelBg = rgb(40, 40, 40)
Theme.MenuItemSelText = rgb(238, 238, 238)
Theme.MenuFont = 11

Theme.FooterBorder = rgb(34, 34, 34)
Theme.FooterBg = rgb(9, 9, 9)
Theme.FooterText = rgb(139, 139, 139)
Theme.FooterFont = 9
Theme.FooterPadV = 11
Theme.FooterPadH = 22
Theme.FooterBrandColor = rgb(153, 153, 153)
Theme.FooterBrandSize = 8
Theme.FooterKeyColor = rgb(170, 170, 170)
Theme.FooterKeyBorder = rgb(51, 51, 51)
Theme.FooterKeyRadius = 3
Theme.FooterKeyPadV = 3
Theme.FooterKeyPadH = 5

Theme.ToastBg = rgb(21, 21, 21)
Theme.ToastBorder = rgb(58, 58, 58)
Theme.ToastErrorBorder = rgb(121, 80, 80)
Theme.ToastRadius = 9
Theme.ToastPad = 16
Theme.ToastWidth = 310
Theme.ToastBottom = 22
Theme.ToastRight = 22
Theme.ToastTitleSize = 12
Theme.ToastBodySize = 11
Theme.ToastBodyColor = rgb(170, 170, 170)

Theme.DialogBg = rgb(18, 18, 18)
Theme.DialogBorder = rgb(66, 66, 66)
Theme.DialogRadius = 12
Theme.DialogPad = 25
Theme.DialogWidth = 390
Theme.DialogH2Size = 18
Theme.DialogBodyColor = rgb(170, 170, 170)
Theme.DialogBodySize = 12

Theme.Duration = {
    Fast = 0.18, Background = 0.20, Knob = 0.25, Toast = 0.30,
    Modal = 0.25, Menu = 0.18, Morph = 1.05,
}

function Theme.Color(token)
    if token == nil then return Color3.fromRGB(255, 255, 255) end
    return Color3.fromRGB(token.r, token.g, token.b)
end
function Theme.px(n) return UDim2.fromOffset(n, n) end
function Theme.off(x, y) return UDim2.fromOffset(x, y) end

-- ---------------------------------------------------------------------------
-- Construction helpers
-- ---------------------------------------------------------------------------
local function new(class, props)
    local instance = Instance.new(class)
    for key, value in pairs(props or {}) do
        if key ~= "Parent" then instance[key] = value end
    end
    if props and props.Parent then instance.Parent = props.Parent end
    return instance
end

local function corner(instance, radius)
    new("UICorner", {CornerRadius = UDim.new(0, radius or 0), Parent = instance})
    return instance
end

local function stroke(instance, colour, thickness, transparency)
    return new("UIStroke", {
        Color = Theme.Color(colour or Theme.Line),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        Parent = instance,
    })
end

local function pad(instance, top, right, bottom, left)
    new("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        PaddingLeft = UDim.new(0, left or right or top or 0),
        Parent = instance,
    })
    return instance
end

-- Apply text properties and return the label so callers can chain.
local function label(instance, value, size, colour, font)
    instance.Text = value or ""
    instance.TextSize = size or 12
    instance.TextColor3 = Theme.Color(colour or Theme.Text)
    instance.Font = font or Enum.Font.Gotham
    instance.TextXAlignment = Enum.TextXAlignment.Left
    instance.BackgroundTransparency = 1
    return instance
end

local function flex(parent, fill, gap, order)
    return new("UIListLayout", {
        FillDirection = fill or Enum.FillDirection.Vertical,
        Padding = UDim.new(0, gap or 0),
        SortOrder = order or Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

-- ---------------------------------------------------------------------------
-- Factory
-- ---------------------------------------------------------------------------
local Panel = {}
Panel.__index = Panel

function Panel.new(config)
    config = config or {}
    local self = setmetatable({}, Panel)

    self.Destroyed = false
    self.Connections = {}
    self.Tabs = {}
    self.TabOrder = {}
    self.Open = config.StartOpen ~= false
    self.Expanded = false
    self.Minimized = false
    self.Hotkey = config.Hotkey or Enum.KeyCode.Insert
    self.Order = 0
    self.Components = {}

    local Players = game:GetService("Players")
    self.LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
    self._connect = function(signal, callback)
        if not signal then return nil end
        local connection = signal:Connect(callback)
        self.Connections[#self.Connections + 1] = connection
        return connection
    end

    self:_buildScreen(config)
    self:_buildWindow(config)
    self:_buildHeader(config)
    self:_buildLayout()
    self:_buildFooter()
    self:_buildToast()
    self:_buildDialog()
    self:_bindHotkey()
    self:_applyLayout()

    return self
end

-- ---------------------------------------------------------------------------
-- Screen + window shell
-- ---------------------------------------------------------------------------
function Panel:_buildScreen(config)
    local localPlayer = self.LocalPlayer
    local parent = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 15)

    local screen = new("ScreenGui", {
        Name = "DepHubPanel",                 -- "dephub" keeps ui-guard on it
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 2147483647,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Enabled = self.Open,
        Parent = parent,
    })
    self.ScreenGui = screen
    self._connect(screen:GetPropertyChangedSignal("Enabled"), function()
        if not self.Destroyed and self.Open and not screen.Enabled then
            screen.Enabled = true
        end
    end)
end

function Panel:_buildWindow(config)
    -- .rectangle: width min(840, 100vw-32), height min(560, 100dvh-100)
    local window = new("Frame", {
        Name = "Window",
        BackgroundColor3 = Theme.Color(Theme.Bg),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Parent = self.ScreenGui,
    })
    corner(window, Theme.WindowRadius)
    stroke(window, Theme.WindowBorder, 1)
    self.Window = window

    -- The body holds layout + footer below the fixed header.
    local body = new("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -Theme.Header),
        Position = UDim2.fromOffset(0, Theme.Header),
        Parent = window,
    })
    self.Body = body
end

-- ---------------------------------------------------------------------------
-- Header
-- ---------------------------------------------------------------------------
function Panel:_buildHeader(config)
    local header = new("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.Header),
        Position = UDim2.fromOffset(0, 0),
        Active = true,
        Parent = self.Window,
    })
    self.Header = header
    -- border-bottom: 1px solid var(--line)
    new("Frame", {
        Name = "BottomBorder",
        BackgroundColor3 = Theme.Color(Theme.HeaderBorder),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        Parent = header,
    })

    -- Brand: header strong is a flex row holding the mark and the morph-name.
    -- In the ready state .morph-name is width:0/max-width:0/opacity:0, so only
    -- the 30x30 mark shows; the name is materialised by the intro.
    local brand = new("Frame", {
        Name = "Brand",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 300, 0, Theme.BrandHeight),
        Position = UDim2.fromOffset(Theme.Left, Theme.BrandTop),
        Parent = header,
    })
    new("UIListLayout", {
        Name = "Flow",
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 0),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = brand,
    })
    local mark = new("Frame", {
        Name = "Mark",
        BackgroundColor3 = Theme.Color(Theme.MarkBg),
        BorderSizePixel = 0,
        Size = Theme.px(Theme.MarkSize),
        LayoutOrder = 1,
        Parent = brand,
    })
    corner(mark, Theme.MarkRadius)
    -- The mark holds the DepHub "D" glyph (the mockup's inline SVG, drawn as text).
    label(new("TextLabel", {
        Name = "Glyph",
        Size = UDim2.fromScale(1, 1),
        TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = mark,
    }), "D", 18, Theme.MarkInk, Enum.Font.GothamBold)

    -- morph-name: collapsed to zero width in the ready state, exactly like the
    -- stylesheet. Kept as an instance so the intro can grow it.
    self.BrandName = label(new("TextLabel", {
        Name = "MorphName",
        Size = UDim2.fromOffset(0, Theme.BrandHeight),
        LayoutOrder = 2,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTransparency = 1,
        Parent = brand,
    }), config.Title or "DepHub", 15, Theme.Text, Enum.Font.GothamBold)
    local morphConstraint = new("UISizeConstraint", {
        Name = "MorphWidth",
        MinSize = Vector2.new(0, 0),
        MaxSize = Vector2.new(0, math.huge),
        Parent = self.BrandName,
    })

    -- Current game: left:24 top:64, flex row gap:7 with a 4x4 dot and a div
    -- holding the (hidden) caption plus the name.
    local gameRow = new("Frame", {
        Name = "CurrentGame",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 260, 0, 16),
        Position = UDim2.fromOffset(Theme.Left, Theme.GameTop),
        Parent = header,
    })
    new("UIListLayout", {
        Name = "Flow",
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, Theme.GameGap),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = gameRow,
    })
    local indicator = new("Frame", {
        Name = "Indicator",
        BackgroundColor3 = Theme.Color(Theme.GameIndicatorColor),
        BorderSizePixel = 0,
        Size = Theme.px(Theme.GameIndicator),
        LayoutOrder = 1,
        Parent = gameRow,
    })
    corner(indicator, 2)
    local gameText = new("Frame", {
        Name = "TextBlock",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -(Theme.GameIndicator + Theme.GameGap), 0, 16),
        LayoutOrder = 2,
        Parent = gameRow,
    })
    -- .game-caption is display:none in the ready state; present for fidelity.
    local caption = label(new("TextLabel", {
        Name = "Caption",
        Size = UDim2.new(1, 0, 0, 10),
        Visible = false,
        Parent = gameText,
    }), "JOGO ATUAL", 9, Theme.GameIndicatorColor)
    self.GameLabel = label(new("TextLabel", {
        Name = "GameName",
        Size = UDim2.fromScale(1, 1),
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = gameText,
    }), config.GameName or "Jogo atual", Theme.GameNameFont, Theme.GameNameColor)
    self.GameCaption = caption

    -- Window buttons: right:16 top:13, each 30x44 with a 13px dot that only
    -- reveals its colour on hover (matching .window-buttons button::before).
    local buttons = new("Frame", {
        Name = "WindowButtons",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(Theme.WindowButtonW * 3, Theme.WindowButtonH),
        Position = UDim2.new(1, -Theme.WindowButtonsRight - Theme.WindowButtonW * 3, 0, Theme.WindowButtonsTop),
        Parent = header,
    })
    local specs = {
        {Name = "Close", Colour = Theme.CloseDot, Glyph = "×", Action = function() self:SetOpen(false) end},
        {Name = "Minimize", Colour = Theme.MinDot, Glyph = "−", Action = function() self:ToggleMinimize() end},
        {Name = "Expand", Colour = Theme.MaxDot, Glyph = "⤢", Action = function() self:ToggleExpand() end},
    }
    self.WindowButtons = {}
    local glyphs = {}
    -- .window-buttons:hover button{color:#000a}: the glyphs appear when the
    -- whole cluster is hovered, not on a single button.
    self._connect(buttons.MouseEnter, function()
        for _, glyph in ipairs(glyphs) do glyph.TextTransparency = 0.33 end
    end)
    self._connect(buttons.MouseLeave, function()
        for _, glyph in ipairs(glyphs) do glyph.TextTransparency = 1 end
    end)

    for index, spec in ipairs(specs) do
        local button = new("TextButton", {
            Name = spec.Name,
            BackgroundTransparency = 1,
            Text = "",
            Size = UDim2.fromOffset(Theme.WindowButtonW, Theme.WindowButtonH),
            Position = UDim2.fromOffset((index - 1) * Theme.WindowButtonW, 0),
            AutoButtonColor = false,
            ClipsDescendants = false,
            Parent = buttons,
        })
        -- The dot is the ::before, drawn behind the glyph (z-index -1). ZIndex
        -- ordering with Sibling behaviour puts the later Glyph on top.
        local dot = new("Frame", {
            Name = "Dot",
            BackgroundColor3 = Theme.Color(spec.Colour),
            BorderSizePixel = 0,
            Size = Theme.px(Theme.WindowDot),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            ZIndex = 1,
            Parent = button,
        })
        corner(dot, Theme.WindowDot / 2)
        local glyph = label(new("TextLabel", {
            Name = "Glyph",
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTransparency = 1,
            ZIndex = 2,
            Parent = button,
        }), spec.Glyph, 14, {r = 0, g = 0, b = 0}, Enum.Font.GothamBold)
        glyphs[#glyphs + 1] = glyph

        -- dot:hover::before{transform:scale(1.17);filter:brightness(1.12)}
        self._connect(button.MouseEnter, function()
            dot.Size = Theme.px(math.floor(Theme.WindowDot * 1.17 + 0.5))
        end)
        self._connect(button.MouseLeave, function()
            dot.Size = Theme.px(Theme.WindowDot)
        end)
        -- button:active::before{transform:scale(.82)}
        self._connect(button.MouseButton1Down, function()
            dot.Size = Theme.px(math.floor(Theme.WindowDot * 0.82 + 0.5))
        end)
        self._connect(button.MouseButton1Up, function()
            dot.Size = Theme.px(Theme.WindowDot)
        end)
        self._connect(button.MouseButton1Click, spec.Action)
        self.WindowButtons[spec.Name] = button
    end
end

-- ---------------------------------------------------------------------------
-- Layout: nav + main
-- ---------------------------------------------------------------------------
function Panel:_buildLayout()
    local layout = new("Frame", {
        Name = "Layout",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -Theme.Footer),
        Parent = self.Body,
    })
    self.Layout = layout

    -- nav: 160px, border-right 1px #1c1c1c, padding 20 10, gap 7
    local nav = new("Frame", {
        Name = "Nav",
        BackgroundColor3 = Theme.Color(Theme.NavBg),
        BorderSizePixel = 0,
        Size = UDim2.new(0, Theme.NavWidth, 1, 0),
        Parent = layout,
    })
    new("Frame", {
        Name = "Divider",
        BackgroundColor3 = Theme.Color(Theme.NavBorder),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        Parent = nav,
    })
    local navList = new("Frame", {
        Name = "List",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = nav,
    })
    pad(nav, Theme.NavPadV, Theme.NavPadH, Theme.NavPadV, Theme.NavPadH)
    flex(navList, Enum.FillDirection.Vertical, Theme.NavGap)
    self.Nav = nav
    self.NavList = navList

    -- main: fluid, bg #0c0c0c, padding 25 26 30, scrollable
    local main = new("ScrollingFrame", {
        Name = "Main",
        BackgroundColor3 = Theme.Color(Theme.MainBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, -Theme.NavWidth, 1, 0),
        Position = UDim2.fromOffset(Theme.NavWidth, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Color(Theme.ScrollBar),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = layout,
    })
    pad(main, Theme.MainPadTop, Theme.MainPadX, Theme.MainPadBottom, Theme.MainPadX)
    local mainList = new("Frame", {
        Name = "Stack",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = main,
    })
    flex(mainList, Enum.FillDirection.Vertical, 0)
    self.Main = main
    self.MainStack = mainList
end

-- ---------------------------------------------------------------------------
-- Footer
-- ---------------------------------------------------------------------------
function Panel:_buildFooter()
    local footer = new("Frame", {
        Name = "Footer",
        BackgroundColor3 = Theme.Color(Theme.FooterBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Theme.Footer),
        Position = UDim2.new(0, 0, 1, -Theme.Footer),
        Parent = self.Body,
    })
    new("Frame", {
        Name = "TopBorder",
        BackgroundColor3 = Theme.Color(Theme.FooterBorder),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Parent = footer,
    })
    pad(footer, Theme.FooterPadV, Theme.FooterPadH, Theme.FooterPadV, Theme.FooterPadH)

    label(new("TextLabel", {
        Name = "Brand",
        Size = UDim2.fromOffset(110, 1),
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = footer,
    }), "D / DEPHUB", Theme.FooterBrandSize, Theme.FooterBrandColor)

    self.StatusLabel = label(new("TextLabel", {
        Name = "Status",
        Size = UDim2.new(1, -220, 1, 0),
        Position = UDim2.fromOffset(110, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = footer,
    }), "Prévia de interface", Theme.FooterFont, Theme.FooterText)

    local key = new("Frame", {
        Name = "Key",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(60, 1),
        Position = UDim2.new(1, -60, 0, 0),
        Parent = footer,
    })
    self.KeyLabel = label(new("TextLabel", {
        Name = "KeyText",
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = key,
    }), "INSERT", 9, Theme.FooterKeyColor, Enum.Font.Code)
    self.Footer = footer
end

-- ---------------------------------------------------------------------------
-- Toast
-- ---------------------------------------------------------------------------
function Panel:_buildToast()
    local toast = new("Frame", {
        Name = "Toast",
        BackgroundColor3 = Theme.Color(Theme.ToastBg),
        BackgroundTransparency = 0.07,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(Theme.ToastWidth, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(1, -Theme.ToastRight, 1, -Theme.ToastBottom + 40),
        AnchorPoint = Vector2.new(1, 1),
        Visible = false,
        ZIndex = 100,
        Parent = self.ScreenGui,
    })
    corner(toast, Theme.ToastRadius)
    local toastStroke = stroke(toast, Theme.ToastBorder, 1)
    pad(toast, Theme.ToastPad, Theme.ToastPad, Theme.ToastPad, Theme.ToastPad)
    flex(toast, Enum.FillDirection.Vertical, 7)

    self.ToastTitle = label(new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 15),
        LayoutOrder = 1,
        Parent = toast,
    }), "", Theme.ToastTitleSize, Theme.Text, Enum.Font.GothamMedium)

    self.ToastMessage = label(new("TextLabel", {
        Name = "Message",
        Size = UDim2.new(1, 0, 0, 14),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        Parent = toast,
    }), "", Theme.ToastBodySize, Theme.ToastBodyColor)

    self.Toast = toast
    self.ToastStroke = toastStroke
    self.ToastToken = 0
end

-- ---------------------------------------------------------------------------
-- Confirmation dialog
-- ---------------------------------------------------------------------------
function Panel:_buildDialog()
    local overlay = new("Frame", {
        Name = "DialogOverlay",
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.31,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 200,
        Parent = self.ScreenGui,
    })
    local dialog = new("Frame", {
        Name = "Dialog",
        BackgroundColor3 = Theme.Color(Theme.DialogBg),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(Theme.DialogWidth, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        ZIndex = 201,
        Parent = overlay,
    })
    corner(dialog, Theme.DialogRadius)
    stroke(dialog, Theme.DialogBorder, 1)
    pad(dialog, Theme.DialogPad, Theme.DialogPad, Theme.DialogPad, Theme.DialogPad)
    -- Block flow, exactly like the dialog's h2/p/div stack: a vertical list with
    -- the h2 margin (14) and the p margin (23) expressed as padding.
    new("UIListLayout", {
        Name = "Stack",
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = dialog,
    })

    self.DialogTitle = label(new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, Theme.DialogH2Size + 6),
        LayoutOrder = 1,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = dialog,
    }), "Confirmar ação?", Theme.DialogH2Size, Theme.Text, Enum.Font.GothamMedium)

    self.DialogMessage = label(new("TextLabel", {
        Name = "Message",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = dialog,
    }), "", Theme.DialogBodySize, Theme.DialogBodyColor)
    -- h2 margin-bottom 14, p margin-bottom 23.
    pad(self.DialogMessage, 14, 0, 23, 0)

    local group = new("Frame", {
        Name = "Buttons",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.ActionMinH),
        LayoutOrder = 3,
        Parent = dialog,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, Theme.ButtonGroupGap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = group,
    })
    self.Dialog = dialog
    self.DialogOverlay = overlay
    self.DialogButtons = group
end

-- ---------------------------------------------------------------------------
-- Hotkey
-- ---------------------------------------------------------------------------
function Panel:_bindHotkey()
    local UserInputService = game:GetService("UserInputService")
    self._connect(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == self.Hotkey then
            self:SetOpen(not self.Open)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Layout / window state
-- ---------------------------------------------------------------------------
function Panel:_applyLayout()
    local window = self.Window
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    if self.Minimized then
        window.Size = UDim2.fromOffset(Theme.MinWidth, Theme.Header + 1)
        window.Position = UDim2.fromScale(0.5, 0.5)
    elseif self.Expanded then
        window.Size = UDim2.new(1, -32, 1, -92)
        window.AnchorPoint = Vector2.new(0, 0)
        window.Position = UDim2.fromOffset(16, 76)
    else
        window.Size = UDim2.fromOffset(Theme.MinWidth, Theme.MinHeight)
        window.Position = UDim2.fromScale(0.5, 0.5)
    end
    local show = not self.Minimized
    self.Layout.Visible = show
    self.Footer.Visible = show
end

function Panel:SetOpen(open)
    if self.Destroyed then return end
    self.Open = open and true or false
    self.ScreenGui.Enabled = self.Open
    return self.Open
end

function Panel:ToggleMinimize()
    self.Minimized = not self.Minimized
    if self.Minimized then self.Expanded = false end
    self:_applyLayout()
end

function Panel:ToggleExpand()
    self.Expanded = not self.Expanded
    if self.Expanded then self.Minimized = false end
    self:_applyLayout()
end

function Panel:SetGame(name)
    if self.GameLabel and type(name) == "string" then self.GameLabel.Text = name end
end

function Panel:SetStatus(text)
    if self.StatusLabel and type(text) == "string" then self.StatusLabel.Text = text end
end

-- ---------------------------------------------------------------------------
-- Page scaffolding
-- ---------------------------------------------------------------------------

function Panel:_next()
    self.Order = (self.Order or 0) + 1
    return self.Order
end

-- CreateTab(spec) -> {Name, Page, Button, Label}
-- spec = {Name, Glyph, Intro, Search} (Search renders the filter field the
-- mockup shows at the top of the Jogador page).
function Panel:CreateTab(spec)
    if type(spec) == "string" then spec = {Name = spec} end
    assert(type(spec.Name) == "string" and #spec.Name > 0, "CreateTab needs a Name")

    local index = #self.TabOrder + 1
    local first = index == 1

    -- nav button: flex row, gap 9, min-height 44, padding 11 10, radius 6
    local button = new("TextButton", {
        Name = spec.Name,
        BackgroundColor3 = Theme.Color(first and Theme.NavActiveBg or Theme.NavBg),
        BackgroundTransparency = first and 0 or 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, Theme.NavItemMinH),
        LayoutOrder = index,
        Text = "",
        Parent = self.NavList,
    })
    corner(button, Theme.NavItemRadius)
    pad(button, Theme.NavItemPadV, Theme.NavItemPadH, Theme.NavItemPadV, Theme.NavItemPadH)
    new("UIListLayout", {
        Name = "Flow",
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, Theme.NavItemGap),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = button,
    })

    local glyph = label(new("TextLabel", {
        Name = "Glyph",
        Size = UDim2.new(0, Theme.NavGlyphWidth, 1, 0),
        LayoutOrder = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = button,
    }), spec.Glyph or "•", Theme.NavGlyphFont, first and Theme.NavActiveText or Theme.NavGlyphColor)

    local text = label(new("TextLabel", {
        Name = "Text",
        Size = UDim2.new(1, -(Theme.NavGlyphWidth + Theme.NavItemGap), 1, 0),
        LayoutOrder = 2,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = button,
    }), spec.Name, Theme.NavFont, first and Theme.NavActiveText or Theme.NavIdle)

    -- .nav-index{display:none} on desktop; present for structural fidelity.
    local navIndex = label(new("TextLabel", {
        Name = "Index",
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 3,
        Visible = false,
        Parent = button,
    }), string.format("%02d", index), Theme.NavFont, Theme.NavIdle)

    -- page: a heading (h1 + intro), optional search, then the stack
    local page = new("Frame", {
        Name = spec.Name,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = first,
        Parent = self.MainStack,
    })
    flex(page, Enum.FillDirection.Vertical, 0)

    local heading = new("Frame", {
        Name = "Heading",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40),
        LayoutOrder = self:_next(),
        Parent = page,
    })
    label(new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 25),
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = heading,
    }), spec.Name, Theme.H1Size, Theme.Text, Enum.Font.GothamMedium)
    if spec.Intro then
        label(new("TextLabel", {
            Name = "Intro",
            Size = UDim2.new(1, 0, 0, 15),
            Position = UDim2.fromOffset(0, 28),
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = heading,
        }), spec.Intro, Theme.IntroSize, Theme.IntroColor)
    end

    local stack = new("Frame", {
        Name = "Stack",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_next(),
        Parent = page,
    })
    flex(stack, Enum.FillDirection.Vertical, 0)

    local tab = {Name = spec.Name, Page = page, Button = button, Stack = stack, Label = text, Glyph = glyph, Index = navIndex, Active = first}

    if spec.Search then
        tab.Search = self:AddSearch(tab, spec.Search)
    end

    self._connect(button.MouseEnter, function()
        if not tab.Active then
            button.BackgroundTransparency = 0
            button.BackgroundColor3 = Theme.Color(Theme.NavHoverBg)
            text.TextColor3 = Theme.Color(Theme.NavHoverText)
        end
    end)
    self._connect(button.MouseLeave, function()
        if not tab.Active then
            button.BackgroundTransparency = 1
            text.TextColor3 = Theme.Color(Theme.NavIdle)
            glyph.TextColor3 = Theme.Color(Theme.NavGlyphColor)
        end
    end)
    self._connect(button.MouseButton1Click, function() self:SelectTab(spec.Name) end)

    self.Tabs[spec.Name] = tab
    self.TabOrder[#self.TabOrder + 1] = tab
    return tab
end

function Panel:SelectTab(name)
    local target = self.Tabs[name]
    if not target or self.Destroyed then return end
    for _, tab in ipairs(self.TabOrder) do
        local active = tab == target
        tab.Active = active
        tab.Page.Visible = active
        tab.Button.BackgroundTransparency = active and 0 or 1
        tab.Button.BackgroundColor3 = Theme.Color(active and Theme.NavActiveBg or Theme.NavBg)
        tab.Label.TextColor3 = Theme.Color(active and Theme.NavActiveText or Theme.NavIdle)
        tab.Glyph.TextColor3 = Theme.Color(active and Theme.NavActiveText or Theme.NavGlyphColor)
    end
    return target
end

-- A search field at the top of a page, matching .field.search.
function Panel:AddSearch(tab, placeholder)
    local page = tab.Stack or tab.Page
    local field = new("TextBox", {
        Name = "Search",
        BackgroundColor3 = Theme.Color(Theme.SearchBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Theme.FieldMinH),
        LayoutOrder = self:_next(),
        Text = "",
        PlaceholderText = placeholder or "Encontrar uma opção...",
        PlaceholderColor3 = Theme.Color(Theme.FieldPlaceholder),
        Font = Enum.Font.Gotham,
        TextSize = Theme.FieldFont,
        TextColor3 = Theme.Color(Theme.FieldText),
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = page,
    })
    corner(field, Theme.FieldRadius)
    stroke(field, Theme.SearchBorder, 1)
    pad(field, 0, Theme.FieldPadH, 0, Theme.FieldPadH)

    local wrapper = {Instance = field, Rows = {}}
    function wrapper:Get() return field.Text end
    function wrapper:Set(value) field.Text = tostring(value or "") end
    function wrapper:Register(row, searchText)
        self.Rows[#self.Rows + 1] = {Row = row, Text = string.lower(searchText or "")}
    end
    self._connect(field:GetPropertyChangedSignal("Text"), function()
        local query = string.lower(field.Text)
        for _, entry in ipairs(wrapper.Rows) do
            local visible = query == "" or string.find(entry.Text, query, 1, true) ~= nil
            entry.Row.Visible = visible
        end
    end)
    self.Components[#self.Components + 1] = wrapper
    return wrapper
end

-- AddSection(tab, text): the uppercase .section-label.
function Panel:AddSection(tab, text)
    local stack = tab.Stack or tab.Page
    local result = label(new("TextLabel", {
        Name = "SectionLabel",
        Size = UDim2.new(1, 0, 0, 12),
        LayoutOrder = self:_next(),
        Parent = stack,
    }), string.upper(text or ""), Theme.SectionLabelSize, Theme.SectionLabel)
    result.TextXAlignment = Enum.TextXAlignment.Left
    return result
end

-- Internal: a .row with a left label block and a right control slot.
-- Mirrors .row{display:flex;justify-content:space-between;align-items:center;
-- gap:14px;min-height:61px;padding:14px}: a horizontal list layout holds the
-- flexible label block and the fixed control column.
function Panel:_row(tab, title, help, order, opts)
    opts = opts or {}
    local stack = tab.Stack or tab.Page
    local row = new("Frame", {
        Name = title or "Row",
        BackgroundColor3 = Theme.Color(Theme.RowBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Theme.RowMinH),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order or self:_next(),
        Parent = stack,
    })
    corner(row, Theme.RowRadius)
    pad(row, Theme.RowPad, Theme.RowPad, Theme.RowPad, Theme.RowPad)
    new("UISizeConstraint", {
        Name = "MinHeight",
        MinSize = Vector2.new(0, Theme.RowMinH),
        MaxSize = Vector2.new(math.huge, math.huge),
        Parent = row,
    })
    new("UIListLayout", {
        Name = "Row",
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, Theme.RowGap),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = row,
    })

    -- left block: label + optional help, takes the remaining width
    local block = new("Frame", {
        Name = "Labels",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -(opts.ControlWidth or 150) - Theme.RowGap, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
        Parent = row,
    })
    flex(block, Enum.FillDirection.Vertical, Theme.HelpMarginTop)
    label(new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 14),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 1,
        Parent = block,
    }), title or "", Theme.RowLabelFont, Theme.RowLabel)
    if help and #help > 0 then
        label(new("TextLabel", {
            Name = "Help",
            Size = UDim2.new(1, 0, 0, 12),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 2,
            Parent = block,
        }), help, Theme.HelpFont, Theme.HelpColor)
    end

    -- right column: a fixed-width slot whose single control is centred, exactly
    -- like the flex row's align-items:center putting the control on the right.
    local slot = new("Frame", {
        Name = "Control",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, opts.ControlWidth or 150, 1, 0),
        LayoutOrder = 2,
        Parent = row,
    })
    new("UIListLayout", {
        Name = "Column",
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = slot,
    })
    return row, block, slot
end

-- ---------------------------------------------------------------------------
-- Controls
-- ---------------------------------------------------------------------------

-- AddToggle(tab, title, help, value, callback)
function Panel:AddToggle(tab, title, help, value, callback)
    local order = self:_next()
    local row, _, slot = self:_row(tab, title, help, order)
    local on = value == true

    -- .toggle: 34x21 radius 20, knob 13 at 3,3 that shifts 13px
    local toggle = new("TextButton", {
        Name = "Toggle",
        BackgroundColor3 = Theme.Color(on and Theme.Accent or Theme.ToggleBg),
        BorderSizePixel = 0,
        Size = Theme.px(Theme.ToggleW, Theme.ToggleH),
        LayoutOrder = 1,
        AutoButtonColor = false,
        Text = "",
        Parent = slot,
    })
    corner(toggle, Theme.ToggleRadius)
    local toggleStroke = stroke(toggle, on and Theme.Accent or Theme.ToggleBorder, 1)
    local knob = new("Frame", {
        Name = "Knob",
        BackgroundColor3 = Theme.Color(on and Theme.ToggleKnobOn or Theme.ToggleKnob),
        BorderSizePixel = 0,
        Size = Theme.px(Theme.ToggleKnobSize),
        Position = UDim2.fromOffset(on and (Theme.ToggleKnobInset + Theme.ToggleShift) or Theme.ToggleKnobInset, Theme.ToggleKnobInset),
        Parent = toggle,
    })
    corner(knob, Theme.ToggleKnobSize / 2)

    local control = {}
    local function render()
        toggle.BackgroundColor3 = Theme.Color(on and Theme.Accent or Theme.ToggleBg)
        toggleStroke.Color = Theme.Color(on and Theme.Accent or Theme.ToggleBorder)
        knob.BackgroundColor3 = Theme.Color(on and Theme.ToggleKnobOn or Theme.ToggleKnob)
        knob.Position = UDim2.fromOffset(on and (Theme.ToggleKnobInset + Theme.ToggleShift) or Theme.ToggleKnobInset, Theme.ToggleKnobInset)
    end
    function control:Get() return on end
    function control:Set(next, silent)
        next = next == true
        if next == on then return on end
        on = next
        render()
        if not silent and callback then pcall(callback, on) end
        return on
    end
    self._connect(toggle.MouseButton1Click, function() control:Set(not on) end)
    control.Instance = toggle
    control.Row = row
    self.Components[#self.Components + 1] = control
    if tab.Search then tab.Search:Register(row, title) end
    return control
end

-- AddCheckbox(tab, title, help, value, callback): the 17px .checkbox
function Panel:AddCheckbox(tab, title, help, value, callback)
    local order = self:_next()
    local row, _, slot = self:_row(tab, title, help, order)
    local on = value == true

    local box = new("TextButton", {
        Name = "Checkbox",
        BackgroundColor3 = Theme.Color(on and Theme.Accent or Theme.FieldBg),
        BorderSizePixel = 0,
        Size = Theme.px(Theme.CheckboxSize),
        LayoutOrder = 1,
        AutoButtonColor = false,
        Text = "",
        Parent = slot,
    })
    corner(box, 3)
    local boxStroke = stroke(box, on and Theme.Accent or Theme.FieldBorder, 1)
    local tick = label(new("TextLabel", {
        Name = "Tick",
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = box,
    }), "✓", 12, Theme.MarkInk, Enum.Font.GothamBold)
    tick.Visible = on

    local control = {}
    local function render()
        box.BackgroundColor3 = Theme.Color(on and Theme.Accent or Theme.FieldBg)
        boxStroke.Color = Theme.Color(on and Theme.Accent or Theme.FieldBorder)
        tick.Visible = on
    end
    function control:Get() return on end
    function control:Set(next, silent)
        next = next == true
        if next == on then return on end
        on = next
        render()
        if not silent and callback then pcall(callback, on) end
        return on
    end
    self._connect(box.MouseButton1Click, function() control:Set(not on) end)
    control.Instance = box
    control.Row = row
    self.Components[#self.Components + 1] = control
    if tab.Search then tab.Search:Register(row, title) end
    return control
end

-- AddSlider(tab, title, min, max, step, value, callback, format)
-- Builds the .range block: label + output row on top, a 5px track below.
function Panel:AddSlider(tab, title, min, max, step, value, callback, format)
    local stack = tab.Stack or tab.Page
    local minV = tonumber(min) or 0
    local maxV = tonumber(max) or 100
    local stepV = tonumber(step) or 1
    local current = math.clamp(tonumber(value) or minV, minV, maxV)
    format = format or function(v) return tostring(v) end

    local block = new("Frame", {
        Name = title or "Range",
        BackgroundColor3 = Theme.Color(Theme.RangeBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 66),
        LayoutOrder = self:_next(),
        Parent = stack,
    })
    corner(block, Theme.RangeRadius)
    pad(block, Theme.RangePadTop, Theme.RangePadX, Theme.RangePadBottom, Theme.RangePadX)

    local head = new("Frame", {
        Name = "Head",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Parent = block,
    })
    label(new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -70, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = head,
    }), title or "", 12, Theme.RangeLabel)
    local readout = label(new("TextLabel", {
        Name = "Output",
        Size = UDim2.fromOffset(70, 1),
        Position = UDim2.new(1, -70, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = head,
    }), format(current), Theme.RangeOutputSize, Theme.RangeOutput)
    readout.Size = UDim2.new(0, 70, 1, 0)

    local track = new("Frame", {
        Name = "Track",
        BackgroundColor3 = Theme.Color(Theme.ToggleBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Theme.RangeTrackHeight),
        Position = UDim2.fromOffset(0, Theme.RangeTrackMarginTop),
        Parent = block,
    })
    corner(track, Theme.RangeTrackHeight / 2)
    local fill = new("Frame", {
        Name = "Fill",
        BackgroundColor3 = Theme.Color(Theme.Accent),
        BorderSizePixel = 0,
        Size = UDim2.fromScale((current - minV) / math.max(maxV - minV, 1e-6), 1),
        Parent = track,
    })
    corner(fill, Theme.RangeTrackHeight / 2)
    local knob = new("Frame", {
        Name = "Knob",
        BackgroundColor3 = Theme.Color(Theme.Accent),
        BorderSizePixel = 0,
        Size = Theme.px(14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((current - minV) / math.max(maxV - minV, 1e-6), 0, 0.5, 0),
        Parent = track,
    })
    corner(knob, 7)
    local hitbox = new("TextButton", {
        Name = "Hitbox",
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.new(1, 0, 1, 24),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        AutoButtonColor = false,
        Parent = track,
    })

    local control = {}
    local function quantize(v)
        local steps = math.floor((v - minV) / stepV + 0.5)
        return math.clamp(minV + steps * stepV, minV, maxV)
    end
    local function render(v)
        local alpha = (v - minV) / math.max(maxV - minV, 1e-6)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        readout.Text = format(v)
    end
    function control:Get() return current end
    function control:Set(v, silent)
        local next = quantize(tonumber(v) or current)
        if next == current then return current end
        current = next
        render(current)
        if not silent and callback then pcall(callback, current) end
        return current
    end

    local dragging = false
    local function fromX(px)
        local absX = track.AbsolutePosition.X
        local width = math.max(track.AbsoluteSize.X, 1)
        local alpha = math.clamp((px - absX) / width, 0, 1)
        control:Set(minV + alpha * (maxV - minV))
    end
    self._connect(hitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end)
    self._connect(hitbox.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    self._connect(game:GetService("UserInputService").InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)

    control.Instance = track
    control.Block = block
    render(current)
    self.Components[#self.Components + 1] = control
    if tab.Search then tab.Search:Register(block, title) end
    return control
end

-- AddInlineSlider(tab, title, min, max, step, value, callback, format)
-- The .inline control: a range and its output side by side inside a .row,
-- used by the mockup's "Opacidade" row. Shares the slider semantics.
function Panel:AddInlineSlider(tab, title, min, max, step, value, callback, format)
    local order = self:_next()
    local row, _, slot = self:_row(tab, title, nil, order)
    local minV = tonumber(min) or 0
    local maxV = tonumber(max) or 100
    local stepV = tonumber(step) or 1
    local current = math.clamp(tonumber(value) or minV, minV, maxV)
    format = format or function(v) return tostring(v) end

    -- .inline{width:46%;display:flex;align-items:center;gap:10px}; inside the
    -- right-aligned control column it fills the slot rather than the row.
    local inline = new("Frame", {
        Name = "Inline",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        LayoutOrder = 1,
        Parent = slot,
    })
    new("UIListLayout", {
        Name = "Flow",
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 10),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = inline,
    })

    local track = new("Frame", {
        Name = "Track",
        BackgroundColor3 = Theme.Color(Theme.ToggleBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, -46, 0, Theme.RangeTrackHeight),
        LayoutOrder = 1,
        Parent = inline,
    })
    corner(track, Theme.RangeTrackHeight / 2)
    local fill = new("Frame", {
        Name = "Fill",
        BackgroundColor3 = Theme.Color(Theme.Accent),
        BorderSizePixel = 0,
        Size = UDim2.fromScale((current - minV) / math.max(maxV - minV, 1e-6), 1),
        Parent = track,
    })
    corner(fill, Theme.RangeTrackHeight / 2)
    local knob = new("Frame", {
        Name = "Knob",
        BackgroundColor3 = Theme.Color(Theme.Accent),
        BorderSizePixel = 0,
        Size = Theme.px(14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((current - minV) / math.max(maxV - minV, 1e-6), 0, 0.5, 0),
        Parent = track,
    })
    corner(knob, 7)
    local hitbox = new("TextButton", {
        Name = "Hitbox",
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.new(1, 0, 1, 20),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        AutoButtonColor = false,
        Parent = track,
    })
    local readout = label(new("TextLabel", {
        Name = "Output",
        Size = UDim2.new(0, 40, 1, 0),
        LayoutOrder = 2,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = inline,
    }), format(current), 10, {r = 170, g = 170, b = 170})

    local control = {}
    local function quantize(v)
        local steps = math.floor((v - minV) / stepV + 0.5)
        return math.clamp(minV + steps * stepV, minV, maxV)
    end
    local function render(v)
        local alpha = (v - minV) / math.max(maxV - minV, 1e-6)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        readout.Text = format(v)
    end
    function control:Get() return current end
    function control:Set(v, silent)
        local next = quantize(tonumber(v) or current)
        if next == current then return current end
        current = next
        render(current)
        if not silent and callback then pcall(callback, current) end
        return current
    end
    local dragging = false
    local function fromX(px)
        local absX = track.AbsolutePosition.X
        local width = math.max(track.AbsoluteSize.X, 1)
        local alpha = math.clamp((px - absX) / width, 0, 1)
        control:Set(minV + alpha * (maxV - minV))
    end
    self._connect(hitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end)
    self._connect(hitbox.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    self._connect(game:GetService("UserInputService").InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)
    control.Instance = track
    control.Block = inline
    control.Row = row
    self.Components[#self.Components + 1] = control
    if tab.Search then tab.Search:Register(row, title) end
    return control
end

-- AddDisabledToggle(tab, title, help, value): the .row.disabled state (opacity
-- .55, control not interactive). Used for the mockup's "indisponível" row.
function Panel:AddDisabledToggle(tab, title, help, value)
    local order = self:_next()
    local row = self:_row(tab, title, help, order)
    row.BackgroundTransparency = 0.45

    local toggle = new("Frame", {
        Name = "Toggle",
        BackgroundColor3 = Theme.Color(value and Theme.Accent or Theme.ToggleBg),
        BorderSizePixel = 0,
        Size = Theme.px(Theme.ToggleW, Theme.ToggleH),
        LayoutOrder = 1,
        Parent = row:FindFirstChild("Control"),
    })
    corner(toggle, Theme.ToggleRadius)
    toggle.BackgroundTransparency = 0.45
    stroke(toggle, value and Theme.Accent or Theme.ToggleBorder, 1)
    local knob = new("Frame", {
        Name = "Knob",
        BackgroundColor3 = Theme.Color(value and Theme.ToggleKnobOn or Theme.ToggleKnob),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Size = Theme.px(Theme.ToggleKnobSize),
        Position = UDim2.fromOffset(value and (Theme.ToggleKnobInset + Theme.ToggleShift) or Theme.ToggleKnobInset, Theme.ToggleKnobInset),
        Parent = toggle,
    })
    corner(knob, Theme.ToggleKnobSize / 2)
    local control = {Instance = toggle, Row = row, Disabled = true}
    function control:Get() return value == true end
    self.Components[#self.Components + 1] = control
    if tab.Search then tab.Search:Register(row, title) end
    return control
end

-- AddDropdown(tab, title, help, options, value, callback)
-- Uses the .choice-trigger button + floating .choice-menu from the mockup.
function Panel:AddDropdown(tab, title, help, options, value, callback)
    local order = self:_next()
    local row, _, slot = self:_row(tab, title, help, order)
    options = options or {}
    local current = value
    if current == nil and #options > 0 then current = options[1] end

    local trigger = new("TextButton", {
        Name = "ChoiceTrigger",
        BackgroundColor3 = Theme.Color(Theme.TriggerBg),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, Theme.TriggerMinH),
        LayoutOrder = 1,
        Text = "",
        Parent = slot,
    })
    corner(trigger, Theme.TriggerRadius)
    stroke(trigger, Theme.TriggerBorder, 1)
    pad(trigger, 0, 11, 0, 11)
    local shown = label(new("TextLabel", {
        Name = "Value",
        Size = UDim2.new(1, -22, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = trigger,
    }), tostring(current or "Escolher"), Theme.TriggerFont, Theme.TriggerText)
    label(new("TextLabel", {
        Name = "Caret",
        Size = UDim2.fromOffset(14, 1),
        Position = UDim2.new(1, -14, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = trigger,
    }), "⌄", 12, Theme.TriggerText).Size = UDim2.new(0, 14, 1, 0)

    local control = {Options = options}
    local function render() shown.Text = tostring(current or "Escolher") end
    function control:Get() return current end
    function control:Set(next, silent)
        local found = false
        for _, option in ipairs(options) do
            if option == next then found = true break end
        end
        if not found or next == current then return current end
        current = next
        render()
        if not silent and callback then pcall(callback, current) end
        return current
    end
    self._connect(trigger.MouseButton1Click, function()
        self:_openMenu(trigger, options, current, function(chosen) control:Set(chosen) end)
    end)
    control.Instance = trigger
    control.Row = row
    render()
    self.Components[#self.Components + 1] = control
    if tab.Search then tab.Search:Register(row, title) end
    return control
end

-- Internal: the floating .choice-menu, one at a time.
function Panel:_openMenu(trigger, options, current, onChoose)
    if self.Menu then
        self.Menu:Destroy()
        self.Menu = nil
    end
    local menu = new("Frame", {
        Name = "ChoiceMenu",
        BackgroundColor3 = Theme.Color(Theme.MenuBg),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(math.max(Theme.MenuMinW, trigger.AbsoluteSize.X), 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(trigger.AbsolutePosition.X, trigger.AbsolutePosition.Y + trigger.AbsoluteSize.Y + 6),
        ZIndex = 150,
        Parent = self.ScreenGui,
    })
    corner(menu, Theme.MenuRadius)
    stroke(menu, Theme.MenuBorder, 1)
    pad(menu, Theme.MenuPad, Theme.MenuPad, Theme.MenuPad, Theme.MenuPad)
    flex(menu, Enum.FillDirection.Vertical, 0)

    for index, option in ipairs(options) do
        local selected = option == current
        local item = new("TextButton", {
            Name = option,
            BackgroundColor3 = Theme.Color(selected and Theme.MenuItemSelBg or Theme.MenuBg),
            BackgroundTransparency = selected and 0 or 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, Theme.MenuItemMinH),
            LayoutOrder = index,
            Text = selected and (option .. "  ✓") or option,
            Font = Enum.Font.Gotham,
            TextSize = Theme.MenuFont,
            TextColor3 = Theme.Color(selected and Theme.MenuItemSelText or Theme.MenuItemColor),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = menu,
        })
        corner(item, 5)
        pad(item, 0, Theme.MenuItemPadH, 0, Theme.MenuItemPadH)
        self._connect(item.MouseEnter, function()
            item.BackgroundTransparency = 0
            item.BackgroundColor3 = Theme.Color(Theme.MenuItemSelBg)
            item.TextColor3 = Theme.Color(Theme.MenuItemSelText)
        end)
        self._connect(item.MouseLeave, function()
            if not selected then
                item.BackgroundTransparency = 1
                item.TextColor3 = Theme.Color(Theme.MenuItemColor)
            end
        end)
        self._connect(item.MouseButton1Click, function()
            menu:Destroy()
            if self.Menu == menu then self.Menu = nil end
            if onChoose then onChoose(option) end
        end)
    end
    self.Menu = menu
    return menu
end

-- AddTextField(tab, title, placeholder, value, callback, help)
-- The .input-group block: label above a field with the darker background.
function Panel:AddTextField(tab, title, placeholder, value, callback, help)
    local stack = tab.Stack or tab.Page
    local group = new("Frame", {
        Name = title or "InputGroup",
        BackgroundColor3 = Theme.Color(Theme.GroupBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 76),
        LayoutOrder = self:_next(),
        Parent = stack,
    })
    corner(group, Theme.GroupRadius)
    pad(group, Theme.GroupPad, Theme.GroupPad, Theme.GroupPad, Theme.GroupPad)
    label(new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 13),
        Parent = group,
    }), title or "", Theme.GroupLabelSize, Theme.GroupLabel)

    local box = new("TextBox", {
        Name = "Input",
        BackgroundColor3 = Theme.Color(Theme.GroupFieldBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Theme.FieldMinH),
        Position = UDim2.fromOffset(0, Theme.GroupLabelSize + Theme.GroupLabelMargin),
        Text = tostring(value or ""),
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = Theme.Color(Theme.FieldPlaceholder),
        Font = Enum.Font.Gotham,
        TextSize = Theme.FieldFont,
        TextColor3 = Theme.Color(Theme.FieldText),
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = group,
    })
    corner(box, Theme.FieldRadius)
    local boxStroke = stroke(box, Theme.FieldBorder, 1)
    pad(box, 0, Theme.FieldPadH, 0, Theme.FieldPadH)

    if help then
        label(new("TextLabel", {
            Name = "Help",
            Size = UDim2.new(1, 0, 0, 12),
            Position = UDim2.fromOffset(0, Theme.GroupLabelSize + Theme.GroupLabelMargin + Theme.FieldMinH + 4),
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = group,
        }), help, Theme.HelpFont, Theme.HelpColor)
        group.Size = UDim2.new(1, 0, 0, 96)
    end

    local control = {}
    function control:Get() return box.Text end
    function control:Set(next, silent)
        box.Text = tostring(next or "")
        if not silent and callback then pcall(callback, box.Text) end
        return box.Text
    end
    self._connect(box.Focused, function()
        box.BackgroundColor3 = Theme.Color(Theme.FieldFocusBg)
        boxStroke.Color = Theme.Color(Theme.FieldFocusBorder)
    end)
    self._connect(box.FocusLost, function(enterPressed)
        box.BackgroundColor3 = Theme.Color(Theme.GroupFieldBg)
        boxStroke.Color = Theme.Color(Theme.FieldBorder)
        if enterPressed and callback then pcall(callback, box.Text) end
    end)
    control.Instance = box
    control.Row = group
    self.Components[#self.Components + 1] = control
    if tab.Search then tab.Search:Register(group, title) end
    return control
end

-- AddAction(tab, title, help, buttonLabel, callback, primary)
function Panel:AddAction(tab, title, help, buttonLabel, callback, primary)
    local order = self:_next()
    local _, _, slot = self:_row(tab, title, help, order)
    local button = new("TextButton", {
        Name = "Action",
        BackgroundColor3 = Theme.Color(primary and Theme.PrimaryBg or Theme.ActionBg),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, Theme.ActionMinH),
        LayoutOrder = 1,
        Text = buttonLabel or "Executar",
        Font = Enum.Font.Gotham,
        TextSize = Theme.ActionFont,
        TextColor3 = Theme.Color(primary and Theme.PrimaryText or Theme.ActionText),
        Parent = slot,
    })
    corner(button, Theme.ActionRadius)
    stroke(button, primary and Theme.PrimaryBg or Theme.ActionBorder, 1)
    local base = button.BackgroundColor3
    self._connect(button.MouseEnter, function()
        button.BackgroundColor3 = Theme.Color(primary and Theme.PrimaryHoverBg or Theme.ActionHoverBg)
    end)
    self._connect(button.MouseLeave, function() button.BackgroundColor3 = base end)
    self._connect(button.MouseButton1Click, function() if callback then pcall(callback) end end)

    local control = {Instance = button}
    function control:SetLabel(text) button.Text = tostring(text or "") end
    self.Components[#self.Components + 1] = control
    return control
end

-- AddKeybind(tab, title, help, keyLabel, callback): the .keybind button.
function Panel:AddKeybind(tab, title, help, keyLabel, callback)
    local order = self:_next()
    local _, _, slot = self:_row(tab, title, help, order)
    local button = new("TextButton", {
        Name = "Keybind",
        BackgroundColor3 = Theme.Color(Theme.ActionBg),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, Theme.ActionMinH),
        LayoutOrder = 1,
        Text = keyLabel or "Insert",
        Font = Enum.Font.Gotham,
        TextSize = Theme.ActionFont,
        TextColor3 = Theme.Color(Theme.ActionText),
        Parent = slot,
    })
    corner(button, Theme.ActionRadius)
    stroke(button, Theme.ActionBorder, 1)
    self._connect(button.MouseButton1Click, function()
        if callback then pcall(callback) end
    end)
    local control = {Instance = button}
    function control:Set(text) button.Text = tostring(text or "") end
    self.Components[#self.Components + 1] = control
    return control
end

-- AddNotice(tab, text, strongTitle): the .notice block.
function Panel:AddNotice(tab, text, strongTitle)
    local stack = tab.Stack or tab.Page
    local notice = new("Frame", {
        Name = "Notice",
        BackgroundColor3 = Theme.Color(Theme.NoticeBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_next(),
        Parent = stack,
    })
    corner(notice, Theme.NoticeRadius)
    pad(notice, Theme.NoticePad, Theme.NoticePad, Theme.NoticePad, Theme.NoticePad)
    local body = label(new("TextLabel", {
        Name = "Body",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        RichText = true,
        Parent = notice,
    }), (strongTitle and ("<b>" .. strongTitle .. "</b><br>") or "") .. (text or ""), Theme.NoticeSize, Theme.NoticeColor)
    body.TextYAlignment = Enum.TextYAlignment.Top
    return notice
end

-- AddCollapsible(tab, summary, open) -> {Body, Toggle}: the details/summary block.
function Panel:AddCollapsible(tab, summary, open)
    local stack = tab.Stack or tab.Page
    local container = new("Frame", {
        Name = "Details",
        BackgroundColor3 = Theme.Color(Theme.DetailsBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 46),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self:_next(),
        Parent = stack,
    })
    corner(container, Theme.DetailsRadius)
    stroke(container, Theme.DetailsBorder, 1)
    pad(container, Theme.DetailsPad, Theme.DetailsPad, Theme.DetailsPad, Theme.DetailsPad)
    -- details is block flow: summary, then the body. A vertical list mirrors it
    -- without depending on absolute offsets inside an AutomaticSize parent.
    new("UIListLayout", {
        Name = "Stack",
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = container,
    })

    local head = new("TextButton", {
        Name = "Summary",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, Theme.SummaryMinH),
        LayoutOrder = 1,
        Text = "",
        Parent = container,
    })
    local headLabel = label(new("TextLabel", {
        Name = "SummaryText",
        Size = UDim2.fromScale(1, 1),
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = head,
    }), "", 12, Theme.SummaryColor)

    local body = new("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        Visible = open == true,
        Parent = container,
    })
    flex(body, Enum.FillDirection.Vertical, 4)

    local state = open == true
    local function render()
        -- summary is a <summary> marker; the mockup shows the disclosure arrow.
        headLabel.Text = (state and "▾  " or "▸  ") .. (summary or "Seção")
        container.AutomaticSize = Enum.AutomaticSize.Y
    end
    self._connect(head.MouseButton1Click, function()
        state = not state
        body.Visible = state
        render()
    end)
    render()
    return {Body = body, Toggle = head, Container = container}
end

-- AddButtonGroup(tab, buttons): the .button-group row.
-- buttons = { {Label=..., Callback=..., Primary=bool}, ... }
function Panel:AddButtonGroup(tab, buttons)
    local stack = tab.Stack or tab.Page
    local group = new("Frame", {
        Name = "ButtonGroup",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.ActionMinH),
        LayoutOrder = self:_next(),
        Parent = stack,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, Theme.ButtonGroupGap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = group,
    })
    local controls = {}
    local count = #(buttons or {})
    for index, spec in ipairs(buttons or {}) do
        -- .button-group .action{flex:1}: share the row equally.
        local share = (count > 0) and (1 / count) or 1
        local button = new("TextButton", {
            Name = spec.Label or "Action",
            BackgroundColor3 = Theme.Color(spec.Primary and Theme.PrimaryBg or Theme.ActionBg),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Size = UDim2.new(share, -(Theme.ButtonGroupGap * (count - 1)) / math.max(count, 1), 0, Theme.ActionMinH),
            LayoutOrder = index,
            Text = spec.Label or "Ação",
            Font = Enum.Font.Gotham,
            TextSize = Theme.ActionFont,
            TextColor3 = Theme.Color(spec.Primary and Theme.PrimaryText or Theme.ActionText),
            Parent = group,
        })
        corner(button, Theme.ActionRadius)
        stroke(button, spec.Primary and Theme.PrimaryBg or Theme.ActionBorder, 1)
        local base = button.BackgroundColor3
        self._connect(button.MouseEnter, function()
            button.BackgroundColor3 = Theme.Color(spec.Primary and Theme.PrimaryHoverBg or Theme.ActionHoverBg)
        end)
        self._connect(button.MouseLeave, function() button.BackgroundColor3 = base end)
        self._connect(button.MouseButton1Click, function()
            if spec.Callback then pcall(spec.Callback) end
        end)
        controls[#controls + 1] = button
    end
    return {Instance = group, Buttons = controls}
end

-- ---------------------------------------------------------------------------
-- Feedback
-- ---------------------------------------------------------------------------
function Panel:Notify(title, message, error)
    if self.Destroyed or not self.Toast then return end
    local token = self.ToastToken + 1
    self.ToastToken = token
    self.ToastTitle.Text = tostring(title or "")
    self.ToastMessage.Text = tostring(message or "")
    if self.ToastStroke then
        self.ToastStroke.Color = Theme.Color(error and Theme.ToastErrorBorder or Theme.ToastBorder)
    end
    self.Toast.Visible = true
    local TweenService = game:GetService("TweenService")
    local tween = TweenService:Create(
        self.Toast,
        TweenInfo.new(Theme.Duration.Toast, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Position = UDim2.new(1, -Theme.ToastRight, 1, -Theme.ToastBottom), BackgroundTransparency = 0.07}
    )
    tween:Play()
    task.delay(3.5, function()
        if self.Destroyed or self.ToastToken ~= token then return end
        local out = TweenService:Create(
            self.Toast,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(1, -Theme.ToastRight, 1, -Theme.ToastBottom + 40), BackgroundTransparency = 1}
        )
        out:Play()
        out.Completed:Once(function()
            if self.ToastToken == token then self.Toast.Visible = false end
        end)
    end)
end

-- Confirm(title, message, onConfirm, confirmLabel, cancelLabel)
function Panel:Confirm(title, message, onConfirm, confirmLabel, cancelLabel)
    if self.Destroyed or not self.DialogOverlay then return end
    self.DialogTitle.Text = tostring(title or "Confirmar ação?")
    self.DialogMessage.Text = tostring(message or "")
    self.DialogOverlay.Visible = true

    local group = self.DialogButtons
    group:ClearAllChildren()
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, Theme.ButtonGroupGap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = group,
    })
    local function close() self.DialogOverlay.Visible = false end
    local function makeButton(name, text, primary, order, callback)
        -- .button-group .action{flex:1;min-width:90px}: share the row equally.
        local button = new("TextButton", {
            Name = name,
            BackgroundColor3 = Theme.Color(primary and Theme.PrimaryBg or Theme.ActionBg),
            BorderSizePixel = 0,
            Size = UDim2.new(0.5, -(Theme.ButtonGroupGap / 2), 1, 0),
            LayoutOrder = order,
            Text = text,
            Font = Enum.Font.Gotham,
            TextSize = Theme.ActionFont,
            TextColor3 = Theme.Color(primary and Theme.PrimaryText or Theme.ActionText),
            AutoButtonColor = false,
            Parent = group,
        })
        corner(button, Theme.ActionRadius)
        stroke(button, primary and Theme.PrimaryBg or Theme.ActionBorder, 1)
        local base = button.BackgroundColor3
        self._connect(button.MouseEnter, function()
            button.BackgroundColor3 = Theme.Color(primary and Theme.PrimaryHoverBg or Theme.ActionHoverBg)
        end)
        self._connect(button.MouseLeave, function() button.BackgroundColor3 = base end)
        self._connect(button.MouseButton1Click, callback)
        return button
    end
    makeButton("Cancel", cancelLabel or "Cancelar", false, 1, close)
    makeButton("Confirm", confirmLabel or "Confirmar", true, 2, function()
        close()
        if onConfirm then pcall(onConfirm) end
    end)
end

function Panel:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for i = #self.Connections, 1, -1 do
        pcall(function() self.Connections[i]:Disconnect() end)
        self.Connections[i] = nil
    end
    if self.Menu then pcall(function() self.Menu:Destroy() end) self.Menu = nil end
    if self.ScreenGui then pcall(function() self.ScreenGui:Destroy() end) end
    self.ScreenGui = nil
end

return Panel
