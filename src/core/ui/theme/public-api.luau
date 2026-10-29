--[[
  PUBLIC API (CreateCategory/Tab/Section and label helpers)

  Split out of src/core/ui/demon-theme.luau (original lines 6505-8621).
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
local SubTabModule = __CTX.SubTabModule
local SUBTAB_DEFAULT_THEME = __CTX.SUBTAB_DEFAULT_THEME

-- =========================================================
-- PUBLIC API: CREATE CATEGORY / TAB / SECTION
-- =========================================================

function Library:CreateCategory(categoryName, iconSpec)
    if self:_isDead() then return end
    if type(categoryName) ~= "string" or categoryName == "" then
        error("[DoD UI] CreateCategory requires a non-empty category name.")
    end
    if iconSpec ~= nil and type(iconSpec) ~= "string" then
        error("[DoD UI] CreateCategory iconSpec must be a string or nil.")
    end
    local UI = self._UI
    local STATE = self._STATE
    if STATE.CategoryButtons and STATE.CategoryButtons[categoryName] then
        error("[DoD UI] Category '" .. categoryName .. "' already exists.")
    end
    STATE.CategoryTabs[categoryName] = STATE.CategoryTabs[categoryName] or {}
    STATE.CategoryOrder = STATE.CategoryOrder or {}
    STATE.CategoryButtons = STATE.CategoryButtons or {}
    if not STATE.CategoryButtons[categoryName] then
        table.insert(STATE.CategoryOrder, categoryName)
    end

    if self.TabPosition == "Side" and UI.AccordionScroll then
        local group = Instance.new("Frame", UI.AccordionScroll)
        group.Name = "AccGroup_" .. categoryName
        group.LayoutOrder = #STATE.CategoryOrder
        group.Size = UDim2.new(1, 0, 0, 34)
        group.BackgroundTransparency = 1
        group.ClipsDescendants = true
        group.ZIndex = 5
        group.AutomaticSize = Enum.AutomaticSize.Y

        local groupLayout = Instance.new("UIListLayout", group)
        groupLayout.SortOrder = Enum.SortOrder.LayoutOrder
        groupLayout.Padding = UDim.new(0, 2)

        local header = Instance.new("TextButton", group)
        header.Name = "Header"
        header.LayoutOrder = 1
        header.Size = UDim2.new(1, 0, 0, 32)
        header.BackgroundColor3 = self._Colors.Card
        header.BackgroundTransparency = 0.75
        header.Text = ""
        header.AutoButtonColor = false
        header.ZIndex = 6
        Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

        local hStroke = Instance.new("UIStroke", header)
        hStroke.Color = self._Colors.Border
        hStroke.Thickness = 1
        hStroke.Transparency = 0.7

        local chevron = Instance.new("ImageLabel", header)
        chevron.Name = "Chevron"
        chevron.Size = UDim2.fromOffset(12, 12)
        chevron.Position = UDim2.new(0, 8, 0.5, -6)
        chevron.BackgroundTransparency = 1
        chevron.Image = GetIcon("chevron-down")
        chevron.ImageColor3 = self._Colors.TextDim
        chevron.ScaleType = Enum.ScaleType.Fit
        chevron.ZIndex = 7

        local iconImg = Instance.new("ImageLabel", header)
        iconImg.Size = UDim2.fromOffset(14, 14)
        iconImg.Position = UDim2.new(0, 26, 0.5, -7)
        iconImg.BackgroundTransparency = 1
        iconImg.ImageColor3 = self._Colors.TextDim
        iconImg.ScaleType = Enum.ScaleType.Fit
        iconImg.ZIndex = 7
        if iconSpec then
            if string.sub(iconSpec, 1, 6) == "asset:" then
                iconImg.Image = "rbxassetid://" .. string.sub(iconSpec, 7)
            else
                iconImg.Image = GetIcon(iconSpec)
            end
        end

        local label = Instance.new("TextLabel", header)
        label.Size = UDim2.new(1, -48, 1, 0)
        label.Position = UDim2.new(0, 46, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = string.upper(categoryName)
        label.TextColor3 = self._Colors.TextDim
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.ZIndex = 7

        local tabList = Instance.new("Frame", group)
        tabList.Name = "TabList"
        tabList.LayoutOrder = 2
        tabList.Size = UDim2.new(1, 0, 0, 0)
        tabList.BackgroundTransparency = 1
        tabList.ClipsDescendants = true
        tabList.Visible = false
        tabList.ZIndex = 5

        local tlLayout = Instance.new("UIListLayout", tabList)
        tlLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tlLayout.Padding = UDim.new(0, 3)

        local tlPad = Instance.new("UIPadding", tabList)
        tlPad.PaddingLeft = UDim.new(0, 20)
        tlPad.PaddingRight = UDim.new(0, 4)
        tlPad.PaddingTop = UDim.new(0, 4)
        tlPad.PaddingBottom = UDim.new(0, 6)

        STATE.CategoryButtons[categoryName] = {
            button = header,
            label = label,
            icon = iconImg,
            chevron = chevron,
            group = group,
            tabList = tabList,
            layout = tlLayout,
            stroke = hStroke,
            isAccordion = true,
        }

        header.MouseButton1Click:Connect(function()
            local current = STATE.AccordionExpanded[categoryName]
            local isActiveCat = (STATE.ActiveCategory == categoryName)
            
            if not current then
                local tabs = STATE.CategoryTabs[categoryName]
                local targetTab = nil
                if tabs and #tabs > 0 then
                    local savedIdx = STATE.ActiveSubIndices[categoryName]
                    targetTab = (savedIdx and tabs[savedIdx]) or tabs[1]
                end
                self:SetActiveCategory(categoryName, targetTab)
            elseif current and not isActiveCat then
                local tabs = STATE.CategoryTabs[categoryName]
                local targetTab = nil
                if tabs and #tabs > 0 then
                    local savedIdx = STATE.ActiveSubIndices[categoryName]
                    targetTab = (savedIdx and tabs[savedIdx]) or tabs[1]
                end
                self:SetActiveCategory(categoryName, targetTab)
            elseif current and isActiveCat then
                self:_setAccordionState(categoryName, false)
            end
        end)

        header.MouseEnter:Connect(function()
            self:PlaySound("Hover")
            TweenService:Create(hStroke, TweenInfo.new(0.15), {Transparency = 0.3, Color = self._Colors.Accent}):Play()
            TweenService:Create(header, TweenInfo.new(0.15), {BackgroundTransparency = 0.55}):Play()
        end)
        header.MouseLeave:Connect(function()
            local isActive = (self.TabPosition == "Side") and STATE.AccordionExpanded[categoryName] or (categoryName == STATE.ActiveCategory)
            TweenService:Create(hStroke, TweenInfo.new(0.15), {
                Transparency = isActive and 0.3 or 0.7,
                Color = isActive and self._Colors.Accent or self._Colors.Border,
            }):Play()
            TweenService:Create(header, TweenInfo.new(0.15), {BackgroundTransparency = isActive and 0.5 or 0.75}):Play()
        end)

        self:_registerThemeRefresher(function()
            if not header.Parent then return end
            header.BackgroundColor3 = self._Colors.Card
            local isActive = (self.TabPosition == "Side") and STATE.AccordionExpanded[categoryName] or (categoryName == STATE.ActiveCategory)
            hStroke.Color = isActive and self._Colors.Accent or self._Colors.Border
            label.TextColor3 = isActive and self._Colors.Text or self._Colors.TextDim
            iconImg.ImageColor3 = isActive and self._Colors.Accent or self._Colors.TextDim
            chevron.ImageColor3 = isActive and self._Colors.Accent or self._Colors.TextDim
        end)

        return header
    end

    local btn = Instance.new("TextButton", UI.CategoryBar)
    btn.Name = "CatBtn_" .. categoryName
    btn.Size = UDim2.new(0, 110, 0, 30)
    btn.BackgroundColor3 = self._Colors.Card
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    Fn.bindPressAnimation(btn)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local iconImg = Instance.new("ImageLabel", btn)
    iconImg.Size = UDim2.new(0, 16, 0, 16)
    iconImg.Position = UDim2.new(0, 14, 0.5, -8)
    iconImg.BackgroundTransparency = 1
    iconImg.ImageColor3 = Color3.new(1, 1, 1)
    iconImg.ImageTransparency = 0.45
    iconImg.ScaleType = Enum.ScaleType.Fit
    if iconSpec then
        if string.sub(iconSpec, 1, 6) == "asset:" then
            iconImg.Image = "rbxassetid://" .. string.sub(iconSpec, 7)
        else
            iconImg.Image = GetIcon(iconSpec)
        end
    end

    local label = Instance.new("TextLabel", btn)
    label.Size = UDim2.new(1, -42, 1, 0)
    label.Position = UDim2.new(0, 36, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = categoryName
    label.TextColor3 = self._Colors.TextDim
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd

    btn.MouseEnter:Connect(function()
        self:PlaySound("Hover")
    end)

    btn.MouseButton1Click:Connect(function()
        self:SetActiveCategory(categoryName)
    end)

    STATE.CategoryButtons[categoryName] = { button = btn, label = label, icon = iconImg }
    self:_registerThemeRefresher(function()
        if not btn.Parent then return end
        btn.BackgroundColor3 = self._Colors.Card
        -- Contrast-derived instead of hard-coded white: the active label was
        -- unreadable on light themes (Monochrome / Ice / Gold).
        label.TextColor3 = categoryName == STATE.ActiveCategory
            and Fn.contrastForeground(self._Colors.Sidebar) or self._Colors.TextDim
    end)

    self:_layoutCategoryButtons()
    return btn
end

function Library:_layoutCategoryButtons()
    local STATE = self._STATE
    local UI = self._UI
    if not STATE.CategoryButtons then return end
    if self.TabPosition == "Side" then
        if UI.BottomPill then UI.BottomPill.Visible = false end
        return
    end
    local names = {}
    for _, name in ipairs(STATE.CategoryOrder or {}) do
        local data = STATE.CategoryButtons[name]
        -- Skip categories the frontend has hidden (the sea filter hides the
        -- categories of the other seas) so the visible buttons reflow without
        -- leaving a gap where a hidden one used to be.
        if data and (not data.button or data.button.Visible ~= false) then table.insert(names, name) end
    end
    if #names == 0 then
        if self.TabPosition == "Bottom" then
            UI.CategoryBar.Size = UDim2.new(1, -20, 0, 48)
            UI.CategoryBar.Position = UDim2.new(0, 10, 1, -58)
        end
        return
    end

    local gap, padding = 8, 8
    local availableWidth = UI.MainContainer.AbsoluteSize.X - 20
    if self.TabPosition == "Top" then
        availableWidth = UI.CategoryBar.AbsoluteSize.X
    end
    if availableWidth <= 0 then return end

    gap = math.min(gap, math.floor(availableWidth / math.max(#names * 2, 1)))
    padding = math.min(padding, math.floor((availableWidth - gap * math.max(#names - 1, 0)) / (#names * 2)))
    local gapsWidth = math.max(#names - 1, 0) * gap
    local buttonWidth = math.min(self.TabWidth, math.floor((availableWidth - padding * 2 - gapsWidth) / #names))
    buttonWidth = math.max(buttonWidth, 1)
    local dockWidth = math.min(availableWidth, #names * buttonWidth + gapsWidth + padding * 2)
    
    if self.TabPosition == "Bottom" then
        UI.CategoryBar.Size = UDim2.new(1, -20, 0, 56)
        UI.CategoryBar.Position = UDim2.new(0, 10, 1, -66)
    end

    local startX = padding
    if self.CategoryAlign == "Center" or self.TabPosition == "Bottom" then
        startX = math.floor((availableWidth - dockWidth) / 2) + padding
    elseif self.CategoryAlign == "Right" then
        startX = availableWidth - dockWidth + padding
    end
    for i, name in ipairs(names) do
        local data = STATE.CategoryButtons[name]
        data.button.Size = UDim2.new(0, buttonWidth, 0, self.TabPosition == "Bottom" and 36 or 30)
        data.button.Position = UDim2.new(0, startX + (i - 1) * (buttonWidth + gap), 0.5, self.TabPosition == "Bottom" and -18 or -15)
        data.label.Visible = buttonWidth >= 72
        data.icon.Position = UDim2.new(0, buttonWidth >= 72 and 10 or (buttonWidth - 16) / 2, 0.5, -8)
        data.label.Size = UDim2.new(1, -38, 1, 0)
    end

    if self.TabPosition == "Bottom" and UI.BottomPill then
        local activeData = STATE.CategoryButtons[STATE.ActiveCategory]
        if activeData and activeData.button then
            UI.BottomPill.Size = UDim2.new(0, buttonWidth, 0, 36)
            UI.BottomPill.Position = UDim2.new(0, activeData.button.Position.X.Offset, 0.5, -18)
        end
    end
end

function Library:SetActiveCategory(categoryName, preferredTab)
    if self:_isDead() then return end
    local STATE = self._STATE
    if not STATE.CategoryButtons or not STATE.CategoryButtons[categoryName] then return end
    local targetData = STATE.CategoryButtons[categoryName]
    if targetData.isStandalone then
        if STATE.ActiveCategory == categoryName and STATE.ActiveTab then
            return
        end
        for name, data in pairs(STATE.CategoryButtons or {}) do
            local active = (name == categoryName)
            if data.isStandalone then
                if data.isAccordion then
                    if data.stroke then
                        TweenService:Create(data.stroke, TweenInfo.new(0.2), {
                            Transparency = active and 0.3 or 0.7,
                            Color = active and self._Colors.Accent or self._Colors.Border,
                        }):Play()
                    end
                    if data.button then
                        TweenService:Create(data.button, TweenInfo.new(0.2), {
                            BackgroundTransparency = active and 0.4 or 0.75,
                        }):Play()
                    end
                    if data.label then
                        data.label.TextColor3 = active and self._Colors.Text or self._Colors.TextDim
                        data.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
                    end
                    if data.icon then
                        data.icon.ImageColor3 = active and self._Colors.Accent or self._Colors.TextDim
                    end
                else
                    if data.button then
                        TweenService:Create(data.button, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {
                            BackgroundTransparency = active and 0.55 or 1,
                        }):Play()
                    end
                    if data.label then
                        TweenService:Create(data.label, TweenInfo.new(0.22), {
                            TextColor3 = active and Color3.fromRGB(255, 255, 255) or self._Colors.TextDim,
                        }):Play()
                        data.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
                    end
                    if data.icon then
                        TweenService:Create(data.icon, TweenInfo.new(0.22), {
                            ImageTransparency = active and 0 or 0.45,
                        }):Play()
                    end
                end
            elseif not data.isAccordion and data.button and data.label and data.icon then
                TweenService:Create(data.button, TweenInfo.new(0.22), {BackgroundTransparency = 1}):Play()
                TweenService:Create(data.label, TweenInfo.new(0.22), {TextColor3 = self._Colors.TextDim}):Play()
                data.label.Font = Enum.Font.GothamMedium
                TweenService:Create(data.icon, TweenInfo.new(0.22), {ImageTransparency = 0.45}):Play()
            end
        end
        STATE.ActiveCategory = categoryName
        STATE.ActiveSubIndices = STATE.ActiveSubIndices or {}
        local tabs = STATE.CategoryTabs[categoryName]
        if tabs and tabs[1] then
            STATE.ActiveTab = nil
            self:SwitchTab(tabs[1])
        end
        self:_applyNavigationLayout()
        return
    end
    local prevActive = STATE.ActiveCategory
    if prevActive and prevActive ~= categoryName then
        local prevData = STATE.CategoryButtons[prevActive]
        if prevData and prevData.isStandalone then
            if prevData.isAccordion then
                if prevData.stroke then
                    TweenService:Create(prevData.stroke, TweenInfo.new(0.2), {Transparency = 0.7, Color = self._Colors.Border}):Play()
                end
                if prevData.button then
                    TweenService:Create(prevData.button, TweenInfo.new(0.2), {BackgroundTransparency = 0.75}):Play()
                end
                if prevData.label then
                    prevData.label.TextColor3 = self._Colors.TextDim
                    prevData.label.Font = Enum.Font.GothamMedium
                end
                if prevData.icon then
                    prevData.icon.ImageColor3 = self._Colors.TextDim
                end
            else
                if prevData.button then
                    TweenService:Create(prevData.button, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                end
                if prevData.label then
                    TweenService:Create(prevData.label, TweenInfo.new(0.2), {TextColor3 = self._Colors.TextDim}):Play()
                    prevData.label.Font = Enum.Font.GothamMedium
                end
                if prevData.icon then
                    TweenService:Create(prevData.icon, TweenInfo.new(0.2), {ImageTransparency = 0.45}):Play()
                end
            end
        end
    end
    if STATE.ActiveCategory == categoryName and STATE.SubTabBar then
        if preferredTab and STATE.ContentPages[preferredTab] then
            self:SwitchTab(preferredTab)
        end
        return
    end
    STATE.ActiveCategory = categoryName
    STATE.ActiveSubIndices = STATE.ActiveSubIndices or {}

    if self.TabPosition ~= "Side" then
        for name, data in pairs(STATE.CategoryButtons or {}) do
            local active = (name == categoryName)
            TweenService:Create(data.button, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {
                BackgroundTransparency = active and 0.55 or 1,
            }):Play()
            TweenService:Create(data.label, TweenInfo.new(0.22), {
                TextColor3 = active and Color3.fromRGB(255, 255, 255) or self._Colors.TextDim,
            }):Play()
            data.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
            TweenService:Create(data.icon, TweenInfo.new(0.22), {
                ImageTransparency = active and 0 or 0.45,
            }):Play()
        end
    end

    local tabs = STATE.CategoryTabs[categoryName]
    if not (tabs and #tabs > 0) then return end

    local targetIdx, targetName
    if preferredTab and STATE.ContentPages[preferredTab] then
        for idx, name in ipairs(tabs) do
            if name == preferredTab then
                targetIdx, targetName = idx, name
                break
            end
        end
    end
    if not targetName then
        local savedIdx = STATE.ActiveSubIndices[categoryName]
        if savedIdx and tabs[savedIdx] then
            targetIdx, targetName = savedIdx, tabs[savedIdx]
        else
            targetIdx, targetName = 1, tabs[1]
        end
    end

    if self.TabPosition == "Side" then
        if not STATE.AccordionExpanded[categoryName] then
            self:_setAccordionState(categoryName, true)
        end
        
        for _, catData in pairs(STATE.CategoryButtons) do
            if catData.isAccordion and catData.tabList then
                for _, otherSub in ipairs(catData.tabList:GetChildren()) do
                    if otherSub:IsA("TextButton") then
                        otherSub.BackgroundTransparency = 1
                        local lbl = otherSub:FindFirstChild("SubLabel")
                        if lbl then
                            lbl.TextColor3 = self._Colors.TextDim
                            lbl.Font = Enum.Font.GothamMedium
                        end
                        local ind = otherSub:FindFirstChild("AccentDot")
                        if ind then ind.Visible = false end
                    end
                end
            end
        end
        
        if targetName then
            STATE.ActiveSubIndices[categoryName] = targetIdx
            local catData = STATE.CategoryButtons[categoryName]
            if catData and catData.tabList then
                for _, child in ipairs(catData.tabList:GetChildren()) do
                    if child:IsA("TextButton") and child:GetAttribute("TabName") == targetName then
                        child.BackgroundTransparency = 0.4
                        local lbl = child:FindFirstChild("SubLabel")
                        if lbl then
                            lbl.TextColor3 = self._Colors.Text
                            lbl.Font = Enum.Font.GothamBold
                        end
                        local ind = child:FindFirstChild("AccentDot")
                        if ind then ind.Visible = true end
                        break
                    end
                end
            end
            if STATE.ContentPages[targetName] then
                self:SwitchTab(targetName)
            end
        end
        self:_applyNavigationLayout()
        return
    end

    -- The tab strip is cached per category. It used to be destroyed and rebuilt
    -- from scratch on every category click, churning dozens of instances and
    -- connections each time.
    STATE.SubTabBars = STATE.SubTabBars or {}
    for name, bar in pairs(STATE.SubTabBars) do
        if name ~= categoryName and bar and bar.Wrapper then
            bar.Wrapper.Visible = false
        end
    end

    local cachedBar = STATE.SubTabBars[categoryName]
    if cachedBar and cachedBar.Wrapper and cachedBar.Wrapper.Parent then
        cachedBar.Wrapper.Visible = true
        STATE.SubTabBar = cachedBar
        self:_resizeSubTabs()
        if targetName then
            STATE.ActiveSubIndices[categoryName] = targetIdx
            cachedBar:SetActiveSub(categoryName, targetName)
            if STATE.ContentPages[targetName] then
                self:SwitchTab(targetName)
            end
        end
        self:_applyNavigationLayout()
        return
    end

    local suppress = false
    STATE.SubTabBar = SubTabModule.new({
        Parent = self._UI.Sidebar,
        Data = { [categoryName] = tabs },
        TabWidth = self.TabWidth, TabHeight = self._isMobile and 44 or 28, Padding = 6,
        Theme = {
            PillBg = self._Colors.Card, LeftAccent = self._Colors.Accent,
            TextActive = Fn.contrastForeground(self._Colors.Card), TextInactive = self._Colors.TextDim,
            FontActive = Enum.Font.GothamBold, FontInactive = Enum.Font.GothamMedium,
        },
        Owner = self,
        OnChanged = function(_, subName)
            if suppress then return end
            for idx, name in ipairs(tabs) do
                if name == subName then
                    STATE.ActiveSubIndices[categoryName] = idx
                    break
                end
            end
            if STATE.ContentPages[subName] then
                self:SwitchTab(subName)
            end
        end,
    })
    self:_resizeSubTabs()
    suppress = true
    STATE.SubTabBar:SwitchCategory(categoryName)
    suppress = false
    STATE.SubTabBars[categoryName] = STATE.SubTabBar

    if targetName then
        STATE.SubTabBar:SetActiveSub(categoryName, targetName)
        STATE.ActiveSubIndices[categoryName] = targetIdx
        if STATE.ContentPages[targetName] then
            self:SwitchTab(targetName)
        end
    end
    self:_applyNavigationLayout()
end

function Library:SetTabBadge(categoryName, tabName, text, color)
    warn("[DoD UI] SetTabBadge is deprecated - badges removed in this version.")
    return
end

function Library:CreateTab(categoryName, tabName)
    if self:_isDead() then return end
    if type(tabName) ~= "string" or tabName == "" then
        error("[DoD UI] CreateTab requires a non-empty tab name.")
    end
    local UI = self._UI
    local STATE = self._STATE
    if not STATE.CategoryButtons or not STATE.CategoryButtons[categoryName] then
        error("[DoD UI] Category '" .. tostring(categoryName) .. "' belum dibuat. Panggil :CreateCategory dulu.")
    end
    if STATE.ContentPages[tabName] then
        error("[DoD UI] Tab '" .. tabName .. "' already exists.")
    end
    STATE.TabCategories[tabName] = categoryName
    STATE.CategoryTabs[categoryName] = STATE.CategoryTabs[categoryName] or {}
    table.insert(STATE.CategoryTabs[categoryName], tabName)

    local page = Instance.new("ScrollingFrame", UI.ContentArea)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.Position = UDim2.new(0, 0, 0, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 0
    page.ScrollBarImageColor3 = self._Colors.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    page.VerticalScrollBarInset = Enum.ScrollBarInset.None
    page.HorizontalScrollBarInset = Enum.ScrollBarInset.None
    -- MOBILE: native bounce+inertia so finger scroll feels smooth.
    page.ElasticBehavior = self._isMobile and Enum.ElasticBehavior.WhenScrollable or Enum.ElasticBehavior.Never
    self:_registerScrollFrame(page)

    local pagePad = Instance.new("UIPadding", page)
    pagePad.PaddingTop = UDim.new(0, 6)
    pagePad.PaddingBottom = UDim.new(0, 12)
    pagePad.PaddingRight = UDim.new(0, 6)

    local pageList = Instance.new("UIListLayout", page)
    pageList.SortOrder = Enum.SortOrder.LayoutOrder
    pageList.Padding = UDim.new(0, self:_densityPadding(10))

    -- Top container (full width) for banners
    local topContainer = Instance.new("Frame", page)
    topContainer.Name = "TopContainer"
    topContainer.LayoutOrder = 1
    topContainer.Size = UDim2.new(1, 0, 0, 0)
    topContainer.AutomaticSize = Enum.AutomaticSize.Y
    topContainer.BackgroundTransparency = 1
    local topLayout = Instance.new("UIListLayout", topContainer)
    topLayout.SortOrder = Enum.SortOrder.LayoutOrder
    topLayout.Padding = UDim.new(0, 10)

    -- Dual Columns Container
    local columnsContainer = Instance.new("Frame", page)
    columnsContainer.Name = "ColumnsContainer"
    columnsContainer.LayoutOrder = 2
    columnsContainer.Size = UDim2.new(1, 0, 0, 0)
    columnsContainer.BackgroundTransparency = 1
    columnsContainer.ClipsDescendants = false

    -- Left Column
    local leftCol = Instance.new("Frame", columnsContainer)
    leftCol.Name = "LeftColumn"
    leftCol.Size = UDim2.new(0.5, -5, 0, 0)
    leftCol.Position = UDim2.new(0, 0, 0, 0)
    leftCol.AutomaticSize = Enum.AutomaticSize.Y
    leftCol.BackgroundTransparency = 1
    leftCol.ClipsDescendants = false
    local leftLayout = Instance.new("UIListLayout", leftCol)
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Padding = UDim.new(0, self:_densityPadding(10))

    -- Right Column
    local rightCol = Instance.new("Frame", columnsContainer)
    rightCol.Name = "RightColumn"
    rightCol.Size = UDim2.new(0.5, -5, 0, 0)
    rightCol.Position = UDim2.new(0.5, 5, 0, 0)
    rightCol.AutomaticSize = Enum.AutomaticSize.Y
    rightCol.BackgroundTransparency = 1
    rightCol.ClipsDescendants = false
    local rightLayout = Instance.new("UIListLayout", rightCol)
    rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rightLayout.Padding = UDim.new(0, self:_densityPadding(10))

    -- Auto-scale height for columns container
    local function updateColumnsSize()
        local leftSize = leftLayout.AbsoluteContentSize.Y
        local rightSize = rightLayout.AbsoluteContentSize.Y
        local maxH = math.max(leftSize, rightSize)
        columnsContainer.Size = UDim2.new(1, 0, 0, maxH)
    end
    leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateColumnsSize)
    rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateColumnsSize)

    -- Save references
    STATE.ContentPages[tabName] = page
    STATE.TabTopContainers[tabName] = topContainer
    STATE.TabColumns[tabName] = { Left = leftCol, Right = rightCol, Container = columnsContainer }

    self:_registerThemeRefresher(function()
        if page.Parent then
            page.ScrollBarImageColor3 = self._Colors.Accent
        end
    end)
    page:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if STATE.ActiveTab == tabName then
            STATE.SavedScrollPositions[tabName] = page.CanvasPosition
        end
    end)

    if self.TabPosition == "Side" then
        local catData = STATE.CategoryButtons[categoryName]
        if catData and catData.tabList and not catData.isStandalone then
            local tabCount = 0
            for _, c in ipairs(catData.tabList:GetChildren()) do
                if c:IsA("TextButton") then tabCount = tabCount + 1 end
            end
            local subBtn = Instance.new("TextButton", catData.tabList)
            subBtn.Name = "SubTab_" .. tabName
            subBtn.LayoutOrder = tabCount + 1
            subBtn.Size = UDim2.new(1, 0, 0, 26)
            subBtn.BackgroundColor3 = self._Colors.Card
            subBtn.BackgroundTransparency = 1
            subBtn.Text = ""
            subBtn.AutoButtonColor = false
            subBtn.ZIndex = 6
            subBtn:SetAttribute("TabName", tabName)
            Instance.new("UICorner", subBtn).CornerRadius = UDim.new(0, 6)

            local accentDot = Instance.new("Frame", subBtn)
            accentDot.Name = "AccentDot"
            accentDot.Size = UDim2.fromOffset(3, 12)
            accentDot.Position = UDim2.new(0, 2, 0.5, -6)
            accentDot.BackgroundColor3 = self._Colors.Accent
            accentDot.BorderSizePixel = 0
            accentDot.Visible = false
            accentDot.ZIndex = 7
            Instance.new("UICorner", accentDot).CornerRadius = UDim.new(1, 0)

            local subLabel = Instance.new("TextLabel", subBtn)
            subLabel.Name = "SubLabel"
            subLabel.Size = UDim2.new(1, -16, 1, 0)
            subLabel.Position = UDim2.new(0, 12, 0, 0)
            subLabel.BackgroundTransparency = 1
            subLabel.Text = tabName
            subLabel.TextColor3 = self._Colors.TextDim
            subLabel.Font = Enum.Font.GothamMedium
            subLabel.TextSize = 11
            subLabel.TextXAlignment = Enum.TextXAlignment.Left
            subLabel.TextTruncate = Enum.TextTruncate.AtEnd
            subLabel.ZIndex = 7

            subBtn.MouseEnter:Connect(function()
                self:PlaySound("Hover")
                if STATE.ActiveTab ~= tabName then
                    TweenService:Create(subBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.7}):Play()
                    TweenService:Create(subLabel, TweenInfo.new(0.15), {TextColor3 = self._Colors.Text}):Play()
                end
            end)
            subBtn.MouseLeave:Connect(function()
                if STATE.ActiveTab ~= tabName then
                    TweenService:Create(subBtn, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
                    TweenService:Create(subLabel, TweenInfo.new(0.15), {TextColor3 = self._Colors.TextDim}):Play()
                end
            end)

            subBtn.MouseButton1Click:Connect(function()
                self:SetActiveCategory(categoryName, tabName)
            end)

            self:_registerThemeRefresher(function()
                if not subBtn.Parent then return end
                subBtn.BackgroundColor3 = self._Colors.Card
                subLabel.TextColor3 = STATE.ActiveTab == tabName and self._Colors.Text or self._Colors.TextDim
                accentDot.BackgroundColor3 = self._Colors.Accent
            end)
        end
    end

    if self.TabPosition == "Side" and STATE.AccordionExpanded[categoryName] then
        self:_setAccordionState(categoryName, true)
    end

    if STATE.ActiveCategory == nil or STATE.ActiveCategory == categoryName then
        self:SetActiveCategory(categoryName)
    end
    return self:_wrapTab(page, tabName)
end

function Library:CreateStandaloneTab(tabName, iconSpec)
    if self:_isDead() then return end
    if type(tabName) ~= "string" or tabName == "" then
        error("[DoD UI] CreateStandaloneTab requires a non-empty tab name.")
    end
    if iconSpec ~= nil and type(iconSpec) ~= "string" then
        error("[DoD UI] CreateStandaloneTab iconSpec must be a string or nil.")
    end
    local STATE = self._STATE
    if STATE.ContentPages[tabName] then
        error("[DoD UI] Tab '" .. tabName .. "' already exists.")
    end
    if STATE.CategoryButtons and STATE.CategoryButtons[tabName] then
        error("[DoD UI] Category '" .. tabName .. "' already exists.")
    end
    self:CreateCategory(tabName, iconSpec)
    local catData = self._STATE.CategoryButtons[tabName]
    if catData then
        catData.isStandalone = true
        if catData.isAccordion then
            if catData.chevron then catData.chevron.Visible = false end
            if catData.icon then catData.icon.Position = UDim2.new(0, 10, 0.5, -7) end
            if catData.label then
                catData.label.Position = UDim2.new(0, 30, 0, 0)
                catData.label.Size = UDim2.new(1, -40, 1, 0)
            end
        end
    end
    self._STATE.StandaloneTabs[tabName] = true
    self:CreateTab(tabName, tabName)
    return self:_wrapTab(self._STATE.ContentPages[tabName], tabName)
end

function Library:SwitchTab(tabName)
    if self:_isDead() then return end
    local STATE = self._STATE
    local page = STATE.ContentPages[tabName]
    if not page then return end

    local ownerCat = STATE.TabCategories[tabName]
    if ownerCat and STATE.ActiveCategory ~= ownerCat then
        self:SetActiveCategory(ownerCat, tabName)
        return
    end

    if STATE.ActiveTab == tabName and page.Visible then
        return
    end

    self:PlaySound("TabSwitch")

    for _, p in pairs(STATE.ContentPages) do
        if p ~= page then p.Visible = false end
    end
    page.Visible = true
    STATE.ActiveTab = tabName

    local scale = page:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale", page)
    end
    scale.Scale = 0.94
    page.Position = UDim2.new(0, 25, 0, 0)
    page.BackgroundTransparency = 1

    TweenService:Create(scale,
        TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Scale = 1}
    ):Play()
    TweenService:Create(page,
        TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 0, 0, 0)}
    ):Play()

    local saved = STATE.SavedScrollPositions[tabName]
    if saved then
        task.defer(function()
            for _ = 1, 3 do
                task.wait(0.05)
                if page.Parent then page.CanvasPosition = saved end
            end
        end)
    end

    self:_applySearchFilter(tabName)
    if STATE.SubTabBar and ownerCat then
        pcall(function() STATE.SubTabBar:SetActiveSub(ownerCat, tabName) end)
    end
end

function Library:CreateSection(tabName, title, summary, defaultOpen, columnName, iconName)
    if self:_isDead() then return end
    if type(title) ~= "string" or title == "" then
        error("[DoD UI] CreateSection requires a non-empty title.")
    end
    if summary ~= nil and type(summary) ~= "string" then
        error("[DoD UI] CreateSection summary must be a string or nil.")
    end
    if columnName ~= nil and columnName ~= "Left" and columnName ~= "Right" then
        error("[DoD UI] CreateSection column must be 'Left' or 'Right'.")
    end
    columnName = columnName or "Left"
    local hasIcon = iconName ~= nil and iconName ~= ""
    local labelOffset = hasIcon and 42 or 16
    local labelWidth = hasIcon and -76 or -50

    local columns = self._STATE.TabColumns[tabName]
    if not columns then
        error("[DoD UI] Tab '" .. tostring(tabName) .. "' not found. Call :CreateTab first.")
    end
    local parentCol = columns[columnName]

    local sectionOrder = #parentCol:GetChildren() + 1
    local HEADER_HEIGHT = 50

    local section = Instance.new("Frame", parentCol)
    section.Name = (title:gsub("%W", "") or "") .. "Section"
    section.LayoutOrder = sectionOrder
    section.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
    section.BackgroundColor3 = self._Colors.Card
    section.BackgroundTransparency = self._STATE.SectionTransparency or 0.15
    section.BorderSizePixel = 0
    section.ClipsDescendants = true
    Instance.new("UICorner", section).CornerRadius = UDim.new(0, 12) -- Softer corners

    local cardStroke = Instance.new("UIStroke", section)
    cardStroke.Color = self._Colors.Border
    cardStroke.Thickness = 1
    cardStroke.Transparency = 0.4

    local header = Instance.new("TextButton", section)
    header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    Fn.bindPressAnimation(header)

    local sectionIcon
    if hasIcon then
        sectionIcon = Instance.new("ImageLabel", header)
        sectionIcon.Name = "SectionIcon"
        sectionIcon.Size = UDim2.fromOffset(18, 18)
        sectionIcon.Position = UDim2.new(0, 16, 0, 10)
        sectionIcon.BackgroundTransparency = 1
        sectionIcon.Image = GetIcon(iconName)
        sectionIcon.ImageColor3 = self._Colors.Accent
        sectionIcon.ScaleType = Enum.ScaleType.Fit
    end

    local titleLabel = Instance.new("TextLabel", header)
    titleLabel.Size = UDim2.new(1, labelWidth, 0, 18)
    titleLabel.Position = UDim2.new(0, labelOffset, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = self._Colors.Text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local summaryLabel = Instance.new("TextLabel", header)
    summaryLabel.Size = UDim2.new(1, labelWidth, 0, 14)
    summaryLabel.Position = UDim2.new(0, labelOffset, 0, 28)
    summaryLabel.BackgroundTransparency = 1
    summaryLabel.Text = summary or ""
    summaryLabel.TextColor3 = self._Colors.TextDim
    summaryLabel.Font = Enum.Font.GothamMedium
    summaryLabel.TextSize = 10
    summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
    summaryLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local indicator = Instance.new("ImageLabel", header)
    indicator.Name = "ExpandIndicator"
    indicator.Size = UDim2.fromOffset(16, 16)
    indicator.AnchorPoint = Vector2.new(0.5, 0.5)
    indicator.Position = UDim2.new(1, -26, 0.5, 0)
    indicator.BackgroundTransparency = 1
    indicator.Image = GetIcon(defaultOpen and "arrow-up" or "arrow-down")
    indicator.ImageColor3 = defaultOpen and self._Colors.Accent or self._Colors.TextDim
    indicator.ScaleType = Enum.ScaleType.Fit

    local hoverBar = Instance.new("Frame", section)
    hoverBar.Name = "HoverBar"
    hoverBar.AnchorPoint = Vector2.new(0, 0.5)
    hoverBar.Position = UDim2.new(0, 0, 0.5, 0)
    hoverBar.Size = UDim2.new(0, 3, 1, -32)
    hoverBar.BackgroundColor3 = self._Colors.Accent
    hoverBar.BackgroundTransparency = 1
    hoverBar.BorderSizePixel = 0
    hoverBar.ZIndex = 5
    Instance.new("UICorner", hoverBar).CornerRadius = UDim.new(1, 0)

    local separator = Instance.new("Frame", section)
    separator.Size = UDim2.new(1, -32, 0, 1)
    separator.Position = UDim2.new(0, 16, 0, HEADER_HEIGHT)
    separator.BackgroundColor3 = self._Colors.Border
    separator.BackgroundTransparency = 1
    separator.BorderSizePixel = 0

    local body = Instance.new("ScrollingFrame", section)
    body.Size = UDim2.new(1, 0, 0, 0)
    body.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.ClipsDescendants = true
    body.Visible = false
    body.ScrollBarThickness = 0
    body.ScrollingDirection = Enum.ScrollingDirection.Y
    body.ElasticBehavior = self._isMobile and Enum.ElasticBehavior.WhenScrollable or Enum.ElasticBehavior.Never
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.CanvasSize = UDim2.new(0, 0, 0, 0)
    body.VerticalScrollBarInset = Enum.ScrollBarInset.None
    body.HorizontalScrollBarInset = Enum.ScrollBarInset.None
    self:_registerScrollFrame(body)

    local bodyLayout = Instance.new("UIListLayout", body)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Padding = UDim.new(0, self:_densityPadding(8))

    local bodyPad = Instance.new("UIPadding", body)
    bodyPad.PaddingLeft = UDim.new(0, 12)
    bodyPad.PaddingRight = UDim.new(0, 20)
    bodyPad.PaddingTop = UDim.new(0, 10)
    bodyPad.PaddingBottom = UDim.new(0, 14)

    local scrollTrack = Instance.new("Frame", section)
    scrollTrack.Name = "ScrollTrack"
    scrollTrack.AnchorPoint = Vector2.new(0.5, 0)
    scrollTrack.Position = UDim2.new(1, -10, 0, HEADER_HEIGHT + 14)
    scrollTrack.Size = UDim2.fromOffset(3, 0)
    scrollTrack.BackgroundColor3 = self._Colors.Border
    scrollTrack.BackgroundTransparency = 0.75
    scrollTrack.BorderSizePixel = 0
    scrollTrack.ZIndex = 6
    scrollTrack.Visible = false
    Instance.new("UICorner", scrollTrack).CornerRadius = UDim.new(1, 0)

    local scrollThumb = Instance.new("Frame", scrollTrack)
    scrollThumb.Name = "ScrollThumb"
    scrollThumb.Size = UDim2.new(1, 0, 0.3, 0)
    scrollThumb.Position = UDim2.new(0, 0, 0, 0)
    scrollThumb.BackgroundColor3 = self._Colors.Accent
    scrollThumb.BorderSizePixel = 0
    scrollThumb.ZIndex = 7
    Instance.new("UICorner", scrollThumb).CornerRadius = UDim.new(1, 0)

    local scrollThumbGlow = Instance.new("Frame", scrollThumb)
    scrollThumbGlow.Name = "ThumbGlow"
    scrollThumbGlow.Size = UDim2.new(1, 8, 1, 0)
    scrollThumbGlow.Position = UDim2.new(0, -4, 0, 0)
    scrollThumbGlow.BackgroundColor3 = self._Colors.Accent
    scrollThumbGlow.BackgroundTransparency = 0.7
    scrollThumbGlow.BorderSizePixel = 0
    scrollThumbGlow.ZIndex = 6
    Instance.new("UICorner", scrollThumbGlow).CornerRadius = UDim.new(1, 0)

    local expanded = defaultOpen == true
    local currentTween
    local sectionData = {
        tabName = tabName,
        title = title,
        summary = summary or "",
        section = section,
        parentColumn = parentCol,
        controls = {},
        expanded = expanded,
        searching = false,
    }
    self._STATE.SearchSections[tabName] = self._STATE.SearchSections[tabName] or {}
    table.insert(self._STATE.SearchSections[tabName], sectionData)
    self._STATE.SearchBodies[body] = sectionData

    local function updateScrollIndicator()
        if not body or not body.Parent then return end
        if not expanded then
            scrollTrack.Visible = false
            return
        end
        local maxScroll = math.max(0, body.AbsoluteCanvasSize.Y - body.AbsoluteSize.Y)
        if maxScroll <= 2 then
            scrollTrack.Visible = false
            return
        end
        scrollTrack.Visible = true
        local bodyH = body.AbsoluteSize.Y
        if bodyH <= 0 then return end
        local trackH = math.max(28, bodyH - 20)
        scrollTrack.Size = UDim2.fromOffset(3, trackH)
        local canvasH = math.max(1, body.AbsoluteCanvasSize.Y)
        local ratio = math.clamp(body.CanvasPosition.Y / maxScroll, 0, 1)
        local thumbRatio = math.clamp(bodyH / canvasH, 0.12, 1)
        local thumbH = math.max(22, trackH * thumbRatio)
        scrollThumb.Size = UDim2.new(1, 0, 0, thumbH)
        local maxThumbY = math.max(0, trackH - thumbH)
        scrollThumb.Position = UDim2.new(0, 0, 0, ratio * maxThumbY)
    end

    local function updateHeight(animate)
        if not body or not body.Parent then return end
        local innerH = bodyLayout.AbsoluteContentSize.Y
        local contentH = (innerH > 0) and (innerH + 24) or 24
        local maxH = 450
        local contentArea = self._UI.ContentArea
        if contentArea and contentArea.AbsoluteSize.Y > 0 then
            maxH = math.min(450, math.max(240, contentArea.AbsoluteSize.Y - 40))
        end
        local cappedH = math.min(contentH, maxH)
        local targetH = expanded and (HEADER_HEIGHT + cappedH) or HEADER_HEIGHT
        if expanded then
            body.Size = UDim2.new(1, 0, 0, cappedH)
        end
        if currentTween then currentTween:Cancel() end
        if animate == false then
            section.Size = UDim2.new(1, 0, 0, targetH)
        else
            currentTween = TweenService:Create(section,
                TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {Size = UDim2.new(1, 0, 0, targetH)})
            currentTween:Play()
            if not expanded then
                local cap = currentTween
                cap.Completed:Connect(function()
                    if not expanded and body then body.Visible = false end
                    updateScrollIndicator()
                end)
            end
        end
        TweenService:Create(separator, TweenInfo.new(0.2), {
            BackgroundTransparency = expanded and 0.6 or 1
        }):Play()
        indicator.Image = GetIcon(expanded and "arrow-up" or "arrow-down")
        TweenService:Create(indicator,
            TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                ImageColor3 = expanded and self._Colors.Accent or self._Colors.TextDim,
            }):Play()
        updateScrollIndicator()
        task.defer(updateScrollIndicator)
    end

    local function toggle(forceState)
        if forceState ~= nil then expanded = forceState
        else expanded = not expanded end
        sectionData.expanded = expanded
        if expanded then
            body.Visible = true
            task.defer(function() updateHeight(true) end)
        else
            updateHeight(true)
        end
    end

    sectionData.setExpanded = function(isExpanded)
        expanded = isExpanded
        sectionData.expanded = expanded
        body.Visible = expanded
        if expanded then
            task.defer(function() updateHeight(false) end)
        else
            updateHeight(false)
        end
    end

    bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if expanded then updateHeight(true) end
    end)

    body:GetPropertyChangedSignal("CanvasPosition"):Connect(updateScrollIndicator)
    body:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateScrollIndicator)
    body:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScrollIndicator)

    -- No per-section listener on ContentArea.AbsoluteSize: every section used to
    -- register one, so a window resize produced N layout flushes per frame. The
    -- body's own AbsoluteContentSize signal already keeps the height correct.

    header.MouseEnter:Connect(function()
        local baseTrans = self._STATE.SectionTransparency or 0.15
        TweenService:Create(section, TweenInfo.new(0.18),
            {BackgroundColor3 = self._Colors.CardHover, BackgroundTransparency = math.max(0, baseTrans - 0.1)}):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.22),
            {Color = self._Colors.Accent, Transparency = 0.25}):Play()
        TweenService:Create(hoverBar, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.15}):Play()
        if sectionIcon then
            TweenService:Create(sectionIcon, TweenInfo.new(0.22),
                {ImageColor3 = self._Colors.Accent}):Play()
        end
    end)
    header.MouseLeave:Connect(function()
        local baseTrans = self._STATE.SectionTransparency or 0.15
        TweenService:Create(section, TweenInfo.new(0.18),
            {BackgroundColor3 = self._Colors.Card, BackgroundTransparency = baseTrans}):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.22),
            {Color = self._Colors.Border, Transparency = 0.4}):Play()
        TweenService:Create(hoverBar, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}):Play()
        if sectionIcon then
            TweenService:Create(sectionIcon, TweenInfo.new(0.22),
                {ImageColor3 = self._Colors.Accent}):Play()
        end
    end)

    local lastToggleTime = 0
    header.MouseButton1Up:Connect(function()
        local now = os.clock()
        if now - lastToggleTime < 0.18 then return end
        lastToggleTime = now
        toggle()
    end)

    if expanded then
        body.Visible = true
        task.spawn(function()
            task.wait(0.08)
            updateHeight(false)
        end)
    end

    self:_registerThemeRefresher(function()
        section.BackgroundColor3 = self._Colors.Card
        section.BackgroundTransparency = self._STATE.SectionTransparency or 0.15
        cardStroke.Color = self._Colors.Border
        titleLabel.TextColor3 = self._Colors.Text
        summaryLabel.TextColor3 = self._Colors.TextDim
        if sectionIcon then sectionIcon.ImageColor3 = self._Colors.Accent end
        indicator.Image = GetIcon(expanded and "arrow-up" or "arrow-down")
        indicator.ImageColor3 = expanded and self._Colors.Accent or self._Colors.TextDim
        separator.BackgroundColor3 = self._Colors.Border
        if hoverBar then
            hoverBar.BackgroundColor3 = self._Colors.Accent
        end
        if scrollTrack then
            scrollTrack.BackgroundColor3 = self._Colors.Border
        end
        if scrollThumb then
            scrollThumb.BackgroundColor3 = self._Colors.Accent
        end
        if scrollThumbGlow then
            scrollThumbGlow.BackgroundColor3 = self._Colors.Accent
        end
    end)

    self:_queueSearchFilter(tabName)
    return self:_wrapSection(body)
end

-- Helper for backwards compatibility
function Library:CreateColumnSection(tabName, title, summary, defaultOpen)
    if self:_isDead() then return end
    local body = self:_unwrap(self:CreateSection(tabName, title, summary, defaultOpen))
    local row = Instance.new("Frame", body)
    row.Name = "Columns"
    row.LayoutOrder = 1
    row.Size = UDim2.new(1, 0, 0, 0)
    row.BackgroundTransparency = 1
    row.AutomaticSize = Enum.AutomaticSize.Y

    local function createColumn(name, xPosition)
        local column = Instance.new("Frame", row)
        column.Name = name
        column.Size = UDim2.new(0.5, -6, 0, 0)
        column.Position = UDim2.new(xPosition, xPosition == 0 and 0 or 6, 0, 0)
        column.BackgroundTransparency = 1
        column.AutomaticSize = Enum.AutomaticSize.Y
        local layout = Instance.new("UIListLayout", column)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        local padding = Instance.new("UIPadding", column)
        padding.PaddingLeft = UDim.new(0, 4)
        padding.PaddingRight = UDim.new(0, 4)
        padding.PaddingTop = UDim.new(0, 1)
        padding.PaddingBottom = UDim.new(0, 1)
        return column
    end

    local leftColumn = createColumn("LeftColumn", 0)
    local rightColumn = createColumn("RightColumn", 0.5)
    return self:_wrapSection(leftColumn), self:_wrapSection(rightColumn)
end

function Library:CreateDashboardBanner(tabName)
    if self:_isDead() then return end
    local topContainer = self._STATE.TabTopContainers[tabName]
    if not topContainer then
        error("[DoD UI] Tab '" .. tostring(tabName) .. "' not found. Call :CreateTab first.")
    end

    local function GetGreeting()
        local h = tonumber(os.date("%H")) or 12
        if h >= 5 and h < 12 then return "Good Morning"
        elseif h >= 12 and h < 17 then return "Good Afternoon"
        elseif h >= 17 and h < 20 then return "Good Evening"
        else return "Good Night" end
    end

    local PlayerCard = Instance.new("Frame", topContainer)
    PlayerCard.Name = "PlayerGreetingCard"
    PlayerCard.LayoutOrder = #topContainer:GetChildren() + 1
    PlayerCard.Size = UDim2.new(1, 0, 0, 68)
    PlayerCard.BackgroundColor3 = self._Colors.Card
    PlayerCard.BorderSizePixel = 0
    Instance.new("UICorner", PlayerCard).CornerRadius = UDim.new(0, 12)
    local pcStroke = Instance.new("UIStroke", PlayerCard)
    pcStroke.Color = self._Colors.Border
    pcStroke.Thickness = 1

    local AvatarImg = Instance.new("ImageLabel", PlayerCard)
    AvatarImg.Size = UDim2.new(0, 46, 0, 46)
    AvatarImg.Position = UDim2.new(0, 12, 0.5, -23)
    AvatarImg.BackgroundTransparency = 1
    AvatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150&filters=circular"
    Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)
    local avStroke = Instance.new("UIStroke", AvatarImg)
    avStroke.Color = self._Colors.Border
    avStroke.Thickness = 1

    local GreetLabel = Instance.new("TextLabel", PlayerCard)
    GreetLabel.Size = UDim2.new(0.5, -70, 0, 14)
    GreetLabel.Position = UDim2.new(0, 68, 0, 14)
    GreetLabel.BackgroundTransparency = 1
    GreetLabel.Font = Enum.Font.GothamMedium
    GreetLabel.TextSize = 10.5
    GreetLabel.TextColor3 = self._Colors.TextDim
    GreetLabel.TextXAlignment = Enum.TextXAlignment.Left
    GreetLabel.Text = GetGreeting()

    local NameLabel = Instance.new("TextLabel", PlayerCard)
    NameLabel.Size = UDim2.new(0.5, -70, 0, 22)
    NameLabel.Position = UDim2.new(0, 68, 0, 30)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.TextSize = 16
    NameLabel.TextColor3 = self._Colors.Text
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Text = LocalPlayer.DisplayName or LocalPlayer.Name

    local ClockLabel = Instance.new("TextLabel", PlayerCard)
    ClockLabel.Size = UDim2.new(0.5, 0, 0, 24)
    ClockLabel.Position = UDim2.new(0.5, -16, 0, 11)
    ClockLabel.BackgroundTransparency = 1
    ClockLabel.Font = Enum.Font.GothamBold
    ClockLabel.TextSize = 20
    ClockLabel.TextColor3 = self._Colors.Text
    ClockLabel.TextXAlignment = Enum.TextXAlignment.Right
    ClockLabel.Text = os.date("%H:%M:%S")

    local DateLabel = Instance.new("TextLabel", PlayerCard)
    DateLabel.Size = UDim2.new(0.45, 0, 0, 14)
    DateLabel.Position = UDim2.new(0.55, -16, 0, 38)
    DateLabel.BackgroundTransparency = 1
    DateLabel.Font = Enum.Font.GothamMedium
    DateLabel.TextSize = 10.5
    DateLabel.TextColor3 = self._Colors.TextDim
    DateLabel.TextXAlignment = Enum.TextXAlignment.Right
    DateLabel.Text = os.date("%d / %m / %Y")

    local placeName = "Roblox Experience"
    local creatorName = "Roblox Studio"
    local resolvedGameIcon = ""
    -- The product lookup is an HTTP call: running it inline froze the whole UI
    -- build for 1-3 seconds. Resolve it from a spawned thread further below and
    -- patch the labels once it lands.
    if resolvedGameIcon == "" then
        local universeId = (game.GameId and tonumber(game.GameId) and tonumber(game.GameId) > 0) and game.GameId or nil
        if universeId then
            resolvedGameIcon = "rbxthumb://type=GameIcon&id=" .. tostring(universeId) .. "&w=150&h=150"
        else
            resolvedGameIcon = "rbxthumb://type=Asset&id=" .. tostring(game.PlaceId) .. "&w=150&h=150"
        end
    end

    local GameCard = Instance.new("Frame", topContainer)
    GameCard.Name = "GameServerCard"
    GameCard.LayoutOrder = #topContainer:GetChildren() + 1
    GameCard.Size = UDim2.new(1, 0, 0, 86)
    GameCard.BackgroundColor3 = self._Colors.Card
    GameCard.BorderSizePixel = 0
    Instance.new("UICorner", GameCard).CornerRadius = UDim.new(0, 14)
    local gcStroke = Instance.new("UIStroke", GameCard)
    gcStroke.Color = self._Colors.Border
    gcStroke.Thickness = 1

    local BannerImg = Instance.new("ImageLabel", GameCard)
    BannerImg.Name = "MapBanner"
    BannerImg.AnchorPoint = Vector2.new(1, 0)
    BannerImg.Position = UDim2.new(1, 0, 0, 0)
    BannerImg.Size = UDim2.new(0.65, 0, 1, 0)
    BannerImg.BackgroundTransparency = 1
    BannerImg.ScaleType = Enum.ScaleType.Crop
    BannerImg.Image = resolvedGameIcon
    BannerImg.ImageTransparency = 0.70
    BannerImg.ZIndex = 1
    Instance.new("UICorner", BannerImg).CornerRadius = UDim.new(0, 14)

    local bGrad = Instance.new("UIGradient", BannerImg)
    bGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.35, 0.82),
        NumberSequenceKeypoint.new(1, 0.35)
    })

    local GameThumb = Instance.new("ImageLabel", GameCard)
    GameThumb.Size = UDim2.new(0, 60, 0, 60)
    GameThumb.Position = UDim2.new(0, 12, 0.5, -30)
    GameThumb.BackgroundColor3 = self._Colors.Bg2
    GameThumb.BackgroundTransparency = 0.1
    GameThumb.ScaleType = Enum.ScaleType.Fit
    GameThumb.Image = resolvedGameIcon
    GameThumb.ZIndex = 3
    Instance.new("UICorner", GameThumb).CornerRadius = UDim.new(0, 14)
    local gtStroke = Instance.new("UIStroke", GameThumb)
    gtStroke.Color = self._Colors.Border
    gtStroke.Thickness = 1

    local GameTitleLbl = Instance.new("TextLabel", GameCard)
    GameTitleLbl.Size = UDim2.new(1, -90, 0, 18)
    GameTitleLbl.Position = UDim2.new(0, 84, 0, 12)
    GameTitleLbl.BackgroundTransparency = 1
    GameTitleLbl.Font = Enum.Font.GothamBold
    GameTitleLbl.TextSize = 14
    GameTitleLbl.TextColor3 = self._Colors.Text
    GameTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    GameTitleLbl.Text = placeName
    GameTitleLbl.ZIndex = 3

    local GameSubLbl = Instance.new("TextLabel", GameCard)
    GameSubLbl.Size = UDim2.new(1, -90, 0, 14)
    GameSubLbl.Position = UDim2.new(0, 84, 0, 32)
    GameSubLbl.BackgroundTransparency = 1
    GameSubLbl.Font = Enum.Font.Gotham
    GameSubLbl.TextSize = 9.5
    GameSubLbl.TextColor3 = self._Colors.TextDim
    GameSubLbl.TextXAlignment = Enum.TextXAlignment.Left
    GameSubLbl.Text = "by " .. ((creatorName and creatorName ~= "") and creatorName or "Roblox Creator")
    GameSubLbl.ZIndex = 3

    task.spawn(function()
        local ok = pcall(function()
            local info = MarketplaceService:GetProductInfo(game.PlaceId)
            if not info or self:_isDead() then return end
            if info.Name and info.Name ~= "" then
                placeName = info.Name
                if GameTitleLbl.Parent then GameTitleLbl.Text = placeName end
            end
            if info.Creator and info.Creator.Name and info.Creator.Name ~= "" then
                creatorName = info.Creator.Name
                if GameSubLbl.Parent then
                    GameSubLbl.Text = "by " .. creatorName
                end
            end
            if info.IconImageAssetId and tonumber(info.IconImageAssetId) and tonumber(info.IconImageAssetId) > 0 then
                local iconUrl = "rbxassetid://" .. tostring(info.IconImageAssetId)
                if BannerImg.Parent then BannerImg.Image = iconUrl end
                if GameThumb.Parent then GameThumb.Image = iconUrl end
            end
        end)
        if not ok then
            -- Network unavailable or throttled: placeholders stay, which is fine.
        end
    end)

    local PillsRow = Instance.new("Frame", GameCard)
    PillsRow.Size = UDim2.new(1, -90, 0, 22)
    PillsRow.Position = UDim2.new(0, 84, 0, 52)
    PillsRow.BackgroundTransparency = 1
    PillsRow.ZIndex = 3

    local prLayout = Instance.new("UIListLayout", PillsRow)
    prLayout.FillDirection = Enum.FillDirection.Horizontal
    prLayout.Padding = UDim.new(0, 6)

    local function MakePill(iconName, initialText, minW)
        local p = Instance.new("Frame", PillsRow)
        p.AutomaticSize = Enum.AutomaticSize.X
        p.Size = UDim2.new(0, minW or 70, 0, 22)
        p.BackgroundColor3 = self._Colors.Bg2
        p.BackgroundTransparency = 0.3
        Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)

        local ps = Instance.new("UIStroke", p)
        ps.Color = self._Colors.Border
        ps.Thickness = 1
        ps.Transparency = 0.6

        local gradient = Instance.new("UIGradient", p)
        gradient.Rotation = 90
        gradient.Color = ColorSequence.new(self._Colors.Bg2, self._Colors.Bg)

        local layout = Instance.new("UIListLayout", p)
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        layout.VerticalAlignment = Enum.VerticalAlignment.Center

        local pad = Instance.new("UIPadding", p)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 10)
        pad.PaddingTop = UDim.new(0, 2)
        pad.PaddingBottom = UDim.new(0, 2)

        local icon = Instance.new("ImageLabel", p)
        icon.LayoutOrder = 1
        icon.Size = UDim2.fromOffset(12, 12)
        icon.BackgroundTransparency = 1
        icon.Image = GetIcon(iconName)
        icon.ImageColor3 = self._Colors.Accent
        icon.ScaleType = Enum.ScaleType.Fit

        local t = Instance.new("TextLabel", p)
        t.LayoutOrder = 2
        t.AutomaticSize = Enum.AutomaticSize.X
        t.Size = UDim2.new(0, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.GothamBold
        t.TextSize = 9
        t.TextColor3 = self._Colors.Text
        t.Text = initialText
        t.TextXAlignment = Enum.TextXAlignment.Left

        return { Frame = p, Stroke = ps, Label = t, Icon = icon, Gradient = gradient }
    end

    local pillId = MakePill("id-card", "ID " .. tostring(game.PlaceId), 90)
    local pillPl = MakePill("users", tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers), 60)
    local pillPing = MakePill("wifi", "35 ms", 55)
    local pillFps = MakePill("zap", "60 FPS", 65)

    task.spawn(function()
        local frames = 0
        local timeElapsed = 0
        local fpsConn = RunService.RenderStepped:Connect(function(dt)
            -- Only sample while the banner is actually on screen (open window and
            -- visible tab); it used to run for the whole session.
            if not PlayerCard.Visible then return end
            if not self._STATE.GuiVisible then return end
            frames = frames + 1
            timeElapsed = timeElapsed + dt
            if timeElapsed >= 0.5 then
                local fps = math.floor(frames / timeElapsed + 0.5)
                pillFps.Label.Text = tostring(fps) .. " FPS"
                frames = 0
                timeElapsed = 0
            end
        end)

        while task.wait(0.25) do
            if not PlayerCard or not PlayerCard.Parent then
                fpsConn:Disconnect()
                break
            end
            if not PlayerCard.Visible or not self._STATE.GuiVisible then
                continue
            end
            ClockLabel.Text = os.date("%H:%M:%S")
            DateLabel.Text = os.date("%d / %m / %Y")
            GreetLabel.Text = GetGreeting()
            pillPl.Label.Text = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers)
            pcall(function()
                local p = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                pillPing.Label.Text = tostring(p) .. " ms"
            end)
        end
    end)

    self:_registerThemeRefresher(function()
        PlayerCard.BackgroundColor3 = self._Colors.Card
        pcStroke.Color = self._Colors.Border
        avStroke.Color = self._Colors.Border
        GreetLabel.TextColor3 = self._Colors.TextDim
        NameLabel.TextColor3 = self._Colors.Text
        ClockLabel.TextColor3 = self._Colors.Text
        DateLabel.TextColor3 = self._Colors.TextDim
        GameCard.BackgroundColor3 = self._Colors.Card
        gcStroke.Color = self._Colors.Border
        GameThumb.BackgroundColor3 = self._Colors.Bg2
        gtStroke.Color = self._Colors.Border
        GameTitleLbl.TextColor3 = self._Colors.Text
        GameSubLbl.TextColor3 = self._Colors.TextDim
        for _, pill in ipairs({pillId, pillPl, pillPing, pillFps}) do
            pill.Frame.BackgroundColor3 = self._Colors.Bg2
            pill.Stroke.Color = self._Colors.Border
            pill.Label.TextColor3 = self._Colors.Text
            if pill.Icon then
                pill.Icon.ImageColor3 = self._Colors.Accent
            end
            if pill.Gradient then
                pill.Gradient.Color = ColorSequence.new(self._Colors.Bg2, self._Colors.Bg)
            end
        end
    end)

    return GameCard
