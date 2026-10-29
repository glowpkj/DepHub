-- DepHub temporary UI.
--
-- Minimal, dependency-free panel that mounts over whatever backend the loader
-- published on getgenv().__DEPHUB.Backend. It exists only so the current
-- backends stay usable after the old frontend was removed; it is meant to be
-- replaced by a proper library later.
--
-- It discovers controls from the backend itself:
--   * backend.Toggles          -> one on/off row per key
--   * backend.Features (RT3)   -> one on/off row per registered feature
--   * backend.SetToggle        -> used when present (Blox Fruits, AOTR)
--   * backend.Set<Name>(bool)  -> used otherwise (Universal, TSB, MM2, NoobPiece)
--
-- Hotkey: Insert shows/hides the panel. The round "D" button reopens it.

local game = game
local type = type
local tostring = tostring
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local table_sort = table.sort

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local TempUI = {}

local function pretty(name)
    local text = tostring(name):gsub("(%l)(%u)", "%1 %2")
    return text
end

local function setterCandidates(name)
    return {"Set" .. name, "Set" .. name .. "Enabled"}
end

local function applyToggle(backend, name, value)
    if type(backend.SetToggle) == "function" then
        local ok = pcall(backend.SetToggle, backend, name, value)
        if ok then return true end
    end
    for _, setter in ipairs(setterCandidates(name)) do
        local fn = backend[setter]
        if type(fn) == "function" then
            local ok = pcall(fn, backend, value)
            if ok then return true end
        end
    end
    if type(backend.Toggles) == "table" then
        backend.Toggles[name] = value
        return true
    end
    return false
end

local function readToggle(backend, name)
    if type(backend.GetToggle) == "function" then
        local ok, value = pcall(backend.GetToggle, backend, name)
        if ok then return value == true end
    end
    if type(backend.Toggles) == "table" then
        return backend.Toggles[name] == true
    end
    return false
end

