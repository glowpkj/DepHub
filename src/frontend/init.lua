-- DepHub panel library.
--
-- Roblox translation of the authored interface mockup. It builds the same
-- monochrome window: a fixed panel with a draggable header, macOS-style window
-- buttons, a section sidebar, scrollable content, and the control set (toggle,
-- checkbox, slider, dropdown, text field, colour trigger, action buttons,
-- notices, collapsible groups). A toast and a confirmation modal complete it.
--
-- The panel is pure presentation. It never touches the game: callers hand it a
-- spec (tabs -> sections -> components) and receive callbacks when a control
-- changes. The loader wires those callbacks to a backend's State.
--
-- Naming note: the ScreenGui is named with "dephub" so src/core/ui-guard keeps
-- it enabled, on top and parented to gethui().
--
-- Modules here are loaded as plain chunks by the bundle (no require), so this
-- file is self-contained: the theme tokens are inlined below. src/core/theme.lua
-- mirrors the same values as the standalone reference.

-- Inlined theme tokens (kept in lockstep with src/core/theme.lua).
local Theme = {}
Theme.Accent = {r = 188, g = 188, b = 188}
Theme.Bg = {r = 9, g = 9, b = 9}
Theme.Surface = {r = 16, g = 16, b = 16}
Theme.Line = {r = 37, g = 37, b = 37}
Theme.Text = {r = 222, g = 222, b = 222}
Theme.Muted = {r = 154, g = 154, b = 154}
Theme.Quiet = {r = 119, g = 119, b = 119}

Theme.PanelWidth = 840
Theme.PanelHeight = 560
Theme.PanelRadius = 12
Theme.PanelBorder = {r = 44, g = 44, b = 44}
Theme.HeaderHeight = 100
Theme.FooterHeight = 40
Theme.SidebarWidth = 160

Theme.BrandAccent = {r = 209, g = 209, b = 209}
Theme.BrandInk = {r = 23, g = 23, b = 23}
Theme.LeftPad = 24
Theme.BrandTop = 20

Theme.CloseButton = {r = 255, g = 96, b = 88}
Theme.MinButton = {r = 254, g = 188, b = 46}
Theme.MaxButton = {r = 40, g = 200, b = 64}

Theme.NavBorder = {r = 28, g = 28, b = 28}
Theme.NavIdle = {r = 146, g = 146, b = 146}
Theme.NavActiveBg = {r = 26, g = 26, b = 26}
Theme.NavActiveText = {r = 227, g = 227, b = 227}
Theme.NavHoverBg = {r = 22, g = 22, b = 22}

Theme.MainBg = {r = 12, g = 12, b = 12}
Theme.RowBg = {r = 17, g = 17, b = 17}
Theme.RowHoverBg = {r = 22, g = 22, b = 22}
Theme.SectionLabel = {r = 153, g = 153, b = 153}
Theme.Heading = {r = 222, g = 222, b = 222}
Theme.HelpText = {r = 146, g = 146, b = 146}

Theme.FieldBg = {r = 17, g = 17, b = 17}
Theme.FieldBorder = {r = 51, g = 51, b = 51}
Theme.FieldFocusBg = {r = 22, g = 22, b = 22}
Theme.ToggleOff = {r = 48, g = 48, b = 48}
Theme.ToggleOffBorder = {r = 68, g = 68, b = 68}
Theme.ToggleKnobOff = {r = 148, g = 148, b = 148}
Theme.ToggleKnobOn = {r = 34, g = 34, b = 34}
Theme.ActionBg = {r = 29, g = 29, b = 29}
Theme.ActionBorder = {r = 58, g = 58, b = 58}
Theme.ActionHoverBg = {r = 39, g = 39, b = 39}
Theme.ActionHoverBorder = {r = 90, g = 90, b = 90}
Theme.PrimaryBg = {r = 204, g = 204, b = 204}
Theme.PrimaryInk = {r = 22, g = 22, b = 22}

Theme.FooterBorder = {r = 34, g = 34, b = 34}
Theme.FooterText = {r = 139, g = 139, b = 139}

Theme.ToastBg = {r = 21, g = 21, b = 21}
Theme.ToastBorder = {r = 58, g = 58, b = 58}
Theme.ToastError = {r = 121, g = 80, b = 80}
Theme.ModalBg = {r = 18, g = 18, b = 18}
Theme.ModalBorder = {r = 66, g = 66, b = 66}
Theme.NoticeBg = {r = 17, g = 17, b = 17}

function Theme.Color(token)
    if token == nil then return Color3.fromRGB(255, 255, 255) end
    return Color3.fromRGB(token.r, token.g, token.b)
end

function Theme.px(n)
    return UDim2.fromOffset(n, n)
end

local Panel = {}
Panel.__index = Panel

-- ---------------------------------------------------------------------------
-- Construction helpers
-- ---------------------------------------------------------------------------

local function NewInstance(class, props)
    local instance = Instance.new(class)
    for key, value in pairs(props or {}) do
        if key ~= "Parent" then
            instance[key] = value
        end
    end
    if props and props.Parent then
        instance.Parent = props.Parent
    end
    return instance
end

local function corner(instance, radius)
    NewInstance("UICorner", {CornerRadius = UDim.new(0, radius or 0), Parent = instance})
    return instance
