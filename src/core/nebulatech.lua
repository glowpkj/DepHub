local DepHub = {}
DepHub.__index = DepHub

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local COLORS = {
    Background = Color3.fromRGB(0, 0, 0),
    Panel = Color3.fromRGB(5, 5, 5),
    Panel2 = Color3.fromRGB(10, 10, 10),
    Border = Color3.fromRGB(24, 24, 24),
    Text = Color3.fromRGB(231, 233, 238),
    Muted = Color3.fromRGB(139, 144, 160),
    Accent = Color3.fromRGB(124, 108, 255),
    Accent2 = Color3.fromRGB(88, 101, 242),
    Track = Color3.fromRGB(30, 30, 30)
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

function DepHub.new(config)
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

    local old = parent:FindFirstChild(config.GuiName or "DepHub")
    if old then old:Destroy() end

    local gui = create("ScreenGui", {
        Name = config.GuiName or "DepHub",
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
        Text = "<font color=\"#FFFFFF\">Dep</font><font color=\"#8B5CF6\">Hub</font>",
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
            self.SelectedTab = tab
            tabButton.TextColor3 = COLORS.Text
            navButton.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
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
        function tab:SetVisible(value)
            value = value == true
            self.Visible = value
            self.Page.Visible = value and self.ParentWindow.SelectedTab == self
            self.NavButton.Visible = value
            self.TabButton.Visible = value
            if not value and self.ParentWindow.SelectedTab == self then
                for _, other in ipairs(self.ParentWindow.Tabs) do
                    if other ~= self and other.Visible ~= false then
                        other.Select()
                        break
                    end
                end
            end
        end
        tab.Visible = true
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
                action.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
                local item = register(name, function(available) action.Active = available; action.BackgroundTransparency = available and 0 or 0.5 end)
                action.Activated:Connect(function() if item.Available and callback then callback() end end)
                item:SetAvailableState(section.Enabled)
                return item
            end

            function section:CreateColorPicker(name, default, callback)
                local _, _, controls = addRow(name, 36)
                local color = default or COLORS.Accent
                local hue, saturation, brightness = color:ToHSV()
                local swatch = makeButton(controls, "", UDim2.fromOffset(22, 22))
                swatch.AnchorPoint = Vector2.new(1, 0.5)
                swatch.Position = UDim2.new(1, 0, 0.5, 0)
                swatch.BackgroundColor3 = color
                stroke(swatch)

                local popup = create("Frame", {
                    Visible = false,
                    Position = UDim2.new(1, -184, 1, 4),
                    Size = UDim2.fromOffset(172, 138),
                    BackgroundColor3 = COLORS.Background,
                    BorderSizePixel = 0,
                    ZIndex = 40
                }, card)
                corner(popup, 8)
                stroke(popup)
                padding(popup, 8, 8, 8, 8)

                local hueBar = create("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 14),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 41
                }, popup)
                corner(hueBar, 4)
                create("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
                    })
                }, hueBar)

                local sv = create("TextButton", {
                    Text = "",
                    AutoButtonColor = false,
                    Position = UDim2.fromOffset(0, 22),
                    Size = UDim2.new(1, 0, 1, -22),
                    BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 41
                }, popup)
                corner(sv, 5)
                create("UIGradient", {
                    Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
                }, sv)
                create("UIGradient", {
                    Rotation = 90,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0)
                    })
                }, sv)

                local function refresh()
                    color = Color3.fromHSV(hue, saturation, brightness)
                    swatch.BackgroundColor3 = color
                    sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
                    section.ParentWindow.Flags[name] = color
                    if callback then callback(color) end
                end

                local function bindDrag(target, update)
                    local active = false
                    target.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            active = true
                            update(input.Position)
                        end
                    end)
                    target.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then active = false end
                    end)
                    section.ParentWindow.Connections[#section.ParentWindow.Connections + 1] = UserInputService.InputChanged:Connect(function(input)
                        if active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input.Position) end
                    end)
                end

                bindDrag(hueBar, function(position)
                    hue = math.clamp((position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
                    refresh()
                end)
                bindDrag(sv, function(position)
                    saturation = math.clamp((position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
                    brightness = 1 - math.clamp((position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
                    refresh()
                end)

                local item = register(name, function(available)
                    swatch.Active = available
                    swatch.BackgroundTransparency = available and 0 or 0.5
                end)
                function item:Set(nextColor)
                    if typeof(nextColor) ~= "Color3" then return end
                    color = nextColor
                    hue, saturation, brightness = color:ToHSV()
                    refresh()
                end
                swatch.Activated:Connect(function() if item.Available then popup.Visible = not popup.Visible end end)
                item:SetAvailableState(section.Enabled)
                section.ParentWindow.Flags[name] = color
                return item
            end

            function section:CreateSlider(name, minimum, maximum, default, callback)
                local minValue = tonumber(minimum) or 0
                local maxValue = tonumber(maximum) or 100
                if maxValue < minValue then minValue, maxValue = maxValue, minValue end
                local value = math.clamp(tonumber(default) or minValue, minValue, maxValue)
                local row = create("Frame", {Name = tostring(name), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48)}, inner)
                create("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -54, 0, 20), Text = tostring(name), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLORS.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, row)
                local valueLabel = create("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(48, 20), Text = tostring(value), Font = Enum.Font.GothamSemibold, TextSize = 11, TextColor3 = COLORS.Accent, TextXAlignment = Enum.TextXAlignment.Right}, row)
                local bar = create("TextButton", {Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = COLORS.Track, BorderSizePixel = 0}, row)
                corner(bar, 4)
                local fill = create("Frame", {Size = UDim2.new(maxValue == minValue and 0 or (value - minValue) / (maxValue - minValue), 0, 1, 0), BackgroundColor3 = COLORS.Accent, BorderSizePixel = 0}, bar)
                corner(fill, 4)
                local item = register(name, function(available) bar.Active = available; bar.BackgroundTransparency = available and 0 or 0.5 end)
                local function render(runCallback)
                    value = math.clamp(value, minValue, maxValue)
                    valueLabel.Text = tostring(value)
                    fill.Size = UDim2.new(maxValue == minValue and 0 or (value - minValue) / (maxValue - minValue), 0, 1, 0)
                    section.ParentWindow.Flags[name] = value
                    if runCallback and callback then callback(value) end
                end
                function item:Set(nextValue)
                    local n = tonumber(nextValue)
                    if not n then return end
                    value = math.clamp(math.floor(n + 0.5), minValue, maxValue)
                    render(true)
                end
                local draggingSlider = false
                local function setFromX(x)
                    local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
                    item:Set(minValue + (maxValue - minValue) * alpha)
                end
                bar.Activated:Connect(function() if item.Available then setFromX(UserInputService:GetMouseLocation().X) end end)
                bar.InputBegan:Connect(function(input)
                    if item.Available and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                        draggingSlider = true
                        setFromX(input.Position.X)
                    end
                end)
                bar.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSlider = false end
                end)
                section.ParentWindow.Connections[#section.ParentWindow.Connections + 1] = UserInputService.InputChanged:Connect(function(input)
                    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromX(input.Position.X) end
                end)
                item:SetAvailableState(section.Enabled)
                render(false)
                return item
            end

            function section:CreateInput(name, placeholder, default, callback)
                local _, _, controls = addRow(name, 36)
                local box = create("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(112, 28), BackgroundColor3 = COLORS.Background, BorderSizePixel = 0, Text = tostring(default or ""), PlaceholderText = tostring(placeholder or ""), ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = COLORS.Text, PlaceholderColor3 = COLORS.Muted}, controls)
                corner(box, 6)
                stroke(box)
                local value = tostring(default or "")
                local item = register(name, function(available) box.Active = available; box.TextEditable = available; box.BackgroundTransparency = available and 0 or 0.5 end)
                function item:Set(nextValue)
                    value = tostring(nextValue or "")
                    box.Text = value
                    section.ParentWindow.Flags[name] = value
                    if callback then callback(value) end
                end
                box.FocusLost:Connect(function()
                    if item.Available then
                        value = box.Text
                        section.ParentWindow.Flags[name] = value
                        if callback then callback(value) end
                    end
                end)
                item:SetAvailableState(section.Enabled)
                section.ParentWindow.Flags[name] = value
                return item
            end

            function section:CreateParagraph(text)
                local row = create("Frame", {Name = "Paragraph", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, inner)
                local label = create("TextLabel", {BackgroundColor3 = COLORS.Background, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(text or ""), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = COLORS.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center}, row)
                corner(label, 6)
                padding(label, 8, 8, 4, 4)
                local item = {Name = tostring(text or ""), Label = label}
                function item:SetText(nextText)
                    label.Text = tostring(nextText or "")
                    row.Size = UDim2.new(1, 0, 0, 0)
                end
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

function DepHub:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
    if self.Gui then self.Gui:Destroy() end
end

return DepHub
