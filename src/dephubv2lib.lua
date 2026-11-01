local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local Library = {}
Library.__index = Library

local Theme = {
    Background = Color3.fromRGB(17, 18, 24),
    Surface = Color3.fromRGB(23, 25, 33),
    Surface2 = Color3.fromRGB(30, 33, 43),
    Sidebar = Color3.fromRGB(20, 21, 28),
    Accent = Color3.fromRGB(139, 92, 246),
    AccentDark = Color3.fromRGB(112, 72, 210),
    Text = Color3.fromRGB(238, 239, 245),
    Muted = Color3.fromRGB(145, 149, 164),
    Border = Color3.fromRGB(43, 46, 58),
    Success = Color3.fromRGB(74, 190, 126),
    Danger = Color3.fromRGB(224, 87, 87)
}

local function create(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end

local function stroke(parent, color, transparency)
    return create("UIStroke", {
        Color = color or Theme.Border,
        Transparency = transparency or 0,
        Thickness = 1
    }, parent)
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0)
    }, parent)
end

local function label(parent, text, size, color, font)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = color or Theme.Text,
        TextSize = size or 13,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        AutomaticSize = Enum.AutomaticSize.None
    }, parent)
end

local function tween(object, properties, duration)
    local animation = TweenService:Create(object, TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
    animation:Play()
    return animation
end

local function addConnection(self, connection)
    table.insert(self._connections, connection)
    return connection
end

local function addInstance(self, instance)
    table.insert(self._instances, instance)
    return instance
end

local function makeButton(parent, text, size, background)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = background or Theme.Surface2,
        BorderSizePixel = 0,
        Size = size,
        Text = text or "",
        TextColor3 = Theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium
    }, parent)
    corner(button, 7)
    return button
end

local function createComponentBase(section, height)
    local frame = create("Frame", {
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height),
        AutomaticSize = Enum.AutomaticSize.None
    }, section._content)
    corner(frame, 8)
    stroke(frame, Theme.Border, 0.35)
    table.insert(section._window._instances, frame)
    return frame
end