end

local function stroke(instance, colour, thickness)
    NewInstance("UIStroke", {
        Color = Theme.Color(colour or Theme.Line),
        Thickness = thickness or 1,
        Parent = instance,
    })
    return instance
end

local function padding(instance, top, right, bottom, left)
    NewInstance("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        PaddingLeft = UDim.new(0, left or right or top or 0),
        Parent = instance,
    })
    return instance
end

local function text(instance, label, size, colour, bold)
    instance.Text = label or ""
    instance.TextSize = size or 12
    instance.TextColor3 = Theme.Color(colour or Theme.Text)
    instance.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    instance.TextXAlignment = Enum.TextXAlignment.Left
    instance.BackgroundTransparency = 1
    return instance
end

-- ---------------------------------------------------------------------------
-- Factory
-- ---------------------------------------------------------------------------

-- config = {
--   Title      = string (header brand, defaults "DepHub"),
--   GameName   = string (current-game caption),
--   Hotkey     = Enum.KeyCode (default Insert),
--   StartOpen  = boolean,
-- }
function Panel.new(config)
    config = config or {}
    local self = setmetatable({}, Panel)

    self.Destroyed = false
    self.Connections = {}
    self.Animations = {}
    self.Tabs = {}
    self.TabOrder = {}
    self.Components = {}
    self.Open = config.StartOpen ~= false
    self.Expanded = false
    self.Minimized = false
    self.Hotkey = config.Hotkey or Enum.KeyCode.Insert
    self.OnHotkeyChanged = nil

    local Players = game:GetService("Players")
    self.LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

    local function connect(signal, callback)
        if not signal then return nil end
        local connection = signal:Connect(callback)
        self.Connections[#self.Connections + 1] = connection
        return connection
    end
    self._connect = connect

    self:_buildGui(config)
    self:_buildHeader(config)
    self:_buildSidebar()
    self:_buildContent()
    self:_buildFooter()
    self:_buildToast()
    self:_buildModal()
    self:_bindHotkey()

    self:_applyLayout()
    return self
end

-- ---------------------------------------------------------------------------
-- Root screen gui
-- ---------------------------------------------------------------------------
function Panel:_buildGui(config)
    local Players = game:GetService("Players")
    local localPlayer = self.LocalPlayer
    local parent = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 15)

    local screen = NewInstance("ScreenGui", {
        Name = "DepHubPanel",           -- "dephub" keeps ui-guard protecting it
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 2147483647,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Enabled = self.Open,
        Parent = parent,
    })
    self.ScreenGui = screen

    local function guard(signal, callback)
        return self._connect(signal, callback)
    end
    guard(screen:GetPropertyChangedSignal("Enabled"), function()
        if not self.Destroyed and self.Open and not screen.Enabled then
            screen.Enabled = true
        end
    end)

    -- The window: fixed, centred, 840x560. Positioned by _applyLayout.
    local window = NewInstance("Frame", {
        Name = "Window",
        BackgroundColor3 = Theme.Color(Theme.Bg),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Parent = screen,
    })
    corner(window, Theme.PanelRadius)
    stroke(window, Theme.PanelBorder, 1)
    self.Window = window

    -- Everything except the header lives inside, so the header can be dragged
    -- independently and the body clips under it.
    local body = NewInstance("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -Theme.HeaderHeight),
        Position = UDim2.new(0, 0, 0, Theme.HeaderHeight),
        Parent = window,
    })
    self.Body = body
end

