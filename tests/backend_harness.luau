-- Behavioral doubles, not a Roblox rendering/physics/executor emulator.
local passed = 0
local function check(condition, message)
    assert(condition, message)
    passed += 1
end
local function signal()
    local event = {connections = {}}
    function event:Connect(fn)
        local connection = {Connected = true, fn = fn}
        function connection:Disconnect() self.Connected = false end
        self.connections[#self.connections + 1] = connection
        return connection
    end
    function event:Fire(...)
        for _, connection in ipairs(table.clone(self.connections)) do
            if connection.Connected then connection.fn(...) end
        end
    end
    function event:Once(fn)
        local connection
        connection=self:Connect(function(...) connection:Disconnect(); fn(...) end)
        return connection
    end
    return event
end
local Color3 = {}
local colorMeta = {__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end}
function Color3.new(r, g, b) return setmetatable({R=r, G=g, B=b, __color=true}, colorMeta) end
function Color3.fromRGB(r, g, b) return Color3.new(r/255, g/255, b/255) end
local Vector3 = {}
local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__add = function(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
vectorMeta.__sub = function(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
vectorMeta.__mul = function(a, b)
    if type(a) == "number" then return Vector3.new(a*b.X, a*b.Y, a*b.Z) end
    if type(b) == "number" then return Vector3.new(a.X*b, a.Y*b, a.Z*b) end
    return Vector3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z)
end
vectorMeta.__div = function(a, b) return Vector3.new(a.X/b, a.Y/b, a.Z/b) end
vectorMeta.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function Vector3.new(x, y, z)
    if type(x) == "table" then y, z = x.Y, x.Z; x = x.X end
    return setmetatable({X=x or 0, Y=y or 0, Z=z or 0, __vector=true, Magnitude=math.sqrt((x or 0)^2+(y or 0)^2+(z or 0)^2)}, vectorMeta)
end
function Vector3.zero() return Vector3.new(0, 0, 0) end
local vectors = Vector3

-- Minimal CFrame double: enough for camera lerp/aim tests. Tracks Position and a
-- LookAt target so Lerp can be verified to move partway, never in one jump.
local CFrame = {}
local cframeMeta = {}
cframeMeta.__index = cframeMeta
function CFrame.new(x, y, z)
    local position = type(x) == "table" and x or Vector3.new(x or 0, y or 0, z or 0)
    return setmetatable({Position = position, LookAt = nil, __cframe = true}, cframeMeta)
end
function CFrame.lookAt(from, to)
    local position = type(from) == "table" and from or Vector3.new(from, 0, 0)
    return setmetatable({Position = position, LookAt = to, __cframe = true}, cframeMeta)
end
function cframeMeta:Lerp(goal, alpha)
    local position = self.Position + (goal.Position - self.Position) * alpha
    local look
    if goal.LookAt then look = goal.LookAt end
    return setmetatable({Position = position, LookAt = look, __cframe = true}, cframeMeta)
end
-- Enough for offset math (target.CFrame * CFrame.new(dx, dy, dz)): positions add.
cframeMeta.__mul = function(a, b)
    return setmetatable({Position = a.Position + b.Position, LookAt = b.LookAt or a.LookAt, __cframe = true}, cframeMeta)
end
local builtinTypeof = typeof
local function typeof(value)
    if type(value) == "table" and value.__color then return "Color3" end
    if type(value) == "table" and value.__vector then return "Vector3" end
    if type(value) == "table" and value.__cframe then return "CFrame" end
    return builtinTypeof(value)
end
local methods, instanceMeta = {}, {}
function instanceMeta:__index(key) return methods[key] or self._props[key] end
function instanceMeta:__newindex(key, value)
    if key == "Parent" then
        local old = self._props.Parent
        if old then local index = table.find(old._children, self); if index then table.remove(old._children, index) end end
        self._props.Parent = value
        if value then value._children[#value._children + 1] = self end
    else
        self._props[key] = value
    end
end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetFullName() return self.Parent and self.Parent:GetFullName().."."..self.Name or self.Name end
function methods:FindFirstChild(name) for _, child in ipairs(self._children) do if child.Name == name then return child end end end
function methods:FindFirstChildWhichIsA(class) return self:FindFirstChildOfClass(class) end
function methods:GetDescendants() local result={}; for _,child in ipairs(self:GetChildren()) do result[#result+1]=child; for _,descendant in ipairs(child:GetDescendants()) do result[#result+1]=descendant end end; return result end
function methods:FindFirstChildOfClass(class) for _, child in ipairs(self._children) do if child:IsA(class) then return child end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "Unexpected wait: " .. name) end
function methods:IsA(class) return class == self.ClassName or class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart") end
function methods:IsDescendantOf(ancestor)
    local parent = self.Parent
    while parent do if parent == ancestor then return true end; parent = parent.Parent end
    return false
end
function methods:GetAttributes() if self.FailRead then error("Simulated read failure") end; return table.clone(self._attributes) end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:SetAttribute(key, value)
    if self.FailKey == key then self.FailKey = nil; error("Simulated attribute failure") end
    self._attributes[key] = value
    self.WriteCount = (self.WriteCount or 0) + 1
end
function methods:Destroy()
    for _, child in ipairs(self:GetChildren()) do child:Destroy() end
    self.Parent = nil
end
-- Remote doubles: record outgoing payloads so attack/quest features can assert
-- exactly what was sent to the server.
function methods:FireServer(...)
    self.Fired = self.Fired or {}
    self.Fired[#self.Fired + 1] = {...}
end
function methods:InvokeServer(...)
    self.Invoked = self.Invoked or {}
    self.Invoked[#self.Invoked + 1] = {...}
    return nil
end
local Instance = {}
function Instance.new(class)
    assert(class ~= "ScreenGui" and class ~= "TextButton" and class ~= "Frame", "Frontend instance created: " .. class)
    local object = setmetatable({_props={ClassName=class, Name=class}, _children={}, _attributes={}}, instanceMeta)
    -- Instance container signals, available on every double so feature modules
    -- that watch children/descendants bind exactly like they do in Roblox.
    object.ChildAdded = signal()
    object.ChildRemoved = signal()
    object.DescendantAdded = signal()
    object.DescendantRemoving = signal()
    -- Remote event doubles expose the client/server signals features connect to.
    if class == "RemoteEvent" or class == "RemoteFunction" or class == "BindableEvent" then
        object.OnClientEvent = signal()
        object.OnServerEvent = signal()
        object.OnServerInvoke = signal()
    end
    return object
end
-- UDim/UDim2 doubles: the Demon UI wrapper builds window sizes with them.
local UDim = {}
function UDim.new(scale, offset) return {Scale = scale or 0, Offset = offset or 0} end
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo) return {X = UDim.new(xs, xo), Y = UDim.new(ys, yo)} end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
local ColorSequence = {}
function ColorSequence.new(color) return {__colorSequence = true, Color = color} end
function ColorSequence.new(colorA, colorB) return {__colorSequence = true, Color = colorA, Color2 = colorB} end
local NumberSequence = {}
function NumberSequence.new(value) return {__numberSequence = true, Value = value} end
-- RaycastParams double: enough for prediction code to construct and mutate it.
local RaycastParams = {}
function RaycastParams.new() return {FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false} end
local Enum = setmetatable({}, {__index=function(t, key)
    local values = setmetatable({}, {__index=function(s, name) rawset(s, name, name); return name end})
    rawset(t, key, values); return values
end})
-- INSERT_SOURCES
-- Minimal stand-in for DemonOfDarknessUI. It records every category, tab and
-- control so tests can assert per-game isolation without a Roblox client.
local DOD_LIBRARY_STUB = [==[
local function NewWindow()
    local state = {ContentPages = {}, CategoryButtons = {}, ActiveCategory = "General", ActiveTab = nil}
    local library = {_STATE = state, _Categories = {}, _Tabs = {}, _Controls = {}}
    function library:CreateCategory(name, icon)
        self._Categories[name] = true
        state.CategoryButtons[name] = {button = {Visible = true, IsA = function(_, c) return c == "GuiObject" end}}
        return {Name = name}
    end
    function library:CreateTab(category, name)
        -- Mirror the real library: a tab name is global, so a duplicate name is
        -- an error, and the category must exist first.
        if not self._Categories[category] then
            error("[DoD UI] Category '" .. tostring(category) .. "' belum dibuat. Panggil :CreateCategory dulu.")
        end
        if state.ContentPages[name] then
            error("[DoD UI] Tab '" .. tostring(name) .. "' already exists.")
        end
        self._Tabs[#self._Tabs + 1] = {Category = category, Name = name}
        state.ContentPages[name] = {Visible = true}
        return {Name = name}
    end
    function library:CreateSection(tabName, title, _, _, column)
        if not state.ContentPages[tabName] then return nil end
        return {TabName = tabName, Title = title, Column = column}
    end
    function library:AddToggle(_, label, default, callback)
        library._Controls[#library._Controls + 1] = {Kind = "toggle", Label = label, Callback = callback}
        return {Kind = "toggle", Value = default}
    end
    function library:AddSlider(_, label, min, max, default, _, callback)
        library._Controls[#library._Controls + 1] = {Kind = "slider", Label = label, Min = min, Max = max, Callback = callback}
        return {Kind = "slider", Value = default}
    end
    function library:AddDropdown(_, label, options, index, callback)
        library._Controls[#library._Controls + 1] = {Kind = "dropdown", Label = label, Options = options, Callback = callback}
        return {Kind = "dropdown", Value = options[index]}
    end
    function library:AddButton(_, label, callback)
        library._Controls[#library._Controls + 1] = {Kind = "button", Label = label, Callback = callback}
        return {Kind = "button"}
    end
    function library:AddTextbox(_, label, _, callback)
        library._Controls[#library._Controls + 1] = {Kind = "textbox", Label = label, Callback = callback}
        return {Kind = "textbox", Value = ""}
    end
    function library:AddParagraph(_, title, body)
        library._Controls[#library._Controls + 1] = {Kind = "paragraph", Title = title, Body = body}
        return {Kind = "paragraph"}
    end
    function library:Notify(title, message) library.Notifications = library.Notifications or {}; library.Notifications[#library.Notifications + 1] = {title, message} end
    function library:SetActiveCategory(category, tab) state.ActiveCategory = category; state.ActiveTab = tab end
    function library:Destroy() library.Destroyed = true end
    return library
end
return {new = function() return NewWindow() end}
]==]
local function sandbox(placeId, gameId)
    local player = Instance.new("Player")
    player.CharacterAdded, player.CharacterRemoving, player.CameraMaxZoomDistance = signal(), signal(), 128
    player.Idled = signal()
    player.ChildAdded, player.ChildRemoved = signal(), signal()
    local players = {LocalPlayer=player, PlayerAdded=signal(), PlayerRemoving=signal()}
    function players:GetPlayers() return {player} end
    function players:GetPlayerFromCharacter(character)
        for _, candidate in ipairs(players:GetPlayers()) do if candidate.Character == character then return candidate end end
    end
    local run = {RenderStepped=signal(), Stepped=signal(), Heartbeat=signal()}
    local input = {InputBegan=signal(), InputEnded=signal(), JumpRequest=signal()}
    local teleport = {Calls=0}
    function teleport:Teleport() self.Calls += 1 end
    function teleport:TeleportToPlaceInstance() self.Calls += 1 end
    local tween = {Create=function(_, object, info, goal)
        return {Play=function() end, Cancel=function() end, Completed={Connect=function() end}}
    end}
    local vim = {}
    for _, name in ipairs({"SendKeyEvent", "SendMouseButtonEvent", "SendMouseMoveEvent", "SendKeyDownEvent", "SendKeyUpEvent", "SendMouseWheelEvent"}) do
        vim[name] = function() end
    end
    local vuser = {}
    for _, name in ipairs({"Button1Down", "Button1Up", "MouseMove", "KeyPress", "CaptureController", "ClickButton1", "MoveMouseRel"}) do
        vuser[name] = function() end
    end
    local services = {Players=players, RunService=run, UserInputService=input, TeleportService=teleport,
        TweenService=tween, VirtualInputManager=vim, VirtualUser=vuser,
        Workspace=Instance.new("Workspace"), Teams=Instance.new("Teams"), Lighting={},
        ReplicatedStorage=Instance.new("ReplicatedStorage"), TextChatService=Instance.new("TextChatService"), HttpService={}}
    services.Workspace.CurrentCamera = {CFrame = CFrame.new(0, 0, 0)}
    -- Workspace/instance container signals the feature modules connect to.
    services.Workspace.ChildAdded = signal()
    services.Workspace.ChildRemoved = signal()
    services.Workspace.DescendantAdded = signal()
    services.Workspace.DescendantRemoving = signal()
    -- ReplicatedStorage.Events holder that several games resolve remotes from.
    local events = Instance.new("Folder"); events.Name = "Events"; events.Parent = services.ReplicatedStorage
    -- Workspace physics/query surface used by prediction and movement features.
    services.Workspace.Gravity = 196.2
    function services.Workspace:Raycast() return nil end
    local context = {State={}, Logs={}, Requests={}, Responses={}, Deferred={}, Spawned={}, Services=services, Player=player}
    local game = {PlaceId=placeId or 1, GameId=gameId or 2, JobId="job"}
    function game:GetService(name) return assert(services[name], "Unexpected service " .. name) end
    function game:IsLoaded() return true end
    function game:HttpGet(url)
        context.Requests[#context.Requests + 1] = url
        assert(not url:find("src/ui/", 1, true), "Frontend download attempted")
        -- The theme module is a normal repo file; the test double stands in for
        -- it so the wrapper can build a window without a real client.
        if url:find("demon-theme", 1, true) or url:find("demon-of-darkness-ui", 1, true) or url:find("DemonOfDarknessUI", 1, true) then
            return DOD_LIBRARY_STUB
        end
        local path = url:gsub("^https://raw.githubusercontent.com/glowpkj/DepHub/main/", ""):gsub("%?.*$", "")
        return assert(context.Responses[path], "Unexpected HTTP: " .. path)
    end
    local env = setmetatable({game=game, workspace=services.Workspace, Color3=Color3, Vector3=Vector3, CFrame=CFrame, typeof=typeof, Instance=Instance, Enum=Enum,
        UDim=UDim, UDim2=UDim2, ColorSequence=ColorSequence, NumberSequence=NumberSequence, RaycastParams=RaycastParams,
        getgenv=function() return context.State end, identifyexecutor=function() return "Test" end,
        print=function(message) context.Logs[#context.Logs + 1] = tostring(message) end,
        warn=function(message) context.Logs[#context.Logs + 1] = tostring(message) end,
        task={wait=function() end, cancel=function() end,
            defer=function(fn, ...) context.Deferred[#context.Deferred + 1] = {Fn=fn, Args={...}} end,
            spawn=function(fn, ...) context.Spawned[#context.Spawned + 1] = {Fn=fn, Args={...}}; return fn end}}, {__index=getfenv(0)})
    function env.loadstring(source)
        local fn, err = loadstring(source)
        if fn then setfenv(fn, env) end
        return fn, err
    end
    function context:Run(path) return assert(env.loadstring(sources[path]))() end
    function context:FlushDeferred()
        local pending = self.Deferred
        self.Deferred = {}
        for _, call in ipairs(pending) do call.Fn(unpack(call.Args)) end
    end
    function context:Provide(path, value)
        self.Responses[path] = 'return _provided[' .. string.format('%q', path) .. ']'
        env._provided[path] = value
    end
    -- Install the Demon UI wrapper as the shared frontend (context.State.UI)
    -- and hand back the recorded library so tests can inspect which categories,
    -- tabs and controls a backend registered. The shell is identical for every
    -- game, so no mode/profile is passed here.
    function context:MountUI(options)
        options = options or {}
        local demon = env.loadstring(sources['src/core/demon-ui.lua'])()
        local window = demon.new({
            Name = 'DepHub',
            Version = options.Version or 'test'
        })
        self.State.__DEPHUB = self.State.__DEPHUB or {}
        self.State.__DEPHUB.UI = window
        return window, window.Library
    end
    env._provided = {}
    context.Env = env
    -- Core modules that the loader always fetches are served straight from the
    -- bundled sources unless a test overrides them, so a loader run only needs
    -- to provide its game backend.
    for path, source in pairs(sources) do
        if context.Responses[path] == nil then context.Responses[path] = source end
    end
    -- Vendored Blox Fruits modules read their globals from the shared
    -- environment (getgenv), not from chunk-locals, so publish the same runtime
    -- table a real executor's module would see.
    context.State.__DEPHUB_OSS_RUNTIME = {game = game, task = env.task}
    return context
end
local ossContext = sandbox()
local player = ossContext.Player
-- INSERT_BLOXF_OSS_TESTS
-- INSERT_LIFECYCLE_TESTS
-- INSERT_HEADLESS_TESTS
print(string.format("PASS %d backend/headless checks", passed))
