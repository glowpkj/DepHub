--[[
    DepHubUI.lua — Library de interface estilo Rayfield
    Uso:
        local Lib = loadstring(game:HttpGet("URL/DepHubUI.lua"))()
        local win = Lib:CreateWindow({ Title = "Meu Script" })
        local tab = win:CreateTab("Principal")
        tab:CreateToggle({ Name = "AutoFarm", Default = false, Callback = function(v) end })
    Visual: tema escuro DepHub (#151515 / #2b2b2b), cantos arredondados, toggle deslizante.
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Lib = {}
Lib.__index = Lib

local Theme = {
    Background   = Color3.fromRGB(0x15, 0x15, 0x15),
    Panel        = Color3.fromRGB(0x18, 0x18, 0x18),
    Sidebar      = Color3.fromRGB(0x13, 0x13, 0x13),
    Border       = Color3.fromRGB(0x2b, 0x2b, 0x2b),
    RowBorder    = Color3.fromRGB(0x28, 0x28, 0x28),
    Text         = Color3.fromRGB(0xbd, 0xbd, 0xbd),
    TextBright   = Color3.fromRGB(0xef, 0xef, 0xef),
    TextDim      = Color3.fromRGB(0x80, 0x80, 0x80),
    Accent       = Color3.fromRGB(0xd6, 0xd6, 0xd6),
    ToggleOff    = Color3.fromRGB(0x35, 0x35, 0x35),
    ToggleOn     = Color3.fromRGB(0xd6, 0xd6, 0xd6),
    Button       = Color3.fromRGB(0x25, 0x25, 0x25),
    ButtonHover  = Color3.fromRGB(0x33, 0x33, 0x33),
    Input        = Color3.fromRGB(0x22, 0x22, 0x22),
    Font         = Enum.Font.Gotham,
    FontBold     = Enum.Font.GothamBold,
    Corner       = UDim.new(0, 7),
}

local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(inst, radius)
    return new("UICorner", { CornerRadius = radius or Theme.Corner }, inst)
end

local function stroke(inst, color, thickness)
    return new("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, inst)
end

local function padding(inst, px)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
        PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
    }, inst)
end

local function tween(inst, time, props)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
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
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function safeParent()
    local ok, gui = pcall(function() return CoreGui end)
    if ok and gui then
        local test = new("ScreenGui", { Name = "DepHubUI_probe" })
        local s = pcall(function() test.Parent = CoreGui end)
        test:Destroy()
        if s then return CoreGui end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

Lib.Theme = Theme
Lib._helpers = { new = new, corner = corner, stroke = stroke, padding = padding, tween = tween, draggable = makeDraggable }



-- ============================================================================
-- WINDOW
-- ============================================================================
local Window = {}
Window.__index = Window

function Lib:CreateWindow(opts)
    opts = opts or {}
    local win = setmetatable({}, Window)
    win.Tabs = {}
    win.Flags = {}
    win.Title = opts.Title or "DepHub"
    win.Subtitle = opts.Subtitle or "LIBRARY"
    win.Size = opts.Size or UDim2.fromOffset(740, 455)
    win.Keybind = opts.Keybind or Enum.KeyCode.RightShift

    local gui = new("ScreenGui", {
        Name = "DepHubUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, safeParent())
    win.Gui = gui

    -- Container arrastável
    local main = new("Frame", {
        Name = "Main",
        Size = win.Size,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Active = true,
    }, gui)
    corner(main)
    stroke(main, Theme.Border)
    makeDraggable(main, main)

    -- Header
    local header = new("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 66),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    }, main)
    corner(header)
    new("Frame", { -- cobre os cantos de baixo do header (só cantos de cima arredondados)
        Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 1, -8),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    }, header)
    new("Frame", { -- linha divisória inferior
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
    }, header)
    padding(header, 25)

    new("TextLabel", {
        Size = UDim2.new(0, 200, 1, 0),
        BackgroundTransparency = 1,
        Text = win.Title,
        TextColor3 = Theme.TextBright,
        Font = Theme.FontBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local badge = new("TextLabel", {
        Size = UDim2.new(0, 90, 0, 22),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Text = win.Subtitle,
        TextColor3 = Theme.TextDim,
        Font = Theme.Font,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, header)

    -- Sidebar (nav)
    local sidebar = new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 160, 1, -66),
        Position = UDim2.new(0, 0, 0, 66),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
    }, main)
    new("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
    }, sidebar)
    local navPad = padding(sidebar, 12)
    navPad.PaddingTop = UDim.new(0, 20)
    navPad.PaddingBottom = UDim.new(0, 20)
    local navLayout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 7),
    }, sidebar)

    -- Área de conteúdo
    local content = new("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -160, 1, -66),
        Position = UDim2.new(0, 160, 0, 66),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, main)
    win.Content = content

    -- Toggle button flutuante (esconde/mostra)
    local toggleBtn = new("TextButton", {
        Name = "Toggle",
        Size = UDim2.fromOffset(40, 40),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = Theme.Panel,
        Text = "d",
        TextColor3 = Theme.TextBright,
        Font = Theme.FontBold,
        TextSize = 18,
        Visible = false,
        ZIndex = 5,
    }, gui)
    corner(toggleBtn, UDim.new(1, 0))
    stroke(toggleBtn)
    toggleBtn.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
    end)

    -- Keybind para esconder/mostrar janela
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == win.Keybind then
            main.Visible = not main.Visible
            toggleBtn.Visible = not main.Visible
        end
    end)

    -- Botão de fechar
    local closeBtn = new("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -8, 0, 8),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBold,
        TextSize = 22,
        ZIndex = 3,
    }, header)
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = Theme.TextBright end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = Theme.TextDim end)
    closeBtn.MouseButton1Click:Connect(function()
        main.Visible = false
        toggleBtn.Visible = true
    end)

    win.Main = main
    win.Sidebar = sidebar
    win.Header = header
    win.ToggleButton = toggleBtn
    win._navLayout = navLayout

    return win
