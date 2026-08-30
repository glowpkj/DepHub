local Utils = require(script.Parent.utils)
local Components = require(script.Parent.components)
local C, UIS = Utils.Colors, Utils.UserInputService
local Window, Tab, Library = {}, {}, {}
Window.__index, Tab.__index = Window, Tab
Components.Register(Tab)

local function create(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function text(parent, value, size, color, bold)
    return create("TextLabel", parent, {BackgroundTransparency = 1, Text = value or "", TextSize = size or 12, TextColor3 = color or C.Light, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd})
end

local function list(parent, gap, direction)
    return create("UIListLayout", parent, {Padding = UDim.new(0, gap or 8), FillDirection = direction or Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder})
end

local function rounded(object, radius, border)
    Utils.ApplyCorner(object, radius or 8)
    if border then Utils.ApplyStroke(object, C.Border, 1, 0.2) end
    return object
end

local function connect(window, signal, callback)
    local connection = signal:Connect(callback)
    window.Connections[#window.Connections + 1] = connection
    return connection
end

local function viewport()
    return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
end

function Tab:_mount(object, height, fullWidth)
    self.NextOrder = self.NextOrder + 1
    object.LayoutOrder = self.NextOrder
    local record = {Object = object, Height = height, FullWidth = fullWidth == true, Order = self.NextOrder}
    self.Elements[#self.Elements + 1] = object
    self.Records[#self.Records + 1] = record
    self:_layout()
    if self.WindowRef.SearchBox and self.WindowRef.SearchBox.Text ~= "" then self.WindowRef:_filter() end
end

function Tab:_layout()
    local single = self.WindowRef.Compact
    local heights = {0, 0}
    self.RightColumn.Visible = not single
    self.LeftColumn.Size = UDim2.new(single and 1 or 0.5, single and 0 or -6, 0, 0)
    self.RightColumn.Size = UDim2.new(0.5, -6, 0, 0)
    for _, record in ipairs(self.Records) do
        if record.FullWidth then
            record.Object.Parent = self.Banners
        else
            record.Column = record.Column or (heights[1] <= heights[2] and 1 or 2)
            local column = single and 1 or record.Column
            record.Object.Parent = column == 1 and self.LeftColumn or self.RightColumn
            if record.Object.Visible then heights[column] = heights[column] + record.Height + 8 end
        end
    end
    self.Banners.Visible = #self.Banners:GetChildren() > 1
end

function Tab:CreateSection(name)
    local owner = self
    local frame = create("Frame", nil, {Name = "Section_" .. name, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1})
    local title = text(frame, string.upper(name), 9, C.Gray, true)
    title.Size = UDim2.new(1, 0, 0, 23)
    local content = create("Frame", frame, {Name = "Controls", Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y})
    list(content, 8)
    local section = setmetatable({Name = name, Frame = frame, WindowRef = self.WindowRef, Elements = {}, Records = {}, NextOrder = 0}, Tab)
    self:_mount(frame, 28)
    local sectionRecord = self.Records[#self.Records]
    sectionRecord.Section = section
    function section:SetVisible(visible)
        sectionRecord.Enabled = visible == true
        frame.Visible = visible == true
        self.WindowRef:_filter()
        owner:_layout()
    end
    function section:_layout()
        local height, count = 28, 0
        for _, item in ipairs(self.Records) do
            if item.Object.Visible then height += item.Height + 8; count += 1 end
        end
        owner:_resize(frame, count > 0 and height - 8 or 28)
    end
    function section:_mount(object, height)
        self.NextOrder += 1
        object.Parent, object.LayoutOrder = content, self.NextOrder
        self.Elements[#self.Elements + 1] = object
        self.Records[#self.Records + 1] = {Object = object, Height = height}
        self:_layout()
    end
    return section
end

function Tab:_resize(object, height)
    object.Size = UDim2.new(1, 0, 0, height)
    for _, record in ipairs(self.Records) do if record.Object == object then record.Height = height; break end end
    self:_layout()
end

function Window:_filter()
    local tab = self.TabButtons[self.CurrentTab]
    if not tab then return end
    local query = string.lower(self.SearchBox.Text)
    local function matches(object)
        local parts = {}
        if object:IsA("TextLabel") then parts[#parts + 1] = object.Text end
        for _, item in ipairs(object:GetDescendants()) do
            if item:IsA("TextLabel") or item:IsA("TextButton") then parts[#parts + 1] = item.Text end
        end
        return query == "" or string.find(string.lower(table.concat(parts, " ")), query, 1, true) ~= nil
    end
    local count = 0
    for _, record in ipairs(tab.Records) do
        local object = record.Object
        local section = record.Section
        if section then
            local showAll = query == "" or string.find(string.lower(section.Name), query, 1, true) ~= nil
            local visible = false
            for _, item in ipairs(section.Records) do
                item.Object.Visible = showAll or matches(item.Object)
                visible = visible or item.Object.Visible
            end
            object.Visible = visible and record.Enabled ~= false
            section:_layout()
        else
            object.Visible = record.Enabled ~= false and matches(object)
        end
        if object.Visible then count = count + 1 end
    end
    self.EmptySearch.Visible = query ~= "" and count == 0
    tab:_layout()
end

function Window:_responsive()
    if self.Destroyed then return end
    local screen = viewport()
    local width, height = math.min(1040, screen.X - 24), math.min(710, screen.Y - 24)
    width, height = math.max(1, width), math.max(1, height)
    self.Compact = width < 700
    self.Window.Size = UDim2.fromOffset(width, height)
    self.ModuleTag.Visible = width >= 550
    self.FooterHint.Visible = width >= 500
    self.SearchHolder.Size = UDim2.new(self.Compact and 1 or 0, self.Compact and 0 or 232, 0, 34)
    self.SearchHolder.Position = self.Compact and UDim2.fromOffset(0, 61) or UDim2.new(1, -232, 0, 12)
    self.PageHeading.Size = UDim2.new(1, 0, 0, self.Compact and 107 or 72)
    self.PageTitle.Size = UDim2.new(self.Compact and 1 or 0.55, 0, 0, 26)
    self.PageDescription.Size = UDim2.new(self.Compact and 1 or 0.65, self.Compact and 0 or -100, 0, 22)
    local top = self.Compact and 107 or 72
    self.Pages.Position, self.Pages.Size = UDim2.fromOffset(0, top), UDim2.new(1, 0, 1, -top)
    for _, tab in ipairs(self.Tabs) do tab:_layout() end
    self:_clampPosition()
end

function Window:_clampPosition()
    local screen = viewport()
    local width, height = self.Window.Size.X.Offset, self.Window.Size.Y.Offset
    local x = screen.X * self.Window.Position.X.Scale + self.Window.Position.X.Offset
    local y = screen.Y * self.Window.Position.Y.Scale + self.Window.Position.Y.Offset
    x = math.clamp(x, width / 2, math.max(width / 2, screen.X - width / 2))
    y = math.clamp(y, height / 2, math.max(height / 2, screen.Y - height / 2))
    self.Window.Position = UDim2.fromOffset(x, y)
end

function Window:SetOpen(open)
    if self.Destroyed then return end
    self.IsHidden = not open
    self.Window.Visible = open == true
    self.ToggleButton.Visible = not open
end

function Window:SelectTab(name)
    if self.Destroyed then return end
    local chosen = self.TabButtons[name]
    if not chosen then return end
    for _, tab in ipairs(self.Tabs) do
        local active = tab == chosen
        tab.Page.Visible = active
        tab.Button.BackgroundColor3 = active and C.Active or C.Sidebar
        tab.Label.TextColor3 = active and C.White or C.Gray
        tab.Indicator.Visible = active
    end
    self.CurrentTab, self.CurrentTabName = name, name
    self.PageTitle.Text = name == "Dashboard" and "Visão geral" or name
    self.PageDescription.Text = chosen.Description or ""
    self.SearchBox.Text = ""
    self:_filter()
end

function Window:CreateTab(name, icon, description)
    if self.TabButtons[name] then return self.TabButtons[name] end
    local tab = setmetatable({Name = name, Description = description, WindowRef = self, Elements = {}, Records = {}, NextOrder = 0}, Tab)
    tab.Page = create("ScrollingFrame", self.Pages, {Name = name .. "Page", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent, Visible = false})
    create("UIPadding", tab.Page, {PaddingRight = UDim.new(0, 7), PaddingBottom = UDim.new(0, 16), PaddingTop = UDim.new(0, 2)})
    list(tab.Page, 12)
    tab.Banners = create("Frame", tab.Page, {Name = "Overview", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 0})
    list(tab.Banners, 8)
    local columns = create("Frame", tab.Page, {Name = "ResponsiveColumns", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1})
    list(columns, 12, Enum.FillDirection.Horizontal)
    tab.LeftColumn = create("Frame", columns, {Name = "Left", Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1})
    tab.RightColumn = create("Frame", columns, {Name = "Right", Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2})
    list(tab.LeftColumn, 8); list(tab.RightColumn, 8)
    tab.Button = rounded(create("TextButton", self.TabContainer, {Name = name .. "Tab", Size = UDim2.fromOffset(math.max(104, math.min(176, #name * 7 + 34)), 37), BackgroundColor3 = C.Sidebar, BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = #self.Tabs + 1}), 6)
    tab.Label = text(tab.Button, name == "Dashboard" and "Início" or name, 11, C.Gray, true)
    tab.Label.Size, tab.Label.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
    tab.Indicator = create("Frame", tab.Button, {Size = UDim2.new(1, -26, 0, 2), Position = UDim2.new(0, 13, 1, -2), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Visible = false})
    self.Tabs[#self.Tabs + 1], self.TabButtons[name] = tab, tab
    connect(self, tab.Button.MouseButton1Click, function() self:SelectTab(name) end)
    tab:_layout()
    if not self.CurrentTab then self:SelectTab(name) end
    return tab
end

function Window:CreateDashboard(title, description)
    if self.DashboardTab then return self.DashboardTab end
    self.DashboardCreated = true
    local tab = self:CreateTab("Dashboard", nil, description or "Seu painel de controle. Tudo organizado em um só lugar.")
    self.DashboardTab = tab
    local banner = rounded(create("Frame", nil, {Name = "WelcomeBanner", Size = UDim2.new(1, 0, 0, 95), BackgroundColor3 = C.Active, BorderSizePixel = 0}), 8, true)
    local heading = text(banner, title or ("Olá, " .. Utils.LocalPlayer.DisplayName), 20, C.White, true)
    heading.Size, heading.Position = UDim2.new(1, -34, 0, 30), UDim2.fromOffset(17, 16)
    local sub = text(banner, "Selecione uma categoria acima para acessar seus recursos.", 11, C.Light)
    sub.Size, sub.Position = UDim2.new(1, -34, 0, 28), UDim2.fromOffset(17, 48)
    sub.TextWrapped = true
    tab:_mount(banner, 95, true)
    local grid = tab:CreateStatGrid()
    self.DashboardStats = {Player = grid:CreateStat("Jogador", "@" .. Utils.LocalPlayer.Name), Status = grid:CreateStat("Status", "ONLINE"), Version = grid:CreateStat("Versão", "--"), Ping = grid:CreateStat("Ping", "--")}
    grid.Frame.Size = UDim2.new(1, 0, 0, 148)
    local releases = rounded(create("Frame", nil, {Name = "ReleasePanel", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Card, BorderSizePixel = 0}), 8, true)
    create("UIPadding", releases, {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12)})
    list(releases, 8)
    self.ReleasesHolder = releases
    tab:_mount(releases, 120, true)
    self:SetReleases({})
    return tab
end

function Window:SetReleases(changelog)
    if not self.DashboardTab then self:CreateDashboard() end
    for _, child in ipairs(self.ReleasesHolder:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    local heading = text(self.ReleasesHolder, "ATUALIZAÇÕES", 9, C.Gray, true)
    heading.Size, heading.LayoutOrder = UDim2.new(1, 0, 0, 20), 0
    if not changelog or #changelog == 0 then
        local empty = text(self.ReleasesHolder, "Nenhuma atualização publicada ainda.", 11, C.DarkGray)
        empty.Size, empty.LayoutOrder = UDim2.new(1, 0, 0, 24), 1
        return
    end
    self.DashboardStats.Version:SetValue(changelog[1].Version or "--")
    local order = 1
    for _, entry in ipairs(changelog) do
        local version = text(self.ReleasesHolder, tostring(entry.Version or "") .. "   ·   " .. tostring(entry.Date or ""), 12, C.White, true)
        version.Size, version.LayoutOrder = UDim2.new(1, 0, 0, 23), order; order += 1
        for _, change in ipairs(entry.Changes or {}) do
            local line = text(self.ReleasesHolder, "•  " .. tostring(change), 11, C.Gray)
            line.Size, line.AutomaticSize, line.TextWrapped, line.LayoutOrder = UDim2.new(1, 0, 0, 20), Enum.AutomaticSize.Y, true, order; order += 1
        end
    end
end

function Window:Notify(title, message, duration, kind)
    if self.Destroyed then return end
    self.NotifyCount += 1
    local toast = rounded(create("Frame", self.NotificationContainer, {Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = C.Sidebar, BorderSizePixel = 0, LayoutOrder = self.NotifyCount}), 8, true)
    local color = ({Success = C.Success, Error = C.Error, Warning = C.Warning})[kind] or C.Accent
    create("Frame", toast, {Size = UDim2.new(0, 3, 1, -20), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = color, BorderSizePixel = 0})
    local heading = text(toast, title, 12, C.White, true)
    heading.Size, heading.Position = UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 8)
    local body = text(toast, message, 11, C.Gray)
    body.Size, body.Position, body.TextWrapped = UDim2.new(1, -28, 0, 38), UDim2.fromOffset(14, 30), true
    task.delay(duration or 4, function() if toast.Parent then toast:Destroy() end end)
    return toast
end

function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    self.Connections = {}
    if self.CameraConnection then self.CameraConnection:Disconnect() end
    if self.ScreenGui then self.ScreenGui:Destroy() end
    self.ScreenGui = nil
end

function Library.new(hubName, subtitle, logoId)
    local self = setmetatable({Connections = {}, Tabs = {}, TabButtons = {}, Destroyed = false, IsHidden = false, Compact = false, NotifyCount = 0, HubName = hubName or "DepHub", Subtitle = subtitle or "Universal"}, Window)
    self.ScreenGui = create("ScreenGui", Utils.PlayerGui, {Name = "DepHubNextUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    self.Window = rounded(create("Frame", self.ScreenGui, {Name = "Workspace", Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Background, BorderSizePixel = 0, ClipsDescendants = true}), 10, true)
    self.TitleBar = create("Frame", self.Window, {Name = "Header", Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = C.Sidebar, BorderSizePixel = 0})
    local mark = rounded(create("Frame", self.TitleBar, {Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(18, 14), BackgroundColor3 = C.Accent, BorderSizePixel = 0}), 8)
    local monogram = text(mark, "D", 22, C.White, true); monogram.Size, monogram.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
    local brand = text(self.TitleBar, "DEPHUB", 15, C.White, true); brand.Size, brand.Position = UDim2.fromOffset(142, 24), UDim2.fromOffset(66, 11)
    local byline = text(self.TitleBar, "CONTROL CENTER", 8, C.DarkGray, true); byline.Size, byline.Position = UDim2.fromOffset(142, 17), UDim2.fromOffset(66, 35)
    self.ModuleTag = rounded(create("TextLabel", self.TitleBar, {Size = UDim2.fromOffset(150, 27), Position = UDim2.fromOffset(217, 19), BackgroundColor3 = C.Surface, BorderSizePixel = 0, Text = subtitle or "Universal", TextColor3 = C.Gray, Font = Enum.Font.GothamMedium, TextSize = 10}), 5)
    local minimize = rounded(create("TextButton", self.TitleBar, {Size = UDim2.fromOffset(34, 32), Position = UDim2.new(1, -52, 0, 16), BackgroundColor3 = C.Surface, BorderSizePixel = 0, Text = "−", TextColor3 = C.Gray, Font = Enum.Font.GothamBold, TextSize = 18}), 6)
    connect(self, minimize.MouseButton1Click, function() self:SetOpen(false) end)
    for _, connection in ipairs(Utils.MakeDraggable(self.TitleBar, self.Window, nil, function() self:_clampPosition() end)) do self.Connections[#self.Connections + 1] = connection end
    self.TabContainer = create("ScrollingFrame", self.Window, {Name = "CategoryRail", Position = UDim2.fromOffset(18, 72), Size = UDim2.new(1, -36, 0, 45), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 2, ScrollBarImageColor3 = C.Border, ScrollingDirection = Enum.ScrollingDirection.X})
    list(self.TabContainer, 6, Enum.FillDirection.Horizontal)
    create("Frame", self.Window, {Size = UDim2.new(1, -36, 0, 1), Position = UDim2.fromOffset(18, 122), BackgroundColor3 = C.Border, BorderSizePixel = 0})
    self.Content = create("Frame", self.Window, {Name = "Content", Position = UDim2.fromOffset(18, 129), Size = UDim2.new(1, -36, 1, -163), BackgroundTransparency = 1})
    self.PageHeading = create("Frame", self.Content, {Name = "PageHeading", BackgroundTransparency = 1})
    self.PageTitle = text(self.PageHeading, "Visão geral", 22, C.White, true); self.PageTitle.Position = UDim2.fromOffset(0, 5)
    self.PageDescription = text(self.PageHeading, "", 10, C.Gray); self.PageDescription.Position = UDim2.fromOffset(0, 33)
    self.SearchHolder = rounded(create("Frame", self.PageHeading, {Name = "Search", BackgroundColor3 = C.Surface, BorderSizePixel = 0}), 7, true)
    local searchIcon = text(self.SearchHolder, "⌕", 20, C.Gray, true); searchIcon.Size, searchIcon.Position, searchIcon.TextXAlignment = UDim2.fromOffset(30, 34), UDim2.fromOffset(3, 0), Enum.TextXAlignment.Center
    self.SearchBox = create("TextBox", self.SearchHolder, {Size = UDim2.new(1, -43, 1, 0), Position = UDim2.fromOffset(34, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Buscar nesta página...", PlaceholderColor3 = C.DarkGray, TextColor3 = C.White, Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left})
    self.Pages = create("Frame", self.Content, {Name = "Pages", BackgroundTransparency = 1})
    self.EmptySearch = text(self.Pages, "Nenhum recurso encontrado. Tente outro termo.", 12, C.Gray); self.EmptySearch.Size, self.EmptySearch.Visible, self.EmptySearch.TextXAlignment = UDim2.new(1, 0, 0, 80), false, Enum.TextXAlignment.Center
    local footer = create("Frame", self.Window, {Size = UDim2.new(1, -36, 0, 28), Position = UDim2.new(0, 18, 1, -29), BackgroundTransparency = 1})
    local status = text(footer, "●  " .. (subtitle or "Universal") .. "  /  @" .. Utils.LocalPlayer.Name, 9, C.Gray); status.Size = UDim2.new(0.7, 0, 1, 0)
    self.FooterHint = text(footer, "Right Ctrl  ·  ocultar", 9, C.DarkGray); self.FooterHint.Size, self.FooterHint.Position, self.FooterHint.TextXAlignment = UDim2.new(0.3, 0, 1, 0), UDim2.fromScale(0.7, 0), Enum.TextXAlignment.Right
    self.ToggleButton = rounded(create("TextButton", self.ScreenGui, {Name = "Reopen", Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(16, 100), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Text = "D", TextColor3 = C.White, Font = Enum.Font.GothamBold, TextSize = 24, Visible = false}), 10, true)
    connect(self, self.ToggleButton.MouseButton1Click, function() self:SetOpen(true) end)
    self.NotificationContainer = create("Frame", self.ScreenGui, {Size = UDim2.new(0.85, 0, 1, -36), Position = UDim2.new(1, -18, 0, 18), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1})
    create("UISizeConstraint", self.NotificationContainer, {MaxSize = Vector2.new(320, 10000)})
    list(self.NotificationContainer, 8)
    connect(self, UIS.InputBegan, function(input, processed) if not processed and input.KeyCode == Enum.KeyCode.RightControl then self:SetOpen(self.IsHidden) end end)
    connect(self, self.SearchBox:GetPropertyChangedSignal("Text"), function() self:_filter() end)
    local function bindCamera()
        if self.CameraConnection then self.CameraConnection:Disconnect() end
        if workspace.CurrentCamera then self.CameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() self:_responsive() end) end
        self:_responsive()
    end
    connect(self, workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
    bindCamera()
    self:CreateDashboard()
    return self
end

return Library
