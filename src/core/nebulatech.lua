local NebulaTech = {}
NebulaTech.__index = NebulaTech

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local COLORS = {
    Background = Color3.fromRGB(13, 15, 20),
    Panel = Color3.fromRGB(21, 23, 31),
    Panel2 = Color3.fromRGB(26, 29, 39),
    Border = Color3.fromRGB(38, 42, 54),
    Text = Color3.fromRGB(231, 233, 238),
    Muted = Color3.fromRGB(139, 144, 160),
    Accent = Color3.fromRGB(124, 108, 255),
    Accent2 = Color3.fromRGB(88, 101, 242),
    Track = Color3.fromRGB(42, 46, 59)
}

local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end

local function stroke(parent, color, thickness)
    return create("UIStroke", {Color = color or COLORS.Border, Thickness = thickness or 1}, parent)
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0)
    }, parent)
end

local function listLayout(parent, gap, direction)
    return create("UIListLayout", {
        Padding = UDim.new(0, gap or 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = direction or Enum.FillDirection.Vertical
    }, parent)
end

local function makeButton(parent, text, size)
    local object = create("TextButton", {
        AutoButtonColor = false,
        Text = text or "",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = COLORS.Text,
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0,
        Size = size or UDim2.new(1, 0, 0, 30)
    }, parent)
    corner(object, 6)
    return object
end

function NebulaTech.new(config)
    config = config or {}
    local self = setmetatable({}, NebulaTech)
    self.Name = config.Name or "DepHub"
    self.Tabs = {}
    self.Flags = {}
    self.Connections = {}
    self.Destroyed = false

    local player = Players.LocalPlayer
    local parent = config.Parent
    if not parent then
        parent = player:WaitForChild("PlayerGui")
        if type(gethui) == "function" then
            local ok, result = pcall(gethui)
            if ok and typeof(result) == "Instance" then parent = result end
        end
    end

    local old = parent:FindFirstChild(config.GuiName or "NebulaTech")
    if old then old:Destroy() end

    local gui = create("ScreenGui", {
        Name = config.GuiName or "NebulaTech",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 1000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, parent)
    self.Gui = gui

    local main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = config.Size or UDim2.fromOffset(820, 540),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true
    }, gui)
    corner(main, 14)
    stroke(main)
    self.Main = main

    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 155, 1, 0),
        BackgroundColor3 = COLORS.Panel2,
        BorderSizePixel = 0
    }, main)
    padding(sidebar, 10, 10, 14, 12)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        Text = "<u>nebula</u><font color=\"#7C6CFF\">tech</font>",
        RichText = true,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = COLORS.Text,
        TextXAlignment = Enum.TextXAlignment.Left
    }, sidebar)

    local nav = create("ScrollingFrame", {
        Name = "Navigation",
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(1, 0, 1, -42),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = COLORS.Track
    }, sidebar)
    listLayout(nav, 7)

    create("Frame", {
        Position = UDim2.new(0, 155, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = COLORS.Border,
        BorderSizePixel = 0
    }, main)

    local body = create("Frame", {
        Name = "Body",
        Position = UDim2.new(0, 156, 0, 0),
        Size = UDim2.new(1, -156, 1, 0),
        BackgroundTransparency = 1
    }, main)

    local tabbar = create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1
    }, body)
    padding(tabbar, 16, 12, 5, 0)
    local tabLayout = listLayout(tabbar, 6, Enum.FillDirection.Horizontal)
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

    create("Frame", {
        Position = UDim2.new(0, 0, 0, 47),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = COLORS.Border,
        BorderSizePixel = 0
    }, body)

    local content = create("ScrollingFrame", {
        Name = "Content",
        Position = UDim2.new(0, 0, 0, 49),
        Size = UDim2.new(1, 0, 1, -81),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = COLORS.Track,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, body)
    padding(content, 16, 16, 14, 16)
    self.Content = content

    local grid = create("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, content)
    self.Grid = grid
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 24)
    end)

    local footer = create("Frame", {
        Name = "Footer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1
    }, body)
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = COLORS.Border,
        BorderSizePixel = 0
    }, footer)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 5),
        Size = UDim2.new(0.65, -16, 0, 20),
        Text = config.FooterLeft or "DepHub UI Library",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = COLORS.Muted,
        TextXAlignment = Enum.TextXAlignment.Left
    }, footer)
    create("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 5),
        Size = UDim2.new(0.35, -16, 0, 20),
        Text = self.Name,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = COLORS.Accent,
        TextXAlignment = Enum.TextXAlignment.Right
    }, footer)

    local floating = makeButton(gui, "N", UDim2.fromOffset(44, 44))
    floating.Name = "Floating"
    floating.AnchorPoint = Vector2.new(1, 1)
    floating.Position = UDim2.new(1, -18, 1, -18)
    floating.Visible = false
    floating.TextSize = 18
    floating.Font = Enum.Font.GothamBold
    corner(floating, 22)

    local dragging, dragInput, dragStart, startPosition
    tabbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    tabbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    self.Connections[#self.Connections + 1] = UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)

    local visible = true
    local function setVisible(value)
        visible = value == true
        main.Visible = visible
        floating.Visible = not visible
    end
    floating.Activated:Connect(function() setVisible(true) end)
    self.Connections[#self.Connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.Insert then setVisible(not visible) end
    end)
    self.SetVisible = setVisible

    function self:CreateTab(tabName)
        local tab = {Name = tabName, Sections = {}}
        local navButton = makeButton(nav, "◉  " .. tostring(tabName), UDim2.new(1, 0, 0, 32))
        navButton.TextXAlignment = Enum.TextXAlignment.Left
        navButton.LayoutOrder = #self.Tabs + 1
        padding(navButton, 9, 4, 0, 0)

        local tabButton = makeButton(tabbar, tostring(tabName), UDim2.fromOffset(math.max(78, #tostring(tabName) * 8 + 24), 38))
        tabButton.BackgroundTransparency = 1
        tabButton.TextColor3 = COLORS.Muted
        tabButton.Font = Enum.Font.GothamSemibold
        tabButton.LayoutOrder = #self.Tabs + 1

        local page = create("Frame", {
            Name = tostring(tabName) .. "Page",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = false
        }, content)
        page.LayoutOrder = #self.Tabs + 1
        local pageGrid = create("UIListLayout", {
            Padding = UDim.new(0, 12),
            SortOrder = Enum.SortOrder.LayoutOrder
        }, page)
        pageGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.Size = UDim2.new(1, 0, 0, pageGrid.AbsoluteContentSize.Y)
        end)

        local function selectTab()
            for _, other in ipairs(self.Tabs) do
                other.Page.Visible = false
                other.TabButton.TextColor3 = COLORS.Muted
                other.NavButton.BackgroundColor3 = COLORS.Panel2
                if other.Indicator then other.Indicator:Destroy() end
            end
            page.Visible = true
            tabButton.TextColor3 = COLORS.Text
            navButton.BackgroundColor3 = Color3.fromRGB(44, 40, 70)
            local indicator = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, 0),
                Size = UDim2.new(1, -18, 0, 2),
                BackgroundColor3 = COLORS.Accent,
                BorderSizePixel = 0
            }, tabButton)
            corner(indicator, 2)
            tab.Indicator = indicator
            content.CanvasPosition = Vector2.zero
        end

        tab.Page, tab.PageGrid, tab.TabButton, tab.NavButton = page, pageGrid, tabButton, navButton
        tab.Select = selectTab
        table.insert(self.Tabs, tab)
        tabButton.Activated:Connect(selectTab)
        navButton.Activated:Connect(selectTab)
        if #self.Tabs == 1 then selectTab() end

        function tab:CreateSection(sectionName, sectionConfig)
            sectionConfig = sectionConfig or {}
            local section = {Name = sectionName, Items = {}, Enabled = sectionConfig.Enabled ~= false, ParentWindow = self.ParentWindow}
            local card = create("Frame", {
                Name = tostring(sectionName),
                BackgroundColor3 = COLORS.Panel2,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 190),
                ClipsDescendants = false
            }, page)
            corner(card, 10)
            stroke(card)
            local header = create("Frame", {
                Size = UDim2.new(1, 0, 0, 42),
                BackgroundTransparency = 1
            }, card)
            local dot = create("Frame", {
                Position = UDim2.fromOffset(12, 13),
                Size = UDim2.fromOffset(16, 16),
                BackgroundColor3 = COLORS.Accent,
                BorderSizePixel = 0
            }, header)
            corner(dot, 8)
            create("UIGradient", {Color = ColorSequence.new(COLORS.Accent, COLORS.Accent2), Rotation = 45}, dot)
            create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(36, 0),
                Size = UDim2.new(1, -84, 1, 0),
                Text = tostring(sectionName),
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextColor3 = COLORS.Text,
                TextXAlignment = Enum.TextXAlignment.Left
            }, header)
            local master = makeButton(header, "", UDim2.fromOffset(30, 17))
            master.AnchorPoint = Vector2.new(1, 0.5)
            master.Position = UDim2.new(1, -12, 0.5, 0)
            master.BackgroundColor3 = section.Enabled and COLORS.Accent or COLORS.Track
            corner(master, 12)
            local knob = create("Frame", {
                Size = UDim2.fromOffset(13, 13),
                Position = section.Enabled and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0
            }, master)
            corner(knob, 8)

            local inner = create("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 42),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y
            }, card)
            padding(inner, 12, 12, 0, 10)
            local innerLayout = listLayout(inner, 2)
            innerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                card.Size = UDim2.new(1, 0, 0, innerLayout.AbsoluteContentSize.Y + 52)
            end)

            local function register(name, setAvailable)
                local item = {Name = name, Available = true, SetAvailable = setAvailable}
                function item:SetAvailableState(value)
                    self.Available = value == true
                    if self.SetAvailable then self.SetAvailable(self.Available) end
                end
                table.insert(section.Items, item)
                return item
            end

            local function addRow(name, height)
                local row = create("Frame", {
                    Name = tostring(name),
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, height or 32)
                }, inner)
                local title = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -116, 1, 0),
                    Text = tostring(name),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = COLORS.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd
                }, row)
                local controls = create("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(112, height or 32),
                    BackgroundTransparency = 1
                }, row)
                return row, title, controls
            end

            local function refreshSection()
                master.BackgroundColor3 = section.Enabled and COLORS.Accent or COLORS.Track
                TweenService:Create(knob, TweenInfo.new(0.12), {
                    Position = section.Enabled and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
                }):Play()
                for _, item in ipairs(section.Items) do item:SetAvailableState(section.Enabled) end
                if sectionConfig.Callback then pcall(sectionConfig.Callback, section.Enabled) end
            end
            master.Activated:Connect(function()
                section.Enabled = not section.Enabled
                refreshSection()
            end)

            function section:CreateToggle(name, default, callback)
                local _, _, controls = addRow(name)
                local value = default == true
                local toggle = makeButton(controls, "", UDim2.fromOffset(30, 17))
                toggle.AnchorPoint = Vector2.new(1, 0.5)
                toggle.Position = UDim2.new(1, 0, 0.5, 0)
                corner(toggle, 12)
                local knob2 = create("Frame", {
                    Size = UDim2.fromOffset(13, 13),
                    Position = value and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0
                }, toggle)
                corner(knob2, 8)
                local function render()
                    toggle.BackgroundColor3 = value and COLORS.Accent or COLORS.Track
                    knob2.Position = value and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
                    section.ParentWindow.Flags[name] = value
                end
                local item = register(name, function(available)
                    toggle.Active = available
                    toggle.BackgroundTransparency = available and 0 or 0.5
                end)
                function item:Set(nextValue)
                    value = nextValue == true
                    render()
                    if callback then callback(value) end
                end
                toggle.Activated:Connect(function()
                    if item.Available then item:Set(not value) end
                end)
                item:SetAvailableState(section.Enabled)
                render()
                return item
            end

            function section:CreateCheckbox(name, default, callback)
                local _, _, controls = addRow(name)
                local value = default == true
                local check = makeButton(controls, value and "✓" or "", UDim2.fromOffset(18, 18))
                check.AnchorPoint = Vector2.new(1, 0.5)
                check.Position = UDim2.new(1, 0, 0.5, 0)
                local item = register(name, function(available) check.Active = available end)
                function item:Set(nextValue)
                    value = nextValue == true
                    check.Text = value and "✓" or ""
                    section.ParentWindow.Flags[name] = value
                    if callback then callback(value) end
                end
                check.Activated:Connect(function() if item.Available then item:Set(not value) end end)
                item:SetAvailableState(section.Enabled)
                section.ParentWindow.Flags[name] = value
                return item
            end

            function section:CreateDropdown(name, options, default, callback)
                local _, _, controls = addRow(name, 36)
                local selected = default or options[1] or "Select"
                local dd = makeButton(controls, tostring(selected) .. "  ▾", UDim2.fromOffset(112, 26))
                dd.AnchorPoint = Vector2.new(1, 0.5)
                dd.Position = UDim2.new(1, 0, 0.5, 0)
                local popup = create("Frame", {
                    Visible = false,
                    Position = UDim2.new(0, 0, 1, 3),
                    Size = UDim2.new(1, 0, 0, math.min(#options * 26, 130)),
                    BackgroundColor3 = COLORS.Background,
                    BorderSizePixel = 0,
                    ZIndex = 30
                }, dd)
                corner(popup, 6)
                stroke(popup)
                local scroller = create("ScrollingFrame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    CanvasSize = UDim2.new(0, 0, 0, #options * 26),
                    ScrollBarThickness = 3,
                    ZIndex = 31
                }, popup)
                listLayout(scroller, 0)
                local item = register(name, function(available) dd.Active = available; dd.BackgroundTransparency = available and 0 or 0.5 end)
                function item:Set(nextValue)
                    selected = nextValue
                    dd.Text = tostring(selected) .. "  ▾"
                    popup.Visible = false
                    section.ParentWindow.Flags[name] = selected
                    if callback then callback(selected) end
                end
                for _, option in ipairs(options) do
                    local opt = makeButton(scroller, tostring(option), UDim2.new(1, 0, 0, 26))
                    opt.BackgroundColor3 = COLORS.Background
                    opt.TextXAlignment = Enum.TextXAlignment.Left
                    opt.ZIndex = 32
                    opt.Activated:Connect(function() if item.Available then item:Set(option) end end)
                end
                dd.Activated:Connect(function() if item.Available then popup.Visible = not popup.Visible end end)
                section.ParentWindow.Flags[name] = selected
                item:SetAvailableState(section.Enabled)
                return item
            end

            function section:CreateButton(name, callback)
                local _, _, controls = addRow(name)
                local action = makeButton(controls, name, UDim2.fromOffset(104, 26))
                action.AnchorPoint = Vector2.new(1, 0.5)
                action.Position = UDim2.new(1, 0, 0.5, 0)
                action.BackgroundColor3 = Color3.fromRGB(44, 40, 70)
                local item = register(name, function(available) action.Active = available; action.BackgroundTransparency = available and 0 or 0.5 end)
                action.Activated:Connect(function() if item.Available and callback then callback() end end)
                item:SetAvailableState(section.Enabled)
                return item
            end

            function section:CreateLabel(text)
                local _, title = addRow(text, 28)
                title.Size = UDim2.new(1, 0, 1, 0)
                return title
            end

            table.insert(self.Sections, section)
            return section
        end

        tab.ParentWindow = self
        return tab
    end

    function self:Notify(title, message, duration)
        local toast = create("Frame", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -20, 1, -20),
            Size = UDim2.fromOffset(280, 76),
            BackgroundColor3 = COLORS.Panel2,
            BorderSizePixel = 0,
            ZIndex = 100
        }, self.Gui)
        corner(toast, 10)
        stroke(toast)
        padding(toast, 12, 12, 8, 8)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Text = tostring(title or "DepHub"),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = COLORS.Accent,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 101
        }, toast)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 24),
            Size = UDim2.new(1, 0, 0, 36),
            Text = tostring(message or ""),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = COLORS.Text,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 101
        }, toast)
        task.delay(duration or 3, function()
            if toast.Parent then
                TweenService:Create(toast, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                task.wait(0.22)
                if toast.Parent then toast:Destroy() end
            end
        end)
    end

    return self
end

function NebulaTech:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
    if self.Gui then self.Gui:Destroy() end
end

return NebulaTech