end

function Library:CreateThemeCustomizer(tabName)
    if self:_isDead() then return end
    local section = self:CreateSection(
        tabName,
        "Theme Customizer",
        "Adjust appearance and effects live",
        true
    )
    local _perfDefault = 1
    if self._perfAuto == false then
        _perfDefault = (self._perfTier == "Potato" and 2) or (self._perfTier == "Balanced" and 3) or 4
    end
    self._perfDropdown = self:AddDropdown(section, "Performance Mode", { "Auto", "Potato", "Balanced", "High" },
        _perfDefault,
        function(_, val)
            if val == "Auto" then
                self._perfAuto = true
                local _t = self:_detectPerfTier()
                self:SetPerformanceTier(_t, true)
                self:Notify("PERFORMANCE", "Auto mode active", "info")
            else
                self._perfAuto = false
                self:SetPerformanceTier(val, false)
            end
        end
    )
    local themeIndex = table.find(D.ThemeNames, self.ThemeName) or 1
    self:AddDropdown(section, "Theme", D.ThemeNames, themeIndex, function(_, themeName)
        self._AccentOverride = nil
        self:SetTheme(themeName)
    end)
    
    local iconOptions = {
        "hexagon", "shield", "sword", "ghost", "skull", "crown", "star", 
        "zap", "flame", "diamond", "gem", "target", "crosshair", "eye", 
        "settings", "wrench", "cog", "command", "activity", "cpu", 
        "database", "terminal", "box", "package", "layers", "gamepad-2",
        "bot", "user", "users", "infinity", "orbit", "atom", "sparkles"
    }
    local currentIcon = self._TitleIconName or "hexagon"
    local iconIndex = table.find(iconOptions, currentIcon) or 1
    
    self:AddDropdown(section, "Title Icon", iconOptions, iconIndex, function(_, val)
        self:SetTitleIcon(val)
        self._TitleIconName = val
    end)
    
    self:AddTextbox(section, "Custom Title Icon", "Lucide Name / ID / URL", function(txt)
        if txt and txt ~= "" then
            self:SetTitleIcon(txt)
            self._TitleIconName = txt
        end
    end)
    self:AddColorPicker(section, "Accent color", self._Colors.Accent, function(color)
        self:SetAccentColor(color)
    end)
    self:AddDropdown(section, "Focus overlay pattern", D.FocusOverlayTypes,
        math.max(1, table.find(D.FocusOverlayTypes, self._STATE.FocusOverlayType) or 2),
        function(_, overlayType)
            self:SetFocusOverlay(self._STATE.FocusOverlayEnabled, overlayType)
        end
    )
    self:AddToggle(section, "Focus overlay", self._STATE.FocusOverlayEnabled, function(enabled)
        self:SetFocusOverlay(enabled, self._STATE.FocusOverlayType)
    end)
    self:AddToggle(section, "Acrylic blur", self.Acrylic, function(enabled)
        self:SetAcrylic(enabled)
    end)
    self:AddSlider(section, "Blur intensity", 0, 24, self.AcrylicBlurIntensity, 0, function(value)
        self:SetAcrylicIntensity(value)
    end)
    local wallpaperBaseUrl = "https://raw.githubusercontent.com/rapzxcwxcorparation/DemonOfDarknessUI/refs/heads/main/wallpaperdod/"
    local wallpaperOptions = {
        "None",
        "chika-fujiwara-3840x2160-16148.jpg",
        "h1-key-lovechapter-3840x2160-25940.jpg",
        "itachi-uchiha-3840x2160-25721.jpg",
        "kawaii-cat-girl-3840x2160-26545.png",
        "miles-morales-3840x2160-25975.jpg",
        "thumb-1920-1394067.png",
        "daemons.wtf.png",
        "miside-mita-dark-3840x2160-21051.jpg",
        "wp15319350-4k-anime-girl-eyes-wallpapers.jpg"
    }

    local currentWallpaperIndex = 1
    local wpName = tostring(self.WallpaperSource or "")
    for i, name in ipairs(wallpaperOptions) do
        if wpName:find(name, 1, true) or (self._UI.Wallpaper and self._UI.Wallpaper.Image and string.find(tostring(self._UI.Wallpaper.Image), name, 1, true)) then
            currentWallpaperIndex = i
            break
        end
    end

    local _pendingWallpaper = self.WallpaperSource

    self:AddDropdown(section, "Wallpaper Image", wallpaperOptions, currentWallpaperIndex, function(idx, val)
        if val == "None" then
            _pendingWallpaper = nil
            self:SetWallpaper(nil)
            self.WallpaperSource = nil
        else
            local fullUrl = wallpaperBaseUrl .. val
            _pendingWallpaper = fullUrl
            self:SetWallpaper(fullUrl, self.WallpaperTransparency or 0)
            self.WallpaperSource = fullUrl
        end
    end)

    self:AddButton(section, "Re-apply Wallpaper", function()
        if _pendingWallpaper then
            self:SetWallpaper(_pendingWallpaper, self.WallpaperTransparency or 0)
        else
            self:Notify("WALLPAPER", "Pilih wallpaper dulu di dropdown", "info")
        end
    end)

    self:AddButton(section, "Remove Wallpaper", function()
        self:SetWallpaper(nil)
        self.WallpaperSource = nil
        _pendingWallpaper = nil
        self:Notify("WALLPAPER", "Wallpaper dihapus", "info")
    end)
    
    self:AddTextbox(section, "Custom Image URL", "https://raw.github.../image.png", function(txt)
        if txt and txt ~= "" then
            _pendingWallpaper = txt
            self:SetWallpaper(txt, self.WallpaperTransparency or 0)
            self.WallpaperSource = txt
        end
    end)

    self:AddSlider(section, "Wallpaper Transparency", 0, 1, self.WallpaperTransparency or 0, 2, function(value)
        self.WallpaperTransparency = value
        if self._UI.Wallpaper and self._UI.Wallpaper.Visible then
            self._UI.Wallpaper.ImageTransparency = math.clamp(value, 0, 1)
        end
    end)

    self:AddDropdown(section, "Weather effect", D.WeatherTypes,
        table.find(D.WeatherTypes, self._STATE.WeatherType) or 1,
        function(_, weatherType)
            if self._STATE.WeatherEnabled then
                self:SetWeather(true, weatherType, self._STATE.WeatherIntensity)
            else
                self._STATE.WeatherType = weatherType
            end
        end
    )
    local weatherIntensity = math.clamp(tonumber(self._STATE.WeatherIntensity) or 65, 0, 100)
    self:AddSlider(section, "Weather intensity", 0, 100, weatherIntensity, 0, function(value)
        self:SetWeather(self._STATE.WeatherEnabled, self._STATE.WeatherType, value)
    end)
    self:AddToggle(section, "Weather effects", self._STATE.WeatherEnabled, function(enabled)
        self:SetWeather(enabled, self._STATE.WeatherType, self._STATE.WeatherIntensity)
    end)
    self:AddToggle(section, "UI Sounds", self._SoundsEnabled, function(enabled)
        self:SetSoundsEnabled(enabled)
    end)
    self:AddSlider(section, "Sound Volume", 0, 1, self._SoundVolume or 1, 2, function(value)
        self:SetSoundVolume(value)
    end)
    self:AddToggle(section, "Reduced Motion", self._STATE.ReducedMotion or false, function(enabled)
        self:SetReducedMotion(enabled)
    end)
    self:AddToggle(section, "Cursor Trail", self._cursorTrailEnabled or false, function(enabled)
        self:SetCursorTrail(enabled)
    end)
    self:AddColorPicker(section, "Cursor Trail Color", self._cursorTrailColor or Color3.fromRGB(0, 255, 255), function(color)
        self:SetCursorTrailColor(color)
    end)
    local _densityIdx = 2
    local _curDensity = self._STATE.LayoutDensity or "Normal"
    if _curDensity == "Compact" then _densityIdx = 1
    elseif _curDensity == "Spacious" then _densityIdx = 3 end
    self:AddDropdown(section, "Layout Density", { "Compact", "Normal", "Spacious" }, _densityIdx, function(idx, val)
        self:SetLayoutDensity(val)
    end)
    self:AddSlider(section, "Section Transparency", 0, 1, self._STATE.SectionTransparency or 0.15, 2, function(value)
        self:SetSectionTransparency(value)
    end)
    local notifPositionLabels = { "Top Right", "Top Left", "Bottom Right", "Bottom Left" }
    local notifPositionKeys = { "TopRight", "TopLeft", "BottomRight", "BottomLeft" }
    local notifCurrentKey = self._NotifPosition or "TopRight"
    local notifCurrentIdx = 1
    for i, key in ipairs(notifPositionKeys) do
        if key == notifCurrentKey then notifCurrentIdx = i; break end
    end
    self:AddDropdown(section, "Notification Position", notifPositionLabels, notifCurrentIdx, function(idx, _)
        self:SetNotificationPosition(notifPositionKeys[idx])
    end)
    self:AddToggle(section, "Tooltip", self._STATE.TooltipEnabled ~= false, function(enabled)
        self:SetTooltipEnabled(enabled)
    end)
    self:AddSlider(section, "Tooltip Background Transparency", 0, 1, self._STATE.TooltipTransparency or 0.15, 2, function(value)
        self:SetTooltipTransparency(value)
    end)
    self:AddButton(section, "Clear Wallpaper Cache", function()
        self:ClearWallpaperCache()
    end)
    self:AddButton(section, "Save Theme Settings", function()
        self:SaveThemeConfig("settings")
    end)
    self:AddButton(section, "Reset Theme to Default", function()
        self:Confirm("Reset Theme", "Reset all theme customization to defaults?", function()
            self:ResetThemeConfig()
        end)
    end)
    return section
