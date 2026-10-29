--[[
    DepHub UI Library
    API pública preservada:
      DepHub.new(config) -> window
      window:CreateTab(name) -> tab
      tab:CreateSection(name, {Enabled = bool, Callback = fn}) -> section
      section:CreateToggle / CreateCheckbox / CreateDropdown / CreateButton
      section:CreateColorPicker / CreateSlider / CreateInput / CreateParagraph / CreateLabel
      item:Set(value), item:SetAvailableState(bool)
      window:Notify(title, message, duration), window:Destroy(), window.Flags
      tab:SetVisible(bool), window.SetVisible(bool)
]]

local DepHub = {}
DepHub.__index = DepHub

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local THEME = {
    Surface0 = Color3.fromRGB(8, 8, 11),
    Surface1 = Color3.fromRGB(14, 14, 19),
    Surface2 = Color3.fromRGB(22, 22, 30),
    Surface3 = Color3.fromRGB(32, 32, 44),
    Border = Color3.fromRGB(36, 36, 50),
    Text = Color3.fromRGB(236, 238, 244),
    TextMuted = Color3.fromRGB(140, 146, 165),
    TextDim = Color3.fromRGB(92, 98, 118),
    Accent = Color3.fromRGB(132, 112, 255),
    AccentAlt = Color3.fromRGB(88, 101, 242),
    AccentSoft = Color3.fromRGB(34, 28, 62),
    Track = Color3.fromRGB(40, 40, 54),
    Knob = Color3.fromRGB(255, 255, 255),
}

local RADIUS = {Window = 16, Card = 12, Control = 8, Small = 6, Pill = 99}
local FONT = {
    Regular = Enum.Font.Gotham,
    Medium = Enum.Font.GothamMedium,
    Semibold = Enum.Font.GothamSemibold,
    Bold = Enum.Font.GothamBold,
}

local TWEEN_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_TOGGLE = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local ROW_HEIGHT = 34
local CONTROL_WIDTH = 116
local TOAST_STEP = 84

local tweenRegistry = setmetatable({}, {__mode = "k"})

local function tween(object, info, goal)
    if not object or not object.Parent then
        return nil
    end
    local list = tweenRegistry[object]
    if not list then
        list = {}
        tweenRegistry[object] = list
    end
    for i = #list, 1, -1 do
        local entry = list[i]
        for key in pairs(goal) do
            if entry.keys[key] then
                entry.tween:Cancel()
                table.remove(list, i)
                break
            end
        end
    end
    local t = TweenService:Create(object, info, goal)
    local keys = {}
    for key in pairs(goal) do
        keys[key] = true
    end
    local entry = {tween = t, keys = keys}
    table.insert(list, entry)
    t.Completed:Once(function()
        for i = #list, 1, -1 do
            if list[i] == entry then
                table.remove(list, i)
            end
        end
    end)
    t:Play()
    return t
end

local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function corner(parent, radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius or RADIUS.Control)}, parent)
end

local function stroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or THEME.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