local function createSection(tab, title)
    local section = {
        _tab = tab,
        _window = tab._window,
        _title = title,
        _components = {}
    }

    local header = label(tab._content, title, 12, Theme.Muted, Enum.Font.GothamBold)
    header.Size = UDim2.new(1, 0, 0, 23)
    header.Text = string.upper(title)
    header.TextXAlignment = Enum.TextXAlignment.Left
    table.insert(tab._window._instances, header)

    local container = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y
    }, tab._content)
    create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, container)
    section._content = container
    table.insert(tab._window._instances, container)

    function section:CreateToggle(options)
        options = options or {}
        local frame = createComponentBase(self, 46)
        local name = label(frame, options.Name or "Toggle", 13, Theme.Text)
        name.Position = UDim2.fromOffset(12, 0)
        name.Size = UDim2.new(1, -74, 1, 0)

        local track = create("Frame", {
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -54, 0.5, -10),
            Size = UDim2.fromOffset(42, 20)
        }, frame)
        corner(track, 10)

        local knob = create("Frame", {
            BackgroundColor3 = Color3.fromRGB(220, 222, 230),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(3, 3),
            Size = UDim2.fromOffset(14, 14)
        }, track)
        corner(knob, 10)

        local state = options.Default == true
        local hit = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = ""
        }, frame)

        local function set(value, silent)
            state = value == true
            tween(track, {BackgroundColor3 = state and Theme.Accent or Theme.Surface2})
            tween(knob, {Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)})
            if not silent and options.Callback then
                task.spawn(options.Callback, state)
            end
        end

        addConnection(self._window, hit.Activated:Connect(function()
            set(not state, false)
        end))
        set(state, true)

        local control = {}
        function control:Set(value) set(value, false) end
        function control:Get() return state end
        table.insert(self._components, control)
        return control
    end

    function section:CreateButton(options)
        options = options or {}
        local frame = createComponentBase(self, 42)
        local button = makeButton(frame, options.Name or "Button", UDim2.new(1, -12, 1, -10), Theme.Surface2)
        button.Position = UDim2.fromOffset(6, 5)
        addConnection(self._window, button.Activated:Connect(function()
            if options.Callback then task.spawn(options.Callback) end
        end))
        local control = {}
        function control:SetText(value) button.Text = tostring(value) end
        table.insert(self._components, control)
        return control
    end

    function section:CreateSlider(options)
        options = options or {}
        local minimum = tonumber(options.Min) or 0
        local maximum = tonumber(options.Max) or 100
        if maximum <= minimum then maximum = minimum + 1 end
        local value = math.clamp(tonumber(options.Default) or minimum, minimum, maximum)
        local frame = createComponentBase(self, 58)
        local titleLabel = label(frame, options.Name or "Slider", 13, Theme.Text)
        titleLabel.Position = UDim2.fromOffset(12, 5)
        titleLabel.Size = UDim2.new(1, -80, 0, 20)
        local valueLabel = label(frame, tostring(value), 12, Theme.Muted)
        valueLabel.Position = UDim2.new(1, -62, 0, 5)
        valueLabel.Size = UDim2.fromOffset(50, 20)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right

        local bar = create("Frame", {
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 12, 1, -17),
            Size = UDim2.new(1, -24, 0, 6)
        }, frame)
        corner(bar, 5)
        local fill = create("Frame", {
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.new((value - minimum) / (maximum - minimum), 0, 1, 0)
        }, bar)
        corner(fill, 5)
        local knob = create("Frame", {
            BackgroundColor3 = Theme.Text,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new((value - minimum) / (maximum - minimum), 0, 0.5, 0),
            Size = UDim2.fromOffset(12, 12)
        }, bar)
        corner(knob, 8)
        local hit = create("TextButton", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, -8),
            Size = UDim2.new(1, 0, 1, 16),
            Text = ""
        }, bar)

        local dragging = false
        local function set(nextValue, silent)
            value = math.clamp(nextValue, minimum, maximum)
            local ratio = (value - minimum) / (maximum - minimum)
            fill.Size = UDim2.new(ratio, 0, 1, 0)
            knob.Position = UDim2.new(ratio, 0, 0.5, 0)
            valueLabel.Text = tostring(math.floor(value * 100 + 0.5) / 100)
            if not silent and options.Callback then task.spawn(options.Callback, value) end
        end
        local function updateFromX(x)
            local ratio = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            set(minimum + (maximum - minimum) * ratio, false)
        end
        addConnection(self._window, hit.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromX(input.Position.X)
            end
        end))
        addConnection(self._window, UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromX(input.Position.X)
            end
        end))
        addConnection(self._window, UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
        set(value, true)
        local control = {}
        function control:Set(nextValue) set(tonumber(nextValue) or minimum, false) end
        function control:Get() return value end
        table.insert(self._components, control)
        return control
    end

    function section:CreateDropdown(options)
        options = options or {}
        local items = options.Options or {}
        local selected = options.Default
        local expanded = false
        local frame = createComponentBase(self, 44)
        local titleLabel = label(frame, options.Name or "Dropdown", 13, Theme.Text)
        titleLabel.Position = UDim2.fromOffset(12, 0)
        titleLabel.Size = UDim2.new(0.42, -12, 1, 0)
        local button = makeButton(frame, tostring(selected or "Select"), UDim2.new(0.58, -12, 0, 30), Theme.Surface2)
        button.Position = UDim2.new(0.42, 0, 0.5, -15)
        local menu = create("Frame", {
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 1, 5),
            Size = UDim2.new(1, 0, 0, 0),
            Visible = false,
            ZIndex = 8,
            ClipsDescendants = true
        }, frame)
        corner(menu, 7)
        stroke(menu, Theme.Border)
        local list = create("UIListLayout", {Padding = UDim.new(0, 2)}, menu)
        local menuPadding = padding(menu, 4, 4, 4, 4)

        local function close()
            expanded = false
            menu.Visible = false
            frame.ZIndex = 1
            button.Text = tostring(selected or "Select")
        end
        local function choose(item)
            selected = item
            close()
            if options.Callback then task.spawn(options.Callback, item) end
        end
        for index, item in ipairs(items) do
            local optionButton = makeButton(menu, tostring(item), UDim2.new(1, 0, 0, 28), Theme.Surface2)
            optionButton.LayoutOrder = index
            optionButton.ZIndex = 9
            addConnection(self._window, optionButton.Activated:Connect(function() choose(item) end))
        end
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if expanded then menu.Size = UDim2.new(1, 0, 0, math.min(list.AbsoluteContentSize.Y + 8, 150)) end
        end)
        addConnection(self._window, button.Activated:Connect(function()
            expanded = not expanded
            menu.Visible = expanded
            frame.ZIndex = expanded and 10 or 1
            if expanded then
                menu.Size = UDim2.new(1, 0, 0, math.min(list.AbsoluteContentSize.Y + 8, 150))
                button.Text = "Close"
            else
                close()
            end
        end))
        local control = {}
        function control:Set(item) choose(item) end
        function control:Get() return selected end
        table.insert(self._components, control)
        return control
    end

    function section:CreateInput(options)
        options = options or {}
        local frame = createComponentBase(self, 44)
        local titleLabel = label(frame, options.Name or "Input", 13, Theme.Text)
        titleLabel.Position = UDim2.fromOffset(12, 0)
        titleLabel.Size = UDim2.new(0.4, -12, 1, 0)
        local box = create("TextBox", {
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            Position = UDim2.new(0.4, 0, 0.5, -15),
            Size = UDim2.new(0.6, -12, 0, 30),
            ClearTextOnFocus = false,
            PlaceholderText = options.Placeholder or "Type here...",
            PlaceholderColor3 = Theme.Muted,
            Text = options.Default or "",
            TextColor3 = Theme.Text,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left
        }, frame)
        corner(box, 7)
        padding(box, 9, 9, 0, 0)
        addConnection(self._window, box.FocusLost:Connect(function(enterPressed)
            if options.Callback then task.spawn(options.Callback, box.Text, enterPressed) end
        end))
        local control = {}
        function control:Set(value) box.Text = tostring(value) end
        function control:Get() return box.Text end
        table.insert(self._components, control)
        return control
    end

    function section:CreateParagraph(options)
        options = options or {}
        local content = tostring(options.Content or options.Text or "")
        local frame = createComponentBase(self, 54)
        local titleLabel = label(frame, options.Title or "Info", 13, Theme.Text, Enum.Font.GothamBold)
        titleLabel.Position = UDim2.fromOffset(12, 7)
        titleLabel.Size = UDim2.new(1, -24, 0, 18)
        local body = label(frame, content, 12, Theme.Muted)
        body.Position = UDim2.fromOffset(12, 27)
        body.Size = UDim2.new(1, -24, 0, 20)
        body.TextWrapped = true
        body.TextYAlignment = Enum.TextYAlignment.Top
        local control = {}
        function control:SetContent(value) body.Text = tostring(value) end
        table.insert(self._components, control)
        return control
    end

    return section
