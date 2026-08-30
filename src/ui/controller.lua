local Controller = {}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local C = {
    Base = Color3.fromRGB(15, 14, 18),
    Top = Color3.fromRGB(20, 18, 23),
    Side = Color3.fromRGB(22, 20, 25),
    Card = Color3.fromRGB(29, 27, 33),
    CardHover = Color3.fromRGB(37, 33, 41),
    Active = Color3.fromRGB(61, 28, 36),
    Border = Color3.fromRGB(54, 47, 58),
    Accent = Color3.fromRGB(210, 43, 67),
    AccentSoft = Color3.fromRGB(132, 34, 49),
    White = Color3.fromRGB(248, 245, 247),
    Text = Color3.fromRGB(216, 208, 214),
    Muted = Color3.fromRGB(150, 140, 147),
    Dim = Color3.fromRGB(96, 88, 95),
    Green = Color3.fromRGB(77, 205, 124)
}

local Glyphs = {
    Dashboard = "⌂", ["Combat/PvP"] = "◈", ["Visual/ESP"] = "◉",
    ["Utility/Misc"] = "◆", Settings = "⚙", ["Automação"] = "↻",
    Movimento = "➤", Visual = "◉", ["Mira"] = "◎", Chat = "◇",
    Servidor = "◫", Desenvolvedor = "⌘"
}

local function corner(object, radius)
    local value = object:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius)
    value.Parent = object
end

local function stroke(object, color, transparency)
    local value = object:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
    value.Color, value.Thickness, value.Transparency, value.Parent = color or C.Border, 1, transparency or 0, object
end

local function text(label, size, color, font)
    if not label or not label:IsA("TextLabel") then return end
    label.TextSize = size or label.TextSize
    label.TextColor3 = color or C.Text
    label.Font = font or Enum.Font.Gotham
end

local function viewport()
    return Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
end

local function styleGeometry(window)
    local size = viewport()
    local mobile = size.X < 720
    local compact = size.X < 1050
    local width = mobile and 0.96 or (compact and 0.88 or 0.74)
    local height = mobile and 0.88 or 0.79
    window.Window.Size = UDim2.new(width, 0, height, 0)
    local limit = window.Window:FindFirstChildOfClass("UISizeConstraint")
    if limit then limit.MinSize = mobile and Vector2.new(350, 300) or Vector2.new(620, 390); limit.MaxSize = Vector2.new(1180, 760) end
    local sidebarWidth = mobile and 138 or (compact and 172 or 196)
    local topHeight = mobile and 50 or 58
    window.TitleBar.Size = UDim2.new(1, 0, 0, topHeight)
    window.Sidebar.Position, window.Sidebar.Size = UDim2.new(0, 0, 0, topHeight), UDim2.new(0, sidebarWidth, 1, -topHeight)
    window.Content.Position, window.Content.Size = UDim2.new(0, sidebarWidth, 0, topHeight), UDim2.new(1, -sidebarWidth, 1, -topHeight)
end

