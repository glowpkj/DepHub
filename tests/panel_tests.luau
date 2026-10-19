-- Panel regression checks.
--
-- Runs the real frontend factory against a GUI-capable Roblox double, then
-- asserts the structure the authored interface requires: a protected ScreenGui,
-- the window with header/nav/main/footer, the brand mark, the current-game
-- caption, three window buttons, per-page headings, the search field, and every
-- control from the mockup building and calling back. Structure and wiring are
-- checked; nothing is rendered, which is what can regress without a live client.
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
    PlayerAdded = true, PlayerRemoving = true, Completed = true,
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
function instanceMeta:IsA(class) return self.ClassName == class end
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

local Instance = {}
function Instance.new(class)
    return setmetatable({
        _props = {ClassName = class, Name = class, Parent = nil},
        _children = {},
    }, instanceMeta)
end

local Enum = setmetatable({}, {__index = function(t, key)
    local values = setmetatable({}, {__index = function(s, name) rawset(s, name, name); return name end})
    rawset(t, key, values)
    return values
end})

local UserInputService = {InputBegan = signal(), InputChanged = signal()}
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
    local player = Instance.new("Player"); player.Name = "Tester"
    player.CharacterAdded = signal(); player.CharacterRemoving = signal()
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
            local made = Instance.new(name); services[name] = made; return made
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

-- Recursively collect every descendant name for structural assertions.
local function names(root)
    local set = {}
    for _, d in ipairs(root:GetDescendants()) do
        if d.Name then set[d.Name] = (set[d.Name] or 0) + 1 end
    end
    return set
end

