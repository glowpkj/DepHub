local Components = {}
Components.__index = Components

local function destroyWrapper(wrapper)
    if wrapper.Destroyed then return end
    wrapper.Destroyed = true
    if wrapper.Cleanup then pcall(wrapper.Cleanup, wrapper) end
    if wrapper.Instance then wrapper.Instance:Destroy() end
    wrapper.Instance = nil
end

function Components.new(window, utils, theme)
    return setmetatable({Window=window, Utils=utils, Theme=theme}, Components)
end

function Components:_section(page, title)
    local holder = Instance.new("Frame")
    holder.Name = "Section_" .. tostring(title)
    holder.Size = UDim2.new(1, 0, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.BackgroundTransparency = 1
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = holder
    local header = self.Utils:Text(holder, string.upper(tostring(title)), UDim2.new(1, -25, 0, 29), UDim2.fromOffset(25, 0), 13, Enum.Font.GothamBold, self.Theme.White)
    header.LayoutOrder = 1
    local accent = Instance.new("Frame")
    accent.Name = "SectionAccent"
    accent.Size = UDim2.fromOffset(17, 2)
    accent.Position = UDim2.fromOffset(-25, 14)
    accent.BackgroundColor3 = self.Theme.Accent
    accent.BorderSizePixel = 0
    accent.Parent = header
    local section = {Instance=holder, Header=header, NextOrder=2, Destroyed=false, Controls={}}
    function section:Add(object)
        if self.Destroyed or not object then return end
        object.LayoutOrder = self.NextOrder
        self.NextOrder += 1
        object.Parent = holder
    end
    function section:SetVisible(visible) if holder then holder.Visible = visible == true end end
    function section:Destroy() destroyWrapper(self) end
    page:Add(holder)
    return section
end

function Components:_base(section, height)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, height)
    frame.BackgroundColor3 = self.Theme.Surface
    frame.BorderSizePixel = 0
    self.Utils:Corner(frame, UDim.new(0, 5))
    self.Utils:Stroke(frame, self.Theme.Border, 0.13, 1)
    section:Add(frame)
    return frame
end

function Components:_info(frame, title, description)
    local titleLabel = self.Utils:Text(frame, string.upper(tostring(title)), UDim2.new(1, -190, 0, 26), UDim2.fromOffset(14, 7), 14, Enum.Font.GothamBold, self.Theme.White)
    local descriptionLabel = self.Utils:Text(frame, string.upper(tostring(description or "")), UDim2.new(1, -190, 0, 22), UDim2.fromOffset(14, 32), 11, Enum.Font.GothamMedium, self.Theme.White)
    descriptionLabel.TextTransparency = 0.24
    return titleLabel, descriptionLabel
end

function Components:_register(wrapper, section, reflow)
    wrapper.Destroy = destroyWrapper
    wrapper.Reflow = reflow or function() end
    section.Controls[#section.Controls + 1] = wrapper
    self.Window:RegisterResponsive(wrapper)
    wrapper:Reflow(self.Window.Compact)
    return wrapper
end

function Components:CreateSection(page, title)
    return self:_section(page, title)
end

function Components:CreateLabel(section, options)
    options = options or {}
    local frame = self:_base(section, options.Height or 62)
    local title = self.Utils:Text(frame, string.upper(tostring(options.Title or "INFO")), UDim2.new(1, -28, 0, 24), UDim2.fromOffset(14, 7), 12, Enum.Font.GothamBold, self.Theme.White)
    local value = self.Utils:Text(frame, tostring(options.Text or options.Description or ""), UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 31), 12, Enum.Font.Gotham, self.Theme.White)
    value.TextTransparency = 0.18
    local wrapper = {Instance=frame, Title=title, Label=value, Destroyed=false}
    function wrapper:SetText(text) value.Text = tostring(text or "") end
    function wrapper:GetText() return value.Text end
    return self:_register(wrapper, section)
end

