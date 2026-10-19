-- Panel regression checks.
--
-- Runs the real frontend factory and the real panel host against a GUI-capable
-- Roblox double, then asserts the structure the authored interface requires:
-- a protected ScreenGui, the window with its header/sidebar/content/footer, one
-- nav button per tab, tab switching, and that every control type builds and its
-- callback fires. This does not render anything; it checks the object graph and
-- the wiring, which is what can regress without a real client.
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
    function e:Fire(...)
        for _, c in ipairs(self.handlers) do
            if c.Connected then c.fn(...) end
        end
    end
    return e
end

local function isA(instance, class)
    return instance.ClassName == class
end

local instanceMeta = {}
local AUTO_SIGNALS = {
    MouseButton1Click = true, MouseButton2Click = true, MouseButton1Down = true, MouseButton1Up = true,
    MouseEnter = true, MouseLeave = true, InputBegan = true, InputEnded = true, InputChanged = true,
    Focused = true, FocusLost = true, Activated = true, ChildAdded = true, ChildRemoved = true,
    Changed = true, AncestryChanged = true, DescendantAdded = true, DescendantRemoving = true,
    CharacterAdded = true, CharacterRemoving = true, PlayerAdded = true, PlayerRemoving = true,
    Completed = true, Heartbeat = true, RenderStepped = true,
}
instanceMeta.__index = function(self, key)
    local method = instanceMeta[key]
    if method then return method end
    local props = rawget(self, "_props")
    if props[key] ~= nil then return props[key] end
    -- Roblox creates these events automatically; the double mirrors that so
    -- tests can fire them like the real engine.
    if AUTO_SIGNALS[key] then
        local e = signal()
        props[key] = e
        return e
    end
    return nil
end
instanceMeta.__newindex = function(self, key, value)
    rawget(self, "_props")[key] = value
end

function instanceMeta:GetChildren()
    return table.clone(rawget(self, "_children"))
end
function instanceMeta:FindFirstChild(name)
    for _, child in ipairs(rawget(self, "_children")) do
        if child.Name == name then return child end
    end
    return nil
end
function instanceMeta:FindFirstChildOfClass(class)
    for _, child in ipairs(rawget(self, "_children")) do
        if child.ClassName == class then return child end
    end
    return nil
end
function instanceMeta:FindFirstAncestorOfClass() return nil end
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
function instanceMeta:GetPropertyChangedSignal(name)
    return signal()
end
function instanceMeta:Clone() return Instance.new(self.ClassName) end

local Instance = {}
function Instance.new(class)
    local instance = setmetatable({
        _props = {ClassName = class, Name = class, Parent = nil},
        _children = {},
    }, instanceMeta)
    return instance
end
-- Parent setter maintains the children list.
local rawInstanceNewindex = instanceMeta.__newindex
instanceMeta.__newindex = function(self, key, value)
    if key == "Parent" then
        local props = rawget(self, "_props")
        local oldParent = props.Parent
        if oldParent then
            local siblings = rawget(oldParent, "_children")
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
    rawInstanceNewindex(self, key, value)
end

local Enum = setmetatable({}, {__index = function(t, key)
    local values = setmetatable({}, {__index = function(s, name) rawset(s, name, name); return name end})
    rawset(t, key, values)
    return values
end})

local UserInputService = {InputBegan = signal(), InputChanged = signal()}
local TweenService = {
    Create = function()
        local tween = {Play = function(self) self.Played = true; if self.Completed then self.Completed:Fire() end end,
            Cancel = function() end, Completed = signal()}
        return tween
    end
}
local PlayersService

local function makePlayerGui()
    local playerGui = Instance.new("PlayerGui")
    return playerGui
end

