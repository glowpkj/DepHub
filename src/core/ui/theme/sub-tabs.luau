--[[
  SUB-TAB MODULE

  Split out of src/core/ui/demon-theme.luau (original lines 642-872).
  The body below is the original section, unchanged except for the shared
  reduced-motion flag (ctx.SharedReduced.value). The orchestrator loads this
  part with a shared context; it adds methods to the one Library table.
]]
local __CTX = ...
local SharedReduced = __CTX.SharedReduced
local Library = __CTX.Library
local D = __CTX.D
local Fn = __CTX.Fn
local GetIcon = __CTX.GetIcon
local getCam = __CTX.getCam
local GetGuiParent = __CTX.GetGuiParent
local findInGuiParents = __CTX.findInGuiParents
local GuiParent = __CTX.GuiParent
local TweenService = __CTX.TweenService
local GuiSound = __CTX.GuiSound
local Players = __CTX.Players
local RunService = __CTX.RunService
local MarketplaceService = __CTX.MarketplaceService
local Stats = __CTX.Stats
local UserInputService = __CTX.UserInputService
local CoreGui = __CTX.CoreGui
local Lighting = __CTX.Lighting
local SoundService = __CTX.SoundService
local LocalPlayer = __CTX.LocalPlayer
local IconsV2 = __CTX.IconsV2
local WEATHER_PRESETS = __CTX.WEATHER_PRESETS
local randomFloat = __CTX.randomFloat

-- =========================================================
-- SUB-TAB MODULE
-- =========================================================

local SubTabModule = {}
SubTabModule.__index = SubTabModule

local SUBTAB_DEFAULT_THEME = {
    PillBg       = Color3.fromRGB(34, 34, 44),
    LeftAccent   = Color3.fromRGB(160, 160, 185),
    TextActive   = Color3.fromRGB(255, 255, 255),
    TextInactive = Color3.fromRGB(130, 130, 145),
    FontActive   = Enum.Font.GothamBold,
    FontInactive = Enum.Font.GothamMedium,
}

function SubTabModule.new(config)
    local self = setmetatable({}, SubTabModule)
    self.Parent = config.Parent
    self.Owner = config.Owner
    self.Data = config.Data or {}
    self.OnChanged = config.OnChanged or function() end
    self.Theme = config.Theme or SUBTAB_DEFAULT_THEME
    self.CurrentMainCategory = nil
    self.ActiveSubIndices = {}
    self.Groups = {}
    self.TabWidth = config.TabWidth or 96
    self.TabHeight = config.TabHeight or 28
    self.Padding = config.Padding or 6
    self:_init()
    return self
end

function SubTabModule:_init()
    self.Wrapper = Instance.new("Frame", self.Parent)
    self.Wrapper.Name = "SubTabWrapper"
    self.Wrapper.Size = UDim2.new(1, 0, 1, 0)
    self.Wrapper.BackgroundTransparency = 1
    for mainCategory, subList in pairs(self.Data) do
        self:_createSubGroup(mainCategory, subList)
    end
end

function SubTabModule:_createSubGroup(mainCategory, subList)
    local group = Instance.new("CanvasGroup", self.Wrapper)
    group.Name = "SubGroup_" .. tostring(mainCategory)
    group.Size = UDim2.new(1, 0, 1, 0)
    group.BackgroundTransparency = 1
    group.GroupTransparency = 1
    group.Visible = false

    local indicator = Instance.new("Frame", group)
    indicator.Name = "SlidingIndicator"
    indicator.Size = UDim2.new(0, self.TabWidth, 0, self.TabHeight)
    indicator.Position = UDim2.new(0, 0, 0.5, -self.TabHeight / 2)
    indicator.BackgroundColor3 = self.Theme.PillBg
    indicator.BorderSizePixel = 0
    indicator.ZIndex = 1
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 6)

    local accentLine = Instance.new("Frame", indicator)
    accentLine.Name = "LeftAccentBar"
    accentLine.Size = UDim2.new(0, 3, 0, 12)
    accentLine.Position = UDim2.new(0, 6, 0.5, -6)
    accentLine.BackgroundColor3 = self.Theme.LeftAccent
    accentLine.BorderSizePixel = 0
    Instance.new("UICorner", accentLine).CornerRadius = UDim.new(1, 0)

    local subElements = {}
    self.ActiveSubIndices[mainCategory] = 1

    for i, subName in ipairs(subList) do
        local btn = Instance.new("TextButton", group)
        btn.Name = "SubBtn_" .. tostring(subName)
        btn.Size = UDim2.new(0, self.TabWidth, 0, self.TabHeight)
        btn.Position = UDim2.new(0, (i - 1) * (self.TabWidth + self.Padding), 0.5, -self.TabHeight / 2)
        btn.BackgroundTransparency = 1
        btn.Text = tostring(subName)
        btn.TextColor3 = (i == 1) and self.Theme.TextActive or self.Theme.TextInactive
        btn.Font = (i == 1) and self.Theme.FontActive or self.Theme.FontInactive
        btn.TextSize = 12
        btn.TextTruncate = Enum.TextTruncate.AtEnd
        btn.AutoButtonColor = false
        btn.ZIndex = 2
        subElements[i] = btn
        Fn.bindPressAnimation(btn)

        btn.MouseEnter:Connect(function()
            if self.Owner then self.Owner:PlaySound("Hover") end
            if self.ActiveSubIndices[mainCategory] ~= i then
                TweenService:Create(btn, TweenInfo.new(0.18), {
                    TextColor3 = self.Theme.TextActive or Color3.fromRGB(255, 255, 255)
                }):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if self.ActiveSubIndices[mainCategory] ~= i then
                TweenService:Create(btn, TweenInfo.new(0.18), {TextColor3 = self.Theme.TextInactive}):Play()
            end
        end)

        btn.MouseButton1Click:Connect(function()
            local currentActiveIdx = self.ActiveSubIndices[mainCategory]
            if currentActiveIdx == i then return end
            if self.Owner then self.Owner:PlaySound("TabSwitch") end
            local prevBtn = subElements[currentActiveIdx]
            self.ActiveSubIndices[mainCategory] = i
            local targetX = (i - 1) * (self.TabWidth + self.Padding)
            TweenService:Create(indicator, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, targetX, 0.5, -self.TabHeight / 2)
            }):Play()
            if prevBtn then
                TweenService:Create(prevBtn, TweenInfo.new(0.18), {TextColor3 = self.Theme.TextInactive}):Play()
                prevBtn.Font = self.Theme.FontInactive
            end
            TweenService:Create(btn, TweenInfo.new(0.18), {TextColor3 = self.Theme.TextActive}):Play()
            btn.Font = self.Theme.FontActive
            self.OnChanged(mainCategory, subName)
        end)
    end

    self.Groups[mainCategory] = {
        Group = group,
        Indicator = indicator,
        Buttons = subElements,
    }
