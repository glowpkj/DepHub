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
    -- Roblox signals have :Wait(); the harness cannot block, so it returns at once
    -- (the deferred body runs on the same test step). Faithful enough for code
    -- that waits one frame before acting -- the frame boundary is simulated by
    -- the test firing Heartbeat or flushing spawned work.
    function event:Wait()
        return nil
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
-- Real Vector3.Lerp: linear interpolation, used by velocity smoothing.
function vectorMeta:Lerp(goal, alpha)
    return Vector3.new(self.X + (goal.X - self.X) * alpha, self.Y + (goal.Y - self.Y) * alpha, self.Z + (goal.Z - self.Z) * alpha)
end
-- Real Vector3.Unit: Roblox exposes this as a property, so each vector carries
-- its normalised form from construction (there is no live mutation here). The
-- unit vector is built directly, without recursing into Vector3.new.
function Vector3.new(x, y, z)
    if type(x) == "table" then y, z = x.Y, x.Z; x = x.X end
    x, y, z = x or 0, y or 0, z or 0
    local magnitude = math.sqrt(x^2 + y^2 + z^2)
    local vector = setmetatable({X=x, Y=y, Z=z, __vector=true, Magnitude=magnitude}, vectorMeta)
    if magnitude == 0 then
        vector.Unit = setmetatable({X=0, Y=0, Z=0, __vector=true, Magnitude=0}, vectorMeta)
    else
        vector.Unit = setmetatable({X=x/magnitude, Y=y/magnitude, Z=z/magnitude, __vector=true, Magnitude=1}, vectorMeta)
    end
    return vector
end
-- Vector3.zero is a value in Roblox, not a function: features read it as a value
-- (hrp.AssemblyLinearVelocity = Vector3.zero). Matching the real API here keeps
-- a value-vs-call mixup from hiding behind the double.
Vector3.zero = Vector3.new(0, 0, 0)
local vectors = Vector3

-- Minimal CFrame double: enough for camera lerp/aim tests. Tracks Position and a
-- LookAt target so Lerp can be verified to move partway, never in one jump.
local CFrame = {}
local cframeMeta = {}
local cframeMetaMethods = {}
cframeMeta.__index = function(self, key)
    -- LookVector is the unit facing direction. The double has no matrix, so it is
    -- derived from the LookAt target: (target - position) normalised, or (1,0,0)
    -- when there is no target. Enough for "did the body turn this way" checks.
    if key == "LookVector" then
        local target = self.LookAt
        if target then
            local delta = target - self.Position
            if delta.Magnitude > 0 then return delta.Unit end
        end
        return Vector3.new(1, 0, 0)
    end
    return cframeMetaMethods[key]
end
function CFrame.new(x, y, z)
    local position = type(x) == "table" and x or Vector3.new(x or 0, y or 0, z or 0)
    return setmetatable({Position = position, LookAt = nil, __cframe = true}, cframeMeta)
end
function CFrame.lookAt(from, to)
    local position = type(from) == "table" and from or Vector3.new(from, 0, 0)
    return setmetatable({Position = position, LookAt = to, __cframe = true}, cframeMeta)
end
function cframeMetaMethods:Lerp(goal, alpha)
    local position = self.Position + (goal.Position - self.Position) * alpha
    local look
    if goal.LookAt then look = goal.LookAt end
    return setmetatable({Position = position, LookAt = look, __cframe = true}, cframeMeta)
end
-- The double carries no rotation, so object space is just world space rebased on
-- the frame's position. Court-inside tests rely on this.
function cframeMetaMethods:PointToObjectSpace(point)
    return point - self.Position
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
    -- Instance doubles are plain tables; the engine reports "Instance" for them,
    -- and features that guard a remote with typeof(x) == "Instance" (the silent
    -- aim hook does) depend on that. The _props.ClassName tag is the marker.
    if type(value) == "table" and type(value._props) == "table" and value._props.ClassName then return "Instance" end
    return builtinTypeof(value)
end
-- GUI-only members the harness rejects on non-GUI instances (see __newindex).
-- Position is deliberately absent: it is a real BasePart property.
local GUI_ONLY_MEMBERS = {Visible = true, BackgroundColor3 = true, TextSize = true, Text = true, ZIndex = true}
local GUI_CLASSES = {Frame = true, TextButton = true, TextLabel = true, ImageLabel = true, ScrollingFrame = true, ScreenGui = true}
local methods, instanceMeta = {}, {}function instanceMeta:__index(key)
    -- An own value (set by a feature or by an executor-style hook) wins over
    -- the shared method table, so per-instance overrides are observable.
    local own = self._props[key]
    if own ~= nil then return own end
    -- A real Instance resolves a child by NAME through the same index path
    -- (`LP.Data.Level`). Model that so features that read a child this way
    -- (the ESP reads LP.Data.<Field>.Value) behave as they do in game -- but
    -- ONLY for keys that are not properties. A key the code has explicitly
    -- written (even to nil, e.g. `Player.Character = nil`) is a property, and a
    -- stale child of the same name must not resurface through it.
    if type(key) == "string" and methods[key] == nil and not (rawget(self, "_setKeys") and rawget(self, "_setKeys")[key]) then
        for _, child in ipairs(self._children) do
            if child.Name == key then return child end
        end
    end
    -- Position mirrors CFrame on a real BasePart; deriving it here keeps code
    -- that reads one after setting the other from seeing nil in the double.
    if key == "Position" then
        local frame = self._props.CFrame
        if frame then return frame.Position end
    end
    return methods[key]