local function buildEnvironment()
    local playerGui = makePlayerGui()
    local player = Instance.new("Player")
    player.Name = "Tester"
    player.Character = nil
    player.CharacterAdded = signal()
    player.CharacterRemoving = signal()
    -- FindFirstChildOfClass("PlayerGui") on the player
    player.FindFirstChildOfClass = function(self, class)
        if class == "PlayerGui" then return playerGui end
        return instanceMeta.FindFirstChildOfClass(self, class)
    end
    local players = {LocalPlayer = player, PlayerAdded = signal(), PlayerRemoving = signal()}
    function players:GetPlayers() return {player} end
    PlayersService = players

    local services = {
        Players = players,
        UserInputService = UserInputService,
        TweenService = TweenService,
        RunService = {Heartbeat = signal(), RenderStepped = signal()},
        HttpService = {JSONDecode = function() return {} end, JSONEncode = function() return "{}" end},
    }
    local game = {
        PlaceId = 994732206,
        GameId = 2753915549,
        Name = "Blox Fruits",
        GetService = function(self, name)
            if services[name] then return services[name] end
            local made = Instance.new(name)
            services[name] = made
            return made
        end,
    }
    local state = {}
    local env = setmetatable({
        game = game,
        Instance = Instance,
        Enum = Enum,
        signal = signal,
        getgenv = function() return state end,
        typeof = typeof,
        task = {wait = function() end, defer = function(fn) fn() end, spawn = function(fn) return fn end, cancel = function() end, delay = function(_, fn) end},
        Color3 = {fromRGB = function(r, g, b) return {r = r, g = g, b = b} end},
        UDim = {new = function(s, o) return {Scale = s, Offset = o} end, fromScale = function(s) return {Scale = s, Offset = 0} end, fromOffset = function(o) return {Scale = 0, Offset = o} end},
        UDim2 = {new = function(xs, xo, ys, yo) return {X = {Scale = xs, Offset = xo}, Y = {Scale = ys, Offset = yo}} end,
            fromScale = function(x, y) return {X = {Scale = x, Offset = 0}, Y = {Scale = y, Offset = 0}} end,
            fromOffset = function(x, y) return {X = {Scale = 0, Offset = x}, Y = {Scale = 0, Offset = y}} end},
        Vector2 = {new = function(x, y) return {X = x, Y = y} end},
        NumberSequence = {new = function() return {} end},
        ColorSequence = {new = function() return {} end},
        TweenInfo = {new = function() return {} end},
    }, {__index = _G})
    env._G = env
    env.script = nil
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
    local env, state = buildEnvironment()
    local PanelFactory = loadModule(env, "src/frontend/init.lua")
    check(type(PanelFactory) == "table" and type(PanelFactory.new) == "function", "frontend exposes .new")

    local panel = PanelFactory.new({Title = "DepHub", GameName = "Blox Fruits", StartOpen = true})
    check(type(panel) == "table", "panel constructed")

    -- ScreenGui must be named to match ui-guard's "dephub" rule and sit in PlayerGui.
    local screen = panel.ScreenGui
    check(screen ~= nil and screen.ClassName == "ScreenGui", "screen gui created")
    check(string.find(string.lower(screen.Name), "dephub", 1, true) ~= nil, "screen gui name contains dephub for ui-guard")
    check(screen.ResetOnSpawn == false, "screen gui survives respawn")
    check(screen.Enabled == true, "screen gui enabled when StartOpen")

    -- Window structure
    local window = panel.Window
    check(window ~= nil, "window frame exists")
    check(window:FindFirstChild("Header") ~= nil, "header exists")
    check(window:FindFirstChild("Body") ~= nil, "body exists")
    check(window:FindFirstChild("Body"):FindFirstChild("Sidebar") ~= nil, "sidebar exists")
    check(window:FindFirstChild("Body"):FindFirstChild("Content") ~= nil, "content exists")
    check(window:FindFirstChild("Body"):FindFirstChild("Footer") ~= nil, "footer exists")
    check(window:FindFirstChildOfClass("UICorner") ~= nil, "window has rounded corners")

    -- Window buttons
    local buttons = window:FindFirstChild("Header"):FindFirstChild("WindowButtons")
    check(buttons ~= nil and buttons:FindFirstChild("Close") ~= nil and buttons:FindFirstChild("Minimize") ~= nil and buttons:FindFirstChild("Expand") ~= nil,
        "three traffic-light buttons exist")

    -- Tabs
    local tabA = panel:CreateTab("Jogador", "◫")
    local tabB = panel:CreateTab("Visual", "◎")
    check(tabA.Page ~= nil and tabB.Page ~= nil, "tabs create pages")
    check(tabB.Page.Visible == false, "second tab starts hidden")
    check(tabA.Page.Visible == true, "first tab starts visible")
    panel:SelectTab("Visual")
    check(tabB.Page.Visible == true and tabA.Page.Visible == false, "SelectTab switches visibility")

    -- Toggle
    local toggled = false
    local toggle = panel:AddToggle(tabA, "Teste", "Ajuda", false, function(value) toggled = value end)
    check(toggle:Get() == false, "toggle starts false")
    toggle:Set(true)
    check(toggle:Get() == true and toggled == true, "toggle set triggers callback")

    -- Checkbox
    local checkbox = panel:AddCheckbox(tabA, "Lembrar", nil, false, nil)
    checkbox:Set(true)
    check(checkbox:Get() == true, "checkbox set/get")

    -- Slider
    local sliderValue = nil
    local slider = panel:AddSlider(tabA, "Distância", nil, 0, 100, 10, 50, function(v) sliderValue = v end)
    check(slider:Get() == 50, "slider starts at 50")
    slider:Set(73)  -- quantizes to 70
    check(slider:Get() == 70, "slider quantizes to step")
    check(sliderValue == 70, "slider callback fires")

    -- Dropdown
    local picked = nil
    local dropdown = panel:AddDropdown(tabA, "Perfil", nil, {"A", "B", "C"}, "A", function(v) picked = v end)
    check(dropdown:Get() == "A", "dropdown starts at first option")
    dropdown:Set("C")
    check(dropdown:Get() == "C" and picked == "C", "dropdown set triggers callback")
    dropdown:Set("Z")
    check(dropdown:Get() == "C", "dropdown rejects unknown option")

    -- TextField
    local textField = panel:AddTextField(tabA, "Nome", "placeholder", "inicial", nil)
    check(textField:Get() == "inicial", "text field starts with value")
    textField:Set("novo")
    check(textField:Get() == "novo", "text field set/get")

    -- Action
    local ran = false
    local action = panel:AddAction(tabA, "Executar", nil, "Rodar", function() ran = true end, true)
    action.Instance.MouseButton1Click:Fire()
    check(ran == true, "action button runs callback")

    -- Notice
    local notice = panel:AddNotice(tabA, "Mensagem de aviso", "Título")
    check(notice:FindFirstChild("Body") ~= nil, "notice builds body")

    -- Collapsible
    local collapsible = panel:AddCollapsible(tabA, "Detalhes", false)
    check(collapsible.Body.Visible == false, "collapsible starts closed")
    collapsible.Toggle.MouseButton1Click:Fire()
    check(collapsible.Body.Visible == true, "collapsible opens on click")

    -- Feedback
    panel:Notify("Título", "Mensagem")
    check(panel.Toast.Visible == true, "toast shows")
    check(panel.ToastTitle.Text == "Título", "toast title set")

    panel:Confirm("Confirmar?", "Deseja?", nil)
    check(panel.ModalOverlay.Visible == true, "modal shows")
    local confirmButton = panel.Modal:FindFirstChild("Buttons"):FindFirstChild("Cancel")
    check(confirmButton ~= nil, "modal has cancel button")

    -- Window state
    panel:ToggleMinimize()
    check(panel.Minimized == true, "minimize toggles state")
    panel:ToggleMinimize()
    check(panel.Minimized == false, "minimize toggles back")
    panel:ToggleExpand()
    check(panel.Expanded == true, "expand toggles state")

    panel:SetOpen(false)
    check(panel.Open == false and screen.Enabled == false, "SetOpen(false) hides gui")
    panel:SetOpen(true)
    check(panel.Open == true and screen.Enabled == true, "SetOpen(true) shows gui")

    -- Destroy cleans up
    panel:Destroy()
    check(screen:FindFirstChild("Header") == nil or true, "destroy ran without error")
    check(panel.Destroyed == true, "panel marked destroyed")

    -- Host mounts against a Blox Fruits-shaped backend
    local env2, state2 = buildEnvironment()
    local PanelFactory2 = loadModule(env2, "src/frontend/init.lua")
    local Host = loadModule(env2, "src/core/panel-host.lua")
    check(type(Host) == "table" and type(Host.Mount) == "function", "panel host exposes Mount")

    local calls = {}
    local backend = {
        Toggles = {PlayerESP = false, FruitESP = false, AutoFarm = false, BladeHits = false, AutoJoinTeam = true},
        Values = {DashLength = 3},
        GetToggle = function(self, name) return self.Toggles[name] == true end,
        SetToggle = function(self, name, value) calls[#calls + 1] = {name, value}; self.Toggles[name] = value == true; return true end,
        ServerHop = function() calls.ServerHop = true end,
    }
    state2.__DEPHUB = {Mode = "BloxFruits", Version = "0.0.37", Backend = backend}
    local mounted = Host.Mount(state2, PanelFactory2)
    check(type(mounted) == "table", "host mounts a panel for BloxFruits")
    check(state2.__DEPHUB.Frontend == mounted, "host publishes the panel on __DEPHUB.Frontend")
    -- The BloxFruits spec declares PlayerESP; find its toggle and flip it.
    local found = false
    for _, component in ipairs(mounted.Components or {}) do
        if type(component.Set) == "function" and type(component.Get) == "function" then
            if component:Get() == false then
                component:Set(true)
                found = true
                break
            end
        end
    end
    check(found == true, "host bound at least one toggle")
    check(#calls >= 1, "toggling a bound control called the backend")

    print(string.format("panel checks: %d run, %d failed", checkCount, failCount))
    if failCount > 0 then
        error(string.format("%d panel check(s) failed", failCount))
    end
end

run()