end

function Window:CreateTab(name, icon)
    local tab = { Name = name, Elements = {}, Buttons = {} }

    local btn = new("TextButton", {
        Name = "Tab_" .. name,
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Theme.Sidebar,
        Text = "  " .. name,
        TextColor3 = Theme.TextDim,
        Font = Theme.Font,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 0,
        AutoButtonColor = false,
    }, self.Sidebar)
    corner(btn)

    local page = new("ScrollingFrame", {
        Name = "Page_" .. name,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Border,
        Visible = false,
    }, self.Content)
    local pPad = padding(page, 20)
    pPad.PaddingTop = UDim.new(0, 28)
    pPad.PaddingLeft = UDim.new(0, 30)
    pPad.PaddingRight = UDim.new(0, 30)
    local pageLayout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, page)
    pageLayout.Changed:Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 40)
    end)

    tab.Button = btn
    tab.Page = page
    tab.Layout = pageLayout
    tab.Window = self
    tab.__index = tab

    local function activate()
        for _, t in pairs(self.Tabs) do
            t.Button.BackgroundColor3 = Theme.Sidebar
            t.Button.TextColor3 = Theme.TextDim
            t.Page.Visible = false
        end
        btn.BackgroundColor3 = Color3.fromRGB(0x29, 0x29, 0x29)
        btn.TextColor3 = Color3.fromRGB(0xf1, 0xf1, 0xf1)
        page.Visible = true
    end

    btn.MouseEnter:Connect(function()
        if not page.Visible then btn.BackgroundColor3 = Color3.fromRGB(0x23, 0x23, 0x23) end
    end)
    btn.MouseLeave:Connect(function()
        if not page.Visible then btn.BackgroundColor3 = Theme.Sidebar end
    end)
    btn.MouseButton1Click:Connect(activate)

    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then activate() end

    return tab
end

-- ============================================================================
-- COMPONENTES DA TAB
-- ============================================================================
local function createRow(parent, height)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, height or 58),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
    }, parent)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.RowBorder,
        BorderSizePixel = 0,
    }, row)
    return row
end

local function createTitleBlock(row, name, desc)
    local block = new("Frame", {
        Size = UDim2.new(0.55, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
    }, row)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0.5, desc and -10 or -9),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Theme.Text,
        Font = Theme.Font,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, block)
    if desc and desc ~= "" then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.new(0, 0, 0.5, 8),
            BackgroundTransparency = 1,
            Text = desc,
            TextColor3 = Theme.TextDim,
            Font = Theme.Font,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, block)
    end
    return block
end

-- SECTION ----------------------------------------------------------------
function Window.CreateSection(self, name)
    local label = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = string.upper(name),
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = #self.Elements + 1,
    }, self.Page)
    table.insert(self.Elements, label)
    return label
end