end

function Library:CreateQuickDashboard(tabName, columnName)
    if self:_isDead() then return end
    columnName = columnName or "Right"

    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer

    local QuickBox = self:_unwrap(self:CreateSection(tabName, "QUICK INSTANCE CONTROL", "Manage your session and community", true, columnName, "refresh-cw"))

    local function CreateActionRow(title, desc, iconName, callback)
        local holder = Instance.new("TextButton", QuickBox)
        holder.Size = UDim2.new(1, 0, 0, 54)
        holder.BackgroundColor3 = self._Colors.Card
        holder.BackgroundTransparency = 0.3
        holder.Text = ""
        holder.AutoButtonColor = false
        holder.BorderSizePixel = 0
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", holder)
        stroke.Color = self._Colors.Border
        stroke.Thickness = 1
        stroke.Transparency = 0.5

        local iconBg = Instance.new("Frame", holder)
        iconBg.Size = UDim2.fromOffset(34, 34)
        iconBg.Position = UDim2.new(0, 10, 0.5, -17)
        iconBg.BackgroundColor3 = self._Colors.Bg2
        iconBg.BorderSizePixel = 0
        Instance.new("UICorner", iconBg).CornerRadius = UDim.new(0, 6)

        local icon = Instance.new("ImageLabel", iconBg)
        icon.Size = UDim2.fromOffset(18, 18)
        icon.Position = UDim2.new(0.5, -9, 0.5, -9)
        icon.BackgroundTransparency = 1
        icon.Image = GetIcon(iconName)
        icon.ImageColor3 = self._Colors.Accent

        local titleLbl = Instance.new("TextLabel", holder)
        titleLbl.Size = UDim2.new(1, -70, 0, 18)
        titleLbl.Position = UDim2.new(0, 54, 0, 10)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = title
        titleLbl.TextColor3 = self._Colors.Text
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 13
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local descLbl = Instance.new("TextLabel", holder)
        descLbl.Size = UDim2.new(1, -70, 0, 14)
        descLbl.Position = UDim2.new(0, 54, 0, 28)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = desc
        descLbl.TextColor3 = self._Colors.TextDim
        descLbl.Font = Enum.Font.GothamMedium
        descLbl.TextSize = 10
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.TextTruncate = Enum.TextTruncate.AtEnd

        holder.MouseEnter:Connect(function()
            self:PlaySound("Hover")
            TweenService:Create(stroke, TweenInfo.new(0.15), {Color = self._Colors.Accent, Transparency = 0.1}):Play()
            TweenService:Create(holder, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
        end)
        holder.MouseLeave:Connect(function()
            TweenService:Create(stroke, TweenInfo.new(0.15), {Color = self._Colors.Border, Transparency = 0.5}):Play()
            TweenService:Create(holder, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
        end)
        holder.MouseButton1Click:Connect(function()
            self:PlaySound("Click")
            callback()
        end)
        
        self:_registerThemeRefresher(function()
            holder.BackgroundColor3 = self._Colors.Card
            stroke.Color = self._Colors.Border
            iconBg.BackgroundColor3 = self._Colors.Bg2
            icon.ImageColor3 = self._Colors.Accent
            titleLbl.TextColor3 = self._Colors.Text
            descLbl.TextColor3 = self._Colors.TextDim
        end)
        self:_registerSearchControl(holder, title .. " " .. desc)
        return holder
    end

    CreateActionRow("Reconnect Instance", "Rejoin the current server", "refresh-cw", function()
        -- Rejoin the *same* server (JobId) instead of teleporting into a random
        -- one, and guard against double-clicks creating two teleports.
        if self._teleporting then return end
        self._teleporting = true
        self:Notify("TELEPORT", "Reconnecting to server...", "info")
        task.spawn(function()
            task.wait(0.8)
            local ok = pcall(function()
                if game.JobId and game.JobId ~= "" then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                else
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
            if not ok then
                self._teleporting = false
                self:Notify("TELEPORT", "Reconnect failed — try again", "error")
            end
        end)
    end)

    CreateActionRow("Server Hop", "Move to a different public server", "server", function()
        if self._teleporting then return end
        self._teleporting = true
        self:Notify("SERVER HOP", "Searching for another server...", "info")
        task.spawn(function()
            local success = pcall(function()
                local url = string.format(
                    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
                    game.PlaceId)
                local response = HttpService:JSONDecode(game:HttpGet(url))
                local picked = nil
                if response and type(response.data) == "table" then
                    -- Skip the server we are already on; prefer populated-but-not-full.
                    for _, server in ipairs(response.data) do
                        if server.id ~= game.JobId then
                            picked = server
                            if (server.playing or 0) > 0 then break end
                        end
                    end
                end
                if picked then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, picked.id, LocalPlayer)
                else
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
            if not success then
                self._teleporting = false
                self:Notify("ERROR", "Server hop failed, rejoining instead...", "error")
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            end
        end)
    end)

    CreateActionRow("Discord Community", "Copy encrypted access link to clipboard", "message-circle", function()
        local discordLink = "https://discord.gg/rapptezetyee"
        if setclipboard then
            setclipboard(discordLink)
            self:Notify("DISCORD", "Link copied to clipboard!", "success")
        else
            self:Notify("DISCORD", "Executor doesn't support clipboard", "error")
        end
    end)
    return self:_wrapSection(QuickBox)
end

function Library:CreatePerformanceDashboard(tabName, columnName)
    if self:_isDead() then return end
    columnName = columnName or "Left"

    local PerfBox = self:_unwrap(self:CreateSection(tabName, "SYSTEM PERFORMANCE", "Realtime hardware and network stats", true, columnName, "activity"))

    -- 1. Container for Metrics (Grid Layout)
    local metricsContainer = Instance.new("Frame", PerfBox)
    metricsContainer.Size = UDim2.new(1, 0, 0, 120)
    metricsContainer.BackgroundTransparency = 1
    metricsContainer.LayoutOrder = 1

    local grid = Instance.new("UIGridLayout", metricsContainer)
    grid.CellSize = UDim2.new(0.5, -4, 0.5, -4)
    grid.CellPadding = UDim2.new(0, 8, 0, 8)
    grid.SortOrder = Enum.SortOrder.LayoutOrder

    -- Helper: MakeMetric Card
    local function MakeMetric(label, defaultVal, sub, order)
        local card = Instance.new("Frame", metricsContainer)
        card.LayoutOrder = order
        card.BackgroundColor3 = self._Colors.Bg2
        card.BackgroundTransparency = 0.2
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", card)
        stroke.Color = self._Colors.Border
        stroke.Thickness = 1
        stroke.Transparency = 0.5

        local lbl = Instance.new("TextLabel", card)
        lbl.Size = UDim2.new(1, -16, 0, 14)
        lbl.Position = UDim2.new(0, 8, 0, 8)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 9
        lbl.TextColor3 = self._Colors.TextDim
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.upper(label)

        local valLbl = Instance.new("TextLabel", card)
        valLbl.Size = UDim2.new(1, -16, 0, 22)
        valLbl.Position = UDim2.new(0, 8, 0, 22)
        valLbl.BackgroundTransparency = 1
        valLbl.Font = Enum.Font.GothamBlack
        valLbl.TextSize = 18
        valLbl.TextColor3 = self._Colors.Accent
        valLbl.TextXAlignment = Enum.TextXAlignment.Left
        valLbl.Text = defaultVal

        local subLbl = Instance.new("TextLabel", card)
        subLbl.Size = UDim2.new(1, -16, 0, 12)
        subLbl.Position = UDim2.new(0, 8, 0, 44)
        subLbl.BackgroundTransparency = 1
        subLbl.Font = Enum.Font.GothamMedium
        subLbl.TextSize = 9
        subLbl.TextColor3 = self._Colors.TextDim
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.Text = sub

        self:_registerThemeRefresher(function()
            card.BackgroundColor3 = self._Colors.Bg2
            stroke.Color = self._Colors.Border
            lbl.TextColor3 = self._Colors.TextDim
            valLbl.TextColor3 = self._Colors.Accent
            subLbl.TextColor3 = self._Colors.TextDim
        end)

        return valLbl
    end

    local fpsM = MakeMetric("FRAMERATE", "60.0", "FPS", 1)
    local pingM = MakeMetric("LATENCY", "35 ms", "OPTIMAL", 2)
    local plM = MakeMetric("PLAYERS", tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers), "ONLINE", 3)
    local sessM = MakeMetric("SESSION", "00:00", "ACTIVE", 4)

    -- 2. Graph (Framebuffer Activity)
    local WaveBox = Instance.new("Frame", PerfBox)
    WaveBox.Size = UDim2.new(1, 0, 0, 72)
    WaveBox.BackgroundColor3 = self._Colors.Bg2
    WaveBox.BackgroundTransparency = 0.2
    WaveBox.BorderSizePixel = 0
    WaveBox.LayoutOrder = 2
    Instance.new("UICorner", WaveBox).CornerRadius = UDim.new(0, 8)

    local wStroke = Instance.new("UIStroke", WaveBox)
    wStroke.Color = self._Colors.Border
    wStroke.Thickness = 1
    wStroke.Transparency = 0.5

    local wTitle = Instance.new("TextLabel", WaveBox)
    wTitle.Size = UDim2.new(0.5, -10, 0, 14)
    wTitle.Position = UDim2.new(0, 12, 0, 8)
    wTitle.BackgroundTransparency = 1
    wTitle.Font = Enum.Font.GothamBold
    wTitle.TextSize = 9
    wTitle.TextColor3 = self._Colors.TextDim
    wTitle.TextXAlignment = Enum.TextXAlignment.Left
    wTitle.Text = "FRAMEBUFFER ACTIVITY"

    local wSub = Instance.new("TextLabel", WaveBox)
    wSub.Size = UDim2.new(0.5, -10, 0, 14)
    wSub.Position = UDim2.new(0.5, 0, 0, 8)
    wSub.BackgroundTransparency = 1
    wSub.Font = Enum.Font.GothamBold
    wSub.TextSize = 9
    wSub.TextColor3 = self._Colors.Accent
    wSub.TextXAlignment = Enum.TextXAlignment.Right
    wSub.Text = "REALTIME | 60 FPS"

    local barBox = Instance.new("Frame", WaveBox)
    barBox.Size = UDim2.new(1, -24, 0, 32)
    barBox.Position = UDim2.new(0, 12, 0, 28)
    barBox.BackgroundTransparency = 1
    barBox.ClipsDescendants = true

    local bLayout = Instance.new("UIListLayout", barBox)
    bLayout.FillDirection = Enum.FillDirection.Horizontal
    bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    bLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    bLayout.Padding = UDim.new(0, 3)

    local graphBars = {}
    for i = 1, 20 do
        local b = Instance.new("Frame", barBox)
        b.Size = UDim2.new(0, 4, 0.6, 0)
        b.BackgroundColor3 = self._Colors.Accent
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        table.insert(graphBars, b)
    end

    local fpsHistory = {}
    for i = 1, 20 do
        fpsHistory[i] = 60
    end

    self:_registerThemeRefresher(function()
        WaveBox.BackgroundColor3 = self._Colors.Bg2
        wStroke.Color = self._Colors.Border
        wTitle.TextColor3 = self._Colors.TextDim
        wSub.TextColor3 = self._Colors.Accent
        for _, b in ipairs(graphBars) do
            b.BackgroundColor3 = self._Colors.Accent
        end
    end)

    -- 3. Live Logic
    local currentFPS = 60
    local frameCount = 0
    local lastCheck = os.clock()
    local startTime = os.clock()
    local maxObservedFPS = 60

    Fn.track(RunService.RenderStepped, function()
        if not WaveBox.Parent then return end
        -- Idle when the dashboard is not on screen: this used to run for the whole
        -- session on every rendered frame.
        if not WaveBox.Visible or not self._STATE.GuiVisible then
            lastCheck = os.clock()
            frameCount = 0
            return
        end
        frameCount = frameCount + 1
        local now = os.clock()
        local elapsed = now - lastCheck
        if elapsed >= 0.2 then
            currentFPS = math.clamp(math.floor((frameCount / elapsed) + 0.5), 1, 360)
            fpsM.Text = string.format("%.1f", currentFPS)
            wSub.Text = "REALTIME | " .. tostring(currentFPS) .. " FPS"
            frameCount = 0
            lastCheck = now

            if currentFPS > maxObservedFPS then
                maxObservedFPS = math.max(60, currentFPS)
            end

            table.remove(fpsHistory, 1)
            table.insert(fpsHistory, currentFPS)

            -- Direct sizing instead of 24 fresh tweens every 0.2s.
            for i, bar in ipairs(graphBars) do
                local sample = fpsHistory[i] or 60
                local targetHeight = math.clamp(sample / maxObservedFPS, 0.1, 0.95)
                bar.Size = UDim2.new(0, 4, targetHeight, 0)
            end
        end
    end, self)

    task.spawn(function()
        while task.wait(0.5) do
            if not WaveBox.Parent then break end
            if not WaveBox.Visible or not self._STATE.GuiVisible then continue end
            local elapsed = math.floor(os.clock() - startTime)
            sessM.Text = string.format("%02d:%02d", math.floor(elapsed / 60), elapsed % 60)
            plM.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)
            pcall(function()
                local p = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                pingM.Text = tostring(p) .. " ms"
            end)
        end
    end)

    return self:_wrapSection(PerfBox)
end


return true