end

function SubTabModule:SwitchCategory(newCategory)
    if self.CurrentMainCategory == newCategory then return end
    if not self.Groups[newCategory] then return end
    local oldCategory = self.CurrentMainCategory
    self.CurrentMainCategory = newCategory
    if oldCategory and self.Groups[oldCategory] then
        local oldGroup = self.Groups[oldCategory].Group
        self._switchToken = {}
        local token = self._switchToken
        TweenService:Create(oldGroup, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            GroupTransparency = 1
        }):Play()
        task.delay(0.15, function()
            -- Guard against A->B->A within 150ms hiding the group that is now active.
            if self._switchToken ~= token then return end
            if self.CurrentMainCategory ~= oldCategory then
                oldGroup.Visible = false
            end
        end)
    end
    local newGroupData = self.Groups[newCategory]
    local newGroup = newGroupData.Group
    newGroup.Visible = true
    newGroup.GroupTransparency = 1
    TweenService:Create(newGroup, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        GroupTransparency = 0
    }):Play()
    local activeSubIdx = self.ActiveSubIndices[newCategory] or 1
    local activeSubName = self.Data[newCategory] and self.Data[newCategory][activeSubIdx]
    if activeSubName then self.OnChanged(newCategory, activeSubName) end
end

function SubTabModule:SetActiveSub(category, subName)
    local group = self.Groups[category]
    if not group then return end
    for i, btn in ipairs(group.Buttons) do
        if btn.Text == tostring(subName) then
            local prev = self.ActiveSubIndices[category]
            if prev == i then return end
            self.ActiveSubIndices[category] = i
            if group.Buttons[prev] then
                TweenService:Create(group.Buttons[prev], TweenInfo.new(0.18), {
                    TextColor3 = self.Theme.TextInactive
                }):Play()
                group.Buttons[prev].Font = self.Theme.FontInactive
            end
            TweenService:Create(btn, TweenInfo.new(0.18), {
                TextColor3 = self.Theme.TextActive
            }):Play()
            btn.Font = self.Theme.FontActive
            TweenService:Create(group.Indicator, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, (i - 1) * (self.TabWidth + self.Padding), 0.5, -self.TabHeight / 2)
            }):Play()
            return
        end
    end
end

function SubTabModule:Resize(tabWidth, padding)
    if tabWidth <= 0 then return end
    self.TabWidth = tabWidth
    if padding then self.Padding = padding end
    for category, groupData in pairs(self.Groups) do
        groupData.Indicator.Size = UDim2.new(0, tabWidth, 0, self.TabHeight)
        for index, button in ipairs(groupData.Buttons) do
            button.Size = UDim2.new(0, tabWidth, 0, self.TabHeight)
            button.Position = UDim2.new(0, (index - 1) * (tabWidth + self.Padding), 0.5, -self.TabHeight / 2)
        end
        local activeIndex = self.ActiveSubIndices[category] or 1
        groupData.Indicator.Position = UDim2.new(
            0, (activeIndex - 1) * (tabWidth + self.Padding), 0.5, -self.TabHeight / 2
        )
    end
end

function SubTabModule:RefreshTheme(newTheme)
    if newTheme then self.Theme = newTheme end
    for cat, groupData in pairs(self.Groups) do
        groupData.Indicator.BackgroundColor3 = self.Theme.PillBg
        local accent = groupData.Indicator:FindFirstChild("LeftAccentBar")
        if accent then accent.BackgroundColor3 = self.Theme.LeftAccent end
        for i, btn in ipairs(groupData.Buttons) do
            if self.ActiveSubIndices[cat] == i then
                btn.TextColor3 = self.Theme.TextActive
                btn.Font = self.Theme.FontActive
            else
                btn.TextColor3 = self.Theme.TextInactive
                btn.Font = self.Theme.FontInactive
            end
        end
    end
end

function SubTabModule:Destroy()
    if self.Wrapper then
        self.Wrapper:Destroy()
        self.Wrapper = nil
    end
    table.clear(self.Groups)
    table.clear(self.ActiveSubIndices)
    self.CurrentMainCategory = nil
end


__CTX.SubTabModule = SubTabModule
__CTX.SUBTAB_DEFAULT_THEME = SUBTAB_DEFAULT_THEME
return true