-- LABEL / PARAGRAPH ------------------------------------------------------
function Window.CreateLabel(self, name)
    local l = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Theme.Text,
        Font = Theme.Font,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = #self.Elements + 1,
    }, self.Page)
    table.insert(self.Elements, l)
    return l
end

function Window.CreateParagraph(self, text)
    local l = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.TextDim,
        Font = Theme.Font,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = #self.Elements + 1,
    }, self.Page)
    table.insert(self.Elements, l)
    return l
end

-- TOGGLE -----------------------------------------------------------------
function Window.CreateToggle(self, opts)
    opts = opts or {}
    local state = opts.Default or false
    local row = createRow(self.Page, 58)
    row.LayoutOrder = #self.Elements + 1
    table.insert(self.Elements, row)
    createTitleBlock(row, opts.Name or "Toggle", opts.Description)

    local toggle = new("TextButton", {
        Size = UDim2.fromOffset(35, 21),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(toggle, UDim.new(1, 0))
    local knob = new("Frame", {
        Size = UDim2.fromOffset(15, 15),
        Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = state and Color3.fromRGB(0x2b, 0x2b, 0x2b) or Color3.fromRGB(0x92, 0x92, 0x92),
        BorderSizePixel = 0,
    }, toggle)
    corner(knob, UDim.new(1, 0))

    local api = {}
    function api:Set(value)
        state = value and true or false
        tween(toggle, 0.18, { BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff })
        tween(knob, 0.18, {
            Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = state and Color3.fromRGB(0x2b, 0x2b, 0x2b) or Color3.fromRGB(0x92, 0x92, 0x92),
        })
        if opts.Callback then task.spawn(opts.Callback, state) end
    end
    function api:Get() return state end

    toggle.MouseButton1Click:Connect(function() api:Set(not state) end)
    if opts.Flag then self.Window.Flags[opts.Flag] = api end
    if opts.Default and opts.Callback then task.spawn(opts.Callback, state) end
    return api
end

-- SLIDER -----------------------------------------------------------------
function Window.CreateSlider(self, opts)
    opts = opts or {}
    local min = opts.Min or 0
    local max = opts.Max or 100
    local value = opts.Default or min
    local suffix = opts.Suffix or ""

    local row = createRow(self.Page, 74)
    row.LayoutOrder = #self.Elements + 1
    table.insert(self.Elements, row)

    local titleRow = new("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.new(0, 0, 0, 8),
        BackgroundTransparency = 1,
    }, row)
    new("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Name or "Slider",
        TextColor3 = Theme.Text,
        Font = Theme.Font,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, titleRow)
    local out = new("TextLabel", {
        Size = UDim2.new(0, 80, 0, 20),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Input,
        Text = tostring(value) .. suffix,
        TextColor3 = Theme.Text,
        Font = Theme.Font,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, titleRow)
    corner(out, UDim.new(0, 5))
    stroke(out, Theme.Border)

    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 5),
        Position = UDim2.new(0, 0, 0, 48),
        BackgroundColor3 = Theme.ToggleOff,
        BorderSizePixel = 0,
    }, row)
    corner(track, UDim.new(1, 0))
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0xcf, 0xcf, 0xcf),
        BorderSizePixel = 0,
    }, track)
    corner(fill, UDim.new(1, 0))
    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(0xef, 0xef, 0xef),
        BorderSizePixel = 0,
        ZIndex = 2,
    }, track)
    corner(knob, UDim.new(1, 0))
    stroke(knob, Theme.Border)

    local dragging = false
    local function updateFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * rel + 0.5)
        local frac = (value - min) / (max - min)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        knob.Position = UDim2.new(frac, 0, 0.5, 0)
        out.Text = tostring(value) .. suffix
        if opts.Callback then task.spawn(opts.Callback, value) end
    end

    local api = {}
    function api:Set(v)
        value = math.clamp(v, min, max)
        local frac = (value - min) / (max - min)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        knob.Position = UDim2.new(frac, 0, 0.5, 0)
        out.Text = tostring(value) .. suffix
        if opts.Callback then task.spawn(opts.Callback, value) end
    end
    function api:Get() return value end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    api:Set(value)
    if opts.Flag then self.Window.Flags[opts.Flag] = api end
    return api
end

