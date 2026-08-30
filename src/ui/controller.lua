local Controller = {}

local game = game
local task = task
local type = type
local tostring = tostring
local pcall = pcall
local ipairs = ipairs
local pairs = pairs
local math_clamp = math.clamp
local math_max = math.max

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Color3_fromRGB = Color3.fromRGB
local UDim2_new = UDim2.new
local UDim2_fromOffset = UDim2.fromOffset
local UDim_new = UDim.new
local Vector2_new = Vector2.new
local Instance_new = Instance.new

local Palette = {
    Background = Color3_fromRGB(7, 8, 10),
    BackgroundSoft = Color3_fromRGB(9, 10, 12),
    Sidebar = Color3_fromRGB(9, 10, 12),
    Titlebar = Color3_fromRGB(4, 5, 6),
    Card = Color3_fromRGB(14, 15, 18),
    CardHover = Color3_fromRGB(20, 21, 25),
    Active = Color3_fromRGB(31, 33, 38),
    Border = Color3_fromRGB(39, 41, 47),
    BorderSoft = Color3_fromRGB(31, 33, 38),
    White = Color3_fromRGB(245, 245, 247),
    Text = Color3_fromRGB(214, 215, 220),
    Muted = Color3_fromRGB(145, 147, 156),
    Dim = Color3_fromRGB(91, 93, 101),
    Accent = Color3_fromRGB(112, 126, 255),
    Success = Color3_fromRGB(82, 203, 117)
}

local TabGlyphs = {
    Dashboard = "▦",
    ["Combat/PvP"] = "⚔",
    ["Visual/ESP"] = "◉",
    ["Utility/Misc"] = "◆",
    Settings = "⚙",
    ["Automação"] = "◆"
}