function Components:CreateButton(section, options)
    options = options or {}
    local hasDescription=type(options.Description)=="string" and options.Description~=""
    local frame = self:_base(section, hasDescription and 70 or 58)
    local label = self.Utils:Text(frame, string.upper(tostring(options.Title or "BUTTON")), UDim2.new(1, -56, 0, 26), UDim2.fromOffset(14, hasDescription and 8 or 16), 14, Enum.Font.GothamBold, self.Theme.White)
    if hasDescription then
        local description=self.Utils:Text(frame,string.upper(options.Description),UDim2.new(1,-56,0,22),UDim2.fromOffset(14,35),11,Enum.Font.GothamMedium,self.Theme.White)
        description.TextTransparency=0.24
    end
    local arrow = self.Utils:Text(frame, "›", UDim2.fromOffset(24, 36), UDim2.new(1, -37, 0.5, -18), 23, Enum.Font.GothamBold, self.Theme.White, Enum.TextXAlignment.Center)
    local stroke = frame:FindFirstChildOfClass("UIStroke")
    local hitbox = Instance.new("TextButton")
    hitbox.Size, hitbox.BackgroundTransparency, hitbox.Text, hitbox.AutoButtonColor = UDim2.fromScale(1, 1), 1, "", false
    hitbox.Parent = frame
    local wrapper = {Instance=frame, Label=label, Hitbox=hitbox, Destroyed=false}
    self.Utils:Track(hitbox.MouseEnter:Connect(function()
        if wrapper.Destroyed then return end
        frame.BackgroundColor3 = self.Theme.SurfaceHover
        if stroke then stroke.Color = self.Theme.Accent end
    end))
    self.Utils:Track(hitbox.MouseLeave:Connect(function()
        if wrapper.Destroyed then return end
        frame.BackgroundColor3 = self.Theme.Surface
        if stroke then stroke.Color = self.Theme.Border end
    end))
    self.Utils:Track(hitbox.MouseButton1Click:Connect(function()
        if not wrapper.Destroyed then self.Window:SafeCall(options.Callback) end
    end))
    return self:_register(wrapper, section)
end

function Components:CreateToggle(section, options)
    options = options or {}
    local value = options.Default == true
    local frame = self:_base(section, 68)
    local title, description = self:_info(frame, options.Title or "TOGGLE", options.Description)
    local switch = Instance.new("Frame")
    switch.Size = UDim2.fromOffset(24, 24)
    switch.AnchorPoint = Vector2.new(0, 0.5)
    switch.BackgroundColor3 = self.Theme.Input
    switch.BorderSizePixel = 0
    switch.Parent = frame
    self.Utils:Corner(switch, UDim.new(0, 3))
    local switchStroke = self.Utils:Stroke(switch, self.Theme.Border, 0.05, 1.3)
    local check = self.Utils:Text(switch, "✓", UDim2.fromScale(1, 1), nil, 17, Enum.Font.GothamBold, self.Theme.White, Enum.TextXAlignment.Center)
    check.Visible = false
    local hitbox = Instance.new("TextButton")
    hitbox.Size, hitbox.BackgroundTransparency, hitbox.Text, hitbox.AutoButtonColor = UDim2.fromScale(1, 1), 1, "", false
    hitbox.Parent = frame
    local wrapper = {Instance=frame, Hitbox=hitbox, Destroyed=false}
    local function render()
        switch.BackgroundColor3 = value and self.Theme.AccentDark or self.Theme.Input
        switchStroke.Color = value and self.Theme.Accent or self.Theme.Border
        check.Visible = value
    end
    function wrapper:GetValue() return value end
    function wrapper:SetValue(newValue, silent)
        value = newValue == true; render()
        if not silent then self._owner.Window:SafeCall(options.Callback, value) end
    end
    wrapper._owner = self
    self.Utils:Track(hitbox.MouseButton1Click:Connect(function() if not wrapper.Destroyed then wrapper:SetValue(not value) end end))
    render()
    return self:_register(wrapper, section, function(_, compact)
        frame.Size = UDim2.new(1, 0, 0, compact and 92 or 68)
        title.Size = UDim2.new(1, compact and -28 or -64, 0, 26)
        description.Size = UDim2.new(1, compact and -28 or -64, 0, 22)
        switch.Position = compact and UDim2.new(1, -39, 1, -23) or UDim2.new(1, -40, 0.5, 0)
    end)