-- DROPDOWN ---------------------------------------------------------------
function Window.CreateDropdown(self, opts)
    opts = opts or {}
    local options = opts.Options or {}
    local selected = opts.Default or (options[1] or "")
    local open = false

    local row = createRow(self.Page, 58)
    row.LayoutOrder = #self.Elements + 1
    table.insert(self.Elements, row)
    createTitleBlock(row, opts.Name or "Dropdown", opts.Description)

    local btn = new("TextButton", {
        Size = UDim2.new(0, 160, 0, 34),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Input,
        Text = selected,
        TextColor3 = Theme.Text,
        Font = Theme.Font,
        TextSize = 12,
        AutoButtonColor = false,
    }, row)
    corner(btn, UDim.new(0, 6))
    stroke(btn)

    local list = new("ScrollingFrame", {
        Size = UDim2.new(0, 160, 0, 0),
        Position = UDim2.new(1, 0, 0, 36),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    }, row)
    corner(list, UDim.new(0, 6))
    stroke(list)
    local listLayout = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    }, list)

    local api = {}
    function api:Set(v)
        selected = v
        btn.Text = v
        if opts.Callback then task.spawn(opts.Callback, v) end
    end
    function api:Get() return selected end
    function api:Refresh(newOptions)
        options = newOptions or options
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, opt in ipairs(options) do
            local item = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = Theme.Input,
                Text = "  " .. tostring(opt),
                TextColor3 = Theme.Text,
                Font = Theme.Font,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                LayoutOrder = i,
            }, list)
            item.MouseEnter:Connect(function() item.BackgroundColor3 = Theme.ButtonHover end)
            item.MouseLeave:Connect(function() item.BackgroundColor3 = Theme.Input end)
            item.MouseButton1Click:Connect(function()
                api:Set(opt)
                open = false
                list.Visible = false
                list.Size = UDim2.new(0, 160, 0, 0)
            end)
        end
        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() end)
        list.CanvasSize = UDim2.new(0, 0, 0, #options * 28)
    end

    api:Refresh(options)

    btn.MouseButton1Click:Connect(function()
        open = not open
        list.Visible = open
        list.Size = open and UDim2.new(0, 160, 0, math.min(#options * 28, 140)) or UDim2.new(0, 160, 0, 0)
    end)

    if opts.Flag then self.Window.Flags[opts.Flag] = api end
    return api
end

-- TEXTBOX ----------------------------------------------------------------
function Window.CreateTextbox(self, opts)
    opts = opts or {}
    local row = createRow(self.Page, 58)
    row.LayoutOrder = #self.Elements + 1
    table.insert(self.Elements, row)
    createTitleBlock(row, opts.Name or "Campo", opts.Description)

    local box = new("TextBox", {
        Size = UDim2.new(0, 180, 0, 34),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Input,
        Text = opts.Default or "",
        PlaceholderText = opts.Placeholder or "Digite...",
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.Text,
        Font = Theme.Font,
        TextSize = 12,
        ClearTextOnFocus = false,
    }, row)
    corner(box, UDim.new(0, 6))
    stroke(box)
    padding(box, 8)
    box.TextXAlignment = Enum.TextXAlignment.Left

    local api = {}
    function api:Set(v) box.Text = v end
    function api:Get() return box.Text end

    box.FocusLost:Connect(function()
        if opts.Callback then task.spawn(opts.Callback, box.Text) end
    end)

    if opts.Flag then self.Window.Flags[opts.Flag] = api end
    return api
end

-- BUTTON -----------------------------------------------------------------
function Window.CreateButton(self, opts)
    opts = opts or {}
    local row = createRow(self.Page, 58)
    row.LayoutOrder = #self.Elements + 1
    table.insert(self.Elements, row)
    createTitleBlock(row, opts.Name or "Botão", opts.Description)

    local btn = new("TextButton", {
        Size = UDim2.new(0, 120, 0, 34),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Button,
        Text = opts.Text or "Executar",
        TextColor3 = Theme.Text,
        Font = Theme.Font,
        TextSize = 12,
        AutoButtonColor = false,
    }, row)
    corner(btn, UDim.new(0, 6))
    stroke(btn)
    btn.MouseEnter:Connect(function() tween(btn, 0.15, { BackgroundColor3 = Theme.ButtonHover }) end)
    btn.MouseLeave:Connect(function() tween(btn, 0.15, { BackgroundColor3 = Theme.Button }) end)
    btn.MouseButton1Click:Connect(function()
        if opts.Callback then task.spawn(opts.Callback) end
    end)
    return btn
end

-- KEYBIND ----------------------------------------------------------------
function Window.CreateKeybind(self, opts)
    opts = opts or {}
    local current = opts.Default or Enum.KeyCode.Insert
    local row = createRow(self.Page, 58)
    row.LayoutOrder = #self.Elements + 1
    table.insert(self.Elements, row)
    createTitleBlock(row, opts.Name or "Atalho", opts.Description)

    local btn = new("TextButton", {
        Size = UDim2.new(0, 100, 0, 34),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Button,
        Text = current.Name,
        TextColor3 = Theme.Text,
        Font = Theme.Font,
        TextSize = 12,
        AutoButtonColor = false,
    }, row)
    corner(btn, UDim.new(0, 6))
    stroke(btn)

    local listening = false
    local api = {}
    function api:Set(key)
        current = key
        btn.Text = key.Name
        if opts.Callback then task.spawn(opts.Callback, key) end
    end
    function api:Get() return current end

    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
    end)
    UserInputService.InputBegan:Connect(function(input, processed)
        if not listening then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            api:Set(input.KeyCode)
        end
    end)
    if opts.Flag then self.Window.Flags[opts.Flag] = api end
    return api
end

-- COLORPICKER ------------------------------------------------------------
function Window.CreateColorPicker(self, opts)
    opts = opts or {}
    local color = opts.Default or Color3.fromRGB(0xdd, 0xdd, 0xdd)
    local row = createRow(self.Page, 58)
    row.LayoutOrder = #self.Elements + 1
    table.insert(self.Elements, row)
    createTitleBlock(row, opts.Name or "Cor", opts.Description)

    local swatch = new("TextButton", {
        Size = UDim2.fromOffset(60, 30),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = color,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(swatch, UDim.new(0, 5))
    stroke(swatch)

    local frame = new("Frame", {
        Size = UDim2.new(0, 220, 0, 130),
        Position = UDim2.new(1, 0, 0, 36),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,
    }, row)
    corner(frame, UDim.new(0, 6))
    stroke(frame)
    padding(frame, 10)

    local h = color:ToHSV()
    local function mkSlider(y, label, max)
        local lbl = new("TextLabel", {
            Size = UDim2.new(0, 60, 0, 16),
            Position = UDim2.new(0, 0, 0, y),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Theme.TextDim,
            Font = Theme.Font,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, frame)
        local bar = new("Frame", {
            Size = UDim2.new(1, -70, 0, 5),
            Position = UDim2.new(0, 70, 0, y + 6),
            BackgroundColor3 = Theme.ToggleOff,
            BorderSizePixel = 0,
        }, frame)
        corner(bar, UDim.new(1, 0))
        local fill = new("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(0xcf, 0xcf, 0xcf),
            BorderSizePixel = 0,
        }, bar)
        corner(fill, UDim.new(1, 0))
        return bar, fill
    end
    local hBar, hFill = mkSlider(0, "Matiz", 360)
    local sBar, sFill = mkSlider(26, "Sat", 1)
    local vBar, vFill = mkSlider(52, "Val", 1)

    local function refresh()
        local hh, ss, vv = color:ToHSV()
        hFill.Size = UDim2.new(hh, 0, 1, 0)
        sFill.Size = UDim2.new(ss, 0, 1, 0)
        vFill.Size = UDim2.new(vv, 0, 1, 0)
        swatch.BackgroundColor3 = color
        if opts.Callback then task.spawn(opts.Callback, color) end
    end

    local function bind(bar, setter)
        local dragging = false
        local function upd(x)
            local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            setter(rel)
            refresh()
        end
        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; upd(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then upd(input.Position.X) end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
    end
    bind(hBar, function(f) local hh, ss, vv = color:ToHSV(); color = Color3.fromHSV(f, ss, vv) end)
    bind(sBar, function(f) local hh, ss, vv = color:ToHSV(); color = Color3.fromHSV(hh, f, vv) end)
    bind(vBar, function(f) local hh, ss, vv = color:ToHSV(); color = Color3.fromHSV(hh, ss, f) end)

    swatch.MouseButton1Click:Connect(function() frame.Visible = not frame.Visible end)

    local api = {}
    function api:Set(c) color = c; refresh() end
    function api:Get() return color end
    refresh()
    if opts.Flag then self.Window.Flags[opts.Flag] = api end
    return api
end

-- ============================================================================
-- NOTIFICATION (toast)
-- ============================================================================
local notifGui
local function ensureNotifGui()
    if notifGui and notifGui.Parent then return notifGui end
    notifGui = new("ScreenGui", {
        Name = "DepHubUI_Notify",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, safeParent())
    local holder = new("Frame", {
        Name = "Holder",
        Size = UDim2.new(0, 300, 1, -40),
        Position = UDim2.new(1, -20, 0, 20),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
    }, notifGui)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 8),
    }, holder)
    notifGui:SetAttribute("Holder", holder)
    return notifGui
end

function Lib:Notify(opts)
    if type(opts) == "string" then opts = { Title = opts } end
    opts = opts or {}
    local gui = ensureNotifGui()
    local holder = gui:FindFirstChild("Holder")
    local duration = opts.Duration or 4

    local toast = new("Frame", {
        Size = UDim2.new(0, 280, 0, 62),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    }, holder)
    corner(toast, UDim.new(0, 8))
    stroke(toast)

    new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 12, 0, 10),
        BackgroundTransparency = 1,
        Text = opts.Title or "DepHub",
        TextColor3 = Theme.TextBright,
        Font = Theme.FontBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, toast)
    new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 12, 0, 30),
        BackgroundTransparency = 1,
        Text = opts.Content or opts.Message or "",
        TextColor3 = Theme.TextDim,
        Font = Theme.Font,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, toast)

    toast.Position = UDim2.new(1, 40, 0, 0)
    tween(toast, 0.25, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0 })
    task.delay(duration, function()
        local t = tween(toast, 0.25, { Position = UDim2.new(1, 40, 0, 0), BackgroundTransparency = 1 })
        t.Completed:Connect(function() toast:Destroy() end)
    end)