local function addConnection(window, connection)
    if not connection then
        return connection
    end

    window.Connections = window.Connections or {}
    window.Connections[#window.Connections + 1] = connection
    return connection
end

local function applyCorner(instance, radius)
    local corner = instance:FindFirstChildOfClass("UICorner")
    if not corner then
        corner = Instance_new("UICorner")
        corner.Parent = instance
    end
    corner.CornerRadius = UDim_new(0, radius)
    return corner
end

local function applyStroke(instance, color, transparency, thickness)
    local stroke = instance:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance_new("UIStroke")
        stroke.Parent = instance
    end
    stroke.Color = color
    stroke.Transparency = transparency
    stroke.Thickness = thickness or 1
    return stroke
end

local function directChildrenOfClass(parent, className)
    local result = {}
    if not parent then
        return result
    end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA(className) then
            result[#result + 1] = child
        end
    end
    return result
end

local function findDirectText(parent, text)
    if not parent then
        return nil
    end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextLabel") and child.Text == text then
            return child
        end
    end
    return nil
end

local function setTextStyle(label, size, color, font, alignment)
    if not label then
        return
    end
    label.TextSize = size
    label.TextColor3 = color
    label.Font = font
    if alignment then
        label.TextXAlignment = alignment
    end
end

local function getViewport()
    local camera = Workspace.CurrentCamera
    if not camera then
        return Vector2_new(1280, 720)
    end
    return camera.ViewportSize
end

local function applyWindowGeometry(window)
    if window.Destroyed or not window.Window or not window.Sidebar or not window.Content or not window.TitleBar then
        return
    end

    local main = window.Window
    local viewport = getViewport()
    local widthScale
    local heightScale

    if viewport.X <= 620 then
        widthScale = 0.94
        heightScale = 0.84
    elseif viewport.X <= 1000 then
        widthScale = 0.88
        heightScale = 0.82
    else
        widthScale = 0.72
        heightScale = 0.78
    end

    if main.Size.X.Scale ~= 0 and main.Size.Y.Scale ~= 0 then
        main.Size = UDim2_new(widthScale, 0, heightScale, 0)
    end

    local estimatedWidth = math_max(viewport.X * widthScale, 500)
    local sidebarWidth = math_clamp(estimatedWidth * 0.235, 185, 255)
    local titlebarHeight = 54

    window.TitleBar.Size = UDim2_new(1, 0, 0, titlebarHeight)
    window.Sidebar.Size = UDim2_new(0, sidebarWidth, 1, -titlebarHeight)
    window.Sidebar.Position = UDim2_new(0, 0, 0, titlebarHeight)
    window.Content.Size = UDim2_new(1, -sidebarWidth, 1, -titlebarHeight)
    window.Content.Position = UDim2_new(0, sidebarWidth, 0, titlebarHeight)
end

local function styleTitlebar(window)
    local titlebar = window.TitleBar
    if not titlebar then
        return
    end

    titlebar.BackgroundColor3 = Palette.Titlebar

    local logo
    local labels = {}
    for _, child in ipairs(titlebar:GetChildren()) do
        if child:IsA("ImageLabel") and not logo then
            logo = child
        elseif child:IsA("TextLabel") then
            labels[#labels + 1] = child
        elseif child:IsA("Frame") and child.AbsoluteSize.Y <= 2 then
            child.BackgroundColor3 = Palette.Border
        end
    end

    if logo then
        logo.Size = UDim2_fromOffset(28, 28)
        logo.Position = UDim2_new(0, 18, 0.5, 0)
        logo.AnchorPoint = Vector2_new(0, 0.5)
    end

    for _, label in ipairs(labels) do
        if label.Text == string.upper(window.HubName or "HUB") then
            label.Position = UDim2_new(0, 58, 0, 0)
            label.Size = UDim2_new(0, 100, 1, 0)
            setTextStyle(label, 14, Palette.White, Enum.Font.GothamBold)
        elseif label.Text == string.upper(window.Subtitle or "GAME SYSTEM") then
            label.Position = UDim2_new(0, 154, 0, 0)
            label.Size = UDim2_new(0, 220, 1, 0)
            setTextStyle(label, 11, Palette.Muted, Enum.Font.GothamMedium)
        end
    end
end

local function styleSidebar(window)
    local sidebar = window.Sidebar
    if not sidebar then
        return
    end

    sidebar.BackgroundColor3 = Palette.Sidebar

    local oldDivider = sidebar:FindFirstChild("DepHubSidebarDivider")
    if oldDivider then
        oldDivider:Destroy()
    end

    local divider = Instance_new("Frame")
    divider.Name = "DepHubSidebarDivider"
    divider.Size = UDim2_new(0, 1, 1, 0)
    divider.Position = UDim2_new(1, -1, 0, 0)
    divider.BackgroundColor3 = Palette.BorderSoft
    divider.BorderSizePixel = 0
    divider.Parent = sidebar

    local directImages = directChildrenOfClass(sidebar, "ImageLabel")
    local logo = directImages[1]
    if logo then
        logo.Size = UDim2_fromOffset(56, 56)
        logo.Position = UDim2_new(0.5, 0, 0, 22)
        logo.AnchorPoint = Vector2_new(0.5, 0)
    end

    local brand = findDirectText(sidebar, string.upper(window.HubName or "HUB"))
    local subtitle = findDirectText(sidebar, string.upper(window.Subtitle or "GAME SYSTEM"))
    local navigation = findDirectText(sidebar, "NAVIGATION")

    if brand then
        brand.Position = UDim2_new(0, 18, 0, 84)
        brand.Size = UDim2_new(1, -36, 0, 22)
        setTextStyle(brand, 16, Palette.White, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    end

    if subtitle then
        subtitle.Position = UDim2_new(0, 18, 0, 108)
        subtitle.Size = UDim2_new(1, -36, 0, 18)
        setTextStyle(subtitle, 11, Palette.Muted, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
    end

    if navigation then
        navigation.Text = "NAVEGAÇÃO"
        navigation.Position = UDim2_new(0, 18, 0, 143)
        navigation.Size = UDim2_new(1, -36, 0, 18)
        setTextStyle(navigation, 9, Palette.Dim, Enum.Font.GothamBold)
    end

    if window.TabContainer then
        window.TabContainer.Position = UDim2_new(0, 14, 0, 170)
        window.TabContainer.Size = UDim2_new(1, -28, 1, -242)
        window.TabContainer.ScrollBarImageColor3 = Palette.Border
        local layout = window.TabContainer:FindFirstChildOfClass("UIListLayout")
        if layout then
            layout.Padding = UDim_new(0, 9)
        end
    end

    for _, child in ipairs(sidebar:GetChildren()) do
        if child:IsA("Frame") and child ~= divider and child ~= window.TabContainer then
            local status = child:FindFirstChildOfClass("UICorner")
            local hasText = child:FindFirstChildOfClass("TextLabel")
            if status and hasText and child.Size.Y.Offset <= 60 then
                child.Size = UDim2_new(1, -28, 0, 46)
                child.Position = UDim2_new(0, 14, 1, -60)
                child.BackgroundColor3 = Palette.Card
                applyCorner(child, 9)
                applyStroke(child, Palette.Border, 0.35, 1)
                local labels = directChildrenOfClass(child, "TextLabel")
                for _, label in ipairs(labels) do
                    setTextStyle(label, 11, Palette.Muted, Enum.Font.GothamMedium)
                end
            end
        end
    end
end

local function styleTab(window, tab)
    if not tab or not tab.Button then
        return
    end

    local button = tab.Button
    button.Size = UDim2_new(1, 0, 0, 48)
    button.BackgroundColor3 = Palette.Active
    applyCorner(button, 8)

    if tab.Indicator then
        tab.Indicator.Size = UDim2_fromOffset(3, 24)
        tab.Indicator.Position = UDim2_new(0, 0, 0.5, 0)
        tab.Indicator.BackgroundColor3 = Palette.White
    end

    if tab.Label then
        tab.Label.Text = tab.Name
        tab.Label.Position = UDim2_new(0, 44, 0, 0)
        tab.Label.Size = UDim2_new(1, -54, 1, 0)
        setTextStyle(tab.Label, 13, Palette.Muted, Enum.Font.GothamMedium)
    end

    if tab.IconLabel then
        tab.IconLabel.Size = UDim2_fromOffset(18, 18)
        tab.IconLabel.Position = UDim2_new(0, 16, 0.5, 0)
        tab.IconLabel.ImageColor3 = Palette.Muted
    else
        local glyph = button:FindFirstChild("DepHubTabGlyph")
        if not glyph then
            glyph = Instance_new("TextLabel")
            glyph.Name = "DepHubTabGlyph"
            glyph.BackgroundTransparency = 1
            glyph.Size = UDim2_fromOffset(24, 24)
            glyph.Position = UDim2_new(0, 12, 0.5, 0)
            glyph.AnchorPoint = Vector2_new(0, 0.5)
            glyph.TextXAlignment = Enum.TextXAlignment.Center
            glyph.TextYAlignment = Enum.TextYAlignment.Center
            glyph.Font = Enum.Font.GothamMedium
            glyph.TextSize = 15
            glyph.Parent = button
        end
        glyph.Text = TabGlyphs[tab.Name] or "◇"
        glyph.TextColor3 = window.CurrentTab == tab.Name and Palette.White or Palette.Muted
    end

    if tab.Page then
        tab.Page.ScrollBarImageColor3 = Palette.Border
        local padding = tab.Page:FindFirstChildOfClass("UIPadding")
        if padding then
            padding.PaddingLeft = UDim_new(0, 28)
            padding.PaddingRight = UDim_new(0, 28)
            padding.PaddingTop = UDim_new(0, 28)
            padding.PaddingBottom = UDim_new(0, 28)
        end

        if tab.TitleLabel then
            setTextStyle(tab.TitleLabel, 26, Palette.White, Enum.Font.GothamBold)
        end

        if tab.DescriptionLabel then
            setTextStyle(tab.DescriptionLabel, 12, Palette.Muted, Enum.Font.Gotham)
        end
    end
end

local function styleStatCard(stat, success)
    if not stat or not stat.Card then
        return
    end

    local card = stat.Card
    card.BackgroundColor3 = Palette.Card
    applyCorner(card, 9)
    applyStroke(card, Palette.Border, 0.32, 1)

    local labels = directChildrenOfClass(card, "TextLabel")
    local title = labels[1]
    local value = labels[2]

    if title then
        title.Size = UDim2_new(1, -20, 0, 18)
        title.Position = UDim2_new(0, 10, 0, 13)
        setTextStyle(title, 10, Palette.Muted, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
    end

    if value then
        value.Size = UDim2_new(1, -20, 0, 30)
        value.Position = UDim2_new(0, 10, 0, 39)
        setTextStyle(value, 17, success and Palette.Success or Palette.White, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    end
end

local function styleDashboard(window)
    local stats = window.DashboardStats
    if not stats or not stats.Player or not stats.Player.Card then
        return
    end

    local grid = stats.Player.Card.Parent
    if grid and grid:IsA("Frame") then
        grid.Size = UDim2_new(1, 0, 0, 96)
        local layout = grid:FindFirstChildOfClass("UIGridLayout")
        if layout then
            layout.CellSize = UDim2_new(0.25, -8, 0, 94)
            layout.CellPadding = UDim2_new(0, 10, 0, 0)
        end
    end

    styleStatCard(stats.Player, false)
    styleStatCard(stats.Status, true)
    styleStatCard(stats.Version, false)
    styleStatCard(stats.Ping, false)

    if stats.Player.Card and not stats.Player.Card:FindFirstChild("DepHubAvatar") then
        local avatar = Instance_new("ImageLabel")
        avatar.Name = "DepHubAvatar"
        avatar.Size = UDim2_fromOffset(32, 32)
        avatar.Position = UDim2_new(0, 12, 0.5, 8)
        avatar.AnchorPoint = Vector2_new(0, 0.5)
        avatar.BackgroundTransparency = 1
        avatar.ScaleType = Enum.ScaleType.Crop
        avatar.Parent = stats.Player.Card
        applyCorner(avatar, 100)

        local labels = directChildrenOfClass(stats.Player.Card, "TextLabel")
        if labels[2] then
            labels[2].Position = UDim2_new(0, 48, 0, 39)
            labels[2].Size = UDim2_new(1, -58, 0, 30)
            labels[2].TextXAlignment = Enum.TextXAlignment.Left
        end

        task.spawn(function()
            local ok, image = pcall(function()
                return Players:GetUserThumbnailAsync(
                    LocalPlayer.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size100x100
                )
            end)
            if ok and image and avatar.Parent and not window.Destroyed then
                avatar.Image = image
            end
        end)
    end
end

local function styleReleases(window)
    local holder = window.ReleasesHolder
    if not holder then
        return
    end

    for _, child in ipairs(holder:GetChildren()) do
        if child:IsA("Frame") then
            child.BackgroundColor3 = Palette.Card
            applyCorner(child, 9)
            applyStroke(child, Palette.Border, 0.32, 1)

            for _, nested in ipairs(child:GetChildren()) do
                if nested:IsA("Frame") and nested.Size.X.Offset <= 4 and nested.Size.Y.Offset > 0 then
                    nested.BackgroundColor3 = Palette.Accent
                    nested.BackgroundTransparency = 0.1
                    nested.Size = UDim2_new(0, 3, 1, -20)
                    nested.Position = UDim2_new(0, 0, 0, 10)
                elseif nested:IsA("TextLabel") then
                    setTextStyle(nested, 14, Palette.White, Enum.Font.GothamBold)
                end
            end

            for _, descendant in ipairs(child:GetDescendants()) do
                if descendant:IsA("TextLabel") and descendant.Parent ~= child then
                    setTextStyle(descendant, 12, Palette.Text, Enum.Font.Gotham)
                end
            end
        end
    end
end

local function styleContent(window)
    if not window.Content then
        return
    end

    window.Content.BackgroundColor3 = Palette.Background

    local gradient = window.Content:FindFirstChild("DepHubContentGradient")
    if not gradient then
        gradient = Instance_new("UIGradient")
        gradient.Name = "DepHubContentGradient"
        gradient.Rotation = 90
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Palette.BackgroundSoft),
            ColorSequenceKeypoint.new(1, Palette.Background)
        })
        gradient.Parent = window.Content
    end
end

local function styleToggle(window)
    local toggle = window.ToggleButton
    if not toggle or not toggle:IsA("GuiObject") then
        return
    end

    toggle.Size = UDim2_fromOffset(54, 54)
    toggle.Position = UDim2_fromOffset(22, 22)
    toggle.AnchorPoint = Vector2_new(0, 0)
    toggle.BackgroundColor3 = Palette.Titlebar
    toggle.Visible = true
    applyCorner(toggle, 100)
    applyStroke(toggle, Palette.Border, 0.15, 1)

    local logo = toggle:FindFirstChildOfClass("ImageLabel")
    if logo then
        logo.Size = UDim2_fromOffset(28, 28)
        logo.Position = UDim2_new(0.5, 0, 0.5, 0)
        logo.AnchorPoint = Vector2_new(0.5, 0.5)
    end
end

local function refreshTabState(window)
    for _, tab in ipairs(window.Tabs or {}) do
        local active = window.CurrentTab == tab.Name
        if tab.Label then
            tab.Label.TextColor3 = active and Palette.White or Palette.Muted
        end
        if tab.IconLabel then
            tab.IconLabel.ImageColor3 = active and Palette.White or Palette.Muted
        end
        local glyph = tab.Button and tab.Button:FindFirstChild("DepHubTabGlyph")
        if glyph then
            glyph.TextColor3 = active and Palette.White or Palette.Muted
        end
    end
end

local function styleAll(window)
    if not window or window.Destroyed then
        return
    end

    if window.Window then
        window.Window.BackgroundColor3 = Palette.Background
        applyCorner(window.Window, 10)
        applyStroke(window.Window, Palette.Border, 0.1, 1)
    end

    applyWindowGeometry(window)
    styleTitlebar(window)
    styleSidebar(window)
    styleContent(window)
    styleToggle(window)

    for _, tab in ipairs(window.Tabs or {}) do
        styleTab(window, tab)
    end

    styleDashboard(window)
    styleReleases(window)
    refreshTabState(window)
end

local function patchLifecycle(window)
    if window.__DEPHUBVisualPatched then
        return
    end

    window.__DEPHUBVisualPatched = true

    local originalCreateTab = window.CreateTab
    local originalSelectTab = window.SelectTab
    local originalSetReleases = window.SetReleases
    local originalDestroy = window.Destroy

    window.CreateTab = function(self, ...)
        local tab = originalCreateTab(self, ...)
        styleTab(self, tab)
        task.defer(function()
            styleAll(self)
        end)
        return tab
    end

    window.SelectTab = function(self, ...)
        local result = originalSelectTab(self, ...)
        refreshTabState(self)
        task.defer(function()
            refreshTabState(self)
        end)
        return result
    end

    window.SetReleases = function(self, ...)
        local result = originalSetReleases(self, ...)
        styleReleases(self)
        return result
    end

    window.Destroy = function(self, ...)
        if self.Destroyed then
            return
        end
        self.Destroyed = true
        return originalDestroy(self, ...)
    end
end

local function bindResponsive(window)
    if window.__DEPHUBVisualResponsiveBound then
        return
    end

    window.__DEPHUBVisualResponsiveBound = true

    local camera = Workspace.CurrentCamera
    if camera then
        addConnection(window, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if not window.Destroyed then
                applyWindowGeometry(window)
            end
        end))
    end
end

function Controller.Enhance(window)
    if not window or window.Destroyed then
        return window
    end

    patchLifecycle(window)
    bindResponsive(window)
    styleAll(window)

    return window
end

return Controller