end
function instanceMeta:__newindex(key, value)
    if key == "Parent" then
        local old = self._props.Parent
        if old then local index = table.find(old._children, self); if index then table.remove(old._children, index) end end
        self._props.Parent = value
        if value then value._children[#value._children + 1] = self end
    else
        -- Guard against writing a GUI-only property onto a non-GUI instance:
        -- "Visible is not a valid member of Part" only shows up in a real client,
        -- so catching it here keeps that class of bug out of the bundle.
        local class = self._props.ClassName
        if GUI_ONLY_MEMBERS[key] and not GUI_CLASSES[class] then
            error(string.format("%s is not a valid member of %s", tostring(key), tostring(class)), 2)
        end
        -- A remote's own methods live on the shared metatable, so a field
        -- assignment cannot shadow them in the real client -- it raises instead.
        -- Modelling that here is what stops a wrap-by-assignment from passing in
        -- tests and then failing in game with "FireServer is not a valid member".
        if (class == "RemoteEvent" and key == "FireServer")
            or (class == "RemoteFunction" and (key == "InvokeServer" or key == "FireServer")) then
            error(string.format("%s is not a valid member of %s", tostring(key), tostring(class)), 2)
        end
        self._props[key] = value
        -- Record the explicit write so __index does not let a stale child of the
        -- same name resurface through a property the code set (even to nil).
        local setKeys = rawget(self, "_setKeys")
        if not setKeys then setKeys = {}; rawset(self, "_setKeys", setKeys) end
        setKeys[key] = true
        -- On a Value object (NumberValue/...) the engine raises Changed whenever
        -- Value is written. Firing it here lets a feature that watches a value
        -- (the Player tab keeps Stun at 0) react exactly as it does in game.
        if key == "Value" and self._isValueObject and self.Changed then
            self.Changed:Fire(value)
        end
    end
end
function instanceMeta:__tostring() return self._props.ClassName end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetFullName() return self.Parent and self.Parent:GetFullName().."."..self.Name or self.Name end
function methods:FindFirstChild(name) for _, child in ipairs(self._children) do if child.Name == name then return child end end end
function methods:FindFirstChildWhichIsA(class) return self:FindFirstChildOfClass(class) end
function methods:GetDescendants() local result={}; for _,child in ipairs(self:GetChildren()) do result[#result+1]=child; for _,descendant in ipairs(child:GetDescendants()) do result[#result+1]=descendant end end; return result end
function methods:FindFirstChildOfClass(class) for _, child in ipairs(self._children) do if child:IsA(class) then return child end end end
-- Model:GetPivot(). The harness has no transform hierarchy, so the pivot is the
-- first BasePart's position (what a raid island's floor gives you). Real Roblox
-- derives it from the model's bounding box; the position is what tests assert.
function methods:GetPivot()
    for _, child in ipairs(self:GetChildren()) do
        if child:IsA("BasePart") then return {Position = child.Position} end
    end
    for _, descendant in ipairs(self:GetDescendants()) do
        if descendant:IsA("BasePart") then return {Position = descendant.Position} end
    end
    return {Position = Vector3.new(0, 0, 0)}
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "Unexpected wait: " .. name) end
function methods:IsA(class) return class == self.ClassName or class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart") end
function methods:IsDescendantOf(ancestor)
    local parent = self.Parent
    while parent do if parent == ancestor then return true end; parent = parent.Parent end
    return false
end
function methods:GetAttributes() if self.FailRead then error("Simulated read failure") end; return table.clone(self._attributes) end
function methods:GetAttribute(key) return self._attributes[key] end
-- Per-key attribute-changed signals, so a feature that re-applies an attribute
-- when the game writes it back (e.g. keeping UnbreakableAll true) is testable:
-- SetAttribute fires the signal for that key, exactly like Roblox.
function methods:GetAttributeChangedSignal(key)
    self._attrSignals = self._attrSignals or {}
    local attrSignal = self._attrSignals[key]
    if not attrSignal then attrSignal = signal(); self._attrSignals[key] = attrSignal end
    return attrSignal
end
function methods:SetAttribute(key, value)
    if self.FailKey == key then self.FailKey = nil; error("Simulated attribute failure") end
    self._attributes[key] = value
    self.WriteCount = (self.WriteCount or 0) + 1
    local signal = self._attrSignals and self._attrSignals[key]
    if signal then signal:Fire() end
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
-- The base __namecall the engine always provides: dispatch a method-style call
-- to the instance's own closure. A feature that installs its own __namecall
-- (via getrawmetatable(game)) chains to this one as `original`, exactly as the
-- real executor hook does -- so the hook can rewrite args and still forward.
-- The current method name lives in a module-level slot the test driver sets,
-- mirroring the engine's `getnamecallmethod()`.
local namecallMethod = nil
function instanceMeta:__namecall(...)
    local method = namecallMethod
    local impl = self._props[method]
    if type(impl) == "function" then return impl(self, ...) end
    local shared = methods[method]
    if shared then return shared(self, ...) end
    error(tostring(method) .. " is not a valid member of " .. tostring(self._props.ClassName), 2)