local function newInstance(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do
        pcall(function() object[key] = value end)
    end
    if parent then object.Parent = parent end
    return object
end

local function corner(parent, radius)
    local object = Instance.new("UICorner")
    object.CornerRadius = UDim.new(0, radius or 8)
    object.Parent = parent
    return object
end

local function stroke(parent, color)
    local object = Instance.new("UIStroke")
    object.Color = color or Color3.fromRGB(48, 48, 48)
    object.Thickness = 1
    object.Parent = parent
    return object
end

function TempUI.Mount(env)
    if type(env) ~= "table" then return nil end
    local contract = env.__DEPHUB
    if type(contract) ~= "table" then return nil end
    local backend = contract.Backend
    if type(backend) ~= "table" then return nil end

    local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
    local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 15)
    if not playerGui then return nil end

    local host = playerGui
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and typeof(result) == "Instance" then host = result end
    end

    local gui = newInstance("ScreenGui", {
        Name = "DepHub",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 1000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, host)

    local root = newInstance("Frame", {
        Name = "Root",
        Size = UDim2.new(0, 420, 0, 470),
        Position = UDim2.new(0.5, -210, 0.5, -235),
        BackgroundColor3 = Color3.fromRGB(17, 17, 17),
        BorderSizePixel = 0,
        Active = true,
    }, gui)
    corner(root, 10)
    stroke(root, Color3.fromRGB(46, 46, 46))

    local titleBar = newInstance("Frame", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(24, 24, 24),
        BorderSizePixel = 0,
    }, root)
    corner(titleBar, 10)

    newInstance("TextLabel", {
        Name = "Brand",
        Size = UDim2.new(1, -90, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = "DepHub  ·  " .. tostring(contract.Mode or "?"),
        TextColor3 = Color3.fromRGB(228, 228, 228),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, titleBar)

    local close = newInstance("TextButton", {
        Name = "Close",
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -34, 0, 7),
        BackgroundColor3 = Color3.fromRGB(38, 38, 38),
        BorderSizePixel = 0,
        Text = "×",
        TextColor3 = Color3.fromRGB(220, 220, 220),
        TextSize = 17,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, titleBar)
    corner(close, 6)

    local status = newInstance("TextLabel", {
        Name = "Status",
        Size = UDim2.new(1, -20, 0, 22),
        Position = UDim2.new(0, 10, 1, -26),
        BackgroundTransparency = 1,
        Text = "v" .. tostring(contract.Version or "?"),
        TextColor3 = Color3.fromRGB(128, 128, 128),
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, root)

    local body = newInstance("ScrollingFrame", {
        Name = "Body",
        Size = UDim2.new(1, -20, 1, -74),
        Position = UDim2.new(0, 10, 0, 46),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, root)

    local layout = newInstance("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, body)

    local order = 0
    local function nextOrder()
        order = order + 1
        return order
    end

    local function addSection(text)
        local label = newInstance("TextLabel", {
            Name = "Section",
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Text = string.upper(text),
            TextColor3 = Color3.fromRGB(140, 140, 140),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, body)
        label.LayoutOrder = nextOrder()
    end

    local function addToggleRow(name, title, initial, apply)
        local row = newInstance("TextButton", {
            Name = "Toggle_" .. tostring(name),
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = Color3.fromRGB(26, 26, 26),
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, body)
        corner(row, 6)
        stroke(row, Color3.fromRGB(38, 38, 38))

        newInstance("TextLabel", {
            Size = UDim2.new(1, -70, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = Color3.fromRGB(214, 214, 214),
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)

        local value = initial == true
        local state = newInstance("TextLabel", {
            Size = UDim2.new(0, 46, 0, 20),
            Position = UDim2.new(1, -56, 0.5, -10),
            BackgroundColor3 = value and Color3.fromRGB(70, 140, 90) or Color3.fromRGB(44, 44, 44),
            BorderSizePixel = 0,
            Text = value and "ON" or "OFF",
            TextColor3 = value and Color3.fromRGB(235, 255, 240) or Color3.fromRGB(150, 150, 150),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
        }, row)
        corner(state, 4)

        local function render()
            state.Text = value and "ON" or "OFF"
            state.BackgroundColor3 = value and Color3.fromRGB(70, 140, 90) or Color3.fromRGB(44, 44, 44)
            state.TextColor3 = value and Color3.fromRGB(235, 255, 240) or Color3.fromRGB(150, 150, 150)
        end

        row.Activated:Connect(function()
            local nextValue = not value
            local ok, result = pcall(apply, nextValue)
            if not ok or result == false then
                status.Text = "Falha ao aplicar " .. title
                status.TextColor3 = Color3.fromRGB(220, 130, 130)
                return
            end
            value = nextValue
            render()
            status.Text = title .. (value and " ativado" or " desativado")
            status.TextColor3 = Color3.fromRGB(128, 128, 128)
        end)
        return row
    end

    local function addActionRow(title, label, run)
        local button = newInstance("TextButton", {
            Name = "Action_" .. tostring(title),
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Color3.fromRGB(32, 32, 32),
            BorderSizePixel = 0,
            Text = label or title,
            TextColor3 = Color3.fromRGB(224, 224, 224),
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false,
        }, body)
        corner(button, 6)
        stroke(button, Color3.fromRGB(58, 58, 58))
        button.Activated:Connect(function()
            local ok, err = pcall(run)
            status.Text = ok and (title .. " executado") or (title .. ": " .. tostring(err))
            status.TextColor3 = ok and Color3.fromRGB(128, 128, 128) or Color3.fromRGB(220, 130, 130)
        end)
        return button
    end

    local mode = tostring(contract.Mode or "")

    local actions = {}
    if type(backend.Rejoin) == "function" then
        actions[#actions + 1] = {"Rejoin", "Reentrar", function() backend:Rejoin() end}
    end
    if type(backend.ServerHop) == "function" then
        actions[#actions + 1] = {"ServerHop", "Trocar de servidor", function() backend:ServerHop() end}
    end

    if mode == "RT3" and type(backend.Features) == "table" then
        addSection("Recursos")
        local names = {}
        for name in pairs(backend.Features) do names[#names + 1] = name end
        table_sort(names)
        for _, name in ipairs(names) do
            local feature = backend.Features[name]
            if type(feature) == "table" then
                local initial = feature.Enabled == true
                addToggleRow(name, pretty(name), initial, function(value)
                    local fn = feature.Toggle or feature.Set
                    if type(fn) ~= "function" then return false end
                    pcall(fn, feature, value)
                    return true
                end).LayoutOrder = nextOrder()
            end
        end
    elseif type(backend.Toggles) == "table" then
        addSection("Recursos")
        local names = {}
        for name in pairs(backend.Toggles) do names[#names + 1] = name end
        table_sort(names)
        for _, name in ipairs(names) do
            addToggleRow(name, pretty(name), readToggle(backend, name), function(value)
                return applyToggle(backend, name, value)
            end).LayoutOrder = nextOrder()
        end
    else
        addSection("Estado")
        newInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            Text = "Nenhum recurso publicado por este backend.",
            TextColor3 = Color3.fromRGB(150, 150, 150),
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, body).LayoutOrder = nextOrder()
    end

    if #actions > 0 then
        addSection("Sessão")
        for _, action in ipairs(actions) do
            addActionRow(action[1], action[2], action[3]).LayoutOrder = nextOrder()
        end
    end

    local floating = newInstance("TextButton", {
        Name = "Floating",
        Size = UDim2.new(0, 44, 0, 44),
        Position = UDim2.new(1, -60, 1, -60),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28),
        BorderSizePixel = 0,
        Text = "D",
        TextColor3 = Color3.fromRGB(230, 230, 230),
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Visible = false,
    }, gui)
    corner(floating, 22)
    stroke(floating, Color3.fromRGB(58, 58, 58))

    local visible = true
    local function setVisible(nextValue)
        visible = nextValue == true
        root.Visible = visible
        floating.Visible = not visible
    end

    close.Activated:Connect(function() setVisible(false) end)
    floating.Activated:Connect(function() setVisible(true) end)

    local dragging = false
    local dragStart, startPosition
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = root.Position
        end
    end)
    local dragConnection = UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end)
    local releaseConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    local keyConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            setVisible(not visible)
        end
    end)

    local handle = {Destroyed = false}
    function handle:Show() setVisible(true) end
    function handle:Hide() setVisible(false) end
    function handle:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        pcall(function() dragConnection:Disconnect() end)
        pcall(function() releaseConnection:Disconnect() end)
        pcall(function() keyConnection:Disconnect() end)
        pcall(function() gui:Destroy() end)
    end

    return handle
end

return TempUI