end

-- ============================================================================
-- MODAL (dialog de confirmação)
-- ============================================================================
function Lib:Dialog(opts)
    opts = opts or {}
    local gui = new("ScreenGui", {
        Name = "DepHubUI_Dialog",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, safeParent())

    local overlay = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        Text = "",
        AutoButtonColor = false,
    }, gui)

    local box = new("Frame", {
        Size = UDim2.fromOffset(360, 180),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    }, gui)
    corner(box, UDim.new(0, 10))
    stroke(box)
    padding(box, 20)

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = opts.Title or "Confirmar ação?",
        TextColor3 = Theme.TextBright,
        Font = Theme.FontBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, box)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(0, 0, 0, 32),
        BackgroundTransparency = 1,
        Text = opts.Content or "Este é um placeholder de confirmação.",
        TextColor3 = Theme.Text,
        Font = Theme.Font,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, box)

    local function mkBtn(text, x, primary)
        local b = new("TextButton", {
            Size = UDim2.new(0, 110, 0, 36),
            Position = UDim2.new(1, x, 1, 0),
            AnchorPoint = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = primary and Theme.Accent or Theme.Button,
            Text = text,
            TextColor3 = primary and Color3.fromRGB(0x2b, 0x2b, 0x2b) or Theme.Text,
            Font = Theme.Font,
            TextSize = 12,
            AutoButtonColor = false,
        }, box)
        corner(b, UDim.new(0, 7))
        if not primary then stroke(b) end
        return b
    end

    local cancel = mkBtn(opts.CancelText or "Cancelar", -120, false)
    local confirm = mkBtn(opts.ConfirmText or "Confirmar", 0, true)

    local function close()
        tween(box, 0.15, { BackgroundTransparency = 1 })
        gui:Destroy()
    end

    cancel.MouseButton1Click:Connect(function()
        close()
        if opts.OnCancel then task.spawn(opts.OnCancel) end
    end)
    confirm.MouseButton1Click:Connect(function()
        close()
        if opts.OnConfirm then task.spawn(opts.OnConfirm) end
    end)

    return { Close = close }
end

-- ============================================================================
-- API GLOBAL DE FLAGS
-- ============================================================================
function Lib:GetFlag(name)
    for _, win in pairs(Lib._windows or {}) do
        if win.Flags[name] then return win.Flags[name] end
    end
    return nil
end

Lib._windows = Lib._windows or {}
local _origCreateWindow = Lib.CreateWindow
function Lib:CreateWindow(opts)
    local win = _origCreateWindow(self, opts)
    table.insert(Lib._windows, win)
    return win
end

-- ============================================================================
-- CLEANUP
-- ============================================================================
function Lib:Unload()
    for _, win in pairs(Lib._windows or {}) do
        if win.Gui then win.Gui:Destroy() end
    end
    if notifGui then notifGui:Destroy() end
    Lib._windows = {}
end

return Lib