end

function Library:CreateWindow(options)
    options = options or {}
    local self = setmetatable({}, Library)
    self._connections = {}
    self._instances = {}
    self._tabs = {}
    self._destroyed = false

    local player = Players.LocalPlayer
    local parent = options.Parent
    if not parent then
        local ok, result = pcall(function() return gethui and gethui() end)
        if ok and result then
            parent = result
        else
            parent = player:WaitForChild("PlayerGui")
        end
    end

    local gui = create("ScreenGui", {
        Name = options.Name or "DepHubUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true
    }, parent)
    self._gui = gui
    addInstance(self, gui)

    local root = create("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(options.Width or 680, options.Height or 430),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, gui)
    corner(root, 12)
    stroke(root, Theme.Border)
    self._root = root

    local topbar = create("Frame", {
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 48)
    }, root)
    local title = label(topbar, options.Title or "DepHub", 15, Theme.Text, Enum.Font.GothamBold)
    title.Position = UDim2.fromOffset(17, 0)
    title.Size = UDim2.new(1, -110, 1, 0)
    local subtitle = label(topbar, options.Subtitle or "UI Library", 11, Theme.Muted)
    subtitle.Position = UDim2.new(0, 17, 0, 25)
    subtitle.Size = UDim2.new(1, -110, 0, 15)
    local closeButton = makeButton(topbar, "×", UDim2.fromOffset(30, 30), Theme.Surface2)
    closeButton.Position = UDim2.new(1, -42, 0, 9)
    closeButton.TextSize = 20
    local minimizeButton = makeButton(topbar, "−", UDim2.fromOffset(30, 30), Theme.Surface2)
    minimizeButton.Position = UDim2.new(1, -78, 0, 9)
    minimizeButton.TextSize = 19

    local sidebar = create("Frame", {
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 48),
        Size = UDim2.new(0, 166, 1, -48)
    }, root)
    padding(sidebar, 10, 10, 13, 10)
    local tabList = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0)
    }, sidebar)
    create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, tabList)

    local contentArea = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 166, 0, 48),
        Size = UDim2.new(1, -166, 1, -48)
    }, root)
    local pages = create("Folder", {Name = "Pages"}, contentArea)
    self._pages = pages
    self._tabList = tabList

    local dragging = false
    local dragStart, startPosition
    addConnection(self, topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = root.Position
        end
    end))
    addConnection(self, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end))
    addConnection(self, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))

    local minimized = false
    addConnection(self, minimizeButton.Activated:Connect(function()
        minimized = not minimized
        sidebar.Visible = not minimized
        contentArea.Visible = not minimized
        tween(root, {Size = minimized and UDim2.fromOffset(root.AbsoluteSize.X, 48) or UDim2.fromOffset(options.Width or 680, options.Height or 430)})
        minimizeButton.Text = minimized and "+" or "−"
    end))
    addConnection(self, closeButton.Activated:Connect(function() self:Destroy() end))

    function self:CreateTab(tabOptions)
        tabOptions = tabOptions or {}
        local tab = {
            _window = self,
            _sections = {},
            _name = tabOptions.Name or ("Tab " .. tostring(#self._tabs + 1))
        }
        local button = makeButton(tabList, (tabOptions.Icon and (tostring(tabOptions.Icon) .. "   ") or "") .. tab._name, UDim2.new(1, 0, 0, 36), Theme.Sidebar)
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.TextSize = 12
        padding(button, 10, 6, 0, 0)

        local page = create("ScrollingFrame", {
            Name = tab._name:gsub("%W", ""),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Muted,
            Visible = false
        }, pages)
        padding(page, 17, 17, 16, 16)
        create("UIListLayout", {Padding = UDim.new(0, 11), SortOrder = Enum.SortOrder.LayoutOrder}, page)
        tab._page = page
        tab._content = page

        function tab:CreateSection(sectionTitle)
            local section = createSection(self, tostring(sectionTitle or "Section"))
            table.insert(self._sections, section)
            return section
        end

        local function activate()
            for _, other in ipairs(self._tabs) do
                other._page.Visible = false
                tween(other._button, {BackgroundColor3 = Theme.Sidebar})
                other._button.TextColor3 = Theme.Muted
            end
            page.Visible = true
            tween(button, {BackgroundColor3 = Theme.AccentDark})
            button.TextColor3 = Theme.Text
            self._activeTab = tab
        end

        tab._button = button
        addConnection(self, button.Activated:Connect(activate))
        table.insert(self._tabs, tab)
        if #self._tabs == 1 then activate() end
        return tab
    end

    function self:Notify(notification)
        notification = notification or {}
        local holder = self._gui:FindFirstChild("Notifications")
        if not holder then
            holder = create("Frame", {
                Name = "Notifications",
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -16, 0, 16),
                Size = UDim2.fromOffset(270, 300)
            }, self._gui)
            create("UIListLayout", {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right}, holder)
        end
        local card = create("Frame", {
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(260, 66)
        }, holder)
        corner(card, 9)
        stroke(card, Theme.Border)
        local accent = create("Frame", {
            BackgroundColor3 = notification.Color or Theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 3, 1, -16),
            Position = UDim2.fromOffset(0, 8)
        }, card)
        corner(accent, 3)
        local heading = label(card, notification.Title or "Notification", 13, Theme.Text, Enum.Font.GothamBold)
        heading.Position = UDim2.fromOffset(13, 8)
        heading.Size = UDim2.new(1, -22, 0, 19)
        local message = label(card, notification.Content or notification.Description or "", 11, Theme.Muted)
        message.Position = UDim2.fromOffset(13, 29)
        message.Size = UDim2.new(1, -22, 0, 25)
        message.TextWrapped = true
        task.delay(tonumber(notification.Duration) or 3, function()
            if card.Parent then
                tween(card, {BackgroundTransparency = 1}, 0.18)
                task.wait(0.2)
                card:Destroy()
            end
        end)
    end

    function self:SetTheme(values)
        for key, value in pairs(values or {}) do
            if Theme[key] ~= nil then Theme[key] = value end
        end
    end

    function self:Toggle()
        gui.Enabled = not gui.Enabled
        return gui.Enabled
    end

    function self:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        for _, connection in ipairs(self._connections) do
            pcall(function() connection:Disconnect() end)
        end
        for _, instance in ipairs(self._instances) do
            pcall(function() instance:Destroy() end)
        end
        self._connections = {}
        self._instances = {}
    end

    return self
end

return Library