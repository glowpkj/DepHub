local Components = {}
local Utils = require(script.Parent.utils)
local Colors, Tween = Utils.Colors, Utils.Tween
local UIS = Utils.UserInputService

local function track(tab, signal, callback)
    local connection = signal:Connect(callback)
    tab.WindowRef.Connections[#tab.WindowRef.Connections + 1] = connection
    return connection
end

local function corner(object, radius) Utils.ApplyCorner(object, radius or 7) end
local function stroke(object, transparency) Utils.ApplyStroke(object, Colors.Border, 1, transparency or 0.25) end

local function label(parent, value, size, color, font, alignment)
    local object = Instance.new("TextLabel")
    object.BackgroundTransparency = 1
    object.Text = value or ""
    object.TextSize = size or 12
    object.TextColor3 = color or Colors.Light
    object.Font = font or Enum.Font.Gotham
    object.TextXAlignment = alignment or Enum.TextXAlignment.Left
    object.TextYAlignment = Enum.TextYAlignment.Center
    object.TextWrapped = true
    object.Parent = parent
    return object
end

local function baseCard(tab, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, height)
    card.BackgroundColor3 = Colors.Card
    card.BorderSizePixel = 0
    corner(card, 7); stroke(card, 0.28)
    tab:_mount(card, height)
    return card
end

local function heading(card, title, description, rightSpace)
    local titleLabel = label(card, title, 12, Colors.White, Enum.Font.GothamBold)
    titleLabel.Size, titleLabel.Position = UDim2.new(1, -(rightSpace or 24), 0, 20), UDim2.fromOffset(13, 9)
    titleLabel.TextWrapped, titleLabel.TextTruncate = false, Enum.TextTruncate.AtEnd
    local descriptionLabel = label(card, description or "", 10, Colors.Gray, Enum.Font.Gotham)
    descriptionLabel.Size, descriptionLabel.Position = UDim2.new(1, -(rightSpace or 24), 0, 28), UDim2.fromOffset(13, 29)
    descriptionLabel.TextSize = 11
    return titleLabel, descriptionLabel
end

local function responsiveField(tab, card, title, description, control, rightSpace, panel, extraHeight)
    local update
    update = function()
        local stacked = card.AbsoluteSize.X < 340
        local collapsed = stacked and 102 or 62
        title.Size = UDim2.new(1, -(stacked and 26 or rightSpace), 0, 20)
        description.Size = UDim2.new(1, -(stacked and 26 or rightSpace), 0, 28)
        control.AnchorPoint = Vector2.new(stacked and 0 or 1, 0)
        control.Position = stacked and UDim2.fromOffset(13, 63) or UDim2.new(1, -12, 0, 16)
        control.Size = stacked and UDim2.new(1, -26, 0, 30) or UDim2.fromOffset(rightSpace - 38, 30)
        if panel then panel.Position = UDim2.fromOffset(12, collapsed) end
        tab:_resize(card, collapsed + ((panel and panel.Visible) and extraHeight or 0))
    end
    local lastWidth
    track(tab, card:GetPropertyChangedSignal("AbsoluteSize"), function()
        if lastWidth ~= card.AbsoluteSize.X then lastWidth = card.AbsoluteSize.X; update() end
    end)
    update()
    return update
end

local function bindHover(button, target)
    button.MouseEnter:Connect(function() Tween(target, 0.14, nil, nil, {BackgroundColor3 = Colors.CardHover}) end)
    button.MouseLeave:Connect(function() Tween(target, 0.14, nil, nil, {BackgroundColor3 = Colors.Card}) end)
end

function Components.Register(Tab)
    function Tab:CreateCard(titleText, description, height)
        local card = baseCard(self, height or 76)
        heading(card, titleText, description, 24)
        return card
    end

    function Tab:CreateDivider(value)
        local holder = Instance.new("Frame")
        holder.Size, holder.BackgroundTransparency = UDim2.new(1, 0, 0, 24), 1
        self:_mount(holder, 24)
        local textLabel = label(holder, string.upper(value or "SECTION"), 9, Colors.DarkGray, Enum.Font.GothamBold)
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        local line = Instance.new("Frame")
        line.Size, line.Position, line.AnchorPoint = UDim2.new(1, -120, 0, 1), UDim2.new(1, 0, 0.5, 0), Vector2.new(1, 0.5)
        line.BackgroundColor3, line.BorderSizePixel, line.Parent = Colors.Border, 0, holder
        return holder
    end

    function Tab:CreateLabel(value)
        local holder = Instance.new("Frame")
        holder.Size, holder.BackgroundColor3, holder.BorderSizePixel = UDim2.new(1, 0, 0, 36), Colors.Surface, 0
        corner(holder, 6)
        self:_mount(holder, 36)
        local textLabel = label(holder, value, 10, Colors.Gray, Enum.Font.Gotham)
        textLabel.Size, textLabel.Position, textLabel.AutomaticSize = UDim2.new(1, -22, 0, 20), UDim2.fromOffset(11, 8), Enum.AutomaticSize.Y
        local function resize() self:_resize(holder, math.max(36, textLabel.AbsoluteSize.Y + 16)) end
        track(self, textLabel:GetPropertyChangedSignal("AbsoluteSize"), resize)
        task.defer(resize)
        return textLabel
    end

    function Tab:CreateStatGrid()
        local grid = Instance.new("Frame")
        grid.Size, grid.BackgroundTransparency = UDim2.new(1, 0, 0, 74), 1
        self:_mount(grid, 74, true)
        local layout = Instance.new("UIGridLayout")
        layout.CellSize, layout.CellPadding, layout.FillDirectionMaxCells, layout.Parent = UDim2.new(0.5, -4, 0, 70), UDim2.fromOffset(8, 8), 2, grid
        local object = {Frame = grid, Count = 0}
        function object:CreateStat(title, value)
            self.Count += 1
            local card = Instance.new("Frame")
            card.BackgroundColor3, card.BorderSizePixel, card.LayoutOrder, card.Parent = Colors.Card, 0, self.Count, grid
            corner(card, 7); stroke(card, 0.3)
            local accent = Instance.new("Frame")
            accent.Size, accent.BackgroundColor3, accent.BorderSizePixel, accent.Parent = UDim2.new(0, 3, 1, -18), Colors.Accent, 0, card
            accent.Position = UDim2.fromOffset(0, 9); corner(accent, 99)
            local name = label(card, string.upper(title or "STAT"), 8, Colors.DarkGray, Enum.Font.GothamBold)
            name.Size, name.Position = UDim2.new(1, -22, 0, 16), UDim2.fromOffset(13, 9)
            local output = label(card, tostring(value or "--"), 14, Colors.White, Enum.Font.GothamBold)
            output.Size, output.Position = UDim2.new(1, -22, 0, 26), UDim2.fromOffset(13, 28)
            local stat = {Card = card, Label = output}
            function stat:SetValue(newValue) output.Text = tostring(newValue) end
            function stat:GetValue() return output.Text end
            function stat:SetColor(color) output.TextColor3 = color end
            grid.Size = UDim2.new(1, 0, 0, math.ceil(self.Count / 2) * 78 - 8)
            return stat
        end
        return object
    end

    function Tab:CreateToggle(titleText, description, default, callback)
        local card = baseCard(self, 62)
        heading(card, titleText, description, 76)
        local hit = Instance.new("TextButton")
        hit.Size, hit.BackgroundTransparency, hit.Text, hit.AutoButtonColor, hit.Parent = UDim2.fromScale(1, 1), 1, "", false, card
        local track = Instance.new("Frame")
        track.Size, track.Position, track.AnchorPoint, track.BorderSizePixel, track.Parent = UDim2.fromOffset(42, 22), UDim2.new(1, -13, 0.5, 0), Vector2.new(1, 0.5), 0, card
        corner(track, 99)
        local knob = Instance.new("Frame")
        knob.Size, knob.AnchorPoint, knob.Position, knob.BackgroundColor3, knob.BorderSizePixel, knob.Parent = UDim2.fromOffset(16, 16), Vector2.new(0.5, 0.5), UDim2.new(0, 12, 0.5, 0), Colors.ToggleKnob, 0, track
        corner(knob, 99)
        local state = default == true
        local object = {Frame = card}
        local function render(animate)
            local propsTrack, propsKnob = {BackgroundColor3 = state and Colors.ToggleOn or Colors.ToggleOff}, {Position = UDim2.new(0, state and 30 or 12, 0.5, 0)}
            if animate then Tween(track, 0.16, nil, nil, propsTrack); Tween(knob, 0.16, nil, nil, propsKnob) else for key, value in pairs(propsTrack) do track[key] = value end; for key, value in pairs(propsKnob) do knob[key] = value end end
        end
        function object:SetValue(value, silent) state = value == true; render(true); if callback and not silent then task.spawn(callback, state) end end
        function object:GetValue() return state end
        hit.MouseButton1Click:Connect(function() object:SetValue(not state) end)
        bindHover(hit, card); render(false)
        return object
    end

    function Tab:CreateButton(value, callback)
        local card = baseCard(self, 46)
        local hit = Instance.new("TextButton")
        hit.Size, hit.BackgroundTransparency, hit.Text, hit.AutoButtonColor, hit.Parent = UDim2.fromScale(1, 1), 1, "", false, card
        local titleLabel = label(card, value, 11, Colors.White, Enum.Font.GothamBold)
        titleLabel.Size, titleLabel.Position = UDim2.new(1, -48, 1, 0), UDim2.fromOffset(13, 0)
        local arrow = label(card, "›", 20, Colors.Accent, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        arrow.Size, arrow.Position = UDim2.fromOffset(32, 46), UDim2.new(1, -38, 0, 0)
        bindHover(hit, card)
        hit.MouseButton1Click:Connect(function() Tween(card, 0.08, nil, nil, {BackgroundColor3 = Colors.Active}); if callback then task.spawn(callback) end; task.delay(0.12, function() if card.Parent then Tween(card, 0.15, nil, nil, {BackgroundColor3 = Colors.Card}) end end) end)
        return {Frame = card, Button = hit}
    end

    function Tab:CreateSlider(titleText, description, minimum, maximum, default, callback)
        local card = baseCard(self, 76)
        heading(card, titleText, description, 78)
        local value = math.clamp(tonumber(default) or minimum, minimum, maximum)
        local output = label(card, tostring(math.floor(value + 0.5)), 11, Colors.White, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        output.Size, output.Position, output.BackgroundColor3, output.BackgroundTransparency = UDim2.fromOffset(52, 25), UDim2.new(1, -64, 0, 9), Colors.Surface, 0
        corner(output, 5)
        local bar = Instance.new("Frame")
        bar.Size, bar.Position, bar.BackgroundColor3, bar.BorderSizePixel, bar.Parent = UDim2.new(1, -26, 0, 5), UDim2.new(0, 13, 1, -16), Colors.ToggleOff, 0, card
        corner(bar, 99)
        local fill = Instance.new("Frame")
        fill.Size, fill.BackgroundColor3, fill.BorderSizePixel, fill.Parent = UDim2.new((value - minimum) / (maximum - minimum), 0, 1, 0), Colors.Accent, 0, bar
        corner(fill, 99)
        local hit = Instance.new("TextButton")
        hit.Size, hit.Position, hit.BackgroundTransparency, hit.Text, hit.Parent = UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0.5, -11), 1, "", bar
        local object = {Frame = card}
        local function set(newValue, silent)
            value = math.clamp(tonumber(newValue) or minimum, minimum, maximum)
            output.Text = tostring(math.floor(value + 0.5))
            fill.Size = UDim2.new((value - minimum) / (maximum - minimum), 0, 1, 0)
            if callback and not silent then task.spawn(callback, value) end
        end
        local dragging = false
        local function update(input) set(minimum + (maximum - minimum) * math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)) end
        hit.InputBegan:Connect(function(input) if Utils.IsPrimaryInput(input) then dragging = true; update(input) end end)
        hit.InputEnded:Connect(function(input) if Utils.IsPrimaryInput(input) then dragging = false end end)
        track(self, UIS.InputChanged, function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end end)
        track(self, UIS.InputEnded, function(input) if Utils.IsPrimaryInput(input) then dragging = false end end)
        function object:SetValue(newValue, silent) set(newValue, silent) end
        function object:GetValue() return value end
        return object
    end

    function Tab:CreateDropdown(titleText, description, options, default, callback)
        local card = baseCard(self, 62)
        local titleLabel, descriptionLabel = heading(card, titleText, description, 154)
        local current = default
        local button = Instance.new("TextButton")
        button.Size, button.Position, button.AnchorPoint, button.BackgroundColor3, button.BorderSizePixel, button.Text, button.TextColor3, button.Font, button.TextSize, button.Parent = UDim2.fromOffset(116, 30), UDim2.new(1, -12, 0, 16), Vector2.new(1, 0), Colors.Surface, 0, tostring(default or "Select"), Colors.Light, Enum.Font.GothamMedium, 10, card
        corner(button, 6); stroke(button, 0.35)
        local menu = Instance.new("Frame")
        menu.Size, menu.Position, menu.BackgroundColor3, menu.BorderSizePixel, menu.Visible, menu.ZIndex, menu.Parent = UDim2.new(1, -24, 0, #options * 30 + 8), UDim2.fromOffset(12, 62), Colors.Surface, 0, false, 2, card
        corner(menu, 6); stroke(menu, 0.15)
        local layout = Instance.new("UIListLayout"); layout.Padding, layout.Parent = UDim.new(0, 2), menu
        local padding = Instance.new("UIPadding"); padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight, padding.Parent = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 4), menu
        local object = {Frame = card}
        local tab = self
        local relayout = responsiveField(tab, card, titleLabel, descriptionLabel, button, 154, menu, #options * 30 + 16)
        function object:SetValue(newValue, silent) current = newValue; button.Text = tostring(newValue); menu.Visible = false; relayout(); if callback and not silent then task.spawn(callback, newValue) end end
        function object:GetValue() return current end
        for index, option in ipairs(options) do
            local choice = Instance.new("TextButton")
            choice.Size, choice.BackgroundTransparency, choice.Text, choice.TextColor3, choice.Font, choice.TextSize, choice.LayoutOrder, choice.ZIndex, choice.Parent = UDim2.new(1, 0, 0, 28), 1, tostring(option), Colors.Gray, Enum.Font.Gotham, 10, index, 3, menu
            choice.MouseButton1Click:Connect(function() object:SetValue(option) end)
        end
        button.MouseButton1Click:Connect(function() menu.Visible = not menu.Visible; relayout() end)
        return object
    end

    function Tab:CreateInput(titleText, description, placeholder, callback)
        local card = baseCard(self, 62)
        local titleLabel, descriptionLabel = heading(card, titleText, description, 178)
        local box = Instance.new("TextBox")
        box.Size, box.Position, box.AnchorPoint, box.BackgroundColor3, box.BorderSizePixel, box.Text, box.PlaceholderText, box.PlaceholderColor3, box.TextColor3, box.Font, box.TextSize, box.ClearTextOnFocus, box.Parent = UDim2.fromOffset(140, 30), UDim2.new(1, -12, 0.5, 0), Vector2.new(1, 0.5), Colors.Surface, 0, "", placeholder or "Type...", Colors.DarkGray, Colors.Light, Enum.Font.Gotham, 10, false, card
        corner(box, 6); stroke(box, 0.35)
        responsiveField(self, card, titleLabel, descriptionLabel, box, 178)
        box.FocusLost:Connect(function(enter) if callback then task.spawn(callback, box.Text, enter) end end)
        return {Frame = card, SetValue = function(_, value) box.Text = tostring(value) end, GetValue = function() return box.Text end}
    end

    function Tab:CreateKeybind(titleText, description, defaultKey, callback)
        local object
        local current = defaultKey or Enum.KeyCode.RightControl
        local card = baseCard(self, 62); heading(card, titleText, description, 106)
        local button = Instance.new("TextButton")
        button.Size, button.Position, button.AnchorPoint, button.BackgroundColor3, button.TextColor3, button.Font, button.TextSize, button.Text, button.Parent = UDim2.fromOffset(88, 30), UDim2.new(1, -12, 0.5, 0), Vector2.new(1, 0.5), Colors.Surface, Colors.Light, Enum.Font.GothamBold, 9, current.Name, card
        corner(button, 6)
        local pending
        button.MouseButton1Click:Connect(function()
            if pending then pending:Disconnect() end
            button.Text = "..."
            pending = track(self, UIS.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    current = input.KeyCode; button.Text = current.Name; pending:Disconnect(); pending = nil
                    if callback then task.spawn(callback, current) end
                end
            end)
        end)
        object = {Frame = card, SetValue = function(_, value) current = value; button.Text = value.Name end, GetValue = function() return current end}
        return object
    end

    function Tab:CreateColorPicker(titleText, description, defaultColor, callback)
        local color = defaultColor or Colors.Accent
        local card = baseCard(self, 62); heading(card, titleText, description, 78)
        local button = Instance.new("TextButton")
        button.Size, button.Position, button.AnchorPoint, button.BackgroundColor3, button.Text, button.Parent = UDim2.fromOffset(52, 30), UDim2.new(1, -12, 0.5, 0), Vector2.new(1, 0.5), color, "", card
        corner(button, 6); stroke(button, 0.15)
        button.Position, button.AnchorPoint = UDim2.new(1, -12, 0, 16), Vector2.new(1, 0)
        local panel = Instance.new("Frame")
        panel.Size, panel.Position, panel.BackgroundTransparency, panel.Visible, panel.Parent = UDim2.new(1, -24, 0, 58), UDim2.fromOffset(12, 62), 1, false, card
        local inputs = {}
        local tab = self
        local object = {Frame = card}
        function object:SetValue(value, silent)
            color = value; button.BackgroundColor3 = value
            for index, component in ipairs({value.R, value.G, value.B}) do if inputs[index] then inputs[index].Text = tostring(math.floor(component * 255 + 0.5)) end end
            if callback and not silent then task.spawn(callback, value) end
        end
        function object:GetValue() return color end
        for index, channel in ipairs({"R", "G", "B"}) do
            local name = label(panel, channel, 9, Colors.Gray, Enum.Font.GothamBold)
            name.Size, name.Position = UDim2.new(1/3, -6, 0, 15), UDim2.new((index-1)/3, 0, 0, 0)
            local box = Instance.new("TextBox")
            box.Size, box.Position, box.BackgroundColor3, box.BorderSizePixel = UDim2.new(1/3, -6, 0, 29), UDim2.new((index-1)/3, 0, 0, 19), Colors.Surface, 0
            box.TextColor3, box.Font, box.TextSize, box.ClearTextOnFocus, box.Parent = Colors.White, Enum.Font.Gotham, 11, false, panel
            corner(box, 5); inputs[index] = box
            box.FocusLost:Connect(function()
                local values = {}
                for i, input in ipairs(inputs) do values[i] = math.clamp(tonumber(input.Text) or 0, 0, 255) end
                object:SetValue(Color3.fromRGB(values[1], values[2], values[3]))
            end)
        end
        object:SetValue(color, true)
        button.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible; tab:_resize(card, panel.Visible and 126 or 62) end)
        return object
    end
end

return Components