-- ---------------------------------------------------------------------------
-- Header (brand, current game, window buttons)
-- ---------------------------------------------------------------------------
function Panel:_buildHeader(config)
    local window = self.Window
    local header = NewInstance("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.HeaderHeight),
        Position = UDim2.fromOffset(0, 0),
        Active = true,
        Parent = window,
    })
    self.Header = header
    NewInstance("Frame", {
        Name = "Underline",
        BackgroundColor3 = Theme.Color(Theme.Line),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        Parent = header,
    })

    -- Brand: mark + name
    local brand = NewInstance("Frame", {
        Name = "Brand",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(220, 30),
        Position = UDim2.fromOffset(Theme.LeftPad, Theme.BrandTop),
        Parent = header,
    })
    local mark = NewInstance("Frame", {
        Name = "Mark",
        BackgroundColor3 = Theme.Color(Theme.BrandAccent),
        BorderSizePixel = 0,
        Size = Theme.px(30),
        Parent = brand,
    })
    corner(mark, 7)
    text(NewInstance("TextLabel", {
        Name = "Glyph",
        Size = UDim2.new(1, 0, 1, 0),
        TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = mark,
    }), "D", 16, Theme.BrandInk, true)
    text(NewInstance("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.fromOffset(40, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = brand,
    }), config.Title or "DepHub", 15, Theme.Text, true)

    -- Current game caption
    local gameRow = NewInstance("Frame", {
        Name = "CurrentGame",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -48, 0, 16),
        Position = UDim2.fromOffset(Theme.LeftPad, 64),
        Parent = header,
    })
    local indicator = NewInstance("Frame", {
        Name = "Indicator",
        BackgroundColor3 = Theme.Color(Theme.Quiet),
        BorderSizePixel = 0,
        Size = Theme.px(4),
        Position = UDim2.fromOffset(0, 6),
        Parent = gameRow,
    })
    corner(indicator, 2)
    self.GameLabel = text(NewInstance("TextLabel", {
        Name = "GameName",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -14, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = gameRow,
    }), config.GameName or "Aguardando jogo", 11, Theme.Muted, false)

    -- Window buttons: three traffic lights
    local buttons = NewInstance("Frame", {
        Name = "WindowButtons",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(120, 40),
        Position = UDim2.new(1, -128, 0, 13),
        Parent = header,
    })
    local specs = {
        {Name = "Close", Colour = Theme.CloseButton, Label = "×"},
        {Name = "Minimize", Colour = Theme.MinButton, Label = "−"},
        {Name = "Expand", Colour = Theme.MaxButton, Label = "⤢"},
    }
    self.WindowButtons = {}
    for index, spec in ipairs(specs) do
        local dot = NewInstance("TextButton", {
            Name = spec.Name,
            BackgroundColor3 = Theme.Color(spec.Colour),
            BorderSizePixel = 0,
            Text = "",
            Size = Theme.px(13),
            Position = UDim2.fromOffset((index - 1) * 34, 13),
            AutoButtonColor = false,
            Parent = buttons,
        })
        corner(dot, 7)
        text(dot, spec.Label, 12, {r = 0, g = 0, b = 0}, false)
        dot.TextTransparency = 1
        dot.TextYAlignment = Enum.TextYAlignment.Center
        dot.TextXAlignment = Enum.TextXAlignment.Center
        self.WindowButtons[spec.Name] = dot
    end

    self._connect(self.WindowButtons.Close.MouseButton1Click, function()
        self:SetOpen(false)
    end)
    self._connect(self.WindowButtons.Minimize.MouseButton1Click, function()
        self:ToggleMinimize()
    end)
    self._connect(self.WindowButtons.Expand.MouseButton1Click, function()
        self:ToggleExpand()
    end)
end

-- ---------------------------------------------------------------------------
-- Sidebar (section navigation)
-- ---------------------------------------------------------------------------
function Panel:_buildSidebar()
    local sidebar = NewInstance("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = Theme.Color(Theme.Bg),
        BorderSizePixel = 0,
        Size = UDim2.new(0, Theme.SidebarWidth, 1, -Theme.FooterHeight),
        Parent = self.Body,
    })
    NewInstance("Frame", {
        Name = "Divider",
        BackgroundColor3 = Theme.Color(Theme.NavBorder),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        Parent = sidebar,
    })
    padding(sidebar, 20, 10, 20, 10)

    local list = NewInstance("Frame", {
        Name = "List",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = sidebar,
    })
    NewInstance("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })
    self.NavList = list
    self.Sidebar = sidebar
end

-- ---------------------------------------------------------------------------
-- Content area
-- ---------------------------------------------------------------------------
function Panel:_buildContent()
    local content = NewInstance("ScrollingFrame", {
        Name = "Content",
        BackgroundColor3 = Theme.Color(Theme.MainBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, -Theme.SidebarWidth, 1, -Theme.FooterHeight),
        Position = UDim2.fromOffset(Theme.SidebarWidth, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Color({r = 58, g = 58, b = 58}),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = self.Body,
    })
    padding(content, 25, 26, 30, 26)
    local layout = NewInstance("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = content,
    })
    self.Content = content
    self.ContentLayout = layout
end

-- ---------------------------------------------------------------------------
-- Footer
-- ---------------------------------------------------------------------------
function Panel:_buildFooter()
    local footer = NewInstance("Frame", {
        Name = "Footer",
        BackgroundColor3 = Theme.Color(Theme.Bg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Theme.FooterHeight),
        Position = UDim2.new(0, 0, 1, -Theme.FooterHeight),
        Parent = self.Body,
    })
    NewInstance("Frame", {
        Name = "Divider",
        BackgroundColor3 = Theme.Color(Theme.FooterBorder),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Parent = footer,
    })
    padding(footer, 11, 22, 11, 22)
    text(NewInstance("TextLabel", {
        Name = "Brand",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 120, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = footer,
    }), "D / DEPHUB", 9, Theme.FooterText, false)

    self.StatusLabel = text(NewInstance("TextLabel", {
        Name = "Status",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -240, 1, 0),
        Position = UDim2.fromOffset(120, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = footer,
    }), "DepHub", 9, Theme.FooterText, false)

    self.KeyLabel = text(NewInstance("TextLabel", {
        Name = "Key",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 90, 1, 0),
        Position = UDim2.new(1, -90, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = footer,
    }), "INSERT", 9, Theme.FooterText, false)
    self.Footer = footer
end

-- ---------------------------------------------------------------------------
-- Toast
-- ---------------------------------------------------------------------------
function Panel:_buildToast()
    local toast = NewInstance("Frame", {
        Name = "Toast",
        BackgroundColor3 = Theme.Color(Theme.ToastBg),
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(310, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(1, -22, 1, -22),
        AnchorPoint = Vector2.new(1, 1),
        Visible = false,
        ZIndex = 100,
        Parent = self.ScreenGui,
    })
    corner(toast, 9)
    stroke(toast, Theme.ToastBorder, 1)
    padding(toast, 16, 16, 16, 16)
    NewInstance("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = toast,
    })
    self.ToastTitle = text(NewInstance("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        LayoutOrder = 1,
        Parent = toast,
    }), "", 12, Theme.Text, true)
    self.ToastMessage = text(NewInstance("TextLabel", {
        Name = "Message",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        Parent = toast,
    }), "", 11, Theme.Muted, false)
    self.Toast = toast
    self.ToastStroke = toast:FindFirstChildOfClass("UIStroke")
    self._toastToken = 0