end

function Components:CreateSlider(section, options)
    options = options or {}
    local minimum, maximum = tonumber(options.Min) or 0, tonumber(options.Max) or 100
    if maximum <= minimum then maximum = minimum + 1 end
    local step = math.max(tonumber(options.Step) or 1, 0.001)
    local value = math.clamp(tonumber(options.Default) or minimum, minimum, maximum)
    local frame = self:_base(section, 86)
    local title,description=self:_info(frame, options.Title or "SLIDER", options.Description)
    local valueLabel = self.Utils:Text(frame, "", UDim2.fromOffset(72, 26), UDim2.new(1, -86, 0, 9), 13, Enum.Font.GothamBold, self.Theme.White, Enum.TextXAlignment.Right)
    local bar = Instance.new("Frame")
    bar.Size, bar.Position, bar.BackgroundColor3, bar.BorderSizePixel = UDim2.new(1, -28, 0, 4), UDim2.new(0, 14, 1, -19), self.Theme.Input, 0
    bar.Parent = frame; self.Utils:Corner(bar, UDim.new(1, 0))
    local fill = Instance.new("Frame")
    fill.BackgroundColor3, fill.BorderSizePixel, fill.Parent = self.Theme.Accent, 0, bar; self.Utils:Corner(fill, UDim.new(1, 0))
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.fromOffset(11, 11)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.BackgroundColor3 = self.Theme.White
    thumb.BorderSizePixel = 0
    thumb.Parent = bar
    self.Utils:Corner(thumb, UDim.new(1, 0))
    local hitbox = Instance.new("TextButton")
    hitbox.Size, hitbox.Position, hitbox.BackgroundTransparency, hitbox.Text = UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0.5, -14), 1, ""
    hitbox.Parent = bar
    local dragging, touch = false, nil
    local wrapper = {Instance=frame, Hitbox=hitbox, Destroyed=false}
    local function render(silent)
        local alpha = (value-minimum)/(maximum-minimum)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        thumb.Position = UDim2.fromScale(alpha, 0.5)
        valueLabel.Text = step >= 1 and tostring(math.floor(value + 0.5)) or string.format("%.2f", value)
        if not silent then self.Window:SafeCall(options.Callback, value) end
    end
    local function fromX(x)
        if bar.AbsoluteSize.X <= 0 then return end
        local alpha = math.clamp((x-bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
        wrapper:SetValue(minimum + (maximum-minimum)*alpha)
    end
    function wrapper:GetValue() return value end
    function wrapper:SetValue(newValue, silent)
        local raw = math.clamp(tonumber(newValue) or minimum, minimum, maximum)
        value = math.clamp(minimum + math.floor(((raw-minimum)/step)+0.5)*step, minimum, maximum)
        render(silent == true)
    end
    self.Utils:Track(hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging=true; fromX(input.Position.X)
        elseif input.UserInputType == Enum.UserInputType.Touch then dragging=true; touch=input; fromX(input.Position.X) end
    end))
    self.Utils:Track(game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == touch) then fromX(input.Position.X) end
    end))
    self.Utils:Track(game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input == touch then dragging=false; touch=nil end
    end))
    render(true)
    return self:_register(wrapper, section, function(_,compact)
        frame.Size=UDim2.new(1,0,0,compact and 112 or 86)
        title.Size=UDim2.new(1,compact and -28 or -190,0,26)
        description.Size=UDim2.new(1,compact and -28 or -190,0,22)
        valueLabel.Position=compact and UDim2.new(1,-86,0,56) or UDim2.new(1,-86,0,9)
    end)
end