end
local Instance = {}
-- Every double created, so executor-style hooking can locate the Instance that
-- owns a method closure (hookfunction takes only the function, not the owner).
local INSTANCES = {}
function Instance.new(class)
    assert(class ~= "ScreenGui" and class ~= "TextButton" and class ~= "Frame", "Frontend instance created: " .. class)
    local object = setmetatable({_props={ClassName=class, Name=class}, _children={}, _attributes={}}, instanceMeta)
    INSTANCES[#INSTANCES + 1] = object
    -- Instance container signals, available on every double so feature modules
    -- that watch children/descendants bind exactly like they do in Roblox.
    object.ChildAdded = signal()
    object.ChildRemoved = signal()
    object.DescendantAdded = signal()
    object.DescendantRemoving = signal()
    -- Value objects (NumberValue/StringValue/...) and every double expose a
    -- Changed signal. On a real Value object the engine fires it when Value
    -- changes; here the __newindex metamethod below keeps `Value` in sync and
    -- fires the same signal, so a feature that watches a NumberValue (e.g.
    -- keeping Stun at 0) binds and re-applies exactly like it does in game.
    object.Changed = signal()
    if class == "NumberValue" or class == "IntValue" or class == "StringValue" or class == "BoolValue" or class == "ObjectValue" then
        object._props.Value = 0
    end
    object._isValueObject = (class == "NumberValue" or class == "IntValue" or class == "StringValue" or class == "BoolValue" or class == "ObjectValue")
    -- Remote event doubles expose the client/server signals features connect to.
    -- Each remote also gets its OWN FireServer/InvokeServer closure (not the
    -- shared table method) so an executor-style hook can be routed back to the
    -- exact Instance that owns it, the way hookfunction patches one closure.
    if class == "RemoteEvent" or class == "RemoteFunction" or class == "BindableEvent" then
        object.OnClientEvent = signal()
        object.OnServerEvent = signal()
        object.OnServerInvoke = signal()
        object._props.FireServer = function(self, ...)
            self.Fired = self.Fired or {}
            self.Fired[#self.Fired + 1] = {...}
        end
        object._props.InvokeServer = function(self, ...)
            self.Invoked = self.Invoked or {}
            self.Invoked[#self.Invoked + 1] = {...}
            return nil
        end
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
-- TweenInfo double: the fly/tween features construct one before Create.
local TweenInfo = {}
function TweenInfo.new(time, style, direction)
    return {__tweenInfo = true, Time = time or 1, Style = style, Direction = direction}
end
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
    local state = {ContentPages = {}, CategoryButtons = {}, CategoryTabs = {}, ActiveCategory = "General", ActiveTab = nil, GuiVisible = true}
    local library = {_STATE = state, _Categories = {}, _Tabs = {}, _Controls = {}}
    DOD_STUB_LIBRARY = library
    function library:Toggle()
        state.GuiVisible = not state.GuiVisible
        return state.GuiVisible
    end
    function library:CreateCategory(name, icon)
        self._Categories[name] = true
        -- Mirror the real library: each category owns a "TabList" frame that holds
        -- its tab buttons, and CATEGORY_TABS tracks the ordered names per category.
        -- The backend moves sea-scoped tabs between these lists, so the harness has
        -- to model the container and its Parent, not just a visibility flag.
        local tabList = {ClassName = "Frame", Name = "TabList", Visible = true, _children = {}, _props = {}}
        tabList.IsA = function(_, c) return c == "GuiObject" or c == "Frame" end
        tabList.GetChildren = function(self) return self._children end
        state.CategoryButtons[name] = {button = {Visible = true, IsA = function(_, c) return c == "GuiObject" end}, tabList = tabList}
        state.CategoryTabs[name] = state.CategoryTabs[name] or {}
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
        -- A tab button parented to its category's TabList, named like the real
        -- library so a move can be observed by reading the Parent's Name.
        local list = state.CategoryButtons[category] and state.CategoryButtons[category].tabList
        local button = {ClassName = "TextButton", Name = "SubTab_" .. name, Visible = true, Parent = list, _props = {}, _children = {}}
        button.IsA = function(_, c) return c == "GuiObject" or c == "TextButton" end
        if list then list._children[#list._children + 1] = button end
        state.CategoryTabs[category] = state.CategoryTabs[category] or {}
        state.CategoryTabs[category][#state.CategoryTabs[category] + 1] = name
        return {Name = name, Button = button}
    end
    -- VStack/HStack: a named grouping container. Controls added through the
    -- returned handle record exactly like section controls, so tests see the
    -- same flat list; Row/Stack just marks how they are laid out. Declared before
    -- CreateSection so the section handle built there can close over it.
    local makeGroup
    makeGroup = function(kind)
        local group = {Kind = kind, _n = 0}
        group.AddToggle = function(_, ...) group._n = group._n + 1; return library:AddToggle(nil, ...) end
        group.AddSlider = function(_, ...) group._n = group._n + 1; return library:AddSlider(nil, ...) end
        group.AddDropdown = function(_, ...) group._n = group._n + 1; return library:AddDropdown(nil, ...) end
        group.AddMultiDropdown = function(_, ...) group._n = group._n + 1; return library:AddDropdown(nil, ...) end
        group.AddButton = function(_, ...) group._n = group._n + 1; return library:AddButton(nil, ...) end
        group.AddTextbox = function(_, ...) group._n = group._n + 1; return library:AddTextbox(nil, ...) end
        group.AddKeybind = function(_, ...) group._n = group._n + 1; return {Kind = "keybind"} end
        group.AddColorPicker = function(_, ...) group._n = group._n + 1; return {Kind = "colorpicker"} end
        group.AddParagraph = function(_, ...) group._n = group._n + 1; return library:AddParagraph(nil, ...) end
        group.AddSeparator = function(_, ...) group._n = group._n + 1; return {Kind = "separator"} end
        group.AddLabel = function(_, ...) group._n = group._n + 1; return {Kind = "label"} end
        group.AddChipBar = function(_, ...) group._n = group._n + 1; return {Kind = "chipbar"} end
        group.AddConfigList = function(_, ...) group._n = group._n + 1; return {Kind = "configlist"} end
        group.CreateToggle = function(_, ...) return group.AddToggle(group, ...) end
        group.CreateSlider = function(_, ...) return group.AddSlider(group, ...) end
        group.CreateDropdown = function(_, ...) return group.AddDropdown(group, ...) end
        group.CreateButton = function(_, ...) return group.AddButton(group, ...) end
        group.CreateInput = function(_, ...) return group.AddTextbox(group, ...) end
        group.CreateParagraph = function(_, ...) return group.AddParagraph(group, ...) end
        group.CreateSeparator = function(_, ...) return group.AddSeparator(group, ...) end
        group.CreateLabel = function(_, ...) return group.AddLabel(group, ...) end
        library._Groups = library._Groups or {}
        library._Groups[#library._Groups + 1] = group
        return group
    end
    function library:CreateSection(tabName, title, _, _, column)
        -- Mirror the real library's contract: the column must be "Left" or
        -- "Right" (or nil -> "Left"). A backend that passes a summary/other
        -- string where the column belongs would have its section silently
        -- dropped in game; failing here keeps that bug from reaching the panel.
        if column ~= nil and column ~= "Left" and column ~= "Right" then
            error("[DoD UI] CreateSection column must be 'Left' or 'Right'.")
        end
        if not state.ContentPages[tabName] then return nil end
        -- The real library returns a WRAPPED section handle (theme-apply's
        -- _wrapSection), and AddHStack/AddVStack live on that handle, not on the
        -- library. The stub has to return the same shape, or a wrong call site
        -- (Library:AddHStack) would pass here and fail in game.
        local section = {TabName = tabName, Title = title, Column = column or "Left", __tag = "Section"}
        section.AddHStack = function() return makeGroup("HStack") end
        section.AddVStack = function() return makeGroup("VStack") end
        return section
    end
    function library:AddToggle(_, label, default, callback)
        local handle = {Kind = "toggle", Value = default, Label = label, Callback = callback}
        -- RedzLib's toggle handle exposes :SetValue, which flips the control and
        -- fires its callback. The Island teleport backend uses it to switch the
        -- toggle off when the flight lands, so the double models it.
        function handle:SetValue(value)
            if self.Value == value then return nil end
            self.Value = value
            if self.Callback then self.Callback(self.Value) end
            return self.Value
        end
        library._Controls[#library._Controls + 1] = {Kind = "toggle", Label = label, Callback = callback, Handle = handle}
        return handle
    end
    function library:AddSlider(_, label, min, max, default, _, callback)
        library._Controls[#library._Controls + 1] = {Kind = "slider", Label = label, Min = min, Max = max, Value = default, Callback = callback}
        return {Kind = "slider", Value = default}
    end
    -- The 4th arg is the Default VALUE (the real library's `Default = <option>`),
    -- not an index: a single-select dropdown's Value is the chosen option string.
    -- An unknown/nil default falls back to the first option, like the library.
    function library:AddDropdown(_, label, options, default, callback, multi)
        -- The real library's multi-select `Default` is an ARRAY of the pre-selected
        -- names (`for i = 1, #Default`). Handed a set `{F=true}` it loops zero
        -- times and selects nothing -- the dropdown then shows its "..." placeholder
        -- and looks unselectable. Model that, and expose the resulting label, so a
        -- bad default is caught here instead of in game.
        local initial = default
        if multi == true then
            local set = {}
            if type(default) == "table" then
                -- Only a proper array (ipairs) counts, exactly like the library.
                for _, name in ipairs(default) do set[tostring(name)] = true end
            end
            initial = set
        elseif type(initial) ~= "string" then
            initial = options[1]
        end
        local handle = {Kind = "dropdown", Value = initial, Options = options, MultiSelect = multi == true, Callback = callback}
        -- `Label` is what the field renders: for multi, the selected names joined;
        -- empty means the "..." placeholder (the bug).
        if multi == true then
            local names = {}
            for _, name in ipairs(options) do if initial[name] then names[#names + 1] = name end end
            handle.Text = #names > 0 and table.concat(names, ", ") or "..."
        else
            handle.Text = tostring(initial)
        end
        library._Controls[#library._Controls + 1] = {Kind = "dropdown", Label = label, Options = options, Callback = callback, MultiSelect = multi == true, Handle = handle}
        -- Single-select: :SetValue moves the chosen option and fires the callback,
        -- the way RedzLib's dropdown does when a saved config restores a choice.
        function handle:SetValue(value)
            if multi == true then return nil end
            if self.Value == value then return nil end
            self.Value = value
            self.Text = tostring(value)
            if self.Callback then self.Callback(self.Value) end
            return self.Value
        end
        -- A multi-select dropdown in RedzLib hands its callback a SET table of the
        -- selected names. Model that, plus the array-ifying the adapter does, so
        -- tests can drive a selection and see the backend's array contract.
        local selected = {}
        if multi == true and type(default) == "table" then
            for _, name in ipairs(default) do selected[name] = true end
        end
        function handle:Select(name, isSelected)
            if multi ~= true then return nil end
            selected[tostring(name)] = isSelected ~= false
            local names = {}
            for _, option in ipairs(options) do if selected[option] then names[#names + 1] = option end end
            handle.Text = #names > 0 and table.concat(names, ", ") or "..."
            if self.Callback then
                local snapshot = {}
                for option, on in pairs(selected) do if on then snapshot[option] = true end end
                self.Callback(snapshot)
            end
            return selected
        end
        -- The real library's restore path: Clear removes every option, Add re-adds
        -- one (which is how a saved multi selection is put back). Model both so the
        -- adapter's handle.Set("clear then re-add") is exercised.
        function handle:Clear()
            if multi ~= true then return nil end
            selected = {}
            handle.Text = "..."
        end
        function handle:Add(name)
            if multi ~= true then return nil end
            selected[tostring(name)] = true
            local names = {}
            for _, option in ipairs(options) do if selected[option] then names[#names + 1] = option end end
            handle.Text = #names > 0 and table.concat(names, ", ") or "..."
            return selected
        end
        return handle
    end
    function library:AddButton(_, label, callback)
        library._Controls[#library._Controls + 1] = {Kind = "button", Label = label, Callback = callback}
        return {Kind = "button"}
    end
    function library:AddTextbox(_, label, _, callback)
        library._Controls[#library._Controls + 1] = {Kind = "textbox", Label = label, Callback = callback}
        return {Kind = "textbox", Value = ""}
    end
    function library:Notify(title, message) library.Notifications = library.Notifications or {}; library.Notifications[#library.Notifications + 1] = {title, message} end
    function library:AddParagraph(_, title, body)
        library._Controls[#library._Controls + 1] = {Kind = "paragraph", Title = title, Body = body}
        return {Kind = "paragraph"}
    end
    function library:SetActiveCategory(category, tab) state.ActiveCategory = category; state.ActiveTab = tab end
    -- The loader builds a fixed Dashboard tab from every game: a banner
    -- (greeting/avatar + server card) and the live performance metrics. The
    -- stub records the calls so the loader test can assert the tab is built.
    function library:CreateDashboardBanner(tabName)
        library.Dashboard = library.Dashboard or {}
        library.Dashboard.Banner = tabName
        return {Kind = "dashboardBanner", TabName = tabName}
    end
    function library:CreatePerformanceDashboard(tabName, column)
        library.Dashboard = library.Dashboard or {}
        library.Dashboard.Performance = {TabName = tabName, Column = column}
        return {Kind = "performanceDashboard", TabName = tabName, Column = column}
    end
    function library:Destroy() library.Destroyed = true end
    -- The adapter loads this stub through the RedzLib entry point and drives it
    -- through RedzLib's own shape, so the window has to expose MakeTab and every
    -- Add* accepts a single named-options table. The handlers translate that into
    -- the stub's positional form, keeping the flat DepHub contract the lifecycle
    -- tests assert on.
    local function opt(kind, value)
        -- Accept both RedzLib's named table and the stub's positional argument.
        if type(kind) == "table" then return kind[value] end
        return value
    end
    function library:MakeTab(options)
        options = options or {}
        local name = opt(options, "Title") or opt(options, "Name") or options[1] or "Tab"
        local handle = {Title = name, IS_A_TAB = true}
        local tabs = library._Tabs or {}
        tabs[#tabs + 1] = {Category = state.ActiveCategory, Name = name}
        state.ContentPages[name] = {Visible = true}
        state.ActiveTab = state.ActiveTab or name
        state.CategoryTabs[state.ActiveCategory] = state.CategoryTabs[state.ActiveCategory] or {}
        state.CategoryTabs[state.ActiveCategory][#state.CategoryTabs[state.ActiveCategory] + 1] = name
        handle.AddSection = function(_, title) return library:CreateSection(name, opt(title, "Title") or title) end
        handle.AddToggle = function(_, o) return library:AddToggle(nil, opt(o, "Name"), opt(o, "Default"), opt(o, "Callback")) end
        handle.AddSlider = function(_, o) return library:AddSlider(nil, opt(o, "Name"), opt(o, "Min"), opt(o, "Max"), opt(o, "Default"), opt(o, "Increment"), opt(o, "Callback")) end
        handle.AddDropdown = function(_, o) return library:AddDropdown(nil, opt(o, "Name"), opt(o, "Options"), opt(o, "Default"), opt(o, "Callback"), opt(o, "MultiSelect")) end
        handle.AddButton = function(_, o) return library:AddButton(nil, opt(o, "Name"), opt(o, "Callback")) end
        handle.AddTextBox = function(_, o) return library:AddTextbox(nil, opt(o, "Name"), opt(o, "Default"), opt(o, "Callback")) end
        handle.AddParagraph = function(_, a, b)
            if type(a) == "table" then return library:AddParagraph(nil, a.Title or a[1], a.Body or a[2]) end
            return library:AddParagraph(nil, a, b)
        end
        handle.SetVisible = function(_, visible) state.ContentPages[name].Visible = visible end
        handle.Select = function() state.ActiveTab = name end
        return handle
    end
    function library:Toggle() return true end
    -- The adapter drives visibility through RedzLib's Window:Minimize(), so the
    -- stub models it as the visibility flip the old Toggle performed.
    library.Minimize = function() state.GuiVisible = not state.GuiVisible; return state.GuiVisible end
    return library
end
-- The adapter treats the module export as the library and the MakeWindow return
-- as the window; tests introspect `ui.Library._Tabs/_Categories/_Controls/_STATE`,
-- so the export forwards those to the single instance the window built.
return setmetatable({
    -- RedzLib reads the starting window size from Library.Default.UISize, which
    -- the adapter writes before MakeWindow. The double carries the same table so
    -- that write is exercised (and a test can assert the applied size).
    Default = { Theme = "Darker", UISize = UDim2.fromOffset(550, 380) },
    MakeWindow = function(_, options) return NewWindow() end
}, {
    __index = function(_, key)
        local lib = DOD_STUB_LIBRARY
        if lib then return lib[key] end
        return nil
    end,
})
]==]
local function sandbox(placeId, gameId)
    local player = Instance.new("Player")
    player.CharacterAdded, player.CharacterRemoving, player.CameraMaxZoomDistance = signal(), signal(), 128
    player.Idled = signal()
    player.ChildAdded, player.ChildRemoved = signal(), signal()
    local players = {LocalPlayer=player, PlayerAdded=signal(), PlayerRemoving=signal()}
    -- Test-only: register another player (with a character holding a
    -- HumanoidRootPart) so features that scan players:GetPlayers() -- e.g. silent
    -- aim's nearest-target search -- have someone to find. The entry carries the
    -- distance helper a test sets up via AddPlayer below.
    players.Extra = {}
    function players:GetPlayers()
        local list = {player}
        for _, extra in ipairs(self.Extra) do list[#list + 1] = extra end
        return list
    end
    function players:FindFirstChild(name)
        if player.Name == name then return player end
        for _, extra in ipairs(self.Extra) do if extra.Name == name then return extra end end
    end
    function players:GetPlayerFromCharacter(character)
        for _, candidate in ipairs(players:GetPlayers()) do if candidate.Character == character then return candidate end end
    end
    local run = {RenderStepped=signal(), Stepped=signal(), Heartbeat=signal()}
    local input = {InputBegan=signal(), InputEnded=signal(), JumpRequest=signal()}
    local teleport = {Calls=0}
    function teleport:Teleport() self.Calls += 1 end
    function teleport:TeleportToPlaceInstance() self.Calls += 1 end
    local tween = {Create=function(_, object, info, goal)
        -- The mock keeps the target object and the goal table so tests can assert
        -- WHERE a flight is headed (the teleport motor's whole contract), not
        -- just that Play was called.
        --
        -- FAITHFUL to the real client's Tween: `:Cancel()` FIRES `Completed`
        -- (with PlaybackState = Cancelled), and a tween can be Completed only
        -- once. The old mock made Cancel a silent no-op on Completed, which hid
        -- the real bug: the motor's `Completed` handler runs during Cancel, so
        -- any `self.Tween = nil` bookkeeping has to survive it. The signal is a
        -- real multi-connection event so a tween can carry more than one listener.
        local handle = {Instance=object, Info=info, Goal=goal, Playing=false,
            Play=function(self) self.Playing = true end,
            Cancel=function(self)
                if self.Finished then return end
                self.Finished = true
                self.Playing = false
                self.Cancelled = true
                self.PlaybackState = "Cancelled"
                self.CompletedEvent:Fire("Cancelled")
            end,
            CompletedEvent=signal()}
        handle.Completed = {
            Connect=function(_, fn)
                local connection = handle.CompletedEvent:Connect(fn)
                -- A tween created (and already Completed) fires to a late
                -- listener immediately, like the real client.
                if handle.Finished then fn(handle.PlaybackState) end
                return connection
            end,
        }
        -- Test helper (not part of the real API): finish the tween as if it ran
        -- to completion, firing every Completed listener once.
        handle.Finish = function(self)
            if self.Finished then return end
            self.Finished = true
            self.Playing = false
            self.PlaybackState = "Completed"
            self.CompletedEvent:Fire("Completed")
        end
        return handle
    end}
    local vim = {}
    for _, name in ipairs({"SendKeyEvent", "SendMouseButtonEvent", "SendMouseMoveEvent", "SendKeyDownEvent", "SendKeyUpEvent", "SendMouseWheelEvent"}) do
        vim[name] = function() end
    end
    local vuser = {}
    for _, name in ipairs({"Button1Down", "Button1Up", "MouseMove", "KeyPress", "CaptureController", "ClickButton1", "MoveMouseRel"}) do
        vuser[name] = function() end
    end
    -- Lighting is a real Instance double, not a plain table: features read
    -- properties off it (Brightness, GlobalShadows, ...) and a plain {} would
    -- error on that read. Instance doubles store arbitrary props in _props.
    local lighting = Instance.new("Lighting")
    lighting.GlobalShadows = true
    local services = {Players=players, RunService=run, UserInputService=input, TeleportService=teleport,
        TweenService=tween, VirtualInputManager=vim, VirtualUser=vuser,
        Workspace=Instance.new("Workspace"), Teams=Instance.new("Teams"), Lighting=lighting,
        ReplicatedStorage=Instance.new("ReplicatedStorage"), TextChatService=Instance.new("TextChatService"), HttpService={}}
    -- Minimal JSON codec for config round-trips: the config is flat scalars plus
    -- at most one level of nesting (keys, bounty), which is all this needs to
    -- support. Real HttpService is provided by the executor at runtime.
    do
        local function esc(s)
            return '"' .. s:gsub('[%c"\\]', function(c)
                if c == '"' then return '\\"' elseif c == '\\' then return '\\\\' else return string.format('\\u%04x', c:byte()) end
            end) .. '"'
        end
        local function isArray(t)
            local n = 0
            for _ in pairs(t) do n = n + 1 end
            return n == #t
        end
        local encode
        encode = function(v)
            local ty = type(v)
            if ty == "nil" then return "null" elseif ty == "boolean" then return v and "true" or "false"
            elseif ty == "number" then return tostring(v) elseif ty == "string" then return esc(v) end
            if ty == "table" then
                local parts = {}
                if isArray(v) then
                    for _, item in ipairs(v) do parts[#parts + 1] = encode(item) end
                    return "[" .. table.concat(parts, ",") .. "]"
                end
                for k, item in pairs(v) do parts[#parts + 1] = esc(tostring(k)) .. ":" .. encode(item) end
                return "{" .. table.concat(parts, ",") .. "}"
            end
            return "null"
        end
        local function decode(str)
            local pos = 1
            local function skip() while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end end
            local parse
            local function parseString()
                pos = pos + 1
                local out = {}
                while pos <= #str do
                    local c = str:sub(pos, pos)
                    if c == '"' then pos = pos + 1 break
                    elseif c == "\\" then
                        local n = str:sub(pos + 1, pos + 1)
                        if n == 'u' then out[#out + 1] = string.char(tonumber(str:sub(pos + 2, pos + 5), 16)); pos = pos + 6
                        else out[#out + 1] = n; pos = pos + 2 end
                    else out[#out + 1] = c; pos = pos + 1 end
                end
                return table.concat(out)
            end
            local function parseValue()
                skip()
                local c = str:sub(pos, pos)
                if c == "{" then
                    pos = pos + 1; local obj = {}; skip()
                    if str:sub(pos, pos) == "}" then pos = pos + 1 return obj end
                    while true do
                        skip(); local k = parseString(); skip(); pos = pos + 1  -- skip ':'
                        obj[k] = parseValue(); skip()
                        local d = str:sub(pos, pos); pos = pos + 1
                        if d == "}" then break end
                    end
                    return obj
                elseif c == "[" then
                    pos = pos + 1; local arr = {}; skip()
                    if str:sub(pos, pos) == "]" then pos = pos + 1 return arr end
                    while true do
                        arr[#arr + 1] = parseValue(); skip()
                        local d = str:sub(pos, pos); pos = pos + 1
                        if d == "]" then break end
                    end
                    return arr
                elseif c == '"' then return parseString()
                elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
                elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
                elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
                else
                    local num = str:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
                    pos = pos + #num; return tonumber(num)
                end
            end
            return parseValue()
        end
        services.HttpService.JSONEncode = function(_, v) return encode(v) end
        services.HttpService.JSONDecode = function(_, s) return decode(s) end
    end
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
    local context = {State={}, Logs={}, Requests={}, Responses={}, Deferred={}, Spawned={}, Services=services, Player=player, Instances=INSTANCES, NamecallMethod=nil}
    local game = {PlaceId=placeId or 1, GameId=gameId or 2, JobId="job"}
    function game:GetService(name) return assert(services[name], "Unexpected service " .. name) end
    function game:IsLoaded() return true end
    function game:HttpGet(url)
        context.Requests[#context.Requests + 1] = url
        assert(not url:find("src/ui/", 1, true), "Frontend download attempted")
        -- The shell's UI library is a normal repo file; the test double stands in
        -- for it so the wrapper can build a window without a real client. RedzLib
        -- itself needs a full Roblox client, so the harness answers with the same
        -- contract-shaped stub it has always used.
        if url:find("dephubv2lib", 1, true) or url:find("demon-theme", 1, true)
            or url:find("demon-of-darkness-ui", 1, true) or url:find("DemonOfDarknessUI", 1, true) then
            return DOD_LIBRARY_STUB
        end
        -- Any of the loader's source hosts maps to the same repo path, so strip
        -- whichever prefix the URL carries before looking the response up.
        local path = url
            :gsub("^https://raw%.githubusercontent%.com/glowpkj/DepHub/[^/]+/", "")
            :gsub("^https://github%.com/glowpkj/DepHub/raw/[^/]+/", "")
            :gsub("^https://cdn%.jsdelivr%.net/gh/glowpkj/DepHub@[^/]+/", "")
            :gsub("%?.*$", "")
        -- Host-specific overrides let a test make one mirror serve a different
        -- body (e.g. a stale version.txt) while the others stay current, which is
        -- how the host-resolution rule is exercised.
        local byHost = context.HostResponses or {}
        for _, entry in ipairs(byHost) do
            if url:find(entry.Match, 1, true) or entry.Match:find(url, 1, true) then
                if entry.Responses[path] ~= nil then return entry.Responses[path] end
            end
        end
        return assert(context.Responses[path], "Unexpected HTTP: " .. path)
    end
    local env = setmetatable({game=game, workspace=services.Workspace, Color3=Color3, Vector3=Vector3, CFrame=CFrame, typeof=typeof, Instance=Instance, Enum=Enum,
        UDim=UDim, UDim2=UDim2, ColorSequence=ColorSequence, NumberSequence=NumberSequence, RaycastParams=RaycastParams, TweenInfo=TweenInfo,
        getgenv=function() return context.State end, identifyexecutor=function() return "Test" end,
        print=function(message) context.Logs[#context.Logs + 1] = tostring(message) end,
        warn=function(message) context.Logs[#context.Logs + 1] = tostring(message) end,
        -- Executor hooking primitives, modelled faithfully enough for the real
        -- call sites: hookfunction swaps a method closure on the Instance that
        -- owns it (per-instance, not a field assignment -- a field assignment on
        -- a real remote raises), and restorefunction puts the original back.
        -- Each remote owns its own closure, so the owner is found by identity.
        hookfunction=function(target, replacement)
            if type(target) ~= "function" or type(replacement) ~= "function" then return nil end
            local owner, name
            for i = #context.Instances, 1, -1 do
                local inst = context.Instances[i]
                for _, method in ipairs({"FireServer", "InvokeServer"}) do
                    if inst._props[method] == target then owner, name = inst, method; break end
                end
                if owner then break end
            end
            if not owner then return nil end
            owner._props[name] = replacement
            return {Instance = owner, Name = name, Original = target}
        end,
        restorefunction=function(handle)
            if type(handle) ~= "table" or not handle.Instance then return end
            handle.Instance._props[handle.Name] = handle.Original
            return handle.Original
        end,
        -- Metamethod hooking, as an executor exposes it. Instances share ONE
        -- metatable (instanceMeta), so getrawmetatable(game) hands it back and a
        -- __namecall installed there sees every method-style call -- exactly the
        -- surface the silent aim hook rewrites. setreadonly is advisory here (the
        -- double is never actually locked), and newcclosure returns the function
        -- unchanged, which is enough for the hook's behaviour to be observable.
        getrawmetatable=function(target)
            if target == game then return instanceMeta end
            return getmetatable(target)
        end,
        setreadonly=function() return true end,
        newcclosure=function(fn) return fn end,
        getnamecallmethod=function() return namecallMethod end,
        task={wait=function() end, cancel=function() end,
            defer=function(fn, ...) context.Deferred[#context.Deferred + 1] = {Fn=fn, Args={...}} end,
            -- task.delay is scheduled as deferred work so tests can run it with
            -- ctx:FlushDeferred() instead of sleeping; the delay itself is not
            -- modelled because the harness has no clock to advance.
            delay=function(_, fn, ...) context.Deferred[#context.Deferred + 1] = {Fn=fn, Args={...}} end,
            spawn=function(fn, ...) context.Spawned[#context.Spawned + 1] = {Fn=fn, Args={...}}; return fn end}}, {__index=getfenv(0)})
    function env.loadstring(source)
        local fn, err = loadstring(source)
        if fn then setfenv(fn, env) end
        return fn, err
    end
    -- An optional vars table is published on getgenv() (the sandbox State, which
    -- is what a backend reads as its environment) for the duration of the chunk.
    -- This is how a test lifts a backend's own master switch -- e.g. the Blox
    -- Fruits DISABLED flag -- without editing the source under test.
    function context:Run(path, vars)
        local previous = {}
        if type(vars) == "table" then
            for key, value in pairs(vars) do
                previous[key] = context.State[key]
                context.State[key] = value
            end
        end
        local ok, result = pcall(function() return assert(env.loadstring(sources[path]))() end)
        if type(vars) == "table" then
            for key in pairs(vars) do context.State[key] = previous[key] end
        end
        assert(ok, result)
        return result
    end
    -- Install a remote's method the only way a real Instance allows: not by
    -- assigning the field (which raises), but by swapping the closure the
    -- Instance resolves, i.e. through the executor's hooking path. Tests use this
    -- to make a remote record into their own table; production code reaches the
    -- same slot via hookfunction.
    function context:SetMethod(instance, name, fn)
        instance._props[name] = fn
        return fn
    end
    -- Register another player with a live character at `position`, so a feature
    -- that scans players (silent aim's nearest target) can find it. Returns the
    -- Player; `context:RemovePlayers()` clears them between tests.
    function context:AddPlayer(name, position)
        local target = Instance.new("Player")
        target.Name = name
        target.CharacterAdded, target.CharacterRemoving = signal(), signal()
        local character = Instance.new("Model"); character.Name, character.Parent = name, target
        local hrp = Instance.new("Part"); hrp.Name, hrp.Parent = "HumanoidRootPart", character
        hrp.Position = position or Vector3.new(0, 0, 0)
        local humanoid = Instance.new("Humanoid"); humanoid.Parent = character
        humanoid.Health = 100
        humanoid.MaxHealth = 100
        target.Character = character
        -- O ESP e a captura de infos leem player.Data.<Nome>.Value (o caminho
        -- do jogo). A fixtura cria o Data com Level/Beli/Fragments/Race/Fruit
        -- como Value objects, pra a feature os achar de verdade -- um teste
        -- ajusta os .Value pra exercitar o que quiser. O Data e um FILHO (nao um
        -- campo): o __index do double resolve filho por nome, como o jogo.
        local data = Instance.new("Folder"); data.Name = "Data"; data.Parent = target
        for _, field in ipairs({ "Level", "Beli", "Fragments", "Race", "DevilFruit" }) do
            local value = Instance.new("NumberValue"); value.Name = field; value.Parent = data
        end
        context.Services.Players.Extra[#context.Services.Players.Extra + 1] = target
        return target, character
    end
    -- Instala os Values de Data no LOCAL player (Level/Beli/Fragments/Race/
    -- Fruit), pra a captura das MINHAS infos achar de verdade. Devolve a pasta
    -- Data pra o teste mexer nos .Value.
    function context:AddLocalData(values)
        local data = Instance.new("Folder"); data.Name = "Data"; data.Parent = context.Player
        for _, field in ipairs({ "Level", "Beli", "Fragments", "Race", "DevilFruit" }) do
            local value = Instance.new("NumberValue"); value.Name = field; value.Parent = data
        end
        if type(values) == "table" then
            for field, value in pairs(values) do
                if data:FindFirstChild(field) then data:FindFirstChild(field).Value = value end
            end
        end
        return data
    end
    function context:RemovePlayers()
        context.Services.Players.Extra = {}
    end
    function context:FlushDeferred()
        local pending = self.Deferred
        self.Deferred = {}
        for _, call in ipairs(pending) do call.Fn(unpack(call.Args)) end
    end
    -- task.spawn bodies are recorded (not run) so tests decide when they execute.
    -- Serve uses one for its delayed hit; running it here is how the test proves
    -- the "Serving" fire happens.
    function context:FlushSpawned()
        local pending = self.Spawned
        self.Spawned = {}
        for _, call in ipairs(pending) do call.Fn(unpack(call.Args)) end
    end
    -- Emulate the client's method-style dispatch for a remote: `remote:FireServer(...)`.
    -- In the real client that goes through the shared instance metatable's
    -- __namecall. So if a feature installed a __namecall hook (the silent aim
    -- does, via getrawmetatable(game)), it is the hook that runs and the remote
    -- sees exactly what it forwarded -- which is how a test proves the position
    -- was rewritten. Without a hook, the remote's own closure runs, as normal.
    -- Returns nothing; inspect `remote.Fired` / `remote.Invoked` for what landed.
    function context:FireRemote(remote, method, ...)
        local hook = instanceMeta.__namecall
        if type(hook) == "function" then
            namecallMethod = method
            local ok, err = pcall(hook, remote, ...)
            namecallMethod = nil
            if not ok then error(err, 2) end
            return
        end
        local impl = remote._props[method]
        assert(type(impl) == "function", "remote has no " .. tostring(method))
        return impl(remote, ...)
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
        -- The UI kit is loaded by the loader in game; a test that runs a backend
        -- directly (without the loader) still needs it, so mount it here too, the
        -- same way the loader does.
        local okKit, kit = pcall(function() return env.loadstring(sources['src/core/ui-kit.lua'])() end)
        if okKit and type(kit) == 'table' then self.State.__DEPHUB.UIKit = kit end
        return window, window.Library
    end
    env._provided = {}
    -- In-memory executor filesystem so config save/load (writefile/readfile/
    -- isfile/listfiles/delfile) is exercised end to end without touching disk.
    local fs = {}
    context.Files = fs
    env.writefile = function(name, data) fs[name] = tostring(data) end
    env.readfile = function(name) return fs[name] end
    env.isfile = function(name) return fs[name] ~= nil end
    env.delfile = function(name) fs[name] = nil end
    env.listfiles = function(dir)
        local out = {}
        for name in pairs(fs) do
            if dir == nil or dir == "" or name:sub(1, #dir) == dir then out[#out + 1] = name end
        end
        return out
    end
    env.appendfile = function(name, data) fs[name] = (fs[name] or "") .. tostring(data) end
    -- queue_on_teleport: executors use it to re-run a script after a teleport.
    -- The auto-execute toggle records the queued script so a test can assert the
    -- self re-exec line was handed to it (and that disabling clears it).
    context.QueuedTeleportScript = nil
    env.queue_on_teleport = function(script) context.QueuedTeleportScript = script end
    context.Env = env
    context.Sources = sources
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
    -- Executor globals live on getgenv() (the sandbox State), which is where
    -- features read them (diagnostics, the aim hook). Publish the hooking
    -- primitives there too, matching how a real executor exposes them.
    context.State.hookfunction = env.hookfunction
    context.State.restorefunction = env.restorefunction
    -- Executor debug library. Stock Luau has debug.getupvalue/setupvalue but no
    -- setter for closures' upvalues at a distance, so the real primitive is
    -- modelled here: a per-function list of upvalue slots the feature patches
    -- (Jump Anywhere rewrites CharacterActions.Jump's check upvalue). This keeps
    -- the offline path honest -- a feature that patches by index hits the same
    -- slots it would in an executor.
    local upvalueRegistry = {}
    env.debug = {
        getupvalue = function(fn, index)
            local slots = upvalueRegistry[fn]
            if not slots or not slots[index] then return nil end
            local slot = slots[index]
            return slot.Name, slot.Value
        end,
        setupvalue = function(fn, index, value)
            local slots = upvalueRegistry[fn]
            if not slots or not slots[index] then return nil end
            slots[index].Value = value
            return slots[index].Name
        end,
        -- Test-only: register the upvalue slots a function should expose. A real
        -- executor reads the compiler-produced slots; the harness has no compiled
        -- function for CA.Jump, so the test declares them.
        setregistry = function(fn, slots) upvalueRegistry[fn] = slots end,
    }
    context.State.debug = env.debug
    env.require = function(target)
        local module = target
        if type(module) == "table" and module._props then module = module._props.Module end
        if type(module) == "function" then return module() end
        if module ~= nil then return module end
        error("harness require: no ModuleScript payload", 2)
    end
    context.State.require = env.require
    return context
end
local ossContext = sandbox()
local player = ossContext.Player
-- Blox Fruits: the backend loads its own per-feature modules from
-- features/bloxfruits/ (one file per feature, each self-contained). These are
-- the files the tests have to serve, and the ones they exercise directly.
-- BF_INFRA is the teleport motor: it loads without a toggle and lives in
-- State.Infra, so the backend tests need its file served too.
local BF_FEATURE_PREFIX = "src/games/features/bloxfruits/"
local BF_FEATURES = {"bladhits", "fruit", "islands"}
local BF_INFRA = {"teleport"}
-- INSERT_THEME_SOURCE
-- INSERT_BLOXF_OSS_TESTS
-- INSERT_LIFECYCLE_TESTS
-- INSERT_HEADLESS_TESTS
-- INSERT_THEME_TESTS
print(string.format("PASS %d backend/headless checks", passed))