end

-- ---------------------------------------------------------------------------
-- Confirmation modal
-- ---------------------------------------------------------------------------
function Panel:_buildModal()
    local overlay = NewInstance("Frame", {
        Name = "ModalOverlay",
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 200,
        Parent = self.ScreenGui,
    })
    local dialog = NewInstance("Frame", {
        Name = "Dialog",
        BackgroundColor3 = Theme.Color(Theme.ModalBg),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(390, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        ZIndex = 201,
        Parent = overlay,
    })
    corner(dialog, 12)
    stroke(dialog, Theme.ModalBorder, 1)
    padding(dialog, 25, 25, 25, 25)
    NewInstance("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = dialog,
    })
    self.ModalTitle = text(NewInstance("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 22),
        LayoutOrder = 1,
        Parent = dialog,
    }), "Confirmar ação?", 18, Theme.Text, false)
    self.ModalMessage = text(NewInstance("TextLabel", {
        Name = "Message",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        Parent = dialog,
    }), "", 12, Theme.Muted, false)

    local group = NewInstance("Frame", {
        Name = "Buttons",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 38),
        LayoutOrder = 3,
        Parent = dialog,
    })
    self.ModalOverlay = overlay
    self.Modal = dialog
    self._modalButtons = group
    self._modalConfirm = nil
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
    if self.Minimized then
        window.Size = UDim2.new(0, Theme.PanelWidth, 0, Theme.HeaderHeight + 1)
    elseif self.Expanded then
        window.Size = UDim2.new(1, -32, 1, -92)
        window.Position = UDim2.fromOffset(16, 76)
    else
        window.Size = UDim2.fromOffset(Theme.PanelWidth, Theme.PanelHeight)
        window.Position = UDim2.fromScale(0.5, 0.5)
        window.AnchorPoint = Vector2.new(0.5, 0.5)
    end
    if not self.Expanded then
        window.AnchorPoint = Vector2.new(0.5, 0.5)
    end
    if self.Minimized then
        self.Sidebar.Visible = false
        self.Content.Visible = false
        self.Footer.Visible = false
    else
        self.Sidebar.Visible = true
        self.Content.Visible = true
        self.Footer.Visible = true
    end
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
    if self.GameLabel and type(name) == "string" then
        self.GameLabel.Text = name
    end
end

function Panel:SetStatus(text)
    if self.StatusLabel and type(text) == "string" then
        self.StatusLabel.Text = text
    end
end

-- ---------------------------------------------------------------------------
-- Tabs
-- ---------------------------------------------------------------------------