local function styleTitlebar(window)
    local bar = window.TitleBar
    bar.BackgroundColor3 = C.Top
    local line = bar:FindFirstChild("HohoAccentLine") or Instance.new("Frame")
    line.Name, line.Size, line.Position, line.BackgroundColor3, line.BorderSizePixel, line.Parent = "HohoAccentLine", UDim2.new(1, 0, 0, 2), UDim2.new(0, 0, 1, -2), C.Accent, 0, bar
    local labels = {}
    for _, child in ipairs(bar:GetChildren()) do
        if child:IsA("TextLabel") then labels[#labels + 1] = child end
        if child:IsA("ImageLabel") then child.Size, child.Position = UDim2.fromOffset(26, 26), UDim2.new(0, 17, 0.5, -13) end
    end
    if labels[1] then labels[1].Text = "DEPHUB"; labels[1].TextColor3 = C.White; labels[1].Font = Enum.Font.GothamBold; labels[1].TextSize = 15 end
    if labels[2] then labels[2].TextColor3 = C.Muted; labels[2].Font = Enum.Font.GothamMedium; labels[2].TextSize = 10 end
end

local function styleSidebar(window)
    local side = window.Sidebar
    side.BackgroundColor3 = C.Side
    local divider = side:FindFirstChild("HohoSideLine") or Instance.new("Frame")
    divider.Name, divider.Size, divider.Position, divider.BackgroundColor3, divider.BorderSizePixel, divider.Parent = "HohoSideLine", UDim2.new(0, 1, 1, 0), UDim2.new(1, -1, 0, 0), C.Border, 0, side
    for _, child in ipairs(side:GetChildren()) do
        if child:IsA("ImageLabel") then child.Size, child.Position = UDim2.fromOffset(44, 44), UDim2.new(0.5, -22, 0, 18) end
        if child:IsA("TextLabel") then
            if child.Text == "NAVIGATION" or child.Text == "NAVEGAÇÃO" then child.Text = "PAGES"; text(child, 9, C.Dim, Enum.Font.GothamBold) else text(child, child.TextSize, C.Muted, child.Font) end
        end
    end
    if window.TabContainer then
        window.TabContainer.Position, window.TabContainer.Size = UDim2.new(0, 10, 0, 139), UDim2.new(1, -20, 1, -204)
        window.TabContainer.ScrollBarThickness = 0
        local layout = window.TabContainer:FindFirstChildOfClass("UIListLayout")
        if layout then layout.Padding = UDim.new(0, 5) end
    end
end

local function stylePage(tab)
    if not tab.Page then return end
    tab.Page.ScrollBarThickness, tab.Page.ScrollBarImageColor3 = 3, C.AccentSoft
    local padding = tab.Page:FindFirstChildOfClass("UIPadding")
    if padding then padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 20), UDim.new(0, 20), UDim.new(0, 18), UDim.new(0, 20) end
    local layout = tab.Page:FindFirstChildOfClass("UIListLayout")
    if layout then layout.Padding = UDim.new(0, 8) end
    if tab.TitleLabel then text(tab.TitleLabel, 22, C.White, Enum.Font.GothamBold) end
    if tab.DescriptionLabel then text(tab.DescriptionLabel, 11, C.Muted, Enum.Font.Gotham) end
end

local function styleTab(window, tab)
    if not tab or not tab.Button then return end
    local button = tab.Button
    button.Size, button.BackgroundColor3 = UDim2.new(1, 0, 0, 38), C.Active
    corner(button, 6)
    if tab.Indicator then tab.Indicator.Size, tab.Indicator.Position, tab.Indicator.BackgroundColor3 = UDim2.fromOffset(3, 20), UDim2.new(0, 0, 0.5, 0), C.Accent end
    if tab.Label then tab.Label.Text, tab.Label.Position, tab.Label.Size = tab.Name, UDim2.new(0, 36, 0, 0), UDim2.new(1, -42, 1, 0); text(tab.Label, 11, C.Muted, Enum.Font.GothamMedium) end
    if tab.IconLabel then tab.IconLabel.Size, tab.IconLabel.Position, tab.IconLabel.ImageColor3 = UDim2.fromOffset(15, 15), UDim2.new(0, 13, 0.5, -7), C.Muted else
        local glyph = button:FindFirstChild("HohoGlyph") or Instance.new("TextLabel")
        glyph.Name, glyph.Size, glyph.Position, glyph.BackgroundTransparency, glyph.TextXAlignment, glyph.Font, glyph.TextSize, glyph.Parent = "HohoGlyph", UDim2.fromOffset(20, 20), UDim2.new(0, 10, 0.5, -10), 1, Enum.TextXAlignment.Center, Enum.Font.GothamBold, 13, button
        glyph.Text, glyph.TextColor3 = Glyphs[tab.Name] or "•", C.Muted
    end
    stylePage(tab)
end

local function styleCards(tab)
    if not tab or not tab.Page then return end
    for _, child in ipairs(tab.Page:GetChildren()) do
        if child:IsA("Frame") then
            child.BackgroundColor3 = C.Card
            corner(child, 7)
            stroke(child, C.Border, 0.25)
            for _, descendant in ipairs(child:GetDescendants()) do
                if descendant:IsA("TextLabel") then
                    if descendant.Font == Enum.Font.GothamBold then text(descendant, descendant.TextSize, C.White, descendant.Font) else text(descendant, descendant.TextSize, C.Muted, descendant.Font) end
                elseif descendant:IsA("TextButton") and descendant.BackgroundTransparency < 1 then
                    descendant.BackgroundColor3 = C.Active
                end
            end
        end
    end
end