local function run()
    local env = buildEnvironment()
    local PanelFactory = loadModule(env, "src/frontend/init.lua")
    check(type(PanelFactory) == "table" and type(PanelFactory.new) == "function", "frontend exposes .new")

    local panel = PanelFactory.new({Title = "DepHub", GameName = "Blox Fruits", StartOpen = true})
    check(type(panel) == "table", "panel constructed")

    local screen = panel.ScreenGui
    check(screen ~= nil and screen.ClassName == "ScreenGui", "screen gui created")
    check(string.find(string.lower(screen.Name), "dephub", 1, true) ~= nil, "screen gui name contains dephub for ui-guard")
    check(screen.ResetOnSpawn == false, "screen gui survives respawn")
    check(screen.Enabled == true, "screen gui enabled when StartOpen")

    -- Window shell
    local window = panel.Window
    check(window ~= nil, "window exists")
    check(window:FindFirstChildOfClass("UICorner") ~= nil, "window rounded")
    check(window:FindFirstChildOfClass("UIStroke") ~= nil, "window bordered")
    local body = window:FindFirstChild("Body")
    check(body ~= nil, "body exists")
    check(body:FindFirstChild("Layout") ~= nil, "layout exists")
    check(body:FindFirstChild("Footer") ~= nil, "footer exists")

    -- Header pieces
    local header = window:FindFirstChild("Header")
    check(header ~= nil, "header exists")
    check(header:FindFirstChild("Brand") ~= nil, "brand block exists")
    check(header:FindFirstChild("CurrentGame") ~= nil, "current-game block exists")
    check(header:FindFirstChild("WindowButtons") ~= nil, "window buttons exist")
    local buttons = header:FindFirstChild("WindowButtons")
    check(buttons:FindFirstChild("Close") ~= nil, "close button")
    check(buttons:FindFirstChild("Minimize") ~= nil, "minimize button")
    check(buttons:FindFirstChild("Expand") ~= nil, "expand button")
    -- each button has a coloured Dot and a hidden Glyph
    local close = buttons:FindFirstChild("Close")
    check(close:FindFirstChild("Dot") ~= nil, "close dot exists")
    check(close:FindFirstChild("Glyph") ~= nil, "close glyph exists")

    -- Nav + main
    local layout = body:FindFirstChild("Layout")
    check(layout:FindFirstChild("Nav") ~= nil, "nav exists")
    check(layout:FindFirstChild("Main") ~= nil, "main exists")
    check(layout:FindFirstChild("Nav"):FindFirstChild("List") ~= nil, "nav list exists")

    -- Tab with heading + search
    local tabA = panel:CreateTab({Name = "Jogador", Glyph = "◫", Intro = "Ajuste suas preferências.", Search = "Encontrar uma opção..."})
    local tabB = panel:CreateTab({Name = "Visual", Glyph = "◎", Intro = "Escolha como aparece."})
    check(tabA.Page ~= nil and tabB.Page ~= nil, "tabs create pages")
    check(tabA.Page.Visible == true, "first tab visible")
    check(tabB.Page.Visible == false, "second tab hidden")
    check(tabA.Page:FindFirstChild("Heading") ~= nil, "page has heading")
    check(tabA.Search ~= nil, "search field created")
    panel:SelectTab("Visual")
    check(tabB.Page.Visible == true and tabA.Page.Visible == false, "SelectTab switches")

    -- Section label
    local section = panel:AddSection(tabA, "Preferencias do jogador")
    check(section.Text == "PREFERENCIAS DO JOGADOR", "section label uppercased")

    -- Toggle
    local toggled = nil
    local toggle = panel:AddToggle(tabA, "Ativar recursos", "Controle principal.", false, function(v) toggled = v end)
    check(toggle:Get() == false, "toggle starts false")
    toggle:Set(true)
    check(toggle:Get() == true and toggled == true, "toggle set fires callback")
    check(toggle.Instance:FindFirstChild("Knob") ~= nil, "toggle has knob")

    -- Checkbox
    local checkbox = panel:AddCheckbox(tabA, "Lembrar", nil, false, nil)
    checkbox:Set(true)
    check(checkbox:Get() == true, "checkbox set/get")

    -- Slider with formatting
    local sliderValue = nil
    local slider = panel:AddSlider(tabA, "Distância", 50, 1000, 10, 250, function(v) sliderValue = v end,
        function(v) return tostring(v) .. " m" end)
    check(slider:Get() == 250, "slider starts at 250")
    slider:Set(733)
    check(slider:Get() == 730, "slider quantizes to step")
    check(sliderValue == 730, "slider callback fires")
    check(slider.Block:FindFirstChild("Head") ~= nil, "range has head with label/output")
    check(slider.Block:FindFirstChild("Track") ~= nil, "range has track")

    -- Dropdown (choice trigger)
    local picked = nil
    local dropdown = panel:AddDropdown(tabA, "Perfil", nil, {"Discreto", "Equilibrado", "Personalizado"}, "Discreto", function(v) picked = v end)
    check(dropdown:Get() == "Discreto", "dropdown starts at first")
    dropdown:Set("Personalizado")
    check(dropdown:Get() == "Personalizado" and picked == "Personalizado", "dropdown set fires callback")
    dropdown:Set("Nope")
    check(dropdown:Get() == "Personalizado", "dropdown rejects unknown")

    -- Text field (input group) with help
    local field = panel:AddTextField(tabA, "Nome da configuração", "Ex.: meu perfil", "inicial", nil, "Até 120 caracteres.")
    check(field:Get() == "inicial", "text field value")
    field:Set("novo")
    check(field:Get() == "novo", "text field set")
    check(field.Row:FindFirstChild("Help") ~= nil, "input group shows help")

    -- Action
    local ran = false
    local action = panel:AddAction(tabA, "Aplicar", "Exemplo de ação.", "Aplicar ⏎", function() ran = true end, true)
    action.Instance.MouseButton1Click:Fire()
    check(ran == true, "action fires")

    -- Keybind
    local bound = false
    local keybind = panel:AddKeybind(tabA, "Atalho do menu", nil, "Insert", function() bound = true end)
    keybind.Instance.MouseButton1Click:Fire()
    check(bound == true, "keybind fires")

    -- Notice
    local notice = panel:AddNotice(tabA, "Mensagem de aviso.", "DepHub")
    check(notice:FindFirstChild("Body") ~= nil, "notice body")

    -- Collapsible
    local collapsible = panel:AddCollapsible(tabA, "Seção recolhível", false)
    check(collapsible.Body.Visible == false, "collapsible closed")
    collapsible.Toggle.MouseButton1Click:Fire()
    check(collapsible.Body.Visible == true, "collapsible opens")

    -- Button group
    local groupRan = false
    local group = panel:AddButtonGroup(tabA, {
        {Label = "Salvar", Primary = true, Callback = function() groupRan = true end},
        {Label = "Carregar"},
        {Label = "Restaurar"},
    })
    check(#group.Buttons == 3, "button group has three buttons")
    group.Buttons[1].MouseButton1Click:Fire()
    check(groupRan == true, "button group primary fires")

    -- Search filters rows
    check(#tabA.Search.Rows > 0, "search registered rows")

    -- Toast
    panel:Notify("Título", "Mensagem")
    check(panel.Toast.Visible == true, "toast shows")
    check(panel.ToastTitle.Text == "Título", "toast title")

    -- Dialog
    local confirmed = false
    panel:Confirm("Confirmar?", "Deseja?", function() confirmed = true end)
    check(panel.DialogOverlay.Visible == true, "dialog shows")
    local confirmBtn = panel.DialogButtons:FindFirstChild("Confirm")
    check(confirmBtn ~= nil, "dialog has confirm")
    confirmBtn.MouseButton1Click:Fire()
    check(confirmed == true, "dialog confirm fires")
    check(panel.DialogOverlay.Visible == false, "dialog closes")

    -- Window state
    panel:ToggleMinimize()
    check(panel.Minimized == true, "minimize on")
    panel:ToggleMinimize()
    check(panel.Minimized == false, "minimize off")
    panel:ToggleExpand()
    check(panel.Expanded == true, "expand on")
    panel:ToggleExpand()
    check(panel.Expanded == false, "expand off")

    panel:SetOpen(false)
    check(panel.Open == false and screen.Enabled == false, "SetOpen(false)")
    panel:SetOpen(true)
    check(panel.Open == true and screen.Enabled == true, "SetOpen(true)")

    -- Destroy
    panel:Destroy()
    check(panel.Destroyed == true, "panel destroyed")

    -- Host mounts against a Blox Fruits-shaped backend and binds its controls.
    local env2, state2 = buildEnvironment()
    local PanelFactory2 = loadModule(env2, "src/frontend/init.lua")
    local Host = loadModule(env2, "src/core/panel-host.lua")
    check(type(Host) == "table" and type(Host.Mount) == "function", "panel host exposes Mount")

    local calls = {}
    local backend = {
        Toggles = {PlayerESP = false, FruitESP = false, AutoFarm = false, BladeHits = false, AutoJoinTeam = true},
        Values = {DashLength = 3},
        GetToggle = function(self, name) return self.Toggles[name] == true end,
        SetToggle = function(self, name, value)
            calls[#calls + 1] = {name, value}
            self.Toggles[name] = value == true
            return true
        end,
        ServerHop = function() calls.ServerHop = true end,
    }
    state2.__DEPHUB = {Mode = "BloxFruits", Version = "0.0.37", Backend = backend}
    local mounted = Host.Mount(state2, PanelFactory2)
    check(type(mounted) == "table", "host mounts a panel")
    check(state2.__DEPHUB.Frontend == mounted, "host publishes panel on __DEPHUB.Frontend")

    -- Find the first bound toggle and flip it: the backend must be notified.
    local flipped = false
    for _, component in ipairs(mounted.Components or {}) do
        if type(component.Get) == "function" and type(component.Set) == "function" and component:Get() == false then
            component:Set(true)
            flipped = true
            break
        end
    end
    check(flipped == true, "host bound at least one toggle")
    check(#calls >= 1, "flipping a bound control called the backend")

    print(string.format("panel checks: %d run, %d failed", checkCount, failCount))
    if failCount > 0 then
        error(string.format("%d panel check(s) failed", failCount))
    end
end

run()