-- CreateTab(name, glyph) -> {Name, Page, Button}
-- The first tab created becomes active.
function Panel:CreateTab(name, glyph)
    assert(type(name) == "string" and #name > 0, "CreateTab needs a name")

    local index = #self.TabOrder + 1
    local page = NewInstance("Frame", {
        Name = name,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = #self.TabOrder == 0,
        Parent = self.Content,
    })
    NewInstance("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })

    local button = NewInstance("TextButton", {
        Name = name,
        BackgroundColor3 = (#self.TabOrder == 0) and Theme.Color(Theme.NavActiveBg) or Theme.Color(Theme.Bg),
        BackgroundTransparency = (#self.TabOrder == 0) and 0 or 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 44),
        LayoutOrder = index,
        Text = "",
        Parent = self.NavList,
    })
    corner(button, 6)
    text(NewInstance("TextLabel", {
        Name = "Glyph",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(20, 0),
        Position = UDim2.fromOffset(10, 0),
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextColor3 = Theme.Color(Theme.NavIdle),
        Parent = button,
    }), glyph or "•", 17, Theme.NavIdle, false).Size = UDim2.new(0, 20, 1, 0)
    local label = NewInstance("TextLabel", {
        Name = "Label",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.fromOffset(39, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = button,
    })
    label.Text = name
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Theme.Color(Theme.NavIdle)

    local tab = {Name = name, Page = page, Button = button, Label = label, Glyph = button:FindFirstChild("Glyph")}
    self.Tabs[name] = tab
    self.TabOrder[#self.TabOrder + 1] = tab

    self._connect(button.MouseEnter, function()
        if not tab.Active then
            button.BackgroundTransparency = 0
            button.BackgroundColor3 = Theme.Color(Theme.NavHoverBg)
            label.TextColor3 = Theme.Color(Theme.Heading)
        end
    end)
    self._connect(button.MouseLeave, function()
        if not tab.Active then
            button.BackgroundTransparency = 1
            label.TextColor3 = Theme.Color(Theme.NavIdle)
            if tab.Glyph then tab.Glyph.TextColor3 = Theme.Color(Theme.NavIdle) end
        end
    end)
    self._connect(button.MouseButton1Click, function()
        self:SelectTab(name)
    end)

    if #self.TabOrder == 1 then
        tab.Active = true
    end
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
        tab.Button.BackgroundColor3 = Theme.Color(active and Theme.NavActiveBg or Theme.Bg)
        tab.Label.TextColor3 = Theme.Color(active and Theme.NavActiveText or Theme.NavIdle)
        if tab.Glyph then
            tab.Glyph.TextColor3 = Theme.Color(active and Theme.NavActiveText or Theme.NavIdle)
        end
    end
    return target
end

-- ---------------------------------------------------------------------------
-- Section building blocks
-- ---------------------------------------------------------------------------

local function labelBlock(parent, title, help, order)
    local box = NewInstance("Frame", {
        Name = "Labels",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order or 1,
        Parent = parent,
    })
    NewInstance("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = box,
    })
    local label = text(NewInstance("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 1,
        Parent = box,
    }), title or "", 12, Theme.Heading, false)
    local helpLabel
    if help and #help > 0 then
        helpLabel = text(NewInstance("TextLabel", {
            Name = "Help",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 2,
            Parent = box,
        }), help, 10, Theme.HelpText, false)
    end
    return box, label, helpLabel
end

-- AddSection(tab, label) -> adds a small uppercase section header.
function Panel:AddSection(tab, label)
    local title = type(tab) == "table" and tab.Page or tab
    local header = text(NewInstance("TextLabel", {
        Name = "SectionLabel",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        LayoutOrder = (self._order or 0) + 1,
        Parent = title,
    }), string.upper(label or ""), 9, Theme.SectionLabel, false)
    header.TextXAlignment = Enum.TextXAlignment.Left
    self._order = (self._order or 0) + 1
    return header
end

-- Row(frame with title/help + right-hand control). Returns row frame, the
-- left-hand labels block and the right-hand slot Frame where a control goes.
-- Layout mirrors the CSS: .row is flex/space-between, labels take the left and
-- the control sits on the right.
function Panel:_row(tab, title, help, order)
    local page = tab.Page or tab
    local row = NewInstance("Frame", {
        Name = title or "Row",
        BackgroundColor3 = Theme.Color(Theme.RowBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 61),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order,
        ClipsDescendants = false,
        Parent = page,
    })
    corner(row, 6)
    padding(row, 14, 14, 14, 14)

    local labels = labelBlock(row, title, help, 1)
    labels.Size = UDim2.new(1, -170, 0, 0)
    labels.Position = UDim2.fromOffset(0, 0)

    local slot = NewInstance("Frame", {
        Name = "Control",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(160, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Parent = row,
    })
    -- The row keeps the CSS min-height (61px) but grows if the labels wrap.
    NewInstance("UISizeConstraint", {
        Name = "MinHeight",
        MinSize = Vector2.new(0, 61),
        MaxSize = Vector2.new(math.huge, math.huge),
        Parent = row,
    })
    return row, labels, slot
end

-- ---------------------------------------------------------------------------
-- Controls
-- ---------------------------------------------------------------------------

function Panel:_next(page)
    self._order = (self._order or 0) + 1
    return self._order
end

-- AddToggle(tab, title, help, value, callback) -> {Set, Get, Instance}
function Panel:AddToggle(tab, title, help, value, callback)
    local order = self:_next(tab)
    local row, _, slot = self:_row(tab, title, help, order)
    local on = value == true

    local toggle = NewInstance("TextButton", {
        Name = "Toggle",
        BackgroundColor3 = Theme.Color(on and Theme.Accent or Theme.ToggleOff),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(34, 21),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        AutoButtonColor = false,
        Text = "",
        Parent = slot,
    })
    corner(toggle, 11)
    stroke(toggle, on and Theme.Accent or Theme.ToggleOffBorder, 1)
    local knob = NewInstance("Frame", {
        Name = "Knob",
        BackgroundColor3 = Theme.Color(on and Theme.ToggleKnobOn or Theme.ToggleKnobOff),
        BorderSizePixel = 0,
        Size = Theme.px(13),
        Position = UDim2.fromOffset(on and 18 or 3, 3),
        Parent = toggle,
    })
    corner(knob, 7)

    local control = {}
    local busy = false
    local function render()
        toggle.BackgroundColor3 = Theme.Color(on and Theme.Accent or Theme.ToggleOff)
        local s = toggle:FindFirstChildOfClass("UIStroke")
        if s then s.Color = Theme.Color(on and Theme.Accent or Theme.ToggleOffBorder) end
        knob.BackgroundColor3 = Theme.Color(on and Theme.ToggleKnobOn or Theme.ToggleKnobOff)
        knob.Position = UDim2.fromOffset(on and 18 or 3, 3)
    end
    function control:Get() return on end
    function control:Set(next, silent)
        next = next == true
        if next == on then return on end
        on = next
        render()
        if not silent and callback then
            if busy then return on end
            busy = true
            local ok, err = pcall(callback, on)
            busy = false
            if not ok and type(warn) == "function" then warn("[DepHub panel] toggle callback: " .. tostring(err)) end
        end
        return on
    end

    self._connect(toggle.MouseButton1Click, function()
        control:Set(not on)
    end)
    control.Instance = toggle
    control.Row = row
    self.Components[#self.Components + 1] = control
    return control
end

-- AddCheckbox: a plain square checkbox (indeterminate-free), used for the
-- "remember preferences" style rows.
function Panel:AddCheckbox(tab, title, help, value, callback)
    local order = self:_next(tab)
    local row, _, slot = self:_row(tab, title, help, order)
    local on = value == true

    local box = NewInstance("TextButton", {
        Name = "Checkbox",
        BackgroundColor3 = Theme.Color(Theme.FieldBg),
        BorderSizePixel = 0,
        Size = Theme.px(17),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        AutoButtonColor = false,
        Text = "",
        Parent = slot,
    })
    corner(box, 3)
    stroke(box, on and Theme.Accent or Theme.FieldBorder, 1)
    local tick = text(NewInstance("TextLabel", {
        Name = "Tick",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextYAlignment = Enum.TextYAlignment.Center,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = box,
    }), "✓", 12, Theme.BrandInk, true)
    tick.Visible = on
    tick.TextColor3 = Theme.Color(Theme.BrandInk)

    local control = {}
    local function render()
        box.BackgroundColor3 = Theme.Color(on and Theme.Accent or Theme.FieldBg)
        local s = box:FindFirstChildOfClass("UIStroke")
        if s then s.Color = Theme.Color(on and Theme.Accent or Theme.FieldBorder) end
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
    self._connect(box.MouseButton1Click, function()
        control:Set(not on)
    end)
    control.Instance = box
    control.Row = row
    self.Components[#self.Components + 1] = control
    return control
end

-- AddSlider(tab, title, help, min, max, step, value, callback) -> {Set,Get}
function Panel:AddSlider(tab, title, help, min, max, step, value, callback)
    local order = self:_next(tab)
    local row, _, _ = self:_row(tab, title, help, order)
    -- Sliders take the full width under the label block, like the CSS .range.
    row.Size = UDim2.new(1, 0, 0, 92)
    row:FindFirstChild("Control"):Destroy()

    local minV = tonumber(min) or 0
    local maxV = tonumber(max) or 100
    local stepV = tonumber(step) or 1
    local current = math.clamp(tonumber(value) or minV, minV, maxV)

    local readout = text(NewInstance("TextLabel", {
        Name = "Readout",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 30),
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    }), tostring(current), 11, Theme.Muted, false)

    local track = NewInstance("Frame", {
        Name = "Track",
        BackgroundColor3 = Theme.Color(Theme.ToggleOff),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 5),
        Position = UDim2.new(0, 0, 0, 62),
        Parent = row,
    })
    corner(track, 3)
    local fill = NewInstance("Frame", {
        Name = "Fill",
        BackgroundColor3 = Theme.Color(Theme.Accent),
        BorderSizePixel = 0,
        Size = UDim2.fromScale((current - minV) / math.max(maxV - minV, 1e-6), 1),
        Parent = track,
    })
    corner(fill, 3)
    local knob = NewInstance("Frame", {
        Name = "Knob",
        BackgroundColor3 = Theme.Color(Theme.Accent),
        BorderSizePixel = 0,
        Size = Theme.px(14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((current - minV) / math.max(maxV - minV, 1e-6), 0, 0.5, 0),
        Parent = track,
    })
    corner(knob, 7)

    local hitbox = NewInstance("TextButton", {
        Name = "Hitbox",
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.new(1, 0, 0, 24),
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
        readout.Text = tostring(v)
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
    local function updateFromInput(px)
        local trackAbs = track.AbsolutePosition.X
        local trackW = math.max(track.AbsoluteSize.X, 1)
        local alpha = math.clamp((px - trackAbs) / trackW, 0, 1)
        control:Set(minV + alpha * (maxV - minV))
    end
    self._connect(hitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromInput(input.Position.X)
        end
    end)
    self._connect(hitbox.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    self._connect(game:GetService("UserInputService").InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input.Position.X)
        end
    end)

    control.Instance = track
    control.Row = row
    render(current)
    self.Components[#self.Components + 1] = control
    return control
end

-- AddDropdown(tab, title, help, options, value, callback) -> {Set,Get}
-- options is an array of strings; value is the initially selected string.
function Panel:AddDropdown(tab, title, help, options, value, callback)
    local order = self:_next(tab)
    local row, _, slot = self:_row(tab, title, help, order)
    options = options or {}

    local current = value
    if current == nil and #options > 0 then current = options[1] end

    local trigger = NewInstance("TextButton", {
        Name = "Trigger",
        BackgroundColor3 = Theme.Color({r = 27, g = 27, b = 27}),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 38),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        AutoButtonColor = false,
        Text = "",
        Parent = slot,
    })
    corner(trigger, 6)
    stroke(trigger, {r = 59, g = 59, b = 59}, 1)
    local shown = text(NewInstance("TextLabel", {
        Name = "Value",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.fromOffset(11, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = trigger,
    }), tostring(current or "—"), 11, {r = 197, g = 197, b = 197}, false)
    text(NewInstance("TextLabel", {
        Name = "Caret",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(18, 0),
        Position = UDim2.new(1, -22, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = trigger,
    }), "⌄", 12, Theme.Muted, false)

    local control = {Options = options}
    local function render()
        shown.Text = tostring(current or "—")
    end
    function control:Get() return current end
    function control:Set(next, silent)
        local found = false
        for _, option in ipairs(options) do
            if option == next then found = true break end
        end
        if not found then return current end
        if next == current then return current end
        current = next
        render()
        if not silent and callback then pcall(callback, current) end
        return current
    end
    self._connect(trigger.MouseButton1Click, function()
        self:_openDropdown(trigger, options, current, function(chosen)
            control:Set(chosen)
        end)
    end)
    control.Instance = trigger
    control.Row = row
    render()
    self.Components[#self.Components + 1] = control
    return control
end

-- Internal: a floating option list anchored under a trigger. One at a time.
function Panel:_openDropdown(trigger, options, current, onChoose)
    if self._menu then
        self._menu:Destroy()
        self._menu = nil
    end
    local menu = NewInstance("Frame", {
        Name = "DropdownMenu",
        BackgroundColor3 = Theme.Color({r = 23, g = 23, b = 23}),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(math.max(155, trigger.AbsoluteSize.X), 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(trigger.AbsolutePosition.X, trigger.AbsolutePosition.Y + trigger.AbsoluteSize.Y + 6),
        ZIndex = 150,
        Parent = self.ScreenGui,
    })
    corner(menu, 8)
    stroke(menu, {r = 59, g = 59, b = 59}, 1)
    padding(menu, 5, 5, 5, 5)
    NewInstance("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = menu,
    })
    for index, option in ipairs(options) do
        local selected = option == current
        local item = NewInstance("TextButton", {
            Name = option,
            BackgroundColor3 = selected and Theme.Color({r = 40, g = 40, b = 40}) or Theme.Color(Theme.Surface),
            BackgroundTransparency = selected and 0 or 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 37),
            LayoutOrder = index,
            Text = option,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextColor3 = Theme.Color(selected and Theme.Heading or Theme.Muted),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = menu,
        })
        corner(item, 5)
        padding(item, 0, 11, 0, 11)
        self._connect(item.MouseEnter, function()
            item.BackgroundTransparency = 0
            item.BackgroundColor3 = Theme.Color({r = 40, g = 40, b = 40})
            item.TextColor3 = Theme.Color(Theme.Text)
        end)
        self._connect(item.MouseLeave, function()
            if not selected then
                item.BackgroundTransparency = 1
                item.TextColor3 = Theme.Color(Theme.Muted)
            end
        end)
        self._connect(item.MouseButton1Click, function()
            menu:Destroy()
            if self._menu == menu then self._menu = nil end
            if onChoose then onChoose(option) end
        end)
    end
    self._menu = menu
    return menu
end

-- AddTextField(tab, title, placeholder, value, callback) -> {Set,Get}
function Panel:AddTextField(tab, title, placeholder, value, callback)
    local order = self:_next(tab)
    local page = tab.Page or tab
    local group = NewInstance("Frame", {
        Name = title or "TextField",
        BackgroundColor3 = Theme.Color(Theme.RowBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 74),
        LayoutOrder = order,
        Parent = page,
    })
    corner(group, 6)
    padding(group, 14, 14, 14, 14)
    text(NewInstance("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Parent = group,
    }), title or "", 11, {r = 176, g = 176, b = 176}, false)

    local box = NewInstance("TextBox", {
        Name = "Input",
        BackgroundColor3 = Theme.Color(Theme.MainBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42),
        Position = UDim2.fromOffset(0, 20),
        Text = tostring(value or ""),
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = Theme.Color({r = 129, g = 129, b = 129}),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.Color(Theme.Text),
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = group,
    })
    corner(box, 6)
    stroke(box, Theme.FieldBorder, 1)
    padding(box, 0, 12, 0, 12)

    local control = {}
    function control:Get() return box.Text end
    function control:Set(next, silent)
        box.Text = tostring(next or "")
        if not silent and callback then pcall(callback, box.Text) end
        return box.Text
    end
    self._connect(box.Focused, function()
        box.BackgroundColor3 = Theme.Color(Theme.FieldFocusBg)
        box:FindFirstChildOfClass("UIStroke").Color = Theme.Color(Theme.Quiet)
    end)
    self._connect(box.FocusLost, function(enterPressed)
        box.BackgroundColor3 = Theme.Color(Theme.MainBg)
        box:FindFirstChildOfClass("UIStroke").Color = Theme.Color(Theme.FieldBorder)
        if enterPressed and callback then pcall(callback, box.Text) end
    end)
    control.Instance = box
    control.Row = group
    self.Components[#self.Components + 1] = control
    return control
end

-- AddAction(tab, title, help, buttonLabel, callback, primary)
function Panel:AddAction(tab, title, help, buttonLabel, callback, primary)
    local order = self:_next(tab)
    local _, _, slot = self:_row(tab, title, help, order)
    local button = NewInstance("TextButton", {
        Name = "Action",
        BackgroundColor3 = Theme.Color(primary and Theme.PrimaryBg or Theme.ActionBg),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 38),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Text = buttonLabel or "Executar",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.Color(primary and Theme.PrimaryInk or {r = 204, g = 204, b = 204}),
        Parent = slot,
    })
    corner(button, 6)
    stroke(button, primary and Theme.PrimaryBg or Theme.ActionBorder, 1)
    local baseBg = button.BackgroundColor3
    self._connect(button.MouseEnter, function()
        button.BackgroundColor3 = Theme.Color(primary and {r = 224, g = 224, b = 224} or Theme.ActionHoverBg)
    end)
    self._connect(button.MouseLeave, function()
        button.BackgroundColor3 = baseBg
    end)
    self._connect(button.MouseButton1Click, function()
        if callback then pcall(callback) end
    end)

    local control = {Instance = button}
    function control:SetLabel(text) button.Text = tostring(text or "") end
    self.Components[#self.Components + 1] = control
    return control
end

-- AddNotice(tab, message, boldTitle)
function Panel:AddNotice(tab, message, boldTitle)
    local order = self:_next(tab)
    local page = tab.Page or tab
    local notice = NewInstance("Frame", {
        Name = "Notice",
        BackgroundColor3 = Theme.Color(Theme.NoticeBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order,
        Parent = page,
    })
    corner(notice, 6)
    padding(notice, 14, 14, 14, 14)
    local body = text(NewInstance("TextLabel", {
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        RichText = true,
        Parent = notice,
    }), (boldTitle and ("<b>" .. boldTitle .. "</b><br>") or "") .. (message or ""), 11, Theme.SectionLabel, false)
    body.TextColor3 = Theme.Color(Theme.SectionLabel)
    return notice
end

-- AddCollapsible(tab, summary, open) -> {Body, Toggle}
function Panel:AddCollapsible(tab, summary, open)
    local order = self:_next(tab)
    local page = tab.Page or tab
    local container = NewInstance("Frame", {
        Name = "Collapsible",
        BackgroundColor3 = Theme.Color(Theme.RowBg),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order,
        Parent = page,
    })
    corner(container, 6)
    local head = NewInstance("TextButton", {
        Name = "Summary",
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 44),
        Text = summary or "Seção",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.Color(Theme.Heading),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container,
    })
    padding(head, 0, 14, 0, 14)
    local body = NewInstance("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(0, 44),
        Visible = open == true,
        Parent = container,
    })
    padding(body, 0, 14, 14, 14)
    NewInstance("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = body,
    })
    local state = open == true
    self._connect(head.MouseButton1Click, function()
        state = not state
        body.Visible = state
        head.Text = (state and "▾ " or "▸ ") .. (summary or "Seção")
    end)
    head.Text = (state and "▾ " or "▸ ") .. (summary or "Seção")
    return {Body = body, Toggle = head}
end

-- ---------------------------------------------------------------------------
-- Feedback: toast + modal
-- ---------------------------------------------------------------------------
function Panel:Notify(title, message, error)
    if self.Destroyed or not self.Toast then return end
    local token = self._toastToken + 1
    self._toastToken = token
    self.ToastTitle.Text = tostring(title or "")
    self.ToastMessage.Text = tostring(message or "")
    if self.ToastStroke then
        self.ToastStroke.Color = Theme.Color(error and Theme.ToastError or Theme.ToastBorder)
    end
    self.Toast.Visible = true
    self.Toast.Position = UDim2.new(1, -22, 1, -50)
    local tween = game:GetService("TweenService"):Create(
        self.Toast,
        TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Position = UDim2.new(1, -22, 1, -22), BackgroundTransparency = 0.06}
    )
    tween:Play()
    task.delay(3.5, function()
        if self.Destroyed or self._toastToken ~= token then return end
        local out = game:GetService("TweenService"):Create(
            self.Toast,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(1, -22, 1, -50), BackgroundTransparency = 1}
        )
        out:Play()
        out.Completed:Once(function()
            if self._toastToken == token then self.Toast.Visible = false end
        end)
    end)
end

-- Confirm(title, message, onConfirm) -> shows a modal with Cancel/Confirm.
function Panel:Confirm(title, message, onConfirm)
    if self.Destroyed or not self.ModalOverlay then return end
    self.ModalTitle.Text = tostring(title or "Confirmar ação?")
    self.ModalMessage.Text = tostring(message or "")
    self.ModalOverlay.Visible = true

    local group = self._modalButtons
    if self._modalClose then
        pcall(function() self._modalClose:Disconnect() end)
        self._modalClose = nil
    end
    group:ClearAllChildren()
    NewInstance("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = group,
    })
    local function close()
        self.ModalOverlay.Visible = false
    end
    local cancel = NewInstance("TextButton", {
        Name = "Cancel", BackgroundColor3 = Theme.Color(Theme.ActionBg),
        BorderSizePixel = 0, Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 1,
        Text = "Cancelar", Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = Theme.Color({r = 204, g = 204, b = 204}), AutoButtonColor = false, Parent = group,
    })
    corner(cancel, 6)
    local confirm = NewInstance("TextButton", {
        Name = "Confirm", BackgroundColor3 = Theme.Color(Theme.PrimaryBg),
        BorderSizePixel = 0, Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 2,
        Text = "Confirmar", Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = Theme.Color(Theme.PrimaryInk), AutoButtonColor = false, Parent = group,
    })
    corner(confirm, 6)
    self._connect(cancel.MouseButton1Click, close)
    self._connect(confirm.MouseButton1Click, function()
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
    for _, animation in ipairs(self.Animations) do
        pcall(function() animation:Cancel() end)
    end
    self.Animations = {}
    if self._menu then pcall(function() self._menu:Destroy() end) self._menu = nil end
    if self.ScreenGui then pcall(function() self.ScreenGui:Destroy() end) end
    self.ScreenGui = nil
end

return Panel