local function listLayout(parent, gap, direction)
    return create("UIListLayout", {
        Padding = UDim.new(0, gap or 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = direction or Enum.FillDirection.Vertical,
    }, parent)
end

local function label(parent, props)
    local base = {
        BackgroundTransparency = 1,
        Font = FONT.Regular,
        TextSize = 12,
        TextColor3 = THEME.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }
    for key, value in pairs(props or {}) do
        base[key] = value
    end
    return create("TextLabel", base, parent)
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function inside(object, point)
    if not object or not object.Parent or not object.Visible then
        return false
    end
    local p = object.AbsolutePosition
    local s = object.AbsoluteSize
    return point.X >= p.X and point.X <= p.X + s.X and point.Y >= p.Y and point.Y <= p.Y + s.Y
end

local function viewportSize()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function makeButton(parent, text, size, style)
    local baseSize = size or UDim2.new(1, 0, 0, 30)
    local baseColor = style and style.Background or THEME.Surface2
    local hoverColor = style and style.Hover or THEME.Surface3
    local button = create("TextButton", {
        AutoButtonColor = false,
        Text = text or "",
        Font = FONT.Medium,
        TextSize = 12,
        TextColor3 = THEME.Text,
        BackgroundColor3 = baseColor,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = baseSize,
    }, parent)
    corner(button, RADIUS.Control)

    button.MouseEnter:Connect(function()
        if button.Active then
            tween(button, TWEEN_FAST, {BackgroundColor3 = hoverColor})
        end
    end)
    button.MouseLeave:Connect(function()
        tween(button, TWEEN_FAST, {BackgroundColor3 = baseColor, Size = baseSize})
    end)
    button.MouseButton1Down:Connect(function()
        if button.Active then
            tween(button, TWEEN_FAST, {Size = baseSize - UDim2.fromOffset(2, 2)})
        end
    end)
    button.MouseButton1Up:Connect(function()
        tween(button, TWEEN_FAST, {Size = baseSize})
    end)

    return button, baseColor
end

function DepHub.new(config)
    config = config or {}
    local self = setmetatable({}, DepHub)
    self.Name = config.Name or "DepHub"
    self.ToggleKeyCode = config.ToggleKeyCode or Enum.KeyCode.Insert
    self.Tabs = {}
    self.Flags = {}
    self.Connections = {}
    self.Toasts = {}
    self.Popups = {}
    self.Destroyed = false
    self.SelectedTab = nil
    self.Drag = nil

    local player = Players.LocalPlayer
    local parent = config.Parent
    if not parent then
        parent = player:WaitForChild("PlayerGui")
        if type(gethui) == "function" then
            local ok, result = pcall(gethui)
            if ok and typeof(result) == "Instance" then
                parent = result
            end
        end
    end

    local guiName = config.GuiName or ("DepHub_" .. tostring(math.random(100000, 999999)))
    local old = parent:FindFirstChild(guiName)
    if old then
        old:Destroy()
    end

    local gui = create("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = config.DisplayOrder or 1000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)
    self.Gui = gui

    local main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = config.Size or UDim2.fromOffset(780, 500),
        BackgroundColor3 = THEME.Surface0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, gui)
    corner(main, RADIUS.Window)
    stroke(main, THEME.Border, 1, 0.2)
    self.Main = main

    local mainScale = create("UIScale", {Scale = 1}, main)

    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 168, 1, 0),
        BackgroundColor3 = THEME.Surface1,
        BorderSizePixel = 0,
    }, main)

    local sidebarHandle = create("Frame", {
        Name = "SidebarDragHandle",
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        Active = true,
    }, sidebar)

    label(sidebar, {
        Name = "Brand",
        Position = UDim2.fromOffset(16, 14),
        Size = UDim2.new(1, -32, 0, 30),
        RichText = true,
        Text = '<font color="#FFFFFF">Dep</font><font color="#A78BFA">Hub</font>',
        Font = FONT.Bold,
        TextSize = 17,
    })

    local nav = create("ScrollingFrame", {
        Name = "Navigation",
        Position = UDim2.fromOffset(0, 56),
        Size = UDim2.new(1, 0, 1, -56),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = THEME.Track,
    }, sidebar)
    padding(nav, 10, 10, 4, 8)
    listLayout(nav, 4)

    create("Frame", {
        Name = "Divider",
        Position = UDim2.new(0, 168, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = THEME.Border,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, main)

    local body = create("Frame", {
        Name = "Body",
        Position = UDim2.new(0, 169, 0, 0),
        Size = UDim2.new(1, -169, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, main)

    local headerHandle = create("Frame", {
        Name = "HeaderDragHandle",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        Active = true,
    }, body)

    local tabbar = create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(1, -56, 0, 46),
        BackgroundTransparency = 1,
    }, body)
    padding(tabbar, 16, 0, 0, 0)
    local tabLayout = listLayout(tabbar, 4, Enum.FillDirection.Horizontal)
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    create("Frame", {
        Name = "HeaderDivider",
        Position = UDim2.new(0, 0, 0, 46),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = THEME.Border,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, body)

    local content = create("ScrollingFrame", {
        Name = "Content",
        Position = UDim2.new(0, 0, 0, 47),
        Size = UDim2.new(1, 0, 1, -79),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.Track,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, body)
    padding(content, 16, 16, 14, 16)
    self.Content = content

    local footer = create("Frame", {
        Name = "Footer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
    }, body)
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = THEME.Border,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, footer)
    label(footer, {
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(0.6, -16, 1, 0),
        Text = config.FooterLeft or "DepHub UI Library",
        TextSize = 11,
        TextColor3 = THEME.TextDim,
    })
    label(footer, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 0),
        Size = UDim2.new(0.4, 0, 1, 0),
        Text = self.Name,
        Font = FONT.Bold,
        TextSize = 11,
        TextColor3 = THEME.Accent,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local closeButton = makeButton(body, "×", UDim2.fromOffset(26, 26), {
        Background = THEME.Surface1,
        Hover = THEME.Surface3,
    })
    closeButton.Name = "CloseButton"
    closeButton.AnchorPoint = Vector2.new(1, 0)
    closeButton.Position = UDim2.new(1, -12, 0, 10)
    closeButton.TextSize = 18
    closeButton.Font = FONT.Bold

    local floating = makeButton(gui, "D", UDim2.fromOffset(42, 42), {
        Background = THEME.AccentAlt,
        Hover = THEME.Accent,
    })
    floating.Name = "Floating"
    floating.AnchorPoint = Vector2.new(1, 1)
    floating.Position = UDim2.new(1, -18, 1, -18)
    floating.Visible = false
    floating.TextSize = 18
    floating.Font = FONT.Bold
    corner(floating, RADIUS.Pill)

    -- Camada própria para popups (dropdown e color picker), desenhada acima de tudo
    local overlay = create("Frame", {
        Name = "Overlay",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Active = false,
        ZIndex = 50,
    }, gui)
    self.Overlay = overlay

    -- Popups ----------------------------------------------------------------
    local function closeAllPopups(except)
        for _, entry in ipairs(self.Popups) do
            if entry ~= except and entry.frame.Visible then
                entry.close()
            end
        end
    end

    function self:_createPopup(anchor, width, height)
        local frame = create("Frame", {
            Visible = false,
            Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = THEME.Surface0,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 60,
        }, overlay)
        corner(frame, RADIUS.Control)
        stroke(frame, THEME.Border, 1, 0.1)

        local entry = {frame = frame, anchor = anchor, onClose = nil}

        function entry.open(openWidth, openHeight)
            if not anchor or not anchor.Parent or self.Destroyed then
                return
            end
            closeAllPopups(entry)
            local w = openWidth or width
            local h = openHeight or height
            local a = anchor.AbsolutePosition
            local s = anchor.AbsoluteSize
            local vp = viewportSize()
            local left = math.clamp(a.X, 4, math.max(vp.X - w - 4, 4))
            local top = a.Y + s.Y + 4
            if top + h > vp.Y - 4 and a.Y - h - 4 >= 0 then
                top = a.Y - h - 4
            end
            top = math.clamp(top, 4, math.max(vp.Y - h - 4, 4))
            frame.Size = UDim2.fromOffset(w, h)
            frame.Position = UDim2.fromOffset(left, top)
            frame.Visible = true
        end

        function entry.close()
            if frame.Visible then
                frame.Visible = false
                if entry.onClose then
                    entry.onClose()
                end
            end
        end

        table.insert(self.Popups, entry)
        return entry
    end

    -- Arraste ---------------------------------------------------------------
    local function startDrag(owner, kind, position, onMove)
        self.Drag = {owner = owner, kind = kind, last = position, onMove = onMove}
        onMove(position)
    end

    local function cancelDrag(owner)
        if self.Drag and self.Drag.owner == owner then
            self.Drag = nil
        end
    end
    self._startDrag = startDrag
    self._cancelDrag = cancelDrag

    local function vec(input)
        return Vector2.new(input.Position.X, input.Position.Y)
    end

    local windowDragOrigin = nil
    local windowDragPointer = nil

    local function moveWindow(pointer)
        local size = main.AbsoluteSize
        local delta = pointer - windowDragPointer
        local left = windowDragOrigin.X + delta.X
        local top = windowDragOrigin.Y + delta.Y
        local vp = viewportSize()
        left = math.clamp(left, 0, math.max(vp.X - size.X, 0))
        top = math.clamp(top, 0, math.max(vp.Y - size.Y, 0))
        main.AnchorPoint = Vector2.new(0, 0)
        main.Position = UDim2.fromOffset(left, top)
    end

    local function beginWindowDrag(input)
        if not main.Visible then
            return
        end
        windowDragPointer = vec(input)
        windowDragOrigin = main.AbsolutePosition
        self._closeAllPopups = closeAllPopups
        closeAllPopups(nil)
        startDrag("window", input.UserInputType == Enum.UserInputType.Touch and "touch" or "mouse", vec(input), function(pos)
            moveWindow(pos)
        end)
    end

    headerHandle.InputBegan:Connect(function(input)
        if isPress(input) then
            beginWindowDrag(input)
        end
    end)
    sidebarHandle.InputBegan:Connect(function(input)
        if isPress(input) then
            beginWindowDrag(input)
        end
    end)

    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if isPress(input) then
            local pos = vec(input)
            for _, entry in ipairs(self.Popups) do
                if entry.frame.Visible and not inside(entry.frame, pos) and not inside(entry.anchor, pos) then
                    entry.close()
                end
            end
        elseif input.UserInputType == Enum.UserInputType.Keyboard and not gameProcessed then
            if input.KeyCode == self.ToggleKeyCode then
                self.SetVisible(not self.IsVisible())
            end
        end
    end))

    table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
        local drag = self.Drag
        if not drag or not isMove(input) then
            return
        end
        local pos = vec(input)
        if drag.kind == "mouse" and input.UserInputType == Enum.UserInputType.MouseMovement then
            drag.last = pos
            drag.onMove(pos)
        elseif drag.kind == "touch" and input.UserInputType == Enum.UserInputType.Touch and self.TouchCount == 1 then
            drag.last = pos
            drag.onMove(pos)
        end
    end))

    table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
        local drag = self.Drag
        if not drag or not isPress(input) then
            return
        end
        if drag.kind == "mouse" and input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.Drag = nil
        end
    end))

    self.TouchCount = 0
    table.insert(self.Connections, UserInputService.TouchStarted:Connect(function()
        self.TouchCount += 1
    end))
    table.insert(self.Connections, UserInputService.TouchEnded:Connect(function()
        self.TouchCount = math.max(self.TouchCount - 1, 0)
        local drag = self.Drag
        if drag and drag.kind == "touch" and self.TouchCount == 0 then
            self.Drag = nil
        end
    end))

    -- Visibilidade ----------------------------------------------------------
    local visible = true

    local function setVisible(value)
        value = value == true
        if value == visible or self.Destroyed then
            return
        end
        visible = value
        if value then
            main.Visible = true
            floating.Visible = false
            mainScale.Scale = 0.94
            tween(mainScale, TWEEN_MED, {Scale = 1})
        else
            floating.Visible = true
            closeAllPopups(nil)
            if self.Drag and self.Drag.owner == "window" then
                self.Drag = nil
            end
            local t = tween(mainScale, TWEEN_FAST, {Scale = 0.94})
            if t then
                t.Completed:Once(function()
                    if not visible and main.Parent then
                        main.Visible = false
                    end
                end)
            else
                main.Visible = false
            end
        end
    end

    closeButton.Activated:Connect(function()
        setVisible(false)
    end)
    floating.Activated:Connect(function()
        setVisible(true)
    end)

    self.SetVisible = setVisible
    self.IsVisible = function()
        return visible
    end

    -- Abas --------------------------------------------------------------------
    function self:CreateTab(tabName)
        tabName = tostring(tabName or "Tab")
        local tab = {Name = tabName, Sections = {}, Visible = true, ParentWindow = self}
        local tabIndex = #self.Tabs + 1

        local navButton = makeButton(nav, "   " .. tabName, UDim2.new(1, 0, 0, 34), {
            Background = THEME.Surface1,
            Hover = THEME.Surface2,
        })
        navButton.LayoutOrder = tabIndex
        navButton.TextXAlignment = Enum.TextXAlignment.Left
        navButton.Font = FONT.Medium
        navButton.TextColor3 = THEME.TextMuted
        padding(navButton, 12, 8, 0, 0)

        local navIndicator = create("Frame", {
            Name = "Indicator",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(3, 0),
            BackgroundColor3 = THEME.Accent,
            BorderSizePixel = 0,
        }, navButton)
        corner(navIndicator, RADIUS.Pill)

        local tabButton = makeButton(tabbar, tabName, UDim2.fromOffset(math.max(72, #tabName * 8 + 28), 32), {
            Background = THEME.Surface0,
            Hover = THEME.Surface2,
        })
        tabButton.LayoutOrder = tabIndex
        tabButton.BackgroundTransparency = 1
        tabButton.TextColor3 = THEME.TextMuted
        tabButton.Font = FONT.Semibold
        tabButton.TextSize = 12

        local tabPill = create("Frame", {
            Name = "Pill",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = THEME.AccentSoft,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 0,
        }, tabButton)
        corner(tabPill, RADIUS.Control)

        local page = create("Frame", {
            Name = tabName .. "Page",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = false,
            LayoutOrder = tabIndex,
        }, content)
        listLayout(page, 10)

        local cardCounter = 0

        tab.Page = page
        tab.TabButton = tabButton
        tab.NavButton = navButton

        local function applyStyle(selected)
            local color = selected and THEME.Text or THEME.TextMuted
            tween(tabButton, TWEEN_MED, {TextColor3 = color})
            tween(navButton, TWEEN_MED, {TextColor3 = color, BackgroundColor3 = selected and THEME.AccentSoft or THEME.Surface1})
            tween(navIndicator, TWEEN_TOGGLE, {Size = selected and UDim2.fromOffset(3, 16) or UDim2.fromOffset(3, 0)})
            tween(tabPill, TWEEN_MED, {BackgroundTransparency = selected and 0 or 1})
        end

        local function selectTab()
            if not tab.Visible or self.SelectedTab == tab or self.Destroyed then
                return
            end
            closeAllPopups(nil)
            for _, other in ipairs(self.Tabs) do
                if other ~= tab then
                    other.Page.Visible = false
                    other.ApplyStyle(false)
                end
            end
            page.Visible = true
            page.Position = UDim2.fromOffset(14, 0)
            tween(page, TWEEN_SLOW, {Position = UDim2.new()})
            applyStyle(true)
            self.SelectedTab = tab
            content.CanvasPosition = Vector2.zero
        end

        tab.ApplyStyle = applyStyle
        tab.Select = selectTab

        function tab:SetVisible(value)
            value = value == true
            self.Visible = value
            navButton.Visible = value
            tabButton.Visible = value
            if not value and self.ParentWindow.SelectedTab == self then
                closeAllPopups(nil)
                self.Page.Visible = false
                self.ParentWindow.SelectedTab = nil
                for _, other in ipairs(self.ParentWindow.Tabs) do
                    if other ~= self and other.Visible ~= false then
                        other.Select()
                        break
                    end
                end
            end
        end

        tabButton.Activated:Connect(selectTab)
        navButton.Activated:Connect(selectTab)

        table.insert(self.Tabs, tab)
        if #self.Tabs == 1 then
            selectTab()
        end

        -- Seções ----------------------------------------------------------------
        function tab:CreateSection(sectionName, sectionConfig)
            sectionConfig = sectionConfig or {}
            local window = self.ParentWindow
            cardCounter += 1
            local section = {
                Name = sectionName,
                Items = {},
                Enabled = sectionConfig.Enabled ~= false,
                ParentWindow = window,
            }

            local card = create("Frame", {
                Name = tostring(sectionName),
                BackgroundColor3 = THEME.Surface1,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 80),
                LayoutOrder = cardCounter,
            }, page)
            corner(card, RADIUS.Card)
            stroke(card, THEME.Border, 1, 0.25)

            local header = create("Frame", {
                Size = UDim2.new(1, 0, 0, 42),
                BackgroundTransparency = 1,
            }, card)

            local dot = create("Frame", {
                Position = UDim2.fromOffset(14, 17),
                Size = UDim2.fromOffset(8, 8),
                BackgroundColor3 = THEME.Accent,
                BorderSizePixel = 0,
            }, header)
            corner(dot, RADIUS.Pill)
            create("UIGradient", {Color = ColorSequence.new(THEME.Accent, THEME.AccentAlt), Rotation = 45}, dot)

            label(header, {
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -92, 1, 0),
                Text = tostring(sectionName),
                Font = FONT.Semibold,
                TextSize = 13,
            })

            local master = makeButton(header, "", UDim2.fromOffset(34, 18), {
                Background = THEME.Track,
                Hover = THEME.Track,
            })
            master.AnchorPoint = Vector2.new(1, 0.5)
            master.Position = UDim2.new(1, -12, 0.5, 0)
            corner(master, RADIUS.Pill)

            local knob = create("Frame", {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(0, 2, 0.5, -7),
                BackgroundColor3 = THEME.Knob,
                BorderSizePixel = 0,
            }, master)
            corner(knob, RADIUS.Pill)

            local inner = create("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 42),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            }, card)
            padding(inner, 14, 14, 0, 12)
            local innerLayout = listLayout(inner, 4)
            local rowCounter = 0

            innerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                card.Size = UDim2.new(1, 0, 0, innerLayout.AbsoluteContentSize.Y + 54)
            end)

            local function nextOrder()
                rowCounter += 1
                return rowCounter
            end

            local function renderMaster(animate)
                local on = section.Enabled
                local goalKnob = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
                local goalColor = on and THEME.Accent or THEME.Track
                if animate then
                    tween(knob, TWEEN_TOGGLE, {Position = goalKnob})
                    tween(master, TWEEN_FAST, {BackgroundColor3 = goalColor})
                else
                    knob.Position = goalKnob
                    master.BackgroundColor3 = goalColor
                end
            end

            -- Disponibilidade manual do item é independente da seção; efetivo = manual e seção ativa
            local function registerItem(name, applyState, onDisable)
                local item = {Name = name, Available = true}
                function item:IsEnabled()
                    return self.Available and section.Enabled and not window.Destroyed
                end
                function item.Refresh()
                    local enabled = item:IsEnabled()
                    if not enabled and onDisable then
                        onDisable()
                    end
                    applyState(enabled)
                end
                function item:SetAvailableState(value)
                    self.Available = value == true
                    item.Refresh()
                end
                table.insert(section.Items, item)
                return item
            end

            master.Activated:Connect(function()
                section.Enabled = not section.Enabled
                renderMaster(true)
                for _, item in ipairs(section.Items) do
                    item.Refresh()
                end
                if sectionConfig.Callback then
                    task.spawn(sectionConfig.Callback, section.Enabled)
                end
            end)
            renderMaster(false)

            local function addRow(name, height)
                height = height or ROW_HEIGHT
                local row = create("Frame", {
                    Name = tostring(name),
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, height),
                    LayoutOrder = nextOrder(),
                }, inner)
                label(row, {
                    Size = UDim2.new(1, -CONTROL_WIDTH - 10, 1, 0),
                    Text = tostring(name),
                    TextSize = 12,
                })
                local controls = create("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(CONTROL_WIDTH, height),
                    BackgroundTransparency = 1,
                }, row)
                return row, controls
            end

            -- Toggle ----------------------------------------------------------------
            function section:CreateToggle(name, default, callback)
                local _, controls = addRow(name)
                local value = default == true

                local track = makeButton(controls, "", UDim2.fromOffset(34, 18), {
                    Background = THEME.Track,
                    Hover = THEME.Surface3,
                })
                track.AnchorPoint = Vector2.new(1, 0.5)
                track.Position = UDim2.new(1, 0, 0.5, 0)
                corner(track, RADIUS.Pill)

                local thumb = create("Frame", {
                    Size = UDim2.fromOffset(14, 14),
                    Position = UDim2.new(0, 2, 0.5, -7),
                    BackgroundColor3 = THEME.Knob,
                    BorderSizePixel = 0,
                }, track)
                corner(thumb, RADIUS.Pill)

                local item
                local function render(animate)
                    local goalPos = value and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
                    local goalColor = value and THEME.Accent or THEME.Track
                    if animate then
                        tween(thumb, TWEEN_TOGGLE, {Position = goalPos})
                        tween(track, TWEEN_FAST, {BackgroundColor3 = goalColor})
                    else
                        thumb.Position = goalPos
                        track.BackgroundColor3 = goalColor
                    end
                    window.Flags[item.FlagName or name] = value
                end

                item = registerItem(name, function(enabled)
                    track.Active = enabled
                    track.BackgroundTransparency = enabled and 0 or 0.5
                    thumb.BackgroundTransparency = enabled and 0 or 0.4
                end)

                function item:Set(nextValue)
                    local newValue = nextValue == true
                    if newValue == value then
                        return
                    end
                    value = newValue
                    render(true)
                    if callback then
                        task.spawn(callback, value)
                    end
                end

                track.Activated:Connect(function()
                    if item:IsEnabled() then
                        item:Set(not value)
                    end
                end)

                item.Refresh()
                render(false)
                return item
            end

            -- Checkbox --------------------------------------------------------------
            function section:CreateCheckbox(name, default, callback)
                local _, controls = addRow(name)
                local value = default == true

                local box = makeButton(controls, "", UDim2.fromOffset(18, 18), {
                    Background = THEME.Surface2,
                    Hover = THEME.Surface3,
                })
                box.AnchorPoint = Vector2.new(1, 0.5)
                box.Position = UDim2.new(1, 0, 0.5, 0)
                box.TextSize = 13
                box.Font = FONT.Bold
                box.TextColor3 = THEME.Knob
                corner(box, RADIUS.Small)
                stroke(box, THEME.Border, 1, 0)

                local item
                local function render(animate)
                    box.Text = value and "✓" or ""
                    local goalColor = value and THEME.Accent or THEME.Surface2
                    if animate then
                        tween(box, TWEEN_FAST, {BackgroundColor3 = goalColor})
                    else
                        box.BackgroundColor3 = goalColor
                    end
                    window.Flags[item.FlagName or name] = value
                end

                item = registerItem(name, function(enabled)
                    box.Active = enabled
                    box.BackgroundTransparency = enabled and 0 or 0.5
                end)

                function item:Set(nextValue)
                    local newValue = nextValue == true
                    if newValue == value then
                        return
                    end
                    value = newValue
                    render(true)
                    if callback then
                        task.spawn(callback, value)
                    end
                end

                box.Activated:Connect(function()
                    if item:IsEnabled() then
                        item:Set(not value)
                    end
                end)

                item.Refresh()
                render(false)
                return item
            end

            -- Dropdown --------------------------------------------------------------
            function section:CreateDropdown(name, options, default, callback)
                options = options or {}
                local _, controls = addRow(name, 36)
                local selected = default or options[1] or "Selecionar"

                local dd = makeButton(controls, "", UDim2.fromOffset(CONTROL_WIDTH, 26), {
                    Background = THEME.Surface2,
                    Hover = THEME.Surface3,
                })
                dd.AnchorPoint = Vector2.new(1, 0.5)
                dd.Position = UDim2.new(1, 0, 0.5, 0)
                dd.TextXAlignment = Enum.TextXAlignment.Left
                dd.Font = FONT.Regular
                dd.TextSize = 11
                padding(dd, 10, 22, 0, 0)
                stroke(dd, THEME.Border, 1, 0.3)

                local chevron = label(dd, {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.fromOffset(12, 12),
                    Text = "▾",
                    TextSize = 11,
                    TextColor3 = THEME.TextMuted,
                    TextXAlignment = Enum.TextXAlignment.Center,
                })

                local rowsShown = math.min(#options, 6)
                local popupHeight = math.max(rowsShown, 1) * 26 + 8
                local popup = window:_createPopup(dd, CONTROL_WIDTH, popupHeight)

                local scroller = create("ScrollingFrame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    CanvasSize = UDim2.new(0, 0, 0, #options * 26),
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = THEME.Track,
                }, popup.frame)
                padding(scroller, 4, 4, 4, 4)
                listLayout(scroller, 0)

                local item
                local function setOpen(open)
                    if open and item:IsEnabled() and #options > 0 then
                        popup.open(CONTROL_WIDTH, popupHeight)
                    else
                        popup.close()
                    end
                    tween(chevron, TWEEN_FAST, {Rotation = popup.frame.Visible and 180 or 0})
                end
                popup.onClose = function()
                    tween(chevron, TWEEN_FAST, {Rotation = 0})
                end

                local function render()
                    dd.Text = "  " .. tostring(selected)
                    window.Flags[item.FlagName or name] = selected
                end

                item = registerItem(name, function(enabled)
                    dd.Active = enabled
                    dd.BackgroundTransparency = enabled and 0 or 0.5
                end, function()
                    popup.close()
                end)

                function item:Set(nextValue)
                    if nextValue == nil then
                        return
                    end
                    selected = nextValue
                    popup.close()
                    render()
                    if callback then
                        task.spawn(callback, selected)
                    end
                end

                for index, option in ipairs(options) do
                    local opt = makeButton(scroller, tostring(option), UDim2.new(1, 0, 0, 26), {
                        Background = THEME.Surface0,
                        Hover = THEME.Surface2,
                    })
                    opt.LayoutOrder = index
                    opt.TextXAlignment = Enum.TextXAlignment.Left
                    opt.TextSize = 11
                    opt.Font = FONT.Regular
                    padding(opt, 8, 8, 0, 0)
                    opt.Activated:Connect(function()
                        if item:IsEnabled() then
                            item:Set(option)
                        end
                    end)
                end

                dd.Activated:Connect(function()
                    setOpen(not popup.frame.Visible)
                end)

                item.Refresh()
                render()
                return item
            end

            -- Botão ------------------------------------------------------------------
            function section:CreateButton(name, callback)
                local _, controls = addRow(name)
                local action = makeButton(controls, tostring(name), UDim2.fromOffset(CONTROL_WIDTH, 26), {
                    Background = THEME.AccentSoft,
                    Hover = THEME.Accent,
                })
                action.AnchorPoint = Vector2.new(1, 0.5)
                action.Position = UDim2.new(1, 0, 0.5, 0)
                action.TextSize = 11
                action.TextTruncate = Enum.TextTruncate.AtEnd

                local item = registerItem(name, function(enabled)
                    action.Active = enabled
                    action.BackgroundTransparency = enabled and 0 or 0.5
                end)

                action.Activated:Connect(function()
                    if item:IsEnabled() and callback then
                        task.spawn(callback)
                    end
                end)

                item.Refresh()
                return item
            end

            -- ColorPicker -----------------------------------------------------------
            function section:CreateColorPicker(name, default, callback)
                local _, controls = addRow(name)
                local color = typeof(default) == "Color3" and default or THEME.Accent
                local hue, saturation, brightness = color:ToHSV()

                local swatch = makeButton(controls, "", UDim2.fromOffset(24, 24), {
                    Background = color,
                    Hover = color,
                })
                swatch.AnchorPoint = Vector2.new(1, 0.5)
                swatch.Position = UDim2.new(1, 0, 0.5, 0)
                corner(swatch, RADIUS.Small)
                stroke(swatch, THEME.Knob, 1, 0.7)

                local POP_W, POP_H = 184, 160
                local popup = window:_createPopup(swatch, POP_W, POP_H)
                padding(popup.frame, 8, 8, 8, 8)

                local hueBar = create("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 12),
                    BackgroundColor3 = THEME.Knob,
                    BorderSizePixel = 0,
                }, popup.frame)
                corner(hueBar, RADIUS.Pill)
                create("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                        ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
                        ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
                        ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
                    }),
                }, hueBar)
                local hueCursor = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(6, 16),
                    BackgroundColor3 = THEME.Knob,
                    BorderSizePixel = 0,
                }, hueBar)
                corner(hueCursor, RADIUS.Pill)
                stroke(hueCursor, THEME.Surface0, 1, 0)

                -- Saturação (x): branco -> matiz. Brilho (y): transparente -> preto.
                local sv = create("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    Position = UDim2.fromOffset(0, 20),
                    Size = UDim2.new(1, 0, 1, -20),
                    BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
                    BorderSizePixel = 0,
                }, popup.frame)
                corner(sv, RADIUS.Small)
                create("UIGradient", {
                    Color = ColorSequence.new(Color3.new(1, 1, 1)),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 1),
                    }),
                    Rotation = 0,
                }, sv)
                local shade = create("Frame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                }, sv)
                corner(shade, RADIUS.Small)
                create("UIGradient", {
                    Color = ColorSequence.new(Color3.new(0, 0, 0)),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0),
                    }),
                    Rotation = 90,
                }, shade)
                local svCursor = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Size = UDim2.fromOffset(10, 10),
                    BackgroundTransparency = 1,
                }, sv)
                corner(svCursor, RADIUS.Pill)
                stroke(svCursor, THEME.Knob, 2, 0)

                local item
                local function refreshCursors()
                    hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
                    svCursor.Position = UDim2.new(saturation, 0, 1 - brightness, 0)
                    sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
                end

                local function refresh(fire)
                    color = Color3.fromHSV(hue, saturation, brightness)
                    swatch.BackgroundColor3 = color
                    refreshCursors()
                    window.Flags[item.FlagName or name] = color
                    if fire and callback then
                        task.spawn(callback, color)
                    end
                end

                local function bindDrag(target, onUpdate)
                    target.InputBegan:Connect(function(input)
                        if isPress(input) and item:IsEnabled() then
                            local kind = input.UserInputType == Enum.UserInputType.Touch and "touch" or "mouse"
                            window._startDrag(item, kind, vec(input), onUpdate)
                        end
                    end)
                end

                bindDrag(hueBar, function(position)
                    hue = math.clamp((position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
                    refresh(true)
                end)
                bindDrag(sv, function(position)
                    saturation = math.clamp((position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
                    brightness = 1 - math.clamp((position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
                    refresh(true)
                end)

                item = registerItem(name, function(enabled)
                    swatch.Active = enabled
                    swatch.BackgroundTransparency = enabled and 0 or 0.5
                end, function()
                    popup.close()
                    window._cancelDrag(item)
                end)

                function item:Set(nextColor)
                    if typeof(nextColor) ~= "Color3" then
                        return
                    end
                    color = nextColor
                    hue, saturation, brightness = color:ToHSV()
                    refresh(true)
                end

                swatch.Activated:Connect(function()
                    if popup.frame.Visible then
                        popup.close()
                    elseif item:IsEnabled() then
                        popup.open(POP_W, POP_H)
                    end
                end)

                item.Refresh()
                refresh(false)
                return item
            end

            -- Slider ----------------------------------------------------------------
            function section:CreateSlider(name, minimum, maximum, default, callback)
                local minValue = tonumber(minimum) or 0
                local maxValue = tonumber(maximum) or 100
                if maxValue < minValue then
                    minValue, maxValue = maxValue, minValue
                end
                local span = maxValue - minValue
                local defaultNumber = tonumber(default)
                local isDecimal = (minValue % 1 ~= 0) or (maxValue % 1 ~= 0) or (defaultNumber ~= nil and defaultNumber % 1 ~= 0)
                local step = isDecimal and 0.01 or 1
                local value = minValue

                local function quantize(n)
                    if span == 0 then
                        return minValue
                    end
                    local q = minValue + math.floor((n - minValue) / step + 0.5) * step
                    return math.clamp(q, minValue, maxValue)
                end

                local function format(n)
                    if step < 1 then
                        return string.format("%.2f", n)
                    end
                    return tostring(math.floor(n + 0.5))
                end

                value = quantize(defaultNumber or minValue)

                local row = create("Frame", {
                    Name = tostring(name),
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 44),
                    LayoutOrder = nextOrder(),
                }, inner)

                label(row, {
                    Size = UDim2.new(1, -56, 0, 18),
                    Text = tostring(name),
                    TextSize = 12,
                })

                local valueLabel = label(row, {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, 0, 0, 0),
                    Size = UDim2.fromOffset(52, 18),
                    Font = FONT.Semibold,
                    TextSize = 11,
                    TextColor3 = THEME.Accent,
                    TextXAlignment = Enum.TextXAlignment.Right,
                })

                local bar = create("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    Position = UDim2.fromOffset(0, 28),
                    Size = UDim2.new(1, 0, 0, 6),
                    BackgroundColor3 = THEME.Track,
                    BorderSizePixel = 0,
                }, row)
                corner(bar, RADIUS.Pill)

                local fill = create("Frame", {
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundColor3 = THEME.Accent,
                    BorderSizePixel = 0,
                }, bar)
                corner(fill, RADIUS.Pill)
                create("UIGradient", {Color = ColorSequence.new(THEME.Accent, THEME.AccentAlt)}, fill)

                local knob = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(12, 12),
                    BackgroundColor3 = THEME.Knob,
                    BorderSizePixel = 0,
                    ZIndex = 2,
                }, bar)
                corner(knob, RADIUS.Pill)

                local item
                local function alphaOf(v)
                    if span == 0 then
                        return 0
                    end
                    return (v - minValue) / span
                end

                local function render(animate, runCallback)
                    valueLabel.Text = format(value)
                    local a = alphaOf(value)
                    local goalFill = UDim2.new(a, 0, 1, 0)
                    local goalKnob = UDim2.new(a, 0, 0.5, 0)
                    if animate then
                        tween(fill, TWEEN_FAST, {Size = goalFill})
                        tween(knob, TWEEN_FAST, {Position = goalKnob})
                    else
                        fill.Size = goalFill
                        knob.Position = goalKnob
                    end
                    window.Flags[item.FlagName or name] = value
                    if runCallback and callback then
                        task.spawn(callback, value)
                    end
                end

                item = registerItem(name, function(enabled)
                    bar.Active = enabled
                    bar.BackgroundTransparency = enabled and 0 or 0.5
                    fill.BackgroundTransparency = enabled and 0 or 0.5
                end, function()
                    window._cancelDrag(item)
                end)

                function item:Set(nextValue)
                    local n = tonumber(nextValue)
                    if not n then
                        return
                    end
                    local newValue = quantize(n)
                    if newValue == value then
                        return
                    end
                    value = newValue
                    render(true, true)
                end

                local function setFromX(x)
                    if not item:IsEnabled() or span == 0 then
                        return
                    end
                    local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
                    local newValue = quantize(minValue + span * alpha)
                    if newValue ~= value then
                        value = newValue
                        render(false, true)
                    end
                end

                bar.InputBegan:Connect(function(input)
                    if isPress(input) and item:IsEnabled() then
                        local kind = input.UserInputType == Enum.UserInputType.Touch and "touch" or "mouse"
                        window._startDrag(item, kind, vec(input), function(pos)
                            setFromX(pos.X)
                        end)
                    end
                end)

                item.Refresh()
                render(false, false)
                return item
            end

            -- Input -----------------------------------------------------------------
            function section:CreateInput(name, placeholder, default, callback)
                local _, controls = addRow(name, 36)
                local value = tostring(default or "")

                local box = create("TextBox", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(CONTROL_WIDTH, 26),
                    BackgroundColor3 = THEME.Surface0,
                    BorderSizePixel = 0,
                    Text = value,
                    PlaceholderText = tostring(placeholder or ""),
                    ClearTextOnFocus = false,
                    Font = FONT.Regular,
                    TextSize = 11,
                    TextColor3 = THEME.Text,
                    PlaceholderColor3 = THEME.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }, controls)
                corner(box, RADIUS.Control)
                local boxStroke = stroke(box, THEME.Border, 1, 0.3)
                padding(box, 8, 8, 0, 0)

                local item = registerItem(name, function(enabled)
                    box.Active = enabled
                    box.TextEditable = enabled
                    box.BackgroundTransparency = enabled and 0 or 0.5
                    if not enabled and box:IsFocused() then
                        box:ReleaseFocus(false)
                    end
                end)

                box.Focused:Connect(function()
                    if item:IsEnabled() then
                        tween(boxStroke, TWEEN_FAST, {Color = THEME.Accent, Transparency = 0})
                    else
                        box:ReleaseFocus(false)
                    end
                end)

                box.FocusLost:Connect(function()
                    tween(boxStroke, TWEEN_FAST, {Color = THEME.Border, Transparency = 0.3})
                    if item:IsEnabled() and box.Text ~= value then
                        value = box.Text
                        window.Flags[item.FlagName or name] = value
                        if callback then
                            task.spawn(callback, value)
                        end
                    else
                        box.Text = value
                    end
                end)

                function item:Set(nextValue)
                    value = tostring(nextValue or "")
                    box.Text = value
                    window.Flags[item.FlagName or name] = value
                    if callback then
                        task.spawn(callback, value)
                    end
                end

                item.Refresh()
                window.Flags[item.FlagName or name] = value
                return item
            end

            -- Parágrafo / Label -----------------------------------------------------
            function section:CreateParagraph(text)
                local row = create("Frame", {
                    Name = "Paragraph",
                    BackgroundColor3 = THEME.Surface0,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    LayoutOrder = nextOrder(),
                }, inner)
                corner(row, RADIUS.Small)
                padding(row, 10, 10, 8, 8)

                local textLabel = label(row, {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Text = tostring(text or ""),
                    TextSize = 11,
                    TextColor3 = THEME.TextMuted,
                    TextWrapped = true,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    TextTruncate = Enum.TextTruncate.None,
                })

                local item = {Name = tostring(text or ""), Label = textLabel}
                function item:SetText(nextText)
                    textLabel.Text = tostring(nextText or "")
                end
                return item
            end

            function section:CreateLabel(text)
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 26),
                    LayoutOrder = nextOrder(),
                }, inner)
                local textLabel = label(row, {
                    Size = UDim2.new(1, 0, 1, 0),
                    Text = tostring(text or ""),
                    TextSize = 12,
                })
                local item = {Name = tostring(text or ""), Label = textLabel}
                function item:SetText(nextText)
                    textLabel.Text = tostring(nextText or "")
                end
                return item
            end

            table.insert(self.Sections, section)
            return section
        end

        return tab
    end

    -- Notificações ----------------------------------------------------------------
    function self:Notify(title, message, duration)
        if self.Destroyed then
            return
        end
        local toast = create("Frame", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -20, 1, -20 + 12),
            Size = UDim2.fromOffset(290, 72),
            BackgroundColor3 = THEME.Surface1,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 100,
        }, self.Gui)
        corner(toast, RADIUS.Card)
        local toastStroke = stroke(toast, THEME.Border, 1, 1)
        padding(toast, 14, 14, 10, 10)
        table.insert(self.Toasts, toast)

        local function layoutToasts()
            for index, entry in ipairs(self.Toasts) do
                local goal = UDim2.new(1, -20, 1, -20 - (index - 1) * TOAST_STEP)
                tween(entry, TWEEN_MED, {Position = goal})
            end
        end

        local accentBar = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(3, 30),
            BackgroundColor3 = THEME.Accent,
            BorderSizePixel = 0,
            ZIndex = 101,
        }, toast)
        corner(accentBar, RADIUS.Pill)

        local titleLabel = label(toast, {
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -10, 0, 20),
            Text = tostring(title or "DepHub"),
            Font = FONT.Bold,
            TextSize = 13,
            ZIndex = 101,
        })
        local messageLabel = label(toast, {
            Position = UDim2.fromOffset(10, 22),
            Size = UDim2.new(1, -10, 0, 34),
            Text = tostring(message or ""),
            TextSize = 12,
            TextColor3 = THEME.TextMuted,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 101,
        })

        layoutToasts()
        local shown = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        tween(toast, shown, {BackgroundTransparency = 0})
        tween(toastStroke, shown, {Transparency = 0.3})

        task.delay(duration or 3, function()
            if not toast.Parent then
                return
            end
            for i, entry in ipairs(self.Toasts) do
                if entry == toast then
                    table.remove(self.Toasts, i)
                    break
                end
            end
            layoutToasts()
            local hide = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tween(toast, hide, {BackgroundTransparency = 1})
            tween(toastStroke, hide, {Transparency = 1})
            tween(titleLabel, hide, {TextTransparency = 1})
            tween(messageLabel, hide, {TextTransparency = 1})
            tween(accentBar, hide, {BackgroundTransparency = 1})
            task.wait(0.22)
            if toast.Parent then
                toast:Destroy()
            end
        end)
    end

    return self
end

function DepHub:Destroy()
    if self.Destroyed then
        return
    end
    self.Destroyed = true
    self.Drag = nil
    for _, entry in ipairs(self.Popups) do
        entry.frame.Visible = false
    end
    for _, connection in ipairs(self.Connections) do
        connection:Disconnect()
    end
    self.Connections = {}
    self.Popups = {}
    self.Toasts = {}
    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end
end

return DepHub
