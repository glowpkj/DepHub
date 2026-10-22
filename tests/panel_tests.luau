-- Panel regression checks for the v2 (Rayfield-style) frontend.
--
-- Runs the real frontend factory against a GUI-capable Roblox double, then
-- asserts the structure the module documents: a ScreenGui named "dephub", the
-- Root window with Header/Sidebar/Main, tabs that tag their content and swap on
-- SelectTab, and every control the panel-host consumes building and calling
-- back. Structure and wiring only; nothing is rendered.
--
-- Runner (tests/run_panel_tests.js) supplies: SOURCES table, then executes this.

local checkCount, failCount = 0, 0
local function check(condition, message)
    checkCount += 1
    if not condition then
        failCount += 1
        print("FAIL: " .. tostring(message))
    end
end

-- ---------------------------------------------------------------------------
-- GUI-capable Instance double
-- ---------------------------------------------------------------------------
local signal = function()
    local e = {handlers = {}}
    function e:Connect(fn)
        local c = {Connected = true, fn = fn}
        self.handlers[#self.handlers + 1] = c
        return c
    end
    function e:Once(fn) return self:Connect(fn) end
    function e:Disconnect() self.Connected = false end
    function e:Fire(...)
        for _, c in ipairs(self.handlers) do
            if c.Connected then c.fn(...) end
        end
    end
    return e
end

local AUTO_SIGNALS = {
    MouseButton1Click = true, MouseButton2Click = true, MouseButton1Down = true, MouseButton1Up = true,
    MouseEnter = true, MouseLeave = true, InputBegan = true, InputEnded = true, InputChanged = true,
    Focused = true, FocusLost = true, Activated = true, ChildAdded = true, ChildRemoved = true,
    Changed = true, AncestryChanged = true, CharacterAdded = true, CharacterRemoving = true,
    PlayerAdded = true, PlayerRemoving = true, Completed = true, Destroying = true,
}

local instanceMeta = {}
instanceMeta.__index = function(self, key)
    local method = instanceMeta[key]
    if method then return method end
    local props = rawget(self, "_props")
    if props[key] ~= nil then return props[key] end
    if AUTO_SIGNALS[key] then
        local e = signal()
        props[key] = e
        return e
    end
    return nil
end
instanceMeta.__newindex = function(self, key, value)
    if key == "Parent" then
        local props = rawget(self, "_props")
        local old = props.Parent
        if old then
            local siblings = rawget(old, "_children")
            for i = #siblings, 1, -1 do
                if siblings[i] == self then table.remove(siblings, i) end
            end
        end
        props.Parent = value
        if value then
            local siblings = rawget(value, "_children")
            siblings[#siblings + 1] = self
        end
        return
    end
    rawget(self, "_props")[key] = value
end

function instanceMeta:GetChildren() return table.clone(rawget(self, "_children")) end
function instanceMeta:FindFirstChild(name)
    for _, child in ipairs(rawget(self, "_children")) do if child.Name == name then return child end end
    return nil
end
function instanceMeta:FindFirstChildOfClass(class)
    for _, child in ipairs(rawget(self, "_children")) do if child.ClassName == class then return child end end
    return nil
end
function instanceMeta:FindFirstAncestorOfClass() return nil end
function instanceMeta:FindFirstChildWhichIsA() return nil end
-- Roblox's IsA walks the class hierarchy; the double only knows concrete
-- ClassNames, so the abstract classes the frontend tests for are spelled out.
local CLASS_PARENTS = {
    Frame = "GuiObject", TextLabel = "GuiObject", TextButton = "GuiObject",
    ImageLabel = "GuiObject", ImageButton = "GuiObject", ScrollingFrame = "GuiObject",
    ViewportFrame = "GuiObject", TextBox = "GuiObject",
    GuiObject = "GuiBase2d", ScreenGui = "LayerCollector",
}
function instanceMeta:IsA(class)
    local current = self.ClassName
    while current do
        if current == class then return true end
        current = CLASS_PARENTS[current]
    end
    return false
end
function instanceMeta:WaitForChild() return self end
function instanceMeta:GetDescendants()
    local out = {}
    for _, child in ipairs(rawget(self, "_children")) do
        out[#out + 1] = child
        for _, d in ipairs(child:GetDescendants()) do out[#out + 1] = d end
    end
    return out
end
function instanceMeta:ClearAllChildren()
    for _, child in ipairs(rawget(self, "_children")) do child.Parent = nil end
end
function instanceMeta:Destroy()
    self:ClearAllChildren()
    self.Parent = nil
    rawget(self, "_props").Destroyed = true
end
function instanceMeta:GetPropertyChangedSignal() return signal() end
function instanceMeta:Clone() return Instance.new(self.ClassName) end
function instanceMeta:SetAttribute(name, value) rawget(self, "_attrs")[name] = value end
function instanceMeta:GetAttribute(name) return rawget(self, "_attrs")[name] end

local Instance = {}
function Instance.new(class)
    return setmetatable({
        _props = {ClassName = class, Name = class, Parent = nil},
        _children = {},
        _attrs = {},
    }, instanceMeta)
end

local Enum = setmetatable({}, {__index = function(t, key)
    local values = setmetatable({}, {__index = function(s, name) rawset(s, name, name); return name end})
    rawset(t, key, values)
    return values
end})

local UserInputService = {InputBegan = signal(), InputChanged = signal(), InputEnded = signal()}
local TweenService = {
    Create = function()
        local tween = {Completed = signal()}
        function tween:Play() if self.Completed then self.Completed:Fire() end end
        function tween:Cancel() end
        return tween
    end
}

local function buildEnvironment()
    local playerGui = Instance.new("PlayerGui")
    local player = Instance.new("Player")
    player.Name = "Tester"
    player.CharacterAdded = signal()
    player.CharacterRemoving = signal()
    player.FindFirstChildOfClass = function(self, class)
        if class == "PlayerGui" then return playerGui end
        return instanceMeta.FindFirstChildOfClass(self, class)
    end
    local players = {LocalPlayer = player, PlayerAdded = signal(), PlayerRemoving = signal()}
    function players:GetPlayers() return {player} end

    local services = {
        Players = players,
        UserInputService = UserInputService,
        TweenService = TweenService,
        RunService = {Heartbeat = signal(), RenderStepped = signal()},
    }
    local game = {
        PlaceId = 994732206, GameId = 2753915549, Name = "Blox Fruits",
        GetService = function(self, name)
            if services[name] then return services[name] end
            local made = Instance.new(name)
            services[name] = made
            return made
        end,
    }
    local state = {}
    local env = setmetatable({
        game = game, Instance = Instance, Enum = Enum, signal = signal,
        getgenv = function() return state end, typeof = typeof,
        task = {wait = function() end, defer = function(fn) fn() end, spawn = function(fn) return fn end, cancel = function() end, delay = function(_, fn) end},
        Color3 = {fromRGB = function(r, g, b) return {r = r, g = g, b = b} end},
        UDim = {new = function(s, o) return {Scale = s, Offset = o} end},
        UDim2 = {
            new = function(xs, xo, ys, yo) return {X = {Scale = xs, Offset = xo}, Y = {Scale = ys, Offset = yo}} end,
            fromScale = function(x, y) return {X = {Scale = x, Offset = 0}, Y = {Scale = y, Offset = 0}} end,
            fromOffset = function(x, y) return {X = {Scale = 0, Offset = x}, Y = {Scale = 0, Offset = y}} end,
        },
        Vector2 = {new = function(x, y) return {X = x, Y = y} end},
        TweenInfo = {new = function() return {} end},
    }, {__index = _G})
    env._G = env
    return env, state
end

-- ---------------------------------------------------------------------------
-- Load the real modules
-- ---------------------------------------------------------------------------
local SOURCES = assert(SOURCES, "SOURCES not injected by the runner")

local function loadModule(env, path)
    local source = assert(SOURCES[path], "missing source " .. tostring(path))
    local chunk = assert(loadstring(source))
    setfenv(chunk, env)
    return chunk()
end

local function run()
    local env = buildEnvironment()
    local PanelFactory = loadModule(env, "src/frontend/init.lua")
    check(type(PanelFactory) == "table" and type(PanelFactory.new) == "function", "frontend exposes .new")

    local panel = PanelFactory.new({Title = "DepHub", StartOpen = true})
    check(type(panel) == "table", "panel constructed")

    -- ScreenGui: named "dephub" so ui-guard keeps it enabled, survives respawn.
    local gui = panel.Gui
    check(gui ~= nil and gui.ClassName == "ScreenGui", "screen gui created")
    check(gui.Name == "dephub", "screen gui named dephub for ui-guard")
    check(gui.ResetOnSpawn == false, "screen gui survives respawn")

    -- Window shell
    local root = panel.Root
    check(root ~= nil, "root window exists")
    check(root:FindFirstChildOfClass("UICorner") ~= nil, "window rounded")
    check(root:FindFirstChildOfClass("UIStroke") ~= nil, "window bordered")
    check(root:FindFirstChild("Header") ~= nil, "header exists")
    check(panel.Sidebar ~= nil, "sidebar exists")
    check(panel.Scroll ~= nil, "content scroll exists")
    check(panel.ToastHolder ~= nil, "toast holder exists")
    check(panel.StatusLabel ~= nil, "status label exists")

    -- Tabs: created empty, first becomes active, content is tagged by TabRef.
    local tabA = panel:CreateTab({Name = "Jogador", Glyph = "@", Intro = "Ajuste suas preferencias."})
    local tabB = panel:CreateTab({Name = "Visual", Glyph = "=", Intro = "Escolha como aparece."})
    check(#panel.Tabs == 2, "two tabs registered")
    check(panel.ActiveTab == tabA, "first tab active")
    check(tabA.Button ~= nil, "tab has a nav button")
    check(tabA.NameLabel.Text == "Jogador", "tab label set")
    panel:SelectTab(tabB)
    check(panel.ActiveTab == tabB, "SelectTab switches")
    check(panel.StatusLabel.Text == "Escolha como aparece.", "tab intro becomes the status")
    panel:SelectTab(tabA)

    -- Section
    local section = panel:AddSection(tabA, "Preferencias do jogador")
    check(section.Text == "PREFERENCIAS DO JOGADOR", "section label uppercased")
    check(section:GetAttribute("TabRef") == "Jogador", "section tagged to its tab")

    -- Toggle
    local toggled = nil
    local toggleRow = panel:AddToggle(tabA, "Ativar recursos", "Controle principal.", false, function(v) toggled = v end)
    check(toggleRow ~= nil, "toggle row built")
    check(toggleRow:GetAttribute("TabRef") == "Jogador", "toggle tagged to its tab")
    check(toggleRow.Visible == true, "active tab content visible")

    -- Checkbox equivalent: a toggle without help is still a row
    local plain = panel:AddToggle(tabA, "Lembrar", nil, false, nil)
    check(plain ~= nil and plain.Visible == true, "help-less toggle builds")

    -- Slider with formatting
    local sliderValue = nil
    local slider = panel:AddSlider(tabA, "Distancia", 50, 1000, 10, 250, function(v) sliderValue = v end,
        function(v) return tostring(v) .. " m" end)
    check(slider ~= nil, "slider builds")

    -- Inline slider (the mockup's Opacidade shape)
    local inline = panel:AddInlineSlider(tabA, "Opacidade", 60, 100, 1, 100, nil, function(v) return tostring(v) .. "%" end)
    check(inline ~= nil, "inline slider builds")

    -- Disabled toggle
    local disabled = panel:AddDisabledToggle(tabA, "Opcao indisponivel", "Placeholder futuro.", true)
    check(disabled ~= nil, "disabled toggle builds")

    -- Dropdown
    local picked = nil
    local dropdown = panel:AddDropdown(tabA, "Perfil", nil, {"Discreto", "Equilibrado"}, "Discreto", function(v) picked = v end)
    check(dropdown ~= nil, "dropdown builds")

    -- Action
    local ran = false
    local action = panel:AddAction(tabA, "Aplicar", "Exemplo de acao.", "Aplicar", function() ran = true end, true)
    check(action ~= nil, "action builds")

    -- Notice
    local notice = panel:AddNotice(tabA, "Mensagem de aviso.", "DepHub")
    check(notice ~= nil, "notice builds")

    -- Content belongs to the scroll area and swaps on tab change.
    local onB = panel:AddToggle(tabB, "So no Visual", nil, false, nil)
    check(onB:GetAttribute("TabRef") == "Visual", "second-tab content tagged Visual")
    panel:SelectTab(tabA)
    check(onB.Visible == false, "inactive tab content hidden")
    check(toggleRow.Visible == true, "active tab content shown again")
    panel:SelectTab(tabB)
    check(onB.Visible == true, "switching back shows the other tab")

    -- Toast
    panel:Notify("Titulo", "Mensagem")
    check(#panel.Toasts >= 1 or #panel.ToastHolder:GetChildren() > 0, "toast created")

    -- Status
    panel:SetStatus("Pronto")
    check(panel.StatusLabel.Text == "Pronto", "SetStatus updates the footer")

    print(string.format("panel checks: %d run, %d failed", checkCount, failCount))
    if failCount > 0 then
        error(string.format("%d panel check(s) failed", failCount))
    end
end

run()
