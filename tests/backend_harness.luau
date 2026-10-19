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
    return setmetatable({_props={ClassName=class, Name=class}, _children={}, _attributes={}}, instanceMeta)
end
local Enum = setmetatable({}, {__index=function(t, key)
    local values = setmetatable({}, {__index=function(s, name) rawset(s, name, name); return name end})
    rawset(t, key, values); return values
end})
-- INSERT_SOURCES
local function sandbox(placeId, gameId)
    local player = Instance.new("Player")
    player.CharacterAdded, player.CharacterRemoving, player.CameraMaxZoomDistance = signal(), signal(), 128
    local players = {LocalPlayer=player, PlayerAdded=signal(), PlayerRemoving=signal()}
    function players:GetPlayers() return {player} end
    local run = {RenderStepped=signal(), Stepped=signal(), Heartbeat=signal()}
    local input = {InputBegan=signal(), InputEnded=signal(), JumpRequest=signal()}
    local teleport = {Calls=0}
    function teleport:Teleport() self.Calls += 1 end
    function teleport:TeleportToPlaceInstance() self.Calls += 1 end
    local services = {Players=players, RunService=run, UserInputService=input, TeleportService=teleport,
        Workspace=Instance.new("Workspace"), Teams=Instance.new("Teams"), Lighting={},
        ReplicatedStorage=Instance.new("ReplicatedStorage"), TextChatService=Instance.new("TextChatService"), HttpService={}}
    services.Workspace.CurrentCamera = {CFrame = CFrame.new(0, 0, 0)}
    local context = {State={}, Logs={}, Requests={}, Responses={}, Deferred={}, Spawned={}, Services=services, Player=player}
    local game = {PlaceId=placeId or 1, GameId=gameId or 2, JobId="job"}
    function game:GetService(name) return assert(services[name], "Unexpected service " .. name) end
    function game:IsLoaded() return true end
    function game:HttpGet(url)
        context.Requests[#context.Requests + 1] = url
        assert(not url:find("src/ui/", 1, true), "Frontend download attempted")
        local path = url:gsub("^https://raw.githubusercontent.com/glowpkj/DepHub/main/", ""):gsub("%?.*$", "")
        return assert(context.Responses[path], "Unexpected HTTP: " .. path)
    end
    local env = setmetatable({game=game, workspace=services.Workspace, Color3=Color3, Vector3=Vector3, CFrame=CFrame, typeof=typeof, Instance=Instance, Enum=Enum,
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
    env._provided = {}
    context.Env = env
    return context
end
local vfxContext = sandbox()
local player = vfxContext.Player
local modules = {fruitvfx=vfxContext:Run("src/games/features/bloxfruits/fruitvfx.lua")}
-- INSERT_FRUIT_VFX_TESTS
-- INSERT_LIFECYCLE_TESTS
-- INSERT_HEADLESS_TESTS
print(string.format("PASS %d backend/headless checks", passed))