local function updateTabState(window)
    for _, tab in ipairs(window.Tabs or {}) do
        local active = window.CurrentTab == tab.Name
        if tab.Label then tab.Label.TextColor3 = active and C.White or C.Muted end
        if tab.IconLabel then tab.IconLabel.ImageColor3 = active and C.Accent or C.Muted end
        local glyph = tab.Button and tab.Button:FindFirstChild("HohoGlyph")
        if glyph then glyph.TextColor3 = active and C.Accent or C.Muted end
    end
end

local function installSearch(window)
    if window.__HohoSearch or not window.TitleBar then return end
    window.__HohoSearch = true
    local holder = Instance.new("Frame")
    holder.Name, holder.Size, holder.Position, holder.AnchorPoint, holder.BackgroundColor3, holder.BorderSizePixel, holder.Parent = "FeatureSearch", UDim2.fromOffset(210, 32), UDim2.new(0.72, 0, 0.5, 0), Vector2.new(0.5, 0.5), C.Card, 0, window.TitleBar
    corner(holder, 6); stroke(holder, C.Border, 0.2)
    local icon = Instance.new("TextLabel")
    icon.Size, icon.Position, icon.BackgroundTransparency, icon.Text, icon.TextColor3, icon.Font, icon.TextSize, icon.Parent = UDim2.fromOffset(24, 32), UDim2.new(0, 6, 0, 0), 1, "⌕", C.Muted, Enum.Font.GothamBold, 15, holder
    local box = Instance.new("TextBox")
    box.Size, box.Position, box.BackgroundTransparency, box.Text, box.PlaceholderText, box.PlaceholderColor3, box.TextColor3, box.Font, box.TextSize, box.ClearTextOnFocus, box.Parent = UDim2.new(1, -38, 1, 0), UDim2.new(0, 32, 0, 0), 1, "", "Search features...", C.Dim, C.Text, Enum.Font.Gotham, 11, false, holder
    local function filter()
        local query = string.lower(box.Text)
        local tab = window.TabButtons and window.TabButtons[window.CurrentTab]
        if not tab or not tab.Page then return end
        for _, child in ipairs(tab.Page:GetChildren()) do
            if child:IsA("GuiObject") and child ~= tab.TitleLabel and child ~= tab.DescriptionLabel then
                local haystack = ""
                for _, item in ipairs(child:GetDescendants()) do if item:IsA("TextLabel") or item:IsA("TextButton") then haystack = haystack .. " " .. item.Text end end
                child.Visible = query == "" or string.find(string.lower(haystack), query, 1, true) ~= nil
            end
        end
    end
    box:GetPropertyChangedSignal("Text"):Connect(filter)
end

local function styleAll(window)
    if not window or window.Destroyed or not window.Window then return end
    window.Window.BackgroundColor3 = C.Base
    corner(window.Window, 8); stroke(window.Window, C.Border, 0.05)
    styleGeometry(window); styleTitlebar(window); styleSidebar(window); installSearch(window)
    if window.Content then window.Content.BackgroundColor3 = C.Base end
    for _, tab in ipairs(window.Tabs or {}) do styleTab(window, tab); styleCards(tab) end
    updateTabState(window)
    if window.ToggleButton then window.ToggleButton.BackgroundColor3 = C.Top; window.ToggleButton.Size = UDim2.fromOffset(48, 48); corner(window.ToggleButton, 8); stroke(window.ToggleButton, C.Accent, 0.1) end
end

local function patch(window)
    if window.__HohoPatched then return end
    window.__HohoPatched = true
    local createTab, selectTab, releases, destroy = window.CreateTab, window.SelectTab, window.SetReleases, window.Destroy
    window.CreateTab = function(self, ...)
        local tab = createTab(self, ...)
        styleTab(self, tab)
        task.defer(function() styleCards(tab); styleAll(self) end)
        return tab
    end
    window.SelectTab = function(self, ...)
        local result = selectTab(self, ...)
        updateTabState(self)
        task.defer(function() updateTabState(self) end)
        return result
    end
    window.SetReleases = function(self, ...)
        local result = releases(self, ...)
        styleCards(self.DashboardTab)
        return result
    end
    window.Destroy = function(self, ...)
        if self.Destroyed then return end
        self.Destroyed = true
        return destroy(self, ...)
    end
    local camera = Workspace.CurrentCamera
    if camera then window.Connections[#window.Connections + 1] = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if not window.Destroyed then styleGeometry(window) end end) end
end

function Controller.Enhance(window)
    if not window then return window end
    patch(window)
    styleAll(window)
    return window
end

return Controller