function Components:CreateDropdown(section, options)
    options = options or {}
    local values, value, open = table.clone(options.Values or {}), options.Default, false
    if value == nil then value = values[1] end
    local frame = self:_base(section, 70)
    local title, description = self:_info(frame, options.Title or "DROPDOWN", options.Description)
    local button = Instance.new("TextButton")
    button.BackgroundColor3, button.BorderSizePixel, button.TextColor3, button.TextSize, button.Font, button.AutoButtonColor = self.Theme.Input, 0, self.Theme.White, 12, Enum.Font.GothamBold, false
    button.Parent = frame; self.Utils:Corner(button, UDim.new(0, 6)); self.Utils:Stroke(button, self.Theme.Border, 0.3, 1)
    local menu = Instance.new("ScrollingFrame")
    menu.BackgroundColor3, menu.BorderSizePixel, menu.ClipsDescendants, menu.Visible = self.Theme.SurfaceElevated, 0, true, false
    menu.CanvasSize, menu.AutomaticCanvasSize, menu.ScrollBarThickness, menu.ScrollBarImageColor3 = UDim2.fromOffset(0,0), Enum.AutomaticSize.Y, 2, self.Theme.Accent
    menu.Parent = frame; self.Utils:Corner(menu, UDim.new(0, 6)); self.Utils:Stroke(menu, self.Theme.Border, 0.2, 1)
    local list = Instance.new("UIListLayout"); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = menu
    local wrapper = {Instance=frame, Button=button, Menu=menu, Destroyed=false, OptionConnections={}}
    local function close() open=false; menu.Visible=false; wrapper:Reflow(self.Window.Compact) end
    local function rebuild()
        for _, connection in ipairs(wrapper.OptionConnections) do pcall(connection.Disconnect, connection) end
        wrapper.OptionConnections = {}
        for _, child in ipairs(menu:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        for index, option in ipairs(values) do
            local item = Instance.new("TextButton")
            item.Size, item.BackgroundColor3, item.BorderSizePixel = UDim2.new(1, 0, 0, 30), option==value and self.Theme.AccentDark or self.Theme.SurfaceElevated, 0
            item.Text, item.TextColor3, item.Font, item.TextSize, item.LayoutOrder = string.upper(tostring(option)), self.Theme.White, Enum.Font.GothamBold, 11, index
            item.Parent = menu
            wrapper.OptionConnections[#wrapper.OptionConnections+1] = item.MouseButton1Click:Connect(function() wrapper:SetValue(option); close() end)
        end
        menu.Size = UDim2.new(0, 150, 0, math.min(#values, 6)*30)
    end
    function wrapper:GetValue() return value end
    function wrapper:GetValues() return table.clone(values) end
    function wrapper:SetValues(newValues, newValue, silent)
        values = table.clone(newValues or {})
        value = newValue ~= nil and newValue or values[1]
        button.Text = string.upper(tostring(value or "SELECT")); rebuild(); close()
        if not silent then self._owner.Window:SafeCall(options.Callback, value) end
    end
    function wrapper:SetValue(newValue, silent)
        if not table.find(values, newValue) then return false end
        value = newValue; button.Text = string.upper(tostring(value))
        rebuild()
        if not silent then self._owner.Window:SafeCall(options.Callback, value) end
        return true
    end
    wrapper._owner = self
    function wrapper:Cleanup()
        for _, connection in ipairs(self.OptionConnections) do pcall(connection.Disconnect, connection) end
        self.OptionConnections = {}
    end
    self.Utils:Track(button.MouseButton1Click:Connect(function() if #values > 0 then open=not open; menu.Visible=open; wrapper:Reflow(self.Window.Compact) end end))
    function wrapper:Reflow(compact)
        local baseHeight = compact and 112 or 70
        local xSize = compact and UDim2.new(1, -28, 0, 36) or UDim2.fromOffset(150, 36)
        local xPos = compact and UDim2.new(0, 14, 0, 64) or UDim2.new(1, -164, 0.5, -18)
        button.Size, button.Position = xSize, xPos
        title.Size, description.Size = UDim2.new(1, compact and -28 or -190, 0, 26), UDim2.new(1, compact and -28 or -190, 0, 22)
        local menuHeight = open and math.min(#values, 6)*30 or 0
        menu.Position = compact and UDim2.fromOffset(14, 104) or UDim2.new(1, -164, 0, 57)
        menu.Size, frame.Size = UDim2.new(xSize.X.Scale, xSize.X.Offset, 0, menuHeight), UDim2.new(1, 0, 0, baseHeight + menuHeight)
    end
    button.Text = string.upper(tostring(value or "SELECT")); rebuild()
    return self:_register(wrapper, section, wrapper.Reflow)
end

function Components:CreateInput(section, options)
    options = options or {}
    local frame = self:_base(section, 70)
    local title, description = self:_info(frame, options.Title or "INPUT", options.Description)
    local box = Instance.new("TextBox")
    box.BackgroundColor3, box.BorderSizePixel, box.Text, box.PlaceholderText = self.Theme.Input, 0, tostring(options.Default or ""), tostring(options.Placeholder or "ENTER VALUE")
    box.TextColor3, box.PlaceholderColor3, box.Font, box.TextSize, box.ClearTextOnFocus = self.Theme.White, self.Theme.White, Enum.Font.GothamMedium, 12, false
    box.Parent = frame; self.Utils:Corner(box, UDim.new(0, 6)); self.Utils:Stroke(box, self.Theme.Border, 0.3, 1)
    local wrapper = {Instance=frame, Box=box, Destroyed=false}
    function wrapper:GetValue() return box.Text end
    function wrapper:SetValue(newValue, silent) box.Text=tostring(newValue or ""); if not silent then self._owner.Window:SafeCall(options.Callback, box.Text, false) end end
    wrapper._owner=self
    self.Utils:Track(box.FocusLost:Connect(function(enter) if not wrapper.Destroyed then self.Window:SafeCall(options.Callback, box.Text, enter) end end))
    return self:_register(wrapper, section, function(_, compact)
        frame.Size=UDim2.new(1,0,0,compact and 112 or 70)
        title.Size,description.Size=UDim2.new(1,compact and -28 or -190,0,26),UDim2.new(1,compact and -28 or -190,0,22)
        box.Size=compact and UDim2.new(1,-28,0,36) or UDim2.fromOffset(150,36)
        box.Position=compact and UDim2.fromOffset(14,64) or UDim2.new(1,-164,0.5,-18)
    end)
end

function Components:CreateKeybind(section, options)
    options = options or {}
    local value, listening = options.Default or Enum.KeyCode.RightControl, false
    local frame = self:_base(section, 70)
    local title, description = self:_info(frame, options.Title or "KEYBIND", options.Description)
    local button = Instance.new("TextButton")
    button.BackgroundColor3, button.BorderSizePixel, button.TextColor3, button.Font, button.TextSize, button.AutoButtonColor = self.Theme.Input, 0, self.Theme.White, Enum.Font.GothamBold, 11, false
    button.Parent=frame; self.Utils:Corner(button,UDim.new(0,6)); self.Utils:Stroke(button,self.Theme.Border,0.3,1)
    local wrapper={Instance=frame,Button=button,Destroyed=false}
    function wrapper:GetValue() return value end
    function wrapper:SetValue(newValue,silent)
        if typeof(newValue)~="EnumItem" then return false end
        value=newValue; button.Text=string.upper(value.Name)
        if not silent then self._owner.Window:SafeCall(options.Callback,value) end
        return true
    end
    wrapper._owner=self; button.Text=string.upper(value.Name)
    self.Utils:Track(button.MouseButton1Click:Connect(function() listening=true; button.Text="..." end))
    self.Utils:Track(game:GetService("UserInputService").InputBegan:Connect(function(input)
        if listening and input.UserInputType==Enum.UserInputType.Keyboard then listening=false; wrapper:SetValue(input.KeyCode) end
    end))
    return self:_register(wrapper,section,function(_,compact)
        frame.Size=UDim2.new(1,0,0,compact and 112 or 70)
        title.Size,description.Size=UDim2.new(1,compact and -28 or -190,0,26),UDim2.new(1,compact and -28 or -190,0,22)
        button.Size=compact and UDim2.new(1,-28,0,36) or UDim2.fromOffset(150,36)
        button.Position=compact and UDim2.fromOffset(14,64) or UDim2.new(1,-164,0.5,-18)
    end)
end

function Components:CreateColor(section, options)
    options=options or {}
    local value=options.Default or self.Theme.Accent
    local frame=self:_base(section,112)
    self:_info(frame,options.Title or "COLOR",options.Description)
    local preview=Instance.new("Frame")
    preview.Size,preview.Position,preview.BackgroundColor3,preview.BorderSizePixel=UDim2.fromOffset(40,34),UDim2.fromOffset(14,64),value,0
    preview.Parent=frame; self.Utils:Corner(preview,UDim.new(0,6)); self.Utils:Stroke(preview,self.Theme.Border,0.15,1)
    local boxes={}
    for index,name in ipairs({"R","G","B"}) do
        local box=Instance.new("TextBox")
        box.Name=name; box.Size=UDim2.fromOffset(36,34); box.Position=UDim2.fromOffset(60+(index-1)*40,64)
        box.BackgroundColor3,box.BorderSizePixel,box.TextColor3,box.Font,box.TextSize,box.ClearTextOnFocus=self.Theme.Input,0,self.Theme.White,Enum.Font.GothamBold,11,false
        box.Parent=frame; self.Utils:Corner(box,UDim.new(0,6)); boxes[index]=box
    end
    local apply=Instance.new("TextButton")
    apply.Size,apply.Position,apply.BackgroundColor3,apply.BorderSizePixel=UDim2.new(0,90,0,34),UDim2.new(1,-104,0,64),self.Theme.AccentDark,0
    apply.Text,apply.TextColor3,apply.Font,apply.TextSize="APPLY",self.Theme.White,Enum.Font.GothamBold,10
    apply.Parent=frame; self.Utils:Corner(apply,UDim.new(0,6))
    local wrapper={Instance=frame,Preview=preview,Boxes=boxes,Button=apply,Destroyed=false}
    local function refresh() boxes[1].Text=tostring(math.floor(value.R*255+0.5)); boxes[2].Text=tostring(math.floor(value.G*255+0.5)); boxes[3].Text=tostring(math.floor(value.B*255+0.5)); preview.BackgroundColor3=value end
    function wrapper:GetValue() return value end
    function wrapper:SetValue(newValue,silent)
        if typeof(newValue)~="Color3" then return false end
        value=newValue; refresh(); if not silent then self._owner.Window:SafeCall(options.Callback,value) end; return true
    end
    wrapper._owner=self; refresh()
    self.Utils:Track(apply.MouseButton1Click:Connect(function()
        wrapper:SetValue(Color3.fromRGB(math.clamp(tonumber(boxes[1].Text) or 0,0,255),math.clamp(tonumber(boxes[2].Text) or 0,0,255),math.clamp(tonumber(boxes[3].Text) or 0,0,255)))
    end))
    return self:_register(wrapper,section,function(_,compact)
        frame.Size=UDim2.new(1,0,0,compact and 154 or 112)
        preview.Size=compact and UDim2.fromOffset(28,34) or UDim2.fromOffset(40,34)
        preview.Position=compact and UDim2.fromOffset(12,64) or UDim2.fromOffset(14,64)
        for index,box in ipairs(boxes) do
            box.Size=compact and UDim2.fromOffset(28,34) or UDim2.fromOffset(36,34)
            box.Position=compact and UDim2.fromOffset(48+(index-1)*31,64) or UDim2.fromOffset(60+(index-1)*40,64)
        end
        apply.Size=compact and UDim2.new(1,-24,0,34) or UDim2.new(0,90,0,34)
        apply.Position=compact and UDim2.fromOffset(12,108) or UDim2.new(1,-104,0,64)
    end)
end

return Components
